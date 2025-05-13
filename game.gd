extends Node

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Buttons 
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
@onready var remove_button = $RightUI/RemoveButton

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Multiplayer Dependencies
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

var multiplayer_peer = ENetMultiplayerPeer.new()
const PORT = 9999
const DEFAULT_IP = "127.0.0.1"  # Changed from ADDRESS constant

# Add to networking variables sections
var use_upnp = true  # Enable UPNP for mobile networking
var upnp_attempts = 0
const MAX_UPNP_ATTEMPTS = 10
var is_mobile = false
var local_ip = "127.0.0.1"
var is_host = false

# Add these networking variables
var peer_status = "Not Connected"
var last_error = ""
var connect_retries = 0
const MAX_CONNECT_RETRIES = 3

# Add these networking variables
const BROADCAST_PORT = 9998  # Port for network discovery
var broadcast_timer: Timer
var discovery_socket: PacketPeerUDP

# Add these UI-related variables
var ip_display_timer: Timer
var last_ip_refresh_time = 0.0
const IP_REFRESH_INTERVAL = 5.0  # Refresh IPs every 5 seconds

# Add these constants at the top with other networking variables
const BROADCAST_ADDRESS = "255.255.255.255"
var broadcast_enabled = false

# Add these networking variables at the top
var broadcast_socket: PacketPeerUDP
var listen_socket: PacketPeerUDP
const SERVER_BROADCAST_INTERVAL = 1.0

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Multiplayer variables
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

var connected_peer_ids = []
var current_turn_index = 0
var players = []
var game_started = false
var max_players = 4  # Maximum players allowed
var player_hands = {}  # Store each player's hand data
var player_slots = []  # Track occupied player slots
var player_colors = {}  # Mapping of player IDs to colors

const PLAYER_COLORS = [
	Color(1, 0, 0),     # Red
	Color(0, 1, 0),     # Green
	Color(0, 0, 1),     # Blue
	Color(1, 1, 0)      # Yellow
]

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Card System Dependencies
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

@onready var player_hand = $HandAreas/PlayerHand
@onready var action_deck = $DeckLocations/ActionDeck
@onready var area_deck = $DeckLocations/AreaDeck
@onready var action_area = $PlantingLocations/ActionArea
@onready var area_zone = $PlantingLocations/AreaZone

const MAX_ACTION_CARDS = 2
const MAX_AREA_CARDS = 2

var deck: Array[CardResource] = [] # Structure to track placed cards
var placed_cards = []  # Array of dictionaries containing placement info

const INITIAL_HAND_SIZE = {
	"action": 2,  # Adjust these numbers as needed
	"area": 2
}

# Make sure these are consistent with the card types in CardResource
const CARD_TYPES = {
	"ACTION": 0,
	"AREA": 1
}

const INITIAL_ACTION_CARDS = 2
const INITIAL_AREA_CARDS = 2

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Token System Dependencies
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

@onready var token_manager: TokenManager = $TokenManager
var selected_token_index = -1
var current_selected_button: Button = null

# Modify token selection handling to use both biome and type
var selected_token_biome = -1
var selected_token_node

# Modified token button container setup
@onready var token_button  = $RightUI/TokenButton  # Change from TokenContainer to TokenGrid
@onready var player_token_indicators = $RightUI/PlayerTokenIndicators

# Remove token type selection tracking - just track if tokens are selected
var is_token_selected = false

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Biome System Dependencies
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
var radius = 4.0  # Radius of the octagon
var borders_node: Node3D
var biome_assignments = {
	TokenManager.BiomeType.FOREST: [0, 1],    # Slices 0 and 1
	TokenManager.BiomeType.WATER: [2, 3],    # Slices 2 and 3
	TokenManager.BiomeType.MOUNTAIN: [4, 5],  # Slices 4 and 5
	TokenManager.BiomeType.DESERT: [6, 7]      # Slices 6 and 7
}

# Add these color definitions if not already in TokenManager
const BIOME_COLORS = {
	TokenManager.BiomeType.FOREST: Color(0.2, 0.8, 0.2, 1.0),    # Green
	TokenManager.BiomeType.WATER: Color(0.2, 0.2, 0.8, 1.0),      # Blue
	TokenManager.BiomeType.MOUNTAIN: Color(0.5, 0.5, 0.5, 1.0),  # Gray
	TokenManager.BiomeType.DESERT: Color(0.8, 0.8, 0.2, 1.0)   # Yellow
}

const TOKEN_PLACEMENT_COOLDOWN = 0.5  # 500ms cooldown
var last_token_selection_time = 0.0
var last_token_placement_time = 0.0

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Point System Dependencies
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

var last_point_adjustment_time = 0.0
const POINT_ADJUSTMENT_COOLDOWN = 0.25  # 250ms cooldown

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Dice Dependencies
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

@onready var dice_manager: Node3D = $DiceManager
@onready var point_counter = $PointCounter
@onready var roll_result_label = $RightUI/RollResultLabel

# Add new UI references
@onready var ip_input = $RightUI/Menu/IPInput
@onready var connect_status = $RightUI/Menu/ConnectStatus

# Add touch handling variables
var touch_start_position = Vector2()
var touch_threshold = 10  # pixels for drag detection
var is_dragging = false

# Add these new variables at the top
@onready var player_list = $LeftUI/PlayerList
@onready var start_game_button = $LeftUI/StartGameButton


var player_token_counts = {}  # Dictionary to store token counts per player

var is_remove := false

# ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
# ---    _Ready Initiation     ---
# ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
func _ready() -> void:
	# Create the borders node first
	borders_node = Node3D.new()
	borders_node.name = "BiomeBorders"
	add_child(borders_node)
	
	# Token Button
	token_button.pressed.connect(_on_token_selected)
	token_button.visible = true  # Always visible, but disabled by default
	token_button.disabled = true
	
	# Set up planting locations
	action_area.accepted_card_types = PackedInt32Array([CardResource.CardType.ACTION])
	action_area.location_name = "Action Area"
	
	area_zone.accepted_card_types = PackedInt32Array([CardResource.CardType.AREA])
	area_zone.location_name = "Area Zone"
	
	action_area.card_placed.connect(_on_card_placed)
	area_zone.card_placed.connect(_on_card_placed)
	
	# Set up the hand
	player_hand = $HandAreas/PlayerHand
	player_hand.set_interaction_enabled(false)
	# Token Manager Initiated

	token_manager = TokenManager.new()
	add_child(token_manager)
	
	# Setup token placement locations
	await setup_token_placements()
	await setup_biome_borders()
	
	# Connect signals
	action_deck.card_drawn.connect(_on_action_card_drawn)
	area_deck.card_drawn.connect(_on_area_card_drawn)
	$RightUI/Menu/HostButton.pressed.connect(_on_host_pressed)
	$RightUI/Menu/JoinButton.pressed.connect(_on_join_pressed)
	$RightUI/EndTurnButton.pressed.connect(_on_end_turn_pressed)
	$RightUI/RemoveButton.pressed.connect(_on_remove_token_pressed)
	
	# Setup multiplayer
	multiplayer_peer.peer_connected.connect(_on_peer_connected)
	multiplayer_peer.peer_disconnected.connect(_on_peer_disconnected)

	# Turn off the end turn button
	$RightUI/EndTurnButton.disabled = true
	
	# Dice Manager Initiated
	dice_manager.roll_completed.connect(_on_dice_roll_completed)
	
	# Camera setup
	# var camera = $Camera3D
	
	# Set up area picking
	_setup_area_picking(action_area)
	_setup_area_picking(area_zone)
	
	# Multiplayer setup
	set_multiplayer_authority(1)
	
	# Point Counter
	if point_counter:
		point_counter.set_buttons_enabled(false)
		point_counter.sync_id = 1  # Give authority to the server
		if multiplayer.is_server():
			# Initial sync of points
			point_counter.rpc("sync_point_values", 
				point_counter.forest_points,
				point_counter.desert_points,
				point_counter.mountain_points,
				point_counter.water_points,
				point_counter.forest_magic_points,
				point_counter.desert_magic_points,
				point_counter.mountain_magic_points,
				point_counter.water_magic_points
			)
	
	# Token Buttons disabled by default
	token_button.disabled = true
	token_button.visible = false

	# Initialize player slots
	player_slots.resize(max_players)
	player_slots.fill(false)

	# Check if running on mobile
	is_mobile = OS.has_feature("mobile")
	if is_mobile:
		setup_mobile_ui()
		setup_mobile_network()
	
	# Get local IP for display
	local_ip = get_local_ip()

	if is_mobile:
		setup_network_discovery()
	
	# Connect the start game button
	start_game_button.pressed.connect(_on_start_game_pressed)
	
	# Hide the start game button initially
	start_game_button.visible = false

# ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
# ---    Host/Client Logic     ---
# ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

func _on_host_pressed():
	is_host = true
	connect_status.text = "Starting server..."
	
	# Get the first valid IP
	var host_ip = get_valid_ips()[0] if !get_valid_ips().is_empty() else "127.0.0.1"
	
	var error = multiplayer_peer.create_server(PORT)
	
	if error == OK:
		if is_mobile and use_upnp:
			if setup_upnp():
				connect_status.text += "\nUPnP setup successful"
			else:
				connect_status.text += "\nUPnP setup failed, port forwarding may be needed"
		
		$RightUI/NetworkInfo/NetworkSideDisplay.text = "Server"
		connect_status.text += "\nServer running on: " + host_ip + ":" + str(PORT)
		
		multiplayer.multiplayer_peer = multiplayer_peer
		var host_id = multiplayer.get_unique_id()
		
		# Initialize host data
		players = [host_id]  # Reset players array
		player_hands[host_id] = []
		player_colors[host_id] = PLAYER_COLORS[0]
		
		# Initialize game state
		token_manager.initialize_player_tokens(host_id)
		var tokens = token_manager.get_player_tokens(host_id)
		update_token_ui()
		distribute_initial_hand()
		setup_player(host_id)
		start_game()
		
		# Start broadcasting server info
		setup_network_discovery()
	else:
		connect_status.text = "Failed to create server: " + str(error)

func _on_join_pressed():
	is_host = false
	connect_retries = 0
	
	var target_ip = ip_input.text.strip_edges()
	if target_ip.is_empty() or target_ip == "127.0.0.1":
		connect_status.text = "Searching for local servers..."
		# Start discovery process
		if !discovery_socket:
			setup_network_discovery()
		_start_server_discovery()
	else:
		attempt_connection(target_ip)

# Modify attempt_connection
func attempt_connection(target_ip: String):
	if connect_retries >= MAX_CONNECT_RETRIES:
		connect_status.text = "Failed to connect after multiple attempts"
		return
	
	connect_retries += 1
	
	# Close existing connections
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer = null
	
	if multiplayer_peer:
		multiplayer_peer.close()
	
	multiplayer_peer = ENetMultiplayerPeer.new()
	
	print("Attempting to connect to: ", target_ip)
	connect_status.text = "Connecting to " + target_ip + "... (Attempt " + str(connect_retries) + ")"
	
	var error = multiplayer_peer.create_client(target_ip, PORT)
	print("error : ", error)
	if error == OK:
		multiplayer.multiplayer_peer = multiplayer_peer
		$RightUI/NetworkInfo/NetworkSideDisplay.text = "Client"
	else:
		connect_status.text = "Connection failed: " + str(error)
		# Retry after delay
		await get_tree().create_timer(1.0).timeout
		attempt_connection(target_ip)

func is_valid_ip(ip: String) -> bool:
	if ip.is_empty():
		return false
	var parts = ip.split(".")
	if parts.size() != 4:
		return false
	for part in parts:
		if !part.is_valid_int():
			return false
		var num = part.to_int()
		if num < 0 or num > 255:
			return false
	return true

func _on_peer_connected(new_peer_id):
	if multiplayer.is_server():
		await get_tree().create_timer(0.1).timeout
		
		# Check if game is full
		if players.size() >= max_players:
			# Disconnect the player if game is full
			multiplayer_peer.disconnect_peer(new_peer_id)
			return
			
		print("New peer connected: ", new_peer_id)
		players.append(new_peer_id)
		
		# Initialize new player's hand tracking
		player_hands[new_peer_id] = []
		
		# Assign a color to the new player
		var color_index = players.size() - 1
		if color_index < PLAYER_COLORS.size():
			player_colors[new_peer_id] = PLAYER_COLORS[color_index]
			# Sync colors to all clients including the new one
			rpc("sync_player_colors", player_colors)
		
		# Find first available slot
		var slot_index = player_slots.find(false)
		if slot_index != -1:
			player_slots[slot_index] = true
			
		# Sync game state to new player
		rpc_id(new_peer_id, "sync_game_state", players, game_started, placed_cards)
		
		# Initialize player's tokens and hand
		if game_started:
			distribute_initial_hand_to_client(new_peer_id)
		
		token_manager.initialize_player_tokens(new_peer_id)
		var player_tokens = token_manager.get_player_tokens(new_peer_id)
		rpc_id(new_peer_id, "sync_player_tokens", player_tokens)
		
		setup_player(new_peer_id)
		
		# Update the player list UI
		update_player_list()
		setup_player_token_indicators()

func _on_peer_disconnected(peer_id):
	if peer_id == null or peer_id == 0:  # Check for both null and invalid ID
		return
		
	#print("Peer disconnected: ", peer_id)
	if players.has(peer_id):
		var slot_index = players.find(peer_id)
		if slot_index != -1:
			player_slots[slot_index] = false
		players.erase(peer_id)
	
	# Clean up disconnected player's hand
	if player_hands.has(peer_id):
		player_hands.erase(peer_id)
	
	if multiplayer.is_server():
		rpc("remove_player", peer_id)
		
		# Update the player list UI
		update_player_list()
	setup_player_token_indicators()

func update_player_list():
	player_list.clear()
	for player_id in players:
		var player_name = "P_" + str(player_id)
		player_list.add_item(player_name)
	
	# Show the start game button if there are players
	start_game_button.visible = players.size() > 0

func _on_start_game_pressed():
	if multiplayer.is_server():
		var selected_index = player_list.get_selected_items()[0]
		if selected_index != -1:
			var first_player_id = players[selected_index]
			start_game_with_first_player(first_player_id)

func start_game_with_first_player(first_player_id):
	if multiplayer.is_server():
		game_started = true
		current_turn_index = players.find(first_player_id)
		if players.size() > 0:
			print("\n=== Starting Game ===")
			print("Initial players: ", players)
			print("Starting turn index: ", current_turn_index)
			
			# Sync game start to all clients
			rpc("sync_game_start", players)
			
			# Set initial turn
			print("First player: ", first_player_id)
			rpc("set_current_turn", first_player_id)
			
			print("=== Game Start Complete ===\n")
		else:
			print("No players available to start game")

# ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
# --- Control / Input Handling ---
# ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

## NO NEED FOR NOW
func _unhandled_input(event):
	if event is InputEventScreenTouch:
		if event.pressed:
			_handle_touch(event.position)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_touch(event.position)

