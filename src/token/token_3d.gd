class_name Token3D
extends Node3D

enum BiomeType {FOREST, WATER, MOUNTAIN, DESERT}

var biome_type: BiomeType
@onready var token_mesh: MeshInstance3D = $TokenMesh
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var game = get_node("/root/Game")
@onready var outerglow = $Outerglow
@onready var marker_mesh = $MarkerMesh


var player_color_index: int = -1
var owner_id: int = -1
var token_type: int = 0
var is_energy: bool = false
var is_blighted: bool = false
var token_placement = null

signal token_clicked(token)

var is_highlighted = false
var pattern_highlights = []

# References to player materials
var token_mat_player_1 = preload("res://assets/materials/token_material/token_mat_player_1.tres")
var token_mat_player_2 = preload("res://assets/materials/token_material/token_mat_player_2.tres")
var token_mat_player_3 = preload("res://assets/materials/token_material/token_mat_player_3.tres")
var token_mat_player_4 = preload("res://assets/materials/token_material/token_mat_player_4.tres")

func _ready():
	# Make sure the token is clickable
	var static_body = $TokenMesh/StaticBody3D
	if static_body:
		var input_listener = static_body
		input_listener.input_event.connect(_on_input_event)
	
	# Apply material based on owner_id if available
	update_material()

func set_token_data(biome, owner, is_energy_token=false):
	biome_type = biome
	owner_id = owner
	is_energy = is_energy_token  # Set energy status
	
	# Apply the appropriate material
	update_material()

func set_player_color_index(index: int):
	player_color_index = index
	apply_color_by_index(index)

func apply_color_by_index(index: int):
	if !token_mesh:
		token_mesh = $TokenMesh
		
	if token_mesh:
		match index:
			0:
				token_mesh.material_override = token_mat_player_1
				print("Applied player 1 material by index")
			1:
				token_mesh.material_override = token_mat_player_2
				print("Applied player 2 material by index")
			2:
				token_mesh.material_override = token_mat_player_3
				print("Applied player 3 material by index")
			3:
				token_mesh.material_override = token_mat_player_4
				print("Applied player 4 material by index")
			_:
				print("Invalid player color index: ", index)

func update_material():
	# Make sure we have the token mesh
	if !token_mesh:
		token_mesh = $TokenMesh
	
	# First try to use the explicit color index if available
	if player_color_index >= 0 and token_mesh:
		apply_color_by_index(player_color_index)
		return
	
	# Otherwise fall back to the player array lookup
	if token_mesh and owner_id != -1 and game and game.initial_player_order.size() > 0:
		# Find the player's index in the players array
		var player_index = -1
		print("initial player order: ", game.initial_player_order)
		for i in range(game.initial_player_order.size()):
			if game.initial_player_order[i] == owner_id:
				player_index = i
				break
		
		# Apply material based on player index
		if player_index >= 0:
			player_color_index = player_index  # Save this for future use
			print("player index : ", player_index)
			apply_color_by_index(player_index)
		else:
			print("Owner ID not found in players array: ", owner_id)
	else:
		print("Cannot update material - missing dependencies")

# This is a NEW function that ONLY plays the animation.
# It will be the target of your RPC call.
func play_blight_animation(blighted: bool):
	if blighted:
		animation_player.play("blight")
	else:
		animation_player.play("unblight")

func remove_token():
	# Mark the placement as unoccupied
	if token_placement:
		token_placement.set_occupied(false)
		token_placement.current_token = null
		token_placement.set_highlight(false)
	# Remove the token itself
	queue_free()

func _on_input_event(_camera, event, _position, _normal, _shape_idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		emit_signal("token_clicked", self)

func highlight(enabled: bool):
	is_highlighted = enabled
	# We're not changing colors anymore, so this function is just tracking state

func set_pattern_highlight(enabled: bool, patterns: Array):
	pattern_highlights = patterns
	# We're not changing colors anymore, so this function is just tracking state
