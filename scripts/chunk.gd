extends Node3D

@export var cache = true

var pos: Vector3i
var mins: Vector3i
var maxs: Vector3i
var nodes: Array
var vm: VoxelMesh 
var vd: VoxelData
var data: Dictionary

func init(parent: Node, p: Vector3i, min: Vector3i, max: Vector3i, n: FastNoiseLite):
	pos = p
	mins = min
	maxs = max
	vm = VoxelMesh.new(mins, maxs)
	vd = VoxelData.new(n, mins, maxs)
	position = pos
	parent.call_deferred("add_child", self)

func update(pos: Vector3, res: float):
	if !data.has(res):
		data[res] = vd.read(pos, res)
	if len(data[res]) == 0:
		return

	# Create and configure nodes for the new meshes
	var meshes = vm.generate(data[res], res)
	var nodes_new = []
	for mesh in meshes:
		var node_body_collisions = CollisionShape3D.new()
		var node_body = StaticBody3D.new()
		var node = MeshInstance3D.new()
		node_body.call_deferred("add_child", node_body_collisions)
		node.call_deferred("add_child", node_body)
		# call_deferred("add_child", node) 

		node_body_collisions.set_shape(mesh.create_trimesh_shape())
		node.set_mesh(mesh)
		nodes_new.append(node)

	# Remove the existing nodes and attach the new ones
	# This is done after everything is ready to minimize the time during which the mesh disappears
	for node in nodes:
		node.queue_free()
	for node in nodes_new:
		call_deferred("add_child", node)
	nodes = nodes_new

	# If caching is enabled, remember the points at each resolution as long as the chunk isn't removed
	# This provides faster results when returning to a chunk, but does so at the cost of greatly increased memory use
	if !cache:
		data = {}
