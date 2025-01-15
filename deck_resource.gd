extends Resource
class_name DeckResource

@export var cards: Array[CardResource] = []

func add_card(card: CardResource):
	cards.append(card)

func remove_card(index: int):
	if index >= 0 and index < cards.size():
		cards.remove_at(index)

func get_cards() -> Array[CardResource]:
	return cards
