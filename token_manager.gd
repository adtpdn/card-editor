# token_manager.gd
class_name TokenManager
extends Node

# TOKEN MANAGER SECTIONS:
# - References & Constants
# - Variables & State Management 
# - Initialization & Setup
# - Token Management
# - Placement & Selection
# - Token Placement Generation
# - UI Management
# - Turn Management
# - Card Effects
# - Card Effect Implementation
# - Network Synchronization
# - Helper Functions
# - Phase Management

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

# Modify token selection handling to use both biome and type
var selected_token_biome = -1
var selected_token_node

# Token selection state
var is_token_selected = false

var last_token_selection_time = 0.0
var last_token_placement_time = 0.0

# Token scene reference
var token_scene = preload("res://token_3d.tscn")

# Add variables for card effects
var is_take_off_mode := false
var is_unblight_mode := false
var is_refresh_energy_mode := false
var is_swap_energy_mode := false  
var is_plant_extra := false

var first_swap_token = null  

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

# Main initialization function that can be called from game.gd
func initialize():
	print("TokenManager initializing...")
	
	setup_token_placements()
	setup_biome_borders()
	setup_token_ui()
	
	# Make sure host has tokens on startup
	if multiplayer.is_server():
		var host_id = multiplayer.get_unique_id()
		initialize_player_tokens(host_id, true)  # Force reset to ensure clean state
		
		# Directly update token UI for host
		var tokens = get_player_tokens(host_id)
		print("Host initialized with " + str(tokens.size()) + " tokens")
		
		# Force update the token button
		var token_button = get_parent().get_node("RightUI/TokenButton")
		if token_button:
			token_button.text = "Tokens: " + str(tokens.size())
			token_button.disabled = false  # Force enable for host
		
	print("TokenManager initialized.")

func setup_token_placements():
	# Only set up if not already set up
	if get_parent().get_node("TokenPlacements").get_child_count() > 0:
		return
	
	await get_parent().ready
	await get_tree().process_frame
	
	var token_placement_scene = preload("res://token_placement_location.tscn")
	
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

func setup_biome_borders():
	var material = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	# Create octagonal border for each biome region
	for biome in biome_assignments.keys():
		var slice_indices = biome_assignments[biome]
		
		for slice_idx in slice_indices:
			var start_angle = slice_idx * PI / 4
			var points = []
			
			# Create border mesh
			var surface_tool = SurfaceTool.new()
			surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			
			# Center point
			var center = Vector3.ZERO
			
			# Add vertices for arc
			var segments = 8
			var angle_step = PI / (4 * segments)
			
			# Create triangles
			for i in range(segments):
				var angle1 = start_angle + i * angle_step
				var angle2 = start_angle + (i + 1) * angle_step
				
				var v1 = Vector3(radius * cos(angle1), 0, radius * sin(angle1))
				var v2 = Vector3(radius * cos(angle2), 0, radius * sin(angle2))
				
				# Add triangle (center, v1, v2)
				surface_tool.add_vertex(center)
				surface_tool.add_vertex(v1)
				surface_tool.add_vertex(v2)
			
			var mesh_instance = MeshInstance3D.new()
			mesh_instance.mesh = surface_tool.commit()
			
			# Use a neutral color instead of biome color
			var color = Color(0.7, 0.7, 0.7)  # Light gray
			color.a = 0.2
			var region_material = material.duplicate()
			region_material.albedo_color = color
			mesh_instance.material_override = region_material
			
			# Add to the borders node
			borders_node.add_child(mesh_instance)

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

func get_placed_tokens_for_player(player_id: int) -> Array:
	var game = get_tree().get_root().get_node("Game")
	if !game:
		return []
		
	var placed_tokens = []
	var tokens_node = game.get_node("Tokens")
	if tokens_node:
		for token in tokens_node.get_children():
			if token.owner_id == player_id:
				placed_tokens.append(token)
	
	return placed_tokens

func can_place_token(player_id: int, token_index: int) -> bool:
	if not player_tokens.has(player_id) or token_index >= player_tokens[player_id].size():
		return false
	return true

