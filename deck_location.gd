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
	
	# Draw a card that hasn't been drawn yet
	var card = null
	var attempts = 0
	var max_attempts = deck.cards.size()
	
	while attempts < max_attempts:
		card = deck.draw_card()
		if card and !is_card_in_drawn_cards(card):
			drawn_cards.append(card)
			emit_signal("card_drawn", card)
			return card
		elif card:
			# Put the card back and shuffle if it's a duplicate
			deck.add_card(card)
			deck.shuffle()
		attempts += 1
	
	return null

func is_card_in_drawn_cards(card: CardResource) -> bool:
	for drawn_card in drawn_cards:
		if drawn_card.card_name == card.card_name and \
		   drawn_card.card_type == card.card_type and \
		   drawn_card.cost_to_draw == card.cost_to_draw:
			return true
	return false

func peek_top_card() -> CardResource:
	if deck.is_empty():
		return null
	return deck.cards[0]

func reset_deck():
	deck = Deck.new()
	if deck_resource:
		# Create a list of available cards by filtering out drawn ones
		var available_cards = []
		for card in deck_resource.cards:
			var is_drawn = false
			for drawn_card in drawn_cards:
				if drawn_card.card_name == card.card_name and \
				   drawn_card.card_type == card.card_type and \
				   drawn_card.cost_to_draw == card.cost_to_draw:
					is_drawn = true
					break
			if !is_drawn:
				available_cards.append(card)
		
		# Add only undrawn cards back to the deck
		for card in available_cards:
			deck.add_card(card)
	deck.shuffle()
	drawn_cards.clear()
