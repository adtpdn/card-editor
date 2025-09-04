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
@onready var deck = $"../Deck"
@onready var tokens = $"../Tokens"
@onready var player_turn = $"../PlayerTurn"
@onready var status_phase = $"../Status_Phase"
@onready var notification = $"../Notification"
@onready var soil_star_actions = $"../SoilStarActions"



@onready var end_phase_button = $"../RightUI/EndPhaseButton"
@onready var token_button = $"../RightUI/TokenButton"

var count_plant = 0

# Phase tracking
var current_phase: Phase = Phase.NONE
var completed_phases = {
	Phase.PLANT_BIOME: false,
	Phase.PLANT_SIGIL_AND_CARD: false,
	Phase.PLAY_SIGIL: false
}

# Sub-phase tracking for PLANT_BIOME
var is_draw_card := false

# Sub-phase tracking for PLANT_SIGIL_AND_CARD
var sigil_placed = false
var card_played = false

# Track sigil usage per turn
var sigil_used_this_turn := false

# Phase names for display
var phase_names = {
	Phase.PLANT_BIOME: "Plant Token in Biome",
	Phase.PLANT_SIGIL_AND_CARD: "Plant Token in Sigil AND Play a Card",
	Phase.PLAY_SIGIL: "Activate Sigil",
	Phase.END_TURN: "End Turn"
}

# Phase descriptions for notifications
var phase_descriptions = {
	Phase.PLANT_BIOME: "Place a token in one of the biome locations or draw a card.",
	Phase.PLANT_SIGIL_AND_CARD: "In this phase, do BOTH:\n• Place a token in a sigil location or draw a card\n• Play a card from your hand",
	Phase.PLAY_SIGIL: "Select a token and activate Sigil A, B, or C.",
	Phase.END_TURN: "Your turn is ending."
}

# UI elements
var phase_notification

signal phase_changed(phase)
signal turn_action_completed(phase)

func _ready():
	#print("TurnPhaseManager: _ready called")
	create_phase_popup()
	
	# Connect to token button
	var token_button = game.get_node("RightUI/TokenButton")
	if token_button:
		#print("TurnPhaseManager: Found token button")
		if token_button.pressed.is_connected(on_token_button_pressed):
			token_button.pressed.disconnect(on_token_button_pressed)
		token_button.pressed.connect(on_token_button_pressed)
	else:
		print("TurnPhaseManager: Token button not found!")
	
	# Connect to token manager signals
	if token_manager and token_manager.has_signal("token_placed"):
		#print("TurnPhaseManager: Connecting to token_placed signal")
		if token_manager.token_placed.is_connected(_on_token_placed):
			token_manager.token_placed.disconnect(_on_token_placed)
		token_manager.token_placed.connect(_on_token_placed)
		#print("TurnPhaseManager: Connection to token_placed signal established!")
	else:
		print("TurnPhaseManager: WARNING - token_placed signal not found in token_manager!")
		print("TurnPhaseManager: Available signals in token_manager: ", token_manager.get_signal_list() if token_manager else "token_manager not found")
	
	# Connect to end turn button
	var end_turn_button = game.get_node("RightUI/EndTurnButton")
	if end_turn_button:
		#print("TurnPhaseManager: Found end turn button")
		if end_turn_button.pressed.is_connected(_on_end_turn_pressed):
			end_turn_button.pressed.disconnect(_on_end_turn_pressed)
		end_turn_button.pressed.connect(_on_end_turn_pressed)
	else:
		print("TurnPhaseManager: End turn button not found!")

func initialize():
	#print("")
	#print("TurnPhaseManager: initialize called")
	reset_phases()

# Creates the phase popup
func create_phase_popup():
	#print("TurnPhaseManager: Creating phase popup")
	
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
	
	#print("TurnPhaseManager: Phase popup created")

