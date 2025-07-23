extends Control


@onready var game = get_node("/root/Game")
@onready var soil_star_label = $HBoxContainer/SoilStarLabel
@onready var soil_star_texture = $HBoxContainer/SoilStarTexture

@export var current_soil_star : int = 0 

# Shader
const soil_star_shader = preload("res://assets/materials/shaders/soil_star.gdshader")

func _ready():
	soil_star_texture.connect("pressed", _on_soil_star_texture_pressed)

func increase_soil_star(_count: int) -> void:
	if current_soil_star + _count >= 5:
		current_soil_star = 5
		soil_star_label.text = str(current_soil_star)
		return
	
	current_soil_star += _count
	soil_star_label.text = str(current_soil_star)
	soil_star_texture.material = setup_shader_material()

func decrease_soil_star(_count: int) -> void:
	current_soil_star -= _count
	soil_star_label.text = str(current_soil_star)
	if current_soil_star == 0:
		soil_star_texture.material = null

# Shader Setup
func setup_shader_material() -> ShaderMaterial:
	var shader_material = ShaderMaterial.new()
	shader_material.shader = soil_star_shader
	
	return shader_material

# Buttons
func _on_soil_star_texture_pressed():
	var soil_star_actions = game.soil_star_actions
	if current_soil_star == 0:
		return
	soil_star_actions._show_hide_actions_panel()
