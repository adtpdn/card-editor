# token_manager.gd
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
@onready var dice_manager = $"../DiceManager"
@onready var point_counter = $"../PointCounter"

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

# Add variables for token removal and blighting
var is_remove := false
var is_blight_mode := false

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

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Initialization
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
	
	# Connect remove and blight buttons
	var remove_button = get_parent().get_node("RightUI/RemoveButton")
	var blight_button = get_parent().get_node("RightUI/BlightButton")
	
	if remove_button:
		if remove_button.pressed.is_connected(_on_remove_token_pressed):
			remove_button.pressed.disconnect(_on_remove_token_pressed)
		remove_button.pressed.connect(_on_remove_token_pressed)
	
	if blight_button:
		if blight_button.pressed.is_connected(_on_blight_token_pressed):
			blight_button.pressed.disconnect(_on_blight_token_pressed)
		blight_button.pressed.connect(_on_blight_token_pressed)

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

# ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
# ---   Player Token Management ---
# ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

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

func remove_token(player_id: int, token_index: int):
	if player_tokens.has(player_id) and token_index >= 0 and token_index < player_tokens[player_id].size():
		player_tokens[player_id].remove_at(token_index)
		return true
	return false

func set_player_tokens(player_id: int, tokens: Array):
	if tokens == null:
		tokens = []
	player_tokens[player_id] = tokens.duplicate()

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

# ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
# ---   Token Synchronization  ---
# ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

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

# ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
# ---  Token Placement Setup   ---
# ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

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

# ╭──────────────────────────────╮
# |  Token - Slice Position Gen  |
# ╰──────────────────────────────╯
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

# ╭──────────────────────────────╮
# |  Token - Biome Border Gen    |
# ╰──────────────────────────────╯

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

# ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
# ---    Token UI & Selection  ---
# ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

func setup_token_ui():
	var token_button = get_parent().get_node("RightUI/TokenButton")
	# Clear any existing connections
	if token_button.pressed.is_connected(_on_token_selected):
		token_button.pressed.disconnect(_on_token_selected)
		
	# Connect the token selection function
	token_button.pressed.connect(_on_token_selected)
	
	# Initialize the UI state
	update_token_ui()

func update_token_ui():
	var token_button = get_parent().get_node("RightUI/TokenButton")
	if !token_button:
		return
		
	var player_id = multiplayer.get_unique_id()
	
	# For the host in server mode, always allow token placement
	var is_my_turn = false
	if multiplayer.is_server() && get_parent().game_started:
		is_my_turn = true
	else:
		is_my_turn = game_state_manager.is_valid_player_turn(player_id)
	
	# Get token count
	var tokens = get_player_tokens(player_id)
	var token_count = tokens.size()
	
	# Update button text with current token count
	token_button.text = "Tokens: " + str(token_count)
	
	# Token button is always visible for local player
	token_button.visible = true
	
	# But only enabled during their turn and if they have tokens
	token_button.disabled = !is_my_turn || token_count <= 0
	
	# Visual feedback for selection state
	if is_token_selected:
		token_button.modulate = Color(1.2, 1.2, 0.8, 1)
	else:
		token_button.modulate = Color(1, 1, 1, 1)
	
	print("Token UI updated - Button disabled: " + str(token_button.disabled) + 
		  ", Is my turn: " + str(is_my_turn) + 
		  ", Token count: " + str(token_count))

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
	
	# Toggle selection state
	is_token_selected = !is_token_selected
	print("Token selection mode: " + str(is_token_selected))
	
	if is_token_selected:
		# Highlight all unoccupied placement locations
		for placement in get_parent().get_node("TokenPlacements").get_children():
			if !placement.is_occupied:
				placement.set_highlight(true)
	else:
		# Unhighlight all placements
		unhighlight_all_token_placements()
	
	# Update UI to show selection state
	update_token_ui()
	debug_token_state()

func unhighlight_all_token_placements():
	for placement in get_parent().get_node("TokenPlacements").get_children():
		placement.set_highlight(false)

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

# ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
# ---  Token Placement Logic   ---
# ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

func get_token_placement_at_position(pos: Vector3) -> Node:
	for placement in get_parent().get_node("TokenPlacements").get_children():
		if placement.global_position.distance_to(pos) < 0.1:
			#print("Found token placement at ", pos)
			return placement
	#print("No token placement found at ", pos)
	return null

@rpc("any_peer")
func request_token_placement(token_index: int, position: Vector3, biome_type: int):
	if !multiplayer.is_server():
		return
		
	var player_id = multiplayer.get_remote_sender_id()
	if player_id == 0:  # If this is a local server request
		player_id = multiplayer.get_unique_id()
	
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
			
			# Update server's token manager
			remove_token(player_id, token_index)
			
			# Important: Sync the placement to ALL clients including the requester
			rpc("sync_token_placement", player_id, token_data, position)
			
			# Update tokens for all players
			var players = get_parent().players
			for pid in players:
				var updated_tokens = get_player_tokens(pid)
				rpc_id(pid, "sync_player_tokens", updated_tokens)

@rpc("any_peer", "call_local")
func sync_token_placement(player_id: int, token_data: Dictionary, position: Vector3):
	var placement = get_token_placement_at_position(position)
	if !placement:
		return
	
	# Check if occupied
	if placement.is_occupied:
		return
	
	# Create and place the token
	var token = token_scene.instantiate()
	get_parent().get_node("Tokens").add_child(token, true)
	
	# Convert types explicitly
	var biome_type = int(token_data.biome) if token_data.has("biome") else placement.accepted_biome
	
	# Check if this is an energy placement (one of the first 28 placements)
	var placement_index = placement.get_index()
	var is_energy = placement_index < 28
	
	# Call the updated set_token_data with biome, player id, and energy status
	token.set_token_data(biome_type, player_id, is_energy)
	token.global_position = position
	
	# Store reference to the placement in the token
	token.token_placement = placement
	
	# Mark placement as occupied and store token reference
	placement.set_occupied(true)
	placement.current_token = token  # Store reference to the token
	
	# Reset selection state
	is_token_selected = false
	unhighlight_all_token_placements()
	
	# Update UI for the current player regardless of host/client status
	var local_id = multiplayer.get_unique_id()
	var players = get_parent().players
	var current_turn_index = get_parent().game_state_manager.current_turn_index
	
	if local_id == players[current_turn_index]:
		update_token_ui()
	
	# After placing the token, update the saved count
	if multiplayer.is_server():
		var updated_tokens = get_player_tokens(player_id)
		player_token_counts[player_id] = updated_tokens.size()

# ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
# ---   Token Remove / Blight  ---
# ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

func _on_remove_token_pressed():
	is_remove = true
	is_blight_mode = false  # Disable blight mode if active
	print("Remove mode activated")
	
	# Visual feedback for active mode
	var remove_button = get_parent().get_node("RightUI/RemoveButton")
	var blight_button = get_parent().get_node("RightUI/BlightButton")
	
	if remove_button:
		remove_button.modulate = Color(1.2, 0.8, 0.8, 1)  # Highlight in red
	if blight_button:
		blight_button.modulate = Color(1, 1, 1, 1)  # Reset blight button
		
	# Ensure token selection mode is off
	is_token_selected = false
	unhighlight_all_token_placements()
	update_token_ui()

func _on_blight_token_pressed():
	is_blight_mode = true
	is_remove = false  # Disable remove mode if active
	print("Blight mode activated")
	
	# Visual feedback for active mode
	var remove_button = get_parent().get_node("RightUI/RemoveButton")
	var blight_button = get_parent().get_node("RightUI/BlightButton")
	
	if blight_button:
		blight_button.modulate = Color(0.8, 0.8, 1.2, 1)  # Highlight in blue
	if remove_button:
		remove_button.modulate = Color(1, 1, 1, 1)  # Reset remove button
		
	# Ensure token selection mode is off
	is_token_selected = false
	unhighlight_all_token_placements()
	update_token_ui()