# Sets the current active phase
@rpc("any_peer", "call_local", "reliable")
func set_phase(phase_id: Phase):
	#print("TurnPhaseManager: set_phase called with phase: ", phase_id)
	if phase_id == current_phase:
		#print("TurnPhaseManager: Already in phase ", phase_id)
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
	player_turn.update_turn_display()
	# Show/hide and enable/disable end phase button based on phase
	if current_phase != Phase.NONE and current_phase != Phase.END_TURN:
		end_phase_button.visible = true
		end_phase_button.disabled = false 
		print("TurnPhaseManager: Showing end phase button for phase ", current_phase)
	else:
		end_phase_button.visible = false
		end_phase_button.disabled = true
		print("TurnPhaseManager: Hiding end phase button for phase ", current_phase)
	
	notification.hide()
	
	# Round 0 (plant 2 tokens)
	if game_state_manager.current_round == 0 and count_plant <= 1:
		match current_phase:
			Phase.PLANT_BIOME:
				var end_turn_button = get_parent().get_node("RightUI/EndTurnButton")
				token_manager.can_plant_on_biome = true
				token_manager.can_plant_on_sigil = false
				end_phase_button.disabled = true
				end_turn_button.disabled = true
				return
	## NEED TO DO THE PLANT_SIGIL_AND CARD PHASE AFTER use extra token
	# Round 1 - 8
	match current_phase:
		Phase.PLANT_BIOME:
			#print("TurnPhaseManager: Setting up PLANT_BIOME phase")
			# FIXED: In biome phase, we want to plant tokens on BIOME locations (place_id == -1)
			token_manager.can_plant_on_biome = true
			token_manager.can_plant_on_sigil = false
			
			 # Disable cards in first phase
		Phase.PLANT_SIGIL_AND_CARD:
			#print("TurnPhaseManager: Setting up PLANT_SIGIL_AND_CARD phase")
			# FIXED: In sigil phase, we want to plant tokens on SIGIL locations (place_id != -1)
			token_manager.can_plant_on_biome = false
			token_manager.can_plant_on_sigil = true
		Phase.PLAY_SIGIL:
			#print("TurnPhaseManager: Setting up PLAY_SIGIL phase")
			# Disable tokens and cards
			token_manager.can_plant_on_biome = false
			token_manager.can_plant_on_sigil = false
			reset_card_variables()
			highlight_marker_mesh()
		Phase.END_TURN:
			#print("TurnPhaseManager: Setting up END_TURN phase")
			if game_state_manager:
				game_state_manager._on_end_turn_pressed()

# Actions when exiting a phase
func exit_current_phase():
	#print("TurnPhaseManager: Exiting phase: ", current_phase)
	
	# Hide end phase button
	end_phase_button.visible = false
	
	# Rest of your existing code
	match current_phase:
		Phase.PLANT_BIOME, Phase.PLANT_SIGIL_AND_CARD:
			token_manager.is_token_selected = false
			token_manager.unhighlight_all_token_placements()
			token_manager.update_token_ui()
		Phase.PLAY_SIGIL:
			if sigil_manager:
				sigil_manager.is_sigil_mode = false
				sigil_manager.is_sigil_c = false

func highlight_marker_mesh():
	# Get the ID of the player whose turn it currently is.
	var current_player_id = game_state_manager.get_current_player_id()
	if current_player_id == -1: return # Exit if there is no active player

	for token in tokens.get_children():
		var is_my_activatable_token = false
		# Check that the token belongs to the current player, is an energy token, and is not blighted.
		if token.owner_id == current_player_id and token.is_energy and not token.is_blighted:
			# Also verify that there is enough mana in the token's biome to activate a sigil.
			if sigil_manager.check_mana_available(token.biome_type):
				# Finally, check if the token can form any of the valid sigil patterns.
				if sigil_manager.check_for_sigil_a_pattern(token) or sigil_manager.check_for_sigil_b_pattern(token) or sigil_manager.check_for_sigil_c_pattern(token):
					is_my_activatable_token = true
		
		# Only show the marker mesh if all conditions are met for the current player's token.
		if is_my_activatable_token:
			token.marker_mesh.show()
		else:
			# Ensure all other tokens are not highlighted.
			token.marker_mesh.hide()

func unhighlight_marker_mesh():
	#print("unhighlight marker mesh")
	for token in tokens.get_children():
		token.marker_mesh.hide()

# Resets all card data for the sigil activation
func reset_card_variables():
	card_manager.is_take_off_mode = false
	card_manager.is_unblight_mode = false
	card_manager.is_refresh_energy_mode = false
	card_manager.is_swap_energy_mode = false  
	card_manager.is_plant_extra = false