func set_player_tokens(player_id: int, tokens: Array):
	if tokens == null:
		tokens = []
	player_tokens[player_id] = tokens.duplicate()


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Placement & Selection
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _on_token_selected():
	print("Token button clicked")
	
	var player_id = multiplayer.get_unique_id()
	if !game_state_manager.is_valid_player_turn(player_id):
		print("Not your turn!")
		is_token_selected = false
		update_token_ui()
		return
	
	var tokens = get_player_tokens(player_id)
	if tokens.size() <= 0:
		print("No tokens left!")
		is_token_selected = false
		update_token_ui()
		return
	
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_token_selection_time < TOKEN_PLACEMENT_COOLDOWN:
		return
	
	last_token_selection_time = current_time
	
	# Initialize tokens planted counter for this player if needed
	if !tokens_planted_this_turn.has(player_id):
		tokens_planted_this_turn[player_id] = 0
	
	# Check if player has already planted the maximum tokens this turn
	if tokens_planted_this_turn[player_id] >= max_tokens_per_turn:
		print("Maximum tokens for this turn already planted!")
		is_token_selected = false
		update_token_ui()
		return
	
	# Toggle selection state
	is_token_selected = !is_token_selected
	print("Token selection mode: " + str(is_token_selected))
	
	if is_token_selected:
		# Check current phase and highlight appropriate placements
		var current_phase = turn_phase_manager.current_phase
		
		# First unhighlight all placements to ensure clean state
		unhighlight_all_token_placements()
		
		# Highlight based on phase
		if is_plant_extra:
			# If this is an extra token (from card effect)
			if card_manager.active_card != null:
				for placement in get_parent().get_node("TokenPlacements").get_children():
					if !placement.is_occupied and placement.accepted_biome == card_manager.active_card.card_on_biome:
						placement.set_highlight(true)
		
		elif current_phase == turn_phase_manager.Phase.PLANT_BIOME:
			# In biome phase, highlight biome locations (place_id == -1)
			for placement in get_parent().get_node("TokenPlacements").get_children():
				if !placement.is_occupied and placement.place_id == -1:
					placement.set_highlight(true)
		
		elif current_phase == turn_phase_manager.Phase.PLANT_SIGIL_AND_CARD:
			# In sigil phase, highlight sigil locations (place_id != -1)
			for placement in get_parent().get_node("TokenPlacements").get_children():
				if !placement.is_occupied and placement.place_id != -1:
					placement.set_highlight(true)
		
	else:
		# Unhighlight all placements when deselecting
		unhighlight_all_token_placements()
	
	# Update UI to show selection state
	update_token_ui()
	debug_token_state()

func _input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		#print("event : ", event)
		handle_touch(event.position)

func handle_touch(position: Vector2):
	print("Handle touch")
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_token_placement_time < TOKEN_PLACEMENT_COOLDOWN:
		return
	
	var player_id = multiplayer.get_unique_id()
	
	# Check if it's this player's turn
	if !game_state_manager.is_valid_player_turn(player_id):
		print("Not your turn!")
		selected_token_biome = -1
		unhighlight_all_token_placements()
		return
	
	# First, check if SigilManager wants to handle this input
	if !sigil_manager.is_sigil_mode:
		if get_parent().has_node("SigilManager"):
			var sigil_manager = get_parent().get_node("SigilManager")
			if sigil_manager.handle_sigil_input(position):
				return  # Input was handled by SigilManager.
	
	# Continue with regular token placement logic...
	var camera = get_parent().get_node("Camera3D")
	if !camera:
		print("Camera not found!")
		return
		
	var from = camera.project_ray_origin(position)
	var to = from + camera.project_ray_normal(position) * 1000
	
	var space_state = get_tree().get_root().get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	var result = space_state.intersect_ray(query)
	
	if result:
		var collider = result["collider"]
		
		# If token selection mode is active, check if we're clicking on a valid token placement
		if is_token_selected:
			# Find the placement at this position
			var placement = get_token_placement_at_position(result["position"])
			if placement:
				# Check if the placement is highlighted (valid for current phase)
				if !placement.is_highlighted:
					print("Cannot place token here - not a valid placement location for current phase")
					return
				
				# Handle token placement at this valid location
				if placement.is_occupied:
					print("Location already occupied")
					return
				
				# Place token at this location
				var token_index = selected_token_index if selected_token_index >= 0 else 0
				
				if multiplayer.is_server():
					request_token_placement(token_index, placement.global_position, placement.accepted_biome)
				else:
					rpc_id(1, "request_token_placement", token_index, placement.global_position, placement.accepted_biome)
				
				# Reset selection state
				is_token_selected = false
				unhighlight_all_token_placements()
				return

		# Find the token at this position with improved detection
		var found_token = collider.get_parent().get_parent()

		if found_token and found_token.name.begins_with("Token3D"):
			print("Processing token: " + str(found_token.name))
			# Sigil Effects
			if sigil_manager.is_sigil_mode and !found_token.is_energy:
				print("select target token for sigil activation")
				sigil_manager._selected_token = found_token
				sigil_manager.signal_other_player_token.emit()

			## Card Effects
			var active_card = card_manager.active_card
			if active_card != null:
				print("card active : ", active_card.card_name)
				var card_on_biome = active_card.card_on_biome
				
				print("is take off mode : ", is_take_off_mode)
				print("is energy : ", found_token.is_energy)
				print("is biome type : ", found_token.biome_type)
				print("is blighted : ", found_token.is_blighted)
				print("card on biome : ", card_on_biome)
				
				# Take Off Energy 
				if is_take_off_mode and found_token.is_energy and found_token.biome_type == card_on_biome:
					print("Take Off Energy Card Effect")
					# Handle remove mode
					if multiplayer.is_server():
						take_off_energy(found_token.global_position)
					else:
						print("Sending take off request to server")
						rpc_id(1, "request_take_off_energy", found_token.global_position)
					
					# Reset remove mode after attempt
					is_take_off_mode = false

				# Unblight Card Effect
				elif is_unblight_mode and !found_token.is_energy and found_token.is_blighted and found_token.biome_type == card_on_biome:
					print("Unblight Card Effect")
					# Handle unblight mode
					if multiplayer.is_server():
						unblight_token(found_token.global_position)
					else:
						print("Sending unblight request to server")
						rpc_id(1, "request_unblight_token", found_token.global_position)
					
					# Reset blight mode after attempt
					is_unblight_mode = false

				# Refresh Energy Card Effect 
				elif is_refresh_energy_mode and found_token.is_energy and found_token.is_blighted and found_token.biome_type == card_on_biome:
					print("Refresh Energy Card Effet")
					# Handle refresh energy mode
					if multiplayer.is_server():
						refresh_energy(found_token.global_position)
					else:
						print("Sending refresh energy request to server")
						rpc_id(1, "request_refresh_energy", found_token.global_position)
					
					is_refresh_energy_mode = false

				# Swap Energy Card Effect
				elif is_swap_energy_mode and found_token.is_energy and found_token.biome_type == card_on_biome:
					print("Swap Energy Card Effect - Token Selection")
					
					# If this is the first token selection
					if first_swap_token == null:
						# Only allow selecting your own tokens for the first selection
						if found_token.owner_id == multiplayer.get_unique_id():
							first_swap_token = found_token
							# Highlight this token to show it's selected
							first_swap_token.highlight(true)
							print("First token selected for swap: " + str(first_swap_token.global_position))
						else:
							print("You can only select your own token first")
					
					# If this is the second token selection
					else:
						# Make sure we're not selecting the same token
						if found_token != first_swap_token:
							# Check that both tokens are in the same biome
							if found_token.biome_type == first_swap_token.biome_type:
								# Perform the swap
								if multiplayer.is_server():
									swap_energy_tokens(first_swap_token.global_position, found_token.global_position)
								else:
									print("Sending swap energy request to server")
									rpc_id(1, "request_swap_energy_tokens", first_swap_token.global_position, found_token.global_position)
								
								# Reset swap mode after attempt
								first_swap_token = null
								is_swap_energy_mode = false
				turn_phase_manager.card_played = true 
				
				
			found_token = null
			# Always unhighlight after any token action
			unhighlight_all_token_placements()