@rpc("any_peer")
func request_token_removal(token_position: Vector3):
	if !multiplayer.is_server():
		return
	
	var player_id = multiplayer.get_remote_sender_id()
	if player_id == 0:  # Local server call
		player_id = multiplayer.get_unique_id()
	
	# Validate it's the player's turn
	if !game_state_manager.is_valid_player_turn(player_id):
		return
	
	# Process the token removal
	process_token_removal(token_position)
	print("Server processed token removal at: " + str(token_position))

func process_token_removal(token_position: Vector3):
	# Find the token at this position
	var token = null
	for t in get_parent().get_node("Tokens").get_children():
		if t.global_position.distance_to(token_position) < 1.0:  # More generous distance check
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

@rpc("any_peer")
func request_token_blight(token_position: Vector3):
	if !multiplayer.is_server():
		return
	
	var player_id = multiplayer.get_remote_sender_id()
	if player_id == 0:  # Local server call
		player_id = multiplayer.get_unique_id()
	
	# Validate it's the player's turn
	if !game_state_manager.is_valid_player_turn(player_id):
		return
	
	# Process the token blighting
	process_token_blight(token_position)
	print("Server processed token blight at: " + str(token_position))

func process_token_blight(token_position: Vector3):
	# Find the token at this position
	var token = null
	for t in get_parent().get_node("Tokens").get_children():
		if t.global_position.distance_to(token_position) < 1.0:  # More generous distance check
			token = t
			break
	
	if token:
		print("Blighting token at position: " + str(token_position))
		# Toggle blight status
		token.is_blighted = !token.is_blighted
		token.update_token_display()
		
		# IMPORTANT: Sync to all clients using RPC on this node, not the parent
		rpc("sync_token_blight", token_position, token.is_blighted)
		
		# Always unhighlight token placements after any token action
		unhighlight_all_token_placements()
		
		# Reset remove and blight modes
		is_remove = false
		is_blight_mode = false
		
		# Reset button visual states
		var remove_button = get_parent().get_node("RightUI/RemoveButton")
		var blight_button = get_parent().get_node("RightUI/BlightButton")
		
		if remove_button:
			remove_button.modulate = Color(1, 1, 1, 1)
		if blight_button:
			blight_button.modulate = Color(1, 1, 1, 1)
	else:
		print("No token found at position: " + str(token_position))

@rpc("any_peer", "call_local")
func sync_token_blight(token_position: Vector3, is_blighted: bool):
	print("Syncing token blight at: " + str(token_position) + ", blighted: " + str(is_blighted))
	
	# Find the token at this position
	var token = null
	for t in get_parent().get_node("Tokens").get_children():
		if t.global_position.distance_to(token_position) < 1.0:  # More generous distance check
			token = t
			break
	
	if token:
		token.is_blighted = is_blighted
		token.update_token_display()
		
		# Always unhighlight token placements after any token action
		unhighlight_all_token_placements()
		
		# Reset remove and blight modes
		is_remove = false
		is_blight_mode = false
		
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
func sync_token_removal_at_position(token_position: Vector3, player_id: int, biome_type: int):
	print("Syncing token removal at: " + str(token_position))
	
	# Find the token at this position
	var token = null
	for t in get_parent().get_node("Tokens").get_children():
		if t.global_position.distance_to(token_position) < 1.0:  # More generous distance check
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
	is_remove = false
	is_blight_mode = false
	
	# Reset button visual states
	var remove_button = get_parent().get_node("RightUI/RemoveButton")
	var blight_button = get_parent().get_node("RightUI/BlightButton")
	
	if remove_button:
		remove_button.modulate = Color(1, 1, 1, 1)
	if blight_button:
		blight_button.modulate = Color(1, 1, 1, 1)

