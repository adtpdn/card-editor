extends Node

@onready var player_hand = $HandAreas/PlayerHand
@onready var action_deck = $DeckLocations/ActionDeck
@onready var area_deck = $DeckLocations/AreaDeck
@onready var action_area = $PlantingLocations/ActionArea
@onready var area_zone = $PlantingLocations/AreaZone

# Dice Dependencies
@onready var dice_manager: Node3D = $DiceManager
@onready var roll_result_label = $UI/RollResultLabel

var multiplayer_peer = ENetMultiplayerPeer.new()
const PORT = 9999
const ADDRESS = "127.0.0.1"

var connected_peer_ids = []
var current_turn_index = 0
var players = []
var game_started = false
var max_players = 2

const MAX_ACTION_CARDS = 2
const MAX_AREA_CARDS = 2

var selected_token_index = -1

var deck: Array[CardResource] = []
# Add this structure to track placed cards
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

# Class variables
var radius = 4.0  # Radius of the octagon
var borders_node: Node3D
var biome_assignments = {
	TokenManager.BiomeType.FOREST: [0, 1],    # Slices 0 and 1
	TokenManager.BiomeType.DESERT: [2, 3],    # Slices 2 and 3
	TokenManager.BiomeType.MOUNTAIN: [4, 5],  # Slices 4 and 5
	TokenManager.BiomeType.WATER: [6, 7]      # Slices 6 and 7
}

# Add these color definitions if not already in TokenManager
const BIOME_COLORS = {
	TokenManager.BiomeType.FOREST: Color(0.2, 0.8, 0.2, 1.0),    # Green
	TokenManager.BiomeType.DESERT: Color(0.8, 0.8, 0.2, 1.0),    # Yellow
	TokenManager.BiomeType.MOUNTAIN: Color(0.5, 0.5, 0.5, 1.0),  # Gray
	TokenManager.BiomeType.WATER: Color(0.2, 0.2, 0.8, 1.0)      # Blue
}

var player_hands = {}  # Dictionary to store hands for each player ID
@onready var token_manager: TokenManager = $TokenManager

func _ready() -> void:
	# Create the borders node first
	borders_node = Node3D.new()
	borders_node.name = "BiomeBorders"
	add_child(borders_node)
	
	# Set up planting locations
	action_area.accepted_card_types = PackedInt32Array([CardResource.CardType.ACTION])
	action_area.location_name = "Action Area"
	
	area_zone.accepted_card_types = PackedInt32Array([CardResource.CardType.AREA])
	area_zone.location_name = "Area Zone"
	
	action_area.card_placed.connect(_on_card_placed)
	area_zone.card_placed.connect(_on_card_placed)
	
	# Set up the hand
	player_hand = $HandAreas/PlayerHand
	
	token_manager = TokenManager.new()
	add_child(token_manager)
	
	# Setup token placement locations
	await setup_token_placements()
	await setup_biome_borders()
	
	# Connect signals
	action_deck.card_drawn.connect(_on_action_card_drawn)
	area_deck.card_drawn.connect(_on_area_card_drawn)
	$UI/Menu/HostButton.pressed.connect(_on_host_pressed)
	$UI/Menu/JoinButton.pressed.connect(_on_join_pressed)
	$UI/EndTurnButton.pressed.connect(_on_end_turn_pressed)

	# Setup multiplayer
	multiplayer_peer.peer_connected.connect(_on_peer_connected)
	multiplayer_peer.peer_disconnected.connect(_on_peer_disconnected)

	# Initial state
	player_hand.set_interaction_enabled(false)
	$UI/EndTurnButton.disabled = true
	
	# Dice Manager Initiated
	dice_manager.roll_completed.connect(_on_dice_roll_completed)
	
	# Camera setup
	var camera = $Camera3D
	
	_setup_area_picking(action_area)
	_setup_area_picking(area_zone)
	
	set_multiplayer_authority(1)

func _on_host_pressed():
	var error = multiplayer_peer.create_server(PORT)
	if error == OK:
		$UI/NetworkInfo/NetworkSideDisplay.text = "Server"
		$UI/Menu.visible = false
		multiplayer.multiplayer_peer = multiplayer_peer
		var host_id = multiplayer.get_unique_id()
		players.append(host_id)
		
		# Initialize host's hand tracking
		player_hands[host_id] = []
		
		# Distribute initial hand to host
		distribute_initial_hand()
		setup_player(host_id)
		start_game()

