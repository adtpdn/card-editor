extends Control

@onready var game = get_node("/root/Game")
@onready var animation_player = $AnimationPlayer

# --- Buttons ----------------------------------------------------
@onready var play_card_button = $CardButtons/PlayCardButton
@onready var buy_card_button = $CardButtons/BuyCardButton
@onready var play_extra_token_button = $CardButtons/PlayExtraTokenButton
@onready var play_sigil_magic_button = $CardButtons/PlaySigilMagicButton
@onready var play_elemental_face_down_button = $ElementalButtons/PlayElementalFaceDownButton
@onready var play_elemental_face_up_button = $ElementalButtons/PlayElementalFaceUpButton
@onready var buy_elemental_button = $ElementalButtons/BuyElementalButton
@onready var swap_elemental_button = $ElementalButtons/SwapElementalButton
@onready var switch_button = $SwitchButton


# ----------------------------------------------------------------
# Mapping:  button  ->  minimum soil stars required to enable it
# This dictionary is now initialized in _ready() to ensure nodes are loaded.
var button_rules : Dictionary= {}
var is_buy_action_card : bool = false
var is_playing_from_soil_star_action : bool = false
var is_playing_extra_token_from_soil_star : bool= false
var is_activating_sigil_from_soil_star : bool= false
var is_swapping_elemental :bool = false 
var is_swapping_elemental_face_up: bool = false
var is_swapping_planted_elementals: bool = false

# ----------------------------------------------------------------
var is_panel_status : bool = false   # true when the panel is open
var is_action_buy_card : bool = false 
var is_switch_button : bool = false

func _ready():
	# Initialize the dictionary here, after @onready vars are loaded.
	button_rules = {
		play_card_button         : 1,
		play_elemental_face_down_button : 1,
		play_elemental_face_up_button   : 2,
		buy_card_button          : 2,
		play_extra_token_button  : 3,
		play_sigil_magic_button  : 3,
		buy_elemental_button     : 4,
		swap_elemental_button    : 5,
	}
	connect_action_buttons()
	switch_button.pressed.connect(switch_button_pressed)
	hide()

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
	for n in [game.token_button, game.end_phase_button, game.end_turn_button, game.token_texture]:
		if n:
			n.visible = !is_panel_status

# ----------------------------------------------------------------
# Apply the star rules once per panel open
func apply_button_rules():
	# First, check if it's the player's turn. If not, disable all buttons and exit.
	var local_player_id = multiplayer.get_unique_id()
	if not game.game_state_manager.is_valid_player_turn(local_player_id):
		for btn in button_rules.keys():
			btn.disabled = true
		return
	
	var stars := _get_current_soil_star()
	for btn in button_rules.keys():
		btn.disabled = stars < button_rules[btn]
	
	plant_extra_button_rule()
	elementals_face_swap_button()
	check_buy_elemental_button()

func elementals_face_swap_button():
	var hand = game.deck.hand

	if hand.cards.is_empty():
		play_elemental_face_down_button.disabled = true
		play_elemental_face_up_button.disabled = true
		return

	# Checking if there's elemental card in hand 
	var stars := _get_current_soil_star()
	for card in hand.get_children():
		if card is FaceCard3D:
			if card.card_type == CardResource.CardType.ELEMENTAL and stars >= 1 and stars < 2:
				play_elemental_face_down_button.disabled = false
				break
			elif card.card_type == CardResource.CardType.ELEMENTAL and stars >= 2:
				play_elemental_face_down_button.disabled = false
				play_elemental_face_up_button.disabled = false
				break
			else:
				play_elemental_face_down_button.disabled = true
				play_elemental_face_up_button.disabled = true

func check_buy_elemental_button():
	var hand = game.deck.hand
	# Checking if there's elemental card in hand 
	for card in hand.get_children():
		if card is FaceCard3D and card.card_type == CardResource.CardType.ELEMENTAL:
			buy_elemental_button.disabled = true
			return true

func plant_extra_button_rule():
	var token_manager = game.token_manager
	var player_id = multiplayer.get_unique_id()
	var tokens_player = token_manager.get_player_tokens(player_id) # Array
	if tokens_player.size() == 0:
		play_extra_token_button.disabled = true

