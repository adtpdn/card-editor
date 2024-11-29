# card_resources.gd
@tool
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

func save_to_file(path: String):
	var error = ResourceSaver.save(self, path)
	if error != OK:
		print("An error occurred while saving the card.")

func load_from_file(path: String) -> bool:
	if ResourceLoader.exists(path):
		var loaded_resource = ResourceLoader.load(path)
		if loaded_resource is CardResource:
			card_name = loaded_resource.card_name
			card_type = loaded_resource.card_type
			cost_to_draw = loaded_resource.cost_to_draw
			effect1 = loaded_resource.effect1
			effect2 = loaded_resource.effect2
			card_image = loaded_resource.card_image
			return true
	return false

func duplicate(subresources: bool = false):
	var new_card = get_script().new()
	new_card.card_name = self.card_name
	new_card.card_type = self.card_type
	new_card.cost_to_draw = self.cost_to_draw
	new_card.effect1 = self.effect1
	new_card.effect2 = self.effect2
	new_card.card_image = self.card_image
	return new_card
	

# In card_resource.gd

func to_dictionary() -> Dictionary:
	return {
		"card_name": card_name,
		"card_type": card_type,
		"cost_to_draw": cost_to_draw,
		"effect1": effect1,
		"effect2": effect2,
		# Add other properties as needed
	}

func from_dictionary(data: Dictionary) -> void:
	card_name = data["card_name"]
	card_type = data["card_type"]
	cost_to_draw = data["cost_to_draw"]
	effect1 = data["effect1"]
	effect2 = data["effect2"]
	# Set other properties as needed
