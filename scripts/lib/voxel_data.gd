# Voxel data: Reads processes and writes point data containing voxel information stored in a virtual cube
class_name VoxelData extends RefCounted

var seed: int
var mins: Vector3i
var maxs: Vector3i
var noise_cache: Dictionary

func _sort_materials(a: Dictionary, b: Dictionary):
	# Nodes with a higher offset must spawn after those with a lower one
	# This ensures that nodes intended as toppings don't cut through their base and overshoot their offset
	return a.mapgen.top < b.mapgen.top

func _generate_noise(pos: Vector3, n: FastNoiseLite):
	# Verify if this voxel position passes the noise test
	# As noise can be expensive remember the value we found at this position during previous checks
	if not noise_cache.has(pos):
		var ofs = Data.settings.mapgen.density_up if pos.y >= 0 else Data.settings.mapgen.density_down
		var np = n.get_noise_3dv(pos) + (pos.y / ofs)
		noise_cache[pos] = np
	return noise_cache[pos]

func _generate(pos: Vector3, res: float, n: FastNoiseLite):
	# Find all materials with a generator definition and sort them accordingly
	var nodes = []
	for node in Data.nodes:
		if Data.nodes[node].mapgen:
			nodes.append(Data.nodes[node])
	nodes.sort_custom(_sort_materials)

	# A margin of 1 extra unit is added to the start and end of the iteration
	# This lets the mesh generator know the positions of direct neighbor voxels from neighboring chunks
	var points = {}
	var points_mins = mins / res
	var points_maxs = maxs / res
	for x in range(points_mins.x - 1, points_maxs.x + 2):
		for y in range(points_mins.y - 1, points_maxs.y + 2):
			for z in range(points_mins.z - 1, points_maxs.z + 2):
				for node in nodes:
					var vec = Vector3(x, y, z) * res
					var vec_resolution = Vector3(node.mapgen.resolution_horizontal, node.mapgen.resolution_vertical, node.mapgen.resolution_horizontal)
					var vec_point = vec.snapped(vec_resolution)
					for i in node.mapgen.top + 1:
						var vec_point_offset = Vector3(0, i, 0)
						var np = _generate_noise(pos + vec_point - vec_point_offset, n)
						if (!node.mapgen.density_min or np >= node.mapgen.density_min) and (!node.mapgen.density_max or np <= node.mapgen.density_max):
							points[vec] = node.name
							break
					if points.has(vec):
						break
	noise_cache = {}
	return points

func read(pos: Vector3, res: float):
	# When storage is implemented, this function will read chunk data from the drive and only generate if none is found
	var noise = FastNoiseLite.new()
	noise.noise_type = noise.TYPE_SIMPLEX
	noise.seed = seed
	noise.frequency = 1.0 / Data.settings.mapgen.size
	return _generate(pos, res, noise)

func _init(min: Vector3i, max: Vector3i, s: int):
	mins = min
	maxs = max
	seed = s
