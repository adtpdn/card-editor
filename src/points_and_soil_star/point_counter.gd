# point_counter.gd
extends Node3D

# Emitted when any player's score changes. Connect your player score UI to this.
signal player_points_changed(player_id, new_total)

# Emitted when a biome's magic points change. Connect your biome points UI to this.
signal biome_points_changed(biome_type, new_total)

# Define an enum for the different biomes. This makes the code cleaner and less prone to typos.
enum Biome {
	FOREST,
	WATER,
	MOUNTAIN,
	DESERT
}

var biome_points: Dictionary = {
	Biome.FOREST: 0,
	Biome.WATER: 0,
	Biome.MOUNTAIN: 0,
	Biome.DESERT: 0
}

# Stores points for each player { player_id: points }
var player_points: Dictionary = {}

const TOTAL_POINTS = 10  # Max points per biome

# Regular biome points
var forest_points = 0
var desert_points = 0
var mountain_points = 0
var water_points = 0

# Magic biome points
var forest_magic_points = 3
var desert_magic_points = 3
var mountain_magic_points = 3
var water_magic_points = 3

const BLOCK_HEIGHT = 0.2
const BLOCK_SPACING = 0.01
const STACK_SPACING = 0.01

var block_scene = preload("res://scenes/points_and_soil_star/point_block.tscn")

@onready var game = get_node("/root/Game")

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

var current_turn_player_id: int = 1
var last_button_press_time = 0.0
const BUTTON_PRESS_COOLDOWN = 0.25

func _ready():
	update_all_stacks()

#================================#
#         MAGIC on SIGIL         #
#================================#

@rpc("any_peer", "call_local")
func request_add_magic_points(biome: Biome):
	# The is_multiplayer_authority() check is now redundant because of the decorator,
	# but it's good practice to keep for clarity.
	if not is_multiplayer_authority():
		return

	print("request add magic points")
	add_magic_points_from_biome(biome)

	# After updating the points on the server, we sync the new values with all clients.
	sync_point_values.rpc(
		forest_points, desert_points, mountain_points, water_points,
		forest_magic_points, desert_magic_points, mountain_magic_points, water_magic_points
	)

func add_magic_points_from_biome(biome: Biome):
	match biome:
		Biome.FOREST:
			# Add 2 to the existing forest magic points.
			var new_points = forest_magic_points + 2
			forest_magic_points = validate_points(new_points)
		Biome.DESERT:
			var new_points = desert_magic_points + 2
			print("desert points : ", new_points)
			desert_magic_points = validate_points(new_points)
		Biome.MOUNTAIN:
			var new_points = mountain_magic_points + 2
			mountain_magic_points = validate_points(new_points)
		Biome.WATER:
			var new_points = water_magic_points + 2
			water_magic_points = validate_points(new_points)
	
	# We call update_all_stacks() here on the server so its view is immediately correct.
	# Clients will update when they receive the sync_point_values RPC.
	update_all_stacks()

#================================#
#         PLAYER POINTS          #
#================================#

func add_player_points(player_id: int, amount: int):
	# This check ensures only the server runs this logic.
	if not multiplayer.is_server(): return

	# The .get(player_id, 0) part safely handles cases where the player_id is not yet
	# in the dictionary (i.e., when the player_points dictionary is empty for that player).
	var current_points = player_points.get(player_id, 0)
	var new_total = current_points + amount
	
	# After calculating, sync the authoritative result to all players.
	sync_player_points.rpc(player_id, new_total)

@rpc("any_peer")
func request_add_player_points(player_id: int, amount: int):
	if not is_multiplayer_authority():
		return

	add_player_points(player_id, amount)
	
	#sync_player_points.rpc(player_id, amount)

## Syncs the updated player score to all players and updates the UI Label.
@rpc("any_peer", "call_local")
func sync_player_points(player_id: int, new_total: int):
	# 1. Update the data dictionary
	player_points[player_id] = new_total
	print("SYNC: Player %d now has %d points." % [player_id, new_total])
	player_points_changed.emit(player_id, new_total)

	# 2. Update the corresponding UI Label
	update_player_score_label(player_id, new_total)

