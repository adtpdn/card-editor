"""
CardCollection3D
==========================

This module handles manages a collection of Card3D nodes.

Usage:
	- add card collection 3D instance to scene
	- update card layout behavior if desired (line, fan, pile)
	- update collision shape if desired
	- add Card3D nodes by calling the add or insert method
	- extend CardCollection3D in your own script and override drag behavior methods to alter 
		behaviour with your own game logic (can_select_card, can_insert_card, can_reorder_card, can_remove_card)
"""
class_name CardCollection3D
extends Node3D


signal mouse_enter_drop_zone()
signal mouse_exit_drop_zone()
signal card_selected(card)
signal card_clicked(card)
signal card_added(card)

enum PileType { ACTION, ELEMENTAL }
# VAR for card Placement
# ----------------------
@export var accepted_card_types : CardResource.CardType
@export var max_cards: int = 1 # limit card that stacked
@export var collection_name: String = "CardCollection"
# ----------------------

@onready var dropzone_collision: CollisionShape3D = $DropZone/CollisionShape3D

@export var card_slot_biome = -1
@export var highlight_on_hover: bool = true
@export var card_move_tween_duration: float = .25
@export var card_swap_tween_duration: float = .25
@export var card_layout_strategy: CardLayout = FanCardLayout.new():
	set(strategy):
		card_layout_strategy = strategy
		apply_card_layout()
@export var dropzone_collision_shape: Shape3D = _default_collision_shape(): 
	set(v):
		if v != null:
			$DropZone/CollisionShape3D.shape = v
@export var dropzone_z_offset: float = 1.6:
	set(offset):
		$DropZone.position.z = offset

@onready var place_mesh = $PlaceMesh

# Default VAR
# ----------------------
var cards: Array[Card3D] = []
var card_indicies = {}
# ----------------------
var hover_disabled: bool = false # disable card hover animation (useful when dragging other cards around)
var _hovered_card: Card3D # card currently hovered
var _preview_drop_index: int = -1
# ----------------------
var card_index
# ----------------------

func _ready():
	if self.name == "Hand":
		place_mesh.hide()

# add a card to the hand and animate it to the correct position
# this will add card as child of this node
func append_card(card: Card3D):
	insert_card(card, cards.size())


func prepend_card(card: Card3D):
	insert_card(card, 0)

func insert_card(card: Card3D, index: int):
	# Check if this is a card being added to a hand and we're at max capacity
	var game = get_node("/root/Game/")
	var turn_phase_manager = game.turn_phase_manager

	if self.name == "Hand":
		if game and game.card_manager and game.card_manager.is_hand_full():
			print("Cannot insert card - hand is full!")
			return
	
	card.card_3d_mouse_down.connect(_on_card_pressed.bind(card))
	card.card_3d_mouse_up.connect(_on_card_clicked.bind(card))
	card.card_3d_mouse_over.connect(_on_card_hover.bind(card))
	card.card_3d_mouse_exit.connect(_on_card_exit.bind(card))
	
	card.card_on_biome = card_slot_biome
	cards.append(card)
	add_child(card)
	card.card_parent = card.get_parent().name
	print('card parent : ', card.card_parent)
	#print("node name : ", self.name)
	
	# Actions Plant Restriction
	if card.card_parent == "Pile" and card.card_type == CardResource.CardType.ACTION:
		card.scale = Vector3(0.7, 0.7, 0.7)
		plant_card(card)
		hide_last_card()
		
	elif card.card_parent.begins_with("elemental_slice_") and card.card_type == CardResource.CardType.ELEMENTAL:
		card.position = place_mesh.position
		card.rotation_degrees.z = card.get_parent().rotation_degrees.z
		print("rotation degress : ",place_mesh.rotation_degrees )
		print("card rotation degress : ", card.rotation_degrees)
		plant_elemental_card(card)
		
	for i in range(index, cards.size()):
		card_indicies[cards[i]] = i
	
	apply_card_layout()
	card_added.emit(card)

func hide_last_card() -> void :
	var pile = get_parent()
	print("pile : ", pile )
	var cards = cards
	
	for id in cards.size():
		if id != cards.size() - 1:
			cards[id].hide()

