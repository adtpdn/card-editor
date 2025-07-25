extends Node3D

var card_database = CardResource.new()
@export var actions_cards = preload("res://assets/materials/cards_materials/actions/cards/action_cards.tres")
@export var elementals_cards = preload("res://assets/materials/cards_materials/elementals/elements_card/elementals_cards.tres")

# Deck of CardType
@export var available_cards = [] # action card
@export var elemental_cards = [] # elemental card

# --- MODIFICATION START ---
# This new array will hold the 18 pre-instantiated elemental card nodes.
var elemental_deck_nodes: Array[FaceCard3D] = []
# --- MODIFICATION END ---

var card_index
@export var deck_seed: int = 0
var rng = RandomNumberGenerator.new()

@onready var game = get_node("/root/Game/")
@onready var hand: CardCollection3D = $DragController/Hand
@onready var card_manager 

func _ready():
	card_manager = get_node("/root/Game/CardManager")
	
	var action_deck = get_node_or_null("../CardDeck")
	if action_deck:
		if not action_deck.is_connected("card_3d_mouse_up", _on_action_deck_pressed):
			action_deck.connect("card_3d_mouse_up", _on_action_deck_pressed)
	else:
		print("ERROR: Action Deck node not found at path ../CardDeck")

	var elemental_deck = get_node_or_null("../ElementalDeck")
	if elemental_deck:
		if elemental_deck.is_connected("card_3d_mouse_up", _on_action_deck_pressed):
			elemental_deck.disconnect("card_3d_mouse_up", _on_action_deck_pressed)
			print("INFO: Disconnected incorrect editor signal from ElementalDeck.")
		
		if not elemental_deck.is_connected("card_3d_mouse_up", _on_elemental_deck_pressed):
			elemental_deck.connect("card_3d_mouse_up", _on_elemental_deck_pressed)
	else:
		print("ERROR: Elemental Deck node not found at path ../ElementalDeck")
	
	reset_available_cards()

	if game.network_manager and game.network_manager.multiplayer.is_server():
		deck_seed = randi()
		
		# --- MODIFICATION START ---
		# The logic to create and deal elemental cards is now called here.
		initialize_deck_with_seed(deck_seed)
		# The server is responsible for the initial dealing.
		plant_initial_elemental_cards() 
		# --- MODIFICATION END ---

		game.network_manager.sync_deck_seed(deck_seed)
		sync_initial_state()

func initialize_deck_with_seed(seed_value: int):
	deck_seed = seed_value
	rng.seed = deck_seed
	reset_available_cards()
	shuffle_deck()
	
	# --- MODIFICATION START ---
	# Create the pool of elemental card nodes after the deck indices are shuffled.
	_create_elemental_deck_nodes()
	# --- MODIFICATION END ---

	print("Deck initialized with seed:", deck_seed)

# --- MODIFICATION START ---
# This new function creates a pool of 18 elemental card nodes.
func _create_elemental_deck_nodes():
	elemental_deck_nodes.clear()
	
	# Ensure the elemental_cards array (which holds indices) is populated.
	if elemental_cards.is_empty():
		reset_available_cards()
		shuffle_deck()
		
	print("Creating a pool of 18 elemental card nodes.")
	# Create nodes for up to 18 available elemental cards.
	var count = min(elemental_cards.size(), 18)
	for i in range(count):
		var card_index_from_deck = elemental_cards[i]
		var card_instance = instantiate_face_card(card_index_from_deck, true) # 'true' for is_elemental
		elemental_deck_nodes.append(card_instance)
		
	print("Elemental node pool created with %d cards." % elemental_deck_nodes.size())

# This function is now modified to deal cards to the elemental_slice nodes
# from the pre-instantiated pool.
func plant_initial_elemental_cards():
	var drag_controller = $DragController
	if not drag_controller:
		print("Error: DragController not found in Table scene!")
		return

	if elemental_deck_nodes.is_empty():
		print("Error: The elemental_deck_nodes pool is empty. Cannot deal cards.")
		return
		
	print("Dealing 8 elemental cards to elemental slices.")
	# Deal 8 cards to the elemental slices
	for i in range(1, 9): # Loop from 1 to 8
		var slice_name = "elemental_slice_" + str(i)
		var elemental_slice = drag_controller.get_node_or_null(slice_name)

		if elemental_slice and elemental_slice is CardCollection3D:
			if not elemental_deck_nodes.is_empty():
				var card_to_deal = elemental_deck_nodes.pop_front()
				elemental_slice.append_card(card_to_deal)
				print("Dealt card '", card_to_deal.card_name, "' to ", slice_name)
			else:
				print("Warning: Ran out of elemental cards in the pool to deal.")
				break
		else:
			print("Error: Could not find a valid CardCollection3D node named '", slice_name, "' under DragController.")
# --- MODIFICATION END ---

