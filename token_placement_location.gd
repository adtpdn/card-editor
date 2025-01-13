# token_placement_location.gd
extends Node3D

enum BiomeType {FOREST, DESERT, MOUNTAIN, WATER}

@export var accepted_biome: TokenManager.BiomeType
var is_highlighted: bool = false
var is_occupied = false
var current_token = null

const BIOME_COLORS = {
	BiomeType.FOREST: Color(0.2, 0.8, 0.2, 0.3),    # Green
	BiomeType.DESERT: Color(0.8, 0.8, 0.2, 0.3),    # Yellow
	BiomeType.MOUNTAIN: Color(0.5, 0.5, 0.5, 0.3),  # Gray
	BiomeType.WATER: Color(0.2, 0.2, 0.8, 0.3)      # Blue
}

const BIOME_NAMES = {
	BiomeType.FOREST: "Forest",
	BiomeType.DESERT: "Desert",
	BiomeType.MOUNTAIN: "Mountain",
	BiomeType.WATER: "Water"
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
		
		if !game or is_occupied or game.selected_token_index < 0:
			return
			
		var player_id = multiplayer.get_unique_id()
		if !game.is_valid_player_turn(player_id):
			return
			
		var player_tokens = game.token_manager.get_player_tokens(player_id)
		
		# Find matching token for the selected biome
		var matching_token_index = -1
		for i in range(player_tokens.size()):
			if int(player_tokens[i].biome) == int(accepted_biome):
				matching_token_index = i
				break
		
		if matching_token_index >= 0:
			if multiplayer.is_server():
				game.sync_token_placement.rpc(
					player_id,
					player_tokens[matching_token_index],
					global_position
				)
				game.token_manager.remove_token(player_id, matching_token_index)
			else:
				game.request_token_placement.rpc_id(1, matching_token_index, global_position)
			
			game.selected_token_index = -1
			game.unhighlight_all_token_placements()

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
	return !is_occupied && token_biome == accepted_biome  # Check if not occupied and biome matches

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
