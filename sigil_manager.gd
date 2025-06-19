# sigil_manager.gd
extends Node

#SIGNAL
signal signal_other_player_token

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
var _selected_token = null
var _selected_token_is_other_player = false
var is_blight_mode = false

var is_sigil_c := false

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
	#check_timer.timeout.connect(_on_pattern_check_timer)
	add_child(check_timer)

	# Connect to token clicks
	var tokens_node = game.get_node("Tokens")
	tokens_node.child_entered_tree.connect(_connect_to_new_token)
	
	# Connect to existing tokens
	for token in tokens_node.get_children():
		_connect_to_new_token(token)
	
	# Connect sigil buttons
	connect_sigil_buttons()
	disable_all_sigil_buttons()
	#connect_pull_or_push_buttons()
	print("SigilManager initialized.")

# Handle input from player for sigil interactions
func handle_sigil_input(position: Vector2):
	print("handle sigil input")
	var camera = game.get_node("Camera3D")
	if !camera:
		return false
		
	var from = camera.project_ray_origin(position)
	var to = from + camera.project_ray_normal(position) * 1000
	
	var space_state = get_tree().get_root().get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	var result = space_state.intersect_ray(query)
	
	if !is_sigil_mode and !token_manager.is_take_off_mode and !token_manager.is_unblight_mode and !token_manager.is_refresh_energy_mode:
		if result :
			print("")
			print("sigil manager")
			#print("result : ", result)
			
			var found_token = result.collider.get_parent().get_parent()
			print("found token : ", found_token)
			
			if found_token and found_token.is_energy:
				_on_token_clicked(found_token)
				return true  # Token was handled
			
	return false  # No token was handled

# Connect to new tokens added to the scene
func _connect_to_new_token(token):
	if !token.is_connected("token_clicked", _on_token_clicked):
		token.connect("token_clicked", _on_token_clicked)

func connect_sigil_buttons():
	var sigil_a_button = game.get_node("LeftUI/SigilContainer/SigilAButton")
	var sigil_b_button = game.get_node("LeftUI/SigilContainer/SigilBButton")
	var sigil_c_button = game.get_node("LeftUI/SigilContainer/SigilCButton")
	
	# Connect new signals
	sigil_a_button.pressed.connect(_on_sigil_a_pressed)
	sigil_b_button.pressed.connect(_on_sigil_b_pressed)
	sigil_c_button.pressed.connect(_on_sigil_c_pressed)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Sigil Button
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
func _on_sigil_a_pressed():
	print("")
	print("sigil a pressed")
	if selected_energy_token.owner_id == multiplayer.get_unique_id():
		is_sigil_mode = true
	#print("selected energy token : ", selected_energy_token)
	# Check if we have a selected token
	if selected_energy_token:
		# Verify it's an energy token, not blighted, and owned by the current player
		if selected_energy_token.is_energy and !selected_energy_token.is_blighted and selected_energy_token.owner_id == multiplayer.get_unique_id():
			# Check if this token can form a Sigil A pattern
			if check_for_sigil_a_pattern(selected_energy_token):
				# If valid, activate the sigil
				activate_sigil_pattern(selected_energy_token, SigilPattern.SIGIL_A)
				# Use RPC to sync the blighted state to all clients
				game.rpc("sync_token_blight", selected_energy_token.global_position, true)

func _on_sigil_b_pressed():
	print("")
	print("sigil b pressed")
	if selected_energy_token.owner_id == multiplayer.get_unique_id():
		is_sigil_mode = true
	# Check if we have a selected token
	if selected_energy_token:
		# Verify it's an energy token, not blighted, and owned by the current player
		if selected_energy_token.is_energy and !selected_energy_token.is_blighted and selected_energy_token.owner_id == multiplayer.get_unique_id():
			# Check if this token can form a Sigil B pattern
			if check_for_sigil_b_pattern(selected_energy_token):
				# If valid, activate the sigil
				activate_sigil_pattern(selected_energy_token, SigilPattern.SIGIL_B)
				# Use RPC to sync the blighted state to all clients
				game.rpc("sync_token_blight", selected_energy_token.global_position, true)

