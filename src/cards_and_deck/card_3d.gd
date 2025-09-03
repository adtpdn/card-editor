"""
Card3D
==============

Script for the Card3D scene

Usage:
	- extend the card_3d scene and to add your custom card details
	- extent Card3D class and apply it to your inherited scene
"""
class_name Card3D
extends Node3D

@export var hover_scale_factor: float = 1.15
@export var hover_pos_move: Vector3 = Vector3(0, 0.7, 0)
@export var move_tween_duration: float = 0.08
@export var rotate_tween_duration: float = 0.15
@export var face_down: bool = false:
	set(_face_down):
		face_down = _face_down
		if face_down:
			$CardMesh.rotation.y = PI
		else:
			$CardMesh.rotation.y = 0

signal card_3d_mouse_down()
signal card_3d_mouse_up()
signal card_3d_mouse_over()
signal card_3d_mouse_exit()


var position_tween: Tween
var rotate_tween: Tween
var hover_tween: Tween

enum PileType { NONE, ACTION, ELEMENTAL }


# Dictionary to hold the notification text for each elemental card
const ELEMENTAL_NOTIFICATION_TEXT = {
	"BLUE": {
		0: "Cannot use Sigil A pattern.",
		1: "Cannot use Sigil B pattern.",
		2: "Cannot use Sigil C pattern.",
		3: "Cannot place token energy on blighted Sigil column.",
		4: "Cannot place token energy on blighted Sigil column.",
		5: "Cannot place token energy on blighted Sigil column.",
		6: "Mana cannot be converted to points but remains in Mana slot.",
		7: "Consumes 2 Mana to activate Sigil Magic pattern.",
		8: "Mana amount depends on blighted tokens in Biome."
	},
	"RED": {
		0: "Requires at least 1 blight token in a Biome, determined by dominance; if tied, from last player in reverse order.",
		1: "Requires at least 2 blight tokens in a Biome, determined by dominance; if tied, from last player in reverse order.",
		2: "Maximum 4 tokens in a Biome; excess tokens blighted from dominant player, or if tied, from last player in reverse order.",
		3: "Maximum 5 tokens in a Biome; excess tokens blighted from dominant player, or if tied, from last player in reverse order.",
		4: "Blighted tokens dominate the Biome.",
		5: "1 point counts as 1 score.",
		6: "Dominant player in a Biome gains a card instead of a soil star.",
		7: "Cannot plant tokens in a Biome.",
		8: "Fewer tokens in a Biome dominate it."
	}
}

func disable_collision():
	$StaticBody3D/CollisionShape3D.disabled = true
	
	
func enable_collision():
	$StaticBody3D/CollisionShape3D.disabled = false


func set_hovered():
	if hover_tween and hover_tween.is_running:
		hover_tween.kill()
	
	hover_tween = create_tween()
	hover_tween.set_parallel(true)
	hover_tween.set_ease(Tween.EASE_IN)
	_tween_card_scale(hover_scale_factor)
	_tween_mesh_position(hover_pos_move, move_tween_duration)

func set_notification_elemental_hover(card):
	var game = get_node("/root/Game")
	var card_type_str = "RED" if card.elemental_type == CardResource.ElementalType.RED else "BLUE"
	if ELEMENTAL_NOTIFICATION_TEXT.has(card_type_str) and ELEMENTAL_NOTIFICATION_TEXT[card_type_str].has(card.card_id):
		var notification_text = ELEMENTAL_NOTIFICATION_TEXT[card_type_str][card.card_id]
		game.notification.show_instruction_label(notification_text)


func remove_hovered():
	var parent = self.get_parent()
	#print("parent : ", parent)
	if hover_tween and hover_tween.is_running:
		hover_tween.kill()
		
	hover_tween = create_tween()
	hover_tween.set_parallel(true)
	hover_tween.set_ease(Tween.EASE_IN)
	
	# Card planted on biome
	if parent.name != "Hand":
		_tween_card_scale(0.7)
	else:
		_tween_card_scale(1)
	_tween_mesh_position(Vector3.ZERO, move_tween_duration)


func dragging_rotation(drag_rotation):
	if rotate_tween and rotate_tween.is_running:
		rotate_tween.kill()
	
	rotate_tween = create_tween()
	_tween_card_rotation(drag_rotation, rotate_tween_duration)


func animate_to_position(new_position: Vector3, duration = move_tween_duration):
	if position_tween and position_tween.is_running:
		position_tween.kill()
	
	position.z = new_position.z # set z to prevent transition spring from making card go below another card
	position_tween = create_tween()
	position_tween.set_ease(Tween.EASE_OUT)
	position_tween.set_trans(Tween.TRANS_SPRING)
	_tween_card_position(new_position, duration)
	return position_tween


func _tween_card_scale(scale_factor: float):
	var target_scale = Vector3(scale_factor, scale_factor,1)
	hover_tween.tween_property($".", "scale", target_scale, move_tween_duration)


func _tween_mesh_position(pos: Vector3, duration: float):
	hover_tween.tween_property($CardMesh, "position", pos, duration)


func _tween_card_position(pos: Vector3, duration: float):
	position_tween.tween_property($".", "position", pos, duration)


func _tween_card_rotation(target_rotation, duration):
	rotate_tween.set_ease(Tween.EASE_IN)
	rotate_tween.tween_property($".", "rotation", target_rotation, duration)


func _on_static_body_3d_mouse_entered():
	card_3d_mouse_over.emit()


func _on_static_body_3d_mouse_exited():
	card_3d_mouse_exit.emit()


func _on_static_body_3d_input_event(_camera, event, _event_position, _normal, _shape_idx):
	if event is InputEventMouseButton:
		var button = event.button_index
		var pressed = event.pressed
		if button == 1 and pressed == true:
			card_3d_mouse_down.emit()
		elif button == 1 and pressed == false:
			card_3d_mouse_up.emit()
			