func _handle_touch(position: Vector2):
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_token_placement_time < TOKEN_PLACEMENT_COOLDOWN:
		return
	
	var player_id = multiplayer.get_unique_id()
	
	# Check if it's player's turn
	if !is_valid_player_turn(player_id):
		print("Not your turn!")
		selected_token_biome = -1
		unhighlight_all_token_placements()
		return
	
	var camera = get_node("Camera3D")
	var from = camera.project_ray_origin(position)
	var to = from + camera.project_ray_normal(position) * 1000
	
	var space_state = get_tree().get_root().get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	var result = space_state.intersect_ray(query)
	
	# Process remove token if in remove mode
	if result and is_remove:
		var collider = result["collider"]
		var hit_position = result["position"]
		
		# Find the token at this position
		var found_token = null
		for token in $Tokens.get_children():
			if token.global_position.distance_to(hit_position) < 0.5:  # Generous distance check
				found_token = token
				break
		
		if found_token:
			# Request token removal
			if multiplayer.is_server():
				# Direct removal on server
				process_token_removal(found_token.global_position)
			else:
				# Client requests server
				rpc_id(1, "request_token_removal", found_token.global_position)
		
		# Reset remove mode after attempt
		is_remove = false
		
		#if result:
			#print("")
			#print("token placement")
			#var placement = get_token_placement_at_position(result.position)
			#if placement and !placement.is_occupied:
				#var tokens = token_manager.get_player_tokens(player_id)
				#
				## Find token data for selected biome and type
				#var token_data = null
				#var token_index = -1
				#for i in range(tokens.size()):
					#if tokens[i].biome == selected_token_biome and tokens[i].type == selected_token_type:
						#token_data = tokens[i]
						#token_index = i
						#break
				#
				#if token_data:
					#print("Found matching token data")
					## Update cooldown time
					#last_token_placement_time = current_time
					#
					#if multiplayer.is_server():
						## Server directly places token
						#token_manager.remove_token(player_id, token_index)
						#sync_token_placement(player_id, token_data, placement.global_position)
						#
						## Update UI for all players
						#for pid in players:
							#var updated_tokens = token_manager.get_player_tokens(pid)
							#rpc_id(pid, "sync_player_tokens", updated_tokens)
					#else:
						## Client requests placement
						#rpc_id(1, "request_token_placement", token_index, placement.global_position)
					#
					## Reset selection state
					#selected_token_biome = -1
					#selected_token_type = -1
					#unhighlight_all_token_placements()
				#else:
					#print("No matching token data found")


# ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
# ---   Token Logic Handling   ---
# ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

@rpc("any_peer", "call_local")
func sync_existing_tokens(tokens_data: Array):
	print("")
	print("Syncing existing tokens: ", tokens_data)
	
	# Clear existing tokens first
	for token in $Tokens.get_children():
		token.queue_free()
	
	# Recreate tokens from data
	for token_info in tokens_data:
		var token = token_manager.token_scene.instantiate()
		$Tokens.add_child(token,true)
		print("token info biome: ", token_info)
		token.set_token_data(token_info.biome, token_info.type)
		token.global_position = token_info.position
		
		var placement = get_token_placement_at_position(token_info.position)
		if placement:
			placement.set_occupied(true)

func sync_existing_game_state(new_peer_id: int):
	# Sync tokens
	var tokens_data = []
	for token in $Tokens.get_children():
		tokens_data.append({
			"biome": token.biome_type,
			"type": token.token_type,
			"position": token.global_position
		})
	
	# Sync occupied locations
	var occupied_locations = []
	for placement in $TokenPlacements.get_children():
		if placement.is_occupied:
			occupied_locations.append(placement.global_position)
	
	rpc_id(new_peer_id, "receive_game_state", tokens_data, occupied_locations)

@rpc("any_peer", "call_local")
func receive_game_state(tokens_data: Array, occupied_locations: Array):
	#print("Receiving game state")
	
	# Clear existing tokens
	for token in $Tokens.get_children():
		token.queue_free()
	
	# Recreate tokens
	for token_info in tokens_data:
		var token = token_manager.token_scene.instantiate()
		$Tokens.add_child(token,true)
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
	token_manager.initialize_player_tokens(peer_id)
	var tokens = token_manager.get_player_tokens(peer_id)
	rpc_id(peer_id, "sync_player_tokens", tokens)
	#print("Sent initial tokens to client: ", tokens)

func setup_token_placements():
	# Only set up if not already set up
	if $TokenPlacements.get_child_count() > 0:
		return
	
	await ready
	await get_tree().process_frame
	
	var token_placement_scene = preload("res://token_placement_location.tscn")
	
	# Clear existing placements
	for child in $TokenPlacements.get_children():
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
			$TokenPlacements.add_child(token_placement, true)
			token_placement.global_position = pos
			placements_per_biome[biome] += 1
	
	# Set the first 28 token placements as energy placements
	# We need to determine how many per biome (e.g., 7 per biome for 4 biomes)
	var energy_count = 0
	var energy_per_biome = 7  # 7 per biome x 4 biomes = 28 total
	
	# Iterate through all placements
	for placement in $TokenPlacements.get_children():
		# Check if we've already marked enough energy placements for this biome
		var biome_energy_count = 0
		for check_placement in $TokenPlacements.get_children():
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
	return positions.slice(0, min(positions.size(), TokenManager.MAX_TOKENS_PER_BIOME))

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
			
			# Set material color based on biome
			var color = BIOME_COLORS[biome]
			color.a = 0.2
			var region_material = material.duplicate()
			region_material.albedo_color = color
			mesh_instance.material_override = region_material
			
			# Add to the borders node
			borders_node.add_child(mesh_instance)

# ╭──────────────────────────────╮
# |  Token - Setup               |
# ╰──────────────────────────────╯

func setup_player(player_id: int) -> void:
	#print("Setting up player: ", player_id)
	if player_id == multiplayer.get_unique_id():
		# Enable interaction for the local player
		player_hand.set_interaction_enabled(true)
		player_hand.player_id = player_id
		
		# Initialize tokens only if this is the first setup
		if multiplayer.is_server() and !token_manager.player_tokens.has(player_id):
			token_manager.initialize_player_tokens(player_id)
			var tokens = token_manager.get_player_tokens(player_id)
			update_token_ui()
			
			# Store initial token count
			player_token_counts[player_id] = tokens.size()
	
	# Token initialization for clients
	if multiplayer.is_server() and !token_manager.player_tokens.has(player_id):
		token_manager.initialize_player_tokens(player_id)
		
		# Store initial token count
		var tokens = token_manager.get_player_tokens(player_id)
		player_token_counts[player_id] = tokens.size()
		
		# Use rpc_id instead of rpc when sending to a specific player
		if player_id != multiplayer.get_unique_id():
			rpc_id(player_id, "sync_player_tokens", tokens)

@rpc("authority", "reliable")
func sync_player_tokens(tokens: Array):
	var player_id = multiplayer.get_unique_id()
	token_manager.set_player_tokens(player_id, tokens)
	
	print("Syncing tokens for player: ", player_id, " Tokens: ", tokens)
	# Force UI update regardless of turn
	update_token_ui()
	update_token_indicators()

# Update sync_token_placement
@rpc("any_peer", "call_local")
func sync_token_placement(player_id: int, token_data: Dictionary, position: Vector3):
	var placement = get_token_placement_at_position(position)
	if !placement:
		return
	
	# Check if occupied
	if placement.is_occupied:
		return
	
	# Create and place the token
	var token = token_manager.token_scene.instantiate()
	$Tokens.add_child(token, true)
	
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
	if local_id == players[current_turn_index]:
		update_token_ui()
	
	# After placing the token, update the saved count
	if multiplayer.is_server():
		var updated_tokens = token_manager.get_player_tokens(player_id)
		player_token_counts[player_id] = updated_tokens.size()

func save_player_token_count(player_id: int):
	var tokens = token_manager.get_player_tokens(player_id)
	player_token_counts[player_id] = tokens.size()
	print("Saved token count for player ", player_id, ": ", tokens.size())

func reset_token_buttons():
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

# Update request_token_placement to use biome from token placement location
@rpc("any_peer")
func request_token_placement(token_index: int, position: Vector3):
	if !multiplayer.is_server():
		return
		
	var player_id = multiplayer.get_remote_sender_id()
	if player_id == 0:  # If this is a local server request
		player_id = multiplayer.get_unique_id()
	
	# Validate placement timing and turn
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_token_placement_time < TOKEN_PLACEMENT_COOLDOWN:
		if player_id != multiplayer.get_unique_id():
			rpc_id(player_id, "notify_invalid_placement")
		return
	
	if !is_valid_player_turn(player_id):
		if player_id != multiplayer.get_unique_id():
			rpc_id(player_id, "notify_invalid_placement")
		return
	
	var player_tokens = token_manager.get_player_tokens(player_id)
	
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
			token_manager.remove_token(player_id, token_index)
			
			# Important: Sync the placement to ALL clients including the requester
			rpc("sync_token_placement", player_id, token_data, position)
			
			# Update tokens for all players
			for pid in players:
				var updated_tokens = token_manager.get_player_tokens(pid)
				rpc_id(pid, "sync_player_tokens", updated_tokens)

