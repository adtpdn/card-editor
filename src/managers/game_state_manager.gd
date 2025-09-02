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
@onready var score_ui = $"../ScoreUI"
@onready var elementals_manager = $"../ElementalsManager"
@onready var soil_star_actions = $"../SoilStarActions"


const player_hud_scene = preload("res://scenes/player_ui/player_hud.tscn")

## PLANT ON BIOME AND PLANT SIGIL PHASE AND DRAW A CARD

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Game State Variables
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
var game_started = false
var current_round: int = 0
var round_count
var current_turn_index = 0
var max_players = 4 # Maximum players allowed
var initial_player_order: Array = [] # NEW: Stores the original player order for consistent color indexing.

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
# ---     Game Start/Setup     ---
# ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

func start_game():
	if multiplayer.is_server():
		game_started = true
		current_turn_index = 0
		var players = game.players
		
		if players.size() > 0:
			get_parent().rpc("sync_game_start", players)
			
			var first_player = players[current_turn_index]
			get_parent().rpc("set_current_turn", first_player)

@rpc("any_peer", "call_local", "reliable")
func sync_player_tokens(player_id: int, tokens: Array):
	if not token_manager:
		printerr("TokenManager not found!")
		return
	# Ensure tokens array contains full token state, including is_energy
	var synced_tokens = []
	for token in tokens:
		var token_data = {
			"id": token.get("id", -1), # Adjust based on your token structure
			"is_energy": token.get("is_energy", false), # Ensure is_energy is included
			"blighted": token.get("blighted", false), # Include other relevant properties
			# Add other token properties as needed
		}
		synced_tokens.append(token_data)
	token_manager.player_tokens[player_id] = synced_tokens
	token_manager.player_token_counts[player_id] = synced_tokens.size()
	token_manager.update_token_ui()

@rpc("call_local")
func sync_game_start(current_players):
	print("\n=== Starting Game ===")
	print("Initial players: " + str(current_players))
	
	game.game_started = true
	game.players = current_players
	
	# NEW: Store the initial player order if it hasn't been set yet.
	# This list will NOT be reordered and should be used for color assignments.
	if initial_player_order.is_empty():
		initial_player_order = current_players.duplicate()
		print("Initial player order for colors set: " + str(initial_player_order))
	
	current_turn_index = 0
	print("Starting turn index: " + str(current_turn_index))
	print("First player: " + str(game.players[current_turn_index]))
	
	set_current_turn(game.players[current_turn_index])
	
	for player_id in game.players:
		token_manager.initialize_player_tokens(player_id)
		
	update_turn_controls()
	update_player_hand_interaction()
	print("=== Game Start Complete ===\n")

# ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
# ---    Player Management     ---
# ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

# --- THIS IS THE NEW, AUTHORITATIVE FUNCTION FOR SYNCING PLAYERS ---
@rpc("any_peer", "call_local", "reliable")
func sync_player_list_and_uis(authoritative_player_list: Array):
	print("[%d] Received updated player list: %s" % [multiplayer.get_unique_id(), str(authoritative_player_list)])
	
	# Update the local game state with the official list from the server
	game.players = authoritative_player_list
	game.initial_player_order = authoritative_player_list
	
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
		ui_manager.update_player_hud() # MODIFIED CALL

func _add_player_ui(player_id: int, player_uis_node: Node):
	if player_uis_node.has_node("Player_%d_UI" % player_id):
		return # Safety check to prevent creating duplicates

	var hud_instance = player_hud_scene.instantiate()
	hud_instance.name = "Player_%d_UI" % player_id
	player_uis_node.add_child(hud_instance)
	print("Created UI for player %d" % player_id)

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
# ---     Turn Management      ---
# ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

func get_player_color_index(player_id: int) -> int:
	if initial_player_order.is_empty():
		# Fallback to current order if initial isn't set yet (should be rare)
		return game.players.find(player_id)
	
	var index = initial_player_order.find(player_id)
	return index if index != -1 else 0 # Return 0 as a safe default

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
	soil_star_actions.apply_button_rules()
	
	if ui_manager:
		ui_manager.update_player_hud()
	
	var player_hand = deck.hand
	if player_hand:
		print("Hand interaction initially disabled for local player (ID: " + str(multiplayer.get_unique_id()) + ")")
	
	update_turn_controls()
	
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