func _on_join_pressed():
	var error = multiplayer_peer.create_client("localhost", PORT)
	if error == OK:
		$UI/NetworkInfo/NetworkSideDisplay.text = "Client"
		$UI/Menu.visible = false
		multiplayer.multiplayer_peer = multiplayer_peer
	else:
		print("Failed to create client: ", error)

func _on_peer_connected(new_peer_id):
	if multiplayer.is_server():
		await get_tree().create_timer(0.1).timeout
		print("New peer connected: ", new_peer_id)
		players.append(new_peer_id)
		
		# Initialize new player's tokens
		token_manager.initialize_player_tokens(new_peer_id)
		
		# Sync game state
		sync_existing_game_state(new_peer_id)
		
		# Sync tokens to the new client
		var player_tokens = token_manager.get_player_tokens(new_peer_id)
		rpc_id(new_peer_id, "sync_player_tokens", player_tokens)
		print("Sent initial tokens to client: ", player_tokens)
		
		# Initialize new player's hand tracking
		player_hands[new_peer_id] = []
		
		
		# Sync existing tokens
		var tokens_data = []
		for token in $Tokens.get_children():
			tokens_data.append({
				"biome": token.biome_type,
				"type": token.token_type,
				"position": token.global_position
			})
		
		# First sync game state and tokens
		rpc_id(new_peer_id, "sync_game_state", players, game_started, placed_cards)
		rpc_id(new_peer_id, "sync_existing_tokens", tokens_data)
		
		# Then distribute cards to new client
		distribute_initial_hand_to_client(new_peer_id)
		distribute_initial_tokens_to_client(new_peer_id)
		setup_player(new_peer_id)

func _on_peer_disconnected(peer_id):
	if peer_id == null or peer_id == 0:  # Check for both null and invalid ID
		return
		
	print("Peer disconnected: ", peer_id)
	if players.has(peer_id):
		players.erase(peer_id)
	
	# Clean up disconnected player's hand
	if player_hands.has(peer_id):
		player_hands.erase(peer_id)
	
	if multiplayer.is_server():
		rpc("remove_player", peer_id)

@rpc("any_peer", "call_local")
func sync_existing_tokens(tokens_data: Array):
	print("Syncing existing tokens: ", tokens_data.size())
	
	# Clear existing tokens first
	for token in $Tokens.get_children():
		token.queue_free()
	
	# Recreate tokens from data
	for token_info in tokens_data:
		var token = token_manager.token_scene.instantiate()
		$Tokens.add_child(token)
		token.set_token_data(token_info.biome, token_info.type)
		token.global_position = token_info.position
		
		var placement = get_token_placement_at_position(token_info.position)
		if placement:
			placement.set_occupied(true)

func sync_existing_game_state(new_peer_id: int):
	print("Syncing game state for new client: ", new_peer_id)
	
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
	print("Receiving game state")
	
	# Clear existing tokens
	for token in $Tokens.get_children():
		token.queue_free()
	
	# Recreate tokens
	for token_info in tokens_data:
		var token = token_manager.token_scene.instantiate()
		$Tokens.add_child(token)
		token.set_token_data(token_info.biome, token_info.type)
		token.global_position = token_info.position
	
	# Mark occupied locations
	for pos in occupied_locations:
		var placement = get_token_placement_at_position(pos)
		if placement:
			placement.set_occupied(true)

func distribute_initial_hand():
	if !multiplayer.is_server():
		return
		
	print("Distributing initial hand for host")
	var host_id = multiplayer.get_unique_id()
	
	# Clear hand first
	player_hand.cards.clear()
	player_hand.card_resources.clear()
	player_hands[host_id].clear()
	
	# Draw random cards for host
	var host_cards = draw_random_initial_cards()
	player_hands[host_id] = host_cards.duplicate()
	
	# Update host's visual hand
	for card in host_cards:
		player_hand.draw(card)

func distribute_initial_hand_to_client(peer_id: int):
	if !multiplayer.is_server():
		return
		
	print("Distributing initial hand to client: ", peer_id)
	
	# Draw random cards for this client
	var cards_data = []
	
	# Draw 2 action cards
	for i in range(2):
		var card = action_deck.draw_card()
		if card:
			cards_data.append(card.to_dictionary())
			print("Drew action card: ", card.card_name)
	
	# Draw 2 area cards
	for i in range(2):
		var card = area_deck.draw_card()
		if card:
			cards_data.append(card.to_dictionary())
			print("Drew area card: ", card.card_name)
	
	if cards_data.size() > 0:
		print("Sending ", cards_data.size(), " cards to client ", peer_id)
		rpc_id(peer_id, "receive_initial_hand", cards_data)
	else:
		print("No cards to send to client!")

