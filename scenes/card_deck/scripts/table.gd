extends Node3D

var card_database = CardResource.new()
@export var actions_cards = preload("res://scenes/card_deck/materials/cards/action_cards.tres")
# Deck of CardType
@export var available_cards = [] # action card
@export var elemental_cards = [] # elemental card

var card_index
@export var deck_seed: int = 0
var rng = RandomNumberGenerator.new()

@onready var game = get_node("/root/Game/")
@onready var hand: CardCollection3D = $DragController/Hand

func _ready():
	# Debug the action cards resource
	print("Debugging action cards resource:")
	for i in range(actions_cards.cards.size()):
		var card = actions_cards.cards[i]
		print("Card index:", i, "card_id:", card.card_id, "name:", card.card_name, "type:", card.card_type)

	# Initialize available cards
	reset_available_cards()

	# If we're the server, generate a seed and plant initial Elemental cards
	if game.network_manager and game.network_manager.multiplayer.is_server():
		deck_seed = randi()
		plant_initial_elemental_cards()
		game.network_manager.sync_deck_seed(deck_seed)
		# Sync initial planted cards and deck state
		sync_initial_state()

func initialize_deck_with_seed(seed_value: int):
	deck_seed = seed_value
	rng.seed = deck_seed
	reset_available_cards()
	shuffle_deck()
	print("Deck initialized with seed:", deck_seed)

# Elemental Cards
func plant_initial_elemental_cards():
	# Select 8 random Elemental cards
	var selected_indices = []
	var temp_elemental_cards = elemental_cards.duplicate()
	for i in range(min(8, temp_elemental_cards.size())):
		var rand_index = rng.randi() % temp_elemental_cards.size()
		selected_indices.append(temp_elemental_cards[rand_index])
		temp_elemental_cards.remove_at(rand_index)

	# Get planting locations
	var planting_locations = game.get_node("TokenPlacements").get_children()
	if planting_locations.size() < 8:
		print("Error: Not enough planting locations for 8 Elemental cards!")
		return

	# Plant the cards
	for i in range(min(8, selected_indices.size())):
		var card_resource = actions_cards.cards[selected_indices[i]]
		card_resource.revealed = false
		var planting_location = planting_locations[i]
		planting_location.plant_card(card_resource, 0) # Slot index 0 for simplicity
		print("Planted Elemental card:", card_resource.card_name, "at location:", planting_location.location_name)

func sync_initial_state():
	if game.network_manager and game.network_manager.multiplayer and game.network_manager.multiplayer.get_peers().size() > 0:
		var planted_cards_data = []
		var planting_locations = game.get_node("TokenPlacements").get_children()
		for i in range(min(8, planting_locations.size())):
			var location = planting_locations[i]
			if location.planted_cards[location.slots[0].name].size() > 0:
				var card = location.planted_cards[location.slots[0].name][0]
				planted_cards_data.append({
					"card_data": card.card_resource.to_dictionary(),
					"location_name": location.location_name,
					"slot_index": 0
				})
		game.network_manager.rpc("sync_initial_planted_cards", planted_cards_data, available_cards, elemental_cards, deck_seed)

func shuffle_deck():
	# Use Fisher-Yates shuffle algorithm with our seeded RNG
	for i in range(available_cards.size() - 1, 0, -1):
		var j = rng.randi_range(0, i)
		var temp = available_cards[i]
		available_cards[i] = available_cards[j]
		available_cards[j] = temp
	# Use Fisher-Yates shuffle algorithm
	for i in range(elemental_cards.size() - 1, 0, -1):
		var j = rng.randi_range(0, i)
		var temp = elemental_cards[i]
		elemental_cards[i] = elemental_cards[j]
		elemental_cards[j] = temp

func reset_available_cards():
	available_cards = []
	elemental_cards = []
	for i in range(actions_cards.cards.size()):
		var card = actions_cards.cards[i]
		if card.card_type == CardResource.CardType.ELEMENTAL:
			elemental_cards.append(i)
		else:
			available_cards.append(i)
	if deck_seed != 0:
		shuffle_deck()

func instantiate_face_card(card_index) -> FaceCard3D:
	var scene = load("res://scenes/card_deck/scenes/face_card_3d.tscn")
	var face_card_3d: FaceCard3D = scene.instantiate()
	var card_resource = actions_cards.cards[card_index]
	var resource_card_id = card_resource.card_id
	face_card_3d.card_id = resource_card_id
	face_card_3d.card_name = card_resource.card_name
	face_card_3d.card_type = card_resource.card_type
	face_card_3d.set_meta("original_card_index", card_index)
	face_card_3d.front_material_path = card_resource.front_mesh_material.resource_path
	face_card_3d.back_material_path = card_resource.back_mesh_material.resource_path
	print("Created card from index", card_index, "with RESOURCE card_id:", resource_card_id, 
		  "FINAL card_id:", face_card_3d.card_id, "type:", face_card_3d.card_type)
	return face_card_3d

func add_card():
	print('add card')
	var token_manager = game.token_manager
	if game.card_manager.is_hand_full():
		print("Hand is full! Maximum cards:", game.card_manager.max_hand_size)
		return false
	if available_cards.size() == 0:
		print("Deck is empty! Reshuffling...")
		reset_available_cards()
	var data = next_card()
	if data:
		var card = instantiate_face_card(data["id"])
		card_index = data["id"]
		if card.card_id != data["card_id"]:
			print("Warning: Card ID mismatch. Expected:", data["card_id"], "Got:", card.card_id)
			card.card_id = data["card_id"]
		hand.append_card(card)
		card.global_position = $"../Deck".global_position
		var turn_phase_manager = game.turn_phase_manager
		if turn_phase_manager:
			var current_phase = turn_phase_manager.current_phase
			if token_manager.is_plant_extra:
				pass
			elif current_phase == turn_phase_manager.Phase.PLANT_BIOME:
				turn_phase_manager.completed_phases[turn_phase_manager.Phase.PLANT_BIOME] = true
				turn_phase_manager.advance_to_next_phase()
			elif current_phase == turn_phase_manager.Phase.PLANT_SIGIL_AND_CARD and !turn_phase_manager.sigil_placed:
				turn_phase_manager.sigil_placed = true
				print("sigil placed true")
				if token_manager.is_plant_extra:
					game.token_button.disabled = false
				else:
					game.token_button.disabled = true
				turn_phase_manager.check_phase_two_completion()
		if game.network_manager and game.network_manager.multiplayer and game.network_manager.multiplayer.get_peers().size() > 0:
			game.network_manager.sync_card_drawn(data["card_id"])
		return true
	return false

func next_card():
	if available_cards.size() == 0:
		return null
	var random_index_position = rng.randi() % available_cards.size() if deck_seed != 0 else randi() % available_cards.size()
	var card_index = available_cards[random_index_position]
	var resource_card_id = actions_cards.cards[card_index].card_id
	print("Selected card from deck: index =", card_index, "resource card_id =", resource_card_id)
	available_cards.remove_at(random_index_position)
	print("Drawing card index", card_index, "with resource card_id", resource_card_id, "(", available_cards.size(), "cards left)")
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

func _on_face_card_3d_card_3d_mouse_up():
	var turn_phase_manager = game.turn_phase_manager
	if turn_phase_manager.sigil_placed:
		print("Cannot draw a card if sigil already placed")
		return
	add_card()

# Function to request a sync of the deck state (called by clients)
func request_deck_sync():
	var network_manager = get_node("/root/Game/NetworkManager")
	if network_manager:
		network_manager.request_deck_sync()
