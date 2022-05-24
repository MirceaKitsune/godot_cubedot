class_name Voxel extends RefCounted

var _surface_tool: SurfaceTool

func _init():
	_surface_tool = SurfaceTool.new()

func _generate_faces(faces: Array):
	for face in faces:
		_surface_tool.add_triangle_fan(PackedVector3Array([face.c1, face.c2, face.c3]), PackedVector2Array([face.u1, face.u2, face.u3]))
		_surface_tool.add_triangle_fan(PackedVector3Array([face.c4, face.c3, face.c2]), PackedVector2Array([face.u4, face.u3, face.u2]))

func _generate(points: Dictionary, res: float):
	var arr_mesh = ArrayMesh.new()
	_surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	var faces = []
	for p in points:
		var dirs = [Vector3(-1, 0, 0), Vector3(+1, 0, 0), Vector3(0, -1 , 0), Vector3(0, +1, 0), Vector3(0, 0, -1), Vector3(0, 0, +1)]
		for dir in dirs:
			var pos = p + (dir * res)
			if !points.has(pos) or points[pos] <= 0:
				if dir.x != 0:
					var c1 = p + (dir * res / 2) + Vector3(0, -res / 2, -res / 2)
					var c2 = p + (dir * res / 2) + Vector3(0, -res / 2, +res / 2)
					var c3 = p + (dir * res / 2) + Vector3(0, +res / 2, -res / 2)
					var c4 = p + (dir * res / 2) + Vector3(0, +res / 2, +res / 2)
					var u1 = Vector2(c1.y, c1.z)
					var u2 = Vector2(c2.y, c2.z)
					var u3 = Vector2(c3.y, c3.z)
					var u4 = Vector2(c4.y, c4.z)
					faces.append({c1 = c1, c2 = c2, c3 = c3, c4 = c4, u1 = u1, u2 = u2, u3 = u3, u4 = u4} if dir.x > 0 else {c1 = c2, c2 = c1, c3 = c4, c4 = c3, u1 = u2, u2 = u1, u3 = u4, u4 = u3})
				elif dir.y != 0:
					var c1 = p + (dir * res / 2) + Vector3(-res / 2, 0, -res / 2)
					var c2 = p + (dir * res / 2) + Vector3(-res / 2, 0, +res / 2)
					var c3 = p + (dir * res / 2) + Vector3(+res / 2, 0, -res / 2)
					var c4 = p + (dir * res / 2) + Vector3(+res / 2, 0, +res / 2)
					var u1 = Vector2(c1.x, c1.z)
					var u2 = Vector2(c2.x, c2.z)
					var u3 = Vector2(c3.x, c3.z)
					var u4 = Vector2(c4.x, c4.z)
					faces.append({c1 = c1, c2 = c2, c3 = c3, c4 = c4, u1 = u1, u2 = u2, u3 = u3, u4 = u4} if dir.y < 0 else {c1 = c2, c2 = c1, c3 = c4, c4 = c3, u1 = u2, u2 = u1, u3 = u4, u4 = u3})
				elif dir.z != 0:
					var c1 = p + (dir * res / 2) + Vector3(-res / 2, -res / 2, 0)
					var c2 = p + (dir * res / 2) + Vector3(-res / 2, +res / 2, 0)
					var c3 = p + (dir * res / 2) + Vector3(+res / 2, -res / 2, 0)
					var c4 = p + (dir * res / 2) + Vector3(+res / 2, +res / 2, 0)
					var u1 = Vector2(c1.x, c1.y)
					var u2 = Vector2(c2.x, c2.y)
					var u3 = Vector2(c3.x, c3.y)
					var u4 = Vector2(c4.x, c4.y)
					faces.append({c1 = c1, c2 = c2, c3 = c3, c4 = c4, u1 = u1, u2 = u2, u3 = u3, u4 = u4} if dir.z > 0 else {c1 = c2, c2 = c1, c3 = c4, c4 = c3, u1 = u2, u2 = u1, u3 = u4, u4 = u3})

	if len(faces) > 0:
		_generate_faces(faces)
	_surface_tool.index()
	_surface_tool.generate_normals()
	_surface_tool.commit(arr_mesh)
	return arr_mesh

func get_mesh(points: Dictionary, res: float):
	return _generate(points, res)