func distribute_initial_tokens_to_client(peer_id: int):
	if !multiplayer.is_server():
		return
		
	print("Distributing initial tokens to client: ", peer_id)
	token_manager.initialize_player_tokens(peer_id)
	var tokens = token_manager.get_player_tokens(peer_id)
	rpc_id(peer_id, "sync_player_tokens", tokens)
	print("Sent initial tokens to client: ", tokens)

func draw_random_initial_cards() -> Array:
	var cards = []
	
	# Draw 2 action cards
	for i in range(2):
		var card = action_deck.draw_card()
		if card:
			cards.append(card)
	
	# Draw 2 area cards
	for i in range(2):
		var card = area_deck.draw_card()
		if card:
			cards.append(card)
	
	return cards

@rpc("any_peer", "call_local")
func receive_initial_hand(cards_data: Array):
	print("Receiving initial hand, is server: ", multiplayer.is_server())
	if multiplayer.is_server():
		return
	
	print("Processing ", cards_data.size(), " cards for client")
	
	# Clear existing hand
	player_hand.cards.clear()
	player_hand.card_resources.clear()
	
	# Process received cards
	for card_data in cards_data:
		var card_resource = CardResource.new()
		card_resource.from_dictionary(card_data)
		print("Processing card: ", card_resource.card_name)
		player_hand.draw(card_resource)
		print("Current hand size: ", player_hand.card_resources.size())
	
	print("Finished receiving initial hand, total cards: ", player_hand.get_card_count())

@rpc("any_peer")
func request_initial_cards():
	if multiplayer.is_server():
		distribute_initial_hand_to_client(multiplayer.get_remote_sender_id())

@rpc("any_peer", "call_local")
func sync_game_state(current_players: Array, is_game_started: bool, current_placed_cards: Array) -> void:
	print("Syncing game state. Is server: ", multiplayer.is_server())
	players = current_players
	game_started = is_game_started
	
	# Replay all placed cards
	for placement in current_placed_cards:
		# Make sure placement contains player_id, if not, use a default
		var player_id = placement.get("player_id", 1)  # Use server ID as default if not specified
		sync_card_played(placement.card_data, placement.slot_index, placement.location_name, player_id)
	
	# If this is a client, request initial cards
	if not multiplayer.is_server():
		print("Requesting initial cards as client")
		rpc_id(1, "request_initial_cards")

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
			$TokenPlacements.add_child(token_placement)
			token_placement.global_position = pos
			placements_per_biome[biome] += 1
	
	# Debug print final counts
	for biome in placements_per_biome.keys():
		print("Total placements for biome ", TokenManager.BiomeType.keys()[biome], 
			  ": ", placements_per_biome[biome])

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

func setup_player(player_id: int) -> void:
	print("Setting up player: ", player_id)
	if player_id == multiplayer.get_unique_id():
		# Enable interaction for the local player
		player_hand.set_interaction_enabled(true)
		player_hand.player_id = player_id
	# Token
	if multiplayer.is_server():
		token_manager.initialize_player_tokens(player_id)
		rpc_id(player_id, "sync_player_tokens", token_manager.get_player_tokens(player_id))

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

func unhighlight_all_token_placements():
	for placement in $TokenPlacements.get_children():
		placement.set_highlight(false)

@rpc("authority", "reliable")
func sync_player_tokens(tokens: Array):
	print("Received token sync from server")
	var player_id = multiplayer.get_unique_id()
	token_manager.set_player_tokens(player_id, tokens)
	update_token_ui(tokens)

func update_token_ui(tokens: Array):
	print("Starting UI update with tokens: ", tokens)
	
	# Get all token buttons
	var token_buttons = $UI/TokenContainer.get_children()
	
	# Hide all buttons initially and disconnect any existing signals
	for button in token_buttons:
		button.visible = false
		if button.pressed.is_connected(_on_token_selected):
			button.pressed.disconnect(_on_token_selected)
	
	# Update buttons based on available tokens
	for i in range(tokens.size()):
		if i >= token_buttons.size():
			print("Warning: More tokens than available buttons!")
			break
			
		var token_data = tokens[i]
		var button = token_buttons[i]
		
		# Update button properties
		var biome_name = TokenManager.BiomeType.keys()[token_data.biome]
		button.text = "Token %d (%s)" % [i + 1, biome_name]
		button.visible = true
		
		# Connect the button signal with a unique callable for each button
		button.pressed.connect(func(): _on_token_selected(i))
		print("Updated button ", i + 1, " for biome ", biome_name)
	
	print("Finished updating token UI. Active buttons: ", tokens.size())

