# card-editor/src/managers/token_manager.gd
class_name TokenManager
extends Node

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# References to other managers
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
@onready var game = get_parent()
@onready var network_manager = $"../NetworkManager"
@onready var game_state_manager = $"../GameStateManager"
@onready var card_manager = $"../CardManager"
@onready var ui_manager = $"../UIManager"
@onready var point_counter = $"../PointCounter"
@onready var sigil_manager = $"../SigilManager"
@onready var turn_phase_manager = $"../TurnPhaseManager"
@onready var tokens = $"../Tokens"
@onready var notification = $"../Notification"
@onready var soil_star_actions = $"../SoilStarActions"


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Enums and Constants
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
enum BiomeType {FOREST, WATER, MOUNTAIN, DESERT}

const TOKENS_PER_PLAYER = 16  # Increased to 16 tokens
const MAX_TOKENS_PER_BIOME = 12
const TOKEN_PLACEMENT_COOLDOWN = 0.5  # 500ms cooldown

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Token System Variables
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
var player_tokens = {}
var selected_token_index = -1
var current_selected_button: Button = null

# Elementals
var hidden_placement_ids = {} 
# Variable to track biome where planting is locked
var locked_planting_biome: int = -1

# Modify token selection handling to use both biome and type
var selected_token_biome = -1
var selected_token_node

# Token selection state
var is_token_selected = false

var last_token_selection_time = 0.0
var last_token_placement_time = 0.0

# Token scene reference
var token_scene = preload("res://scenes/token/token_3d.tscn")

# --- Temporary token for visual feedback ---
var _temp_token_instance: Node3D = null
var _token_drag_plane = Plane(Vector3.UP, 0.1) # A plane slightly above the board for the temp token

# --- Biome Click Areas ---
var _biome_click_areas = {} # Dictionary to store biome areas

# Tracking player token counts
var player_token_counts = {}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Biome System Dependencies
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
var radius = 4.0  # Radius of the octagon
var borders_node: Node3D
var biome_assignments = {
	BiomeType.FOREST: [0, 1],    # Slices 0 and 1
	BiomeType.WATER: [2, 3],    # Slices 2 and 3
	BiomeType.MOUNTAIN: [4, 5],  # Slices 4 and 5
	BiomeType.DESERT: [6, 7]      # Slices 6 and 7
}

# Color definitions
const BIOME_COLORS = {
	BiomeType.FOREST: Color(0.2, 0.8, 0.2, 1.0),    # Green
	BiomeType.WATER: Color(0.2, 0.2, 0.8, 1.0),      # Blue
	BiomeType.MOUNTAIN: Color(0.5, 0.5, 0.5, 1.0),  # Gray
	BiomeType.DESERT: Color(0.8, 0.8, 0.2, 1.0)   # Yellow
}

# Signal declarations
signal token_placed(player_id: int, biome: BiomeType, location: Vector3)

var tokens_planted_this_turn = {}  # Track tokens planted per player per turn
var can_plant_on_sigil = true     # Track if player can still plant in sigil locations (place_id == -1)
var can_plant_on_biome = true     # Track if player can still plant in biome locations (place_id != -1)
var max_tokens_per_turn = 2       # Maximum tokens allowed per turn

const token_mat_player_1 = preload("res://assets/materials/token_material/token_mat_player_1.tres")
const token_mat_player_2 = preload("res://assets/materials/token_material/token_mat_player_2.tres")
const token_mat_player_3 = preload("res://assets/materials/token_material/token_mat_player_3.tres")
const token_mat_player_4 = preload("res://assets/materials/token_material/token_mat_player_4.tres")


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Initialization & Setup
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
func _ready():
	# Create the borders node first if not already present
	if !get_parent().has_node("BiomeBorders"):
		borders_node = Node3D.new()
		borders_node.name = "BiomeBorders"
		get_parent().add_child.call_deferred(borders_node)
	else:
		borders_node = get_parent().get_node("BiomeBorders")

	# Connect to the token button
	var token_button = get_parent().get_node("RightUI/TokenButton")
	if token_button:
		if token_button.pressed.is_connected(_on_token_selected):
			token_button.pressed.disconnect(_on_token_selected)
		token_button.pressed.connect(_on_token_selected)

# --- Make the temporary token follow the mouse ---
func _process(_delta):
	# If a temporary token exists, update its position to follow the mouse cursor in 3D space.
	if _temp_token_instance and get_viewport().get_camera_3d():
		var camera = get_viewport().get_camera_3d()
		var mouse_pos = get_viewport().get_mouse_position()
		var ray_origin = camera.project_ray_origin(mouse_pos)
		var ray_normal = camera.project_ray_normal(mouse_pos)
		var world_pos = _token_drag_plane.intersects_ray(ray_origin, ray_normal)
		if world_pos:
			_temp_token_instance.global_position = world_pos


func _input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		handle_touch(event.position)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Start of Core Token Planting Functions
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# This function is triggered when the player clicks the main "Token" button
func _on_token_selected() -> void:
	# 1. Perform validation checks.
	if not _can_toggle_token_selection():
		return

	# 2. Toggle the selection state.
	is_token_selected = not is_token_selected
	print("Token selection mode toggled to: %s" % is_token_selected)

	# 3. Update the UI and placement highlights based on the new state.
	if is_token_selected:
		_activate_placement_highlights()
		# Create the temporary token for visual feedback
		if not is_instance_valid(_temp_token_instance):
			_temp_token_instance = token_scene.instantiate()
			# Add to a high-level node to ensure it's drawn correctly and doesn't interfere
			game.add_child(_temp_token_instance)
			print("instance token")
			# Make it visual only - disable physics/input so it doesn't block clicks
			_temp_token_instance.get_node("TokenMesh/StaticBody3D").set_process_input(false)
			_temp_token_instance.get_node("TokenMesh/StaticBody3D").get_node("CollisionShape3D").disabled = true
			
			# Set its appearance to match the current player
			var player_id = multiplayer.get_unique_id()
			_temp_token_instance.set_token_data(0, player_id, false) # Biome doesn't matter, owner does
	else:
		print("unhiglight token")
		unhighlight_all_token_placements()
		# Destroy the temporary token if we cancel selection mode
		if is_instance_valid(_temp_token_instance):
			_temp_token_instance.queue_free()
			_temp_token_instance = null

	update_token_ui()

# -----------------------------------------------------------------------------
# PRIVATE HELPER FUNCTIONS (_on_token_selected)
# -----------------------------------------------------------------------------
func _can_toggle_token_selection() -> bool:
	var player_id = multiplayer.get_unique_id()
	if not game_state_manager.is_valid_player_turn(player_id):
		print("Not your turn!")
		is_token_selected = false
		update_token_ui()
		return false

	if get_player_tokens(player_id).size() <= 0:
		print("No tokens left!")
		is_token_selected = false
		update_token_ui()
		return false

	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_token_selection_time < TOKEN_PLACEMENT_COOLDOWN:
		return false

	last_token_selection_time = current_time
	return true

# Determines which placement locations to highlight based on the current game phase
# or active card effects.
func _activate_placement_highlights() -> void:
	unhighlight_all_token_placements() # Clear previous highlights first.

	# soil star case
	if soil_star_actions.is_playing_extra_token_from_soil_star:
		_highlight_placements_for_mode("extra_token")
		return

	var current_phase = turn_phase_manager.current_phase

	# Case 1: Special rule for the very first round of the game.
	if current_phase == turn_phase_manager.Phase.PLANT_BIOME and game_state_manager.current_round == 0:
		_highlight_placements_for_mode("biome_only")
		return

	# Case 2: A card effect is active that allows placing extra tokens.
	if card_manager.is_plant_extra:
		_highlight_placements_for_mode("extra_token")
		return

	# Case 3: Regular turn phases.
	match current_phase:
		turn_phase_manager.Phase.PLANT_BIOME:
			_highlight_placements_for_mode("biome_only")
		turn_phase_manager.Phase.PLANT_SIGIL_AND_CARD:
			_highlight_placements_for_mode("sigil_only")

