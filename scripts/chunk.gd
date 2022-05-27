extends Node3D

var pos: Vector3i
var mins: Vector3i
var maxs: Vector3i

var node: MeshInstance3D
var node_body: StaticBody3D
var node_body_collisions: CollisionShape3D

func generate(p: Vector3i, min: Vector3i, max: Vector3i):
	pos = p
	mins = min
	maxs = max

	node_body_collisions = CollisionShape3D.new()
	node_body = StaticBody3D.new()
	node = MeshInstance3D.new()
	node.position = pos
	node_body.add_child(node_body_collisions)
	node.add_child(node_body)
	add_child(node)

func draw(pos: Vector3, points: Dictionary, res: float):
	var vox = Voxel.new(mins, maxs)
	var mesh = vox.generate(points, res)
	var mesh_collision = mesh.create_trimesh_shape()
	node.set_mesh(mesh)
	node_body_collisions.set_shape(mesh_collision)