func _on_token_selected(token_index: int):
	print("Token selected: ", token_index)
	var tokens = token_manager.get_player_tokens(multiplayer.get_unique_id())
	
	if token_index >= 0 and token_index < tokens.size():
		selected_token_index = token_index
		var token_data = tokens[token_index]
		
		# Highlight valid placement locations
		for placement in $TokenPlacements.get_children():
			var should_highlight = placement.accepted_biome == token_data.biome && !placement.is_occupied
			placement.set_highlight(should_highlight)
	else:
		selected_token_index = -1
		unhighlight_all_token_placements()

@rpc("any_peer")
func request_token_placement(token_index: int, position: Vector3):
	if !multiplayer.is_server():
		return
		
	print("Server received placement request from client")
	var player_id = multiplayer.get_remote_sender_id()
	var player_tokens = token_manager.get_player_tokens(player_id)
	
	# Debug prints
	print("Player ID: ", player_id)
	print("Token index: ", token_index)
	print("Available tokens: ", player_tokens)
	
	if token_index >= 0 and token_index < player_tokens.size():
		var token_data = player_tokens[token_index]
		var placement = get_token_placement_at_position(position)
		
		# Debug prints
		print("Token data: ", token_data)
		print("Found placement: ", placement != null)
		if placement:
			print("Placement occupied: ", placement.is_occupied)
			print("Placement biome: ", placement.accepted_biome)
		
		if placement and !placement.is_occupied and placement.accepted_biome == token_data.biome:
			print("Server validating placement - OK")
			sync_token_placement.rpc(player_id, token_data, position)
			token_manager.remove_token(player_id, token_index)
			rpc_id(player_id, "sync_player_tokens", token_manager.get_player_tokens(player_id))
		else:
			print("Invalid placement!")
	else:
		print("Invalid token index!")

func get_token_placement_at_position(pos: Vector3) -> Node:
	for placement in $TokenPlacements.get_children():
		if placement.global_position.distance_to(pos) < 0.1:
			print("Found token placement at ", pos)
			return placement
	print("No token placement found at ", pos)
	return null

@rpc("any_peer", "call_local")
func sync_token_placement(player_id: int, token_data: Dictionary, position: Vector3):
	print("Syncing token placement for player ", player_id, " at position ", position)
	
	var token = token_manager.token_scene.instantiate()
	$Tokens.add_child(token)
	token.set_token_data(token_data.biome, token_data.type)
	token.global_position = position
	
	var placement = get_token_placement_at_position(position)
	if placement:
		placement.set_occupied(true)
	
	# Update UI for the player who placed the token
	if player_id == multiplayer.get_unique_id():
		var updated_tokens = token_manager.get_player_tokens(player_id)
		update_token_ui(updated_tokens)
		unhighlight_all_token_placements()

func can_draw_card(card_type: int) -> bool:
	var current_count = count_cards_by_type(card_type)
	var max_count = MAX_ACTION_CARDS if card_type == CardResource.CardType.ACTION else MAX_AREA_CARDS
	return current_count < max_count

# Add these helper functions to check card counts
func count_cards_by_type(type: int) -> int:
	var count = 0
	for card in player_hand.card_resources:
		if card.card_type == type:
			count += 1
	return count

func _on_card_placed(card: CardResource, slot_index: int, location_name: String) -> void:
	print("Card placed event received for location: ", location_name)
	var current_player = multiplayer.get_unique_id()
	
	if multiplayer.is_server():
		# Store the card placement
		var placement_data = {
			"card_data": card.to_dictionary(),
			"slot_index": slot_index,
			"location_name": location_name,
			"player_id": current_player
		}
		placed_cards.append(placement_data)
		
		# Broadcast to all clients
		rpc("sync_card_played", card.to_dictionary(), slot_index, location_name, current_player)
	else:
		# Client requests server to validate placement
		rpc_id(1, "request_card_placement", card.to_dictionary(), slot_index, location_name, current_player)

func start_game():
	if multiplayer.is_server():
		game_started = true
		current_turn_index = 0
		rpc("sync_game_start", players)
		set_current_turn(players[current_turn_index])

@rpc("call_local")
func sync_game_start(current_players):
	players = current_players
	game_started = true

func next_turn():
	if multiplayer.is_server():
		current_turn_index = (current_turn_index + 1) % players.size()
		rpc("set_current_turn", players[current_turn_index])