@rpc("any_peer")
func request_next_turn():
	if !multiplayer.is_server():
		return
	
	var requesting_player = multiplayer.get_remote_sender_id()
	var players = game.players
	
	print("\n=== Turn Change Request ===")
	print("Requesting player: ", requesting_player)
	print("Current turn player: ", players[current_turn_index])
	
	#if requesting_player == players[current_turn_index]:
	await next_turn() # Await the function
	
	print("=== Turn Change Request Complete ===\n")

func next_turn():
	if !multiplayer.is_server():
		return

	var players = game.players
	print("\n=== Processing Next Turn ===")
	print("Current players: ", players)
	print("Current turn index: ", current_turn_index)

	if players.size() > 0:
		var is_end_of_round = (current_turn_index == players.size() - 1)
		print("is end round : ", is_end_of_round)
		if is_end_of_round and current_round > 0:
			print("current round : ", current_round)
			
			print("Last player's turn ended. A full round is complete.")
			print("--- Checking for biome domination ---")
			await domination_manager.check_domination_for_elemental_flips()
			
			if current_round < 8:
				await domination_manager.check_domination_for_soil_stars()
				await reorder_players_after_round()

			advance_to_next_round() # Increase the current round

			if current_round < 9:
				# Process the blighted token cycle at the start of the turn transition.
				if is_instance_valid(token_manager):
					token_manager.process_blighted_token_cycle()
					await get_tree().create_timer(0.5).timeout # Short delay for visual clarity
				
					# Re-activate all face-up elementals for the new round.
				elementals_manager.activate_all_face_up_elementals()
		
		if is_end_of_round and current_round == 0 :
			advance_to_next_round()

		var current_player = players[current_turn_index]
		token_manager.save_player_token_count(current_player)
		
		var previous_player = players[current_turn_index]
		token_manager.reset_turn_token_counters(previous_player)
		
		# Explicitly sync blighted token state
		var tokens = token_manager.get_player_tokens(previous_player)

		# Advance Turn
		current_turn_index = (current_turn_index + 1) % players.size()
		
		var next_player = game.players[current_turn_index]
		
		tokens = token_manager.get_player_tokens(next_player)
		get_parent().rpc("set_current_turn", next_player)

	# --- NEW CHANGE: UPDATE SCORE AT END OF TURN ---
	if game.score_manager:
		game.score_manager.update_and_sync_all_scores()
	# ---------------------------------------------
	
	# END OF THE ROUND 
	if current_round >= 9:
		await get_tree().create_timer(4.0).timeout
		print("END GAME")
		score_ui.rpc("show_scores")
		return
	
	print("=== Next Turn Complete ===\n")

## Gets the soil star count for a given player from their UI node.
func _get_player_star_count(player_id: int) -> int:
	var soil_star_node_path = "/root/Game/PlayerUIs/Player_%d_UI/SoilStar" % player_id
	var soil_star_node = get_node_or_null(soil_star_node_path)
	
	if soil_star_node:
		# NOTE: This assumes the SoilStar node has a variable named 'current_soil_star'
		# that holds the integer value of the stars. Adjust if the name is different.
		if "current_soil_star" in soil_star_node:
			return soil_star_node.current_soil_star
		else:
			print("WARNING: SoilStar node for player %d is missing 'current_soil_star' variable." % player_id)
			return 0
	else:
		print("WARNING: Could not find SoilStar node for player %d at path: %s" % [player_id, soil_star_node_path])
		return 0

## Calculates and sets the new player turn order after a round is complete.
# card-editor/src/managers/game_state_manager.gd