func plant_elemental_card(card):
	var game = get_node("/root/Game/")
	var turn_phase_manager = game.turn_phase_manager
	var card_manager = game.card_manager
	var soil_star_actions = game.soil_star_actions
	
	# The rest of the function remains the same
	var resource_card_id = card.card_id
	var resource_card_name = card.card_name
	
	print("Planting card with resource card_id:", resource_card_id, "to biome slot:", card_slot_biome)
	
	if game.network_manager and game.network_manager.multiplayer and game.network_manager.multiplayer.get_peers().size() > 0:
		var player_id = game.network_manager.multiplayer.get_unique_id()
		game.network_manager.sync_card_planted(resource_card_id, card_slot_biome, player_id, resource_card_name)
	
	execute_elemental_effect(card.card_id)

func plant_card(card):
	print("plant card")
	var game = get_node("/root/Game/")
	var turn_phase_manager = game.turn_phase_manager
	var card_manager = game.card_manager
	var soil_star_actions = game.soil_star_actions # Get soil star actions reference
	
	card_manager.active_card = card

	# Check if this card play is from the soil star action
	if soil_star_actions.is_playing_from_soil_star_action:
		# It is, so don't count it as the turn's main card play.
		# Reset the flag immediately.
		soil_star_actions.is_playing_from_soil_star_action = false
		
		# Now, find the active player's soil star node and decrease the stars.
		var active_player_ui = soil_star_actions._get_active_player_ui()
		if active_player_ui:
			var soil_star_node = active_player_ui.get_node_or_null("SoilStar")
			if soil_star_node:
				# This action costs 1 soil star.
				var cost = soil_star_actions.button_rules[soil_star_actions.play_card_button]
				soil_star_node.decrease_soil_star(cost)
	else:
		# This is a normal card play during Phase 2.
		turn_phase_manager.card_played = true

	# The rest of the function remains the same
	var resource_card_id = card.card_id
	var resource_card_name = card.card_name
	
	print("Planting card with resource card_id:", resource_card_id, "to biome slot:", card_slot_biome)
	
	if game.network_manager and game.network_manager.multiplayer and game.network_manager.multiplayer.get_peers().size() > 0:
		var player_id = game.network_manager.multiplayer.get_unique_id()
		game.network_manager.sync_card_planted(resource_card_id, card_slot_biome, player_id, resource_card_name)
	
	execute_card_effect(resource_card_id)

func execute_elemental_effect(card_int: int):
	print("elemental effect execute")

func execute_card_effect(card_id: int):
	var game = get_node("/root/Game/")
	var card_manager = game.card_manager
	
	print("Executing effect for resource card_id:", card_id)
	
	match card_id:
		0: # Unblight Our Own Token
			card_manager.unblight_card_effect()
		1: # Take Off enemy or our energy token
			card_manager.take_off_card_effect()
		2: # Swap Energy
			card_manager.swap_energy_card_effect()
		3: # Refresh Energy
			card_manager.refresh_energy_card_effect()
		4: # Plant Extra Token or Energy
			card_manager.plant_extra_card_effect()
		_:
			print("Unknown resource card_id:", card_id)

# remove and return card from the end of the list
func pop_card() -> Card3D:
	return remove_card(cards.size() - 1)
	

# remove and return card from the beggining of the list
func shift_card() -> Card3D:
	return remove_card(0)


# remove card from this hand and return it.
# the caller is responsible for adding card elsewhere
# and/or calling queue_free on it
func remove_card(index: int) -> Card3D:
	var removed_card = cards[index]
	cards.remove_at(index)
	card_indicies.erase(removed_card)
	
	for i in range(index, cards.size()):
		card_indicies[cards[i]] = i
	
	remove_child(removed_card)
	apply_card_layout()
	
	removed_card.card_3d_mouse_down.disconnect(_on_card_pressed.bind(removed_card))
	removed_card.card_3d_mouse_up.disconnect(_on_card_clicked.bind(removed_card))
	removed_card.card_3d_mouse_over.disconnect(_on_card_hover.bind(removed_card))
	removed_card.card_3d_mouse_exit.disconnect(_on_card_exit.bind(removed_card))

	return removed_card


# remove and return all cards
func remove_all() -> Array[Card3D]:
	var cards_to_return = cards
	cards = []
	card_indicies = {}
	
	for c in cards_to_return:
		remove_child(c)
	
	return cards_to_return


func apply_card_layout():
	print("apply card ")
	#print("cards : ", cards.position)
	card_layout_strategy.update_card_positions(cards, card_move_tween_duration)


