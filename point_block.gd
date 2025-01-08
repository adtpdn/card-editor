# block.gd
extends Node3D

enum BlockType { TRIANGLE, SQUARE, CIRCLE }

@export var block_type: BlockType = BlockType.SQUARE
var mesh_instance: MeshInstance3D

const BLOCK_SIZE = 2  # Width and depth
const BLOCK_HEIGHT = 0.4  # Height for all blocks

func _ready():
	create_mesh()

func create_mesh():
	mesh_instance = MeshInstance3D.new()
	add_child(mesh_instance)
	
	var material = create_base_material()
	
	match block_type:
		BlockType.TRIANGLE:
			mesh_instance.mesh = create_triangle_mesh()
			material.albedo_color = Color(1, 0.5, 0.5)  # Red tint
		BlockType.SQUARE:
			mesh_instance.mesh = create_square_mesh()
			material.albedo_color = Color(0.5, 1, 0.5)  # Green tint
		BlockType.CIRCLE:
			mesh_instance.mesh = create_circle_mesh()
			material.albedo_color = Color(0.5, 0.5, 1)  # Blue tint
	
	mesh_instance.material_override = material

func create_base_material() -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.metallic = 0.5
	material.roughness = 0.3
	material.emission_enabled = true
	material.emission_energy = 0.2
	return material

func create_triangle_mesh() -> ArrayMesh:
	# Create triangle with same width and depth as square
	var half_size = BLOCK_SIZE / 2
	var half_height = BLOCK_HEIGHT / 2
	
	var vertices = PackedVector3Array([
		# Bottom face
		Vector3(-half_size, -half_height, -half_size),  # Left back
		Vector3(half_size, -half_height, -half_size),   # Right back
		Vector3(0, -half_height, half_size),            # Center front
		
		# Top face
		Vector3(-half_size, half_height, -half_size),   # Left back
		Vector3(half_size, half_height, -half_size),    # Right back
		Vector3(0, half_height, half_size),             # Center front
	])
	
	var uvs = PackedVector2Array([
		# Bottom face
		Vector2(0, 0),
		Vector2(1, 0),
		Vector2(0.5, 1),
		# Top face
		Vector2(0, 0),
		Vector2(1, 0),
		Vector2(0.5, 1),
	])
	
	var normals = PackedVector3Array([
		Vector3(0, -1, 0),
		Vector3(0, -1, 0),
		Vector3(0, -1, 0),
		Vector3(0, 1, 0),
		Vector3(0, 1, 0),
		Vector3(0, 1, 0),
	])
	
	var indices = PackedInt32Array([
		# Bottom face
		0, 1, 2,
		# Top face
		5, 4, 3,
		# Side faces
		0, 3, 1,
		3, 4, 1,
		1, 4, 2,
		4, 5, 2,
		2, 5, 0,
		5, 3, 0
	])
	
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func create_square_mesh() -> BoxMesh:
	var mesh = BoxMesh.new()
	mesh.size = Vector3(BLOCK_SIZE, BLOCK_HEIGHT, BLOCK_SIZE)
	return mesh

func create_circle_mesh() -> CylinderMesh:
	var mesh = CylinderMesh.new()
	mesh.top_radius = BLOCK_SIZE / 2
	mesh.bottom_radius = BLOCK_SIZE / 2
	mesh.height = BLOCK_HEIGHT
	mesh.radial_segments = 32
	return mesh