# ╭──────────────────────────────╮
# |  Token - REMOVE              |
# ╰──────────────────────────────╯

func _on_remove_token_pressed():
	is_remove = true

@rpc("any_peer")
func request_token_removal(token_position: Vector3):
	if !multiplayer.is_server():
		return
	
	var player_id = multiplayer.get_remote_sender_id()
	
	# Validate it's the player's turn
	if !is_valid_player_turn(player_id):
		return
	
	# Process the token removal
	process_token_removal(token_position)

func process_token_removal(token_position: Vector3):
	# Find the token at this position
	var token = null
	for t in $Tokens.get_children():
		if t.global_position.distance_to(token_position) < 0.5:
			token = t
			break
	
	if token:
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
			token_manager.add_token_to_player(player_id, biome_type)
		
		# Remove the token
		token.queue_free()
		
		# Sync to all clients
		rpc("sync_token_removal_at_position", token_position, player_id, biome_type)
		
		# Update tokens UI for all players
		for pid in players:
			var updated_tokens = token_manager.get_player_tokens(pid)
			if pid == multiplayer.get_unique_id():
				sync_player_tokens(updated_tokens)
			else:
				rpc_id(pid, "sync_player_tokens", updated_tokens)

@rpc("any_peer", "call_local")
func sync_token_removal(token):
	if token:
		print("token : ", token )
		var player_id = token.owner_id
		if player_id != -1:
			# Add token back to player's tokens
			token_manager.add_token_to_player(player_id, token.biome_type)
			
			# Update UI if this is the local player
			if player_id == multiplayer.get_unique_id():
				update_token_ui()
		print("")
		# Remove the token
		token.remove_token()

@rpc("any_peer", "call_local")
func sync_token_removal_at_position(token_position: Vector3, player_id: int, biome_type: int):
	# Find the token at this position
	var token = null
	for t in $Tokens.get_children():
		if t.global_position.distance_to(token_position) < 0.5:
			token = t
			break
	
	if token:
		# Get the token placement
		var placement = get_token_placement_at_position(token.global_position)
		
		# Mark the placement as available again
		if placement:
			placement.set_occupied(false)
			placement.current_token = null
			placement.set_highlight(false)
		# Remove the token
		token.queue_free()
		
		# Update UI if this is for the local player
		if player_id == multiplayer.get_unique_id():
			update_token_ui()

func find_token_at_position(position: Vector3) -> Node:
	for token in $Tokens.get_children():
		if token.global_position.distance_to(position) < 0.1:
			return token
	return null


func update_all_players_tokens():
	if !multiplayer.is_server():
		return
		
	for pid in players:
		var updated_tokens = token_manager.get_player_tokens(pid)
		if pid == multiplayer.get_unique_id():
			# Update server's UI directly
			update_token_ui()
		else:
			# Update clients
			rpc_id(pid, "sync_player_tokens", updated_tokens)

# In _ready or set up functions:
func setup_token_ui():
	# Clear any existing connections
	if token_button.pressed.is_connected(_on_token_selected):
		token_button.pressed.disconnect(_on_token_selected)
		
	# Connect the token selection function
	token_button.pressed.connect(_on_token_selected)
	
	# Initialize the UI state
	update_token_ui()

func update_token_ui():
	var player_id = multiplayer.get_unique_id()
	var is_my_turn = is_valid_player_turn(player_id)
	
	# Get token count
	var tokens = token_manager.get_player_tokens(player_id)
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

@rpc("authority", "reliable")
func notify_invalid_placement():
	print("Invalid placement!")
	selected_token_index = -1
	unhighlight_all_token_placements()
	var tokens = token_manager.get_player_tokens(multiplayer.get_unique_id())
	update_token_ui()

func get_token_placement_at_position(pos: Vector3) -> Node:
	for placement in $TokenPlacements.get_children():
		if placement.global_position.distance_to(pos) < 0.1:
			#print("Found token placement at ", pos)
			return placement
	#print("No token placement found at ", pos)
	return null

# ╭──────────────────────────────╮
# |  Token - Events              |
# ╰──────────────────────────────╯

func _on_token_placed(token: Node3D, placement_location: Node3D):
	if multiplayer.is_server():
		# Mark the placement location as occupied
		placement_location.set_occupied(true)
		
		# Broadcast the token placement to all clients
		rpc("sync_token_placement", token.biome_type, token.token_type, placement_location.global_position)
	else:
		# Client requests server to validate placement
		rpc_id(1, "request_token_placement", token.biome_type, token.token_type, placement_location.global_position)
	
	# Unhighlight all placement locations
	unhighlight_all_token_placements()
	selected_token_index = -1  # Reset selected token

func _on_token_selected():
	if !is_valid_player_turn(multiplayer.get_unique_id()):
		is_token_selected = false
		update_token_ui()
		return
	
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_token_selection_time < TOKEN_PLACEMENT_COOLDOWN:
		return
	
	last_token_selection_time = current_time
	
	# Toggle selection state
	is_token_selected = !is_token_selected
	
	if is_token_selected:
		# Highlight all unoccupied placement locations
		for placement in $TokenPlacements.get_children():
			if !placement.is_occupied:
				placement.set_highlight(true)
	else:
		# Unhighlight all placements
		unhighlight_all_token_placements()
	
	# Update UI to show selection state
	update_token_ui()

func unhighlight_all_token_placements():
	for placement in $TokenPlacements.get_children():
		placement.set_highlight(false)

# ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
# ---   Card Logic Handling    ---
# ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

func distribute_initial_hand():
	if !multiplayer.is_server():
		return
		
	var host_id = multiplayer.get_unique_id()
	
	# Clear hand first
	player_hand.cards.clear()
	player_hand.card_resources.clear()
	player_hands[host_id].clear()
	
	# Track drawn cards to prevent duplicates
	var drawn_cards = []
	
	# Draw initial cards with validation
	for i in range(INITIAL_ACTION_CARDS):
		var card = action_deck.draw_card()
		while card and is_card_in_array(card, drawn_cards):
			action_deck.cards.append(card)  # Put the card back
			action_deck.shuffle()
			card = action_deck.draw_card()
		
		if card:
			drawn_cards.append(card)
			player_hands[host_id].append(card)
			player_hand.draw(card)
	
	for i in range(INITIAL_AREA_CARDS):
		var card = area_deck.draw_card()
		while card and is_card_in_array(card, drawn_cards):
			area_deck.cards.append(card)  # Put the card back
			area_deck.shuffle()
			card = area_deck.draw_card()
			
		if card:
			drawn_cards.append(card)
			player_hands[host_id].append(card)
			player_hand.draw(card)

func is_card_in_array(card: CardResource, array: Array) -> bool:
	for existing_card in array:
		if existing_card.card_name == card.card_name and \
		   existing_card.card_type == card.card_type and \
		   existing_card.cost_to_draw == card.cost_to_draw:
			return true
	return false

func distribute_initial_hand_to_client(peer_id: int):
	if !multiplayer.is_server():
		return
	
	# Clear any existing hand data first
	if player_hands.has(peer_id):
		player_hands[peer_id].clear()
	else:
		player_hands[peer_id] = []
	
	var cards_data = []
	var action_count = 0
	var area_count = 0
	
	# Draw initial action cards
	while action_count < INITIAL_ACTION_CARDS:
		var card = action_deck.draw_card()
		if card:
			if !is_card_duplicate(cards_data, card):
				player_hands[peer_id].append(card)
				cards_data.append(card.to_dictionary())
				action_count += 1
	
	# Draw initial area cards
	while area_count < INITIAL_AREA_CARDS:
		var card = area_deck.draw_card()
		if card:
			if !is_card_duplicate(cards_data, card):
				player_hands[peer_id].append(card)
				cards_data.append(card.to_dictionary())
				area_count += 1
	
	# Send cards to client only if we have the correct number
	if cards_data.size() == (INITIAL_ACTION_CARDS + INITIAL_AREA_CARDS):
		print("Sending initial hand to client ", peer_id, ": ", cards_data.size(), " cards")
		rpc_id(peer_id, "receive_initial_hand", cards_data)

