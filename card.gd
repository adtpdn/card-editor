@tool
class_name Card
extends Panel

const SIZE := Vector2(100, 140)
const CARD_BACK_TEXTURE = preload("res://assets/cards/2D/tile056.png")

@export var card_resource: CardResource:
	set(new_resource):
		card_resource = new_resource
		update_card_display()

@onready var label: Label = $Label
@onready var image: TextureRect = $Image
@onready var cost_label: Label = $CostLabel
@onready var effect1_label: Label = $Effect1Label
@onready var effect2_label: Label = $Effect2Label
var selected = false

func _ready() -> void:
	update_card_display()
	# Ensure consistent initial appearance
	modulate = Color(1, 1, 1, 1)
	pivot_offset = size * 0.5  # Set pivot to center for better rotation

func update_card_display() -> void:
	if not is_inside_tree():
		return
	
	if card_resource:
		if card_resource.revealed:
			# Show card face
			label.text = card_resource.card_name
			cost_label.text = "Cost: " + str(card_resource.cost_to_draw)
			effect1_label.text = card_resource.effect1
			effect2_label.text = card_resource.effect2
			if card_resource.card_image:
				image.texture = card_resource.card_image
			
			# Show all card elements
			label.visible = true
			cost_label.visible = true
			effect1_label.visible = true
			effect2_label.visible = true
		else:
			# Show card back
			image.texture = CARD_BACK_TEXTURE
			
			# Hide card elements
			label.visible = false
			cost_label.visible = false
			effect1_label.visible = false
			effect2_label.visible = false
	else:
		label.text = "No Card Data"
		cost_label.text = ""
		effect1_label.text = ""
		effect2_label.text = ""
		image.texture = null
	
	# Force redraw in editor
	if Engine.is_editor_hint():
		queue_redraw()

func set_card_resource(new_card_resource: CardResource) -> void:
	card_resource = new_card_resource

func _get_configuration_warning() -> String:
	if not card_resource:
		return "Assign a CardResource to this card"
	return ""

func set_selected(value: bool) -> void:
	selected = value
	if selected:
		modulate = Color(1.2, 1.2, 1.2, 1.0)
	else:
		modulate = Color(1, 1, 1, 1.0)

func _gui_input(event):
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var hand = get_parent()
			if !hand.can_interact:  # Check if hand interaction is enabled
				return
			selected = !selected
			if selected:
				modulate = Color(1.2, 1.2, 1.2)  # Highlight selected card
			else:
				modulate = Color(1, 1, 1)  # Reset to normal