# A helper function that iterates through all placements and highlights them
# based on the specified mode. This reduces code duplication.
func _highlight_placements_for_mode(mode: String) -> void:
	var instruction_text := ""
	var highlight_biome := false
	var highlight_sigil := false

	match mode:
		"biome_only":
			instruction_text = "Plant Token on a Biome Location"
			highlight_biome = true
		"sigil_only":
			instruction_text = "Plant Token on a Sigil Location"
			highlight_sigil = true
		"extra_token":
			instruction_text = "Plant Extra Token on any valid location"
			highlight_biome = true
			highlight_sigil = true

	for placement in get_parent().get_node("TokenPlacements").get_children():
		var current_biome = placement.accepted_biome
		if mode != "sigil_only":
			if current_biome == locked_planting_biome and placement.place_id == -1 :
				continue # Skip this placement entirely
		
		# If a placement is meant to be hidden by an effect, ensure it stays hidden.
		if hidden_placement_ids.has(current_biome) and placement.place_id in hidden_placement_ids[current_biome]:
			placement.hide()
			continue # Skip any further logic for this placement

		if not placement.is_occupied:
			var is_biome_placement = (placement.place_id == -1)
			var is_sigil_placement = (placement.place_id >= 0 and placement.place_id <= 7)

			# Determine if this placement should be shown and highlighted
			var should_highlight = (highlight_biome and is_biome_placement) or (highlight_sigil and is_sigil_placement)

			if should_highlight:
				placement.show() # Directly control visibility here
				placement.set_highlight(true)
			else:
				placement.hide() # Ensure others are hidden

	notification.show_instruction_label(instruction_text)
# -----------------------------------------------------------------------------
# END PRIVATE HELPER FUNCTIONS (_on_token_selected)
# -----------------------------------------------------------------------------

func handle_touch(position: Vector2) -> void:
	# 1. Perform initial validation checks. Exit early if input is not allowed.
	if not _can_process_input():
		return

	# 2. Get the 3D object that was touched via raycasting.
	var result: Dictionary = _raycast_from_screen(position)
	print("result : ", result)
	
	if result.is_empty():
		return

	# 3. Determine the current input mode (placing, targeting, etc.).
	var input_mode: String = _get_current_input_mode()

	# 4. Delegate to the correct handler based on the input mode.
	print("input mode : ", input_mode)
	match input_mode:
		#"PLACING_TOKEN":
			#var placement = get_token_placement_at_position(result.position)
			#if placement:
				#_handle_placement_action(placement)
		"SELECTING_MOVE_DESTINATION":
			var clicked_node = result.collider
			var area_node = null

			# Traverse up the node tree to find the main biome/sigil area that was clicked
			while(clicked_node != null):
				if clicked_node.has_method("get_script") and clicked_node.get_script() and "biome_id" in clicked_node:
					area_node = clicked_node
					break
				clicked_node = clicked_node.get_parent()

			# If a valid biome area was clicked...
			if area_node:
				var target_biome_id = area_node.biome_id
				var token_to_move = sigil_manager._selected_token
				
				# Find the best placement spot within that biome
				var destination_placement = _find_closest_available_placement(token_to_move.global_position, target_biome_id)
				
				if destination_placement:
					# If a spot was found, execute the move
					_handle_move_action(destination_placement)
				else:
					# If no spot is available (e.g., the biome is full)
					print("No available spots in the selected biome.")
					notification.show_instruction_label("No available spots in that biome.")
					get_tree().create_timer(2.0).timeout.connect(notification.hide_panel)
		
		"PLACING_TOKEN":
			# ---  Check for biome area click ---
			var clicked_node = result.collider
			var area_node = null

			# Traverse up to find a clickable area (either Biome or Sigil)
			while(clicked_node != null):
				if clicked_node.has_method("get_script") and clicked_node.get_script() and "biome_id" in clicked_node:
					area_node = clicked_node
					break
				clicked_node = clicked_node.get_parent()

			if area_node:
				var biome_type = area_node.biome_id
				# Differentiate between biome and sigil areas based on script path
				if area_node.get_script().resource_path.ends_with("biome_area.gd"):
					_find_closest_placement_and_plant(result.position, biome_type, true) # true for biome
				elif area_node.get_script().resource_path.ends_with("sigil_area.gd"):
					_find_closest_placement_and_plant(result.position, biome_type, false) # false for sigil
				
				## Clean up the temporary visual token
				if is_instance_valid(_temp_token_instance):
					_temp_token_instance.queue_free()
					_temp_token_instance = null
			
			else: 
				# Fallback to clicking individual placements if no specific area was clicked
				var placement = get_token_placement_at_position(result.position)
				if placement:
					_handle_placement_action(placement)

		"TARGETING_FOR_EFFECT":
			var token = _get_token_from_collider(result.collider)
			if token:
				_handle_card_effect_action(token)
		"IDLE_OR_SIGIL":
			_handle_idle_or_sigil_action(position, result.collider)

func _handle_move_action(destination_placement: Node3D) -> void:
	print("\n=== Handling Token Move Action ===")
	
	# Get the token that was selected for movement from the SigilManager
	var token_to_move = sigil_manager._selected_token
	if not is_instance_valid(token_to_move):
		print("ERROR: Token to move is no longer valid.")
		return
		
	var from_position = token_to_move.global_position
	var to_position = destination_placement.global_position
	
	print("Requesting move from %s to %s" % [from_position, to_position])

	# Request the server to perform the move
	if multiplayer.is_server():
		request_token_movement(from_position, to_position)
	else:
		rpc_id(1, "request_token_movement", from_position, to_position)

	# --- Reset all states and UI after the move is requested ---
	unhighlight_all_token_placements()
	
	# Hide Outerglow on all tokens
	for token in tokens.get_children():
		token.outerglow.hide()

	# Clear the instruction label
	notification.hide_panel()
	
	# Reset all relevant flags in SigilManager
	sigil_manager.is_selecting_destination = false
	sigil_manager.is_sigil_mode = false
	sigil_manager._selected_token = null
	if is_instance_valid(sigil_manager.selected_energy_token):
		sigil_manager.selected_energy_token.highlight(false)
		sigil_manager.selected_energy_token = null

# -----------------------------------------------------------------------------
# PRIVATE HELPER FUNCTIONS (Handle Touch)
# -----------------------------------------------------------------------------
# Checks for invalid conditions like cooldown or not being the player's turn.
func _can_process_input() -> bool:
	if Time.get_ticks_msec() / 1000.0 - last_token_placement_time < TOKEN_PLACEMENT_COOLDOWN:
		return false

	if not game_state_manager.is_valid_player_turn(multiplayer.get_unique_id()):
		print("Not your turn!")
		unhighlight_all_token_placements()
		return false

	return true

# Determines the current input state of the game.
func _get_current_input_mode() -> String:
	if sigil_manager.is_selecting_destination:
		return "SELECTING_MOVE_DESTINATION"
	if is_token_selected:
		return "PLACING_TOKEN"
	if card_manager.is_take_off_mode or card_manager.is_unblight_mode or card_manager.is_refresh_energy_mode or card_manager.is_swap_energy_mode:
		return "TARGETING_FOR_EFFECT"
	return "IDLE_OR_SIGIL"

# --- New function to find closest placement ---
func _find_closest_placement_and_plant(click_position_3d: Vector3, biome_type: int, is_for_biome: bool):
	var closest_placement = null
	var min_distance = INF

	for placement in get_parent().get_node("TokenPlacements").get_children():
		# Check if the placement is valid for this action (highlighted and in the correct biome)
		if placement.is_highlighted and placement.accepted_biome == biome_type:
			# Check if it's the correct type of placement (biome vs sigil)
			var is_biome_spot = placement.place_id == -1
			
			if is_for_biome == is_biome_spot:
				var distance = click_position_3d.distance_to(placement.global_position)
				if distance < min_distance:
					min_distance = distance
					closest_placement = placement
	
	# If we found a valid closest spot, handle the placement action
	if closest_placement:
		_handle_placement_action(closest_placement)
	else:
		var area_type = "biome" if is_for_biome else "sigil"
		print("No available %s placement locations found in the clicked biome." % area_type)