@rpc("any_peer")
func request_token_placement(token_index: int, position: Vector3, biome_type: int):
	if !multiplayer.is_server():
		return
		
	var player_id = multiplayer.get_remote_sender_id()
	if player_id == 0:  # If this is a local server request
		player_id = multiplayer.get_unique_id()
	
	print("Processing token placement request from player ", player_id, 
		  " at position ", position)
	
	# Validate placement timing and turn
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_token_placement_time < TOKEN_PLACEMENT_COOLDOWN:
		if player_id != multiplayer.get_unique_id():
			get_parent().rpc_id(player_id, "notify_invalid_placement")
		return
	
	if !game_state_manager.is_valid_player_turn(player_id):
		if player_id != multiplayer.get_unique_id():
			get_parent().rpc_id(player_id, "notify_invalid_placement")
		return
	
	var player_tokens = get_player_tokens(player_id)
	
	if token_index >= 0 and token_index < player_tokens.size():
		var token_data = {}  # Empty token data - biome will be assigned based on placement
		var placement = get_token_placement_at_position(position)
		
		# Only check if placement is occupied
		if placement and !placement.is_occupied:
			# CRITICAL: Add the biome from the placement location
			token_data.biome = placement.accepted_biome
			
			# Update cooldown time
			last_token_placement_time = current_time
			
			# IMPORTANT: Remove the token from player's available tokens BEFORE sync
			remove_token(player_id, token_index)
			
			# Log the token count
			print("Player ", player_id, " token count before sync: ", 
				  get_player_tokens(player_id).size())
			
			# Important: Sync the placement to ALL clients including the requester
			rpc("sync_token_placement", player_id, token_data, position)

@rpc("any_peer", "call_local")
func sync_token_placement(player_id: int, token_data: Dictionary, position: Vector3):
	print("Syncing token placement for player ", player_id, " at position ", position)
	
	var placement = get_token_placement_at_position(position)
	if !placement:
		print("No placement found at position ", position)
		return
	
	# Check if occupied
	if placement.is_occupied:
		print("Placement already occupied at ", position)
		return
	
	# Initialize tokens planted counter for this player if needed
	if !tokens_planted_this_turn.has(player_id):
		tokens_planted_this_turn[player_id] = 0
	
	# Create and place the token
	var token = token_scene.instantiate()
	get_parent().get_node("Tokens").add_child(token, true)
	
	# Convert types explicitly
	var biome_type = int(token_data.biome) if token_data.has("biome") else placement.accepted_biome
	
	# Determine if this is an energy placement
	var placement_index = placement.get_index()
	var is_energy = placement_index < 28  # First 28 placements are energy placements
	print("Placing token at index ", placement_index, ", is_energy: ", is_energy)
	
	# Call the updated set_token_data with biome, player id, and energy status
	token.set_token_data(biome_type, player_id, is_energy)
	token.global_position = position
	
	# Store reference to the placement in the token
	token.token_placement = placement
	
	# Mark placement as occupied and store token reference
	placement.set_occupied(true)
	placement.current_token = token
	
	# Update token planting state
	tokens_planted_this_turn[player_id] += 1
	
	# Reset selection state
	is_token_selected = false
	unhighlight_all_token_placements()
	
	# CRITICAL: After a token is placed, force a full token state sync
	if multiplayer.is_server():
		# Sync token counts for all players
		var players = get_parent().players
		
		# This is critical: Update token counts for all players
		for pid in players:
			var player_tokens = get_player_tokens(pid)
			
			# Print detailed debug
			print("Syncing tokens after placement: Player=", pid, 
				  ", TokenCount=", player_tokens.size())
			
			# Send token counts to EACH player
			if pid == multiplayer.get_unique_id():
				# Direct call for server
				sync_player_tokens(player_tokens, pid)
			else:
				# RPC for clients
				rpc_id(pid, "sync_player_tokens", player_tokens, pid)
		
		# Also sync token placement data to ensure consistency
		var token_placement_data = []
		for token_obj in get_parent().get_node("Tokens").get_children():
			token_placement_data.append({
				"position": token_obj.global_position,
				"biome": token_obj.biome_type,
				"owner": token_obj.owner_id,
				"is_energy": token_obj.is_energy
			})
		
		# Send this data to all clients
		rpc("sync_all_token_placements", token_placement_data)
	
	# Update UI for the current player
	var local_id = multiplayer.get_unique_id()
	if local_id == player_id:
		update_token_ui()
	
	# Verify that UI reflects the correct token count
	if player_id == multiplayer.get_unique_id():
		# This is our token, make sure our UI is updated
		var local_tokens = get_player_tokens(player_id)
		
		var token_button = get_parent().get_node("RightUI/TokenButton")
		if token_button:
			# Force update the button text
			token_button.text = "Tokens: " + str(local_tokens.size())
			
			# Check if we've reached max tokens
			token_button.disabled = local_tokens.size() <= 0 || !game_state_manager.is_valid_player_turn(player_id)
			
			print("After token placement - UI updated: Token count=", local_tokens.size(),
				  ", Button disabled=", token_button.disabled)
	
	# After placing the token, update the saved count
	if multiplayer.is_server():
		var updated_tokens = get_player_tokens(player_id)
		player_token_counts[player_id] = updated_tokens.size()
		print("Updated player ", player_id, " token count to ", updated_tokens.size())
	
	# Make sure to emit the token_placed signal
	emit_signal("token_placed", player_id, token_data.biome, position)
	print("Token manager emitted token_placed signal for player ", player_id, " at position ", position)

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