func sync_initial_state():
	if game.network_manager and game.network_manager.multiplayer and game.network_manager.multiplayer.get_peers().size() > 0:
		# --- MODIFICATION START ---
		# This section needs to be updated to sync the state of the elemental slices to clients.
		# You would gather the card data from each slice and send it via an RPC.
		# For now, I'm leaving the old logic commented out.
		# A new RPC call would be needed in your network_manager.gd.
		
		# Example of how you might gather the data:
		var elemental_slice_cards_data = []
		var drag_controller = $DragController
		for i in range(1, 9):
			var slice_name = "elemental_slice_" + str(i)
			var elemental_slice = drag_controller.get_node_or_null(slice_name)
			if elemental_slice and elemental_slice.cards.size() > 0:
				var card = elemental_slice.cards[0]
				# To sync, you need to send data that allows the client to recreate the card.
				# Sending the original index from the DeckResource is a good way.
				var original_index = -1
				for j in range(elementals_cards.cards.size()):
					if elementals_cards.cards[j].card_id == card.card_id:
						original_index = j
						break
				
				if original_index != -1:
					elemental_slice_cards_data.append({
						"card_index": original_index,
						"slice_index": i
					})

		# You would then call a new RPC, e.g.:
		# game.network_manager.rpc("sync_initial_elemental_slices", elemental_slice_cards_data)
		
		# The old logic for syncing TokenPlacements:
		# var planted_cards_data = []
		# var planting_locations = game.get_node("TokenPlacements").get_children()
		# for i in range(min(8, planting_locations.size())):
		# 	var location = planting_locations[i]
		# 	if location.planted_cards[location.slots[0].name].size() > 0:
		# 		var card = location.planted_cards[location.slots[0].name][0]
		# 		planted_cards_data.append({
		# 			"card_data": card.card_resource.to_dictionary(),
		# 			"location_name": location.location_name,
		# 			"slot_index": 0
		# 		})
		# game.network_manager.rpc("sync_initial_planted_cards", planted_cards_data, available_cards, elemental_cards, deck_seed)
		# --- MODIFICATION END ---
		pass # Placeholder for your new sync logic

# --- MODIFICATION START ---
# This is an example of the function you would need on the client side to handle the sync.
# You would call this via an RPC from your network_manager.
@rpc("any_peer", "call_local")
func sync_initial_elemental_slices(slice_data: Array):
	if multiplayer.is_server(): return # This logic is for clients only

	await ready # Ensure the node is ready before manipulating children

	var drag_controller = $DragController
	if not drag_controller: return

	print("Client syncing initial elemental slices.")
	for data in slice_data:
		var card_index = data["card_index"]
		var slice_index = data["slice_index"]

		var card_instance = instantiate_face_card(card_index, true)
		var slice_name = "elemental_slice_" + str(slice_index)
		var elemental_slice = drag_controller.get_node_or_null(slice_name)

		if elemental_slice and card_instance:
			# Ensure the slice is empty before adding the new card
			for c in elemental_slice.remove_all(): c.queue_free()
			elemental_slice.append_card(card_instance)
# --- MODIFICATION END ---


func shuffle_deck():
	if rng.seed == 0:
		rng.randomize()
		
	available_cards.shuffle()
	elemental_cards.shuffle()


func reset_available_cards():
	available_cards = []
	elemental_cards = []
	for i in range(actions_cards.cards.size()):
		available_cards.append(i)
		
	for i in range(elementals_cards.cards.size()):
		elemental_cards.append(i)

	if deck_seed != 0:
		shuffle_deck()

func instantiate_face_card(card_index: int, is_elemental: bool = false) -> FaceCard3D:
	var scene = load("res://scenes/cards_and_deck/face_card_3d.tscn")
	var face_card_3d: FaceCard3D = scene.instantiate()
	
	var card_resource: CardResource
	if is_elemental:
		if card_index < 0 or card_index >= elementals_cards.cards.size():
			print("Error: Invalid elemental card index: ", card_index)
			face_card_3d.queue_free()
			return null
		card_resource = elementals_cards.cards[card_index]
	else:
		if card_index < 0 or card_index >= actions_cards.cards.size():
			print("Error: Invalid action card index: ", card_index)
			face_card_3d.queue_free()
			return null
		card_resource = actions_cards.cards[card_index]
		
	var resource_card_id = card_resource.card_id
	face_card_3d.card_id = resource_card_id
	face_card_3d.card_name = card_resource.card_name
	var card_type = card_resource.card_type
	face_card_3d.card_type = card_type
	face_card_3d.set_meta("original_card_index", card_index)
	face_card_3d.front_material_path = card_resource.front_mesh_material.resource_path
	face_card_3d.back_material_path = card_resource.back_mesh_material.resource_path
	
	return face_card_3d