# Performs the raycast from the screen position into the 3D world.
func _raycast_from_screen(position: Vector2) -> Dictionary:
	var camera = get_parent().get_node_or_null("Camera3D")
	if not camera:
		printerr("Camera3D not found!")
		return {}

	var from: Vector3 = camera.project_ray_origin(position)
	var to: Vector3 = from + camera.project_ray_normal(position) * 1000
	var query := PhysicsRayQueryParameters3D.create(from, to)

	# FIX: Access the world's 3D space via the viewport.
	return get_viewport().get_world_3d().direct_space_state.intersect_ray(query)

# Safely gets a Token3D node from a collider, if one exists.
func _get_token_from_collider(collider: Node) -> Node3D:
	if collider and collider.get_parent() and collider.get_parent().get_parent() is Node3D:
		var potential_token = collider.get_parent().get_parent()
		if potential_token.name.begins_with("Token3D"):
			return potential_token
	return null

# Handles the logic for placing a new token onto a valid placement area.
func _handle_placement_action(placement: Node3D) -> void:
	if not placement.is_highlighted:
		print("Cannot place token here - not a valid location for the current phase.")
		return

	if placement.is_occupied:
		print("Location already occupied.")
		return

	# Place the token and reset the state
	var token_index := 0 # Just use the first available token
	if multiplayer.is_server():
		request_token_placement(token_index, placement.global_position, placement.accepted_biome)
	else:
		rpc_id(1, "request_token_placement", token_index, placement.global_position, placement.accepted_biome)

	is_token_selected = false
	unhighlight_all_token_placements()

# This function is called when no other mode is active. It delegates to the
# SigilManager to see if a click should initiate a sigil action.
func _handle_idle_or_sigil_action(position: Vector2, collider: Node) -> void:
	# If sigil mode is already active, we are selecting a TARGET.
	if sigil_manager.is_sigil_mode:
		var player_id = multiplayer.get_unique_id()
		if game.sigil_manager.selected_energy_token and game.sigil_manager.selected_energy_token.owner_id == player_id:
			var target_token = _get_token_from_collider(collider)
			if target_token and not target_token.is_energy:
				sigil_manager._selected_token = target_token
				sigil_manager.handle_sigil_input(position)
				sigil_manager.signal_other_player_token.emit()
	else:
		# If not in sigil mode, a click might START the sigil process.
		# Let the sigil manager handle this initial detection.
		if sigil_manager.handle_sigil_input(position):
			return # Input was handled by SigilManager.

# This function is called when a card effect mode is active.
func _handle_card_effect_action(token: Node3D) -> void:
	var effect_was_processed := true

	if card_manager.is_take_off_mode and token.is_energy:
		_process_card_effect("take_off_energy", token)
		card_manager.is_take_off_mode = false
	elif card_manager.is_unblight_mode and not token.is_energy and token.is_blighted:
		_process_card_effect("unblight_token", token)
		card_manager.is_unblight_mode = false
	elif card_manager.is_refresh_energy_mode and token.is_energy and token.is_blighted:
		_process_card_effect("refresh_energy", token)
		card_manager.is_refresh_energy_mode = false
	elif card_manager.is_swap_energy_mode and token.is_energy:
		_process_swap_energy_selection(token)
		# Swap is a multi-step process, so we return early and don't mark card as played yet.
		return
	else:
		effect_was_processed = false

	if effect_was_processed:
		turn_phase_manager.card_played = true
		card_manager.reset_all_effect_modes() # Call the new function
		unhighlight_outerglow()
		unhighlight_all_token_placements()

# A generic helper to execute a card effect and handle the server/client logic.
func _process_card_effect(effect_name: String, token: Node3D) -> void:
	var rpc_name := "request_" + effect_name
	if multiplayer.is_server():
		card_manager.call(effect_name, token.global_position) # Direct call on server
		point_counter.add_magic_points_from_biome(token.biome_type)
	else:
		card_manager.rpc_id(1, rpc_name, token.global_position)
		point_counter.rpc_id(1, "request_add_magic_points", token.biome_type)

# Contains the specific two-step logic for the Swap Energy card effect.
func _process_swap_energy_selection(token: Node3D) -> void:
	# First token selection
	if card_manager.first_swap_token == null:
		if token.owner_id == multiplayer.get_unique_id():
			card_manager.first_swap_token = token
			card_manager.first_swap_token.highlight(true)
			# Highlight other valid targets
			for t in tokens.get_children():
				var is_valid_target = t != card_manager.first_swap_token and t.is_energy and t.biome_type == card_manager.first_swap_token.biome_type
				t.outerglow.visible = is_valid_target
		else:
			print("You must select your own token first for a swap.")
	# Second token selection
	else:
		# If the player clicks the same token again, treat it as a deselection.
		if token == card_manager.first_swap_token:
			print("Swap action cancelled.")
			card_manager.first_swap_token.highlight(false)
			card_manager.first_swap_token = null
			unhighlight_outerglow() # This hides all target highlights.
			return # End the function here.
		var is_valid_target = token != card_manager.first_swap_token and token.biome_type == card_manager.first_swap_token.biome_type and token.owner_id != card_manager.first_swap_token.owner_id
		if is_valid_target:
			# Perform the swap
			if multiplayer.is_server():
				card_manager.swap_energy_tokens(card_manager.first_swap_token.global_position, token.global_position)
				point_counter.add_magic_points_from_biome(token.biome_type)
			else:
				card_manager.rpc_id(1, "request_swap_energy_tokens", card_manager.first_swap_token.global_position, token.global_position)
				point_counter.rpc_id(1, "request_add_magic_points", token.biome_type)

			# Reset state after swap is initiated
			unhighlight_outerglow()
			card_manager.first_swap_token = null
			card_manager.is_swap_energy_mode = false
			turn_phase_manager.card_played = true
# -----------------------------------------------------------------------------
# END PRIVATE HELPER FUNCTIONS (Handle Touch)
# -----------------------------------------------------------------------------

@rpc("any_peer")
func request_token_placement(token_index: int, position: Vector3, biome_type: int, is_blighted: bool = false) -> void:
	if not multiplayer.is_server():
		return

	# Determine the player ID from the sender.
	var player_id: int = multiplayer.get_remote_sender_id()
	if player_id == 0: # This is a local server request.
		player_id = multiplayer.get_unique_id()

	# 1. Perform all validation checks.
	var placement = get_token_placement_at_position(position)
	if not _is_placement_request_valid(player_id, token_index, placement):
		return

	# 2. Prepare the data for the new token.
	var token_data := {
		"biome": placement.accepted_biome,
		"is_blighted": is_blighted
	}

	# 3. Update server-side state BEFORE syncing.
	last_token_placement_time = Time.get_ticks_msec() / 1000.0
	remove_token(player_id, token_index)
	notification.hide_panel()

	# 4. If the plant extra card effect is active, award the magic points.
	if card_manager.is_plant_extra:
		# Call the RPC on point_counter to add 2 magic points to the biome.
		point_counter.rpc_id(1, "request_add_magic_points", token_data.biome)

		# Reset the flag immediately after use.
		#card_manager.is_plant_extra = false

	# 5. Broadcast the confirmed token placement to all clients.
	rpc("sync_token_placement", player_id, token_data, position)


@rpc("any_peer", "call_local")
func sync_token_placement(player_id: int, token_data: Dictionary, position: Vector3) -> void:
	var placement = get_token_placement_at_position(position)
	if not placement or placement.is_occupied:
		printerr("Token placement sync failed: Invalid or occupied placement at %s" % position)
		return

	if soil_star_actions.is_playing_extra_token_from_soil_star:
		soil_star_actions.is_playing_extra_token_from_soil_star = false

	# 1. Create the token and set its visual properties.
	var token = _create_token_instance(player_id, token_data, placement)

	# Biome locations have a place_id == -1
	if placement.place_id == -1 and not token.is_energy: # -1 is plant on biome
		get_parent().player_last_biome_placements[player_id] = token.biome_type
		print("Player %d last placed a token in biome %s" % [player_id, BiomeType.keys()[token.biome_type]])

	# 2. Update the local game state (counters, flags, UI).
	_update_state_after_placement(player_id, token)

	# 3. If this is the server, perform additional synchronization tasks.
	if multiplayer.is_server():
		_server_sync_after_placement(token)

	# 4. Emit signal for other systems to react to.
	emit_signal("token_placed", player_id, token_data.biome, position)

