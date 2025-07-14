# game_state_manager.gd
extends Node

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# References to other managers
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
@onready var game = get_parent()
@onready var token_manager = $"../TokenManager"
@onready var network_manager = $"../NetworkManager"
@onready var card_manager = $"../CardManager"
@onready var ui_manager = $"../UIManager"
@onready var point_counter = $"../PointCounter"
@onready var turn_phase_manager = $"../TurnPhaseManager"
@onready var deck = $"../Deck"
@onready var player_turn = $"../PlayerTurn"
@onready var domination_manager = $"../DominationManager"

const player_hud_scene = preload("res://scenes/player_hud.tscn")

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Game State Variables
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
var game_started = false
var current_turn_index = 0
var max_players = 4 # Maximum players allowed

# Color management for players
var player_colors = {} # Mapping of player IDs to colors

const PLAYER_COLORS = [
	Color(1, 0, 0),# Red
	Color(0, 1, 0),# Green
	Color(0, 0, 1),# Blue
	Color(1, 1, 0) # Yellow
]

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Initialization
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
func _ready():
	# Connect end turn button
	var end_turn_button = get_parent().get_node("RightUI/EndTurnButton")
	if end_turn_button:
		if end_turn_button.pressed.is_connected(_on_end_turn_pressed):
			end_turn_button.pressed.disconnect(_on_end_turn_pressed)
		end_turn_button.pressed.connect(_on_end_turn_pressed)

func initialize():
	# Initial setup
	game_started = false
	current_turn_index = 0

# ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
# ---     Game Start/Setup     ---
# ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

func start_game():
	if multiplayer.is_server():
		game_started = true
		current_turn_index = 0
		var players = game.players
		
		if players.size() > 0:
			print("\n=== Starting Game ===")
			print("Initial players: ", players)
			print("Starting turn index: ", current_turn_index)
			
			get_parent().rpc("sync_game_start", players)
			
			var first_player = players[current_turn_index]
			print("First player: ", first_player)
			get_parent().rpc("set_current_turn", first_player)
			
			print("=== Game Start Complete ===\n")
		else:
			print("No players available to start game")

func start_game_with_first_player(first_player_id):
	if multiplayer.is_server():
		game_started = true
		var players = game.players
		current_turn_index = players.find(first_player_id)
		
		if players.size() > 0:
			print("\n=== Starting Game ===")
			print("Initial players: ", players)
			print("Starting turn index: ", current_turn_index)
			
			get_parent().rpc("sync_game_start", players)
			
			print("First player: ", first_player_id)
			get_parent().rpc("set_current_turn", first_player_id)
			
			print("=== Game Start Complete ===\n")
		else:
			print("No players available to start game")

func _on_start_game_pressed():
	var player_list = get_parent().get_node("LeftUI/PlayerList")
	
	if multiplayer.is_server():
		var selected_items = player_list.get_selected_items()
		if selected_items.size() > 0:
			var selected_index = selected_items[0]
			var players = game.players
			if selected_index < players.size():
				var first_player_id = players[selected_index]
				start_game_with_first_player(first_player_id)

@rpc("any_peer", "call_local", "reliable")
func sync_player_tokens(player_id: int, tokens: Array):
	if not token_manager:
		printerr("TokenManager not found!")
		return
	token_manager.player_tokens[player_id] = tokens
	token_manager.player_token_counts[player_id] = tokens.size()
	token_manager.update_token_ui()

@rpc("call_local")
func sync_game_start(current_players):
	print("\n=== Starting Game ===")
	print("Initial players: " + str(current_players))
	
	game.game_started = true
	game.players = current_players
	
	current_turn_index = 0
	print("Starting turn index: " + str(current_turn_index))
	print("First player: " + str(game.players[current_turn_index]))
	
	set_current_turn(game.players[current_turn_index])
	
	for player_id in game.players:
		token_manager.initialize_player_tokens(player_id)
		
	update_turn_controls()
	debug_turn_state()
	update_player_hand_interaction()
	print("=== Game Start Complete ===\n")

# ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
# ---    Player Management     ---
# ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

# --- THIS IS THE NEW, AUTHORITATIVE FUNCTION FOR SYNCING PLAYERS ---
@rpc("any_peer", "call_local", "reliable")
func sync_player_list_and_uis(authoritative_player_list: Array):
	print("[%d] Received updated player list: %s" % [multiplayer.get_unique_id(), str(authoritative_player_list)])
	
	# Update the local game state with the official list from the server
	game.players = authoritative_player_list
	
	var player_uis_node = get_node_or_null("/root/Game/PlayerUIs")
	if not player_uis_node:
		printerr("GameStateManager: ERROR! Could not find the PlayerUIs node.")
		return
		
	# 1. REMOVE UIs for players who have disconnected
	for child in player_uis_node.get_children():
		var id_str = child.name.trim_prefix("Player_").trim_suffix("_UI")
		if id_str.is_valid_int():
			var ui_player_id = id_str.to_int()
			if not authoritative_player_list.has(ui_player_id):
				print("Removing stale UI for disconnected player %d" % ui_player_id)
				child.queue_free()

	# 2. ADD UIs for new players who don't have one yet
	for player_id in authoritative_player_list:
		if not player_uis_node.has_node("Player_%d_UI" % player_id):
			print("Player %d is new. Creating their UI." % player_id)
			_add_player_ui(player_id, player_uis_node)

	# 3. SET VISIBILITY for each UI based on the local player's ID.
	var local_player_id = multiplayer.get_unique_id()
	for child_ui in player_uis_node.get_children():
		var id_str = child_ui.name.trim_prefix("Player_").trim_suffix("_UI")
		if id_str.is_valid_int():
			var ui_owner_id = id_str.to_int()
			# The UI is visible ONLY if its owner ID matches the local player's ID.
			child_ui.visible = (ui_owner_id == local_player_id)
	
	# 4. (Optional but Recommended) Update other UI elements after changes
	if ui_manager:
		ui_manager.update_player_list()
	if token_manager:
		token_manager.setup_player_token_indicators()

