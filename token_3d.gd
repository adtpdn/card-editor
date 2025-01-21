extends Node3D

enum BiomeType {FOREST, DESERT, MOUNTAIN, WATER}
enum TokenType {TRIANGLE, SQUARE, CIRCLE}

var biome_type: BiomeType
var token_type: TokenType
@onready var outline_mesh: MeshInstance3D = $OutlineMesh  # Outer ring mesh
@onready var token_mesh: MeshInstance3D = $TokenMesh  # Inner token mesh
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

var owner_id: int = -1

const TYPE_MESHES = {
	TokenType.TRIANGLE: preload("res://assets/meshes/triangle_mesh.tres"),
	TokenType.SQUARE: preload("res://assets/meshes/rectangle_mesh.tres"),
	TokenType.CIRCLE: preload("res://assets/meshes/cylinder_mesh.tres")
}

const BIOME_COLORS = {
	BiomeType.FOREST: Color(0.2, 0.8, 0.2),  # Green
	BiomeType.DESERT: Color(0.8, 0.8, 0.2),  # Yellow
	BiomeType.MOUNTAIN: Color(0.5, 0.5, 0.5), # Gray
	BiomeType.WATER: Color(0.2, 0.2, 0.8)     # Blue
}

func set_token_data(b_type: BiomeType, t_type: TokenType, p_id: int = -1):
	print("Setting token data - Biome: ", b_type, " Type: ", t_type, " Owner: ", p_id)
	biome_type = b_type
	token_type = t_type
	owner_id = p_id
	
	# Update mesh based on type
	if TYPE_MESHES.has(token_type):
		mesh_instance.mesh = TYPE_MESHES[token_type]
	
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0, 0, 0)
	mesh_instance.material_override = material
	
	update_token_display()

func update_token_display():
	var material = StandardMaterial3D.new()
	var outline_material = StandardMaterial3D.new()
	if token_mesh and biome_type in BIOME_COLORS:
		material.albedo_color = BIOME_COLORS[biome_type]
		token_mesh.material_override = material
	if owner_id == 1:  # Host
		outline_material.albedo_color = Color(1, 0.8, 0)  # Gold color for host
		outline_mesh.material_override = outline_material
	else:  # Client
		outline_material.albedo_color = Color(0, 0.8, 1)  # Blue color for client
		outline_mesh.material_override = outline_material
