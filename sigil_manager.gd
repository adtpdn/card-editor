# sigil_manager.gd
extends Node

#SIGNAL
signal signal_other_player_token
signal sigil_activated(sigil_type, token)
signal sigil_mode_changed(enabled)


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# References to other managers
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
@onready var game = get_parent()
@onready var token_manager = $"../TokenManager"
@onready var network_manager = $"../NetworkManager"
@onready var game_state_manager = $"../GameStateManager" 
@onready var point_counter = $"../PointCounter"
@onready var deck = $"../Deck"
@onready var turn_phase_manager = $"../TurnPhaseManager"
@onready var tokens = $"../Tokens"
@onready var notification = $"../Notification"



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

var is_sigil_a = false
var is_sigil_b = false
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
	
	
	if !is_sigil_mode and !token_manager.is_take_off_mode and !token_manager.is_unblight_mode and !token_manager.is_refresh_energy_mode and !token_manager.is_swap_energy_mode and !token_manager.is_plant_extra:
		print("goin to result")
		print("result : ", result)
		if result :
			print("")
			print("sigil manager")
			#print("result : ", result)
			
			var found_token = result.collider.get_parent().get_parent()
			print("found token : ", found_token)
			
			if found_token.name == "Deck" or found_token.name.begins_with("CardSlotBiome"):
				pass
			elif found_token.name != "Hand":
				if found_token.is_energy and turn_phase_manager.current_phase == turn_phase_manager.Phase.PLAY_SIGIL:
					_on_token_clicked(found_token)
					return true  # Token was handled
			
	return false  # No token was handled

# Connect to new tokens added to the scene
func _connect_to_new_token(token):
	if !token.is_connected("token_clicked", _on_token_clicked):
		token.connect("token_clicked", _on_token_clicked)

func connect_sigil_buttons():
	var sigil_a_button = game.sigil_a_button
	var sigil_b_button = game.sigil_b_button
	var sigil_c_button = game.sigil_c_button
	
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

#func debug_energy_token_ids():
	#print("\n=== DEBUG ENERGY TOKEN IDs ===")
	#
	#var biomes = [BiomeType.FOREST, BiomeType.WATER, BiomeType.MOUNTAIN, BiomeType.DESERT]
	#
	#for biome_type in biomes:
		#print("\n-- Biome ", biome_type, " --")
		#
		## Get all energy tokens in this biome
		#var tokens = []
		#for token in game.get_node("Tokens").get_children():
			#if token.biome_type == biome_type and token.is_energy:
				#tokens.append(token)
		#
		#if tokens.size() == 0:
			#print("No energy tokens in this biome")
			#continue
		#
		## Sort tokens by position (for consistent ID assignment)
		#tokens.sort_custom(func(a, b): 
			#if abs(a.global_position.z - b.global_position.z) > 0.1:
				#return a.global_position.z < b.global_position.z
			#return a.global_position.x < b.global_position.x
		#)
		#
		## Print each token's position and calculated ID
		#for i in range(tokens.size()):
			#var token = tokens[i]
			#var id = i + 1  # ID is index + 1
			#print("Token at ", token.global_position, " has ID: ", id, 
				 #", Blighted: ", token.is_blighted, 
				 #", Owner: ", token.owner_id)
	#
	#print("==============================\n")
#
#func debug_all_sigil_patterns():
	#print("\n====== DEBUGGING ALL SIGIL PATTERNS ======")
	#
	## Debug all biomes
	#for biome_type in [BiomeType.FOREST, BiomeType.WATER, BiomeType.MOUNTAIN, BiomeType.DESERT]:
		#print("\n== BIOME ", biome_type, " ==")
		#debug_placements_in_biome(biome_type)
		#
		## Find all energy tokens in this biome
		#var energy_tokens = []
		#for token in game.get_node("Tokens").get_children():
			#if token.biome_type == biome_type && token.is_energy && !token.is_blighted:
				#energy_tokens.append(token)
		#
		#print("Found ", energy_tokens.size(), " non-blighted energy tokens in biome ", biome_type)
		#
		## Check each token for patterns
		#for token in energy_tokens:
			#var placement = token_manager.get_token_placement_at_position(token.global_position)
			#if !placement or placement.place_id <= 0:
				#continue
				#
			#print("\nChecking token at place_id ", placement.place_id)
			#
			#var can_form_a = check_for_sigil_a_pattern(token)
			#var can_form_b = check_for_sigil_b_pattern(token)
			#var can_form_c = check_for_sigil_c_pattern(token)
			#
			#print("Token at place_id ", placement.place_id, " can form patterns: A=", can_form_a, ", B=", can_form_b, ", C=", can_form_c)
	#
	#print("\n=======================================")
