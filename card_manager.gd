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
var max_hand_size = 3  # Maximum cards a player can hold
var initial_hand_size = 2  # Starting cards for each player
var network_synced = true

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Initialization
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
func _ready():
	# Get references to card-related nodes
	player_hand = deck.hand

func initialize_starting_hand():
	print("Initializing starting hand with", initial_hand_size, "cards")
	# Get a reference to the player's hand
	player_hand = deck.hand
	
	# Make sure hand is empty before initializing
	if player_hand and player_hand.cards.size() > 0:
		print("Hand already has cards, skipping initialization")
		return
	
	# Draw the initial cards - should be 2
	for i in range(initial_hand_size):
		var success = draw_card()
		if success:
			# Verify the card IDs of the cards in the hand
			var last_card = player_hand.cards[player_hand.cards.size() - 1]
			print("Added initial card with card_id:", last_card.card_id)

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
		# Use the table's add_card method to draw a card
		# The network sync is handled inside add_card(), so we don't need to do it here
		var success = deck.table.add_card()
		return success
	else:
		print("Hand is full! Maximum cards:", max_hand_size)
		return false

func draw_specific_card(card_index: int):
	player_hand = deck.hand
	if player_hand.cards.size() < max_hand_size:
		var card = deck.table.instantiate_face_card(card_index)
		if card:
			player_hand.append_card(card)
			card.global_position = deck.global_position
			return true
		return false
	else:
		print("Hand is full! Cannot draw more cards.")
		return false

# Add this method for when a card is actually drawn
func sync_card_drawn(card_index: int):
	if network_synced and network_manager:
		network_manager.sync_card_drawn(card_index)

# ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
# ---   Card Event Handlers    ---
# ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
func execute_card_effect(card_id: int):
	print("Executing card effect for card ID: ", card_id)
	
	match card_id:
		0: # Unblight Our Own Token
			unblight_card_effect()
		1: # Take Off enemy or our energy token
			take_off_card_effect()
		2: # Swap Energy
			swap_energy_card_effect()
		3: # Refresh Energy
			refresh_energy_card_effect()
		4: # Plant Extra Token or Energy
			plant_extra_card_effect()
		_:
			print("Unknown card ID: ", card_id)

# ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
# ---   Card Utility Methods   ---
# ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
func create_remote_card(card_data: Dictionary, biome_slot: int) -> FaceCard3D:
	var card_id = card_data["card_id"] if card_data.has("card_id") else -1
	
	# Create the card instance
	var face_card = deck.table.instantiate_face_card(card_id)
	if !face_card:
		print("Failed to instantiate remote card")
		return null
	
	face_card.card_on_biome = biome_slot
	
	return face_card

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
