extends Control


@onready var game = get_node("/root/Game")
@onready var soil_star_label = $HBoxContainer/SoilStarLabel
@onready var soil_star_texture = $HBoxContainer/SoilStarTexture

@export var current_soil_star : int = 0 

# Shader
const soil_star_shader = preload("res://assets/materials/shaders/soil_star.gdshader")

func _ready():
	soil_star_texture.connect("pressed", _on_soil_star_texture_pressed)

#func _ready():
	## Create the purchase button if not already in the scene
	#if not purchase_button:
		#purchase_button = Button.new()
		#purchase_button.text = "Buy Elemental Card"
		#$HBoxContainer.add_child(purchase_button)
		#purchase_button.pressed.connect(_on_purchase_button_pressed)

#func _on_purchase_button_pressed():
	#var game = get_node("/root/Game")
	#var table = game.get_node("Deck/Table")
	#if table and game.game_state_manager.is_valid_player_turn(multiplayer.get_unique_id()):
		#if multiplayer.is_server():
			#table.purchase_elemental_card()
		#else:
			#rpc_id(1, "request_purchase_elemental_card", multiplayer.get_unique_id())


func increase_soil_star(_count: int) -> void:
	if current_soil_star + _count >= 5:
		current_soil_star = 5
		soil_star_label.text = str(current_soil_star)
		return
	
	current_soil_star += _count
	soil_star_label.text = str(current_soil_star)
	soil_star_texture.material = setup_shader_material()
	sync_soil_stars()

func decrease_soil_star(_count: int) -> void:
	current_soil_star -= _count
	current_soil_star = max(0, current_soil_star)
	soil_star_label.text = str(current_soil_star)
	sync_soil_stars()

func checking_available_soils_star(_used_soil_star: int) -> bool:
	return current_soil_star >= _used_soil_star

# Temporary RPC

@rpc("any_peer", "call_local")
func sync_soil_stars():
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

@rpc("any_peer")
func request_purchase_elemental_card(player_id: int):
	if multiplayer.is_server():
		var game = get_node("/root/Game")
		if game.game_state_manager.is_valid_player_turn(player_id):
			var table = game.get_node("Deck/Table")
			table.purchase_elemental_card()