#
#func debug_placements_in_biome(biome_type: int):
	#print("\n=== DEBUG PLACEMENTS IN BIOME ", biome_type, " ===")
	#
	#var placements = []
	#for p in get_parent().get_node("TokenPlacements").get_children():
		#if p.accepted_biome == biome_type:
			#placements.append(p)
	#
	#print("Total placements in biome: ", placements.size())
	#
	## Group placements by place_id
	#var placements_by_id = {}
	#for p in placements:
		#var id = p.place_id
		#if !placements_by_id.has(id):
			#placements_by_id[id] = []
		#placements_by_id[id].append(p)
	#
	## Check for duplicate place_ids
	#for id in placements_by_id.keys():
		#if placements_by_id[id].size() > 1:
			#print("WARNING: Found ", placements_by_id[id].size(), " placements with place_id ", id)
	#
	## Print details for each placement by place_id
	#for id in range(1, 8):  # Assuming place_ids 1-7
		#if !placements_by_id.has(id):
			#print("No placement with place_id ", id)
			#continue
			#
		#for p in placements_by_id[id]:
			#var token_info = "none"
			#if p.is_occupied and p.current_token:
				#var token = p.current_token
				#token_info = "Owner=" + str(token.owner_id) + ", Energy=" + str(token.is_energy) + ", Blighted=" + str(token.is_blighted)
			#
			#print("Placement with place_id ", id, 
				  #": Position=", p.global_position, 
				  #", Occupied=", p.is_occupied,
				  #", Token: ", token_info)
	#
	#print("==============================\n")
#
#func debug_selected_token_patterns():
	#if selected_energy_token:
		#print("\n==== DEBUGGING SELECTED TOKEN PATTERNS ====")
		#print("Selected token at: ", selected_energy_token.global_position)
		#
		#var placement = token_manager.get_token_placement_at_position(selected_energy_token.global_position)
		#if placement:
			#print("Token is on placement with place_id: ", placement.place_id)
		#else:
			#print("ERROR: No placement found for token")
			#return
			#
		#print("Biome: ", selected_energy_token.biome_type)
		#print("Is Energy: ", selected_energy_token.is_energy)
		#print("Is Blighted: ", selected_energy_token.is_blighted)
		#
		## Debug the placements in this biome
		#debug_placements_in_biome(selected_energy_token.biome_type)
		#
		## Check patterns
		#var can_form_a = check_for_sigil_a_pattern(selected_energy_token)
		#var can_form_b = check_for_sigil_b_pattern(selected_energy_token)
		#var can_form_c = check_for_sigil_c_pattern(selected_energy_token)
		#
		#print("\nPattern results:")
		#print("Can form Sigil A: ", can_form_a)
		#print("Can form Sigil B: ", can_form_b)
		#print("Can form Sigil C: ", can_form_c)
		#
		## Check mana
		#var has_mana = check_mana_available(selected_energy_token.biome_type)
		#print("Has mana: ", has_mana)
		#
		#print("=========================================")
	#else:
		#print("No energy token selected for debugging")
#
## Debug function to check token movement
#func debug_token_movement(source_token, target_token, target_placement=null):
	#print("\n==== DEBUG TOKEN MOVEMENT ====")
	#
	#print("BEFORE MOVEMENT:")
	#print("Source token (selected energy token):")
	#print("  Position: ", source_token.global_position)
	#print("  Owner: ", source_token.owner_id)
	#print("  Is Energy: ", source_token.is_energy)
	#
	#print("Target token (token to be pushed/pulled):")
	#print("  Position: ", target_token.global_position)
	#print("  Owner: ", target_token.owner_id)
	#print("  Is Energy: ", target_token.is_energy)
	#
	#if target_placement:
		#print("Target placement (where target token should move to):")
		#print("  Position: ", target_placement.global_position)
		#print("  Is Occupied: ", target_placement.is_occupied)
		#if target_placement.is_occupied:
			#print("  Current token: ", target_placement.current_token)
	#
	## Get all tokens to check for duplicates
	#var all_tokens = get_parent().get_node("Tokens").get_children()
	#print("Total tokens in scene before: ", all_tokens.size())
	#
	## Get source token placement
	#var source_placement = token_manager.get_token_placement_at_position(source_token.global_position)
	#if source_placement:
		#print("Source token placement place_id: ", source_placement.place_id)
	#
	## Get target token placement
	#var target_token_placement = token_manager.get_token_placement_at_position(target_token.global_position)
	#if target_token_placement:
		#print("Target token placement place_id: ", target_token_placement.place_id)
	#
	#print("==============================")
