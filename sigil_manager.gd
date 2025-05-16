# sigil_manager.gd
extends Node

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# References to other managers
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
@onready var game = get_parent()
@onready var token_manager = $"../TokenManager"
@onready var network_manager = $"../NetworkManager"
@onready var game_state_manager = $"../GameStateManager" 
@onready var point_counter = $"../PointCounter"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Sigil Pattern Constants
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
enum SigilPattern {SIGIL_A, SIGIL_B, SIGIL_C}
enum BiomeType {FOREST, WATER, MOUNTAIN, DESERT}

# Track sigil interaction state
var selected_energy_token = null
var is_sigil_mode = false
var _current_sigil_token = null
var _current_sigil_is_other_player = false
var is_blight_mode = false

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Initialization
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
func _ready():
	pass

func initialize():
	print("SigilManager initializing...")

	# Create a timer to periodically check for patterns
	var check_timer = Timer.new()
	check_timer.wait_time = 1.0  # Check every second
	check_timer.one_shot = false
	check_timer.autostart = true
	check_timer.timeout.connect(_on_pattern_check_timer)
	add_child(check_timer)

	# Connect to token clicks
	var tokens_node = game.get_node("Tokens")
	tokens_node.child_entered_tree.connect(_connect_to_new_token)
	
	# Connect to existing tokens
	for token in tokens_node.get_children():
		_connect_to_new_token(token)
		
	print("SigilManager initialized.")

# Connect to new tokens added to the scene
func _connect_to_new_token(token):
	if !token.is_connected("token_clicked", _on_token_clicked):
		token.connect("token_clicked", _on_token_clicked)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Sigil Pattern Detection
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
func _on_pattern_check_timer():
	# Check for patterns in the background
	update_all_pattern_highlights()

# Update all token pattern highlights
func update_all_pattern_highlights():
	var tokens = game.get_node("Tokens").get_children()
	var player_id = multiplayer.get_unique_id()
	
	# Only show highlights during player's turn
	if !game_state_manager.is_valid_player_turn(player_id):
		return
	
	for token in tokens:
		if token.is_energy and !token.is_blighted:
			# Check if this token is part of any pattern - including patterns with tokens from ALL players
			var patterns = []
			if check_for_sigil_a_pattern(token):
				patterns.append(SigilPattern.SIGIL_A)
			if check_for_sigil_b_pattern(token):
				patterns.append(SigilPattern.SIGIL_B)
			if check_for_sigil_c_pattern(token):
				patterns.append(SigilPattern.SIGIL_C)
			
			# Only highlight own tokens that can be activated
			if token.owner_id == player_id:
				if patterns.size() > 0:
					token.set_pattern_highlight(true, patterns)
				else:
					token.set_pattern_highlight(false, [])

# Handle token clicks for sigil pattern activation
func _on_token_clicked(token):
	var player_id = multiplayer.get_unique_id()
	
	# Make sure it's the player's turn
	if !game_state_manager.is_valid_player_turn(player_id):
		print("Not your turn!")
		return
	
	# Only allow selecting own energy tokens
	if token.is_energy and token.owner_id == player_id and !token.is_blighted:
		print("Energy token selected")
		
		# Deselect any previously selected token
		if selected_energy_token:
			selected_energy_token.highlight(false)
		
		selected_energy_token = token
		is_sigil_mode = true
		
		# Highlight the token to show it's selected
		token.highlight(true)
		
		# Check for patterns with this token
		check_for_sigil_patterns(token)
	else:
		print("Not a valid energy token for activation")
		
		# Deselect any currently selected energy token
		if selected_energy_token:
			selected_energy_token.highlight(false)
			selected_energy_token = null
			is_sigil_mode = false

# Main pattern check function
func check_for_sigil_patterns(token):
	var patterns_found = []
	
	# Check each pattern type
	if check_for_sigil_a_pattern(token):
		patterns_found.append(SigilPattern.SIGIL_A)
	
	if check_for_sigil_b_pattern(token):
		patterns_found.append(SigilPattern.SIGIL_B)
	
	if check_for_sigil_c_pattern(token):
		patterns_found.append(SigilPattern.SIGIL_C)
	
	# Show pattern options if any found
	if patterns_found.size() > 0:
		show_pattern_activation_ui(token, patterns_found)
	else:
		print("No sigil patterns found for this token")
		# Unhighlight token since no patterns are available
		token.highlight(false)
		selected_energy_token = null
		is_sigil_mode = false