func _on_sigil_c_pressed():
	print("")
	print("sigil c pressed")
	is_sigil_c = true
	if selected_energy_token.owner_id == multiplayer.get_unique_id():
		is_sigil_mode = true
	# Check if we have a selected token
	if selected_energy_token:
		# Verify it's an energy token, not blighted, and owned by the current player
		if selected_energy_token.is_energy and !selected_energy_token.is_blighted and selected_energy_token.owner_id == multiplayer.get_unique_id():
			# Check if this token can form a Sigil C pattern
			if check_for_sigil_c_pattern(selected_energy_token):
				# If valid, activate the sigil
				activate_sigil_pattern(selected_energy_token, SigilPattern.SIGIL_C)
				# Use RPC to sync the blighted state to all clients
				game.rpc("sync_token_blight", selected_energy_token.global_position, true)



func update_sigil_button_states(token):
	var sigil_a_button = game.get_node("LeftUI/SigilContainer/SigilAButton")
	var sigil_b_button = game.get_node("LeftUI/SigilContainer/SigilBButton")
	var sigil_c_button = game.get_node("LeftUI/SigilContainer/SigilCButton")
	
	# Debug log the token info
	#print("Checking patterns for token - Biome: ", token.biome_type, 
		  #", ID: ", get_token_id(token), 
		  #", Is Energy: ", token.is_energy, 
		  #", Owner: ", token.owner_id)
	
	# Check which patterns this token can form
	var can_form_a = check_for_sigil_a_pattern(token)
	var can_form_b = check_for_sigil_b_pattern(token)
	var can_form_c = check_for_sigil_c_pattern(token)
	
	# Debug log pattern check results
	#print("Pattern detection results - A: ", can_form_a, ", B: ", can_form_b, ", C: ", can_form_c)
	
	# Also check if there's enough mana
	var has_mana = check_mana_available(token.biome_type)
	#print("Has mana: ", has_mana)
	if !has_mana:
		return
	
	# Enable or disable buttons based on pattern availability and mana
	sigil_a_button.disabled = !(can_form_a && has_mana)
	sigil_b_button.disabled = !(can_form_b && has_mana)
	sigil_c_button.disabled = !(can_form_c && has_mana)
	
	# Debug log button states
	#print("Button states - A: ", !sigil_a_button.disabled, ", B: ", !sigil_b_button.disabled, ", C: ", !sigil_c_button.disabled)
	
	# Update button appearance based on state
	sigil_a_button.modulate = Color(1, 1, 1, 1.0 if !sigil_a_button.disabled else 0.5)
	sigil_b_button.modulate = Color(1, 1, 1, 1.0 if !sigil_b_button.disabled else 0.5)
	sigil_c_button.modulate = Color(1, 1, 1, 1.0 if !sigil_c_button.disabled else 0.5)

func disable_all_sigil_buttons():
	var sigil_a_button = game.get_node("LeftUI/SigilContainer/SigilAButton")
	var sigil_b_button = game.get_node("LeftUI/SigilContainer/SigilBButton")
	var sigil_c_button = game.get_node("LeftUI/SigilContainer/SigilCButton")
	
	sigil_a_button.disabled = true
	sigil_b_button.disabled = true
	sigil_c_button.disabled = true
	
	sigil_a_button.modulate = Color(1, 1, 1, 0.5)
	sigil_b_button.modulate = Color(1, 1, 1, 0.5)
	sigil_c_button.modulate = Color(1, 1, 1, 0.5)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Sigil Pattern Detection
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
func _on_pattern_check_timer():
	# Only check if there's a selected energy token
	if selected_energy_token and selected_energy_token.is_energy and !selected_energy_token.is_blighted:
		update_sigil_button_states(selected_energy_token)

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
	if !is_sigil_mode:
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
			
			# Only set sigil mode for the current player
			#if token.owner_id == multiplayer.get_unique_id():
				#is_sigil_mode = true
			
			# Highlight the token to show it's selected
			token.highlight(true)
			
			# Update sigil button states
			update_sigil_button_states(token)
		else:
			print("Not a valid energy token for activation")
			
			# Deselect any currently selected energy token
			if selected_energy_token:
				selected_energy_token.highlight(false)
				selected_energy_token = null
				is_sigil_mode = false
				
				# Disable all sigil buttons
				disable_all_sigil_buttons()

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
		print("WARNING: Token placement not found for token at: ", token.global_position)
		return -1
		
	# Calculate the ID (1-7) based on the token placement's index within its biome
	var placement_index = token_placement.get_index()
	var biome_index = token.biome_type
	var local_index = placement_index - (biome_index * 7)
	
	# The ID is the local index + 1 (since IDs start at 1)
	var token_id = local_index + 1
	#print("Token at position ", token.global_position, " has ID: ", token_id, " (placement index: ", placement_index, ", biome: ", biome_index, ")")
	return token_id

