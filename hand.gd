extends ColorRect

@export var hand_curve: Curve
@export var rotation_curve: Curve

@export var max_rotation_degrees := 10
@export var x_sep := 20
@export var y_min := 50
@export var y_max := -50

# Single array to hold all cards
var cards: Array[Card] = []
var card_resources: Array[CardResource] = []

var card_scene: PackedScene = preload("res://card.tscn")
var selected_card: Card = null
var can_interact = false
var selected = false  # Add this at the top with other variables

# Visual settings for different card types
const TYPE_SETTINGS = {
	0: { # CardResource.CardType.ACTION
		"color": Color(1, 0.8, 0.8, 0.2)  # Slight red tint for Action cards
	},
	1: { # CardResource.CardType.AREA
		"color": Color(0.8, 0.8, 1, 0.2)  # Slight blue tint for Area cards
	}
}

const CARD_BASE_POSITION = Vector2(0, 0)
const CARD_SPACING = 110  # Adjust this value to control card spacing
const CARD_VISUAL_SETTINGS = {
	CardResource.CardType.ACTION: {
		"color": Color(1, 0.8, 0.8, 1.0),
		"highlight_color": Color(1.2, 0.9, 0.9, 1.0)
	},
	CardResource.CardType.AREA: {
		"color": Color(0.8, 0.8, 1, 1.0),
		"highlight_color": Color(0.9, 0.9, 1.2, 1.0)
	}
}

var player_id: int = -1


func _ready():
	player_id = multiplayer.get_unique_id()
	#print("Hand initialized for player: ", player_id)

func _gui_input(event):
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if !can_interact:  # Don't process input if interaction is disabled
				return
				
			for card in cards:
				if card.selected:
					card.selected = false
					card.modulate = Color(1, 1, 1)
			selected = !selected

func set_interaction_enabled(enabled: bool):
	can_interact = enabled
	for card in cards:
		card.set_process_input(enabled)  # This disables the card's input processing
		card.modulate.a = 1.0 if enabled else 0.5  # Visual feedback
		if !enabled:
			card.selected = false  # Deselect cards when disabling interaction
			card.modulate = Color(1, 1, 1, 0.5)
			selected = false

func can_accept_card(card: CardResource) -> bool:
	return true

func draw(card_resource: CardResource) -> void:
	if not card_resource:
		#print("Error: Trying to draw null card resource")
		return
	
	#print("Drawing card for player ", player_id, ": ", card_resource.card_name)
	card_resources.append(card_resource)
	_update_cards()

func clear_hand() -> void:
	card_resources.clear()
	for child in get_children():
		if child is Card:
			child.queue_free()
	cards.clear()
	#print("Cleared hand for player ", player_id)

func discard() -> void:
	if not card_resources.is_empty():
		card_resources.pop_back()
	_update_cards()

func _update_cards() -> void:
	#print("Updating cards for player ", player_id)
	#print("Card resources count: ", card_resources.size())
	
	# Clear existing cards
	for child in get_children():
		if child is Card:
			child.queue_free()
	cards.clear()
	
	# Create new cards
	for resource in card_resources:
		var card = card_scene.instantiate()
		add_child(card)
		card.card_resource = resource
		cards.append(card)
	
	# Calculate layout
	var card_count = cards.size()
	if card_count == 0:
		return
	
	# Position cards
	var card_width = 100
	var spacing = 20
	var total_width = (card_width * card_count) + (spacing * (card_count - 1))
	var start_x = (size.x - total_width) * 0.5
	
	for i in range(card_count):
		var card = cards[i]
		var progress = float(i) / max(1, card_count - 1)
		var y_offset = hand_curve.sample(progress) * -50  # Adjust y_max as needed
		var rotation = rotation_curve.sample(progress) * 10  # Adjust max_rotation as needed
		
		card.position = Vector2(
			start_x + (i * (card_width + spacing)),
			size.y - card.SIZE.y + y_offset
		)
		card.rotation_degrees = rotation
		card.pivot_offset = card.SIZE * 0.5
		card.set_process_input(can_interact)
		
		if not can_interact:
			card.modulate.a = 0.5
	
	#print("Updated ", card_count, " cards for player ", player_id)


func apply_card_visual_style(card: Card) -> void:
	var card_type = card.card_resource.card_type
	var settings = CARD_VISUAL_SETTINGS[card_type]
	
	# Apply base color
	card.modulate = settings["color"]
	
	# Set up highlight color for selection
	if card.selected:
		card.modulate = settings["highlight_color"]

func get_selected_card() -> Card:
	if !can_interact:  # Don't return selected card if interaction is disabled
		return null
	for card in cards:
		if card.selected:
			return card
	return null

func remove_card(card: Card) -> void:
	if not card:
		return
	
	var index = cards.find(card)
	if index != -1:
		# Remove locally only
		if index < cards.size():
			cards[index].queue_free()
			cards.remove_at(index)
		if index < card_resources.size():
			card_resources.remove_at(index)
		_update_cards()
		
		# Notify server about card removal
		if !multiplayer.is_server():
			rpc_id(1, "notify_card_removed", index, multiplayer.get_unique_id())

@rpc("any_peer")
func notify_card_removed(index: int, player_id: int):
	if multiplayer.is_server():
		# Update server's tracking of player hands
		var game_node = get_node("/root/Game")
		if game_node:
			game_node.remove_card_from_player_hand(player_id, index)

@rpc("any_peer")
func request_remove_card(index: int):
	if multiplayer.is_server():
		rpc("sync_remove_card", index)

@rpc("any_peer", "call_local")
func sync_remove_card(index: int):
	if index >= 0 and index < card_resources.size():
		if index < cards.size():
			cards[index].queue_free()
			cards.remove_at(index)
		card_resources.remove_at(index)
		_update_cards()

# Helper functions for card management
func get_card_count() -> int:
	return card_resources.size()  # Use card_resources instead of cards array

func get_card_at_index(index: int) -> Card:
	if index >= 0 and index < cards.size():
		return cards[index]
	return null

func clear_selection() -> void:
	if !can_interact:  # Don't allow clearing selection if interaction is disabled
		return
	for card in cards:
		card.selected = false
		card.modulate = Color(1, 1, 1)

func is_hand_empty() -> bool:
	return cards.is_empty()

# Visual feedback functions
func highlight_playable_cards(valid_types: Array) -> void:
	for card in cards:
		if valid_types.has(card.card_resource.card_type):
			card.modulate.a = 1.0
		else:
			card.modulate.a = 0.5

func reset_card_visuals() -> void:
	for card in cards:
		card.modulate.a = 1.0
		if card.selected:
			card.modulate = Color(1.2, 1.2, 1.2)
		else:
			card.modulate = Color(1, 1, 1)

# Turn management
func enable_interaction() -> void:
	can_interact = true
	_update_cards()

func disable_interaction() -> void:
	can_interact = false
	clear_selection()
	_update_cards()

# Card arrangement helpers
func arrange_cards() -> void:
	_update_cards()

func get_card_position(index: int) -> Vector2:
	if index >= 0 and index < cards.size():
		return cards[index].position
	return Vector2.ZERO

func get_card_rotation(index: int) -> float:
	if index >= 0 and index < cards.size():
		return cards[index].rotation_degrees
	return 0.0

func get_cards_by_type(type: int) -> Array:
	var result = []
	for card in cards:
		if card.card_resource.card_type == type:
			result.append(card)
	return result
