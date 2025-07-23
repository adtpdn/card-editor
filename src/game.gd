# game.gd
extends Node

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Manager References
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
@onready var token_manager = $TokenManager
@onready var network_manager = $NetworkManager
@onready var game_state_manager = $GameStateManager
@onready var card_manager = $CardManager
@onready var ui_manager = $UIManager
@onready var sigil_manager = $SigilManager
@onready var turn_phase_manager = $TurnPhaseManager
@onready var point_counter = $PointCounter
@onready var deck = $Deck
@onready var token_placements = $TokenPlacements
@onready var tokens = $Tokens
@onready var notification = $Notification
@onready var soil_star_actions = $SoilStarActions
@onready var player_uis = $PlayerUIs

@onready var sigil_a_button = $SigilContainer/SigilAButton
@onready var sigil_b_button = $SigilContainer/SigilBButton
@onready var sigil_c_button = $SigilContainer/SigilCButton
@onready var token_button = $RightUI/TokenButton
@onready var end_turn_button = $RightUI/EndTurnButton
@onready var end_phase_button = $RightUI/EndPhaseButton

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Core Game State
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
var game_started = false
var players = [] # This list stores the CURRENT TURN ORDER and will be re-sorted.
var initial_player_order: Array = [] # NEW: This stores the PERMANENT JOIN ORDER for colors.
var player_hands = {}
var player_slots = [false, false, false, false] # Track occupied slots
var max_players = 4 # Maximum players allowed

# --- FIX ---
# Player colors are now defined here in the main game script.
const player_colors = [
	Color(1, 0, 0),# Red
	Color(0, 1, 0),# Green
	Color(0, 0, 1),# Blue
	Color(1, 1, 0) # Yellow
]

signal turn_changed

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Initialization
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
func _ready():
	print("Game initializing...")
	
	# Initialize all manager components
	token_manager.initialize()
	network_manager.initialize()
	game_state_manager.initialize()
	
	# Don't call initialize_starting_hand here, let start_game do it
	# card_manager.initialize_starting_hand()
	
	# Start the game - this will handle card initialization
	start_game()
	
	if has_node("TurnPhaseManager"):
		turn_phase_manager.initialize()
	if has_node("SigilManager"):
		$SigilManager.initialize()
	
	# Connect input events to token manager
	set_process_input(true)
	print("Game initialized.")

func start_game():
	# Debug the card_manager initialization
	print("Starting game - initializing card system")
	
	if multiplayer.is_server():
		game_started = true
		

		
	# Initialize the deck with a seed first
	$Deck/Table.initialize_deck_with_seed(randi())
	
	# Draw initial cards for the host player
	card_manager.initialize_starting_hand()
	
	# If there are clients, they will get their cards when they connect
	if network_manager.multiplayer.is_server() and network_manager.multiplayer.get_peers().size() > 0:
		for peer_id in network_manager.multiplayer.get_peers():
			# Send the current deck state to the connected peer
			network_manager.rpc_id(peer_id, "receive_deck_seed", $Deck/Table.deck_seed)
			network_manager.rpc_id(peer_id, "receive_deck_state", $Deck/Table.available_cards)
			
			# Tell the client to initialize their starting hand
			rpc_id(peer_id, "initialize_client_starting_hand")

	# Sync game state to all clients
	rpc("sync_game_state", players, game_started)

# ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
# ---  	Color Management 	  ---
# ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

## NEW HELPER FUNCTION
## Returns the permanent color index for a player based on their initial join order.
func get_player_color_index(player_id: int) -> int:
	if initial_player_order.is_empty():
		# Fallback to current order if initial isn't set yet (should be rare)
		print("WARNING: initial_player_order is empty in game.gd. Falling back to game.players for color index.")
		return players.find(player_id)
	
	var index = initial_player_order.find(player_id)
	return index if index != -1 else 0 # Return 0 as a safe default

# ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
# ---  Network Synchronization ---
# ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
@rpc("any_peer", "call_local", "reliable")
func sync_player_list(updated_players: Array):
	# Ensure the local player list matches the server's master list
	self.players = updated_players

	print("[%s] Player list synced. Current players: %s" % [multiplayer.get_unique_id(), str(self.players)])

	# After syncing the data, update the UI accordingly
	if ui_manager:
		ui_manager.update_player_list()

## NEW RPC
## RPC to ensure all clients have the same permanent color order list.
@rpc("any_peer", "call_local", "reliable")
func sync_initial_order(order_from_server: Array):
	if initial_player_order.is_empty():
		initial_player_order = order_from_server
		print("[%d] Received and set initial player order for colors in game.gd: %s" % [multiplayer.get_unique_id(), str(initial_player_order)])

@rpc("any_peer", "call_remote")
func initialize_client_starting_hand():
	print("Client initializing starting hand...")
	card_manager.initialize_starting_hand()
	
	# Debug the client's hand after initialization
	print("Client hand after initialization:")
	if card_manager.player_hand:
		for i in range(card_manager.player_hand.cards.size()):
			var card = card_manager.player_hand.cards[i]
			print("Client hand card", i, "card_id:", card.card_id, "name:", card.card_name)

@rpc("any_peer", "call_local")
func sync_game_state(game_players, has_started):
	print("Syncing game state from server")
	players = game_players
	game_started = has_started
	initial_player_order = game_players
	
	# Update UI to reflect state
	ui_manager.update_player_list()

	# Request initial cards if client hasn't received any yet
	if !multiplayer.is_server() and game_started:
		var local_id = multiplayer.get_unique_id()
		if !player_hands.has(local_id) or player_hands[local_id].size() == 0:
			#card_manager.rpc_id(1, "request_initial_cards")
			pass

@rpc("any_peer", "call_local")
func sync_game_start(current_players):
	game_state_manager.sync_game_start(current_players)

@rpc("any_peer", "call_local")
func set_current_turn(player_id):
	game_state_manager.set_current_turn(player_id)

@rpc("any_peer", "call_local")
func sync_player_colors(colors: Dictionary):
	# This function might be deprecated now but keeping it for safety.
	# The new system relies on the initial_player_order.
	game_state_manager.sync_player_colors(colors)

@rpc("any_peer", "call_local")
func sync_player_tokens(tokens: Array):
	for id in players.size():
		token_manager.sync_player_tokens(tokens, players[id])

@rpc("any_peer", "call_local")
func sync_turn_state(new_turn_index: int):
	print("Syncing turn state: new index = " + str(new_turn_index))
	var current_turn_index = new_turn_index
	
	# Update local UI
	game_state_manager.update_turn_controls()
	token_manager.update_token_ui()

@rpc("any_peer", "call_local")
func sync_blight_animation(token_pos: Vector3, is_blighted: bool):
	# Find the token at the given position.
	var token = token_manager.find_token_at_position(token_pos) # You need a helper function for this.
	
	if token:
		# Tell the token to ONLY play the animation.
		token.play_blight_animation(is_blighted)

@rpc("any_peer", "call_local")
func sync_token_blight(token_position: Vector3, is_blighted: bool):
	# Forward to token manager to handle the actual state change
	token_manager.sync_token_blight(token_position, is_blighted)

@rpc("any_peer")
func request_token_refresh():
	if !multiplayer.is_server():
		return
		
	var requesting_peer = multiplayer.get_remote_sender_id()
	var tokens = token_manager.get_player_tokens(requesting_peer)
	rpc_id(requesting_peer, "sync_player_tokens", tokens)

@rpc("any_peer")
func request_card_placement(card_data: Dictionary, slot_index: int, location_name: String, player_id: int):
	card_manager.request_card_placement(card_data, slot_index, location_name, player_id)