func debug_token_state():
	var player_id = multiplayer.get_unique_id()
	var tokens = get_player_tokens(player_id)
	
	print("==== TOKEN DEBUG INFO ====")
	print("Player ID: " + str(player_id))
	print("Token count: " + str(tokens.size()))
	print("Is token selected: " + str(is_token_selected))
	print("Is valid turn: " + str(game_state_manager.is_valid_player_turn(player_id)))
	
	var token_button = get_parent().get_node("RightUI/TokenButton")
	if token_button:
		print("Button disabled: " + str(token_button.disabled))
		print("Button text: " + token_button.text)
	print("==========================")

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
# Turn Management
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func reset_turn_token_counters(player_id: int):
	# Reset the tokens planted counter for this player
	if tokens_planted_this_turn.has(player_id):
		tokens_planted_this_turn[player_id] = 0
	
	# Reset the placement type flags
	can_plant_on_sigil = true
	can_plant_on_biome = false  # Start with only sigil planting enabled
	
	# Reset ALL card effect flags - this is important
	is_plant_extra = false
	is_take_off_mode = false
	is_unblight_mode = false
	is_refresh_energy_mode = false
	is_swap_energy_mode = false
	first_swap_token = null
	
	# Reset sigil mode if it's the local player's turn ending
	if player_id == multiplayer.get_unique_id() and sigil_manager != null:
		sigil_manager.is_sigil_mode = false
		sigil_manager.is_sigil_c = false
	
	# Reset max tokens per turn to default
	max_tokens_per_turn = 2
	
	# IMPORTANT: Do NOT sync these card effect states to other players
	# Only sync the basic token planting state
	if multiplayer.is_server():
		rpc("sync_token_planting_state", player_id, 0, true, false, 2)
	
	# Update UI to reflect new state
	update_token_ui()
	
	# Reset any UI highlights
	unhighlight_all_token_placements()
	
	# Reset any highlighting on tokens
	if first_swap_token:
		first_swap_token.highlight(false)
		first_swap_token = null

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Card Effects
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _on_take_off_energy():
	print("Take Off Energy mode activate")
	is_take_off_mode = true

	# Ensure token selection mode is off
	is_token_selected = false
	unhighlight_all_token_placements()
	update_token_ui()

func _on_unblight_token():
	print("Unblight mode activated")
	is_unblight_mode = true
	
	# Ensure token selection mode is off
	is_token_selected = false
	unhighlight_all_token_placements()
	update_token_ui()

func _on_refresh_energy():
	print("Refresh energy mode activated")
	is_refresh_energy_mode = true
	
	# Ensure token selection mode is off
	is_token_selected = false
	unhighlight_all_token_placements()
	update_token_ui()

func _on_swap_energy():
	print("Swap energy mode activated")
	is_swap_energy_mode = true
	is_take_off_mode = false
	is_unblight_mode = false
	is_refresh_energy_mode = false
	first_swap_token = null  # Reset first token selection
	
	# Ensure token selection mode is off
	is_token_selected = false
	unhighlight_all_token_placements()
	update_token_ui()

