extends Node3D

@export var cache = true

var pos: Vector3i
var mins: Vector3i
var maxs: Vector3i

var vm: VoxelMesh 
var vd: VoxelData
var data: Dictionary

var node: MeshInstance3D
var node_body: StaticBody3D
var node_body_collisions: CollisionShape3D

func init(parent: Node, p: Vector3i, min: Vector3i, max: Vector3i, s: int):
	pos = p
	mins = min
	maxs = max
	vm = VoxelMesh.new(mins, maxs)
	vd = VoxelData.new(mins, maxs, s)
	position = pos

	node_body_collisions = CollisionShape3D.new()
	node_body = StaticBody3D.new()
	node = MeshInstance3D.new()
	node_body.call_deferred("add_child", node_body_collisions)
	node.call_deferred("add_child", node_body)
	call_deferred("add_child", node)

	parent.call_deferred("add_child", self)

func update(pos: Vector3, res: float):
	if !data.has(res):
		data[res] = vd.read(pos, res)
	if len(data[res]) == 0:
		return

	var mesh = vm.generate(data[res], res)
	var mesh_collision = mesh.create_trimesh_shape()
	node.set_mesh(mesh)
	node_body_collisions.set_shape(mesh_collision)

	# If caching is enabled, remember the points at each resolution as long as the chunk isn't removed
	# This provides faster results when returning to a chunk, but does so at the cost of greatly increased memory use
	# In the future this will become mandatory, as voxel data will be needed in realtime for inventory processing or effects
	if !cache:
		data = {}
