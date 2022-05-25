extends Node3D

@export var distance = 128
@export var chunk_size = 16
@export var lod_levels = 4
@export var density = Vector2(64, 256)
@export var resolution = 1
@export var noise_frequency = 0.01
@export var optimize = true

# Chunks object, handles chunk storage mesh drawing and node management
class _chunks extends Node3D:
	var mins: Vector3i
	var maxs: Vector3i
	var resolution: float
	var chunks: Array
	var view_chunk: Vector3
	var view_sphere: Array
	var view_sphere_lod: Dictionary
	var update_lod: Dictionary
	var update_reset: bool
	var optimize: bool

	var parent: Node3D
	var viewer: CharacterBody3D
	var noise: FastNoiseLite
	var noise_density: Vector2

	var node: Dictionary
	var node_body: Dictionary
	var node_body_collisions: Dictionary

	func _init(p: Node3D, v: CharacterBody3D, n: FastNoiseLite, nd: Vector2, dist: int, size: int, lod: int, res: float, opt: bool):
		var size_half = int(round(size / 2))
		mins = Vector3i(-size_half, -size_half, -size_half)
		maxs = Vector3i(+size_half, +size_half, +size_half)
		resolution = res
		optimize = opt
		view_chunk = Vector3(INF, INF, INF)

		parent = p
		viewer = v
		noise = n
		noise_density = nd

		# Configure the virtual sphere of possible chunk positions
		# The list is sorted so points closest to the active chunk are processed first
		for x in range(-dist, dist + 1, size):
			for y in range(-dist, dist + 1, size):
				for z in range(-dist, dist + 1, size):
					var pos = Vector3(x, y, z)
					var distance = pos.distance_to(Vector3i(0, 0, 0))
					if distance <= dist:
						# Each LOD level is raised to a power of two for optimal accuracy and performance
						var lod_levels = floor(distance / (dist / lod))
						var r = resolution
						for l in lod_levels:
							r += r

						view_sphere.append(pos)
						view_sphere_lod[pos] = r
		view_sphere.sort_custom(_sort)

	func _sort(a: Vector3, b: Vector3):
		return a.distance_to(Vector3i(0, 0, 0)) < b.distance_to(Vector3i(0, 0, 0))

	func _points_at(pos: Vector3):
		var ofs = noise_density[0] if pos.y >= 0 else noise_density[1]
		var n = noise.get_noise_3dv(pos) + (pos.y / ofs)
		return 1 - min(max(n, 0), 1)

	func _points(pos: Vector3, res: float):
		var p = {}
		var points_mins = mins / res
		var points_maxs = maxs / res
		for x in range(points_mins.x, points_maxs.x):
			for y in range(points_mins.y, points_maxs.y):
				for z in range(points_mins.z, points_maxs.z):
					var vec = Vector3(x, y, z) * res
					var n = _points_at(pos + vec)
					if n > 0:
						p[vec] = n
		return p

	func _chunk_create(pos: Vector3):
		chunks.append(pos)
		node_body_collisions[pos] = CollisionShape3D.new()
		node_body[pos] = StaticBody3D.new()
		node[pos] = MeshInstance3D.new()
		node[pos].position = pos
		node_body[pos].call_deferred("add_child", node_body_collisions[pos])
		node[pos].call_deferred("add_child", node_body[pos])
		parent.call_deferred("add_child", node[pos])

	func _chunk_destroy(pos: Vector3):
		chunks.erase(pos)
		node_body_collisions[pos].queue_free()
		node_body[pos].queue_free()
		node[pos].queue_free()
		node_body_collisions.erase(pos)
		node_body.erase(pos)
		node.erase(pos)

	func _chunk_draw(pos: Vector3, points: Dictionary, res: float):
		var vox = Voxel.new()
		var mesh = vox.get_mesh(points, res, optimize)
		var mesh_collision = mesh.create_trimesh_shape()
		node[pos].set_mesh(mesh)
		node_body_collisions[pos].set_shape(mesh_collision)

	func update_view():
		var pos = viewer.position
		var pos_chunk = pos.snapped(maxs - mins)
		if view_chunk != pos_chunk:
			view_chunk = pos_chunk
			update_reset = true

	func update():
		update_reset = false

		# Remove chunks that are outside the view sphere
		for pos in chunks.duplicate():
			if update_reset:
				break
			var pos_view = pos - view_chunk
			if not view_sphere.has(pos_view):
				_chunk_destroy(pos)
				update_lod.erase(pos)

		# Create or update chunks that are inside the view sphere
		# LOD level 0 marks empty chunks that don't need to be spawned
		for pos_view in view_sphere:
			if update_reset:
				break
			var pos = pos_view + view_chunk
			if not update_lod.has(pos) or (update_lod[pos] > 0 and update_lod[pos] != view_sphere_lod[pos_view]):
				var points = _points(pos, view_sphere_lod[pos_view])
				if points.size() > 0:
					if not chunks.has(pos):
						_chunk_create(pos)
					_chunk_draw(pos, points, view_sphere_lod[pos_view])
				update_lod[pos] = view_sphere_lod[pos_view] if points.size() > 0 else 0

var chunks: _chunks
var update_semaphore: Semaphore
var update_thread: Thread

func _enter_tree():
	var player = get_parent().get_node("Player")
	var noise = FastNoiseLite.new()
	noise.noise_type = noise.TYPE_PERLIN
	noise.seed = randi()
	noise.frequency = noise_frequency

	chunks = _chunks.new(self, player, noise, density, distance, chunk_size, lod_levels, resolution, optimize)
	update_semaphore = Semaphore.new()
	update_thread = Thread.new()
	update_thread.start(Callable(self, "_process_update"))

func _exit_tree():
	update_semaphore.post()
	update_thread.wait_to_finish()

func _process(_delta):
	# Updates are only preformed when the player moves into a new chunk
	# Other chunks are evaluated based on the distance between them and the active chunk
	# This improves performance while providing a good level of accuracy
	chunks.update_view()
	if chunks.update_reset:
		update_semaphore.post()

func _process_update():
	while true:
		update_semaphore.wait()
		chunks.update()