func _on_plant_extra_token():
	print("Plant extra token card effect activated")
	var player_id = multiplayer.get_unique_id()
	
	# Temporarily increase max tokens per turn by 1
	max_tokens_per_turn += 1
	print("Max tokens per turn increased to: " + str(max_tokens_per_turn))
	
	# Set the plant extra flag
	is_plant_extra = true
	
	# Enable placing on both sigil and biome locations
	can_plant_on_sigil = true
	can_plant_on_biome = true
	
	# Sync changes to all clients if we're the server
	if multiplayer.is_server():
		rpc("sync_token_planting_state", player_id, tokens_planted_this_turn.get(player_id, 0), 
			true, true, max_tokens_per_turn)
	else:
		# Request server to sync our changes
		rpc_id(1, "request_token_planting_state_update", player_id, true, true, max_tokens_per_turn)
	
	# Update UI to show token button as active
	update_token_ui()


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Card Effect Implementation
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Extra Plant TOken
@rpc("any_peer")
func request_token_planting_state_update(player_id: int, can_place_sigil: bool, can_place_biome: bool, max_tokens: int):
	if !multiplayer.is_server():
		return
	
	var requesting_player = multiplayer.get_remote_sender_id()
	if requesting_player != player_id:
		return  # Only allow players to update their own state
	
	# Update server's state
	if tokens_planted_this_turn.has(player_id):
		tokens_planted_this_turn[player_id] = tokens_planted_this_turn[player_id]  # Keep current value
	else:
		tokens_planted_this_turn[player_id] = 0
	
	# Update flags
	can_plant_on_sigil = can_place_sigil
	can_plant_on_biome = can_place_biome
	max_tokens_per_turn = max_tokens
	
	# Sync to all clients
	rpc("sync_token_planting_state", player_id, tokens_planted_this_turn[player_id], 
		can_place_sigil, can_place_biome, max_tokens)


# Swap Energy
@rpc("any_peer")
func request_swap_energy_tokens(first_token_position: Vector3, second_token_position: Vector3):
	if !multiplayer.is_server():
		return
	
	var player_id = multiplayer.get_remote_sender_id()
	if player_id == 0:  # Local server call
		player_id = multiplayer.get_unique_id()
	
	# Validate it's the player's turn
	if !game_state_manager.is_valid_player_turn(player_id):
		return
	
	# Find the first token and verify it belongs to the player
	var first_token = find_token_at_position(first_token_position)
	if !first_token or first_token.owner_id != player_id:
		return
	
	# Process the token swap
	swap_energy_tokens(first_token_position, second_token_position)
	print("Server processed token swap between: " + str(first_token_position) + " and " + str(second_token_position))

func swap_energy_tokens(first_token_position: Vector3, second_token_position: Vector3):
	# Find both tokens
	var first_token = find_token_at_position(first_token_position)
	var second_token = find_token_at_position(second_token_position)
	
	if !first_token or !second_token:
		print("One or both tokens not found")
		return
	
	# Verify both are energy tokens in the same biome
	if !first_token.is_energy or !second_token.is_energy or first_token.biome_type != second_token.biome_type:
		print("Invalid swap: Both must be energy tokens in the same biome")
		return
	
	# Get the placements
	var first_placement = get_token_placement_at_position(first_token_position)
	var second_placement = get_token_placement_at_position(second_token_position)
	
	if !first_placement or !second_placement:
		print("One or both placements not found")
		return
	
	# Store token data to swap
	var first_token_owner = first_token.owner_id
	var second_token_owner = second_token.owner_id
	var first_token_blighted = first_token.is_blighted
	var second_token_blighted = second_token.is_blighted
	
	# Update tokens with swapped data
	first_token.owner_id = second_token_owner
	second_token.owner_id = first_token_owner
	first_token.is_blighted = second_token_blighted
	second_token.is_blighted = first_token_blighted
	
	# Update visual appearance to match new owners and blight states
	#first_token.update_appearance()
	#second_token.update_appearance()
	
	# Sync to all clients
	rpc("sync_energy_token_swap", first_token_position, second_token_position, 
		first_token_owner, second_token_owner, 
		first_token_blighted, second_token_blighted)
	
	# Always unhighlight after swap
	unhighlight_all_token_placements()

@rpc("any_peer", "call_local")
func sync_energy_token_swap(first_token_position: Vector3, second_token_position: Vector3, 
						   first_token_owner: int, second_token_owner: int,
						   first_token_blighted: bool, second_token_blighted: bool):
	print("Syncing token swap between: " + str(first_token_position) + " and " + str(second_token_position))
	
	# Find both tokens
	var first_token = find_token_at_position(first_token_position)
	var second_token = find_token_at_position(second_token_position)
	
	if !first_token or !second_token:
		print("One or both tokens not found for swap sync")
		return
	
	# Swap owner IDs
	first_token.owner_id = second_token_owner
	second_token.owner_id = first_token_owner
	
	# Swap blight states
	first_token.is_blighted = second_token_blighted
	second_token.is_blighted = first_token_blighted
	
	# Update visual appearance
	#first_token.update_appearance()
	#second_token.update_appearance()
	
	# Reset swap mode
	is_swap_energy_mode = false
	if first_swap_token:
		first_swap_token.highlight(false)
		first_swap_token = null
	
	# Always unhighlight token placements after any token action
	unhighlight_all_token_placements()


## Refresh Energy
func request_refresh_energy(token_position: Vector3):
	if !multiplayer.is_server():
		return
	
	var player_id = multiplayer.get_remote_sender_id()
	if player_id == 0:  # Local server call
		player_id = multiplayer.get_unique_id()
	
	# Validate it's the player's turn
	if !game_state_manager.is_valid_player_turn(player_id):
		return
	
	# Process the token removal
	refresh_energy(token_position)
	print("Server processed token removal at: " + str(token_position))

