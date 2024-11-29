# card_instance.gd
@tool
extends Node2D
class_name CardInstance

@export var card_resource: CardResource

var card_width: float = 100
var card_height: float = 150

func _ready():
	if card_resource:
		update_card_display()

func update_card_display():
	queue_redraw()

func _draw():
	if card_resource:
		# Draw card background
		draw_rect(Rect2(0, 0, card_width, card_height), Color.LIGHT_GRAY)
		
		# Draw card image
		if card_resource.card_image:
			draw_texture_rect(card_resource.card_image, Rect2(5, 5, card_width - 10, card_height / 2 - 10), false)
		
		# Draw card name
		var font = SystemFont.new()
		draw_string(font, Vector2(5, card_height / 2 + 20), card_resource.card_name, HORIZONTAL_ALIGNMENT_LEFT, card_width - 10, 16)
		
		# Draw card type
		var type_text = "Action Card" if card_resource.card_type == CardResource.CardType.ACTION else "Area Card"
		draw_string(font, Vector2(5, card_height / 2 + 40), type_text, HORIZONTAL_ALIGNMENT_LEFT, card_width - 10, 16)
		
		# Draw cost to draw
		draw_string(font, Vector2(5, card_height / 2 + 60), "Cost: " + str(card_resource.cost_to_draw), HORIZONTAL_ALIGNMENT_LEFT, card_width - 10, 16)
		
		# Draw effects
		draw_string(font, Vector2(5, card_height / 2 + 80), "Effect 1: " + card_resource.effect1, HORIZONTAL_ALIGNMENT_LEFT, card_width - 10, 16)
		draw_string(font, Vector2(5, card_height / 2 + 100), "Effect 2: " + card_resource.effect2, HORIZONTAL_ALIGNMENT_LEFT, card_width - 10, 16)

func _get_configuration_warning():
	if not card_resource:
		return "Assign a CardResource to this node"
	return ""