# ----------------------------------------------------

func setup_player(player_id: int) -> void:
	var player_hand = deck.hand
	
	if player_id == multiplayer.get_unique_id():
		if multiplayer.is_server() and !token_manager.player_tokens.has(player_id):
			token_manager.initialize_player_tokens(player_id)
			var tokens = token_manager.get_player_tokens(player_id)
			token_manager.update_token_ui()
			
			token_manager.player_token_counts[player_id] = tokens.size()
	
	if multiplayer.is_server() and !token_manager.player_tokens.has(player_id):
		token_manager.initialize_player_tokens(player_id)
		
		var tokens = token_manager.get_player_tokens(player_id)
		token_manager.player_token_counts[player_id] = tokens.size()
		
		if player_id != multiplayer.get_unique_id():
			get_parent().rpc_id(player_id, "sync_player_tokens", tokens)

# This function is now only for creating the UI, not for managing the player list.
# It is NOT an RPC.
func _add_player_ui(player_id: int, player_uis_node: Node):
	if player_uis_node.has_node("Player_%d_UI" % player_id):
		return # Safety check to prevent creating duplicates

	var hud_instance = player_hud_scene.instantiate()
	hud_instance.name = "Player_%d_UI" % player_id
	player_uis_node.add_child(hud_instance)
	print("Created UI for player %d" % player_id)


@rpc("any_peer", "call_local")
func remove_player(player_id):
	if game.players.has(player_id):
		game.players.erase(player_id)
	
	var hud_node = get_node_or_null("/root/Game/PlayerUIs/Player_%d_UI" % player_id)
	if hud_node:
		hud_node.queue_free()
		print("Removed UI for player %d." % player_id)

@rpc("any_peer", "call_local")
func sync_player_colors(colors: Dictionary):
	player_colors = colors.duplicate()
	if get_parent().has_node("Tokens"):
		for token in get_parent().get_node("Tokens").get_children():
			if token.has_method("update_token_display"):
				token.update_token_display()

# ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
# ---     Turn Management      ---
# ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

func debug_turn_state():
	var end_turn_button = get_parent().get_node("RightUI/EndTurnButton")
	var players = game.players
	var current_player_id = multiplayer.get_unique_id()
	
	print("\n=== TURN STATE DEBUG ===")
	print("Button exists: " + str(end_turn_button != null))
	if end_turn_button:
		print("Button disabled: " + str(end_turn_button.disabled))
	print("Game started: " + str(game.game_started))
	print("Players: " + str(players))
	print("Current turn index: " + str(current_turn_index))
	if players.size() > 0 and current_turn_index >= 0 and current_turn_index < players.size():
		print("Current turn player: " + str(players[current_turn_index]))
	else:
		print("Current turn player: Invalid index")
	print("Local player ID: " + str(current_player_id))
	print("Is valid turn: " + str(is_valid_player_turn(current_player_id)))
	print("=== END DEBUG ===\n")

func update_turn_controls():
	var end_turn_button = get_parent().get_node("RightUI/EndTurnButton")
	if !end_turn_button:
		print("End turn button not found!")
		return
	
	var current_player_id = multiplayer.get_unique_id()
	
	var players = game.players
	var game_started = game.game_started
	
	var is_my_turn = false
	if game_started and players.size() > 0:
		if current_turn_index >= 0 and current_turn_index < players.size():
			is_my_turn = (current_player_id == players[current_turn_index])
	
	end_turn_button.disabled = !is_my_turn
	
	if is_my_turn:
		end_turn_button.modulate = Color(1, 1, 1, 1)
	else:
		end_turn_button.modulate = Color(0.5, 0.5, 0.5, 0.5)
	
	print("Updated turn controls. Is my turn: " + str(is_my_turn) + ", Button disabled: " + str(end_turn_button.disabled))

func get_current_player_id() -> int:
	var players = game.players
	if is_valid_turn_index():
		return players[current_turn_index]
	return -1

func is_valid_player_turn(player_id: int) -> bool:
	if !get_parent().game_started:
		return false
	
	var players = get_parent().players
	
	if players.is_empty() or current_turn_index < 0 or current_turn_index >= players.size():
		return false
	
	var current_player = players[current_turn_index]
	var is_my_turn = (player_id == current_player)
	
	return is_my_turn