func refresh_energy(token_position: Vector3):
	# Find the token at this position
	var token = null
	for t in get_parent().get_node("Tokens").get_children():
		if t.global_position == token_position:  # More generous distance check
			token = t
			break
	
	if token:
		print("Refresh energy token at position: " + str(token_position))
		var player_id = token.owner_id
		var biome_type = token.biome_type
		
		token.is_blighted = !token.is_blighted
		
		# Play animation on the server
		if token.is_blighted:
			token.animation_player.play("blight")
		else:
			token.animation_player.play("unblight")
		
		# IMPORTANT: Sync to all clients using RPC with POSITION
		rpc("sync_token_blight", token.global_position, token.is_blighted)
		
		# Always unhighlight token placements after any token action
		unhighlight_all_token_placements()
	
	else:
		print("No token found at position: " + str(token_position))

## Take OFF
@rpc("any_peer")
func request_take_off_energy(token_position: Vector3):
	if !multiplayer.is_server():
		return
	
	var player_id = multiplayer.get_remote_sender_id()
	if player_id == 0:  # Local server call
		player_id = multiplayer.get_unique_id()
	
	# Validate it's the player's turn
	if !game_state_manager.is_valid_player_turn(player_id):
		return
	
	# Process the token removal
	take_off_energy(token_position)
	print("Server processed token removal at: " + str(token_position))

func take_off_energy(token_position: Vector3):
	# Find the token at this position
	var token = null
	for t in get_parent().get_node("Tokens").get_children():
		if t.global_position == token_position:  # More generous distance check
			token = t
			break
	
	if token:
		print("Removing token at position: " + str(token_position))
		var player_id = token.owner_id
		var biome_type = token.biome_type
		
		# Get the token placement
		var placement = get_token_placement_at_position(token.global_position)
		
		# Mark the placement as available again
		if placement:
			placement.set_occupied(false)
			placement.current_token = null
		
		# Add a token back to the player's pool
		if player_id != -1:
			add_token_to_player(player_id, biome_type)
		
		# Remove the token
		token.queue_free()
		
		# IMPORTANT: Sync to all clients using RPC on this node, not the parent
		rpc("sync_token_removal_at_position", token_position, player_id, biome_type)
		
		# Update tokens UI for all players
		var players = get_parent().players
		for pid in players:
			var updated_tokens = get_player_tokens(pid)
			if pid == multiplayer.get_unique_id():
				sync_player_tokens(updated_tokens)  # Direct call for server
			else:
				rpc_id(pid, "sync_player_tokens", updated_tokens)  # RPC for clients
	else:
		print("No token found at position: " + str(token_position))

@rpc("any_peer", "call_local")
func sync_token_removal_at_position(token_position: Vector3, player_id: int, biome_type: int):
	print("Syncing token removal at: " + str(token_position))
	
	# Find the token at this position
	var token = null
	for t in get_parent().get_node("Tokens").get_children():
		if t.global_position == token_position:  # More generous distance check
			token = t
			break
	
	if token:
		# Get the token placement
		var placement = get_token_placement_at_position(token.global_position)
		
		# Mark the placement as available again
		if placement:
			placement.set_occupied(false)
			placement.current_token = null
		
		# Remove the token
		token.queue_free()
		
		# Update UI if this is for the local player
		if player_id == multiplayer.get_unique_id():
			update_token_ui()
	else:
		print("No token found at position for removal sync: " + str(token_position))
	
	# Always unhighlight token placements after any token action
	unhighlight_all_token_placements()
	
	# Reset remove and blight modes
	is_take_off_mode = false
	is_unblight_mode = false
	
	# Reset button visual states
	var remove_button = get_parent().get_node("RightUI/RemoveButton")
	var blight_button = get_parent().get_node("RightUI/BlightButton")
	
	if remove_button:
		remove_button.modulate = Color(1, 1, 1, 1)
	if blight_button:
		blight_button.modulate = Color(1, 1, 1, 1)

## Unblight 
@rpc("any_peer")
func request_unblight_token(token_position: Vector3):
	if !multiplayer.is_server():
		return
	print("request token blight")
	var player_id = multiplayer.get_remote_sender_id()
	if player_id == 0:  # Local server call
		player_id = multiplayer.get_unique_id()
	
	# Validate it's the player's turn
	if !game_state_manager.is_valid_player_turn(player_id):
		return
	
	# Process the token blighting
	unblight_token(token_position)
	print("Server processed token blight at: " + str(token_position))

func unblight_token(token_position):
	# Find the token at this position
	print("token position : ", token_position)
	var token = null
	for t in get_parent().get_node("Tokens").get_children():
		if t.global_position == token_position :  # More generous distance check
			token = t
			break
	
	if token:
		print("process token blight")
		print('token name : ', token)
		print("Blighting token at position: " + str(token.global_position))
		# Toggle blight status
		token.is_blighted = !token.is_blighted
		
		# Play animation on the server
		if token.is_blighted:
			token.animation_player.play("blight")
		else:
			token.animation_player.play("unblight")
		
		# IMPORTANT: Sync to all clients using RPC with POSITION
		rpc("sync_token_blight", token.global_position, token.is_blighted)
		
		# Always unhighlight token placements after any token action
		unhighlight_all_token_placements()
		
	else:
		print("No token found")


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