# Resets all phases for a new turn
func reset_phases():
	#print("TurnPhaseManager: Resetting phases")
	current_phase = Phase.NONE
	is_draw_card = false
	sigil_placed = false
	card_played = false
	
	sigil_used_this_turn = false
	sigil_manager.is_sigil_a = false
	sigil_manager.is_sigil_b = false
	sigil_manager.is_sigil_c = false
	
	for phase_id in completed_phases:
		completed_phases[phase_id] = false
	
	# Disable all interactive elements until explicitly enabled
	
	token_manager.can_plant_on_biome = false
	token_manager.can_plant_on_sigil = false
	
	# Set initial phase when it's player's turn
	var local_id = multiplayer.get_unique_id()
	if game_state_manager.is_valid_player_turn(local_id):
		#print("TurnPhaseManager: It's the local player's turn, setting initial phase")
		set_phase(Phase.PLANT_BIOME)
	else:
		print("TurnPhaseManager: Not the local player's turn")

# Complete the current phase
func complete_current_phase():
	#print("TurnPhaseManager: Completing phase: ", current_phase)
	
	if current_phase == Phase.PLAY_SIGIL:
		end_phase_button.disabled = true
	elif current_phase != Phase.NONE:
		completed_phases[current_phase] = true
		emit_signal("turn_action_completed", current_phase)
		
		# Automatically advance to next phase
		advance_to_next_phase()

# Check if phase 2 is complete (both sigil placed and card played)
func check_phase_two_completion():
	#print("TurnPhaseManager: Checking phase two completion. Sigil placed: ", sigil_placed, ", Card played: ", card_played)
	if is_draw_card:
		print("check phase two comp")
		completed_phases[Phase.PLANT_BIOME] = true
		call_deferred("advance_to_next_phase")
	
	if sigil_placed and card_played:
		print('advance to sigil activation')
		completed_phases[Phase.PLANT_SIGIL_AND_CARD] = true
		# Use call_deferred to avoid immediate phase change during signal processing
		call_deferred("advance_to_next_phase")
	
	#else:
		# Update notification to show progress
		#show_phase_two_progress()

# Show progress in phase 2
func show_phase_two_progress():
	#print("TurnPhaseManager: Showing phase two progress")
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
	
	#print("count plant : ", count_plant)
	if game_state_manager.current_round == 0:
		if count_plant == 2:
			var end_turn_button = get_parent().get_node("RightUI/EndTurnButton")
			end_turn_button.disabled = false
			token_button.disabled = true
			count_plant = 0
			current_phase = Phase.END_TURN
		return
	
	# Store the current phase for reference
	var previous_phase = current_phase
	
	# Determine the next phase
	var next_phase
	match current_phase:
		Phase.PLANT_BIOME:
			next_phase = Phase.PLANT_SIGIL_AND_CARD
			#print("TurnPhaseManager: Advancing from PLANT_BIOME to PLANT_SIGIL_AND_CARD")
		Phase.PLANT_SIGIL_AND_CARD:
			next_phase = Phase.PLAY_SIGIL
			print("TurnPhaseManager: Advancing from PLANT_SIGIL_AND_CARD to PLAY_SIGIL")
		Phase.PLAY_SIGIL:
			next_phase = Phase.END_TURN
			#print("TurnPhaseManager: Advancing from PLAY_SIGIL to END_TURN")
		Phase.END_TURN:
			#print("TurnPhaseManager: Already at END_TURN, no further advancement")
			return
		_:
			#print("TurnPhaseManager: Invalid phase: ", current_phase)
			return
	
	# Instead of changing the phase directly, the server tells everyone to change the phase.
	if multiplayer.is_server():
		# This will now execute set_phase() on the server and all clients.
		rpc("set_phase", next_phase)
	
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
	
	#print("TurnPhaseManager: Phase successfully advanced from ", previous_phase, " to ", current_phase)

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
	#print("TurnPhaseManager: Showing phase notification for phase: ", current_phase)
	if current_phase == Phase.NONE:
		#print("TurnPhaseManager: Not showing notification for NONE phase")
		return

	# Add a description label
	status_phase.show_instruction_label(phase_descriptions[current_phase])

	#print("TurnPhaseManager: Custom notification displayed")

# --------------------------------
# Event handlers
# --------------------------------

