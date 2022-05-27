extends Node3D

@export var distance = 256
@export var chunk_size = 16
@export var lod_levels = 4
@export var density = Vector2(64, 1024)
@export var resolution = 1
@export var size = 128
@export var threads = -1

var scene: Resource
var mins: Vector3i
var maxs: Vector3i
var chunks: Array
var chunks_lod: Array
var view_sphere: Array

var update_threads: Array
var noise: FastNoiseLite
var viewer: CharacterBody3D
var viewer_pos: Vector3

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

func _update(t: int):
	# Detect if the viewer position changed while updating and restart the process if so
	var pos_center = Vector3(INF, INF, INF)
	while pos_center != viewer_pos:
		pos_center = viewer_pos

		# Add new chunks that are inside the view sphere
		for pos_sphere in view_sphere:
			if pos_center != viewer_pos:
				break

			# Attribute this chunk to a constant thread ID using its distance from the world center
			# This ensures no two threads ever modify the same chunk and avoids requiring a mutex
			var pos = pos_sphere + pos_center
			var pos_dist = pos.distance_to(Vector3i(0, 0, 0))
			var tid = int(pos_dist) % max(1, threads)
			if t != tid:
				continue

			# LOD levels are raised by the power of two for optimal accuracy and performance
			# As each time a chunk's LOD changes it must be processed again, fewer levels with large differences are best
			var lod_dist = pos_sphere.distance_to(Vector3i(0, 0, 0))
			var lod_steps = floor(lod_dist / (distance / lod_levels))
			var lod = resolution
			for i in lod_steps:
				lod += lod

			# Update this chunk if its LOD level changed
			# Zero LOD is used to mark chunks as empty, this avoids recalculation if no points were found at the smallest resolution
			if not chunks_lod[t].has(pos) or (chunks_lod[t][pos] > 0 and chunks_lod[t][pos] != lod):
				var points = _points(pos, lod)
				if points.size() > 0:
					if !chunks[t].has(pos):
						chunks[t][pos] = scene.instantiate()
						chunks[t][pos].generate(self, pos, mins, maxs)
					chunks[t][pos].draw(pos, points, lod)
				chunks_lod[t][pos] = 0 if lod == resolution and points.size() == 0 else lod

		# Remove existing chunks that are outside the view sphere
		for pos in chunks[t].duplicate():
			if pos_center != viewer_pos:
				break

			var pos_sphere = pos - pos_center
			if not view_sphere.has(pos_sphere):
				if chunks[t].has(pos):
					chunks[t][pos].queue_free()
					chunks[t].erase(pos)
				chunks_lod[t].erase(pos)

func _enter_tree():
	var size_half = int(round(chunk_size / 2))
	mins = Vector3i(-size_half, -size_half, -size_half)
	maxs = Vector3i(+size_half, +size_half, +size_half)
	scene = load("res://chunk.tscn")
	viewer = get_node("Player")
	viewer_pos = Vector3(INF, INF, INF)

	# Configure the number of threads based on the thread count setting and system capabilities
	# -1 = Automatic, 0 = Disabled, 1+ = Fixed count
	threads = (OS.get_processor_count() if threads < 0 else threads) if OS.can_use_threads() else 0
	for i in threads:
		update_threads.append(Thread.new())
	for i in max(1, threads):
		chunks.append({})
		chunks_lod.append({})

	# Setup the noise used to generate terrain
	var seed = randi()
	noise = FastNoiseLite.new()
	noise.noise_type = noise.TYPE_SIMPLEX
	noise.seed = seed
	noise.frequency = 1.0 / size
	print("Started new world with seed ", seed, " running on ", threads, " threads.")

	# Configure the virtual sphere of chunk positions visible from the player's POV
	# Each position is calculated against the active chunk to decide what to spawn
	# The list is sorted so points closest to the camera are processed first
	for x in range(-distance, distance, chunk_size):
		for y in range(-distance, distance, chunk_size):
			for z in range(-distance, distance, chunk_size):
				var pos = Vector3(x, y, z)
				var dist = pos.distance_to(Vector3i(0, 0, 0))
				if dist < distance:
					view_sphere.append(pos)
	view_sphere.sort_custom(_sort)

func _process(_delta):
	# View updates are preformed when the player moves into a new chunk
	# This greatly improves performance while providing a good level of accuracy
	var pos_chunk = viewer.position.snapped(maxs - mins)
	if viewer_pos != pos_chunk:
		viewer_pos = pos_chunk

		# Start the generator threads, if multithreading is disabled run updates on the main thread instead
		if threads == 0:
			_update(0)
		for i in len(update_threads):
			if !update_threads[i].is_started():
				update_threads[i].start(Callable(self, "_update"), i)

	# Stop the generator threads that finished their job
	for i in len(update_threads):
		if update_threads[i].is_started() && !update_threads[i].is_alive():
			update_threads[i].wait_to_finish()
