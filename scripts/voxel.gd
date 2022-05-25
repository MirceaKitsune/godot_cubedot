class_name Voxel extends RefCounted

var _surface_tool: SurfaceTool

# Helper used to describe face directions: 0 = -X, 1 = +X, 2 = -Y, 3 = +Y, 4 = -Z, 5 = +Z
const DIR = [Vector3(-1, 0, 0), Vector3(+1, 0, 0), Vector3(0, -1 , 0), Vector3(0, +1, 0), Vector3(0, 0, -1), Vector3(0, 0, +1)]

# Stores face data, generates corners and UV coordinates on init
class Quad extends RefCounted:
	var tc1: PackedVector3Array
	var tc2: PackedVector3Array
	var tu1: PackedVector2Array
	var tu2: PackedVector2Array
	var mins: Vector3
	var maxs: Vector3

	func _init(pos: Vector3, size: Vector2, dir: int):
		var invert = dir == 1 or dir == 2 or dir == 5
		var c: PackedVector3Array
		var u: PackedVector2Array
		if dir == 0 or dir == 1:
			c = [pos + Vector3(0, -size.x, -size.y), pos + Vector3(0, -size.x, +size.y), pos + Vector3(0, +size.x, -size.y), pos + Vector3(0, +size.x, +size.y)]
			u = [Vector2(c[0].y, c[0].z), Vector2(c[1].y, c[1].z), Vector2(c[2].y, c[2].z), Vector2(c[3].y, c[3].z)]
			mins = pos + Vector3(0, -size.x, -size.y)
			maxs = pos + Vector3(0, +size.x, +size.y)
		elif dir == 2 or dir == 3:
			c = [pos + Vector3(-size.x, 0, -size.y), pos + Vector3(-size.x, 0, +size.y), pos + Vector3(+size.x, 0, -size.y), pos + Vector3(+size.x, 0, +size.y)]
			u = [Vector2(c[0].x, c[0].z), Vector2(c[1].x, c[1].z), Vector2(c[2].x, c[2].z), Vector2(c[3].x, c[3].z)]
			mins = pos + Vector3(-size.x, 0, -size.y)
			maxs = pos + Vector3(+size.x, 0, +size.y)
		elif dir == 4 or dir == 5:
			c = [ pos + Vector3(-size.x, -size.y, 0), pos + Vector3(-size.x, +size.y, 0), pos + Vector3(+size.x, -size.y, 0), pos + Vector3(+size.x, +size.y, 0)]
			u = [Vector2(c[0].x, c[0].y), Vector2(c[1].x, c[1].y), Vector2(c[2].x, c[2].y), Vector2(c[3].x, c[3].y)]
			mins = pos + Vector3(-size.x, -size.y, 0)
			maxs = pos + Vector3(+size.x, +size.y, 0)
		tc1 = [c[0], c[1], c[2]] if invert else [c[2], c[1], c[0]]
		tc2 = [c[3], c[2], c[1]] if invert else [c[1], c[2], c[3]]
		tu1 = [u[0], u[1], u[2]] if invert else [u[2], u[1], u[0]]
		tu2 = [u[3], u[2], u[1]] if invert else [u[1], u[2], u[3]]

func _init():
	_surface_tool = SurfaceTool.new()