@rpc("any_peer", "call_local")
func sync_player_tokens(tokens_data, target_player_id: int = -1):
	print("Sync player tokens called with ", tokens_data.size(), " tokens, target=", target_player_id)
	
	var player_id = multiplayer.get_unique_id()
	
	# Only update if this is for our player ID
	if target_player_id == -1 || player_id == target_player_id:
		# Update the local token data
		player_tokens[player_id] = tokens_data.duplicate()
		
		print("Updated token count for player ", player_id, 
			  " to ", player_tokens[player_id].size())
		
		# Update token count UI
		var token_button = get_parent().get_node("RightUI/TokenButton")
		if token_button:
			token_button.text = "Tokens: " + str(tokens_data.size())
			token_button.disabled = tokens_data.size() <= 0 || !game_state_manager.is_valid_player_turn(player_id) || tokens_planted_this_turn.get(player_id, 0) >= max_tokens_per_turn
		
		# Update UI
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
		
		# Ensure the animation plays on the client
		if is_blighted:
			token.animation_player.play("blight")
		else:
			token.animation_player.play("unblight")
		
		# Always unhighlight token placements after any token action
		unhighlight_all_token_placements()
		
		# Reset remove and blight modes
		is_take_off_mode = false
		is_unblight_mode = false
		
		# Reset button visual states
		var remove_button = get_parent().get_node("RightUI/RemoveButton")
		var blight_button = get_parent().get_node("RightUI/BlightButton")
		
		if remove_button:
			remove_button.modulate = Color(1, 1, 1, 1)
		if blight_button:
			blight_button.modulate = Color(1, 1, 1, 1)
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

func sync_existing_game_state(new_peer_id: int):
	# Sync tokens
	var tokens_data = []
	for token in get_parent().get_node("Tokens").get_children():
		tokens_data.append({
			"biome": token.biome_type,
			"type": token.token_type,
			"position": token.global_position
		})
	
	# Sync occupied locations
	var occupied_locations = []
	for placement in get_parent().get_node("TokenPlacements").get_children():
		if placement.is_occupied:
			occupied_locations.append(placement.global_position)
	
	get_parent().rpc_id(new_peer_id, "receive_game_state", tokens_data, occupied_locations)

@rpc("any_peer", "call_local")
func receive_game_state(tokens_data: Array, occupied_locations: Array):
	#print("Receiving game state")
	
	# Clear existing tokens
	for token in get_parent().get_node("Tokens").get_children():
		token.queue_free()
	
	# Recreate tokens
	for token_info in tokens_data:
		var token = token_scene.instantiate()
		get_parent().get_node("Tokens").add_child(token,true)
		token.set_token_data(token_info.biome, token_info.type)
		token.global_position = token_info.position
	
	# Mark occupied locations
	for pos in occupied_locations:
		var placement = get_token_placement_at_position(pos)
		if placement:
			placement.set_occupied(true)

func distribute_initial_tokens_to_client(peer_id: int):
	if !multiplayer.is_server():
		return
		
	#print("Distributing initial tokens to client: ", peer_id)
	initialize_player_tokens(peer_id)
	var tokens = get_player_tokens(peer_id)
	rpc_id(peer_id, "sync_player_tokens", tokens)
	#print("Sent initial tokens to client: ", tokens)

func sync_complete_token_state():
	if !multiplayer.is_server():
		return
	
	print("Syncing complete token state to all clients")
	
	# 1. Sync token counts for all players
	var players = get_parent().players
	for pid in players:
		var tokens = get_player_tokens(pid)
		player_token_counts[pid] = tokens.size()
		print("Player ", pid, " has ", tokens.size(), " tokens")
		rpc("sync_player_tokens", tokens, pid)
	
	# 2. Sync token placements
	var placement_data = []
	for placement in get_parent().get_node("TokenPlacements").get_children():
		if placement.is_occupied:
			placement_data.append({
				"position": placement.global_position,
				"occupied": true
			})
	
	# 3. Sync actual tokens
	var token_data = []
	for token in get_parent().get_node("Tokens").get_children():
		token_data.append({
			"position": token.global_position,
			"biome": token.biome_type,
			"owner": token.owner_id,
			"is_energy": token.is_energy,
			"is_blighted": token.is_blighted
		})
	
	# Send comprehensive sync to all players
	rpc("receive_complete_token_state", placement_data, token_data)

@rpc("any_peer", "call_local")
func receive_complete_token_state(placement_data: Array, token_data: Array):
	print("Received complete token state")
	
	# 1. Update placement occupied states
	for placement_info in placement_data:
		var placement = get_token_placement_at_position(placement_info.position)
		if placement:
			placement.set_occupied(placement_info.occupied)
	
	# 2. Remove all existing tokens and recreate from data
	for token in get_parent().get_node("Tokens").get_children():
		token.queue_free()
	
	# Wait a frame to ensure tokens are fully removed
	await get_tree().process_frame
	
	# 3. Recreate tokens from received data
	for token_info in token_data:
		var token = token_scene.instantiate()
		get_parent().get_node("Tokens").add_child(token, true)
		token.set_token_data(token_info.biome, token_info.owner, token_info.is_energy)
		token.is_blighted = token_info.is_blighted
		token.global_position = token_info.position
		
		# Connect token to its placement
		var placement = get_token_placement_at_position(token_info.position)
		if placement:
			token.token_placement = placement
			placement.current_token = token
	
	# 4. Update UI
	update_token_ui()

