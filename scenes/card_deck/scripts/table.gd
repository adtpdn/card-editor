extends Node3D

var card_database = CardResource.new()
@export var actions_cards = preload("res://scenes/card_deck/materials/cards/action_cards.tres")
@export var available_cards = [] # Will store indices of available cards

var card_index
@export var deck_seed: int = 0
var rng = RandomNumberGenerator.new()

@onready var hand: CardCollection3D = $DragController/Hand
@onready var card_manager 

func _ready():
	card_manager = get_node("/root/Game/CardManager")
	# Debug the action cards resource
	print("Debugging action cards resource:")
	for i in range(actions_cards.cards.size()):
		var card = actions_cards.cards[i]
		print("Card index:", i, "card_id:", card.card_id, "name:", card.card_name)
	
	# Initialize available cards
	reset_available_cards()
	
	# If we're the server, generate a seed and sync it
	var game = get_node("/root/Game/")
	if game.network_manager and game.network_manager.multiplayer.is_server():
		deck_seed = randi()
		# Sync the seed to all clients
		game.network_manager.sync_deck_seed(deck_seed)

func initialize_deck_with_seed(seed_value: int):
	deck_seed = seed_value
	rng.seed = deck_seed
	
	# Re-initialize available cards with the seeded RNG
	reset_available_cards()
	
	# Shuffle the deck using the seeded RNG
	shuffle_deck()
	
	print("Deck initialized with seed:", deck_seed)

func shuffle_deck():
	# Use Fisher-Yates shuffle algorithm with our seeded RNG
	for i in range(available_cards.size() - 1, 0, -1):
		var j = rng.randi_range(0, i)
		var temp = available_cards[i]
		available_cards[i] = available_cards[j]
		available_cards[j] = temp

func reset_available_cards():
	available_cards = []
	for i in range(actions_cards.cards.size()):
		available_cards.append(i)
	
	# If we have a seed, shuffle the deck
	if deck_seed != 0:
		shuffle_deck()

#func _input(event):
	#if event.is_action_pressed("ui_down"):
		#add_card()
	#elif event.is_action_pressed("ui_up"):
		#remove_card()
	#elif event.is_action_pressed("ui_left"):
		#clear_cards()
	#elif event.is_action_pressed("ui_right"):
		#if pile.card_layout_strategy is PileCardLayout and hand.card_layout_strategy is LineCardLayout:
			#var layout := LineCardLayout.new()
			#pile.card_layout_strategy = layout
		#elif hand.card_layout_strategy is LineCardLayout:
			#hand.card_layout_strategy = FanCardLayout.new()
		#elif pile.card_layout_strategy is LineCardLayout:
			#pile.card_layout_strategy = PileCardLayout.new()
		#elif hand.card_layout_strategy is FanCardLayout:
			#hand.card_layout_strategy = LineCardLayout.new()

func instantiate_face_card(card_index) -> FaceCard3D:
	var scene = load("res://scenes/card_deck/scenes/face_card_3d.tscn")
	var face_card_3d: FaceCard3D = scene.instantiate()
	
	# Get the card from the action cards deck
	var card_resource = actions_cards.cards[card_index]
	
	# Store the actual resource card_id, completely ignoring the index
	var resource_card_id = card_resource.card_id
	
	# Set the card data explicitly from the resource
	face_card_3d.card_id = resource_card_id
	face_card_3d.card_name = card_resource.card_name
	face_card_3d.card_type = card_resource.card_type
	
	# Store the original index as metadata if needed, but don't use it for card_id
	face_card_3d.set_meta("original_card_index", card_index)
	
	face_card_3d.front_material_path = card_resource.front_mesh_material.resource_path
	face_card_3d.back_material_path = card_resource.back_mesh_material.resource_path
	
	# Debug to verify card_id is from resource
	print("Created card from index", card_index, "with RESOURCE card_id:", resource_card_id, 
		  "FINAL card_id:", face_card_3d.card_id)
	
	return face_card_3d

func add_card():
	print('add card')
	
	# Check if the hand is full
	var game = get_node("/root/Game/")
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
		# Double-check the card_id is correct and matches the resource
		if card.card_id != data["card_id"]:
			print("Warning: Card ID mismatch. Expected:", data["card_id"], "Got:", card.card_id)
			card.card_id = data["card_id"]  # Force the correct ID from resource
		
		hand.append_card(card)

		card.global_position = $"../Deck".global_position
		
		# Handle turn phase logic when drawing a card
		var turn_phase_manager = game.turn_phase_manager
		if turn_phase_manager:
			var current_phase = turn_phase_manager.current_phase
			
			# If we're in the biome phase, drawing a card means we skip this phase
			if card_manager.is_plant_extra:
				pass
			
			elif current_phase == turn_phase_manager.Phase.PLANT_BIOME:
				# Complete the current phase and move to next phase
				turn_phase_manager.completed_phases[turn_phase_manager.Phase.PLANT_BIOME] = true
				turn_phase_manager.advance_to_next_phase()
			
			# If we're in the sigil/card phase, drawing a card counts as planting a sigil
			elif current_phase == turn_phase_manager.Phase.PLANT_SIGIL_AND_CARD and !turn_phase_manager.sigil_placed:
				# Mark sigil as placed and check for phase completion
				turn_phase_manager.sigil_placed = true
				print("sigil placed true")
				if card_manager.is_plant_extra:
					game.token_button.disabled = false
				else:
					game.token_button.disabled = true
				turn_phase_manager.check_phase_two_completion()
		
		# Only sync the available_cards state, don't make the client draw a card
		if game.network_manager and game.network_manager.multiplayer and game.network_manager.multiplayer.get_peers().size() > 0:
			# Sync with the resource card_id, not the index
			game.network_manager.sync_card_drawn(data["card_id"])
			
		return true
	
	return false

func next_card():
	if available_cards.size() == 0:
		return null
		
	# Use our seeded RNG instead of randi()
	var random_index_position = rng.randi() % available_cards.size() if deck_seed != 0 else randi() % available_cards.size()
	var card_index = available_cards[random_index_position]
	
	# Get the actual card_id from the resource
	var resource_card_id = actions_cards.cards[card_index].card_id
	
	# Debug the selected card
	print("Selected card from deck: index =", card_index, "resource card_id =", resource_card_id)
	
	# Remove this card from available cards
	available_cards.remove_at(random_index_position)
	
	print("Drawing card index", card_index, "with resource card_id", resource_card_id, "(", available_cards.size(), "cards left)")
	
	# Return both the index and the card_id
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

func _on_face_card_3d_card_3d_mouse_up():
	var game = get_node("/root/Game")
	var turn_phase_manager = game.turn_phase_manager
	if turn_phase_manager.sigil_placed :
		print("cant draw a card if sigil already placed")
		return
	
	add_card()

# Function to request a sync of the deck state (called by clients)
func request_deck_sync():
	var network_manager = get_node("/root/Game/NetworkManager")
	if network_manager:
		network_manager.request_deck_sync()