# -----------------------------------------------------------------------------
# PRIVATE HELPER FUNCTIONS request_token_placement and sync_token_placement
# -----------------------------------------------------------------------------
func _is_placement_request_valid(player_id: int, token_index: int, placement: Node) -> bool:
	if soil_star_actions.is_playing_extra_token_from_soil_star:
		return true # If using the action, always allow placement

	if not game_state_manager.is_valid_player_turn(player_id):
		get_parent().rpc_id(player_id, "notify_invalid_placement")
		return false

	var player_tokens = get_player_tokens(player_id)
	if not (token_index >= 0 and token_index < player_tokens.size()):
		printerr("Invalid token_index %d for player %d" % [token_index, player_id])
		return false

	if not placement or placement.is_occupied:
		printerr("Invalid or occupied placement for player %d" % player_id)
		return false

	# If the "Plant Extra" card effect is active, bypass the phase-based placement rules.
	if card_manager.is_plant_extra:
		return true # The UI has already highlighted valid spots, so we can approve.
	# Check if the placement is valid for the current game phase (normal rules).
	var current_phase = turn_phase_manager.current_phase
	var is_sigil_valid = (placement.place_id >= 0 and placement.place_id <= 7)
	if current_phase == turn_phase_manager.Phase.PLANT_BIOME and is_sigil_valid:
		return false
	if current_phase == turn_phase_manager.Phase.PLANT_SIGIL_AND_CARD and placement.place_id == -1:
		return false

	return true

# Handles the creation and configuration of a new token instance.
func _create_token_instance(player_id: int, token_data: Dictionary, placement: Node) -> Node:
	var token = token_scene.instantiate()
	get_parent().get_node("Tokens").add_child(token, true)

	var biome_type: int = int(token_data.get("biome", placement.accepted_biome))
	var is_energy: bool = placement.get_index() < 28
	var is_blighted: bool = token_data.get("is_blighted", false)

	token.set_token_data(biome_type, player_id, is_energy)
	token.is_blighted = is_blighted
	token.global_position = placement.global_position
	apply_player_material(token, player_id)

	if token.is_blighted:
		token.rotation_degrees.z = 180

	# Link the token and its placement location.
	token.token_placement = placement
	placement.set_occupied(true)
	placement.current_token = token

	return token

# Updates local game state variables and UI after a token is placed.
func _update_state_after_placement(player_id: int, token: Node) -> void:
	if not tokens_planted_this_turn.has(player_id):
		tokens_planted_this_turn[player_id] = 0
	tokens_planted_this_turn[player_id] += 1

	#if card_manager.is_plant_extra:
		#card_manager.is_plant_extra = false

	is_token_selected = false
	unhighlight_all_token_placements()

	if multiplayer.get_unique_id() == player_id:
		update_token_ui()

func _server_sync_after_placement(token: Node) -> void:
	# 1. Sync the updated available token counts for ALL players to ALL players.
	for pid in get_parent().players:
		var player_tokens = get_player_tokens(pid)
		# Broadcast this player's token data to everyone.
		rpc("sync_player_tokens", player_tokens, pid)

	# 2. Collect data for every token currently on the board.
	var all_tokens_data := []
	for t in get_parent().get_node("Tokens").get_children():
		all_tokens_data.append({
			"position": t.global_position,
			"biome": t.biome_type,
			"owner": t.owner_id,
			"is_energy": t.is_energy,
			"is_blighted": t.is_blighted
		})

	# 3. Broadcast the complete list of tokens to all clients.
	rpc("sync_all_tokens_on_board", all_tokens_data)

	# 4. Update the server's internal count for the player.
	var player_id = token.owner_id
	var updated_tokens = get_player_tokens(player_id)
	player_token_counts[player_id] = updated_tokens.size()

@rpc("any_peer", "call_local")
func sync_all_tokens_on_board(all_tokens_data: Array) -> void:
	var tokens_node = get_parent().get_node("Tokens")
	var placements_node = get_parent().get_node("TokenPlacements")

	# 1. Clear all existing tokens and reset placement states.
	for child in tokens_node.get_children():
		child.queue_free()
	for child in placements_node.get_children():
		child.is_occupied = false
		child.current_token = null

	# 2. Wait for one frame to ensure nodes are freed before recreating.
	await get_tree().process_frame

	# 3. Recreate all tokens from the authoritative data.
	for token_data in all_tokens_data:
		var placement = get_token_placement_at_position(token_data.position)
		if placement:
			# Note: We pass token_data itself to the creation function
			_create_token_instance(token_data.owner, token_data, placement)

# -----------------------------------------------------------------------------
# Blight and Move Logic
# -----------------------------------------------------------------------------
# NEW: Called by GameStateManager at the start of each turn.
func process_blighted_token_cycle():
	if not multiplayer.is_server(): return

	print("Processing blighted token cycle...")
	var tokens_to_move = []
	for token in get_parent().get_node("Tokens").get_children():
		if token.is_blighted:
			tokens_to_move.append(token)

	for token in tokens_to_move:
		var current_placement = get_token_placement_at_position(token.global_position)
		# Only move blighted tokens that are in the blight area (place_id == 10).
		if not current_placement or current_placement.place_id != 10:
			print("Skipping blighted token not in blight area (place_id: %d)." % [current_placement.place_id if current_placement else -99])
			continue

		var current_biome = token.biome_type
		var next_biome = _get_next_biome(current_biome)

		var new_placement = _find_available_blight_spot(next_biome)
		if new_placement:
			# If a spot is found, move the token there.
			rpc("sync_token_reposition", token.global_position, new_placement.global_position, next_biome)
		else:
			# If no spot is available in the next biome, it stays put for this turn.
			print("No available blight spot in biome %s for token." % BiomeType.keys()[next_biome])

# NEW: Helper to determine the next biome in the cycle.
func _get_next_biome(current_biome: int) -> int:
	var next_biome = (current_biome + 1) % 4 # Cycle through the 4 biomes
	return next_biome

# Called by card_manager or sigil_manager to start the blight process.
# This function must only be called on the server.
func blight_token_and_move(token_pos : Vector3):
	if not multiplayer.is_server(): return

	var placement = get_token_placement_at_position(token_pos)
	var token =  placement.current_token
	if token.is_blighted:
		return # Can't blight an invalid or already blighted token.

	var original_pos = token.global_position
	var biome_type = token.biome_type

	# Find a valid, unoccupied spot with place_id 10 in the same biome.
	var new_placement = _find_available_blight_spot(biome_type)

	if new_placement:
		var new_pos = new_placement.global_position
		# Broadcast the move to all clients (including the server).
		rpc("sync_token_blight_move", original_pos, new_pos)
	else:
		# If no spot is available, just blight the token in place.
		rpc("sync_token_blight", original_pos, true)

# NEW: Specifically for UNBLIGHTING a token and moving it back to the main board.
func unblight_token_and_move(token: Node3D):
	if not multiplayer.is_server(): return
	if not is_instance_valid(token) or not token.is_blighted:
		return # Can only unblight a valid, blighted token.

	var original_pos = token.global_position
	var biome_type = token.biome_type

	# Find an available NON-blight spot (place_id = -1) in the same biome.
	var new_placement = _find_available_non_blight_spot(biome_type)

	if new_placement:
		var new_pos = new_placement.global_position
		# Broadcast the move and unblight action.
		rpc("sync_token_unblight_move", original_pos, new_pos)
	else:
		# If no spot is available, just unblight it in place.
		rpc("sync_token_blight", original_pos, false)

# Helper to find a valid placement for a blighted token.
func _find_available_blight_spot(biome_type: int) -> Node:
	for placement in get_parent().get_node("TokenPlacements").get_children():
		if not placement.is_occupied and placement.accepted_biome == biome_type and placement.place_id == 10:
			return placement # Return the first available spot.
	return null # Return null if no spots are available.

# NEW: Helper to find an available spot on the regular board.
func _find_available_non_blight_spot(biome_type: int) -> Node:
	for placement in get_parent().get_node("TokenPlacements").get_children():
		if not placement.is_occupied and placement.accepted_biome == biome_type and placement.place_id == -1:
			return placement # Return the first available spot.
	return null # Return null if no spots are available.

