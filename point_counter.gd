# point_counter.gd
extends Node3D

const TOTAL_POINTS = 10  # Max points per biome

# Regular biome points
var forest_points = 0
var desert_points = 0
var mountain_points = 0
var water_points = 0

# Magic biome points
var forest_magic_points = 0
var desert_magic_points = 0
var mountain_magic_points = 0
var water_magic_points = 0

const BLOCK_HEIGHT = 0.2
const BLOCK_SPACING = 0.05
const STACK_SPACING = 2.0

var block_scene = preload("res://point_block.tscn")

# Regular stacks
@onready var forest_stack = $ForestStack
@onready var desert_stack = $DesertStack
@onready var mountain_stack = $MountainStack
@onready var water_stack = $WaterStack

# Magic stacks
@onready var forest_magic_stack = $ForestMagicStack
@onready var desert_magic_stack = $DesertMagicStack
@onready var mountain_magic_stack = $MountainMagicStack
@onready var water_magic_stack = $WaterMagicStack

# Regular biome buttons
@onready var btn_forest_plus = $"../LeftUI/VBoxContainer/ForestButtons/PlusButton"
@onready var btn_forest_min = $"../LeftUI/VBoxContainer/ForestButtons/MinusButton"
@onready var btn_desert_plus = $"../LeftUI/VBoxContainer/DesertButtons/PlusButton"
@onready var btn_desert_min = $"../LeftUI/VBoxContainer/DesertButtons/MinusButton"
@onready var btn_mountain_plus = $"../LeftUI/VBoxContainer/MountainButtons/PlusButton"
@onready var btn_mountain_min = $"../LeftUI/VBoxContainer/MountainButtons/MinusButton"
@onready var btn_water_plus = $"../LeftUI/VBoxContainer/WaterButtons/PlusButton"
@onready var btn_water_min = $"../LeftUI/VBoxContainer/WaterButtons/MinusButton"

# Magic biome buttons
@onready var btn_forest_magic_plus = $"../LeftUI/VBoxContainer/ForestMagicButtons/PlusButton"
@onready var btn_forest_magic_min = $"../LeftUI/VBoxContainer/ForestMagicButtons/MinusButton"
@onready var btn_desert_magic_plus = $"../LeftUI/VBoxContainer/DesertMagicButtons/PlusButton"
@onready var btn_desert_magic_min = $"../LeftUI/VBoxContainer/DesertMagicButtons/MinusButton"
@onready var btn_mountain_magic_plus = $"../LeftUI/VBoxContainer/MountainMagicButtons/PlusButton"
@onready var btn_mountain_magic_min = $"../LeftUI/VBoxContainer/MountainMagicButtons/MinusButton"
@onready var btn_water_magic_plus = $"../LeftUI/VBoxContainer/WaterMagicButtons/PlusButton"
@onready var btn_water_magic_min = $"../LeftUI/VBoxContainer/WaterMagicButtons/MinusButton"

var current_turn_player_id: int = 1
var last_button_press_time = 0.0
const BUTTON_PRESS_COOLDOWN = 0.25

@export var sync_id := 1:
	set(id):
		sync_id = id
		set_multiplayer_authority(1)

func _ready():
	connect_signals()
	set_multiplayer_authority(1)
	
	# Initialize magic points to 1 if this is the server
	if multiplayer.is_server() or multiplayer.get_unique_id() == 1:
		var point_count = 3
		forest_magic_points = point_count
		desert_magic_points = point_count
		mountain_magic_points = point_count
		water_magic_points = point_count
		
		# Sync to all clients
		rpc("sync_point_values", 
			forest_points,
			desert_points,
			mountain_points,
			water_points,
			forest_magic_points,
			desert_magic_points,
			mountain_magic_points,
			water_magic_points
		)
	
	create_stack_labels()
	update_all_stacks()

func connect_signals():
	var buttons = [
		[btn_forest_plus, btn_forest_min],
		[btn_desert_plus, btn_desert_min],
		[btn_mountain_plus, btn_mountain_min],
		[btn_water_plus, btn_water_min],
		[btn_forest_magic_plus, btn_forest_magic_min],
		[btn_desert_magic_plus, btn_desert_magic_min],
		[btn_mountain_magic_plus, btn_mountain_magic_min],
		[btn_water_magic_plus, btn_desert_magic_min]
	]
	
	# Disconnect existing connections
	for button_pair in buttons:
		for button in button_pair:
			if button.pressed.is_connected(on_button_pressed):
				button.pressed.disconnect(on_button_pressed)
	
	# Connect new signals
	btn_forest_plus.pressed.connect(func(): on_button_pressed("forest", 1))
	btn_forest_min.pressed.connect(func(): on_button_pressed("forest", -1))
	btn_desert_plus.pressed.connect(func(): on_button_pressed("desert", 1))
	btn_desert_min.pressed.connect(func(): on_button_pressed("desert", -1))
	btn_mountain_plus.pressed.connect(func(): on_button_pressed("mountain", 1))
	btn_mountain_min.pressed.connect(func(): on_button_pressed("mountain", -1))
	btn_water_plus.pressed.connect(func(): on_button_pressed("water", 1))
	btn_water_min.pressed.connect(func(): on_button_pressed("water", -1))
	
	# Magic biome buttons
	btn_forest_magic_plus.pressed.connect(func(): on_button_pressed("forest_magic", 1))
	btn_forest_magic_min.pressed.connect(func(): on_button_pressed("forest_magic", -1))
	btn_desert_magic_plus.pressed.connect(func(): on_button_pressed("desert_magic", 1))
	btn_desert_magic_min.pressed.connect(func(): on_button_pressed("desert_magic", -1))
	btn_mountain_magic_plus.pressed.connect(func(): on_button_pressed("mountain_magic", 1))
	btn_mountain_magic_min.pressed.connect(func(): on_button_pressed("mountain_magic", -1))
	btn_water_magic_plus.pressed.connect(func(): on_button_pressed("water_magic", 1))
	btn_water_magic_min.pressed.connect(func(): on_button_pressed("water_magic", -1))

