extends Node3D

@export var threads = -1

const view_profiles = [
	{at_threads = 0, distance = 16, chunk = Vector3(2, 1, 2), lod = [1]},
	{at_threads = 2, distance = 32, chunk = Vector3(2, 1, 2), lod = [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 2]},
	{at_threads = 4, distance = 64, chunk = Vector3(4, 2, 4), lod = [1, 1, 1, 1, 1, 2, 2, 2, 2, 4, 4, 4]},
	{at_threads = 8, distance = 128, chunk = Vector3(8, 4, 8), lod = [1, 1, 1, 2, 2, 2, 4, 4, 4, 4, 6, 6]},
	{at_threads = 16, distance = 256, chunk = Vector3(16, 8, 16), lod = [1, 1, 2, 2, 4, 4, 4, 4, 6, 6, 6, 6]},
	{at_threads = 32, distance = 512, chunk = Vector3(32, 16, 32), lod = [1, 1, 2, 4, 4, 4, 6, 6, 6, 6, 8, 8]},
	{at_threads = 64, distance = 1024, chunk = Vector3(64, 32, 64), lod = [1, 2, 4, 4, 6, 6, 6, 6, 8, 8, 8, 8]}
]

var seed = Data.settings.seed if Data.settings.seed >= 0 else randi()
var mins: Vector3i
var maxs: Vector3i
var chunks: Array
var chunks_lod: Array
var chunks_scene: Resource
var sphere: Array
var view: Dictionary

var update_threads: Array
var player: CharacterBody3D
var player_chunk: Vector3

func _sort(a: Vector3, b: Vector3):
	return a.distance_to(Vector3i(0, 0, 0)) < b.distance_to(Vector3i(0, 0, 0))

func _update(t: int):
	# Detect if the viewer position changed while updating and restart the process if so
	var pos_center = Vector3(INF, INF, INF)
	while pos_center != player_chunk:
		pos_center = player_chunk

		# Remove existing chunks that are outside the view sphere
		for pos in chunks_lod[t].duplicate():
			if pos_center != player_chunk:
				break

			var pos_sphere = pos - pos_center
			if not sphere.has(pos_sphere):
				if chunks[t].has(pos):
					chunks[t][pos].queue_free()
					chunks[t].erase(pos)
				chunks_lod[t].erase(pos)

		# Add new chunks that are inside the view sphere
		for pos_sphere in sphere:
			if pos_center != player_chunk:
				break

			# Attribute this chunk to a constant thread ID by using its position as an identifier
			# This ensures no two threads ever modify the same chunk and avoids requiring a mutex
			var pos = pos_sphere + pos_center
			var tid = int(pos.length()) % max(1, threads)
			if t != tid:
				continue

			# LOD level is picked from the view settings array based on distance
			var lod_dist = pos_sphere.distance_to(Vector3i(0, 0, 0))
			var lod_index = floor(lod_dist / (view.distance / len(view.lod)))
			var lod = view.lod[lod_index] * Data.settings.resolution

			# Update this chunk if its LOD level has changed
			# The nodes of empty chunks are immediately removed as to not waste resources and produce extra iterations later
			# If there was no data at the highest resolution, we know this chunk will never generate faces, assign zero LOD level to skip further attempts
			if not chunks_lod[t].has(pos) or (chunks_lod[t][pos] > 0 and chunks_lod[t][pos] != lod):
				chunks_lod[t][pos] = lod
				if !chunks[t].has(pos):
					chunks[t][pos] = chunks_scene.instantiate()
					chunks[t][pos].init(self, pos, mins, maxs, seed)
				if !chunks[t][pos].update(pos, lod):
					chunks[t][pos].queue_free()
					chunks[t].erase(pos)
					if lod == Data.settings.resolution:
						chunks_lod[t][pos] = 0

func _ready():
	# Spawn the player above ground level
	var player_scene = load("res://player.tscn")
	var player_scene_instance = player_scene.instantiate()
	add_child(player_scene_instance)
	player = player_scene_instance.get_node("Player")
	player.position = Vector3(0, Data.settings.mapgen.density_up * 2, 0)
	player_chunk = Vector3(INF, INF, INF)

func _enter_tree():
	# Configure the number of threads based on the thread count setting and system capabilities
	# -1 = Automatic, 0 = Disabled, 1+ = Fixed count
	threads = (OS.get_processor_count() if threads < 0 else threads) if OS.can_use_threads() else 0
	for i in threads:
		update_threads.append(Thread.new())
	for i in max(1, threads):
		chunks.append({})
		chunks_lod.append({})

	# Choose an appropriate view profile based on the number of threads available
	view = view_profiles[0]
	for vp in view_profiles:
		if threads >= vp.at_threads:
			view = vp

	mins = view.chunk / -2
	maxs = view.chunk / +2
	chunks_scene = load("res://chunk.tscn")
	print("Started new world with seed ", seed, " running on ", threads, " threads.")

	# Configure the virtual sphere of chunk positions visible from the player's POV
	# Each position is calculated against the active chunk to decide what to spawn
	# The list is sorted so points closest to the camera are processed first
	for x in range(-view.distance, view.distance + 1, view.chunk.x):
		for y in range(-view.distance, view.distance + 1, view.chunk.y):
			for z in range(-view.distance, view.distance + 1, view.chunk.z):
				var pos = Vector3(x, y, z)
				var dist = pos.distance_to(Vector3i(0, 0, 0))
				if dist < view.distance:
					sphere.append(pos)
	sphere.sort_custom(_sort)

func _process(_delta):
	# View updates are preformed when the player moves into a new chunk
	# This greatly improves performance while providing a good level of accuracy
	var pos_chunk = player.position.snapped(view.chunk)
	if player_chunk != pos_chunk:
		player_chunk = pos_chunk

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