func _generate(points: Dictionary, res: float, opt: bool):
	# Faces are stored in slices each representing the virtual 2D plane the faces occupy
	var hres = res / 2
	var slices: Dictionary
	for p in points:
		for d in len(DIR):
			var pos = p + (DIR[d] * res)
			if !points.has(pos) or points[pos] <= 0:
				var center = p + (DIR[d] * hres)
				var size = Vector2(hres, hres)
				var slice = center * DIR[d]
				if !slices.has(slice):
					slices[slice] = []

				# If face optimization is enabled, existing faces will now be scanned
				# Any face that can merge will be deleted and replaced by the new face
				# The process compares two faces at a time and repeats until no more changes are made
				var q = Quad.new(center, size, d)
				var merge = opt
				while merge:
					merge = false
					for face in slices[slice]:
						if d == 0 or d == 1:
							var parallel_y = q.mins.y == face.mins.y and q.maxs.y == face.maxs.y
							var parallel_z = q.mins.z == face.mins.z and q.maxs.z == face.maxs.z
							var touching_y = q.mins.y == face.maxs.y or q.maxs.y == face.mins.y
							var touching_z = q.mins.z == face.maxs.z or q.maxs.z == face.mins.z
							if parallel_y and touching_z:
								center = Vector3(q.mins.x, (q.mins.y + q.maxs.y) / 2, (min(q.mins.z, face.mins.z) + max(q.maxs.z, face.maxs.z)) / 2)
								size = Vector2((q.maxs.y - q.mins.y) / 2, (max(q.maxs.z, face.maxs.z) - min(q.mins.z, face.mins.z)) / 2)
								merge = true
							elif parallel_z and touching_y:
								center = Vector3(q.mins.x, (min(q.mins.y, face.mins.y) + max(q.maxs.y, face.maxs.y)) / 2, (q.mins.z + q.maxs.z) / 2)
								size = Vector2((max(q.maxs.y, face.maxs.y) - min(q.mins.y, face.mins.y)) / 2, (q.maxs.z - q.mins.z) / 2)
								merge = true
						elif d == 2 or d == 3:
							var parallel_x = q.mins.x == face.mins.x and q.maxs.x == face.maxs.x
							var parallel_z = q.mins.z == face.mins.z and q.maxs.z == face.maxs.z
							var touching_x = q.mins.x == face.maxs.x or q.maxs.x == face.mins.x
							var touching_z = q.mins.z == face.maxs.z or q.maxs.z == face.mins.z
							if parallel_x and touching_z:
								center = Vector3((q.mins.x + q.maxs.x) / 2, q.mins.y, (min(q.mins.z, face.mins.z) + max(q.maxs.z, face.maxs.z)) / 2)
								size = Vector2((q.maxs.x - q.mins.x) / 2, (max(q.maxs.z, face.maxs.z) - min(q.mins.z, face.mins.z)) / 2)
								merge = true
							elif parallel_z and touching_x:
								center = Vector3((min(q.mins.x, face.mins.x) + max(q.maxs.x, face.maxs.x)) / 2, q.mins.y, (q.mins.z + q.maxs.z) / 2)
								size = Vector2((max(q.maxs.x, face.maxs.x) - min(q.mins.x, face.mins.x)) / 2, (q.maxs.z - q.mins.z) / 2)
								merge = true
						elif d == 4 or d == 5:
							var parallel_x = q.mins.x == face.mins.x and q.maxs.x == face.maxs.x
							var parallel_y = q.mins.y == face.mins.y and q.maxs.y == face.maxs.y
							var touching_x = q.mins.x == face.maxs.x or q.maxs.x == face.mins.x
							var touching_y = q.mins.y == face.maxs.y or q.maxs.y == face.mins.y
							if parallel_x and touching_y:
								center = Vector3((q.mins.x + q.maxs.x) / 2, (min(q.mins.y, face.mins.y) + max(q.maxs.y, face.maxs.y)) / 2, q.mins.z)
								size = Vector2((q.maxs.x - q.mins.x) / 2, (max(q.maxs.y, face.maxs.y) - min(q.mins.y, face.mins.y)) / 2)
								merge = true
							elif parallel_y and touching_x:
								center = Vector3((min(q.mins.x, face.mins.x) + max(q.maxs.x, face.maxs.x)) / 2, (q.mins.y + q.maxs.y) / 2, q.mins.z)
								size = Vector2((max(q.maxs.x, face.maxs.x) - min(q.mins.x, face.mins.x)) / 2, (q.maxs.y - q.mins.y) / 2)
								merge = true

						if merge:
							q = Quad.new(center, size, d)
							slices[slice].erase(face)
							break
				slices[slice].append(q)

	# Generate triangles and return the mesh
	var arr_mesh = ArrayMesh.new()
	_surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for slice in slices:
		for face in slices[slice]:
			_surface_tool.add_triangle_fan(PackedVector3Array(face.tc1), PackedVector2Array(face.tu1))
			_surface_tool.add_triangle_fan(PackedVector3Array(face.tc2), PackedVector2Array(face.tu2))
	_surface_tool.index()
	_surface_tool.generate_normals()
	_surface_tool.commit(arr_mesh)
	return arr_mesh

func get_mesh(points: Dictionary, res: float, opt: bool):
	return _generate(points, res, opt)