# Add this function to your token_manager.gd script
@rpc("any_peer", "call_local")
func sync_player_tokens(tokens_data):
	var player_id = multiplayer.get_unique_id()
	player_tokens[player_id] = tokens_data.duplicate()
	
	# Update token count UI
	var token_button = get_parent().get_node("RightUI/TokenButton")
	if token_button:
		token_button.text = "Tokens: " + str(tokens_data.size())
		token_button.disabled = tokens_data.size() <= 0
	
	# Update token UI elements
	update_token_ui()
	update_token_indicators()
	
	# If we're in the middle of a token selection and there are no tokens_data left,
	# reset the selection state
	if is_token_selected and tokens_data.size() <= 0:
		is_token_selected = false
		selected_token_index = -1
		unhighlight_all_token_placements()
		
		# Update visual feedback for token button
		if token_button:
			token_button.modulate = Color(1, 1, 1, 1)  # Reset to normal color

# ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
# ---   Token Helper Methods   ---
# ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

func save_player_token_count(player_id: int):
	var tokens = get_player_tokens(player_id)
	player_token_counts[player_id] = tokens.size()
	print("Saved token count for player ", player_id, ": ", tokens.size())

func find_token_at_position(position: Vector3) -> Node:
	for token in get_parent().get_node("Tokens").get_children():
		if token.global_position.distance_to(position) < 0.1:
			return token
	return null

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

# Optional: Handle input for token selection/placement
func handle_touch(position: Vector2):
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_token_placement_time < TOKEN_PLACEMENT_COOLDOWN:
		return
	
	var player_id = multiplayer.get_unique_id()
	
	# Only check for turn validity in token placement mode
	if is_token_selected and !game_state_manager.is_valid_player_turn(player_id):
		print("Not your turn!")
		selected_token_biome = -1
		unhighlight_all_token_placements()
		return
	
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
		var hit_position = result["position"]
		
		# Find the token at this position with improved detection
		var found_token = null
		for token in get_parent().get_node("Tokens").get_children():
			var distance = token.global_position.distance_to(hit_position)
			print("Distance to token: " + str(distance))
			if distance < 1.0:  # More generous distance check
				found_token = token
				print("Found token at position: " + str(token.global_position))
				break
		
		if found_token:
			print("Processing token: " + str(found_token.name))
			if is_remove:
				print("Attempting to remove token")
				# Handle remove mode
				if multiplayer.is_server():
					process_token_removal(found_token.global_position)
				else:
					print("Sending removal request to server")
					rpc_id(1, "request_token_removal", found_token.global_position)
				
				# Reset remove mode after attempt
				is_remove = false
				
			elif is_blight_mode:
				print("Attempting to blight token")
				# Handle blight mode
				if multiplayer.is_server():
					process_token_blight(found_token.global_position)
				else:
					print("Sending blight request to server")
					rpc_id(1, "request_token_blight", found_token.global_position)
				
				# Reset blight mode after attempt
				is_blight_mode = false
				
			# Always unhighlight after any token action
			unhighlight_all_token_placements()
			
			# Reset button visual states
			var remove_button = get_parent().get_node("RightUI/RemoveButton")
			var blight_button = get_parent().get_node("RightUI/BlightButton")
			
			if remove_button:
				remove_button.modulate = Color(1, 1, 1, 1)
			if blight_button:
				blight_button.modulate = Color(1, 1, 1, 1)
		else:
			print("No token found at position")
			# Handle token placement if in token selection mode
			if is_token_selected:
				var placement = get_token_placement_at_position(hit_position)
				if placement and !placement.is_occupied:
					# Handle token placement
					var token_index = 0  # Use first available token
					
					# Update cooldown time
					last_token_placement_time = current_time
					
					# IMPORTANT: Pass the accepted_biome from the placement location
					var biome_type = placement.accepted_biome
					
					if multiplayer.is_server():
						request_token_placement(token_index, placement.global_position, biome_type)
					else:
						rpc_id(1, "request_token_placement", token_index, placement.global_position, biome_type)
					
					# Reset selection state
					is_token_selected = false
					unhighlight_all_token_placements()
