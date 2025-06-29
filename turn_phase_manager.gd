# turn_phase_manager.gd
extends Node

enum Phase {
	NONE = -1,
	PLANT_BIOME = 0,
	PLANT_SIGIL_AND_CARD = 1, 
	PLAY_SIGIL = 2,
	END_TURN = 3
}

# References to other managers
@onready var game = get_parent()
@onready var token_manager = $"../TokenManager"
@onready var game_state_manager = $"../GameStateManager"
@onready var card_manager = $"../CardManager"
@onready var ui_manager = $"../UIManager"
@onready var sigil_manager = $"../SigilManager"

@onready var end_phase_button = $"../RightUI/EndPhaseButton"
@onready var token_button = $"../RightUI/TokenButton"


# Phase tracking
var current_phase: Phase = Phase.NONE
var completed_phases = {
	Phase.PLANT_BIOME: false,
	Phase.PLANT_SIGIL_AND_CARD: false,
	Phase.PLAY_SIGIL: false
}

# Sub-phase tracking for PLANT_SIGIL_AND_CARD
var sigil_placed = false
var card_played = false

# Phase names for display
var phase_names = {
	Phase.PLANT_BIOME: "Plant Token in Biome",
	Phase.PLANT_SIGIL_AND_CARD: "Plant Token in Sigil AND Play a Card",
	Phase.PLAY_SIGIL: "Activate Sigil",
	Phase.END_TURN: "End Turn"
}

# Phase descriptions for notifications
var phase_descriptions = {
	Phase.PLANT_BIOME: "Place a token in one of the biome locations.",
	Phase.PLANT_SIGIL_AND_CARD: "In this phase, do BOTH:\n• Place a token in a sigil location\n• Play a card from your hand",
	Phase.PLAY_SIGIL: "Select a token and activate Sigil A, B, or C.",
	Phase.END_TURN: "Your turn is ending."
}

# UI elements
var phase_notification

signal phase_changed(phase)
signal turn_action_completed(phase)

func _ready():
	print("TurnPhaseManager: _ready called")
	create_phase_popup()
	
	# Connect to token button
	var token_button = game.get_node("RightUI/TokenButton")
	if token_button:
		print("TurnPhaseManager: Found token button")
		if token_button.pressed.is_connected(on_token_button_pressed):
			token_button.pressed.disconnect(on_token_button_pressed)
		token_button.pressed.connect(on_token_button_pressed)
	else:
		print("TurnPhaseManager: Token button not found!")
	
	# Connect to token manager signals
	if token_manager and token_manager.has_signal("token_placed"):
		print("TurnPhaseManager: Connecting to token_placed signal")
		if token_manager.token_placed.is_connected(_on_token_placed):
			token_manager.token_placed.disconnect(_on_token_placed)
		token_manager.token_placed.connect(_on_token_placed)
		print("TurnPhaseManager: Connection to token_placed signal established!")
	else:
		print("TurnPhaseManager: WARNING - token_placed signal not found in token_manager!")
		print("TurnPhaseManager: Available signals in token_manager: ", token_manager.get_signal_list() if token_manager else "token_manager not found")
	
	# Connect to sigil buttons
	var sigil_container = game.get_node("SigilContainer")
	if sigil_container:
		print("TurnPhaseManager: Found sigil container")
		for child in sigil_container.get_children():
			if child is Button:
				if child.pressed.is_connected(_on_sigil_button_pressed.bind(child.name)):
					child.pressed.disconnect(_on_sigil_button_pressed.bind(child.name))
				child.pressed.connect(_on_sigil_button_pressed.bind(child.name))
	else:
		print("TurnPhaseManager: Sigil container not found!")
	
	# Connect to end turn button
	var end_turn_button = game.get_node("RightUI/EndTurnButton")
	if end_turn_button:
		print("TurnPhaseManager: Found end turn button")
		if end_turn_button.pressed.is_connected(_on_end_turn_pressed):
			end_turn_button.pressed.disconnect(_on_end_turn_pressed)
		end_turn_button.pressed.connect(_on_end_turn_pressed)
	else:
		print("TurnPhaseManager: End turn button not found!")

	# Connect to card manager signals
	var action_area = game.get_node("PlantingLocations/ActionArea")
	if action_area and action_area.has_signal("card_placed"):
		print("TurnPhaseManager: Connecting to action_area card_placed signal")
		if action_area.card_placed.is_connected(_on_card_placed):
			action_area.card_placed.disconnect(_on_card_placed)
		action_area.card_placed.connect(_on_card_placed)
	else:
		print("TurnPhaseManager: action_area card_placed signal not found!")
		
	var area_zone = game.get_node("PlantingLocations/AreaZone")
	if area_zone and area_zone.has_signal("card_placed"):
		print("TurnPhaseManager: Connecting to area_zone card_placed signal")
		if area_zone.card_placed.is_connected(_on_card_placed):
			area_zone.card_placed.disconnect(_on_card_placed)
		area_zone.card_placed.connect(_on_card_placed)
	else:
		print("TurnPhaseManager: area_zone card_placed signal not found!")