#
#func debug_all_energy_tokens():
	#print("\n=== DEBUG ALL ENERGY TOKENS ===")
	#var tokens_by_biome = {
		#BiomeType.FOREST: [],
		#BiomeType.WATER: [],
		#BiomeType.MOUNTAIN: [],
		#BiomeType.DESERT: []
	#}
	#
	## Group tokens by biome
	#for token in game.get_node("Tokens").get_children():
		#if token.is_energy:
			#tokens_by_biome[token.biome_type].append(token)
	#
	## Output details for each biome
	#for biome in tokens_by_biome.keys():
		#var biome_tokens = tokens_by_biome[biome]
		#print("\nBiome ", biome, " has ", biome_tokens.size(), " energy tokens:")
		#
		## Sort tokens for consistent output
		#biome_tokens.sort_custom(func(a, b): 
			#if abs(a.global_position.z - b.global_position.z) > 0.1:
				#return a.global_position.z < b.global_position.z
			#return a.global_position.x < b.global_position.x
		#)
		#
		## Output info for each token
		#for i in range(biome_tokens.size()):
			#var token = biome_tokens[i]
			#print("  Token ", i+1, ": Position=", token.global_position, 
				  #", Blighted=", token.is_blighted, 
				  #", Owner=", token.owner_id)
			#
			## Try to get its placement
			#var placement = token_manager.get_token_placement_at_position(token.global_position)
			#if placement:
				#print("    Placement: place_id=", placement.place_id, 
					  #", index=", placement.get_index())
	#
	#print("==============================\n")

func update_sigil_button_states(token):
	if turn_phase_manager.current_phase == 2:
		print("\n=== SHOWING SIGIL OPTIONS MENU ===")
	
		# Create popup menu
		var popup = PopupMenu.new()
		popup.name = "SigilOptionsPopup"
		game.add_child(popup)
		
		# Check for available patterns
		var can_form_a = check_for_sigil_a_pattern(token)
		var can_form_b = check_for_sigil_b_pattern(token)
		var can_form_c = check_for_sigil_c_pattern(token)
		
		# Check if there's enough mana
		var has_mana = check_mana_available(token.biome_type)
		
		var added_items = 0
		
		# Add available pattern options
		if can_form_a && has_mana:
			popup.add_item("Sigil A", SigilPattern.SIGIL_A)
			added_items += 1
		
		if can_form_b && has_mana:
			popup.add_item("Sigil B", SigilPattern.SIGIL_B)
			added_items += 1
		
		if can_form_c && has_mana:
			popup.add_item("Sigil C", SigilPattern.SIGIL_C)
			added_items += 1
		
		# If no options are available, show a message
		if added_items == 0:
			var dialog = AcceptDialog.new()
			dialog.title = "No Sigil Patterns Available"
			dialog.dialog_text = "No valid sigil patterns can be formed or not enough mana."
			game.add_child(dialog)
			dialog.popup_centered()
			return
		
		# Connect signal to the appropriate sigil handler based on selection
		popup.id_pressed.connect(func(id):
			match id:
				SigilPattern.SIGIL_A:
					_on_sigil_a_pressed()
				SigilPattern.SIGIL_B:
					_on_sigil_b_pressed()
				SigilPattern.SIGIL_C:
					_on_sigil_c_pressed()
		)
		
		# Show popup at mouse position
		var mouse_pos = get_viewport().get_mouse_position()
		popup.position = mouse_pos
		popup.popup()
		
		print("Added " + str(added_items) + " sigil options to menu")
		print("===========================\n")


func disable_all_sigil_buttons():
	var sigil_a_button = game.sigil_a_button
	var sigil_b_button = game.sigil_b_button
	var sigil_c_button = game.sigil_c_button
	
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
	print("checking for sigil patterns")
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

