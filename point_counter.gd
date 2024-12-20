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

func _ready():
	
	# Connect Button Signal
	# Triangle
	$UI/VBoxContainer/TriangleButtons/PlusButton.pressed.connect(
		func(): adjust_points("triangle", 1))
	$UI/VBoxContainer/TriangleButtons/MinusButton.pressed.connect(
		func(): adjust_points("triangle", -1))
	# Square
	$UI/VBoxContainer/SquareButtons/PlusButton.pressed.connect(
		func(): adjust_points("square", 1))
	$UI/VBoxContainer/SquareButtons/MinusButton.pressed.connect(
		func(): adjust_points("square", -1))
	# Circle
	$UI/VBoxContainer/RectangleButtons/PlusButton.pressed.connect(
		func(): adjust_points("circle", 1))
	$UI/VBoxContainer/RectangleButtons/MinusButton.pressed.connect(
		func(): adjust_points("circle", -1))
	
	# Position the stacks with equal spacing
	triangle_stack.position = Vector3(-STACK_SPACING, 0, 0)
	square_stack.position = Vector3(0, 0, 0)
	circle_stack.position = Vector3(STACK_SPACING, 0, 0)
	
	# Add labels for each stack
	create_stack_labels()
	
	update_all_stacks()

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
	update_stack(triangle_stack, triangle_points, "triangle")
	update_stack(square_stack, square_points, "square")
	update_stack(circle_stack, circle_points, "circle")

func update_stack(stack_node: Node3D, points: int, type: String):
	# Clear existing blocks
	for child in stack_node.get_children():
		child.queue_free()
	
	# Create new blocks
	for i in range(points):
		var block = create_block(type)
		stack_node.add_child(block)
		block.position.y = i * (BLOCK_HEIGHT + BLOCK_SPACING)

func adjust_points(region: String, delta: int):
	var current_points
	match region:
		"triangle":
			current_points = triangle_points
		"square":
			current_points = square_points
		"circle":
			current_points = circle_points
	
	if delta > 0 and current_points < 10:  # Maximum 10 points per region
		var points_to_remove = delta
		# Remove points from other regions
		if region != "triangle" and triangle_points > 0:
			triangle_points -= 1
			points_to_remove -= 1
		if points_to_remove > 0 and region != "square" and square_points > 0:
			square_points -= 1
			points_to_remove -= 1
		if points_to_remove > 0 and region != "circle" and circle_points > 0:
			circle_points -= 1
		
		# Add point to selected region
		match region:
			"triangle":
				triangle_points += 1
			"square":
				square_points += 1
			"circle":
				circle_points += 1
	
	elif delta < 0 and current_points > 0:  # Minimum 0 points per region
		var points_to_add = -delta
		# Add points to other regions
		if region != "triangle":
			triangle_points += 1
			points_to_add -= 1
		if points_to_add > 0 and region != "square":
			square_points += 1
			points_to_add -= 1
		if points_to_add > 0 and region != "circle":
			circle_points += 1
		
		# Remove point from selected region
		match region:
			"triangle":
				triangle_points -= 1
			"square":
				square_points -= 1
			"circle":
				circle_points -= 1
	
	update_all_stacks()
