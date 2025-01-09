extends Node3D

enum BiomeType {FOREST, DESERT, MOUNTAIN, WATER}
enum TokenType {TYPE1, TYPE2, TYPE3}

var biome_type: BiomeType
var token_type: TokenType
@onready var outline_mesh: MeshInstance3D = $OutlineMesh  # Outer ring mesh
@onready var token_mesh: MeshInstance3D = $TokenMesh  # Inner token mesh

var owner_id: int = -1

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