func get_token_id(token):
	print("Getting ID for token at position: ", token.global_position)
	
	# Find the placement this token is on
	var placement = token_manager.get_token_placement_at_position(token.global_position)
	if !placement:
		print("ERROR: No placement found for token")
		return -1
	
	# Get the place_id directly from the placement
	var place_id = placement.place_id
	print("Token is on placement with place_id: ", place_id)
	
	# If place_id is valid, return it directly
	if place_id > 0:
		return place_id
	
	# If place_id is not set, we need to calculate it based on position
	print("WARNING: place_id not set, calculating based on position")
	
	# Get all placements for this biome
	var biome_placements = []
	for p in get_parent().get_node("TokenPlacements").get_children():
		if p.accepted_biome == token.biome_type:
			biome_placements.append(p)
	
	# Sort placements by position
	biome_placements.sort_custom(func(a, b): 
		if abs(a.global_position.z - b.global_position.z) > 0.1:
			return a.global_position.z < b.global_position.z
		return a.global_position.x < b.global_position.x
	)
	
	# Find our placement in the sorted list
	var index = -1
	for i in range(biome_placements.size()):
		if biome_placements[i] == placement:
			index = i
			break
	
	if index == -1:
		print("ERROR: Placement not found in sorted list")
		return -1
	
	# The ID is index + 1 (since IDs start at 1)
	var calculated_id = index + 1
	print("Calculated ID based on position: ", calculated_id)
	
	return calculated_id

# Pattern detection based on token IDs within a biome
func check_for_sigil_a_pattern(token) -> bool:
	print("\n=== CHECKING SIGIL A PATTERN ===")
	
	# Verify it's an energy token
	if !token.is_energy:
		print("Not an energy token")
		return false
	
	# But the selected token itself shouldn't be blighted
	if token.is_blighted:
		print("Selected token is blighted")
		return false
		
	var biome_type = token.biome_type
	print("Checking for Sigil A pattern in biome ", biome_type)
	
	# Get all placements in this biome
	var placements = []
	for p in get_parent().get_node("TokenPlacements").get_children():
		if p.accepted_biome == biome_type:
			placements.append(p)
	
	# Create a map of place_ids to placements
	var placement_map = {}
	for p in placements:
		if p.place_id > 0:  # Only consider placements with valid place_ids
			placement_map[p.place_id] = p
	
	# Get the current token's placement
	var token_placement = token_manager.get_token_placement_at_position(token.global_position)
	if !token_placement:
		print("No placement found for token")
		return false
	
	# Get the token's place_id
	var token_place_id = token_placement.place_id
	if token_place_id <= 0:
		print("Invalid place_id for token: ", token_place_id)
		return false
	
	print("Current token is at place_id: ", token_place_id)
	
	# Check each Sigil A pattern
	var patterns = [
		[1, 2, 7],
		[2, 3, 7],
		[4, 5, 7],
		[5, 6, 7]
	]
	
	for pattern in patterns:
		# Check if current token's place_id is part of this pattern
		if !pattern.has(token_place_id):
			print("Current token (place_id:", token_place_id, ") not part of pattern ", pattern)
			continue
		
		print("Checking pattern: ", pattern)
		
		# Check if all pattern place_ids have occupied placements with tokens
		# Important change: we now count blighted tokens too
		var pattern_found = true
		for id in pattern:
			if !placement_map.has(id):
				print("No placement found for place_id ", id)
				pattern_found = false
				break
				
			var placement = placement_map[id]
			if !placement.is_occupied:
				print("Placement ", id, " is not occupied")
				pattern_found = false
				break
				
			var placed_token = placement.current_token
			if !placed_token:
				print("Placement ", id, " has no token")
				pattern_found = false
				break
				
			# We include blighted tokens now for pattern detection
			print("Placement ", id, " has token, blighted: ", placed_token.is_blighted)
		
		if pattern_found:
			print("PATTERN FOUND! ", pattern)
			return true
	
	print("No Sigil A pattern found")
	return false