## Finds and updates the score label for a specific player.
func update_player_score_label(player_id: int, new_total: int):
	# Find the root node for all player UIs.
	var player_uis_node = get_node_or_null("/root/Game/PlayerUIs")
	if not player_uis_node:
		print("UI update failed: '/root/Game/PlayerUIs' node not found.")
		return

	# Construct the correct node name based on your screenshot's naming convention.
	var node_name = "Player_%d_UI" % player_id
	var player_ui_root = player_uis_node.get_node_or_null(node_name)
	
	if not player_ui_root:
		return

	# Find the 'Points' Control node inside the player's UI.
	var points_control = player_ui_root.get_node_or_null("Points")
	if not points_control:
		print("UI update failed: 'Points' node not found in %s." % player_ui_root.name)
		return

	# Find the Label to update within the 'Points' control node.
	var points_label: Label
	for child in points_control.get_children():
		if child is Label:
			points_label = child
			break
		elif child.get_child_count() > 0:
			for grandchild in child.get_children():
				if grandchild is Label:
					points_label = grandchild
					break
		if points_label:
			break
	
	# Finally, update the label's text if it was found.
	if points_label:
		points_control.increase_point(new_total)
		points_label.text = str(new_total)
	else:
		print("UI update failed: No Label child found in %s." % points_control.name)

#================================#
#          BIOME POINTS          #
#================================#

func add_biome_points(biome_type: int, amount: int):
	if not multiplayer.is_server(): return
	
	add_points_to_biome(biome_type, amount)
	
	# Sync the authoritative result to all players.
	sync_point_values.rpc(
		forest_points, desert_points, mountain_points, water_points,
		forest_magic_points, desert_magic_points, mountain_magic_points, water_magic_points
	)

@rpc("any_peer", "call_local")
func request_add_biome_points(biome_type: int, amount: int):
	if not is_multiplayer_authority():
		return
	
	add_biome_points(biome_type, amount)


func add_points_to_biome(biome: Biome, amount: int):
	match biome:
		Biome.FOREST:
			# Add 2 to the existing forest magic points.
			var new_points = forest_points + amount
			forest_points = validate_points(new_points)
			biome_points[Biome.FOREST] = forest_points
		Biome.DESERT:
			var new_points = desert_points + amount
			desert_points = validate_points(new_points)
			biome_points[Biome.DESERT] = desert_points
		Biome.MOUNTAIN:
			var new_points = mountain_points + amount
			mountain_points = validate_points(new_points)
			biome_points[Biome.MOUNTAIN] = mountain_points
		Biome.WATER:
			var new_points = water_points + amount
			water_points = validate_points(new_points)
			biome_points[Biome.WATER] = water_points


#================================#
#        HELPER FUNCTION         #
#================================#

## ELEMENTAL BLUE FUNCTION ( card_id = 8 )
func server_set_mana_for_biome(biome: Biome, amount: int):
	print("server set mana for biome")
	if not is_multiplayer_authority():
		return

	var validated_amount = validate_points(amount) # Ensure amount is within 0-10
	
	match biome:
		Biome.FOREST:
			forest_magic_points = validated_amount
		Biome.DESERT:
			desert_magic_points = validated_amount
		Biome.MOUNTAIN:
			mountain_magic_points = validated_amount
		Biome.WATER:
			water_magic_points = validated_amount

	# After updating the points on the server, sync the new values with all clients.
	sync_point_values.rpc(
		forest_points, desert_points, mountain_points, water_points,
		forest_magic_points, desert_magic_points, mountain_magic_points, water_magic_points
	)

func create_block(biome: String) -> Node3D:
	var block = block_scene.instantiate()
	block.biome_type = biome
	return block

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
		if stack_node.name.contains("Magic"):
			block.position.y = i * (BLOCK_HEIGHT + BLOCK_SPACING)
			block.rotation_degrees.z = 180.0
		else:
			block.position.y = i * (BLOCK_HEIGHT + BLOCK_SPACING) + 0.2
			block.rotation_degrees.y = 45.0
			

# This RPC is now called by the server to broadcast the state to all clients.
# We change it to 'any_peer' so the server can call it on clients.
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
	update_biome_points()
	update_all_stacks()

func update_biome_points():
	biome_points[Biome.FOREST] = forest_points
	biome_points[Biome.DESERT] = desert_points
	biome_points[Biome.WATER] = water_points
	biome_points[Biome.MOUNTAIN] = mountain_points

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
	# This function should generally only be called on the server.
	if not is_multiplayer_authority(): return
	
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
