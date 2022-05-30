# Voxel mesh: Generates the 3D mesh of a chunk from its voxel data object
# Instances are meant to be used temporarily to obtain a mesh and are then disposed of
class_name VoxelMesh extends RefCounted

@export var optimize = true

var _surface_tool: SurfaceTool
var mins: Vector3
var maxs: Vector3

# Helper used to describe face directions: 0 = -X, 1 = +X, 2 = -Y, 3 = +Y, 4 = -Z, 5 = +Z
const DIR = [Vector3(-1, 0, 0), Vector3(+1, 0, 0), Vector3(0, -1 , 0), Vector3(0, +1, 0), Vector3(0, 0, -1), Vector3(0, 0, +1)]

# Stores face data, returns corners and UV data on demand
class Quad extends RefCounted:
	var pos: Vector3
	var size: Vector2
	var dir: int
	var mins: Vector3
	var maxs: Vector3

	func _init(p: Vector3, s: Vector2, d: int):
		update(p, s, d)

	func update(p: Vector3, s: Vector2, d: int):
		pos = p
		size = s
		dir = d
		if dir == 0 or dir == 1:
			mins = pos + Vector3(0, -size.x, -size.y)
			maxs = pos + Vector3(0, +size.x, +size.y)
		elif dir == 2 or dir == 3:
			mins = pos + Vector3(-size.x, 0, -size.y)
			maxs = pos + Vector3(+size.x, 0, +size.y)
		elif dir == 4 or dir == 5:
			mins = pos + Vector3(-size.x, -size.y, 0)
			maxs = pos + Vector3(+size.x, +size.y, 0)

	func get_tris():
		var c: PackedVector3Array
		var u: PackedVector2Array
		var invert = dir == 1 or dir == 2 or dir == 5
		if dir == 0 or dir == 1:
			c = [pos + Vector3(0, -size.x, -size.y), pos + Vector3(0, -size.x, +size.y), pos + Vector3(0, +size.x, -size.y), pos + Vector3(0, +size.x, +size.y)]
			u = [Vector2(c[0].y, c[0].z), Vector2(c[1].y, c[1].z), Vector2(c[2].y, c[2].z), Vector2(c[3].y, c[3].z)]
		elif dir == 2 or dir == 3:
			c = [pos + Vector3(-size.x, 0, -size.y), pos + Vector3(-size.x, 0, +size.y), pos + Vector3(+size.x, 0, -size.y), pos + Vector3(+size.x, 0, +size.y)]
			u = [Vector2(c[0].x, c[0].z), Vector2(c[1].x, c[1].z), Vector2(c[2].x, c[2].z), Vector2(c[3].x, c[3].z)]
		elif dir == 4 or dir == 5:
			c = [ pos + Vector3(-size.x, -size.y, 0), pos + Vector3(-size.x, +size.y, 0), pos + Vector3(+size.x, -size.y, 0), pos + Vector3(+size.x, +size.y, 0)]
			u = [Vector2(c[0].x, c[0].y), Vector2(c[1].x, c[1].y), Vector2(c[2].x, c[2].y), Vector2(c[3].x, c[3].y)]

		var tc1: PackedVector3Array
		var tc2: PackedVector3Array
		var tu1: PackedVector2Array
		var tu2: PackedVector2Array
		tc1 = [c[0], c[1], c[2]] if invert else [c[2], c[1], c[0]]
		tc2 = [c[3], c[2], c[1]] if invert else [c[1], c[2], c[3]]
		tu1 = [u[0], u[1], u[2]] if invert else [u[2], u[1], u[0]]
		tu2 = [u[3], u[2], u[1]] if invert else [u[1], u[2], u[3]]
		return {tc1 = tc1, tc2 = tc2, tu1 = tu1, tu2= tu2}

func _init(min: Vector3i, max: Vector3i):
	_surface_tool = SurfaceTool.new()
	mins = min
	maxs = max

