extends Control

@onready var game = get_node("/root/Game")
@onready var animation_player = $AnimationPlayer

# --- Buttons ----------------------------------------------------
@onready var play_card_button := $VBoxContainer/PlayCardButton
@onready var play_elemental_face_down := $VBoxContainer/PlayElementalFaceDownButton
@onready var play_elemental_face_up := $VBoxContainer/PlayElementalFaceUpButton
@onready var buy_card_button := $VBoxContainer/BuyCardButton
@onready var play_extra_token_button := $VBoxContainer/PlayExtraTokenButton
@onready var play_sigil_magic_button := $VBoxContainer/PlaySigilMagicButton
@onready var buy_elemental_button := $VBoxContainer/BuyElementalButton
@onready var swap_elemental_button := $VBoxContainer/SwapElementalButton

# ----------------------------------------------------------------
# Mapping:  button  ->  minimum soil stars required to enable it
# This dictionary is now initialized in _ready() to ensure nodes are loaded.
var button_rules := {}
var is_playing_from_soil_star_action := false
var is_playing_extra_token_from_soil_star := false
var is_activating_sigil_from_soil_star := false

# ----------------------------------------------------------------
var is_panel_status : bool = false   # true when the panel is open

func _ready():
	# Initialize the dictionary here, after @onready vars are loaded.
	button_rules = {
		play_card_button         : 1,
		play_elemental_face_down : 1,
		play_elemental_face_up   : 2,
		buy_card_button          : 2,
		play_extra_token_button  : 3,
		play_sigil_magic_button  : 1,
		buy_elemental_button     : 4,
		swap_elemental_button    : 5,
	}
	connect_action_buttons()

# ----------------------------------------------------------------
# Connect all button-pressed signals to the simple print handlers
func connect_action_buttons():
	for btn in button_rules.keys():
		var signal_name = "_on_%s_pressed" % btn.name
		if has_method(signal_name):
			btn.pressed.connect(Callable(self, signal_name))
		else:
			printerr("Handler function not found for button: ", btn.name)


# ----------------------------------------------------------------
# Toggle the panel's visibility
func _show_hide_actions_panel():
	apply_button_rules()
	is_panel_status = !is_panel_status

	animation_player.play("show_actions" if is_panel_status else "hide_actions")
	_show_hide_right_ui_panel()

func _show_hide_right_ui_panel():
	for n in [game.token_button, game.end_phase_button, game.end_turn_button]:
		if n:
			n.visible = !is_panel_status

# ----------------------------------------------------------------
# Apply the star rules once per panel open
func apply_button_rules():
	var stars := _get_current_soil_star()
	for btn in button_rules.keys():
		btn.disabled = stars < button_rules[btn]

func _get_current_soil_star() -> int:
	var player_ui := _get_active_player_ui()
	if not player_ui:
		return 0
	var soil_star := player_ui.get_node_or_null("SoilStar")
	if not soil_star:
		printerr("SoilStar node not found in player UI.")
		return 0
	return soil_star.current_soil_star

func _get_active_player_ui() -> Control:
	var container := game.get_node_or_null("PlayerUIs")
	if not container:
		printerr("PlayerUIs node not found.")
		return null
	for child in container.get_children():
		if child.visible:
			return child
	printerr("No visible player UI found.")
	return null

# ----------------------------------------------------------------
# Handlers
func _on_PlayCardButton_pressed():                 
	print("play_card_button pressed")
	
	# Check for cost BEFORE allowing the action
	var cost = button_rules[play_card_button]
	var active_player_ui = _get_active_player_ui()
	if not active_player_ui: return
	
	var soil_star_node = active_player_ui.get_node_or_null("SoilStar")
	if not soil_star_node: return
	
	if soil_star_node.current_soil_star < cost:
		game.notification.show_instruction_label("Not enough Soil Stars!")
		get_tree().create_timer(2.0).timeout.connect(game.notification.hide_panel)
		return

	# Check if the player has cards in their hand.
	var hand = game.deck.hand
	if hand.cards.is_empty():
		game.notification.show_instruction_label("You have no cards to play.")
		get_tree().create_timer(2.0).timeout.connect(game.notification.hide_panel)
		return

	# Set the local flag to indicate this is a special card play.
	is_playing_from_soil_star_action = true
	
	# Instruct the player on what to do next.
	game.notification.show_instruction_label("Select a card from your hand, then drag it to a biome.")
	
	# Hide the actions panel to allow interaction with the game board.
	_show_hide_actions_panel()