# Get the token ID based on placement index and biome
func get_token_id(token):
	var token_placement = token_manager.get_token_placement_at_position(token.global_position)
	if !token_placement:
		return -1
		
	# Calculate the ID (1-7) based on the token placement's index within its biome
	var placement_index = token_placement.get_index()
	var biome_index = token.biome_type
	var local_index = placement_index - (biome_index * 7)
	
	# The ID is the local index + 1 (since IDs start at 1)
	return local_index + 1

# Pattern detection based on token IDs within a biome
func check_for_sigil_a_pattern(token) -> bool:
	# L pattern detection for exact patterns:
	# 1,2,7 or 2,3,7 or 4,5,7 or 5,6,7
	
	# Get the token ID
	var token_id = get_token_id(token)
	if token_id == -1:
		return false
	
	# Get all tokens in the same biome (from ANY player)
	var all_tokens = get_tokens_in_biome(token.biome_type)
	
	# Convert tokens to IDs
	var token_ids = []
	for t in all_tokens:
		if !t.is_blighted:  # Only consider non-blighted tokens
			var id = get_token_id(t)
			if id != -1:
				token_ids.append(id)
	
	# Check each L pattern
	var patterns = [
		[1, 2, 7],
		[2, 3, 7],
		[4, 5, 7],
		[5, 6, 7]
	]
	
	for pattern in patterns:
		# Check if current token is part of this pattern
		if !pattern.has(token_id):
			continue
			
		# Check if all pattern IDs exist in placed tokens
		var pattern_found = true
		for id in pattern:
			if !token_ids.has(id):
				pattern_found = false
				break
				
		if pattern_found:
			return true
	
	return false

func check_for_sigil_b_pattern(token) -> bool:
	# Straight pattern detection for exact patterns:
	# 1,2,3 or 4,5,6 or 2,7,5
	
	# Get the token ID
	var token_id = get_token_id(token)
	if token_id == -1:
		return false
	
	# Get all tokens in the same biome (from ANY player)
	var all_tokens = get_tokens_in_biome(token.biome_type)
	
	# Convert tokens to IDs
	var token_ids = []
	for t in all_tokens:
		if !t.is_blighted:  # Only consider non-blighted tokens
			var id = get_token_id(t)
			if id != -1:
				token_ids.append(id)
	
	# Check each straight pattern
	var patterns = [
		[1, 2, 3],
		[4, 5, 6],
		[2, 7, 5]
	]
	
	for pattern in patterns:
		# Check if current token is part of this pattern
		if !pattern.has(token_id):
			continue
			
		# Check if all pattern IDs exist in placed tokens
		var pattern_found = true
		for id in pattern:
			if !token_ids.has(id):
				pattern_found = false
				break
				
		if pattern_found:
			return true
	
	return false

func check_for_sigil_c_pattern(token) -> bool:
	# Diagonal pattern detection for exact patterns:
	# 1,7,6 or 4,7,3
	
	# Get the token ID
	var token_id = get_token_id(token)
	if token_id == -1:
		return false
	
	# Get all tokens in the same biome (from ANY player)
	var all_tokens = get_tokens_in_biome(token.biome_type)
	
	# Convert tokens to IDs
	var token_ids = []
	for t in all_tokens:
		if !t.is_blighted:  # Only consider non-blighted tokens
			var id = get_token_id(t)
			if id != -1:
				token_ids.append(id)
	
	# Check each diagonal pattern
	var patterns = [
		[1, 7, 6],
		[4, 7, 3]
	]
	
	for pattern in patterns:
		# Check if current token is part of this pattern
		if !pattern.has(token_id):
			continue
			
		# Check if all pattern IDs exist in placed tokens
		var pattern_found = true
		for id in pattern:
			if !token_ids.has(id):
				pattern_found = false
				break
				
		if pattern_found:
			return true
	
	return false