func check_for_sigil_b_pattern(token) -> bool:
	print("\n=== CHECKING SIGIL B PATTERN ===")
	
	# Verify it's an energy token
	if !token.is_energy:
		print("Not an energy token")
		return false
	
	# But the selected token itself shouldn't be blighted
	if token.is_blighted:
		print("Selected token is blighted")
		return false
		
	var biome_type = token.biome_type
	print("Checking for Sigil B pattern in biome ", biome_type)
	
	# Get all placements in this biome
	var placements = []
	for p in get_parent().get_node("TokenPlacements").get_children():
		if p.accepted_biome == biome_type:
			placements.append(p)
	
	# Create a map of place_ids to placements
	var placement_map = {}
	for p in placements:
		if p.place_id > 0:  # Only consider placements with valid place_ids
			placement_map[p.place_id] = p
	
	# Get the current token's placement
	var token_placement = token_manager.get_token_placement_at_position(token.global_position)
	if !token_placement:
		print("No placement found for token")
		return false
	
	# Get the token's place_id
	var token_place_id = token_placement.place_id
	if token_place_id <= 0:
		print("Invalid place_id for token: ", token_place_id)
		return false
	
	print("Current token is at place_id: ", token_place_id)
	
	# Check each Sigil B pattern
	var patterns = [
		[1, 2, 3],
		[2, 5, 7],
		[4, 5, 6]
	]
	
	for pattern in patterns:
		# Check if current token's place_id is part of this pattern
		if !pattern.has(token_place_id):
			print("Current token (place_id:", token_place_id, ") not part of pattern ", pattern)
			continue
		
		print("Checking pattern: ", pattern)
		
		# Check if all pattern place_ids have occupied placements with tokens
		# Important change: we now count blighted tokens too
		var pattern_found = true
		for id in pattern:
			if !placement_map.has(id):
				print("No placement found for place_id ", id)
				pattern_found = false
				break
				
			var placement = placement_map[id]
			if !placement.is_occupied:
				print("Placement ", id, " is not occupied")
				pattern_found = false
				break
				
			var placed_token = placement.current_token
			if !placed_token:
				print("Placement ", id, " has no token")
				pattern_found = false
				break
				
			# We include blighted tokens now for pattern detection
			print("Placement ", id, " has token, blighted: ", placed_token.is_blighted)
		
		if pattern_found:
			print("PATTERN FOUND! ", pattern)
			return true
	
	print("No Sigil B pattern found")
	return false

func check_for_sigil_c_pattern(token) -> bool:
	print("\n=== CHECKING SIGIL C PATTERN ===")
	
	# Verify it's an energy token
	if !token.is_energy:
		print("Not an energy token")
		return false
	
	# But the selected token itself shouldn't be blighted
	if token.is_blighted:
		print("Selected token is blighted")
		return false
		
	var biome_type = token.biome_type
	print("Checking for Sigil C pattern in biome ", biome_type)
	
	# Get all placements in this biome
	var placements = []
	for p in get_parent().get_node("TokenPlacements").get_children():
		if p.accepted_biome == biome_type:
			placements.append(p)
	
	# Create a map of place_ids to placements
	var placement_map = {}
	for p in placements:
		if p.place_id > 0:  # Only consider placements with valid place_ids
			placement_map[p.place_id] = p
	
	# Get the current token's placement
	var token_placement = token_manager.get_token_placement_at_position(token.global_position)
	if !token_placement:
		print("No placement found for token")
		return false
	
	# Get the token's place_id
	var token_place_id = token_placement.place_id
	if token_place_id <= 0:
		print("Invalid place_id for token: ", token_place_id)
		return false
	
	print("Current token is at place_id: ", token_place_id)
	
	# Check each Sigil C pattern
	var patterns = [
		[1, 6, 7],
		[3, 4, 7]
	]
	
	for pattern in patterns:
		# Check if current token's place_id is part of this pattern
		if !pattern.has(token_place_id):
			print("Current token (place_id:", token_place_id, ") not part of pattern ", pattern)
			continue
		
		print("Checking pattern: ", pattern)
		
		# Check if all pattern place_ids have occupied placements with tokens
		# Important change: we now count blighted tokens too
		var pattern_found = true
		for id in pattern:
			if !placement_map.has(id):
				print("No placement found for place_id ", id)
				pattern_found = false
				break
				
			var placement = placement_map[id]
			if !placement.is_occupied:
				print("Placement ", id, " is not occupied")
				pattern_found = false
				break
				
			var placed_token = placement.current_token
			if !placed_token:
				print("Placement ", id, " has no token")
				pattern_found = false
				break
				
			# We include blighted tokens now for pattern detection
			print("Placement ", id, " has token, blighted: ", placed_token.is_blighted)
		
		if pattern_found:
			print("PATTERN FOUND! ", pattern)
			return true
	
	print("No Sigil C pattern found")
	return false

