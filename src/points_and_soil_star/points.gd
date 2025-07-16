extends Control

@onready var points_label = $HBoxContainer/PointsLabel
@onready var points_texture = $HBoxContainer/PointsTexture

@export var current_point : int = 0

func increase_point(_count: int) -> void:
	current_point += _count
