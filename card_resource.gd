extends Resource
class_name CardResource

enum CardType {ACTION, AREA}

@export var card_name: String = "New Card"
@export var card_type: CardType = CardType.ACTION
@export var cost_to_draw: int = 1
@export var effect1: String = ""
@export var effect2: String = ""
@export var revealed: bool = true
@export var tex3D_path: String = ""
@export var image_path: String = ""

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
		"effect2": effect2,
		"revealed": revealed,
		"tex3D_path": tex3D_path,
		"image_path": image_path
	}

func from_dictionary(data: Dictionary) -> void:
	card_name = data["card_name"]
	card_type = data["card_type"]
	cost_to_draw = data["cost_to_draw"]
	effect1 = data["effect1"]
	effect2 = data["effect2"]
	revealed = data["revealed"]
	tex3D_path = data["tex3D_path"]
	image_path = data.get("image_path", "")

func _get_property_list():
	var properties = []
	properties.append({
		"name": "card_image",
		"type": TYPE_OBJECT,
		"usage": PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_SCRIPT_VARIABLE
	})
	properties.append({
		"name": "tex3D_path",
		"type": TYPE_STRING,
		"usage": PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_SCRIPT_VARIABLE
	})
	return properties