# RPC called on all clients to execute the token blight and move.
@rpc("any_peer", "call_local")
func sync_token_blight_move(original_position: Vector3, new_position: Vector3):
	var token = find_token_at_position(original_position)
	if not is_instance_valid(token):
		printerr("Blight sync failed: Could not find token at original position.")
		return

	var old_placement = get_token_placement_at_position(original_position)
	var new_placement = get_token_placement_at_position(new_position)

	if not is_instance_valid(new_placement):
		printerr("Blight sync failed: Could not find new placement location.")
		return

	# Free up the old spot.
	if is_instance_valid(old_placement):
		old_placement.is_occupied = false
		old_placement.current_token = null

	# Move the token.
	token.global_position = new_position

	# Occupy the new spot.
	new_placement.is_occupied = true
	new_placement.current_token = token
	token.token_placement = new_placement

	# Update the token's state and play the animation.
	token.is_blighted = true
	token.play_blight_animation(true)

# NEW RPC for unblighting and moving.
@rpc("any_peer", "call_local")
func sync_token_unblight_move(original_position: Vector3, new_position: Vector3):
	var token = find_token_at_position(original_position)
	if not is_instance_valid(token):
		printerr("Unblight sync failed: Could not find token at original position.")
		return

	var old_placement = get_token_placement_at_position(original_position)
	var new_placement = get_token_placement_at_position(new_position)

	if not is_instance_valid(new_placement):
		printerr("Unblight sync failed: Could not find new placement location.")
		return

	# Free up the old spot.
	if is_instance_valid(old_placement):
		old_placement.is_occupied = false
		old_placement.current_token = null

	# Move the token.
	token.global_position = new_position

	# Occupy the new spot.
	new_placement.is_occupied = true
	new_placement.current_token = token
	token.token_placement = new_placement

	# Update the token's state and play the animation.
	token.is_blighted = false
	token.play_blight_animation(false)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# End of Core Token Planting Functions
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Start of Token Data and State Management
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Original functions from your token_manager.gd
func initialize_player_tokens(player_id: int, force_reset: bool = false):
	# Check if this is initial setup
	if !player_tokens.has(player_id) or force_reset:
		# Clear existing tokens
		player_tokens[player_id] = []

		# Add exactly 16 tokens (4 of each biome)
		for biome in range(BiomeType.size()):
			for i in range(4):  # 4 tokens per biome
				player_tokens[player_id].append({
					"biome": biome
				})

		print("Initialized tokens for player ", player_id, " with ", TOKENS_PER_PLAYER, " tokens")

func get_player_tokens(player_id: int) -> Array:
	if !player_tokens.has(player_id):
		player_tokens[player_id] = []
	return player_tokens[player_id].duplicate()

func add_token_to_player(player_id: int, biome_type: int):
	if !player_tokens.has(player_id):
		player_tokens[player_id] = []

	# Create a new token data entry with the appropriate biome
	player_tokens[player_id].append({
		"biome": biome_type
	})

	# Force update to clients
	var game = get_tree().get_root().get_node("Game")
	if game and game.multiplayer.is_server():
		var tokens = get_player_tokens(player_id)
		game.rpc_id(player_id, "sync_player_tokens", tokens)

func remove_token(player_id: int, token_index: int):
	if player_tokens.has(player_id) and token_index >= 0 and token_index < player_tokens[player_id].size():
		# Remove the token
		player_tokens[player_id].remove_at(token_index)

		# Debug output
		print("Removed token for player ", player_id,
			  ", remaining tokens: ", player_tokens[player_id].size())

		return true
	return false

func reset_turn_token_counters(player_id: int):
	# Reset the tokens planted counter for this player
	if tokens_planted_this_turn.has(player_id):
		tokens_planted_this_turn[player_id] = 0

	# Reset the placement type flags
	can_plant_on_sigil = true
	can_plant_on_biome = false  # Start with only sigil planting enabled

	# Reset ALL card effect flags - this is important
	card_manager.is_plant_extra = false
	card_manager.is_take_off_mode = false
	card_manager.is_unblight_mode = false
	card_manager.is_refresh_energy_mode = false
	card_manager.is_swap_energy_mode = false
	card_manager.first_swap_token = null

	# Reset sigil mode if it's the local player's turn ending
	if player_id == multiplayer.get_unique_id() and sigil_manager != null:
		sigil_manager.is_sigil_mode = false
		sigil_manager.is_sigil_c = false

	# Reset max tokens per turn to default
	max_tokens_per_turn = 2

	# Only sync the basic token planting state
	if multiplayer.is_server():
		rpc("sync_token_planting_state", player_id, 0, true, false, 2)

	# Update UI to reflect new state
	update_token_ui()

	# Reset any UI highlights
	unhighlight_all_token_placements()

	# Reset any highlighting on tokens
	if card_manager.first_swap_token:
		card_manager.first_swap_token.highlight(false)
		card_manager.first_swap_token = null

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# End of Token Data and State Management
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Start of Network Synchronization
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
@rpc("any_peer", "call_local")
func sync_player_tokens(tokens_data: Array, target_player_id: int) -> void:
	# Update the local data for the specified player.
	player_tokens[target_player_id] = tokens_data.duplicate()

	# If the updated player is the local player, refresh the UI.
	if multiplayer.get_unique_id() == target_player_id:
		update_token_ui()

@rpc("any_peer", "call_local")
func sync_token_blight(token_position: Vector3, is_blighted: bool):
	print("Syncing token blight at: " + str(token_position) + ", blighted: " + str(is_blighted))

	# Find the token at this position
	var token = null
	for t in get_parent().get_node("Tokens").get_children():
		if t.global_position == token_position:  # More generous distance check
			token = t
			break

	if token:
		# Set the blight flag
		token.is_blighted = is_blighted

		token.play_blight_animation(is_blighted)

		# Always unhighlight token placements after any token action
		#unhighlight_all_token_placements()

		# Reset remove and blight modes
		card_manager.is_take_off_mode = false
		card_manager.is_unblight_mode = false

	else:
		print("No token found at position for blight sync: " + str(token_position))

@rpc("any_peer", "call_local")
func sync_token_movement(from_position: Vector3, to_position: Vector3):
	var token = find_token_at_position(from_position)
	if !token:
		return

	var from_placement = get_token_placement_at_position(from_position)
	var to_placement = get_token_placement_at_position(to_position)

	if !from_placement or !to_placement:
		return

	# Update placements
	from_placement.set_occupied(false)
	from_placement.current_token = null

	token.biome_type = to_placement.accepted_biome
	to_placement.set_occupied(true)
	to_placement.current_token = token

	# Move the token
	token.global_position = to_placement.global_position

	# Ensure the player material is still correct
	apply_player_material(token, token.owner_id)

@rpc("any_peer", "call_local")
func receive_complete_token_state(placement_data: Array, token_data: Array):
	print("Received complete token state")

	# --- Step 1: Clear all old tokens ---
	for token in get_parent().get_node("Tokens").get_children():
		token.queue_free()

	# --- Step 2: Update placements (can be done right away) ---
	for placement_info in placement_data:
		var placement = get_token_placement_at_position(placement_info.position)
		if placement:
			placement.set_occupied(placement_info.occupied)

	# --- Step 3: Create new tokens and set their DATA ONLY ---
	# We create a temporary array to hold references to our new tokens.
	var new_tokens = []
	for token_info in token_data:
		var token = token_scene.instantiate()
		get_parent().get_node("Tokens").add_child(token, true)

		# Set all the data variables
		token.set_token_data(token_info.biome, token_info.owner, token_info.is_energy)
		token.is_blighted = token_info.is_blighted
		token.global_position = token_info.position

		if token.is_blighted:
			token.rotation_degrees.z = 180

		# Add the new token to our temporary array
		new_tokens.append(token)

	# --- Step 4: WAIT for one frame ---
	await get_tree().process_frame

	# --- Step 5: Set the VISUALS on the now-ready tokens ---
	for i in range(new_tokens.size()):
		var token = new_tokens[i]
		var token_info = token_data[i] # Get the corresponding data

		# Now that the token is ready, apply its material and visual state
		apply_player_material(token, token_info.owner)

		# Connect token to its placement
		var placement = get_token_placement_at_position(token_info.position)
		if placement:
			token.token_placement = placement
			placement.current_token = token

	# --- Step 6: Update UI ---
	update_token_ui()

