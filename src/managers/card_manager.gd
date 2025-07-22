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

# Add variables for card effects
var is_take_off_mode := false
var is_unblight_mode := false
var is_refresh_energy_mode := false
var is_swap_energy_mode := false  
var is_plant_extra := false

var first_swap_token = null  


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

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Start of Card Effect Logic
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
func unblight_card_effect():
	print("unblight card effect")
	is_unblight_mode = true
	
	# Ensure token selection mode is off
	token_manager.is_token_selected = false
	# Highlight our token.is_blighted
	var tokens = token_manager.tokens
	var player_id = multiplayer.get_unique_id()
	for token in tokens.get_children():
		if !token.is_energy and token.owner_id == player_id and token.is_blighted:
			token.outerglow.show()
	
	token_manager.unhighlight_all_token_placements()
	token_manager.update_token_ui()

func take_off_card_effect():
	print("take off card effect")
	is_take_off_mode = true

	# Ensure token selection mode is off
	token_manager.is_token_selected = false
	
	# Highlight our token.is_blighted
	var tokens = token_manager.tokens
	for token in tokens.get_children():
		if token.is_energy:
			token.outerglow.show()
	
	token_manager.unhighlight_all_token_placements()
	token_manager.update_token_ui()

func refresh_energy_card_effect():
	print("refresh energy card effect")
	is_refresh_energy_mode = true
	
	# Ensure token selection mode is off
	token_manager.is_token_selected = false
	
	# Highlight our token.is_blighted
	var tokens = token_manager.tokens
	var player_id = multiplayer.get_unique_id()
	for token in tokens.get_children():
		if token.is_energy and token.owner_id == player_id and token.is_blighted:
			token.outerglow.show()
	
	token_manager.unhighlight_all_token_placements()
	token_manager.update_token_ui()

func swap_energy_card_effect():
	print("swap energy card effect")
	is_swap_energy_mode = true
	is_take_off_mode = false
	is_unblight_mode = false
	is_refresh_energy_mode = false
	first_swap_token = null  # Reset first token selection
	
	# Ensure token selection mode is off
	token_manager.is_token_selected = false
	
	# Highlight our token.is_blighted
	var tokens = token_manager.tokens
	var player_id = multiplayer.get_unique_id()
	for token in tokens.get_children():
		if token.is_energy and token.owner_id == player_id:
			token.outerglow.show()
	
	token_manager.unhighlight_all_token_placements()
	token_manager.update_token_ui()

func plant_extra_card_effect():
	print("plant extra token card effect")
	var player_id = multiplayer.get_unique_id()
	
	# Temporarily increase max tokens per turn by 1
	token_manager.max_tokens_per_turn += 1
	
	# Set the plant extra flag
	is_plant_extra = true
	
	# Enable placing on both sigil and biome locations
	token_manager.can_plant_on_sigil = true
	token_manager.can_plant_on_biome = true
	
	# Sync changes to all clients if we're the server
	if multiplayer.is_server():
		token_manager.rpc("sync_token_planting_state", player_id, token_manager.tokens_planted_this_turn.get(player_id, 0), 
			true, true, token_manager.max_tokens_per_turn)
	else:
		# Request server to sync our changes
		token_manager.rpc_id(1, "request_token_planting_state_update", player_id, true, true, token_manager.max_tokens_per_turn)
	
	# Update UI to show token button as active
	token_manager.update_token_ui()
