# card_manager.gd
extends Node

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# References to other managers
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
@onready var game = get_parent()
@onready var sigil_manager = $"../SigilManager"
@onready var token_manager = $"../TokenManager"
@onready var network_manager = $"../NetworkManager"
@onready var game_state_manager = $"../GameStateManager"
@onready var ui_manager = $"../UIManager"
@onready var point_counter = $"../PointCounter"
@onready var deck = $"../Deck"


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Card System Variables
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
@onready var player_hand

var active_card
var max_action_cards = 3      # Maximum action cards a player can hold
var max_elemental_cards = 1   # Maximum elemental cards a player can hold
var initial_hand_size = 2     # Starting cards for each player
var network_synced = true
var hand_card_for_swap: FaceCard3D = null

# Add variables for card effects
var is_take_off_mode := false
var is_unblight_mode := false
var is_refresh_energy_mode := false
var is_swap_energy_mode := false
var is_plant_extra := false

var first_swap_token = null

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Initialization
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
func _ready():
	await get_parent().ready
	player_hand = deck.hand

func initialize_starting_hand():
	print("Initializing starting hand with", initial_hand_size, "cards for player", multiplayer.get_unique_id())

	player_hand = deck.hand

	if player_hand and player_hand.cards.size() > 0:
		print("Hand already has cards, skipping initialization.")
		return

	# Request the initial cards from the server.
	# The server will handle drawing and syncing.
	for i in range(initial_hand_size):
		# We are requesting a non-elemental (action) card.
		var player_id = multiplayer.get_unique_id()

		# If the current instance is the server, it calls the function directly.
		# If it's a client, it sends an RPC to the server (ID 1).
		if multiplayer.is_server():
			deck.table.server_draw_card(player_id, false)
		else:
			deck.table.rpc_id(1, "request_server_draw_card", player_id, false)

# ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
# --- Card Distribution & Deck  ---
# ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
func is_hand_full(player_id: int):
	if not player_hand:
		player_hand = deck.hand
	
	var card_count = 0
	for card in player_hand.cards:
		if card.owner_id == player_id:
			card_count += 1
			
	return card_count >= (max_action_cards + max_elemental_cards)

# MODIFIED: This function now takes a player_id to check a specific player's hand.
func is_action_hand_full(player_id: int):
	if not player_hand:
		player_hand = deck.hand
	var action_card_count = 0
	for card in player_hand.cards:
		if card.owner_id == player_id and card.card_type == CardResource.CardType.ACTION:
			action_card_count += 1
	return action_card_count >= max_action_cards

# MODIFIED: This function now takes a player_id to check a specific player's hand.
func is_elemental_hand_full(player_id: int):
	if not player_hand:
		player_hand = deck.hand
	var elemental_card_count = 0
	for card in player_hand.cards:
		if card.owner_id == player_id and card.card_type == CardResource.CardType.ELEMENTAL:
			elemental_card_count += 1
	return elemental_card_count >= max_elemental_cards

# ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
# --- Card Drawing & Discarding ---
# ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
func draw_card():
	player_hand = deck.hand
	if player_hand.cards.size() < (max_action_cards + max_elemental_cards):
		# Use the table's add_card method to draw a card
		# The network sync is handled inside add_card(), so we don't need to do it here
		var success = deck.table.add_card()
		return success

		return true
	else:
		print("Hand is full! Maximum cards:", (max_action_cards + max_elemental_cards))
		return false

func draw_specific_card(card_index: int):
	player_hand = deck.hand
	if player_hand.cards.size() < (max_action_cards + max_elemental_cards):
		var card = deck.table.instantiate_face_card(card_index)
		if card:
			player_hand.append_card(card)
			card.global_position = deck.global_position
			return true
		return false
	else:
		print("Hand is full! Cannot draw more cards.")
		return false

# Add this method for when a card is actually drawn
func sync_card_drawn(card_index: int):
	if network_synced and network_manager:
		network_manager.sync_card_drawn(card_index)

# ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
# ---   Card Event Handlers    ---
# ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
func execute_card_effect(card_id: int):
	print("Executing card effect for card ID: ", card_id)

	match card_id:
		0: # Unblight Our Own Token
			unblight_card_effect()
		1: # Take Off enemy or our energy token
			take_off_card_effect()
		2: # Swap Energy
			swap_energy_card_effect()
		3: # Refresh Energy
			refresh_energy_card_effect()
		4: # Plant Extra Token or Energy
			plant_extra_card_effect()
		_:
			print("Unknown card ID: ", card_id)

# ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
# ---   Card Utility Methods   ---
# ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
func create_remote_card(card_data: Dictionary, biome_slot: int) -> FaceCard3D:
	var card_id = card_data["card_id"] if card_data.has("card_id") else -1

	# Create the card instance
	var face_card = deck.table.instantiate_face_card(card_id)
	if !face_card:
		print("Failed to instantiate remote card")
		return null

	face_card.card_on_biome = biome_slot

	return face_card

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Start of Card Effect Logic
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
func unblight_card_effect():
	print("unblight card effect")
	is_unblight_mode = true

	# Ensure token selection mode is off
	token_manager.is_token_selected = false
	# Highlight our token.is_blighted
	var tokens = token_manager.tokens
	var player_id = multiplayer.get_unique_id()
	for token in tokens.get_children():
		if !token.is_energy and token.owner_id == player_id and token.is_blighted:
			token.outerglow.show()

	token_manager.unhighlight_all_token_placements()
	token_manager.update_token_ui()

func take_off_card_effect():
	print("take off card effect")
	is_take_off_mode = true

	# Ensure token selection mode is off
	token_manager.is_token_selected = false

	# Highlight our token.is_blighted
	var tokens = token_manager.tokens
	for token in tokens.get_children():
		if token.is_energy:
			token.outerglow.show()

	token_manager.unhighlight_all_token_placements()
	token_manager.update_token_ui()

func refresh_energy_card_effect():
	print("refresh energy card effect")
	is_refresh_energy_mode = true

	# Ensure token selection mode is off
	token_manager.is_token_selected = false

	# Highlight our token.is_blighted
	var tokens = token_manager.tokens
	var player_id = multiplayer.get_unique_id()
	for token in tokens.get_children():
		if token.is_energy and token.owner_id == player_id and token.is_blighted:
			token.outerglow.show()

	token_manager.unhighlight_all_token_placements()
	token_manager.update_token_ui()

func swap_energy_card_effect():
	print("swap energy card effect")
	is_swap_energy_mode = true
	is_take_off_mode = false
	is_unblight_mode = false
	is_refresh_energy_mode = false
	first_swap_token = null  # Reset first token selection

	# Ensure token selection mode is off
	token_manager.is_token_selected = false

	# Highlight our token.is_blighted
	var tokens = token_manager.tokens
	var player_id = multiplayer.get_unique_id()
	for token in tokens.get_children():
		if token.is_energy and token.owner_id == player_id:
			token.outerglow.show()

	token_manager.unhighlight_all_token_placements()
	token_manager.update_token_ui()

func plant_extra_card_effect():
	print("plant extra token card effect")
	var player_id = multiplayer.get_unique_id()

	# Temporarily increase max tokens per turn by 1
	token_manager.max_tokens_per_turn += 1

	# Set the plant extra flag
	is_plant_extra = true

	# Enable placing on both sigil and biome locations
	token_manager.can_plant_on_sigil = true
	token_manager.can_plant_on_biome = true

	# Sync changes to all clients if we're the server
	if multiplayer.is_server():
		token_manager.rpc("sync_token_planting_state", player_id, token_manager.tokens_planted_this_turn.get(player_id, 0),
			true, true, token_manager.max_tokens_per_turn)
	else:
		# Request server to sync our changes
		rpc_id(1, "request_token_planting_state_update", player_id, true, true, token_manager.max_tokens_per_turn)

	# Update UI to show token button as active
	token_manager.update_token_ui()