func is_card_duplicate(cards_data: Array, new_card: CardResource) -> bool:
	for card_data in cards_data:
		if card_data.card_name == new_card.card_name and \
		   card_data.card_type == new_card.card_type:
			return true
	return false

func print_hand_debug():
	var player_id = multiplayer.get_unique_id()
	print("\n=== Hand Debug ===")
	print("Player ID: ", player_id)
	print("Cards in hand: ", player_hand.get_card_count())
	print("Card resources: ", player_hand.card_resources.size())
	print("=================\n")

@rpc("any_peer", "call_local")
func receive_initial_hand(cards_data: Array):
	if multiplayer.is_server():
		return
	
	# Clear existing hand completely first
	player_hand.clear_hand()
	
	var action_count = 0
	var area_count = 0
	
	# Process received cards with type limits
	for card_data in cards_data:
		if action_count >= INITIAL_ACTION_CARDS and area_count >= INITIAL_AREA_CARDS:
			break
			
		var card_resource = CardResource.new()
		card_resource.from_dictionary(card_data)
		
		# Check card type limits
		if card_resource.card_type == CardResource.CardType.ACTION:
			if action_count < INITIAL_ACTION_CARDS:
				player_hand.draw(card_resource)
				action_count += 1
		else:  # AREA type
			if area_count < INITIAL_AREA_CARDS:
				player_hand.draw(card_resource)
				area_count += 1
	
	print("Received initial hand: ", player_hand.card_resources.size(), " cards")
	print("Action cards: ", action_count, ", Area cards: ", area_count)

@rpc("any_peer")
func request_initial_cards():
	
	if multiplayer.is_server():
		distribute_initial_hand_to_client(multiplayer.get_remote_sender_id())

@rpc("any_peer", "call_local")
func sync_game_state(current_players: Array, is_game_started: bool, current_placed_cards: Array) -> void:
	players = current_players
	game_started = is_game_started
	
	# Sync player colors
	if multiplayer.is_server():
		# Server sends color mapping to new client
		rpc("sync_player_colors", player_colors)
	
	# Replay all placed cards
	for placement in current_placed_cards:
		var player_id = placement.get("player_id", 1)
		sync_card_played(placement.card_data, placement.slot_index, placement.location_name, player_id)
	
	# Only request initial cards if this client has NO existing hand data
	if not multiplayer.is_server() and (
		!player_hands.has(multiplayer.get_unique_id()) or 
		player_hands[multiplayer.get_unique_id()].is_empty()
	):
		rpc_id(1, "request_initial_cards")

@rpc("any_peer", "call_local")
func sync_player_colors(colors: Dictionary):
	player_colors = colors.duplicate()
	# Update existing tokens
	if $Tokens:
		for token in $Tokens.get_children():
			if token.has_method("update_token_display"):
				token.update_token_display()

func remove_card_from_player_hand(player_id: int, card_index: int) -> void:
	if !player_hands.has(player_id):
		return
		
	if card_index >= 0 and card_index < player_hands[player_id].size():
		player_hands[player_id].remove_at(card_index)
		#print("Removed card at index ", card_index, " from player ", player_id, "'s hand")

func _setup_area_picking(node: Node) -> void:
	if node is Area3D:
		node.input_ray_pickable = true
		node.collision_layer = 1
		node.collision_mask = 1
	for child in node.get_children():
		_setup_area_picking(child)

func count_cards_by_type_for_player(player_id: int, type: int) -> int:
	if !player_hands.has(player_id):
		return 0
		
	var count = 0
	for card in player_hands[player_id]:
		if card.card_type == type:
			count += 1
	return count

@rpc("any_peer")
func request_card_placement(card_data: Dictionary, slot_index: int, location_name: String, player_id: int) -> void:
	if !multiplayer.is_server():
		return
		
	# Validate it's the player's turn
	if !is_valid_player_turn(player_id):
		return
		
	var card_resource = CardResource.new()
	card_resource.from_dictionary(card_data)
	
	# Remove card from server's tracking of player's hand
	remove_card_from_hand(player_id, card_resource)
	
	# Broadcast placement to all clients
	rpc("sync_card_played", card_data, slot_index, location_name, player_id)

# ╭──────────────────────────────╮
# |  Card - Draw                 |
# ╰──────────────────────────────╯

@rpc("any_peer", "call_local")
func sync_draw_card(card_data: Dictionary) -> void:
	# Only process if it's meant for the current player's turn
	var current_player = players[current_turn_index]
	var local_id = multiplayer.get_unique_id()
	
	if local_id != current_player:
		return
	
	# Prevent duplicate draws
	for existing_card in player_hand.card_resources:
		if existing_card.card_name == card_data.card_name:
			return
	
	var card_resource = CardResource.new()
	card_resource.from_dictionary(card_data)
	player_hand.draw(card_resource)

@rpc("any_peer")
func request_draw_card(is_action: bool):
	if !multiplayer.is_server():
		return

	var requesting_peer = multiplayer.get_remote_sender_id()
	
	# Validate turn ownership
	if players[current_turn_index] != requesting_peer:
		print("Not your turn to draw!")
		return
	
	var current_count = count_cards_by_type_for_player(
		requesting_peer,
		CardResource.CardType.ACTION if is_action else CardResource.CardType.AREA
	)
	
	var max_count = MAX_ACTION_CARDS if is_action else MAX_AREA_CARDS
	if current_count >= max_count:
		return
		
	var deck = action_deck if is_action else area_deck
	var card = deck.draw_card()
	
	if card:
		# Add to server's tracking
		player_hands[requesting_peer].append(card)
		# Send only to the requesting player
		rpc_id(requesting_peer, "sync_draw_card", card.to_dictionary())

func can_draw_card(card_type: int) -> bool:
	var current_count = count_cards_by_type(card_type)
	var max_count = MAX_ACTION_CARDS if card_type == CardResource.CardType.ACTION else MAX_AREA_CARDS
	return current_count < max_count

func count_cards_by_type(type: int) -> int:
	var count = 0
	for card in player_hand.card_resources:
		if card.card_type == type:
			count += 1
	return count

# ╭──────────────────────────────╮
# |  Card - Discard              |
# ╰──────────────────────────────╯

@rpc("any_peer", "call_local")
func sync_discard_card():
	player_hand.discard()

@rpc("any_peer")
func request_discard_cards():
	if multiplayer.is_server():
		rpc("sync_discard_card")

@rpc("any_peer", "call_local")
func sync_card_played(card_data: Dictionary, slot_index: int, location_name: String, player_id: int) -> void:
	# Find the correct location node
	var locations = {
		"Action Area": action_area,
		"Area Zone": area_zone
	}
	
	var location = locations.get(location_name)
	if location:
		var card_resource = CardResource.new()
		card_resource.from_dictionary(card_data)
		location.plant_card(card_resource, slot_index)
	else:
		pass

func _on_card_placed(card: CardResource, slot_index: int, location_name: String) -> void:
	var current_player = multiplayer.get_unique_id()
	
	if !is_valid_player_turn(current_player):
		return
	
	if multiplayer.is_server():
		# Store the card placement
		var placement_data = {
			"card_data": card.to_dictionary(),
			"slot_index": slot_index,
			"location_name": location_name,
			"player_id": current_player
		}
		placed_cards.append(placement_data)
		
		# Remove card from server's hand tracking
		remove_card_from_hand(current_player, card)
		
		# Broadcast placement to all clients
		rpc("sync_card_played", card.to_dictionary(), slot_index, location_name, current_player)
	else:
		# Client requests server to validate placement
		rpc_id(1, "request_card_placement", card.to_dictionary(), slot_index, location_name, current_player)

@rpc("any_peer", "call_local")
func sync_remove_played_card(card_data: Dictionary, player_id: int):
	# Only process if this is for the local player
	if player_id == multiplayer.get_unique_id():
		var card_resource = CardResource.new()
		card_resource.from_dictionary(card_data)
		remove_local_card(card_resource)