# Main initialization function that can be called from game.gd
func initialize():
	#print("TokenManager initializing...")

	setup_token_placements()
	#setup_biome_borders()
	setup_token_ui()

	# Make sure host has tokens on startup
	if multiplayer.is_server():
		var host_id = multiplayer.get_unique_id()
		initialize_player_tokens(host_id, true)  # Force reset to ensure clean state

		# Directly update token UI for host
		var tokens = get_player_tokens(host_id)
		#print("Host initialized with " + str(tokens.size()) + " tokens")

		# Force update the token button
		var token_button = get_parent().get_node("RightUI/TokenButton")
		if token_button:
			token_button.text = "Tokens: " + str(tokens.size())
			token_button.disabled = false  # Force enable for host

	#print("TokenManager initialized.")

func setup_token_placements():
	# Only set up if not already set up
	if get_parent().get_node("TokenPlacements").get_child_count() > 0:
		return

	await get_parent().ready
	await get_tree().process_frame

	var token_placement_scene = preload("res://scenes/token/token_placement_location.tscn")

	# Clear existing placements
	for child in get_parent().get_node("TokenPlacements").get_children():
		child.queue_free()

	var placements_per_biome = {}

	# Initialize counters for each biome
	for biome in biome_assignments.keys():
		placements_per_biome[biome] = 0

	# Create placements for each biome
	for biome in biome_assignments.keys():
		var slice_indices = biome_assignments[biome]

		# Calculate start and end angles for the entire biome section
		var start_angle = slice_indices[0] * PI / 4
		var end_angle = (slice_indices[1] + 1) * PI / 4

		# Generate positions for this biome section
		var positions = _generate_slice_positions(
			radius,
			start_angle,
			end_angle
		)

		# Create token placements
		for pos in positions:
			var token_placement = token_placement_scene.instantiate()
			token_placement.accepted_biome = biome
			get_parent().get_node("TokenPlacements").add_child(token_placement, true)
			token_placement.global_position = pos
			placements_per_biome[biome] += 1

	# Set the first 28 token placements as energy placements
	# We need to determine how many per biome (e.g., 7 per biome for 4 biomes)
	var energy_count = 0
	var energy_per_biome = 7  # 7 per biome x 4 biomes = 28 total

	# Iterate through all placements
	for placement in get_parent().get_node("TokenPlacements").get_children():
		# Check if we've already marked enough energy placements for this biome
		var biome_energy_count = 0
		for check_placement in get_parent().get_node("TokenPlacements").get_children():
			if check_placement.accepted_biome == placement.accepted_biome and check_placement.is_energy:
				biome_energy_count += 1

		# If we haven't reached the limit for this biome and total energy count is under 28
		if biome_energy_count < energy_per_biome and energy_count < 28:
			placement.set_energy_placement(true)
			energy_count += 1
		else:
			placement.set_energy_placement(false)

#func setup_biome_borders():
	#var material = StandardMaterial3D.new()
	#material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
#
	## Create octagonal border for each biome region
	#for biome in biome_assignments.keys():
		#var slice_indices = biome_assignments[biome]
#
		#for slice_idx in slice_indices:
			#var start_angle = slice_idx * PI / 4
			#var points = []
#
			## Create border mesh
			#var surface_tool = SurfaceTool.new()
			#surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
#
			## Center point
			#var center = Vector3.ZERO
#
			## Add vertices for arc
			#var segments = 8
			#var angle_step = PI / (4 * segments)
#
			## Create triangles
			#for i in range(segments):
				#var angle1 = start_angle + i * angle_step
				#var angle2 = start_angle + (i + 1) * angle_step
#
				#var v1 = Vector3(radius * cos(angle1), 0, radius * sin(angle1))
				#var v2 = Vector3(radius * cos(angle2), 0, radius * sin(angle2))
#
				## Add triangle (center, v1, v2)
				#surface_tool.add_vertex(center)
				#surface_tool.add_vertex(v1)
				#surface_tool.add_vertex(v2)
#
			#var mesh_instance = MeshInstance3D.new()
			#mesh_instance.mesh = surface_tool.commit()
#
			## Use a neutral color instead of biome color
			#var color = Color(0.7, 0.7, 0.7)  # Light gray
			#color.a = 0.2
			#var region_material = material.duplicate()
			#region_material.albedo_color = color
			#mesh_instance.material_override = region_material
#
			## Add to the borders node
			#borders_node.add_child(mesh_instance)

# --- Add clickable areas to biomes ---
#func setup_biome_borders():
	#var click_areas_node = Node3D.new()
	#click_areas_node.name = "BiomeClickAreas"
	#add_child(click_areas_node)
#
	#for biome_type in biome_assignments:
		#var slice_indices = biome_assignments[biome_type]
		#var biome_area = StaticBody3D.new()
		#var biome_name = "BiomeArea_%s" % BiomeType.keys()[biome_type]
		#biome_area.name = biome_name
		#click_areas_node.add_child(biome_area)
		#
		## Store reference for easy lookup
		#_biome_click_areas[biome_name] = biome_type
#
		#var collision_shape = CollisionShape3D.new()
		#biome_area.add_child(collision_shape)
#
		#var shape = ConcavePolygonShape3D.new()
		#var faces = PackedVector3Array()
#
		## Create a wedge shape for the two slices of the biome
		#var start_angle = slice_indices[0] * PI / 4
		#var end_angle = (slice_indices[1] + 1) * PI / 4
		#var segments = 16 # More segments for a smoother shape
#
		#var angle_step = (end_angle - start_angle) / segments
		#
		## Bottom face
		#for i in range(segments):
			#var angle1 = start_angle + i * angle_step
			#var angle2 = start_angle + (i + 1) * angle_step
			#var v1 = Vector3(radius * cos(angle1), 0, radius * sin(angle1))
			#var v2 = Vector3(radius * cos(angle2), 0, radius * sin(angle2))
			#faces.append(Vector3.ZERO)
			#faces.append(v2)
			#faces.append(v1)
#
		#shape.set_faces(faces)
		#collision_shape.shape = shape
# --- MODIFICATION END ---

func setup_token_ui():
	var token_button = get_parent().get_node("RightUI/TokenButton")
	# Clear any existing connections
	if token_button.pressed.is_connected(_on_token_selected):
		token_button.pressed.disconnect(_on_token_selected)

	# Connect the token selection function
	token_button.pressed.connect(_on_token_selected)

	# Initialize the UI state
	update_token_ui()

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Token Management
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
func apply_player_material(token: Node, player_id: int):
	# Ensure the token has the correct owner_id
	if token.owner_id != player_id:
		token.owner_id = player_id

	# Call the token's update_material method if it has one
	if token.has_method("update_material"):
		token.update_material()
	else:
		print("Warning: Token does not have update_material method")

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Placement & Selection
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
func unhighlight_outerglow():
	# First handle the local call
	_unhighlight_outerglow_local()

	# If server, propagate to all clients
	if multiplayer.is_server():
		rpc("_unhighlight_outerglow_local")
	else:
		# If client, request server to propagate
		rpc_id(1, "request_unhighlight_outerglow")

@rpc("any_peer", "call_local")
func _unhighlight_outerglow_local():
	for token in tokens.get_children():
		token.outerglow.hide()

@rpc("any_peer")
func request_unhighlight_outerglow():
	if !multiplayer.is_server():
		return

	var player_id = multiplayer.get_remote_sender_id()
	# Validate it's the player's turn or any other validation logic
	if !game_state_manager.is_valid_player_turn(player_id):
		return

	# Propagate to all clients
	rpc("_unhighlight_outerglow_local")