@rpc("any_peer", "call_local")
func set_current_turn(player_id):
	if player_id == multiplayer.get_unique_id():
		player_hand.set_interaction_enabled(true)
		$UI/EndTurnButton.disabled = false
	else:
		player_hand.set_interaction_enabled(false)
		$UI/EndTurnButton.disabled = true

func enable_player_turn():
	player_hand.set_interaction_enabled(true)
	$UI/EndTurnButton.disabled = false

func disable_player_turn():
	player_hand.set_interaction_enabled(false)
	$UI/EndTurnButton.disabled = true

func _on_end_turn_pressed():
	if multiplayer.is_server():
		next_turn()
	else:
		rpc_id(1, "request_next_turn")

@rpc("any_peer")
func request_next_turn():
	if multiplayer.is_server():
		next_turn()

func _on_reset_button_pressed() -> void:
	get_tree().reload_current_scene()

@rpc("any_peer", "call_local")
func sync_discard_card():
	player_hand.discard()

func remove_card_from_player_hand(player_id: int, card_index: int) -> void:
	if !player_hands.has(player_id):
		return
		
	if card_index >= 0 and card_index < player_hands[player_id].size():
		player_hands[player_id].remove_at(card_index)
		print("Removed card at index ", card_index, " from player ", player_id, "'s hand")


func _on_discard_card_button_pressed() -> void:
	if multiplayer.is_server():
		rpc("sync_discard_card")
	else:
		rpc_id(1, "request_discard_cards")

@rpc("any_peer")
func request_discard_cards():
	if multiplayer.is_server():
		rpc("sync_discard_card")

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

@rpc("any_peer", "call_local")
func sync_draw_card(card_data: Dictionary) -> void:
	if multiplayer.is_server():
		return
		
	print("Receiving card data: ", card_data)
	var card_resource = CardResource.new()
	card_resource.from_dictionary(card_data)
	player_hand.draw(card_resource)

@rpc("any_peer")
func request_draw_card(is_action: bool):
	if multiplayer.is_server():
		var requesting_peer = multiplayer.get_remote_sender_id()
		var current_count = count_cards_by_type_for_player(
			requesting_peer,
			CardResource.CardType.ACTION if is_action else CardResource.CardType.AREA
		)
		var max_count = MAX_ACTION_CARDS if is_action else MAX_AREA_CARDS
		
		if current_count >= max_count:
			return
			
		var card = action_deck.draw_card() if is_action else area_deck.draw_card()
		if card:
			# Add to server's tracking
			player_hands[requesting_peer].append(card)
			# Send to specific client
			rpc_id(requesting_peer, "sync_draw_card", card.to_dictionary())

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
	if multiplayer.is_server():
		print("Server received card placement request from player: ", player_id)
		rpc("sync_card_played", card_data, slot_index, location_name, player_id)

func _on_draw_action_button_pressed():
	var player_id = multiplayer.get_unique_id()
	var current_count = count_cards_by_type(CardResource.CardType.ACTION)
	
	if current_count >= MAX_ACTION_CARDS:
		print("Cannot draw more action cards: limit reached")
		return
		
	if multiplayer.is_server():
		var card = action_deck.draw_card()
		if card:
			# Add to server's tracking
			player_hands[player_id].append(card)
			rpc("sync_draw_card", card.to_dictionary())
			# Update local hand
			player_hand.draw(card)
	else:
		rpc_id(1, "request_draw_card", true)

func _on_draw_area_button_pressed():
	if count_cards_by_type(CardResource.CardType.AREA) >= MAX_AREA_CARDS:
		print("Cannot draw more area cards: limit reached")
		return
		
	if multiplayer.is_server():
		var card = area_deck.draw_card()
		if card:
			rpc("sync_draw_card", card.to_dictionary())
	else:
		rpc_id(1, "request_draw_card", false)

func _setup_area_picking(node: Node) -> void:
	if node is Area3D:
		node.input_ray_pickable = true
		node.collision_layer = 1
		node.collision_mask = 1
	for child in node.get_children():
		_setup_area_picking(child)

@rpc("any_peer", "call_local")
func sync_card_played(card_data: Dictionary, slot_index: int, location_name: String, player_id: int) -> void:
	print("Syncing card played by player: ", player_id, " in location: ", location_name)
	
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
		print("Error: Could not find location: ", location_name)
		print("Available locations: ", locations.keys())

@rpc("any_peer", "call_local")
func add_player(player_id):
	if not players.has(player_id):
		players.append(player_id)

@rpc("any_peer", "call_local")
func remove_player(player_id):
	players.erase(player_id)

# Dice Events

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