func initialize():
	print("TurnPhaseManager: initialize called")
	reset_phases()

# Creates the phase popup
func create_phase_popup():
	print("TurnPhaseManager: Creating phase popup")
	
	# Create popup panel
	phase_notification = AcceptDialog.new()
	phase_notification.name = "PhaseNotification"
	phase_notification.title = "Turn Phase"
	phase_notification.size = Vector2(350, 180)
	phase_notification.exclusive = false  # Allow interaction with the game while notification is shown
	phase_notification.dialog_text = "Initialize notification"
	game.add_child.call_deferred(phase_notification)
	
	# End phase button
	end_phase_button.pressed.connect(_on_end_phase_button_pressed)
	
	print("TurnPhaseManager: Phase popup created")

# Sets the current active phase
func set_phase(phase_id: Phase):
	print("TurnPhaseManager: set_phase called with phase: ", phase_id)
	if phase_id == current_phase:
		print("TurnPhaseManager: Already in phase ", phase_id)
		return
		
	# Exit current phase
	exit_current_phase()
	
	# Enter new phase
	current_phase = phase_id
	enter_current_phase()
	
	# Emit signal
	emit_signal("phase_changed", current_phase)
	
	# Show phase notification
	show_phase_notification()

# Actions when entering a phase
func enter_current_phase():
	print("TurnPhaseManager: Entering phase: ", current_phase)
	
	# Show/hide and enable/disable end phase button based on phase
	if current_phase != Phase.NONE and current_phase != Phase.END_TURN:
		end_phase_button.visible = true
		end_phase_button.disabled = false 
		print("TurnPhaseManager: Showing end phase button for phase ", current_phase)
	else:
		end_phase_button.visible = false
		end_phase_button.disabled = true
		print("TurnPhaseManager: Hiding end phase button for phase ", current_phase)
	
	# Rest of your existing code
	match current_phase:
		Phase.PLANT_BIOME:
			print("TurnPhaseManager: Setting up PLANT_BIOME phase")
			token_manager.can_plant_on_biome = true
			token_manager.can_plant_on_sigil = false
			disable_card_play()  # Disable cards in first phase
		Phase.PLANT_SIGIL_AND_CARD:
			print("TurnPhaseManager: Setting up PLANT_SIGIL_AND_CARD phase")
			token_manager.can_plant_on_biome = false
			token_manager.can_plant_on_sigil = true
			enable_card_play()  # Enable cards for this phase
		Phase.PLAY_SIGIL:
			print("TurnPhaseManager: Setting up PLAY_SIGIL phase")
			# Disable tokens and cards
			token_manager.can_plant_on_biome = false
			token_manager.can_plant_on_sigil = false
			disable_card_play()
			token_button.disabled = true
		Phase.END_TURN:
			print("TurnPhaseManager: Setting up END_TURN phase")
			if game_state_manager:
				game_state_manager._on_end_turn_pressed()

# Actions when exiting a phase
func exit_current_phase():
	print("TurnPhaseManager: Exiting phase: ", current_phase)
	
	# Hide end phase button
	end_phase_button.visible = false
	
	# Rest of your existing code
	match current_phase:
		Phase.PLANT_BIOME, Phase.PLANT_SIGIL_AND_CARD:
			token_manager.is_token_selected = false
			token_manager.unhighlight_all_token_placements()
			token_manager.update_token_ui()
		Phase.PLAY_SIGIL:
			enable_sigil_buttons(false)
			if sigil_manager:
				sigil_manager.is_sigil_mode = false
				sigil_manager.is_sigil_c = false

