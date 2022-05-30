# Voxel data: Reads processes and writes point data containing voxel information stored in a virtual cube
# Instances are meant to be used temporarily to read or write data and are then disposed of
class_name VoxelData extends RefCounted

@export var density = Vector2(64, 1024)
@export var resolution_generator = Vector3(1, 0.5, 1)

var mins: Vector3i
var maxs: Vector3i
var noise: FastNoiseLite

func _generate_get(pos: Vector3):
	var ofs = density[0] if pos.y >= 0 else density[1]
	var n = noise.get_noise_3dv(pos) + (pos.y / ofs)
	return 1 - min(max(n, 0), 1)

func _generate(pos: Vector3, res: float):
	# A margin of 1 extra unit is added to the start and end of the iteration
	# This lets the mesh generator know the positions of direct neighbor voxels from neighboring chunks
	var points = {}
	var points_cache = {}
	var points_mins = mins / res
	var points_maxs = maxs / res
	for x in range(points_mins.x - 1, points_maxs.x + 1):
		for y in range(points_mins.y - 1, points_maxs.y + 1):
			for z in range(points_mins.z - 1, points_maxs.z + 1):
				var vec = Vector3(x, y, z) * res
				var vec_point = vec.snapped(resolution_generator)
				if not points_cache.has(vec_point):
					points_cache[vec_point] = _generate_get(pos + vec_point)
				if points_cache[vec_point] > 0:
					points[vec] = points_cache[vec_point]
	return points

func read(pos: Vector3, res: float):
	# When storage is implemented, this function will read chunk data from the drive and only generate if none is found
	return _generate(pos, res)

func _init(n: FastNoiseLite, min: Vector3i, max: Vector3i):
	mins = min
	maxs = max
	noise = n