# Helper functions for pattern detection
func get_tokens_in_biome(biome_type: int) -> Array:
	var result = []
	var tokens = game.get_node("Tokens").get_children()
	
	print("Finding energy tokens in biome ", biome_type, " (total tokens: ", tokens.size(), ")")
	
	for token in tokens:
		if token.biome_type == biome_type and token.is_energy:
			result.append(token)
			print("  Added token at ", token.global_position, " to result")
	
	print("Found ", result.size(), " energy tokens in biome ", biome_type)
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
	#dialog.popup_centered()

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

# Updated function for push/pull UI
func show_pull_push_ui(energy_token, is_other_player: bool):
	print("\n=== SHOW PUSH OR PULL UI ===")
	print("Energy token position: ", energy_token.global_position)
	print("Is targeting other player tokens: ", is_other_player)

	# Use the existing PopUpSigil node
	var instruction_text = ""
	if is_other_player:
		instruction_text = "Select another player's token to Push or Pull"
	else:
		instruction_text = "Select your own token to Push or Pull"
	
	notification.show_instruction_label(instruction_text)
	
	# Set game to token selection mode for push/pull
	token_manager.is_token_selected = false  # Turn off normal token placement mode
	
	# Store information about which sigil is being used
	_selected_token_is_other_player = is_other_player
	
	# Track token count before operation
	var token_count_before = get_parent().get_node("Tokens").get_children().size()
	print("Token count before starting push/pull operation: ", token_count_before)
	
	# Showing outerglow for each token to select
	var tokens_list = tokens.get_children()
	print("Total tokens: ", tokens_list.size())
	
	var highlighted_count = 0
	if is_other_player:
		# For Sigil A (other player's tokens)
		for token in tokens_list:
			if token.owner_id != energy_token.owner_id and !token.is_energy:
				token.outerglow.show()
				highlighted_count += 1
	else:
		# For Sigil B (own tokens)
		for token in tokens_list:
			if token.owner_id == energy_token.owner_id and !token.is_energy:
				token.outerglow.show()
				highlighted_count += 1
	
	print("Highlighted ", highlighted_count, " tokens for selection")
	print("===========================\n")


# Updated function for blight/unblight UI
func show_blight_unblight_ui(energy_token):
	# Use the existing PopUpSigil node
	var instruction_text = "Select a token to Blight (opponent's) or Unblight (your own)"
	notification.show_instruction_label(instruction_text)
	
	# Set game to token selection mode for blight/unblight
	token_manager.is_token_selected = false  # Turn off normal token placement mode
	is_blight_mode = true
	
	# Showing outerglow for each token to select
	var tokens_list = tokens.get_children()
	for token in tokens_list:
		if token.owner_id != energy_token.owner_id and !token.is_energy and !token.is_blighted and token.biome_type == energy_token.biome_type:
			token.outerglow.show()
		if token.owner_id == energy_token.owner_id and !token.is_energy and token.is_blighted and token.biome_type == energy_token.biome_type:
			print("own token blight")
			token.outerglow.show()


func show_blight_unblight_direction_ui(energy_token):
	await signal_other_player_token
	var target_token = _selected_token
	if target_token.biome_type == energy_token.biome_type :
		print("show blight and unblight direction ui")
		# Add direction options
		#print("show option blight and unblight")
		#print("target token : ", target_token)
		#print("target token owner id : ", target_token.owner_id)
		#print("energy token owner id : ", energy_token.owner_id)
		var choose_id 
		if !target_token.is_blighted and target_token.owner_id != energy_token.owner_id:
			choose_id = 0
		elif target_token.is_blighted and target_token.owner_id == energy_token.owner_id:
			choose_id = 1
		else: 
			return

		# Connect signal
		perform_blight_unblight(energy_token, target_token, choose_id == 0)


