# Voxel mesh: Generates the 3D mesh of a chunk from its voxel data object
# Instances are meant to be used temporarily to obtain a mesh and are then disposed of
class_name VoxelMesh extends RefCounted

@export var optimize = true

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

	func get_tris(res: float):
		# c represents the 4 corners in 3D space, u represents the 4 UV coordinates in 2D space
		# UV coordinates must be flipped and / or rotated per direction to ensure the texture always points up
		# When rotating the coordinates, the X scale is used in the Y field and vice versa
		var c: PackedVector3Array
		var u: PackedVector2Array
		var u_scale_point = 1 / min(1, max(0, Data.settings.resolution_texture)) / res
		var u_scale = Vector2(u_scale_point * size.x * 2, u_scale_point * size.y * 2)
		if dir == 0 or dir == 1:
			c = [pos + Vector3(0, -size.x, -size.y), pos + Vector3(0, -size.x, +size.y), pos + Vector3(0, +size.x, -size.y), pos + Vector3(0, +size.x, +size.y)]
			u = [Vector2(0, u_scale.x), Vector2(u_scale.y, u_scale.x), Vector2(0, 0), Vector2(u_scale.y, 0)] if dir == 0 else [Vector2(u_scale.y, u_scale.x), Vector2(0, u_scale.x), Vector2(u_scale.y, 0), Vector2(0, 0)]
		elif dir == 2 or dir == 3:
			c = [pos + Vector3(-size.x, 0, -size.y), pos + Vector3(-size.x, 0, +size.y), pos + Vector3(+size.x, 0, -size.y), pos + Vector3(+size.x, 0, +size.y)]
			u = [Vector2(0, 0), Vector2(u_scale.y, 0), Vector2(0, u_scale.x), Vector2(u_scale.y, u_scale.x)] if dir == 2 else [Vector2(0, u_scale.x), Vector2(u_scale.y, u_scale.x), Vector2(0, 0), Vector2(u_scale.y, 0)]
		elif dir == 4 or dir == 5:
			c = [pos + Vector3(-size.x, -size.y, 0), pos + Vector3(-size.x, +size.y, 0), pos + Vector3(+size.x, -size.y, 0), pos + Vector3(+size.x, +size.y, 0)]
			u = [Vector2(u_scale.x, u_scale.y), Vector2(u_scale.x, 0), Vector2(0, u_scale.y), Vector2(0, 0)] if dir == 4 else [Vector2(0, u_scale.y), Vector2(0, 0), Vector2(u_scale.x, u_scale.y), Vector2(u_scale.x, 0)]

		var invert = dir == 1 or dir == 2 or dir == 5
		var tc1: PackedVector3Array = [c[0], c[1], c[2]] if invert else [c[2], c[1], c[0]]
		var tc2: PackedVector3Array = [c[3], c[2], c[1]] if invert else [c[1], c[2], c[3]]
		var tu1: PackedVector2Array = [u[0], u[1], u[2]] if invert else [u[2], u[1], u[0]]
		var tu2: PackedVector2Array = [u[3], u[2], u[1]] if invert else [u[1], u[2], u[3]]
		return {tc1 = tc1, tc2 = tc2, tu1 = tu1, tu2= tu2}

func _init(min: Vector3i, max: Vector3i):
	mins = min
	maxs = max

func generate(points: Dictionary, res: float):
	var slices: Array
	for pos in points:
		# Points outside of chunk boundaries can't produce faces, they only exist to check neighbors
		if pos.x < mins.x or pos.x >= maxs.x or pos.y < mins.y or pos.y >= maxs.y or pos.z < mins.z or pos.z >= maxs.z:
			continue

		# Determine if this material should be accounted for at the current resolution
		var node = Data.nodes[points[pos]]
		if node.lod > 0 and node.lod < res:
			continue

		# Look for neighbors in all directions (up, down, left, right, forward, backward)
		# If a voxel on the same or a lower layer isn't found, this is a valid empty space, draw a face between the two positions
		for d in len(DIR):
			var dir_pos = pos + (DIR[d] * res)
			var dir_node = Data.nodes[points[dir_pos]] if points.has(dir_pos) else null
			if dir_node and dir_node.layer <= node.layer and !(dir_node.lod > 0 and dir_node.lod < res):
				continue

			# Find the last material defined for this direction in the settings
			var materials = node.material
			var material = materials[0]
			if d == 1 and len(materials) > 5:
				material = materials[5]
			elif d == 0 and len(materials) > 4:
				material = materials[4]
			elif d == 5 and len(materials) > 3:
				material = materials[3]
			elif d == 4 and len(materials) > 2:
				material = materials[2]
			elif d == 3 and len(materials) > 1:
				material = materials[1]

			# Faces are stored in slices each representing the virtual 2D plane the faces occupy
			# This ensures only identical faces are checked against one another for optimization
			# Slices range from 0 to the maximum chunk size, negative entries represent inverted faces in the given direction
			# Each slice is indexed by layer and material name, eg: slice[0]["dirt"][(0, 0, 0)]
			var layer = node.layer
			var center = pos + (DIR[d] * (res / 2))
			var slice = (maxs + center) * DIR[d]
			while len(slices) <= layer:
				slices.append({})
			if !slices[layer].has(material):
				slices[layer][material] = {}
			if !slices[layer][material].has(slice):
				slices[layer][material][slice] = []

			# If face optimization is enabled, two scans are preformed through existing faces to detect and merge frontal then lateral matches
			# If a face that connects to the new face is detected, the old face is positioned and scaled to fill the gap, otherwise a new face is created
			var q = Quad.new(center, Vector2(res / 2, res / 2), d)
			if optimize:
				# Match frontally (across size X)
				for face in slices[layer][material][slice]:
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
				slices[layer][material][slice].erase(q)

				# Match laterally (across size Y)
				for face in slices[layer][material][slice]:
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
				slices[layer][material][slice].erase(q)
			slices[layer][material][slice].append(q)

	# Generate triangles then return the resulting mesh and collision shape
	# Collisions are generated once when the loop reaches the last solid layer
	# Only fully loaded chunks produce collisions, LOD levels are non-solid
	var m = {mesh = null, mesh_collision = null}
	if len(slices) > 0:
		m.mesh = ArrayMesh.new()
		var st = SurfaceTool.new()
		for layer in len(slices):
			for mesh in slices[layer]:
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				for slice in slices[layer][mesh]:
					for face in slices[layer][mesh][slice]:
						var f = face.get_tris(res)
						st.add_triangle_fan(PackedVector3Array(f.tc1), PackedVector2Array(f.tu1))
						st.add_triangle_fan(PackedVector3Array(f.tc2), PackedVector2Array(f.tu2))
				st.index()
				st.generate_normals()
				st.set_material(Data.materials[mesh])
				st.commit(m.mesh)
				st.clear()
			if layer == Data.settings.layer_solid and res == Data.settings.resolution:
				m.mesh_collision = m.mesh.create_trimesh_shape()
	return m