@rpc("any_peer", "call_local")
func sync_all_token_placements(token_placement_data: Array):
	print("Received token placement sync with ", token_placement_data.size(), " tokens")
	
	# Clear existing tokens
	for token in get_parent().get_node("Tokens").get_children():
		token.queue_free()
	
	# Clear placement occupied states
	for placement in get_parent().get_node("TokenPlacements").get_children():
		placement.set_occupied(false)
		placement.current_token = null
	
	# Wait a frame to ensure tokens are cleared
	await get_tree().process_frame
	
	# Recreate tokens from data
	for token_info in token_placement_data:
		var token = token_scene.instantiate()
		get_parent().get_node("Tokens").add_child(token, true)
		
		# Set token data
		token.set_token_data(token_info.biome, token_info.owner, token_info.is_energy)
		token.global_position = token_info.position
		
		# Connect to placement
		var placement = get_token_placement_at_position(token_info.position)
		if placement:
			placement.set_occupied(true)
			placement.current_token = token
			token.token_placement = placement
	
	# Update UI
	update_token_ui()


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Helper Functions
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func get_token_placement_at_position(pos: Vector3) -> Node:
	for placement in get_parent().get_node("TokenPlacements").get_children():
		if placement.global_position.distance_to(pos) < 0.1:
			print("Found token placement at ", pos, " with place_id: ", placement.place_id)
			return placement
	print("No token placement found at ", pos)
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
	
	# For the host in server mode, always allow token placement
	var is_my_turn = false
	if multiplayer.is_server() && get_parent().game_started:
		is_my_turn = game_state_manager.is_valid_player_turn(player_id)
	else:
		is_my_turn = game_state_manager.is_valid_player_turn(player_id)
	
	# Get token count
	var tokens = get_player_tokens(player_id)
	var token_count = tokens.size()
	
	# Check tokens planted this turn
	if !tokens_planted_this_turn.has(player_id):
		tokens_planted_this_turn[player_id] = 0
	
	# Check if player has reached max tokens for this turn
	var max_tokens_reached = tokens_planted_this_turn[player_id] >= max_tokens_per_turn
	
	# Update button text with current token count
	token_button.text = "Tokens: " + str(token_count)
	
	# Token button is always visible for local player
	token_button.visible = true
	
	# But only enabled during their turn, if they have tokens, and haven't reached max tokens
	token_button.disabled = !is_my_turn || token_count <= 0 || max_tokens_reached
	
	# Visual feedback for selection state
	if is_token_selected:
		token_button.modulate = Color(1.2, 1.2, 0.8, 1)
	else:
		token_button.modulate = Color(1, 1, 1, 1)
	
	print("Token UI updated - Button disabled: " + str(token_button.disabled) + 
		  ", Is my turn: " + str(is_my_turn) + 
		  ", Token count: " + str(token_count) +
		  ", Tokens planted this turn: " + str(tokens_planted_this_turn[player_id]) +
		  ", Max tokens reached: " + str(max_tokens_reached))

func save_player_token_count(player_id: int):
	var tokens = get_player_tokens(player_id)
	player_token_counts[player_id] = tokens.size()
	print("Saved token count for player ", player_id, ": ", tokens.size())

func reset_token_buttons():
	var token_button = get_parent().get_node("RightUI/TokenButton")
	# Reset token button state
	if token_button:
		# Disconnect any existing signals
		if token_button.pressed.is_connected(_on_token_selected):
			token_button.pressed.disconnect(_on_token_selected)
			
		# Reset button state
		token_button.button_pressed = false  
		token_button.disabled = true
		token_button.visible = true  # Keep it visible
		token_button.modulate = Color(0.5, 0.5, 0.5, 0.5)
		
		# Reset token selection state
		is_token_selected = false

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
	if !game_state_manager.is_valid_player_turn(player_id):
		return
	
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

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Phase Management
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Enable only sigil placement locations
func enable_sigil_placement():
	is_token_selected = true
	
	# Unhighlight all first
	unhighlight_all_token_placements()
	
	# Highlight only sigil locations (place_id == -1)
	for placement in get_parent().get_node("TokenPlacements").get_children():
		if !placement.is_occupied and placement.place_id == -1:
			placement.set_highlight(true)
	
	# Update the UI
	update_token_ui()

# Enable only biome placement locations
func enable_biome_placement():
	is_token_selected = true
	
	# Unhighlight all first
	unhighlight_all_token_placements()
	
	# Highlight only biome locations (place_id != -1)
	for placement in get_parent().get_node("TokenPlacements").get_children():
		if !placement.is_occupied and placement.place_id != -1:
			placement.set_highlight(true)
	
	# Update the UI
	update_token_ui()

# Disable sigil placement
func disable_sigil_placement():
	if is_token_selected:
		is_token_selected = false
		unhighlight_all_token_placements()
		update_token_ui()

# Disable biome placement
func disable_biome_placement():
	if is_token_selected:
		is_token_selected = false
		unhighlight_all_token_placements()
		update_token_ui()