func preview_card_remove(dragging_card: Card3D):
	if card_indicies.has(dragging_card):
		var preview_cards: Array[Card3D] = []
		var card_index = card_indicies[dragging_card]
		preview_cards += cards.slice(0, card_index)
		preview_cards += cards.slice(card_index + 1, cards.size())
		
		card_layout_strategy.update_card_positions(preview_cards, card_swap_tween_duration)


func preview_card_drop(dragging_card: Card3D, index: int):
	if index == _preview_drop_index:
		return
	
	_preview_drop_index = index
	var preview_cards: Array[Card3D] = []
	
	if card_indicies.has(dragging_card):
		# dragging card in the current collection
		index = clamp(index, 0, cards.size() - 1)
		var current_index = card_indicies[dragging_card]
		preview_cards += cards.slice(0, current_index)
		preview_cards += cards.slice(current_index + 1, cards.size())
		preview_cards.insert(index, null)
	else:
		# dragging new card in from another collection
		preview_cards += cards.slice(0, index)
		preview_cards.append(null)
		preview_cards += cards.slice(index, cards.size())
	
	card_layout_strategy.update_card_positions(preview_cards, card_swap_tween_duration)


func enable_drop_zone():
	_preview_drop_index = -1
	dropzone_collision.disabled = false


func disable_drop_zone():
	_preview_drop_index = -1
	dropzone_collision.disabled = true

"""
Returns the index at which a card should be inserted based on a projection along the layout direction.
- global_direction: The normalized direction vector in global space.
- distance_along_layout: The projected distance along the layout direction.
"""
func get_closest_card_index_along_vector(global_direction: Vector3, distance_along_layout: float) -> int:
	var index := cards.size()
	for i in range(cards.size()):
		var card_position_local := card_layout_strategy.calculate_card_position_by_index(cards.size(), i)
		var card_position_global := self.to_global(card_position_local)
		var card_projection := card_position_global.dot(global_direction)
		if distance_along_layout < card_projection:
			index = i
			break
	return index


# when a mouse enters card collision
# set hover state, if applicable
func _on_card_hover(card: Card3D):
	if not hover_disabled and can_select_card(card):
		_hovered_card = card
		
		for _id in cards.size():
			if card.card_id == cards[_id].card_id:
				card_index = _id
		
		if highlight_on_hover:
			card.set_hovered()


func _on_card_exit(card: Card3D):
	if not hover_disabled and _hovered_card == card:
		card.remove_hovered()
		_hovered_card = null


func _on_card_pressed(card: Card3D):
	var game = get_node("/root/Game")
	var turn_phase_manager = game.turn_phase_manager
	var notification = game.notification
	var soil_star_actions = game.soil_star_actions # Get soil star actions reference

	var parent = card.get_parent()
	
	if parent.name != "Hand" :
		return
	
	# Allow playing a card if it's the right phase OR if using the soil star action
	var can_play_normally = turn_phase_manager.current_phase == 1 and not turn_phase_manager.card_played
	var can_play_from_soil_star = soil_star_actions.is_playing_from_soil_star_action

	if can_play_normally or can_play_from_soil_star:
		if can_select_card(card):
			notification.show_instruction_label("Play a Card")
			card_selected.emit(card)
			
		

func _on_card_clicked(card: Card3D):
	#print("carc clicked")
	card_clicked.emit(card)


func _on_drop_zone_mouse_entered():
	mouse_enter_drop_zone.emit()


func _on_drop_zone_mouse_exited():
	_preview_drop_index = -1
	mouse_exit_drop_zone.emit()
	

func _default_collision_shape() -> Shape3D:
	var shape = ConvexPolygonShape3D.new()
	shape.points = PackedVector3Array(
		[
			Vector3(-7,2,0),
			Vector3(-7,-2,0),
			Vector3(7,-2,0),
			Vector3(7,2,0)
		]
	)
	return shape


# whether or not a card can be selected
func can_select_card(_card) -> bool:
	return true


func can_remove_card(_card) -> bool:
	return true


func can_reorder_card(_card) -> bool:
	return true

func can_insert_card(card, _from_collection) -> bool:
	# This function is used by the DragController to validate drops.
	match accepted_card_types:
		PileType.ACTION:
			return card.card_type == CardResource.CardType.ACTION
		PileType.ELEMENTAL:
			return card.card_type == CardResource.CardType.ELEMENTAL
	return false # Default to false if something goes wrong.