# Helper functions for pattern detection
func get_tokens_in_biome(biome_type: int) -> Array:
	var result = []
	var tokens = game.get_node("Tokens").get_children()
	
	for token in tokens:
		if token.biome_type == biome_type and token.is_energy:
			result.append(token)
	
	return result

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Sigil Pattern Activation
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
func show_pattern_activation_ui(token, patterns):
	# Create popup menu for pattern selection
	var popup = PopupMenu.new()
	popup.name = "PatternSelectionPopup"
	game.add_child(popup)
	
	# Add pattern options
	for pattern in patterns:
		var pattern_name = ""
		match pattern:
			SigilPattern.SIGIL_A: pattern_name = "Sigil A (L Pattern): Pull and Push another player token"
			SigilPattern.SIGIL_B: pattern_name = "Sigil B (Straight Pattern): Pull and Push Your token"
			SigilPattern.SIGIL_C: pattern_name = "Sigil C (Diagonal Pattern): Unblight your token or blight another player token"
		
		popup.add_item(pattern_name, pattern)
	
	# Connect signal
	popup.id_pressed.connect(func(id): activate_sigil_pattern(token, id))
	
	# Show popup at mouse position
	var mouse_pos = get_viewport().get_mouse_position()
	popup.position = mouse_pos
	popup.popup()

# Pattern activation logic
func activate_sigil_pattern(token, pattern_id):
	print("Activating pattern: ", pattern_id)
	
	# Check if we have mana to spend
	var mana_available = check_mana_available(token.biome_type)
	if !mana_available:
		print("Not enough mana available!")
		# Show error message to player
		var dialog = AcceptDialog.new()
		dialog.title = "No Mana Available"
		dialog.dialog_text = "You need mana to activate this sigil pattern."
		game.add_child(dialog)
		dialog.popup_centered()
		return
	
	# Consume mana
	consume_mana(token.biome_type)
	
	# Determine pattern effect based on ID
	match pattern_id:
		SigilPattern.SIGIL_A:
			show_pull_push_ui(token, true)  # true = another player's token
		SigilPattern.SIGIL_B:
			show_pull_push_ui(token, false)  # false = own token
		SigilPattern.SIGIL_C:
			show_blight_unblight_ui(token)
	
	# After activation, determine if points go to player or biome
	# Based on the round number (rounds 1-5 to player, 6-8 to biome)
	var current_round = get_current_round()
	
	if current_round >= 1 and current_round <= 5:
		# Points to player
		add_point_to_player(token.owner_id)
	else:
		# Points to biome
		add_point_to_biome(token.biome_type)

# Check if mana is available for this biome
func check_mana_available(biome_type: int) -> bool:
	# Get mana for this biome from point counter
	var mana = 0
	
	match biome_type:
		BiomeType.FOREST: mana = point_counter.forest_magic_points
		BiomeType.WATER: mana = point_counter.water_magic_points
		BiomeType.MOUNTAIN: mana = point_counter.mountain_magic_points
		BiomeType.DESERT: mana = point_counter.desert_magic_points
	
	return mana > 0

# Consume mana for a sigil activation
func consume_mana(biome_type: int):
	# Determine which mana to consume
	var mana_biome = ""
	
	match biome_type:
		BiomeType.FOREST: mana_biome = "forest_magic"
		BiomeType.WATER: mana_biome = "water_magic"
		BiomeType.MOUNTAIN: mana_biome = "mountain_magic"
		BiomeType.DESERT: mana_biome = "desert_magic"
	
	# Use the point adjustment function to reduce mana by 1
	game.request_point_adjustment(mana_biome, -1)

# Add point to player from sigil activation (rounds 1-5)
func add_point_to_player(player_id: int):
	# In your game this would update the player's score
	print("Adding point to player: ", player_id)
	
	# You'll need to implement player scoring
	# For now we'll show a notification
	var dialog = AcceptDialog.new()
	dialog.title = "Point Earned"
	dialog.dialog_text = "You earned 1 point from activating a sigil pattern!"
	game.add_child(dialog)
	dialog.popup_centered()

