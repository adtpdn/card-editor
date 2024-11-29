extends Node3D

enum BiomeType {FOREST, DESERT, MOUNTAIN, WATER}
enum TokenType {TYPE1, TYPE2, TYPE3}

var biome_type: BiomeType
var token_type: TokenType

@onready var mesh = $TokenMesh

const BIOME_COLORS = {
	BiomeType.FOREST: Color(0.2, 0.8, 0.2),  # Green
	BiomeType.DESERT: Color(0.8, 0.8, 0.2),  # Yellow
	BiomeType.MOUNTAIN: Color(0.5, 0.5, 0.5), # Gray
	BiomeType.WATER: Color(0.2, 0.2, 0.8)     # Blue
}

func set_token_data(b_type: BiomeType, t_type: TokenType):
	biome_type = b_type
	token_type = t_type
	update_token_display()

func update_token_display():
	if mesh and biome_type in BIOME_COLORS:
		var material = StandardMaterial3D.new()
		material.albedo_color = BIOME_COLORS[biome_type]
		mesh.material_override = material