# Resets all phases for a new turn
func reset_phases():
	print("TurnPhaseManager: Resetting phases")
	current_phase = Phase.NONE
	sigil_placed = false
	card_played = false
	
	for phase_id in completed_phases:
		completed_phases[phase_id] = false
	
	# Disable all interactive elements until explicitly enabled
	disable_card_play()
	enable_sigil_buttons(false)
	token_manager.can_plant_on_biome = false
	token_manager.can_plant_on_sigil = false
	
	# Set initial phase when it's player's turn
	var local_id = multiplayer.get_unique_id()
	if game_state_manager.is_valid_player_turn(local_id):
		print("TurnPhaseManager: It's the local player's turn, setting initial phase")
		set_phase(Phase.PLANT_BIOME)
	else:
		print("TurnPhaseManager: Not the local player's turn")

# Complete the current phase
func complete_current_phase():
	print("TurnPhaseManager: Completing phase: ", current_phase)
	if current_phase != Phase.NONE:
		completed_phases[current_phase] = true
		emit_signal("turn_action_completed", current_phase)
		
		# Automatically advance to next phase
		advance_to_next_phase()

# Check if phase 2 is complete (both sigil placed and card played)
func check_phase_two_completion():
	print("TurnPhaseManager: Checking phase two completion. Sigil placed: ", sigil_placed, ", Card played: ", card_played)
	if sigil_placed and card_played:
		print("TurnPhaseManager: Phase two complete, both actions done")
		complete_current_phase()
	else:
		print("TurnPhaseManager: Phase two not yet complete")
		# Update notification to show progress
		show_phase_two_progress()

# Show progress in phase 2
func show_phase_two_progress():
	print("TurnPhaseManager: Showing phase two progress")
	if current_phase != Phase.PLANT_SIGIL_AND_CARD:
		return
		
	# Create progress text
	var progress_text = "PROGRESS:\n"
	progress_text += "• Place token in sigil: " + ("✓" if sigil_placed else "□") + "\n"
	progress_text += "• Play a card: " + ("✓" if card_played else "□")
	
	# Create a custom popup without buttons
	var panel = Panel.new()
	panel.name = "ProgressPanel"
	
	# Set up the panel size
	panel.size = Vector2(300, 150)
	
	# Position in the center of the screen
	var viewport_size = get_viewport().size
	panel.position = Vector2(
		(viewport_size.x - panel.size.x) / 2,
		(viewport_size.y - panel.size.y) / 2
	)
	
	# Add a title label
	var title_label = Label.new()
	title_label.text = phase_names[current_phase]
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_color_override("font_color", Color(1, 1, 1))
	title_label.position = Vector2(10, 10)
	title_label.size = Vector2(panel.size.x - 20, 30)
	panel.add_child(title_label)
	
	# Add a progress label
	var progress_label = Label.new()
	progress_label.text = progress_text
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress_label.position = Vector2(10, 50)
	progress_label.size = Vector2(panel.size.x - 20, 90)
	panel.add_child(progress_label)
	
	# Add to scene
	get_parent().add_child(panel)
	
	# Auto-close after 3 seconds
	await get_tree().create_timer(3.0).timeout
	if is_instance_valid(panel):
		panel.queue_free()


# Advances to the next phase in sequence
func advance_to_next_phase():
	print("TurnPhaseManager: Advancing to next phase from: ", current_phase)
	
	# Store the current phase for reference
	var previous_phase = current_phase
	
	# Determine the next phase
	var next_phase
	match current_phase:
		Phase.PLANT_BIOME:
			next_phase = Phase.PLANT_SIGIL_AND_CARD
			print("TurnPhaseManager: Advancing from PLANT_BIOME to PLANT_SIGIL_AND_CARD")
		Phase.PLANT_SIGIL_AND_CARD:
			next_phase = Phase.PLAY_SIGIL
			print("TurnPhaseManager: Advancing from PLANT_SIGIL_AND_CARD to PLAY_SIGIL")
		Phase.PLAY_SIGIL:
			next_phase = Phase.END_TURN
			print("TurnPhaseManager: Advancing from PLAY_SIGIL to END_TURN")
		Phase.END_TURN:
			print("TurnPhaseManager: Already at END_TURN, no further advancement")
			return
		_:
			print("TurnPhaseManager: Invalid phase: ", current_phase)
			return
	
	# Exit current phase
	exit_current_phase()
	
	# Update phase
	current_phase = next_phase
	
	# Enter new phase
	enter_current_phase()
	
	# Notify about phase change
	emit_signal("phase_changed", current_phase)
	
	# Show notification
	show_phase_notification()
	
	print("TurnPhaseManager: Phase successfully advanced from ", previous_phase, " to ", current_phase)