# Pattern detection based on token IDs within a biome
func check_for_sigil_a_pattern(token) -> bool:
	# L pattern detection for exact patterns:
	# 1,2,7 or 2,3,7 or 4,5,7 or 5,6,7
	
	# Get the token ID
	var token_id = get_token_id(token)
	if token_id == -1:
		#print("Sigil A check: Invalid token ID")
		return false
	
	# Get all tokens in the same biome (from ANY player)
	var all_tokens = get_tokens_in_biome(token.biome_type)
	#print("Sigil A check: Found ", all_tokens.size(), " energy tokens in biome ", token.biome_type)
	
	# Convert tokens to IDs
	var token_ids = []
	for t in all_tokens:
		if !t.is_blighted:  # Only consider non-blighted tokens
			var id = get_token_id(t)
			if id != -1:
				token_ids.append(id)
	
	#print("Sigil A check: Token IDs in biome: ", token_ids)
	
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
			
		#print("Sigil A check: Current token part of pattern ", pattern)
			
		# Check if all pattern IDs exist in placed tokens
		var pattern_found = true
		for id in pattern:
			if !token_ids.has(id):
				pattern_found = false
				#print("Sigil A check: Missing ID ", id, " for pattern ", pattern)
				break
				
		if pattern_found:
			#print("Sigil A check: Pattern found! ", pattern)
			return true
	
	#print("Sigil A check: No pattern found")
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
	
	#print("Checking tokens in biome ", biome_type, " (total tokens: ", tokens.size(), ")")
	
	for token in tokens:
		# Debug token properties
		#print("Token - biome: ", token.biome_type, 
			  #", is_energy: ", token.is_energy, 
			  #", position: ", token.global_position)
		
		if token.biome_type == biome_type and token.is_energy:
			result.append(token)
	
	#print("Found ", result.size(), " energy tokens in biome ", biome_type)
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
func show_pull_push_ui(energy_token, is_other_player: bool):
	print("show push or pull ui")
	var pull_or_push_container = game.get_node("LeftUI/PullorPushContainer/")

	# Create UI to select which token to push/pull
	var dialog = AcceptDialog.new()
	dialog.title = "Select Token to Push/Pull"
	dialog.dialog_text = "Click on a token to push or pull."
	game.add_child(dialog)
	dialog.popup_centered()
	
	# Set game to token selection mode for push/pull
	#pull_or_push_container.show()
	token_manager.is_token_selected = false  # Turn off normal token placement mode
	#is_sigil_mode = true
	
	# Store information about which sigil is being used
	_selected_token_is_other_player = is_other_player
	
	show_push_pull_direction_ui(energy_token)
	#_on_push_pull_perform()


# UI for Sigil C effect (blight/unblight)
func show_blight_unblight_ui(energy_token):
	# Token is still energy
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
	#_selected_token = token
	
	show_blight_unblight_direction_ui(energy_token)