# This function is called whenever the soil star count changes.
func _on_soil_star_changed(new_count: int):
	# If the panel is currently open and the star count changes,
	# [cite_start]re-evaluate which buttons should be enabled. [cite: 539]
	if is_panel_status:
		apply_button_rules()

# This helper ensures we are always connected to the active player's signal.
func _connect_to_soil_star_signal():
	var active_player_ui = _get_active_player_ui()
	if active_player_ui:
		var soil_star_node = active_player_ui.get_node_or_null("SoilStar")
		# [cite_start]Connect the signal if it's not already connected. [cite: 541]
		if soil_star_node and not soil_star_node.is_connected("soil_star_changed", Callable(self, "_on_soil_star_changed")):
			soil_star_node.soil_star_changed.connect(Callable(self, "_on_soil_star_changed"))

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
	#printerr("No visible player UI found.")
	return null

func _check_elements_button():
	apply_button_rules()

func switch_button_pressed():
	
	print("switch button : ", is_switch_button)
	if is_switch_button:
		animation_player.play("show_card_actions")
	else:
		animation_player.play("show_elemental_actions")
	
	apply_button_rules()
	is_switch_button = !is_switch_button

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

	# 1. Check cost
	var cost = button_rules[play_elemental_face_down_button]
	var active_player_ui = _get_active_player_ui()
	if not active_player_ui: return

	var soil_star_node = active_player_ui.get_node_or_null("SoilStar")
	if not soil_star_node: return

	if soil_star_node.current_soil_star < cost:
		game.notification.show_instruction_label("Not enough Soil Stars!")
		get_tree().create_timer(2.0).timeout.connect(game.notification.hide_panel)
		return

	# 2. Check if hand has a face-down elemental card
	var hand = game.deck.hand
	var has_valid_card = false
	for card in hand.cards:
		if card is FaceCard3D and card.card_type == CardResource.CardType.ELEMENTAL:
			has_valid_card = true
			break
	
	if not has_valid_card:
		game.notification.show_instruction_label("You have no face-down elemental cards to play.")
		get_tree().create_timer(2.0).timeout.connect(game.notification.hide_panel)
		return

	# 3. Deduct cost, set the flag, and instruct the player
	soil_star_node.decrease_soil_star(cost)
	is_swapping_elemental = true
	#game.card_manager.hand_card_for_swap = null # Reset any previously selected card
	game.notification.show_instruction_label("Select an elemental from your hand.")

	# 4. Hide the actions panel to allow board interaction
	_show_hide_actions_panel()


func _on_PlayElementalFaceUpButton_pressed():     
	print("play_elemental_face_up_button pressed")

	# 1. Check cost
	var cost = button_rules[play_elemental_face_up_button]
	var active_player_ui = _get_active_player_ui()
	if not active_player_ui: return

	var soil_star_node = active_player_ui.get_node_or_null("SoilStar")
	if not soil_star_node: return

	if soil_star_node.current_soil_star < cost:
		game.notification.show_instruction_label("Not enough Soil Stars!")
		get_tree().create_timer(2.0).timeout.connect(game.notification.hide_panel)
		return

	# 2. Check if hand has a face-up elemental card
	var hand = game.deck.hand
	var has_valid_card = false
	for card in hand.cards:
		if card is FaceCard3D and card.card_type == CardResource.CardType.ELEMENTAL and not card.face_down:
			has_valid_card = true
			break
	
	if not has_valid_card:
		game.notification.show_instruction_label("You have no face-up elemental cards to play.")
		get_tree().create_timer(2.0).timeout.connect(game.notification.hide_panel)
		return

	# 3. Deduct cost, set the flag, and instruct the player
	soil_star_node.decrease_soil_star(cost)
	is_swapping_elemental_face_up = true
	#game.card_manager.hand_card_for_swap = null # Reset any previously selected card
	game.notification.show_instruction_label("Select an elemental from your hand.")

	# 4. Hide the actions panel to allow board interaction
	_show_hide_actions_panel()

