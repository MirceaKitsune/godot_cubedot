extends Node3D

var pos: Vector3i
var mins: Vector3i
var maxs: Vector3i

var node: MeshInstance3D
var node_body: StaticBody3D
var node_body_collisions: CollisionShape3D

func generate(parent: Node, p: Vector3i, min: Vector3i, max: Vector3i):
	pos = p
	mins = min
	maxs = max

	position = pos
	node_body_collisions = CollisionShape3D.new()
	node_body = StaticBody3D.new()
	node = MeshInstance3D.new()
	node_body.call_deferred("add_child", node_body_collisions)
	node.call_deferred("add_child", node_body)
	call_deferred("add_child", node)
	parent.call_deferred("add_child", self)

func draw(pos: Vector3, points: Dictionary, res: float):
	var vox = Voxel.new(mins, maxs)
	var mesh = vox.generate(points, res)
	var mesh_collision = mesh.create_trimesh_shape()
	node.set_mesh(mesh)
	node_body_collisions.set_shape(mesh_collision)
