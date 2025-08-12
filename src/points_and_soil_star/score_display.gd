extends Control

@onready var score_value_label = $HBoxContainer/ScoreValue

func update_score(new_score: int):
	score_value_label.text = str(new_score)
