# point_counter.gd
extends Node3D

const TOTAL_POINTS = 15
const POINTS_PER_REGION = 5

var triangle_points = 5
var square_points = 5
var circle_points = 5

var block_scene = preload("res://point_block.tscn")
const BLOCK_HEIGHT = 0.2
const BLOCK_SPACING = 0.05
const STACK_SPACING = 2.0  # Distance between stacks

@onready var triangle_stack = $TriangleStack
@onready var square_stack = $SquareStack
@onready var circle_stack = $CircleStack

# Add multiplayer variables
var current_turn_player_id: int = 1

@export var sync_id := 1:
	set(id):
		sync_id = id
		# Give authority to the server
		set_multiplayer_authority(1)

@rpc("authority", "call_local")
func sync_point_values(t_points: int, s_points: int, c_points: int):
	#print("Syncing points - Triangle: ", t_points, " Square: ", s_points, " Circle: ", c_points)
	triangle_points = t_points
	square_points = s_points
	circle_points = c_points
	# Force update the visual stacks
	call_deferred("update_all_stacks")

func _ready():
	connect_signals()
	# Set up multiplayer authority
	set_multiplayer_authority(1)
	
	# Position the stacks with equal spacing
	triangle_stack.position = Vector3(-STACK_SPACING, 0, 0)
	square_stack.position = Vector3(0, 0, 0)
	circle_stack.position = Vector3(STACK_SPACING, 0, 0)
	
	# Add labels for each stack
	create_stack_labels()
	
	update_all_stacks()

func connect_signals():
	$UI/VBoxContainer/TriangleButtons/PlusButton.pressed.connect(
		func(): on_button_pressed("triangle", 1))
	$UI/VBoxContainer/TriangleButtons/MinusButton.pressed.connect(
		func(): on_button_pressed("triangle", -1))
	$UI/VBoxContainer/SquareButtons/PlusButton.pressed.connect(
		func(): on_button_pressed("square", 1))
	$UI/VBoxContainer/SquareButtons/MinusButton.pressed.connect(
		func(): on_button_pressed("square", -1))
	$UI/VBoxContainer/RectangleButtons/PlusButton.pressed.connect(
		func(): on_button_pressed("circle", 1))
	$UI/VBoxContainer/RectangleButtons/MinusButton.pressed.connect(
		func(): on_button_pressed("circle", -1))

func on_button_pressed(region: String, delta: int):
	if get_parent().has_method("request_point_adjustment"):
		get_parent().request_point_adjustment(region, delta)

func create_block(type: String) -> Node3D:
	var block = block_scene.instantiate()
	match type:
		"triangle":
			block.block_type = block.BlockType.TRIANGLE
		"square":
			block.block_type = block.BlockType.SQUARE
		"circle":
			block.block_type = block.BlockType.CIRCLE
	return block

func create_stack_labels():
	for stack_data in [
		{"node": triangle_stack, "text": "Triangle"},
		{"node": square_stack, "text": "Square"},
		{"node": circle_stack, "text": "Circle"}
	]:
		var label = Label3D.new()
		stack_data.node.add_child(label)
		label.text = stack_data.text
		label.position = Vector3(0, -0.3, 0)  # Position below the stack
		label.pixel_size = 0.01
		label.modulate = Color(1, 1, 1)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED

func highlight_stack(stack: Node3D, enabled: bool):
	for block in stack.get_children():
		if block is Node3D and block.has_method("set_highlighted"):
			block.set_highlighted(enabled)

func update_all_stacks():
	# Clear existing blocks first
	for child in triangle_stack.get_children():
		if not (child is Label3D):  # Don't remove the label
			child.queue_free()
	for child in square_stack.get_children():
		if not (child is Label3D):
			child.queue_free()
	for child in circle_stack.get_children():
		if not (child is Label3D):
			child.queue_free()
	
	# Create new blocks
	update_stack(triangle_stack, triangle_points, "triangle")
	update_stack(square_stack, square_points, "square")
	update_stack(circle_stack, circle_points, "circle")

func update_stack(stack_node: Node3D, points: int, type: String):
	# Only remove blocks, not labels
	for child in stack_node.get_children():
		if not (child is Label3D):
			child.queue_free()
	
	# Create new blocks
	for i in range(points):
		var block = create_block(type)
		stack_node.add_child(block)
		block.position.y = i * (BLOCK_HEIGHT + BLOCK_SPACING)

func adjust_points(region: String, delta: int):
	if !multiplayer.is_server():
		return
		
	var current_points
	match region:
		"triangle":
			current_points = triangle_points
		"square":
			current_points = square_points
		"circle":
			current_points = circle_points
	
	if delta > 0 and current_points < 10:
		var points_to_remove = delta
		if region != "triangle" and triangle_points > 0:
			triangle_points -= 1
			points_to_remove -= 1
		if points_to_remove > 0 and region != "square" and square_points > 0:
			square_points -= 1
			points_to_remove -= 1
		if points_to_remove > 0 and region != "circle" and circle_points > 0:
			circle_points -= 1
		
		match region:
			"triangle":
				triangle_points += 1
			"square":
				square_points += 1
			"circle":
				circle_points += 1
	
	elif delta < 0 and current_points > 0:
		var points_to_add = -delta
		if region != "triangle":
			triangle_points += 1
			points_to_add -= 1
		if points_to_add > 0 and region != "square":
			square_points += 1
			points_to_add -= 1
		if points_to_add > 0 and region != "circle":
			circle_points += 1
		
		match region:
			"triangle":
				triangle_points -= 1
			"square":
				square_points -= 1
			"circle":
				circle_points -= 1
	
	update_all_stacks()

# Add this function to validate points before setting
func validate_points(value: int) -> int:
	return clampi(value, 0, 10)  # Clamp between 0 and 10

func set_points(region: String, value: int):
	value = validate_points(value)
	match region:
		"triangle":
			triangle_points = value
		"square":
			square_points = value
		"circle":
			circle_points = value
	update_all_stacks()

func get_points(region: String) -> int:
	match region:
		"triangle":
			return triangle_points
		"square":
			return square_points
		"circle":
			return circle_points
	return 0

func set_buttons_enabled(enabled: bool):
	#print("Setting buttons enabled: ", enabled)
	var buttons = [
		$UI/VBoxContainer/TriangleButtons/PlusButton,
		$UI/VBoxContainer/TriangleButtons/MinusButton,
		$UI/VBoxContainer/SquareButtons/PlusButton,
		$UI/VBoxContainer/SquareButtons/MinusButton,
		$UI/VBoxContainer/RectangleButtons/PlusButton,
		$UI/VBoxContainer/RectangleButtons/MinusButton
	]
	
	for button in buttons:
		if is_instance_valid(button):
			button.disabled = !enabled
			#print("Button ", button.name, " disabled: ", !enabled)