# Helper function to enable card play
func enable_card_play():
	print("TurnPhaseManager: Enabling card play")
	var player_hand = get_parent().get_node("HandAreas/PlayerHand")
	if player_hand:
		player_hand.set_interaction_enabled(true)
		print("TurnPhaseManager: Card play enabled")
	else:
		print("TurnPhaseManager: Player hand not found!")

# Helper function to disable card play
func disable_card_play():
	print("TurnPhaseManager: Disabling card play")
	var player_hand = get_parent().get_node("HandAreas/PlayerHand")
	if player_hand:
		player_hand.set_interaction_enabled(false)
		print("TurnPhaseManager: Card play disabled")
	else:
		print("TurnPhaseManager: Player hand not found!")

# Helper function to enable/disable sigil buttons
func enable_sigil_buttons(enabled: bool):
	print("TurnPhaseManager: ", "Enabling" if enabled else "Disabling", " sigil buttons")
	var sigil_container = game.get_node("SigilContainer")
	if sigil_container:
		for child in sigil_container.get_children():
			if child is Button:
				child.disabled = !enabled
				child.modulate = Color(1, 1, 1, 1) if enabled else Color(0.5, 0.5, 0.5, 0.5)
		print("TurnPhaseManager: Sigil buttons ", "enabled" if enabled else "disabled")
	else:
		print("TurnPhaseManager: Sigil container not found!")

func show_requirement_notification(message: String):
	# Create a custom popup without buttons
	var panel = Panel.new()
	panel.name = "RequirementPanel"
	
	# Set up the panel size
	panel.size = Vector2(300, 120)
	
	# Position in the center of the screen
	var viewport_size = get_viewport().size
	panel.position = Vector2(
		(viewport_size.x - panel.size.x) / 2,
		(viewport_size.y - panel.size.y) / 2
	)
	
	# Add a title label
	var title_label = Label.new()
	title_label.text = "Cannot End Phase"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_color_override("font_color", Color(1, 1, 1))
	title_label.position = Vector2(10, 10)
	title_label.size = Vector2(panel.size.x - 20, 30)
	panel.add_child(title_label)
	
	# Add a message label
	var message_label = Label.new()
	message_label.text = message
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.position = Vector2(10, 40)
	message_label.size = Vector2(panel.size.x - 20, 80)
	panel.add_child(message_label)
	
	# Add to scene
	get_parent().add_child(panel)
	
	# Auto-close after 3 seconds
	await get_tree().create_timer(3.0).timeout
	if is_instance_valid(panel):
		panel.queue_free()

# Displays a notification about the current phase
func show_phase_notification():
	print("TurnPhaseManager: Showing phase notification for phase: ", current_phase)
	if current_phase == Phase.NONE:
		print("TurnPhaseManager: Not showing notification for NONE phase")
		return
	
	# Create a custom popup without buttons
	var panel = Panel.new()
	panel.name = "PhaseNotificationPanel"
	
	# Set up the panel size
	panel.size = Vector2(350, 150)
	
	# Position in the center of the screen
	var viewport_size = get_viewport().size
	panel.position = Vector2(
		(viewport_size.x - panel.size.x) / 2,
		(viewport_size.y - panel.size.y) / 2
	)
	
	# Add a title label
	var title_label = Label.new()
	title_label.text = phase_names[current_phase]
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_color_override("font_color", Color(1, 1, 1))
	title_label.position = Vector2(10, 10)
	title_label.size = Vector2(panel.size.x - 20, 30)
	panel.add_child(title_label)
	
	# Add a description label
	var desc_label = Label.new()
	desc_label.text = phase_descriptions[current_phase]
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.position = Vector2(10, 50)
	desc_label.size = Vector2(panel.size.x - 20, 90)
	panel.add_child(desc_label)
	
	# Add to scene
	get_parent().add_child(panel)
	print("TurnPhaseManager: Custom notification displayed")
	
	# Auto-close after 3 seconds
	await get_tree().create_timer(3.0).timeout
	if is_instance_valid(panel):
		panel.queue_free()
		print("TurnPhaseManager: Notification auto-closed")

# --------------------------------
# Event handlers
# --------------------------------

