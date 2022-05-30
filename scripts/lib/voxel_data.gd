# Voxel data: Reads processes and writes point data containing voxel information stored in a virtual cube
# Instances are meant to be used temporarily to read or write data and are then disposed of
class_name VoxelData extends RefCounted

var mins: Vector3i
var maxs: Vector3i
var noise: FastNoiseLite
var noise_cache: Dictionary

func _sort_materials(a: Dictionary, b: Dictionary):
	return a.generate.resolution_horizontal + a.generate.resolution_vertical > b.generate.resolution_horizontal + b.generate.resolution_vertical

func _generate_noise(pos: Vector3):
	# Verify if this voxel position passes the noise test
	# As noise can be expensive remember the value we found at this position during previous checks
	if not noise_cache.has(pos):
		var ofs = Data.settings.generate_density_up if pos.y >= 0 else Data.settings.generate_density_down
		var n = noise.get_noise_3dv(pos) + (pos.y / ofs)
		noise_cache[pos] = n
	return noise_cache[pos]

func _generate(pos: Vector3, res: float):
	# Find all materials with a generator definition
	# For performance and consistency materials with the largest resolution are picked first
	# This ensures less noise checks are performed while mitigating the risk of missing surfaces
	var mats = []
	for mat in Data.materials:
		if Data.materials[mat].generate:
			mats.append(Data.materials[mat])
	mats.sort_custom(_sort_materials)

	# A margin of 1 extra unit is added to the start and end of the iteration
	# This lets the mesh generator know the positions of direct neighbor voxels from neighboring chunks
	var points = {}
	var points_mins = mins / res
	var points_maxs = maxs / res
	for x in range(points_mins.x - 1, points_maxs.x + 1):
		for y in range(points_mins.y - 1, points_maxs.y + 1):
			for z in range(points_mins.z - 1, points_maxs.z + 1):
				for mat in mats:
					var vec = Vector3(x, y, z) * res
					var vec_resolution = Vector3(mat.generate.resolution_horizontal, mat.generate.resolution_vertical, mat.generate.resolution_horizontal)
					var vec_point = vec.snapped(vec_resolution)
					var vec_point_offset = Vector3(0, mat.generate.offset, 0) if mat.generate.offset else Vector3(0, 0, 0)
					var n = _generate_noise(pos + vec_point - vec_point_offset)
					if (!mat.generate.density_min or n >= mat.generate.density_min) and (!mat.generate.density_max or n <= mat.generate.density_max):
						points[vec] = mat.name
						break
	return points

func read(pos: Vector3, res: float):
	# When storage is implemented, this function will read chunk data from the drive and only generate if none is found
	return _generate(pos, res)

func _init(n: FastNoiseLite, min: Vector3i, max: Vector3i):
	mins = min
	maxs = max
	noise = n
