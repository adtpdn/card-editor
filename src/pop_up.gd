extends Control

@onready var panel = $Panel
@onready var label = $Panel/Label


func show_instruction_label(text: String):
	label.text = text
	show()

# Clear the instruction label
func hide_panel():
	hide()