func _on_BuyCardButton_pressed():                   
	print("buy_card_button pressed")
	var turn_phase_manager = game.turn_phase_manager
	
	var player_id = multiplayer.get_unique_id()
	# 1. Check if hand is full
	if game.card_manager.is_action_hand_full(player_id):
		game.notification.show_instruction_label("Your action card hand is full!")
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
	#turn_phase_manager.sigil_placed = false
	is_action_buy_card = true
	# This now calls the same logic as clicking the deck
	game.deck.table._on_action_deck_pressed()

	# turn_phase_manager.sigil_placed = true
	# 3. All checks passed, perform the action
	soil_star_node.decrease_soil_star(cost)

	# 4. Close the panel
	_show_hide_actions_panel()

func _on_PlayExtraTokenButton_pressed():          
	print("play_extra_token_button pressed")

	var token_manager = game.token_manager
	var player_id = multiplayer.get_unique_id()
	var tokens_player = token_manager.get_player_tokens(player_id) # Array
	if tokens_player.size() == 0:
		return

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
	print("Buy Elemental Button pressed")
	var cost = button_rules[buy_elemental_button]

	# Checking if there's elemental card in hand 
	var elemental_on_hand = check_buy_elemental_button()
	if elemental_on_hand:
		return

	var local_player_id = multiplayer.get_unique_id()
	# 1. Client-side validation: Check hand size first.
	if game.card_manager.is_elemental_hand_full(local_player_id):
		game.notification.show_instruction_label("Your elemental hand is full!")
		get_tree().create_timer(2.0).timeout.connect(game.notification.hide_panel)
		return

	# 2. Client-side validation: Check if the player has enough stars.
	if _get_current_soil_star() < cost:
		game.notification.show_instruction_label("Not enough Soil Stars!")
		get_tree().create_timer(2.0).timeout.connect(game.notification.hide_panel)
		return

	# 3. If all local checks pass, call the new centralized drawing function.
	var table = get_node("/root/Game/Deck/Table")
	if is_instance_valid(table):
		table.draw_local_elemental_card(cost)
	
	# 4. Close the actions panel.
	_show_hide_actions_panel()

func _on_SwapElementalButton_pressed():
	print("swap_elemental_button pressed")

	# 1. Check cost
	var cost = button_rules[swap_elemental_button]
	var active_player_ui = _get_active_player_ui()
	if not active_player_ui: return

	var soil_star_node = active_player_ui.get_node_or_null("SoilStar")
	if not soil_star_node: return

	if soil_star_node.current_soil_star < cost:
		game.notification.show_instruction_label("Not enough Soil Stars!")
		get_tree().create_timer(2.0).timeout.connect(game.notification.hide_panel)
		return

	# 2. Check if there are at least two swappable elementals on the board
	var player_id = multiplayer.get_unique_id()
	var swappable_cards = 0
	var drag_controller = get_node("/root/Game/Deck/Table/DragController")
	for i in range(1, 9): # elemental_slice_1 to elemental_slice_8
		var slice_node = drag_controller.get_node_or_null("elemental_slice_" + str(i))
		if slice_node and not slice_node.cards.is_empty():
			var card = slice_node.cards[0]
			print('card : ', card)
			# Card must be a face-up elemental owned by the player
			if card is FaceCard3D:
				swappable_cards += 1

	if swappable_cards < 2:
		game.notification.show_instruction_label("You need at least two elementals on the board to swap.")
		get_tree().create_timer(3.5).timeout.connect(game.notification.hide_panel)
		return

	# 3. Deduct cost, set the flag, and instruct the player
	soil_star_node.decrease_soil_star(cost)
	is_swapping_planted_elementals = true
	game.card_manager.first_selected_card_for_swap = null # Reset any previously selected card
	game.notification.show_instruction_label("Select the first elemental on the board to swap.")

	# 4. Highlight valid cards
	for i in range(1, 9):
		var slice_node = drag_controller.get_node_or_null("elemental_slice_" + str(i))
		if slice_node and not slice_node.cards.is_empty():
			var card = slice_node.cards[0]
			if card is FaceCard3D:
				card.set_hovered() # Use hover effect for highlighting

	# 5. Hide the actions panel to allow board interaction
	_show_hide_actions_panel()
