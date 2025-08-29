# ui_manager.gd
extends Node

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# References to other managers
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
@onready var game = get_parent()
@onready var token_manager = $"../TokenManager"
@onready var network_manager = $"../NetworkManager"
@onready var game_state_manager = $"../GameStateManager" 
@onready var card_manager = $"../CardManager"
@onready var point_counter = $"../PointCounter"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# UI System Variables
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
var current_dialog: AcceptDialog
var show_fps = false
var fps_label: Label
var debug_panel: PanelContainer
var ui_update_timer: Timer

# Add this constant at the top of the script for easy access
const TURN_INDICATOR_ICON = preload("res://assets/ui/hud/player_hud_indicator_selector.png")

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Initialization
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━


func initialize():
	# Initial UI setup
	update_player_list()
	setup_start_game_button()
	update_network_info()

# ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
# ---     General UI Setup     ---
# ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
# This new function replaces the old update_player_list.
# It controls visibility, names, turn indicators, and card counts.
func update_player_hud():
	var player_list_node = get_parent().get_node_or_null("PlayerList")
	if not player_list_node: return

	# Get the latest game state data
	var initial_order = game.initial_player_order
	var active_player_id = game_state_manager.get_current_player_id()
	var player_names = game.player_names
	var hand_sizes = game.player_hand_sizes
	print("hand sizes : ", hand_sizes)

	# Loop through all 4 possible player slots in the UI
	for i in range(4):
		var player_node = player_list_node.get_node_or_null("Player" + str(i + 1))
		if not player_node: continue

		# --- VISIBILITY & NAMING ---
		if i < initial_order.size():
			# A player exists for this slot
			player_node.visible = true
			var player_id = initial_order[i]
			
			var name_label = player_node.get_node_or_null("Player" + str(i + 1) + "Label")
			if name_label:
				name_label.text = player_names.get(player_id, "Player " + str(player_id))

			# --- TURN INDICATOR ---
			var player_id_for_slot = initial_order[i]
			var indicator_name = "Player" + str(i + 1) + "Indicator"
			var indicator = player_node.get_node_or_null(indicator_name)
			if indicator:
				# If it's the active player's turn, show the icon. Otherwise, clear it.
				if player_id_for_slot == active_player_id:
					indicator.texture = TURN_INDICATOR_ICON
				else:
					indicator.texture = null

			# --- CARD COUNT INDICATORS ---
			# Get the dictionary of counts for this player, with a safe default
			var counts = hand_sizes.get(player_id_for_slot, {"action": 0, "elemental": 0})
			var action_count = counts.get("action", 0)
			var elemental_count = counts.get("elemental", 0)

			# Update Action card indicators (1 to 3)
			for card_idx in range(1, 4): # Loops for 1, 2, 3
				var card_indicator_name = "Player" + str(i + 1) + "Card" + str(card_idx)
				var card_indicator = player_node.get_node_or_null(card_indicator_name)
				if card_indicator:
					card_indicator.visible = (card_idx <= action_count)

			# Update Elemental card indicator (4)
			var elemental_indicator_name = "Player" + str(i + 1) + "Card4"
			var elemental_indicator = player_node.get_node_or_null(elemental_indicator_name)
			if elemental_indicator:
				elemental_indicator.visible = (elemental_count > 0)
		else:
			# No player for this slot, hide it
			player_node.visible = false

func update_turn_indicator():
	# Get the current turn player ID
	var current_player_id = -1
	
	if game.game_state_manager.current_turn_index >= 0 and game.game_state_manager.current_turn_index < game.players.size():
		current_player_id = game.players[game.game_state_manager.current_turn_index]
	
	# Get turn indicator label if it exists
	var turn_label = get_parent().get_node_or_null("RightUI/TurnLabel")
	if turn_label:
		if current_player_id == -1:
			turn_label.text = "Waiting..."
		elif current_player_id == multiplayer.get_unique_id():
			turn_label.text = "Your Turn!"
			turn_label.add_theme_color_override("font_color", Color(1, 1, 0))  # Yellow
		else:
			turn_label.text = "Player " + str(current_player_id) + "'s Turn"
			turn_label.add_theme_color_override("font_color", Color(1, 1, 1))  # White
	
	# Highlight the active player in the player list
	var player_list = get_parent().get_node_or_null("RightUI/PlayerList")
	if player_list:
		for child in player_list.get_children():
			if child.has_method("set_active"):
				var is_active = child.name == "Player_" + str(current_player_id)
				child.set_active(is_active)

# Round Indicator
func update_round_indicator():
	var round_label = get_parent().get_node_or_null("RightUI/RoundLabel")
	if round_label:
		round_label.text = "Round: %d" % game.game_state_manager.round_count

