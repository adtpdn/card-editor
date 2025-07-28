extends Node3D

@export var actions_cards = preload("res://assets/materials/cards_materials/actions/cards/action_cards.tres")
@export var elementals_cards = preload("res://assets/materials/cards_materials/elementals/elements_card/elementals_cards.tres")

# Deck State Arrays - these will be synced from the server
@export var available_cards = []
@export var elementals_ids_arr = []

# This holds the pre-instantiated elemental card nodes for initial placement (server-side only)
var elemental_deck_nodes := []

var rng = RandomNumberGenerator.new()

@onready var game = get_node("/root/Game/")
@onready var hand: CardCollection3D = $DragController/Hand
@onready var card_manager

func _ready():
	await game.ready # Ensure game node and its children are ready

	card_manager = get_node("/root/Game/CardManager")
	
	# Connect deck click signals
	var action_deck = get_node_or_null("../CardDeck")
	if action_deck:
		action_deck.connect("card_3d_mouse_up", _on_action_deck_pressed)
	
	var elemental_deck = get_node_or_null("../ElementalDeck")
	if elemental_deck:
		elemental_deck.connect("card_3d_mouse_up", _on_elemental_deck_pressed)

	# All instances populate their decks with a default, unshuffled order.
	reset_decks()

# --- Deck Setup and Shuffling (Server-Side) ---

# This is the new main function to be called by the NetworkManager ONLY ON THE HOST
# after the server has been created.
func setup_decks_for_new_game():
	if not multiplayer.is_server(): return

	shuffle_decks()
	_create_elemental_deck_nodes()
	rpc("client_receive_shuffled_decks", available_cards, elementals_ids_arr)
	plant_initial_elemental_cards()
	sync_initial_board_state()

# Populates the deck arrays with sequential IDs.
func reset_decks():
	available_cards.clear()
	elementals_ids_arr.clear()
	for i in range(actions_cards.cards.size()):
		available_cards.append(i)
	for i in range(elementals_cards.cards.size()):
		elementals_ids_arr.append(i)

# Shuffles the decks. ONLY the server should run this.
func shuffle_decks():
	if not multiplayer.is_server(): return
	rng.randomize()
	available_cards.shuffle()
	elementals_ids_arr.shuffle()
	print("Server has shuffled the decks. Elementals order: ", elementals_ids_arr)

# Initializes both decks with a seed, shuffles them, and syncs with clients.
# THIS FUNCTION ONLY RUNS ON THE SERVER.
func initialize_deck_with_seed(seed_value: int):
	# Populate and shuffle both decks
	reset_and_shuffle_decks()
	
	# Sync the shuffled decks with all clients
	rpc("client_receive_decks", available_cards, elementals_ids_arr)

# Populates the deck arrays and shuffles them.
# THIS FUNCTION ONLY RUNS ON THE SERVER.
func reset_and_shuffle_decks():
	available_cards.clear()
	elementals_ids_arr.clear()
	
	for i in range(actions_cards.cards.size()):
		available_cards.append(i)
	
	for i in range(elementals_cards.cards.size()):
		elementals_ids_arr.append(i)
		
	available_cards.shuffle()
	elementals_ids_arr.shuffle()

# --- Initial Board Setup (Server-Side) ---

# Creates a pool of card nodes from the shuffled elemental deck.
func _create_elemental_deck_nodes():
	elemental_deck_nodes.clear()
	
	var count = min(elementals_ids_arr.size(), 18)
	for i in range(count):
		var card_index_from_deck = elementals_ids_arr[i]
		var card_instance = instantiate_face_card(card_index_from_deck, true)
		elemental_deck_nodes.append(card_instance)
		
	print("Player %d created an elemental node pool with %d cards." % [multiplayer.get_unique_id(), elemental_deck_nodes.size()])