func on_token_button_pressed():
	#print("TurnPhaseManager: Token button pressed")
	var local_id = multiplayer.get_unique_id()
	if !game_state_manager.is_valid_player_turn(local_id):
		#print("TurnPhaseManager: Not player's turn")
		return
		
	# Check if we're in a valid token planting phase
	if current_phase == Phase.PLANT_BIOME:
		#print("TurnPhaseManager: In PLANT_BIOME phase, enabling biome placement")
		token_manager.can_plant_on_biome = true
		token_manager.can_plant_on_sigil = false
		token_manager._on_token_selected()
	elif current_phase == Phase.PLANT_SIGIL_AND_CARD:
		#print("TurnPhaseManager: In PLANT_SIGIL_AND_CARD phase, enabling sigil placement")
		token_manager.can_plant_on_biome = false
		token_manager.can_plant_on_sigil = true
		token_manager._on_token_selected()


func _on_end_phase_button_pressed():
	#print("TurnPhaseManager: End phase button pressed")
	
	if game_state_manager.current_round == 0:
		return
	
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
			print("END PHASE PLAY SIGIL")
			# Allow skipping sigil activation entirely
			completed_phases[Phase.PLAY_SIGIL] = true
			advance_to_next_phase()

func _on_end_turn_pressed():
	print("TurnPhaseManager: End turn button pressed")
	unhighlight_marker_mesh()
	status_phase.hide_panel()
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
	
	if game_state_manager.current_round == 0:
		count_plant += 1
		print("TurnPhaseManager: count_plant incremented to: ", count_plant)
		
		# If we've reached 2 plants, update UI accordingly
		if count_plant == 2:
			var end_turn_button = get_parent().get_node("RightUI/EndTurnButton")
			end_turn_button.disabled = false
			token_button.disabled = true
		return
	
	# Check current phase and placement type
	print('current phase : ', current_phase)
	print('Phase : ', Phase.PLANT_SIGIL_AND_CARD)
	match current_phase:
		Phase.PLANT_BIOME:
			# In this phase, we only care about biome placements (place_id == -1).
			print('soil_star_actions.is_playing_extra_token_from_soil_star : ', soil_star_actions.is_playing_extra_token_from_soil_star)
			if placement.place_id == -1 and not soil_star_actions.is_playing_extra_token_from_soil_star:
				print("TurnPhaseManager: Biome placement registered, advancing phase.")
				completed_phases[Phase.PLANT_BIOME] = true
				call_deferred("advance_to_next_phase")
				if card_manager.is_plant_extra:
					card_manager.rpc("sync_plant_extra_state", false)
			

		Phase.PLANT_SIGIL_AND_CARD:
			# In this phase, we only care about sigil placements (place_id != -1).
			if placement.place_id != -1 and not soil_star_actions.is_playing_extra_token_from_soil_star:
				print("TurnPhaseManager: Sigil placement registered.")
				# Check if the sigil part of the turn has already been fulfilled.
				print('card manager is plant extra : ', card_manager.is_plant_extra)
				
				if card_manager.is_plant_extra:
					card_manager.rpc("sync_plant_extra_state", false)
				elif not sigil_placed:
					sigil_placed = true
					token_button.disabled = true # Prevent placing more free tokens.
			else:
				if card_manager.is_plant_extra:
					card_manager.rpc("sync_plant_extra_state", false)

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

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Phase Management
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Enable only sigil placement locations
func enable_sigil_placement():
	token_manager.is_token_selected = true
	
	# Unhighlight all first
	token_manager.unhighlight_all_token_placements()
	
	# Highlight only sigil locations (place_id == -1)
	for placement in get_parent().get_node("TokenPlacements").get_children():
		if !placement.is_occupied and placement.place_id == -1:
			placement.set_highlight(true)
	
	# Update the UI
	token_manager.update_token_ui()

# Enable only biome placement locations
func enable_biome_placement():
	token_manager.is_token_selected = true
	
	# Unhighlight all first
	token_manager.unhighlight_all_token_placements()
	
	# Highlight only biome locations (place_id != -1)
	for placement in get_parent().get_node("TokenPlacements").get_children():
		if !placement.is_occupied and placement.place_id != -1:
			placement.set_highlight(true)
	
	# Update the UI
	token_manager.update_token_ui()

# Disable sigil placement
func disable_sigil_placement():
	if token_manager.is_token_selected:
		token_manager.is_token_selected = false
		token_manager.unhighlight_all_token_placements()
		token_manager.update_token_ui()

# Disable biome placement
func disable_biome_placement():
	if token_manager.is_token_selected:
		token_manager.is_token_selected = false
		token_manager.unhighlight_all_token_placements()
		token_manager.update_token_ui()
