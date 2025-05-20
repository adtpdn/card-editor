extends Node3D

enum BiomeType {FOREST, WATER, MOUNTAIN, DESERT}

var biome_type: BiomeType
@onready var token_mesh: MeshInstance3D = $TokenMesh
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var game = get_node("/root/Game")

var owner_id: int = -1
var token_type: int = 0  # Added to match the syncing code in token_manager.gd

var token_placement = null
var is_energy: bool = false
var is_blighted: bool = false

signal token_clicked(token)

var is_highlighted = false
var pattern_highlights = []

func _ready():
	# Make sure the token is clickable
	var static_body = $TokenMesh/StaticBody3D
	if static_body:
		var input_listener = static_body
		input_listener.input_event.connect(_on_input_event)

func set_token_data(biome, owner, is_energy_token=false):
	biome_type = biome
	owner_id = owner
	is_energy = is_energy_token  # Set energy status
	# No need to call update_token_display() since we're not changing colors

func set_blighted(blighted: bool):
	if is_blighted != blighted:
		is_blighted = blighted
		
		# Play the appropriate animation
		if is_blighted:
			animation_player.play("blight")
		else:
			animation_player.play("unblight")
			
		# Sync the animation to all clients
		if game && game.multiplayer.is_server():
			game.rpc("sync_token_blight", global_position, is_blighted)

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