@rpc("any_peer")
func request_game_state_sync(requesting_peer_id):
	if !multiplayer.is_server():
		return
		
	var actual_requesting_peer = multiplayer.get_remote_sender_id()
	print("Client ", actual_requesting_peer, " requested game state sync")
	
	# --- FIX ---
	# When a client requests a sync, also send them the permanent color order.
	rpc_id(actual_requesting_peer, "sync_initial_order", initial_player_order)
	
	# Send full game state to the requesting client
	rpc_id(actual_requesting_peer, "sync_game_state", players, game_started)
	
	# Also send turn state
	rpc_id(actual_requesting_peer, "sync_turn_state", game_state_manager.current_turn_index)

@rpc("any_peer")
func request_draw_card(is_action: bool):
	card_manager.request_draw_card(is_action)

@rpc("any_peer", "call_local")
func sync_discard_card():
	card_manager.sync_discard_card()

@rpc("any_peer")
func request_discard_cards():
	card_manager.request_discard_cards()

@rpc("any_peer", "call_local")
func sync_token_placement(token_data: Dictionary, position: Vector3, player_id: int):
	token_manager.sync_token_placement(token_data, position, player_id)

@rpc("any_peer")
func request_token_placement(token_index: int, position: Vector3, biome_type: int = -1):
	if !multiplayer.is_server():
		return
		
	var player_id = multiplayer.get_remote_sender_id()
	if player_id == 0:
		player_id = multiplayer.get_unique_id()
	
	# Forward the request to the token manager
	if token_manager:
		token_manager.request_token_placement(token_index, position, biome_type)
	else:
		print("ERROR: token_manager not found")

@rpc("any_peer")
func request_next_turn():
	game_state_manager.request_next_turn()

@rpc("any_peer", "call_local")
func add_player(player_id):
	game_state_manager.add_player(player_id)

@rpc("any_peer", "call_local")
func remove_player(player_id):
	game_state_manager.remove_player(player_id)


# ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
# ---   Game Engine Handlers   ---
# ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

func _process(delta: float) -> void:
	# Let each manager handle their own processing
	pass

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		# Cleanup network connections when game is closed
		network_manager.cleanup_network()
		get_tree().quit()


# ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
# ---      Point Counter       ---
# ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

func request_point_adjustment(biome: String, delta: int):
	if multiplayer.is_server():
		# Server directly adjusts the points
		adjust_points(biome, delta)
	else:
		# Client sends request to server
		rpc_id(1, "receive_point_adjustment_request", biome, delta)

@rpc("any_peer")
func receive_point_adjustment_request(biome: String, delta: int):
	if !multiplayer.is_server():
		return
		
	# Validate it's the player's turn
	var requesting_player = multiplayer.get_remote_sender_id()
	if game_state_manager.is_valid_player_turn(requesting_player):
		adjust_points(biome, delta)

func adjust_points(biome: String, delta: int):
	if !point_counter:
		return
		
	# Get current points
	var current_points = point_counter.get_points(biome)
	
	# Calculate new value with validation
	var new_value = point_counter.validate_points(current_points + delta)
	
	# Set the points
	point_counter.set_points(biome, new_value)
	
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

@rpc("any_peer", "call_local")
func sync_card_planted(card_data: Dictionary, biome_slot: int, player_id: int):
	# This function will handle the visual representation of cards
	# being planted by other players
	
	if player_id == multiplayer.get_unique_id():
		# Skip if it's our own card - we already handled it locally
		return
		
	print("Received card plant from player", player_id, "to biome", biome_slot)
	
	# Create a card instance for the other player's action
	var card = card_manager.create_remote_card(card_data, biome_slot)
	
	# Place it in the right slot
	var target_slot = null
	match biome_slot:
		0: target_slot = $Deck/Table/DragController/CardSlotBiome1
		1: target_slot = $Deck/Table/DragController/CardSlotBiome2
		2: target_slot = $Deck/Table/DragController/CardSlotBiome3
		3: target_slot = $Deck/Table/DragController/CardSlotBiome4
	
	if target_slot and card:
		# Set a flag to prevent it from re-triggering effects
		card.set_meta("remote_planted", true)
		target_slot.append_card(card)