# Deals the initial 8 cards to the board slices. (Server only)
func plant_initial_elemental_cards():
	if not multiplayer.is_server(): return
	
	var drag_controller = $DragController
	if elemental_deck_nodes.is_empty():
		print("Error: The elemental_deck_nodes pool is empty.")
		return
		
	for i in range(1, 9): # Loop from 1 to 8
		var slice_name = "elemental_slice_" + str(i)
		var elemental_slice = drag_controller.get_node_or_null(slice_name)
		if elemental_slice and not elemental_deck_nodes.is_empty():
			var card_to_deal = elemental_deck_nodes.pop_front()
			elemental_slice.append_card(card_to_deal)
		else:
			print("Warning: Could not find slice or ran out of cards for initial placement.")
			break

# Gathers data about the initial board state and sends it to clients. (Server only)
func sync_initial_board_state(peer_id: int = 0):
	if not multiplayer.is_server(): return
	
	# Wait a single frame to ensure the board state is settled from any recent additions.
	# This prevents a race condition where a client connects before the server has finished placing cards.
	await get_tree().process_frame
	
	var elemental_slice_cards_data = []
	var drag_controller = $DragController
	for i in range(1, 9):
		var slice_name = "elemental_slice_" + str(i)
		var elemental_slice = drag_controller.get_node_or_null(slice_name)
		if elemental_slice and elemental_slice.cards.size() > 0:
			var card = elemental_slice.cards[0]
			var original_index = card.get_meta("original_card_index", -1)
			if original_index != -1:
				elemental_slice_cards_data.append({
					"card_index": original_index,
					"slice_index": i
				})
	
	if not elemental_slice_cards_data.is_empty():
		if peer_id > 0:
			# If a specific peer is targeted, send only to them.
			rpc_id(peer_id, "client_receive_initial_slices", elemental_slice_cards_data)
			print("Sent initial board state to new peer: %d" % peer_id)
		else:
			# Otherwise, broadcast to all connected peers.
			rpc("client_receive_initial_slices", elemental_slice_cards_data)
			print("Broadcasted initial board state to all peers.")
	else:
		print("WARNING: sync_initial_board_state was called, but no cards were found on the board slices.")

# This function handles the local player's action of adding a card to their hand.
func add_card(card_data: Dictionary, is_elemental: bool):
	var card = instantiate_face_card(card_data["id"], is_elemental)
	if card:
		hand.append_card(card)
		var deck_node_path = "../ElementalDeck" if is_elemental else "../CardDeck"
		card.global_position = get_node(deck_node_path).global_position
		
		if not is_elemental:
			var turn_phase_manager = game.turn_phase_manager
			if turn_phase_manager and turn_phase_manager.current_phase == turn_phase_manager.Phase.PLANT_SIGIL_AND_CARD and not turn_phase_manager.sigil_placed:
				turn_phase_manager.sigil_placed = true
				turn_phase_manager.check_phase_two_completion()

# --- Client-Side RPCs for Setup ---
@rpc("any_peer", "call_local")
func client_receive_shuffled_decks(shuffled_actions: Array, shuffled_elementals: Array):
	if multiplayer.is_server(): return
	
	available_cards = shuffled_actions
	elementals_ids_arr = shuffled_elementals
	print("Client received shuffled decks. Elementals order: ", elementals_ids_arr)
	
	# Now that the client has the shuffled list, it builds its own identical node pool.
	_create_elemental_deck_nodes()

@rpc("any_peer", "call_local")
func client_receive_initial_slices(slice_data: Array):
	if multiplayer.is_server(): return
	print("client receive initial slices")

	var drag_controller = $DragController
	if not drag_controller: return

	# To stay in sync, clients must remove the 8 dealt cards from their node pool,
	# just like the server did using pop_front().
	for i in range(slice_data.size()):
		if not elemental_deck_nodes.is_empty():
			elemental_deck_nodes.pop_front()
	
	print("Client removed dealt cards. Remaining nodes: %d" % elemental_deck_nodes.size())

	print("Client syncing initial elemental slices.")
	for data in slice_data:
		var card_instance = instantiate_face_card(data["card_index"], true)
		var slice_name = "elemental_slice_" + str(data["slice_index"])
		var elemental_slice = drag_controller.get_node_or_null(slice_name)
		if elemental_slice and card_instance:
			for c in elemental_slice.remove_all(): c.queue_free()
			elemental_slice.append_card(card_instance)