func on_token_button_pressed():
	print("TurnPhaseManager: Token button pressed")
	var local_id = multiplayer.get_unique_id()
	if !game_state_manager.is_valid_player_turn(local_id):
		print("TurnPhaseManager: Not player's turn")
		return
		
	# Check if we're in a valid token planting phase
	if current_phase == Phase.PLANT_BIOME:
		print("TurnPhaseManager: In PLANT_BIOME phase, enabling biome placement")
		token_manager.can_plant_on_biome = true
		token_manager.can_plant_on_sigil = false
		token_manager._on_token_selected()
	elif current_phase == Phase.PLANT_SIGIL_AND_CARD:
		print("TurnPhaseManager: In PLANT_SIGIL_AND_CARD phase, enabling sigil placement")
		token_manager.can_plant_on_biome = false
		token_manager.can_plant_on_sigil = true
		token_manager._on_token_selected()
	#else:
		#print("TurnPhaseManager: Wrong phase for token placement: ", current_phase)
		## Not in token planting phase, show notification
		#var dialog = AcceptDialog.new()
		#dialog.dialog_text = "You cannot place tokens in the " + phase_names[current_phase] + " phase."
		#dialog.title = "Wrong Phase"
		#get_parent().add_child(dialog)
		#dialog.popup_centered()
		
		# Auto-close after 1.5 seconds
		#await get_tree().create_timer(3.0).timeout
		#if is_instance_valid(dialog) and dialog.visible:
			#dialog.queue_free()

func _on_end_phase_button_pressed():
	print("TurnPhaseManager: End phase button pressed")
	
	match current_phase:
		Phase.PLANT_BIOME:
			# For biome phase, only allow ending if a token has been placed
			if current_phase == 0:
				completed_phases[Phase.PLANT_BIOME] = true
				advance_to_next_phase()
			else:
				show_requirement_notification("You must place at least one token in a biome before ending this phase.")
		
		Phase.PLANT_SIGIL_AND_CARD:
			# For sigil and card phase, check if either action is done
			if current_phase == 1:
				# If at least sigil is placed, allow ending (card is optional)
				completed_phases[Phase.PLANT_SIGIL_AND_CARD] = true
				advance_to_next_phase()
				end_phase_button.disabled = true
			else:
				show_requirement_notification("You must place at least one token in a sigil before ending this phase.")
		
		Phase.PLAY_SIGIL:
			# Allow skipping sigil activation entirely
			completed_phases[Phase.PLAY_SIGIL] = true
			advance_to_next_phase()

func _on_end_turn_pressed():
	print("TurnPhaseManager: End turn button pressed")
	current_phase = Phase.NONE

func _on_token_placed(player_id, biome, location):
	print("TurnPhaseManager: Token placed signal received! Player ID: ", player_id, ", Biome: ", biome, ", Location: ", location)
	
	var local_id = multiplayer.get_unique_id()
	if player_id != local_id:
		print("TurnPhaseManager: Token placed by another player, ignoring")
		return
	
	print("TurnPhaseManager: Processing token placement for local player")
	print("TurnPhaseManager: Current phase is: ", current_phase)
	
	# Get placement information
	var placement = token_manager.get_token_placement_at_position(location)
	if !placement:
		print("TurnPhaseManager: ERROR - No placement found at location: ", location)
		return
	
	print("TurnPhaseManager: Placement found with place_id: ", placement.place_id)
	
	# IMPORTANT: There was a logic error here. place_id == -1 means biome placement
	# and place_id != -1 means sigil placement
	
	# Check current phase and placement type
	if current_phase == Phase.PLANT_BIOME:
		# In biome planting phase
		if placement.place_id == -1:  # This is BIOME placement (place_id is the biome ID)
			print("TurnPhaseManager: Biome placement detected in PLANT_BIOME phase")
			completed_phases[Phase.PLANT_BIOME] = true
			call_deferred("advance_to_next_phase")
		else:  # place_id == -1 means SIGIL placement
			print("TurnPhaseManager: WARNING - Sigil placement detected in PLANT_BIOME phase")
	
	elif current_phase == Phase.PLANT_SIGIL_AND_CARD:
		# In sigil/card phase
		if placement.place_id != -1:  # This is SIGIL placement
			print("TurnPhaseManager: Sigil placement detected in PLANT_SIGIL_AND_CARD phase")
			sigil_placed = true
			check_phase_two_completion()