# Add point to biome from sigil activation (rounds 6-8)
func add_point_to_biome(biome_type: int):
	# Determine which biome to add points to
	var biome = ""
	
	match biome_type:
		BiomeType.FOREST: biome = "forest"
		BiomeType.WATER: biome = "water"
		BiomeType.MOUNTAIN: biome = "mountain"
		BiomeType.DESERT: biome = "desert"
	
	# Use the point adjustment function to add a point
	game.request_point_adjustment(biome, 1)

# Get current round
func get_current_round() -> int:
	# You need to implement round tracking in your game
	# For now, assume it's round 1-5 (points to player)
	return 1  # Default to round 1

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Sigil Effect Implementation
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# UI for Sigil A and B effect (push/pull tokens)
func show_pull_push_ui(token, is_other_player: bool):
	# Create UI to select which token to push/pull
	var dialog = AcceptDialog.new()
	dialog.title = "Select Token to Push/Pull"
	dialog.dialog_text = "Click on a token to push or pull."
	game.add_child(dialog)
	dialog.popup_centered()
	
	# Set game to token selection mode for push/pull
	token_manager.is_token_selected = false  # Turn off normal token placement mode
	is_sigil_mode = true
	
	# Store information about which sigil is being used
	_current_sigil_token = token
	_current_sigil_is_other_player = is_other_player
	
	# Connect to viewport for token detection
	if !get_viewport().is_connected("gui_input", _on_push_pull_input):
		get_viewport().connect("gui_input", _on_push_pull_input)

# UI for Sigil C effect (blight/unblight)
func show_blight_unblight_ui(token):
	# Create UI to select which token to blight/unblight
	var dialog = AcceptDialog.new()
	dialog.title = "Select Token to Blight/Unblight"
	dialog.dialog_text = "Click on a token to blight an opponent's token or unblight your own."
	game.add_child(dialog)
	dialog.popup_centered()
	
	# Set game to token selection mode for blight/unblight
	token_manager.is_token_selected = false  # Turn off normal token placement mode
	is_blight_mode = true
	
	# Store information about which sigil is being used
	_current_sigil_token = token
	
	# Connect to viewport for token detection
	if !get_viewport().is_connected("gui_input", _on_blight_unblight_input):
		get_viewport().connect("gui_input", _on_blight_unblight_input)

# Handle push/pull input
func _on_push_pull_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Find token at this position
		var from = game.get_node("Camera3D").project_ray_origin(event.position)
		var to = from + game.get_node("Camera3D").project_ray_normal(event.position) * 1000
		
		var space_state = get_tree().get_root().get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.create(from, to)
		var result = space_state.intersect_ray(query)
		
		if result:
			var hit_position = result.position
			var target_token = token_manager.find_token_at_position(hit_position)
			
			if target_token:
				# Check if this is a valid target
				var valid = false
				
				if _current_sigil_is_other_player:
					# Sigil A - Can only target other player's tokens
					valid = target_token.owner_id != multiplayer.get_unique_id()
				else:
					# Sigil B - Can only target own tokens
					valid = target_token.owner_id == multiplayer.get_unique_id()
				
				if valid:
					# Perform push/pull
					show_push_pull_direction_ui(target_token)
				else:
					print("Invalid target for this sigil pattern")
		
		# Clean up
		get_viewport().disconnect("gui_input", _on_push_pull_input)
		is_sigil_mode = false
		_current_sigil_token = null

