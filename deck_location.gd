# deck_location.gd
class_name DeckLocation
extends Node3D

signal card_drawn(card_resource: CardResource)

@export var deck_name: String = "Default Deck"
@export var revealed: bool = false
@export var deck: Array[CardResource] = []

var current_deck: Array[CardResource] = []

func _ready():
	current_deck = deck.duplicate()
	current_deck.shuffle()

func draw_card() -> CardResource:
	if current_deck.is_empty():
		print("Deck is empty: ", deck_name)  # Debug print
		return null
	var card = current_deck.pop_front()
	print("Drew card: ", card.card_name, " from ", deck_name)  # Debug print
	emit_signal("card_drawn", card)
	return card

func peek_top_card() -> CardResource:
	if current_deck.is_empty():
		return null
	return current_deck[0]

func reset_deck():
	print("Resetting deck: ", deck_name)  # Debug print
	current_deck = deck.duplicate()
	current_deck.shuffle()
	print("Deck size after reset: ", current_deck.size())  # Debug print
