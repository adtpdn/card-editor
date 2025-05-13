# token_placement_location.gd
extends Node3D

enum BiomeType {FOREST, WATER, MOUNTAIN, DESERT}

@export var accepted_biome: TokenManager.BiomeType

var is_highlighted: bool = false
var is_occupied = false
var current_token = null


const BIOME_COLORS = {
	BiomeType.FOREST: Color(0.2, 0.8, 0.2, 0.3),    # Green
	BiomeType.WATER: Color(0.2, 0.2, 0.8, 0.3),      # Blue
	BiomeType.MOUNTAIN: Color(0.5, 0.5, 0.5, 0.3),  # Gray
	BiomeType.DESERT: Color(0.8, 0.8, 0.2, 0.3)    # Yellow
}

const BIOME_NAMES = {
	BiomeType.FOREST: "Forest",
	BiomeType.WATER: "Water",
	BiomeType.MOUNTAIN: "Mountain",
	BiomeType.DESERT: "Desert"
}

@onready var marker_mesh = $MarkerMesh
@onready var area_3d = $Area3D

func _ready():
	update_marker_appearance()
	update_appearance()
	# Set up interaction
	# Set up area signals
	area_3d.input_event.connect(_on_area_input)
	area_3d.mouse_entered.connect(_on_mouse_entered)
	area_3d.mouse_exited.connect(_on_mouse_exited)
	
	# Make sure the Area3D is pickable
	area_3d.input_ray_pickable = true

func _on_area_input(camera: Node, event: InputEvent, position: Vector3, normal: Vector3, shape_idx: int):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var game = get_node("/root/Game")
		
		if !game or is_occupied:
			return
			
		var player_id = multiplayer.get_unique_id()
		if !game.is_valid_player_turn(player_id):
			return
			
		# Only process clicks if token selection mode is active
		if !game.is_token_selected:
			return
		
		# Check if player has tokens left
		var player_tokens = game.token_manager.get_player_tokens(player_id)
		if player_tokens.size() <= 0:
			return
		
		# Just use the first available token
		var token_index = 0
		
		# Send placement request to server
		if multiplayer.is_server():
			game.request_token_placement(token_index, global_position)
		else:
			game.rpc_id(1, "request_token_placement", token_index, global_position)

func set_highlight(enabled: bool):
	if is_occupied:  # Never highlight if occupied
		is_highlighted = false
		var material = StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA  # Enable transparency
		material.albedo_color = Color(0, 0, 0, 0)  # Fully transparent
		material.flags_transparent = true  # Ensure transparency is enabled
		material.flags_no_depth_test = true  # Optional: prevents depth testing issues
		$MarkerMesh.material_override = material
		return
	
	is_highlighted = enabled
	var material = StandardMaterial3D.new()
	
	if enabled:
		material.albedo_color = Color(0, 0, 0, 0.3)  # Yellow highlight
	else:
		material.albedo_color = BIOME_COLORS[accepted_biome]  # Default biome color
		
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	$MarkerMesh.material_override = material

func set_occupied(occupied: bool):
	print("Setting occupied state to: ", occupied)
	is_occupied = occupied
	if occupied:
		set_highlight(false)
	else:
		# If no longer occupied, clear the token reference
		current_token = null

func set_energy_placement(is_sigil_placement: bool):
	# Optional: Update the visual appearance to indicate sigil placement
	if is_sigil_placement:
		# Maybe add a special effect or change the marker appearance
		var material = marker_mesh.material_override.duplicate()
		# Add a subtle glow or pattern to indicate sigil placement
		material.emission_enabled = true
		material.emission = Color(1, 1, 1, 0.3)
		marker_mesh.material_override = material

# Optional: Add these functions if you need drag and drop functionality
func _on_area_3d_mouse_entered():
	set_highlight(true)

func _on_area_3d_mouse_exited():
	set_highlight(false)

func update_appearance():
	var material = StandardMaterial3D.new()
	material.albedo_color = BIOME_COLORS[accepted_biome]
	$MarkerMesh.material_override = material

func update_marker_appearance():
	var material = StandardMaterial3D.new()
	material.albedo_color = BIOME_COLORS[accepted_biome]
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	marker_mesh.material_override = material

func can_place_token(token_biome: BiomeType) -> bool:
	return !is_occupied  # Only check if not occupied

func place_token(player_id: int, token_data: Dictionary):
	var game = get_node("/root/Game")
	
	# Create and place the token
	var token = game.token_manager.token_scene.instantiate()
	game.get_node("Tokens").add_child(token, true)
	token.set_token_data(token_data.biome, token_data.type)
	token.global_position = global_position
	
	# Mark as occupied
	set_occupied(true)
	
	# Update UI for the player who placed the token
	game.token_manager.remove_token(player_id, game.selected_token_index)
	game.update_token_ui(game.token_manager.get_player_tokens(player_id))

func _on_mouse_entered():
	if !is_occupied:
		var material = marker_mesh.material_override.duplicate()
		material.albedo_color.a = 0.6
		marker_mesh.material_override = material

func _on_mouse_exited():
	if !is_occupied:
		var material = marker_mesh.material_override.duplicate()
		material.albedo_color.a = 0.3
		marker_mesh.material_override = material