func add_card():
	var token_manager = game.token_manager
	if game.card_manager.is_hand_full():
		print("Hand is full! Maximum cards:", game.card_manager.max_hand_size)
		return false
	if available_cards.size() == 0:
		print("Deck is empty! Reshuffling...")
		reset_available_cards()
	var data = next_card()
	if data:
		var card = instantiate_face_card(data["id"], false)
		card_index = data["id"]
		if card.card_id != data["card_id"]:
			print("Warning: Card ID mismatch. Expected:", data["card_id"], "Got:", card.card_id)
			card.card_id = data["card_id"]
		hand.append_card(card)
		card.global_position = $"../CardDeck".global_position
		var turn_phase_manager = game.turn_phase_manager
		if turn_phase_manager:
			var current_phase = turn_phase_manager.current_phase
			
			if card_manager.is_plant_extra:
				pass
			elif current_phase == turn_phase_manager.Phase.PLANT_BIOME:
				turn_phase_manager.completed_phases[turn_phase_manager.Phase.PLANT_BIOME] = true
				turn_phase_manager.advance_to_next_phase()
			elif current_phase == turn_phase_manager.Phase.PLANT_SIGIL_AND_CARD and !turn_phase_manager.sigil_placed:
				turn_phase_manager.sigil_placed = true
				if card_manager.is_plant_extra:
					game.token_button.disabled = false
				else:
					game.token_button.disabled = true
				turn_phase_manager.check_phase_two_completion()
		if game.network_manager and game.network_manager.multiplayer and game.network_manager.multiplayer.get_peers().size() > 0:
			game.network_manager.sync_card_drawn(data["card_id"])
		return true
	return false

func add_elemental_card():
	if elemental_cards.size() == 0:
		print("Elemental deck is empty! Reshuffling...")
		reset_available_cards()
	var data = next_elemental_card()
	if data:
		var card = instantiate_face_card(data["id"], true)
		card_index = data["id"]
		if card.card_id != data["card_id"]:
			print("Warning: Card ID mismatch. Expected:", data["card_id"], "Got:", card.card_id)
			card.card_id = data["card_id"]
		hand.append_card(card)
		card.global_position = $"../ElementalDeck".global_position
		if game.network_manager and game.network_manager.multiplayer and game.network_manager.multiplayer.get_peers().size() > 0:
			game.network_manager.sync_card_drawn(data["card_id"])
		return true
	return false

func next_elemental_card():
	if elemental_cards.is_empty():
		return null
	var random_index_position = rng.randi() % elemental_cards.size() if deck_seed != 0 else randi() % elemental_cards.size()
	var card_index = elemental_cards[random_index_position]
	var resource_card_id = elementals_cards.cards[card_index].card_id
	elemental_cards.remove_at(random_index_position)
	return {
		"id": card_index,
		"card_id": resource_card_id
	}

func next_card():
	if available_cards.is_empty():
		return null
	var random_index_position = rng.randi() % available_cards.size() if deck_seed != 0 else randi() % available_cards.size()
	var card_index = available_cards[random_index_position]
	var resource_card_id = actions_cards.cards[card_index].card_id
	available_cards.remove_at(random_index_position)
	return {
		"id": card_index,
		"card_id": resource_card_id
	}

func remove_card():
	if hand.cards.size() == 0:
		return
	var random_card_index = randi() % hand.cards.size()
	var card_to_remove = hand.cards[random_card_index]
	play_card(card_to_remove)

func play_card(card):
	var card_index = hand.card_indicies[card]
	var card_global_position = hand.cards[card_index].global_position
	var c = hand.remove_card(card_index)
	c.remove_hovered()
	c.global_position = card_global_position

func clear_cards():
	var hand_cards = hand.remove_all()
	for c in hand_cards:
		c.queue_free()

func purchase_elemental_card():
	if elemental_cards.size() == 0:
		print("No Elemental cards available!")
		return false
	var soil_star_node = game.get_node("SoilStar")
	if not soil_star_node:
		print("SoilStar node not found!")
		return false
	var random_index_position = rng.randi() % elemental_cards.size() if deck_seed != 0 else randi() % elemental_cards.size()
	var card_index = elemental_cards[random_index_position]
	var card_resource = actions_cards.cards[card_index]
	if soil_star_node.current_soil_star < card_resource.elemental_cost:
		print("Not enough soil stars! Required:", card_resource.elemental_cost, "Available:", soil_star_node.current_soil_star)
		return false
	soil_star_node.decrease_soil_star(card_resource.elemental_cost)
	var card = instantiate_face_card(card_index)
	hand.append_card(card)
	card.global_position = $"../Deck".global_position
	elemental_cards.remove_at(random_index_position)
	print("Purchased Elemental card:", card.card_name, "with cost:", card_resource.elemental_cost)
	if game.network_manager and game.network_manager.multiplayer and game.network_manager.multiplayer.get_peers().size() > 0:
		game.network_manager.rpc("sync_elemental_purchase", card_resource.to_dictionary(), multiplayer.get_unique_id(), soil_star_node.current_soil_star)
	return true

func _on_action_deck_pressed():
	var turn_phase_manager = game.turn_phase_manager
	if turn_phase_manager.sigil_placed:
		print("Cannot draw a card if sigil already placed")
		return
	add_card()

func _on_elemental_deck_pressed():
	add_elemental_card()

func request_deck_sync():
	var network_manager = get_node("/root/Game/NetworkManager")
	if network_manager:
		network_manager.request_deck_sync()