func setup_debug_ui():
	# Create FPS display
	fps_label = Label.new()
	fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	fps_label.position = Vector2(10, 10)
	fps_label.size = Vector2(200, 50)
	fps_label.visible = show_fps
	
	# Create debug panel
	debug_panel = PanelContainer.new()
	debug_panel.size = Vector2(300, 200)
	debug_panel.position = Vector2(10, 40)
	debug_panel.visible = false
	
	# Add to UI layer
	var ui_layer = get_parent().get_node("UILayer")
	if ui_layer:
		ui_layer.add_child(fps_label)
		ui_layer.add_child(debug_panel)

func setup_menu_buttons():
	# Connect to toggle FPS button
	var toggle_fps_button = get_parent().get_node("RightUI/Menu/ToggleFPSButton")
	if toggle_fps_button:
		if toggle_fps_button.pressed.is_connected(_on_toggle_fps_pressed):
			toggle_fps_button.pressed.disconnect(_on_toggle_fps_pressed)
		toggle_fps_button.pressed.connect(_on_toggle_fps_pressed)
	
	# Connect to toggle debug button
	var toggle_debug_button = get_parent().get_node("RightUI/Menu/ToggleDebugButton")
	if toggle_debug_button:
		if toggle_debug_button.pressed.is_connected(_on_toggle_debug_pressed):
			toggle_debug_button.pressed.disconnect(_on_toggle_debug_pressed)
		toggle_debug_button.pressed.connect(_on_toggle_debug_pressed)

func setup_player_list():
	var player_list = get_parent().get_node("PlayerList")
	if player_list:
		player_list.clear()
		player_list.item_selected.connect(_on_player_selected)

func setup_start_game_button():
	var start_game_button = get_parent().get_node("StartGameButton")
	if start_game_button:
		# Show button only for server/host
		start_game_button.visible = multiplayer.is_server()

# ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
# ---    UI Update Methods     ---
# ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

# in case other parts of your code still use it.
func update_player_list():
	update_player_hud()

func update_network_info():
	var network_display = get_parent().get_node("RightUI/NetworkInfo/NetworkSideDisplay")
	if network_display:
		if multiplayer.is_server():
			network_display.text = "Server"
		else:
			network_display.text = "Client"

func _on_ui_update_timer():
	if show_fps and fps_label:
		fps_label.text = "FPS: " + str(Engine.get_frames_per_second())
	
	# Update player list periodically
	if multiplayer.is_server():
		update_player_list()

# ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
# ---     UI Event Handlers    ---
# ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

func _on_toggle_fps_pressed():
	show_fps = !show_fps
	if fps_label:
		fps_label.visible = show_fps

func _on_toggle_debug_pressed():
	if debug_panel:
		debug_panel.visible = !debug_panel.visible

func _on_player_selected(index: int):
	if multiplayer.is_server():
		var start_game_button = get_parent().get_node("StartGameButton")
		if start_game_button:
			start_game_button.disabled = false

func _on_zoom_in_pressed():
	var camera = get_parent().get_node("Camera3D")
	if camera:
		camera.zoom_in()

func _on_zoom_out_pressed():
	var camera = get_parent().get_node("Camera3D")
	if camera:
		camera.zoom_out()

# ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
# ---      Dialog Management   ---
# ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

func show_dialog(title: String, message: String):
	if current_dialog and is_instance_valid(current_dialog):
		current_dialog.queue_free()
	
	current_dialog = AcceptDialog.new()
	current_dialog.title = title
	current_dialog.dialog_text = message
	current_dialog.size = Vector2(400, 200)
	
	get_parent().add_child(current_dialog)
	current_dialog.popup_centered()

func show_confirmation_dialog(title: String, message: String, callback: Callable):
	if current_dialog and is_instance_valid(current_dialog):
		current_dialog.queue_free()
	
	var dialog = ConfirmationDialog.new()
	current_dialog = dialog
	dialog.title = title
	dialog.dialog_text = message
	dialog.size = Vector2(400, 200)
	
	# Connect confirmed signal to callback
	dialog.confirmed.connect(callback)
	
	get_parent().add_child(dialog)
	dialog.popup_centered()

# ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
# ---    Mobile UI Support     ---
# ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

func setup_mobile_controls():
	# Check if we're on a mobile platform
	var is_mobile = OS.has_feature("mobile")
	if !is_mobile:
		return
	
	# Show mobile-specific UI
	var mobile_controls = get_parent().get_node("MobileControls")
	if mobile_controls:
		mobile_controls.visible = true
	
	# Adjust UI scaling as needed
	get_viewport().size_override_stretch = true

