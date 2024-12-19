extends Resource
class_name CardResource

enum CardType {ACTION, AREA}

@export var card_name: String = "New Card"
@export var card_type: CardType = CardType.ACTION
@export var cost_to_draw: int = 1
@export var effect1: String = ""
@export var effect2: String = ""
@export var card_image: Texture2D

func _init(p_name = "New Card", p_type = CardType.ACTION, p_cost = 1, p_effect1 = "", p_effect2 = ""):
	card_name = p_name
	card_type = p_type
	cost_to_draw = p_cost
	effect1 = p_effect1
	effect2 = p_effect2

func to_dictionary() -> Dictionary:
	return {
		"card_name": card_name,
		"card_type": card_type,
		"cost_to_draw": cost_to_draw,
		"effect1": effect1,
		"effect2": effect2
	}

func from_dictionary(data: Dictionary) -> void:
	card_name = data["card_name"]
	card_type = data["card_type"]
	cost_to_draw = data["cost_to_draw"]
	effect1 = data["effect1"]
	effect2 = data["effect2"]
