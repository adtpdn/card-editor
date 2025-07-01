# card_manager.gd
extends Node

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# References to other managers
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
@onready var game = get_parent()
@onready var sigil_manager = $"../SigilManager"
@onready var token_manager = $"../TokenManager"
@onready var network_manager = $"../NetworkManager"
@onready var game_state_manager = $"../GameStateManager" 
@onready var ui_manager = $"../UIManager"
@onready var point_counter = $"../PointCounter"
@onready var deck = $"../Deck"


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Card System Variables
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
@onready var player_hand

var active_card 
var max_hand_size = 3
var network_synced = true

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Initialization
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
func initialize_starting_hand():
	# Draw 2 cards for the starting hand
	for i in range(1):
		draw_card()

# ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
# --- Card Distribution & Deck  ---
# ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
func is_hand_full():
	return player_hand.cards.size() >= max_hand_size

# ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
# ---     Card Management      ---
# ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛


# ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
# --- Card Drawing & Discarding ---
# ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
func draw_card():
	player_hand = deck.hand
	if player_hand.cards.size() < max_hand_size:
		deck.table.add_card()
		if network_synced and network_manager:
			network_manager.sync_card_draw()
		return true
	else:
		print("Hand is full! Cannot draw more cards.")
		return false

# ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
# ---   Card Event Handlers    ---
# ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛


# ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
# ---   Card Utility Methods   ---
# ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛


# ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
# ---        Card Effects      ---
# ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
func unblight_card_effect():
	print("unblight card effect")
	token_manager._on_unblight_token()

func take_off_card_effect():
	print("take off card effect")
	token_manager._on_take_off_energy()

func refresh_energy_card_effect():
	print("refresh energy card effect")
	token_manager._on_refresh_energy()

func swap_energy_card_effect():
	print("swap energy card effect")
	token_manager._on_swap_energy()

func plant_extra_card_effect():
	print("plant extra token card effect")
	token_manager._on_plant_extra_token()
