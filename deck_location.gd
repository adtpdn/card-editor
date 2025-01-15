# deck_location.gd
class_name DeckLocation
extends Node3D

signal card_drawn(card_resource: CardResource)

@export var deck_resource: DeckResource
@export var deck_name: String = ""
var deck: Deck

func _ready():
	deck = Deck.new()
	if deck_resource:
		for card in deck_resource.cards:
			deck.add_card(card)
	deck.shuffle()

func draw_card() -> CardResource:
	if deck.is_empty():
		#print("Deck is empty: ", deck_name)
		return null
	var card = deck.draw_card()
	#print("Drew card: ", card.card_name, " from ", deck_name)
	emit_signal("card_drawn", card)
	return card

func peek_top_card() -> CardResource:
	if deck.is_empty():
		return null
	return deck.cards[0]

func reset_deck():
	#print("Resetting deck: ", deck_name)
	deck = Deck.new()
	for card in deck_resource.cards:
		deck.add_card(card)
	deck.shuffle()
	#print("Deck size after reset: ", deck.cards.size())