func _on_PlayElementalFaceDownButton_pressed():   
	print("play_elemental_face_down_button pressed")

func _on_PlayElementalFaceUpButton_pressed():     
	print("play_elemental_face_up_button pressed")

func _on_BuyCardButton_pressed():                   
	print("buy_card_button pressed")
	
	# 1. Check if hand is full
	if game.card_manager.is_hand_full():
		game.notification.show_instruction_label("Your hand is full!")
		get_tree().create_timer(2.0).timeout.connect(game.notification.hide_panel)
		return
		
	# 2. Check for cost and deduct soil stars
	var cost = button_rules[buy_card_button]
	var active_player_ui = _get_active_player_ui()
	if not active_player_ui: return
	
	var soil_star_node = active_player_ui.get_node_or_null("SoilStar")
	if not soil_star_node: return
	
	if soil_star_node.current_soil_star < cost:
		game.notification.show_instruction_label("Not enough Soil Stars!")
		get_tree().create_timer(2.0).timeout.connect(game.notification.hide_panel)
		return
	
	# 3. All checks passed, perform the action
	soil_star_node.decrease_soil_star(cost)
	var card_drawn = game.deck.table.add_card()
	
	if card_drawn:
		game.notification.show_instruction_label("You drew a card!")
		get_tree().create_timer(2.0).timeout.connect(game.notification.hide_panel)
	else:
		game.notification.show_instruction_label("The deck is empty!")
		get_tree().create_timer(2.0).timeout.connect(game.notification.hide_panel)
		# If drawing failed, refund the stars.
		soil_star_node.increase_soil_star(cost)

	# 4. Close the panel
	_show_hide_actions_panel()

func _on_PlayExtraTokenButton_pressed():          
	print("play_extra_token_button pressed")

	# 1. Check cost
	var cost = button_rules[play_extra_token_button]
	var active_player_ui = _get_active_player_ui()
	if not active_player_ui: return
	
	var soil_star_node = active_player_ui.get_node_or_null("SoilStar")
	if not soil_star_node: return
	
	if soil_star_node.current_soil_star < cost:
		game.notification.show_instruction_label("Not enough Soil Stars!")
		get_tree().create_timer(2.0).timeout.connect(game.notification.hide_panel)
		return

	# 2. Check if player has tokens
	var player_id = multiplayer.get_unique_id()
	if game.token_manager.get_player_tokens(player_id).is_empty():
		game.notification.show_instruction_label("You have no tokens left to play!")
		get_tree().create_timer(2.0).timeout.connect(game.notification.hide_panel)
		return
	
	# 3. Deduct cost and set flag
	soil_star_node.decrease_soil_star(cost)
	is_playing_extra_token_from_soil_star = true
	
	# 4. Activate token placement mode and instruct player
	game.token_manager._on_token_selected()
	game.notification.show_instruction_label("Place your extra token on any valid location.")

	# 5. Close the panel
	_show_hide_actions_panel()

func _on_PlaySigilMagicButton_pressed():          
	print("play_sigil_magic_button pressed")

	# 1. Check cost
	var cost = button_rules[play_sigil_magic_button]
	var active_player_ui = _get_active_player_ui()
	if not active_player_ui: return
	
	var soil_star_node = active_player_ui.get_node_or_null("SoilStar")
	if not soil_star_node: return
	
	if soil_star_node.current_soil_star < cost:
		game.notification.show_instruction_label("Not enough Soil Stars!")
		get_tree().create_timer(2.0).timeout.connect(game.notification.hide_panel)
		return

	# 2. Check if there are any valid sigils to activate
	var player_id = multiplayer.get_unique_id()
	if not game.sigil_manager.player_has_activatable_sigils(player_id):
		game.notification.show_instruction_label("You have no sigil patterns to activate!")
		get_tree().create_timer(2.0).timeout.connect(game.notification.hide_panel)
		return
		
	# 3. Deduct cost and set flag
	soil_star_node.decrease_soil_star(cost)
	is_activating_sigil_from_soil_star = true
	
	# 4. Highlight valid tokens and instruct the player
	game.sigil_manager.highlight_activatable_sigil_tokens(player_id)
	game.notification.show_instruction_label("Select one of your highlighted energy tokens to activate a sigil.")
	
	# 5. Close the panel
	_show_hide_actions_panel()

func _on_BuyElementalButton_pressed():            
	print("buy_elemental_button pressed")

func _on_SwapElementalButton_pressed():           
	print("swap_elemental_button pressed")
