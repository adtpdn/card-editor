# token_placement_location.gd
extends Node3D

enum BiomeType {FOREST, WATER, MOUNTAIN, DESERT}

@export var accepted_biome: BiomeType
@export var place_id: int = -1

var is_highlighted: bool = false
var is_occupied = false
var current_token = null
var is_blocked_by_elemental := false

# Replace biome colors with a neutral placeholder color
#const PLACEHOLDER_COLOR = Color(0.7, 0.7, 0.7, 0.2)  # Light gray with transparency
const PLACEHOLDER_COLOR = Color(0.736, 0.693, 0.454, 0.2)

const BIOME_NAMES = {
	BiomeType.FOREST: "Forest",
	BiomeType.WATER: "Water",
	BiomeType.MOUNTAIN: "Mountain",
	BiomeType.DESERT: "Desert"
}

@onready var marker_mesh = $MarkerMesh
@onready var area_3d = $Area3D

func _ready():
	hide_placement()
	
	update_marker_appearance()
	update_appearance()
	# Set up interaction
	# Set up area signals
	area_3d.input_event.connect(_on_area_input)
	area_3d.mouse_entered.connect(_on_mouse_entered)
	area_3d.mouse_exited.connect(_on_mouse_exited)
	
	# Make sure the Area3D is pickable
	area_3d.input_ray_pickable = true

func hide_placement():
	var game = get_node("/root/Game")
	var token_placements = get_node("/root/Game/TokenPlacements")
	
	for placement in token_placements.get_children():
		placement.hide()
 
func set_biome_placement():
	var game = get_node("/root/Game")
	var card_manager = game.card_manager
	var turn_phase_manager = game.turn_phase_manager
	var token_manager = game.token_manager
	if turn_phase_manager.current_phase == 0 and place_id == -1:
		self.show()
	if card_manager.is_plant_extra:
		self.show()

func set_sigil_placement():
	var game = get_node("/root/Game")
	var turn_phase_manager = game.turn_phase_manager
	var card_manager = game.card_manager
	if turn_phase_manager.current_phase == 1 and place_id != -1:
		self.show()
	if card_manager.is_plant_extra:
		self.show()

func _on_area_input(camera: Node, event: InputEvent, position: Vector3, normal: Vector3, shape_idx: int):
	# This function is now primarily for potential future interactions like tooltips.
	# The main token placement click is handled by the TokenManager and the larger biome areas.
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var game = get_node("/root/Game")
		print("area clicked")
		if game and game.has_node("TokenManager"):
			# We still pass the click to the token manager in case it needs to handle it,
			# for example, if a card effect requires clicking a specific spot.
			game.get_node("TokenManager").handle_touch(event.position)

func set_highlight(enabled: bool):
	if is_occupied:
		is_highlighted = false
		var material = StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = Color(0, 0, 0, 0)
		material.flags_transparent = true
		material.flags_no_depth_test = true
		$MarkerMesh.material_override = material
		return
	
	is_highlighted = enabled
	var material = StandardMaterial3D.new()
	
	if enabled:
		material.albedo_color = Color(0, 0, 0, 0)
		show()
	else:
		material.albedo_color = Color(0, 0, 0, 0)
		hide()
	
	if is_blocked_by_elemental:
		material.albedo_color = Color(1, 0, 0, 1)
		show()
	elif not is_blocked_by_elemental:
		material.albedo_color = Color(0, 0, 0, 0)
		hide()
	
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	$MarkerMesh.material_override = material

func set_occupied(occupied: bool):
	is_occupied = occupied
	if occupied:
		set_highlight(false)
	else:
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
	material.albedo_color = PLACEHOLDER_COLOR  # Use neutral color
	$MarkerMesh.material_override = material

func update_marker_appearance():
	var material = StandardMaterial3D.new()
	material.albedo_color = PLACEHOLDER_COLOR  # Use neutral color
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
	if !is_occupied and not is_blocked_by_elemental:
		var material = marker_mesh.material_override.duplicate()
		#material.albedo_color = Color(0.376, 0.709, 0.548, 0.4)
		material.albedo_color = Color(0, 0, 0, 0)
		marker_mesh.material_override = material

func _on_mouse_exited():
	if !is_occupied and not is_blocked_by_elemental:
		var material = marker_mesh.material_override.duplicate()
		#material.albedo_color = Color(0.736, 0.693, 0.454, 0.2)
		material.albedo_color = Color(0, 0, 0, 0)
		marker_mesh.material_override = material