# Show UI for push/pull direction selection
func show_push_pull_direction_ui(energy_token):
	print("\n=== SHOW PUSH/PULL DIRECTION UI ===")

	await signal_other_player_token
	var target_token = _selected_token
	energy_token = selected_energy_token
	
	print("Energy token: ", energy_token.global_position)
	print("Target token: ", target_token.global_position)
	
	# Checking if the true then sigil a active (other player's token)
	if _selected_token_is_other_player:
		if target_token.owner_id == energy_token.owner_id:
			print("ERROR: Sigil A cannot target your own tokens")
			return
	# Checking if false then sigil b active (own token)
	else:
		if target_token.owner_id != energy_token.owner_id:
			print("ERROR: Sigil B cannot target other player's tokens")
			return
	
	var choose_id 
	# Add direction options based on biome relationship
	if target_token.biome_type == energy_token.biome_type:
		choose_id = 0
		print("Push option added (same biome)")
	else:
		choose_id = 1
		print("Pull option added (different biome)")
	
	# Connect signal
	perform_push_pull(energy_token, target_token, choose_id == 0)
	print("==============================\n")

# Perform actual blight or unblight
func perform_blight_unblight(energy_token, token, is_blight: bool):
	print("perform blight unblight")
	
	_selected_token = token
	token_manager.is_token_selected = true

	_on_blight_unblight_input()


# Perform the actual push or pull
func perform_push_pull(energy_token, token, is_push: bool):
	print("\n=== PERFORM PUSH/PULL ===")
	print("Energy token: ", energy_token.global_position)
	print("Target token: ", token.global_position)
	print("Operation: ", "PUSH" if is_push else "PULL")
	
	# Track token count before operation
	var token_count_before = get_parent().get_node("Tokens").get_children().size()
	print("Token count before push/pull: ", token_count_before)
	
	# Store the selected token for use in subsequent steps
	var target_token = token
	
	# Clear any previous highlights
	for placement in get_parent().get_node("TokenPlacements").get_children():
		placement.set_highlight(false)
	
	# Get the token's current placement
	var token_placement = token_manager.get_token_placement_at_position(target_token.global_position)
	if !token_placement:
		print("ERROR: Could not find token placement location")
		return
	
	print("Current token placement: ", token_placement.global_position)
	
	# Get the sigil token's placement (this is the energy token that activated the sigil)
	var energy_token_placement = null
	if energy_token:
		energy_token_placement = token_manager.get_token_placement_at_position(energy_token.global_position)
	
	if !energy_token_placement:
		print("ERROR: Could not find energy token placement")
		return
	
	print("Energy token placement: ", energy_token_placement.global_position)
	
	# Get the biome types
	var target_token_biome = target_token.biome_type
	var energy_token_biome = energy_token.biome_type
	
	print("Target token biome: ", target_token_biome)
	print("Energy token biome: ", energy_token_biome)
	
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
	
	print("Adjacent biomes: ", adjacent_biomes)
	
	for placement in get_parent().get_node("TokenPlacements").get_children():
		if placement.is_occupied:
			continue
		
		var placement_biome = placement.accepted_biome
		
		if is_push:
			# For "push away": Highlight placements in adjacent biomes to the energy token
			if adjacent_biomes.has(placement_biome) and placement.place_id == -1:
				print("push placement")
				placement.show()
				placement.set_highlight(true)
				potential_placements.append(placement)
			else:
				placement.hide()
		else:
			# For "pull closer": Highlight placements in the energy token's biome
			if placement_biome == energy_token_biome and placement.place_id == -1:
				placement.show()
				placement.set_highlight(true)
				potential_placements.append(placement)
			else:
				placement.hide()
	
	print("Found ", potential_placements.size(), " potential placements for the operation")
	
	if potential_placements.size() == 0:
		print("ERROR: No valid placements found for push/pull operation")
		return
	
	# Store token for use in the input handler
	_selected_token = target_token
	token_manager.is_token_selected = true
	
	print("Target token stored for movement. Please click on a highlighted location.")
	print("==============================\n")


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
		
		# Clear the instruction label at the end of the operation
		notification.hide_panel()
		
		_selected_token = null
		is_sigil_mode = false
		token_manager.is_token_selected = false
		selected_energy_token.highlight(false)
		selected_energy_token = null
		is_sigil_c = false
		is_blight_mode = false
		turn_phase_manager.unhighlight_marker_mesh()
		
		# Hide Outerglow
		var tokens = tokens.get_children()
		for token in tokens:
			token.outerglow.hide()
		
		disable_all_sigil_buttons()
		print("Blight")