func show_blight_unblight_direction_ui(energy_token):
	print("show blight and unblight direction ui")
	var popup = PopupMenu.new()
	popup.name = "DirectionSelectionPopup"
	game.add_child(popup)

	await signal_other_player_token
	var target_token = _selected_token

	# Add direction options
	if target_token.biome_type == energy_token.biome_type :
		print("show option blight and unblight")
		print("target token : ", target_token)
		print("target token owner id : ", target_token.owner_id)
		print("energy token owner id : ", energy_token.owner_id)
		if !target_token.is_blighted and target_token.owner_id != energy_token.owner_id:
			popup.add_item("Blight", 0)
		elif target_token.is_blighted and target_token.owner_id == energy_token.owner_id:
			popup.add_item("Unblight", 1)
		else: 
			return

	# Connect signal
	popup.id_pressed.connect(func(id): perform_blight_unblight(energy_token, target_token, id == 0))

	# Show popup at mouse position
	var mouse_pos = get_viewport().get_mouse_position()
	popup.position = mouse_pos
	popup.popup()

# Show UI for push/pull direction selection
func show_push_pull_direction_ui(energy_token):
	var popup = PopupMenu.new()
	popup.name = "DirectionSelectionPopup"
	game.add_child(popup)

	await signal_other_player_token
	var target_token = _selected_token
	
	# Checking if the true than sigil a active
	if _selected_token_is_other_player:
		if target_token.owner_id == energy_token.owner_id:
			print("sigil A with the same owner id cant run")
			return
	# Checking if the true than sigil b active
	else:
		if target_token.owner_id != energy_token.owner_id:
			print("sigil B with the different owner id cant run")
			return
	
	# Add direction options
	if target_token.biome_type == energy_token.biome_type:
		popup.add_item("Push Away", 0)
	else:
		popup.add_item("Pull Closer", 1)
	
	# Connect signal
	popup.id_pressed.connect(func(id): perform_push_pull(energy_token, target_token, id == 0))
	
	# Show popup at mouse position
	var mouse_pos = get_viewport().get_mouse_position()
	popup.position = mouse_pos
	popup.popup()

# Perform actual blight or unblight
func perform_blight_unblight(energy_token, token, is_blight: bool):
	print("perform blight unblight")
	
	_selected_token = token
	token_manager.is_token_selected = true

	_on_blight_unblight_input()


# Perform the actual push or pull
func perform_push_pull(energy_token, token, is_push: bool):
	print("perform push pull")
	# Store the selected token for use in subsequent steps
	var target_token = token
	
	# Reset token selection mode
	#is_sigil_mode = false
	
	# Clear any previous highlights
	for placement in get_parent().get_node("TokenPlacements").get_children():
		placement.set_highlight(false)
	
	# Get the token's current placement
	var token_placement = token_manager.get_token_placement_at_position(target_token.global_position)
	if !token_placement:
		print("Could not find token placement location")
		return
	
	# Get the sigil token's placement (this is the energy token that activated the sigil)
	var energy_token_placement = null
	print("energy token : ", energy_token)
	if energy_token:
		print("energy token : ", energy_token.global_position)
		energy_token_placement = token_manager.get_token_placement_at_position(energy_token.global_position)
		print("energy token placment : ", energy_token_placement)
	
	if !energy_token_placement:
		print("Could not find energy token placement")
		return
	
	# Get the biome types
	var target_token_biome = target_token.biome_type
	var energy_token_biome = energy_token.biome_type
	
	# Find potential placement locations based on push/pull mode
	var potential_placements = []
	
	# Determine adjacent biomes based on the rule:
	# If energy token biome is 0 or 2, adjacent biomes are 1 and 3
	# If energy token biome is 1 or 3, adjacent biomes are 0 and 2
	var adjacent_biomes = []
	if energy_token_biome == BiomeType.FOREST || energy_token_biome == BiomeType.MOUNTAIN:
		adjacent_biomes = [BiomeType.WATER, BiomeType.DESERT]
	else: # WATER or DESERT
		adjacent_biomes = [BiomeType.FOREST, BiomeType.MOUNTAIN]
	
	for placement in get_parent().get_node("TokenPlacements").get_children():
		if placement.is_occupied:
			continue
		
		var placement_biome = placement.accepted_biome
		
		if is_push:
			# For "push away": Highlight placements in adjacent biomes to the energy token
			if adjacent_biomes.has(placement_biome) and placement.place_id == -1:
				placement.set_highlight(true)
				potential_placements.append(placement)
		else:
			# For "pull closer": Highlight placements in the energy token's biome
			if placement_biome == energy_token_biome and placement.place_id == -1:
				placement.set_highlight(true)
				potential_placements.append(placement)
	print("adjcents biomes : ",adjacent_biomes )
	if potential_placements.size() == 0:
		print("No valid placements found for push/pull operation")
		return
	
	# Store token for use in the input handler
	_selected_token = target_token
	token_manager.is_token_selected = true
	
	# Will go to push pull input event
	print("Please click on a highlighted location to move the token")