func generate(points: Dictionary, res: float):
	# Faces are stored in slices each representing the virtual 2D plane the faces occupy
	var hres = res / 2
	var slices: Dictionary
	for p in points:
		# Points outside of chunk boundaries can't produce faces, they only exist to check neighbors
		if p.x < mins.x or p.x >= maxs.x or p.y < mins.y or p.y >= maxs.y or p.z < mins.z or p.z >= maxs.z:
			continue

		for d in len(DIR):
			var pos = p + (DIR[d] * res)
			if points.has(pos) and points[pos] > 0:
				continue

			# Slices range between 0 and the maximum chunk size, negative entries represent inverted faces
			var center = p + (DIR[d] * hres)
			var size = Vector2(hres, hres)
			var slice = (maxs + center) * DIR[d]
			if !slices.has(slice):
				slices[slice] = []

			# If face optimization is enabled, two scans are preformed through existing faces to detect and merge frontal then lateral matches
			# If a face that connects to the new face is detected, the old face is positioned and scaled to fill the gap, otherwise a new face is created
			var q = Quad.new(center, size, d)
			if optimize:
				# Match frontally (across size X)
				for face in slices[slice]:
					# Facing in X, parallel in Y, touching in Z
					if (face.dir == 0 or face.dir == 1) and (q.mins.y == face.mins.y and q.maxs.y == face.maxs.y) and (q.mins.z == face.maxs.z or q.maxs.z == face.mins.z):
						var new_pos = q.pos + Vector3(0, 0, -face.size.y if q.pos.z > face.pos.z else +face.size.y)
						var new_size = q.size + Vector2(0, face.size.y)
						q = face
						q.update(new_pos, new_size, d)
					# Facing in Y, parallel in X, touching in Z
					if (face.dir == 2 or face.dir == 3) and (q.mins.x == face.mins.x and q.maxs.x == face.maxs.x) and (q.mins.z == face.maxs.z or q.maxs.z == face.mins.z):
						var new_pos = q.pos + Vector3(0, 0, -face.size.y if q.pos.z > face.pos.z else +face.size.y)
						var new_size = q.size + Vector2(0, face.size.y)
						q = face
						q.update(new_pos, new_size, d)
					# Facing in Z, parallel in X, touching in Y
					if (face.dir == 4 or face.dir == 5) and (q.mins.x == face.mins.x and q.maxs.x == face.maxs.x) and (q.mins.y == face.maxs.y or q.maxs.y == face.mins.y):
						var new_pos = q.pos + Vector3(0, -face.size.y if q.pos.y > face.pos.y else +face.size.y, 0)
						var new_size = q.size + Vector2(0, face.size.y)
						q = face
						q.update(new_pos, new_size, d)
				slices[slice].erase(q)

				# Match laterally (across size Y)
				for face in slices[slice]:
					# Facing in X, parallel in Z, touching in Y
					if (face.dir == 0 or face.dir == 1) and (q.mins.z == face.mins.z and q.maxs.z == face.maxs.z) and (q.mins.y == face.maxs.y or q.maxs.y == face.mins.y):
						var new_pos = q.pos + Vector3(0, -face.size.x if q.pos.y > face.pos.y else +face.size.x, 0)
						var new_size = q.size + Vector2(face.size.x, 0)
						q = face
						q.update(new_pos, new_size, d)
					# Facing in Y, parallel in Z, touching in X
					if (face.dir == 2 or face.dir == 3) and (q.mins.z == face.mins.z and q.maxs.z == face.maxs.z) and (q.mins.x == face.maxs.x or q.maxs.x == face.mins.x):
						var new_pos = q.pos + Vector3(-face.size.x if q.pos.x > face.pos.x else +face.size.x, 0, 0)
						var new_size = q.size + Vector2(face.size.x, 0)
						q = face
						q.update(new_pos, new_size, d)
					# Facing in Z, parallel in Y, touching in X
					if (face.dir == 4 or face.dir == 5) and (q.mins.y == face.mins.y and q.maxs.y == face.maxs.y) and (q.mins.x == face.maxs.x or q.maxs.x == face.mins.x):
						var new_pos = q.pos + Vector3(-face.size.x if q.pos.x > face.pos.x else +face.size.x, 0, 0)
						var new_size = q.size + Vector2(face.size.x, 0)
						q = face
						q.update(new_pos, new_size, d)
				slices[slice].erase(q)
			slices[slice].append(q)

	# Generate triangles and return the mesh
	var arr_mesh = ArrayMesh.new()
	_surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for slice in slices:
		for face in slices[slice]:
			var f = face.get_tris()
			_surface_tool.add_triangle_fan(PackedVector3Array(f.tc1), PackedVector2Array(f.tu1))
			_surface_tool.add_triangle_fan(PackedVector3Array(f.tc2), PackedVector2Array(f.tu2))
	_surface_tool.index()
	_surface_tool.generate_normals()
	_surface_tool.commit(arr_mesh)
	return arr_mesh