func is_valid_turn_index() -> bool:
	var players = game.players
	return current_turn_index >= 0 and current_turn_index < players.size()

@rpc("any_peer", "call_local")
func set_current_turn(player_id: int):
	print("Setting turn for player: " + str(player_id) + " (local: " + str(multiplayer.get_unique_id()) + ")")
	
	var player_index = -1
	for i in range(game.players.size()):
		if game.players[i] == player_id:
			player_index = i
			break
	
	if player_index == -1:
		print("ERROR: Player " + str(player_id) + " not found in player list: " + str(game.players))
		return
	
	current_turn_index = player_index
	
	token_manager.update_token_ui()
	
	var player_hand = deck.hand
	if player_hand:
		print("Hand interaction initially disabled for local player (ID: " + str(multiplayer.get_unique_id()) + ")")
	
	update_turn_controls()
	debug_turn_state()
	
	if turn_phase_manager:
		print("Resetting turn phase manager")
		turn_phase_manager.reset_phases()
	else:
		print("Warning: turn_phase_manager not found!")
	
	if player_id == multiplayer.get_unique_id():
		print("My turn started, requesting token sync")
	
	get_parent().emit_signal("turn_changed")
	player_turn._check_for_turn_changes()
	
	print("Current turn index set to: " + str(current_turn_index) + " (Player " + str(game.players[current_turn_index]) + ")")


func enable_player_turn():
	var player_hand = get_parent().get_node("HandAreas/PlayerHand")
	var end_turn_button = get_parent().get_node("RightUI/EndTurnButton")
	
	if player_hand:
		player_hand.set_interaction_enabled(true)
	
	if end_turn_button:
		end_turn_button.disabled = false

func disable_player_turn():
	var player_hand = get_parent().get_node("HandAreas/PlayerHand")
	var end_turn_button = get_parent().get_node("RightUI/EndTurnButton")
	
	if player_hand:
		player_hand.set_interaction_enabled(false)
	
	if end_turn_button:
		end_turn_button.disabled = true

@rpc("any_peer")
func request_next_turn():
	if !multiplayer.is_server():
		return
	
	var requesting_player = multiplayer.get_remote_sender_id()
	var players = game.players
	
	print("\n=== Turn Change Request ===")
	print("Requesting player: ", requesting_player)
	print("Current turn player: ", players[current_turn_index])
	
	if requesting_player == players[current_turn_index]:
		next_turn()
	
	print("=== Turn Change Request Complete ===\n")

func next_turn():
	if !multiplayer.is_server():
		return
	
	var players = game.players
	
	print("\n=== Processing Next Turn ===")
	print("Current players: ", players)
	print("Current turn index: ", current_turn_index)
	
	if players.size() > 0:
		if current_turn_index == players.size() - 1:
			print("Last player's turn ended. A full round is complete.")
			print("--- Checking for biome domination ---")
			domination_manager.check_domination_biomes()
		
		var current_player = players[current_turn_index]
		token_manager.save_player_token_count(current_player)
		
		var previous_player = players[current_turn_index]
		var token_manager = get_parent().get_node("TokenManager")
		token_manager.reset_turn_token_counters(previous_player)
		
		current_turn_index = (current_turn_index + 1) % players.size()
		var next_player = players[current_turn_index]
		print("Next player: ", next_player)
		
		var tokens = token_manager.get_player_tokens(next_player)
		
		get_parent().rpc("set_current_turn", next_player)
		
		if next_player != multiplayer.get_unique_id():
			get_parent().rpc_id(next_player, "sync_player_tokens", tokens)
		else:
			game.sync_player_tokens(tokens)
		
		if point_counter:
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
	
	print("=== Next Turn Complete ===\n")

func _on_end_turn_pressed():
	var players = game.players
	if not is_valid_turn_index(): return
	var current_player = players[current_turn_index]
	
	token_manager.save_player_token_count(current_player)
	
	var end_turn_button = get_parent().get_node("RightUI/EndTurnButton")
	var end_phase_button = get_parent().get_node("RightUI/EndPhaseButton")
	
	print("end phase button : ", end_phase_button)
	var local_player_id = multiplayer.get_unique_id()
	if local_player_id == current_player:
		print("Disabling controls for current player: " + str(local_player_id))
		
		if end_turn_button:
			end_turn_button.disabled = true
		
		if end_phase_button:
			end_phase_button.disabled = true
	
	if multiplayer.is_server():
		next_turn()
		token_manager.reset_turn_token_counters(current_player)
		token_manager.sync_complete_token_state()
	else:
		get_parent().rpc_id(1, "request_next_turn")

func update_player_hand_interaction():
	var player_hand = deck.hand
	if !player_hand:
		return
		
	var local_player_id = multiplayer.get_unique_id()
	var is_my_turn = is_valid_player_turn(local_player_id)
	
	print("Updated hand interaction: " + ("enabled" if is_my_turn else "disabled"))

func reset_game():
	get_tree().reload_current_scene()