func _on_blight_unblight_input():
	print("blight unblight input")
	if is_sigil_mode:
		print("")
		
		if _selected_token == null:
			show_blight_unblight_direction_ui(selected_energy_token)
			return
		
		print("Processing push/pull input")
		print("Target token : ", _selected_token)
		print("Hit something at position: ", _selected_token.position)
		
		var target_token = _selected_token
		
		var is_blight_status = target_token.is_blighted
		_selected_token.set_blighted(!is_blight_status)
		
		_selected_token = null
		is_sigil_mode = false
		token_manager.is_token_selected = false
		selected_energy_token.highlight(false)
		selected_energy_token = null
		is_sigil_c = false
		is_blight_mode = false
		disable_all_sigil_buttons()
		print("Blight")

# Function to handle the input for push/pull destination selection
func _on_push_pull_input(_placement_pos):
	if is_sigil_mode:
		print("")
		
		if _selected_token == null:
			show_push_pull_direction_ui(selected_energy_token)
			return
		
		print("Processing push/pull input")
		print("Target token : ", _selected_token)
		print("Hit something at position: ", _selected_token.position)
		print("placement pos : ", _placement_pos)
		
		var source_placement = token_manager.get_token_placement_at_position(_selected_token.global_position)
		# Set the new placement
		var _placement_node = null
		for _placement in get_parent().get_node("TokenPlacements").get_children():
			if _placement.global_position.distance_to(_placement_pos) < 0.1:
				_placement_node = _placement
				break
		
		if !_placement_node.is_highlighted:
			return
		
		print("")
		# Move the token
		if multiplayer.is_server():
			print("multiplayer pull and push")
			if source_placement:
				# Clear the current placement
				source_placement.set_occupied(false)
				source_placement.current_token = null
				
				print("placement node : ", _placement_node)
				_selected_token.biome_type = _placement_node.accepted_biome
				print("biome type current player token: ", _selected_token.biome_type)
				_placement_node.set_occupied(true)
				_placement_node.current_token = _selected_token
				
				# Move the token
				_selected_token.global_position = _placement_pos
				
				# Sync to clients
				token_manager.rpc("sync_token_movement", source_placement.global_position, _placement_pos)
			else:
				print("Source placement not found!")
		else:
			# Request server to move the token
			print("Requesting server to move token")
			token_manager.rpc_id(1, "request_token_movement", source_placement.global_position, _placement_pos)
		
		# Cleanup
		if get_tree().root.is_connected("input_event", Callable(self, "_on_push_pull_input")):
			get_tree().root.disconnect("input_event", Callable(self, "_on_push_pull_input"))
		
		# Clear all highlights
		for placement in get_parent().get_node("TokenPlacements").get_children():
			placement.set_highlight(false)
		
		_selected_token = null
		is_sigil_mode = false
		token_manager.is_token_selected = false
		selected_energy_token.highlight(false)
		selected_energy_token = null
		
		
		disable_all_sigil_buttons()
		print("Token move operation completed")
		#else:
			#print("No highlighted placement found near click position")

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Network Integration
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# These functions should be added to token_manager.gd if not already there

# Request token movement (for RPC)
func request_token_movement(from_position: Vector3, to_position: Vector3):	token_manager.request_token_movement(from_position, to_position)