func _on_card_placed(card, slot_index, location_name):
	print("TurnPhaseManager: Card placed. Card: ", card.card_name if card else "null", ", Slot: ", slot_index, ", Location: ", location_name)
	var local_id = multiplayer.get_unique_id()
	if !game_state_manager.is_valid_player_turn(local_id):
		print("TurnPhaseManager: Not player's turn, ignoring card placement")
		return
		
	if current_phase == Phase.PLANT_SIGIL_AND_CARD:
		print("TurnPhaseManager: Card played in correct phase")
		# Mark card as played
		card_played = true
		disable_card_play()
		
		# Check if phase is complete
		check_phase_two_completion()
	else:
		print("TurnPhaseManager: Card played in wrong phase: ", current_phase)

func _on_sigil_button_pressed(button_name):
	print("TurnPhaseManager: Sigil button pressed: ", button_name)
	var local_id = multiplayer.get_unique_id()
	if !game_state_manager.is_valid_player_turn(local_id):
		print("TurnPhaseManager: Not player's turn")
		return
		
	if current_phase != Phase.PLAY_SIGIL:
		print("TurnPhaseManager: Wrong phase for sigil activation: ", current_phase)
		# Wrong phase notification
		var dialog = AcceptDialog.new()
		dialog.dialog_text = "You can only activate sigils in the " + phase_names[Phase.PLAY_SIGIL] + " phase."
		dialog.title = "Wrong Phase"
		get_parent().add_child(dialog)
		dialog.popup_centered()
		
		# Auto-close after 1.5 seconds
		await get_tree().create_timer(1.5).timeout
		if is_instance_valid(dialog) and dialog.visible:
			dialog.queue_free()
		
		return
	
	# Set sigil mode based on button name
	if sigil_manager:
		print("TurnPhaseManager: Activating sigil: ", button_name)
		sigil_manager.is_sigil_mode = true
		
		match button_name:
			"SigilAButton":
				print("TurnPhaseManager: Sigil A activated")
				sigil_manager.is_sigil_a = true
				sigil_manager.is_sigil_b = false
				sigil_manager.is_sigil_c = false
			"SigilBButton":
				print("TurnPhaseManager: Sigil B activated")
				sigil_manager.is_sigil_a = false
				sigil_manager.is_sigil_b = true
				sigil_manager.is_sigil_c = false
			"SigilCButton":
				print("TurnPhaseManager: Sigil C activated")
				sigil_manager.is_sigil_a = false
				sigil_manager.is_sigil_b = false
				sigil_manager.is_sigil_c = true
		
		# Mark the phase as complete after sigil activation
		complete_current_phase()
	else:
		print("TurnPhaseManager: Sigil manager not found!")

# --------------------------------
# Network synchronization
# --------------------------------

@rpc("any_peer", "call_local")
func sync_phase_state(phase_data: Dictionary):
	print("TurnPhaseManager: Received sync_phase_state")
	current_phase = phase_data.current_phase
	completed_phases = phase_data.completed_phases
	sigil_placed = phase_data.sigil_placed
	card_played = phase_data.card_played

func request_phase_sync():
	print("TurnPhaseManager: Requesting phase sync")
	if multiplayer.is_server():
		# If we're the server, broadcast to all clients
		var phase_data = {
			"current_phase": current_phase,
			"completed_phases": completed_phases,
			"sigil_placed": sigil_placed,
			"card_played": card_played
		}
		rpc("sync_phase_state", phase_data)
	else:
		# If we're a client, request from server
		rpc_id(1, "request_phase_data")

@rpc("any_peer")
func request_phase_data():
	print("TurnPhaseManager: Received request_phase_data")
	if !multiplayer.is_server():
		print("TurnPhaseManager: Not server, ignoring request")
		return
		
	var requesting_peer = multiplayer.get_remote_sender_id()
	var phase_data = {
		"current_phase": current_phase,
		"completed_phases": completed_phases,
		"sigil_placed": sigil_placed,
		"card_played": card_played
	}
	rpc_id(requesting_peer, "sync_phase_state", phase_data)

# --------------------------------
# Compatibility functions
# --------------------------------
# Compatibility function for existing code
func show_phase_ui():
	print("TurnPhaseManager: show_phase_ui compatibility function called")
	# Not used in this implementation
	pass

# Compatibility function for existing code
func hide_phase_ui():
	print("TurnPhaseManager: hide_phase_ui compatibility function called")
	# Not used in this implementation
	pass

# Compatibility function for existing code
func update_phase_ui():
	print("TurnPhaseManager: update_phase_ui compatibility function called")
	# Not used in this implementation
	pass
