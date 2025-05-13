extends Node3D

enum BiomeType {FOREST, WATER, MOUNTAIN, DESERT}

var biome_type: BiomeType
@onready var outline_mesh: MeshInstance3D = $OutlineMesh  # Outer ring mesh
@onready var token_mesh: MeshInstance3D = $TokenMesh  # Inner token mesh
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var game = get_node("/root/Game")

var owner_id: int = -1

var token_placement = null
var is_energy: bool = false
var is_blighted: bool = false

const BIOME_COLORS = {
	BiomeType.FOREST: Color(0.2, 0.8, 0.2),  # Green
	BiomeType.WATER: Color(0.2, 0.2, 0.8),     # Blue
	BiomeType.MOUNTAIN: Color(0.5, 0.5, 0.5), # Gray
	BiomeType.DESERT: Color(0.8, 0.8, 0.2),  # Yellow
}

# Add player color mapping
const PLAYER_COLORS = {
	1: Color(1, 0, 0),     # Host/Player 1 (Red)
	2: Color(0, 1, 0),     # Player 2 (Green) 
	3: Color(0, 0, 1),     # Player 3 (Blue)
	4: Color(1, 1, 0)      # Player 4 (Yellow)
}

func set_token_data(b_type: BiomeType, p_id: int = -1, energy: bool = false):
	print("Setting token data - Biome: ", b_type, " Owner: ", p_id, " Energy: ", energy)
	biome_type = b_type
	owner_id = p_id
	is_energy = energy
	
	# Standard mesh for all tokens
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0, 0, 0)
	mesh_instance.material_override = material
	
	update_token_display()

func update_token_display():
	var material = StandardMaterial3D.new()
	var outline_material = StandardMaterial3D.new()
	
	# Set biome color
	if token_mesh and biome_type in BIOME_COLORS:
		material.albedo_color = BIOME_COLORS[biome_type]
		token_mesh.material_override = material

	# Set player-specific outline color
	if game && game.player_colors.has(owner_id):
		outline_material.albedo_color = game.player_colors[owner_id]
		print("Setting token color for player ", owner_id, ": ", game.player_colors[owner_id])
	else:
		print("No color found for player ", owner_id)
		outline_material.albedo_color = Color(0.5, 0.5, 0.5)  # Gray
		
	outline_mesh.material_override = outline_material

func remove_token():
	# Mark the placement as unoccupied
	if token_placement:
		token_placement.set_occupied(false)
		token_placement.current_token = null
		token_placement.set_highlight(false)
	# Remove the token itself
	queue_free()
