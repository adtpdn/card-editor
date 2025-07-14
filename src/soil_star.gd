extends Control


@onready var soil_star_label = $HBoxContainer/SoilStarLabel
@onready var soil_star_texture = $HBoxContainer/SoilStarTexture

@export var current_soil_star : int = 0 


func increase_soil_star(_count: int) -> void:
	current_soil_star += _count
	soil_star_label.text = str(current_soil_star)

func decrease_soil_star(_count: int) -> void:
	current_soil_star -= _count
	soil_star_label.text = str(current_soil_star)

func checking_available_soils_star(_used_soil_star: int) -> void:
	if current_soil_star < _used_soil_star:
		return
	
	decrease_soil_star(_used_soil_star)