func show_message(title: String, message: String, duration: float = 2.0):
	var message_panel = PanelContainer.new()
	var vbox = VBoxContainer.new()
	var title_label = Label.new()
	var message_label = Label.new()
	
	title_label.text = title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
	
	message_label.text = message
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	vbox.add_child(title_label)
	vbox.add_child(message_label)
	message_panel.add_child(vbox)
	
	message_panel.position = Vector2(
		(get_viewport().size.x - message_panel.size.x) / 2,
		get_viewport().size.y * 0.7
	)
	
	get_parent().add_child(message_panel)
	
	# Create a timer to remove the message
	var timer = Timer.new()
	message_panel.add_child(timer)
	timer.wait_time = duration
	timer.one_shot = true
	timer.timeout.connect(func(): message_panel.queue_free())
	timer.start()

# ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
# ---     Tooltip System      ---
# ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

var current_tooltip: PanelContainer
var tooltip_timer: Timer

func show_tooltip(text: String, position: Vector2):
	if current_tooltip and is_instance_valid(current_tooltip):
		current_tooltip.queue_free()
	
	# Create tooltip container
	current_tooltip = PanelContainer.new()
	var tooltip_label = Label.new()
	tooltip_label.text = text
	current_tooltip.add_child(tooltip_label)
	
	# Style the tooltip
	current_tooltip.add_theme_stylebox_override(
		"panel", 
		StyleBoxFlat.new()
	)
	var style = current_tooltip.get_theme_stylebox("panel")
	style.bg_color = Color(0.2, 0.2, 0.2, 0.9)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	
	# Position tooltip
	get_parent().add_child(current_tooltip)
	current_tooltip.position = position
	
	# Setup auto-hide timer
	if tooltip_timer and is_instance_valid(tooltip_timer):
		tooltip_timer.stop()
	else:
		tooltip_timer = Timer.new()
		get_parent().add_child(tooltip_timer)
		tooltip_timer.one_shot = true
	
	tooltip_timer.wait_time = 3.0  # Hide after 3 seconds
	tooltip_timer.timeout.connect(func(): hide_tooltip())
	tooltip_timer.start()

func hide_tooltip():
	if current_tooltip and is_instance_valid(current_tooltip):
		current_tooltip.queue_free()
		current_tooltip = null

# ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
# ---    Notification System   ---
# ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

var notification_queue = []
var current_notification
var notification_timer: Timer

func show_notification(text: String, duration: float = 2.0):
	# Add to queue
	notification_queue.append({"text": text, "duration": duration})
	
	# Process queue if no current notification
	if !current_notification:
		_process_next_notification()

func _process_next_notification():
	if notification_queue.size() == 0:
		return
	
	var next = notification_queue.pop_front()
	
	# Create notification
	var notification_panel = PanelContainer.new()
	var label = Label.new()
	label.text = next.text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notification_panel.add_child(label)
	
	# Style notification
	notification_panel.add_theme_stylebox_override(
		"panel", 
		StyleBoxFlat.new()
	)
	var style = notification_panel.get_theme_stylebox("panel")
	style.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	
	# Add to UI
	get_parent().add_child(notification_panel)
	
	# Position at top of screen
	await notification_panel.ready
	notification_panel.position = Vector2(
		(get_viewport().size.x - notification_panel.size.x) / 2,
		20
	)
	
	# Set as current notification
	current_notification = notification_panel
	
	# Setup hide timer
	if notification_timer and is_instance_valid(notification_timer):
		notification_timer.stop()
	else:
		notification_timer = Timer.new()
		get_parent().add_child(notification_timer)
		notification_timer.one_shot = true
	
	notification_timer.wait_time = next.duration
	notification_timer.timeout.connect(func(): 
		if current_notification and is_instance_valid(current_notification):
			current_notification.queue_free()
			current_notification = null
			# Process next notification if any
			_process_next_notification()
	)
	notification_timer.start()

# ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
# ---    Animation Controls    ---
# ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

func animate_bounce(node: Control, scale_amount: float = 1.2, duration: float = 0.3):
	if !node or !is_instance_valid(node):
		return
	
	var tween = create_tween().set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "scale", Vector2.ONE * scale_amount, duration / 2.0)
	tween.tween_property(node, "scale", Vector2.ONE, duration / 2.0)

func animate_fade(node: Control, from_alpha: float = 0.0, to_alpha: float = 1.0, duration: float = 0.5):
	if !node or !is_instance_valid(node):
		return
	
	var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var modulate_from = node.modulate
	var modulate_to = node.modulate
	
	modulate_from.a = from_alpha
	modulate_to.a = to_alpha
	
	node.modulate = modulate_from
	tween.tween_property(node, "modulate", modulate_to, duration)

func animate_slide(node: Control, from_pos: Vector2, to_pos: Vector2, duration: float = 0.5):
	if !node or !is_instance_valid(node):
		return
	
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	node.position = from_pos
	tween.tween_property(node, "position", to_pos, duration)