func remove_local_card(card: CardResource):
	
	for i in range(player_hand.card_resources.size()):
		var existing = player_hand.card_resources[i]
		if existing.card_name == card.card_name and existing.card_type == card.card_type:
			player_hand.card_resources.remove_at(i)
			break
	player_hand._update_cards()

func remove_card_from_hand(player_id: int, card: CardResource) -> void:
	if !player_hands.has(player_id):
		return
		
	var hand = player_hands[player_id]
	for i in range(hand.size()):
		if hand[i].card_name == card.card_name and hand[i].card_type == card.card_type:
			hand.remove_at(i)
			break

func validate_hand_sync(peer_id: int) -> bool:
	if !player_hands.has(peer_id):
		return false
		
	if multiplayer.is_server():
		# Server validation
		var server_cards = player_hands[peer_id].size()
		return server_cards == (INITIAL_ACTION_CARDS + INITIAL_AREA_CARDS)
	else:
		# Client validation
		var client_cards = player_hand.card_resources.size()
		return client_cards == (INITIAL_ACTION_CARDS + INITIAL_AREA_CARDS)

@rpc("any_peer")
func request_hand_resync():
	if !multiplayer.is_server():
		return
		
	var requesting_peer = multiplayer.get_remote_sender_id()
	if player_hands.has(requesting_peer):
		var cards_data = []
		for card in player_hands[requesting_peer]:
			cards_data.append(card.to_dictionary())
		rpc_id(requesting_peer, "receive_initial_hand", cards_data)

func _on_action_card_drawn(card: CardResource):
	if not card:
		return
		
	if multiplayer.is_server() and game_started:
		rpc("sync_draw_card", card.to_dictionary())

func _on_area_card_drawn(card: CardResource):
	if not card:
		return
		
	if multiplayer.is_server() and game_started:
		rpc("sync_draw_card", card.to_dictionary())

func _on_discard_card_button_pressed() -> void:
	if multiplayer.is_server():
		rpc("sync_discard_card")
	else:
		rpc_id(1, "request_discard_cards")

func _on_draw_action_button_pressed():
	var player_id = multiplayer.get_unique_id()
	
	# Check if it's the player's turn
	if !is_valid_player_turn(player_id):
		print("Not your turn to draw!")
		return
	
	var current_count = count_cards_by_type(CardResource.CardType.ACTION)
	if current_count >= MAX_ACTION_CARDS:
		return
		
	if multiplayer.is_server():
		var card = action_deck.draw_card()
		if card:
			# Add to server's tracking
			player_hands[player_id].append(card)
			# Only sync to the current player
			rpc_id(player_id, "sync_draw_card", card.to_dictionary())
			# Update local hand if server is the current player
			if player_id == multiplayer.get_unique_id():
				player_hand.draw(card)
	else:
		rpc_id(1, "request_draw_card", true)

func _on_draw_area_button_pressed():
	var player_id = multiplayer.get_unique_id()
	
	# Check if it's the player's turn
	if !is_valid_player_turn(player_id):
		print("Not your turn to draw!")
		return
	
	var current_count = count_cards_by_type(CardResource.CardType.AREA)
	if current_count >= MAX_AREA_CARDS:
		return
		
	if multiplayer.is_server():
		var card = area_deck.draw_card()
		if card:
			# Add to server's tracking
			player_hands[player_id].append(card)
			# Only sync to the current player
			rpc_id(player_id, "sync_draw_card", card.to_dictionary())
			# Update local hand if server is the current player
			if player_id == multiplayer.get_unique_id():
				player_hand.draw(card)
	else:
		rpc_id(1, "request_draw_card", false)

# ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
# ---  Turn Manager Handling   ---
# ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

func get_current_player_id() -> int:
	if is_valid_turn_index():
		return players[current_turn_index]
	return -1

func start_game():
	if multiplayer.is_server():
		game_started = true
		current_turn_index = 0
		if players.size() > 0:
			print("\n=== Starting Game ===")
			print("Initial players: ", players)
			print("Starting turn index: ", current_turn_index)
			
			# Sync game start to all clients
			rpc("sync_game_start", players)
			
			# Set initial turn
			var first_player = players[current_turn_index]
			print("First player: ", first_player)
			rpc("set_current_turn", first_player)
			
			print("=== Game Start Complete ===\n")
		else:
			print("No players available to start game")

@rpc("call_local")
func sync_game_start(current_players):
	players = current_players
	game_started = true
	
	# Assign colors to existing players
	for i in range(players.size()):
		if i < PLAYER_COLORS.size():
			player_colors[players[i]] = PLAYER_COLORS[i]

@rpc("any_peer", "call_local")
func add_player(player_id):
	if not players.has(player_id):
		players.append(player_id)
	#print(player_id)

@rpc("any_peer", "call_local")
func remove_player(player_id):
	players.erase(player_id)

func is_valid_player_turn(player_id: int) -> bool:
	if players.is_empty():
		return false
	
	if current_turn_index < 0 or current_turn_index >= players.size():
		return false
	
	var is_valid = players[current_turn_index] == player_id
	
	# Handle hand resync without RPC if we're the server
	if !validate_hand_sync(multiplayer.get_unique_id()):
		if multiplayer.is_server():
			resync_hand_locally()
		else:
			rpc_id(1, "request_hand_resync")
	
	return is_valid

func resync_hand_locally() -> void:
	if multiplayer.is_server():
		var host_id = multiplayer.get_unique_id()
		if player_hands.has(host_id):
			var cards_data = []
			for card in player_hands[host_id]:
				cards_data.append(card.to_dictionary())
			receive_initial_hand(cards_data)


# ╭──────────────────────────────╮
# |  Setup Player - Token        |
# ╰──────────────────────────────╯
func setup_player_token_indicators():
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

# Add this function to update token counts
func update_token_indicators():
	for player_id in players:
		var indicator_name = "Player_" + str(player_id)
		if player_token_indicators.has_node(indicator_name):
			var indicator = player_token_indicators.get_node(indicator_name)
			var label = indicator.get_node("TokenCount")
			
			# Get token count for this player
			var token_count = token_manager.get_player_tokens(player_id).size()
			label.text = str(token_count)
			
			# Maybe fade out if they have no tokens
			indicator.modulate.a = 1.0 if token_count > 0 else 0.5

# ╭──────────────────────────────╮
# |  Turn Manager - Current Turn |
# ╰──────────────────────────────╯

@rpc("any_peer", "call_local")
func set_current_turn(player_id):
	if !is_instance_valid(point_counter):
		return
	
	var local_id = multiplayer.get_unique_id()
	current_turn_index = players.find(player_id)
	selected_token_index = -1  # Reset selection
	is_token_selected = false  # Reset token selection state
	unhighlight_all_token_placements()

	print("Setting turn for player: ", player_id, " (local: ", local_id, ")")

	# Always show token button for local player
	token_button.visible = true  # Always visible
	
	# Don't reset tokens, just sync the current state
	if multiplayer.is_server():
		# Make sure the player has a token entry
		if !token_manager.player_tokens.has(player_id):
			token_manager.initialize_player_tokens(player_id)
		
		# Sync tokens to the player whose turn it is
		var tokens = token_manager.get_player_tokens(player_id)
		if player_id != multiplayer.get_unique_id():
			rpc_id(player_id, "sync_player_tokens", tokens)
		else:
			# Direct update for host
			sync_player_tokens(tokens)
	
	if player_id == local_id:
		# It's your turn - Enable controls for local player
		player_hand.set_interaction_enabled(true)
		$RightUI/EndTurnButton.disabled = false
		if point_counter:
			point_counter.set_buttons_enabled(true)
			point_counter.update_all_stacks()
		
		# Enable/disable draw buttons based on turn
		$DrawActionButton.disabled = false
		$DrawAreaButton.disabled = false

		# Force token refresh if client
		if !multiplayer.is_server():
			rpc_id(1, "request_token_refresh")
		
		# Enable card interactions
		player_hand.set_interaction_enabled(true)
		
		# Update token display after refreshing tokens
		var tokens = token_manager.get_player_tokens(local_id)
		token_button.disabled = tokens.size() <= 0
		token_button.text = "Tokens: " + str(tokens.size())
		
		# Make sure the token button is connected
		if token_button.pressed.is_connected(_on_token_selected):
			token_button.pressed.disconnect(_on_token_selected)
		token_button.pressed.connect(_on_token_selected)
	else:
		# Not your turn - Disable controls for local player
		player_hand.set_interaction_enabled(false)
		$RightUI/EndTurnButton.disabled = true
		if point_counter:
			point_counter.set_buttons_enabled(false)
			point_counter.update_all_stacks()
		
		# Disable draw buttons when not player's turn
		$DrawActionButton.disabled = true
		$DrawAreaButton.disabled = true
		
		# Disable card interactions
		player_hand.set_interaction_enabled(false)
		
		# Disable token button when not your turn, but keep it visible
		token_button.disabled = true
		
		# Reset any highlighting when it's not your turn
		is_token_selected = false
		unhighlight_all_token_placements()
		
		# Still update the local player's token display
		var tokens = token_manager.get_player_tokens(local_id)
		token_button.text = "Tokens: " + str(tokens.size())
	
	# Update the token count display for all players
	update_token_indicators()
	
	# Update visual feedback for token selection state
	if is_token_selected:
		token_button.modulate = Color(1.2, 1.2, 0.8, 1)
	else:
		token_button.modulate = Color(1, 1, 1, 1)