# -----------------------------------------------------------------------------
# HELPER FUNCTIONS ( Networking Card Plant)
# -----------------------------------------------------------------------------
# Extra Plant TOken
@rpc("any_peer")
func request_token_planting_state_update(player_id: int, can_place_sigil: bool, can_place_biome: bool, max_tokens: int):
	if !multiplayer.is_server():
		return

	var requesting_player = multiplayer.get_remote_sender_id()
	if requesting_player != player_id:
		return  # Only allow players to update their own state

	var tokens_planted_this_turn = token_manager.tokens_planted_this_turn

	# Update server's state
	if tokens_planted_this_turn.has(player_id):
		tokens_planted_this_turn[player_id] = tokens_planted_this_turn[player_id]  # Keep current value
	else:
		tokens_planted_this_turn[player_id] = 0

	# Update flags
	token_manager.can_plant_on_sigil = can_place_sigil
	token_manager.can_plant_on_biome = can_place_biome
	token_manager.max_tokens_per_turn = max_tokens

	# Sync to all clients
	token_manager.rpc("sync_token_planting_state", player_id, tokens_planted_this_turn[player_id],
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
	var first_token = token_manager.find_token_at_position(first_token_position)
	if !first_token or first_token.owner_id != player_id:
		return

	# Process the token swap
	swap_energy_tokens(first_token_position, second_token_position)
	print("Server processed token swap between: " + str(first_token_position) + " and " + str(second_token_position))

func swap_energy_tokens(first_token_position: Vector3, second_token_position: Vector3):
	# Find both tokens
	var first_token = token_manager.find_token_at_position(first_token_position)
	var second_token = token_manager.find_token_at_position(second_token_position)

	if !first_token or !second_token:
		print("One or both tokens not found")
		return

	# Verify both are energy tokens in the same biome
	if !first_token.is_energy or !second_token.is_energy or first_token.biome_type != second_token.biome_type:
		print("Invalid swap: Both must be energy tokens in the same biome")
		return

	# Get the placements
	var first_placement = token_manager.get_token_placement_at_position(first_token_position)
	var second_placement = token_manager.get_token_placement_at_position(second_token_position)

	if !first_placement or !second_placement:
		print("One or both placements not found")
		return

	# Store token data to swap
	var first_token_owner = first_token.owner_id
	var second_token_owner = second_token.owner_id
	var first_token_blighted = first_token.is_blighted
	var second_token_blighted = second_token.is_blighted
	var first_token_color_index = first_token.player_color_index
	var second_token_color_index = second_token.player_color_index

	# Update tokens with swapped data
	first_token.owner_id = second_token_owner
	second_token.owner_id = first_token_owner
	first_token.is_blighted = second_token_blighted
	second_token.is_blighted = first_token_blighted
	first_token.player_color_index = second_token_color_index
	second_token.player_color_index = first_token_color_index

	# Sync to all clients
	rpc("sync_energy_token_swap", first_token_position, second_token_position,
		first_token_owner, second_token_owner,
		first_token_blighted, second_token_blighted, first_token_color_index, second_token_color_index)

	# Always unhighlight after swap
	token_manager.unhighlight_all_token_placements()

@rpc("any_peer", "call_local")
func sync_energy_token_swap(first_token_position: Vector3, second_token_position: Vector3,
						   first_token_owner: int, second_token_owner: int,
						   first_token_blighted: bool, second_token_blighted: bool, first_token_color_index: int, second_token_color_index: int):
	print("Syncing token swap between: " + str(first_token_position) + " and " + str(second_token_position))

	# Find both tokens
	var first_token = token_manager.find_token_at_position(first_token_position)
	var second_token = token_manager.find_token_at_position(second_token_position)

	if !first_token or !second_token:
		print("One or both tokens not found for swap sync")
		return

	# Swap owner IDs
	first_token.owner_id = second_token_owner
	second_token.owner_id = first_token_owner

	# Swap blight states
	first_token.is_blighted = second_token_blighted
	second_token.is_blighted = first_token_blighted

	# Swap Player Color Index
	first_token.player_color_index = second_token_color_index
	second_token.player_color_index = first_token_color_index

	# Update visual appearance with correct player materials
	token_manager.apply_player_material(first_token, second_token_owner)
	token_manager.apply_player_material(second_token, first_token_owner)

	# Reset swap mode
	is_swap_energy_mode = false
	if first_swap_token:
		first_swap_token.highlight(false)
		first_swap_token = null

	if first_token.is_blighted:
		first_token.rotation_degrees.z = 180
	else:
		first_token.rotation_degrees.z = 0

	if second_token.is_blighted:
		second_token.rotation_degrees.z = 180
	else:
		second_token.rotation_degrees.z = 0

	# Always unhighlight token placements after any token action
	token_manager.unhighlight_all_token_placements()


## Refresh Energy
@rpc("any_peer")
func request_refresh_energy(token_position: Vector3):
	if !multiplayer.is_server():
		return

	var player_id = multiplayer.get_remote_sender_id()
	if player_id == 0:  # Local server call
		player_id = multiplayer.get_unique_id()

	# Validate it's the player's turn
	if !game_state_manager.is_valid_player_turn(player_id):
		return

	# Process the token refresh
	refresh_energy(token_position)
	print("Server processed token refresh at: " + str(token_position))

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
		token_manager.rpc("sync_token_blight", token.global_position, token.is_blighted)

		# Always unhighlight token placements after any token action
		token_manager.unhighlight_all_token_placements()

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
		var placement = token_manager.get_token_placement_at_position(token.global_position)

		# Mark the placement as available again
		if placement:
			placement.set_occupied(false)
			placement.current_token = null

		# Add a token back to the player's pool
		if player_id != -1:
			token_manager.add_token_to_player(player_id, biome_type)

		# Remove the token
		token.queue_free()

		# IMPORTANT: Sync to all clients using RPC on this node, not the parent
		rpc("sync_token_removal_at_position", token_position, player_id, biome_type)

		# Update tokens UI for all players
		var players = get_parent().players
		for pid in players:
			var updated_tokens = token_manager.get_player_tokens(pid)
			if pid == multiplayer.get_unique_id():
				token_manager.sync_player_tokens(updated_tokens, pid)  # Direct call for server
			else:
				token_manager.rpc_id(pid, "sync_player_tokens", updated_tokens, pid)  # RPC for clients
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
		var placement = token_manager.get_token_placement_at_position(token.global_position)

		# Mark the placement as available again
		if placement:
			placement.set_occupied(false)
			placement.current_token = null

		# Remove the token
		token.queue_free()

		# Update UI if this is for the local player
		if player_id == multiplayer.get_unique_id():
			token_manager.update_token_ui()
	else:
		print("No token found at position for removal sync: " + str(token_position))

	# Always unhighlight token placements after any token action
	token_manager.unhighlight_all_token_placements()

	# Reset remove and blight modes
	is_take_off_mode = false
	is_unblight_mode = false


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

	# MODIFICATION START: This now handles both blighting and unblighting
	var token = token_manager.find_token_at_position(token_position)
	if not is_instance_valid(token):
		print("Server could not find token to unblight/blight.")
		return

	# If the token is already blighted, it's an un-blight action (flip in place).
	if token.is_blighted:
		# The original 'unblight' logic is now just flipping it back.
		unblight_token(token_position)
	else:
		# If it's NOT blighted, it's a blight action that requires MOVING.
		# This is a new path that was not in the original code.
		# We delegate this complex logic to the token manager.
		token_manager.blight_token_and_move(token)

	print("Server processed token unblight/blight at: " + str(token_position))
	# MODIFICATION END

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
		token_manager.rpc("sync_token_blight", token.global_position, token.is_blighted)

		# Always unhighlight token placements after any token action
		token_manager.unhighlight_all_token_placements()

	else:
		print("No token found")

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# End of Card Effect Logic
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Helper Functions
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
func reset_all_effect_modes():
	is_take_off_mode = false
	is_unblight_mode = false
	is_refresh_energy_mode = false
	is_swap_energy_mode = false
	is_plant_extra = false # If this should also be reset
	if first_swap_token:
		first_swap_token.highlight(false)
		first_swap_token = null

	# This part still needs to be in token_manager
	# token_manager.unhighlight_outerglow()
	# token_manager.unhighlight_all_token_placements()

# -------------------------------------------------------------------------
# START: Elemental Face Down Swap Logic
# -------------------------------------------------------------------------
func perform_face_down_swap(board_card: FaceCard3D):
	if not hand_card_for_swap or not board_card:
		print("ERROR: Swap cannot be performed. Missing card references.")
		return

	# Get the necessary data to identify the cards across the network
	var hand_card_original_index = hand_card_for_swap.get_meta("original_card_index", -1)
	var board_card_path = board_card.get_path()
	var player_id = multiplayer.get_unique_id()

	if hand_card_original_index == -1:
		print("ERROR: Card from hand is missing original_card_index metadata.")
		return

	# Client sends request to server, server executes directly
	if multiplayer.is_server():
		sync_face_down_swap(player_id, hand_card_original_index, board_card_path)
	else:
		rpc_id(1, "request_face_down_swap", player_id, hand_card_original_index, board_card_path)

@rpc("any_peer")
func request_face_down_swap(player_id: int, hand_card_idx: int, board_card_path: NodePath):
	if not multiplayer.is_server(): return
	# Server validates the request (omitted for brevity, but you'd check if it's the player's turn, etc.)
	# Then broadcasts the confirmed action to all clients
	rpc("sync_face_down_swap", player_id, hand_card_idx, board_card_path)

@rpc("any_peer", "call_local")
func sync_face_down_swap(player_id: int, hand_card_original_index: int, board_card_path: NodePath):
	# This function now runs on ALL peers (including the server)
	
	# 1. Find the card on the board to be replaced
	var board_card = get_node_or_null(board_card_path)
	if not board_card or not board_card is FaceCard3D:
		print("Swap sync failed: could not find board card at path: ", board_card_path)
		return

	var slice_collection = board_card.get_parent()
	if not slice_collection or not slice_collection is CardCollection3D:
		print("Swap sync failed: could not get slice collection from board card.")
		return

	# 2. Remove the old card from the board
	var board_card_index = slice_collection.cards.find(board_card)
	if board_card_index != -1:
		var card_to_remove = slice_collection.remove_card(board_card_index)
		card_to_remove.queue_free()
	
	# 3. The player who made the move removes the card from their hand
	if player_id == multiplayer.get_unique_id():
		var hand_collection = get_node("/root/Game/Deck/Table/DragController/Hand")
		var card_in_hand_to_remove = null
		for card in hand_collection.cards:
			if card.get_meta("original_card_index", -2) == hand_card_original_index:
				card_in_hand_to_remove = card
				break
		if card_in_hand_to_remove:
			var hand_card_idx = hand_collection.cards.find(card_in_hand_to_remove)
			hand_collection.remove_card(hand_card_idx)
		else:
			print("Swap sync warning: could not find card with index ", hand_card_original_index, " in local player's hand.")

	# 4. Instantiate the new card and place it on the board
	var table = get_node("/root/Game/Deck/Table")
	var new_card_instance = table.instantiate_face_card(hand_card_original_index, true) # true for elemental
	if new_card_instance:
		new_card_instance.owner_id = player_id
		new_card_instance.face_down = true # Ensure it's placed face down
		slice_collection.append_card(new_card_instance)
	else:
		print("Swap sync failed: could not instantiate new card with index ", hand_card_original_index)

	# 5. Reset the state
	var game = get_node("/root/Game")
	if game.soil_star_actions.is_swapping_elemental:
		game.soil_star_actions.is_swapping_elemental = false
		hand_card_for_swap = null
		game.notification.hide_panel()
# -------------------------------------------------------------------------
# END: Elemental Face Down Swap Logic
# -------------------------------------------------------------------------

# -------------------------------------------------------------------------
# START: Elemental Face Up Swap Logic
# -------------------------------------------------------------------------
func perform_face_up_swap(board_card: FaceCard3D):
	if not hand_card_for_swap or not board_card:
		print("ERROR: Swap cannot be performed. Missing card references.")
		return

	var hand_card_original_index = hand_card_for_swap.get_meta("original_card_index", -1)
	var board_card_path = board_card.get_path()
	var player_id = multiplayer.get_unique_id()

	if hand_card_original_index == -1:
		print("ERROR: Card from hand is missing original_card_index metadata.")
		return

	if multiplayer.is_server():
		sync_face_up_swap(player_id, hand_card_original_index, board_card_path)
	else:
		rpc_id(1, "request_face_up_swap", player_id, hand_card_original_index, board_card_path)

@rpc("any_peer")
func request_face_up_swap(player_id: int, hand_card_idx: int, board_card_path: NodePath):
	if not multiplayer.is_server(): return
	rpc("sync_face_up_swap", player_id, hand_card_idx, board_card_path)

@rpc("any_peer", "call_local")
func sync_face_up_swap(player_id: int, hand_card_original_index: int, board_card_path: NodePath):
	var board_card = get_node_or_null(board_card_path)
	if not board_card or not board_card is FaceCard3D:
		print("Swap sync failed: could not find board card at path: ", board_card_path)
		return
		
	var slice_collection = board_card.get_parent()
	if not slice_collection or not slice_collection is CardCollection3D:
		print("Swap sync failed: could not get slice collection from board card.")
		return

	var board_card_index = slice_collection.cards.find(board_card)
	if board_card_index != -1:
		var card_to_remove = slice_collection.remove_card(board_card_index)
		card_to_remove.queue_free()
	
	if player_id == multiplayer.get_unique_id():
		var hand_collection = get_node("/root/Game/Deck/Table/DragController/Hand")
		var card_in_hand_to_remove = null
		for card in hand_collection.cards:
			if card.get_meta("original_card_index", -2) == hand_card_original_index:
				card_in_hand_to_remove = card
				break
		if card_in_hand_to_remove:
			var hand_card_idx = hand_collection.cards.find(card_in_hand_to_remove)
			hand_collection.remove_card(hand_card_idx)
		else:
			print("Swap sync warning: could not find card with index ", hand_card_original_index, " in local player's hand.")

	var table = get_node("/root/Game/Deck/Table")
	var new_card_instance = table.instantiate_face_card(hand_card_original_index, true)
	if new_card_instance:
		new_card_instance.owner_id = player_id
		new_card_instance.face_down = false # Ensure it's placed face UP
		slice_collection.append_card(new_card_instance)
	else:
		print("Swap sync failed: could not instantiate new card with index ", hand_card_original_index)

	var game = get_node("/root/Game")
	if game.soil_star_actions.is_swapping_elemental_face_up:
		game.soil_star_actions.is_swapping_elemental_face_up = false
		hand_card_for_swap = null
		game.notification.hide_panel()
# -------------------------------------------------------------------------
# END: Elemental Face Up Swap Logic
# -------------------------------------------------------------------------
