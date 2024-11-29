# deck_builder.gd
@tool
extends Node
class_name DeckBuilder

@export var deck: Array[CardResource] = []

func add_card(card: CardResource):
	deck.append(card)

func remove_card(index: int):
	if index >= 0 and index < deck.size():
		deck.remove_at(index)

func shuffle_deck():
	deck.shuffle()

func draw_card() -> CardResource:
	if deck.size() > 0:
		return deck.pop_front()
	return null

func _get_configuration_warning():
	if deck.is_empty():
		return "Add CardResource instances to the deck"
	return ""

func duplicate_card(card: CardResource):
	var index = deck.find(card)
	if index != -1:
		var new_card = card.duplicate()
		new_card.card_name = "Copy of " + card.card_name
		deck.insert(index + 1, new_card)
		notify_property_list_changed()

func _get_property_list():
	var properties = []
	properties.append({
		"name": "cards",
		"type": TYPE_ARRAY,
		"usage": PROPERTY_USAGE_DEFAULT,
		"hint": PROPERTY_HINT_RESOURCE_TYPE,
		"hint_string": "CardResource"
	})
	return properties