func is_valid_turn_index() -> bool:
	return current_turn_index >= 0 and current_turn_index < players.size()

func enable_player_turn():
	player_hand.set_interaction_enabled(true)
	$RightUI/EndTurnButton.disabled = false

func disable_player_turn():
	player_hand.set_interaction_enabled(false)
	$RightUI/EndTurnButton.disabled = true

# ╭──────────────────────────────╮
# |  Turn Manager - Next Turn    |
# ╰──────────────────────────────╯

@rpc("any_peer")
func request_next_turn():
	if !multiplayer.is_server():
		return
	
	var requesting_player = multiplayer.get_remote_sender_id()
	print("\n=== Turn Change Request ===")
	print("Requesting player: ", requesting_player)
	print("Current turn player: ", players[current_turn_index])
	
	if requesting_player == players[current_turn_index]:
		next_turn()
	
	print("=== Turn Change Request Complete ===\n")

# sync the dice, and card
func next_turn():
	if !multiplayer.is_server():
		return
	
	print("\n=== Processing Next Turn ===")
	print("Current players: ", players)
	print("Current turn index: ", current_turn_index)
	
	if players.size() > 0:
		# Save the current player's token count before advancing turn
		var current_player = players[current_turn_index]
		save_player_token_count(current_player)
		
		# Advance to next player
		current_turn_index = (current_turn_index + 1) % players.size()
		var next_player = players[current_turn_index]
		print("Next player: ", next_player)
		
		# DON'T initialize tokens for next player - use their saved count if available
		var tokens = token_manager.get_player_tokens(next_player)
		
		# Sync turn and tokens to all clients
		rpc("set_current_turn", next_player)
		if next_player != multiplayer.get_unique_id():
			rpc_id(next_player, "sync_player_tokens", tokens)
		else:
			# Direct update for host
			sync_player_tokens(tokens)
		
		# Force sync point counter state
		if point_counter:
			point_counter.rpc("sync_point_values", 
				point_counter.forest_points,
				point_counter.desert_points,
				point_counter.mountain_points,
				point_counter.water_points,
				# magic point
				point_counter.forest_magic_points,
				point_counter.desert_magic_points,
				point_counter.mountain_magic_points,
				point_counter.water_magic_points
			)
	
	print("=== Next Turn Complete ===\n")

# ╭──────────────────────────────╮
# |  Turn Manager - Events       |
# ╰──────────────────────────────╯

func _on_end_turn_pressed():
	var current_player = players[current_turn_index]
	
	# Save the token count before ending turn
	save_player_token_count(current_player)
	
	if multiplayer.is_server():
		# Disable current player's controls immediately
		player_hand.set_interaction_enabled(false)
		$RightUI/EndTurnButton.disabled = true
		if point_counter:
			point_counter.set_buttons_enabled(false)
		
		next_turn()
	else:
		# Client requests turn end
		player_hand.set_interaction_enabled(false)
		$RightUI/EndTurnButton.disabled = true
		if point_counter:
			point_counter.set_buttons_enabled(false)
			
		rpc_id(1, "request_next_turn")

func _on_reset_button_pressed() -> void:
	get_tree().reload_current_scene()




# ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
# ---   Dice Logic Handling    ---
# ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

func _on_roll_dice_pressed():
	if multiplayer.is_server():
		var result = randi_range(1, 6)
		dice_manager.rpc("sync_roll", result, multiplayer.get_unique_id())
	else:
		dice_manager.rpc_id(1, "request_roll")
		
func _on_dice_roll_completed(result: int, player_id: int, face_name: String):
	var player_text = "You" if player_id == multiplayer.get_unique_id() else "Player " + str(player_id)
	roll_result_label.text = player_text + " rolled: " + face_name
	
	# Optional: Add some styling based on the face
	var color = dice_manager.FACE_COLORS[result]
	roll_result_label.modulate = color

# ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
# ---  Point Counter Handling  ---
# ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

@rpc("any_peer")
func request_point_adjustment(region: String, delta: int):
	# Add cooldown check
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_point_adjustment_time < POINT_ADJUSTMENT_COOLDOWN:
		return
	
	last_point_adjustment_time = current_time
	
	var requesting_player = multiplayer.get_remote_sender_id()
	
	# If this is the server making the request locally, use the server's actual ID
	if requesting_player == 0 and multiplayer.is_server():
		requesting_player = multiplayer.get_unique_id()
	
	if multiplayer.is_server():
		# Server processes the request directly
		process_point_adjustment(region, delta, requesting_player)
	else:
		# Clients send request to server
		rpc_id(1, "request_point_adjustment", region, delta)

func process_point_adjustment(region: String, delta: int, requesting_player: int):
	if !multiplayer.is_server():
		return
		
	#print("Processing point adjustment for player: ", requesting_player)
	
	# Validate turn
	if is_valid_player_turn(requesting_player):
		# Clamp delta to ensure only +1/-1
		delta = clamp(delta, -1, 1)
		
		# Perform the adjustment
		if delta > 0 and point_counter.get_points(region) < 10:
			adjust_points_increase(region)
		elif delta < 0 and point_counter.get_points(region) > 0:
			adjust_points_decrease(region)
			
		# Sync to all clients
		point_counter.rpc("sync_point_values", 
			point_counter.forest_points,
			point_counter.desert_points,
			point_counter.mountain_points,
			point_counter.water_points,
			point_counter.forest_magic_points,
			point_counter.desert_magic_points,
			point_counter.mountain_magic_points,
			point_counter.water_magic_points
		)
	#else:
		#print("Invalid turn for point adjustment!")

# Helper functions for point adjustments
# need to change, player should have choice to remove points from any region
func adjust_points_increase(region: String):
	if !point_counter:
		return
		
	var points_to_remove = 1
	
	# Remove points from other regions
	if region != "triangle" and point_counter.forest_points > 0:
		point_counter.set_points("triangle", point_counter.forest_points - 1)
		points_to_remove -= 1
	if points_to_remove > 0 and region != "square" and point_counter.desert_points > 0:
		point_counter.set_points("square", point_counter.desert_points - 1)
		points_to_remove -= 1
	if points_to_remove > 0 and region != "circle" and point_counter.mountain_points > 0:
		point_counter.set_points("circle", point_counter.mountain_points - 1)
	
	# Add point to selected region
	point_counter.set_points(region, point_counter.get_points(region) + 1)

func adjust_points_decrease(region: String):
	if !point_counter:
		return
		
	var points_to_add = 1
	
	# Add points to other regions
	if region != "triangle":
		point_counter.set_points("triangle", point_counter.forest_points + 1)
		points_to_add -= 1
	if points_to_add > 0 and region != "square":
		point_counter.set_points("square", point_counter.desert_points + 1)
		points_to_add -= 1
	if points_to_add > 0 and region != "circle":
		point_counter.set_points("circle", point_counter.mountain_points + 1)
	
	# Remove point from selected region
	point_counter.set_points(region, point_counter.get_points(region) - 1)