@rpc("any_peer", "call_local")
func sync_single_token_placement(token_data: Dictionary):
	print("Syncing single token at position ", token_data.position)

	# Only create a new token if it doesn't already exist at this position
	var existing_token = find_token_at_position(token_data.position)
	if existing_token:
		# Token already exists, just update its properties
		existing_token.biome_type = token_data.biome
		existing_token.owner_id = token_data.owner
		existing_token.is_energy = token_data.is_energy
		existing_token.is_blighted = token_data.is_blighted

		# Apply material based on owner
		apply_player_material(existing_token, token_data.owner)
		return

	# No existing token, create a new one
	var token = token_scene.instantiate()
	get_parent().get_node("Tokens").add_child(token, true)

	# Set token data
	token.set_token_data(token_data.biome, token_data.owner, token_data.is_energy)
	token.is_blighted = token_data.is_blighted
	token.global_position = token_data.position

	# Apply material based on owner
	apply_player_material(token, token_data.owner)

	# Connect to placement
	var placement = get_token_placement_at_position(token_data.position)
	if placement:
		placement.set_occupied(true)
		placement.current_token = token
		token.token_placement = placement

	# Update UI
	update_token_ui()

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Token Placement Generation
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _generate_slice_positions(radius: float, start_angle: float, end_angle: float) -> Array:
	var positions = []
	var hex_size = 1.0  # Increased spacing between tokens

	# Calculate the center point of this biome section (middle of two slices)
	var center_angle = (start_angle + end_angle) / 2
	var center_radius = radius * 0.5
	var section_center = Vector3(
		cos(center_angle) * center_radius,
		0,
		sin(center_angle) * center_radius
	)

	# Define the hexagonal grid
	var grid_positions = []
	var rows = 4  # Number of rows in the grid
	var max_cols = 4  # Maximum columns in the widest row

	for row in range(rows):
		var cols = max_cols - abs(row - (rows/2))  # Fewer columns at top and bottom
		var row_offset = (row - (rows/2)) * hex_size * 0.866  # Vertical spacing
		var col_offset = -(cols * hex_size * 0.5)  # Center the row

		for col in range(cols):
			var x = col_offset + (col * hex_size)
			var z = row_offset

			# Rotate position to align with biome angle
			var rotated_pos = Vector3(
				x * cos(center_angle) - z * sin(center_angle),
				0,
				x * sin(center_angle) + z * cos(center_angle)
			)

			grid_positions.append(section_center + rotated_pos)

	# Filter positions to ensure they're within the biome's slices
	for pos in grid_positions:
		var pos_angle = atan2(pos.z, pos.x)
		if pos_angle < 0:
			pos_angle += PI * 2

		# Check if position is within slice angles and radius
		if pos_angle >= start_angle and pos_angle <= end_angle and pos.length() <= radius * 0.75:
			# Check minimum distance from other positions
			var too_close = false
			for existing_pos in positions:
				if pos.distance_to(existing_pos) < hex_size * 0.8:
					too_close = true
					break

			if not too_close:
				# Add small random offset for natural look
				var random_offset = Vector3(
					randf_range(-0.05, 0.05),
					0,
					randf_range(-0.05, 0.05)
				)
				positions.append(pos + random_offset)

	# Ensure exactly 12 positions
	positions.sort_custom(func(a, b): return a.length() < b.length())
	return positions.slice(0, min(positions.size(), MAX_TOKENS_PER_BIOME))


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# UI Management
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func update_token_indicators():
	var player_token_indicators = get_parent().get_node("RightUI/PlayerTokenIndicators")
	var players = get_parent().players

	for player_id in players:
		var indicator_name = "Player_" + str(player_id)
		if player_token_indicators.has_node(indicator_name):
			var indicator = player_token_indicators.get_node(indicator_name)
			var label = indicator.get_node("TokenCount")

			# Get token count for this player
			var token_count = get_player_tokens(player_id).size()
			label.text = str(token_count)

			# Maybe fade out if they have no tokens
			indicator.modulate.a = 1.0 if token_count > 0 else 0.5

func setup_player_token_indicators():
	var player_token_indicators = get_parent().get_node("RightUI/PlayerTokenIndicators")
	var players = get_parent().players
	var player_colors = get_parent().player_colors

	# Clear existing indicators
	for child in player_token_indicators.get_children():
		child.queue_free()

	# Create an indicator for each player
	for player_id in players:
		var indicator = ColorRect.new()
		indicator.name = "Player_" + str(player_id)
		indicator.size = Vector2(30, 30)  # Small square

		# Set player color
		if player_colors.has(player_id):
			indicator.color = player_colors[player_id]
		else:
			indicator.color = Color(0.5, 0.5, 0.5)

		# Create count label
		var label = Label.new()
		label.name = "TokenCount"
		label.text = "0"  # Will be updated later
		indicator.add_child(label)

		# Position the label
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.size = indicator.size

		# Add to container
		player_token_indicators.add_child(indicator)

	# Call initial update
	update_token_indicators()

@rpc("any_peer", "call_local")
func update_token_ui_remote():
	update_token_ui()

@rpc("any_peer", "call_local")
func sync_token_planting_state(player_id: int, tokens_planted: int, can_place_sigil: bool, can_place_biome: bool, max_tokens: int):
	# Only update for the current player
	if player_id == multiplayer.get_unique_id():
		tokens_planted_this_turn[player_id] = tokens_planted
		can_plant_on_sigil = can_place_sigil
		can_plant_on_biome = can_place_biome
		max_tokens_per_turn = max_tokens

		# Update UI immediately
		update_token_ui()

		print("Synced token planting state: tokens_planted=", tokens_planted,
			  ", can_plant_on_sigil=", can_place_sigil,
			  ", can_plant_on_biome=", can_place_biome,
			  ", max_tokens_per_turn=", max_tokens)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Network Synchronization
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

@rpc("any_peer", "call_local")
func sync_existing_tokens(tokens_data: Array):
	print("")
	print("Syncing existing tokens: ", tokens_data)

	# Clear existing tokens first
	for token in get_parent().get_node("Tokens").get_children():
		token.queue_free()

	# Recreate tokens from data
	for token_info in tokens_data:
		var token = token_scene.instantiate()
		get_parent().get_node("Tokens").add_child(token,true)
		print("token info biome: ", token_info)
		token.set_token_data(token_info.biome, token_info.type)
		token.global_position = token_info.position

		var placement = get_token_placement_at_position(token_info.position)
		if placement:
			placement.set_occupied(true)

func force_resync_token_colors():
	if !multiplayer.is_server():
		return

	print("Forcing resync of all token colors")

	# Collect data for all tokens
	var token_data = []
	for token in get_parent().get_node("Tokens").get_children():
		# Get the player's color index
		var color_index = -1
		for i in range(get_parent().players.size()):
			if get_parent().players[i] == token.owner_id:
				color_index = i
				break

		token_data.append({
			"position": token.global_position,
			"biome": token.biome_type,
			"owner": token.owner_id,
			"is_energy": token.is_energy,
			"is_blighted": token.is_blighted,
			"player_color_index": color_index  # Add the color index
		})

	# Send update to all clients
	rpc("sync_token_colors", token_data)

@rpc("any_peer", "call_local")
func sync_token_colors(token_data: Array):
	print("Syncing token colors for ", token_data.size(), " tokens")

	# Update all tokens with proper colors
	for token_info in token_data:
		var token = find_token_at_position(token_info.position)
		if token:
			# Ensure owner_id is set correctly
			token.owner_id = token_info.owner

			# If we have a color index, use that directly
			if token_info.has("player_color_index") and token_info.player_color_index >= 0:
				token.player_color_index = token_info.player_color_index

				# Apply color based on the index
				var mesh = token.get_node("TokenMesh")
				if mesh:
					match token_info.player_color_index:
						0:
							mesh.material_override = token_mat_player_1
							print("Applied player 1 material to token")
						1:
							mesh.material_override = token_mat_player_2
							print("Applied player 2 material to token")
						2:
							mesh.material_override = token_mat_player_3
							print("Applied player 3 material to token")
						3:
							mesh.material_override = token_mat_player_4
							print("Applied player 4 material to token")
						_:
							print("Invalid player color index: ", token_info.player_color_index)
			else:
				# Fallback to using update_material
				if token.has_method("update_material"):
					token.update_material()

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Helper Functions
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Finds the closest valid (highlighted, unoccupied) placement to a given point within a specific biome.
func _find_closest_available_placement(from_position: Vector3, target_biome: int) -> Node3D:
	var closest_placement: Node3D = null
	var min_distance_sq = INF

	for placement in get_parent().get_node("TokenPlacements").get_children():
		# A placement is valid if it's in the target biome AND currently highlighted by the sigil logic
		if placement.accepted_biome == target_biome and placement.is_highlighted:
			var dist_sq = from_position.distance_squared_to(placement.global_position)
			if dist_sq < min_distance_sq:
				min_distance_sq = dist_sq
				closest_placement = placement
				
	return closest_placement

