# planting_location.gd
extends Node3D

@export var location_name: String = "Default Location"
@export var accepted_card_types: PackedInt32Array = PackedInt32Array()

var slots = []
var planted_cards = {}
var selected_marker = null
const CARD_THICKNESS = 0.01
const STACK_SPACING = 0.001
signal card_placed(card: CardResource, slot_index: int, location_name: String)

var Card3DScene = preload("res://card_3d.tscn")

func _ready():
	# Get all markers from the Markers node
	slots = $Markers.get_children()
	for slot in slots:
		planted_cards[slot.name] = []
		# Connect area signals
		var area = slot.get_node("Area3D")
		area.mouse_entered.connect(_on_marker_mouse_entered.bind(slot))
		area.mouse_exited.connect(_on_marker_mouse_exited.bind(slot))
		# Set initial material
		var mesh = slot.get_node("MeshInstance3D")
		mesh.material_override = create_marker_material(false)

func can_accept_card(card: CardResource) -> bool:
	return accepted_card_types.is_empty() or accepted_card_types.has(card.card_type)

func _on_marker_mouse_entered(marker: Marker3D):
	var mesh = marker.get_node("MeshInstance3D")
	mesh.material_override = create_marker_material(true)
	selected_marker = marker

func _on_marker_mouse_exited(marker: Marker3D):
	var mesh = marker.get_node("MeshInstance3D")
	mesh.material_override = create_marker_material(false)
	if selected_marker == marker:
		selected_marker = null

func create_marker_material(highlighted: bool) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	if highlighted:
		# Different colors for different zones
		var highlight_color = Color(0.2, 1.0, 0.2, 0.5)  # Green for action
		if CardResource.CardType.AREA in accepted_card_types:
			highlight_color = Color(0.2, 0.2, 1.0, 0.5)  # Blue for area
		material.albedo_color = highlight_color
	else:
		material.albedo_color = Color(1.0, 1.0, 1.0, 0.2)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material

func _input(event):
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if selected_marker:
				var game = get_node("/root/Game")
				var hand = game.get_node("HandAreas/PlayerHand")
				# Check if it's player's turn before allowing placement
				if hand and game.is_valid_player_turn(multiplayer.get_unique_id()):
					var selected_card = hand.get_selected_card()
					if selected_card and can_accept_card(selected_card.card_resource):
						var index = slots.find(selected_marker)
						if index != -1:
							print("Attempting to place card in ", location_name, " at index ", index)
							card_placed.emit(selected_card.card_resource, index, location_name)
							hand.remove_card(selected_card)

func plant_card(card_resource: CardResource, slot_index: int) -> void:
	var game = get_node("/root/Game")
	if !game or slot_index < 0 or slot_index >= slots.size():
		print("Invalid slot index: ", slot_index)
		return
		
	var slot = slots[slot_index]
	print("Planting card in slot: ", slot.name, " at location: ", location_name)
	
	var card_instance = Card3DScene.instantiate()
	add_child(card_instance)
	card_instance.set_card_data(card_resource)
	
	var stack_height = planted_cards[slot.name].size() * (CARD_THICKNESS + STACK_SPACING)
	var position = slot.global_position
	position.y += stack_height
	
	card_instance.global_position = position
	planted_cards[slot.name].append(card_instance)
	
	card_instance.rotation.x = -PI/2
	card_instance.rotation.y = slot.rotation.y
	
	update_stack_visuals(slot)

@rpc("any_peer")
func request_plant_card(card_data: Dictionary, slot_index: int, location_name: String):
	if multiplayer.is_server():
		var game = get_node("/root/Game")
		var requesting_player = multiplayer.get_remote_sender_id()
		
		# Validate it's the player's turn
		if game.is_valid_player_turn(requesting_player):
			rpc("sync_plant_card", card_data, slot_index)

@rpc("any_peer", "call_local")
func sync_plant_card(card_data: Dictionary, slot_index: int):
	if slot_index < 0 or slot_index >= slots.size():
		return
		
	var card_resource = CardResource.new()
	card_resource.from_dictionary(card_data)
	
	var slot = slots[slot_index]
	var card_instance = Card3DScene.instantiate()
	add_child(card_instance)
	
	# Set card data
	card_instance.set_card_data(card_resource)
	
	# Calculate stack position
	var stack_height = planted_cards[slot.name].size() * (CARD_THICKNESS + STACK_SPACING)
	var position = slot.global_position
	position.y += stack_height
	
	# Set card position and add to stack
	card_instance.global_position = position
	planted_cards[slot.name].append(card_instance)
	
	# Make sure the card is facing up
	card_instance.rotation.x = -PI/2  # Changed from rotation_x to rotation.x
	
	# Update card visual state
	update_stack_visuals(slot)

func update_stack_visuals(slot: Marker3D) -> void:
	var cards = planted_cards[slot.name]
	for i in range(cards.size()):
		var card = cards[i]
		var new_pos = slot.global_position
		new_pos.y += i * (CARD_THICKNESS + STACK_SPACING)
		
		var tween = create_tween()
		tween.tween_property(card, "global_position", new_pos, 0.2)

func view_card(card: Card) -> void:
	if not card:
		return
	
	if multiplayer.is_server():
		rpc("sync_view_card", global_position)
	else:
		rpc_id(1, "request_view_card", global_position)
		
	# Move camera to view position
	var tween = create_tween()
	var target_pos = global_position + Vector3(0, 1.5, -2.0)
	tween.tween_property(get_node("/root/Game/Camera3D"), "global_position", target_pos, 0.5)
	
	# Make camera look at planting area
	get_node("/root/Game/Camera3D").look_at(global_position)

func reset_camera() -> void:
	if multiplayer.is_server():
		rpc("sync_reset_camera")
	else:
		rpc_id(1, "request_reset_camera")

@rpc("any_peer")
func request_reset_camera():
	if multiplayer.is_server():
		rpc("sync_reset_camera")

@rpc("any_peer", "call_local")
func sync_reset_camera():
	var camera = get_node("/root/Game/Camera3D")
	var tween = create_tween()
	tween.tween_property(camera, "global_position", Vector3(0, 3.361, 1.877), 0.5)
	tween.parallel().tween_property(camera, "rotation", Vector3(-1.1, 0, 0), 0.5)
