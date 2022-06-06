extends Node3D

var pos: Vector3i
var mins: Vector3i
var maxs: Vector3i
var seed: int
var data: Dictionary

var node: MeshInstance3D
var node_body: StaticBody3D
var node_body_collisions: CollisionShape3D

func _ready():
	node = get_node("Chunk")
	node_body = node.get_node("ChunkBody")
	node_body_collisions = node_body.get_node("ChunkBodyCollision")

func init(parent: Node, p: Vector3i, min: Vector3i, max: Vector3i, s: int):
	pos = p
	mins = min
	maxs = max
	seed = s
	position = pos

	parent.call_deferred("add_child", self)

func update(pos: Vector3, res: float):
	# Generate point data if not already cached for this resolution
	if !data.has(res):
		var vd = VoxelData.new(mins, maxs, seed)
		data[res] = vd.read(pos, res)

	# Obtain the chunk mesh and its collisions if any points exist, apply valid changes to the nodes
	# Returns true if geometry was generated or false if this chunk produced no faces
	if len(data[res]) > 0:
		var vm = VoxelMesh.new(mins, maxs)
		var m = vm.generate(data[res], res)
		if m.mesh:
			node.set_mesh(m.mesh)
			if m.mesh_collision:
				node_body_collisions.set_shape(m.mesh_collision)
			return true
	return false
