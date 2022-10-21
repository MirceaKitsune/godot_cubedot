# Voxel data: Reads processes and writes point data containing voxel information stored in a virtual cube
# Instances are meant to be used temporarily to read or write data and are then disposed of
class_name VoxelData extends RefCounted

var seed: int
var mins: Vector3i
var maxs: Vector3i
var noise_cache: Dictionary

func _sort_materials(a: Dictionary, b: Dictionary):
	return a.mapgen.priority > b.mapgen.priority

func _generate_noise(pos: Vector3, n: FastNoiseLite, d: Curve):
	# Verify if this voxel position passes the noise test
	# As noise can be expensive remember the value we found at this position during previous checks
	# An offset of -1 guarantees no density while an offset of +1 guarantees full density, skip checking the noise outside those ranges
	if not noise_cache.has(pos):
		var ofs_point = remap(pos.y, -Data.settings.mapgen.scale_height / 2, +Data.settings.mapgen.scale_height / 2, 0, 1)
		var ofs = d.sample_baked(ofs_point)
		if ofs <= -1:
			noise_cache[pos] = 0
		elif ofs >= +1:
			noise_cache[pos] = 1
		else:
			noise_cache[pos] = min(1, max(0, abs(n.get_noise_3dv(pos)) + ofs))
	return noise_cache[pos]

func _generate(pos: Vector3, res: float, n: FastNoiseLite):
	# Compile the density mapgen settings into a curve
	var density = Curve.new()
	for point in len(Data.settings.mapgen.scale_height_curve):
		var point_index = float(point) / (len(Data.settings.mapgen.scale_height_curve) - 1)
		density.add_point(Vector2(point_index, Data.settings.mapgen.scale_height_curve[point]))
	density.bake()

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
					var vec_point = pos + vec.snapped(Vector3(node.mapgen.resolution_horizontal, node.mapgen.resolution_vertical, node.mapgen.resolution_horizontal))
					var has_height_min = typeof(node.mapgen.height_min) != TYPE_FLOAT or vec_point.y >= node.mapgen.height_min
					var has_height_max = typeof(node.mapgen.height_max) != TYPE_FLOAT or vec_point.y <= node.mapgen.height_max
					if has_height_min and has_height_max:
						for i in abs(node.mapgen.top) + 1:
							var check_density = typeof(node.mapgen.density_min) == TYPE_FLOAT or typeof(node.mapgen.density_max) == TYPE_FLOAT
							var noise = _generate_noise(vec_point - Vector3(0, i * node.mapgen.resolution_vertical, 0), n, density) if check_density else null
							var has_density_min = typeof(node.mapgen.density_min) != TYPE_FLOAT or noise >= node.mapgen.density_min
							var has_density_max = typeof(node.mapgen.density_max) != TYPE_FLOAT or noise <= node.mapgen.density_max
							if has_density_min and has_density_max:
								points[vec] = node.name
								break
					if points.has(vec):
						break
	noise_cache = {}
	return points

func read(pos: Vector3, res: float):
	# When storage is implemented, this function will read chunk data from the drive and only generate if none is found
	var noise = FastNoiseLite.new()
	noise.noise_type = noise.TYPE_PERLIN
	noise.fractal_type = noise.FRACTAL_RIDGED
	noise.seed = seed
	noise.frequency = 1.0 / Data.settings.mapgen.scale
	return _generate(pos, res, noise)

func _init(min: Vector3i, max: Vector3i, s: int):
	mins = min
	maxs = max
	seed = s