@rpc("any_peer", "call_local")
func client_receive_decks(shuffled_actions: Array, shuffled_elementals: Array):
	if multiplayer.is_server(): return # Server already has the decks
	available_cards = shuffled_actions
	elementals_ids_arr = shuffled_elementals
	print("Client received shuffled decks. Actions: %d, Elementals: %d" % [available_cards.size(), elementals_ids_arr.size()])

# --- Card Instantiation ---
func instantiate_face_card(card_index: int, is_elemental: bool = false) -> FaceCard3D:
	var scene = load("res://scenes/cards_and_deck/face_card_3d.tscn")
	var face_card_3d: FaceCard3D = scene.instantiate()
	
	var card_resource: CardResource
	if is_elemental:
		if card_index < 0 or card_index >= elementals_cards.cards.size():
			print("Error: Invalid elemental card index: ", card_index)
			face_card_3d.queue_free(); return null
		card_resource = elementals_cards.cards[card_index]
	else:
		if card_index < 0 or card_index >= actions_cards.cards.size():
			print("Error: Invalid action card index: ", card_index)
			face_card_3d.queue_free(); return null
		card_resource = actions_cards.cards[card_index]
		
	face_card_3d.card_id = card_resource.card_id
	face_card_3d.card_name = card_resource.card_name
	face_card_3d.card_type = card_resource.card_type
	face_card_3d.set_meta("original_card_index", card_index)
	face_card_3d.front_material_path = card_resource.front_mesh_material.resource_path
	face_card_3d.back_material_path = card_resource.back_mesh_material.resource_path
	
	return face_card_3d

# --- Card Drawing Logic (Server-Authoritative) ---
func _on_action_deck_pressed():
	var turn_phase_manager = game.turn_phase_manager
	if turn_phase_manager.sigil_placed:
		print("Cannot draw a card if sigil already placed")
		return
	rpc_id(1, "server_draw_card", multiplayer.get_unique_id(), false)

func _on_elemental_deck_pressed():
	if multiplayer.is_server():
		pass
	else:
		rpc_id(1, "server_draw_card", multiplayer.get_unique_id(), true)

@rpc("authority")
func server_draw_card(player_id: int, is_elemental: bool):
	if game.card_manager.is_hand_full():
		print("Player %d hand is full." % player_id)
		return

	var deck_array = elementals_ids_arr if is_elemental else available_cards
	if deck_array.is_empty():
		print("Deck is empty!")
		return

	var card_original_index = deck_array.pop_front()
	var card_resource = elementals_cards.cards[card_original_index] if is_elemental else actions_cards.cards[card_original_index]
	
	var data = { "id": card_original_index, "card_id": card_resource.card_id }
	
	rpc("client_receive_card", player_id, data, is_elemental)

@rpc("any_peer", "call_local")
func client_receive_card(player_id: int, card_data: Dictionary, is_elemental: bool):
	# All clients must remove the drawn card from their local deck array to stay in sync.
	if is_elemental:
		elementals_ids_arr.erase(card_data["id"])
	else:
		available_cards.erase(card_data["id"])

	# Only the player who requested the card actually adds it to their hand.
	if player_id == multiplayer.get_unique_id():
		add_card_to_hand(card_data, is_elemental)

# This function now only handles adding the card to the hand visually.
func add_card_to_hand(card_data: Dictionary, is_elemental: bool):
	var card = instantiate_face_card(card_data["id"], is_elemental)
	if card:
		hand.append_card(card)
		var deck_node_path = "../ElementalDeck" if is_elemental else "../CardDeck"
		card.global_position = get_node(deck_node_path).global_position
		
		if not is_elemental:
			var turn_phase_manager = game.turn_phase_manager
			if turn_phase_manager.current_phase == turn_phase_manager.Phase.PLANT_SIGIL_AND_CARD and not turn_phase_manager.sigil_placed:
				turn_phase_manager.sigil_placed = true
				turn_phase_manager.check_phase_two_completion()
