# deck_location.gd
class_name DeckLocation
extends Node3D

signal card_drawn(card_resource: CardResource)

@export var deck_resource: DeckResource
@export var deck_name: String = ""
var deck: Deck
var drawn_cards: Array[CardResource] = []

func _ready():
	deck = Deck.new()
	if deck_resource:
		for card in deck_resource.cards:
			deck.add_card(card)
	deck.shuffle()

func draw_card() -> CardResource:
	if deck.is_empty():
		reset_deck()  # Automatically reset when empty
		if deck.is_empty():  # If still empty after reset
			return null
	
	var card = deck.draw_card()
	if card:
		drawn_cards.append(card)
		emit_signal("card_drawn", card)
	return card

func peek_top_card() -> CardResource:
	if deck.is_empty():
		return null
	return deck.cards[0]

func reset_deck():
	deck = Deck.new()
	if deck_resource:
		for card in deck_resource.cards:
			# Only add cards that haven't been drawn or were discarded
			if !drawn_cards.has(card):
				deck.add_card(card)
	deck.shuffle()
	drawn_cards.clear()
