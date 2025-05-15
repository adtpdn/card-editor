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
@onready var dice_manager = $DiceManager
@onready var point_counter = $PointCounter

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Core Game State
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
var game_started = false
var players = []
var player_hands = {}
var player_slots = [false, false, false, false]  # Track occupied slots
var max_players = 4  # Maximum players allowed

# Color management for players
var player_colors = {}  # Mapping of player IDs to colors

const PLAYER_COLORS = [
	Color(1, 0, 0),     # Red
	Color(0, 1, 0),     # Green
	Color(0, 0, 1),     # Blue
	Color(1, 1, 0)      # Yellow
]

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Initialization
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
func _ready():
	print("Game initializing...")
	
	# Initialize all manager components
	token_manager.initialize()
	network_manager.initialize()
	game_state_manager.initialize()
	#ui_manager.initialize()
	
	# Connect input events to token manager
	set_process_input(true)
	print("Game initialized.")


func _input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# When clicking, pass to token manager for handling
		if token_manager:
			token_manager.handle_touch(event.position)

# ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
# ---  Network Synchronization ---
# ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

@rpc("any_peer", "call_local") 
func sync_game_state(game_players, has_started, placed):
	print("Syncing game state from server")
	players = game_players
	game_started = has_started
	
	# Update UI to reflect state
	ui_manager.update_player_list()
	token_manager.setup_player_token_indicators()

@rpc("any_peer", "call_local")
func sync_game_start(current_players):
	game_state_manager.sync_game_start(current_players)

@rpc("any_peer", "call_local")
func set_current_turn(player_id):
	game_state_manager.set_current_turn(player_id)

@rpc("any_peer", "call_local")
func sync_player_colors(colors: Dictionary):
	player_colors = colors.duplicate()
	game_state_manager.sync_player_colors(colors)

@rpc("any_peer", "call_local")
func sync_player_tokens(tokens: Array):
	token_manager.sync_player_tokens(tokens)

@rpc("any_peer", "call_local")
func sync_turn_state(new_turn_index: int):
	print("Syncing turn state: new index = " + str(new_turn_index))
	var current_turn_index = new_turn_index
	
	# Update local UI
	game_state_manager.update_turn_controls()
	token_manager.update_token_ui()

@rpc("any_peer")
func request_token_refresh():
	if !multiplayer.is_server():
		return
		
	var requesting_peer = multiplayer.get_remote_sender_id()
	var tokens = token_manager.get_player_tokens(requesting_peer)
	rpc_id(requesting_peer, "sync_player_tokens", tokens)

@rpc("any_peer", "call_local")
func sync_card_played(card_data: Dictionary, slot_index: int, location_name: String, player_id: int):
	card_manager.sync_card_played(card_data, slot_index, location_name, player_id)

@rpc("any_peer", "call_local")
func sync_draw_card(card_data: Dictionary):
	card_manager.sync_draw_card(card_data)

@rpc("any_peer", "call_local")
func receive_initial_hand(cards_data: Array):
	card_manager.receive_initial_hand(cards_data)

@rpc("any_peer")
func request_hand_resync():
	card_manager.request_hand_resync()

@rpc("any_peer")
func request_card_placement(card_data: Dictionary, slot_index: int, location_name: String, player_id: int):
	card_manager.request_card_placement(card_data, slot_index, location_name, player_id)

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

@rpc("any_peer")
func roll_dice(player_id: int):
	dice_manager.roll_dice(player_id)

@rpc("any_peer", "call_local")
func sync_dice_result(result: int, player_id: int):
	dice_manager.sync_dice_result(result, player_id)

# ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
# ---   Game Engine Handlers   ---
# ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

func _process(delta: float) -> void:
	# Let each manager handle their own processing
	pass

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		# Cleanup network connections when game is closed
		network_manager.cleanup_network()
		get_tree().quit()