func get_token_placement_at_position(pos: Vector3) -> Node:
	for placement in get_parent().get_node("TokenPlacements").get_children():
		if placement.global_position.distance_to(pos) < 0.1:
			return placement
	return null

func find_token_at_position(position: Vector3) -> Node:
	for token in get_parent().get_node("Tokens").get_children():
		if token.global_position.distance_to(position) < 0.1:
			return token
	return null

func unhighlight_all_token_placements():
	for placement in get_parent().get_node("TokenPlacements").get_children():
		placement.set_highlight(false)

func update_token_ui():
	var token_button = get_parent().get_node("RightUI/TokenButton")
	if !token_button:
		return

	var player_id = multiplayer.get_unique_id()
	var players = game.players
	var game_started = game.game_started
	var is_my_turn = false
	if game_started and players.size() > 0 and game_state_manager.current_turn_index < players.size():
		is_my_turn = (player_id == players[game_state_manager.current_turn_index])

	# Get the token count for the local player
	var token_count = 0
	if player_tokens.has(player_id):
		token_count = player_tokens[player_id].size()

	# Update the button text with the local player's token count
	token_button.text = "Tokens: " + str(token_count)

	var max_tokens_reached = tokens_planted_this_turn.get(player_id, 0) >= max_tokens_per_turn

	token_button.visible = true
	token_button.disabled = !is_my_turn or token_count <= 0 or max_tokens_reached

	if card_manager.is_plant_extra:
		token_button.disabled = false

	if is_token_selected:
		token_button.modulate = Color(1.2, 1.2, 0.8, 1)
	else:
		token_button.modulate = Color(1, 1, 1, 1)


func save_player_token_count(player_id: int):
	var tokens = get_player_tokens(player_id)
	player_token_counts[player_id] = tokens.size()
	print("Saved token count for player ", player_id, ": ", tokens.size())

@rpc("authority", "reliable")
func notify_invalid_placement():
	print("Invalid placement!")
	selected_token_index = -1
	unhighlight_all_token_placements()
	var tokens = get_player_tokens(multiplayer.get_unique_id())
	update_token_ui()

func _on_token_placed(token: Node3D, placement_location: Node3D):
	if multiplayer.is_server():
		# Mark the placement location as occupied
		placement_location.set_occupied(true)

		# Broadcast the token placement to all clients
		get_parent().rpc("sync_token_placement", token.biome_type, token.token_type, placement_location.global_position)
	else:
		# Client requests server to validate placement
		get_parent().rpc_id(1, "request_token_placement", token.biome_type, token.token_type, placement_location.global_position)

	# Unhighlight all placement locations
	unhighlight_all_token_placements()
	selected_token_index = -1  # Reset selected token

func update_all_players_tokens():
	if !multiplayer.is_server():
		return

	var players = get_parent().players
	for pid in players:
		var updated_tokens = get_player_tokens(pid)
		if pid == multiplayer.get_unique_id():
			# Update server's UI directly
			update_token_ui()
		else:
			# Update clients
			rpc_id(pid, "sync_player_tokens", updated_tokens)

@rpc("any_peer")
func request_token_refresh():
	if multiplayer.is_server():
		var requesting_player = multiplayer.get_remote_sender_id()

		# Don't force reset, just ensure the player has an entry
		if !player_tokens.has(requesting_player):
			initialize_player_tokens(requesting_player, false)

		var tokens = get_player_tokens(requesting_player)
		rpc_id(requesting_player, "sync_player_tokens", tokens)

@rpc("any_peer")
func request_token_movement(from_position: Vector3, to_position: Vector3):
	if !multiplayer.is_server():
		return

	var player_id = multiplayer.get_remote_sender_id()
	if player_id == 0: # If the sender is 0, it's a local call from the server.
		player_id = multiplayer.get_unique_id() # Use the server's own ID.

	# Find the token
	var token = find_token_at_position(from_position)
	if !token:
		return

	# Find the placements
	var from_placement = get_token_placement_at_position(from_position)
	var to_placement = get_token_placement_at_position(to_position)

	if !from_placement or !to_placement or to_placement.is_occupied:
		return

	# Update placements
	from_placement.set_occupied(false)
	from_placement.current_token = null

	token.biome_type = to_placement.accepted_biome
	to_placement.set_occupied(true)
	to_placement.current_token = token

	# Move the token
	token.global_position = to_placement.global_position

	# Sync to all clients
	rpc("sync_token_movement", from_position, to_position)

# NEW RPC to handle the repositioning of a token during the blight cycle.
@rpc("any_peer", "call_local")
func sync_token_reposition(original_pos: Vector3, new_pos: Vector3, new_biome: int):
	var token = find_token_at_position(original_pos)
	if not is_instance_valid(token):
		printerr("Blight cycle sync failed: Token not found at original position.")
		return

	var old_placement = get_token_placement_at_position(original_pos)
	var new_placement = get_token_placement_at_position(new_pos)

	if not is_instance_valid(new_placement):
		printerr("Blight cycle sync failed: New placement location not found.")
		return

	# Update the old and new placement states
	if is_instance_valid(old_placement):
		old_placement.is_occupied = false
		old_placement.current_token = null

	new_placement.is_occupied = true
	new_placement.current_token = token

	# Update the token's properties
	token.global_position = new_pos
	token.biome_type = new_biome
	token.token_placement = new_placement


## ELEMENTALS 
func server_remove_token_at_pos(position: Vector3):
	if not multiplayer.is_server():
		return

	var token = find_token_at_position(position)
	if token:
		print("Server removing token at position: " + str(position))
		var player_id = token.owner_id
		var biome_type = token.biome_type

		var placement = get_token_placement_at_position(token.global_position)
		if placement:
			placement.set_occupied(false)
			placement.current_token = null

		if player_id != -1:
			add_token_to_player(player_id, biome_type)

		# The removal itself is synced to clients via an RPC.
		rpc("sync_token_removal_at_position", position, player_id, biome_type)
		
		# The token node is freed on the server. The RPC will handle freeing it on clients.
		token.queue_free()
	else:
		print("Server could not find token to remove at: " + str(position))

@rpc("any_peer", "call_local")
func hide_placements_by_id(ids_to_hide: Array, biome_type: int):
	# Ensure the biome key exists in the dictionary
	if not hidden_placement_ids.has(biome_type):
		hidden_placement_ids[biome_type] = []

	# Add new IDs and ensure the list is unique
	var id_set = {}
	for id in ids_to_hide:
		id_set[id] = true
	for id in hidden_placement_ids[biome_type]:
		id_set[id] = true
	hidden_placement_ids[biome_type] = id_set.keys()

	var placements_node = get_node_or_null("/root/Game/TokenPlacements")
	if not placements_node: return

	for placement in placements_node.get_children():
		# Only hide if the biome matches and the ID is in the list for that biome
		if placement.accepted_biome == biome_type and placement.place_id in hidden_placement_ids[biome_type]:
			placement.hide()


@rpc("any_peer", "call_local")
func sync_token_removal_at_position(token_position: Vector3, player_id: int, biome_type: int):
	print("Syncing token removal at: " + str(token_position))

	var token = find_token_at_position(token_position)
	if token:
		var placement = get_token_placement_at_position(token.global_position)
		if placement:
			placement.set_occupied(false)
			placement.current_token = null

		token.queue_free()

		# Update the UI only for the affected player.
		if player_id == multiplayer.get_unique_id():
			update_token_ui()
	else:
		print("No token found at position for removal sync: " + str(token_position))

@rpc("any_peer", "call_local")
func set_biome_planting_lock(biome_index: int, is_locked: bool):
	if is_locked:
		locked_planting_biome = biome_index
		print("Token planting is now locked for biome: %d" % biome_index)
	else:
		# This part would be used if you have an effect that unlocks it
		locked_planting_biome = -1 
		print("Token planting lock removed.")