@rpc("authority", "call_local")
func sync_points():
	if !point_counter:
		return
	point_counter.rpc("sync_point_values", 
		point_counter.forest_points,
		point_counter.desert_points,
		point_counter.mountain_points,
		point_counter.water_points,
		point_counter.forest_magic_points,
		point_counter.desert_magic_points,
		point_counter.mountain_magic_points,
		point_counter.water_magic_points
	)

@rpc("any_peer")
func request_token_refresh():
	if multiplayer.is_server():
		var requesting_player = multiplayer.get_remote_sender_id()
		
		# Don't force reset, just ensure the player has an entry
		if !token_manager.player_tokens.has(requesting_player):
			token_manager.initialize_player_tokens(requesting_player, false)
			
		var tokens = token_manager.get_player_tokens(requesting_player)
		rpc_id(requesting_player, "sync_player_tokens", tokens)

# Card handling section
@rpc("any_peer", "call_local")
func sync_remove_card(index: int, player_id: int):
	# Only process if this is for the local player
	if player_id == multiplayer.get_unique_id():
		if player_hand and index >= 0 and index < player_hand.card_resources.size():
			player_hand.card_resources.remove_at(index)
			player_hand._update_cards()
		
		# Update server's tracking if we are the server
		if multiplayer.is_server() and player_hands.has(player_id):
			if index >= 0 and index < player_hands[player_id].size():
				player_hands[player_id].remove_at(index)

# Add these new networking functions
func setup_mobile_ui():
	if ip_input:
		ip_input.virtual_keyboard_enabled = true
		ip_input.placeholder_text = "Enter host IP..."

func setup_mobile_network():
	# Display local IP for hosting
	if ip_input and connect_status:
		var addresses = IP.get_local_addresses()
		var ip_text = "Available IPs:\n"
		for ip in addresses:
			# Only show IPv4 addresses that aren't localhost
			if ip.count(".") == 3 and not ip.begins_with("127."):
				ip_text += ip + "\n"
		connect_status.text = ip_text

func get_local_ip() -> String:
	var addresses = IP.get_local_addresses()
	#print("address : ", addresses)
	
	# Priority 1: Find a 192.168.x.x address (common home/office network)
	for ip in addresses:
		if ip.begins_with("192.168."):
			return ip
	
	# Priority 2: Find other common private network addresses
	for ip in addresses:
		if ip.begins_with("10.") or ip.begins_with("172.16.") or ip.begins_with("172.17.") or \
		   ip.begins_with("172.18.") or ip.begins_with("172.19.") or ip.begins_with("172.2") or \
		   ip.begins_with("172.30.") or ip.begins_with("172.31."):
			return ip
	
	# Priority 3: Only use link-local as a last resort before localhost
	for ip in addresses:
		if ip.begins_with("169.254."):
			return ip
	
	# Priority 4: Use localhost if nothing else is available
	for ip in addresses:
		if ip == "127.0.0.1":
			return ip
	
	return "IP not found"

func setup_upnp() -> bool:
	var upnp = UPNP.new()
	var discover_result = upnp.discover(2000, 2, "InternetGatewayDevice")
	
	if discover_result == UPNP.UPNP_RESULT_SUCCESS:
		if upnp.get_gateway() and upnp.get_gateway().is_valid_gateway():
			# Try to map both UDP and TCP
			var map_result_udp = upnp.add_port_mapping(PORT, PORT, "GodotGameUDP", "UDP")
			var map_result_tcp = upnp.add_port_mapping(PORT, PORT, "GodotGameTCP", "TCP")
			
			if map_result_udp == UPNP.UPNP_RESULT_SUCCESS or map_result_tcp == UPNP.UPNP_RESULT_SUCCESS:
				print("External IP: ", upnp.query_external_address())
				return true
	
	return false

func cleanup_upnp():
	if !is_host:
		return
		
	var upnp = UPNP.new()
	if upnp.discover() == UPNP.UPNP_RESULT_SUCCESS:
		if upnp.get_gateway() and upnp.get_gateway().is_valid_gateway():
			upnp.delete_port_mapping(PORT, "UDP")
			upnp.delete_port_mapping(PORT, "TCP")

func setup_network_discovery():
	if is_host:
		# Setup broadcasting socket
		broadcast_socket = PacketPeerUDP.new()
		broadcast_socket.set_broadcast_enabled(true)
		broadcast_timer = Timer.new()
		add_child(broadcast_timer)
		broadcast_timer.wait_time = SERVER_BROADCAST_INTERVAL
		broadcast_timer.timeout.connect(_broadcast_server_info)
		broadcast_timer.start()
	else:
		# Setup listening socket
		listen_socket = PacketPeerUDP.new()
		var err = listen_socket.bind(BROADCAST_PORT)
		if err == OK:
			print("Listening for servers on port ", BROADCAST_PORT)
		else:
			print("Failed to bind discovery port: ", err)

func _broadcast_server_info():
	if !is_host or !broadcast_socket:
		return
		
	var server_info = JSON.stringify({
		"server_ip": get_local_ip(),
		"server_port": PORT,
		"players": players.size()
	})
	
	broadcast_socket.set_dest_address("255.255.255.255", BROADCAST_PORT)
	broadcast_socket.put_packet(server_info.to_utf8_buffer())

func _process(_delta):
	if !is_host and listen_socket:
		if listen_socket.get_available_packet_count() > 0:
			var server_ip = listen_socket.get_packet_ip()
			var server_data_raw = listen_socket.get_packet()
			var server_data_str = server_data_raw.get_string_from_utf8()
			var server_info = JSON.parse_string(server_data_str)
			
			if server_info and server_info.has("server_ip"):
				print("Found server at: ", server_info.server_ip)
				connect_status.text = "Found server at: " + server_info.server_ip
				attempt_connection(server_info.server_ip)
				listen_socket = null  # Stop listening once we find a server
	
	# Check connection status
	if multiplayer_peer:
		match multiplayer_peer.get_connection_status():
			MultiplayerPeer.CONNECTION_DISCONNECTED:
				if peer_status != "Disconnected":
					peer_status = "Disconnected"
					connect_status.text = "Disconnected from server"
					$RightUI/Menu.visible = true
			MultiplayerPeer.CONNECTION_CONNECTED:
				if peer_status != "Connected":
					peer_status = "Connected"
					connect_status.text = "Connected!"
					$RightUI/Menu.visible = false

func cleanup_network():
	if broadcast_socket:
		broadcast_socket.close()
	if listen_socket:
		listen_socket.close()
	if broadcast_timer:
		broadcast_timer.stop()
	if multiplayer_peer:
		multiplayer_peer.close()

func _refresh_ip_display():
	if !connect_status:
		return
		
	var addresses = get_valid_ips()
	var ip_text = "Available IPs:\n"
	
	for ip in addresses:
		ip_text += ip + "\n"
	
	if is_host:
		ip_text += "\nHosting on port: " + str(PORT)
	
	connect_status.text = ip_text

func get_valid_ips() -> Array:
	var valid_ips = []
	var addresses = IP.get_local_addresses()
	
	for ip in addresses:
		# Filter for valid IPv4 addresses
		if ip.count(".") == 3 and not ip.begins_with("127."):
			# Check for mobile-specific IP patterns
			if ip.begins_with("192.168.") or \
			   ip.begins_with("10.") or \
			   ip.begins_with("172."):
				valid_ips.append(ip)
	
	return valid_ips

func _start_server_discovery():
	if discovery_socket:
		# Listen for broadcast messages
		while discovery_socket.get_available_packet_count() > 0:
			var packet = discovery_socket.get_packet()
			var data_str = packet.get_string_from_utf8()
			var server_data = JSON.parse_string(data_str)
			
			if server_data and server_data.has("host_ip") and server_data.has("game_port"):
				print("Found server at: ", server_data.host_ip)
				attempt_connection(server_data.host_ip)
				return
	
	# Retry discovery after a delay if no server found
	get_tree().create_timer(1.0).timeout.connect(_start_server_discovery)

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		cleanup_network()
		get_tree().quit()
