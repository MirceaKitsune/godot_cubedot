extends Node3D

@export var distance = 256
@export var chunk_size = 16
@export var lod_levels = 4
@export var density = Vector2(64, 1024)
@export var resolution = 1
@export var size = 128

var scene: Resource
var mins: Vector3i
var maxs: Vector3i
var chunks: Dictionary
var chunks_lod: Dictionary
var view_sphere: Array
var view_sphere_lod: Dictionary
var update_reset: bool

var noise: FastNoiseLite
var viewer: CharacterBody3D
var viewer_pos: Vector3

var update_semaphore: Semaphore
var update_thread: Thread

func _sort(a: Vector3, b: Vector3):
	return a.distance_to(Vector3i(0, 0, 0)) < b.distance_to(Vector3i(0, 0, 0))

func _points_get(pos: Vector3):
	var ofs = density[0] if pos.y >= 0 else density[1]
	var n = noise.get_noise_3dv(pos) + (pos.y / ofs)
	return 1 - min(max(n, 0), 1)

func _points(pos: Vector3, res: float):
	# A margin of 1 extra unit is added to the start and end of the iteration
	# This lets the mesh generator know the positions of direct neighbor voxels from neighboring chunks
	var p = {}
	var points_mins = mins / res
	var points_maxs = maxs / res
	for x in range(points_mins.x - 1, points_maxs.x + 1):
		for y in range(points_mins.y - 1, points_maxs.y + 1):
			for z in range(points_mins.z - 1, points_maxs.z + 1):
				var vec = Vector3(x, y, z) * res
				var n = _points_get(pos + vec)
				if n > 0:
					p[vec] = n
	return p

func _update():
	while true:
		update_semaphore.wait()
		update_reset = false

		# Remove chunks that are outside the view sphere
		for pos in chunks.duplicate():
			if update_reset:
				break
			var pos_sphere = pos - viewer_pos
			if not view_sphere.has(pos_sphere):
				chunks[pos].queue_free()
				chunks.erase(pos)
				chunks_lod.erase(pos)

		# Create or update chunks that are inside the view sphere
		# LOD level 0 marks empty chunks that don't need to be spawned
		for pos_sphere in view_sphere:
			if update_reset:
				break
			var pos = pos_sphere + viewer_pos
			if not chunks_lod.has(pos) or (chunks_lod[pos] > 0 and chunks_lod[pos] != view_sphere_lod[pos_sphere]):
				var points = _points(pos, view_sphere_lod[pos_sphere])
				if points.size() > 0:
					if not chunks.has(pos):
						chunks[pos] = scene.instantiate()
						chunks[pos].generate(pos, mins, maxs)
						add_child(chunks[pos])
					chunks[pos].draw(pos, points, view_sphere_lod[pos_sphere])
				chunks_lod[pos] = view_sphere_lod[pos_sphere] if points.size() > 0 else 0

func _enter_tree():
	scene = load("res://chunk.tscn")
	viewer = get_node("Player")

	noise = FastNoiseLite.new()
	noise.noise_type = noise.TYPE_SIMPLEX
	noise.seed = randi()
	noise.frequency = 1.0 / size

	var size_half = int(round(chunk_size / 2))
	mins = Vector3i(-size_half, -size_half, -size_half)
	maxs = Vector3i(+size_half, +size_half, +size_half)
	viewer_pos = Vector3(INF, INF, INF)

	# Configure the virtual sphere of possible chunk positions
	# The list is sorted so points closest to the active chunk are processed first
	# Each LOD level is raised by the power of two for optimal accuracy and performance
	for x in range(-distance, distance, chunk_size):
		for y in range(-distance, distance, chunk_size):
			for z in range(-distance, distance, chunk_size):
				var pos = Vector3(x, y, z)
				var dist = pos.distance_to(Vector3i(0, 0, 0))
				if dist < distance:
					view_sphere.append(pos)
					view_sphere_lod[pos] = resolution
					var lod = floor(dist / (distance / lod_levels))
					for i in lod:
						view_sphere_lod[pos] += view_sphere_lod[pos]
	view_sphere.sort_custom(_sort)

	update_semaphore = Semaphore.new()
	update_thread = Thread.new()
	update_thread.start(Callable(self, "_update"))

func _exit_tree():
	update_semaphore.post()
	update_thread.wait_to_finish()

func _process(_delta):
	# Updates are only preformed when the player moves into a new chunk
	# Other chunks are evaluated based on the distance between them and the active chunk
	# This improves performance while providing a good level of accuracy
	var pos = viewer.position
	var pos_chunk = pos.snapped(maxs - mins)
	if viewer_pos != pos_chunk:
		viewer_pos = pos_chunk
		update_reset = true
		update_semaphore.post()