# Function to handle the input for push/pull destination selection
func _on_push_pull_input(_placement_pos):
	if is_sigil_mode:
		print("\n=== ON PUSH/PULL INPUT ===")
		
		if _selected_token == null:
			print("No token selected, showing direction UI")
			show_push_pull_direction_ui(selected_energy_token)
			return
		
		
		print("Processing push/pull input")
		print("Target token: ", _selected_token)
		print("Target token position: ", _selected_token.global_position)
		print("Destination position: ", _placement_pos)
		
		# Track token count before operation
		var token_count_before = get_parent().get_node("Tokens").get_children().size()
		print("Token count before moving: ", token_count_before)
		
		var source_placement = token_manager.get_token_placement_at_position(_selected_token.global_position)
		if !source_placement:
			print("ERROR: Source placement not found!")
			return
			
		print("Source placement: ", source_placement.global_position)
		
		# Set the new placement
		var _placement_node = null
		for _placement in get_parent().get_node("TokenPlacements").get_children():
			if _placement.global_position.distance_to(_placement_pos) < 0.1:
				_placement_node = _placement
				break
		
		if !_placement_node:
			print("ERROR: No placement found at destination position")
			return
			
		print("Destination placement: ", _placement_node.global_position)
		
		#if !_placement_node.is_highlighted:
			#print("ERROR: Selected placement is not highlighted")
			#return
		
		print("Moving token from ", source_placement.global_position, " to ", _placement_node.global_position)
		
		# Move the token - IMPORTANT: This is where duplication could happen
		if multiplayer.is_server():
			print("Server handling token movement")
			
			# Clear the current placement FIRST
			source_placement.set_occupied(false)
			source_placement.current_token = null
			print("Source placement marked as unoccupied")
			
			# Update token biome type to match new placement
			_selected_token.biome_type = _placement_node.accepted_biome
			print("Updated token biome type to: ", _selected_token.biome_type)
			
			# Set new placement as occupied WITH THIS TOKEN (not a duplicate)
			_placement_node.set_occupied(true)
			_placement_node.current_token = _selected_token
			print("Destination placement marked as occupied with the same token")
			
			# Move the token to the new position - NO new token creation
			_selected_token.global_position = _placement_pos
			print("Token moved to new position")
			
			# Sync to clients
			token_manager.rpc("sync_token_movement", source_placement.global_position, _placement_pos)
		else:
			# Request server to move the token
			print("Client requesting server to move token")
			token_manager.rpc_id(1, "request_token_movement", source_placement.global_position, _placement_pos)
		
		# Track token count after operation to check for duplication
		var token_count_after = get_parent().get_node("Tokens").get_children().size()
		print("Token count after moving: ", token_count_after)
		if token_count_after > token_count_before:
			print("WARNING: Token count increased! Duplication may have occurred!")
		
		# Clear all highlights
		for placement in get_parent().get_node("TokenPlacements").get_children():
			placement.set_highlight(false)
			placement.hide_placement()
		
		# Hide Outerglow
		var tokens_list = tokens.get_children()
		for token in tokens_list:
			token.outerglow.hide()
		
		# Clear the instruction label at the end of the operation
		notification.hide_panel()
		
		# Reset state
		_selected_token = null
		is_sigil_mode = false
		token_manager.is_token_selected = false
		turn_phase_manager.unhighlight_marker_mesh()
		
		# Unhighlight the energy token
		if selected_energy_token:
			selected_energy_token.highlight(false)
			selected_energy_token = null
		
		disable_all_sigil_buttons()
		print("Token move operation completed")
		print("==============================\n")

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Network Integration
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# These functions should be added to token_manager.gd if not already there

# Request token movement (for RPC)
func request_token_movement(from_position: Vector3, to_position: Vector3):	token_manager.request_token_movement(from_position, to_position)


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Phase Management
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Enable sigil activation mode
func enable_sigil_mode():
	is_sigil_mode = true
	
	# Update the UI to show sigil is active
	var sigil_container = get_parent().get_node("SigilContainer")
	if sigil_container:
		for child in sigil_container.get_children():
			if child is Button:
				child.disabled = false
				child.modulate = Color(1, 1, 1, 1)
				
	# Emit signal for tracking
	sigil_mode_changed.emit(true)

# Disable sigil activation mode
func disable_sigil_mode():
	is_sigil_mode = false
	is_sigil_c = false
	
	# Update the UI
	var sigil_container = get_parent().get_node("SigilContainer")
	if sigil_container:
		for child in sigil_container.get_children():
			if child is Button:
				child.disabled = true
				child.modulate = Color(0.5, 0.5, 0.5, 0.5)
	
	# Emit signal for tracking
	sigil_mode_changed.emit(false)