func on_button_pressed(biome: String, delta: int):
	# Implement cooldown to prevent rapid button presses
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_button_press_time < BUTTON_PRESS_COOLDOWN:
		return
		
	last_button_press_time = current_time
	
	var game_node = get_parent()
	if game_node and game_node.has_method("request_point_adjustment"):
		game_node.request_point_adjustment(biome, delta)

func create_block(biome: String) -> Node3D:
	var block = block_scene.instantiate()
	block.biome_type = biome
	return block

func create_stack_labels():
	var stacks = {
		"Forest": forest_stack,
		"Desert": desert_stack,
		"Mountain": mountain_stack,
		"Water": water_stack
	}
	
	for stack_name in stacks:
		var label = Label3D.new()
		stacks[stack_name].add_child(label)
		label.text = stack_name
		label.position = Vector3(-1, -0.5, 0)
		label.pixel_size = 0.01
		label.modulate = Color(1, 1, 1)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED

func update_all_stacks():
	clear_stacks()
	# Update regular stacks
	update_stack(forest_stack, forest_points, "forest")
	update_stack(desert_stack, desert_points, "desert")
	update_stack(mountain_stack, mountain_points, "mountain")
	update_stack(water_stack, water_points, "water")
	
	# Update magic stacks
	update_stack(forest_magic_stack, forest_magic_points, "forest_magic")
	update_stack(desert_magic_stack, desert_magic_points, "desert_magic")
	update_stack(mountain_magic_stack, mountain_magic_points, "mountain_magic")
	update_stack(water_magic_stack, water_magic_points, "water_magic")

func clear_stacks():
	var all_stacks = [
		forest_stack, desert_stack, mountain_stack, water_stack,
		forest_magic_stack, desert_magic_stack, mountain_magic_stack, water_magic_stack
	]
	for stack in all_stacks:
		for child in stack.get_children():
			if not (child is Label3D):
				child.queue_free()

func update_stack(stack_node: Node3D, points: int, biome: String):
	for i in range(points):
		var block = create_block(biome)
		stack_node.add_child(block)
		block.position.y = i * (BLOCK_HEIGHT + BLOCK_SPACING)

@rpc("any_peer", "call_local")
func sync_point_values(f: int, d: int, m: int, w: int, fm: int, dm: int, mm: int, wm: int):
	forest_points = f
	desert_points = d
	mountain_points = m
	water_points = w
	forest_magic_points = fm
	desert_magic_points = dm
	mountain_magic_points = mm
	water_magic_points = wm
	update_all_stacks()

func get_points(biome: String) -> int:
	match biome:
		"forest": return forest_points
		"desert": return desert_points
		"mountain": return mountain_points
		"water": return water_points
		"forest_magic": return forest_magic_points
		"desert_magic": return desert_magic_points
		"mountain_magic": return mountain_magic_points
		"water_magic": return water_magic_points
	return 0

func set_points(biome: String, value: int):
	value = validate_points(value)
	match biome:
		"forest": forest_points = value
		"desert": desert_points = value
		"mountain": mountain_points = value
		"water": water_points = value
		"forest_magic": forest_magic_points = value
		"desert_magic": desert_magic_points = value
		"mountain_magic": mountain_magic_points = value
		"water_magic": water_magic_points = value
	update_all_stacks()

func validate_points(value: int) -> int:
	return clampi(value, 0, TOTAL_POINTS)


func set_buttons_enabled(enabled: bool):
	var buttons = [
		# Regular biome buttons
		btn_forest_plus, btn_forest_min,
		btn_desert_plus, btn_desert_min,
		btn_mountain_plus, btn_mountain_min,
		btn_water_plus, btn_water_min,
		# Magic biome buttons
		btn_forest_magic_plus, btn_forest_magic_min,
		btn_desert_magic_plus, btn_desert_magic_min,
		btn_mountain_magic_plus, btn_mountain_magic_min,
		btn_water_magic_plus, btn_water_magic_min
	]
	
	for button in buttons:
		if is_instance_valid(button):
			button.disabled = !enabled
	
	if enabled:
		connect_signals()
