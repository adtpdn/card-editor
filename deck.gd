# deck.gd
extends Node
class_name Deck

var cards: Array[CardResource] = []

func add_card(card: CardResource):
	cards.append(card)

func remove_card(index: int):
	if index >= 0 and index < cards.size():
		cards.remove_at(index)

func get_cards() -> Array[CardResource]:
	return cards

func shuffle():
	cards.shuffle()

func draw_card() -> CardResource:
	if cards.size() > 0:
		return cards.pop_front()
	return null

func is_empty() -> bool:
	return cards.is_empty()