# Handle blight/unblight input
func _on_blight_unblight_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Find token at this position
		var from = game.get_node("Camera3D").project_ray_origin(event.position)
		var to = from + game.get_node("Camera3D").project_ray_normal(event.position) * 1000
		
		var space_state = get_tree().get_root().get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.create(from, to)
		var result = space_state.intersect_ray(query)
		
		if result:
			var hit_position = result.position
			var target_token = token_manager.find_token_at_position(hit_position)
			
			if target_token:
				var player_id = multiplayer.get_unique_id()
				
				if target_token.owner_id == player_id:
					# Unblight own token
					if target_token.is_blighted:
						if multiplayer.is_server():
							target_token.is_blighted = false
							target_token.update_token_display()
							token_manager.rpc("sync_token_blight", target_token.global_position, false)
						else:
							token_manager.rpc_id(1, "request_token_blight", target_token.global_position)
					else:
						print("Token is not blighted")
				else:
					# Blight other player's token
					if !target_token.is_blighted:
						if multiplayer.is_server():
							target_token.is_blighted = true
							target_token.update_token_display()
							token_manager.rpc("sync_token_blight", target_token.global_position, true)
						else:
							token_manager.rpc_id(1, "request_token_blight", target_token.global_position)
					else:
						print("Token is already blighted")
		
		# Clean up
		get_viewport().disconnect("gui_input", _on_blight_unblight_input)
		is_blight_mode = false
		_current_sigil_token = null

# Show UI for push/pull direction selection
func show_push_pull_direction_ui(target_token):
	var popup = PopupMenu.new()
	popup.name = "DirectionSelectionPopup"
	game.add_child(popup)
	
	# Add direction options
	popup.add_item("Push Away", 0)
	popup.add_item("Pull Closer", 1)
	
	# Connect signal
	popup.id_pressed.connect(func(id): perform_push_pull(target_token, id == 0))
	
	# Show popup at mouse position
	var mouse_pos = get_viewport().get_mouse_position()
	popup.position = mouse_pos
	popup.popup()

# Perform the actual push or pull
func perform_push_pull(token, is_push: bool):
	var token_placement = token_manager.get_token_placement_at_position(token.global_position)
	if !token_placement:
		print("Could not find token placement location")
		return
	
	var current_index = token_placement.get_index()
	var new_index = -1
	
	# Calculate direction based on current sigil token and target token
	var sigil_placement = token_manager.get_token_placement_at_position(_current_sigil_token.global_position)
	if !sigil_placement:
		print("Could not find sigil token placement location")
		return
	
	var sigil_index = sigil_placement.get_index()
	
	# Calculate direction vector
	var dir_x = current_index % 7 - sigil_index % 7
	var dir_y = current_index / 7 - sigil_index / 7
	
	# Normalize direction
	if dir_x != 0:
		dir_x = dir_x / abs(dir_x)
	if dir_y != 0:
		dir_y = dir_y / abs(dir_y)
	
	# Calculate new position
	if is_push:
		# Push one step away
		new_index = current_index + dir_x + dir_y * 7
	else:
		# Pull one step closer
		new_index = current_index - dir_x - dir_y * 7
	
	# Validate new position
	var placements = game.get_node("TokenPlacements")
	if new_index < 0 or new_index >= placements.get_child_count():
		print("Invalid new position")
		return
	
	var new_placement = placements.get_child(new_index)
	if new_placement.is_occupied:
		print("New position is already occupied")
		return
	
	# Move the token
	if multiplayer.is_server():
		# Clear the current placement
		token_placement.set_occupied(false)
		token_placement.current_token = null
		
		# Set the new placement
		new_placement.set_occupied(true)
		new_placement.current_token = token
		
		# Move the token
		token.global_position = new_placement.global_position
		
		# Sync to clients
		token_manager.rpc("sync_token_movement", token.global_position, new_placement.global_position)
	else:
		# Request server to move the token
		token_manager.rpc_id(1, "request_token_movement", token.global_position, new_placement.global_position)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Network Integration
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# These functions should be added to token_manager.gd if not already there

# Request token movement (for RPC)
func request_token_movement(from_position: Vector3, to_position: Vector3):
	token_manager.request_token_movement(from_position, to_position)

# Handle input from player for sigil interactions
func handle_sigil_input(position: Vector2):
	var camera = game.get_node("Camera3D")
	if !camera:
		return
		
	var from = camera.project_ray_origin(position)
	var to = from + camera.project_ray_normal(position) * 1000
	
	var space_state = get_tree().get_root().get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	var result = space_state.intersect_ray(query)
	
	if result:
		var hit_position = result.position
		var found_token = token_manager.find_token_at_position(hit_position)
		
		if found_token:
			_on_token_clicked(found_token)
			return true  # Token was handled
			
	return false  # No token was handled