## Calculates and sets the new player turn order after a round is complete.
func reorder_players_after_round():
	if not multiplayer.is_server():
		return

	print("\n=== Reordering Players for Next Round ===")
	var old_player_order = game.players.duplicate()
	if old_player_order.is_empty():
		print("No players to reorder.")
		return

	# Step 1: Get star counts for all players and find the maximum number of stars.
	var player_stats = {}
	var max_stars = -1
	for player_id in old_player_order:
		var stars = _get_player_star_count(player_id)
		player_stats[player_id] = stars
		if stars > max_stars:
			max_stars = stars
	
	print("Player star counts: ", player_stats)
	print("Maximum stars: ", max_stars)

	# Step 2: Find all players who are tied for the maximum star count.
	var winners = []
	# Only reorder if at least one player has more than 0 stars.
	if max_stars > 0: 
		for player_id in player_stats:
			if player_stats[player_id] == max_stars:
				winners.append(player_id)
	
	print("Players with max stars (winners): ", winners)

	# If the player who went first is in the winners list, we remove them
	# so they cannot become the first player again in the next round.
	if old_player_order.size() > 0:
		var first_player_last_round = old_player_order[0]
		if winners.has(first_player_last_round):
			print("Excluding Player %d (first player of last round) from winning." % first_player_last_round)
			winners.erase(first_player_last_round)
			print("Remaining potential winners: ", winners)

	# Step 3: Determine the new first player using your specified rules.
	var new_first_player = -1
	
	# Case 1: No one earned stars. The last player from this round goes first next round.
	if winners.is_empty():
		new_first_player = old_player_order.back()
	
	# Case 2: There is one clear winner with the most stars.
	elif winners.size() == 1:
		new_first_player = winners[0]
	
	# Case 3 (TIE-BREAKER): Multiple players are tied for the most stars.
	else:
		# This finds the tied player who appeared EARLIEST in the turn order.
		for i in range(old_player_order.size() - 1, -1, -1):
			var player_id = old_player_order[i]
			if winners.has(player_id):
				new_first_player = player_id
				break
	
	# This is a fallback, but it should not be reached if there are players.
	if new_first_player == -1:
		print("Could not determine a new first player. Keeping original order.")
		return

	print("New first player will be: ", new_first_player)

	# Step 4: Construct the new player order by rotating the old list,
	# starting with the new first player.
	var new_player_order = []
	new_player_order.append(new_first_player)

	var start_index = old_player_order.find(new_first_player)
	
	# Iterate through the old list, starting from the player AFTER the winner,
	# and append them to maintain the relative turn order.
	for i in range(1, old_player_order.size()):
		var current_index = (start_index + i) % old_player_order.size()
		new_player_order.append(old_player_order[current_index])
		
	print("Old player order: ", old_player_order)
	print("New player order: ", new_player_order)

	# Step 5: Update the game state with the new order and sync with all clients.
	game.players = new_player_order
	rpc("sync_new_player_order", new_player_order)

## RPC to synchronize the new turn order with all clients.
@rpc("any_peer", "call_local")
func sync_new_player_order(new_order: Array):
	print("[%d] Received new player order: %s" % [multiplayer.get_unique_id(), str(new_order)])
	game.players = new_order
	# Update any relevant UI, like a player list display
	if ui_manager:
		ui_manager.update_player_list()


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
	else:
		rpc_id(1, "request_next_turn")

func update_player_hand_interaction():
	var player_hand = deck.hand
	if !player_hand:
		return
		
	var local_player_id = multiplayer.get_unique_id()
	var is_my_turn = is_valid_player_turn(local_player_id)
	
	print("Updated hand interaction: " + ("enabled" if is_my_turn else "disabled"))

# Server-side function to increment the round and sync to clients
func advance_to_next_round():
	if multiplayer.is_server():
		current_round += 1
		# Clear the last biome placements for the new round
		get_parent().player_last_biome_placements.clear()
		print("Server advancing to round: ", current_round, " - Cleared last biome placements.")
		# Explicitly sync the new round number to all clients
		rpc("sync_current_round", current_round)

# Client-side RPC to receive the updated round number
@rpc("any_peer", "call_local", "reliable")
func sync_current_round(new_round: int):
	current_round = new_round
	print("[%d] Received updated round: %d" % [multiplayer.get_unique_id(), current_round])
	if current_round == 1:
		turn_phase_manager.count_plant = 0
