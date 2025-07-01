extends Node3D

var card_database = CardResource.new()
var actions_cards = preload("res://cards/action_cards.tres")
var available_cards = [] # Will store indices of available cards

@onready var hand: CardCollection3D = $DragController/Hand
#@onready var pile: CardCollection3D = $DragController/CardSlotBiome1

func _ready():
	# Initialize available cards
	reset_available_cards()

func reset_available_cards():
	available_cards = []
	for i in range(actions_cards.cards.size()):
		available_cards.append(i)

func _input(event):
	if event.is_action_pressed("ui_down"):
		add_card()
	elif event.is_action_pressed("ui_up"):
		remove_card()
	elif event.is_action_pressed("ui_left"):
		clear_cards()
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
	var scene = load("res://card_deck/face_card_3d.tscn")
	var face_card_3d: FaceCard3D = scene.instantiate()
	
	# Get the card from the action cards deck
	var card_resource = actions_cards.cards[card_index]
	
	# Set the card data
	face_card_3d.card_id = card_resource.card_id
	face_card_3d.card_name = card_resource.card_name
	face_card_3d.card_type = card_resource.card_type
	
	# If you want to load and set the 3D texture
	if card_resource.tex3D_path:
		var material = load(card_resource.tex3D_path)
		if material:
			face_card_3d.get_node("CardMesh/CardFrontMesh").set_surface_override_material(0, material)
	
	return face_card_3d

func add_card():
	print('add card')
	if available_cards.size() == 0:
		print("Deck is empty! Reshuffling...")
		reset_available_cards()
		
	var data = next_card()
	if data:
		var card = instantiate_face_card(data["id"])
		hand.append_card(card)
		
		card.global_position = $"../Deck".global_position

func next_card():
	if available_cards.size() == 0:
		return null
		
	# Select a random index from available cards
	var random_index_position = randi() % available_cards.size()
	var card_index = available_cards[random_index_position]
	
	# Remove this card from available cards
	available_cards.remove_at(random_index_position)
	
	print("Drawing card index ", card_index, " (", available_cards.size(), " cards left)")
	
	return {"id": card_index}

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
	
	#pile.append_card(c)
	c.remove_hovered()
	c.global_position = card_global_position

func clear_cards():
	var hand_cards = hand.remove_all()
	#var pile_cards = pile.remove_all()
	
	for c in hand_cards:
		c.queue_free()
	
	#for c in pile_cards:
		#c.queue_free()

func _on_face_card_3d_card_3d_mouse_up():
	add_card()
