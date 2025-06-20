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

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Card System Variables
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
@onready var player_hand
@onready var action_deck
@onready var area_deck
@onready var action_area
@onready var area_zone

const MAX_ACTION_CARDS = 3
const MAX_AREA_CARDS = 1
const INITIAL_ACTION_CARDS = 2
const INITIAL_AREA_CARDS = 0

var deck: Array[CardResource] = [] # Structure to track placed cards
var placed_cards = []  # Array of dictionaries containing placement info

const INITIAL_HAND_SIZE = {
	"action": 0,  # Adjust these numbers as needed
	"area": 0
}

# Make sure these are consistent with the card types in CardResource
const CARD_TYPES = {
	"ACTION": 0,
	"AREA": 1
}

var active_card 

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Initialization
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
func _ready():
	# Get references to card-related nodes
	player_hand = get_parent().get_node("HandAreas/PlayerHand")
	action_deck = get_parent().get_node("DeckLocations/ActionDeck")
	area_deck = get_parent().get_node("DeckLocations/AreaDeck")
	action_area = get_parent().get_node("PlantingLocations/ActionArea")
	area_zone = get_parent().get_node("PlantingLocations/AreaZone")
	
	# Setup planting locations
	if action_area:
		action_area.accepted_card_types = PackedInt32Array([CardResource.CardType.ACTION])
		action_area.location_name = "Action Area"
		action_area.card_placed.connect(_on_card_placed)
	
	if area_zone:
		area_zone.accepted_card_types = PackedInt32Array([CardResource.CardType.AREA])
		area_zone.location_name = "Area Zone"
		area_zone.card_placed.connect(_on_card_placed)
	
	# Connect to deck signals
	if action_deck:
		action_deck.card_drawn.connect(_on_action_card_drawn)
	
	if area_deck:
		area_deck.card_drawn.connect(_on_area_card_drawn)
	
	# Connect discard button if it exists
	var discard_button = get_parent().get_node("DiscardCardButton")
	if discard_button:
		if discard_button.pressed.is_connected(_on_discard_card_button_pressed):
			discard_button.pressed.disconnect(_on_discard_card_button_pressed)
		discard_button.pressed.connect(_on_discard_card_button_pressed)
	
	# Connect draw buttons if they exist
	var draw_action_button = get_parent().get_node("DrawActionButton")
	if draw_action_button:
		if draw_action_button.pressed.is_connected(_on_draw_action_button_pressed):
			draw_action_button.pressed.disconnect(_on_draw_action_button_pressed)
		draw_action_button.pressed.connect(_on_draw_action_button_pressed)
	
	var draw_area_button = get_parent().get_node("DrawAreaButton")
	if draw_area_button:
		if draw_area_button.pressed.is_connected(_on_draw_area_button_pressed):
			draw_area_button.pressed.disconnect(_on_draw_area_button_pressed)
		draw_area_button.pressed.connect(_on_draw_area_button_pressed)
	
	# Setup area picking
	if action_area:
		_setup_area_picking(action_area)
	
	if area_zone:
		_setup_area_picking(area_zone)

# ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
# --- Card Distribution & Deck  ---
# ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

func distribute_initial_hand():
	if !multiplayer.is_server():
		return
		
	var host_id = multiplayer.get_unique_id()
	
	# Clear hand first
	player_hand.cards.clear()
	player_hand.card_resources.clear()
	game.player_hands[host_id].clear()
	
	# Track drawn cards to prevent duplicates
	var drawn_cards = []
	
	# Draw initial cards with validation
	for i in range(INITIAL_ACTION_CARDS):
		var card = action_deck.draw_card()
		while card and is_card_in_array(card, drawn_cards):
			action_deck.cards.append(card)  # Put the card back
			action_deck.shuffle()
			card = action_deck.draw_card()
		
		if card:
			drawn_cards.append(card)
			game.player_hands[host_id].append(card)
			player_hand.draw(card)
	
	for i in range(INITIAL_AREA_CARDS):
		var card = area_deck.draw_card()
		while card and is_card_in_array(card, drawn_cards):
			area_deck.cards.append(card)  # Put the card back
			area_deck.shuffle()
			card = area_deck.draw_card()
			
		if card:
			drawn_cards.append(card)
			game.player_hands[host_id].append(card)
			player_hand.draw(card)
			
	# Ensure the hand is synced with the game state
	player_hand.sync_with_game_state()

# Modify the distribute_initial_hand_to_client function
func distribute_initial_hand_to_client(peer_id: int):
	if !multiplayer.is_server():
		return
	
	print("distribute_initial_hand_to_client called for peer_id: ", peer_id)
	var host_id = multiplayer.get_unique_id()
	
	# Skip if this is the host ID
	if peer_id == host_id:
		print("Skipping distribute_initial_hand_to_client for host")
		return
	
	# Clear any existing hand data first
	if game.player_hands.has(peer_id):
		game.player_hands[peer_id].clear()
	else:
		game.player_hands[peer_id] = []
	
	var cards_data = []
	var action_count = 0
	var area_count = 0
	
	# Draw initial action cards
	while action_count < INITIAL_ACTION_CARDS:
		var card = action_deck.draw_card()
		if card:
			if !is_card_duplicate(cards_data, card):
				# ONLY add to server's tracking of client's hand
				game.player_hands[peer_id].append(card)
				cards_data.append(card.to_dictionary())
				action_count += 1
	
	# Draw initial area cards
	while area_count < INITIAL_AREA_CARDS:
		var card = area_deck.draw_card()
		if card:
			if !is_card_duplicate(cards_data, card):
				# ONLY add to server's tracking of client's hand
				game.player_hands[peer_id].append(card)
				cards_data.append(card.to_dictionary())
				area_count += 1
	
	# Send cards to client only if we have the correct number
	if cards_data.size() == (INITIAL_ACTION_CARDS + INITIAL_AREA_CARDS):
		print("Sending initial hand to client ", peer_id, ": ", cards_data.size(), " cards")
		get_parent().rpc_id(peer_id, "receive_initial_hand", cards_data)
		
		# Re-sync host's hand after giving cards to client
		if player_hand and player_hand.has_method("sync_with_game_state"):
			player_hand.sync_with_game_state()

func is_card_in_array(card: CardResource, array: Array) -> bool:
	for existing_card in array:
		if existing_card.card_name == card.card_name and \
		   existing_card.card_type == card.card_type and \
		   existing_card.cost_to_draw == card.cost_to_draw:
			return true
	return false

func is_card_duplicate(cards_data: Array, new_card: CardResource) -> bool:
	for card_data in cards_data:
		if card_data.card_name == new_card.card_name and \
		   card_data.card_type == new_card.card_type:
			return true
	return false

# ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
# ---     Card Management      ---
# ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

@rpc("any_peer", "call_local")
func receive_initial_hand(cards_data: Array):
	if multiplayer.is_server():
		return
	
	print("Client received initial hand with ", cards_data.size(), " cards")
	
	# Clear existing hand completely first
	player_hand.clear_hand()
	
	var action_count = 0
	var area_count = 0
	
	# Process received cards with type limits
	for card_data in cards_data:
		if action_count >= INITIAL_ACTION_CARDS and area_count >= INITIAL_AREA_CARDS:
			break
			
		var card_resource = CardResource.new()
		card_resource.from_dictionary(card_data)
		
		# Check card type limits
		if card_resource.card_type == CardResource.CardType.ACTION:
			if action_count < INITIAL_ACTION_CARDS:
				player_hand.draw(card_resource)
				action_count += 1
		else:  # AREA type
			if area_count < INITIAL_AREA_CARDS:
				player_hand.draw(card_resource)
				area_count += 1
	
	# Add to local tracking for clients
	var local_id = multiplayer.get_unique_id()
	if !game.player_hands.has(local_id):
		game.player_hands[local_id] = []
	else:
		game.player_hands[local_id].clear()
	
	# Copy cards to local tracking
	for card in player_hand.card_resources:
		game.player_hands[local_id].append(card)
	
	print("Received initial hand: ", player_hand.card_resources.size(), " cards")
	print("Action cards: ", action_count, ", Area cards: ", area_count)
	print("Local tracking updated, player_hands size: ", game.player_hands.size())

@rpc("any_peer")
func request_initial_cards():
	if multiplayer.is_server():
		var requesting_peer = multiplayer.get_remote_sender_id()
		print("Client ", requesting_peer, " requested initial cards")
		
		# Check if this player already has cards tracked on the server
		if game.player_hands.has(requesting_peer) and game.player_hands[requesting_peer].size() > 0:
			print("Using existing cards for client ", requesting_peer)
			var cards_data = []
			for card in game.player_hands[requesting_peer]:
				cards_data.append(card.to_dictionary())
			get_parent().rpc_id(requesting_peer, "receive_initial_hand", cards_data)
		else:
			# Distribute new cards
			print("Distributing new cards to client ", requesting_peer)
			distribute_initial_hand_to_client(requesting_peer)

@rpc("any_peer", "call_local")
func sync_card_played(card_data: Dictionary, slot_index: int, location_name: String, player_id: int) -> void:
	# Find the correct location node
	var locations = {
		"Action Area": action_area,
		"Area Zone": area_zone
	}
	
	var location = locations.get(location_name)
	if location:
		var card_resource = CardResource.new()
		card_resource.from_dictionary(card_data)
		location.plant_card(card_resource, slot_index)
	else:
		pass

func remove_card_from_player_hand(player_id: int, card_index: int) -> void:
	if !game.player_hands.has(player_id):
		return
		
	if card_index >= 0 and card_index < game.player_hands[player_id].size():
		game.player_hands[player_id].remove_at(card_index)
		#print("Removed card at index ", card_index, " from player ", player_id, "'s hand")

func remove_card_from_hand(player_id: int, card: CardResource) -> void:
	if !game.player_hands.has(player_id):
		return
		
	var hand = game.player_hands[player_id]
	for i in range(hand.size()):
		if hand[i].card_name == card.card_name and hand[i].card_type == card.card_type:
			hand.remove_at(i)
			break

func validate_hand_sync(peer_id: int) -> bool:
	if !game.player_hands.has(peer_id):
		return false
		
	if multiplayer.is_server():
		# Server validation
		var server_cards = game.player_hands[peer_id].size()
		return server_cards == (INITIAL_ACTION_CARDS + INITIAL_AREA_CARDS)
	else:
		# Client validation
		var client_cards = player_hand.card_resources.size()
		return client_cards == (INITIAL_ACTION_CARDS + INITIAL_AREA_CARDS)

func resync_hand_locally() -> void:
	if multiplayer.is_server():
		var host_id = multiplayer.get_unique_id()
		if game.player_hands.has(host_id):
			var cards_data = []
			for card in game.player_hands[host_id]:
				cards_data.append(card.to_dictionary())
			receive_initial_hand(cards_data)

func count_cards_by_type(type: int) -> int:
	var count = 0
	for card in player_hand.card_resources:
		if card.card_type == type:
			count += 1
	return count

func count_cards_by_type_for_player(player_id: int, type: int) -> int:
	if !game.player_hands.has(player_id):
		return 0
		
	var count = 0
	for card in game.player_hands[player_id]:
		if card.card_type == type:
			count += 1
	return count

func can_draw_card(card_type: int) -> bool:
	var current_count = count_cards_by_type(card_type)
	var max_count = MAX_ACTION_CARDS if card_type == CardResource.CardType.ACTION else MAX_AREA_CARDS
	return current_count < max_count

@rpc("any_peer")
func request_card_placement(card_data: Dictionary, slot_index: int, location_name: String, player_id: int) -> void:
	if !multiplayer.is_server():
		return
		
	# Validate it's the player's turn
	if !game_state_manager.is_valid_player_turn(player_id):
		return
		
	var card_resource = CardResource.new()
	card_resource.from_dictionary(card_data)
	
	# Remove card from server's tracking of player's hand
	remove_card_from_hand(player_id, card_resource)
	
	# Broadcast placement to all clients
	get_parent().rpc("sync_card_played", card_data, slot_index, location_name, player_id)

# ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
# --- Card Drawing & Discarding ---
# ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

@rpc("any_peer", "call_local")
func sync_draw_card(card_data: Dictionary) -> void:
	# Only process if it's meant for the current player's turn
	var players = game.players
	var current_turn_index = game.game_state_manager.current_turn_index
	var current_player = players[current_turn_index]
	var local_id = multiplayer.get_unique_id()
	
	print("sync_draw_card called for player: ", local_id, ", current player turn: ", current_player)
	
	if local_id != current_player:
		print("Not my turn to draw, ignoring card sync")
		return
	
	# Prevent duplicate draws
	for existing_card in player_hand.card_resources:
		if existing_card.card_name == card_data.card_name:
			print("Duplicate card detected in sync_draw_card, ignoring: ", card_data.card_name)
			return
	
	var card_resource = CardResource.new()
	card_resource.from_dictionary(card_data)
	player_hand.draw(card_resource)

@rpc("any_peer")
func request_draw_card(is_action: bool):
	if !multiplayer.is_server():
		return

	var requesting_peer = multiplayer.get_remote_sender_id()
	var players = game.players
	var current_turn_index = game.current_turn_index
	
	# Validate turn ownership
	if players[current_turn_index] != requesting_peer:
		print("Not your turn to draw!")
		return
	
	var current_count = count_cards_by_type_for_player(
		requesting_peer,
		CardResource.CardType.ACTION if is_action else CardResource.CardType.AREA
	)
	
	var max_count = MAX_ACTION_CARDS if is_action else MAX_AREA_CARDS
	if current_count >= max_count:
		print("Max cards of type ", (CardResource.CardType.ACTION if is_action else CardResource.CardType.AREA), " reached")
		return
		
	var deck = action_deck if is_action else area_deck
	var card = deck.draw_card()
	
	if card:
		# Add to server's tracking
		game.player_hands[requesting_peer].append(card)
		# Send only to the requesting player
		get_parent().rpc_id(requesting_peer, "sync_draw_card", card.to_dictionary())

@rpc("any_peer", "call_local")
func sync_discard_card():
	player_hand.discard()

@rpc("any_peer")
func request_discard_cards():
	if multiplayer.is_server():
		get_parent().rpc("sync_discard_card")

@rpc("any_peer", "call_local")
func sync_remove_card(index: int, player_id: int):
	# Only process if this is for the local player
	if player_id == multiplayer.get_unique_id():
		if player_hand and index >= 0 and index < player_hand.card_resources.size():
			player_hand.card_resources.remove_at(index)
			player_hand._update_cards()
		
		# Update server's tracking if we are the server
		if multiplayer.is_server() and game.player_hands.has(player_id):
			if index >= 0 and index < game.player_hands[player_id].size():
				game.player_hands[player_id].remove_at(index)

@rpc("any_peer", "call_local")
func sync_remove_played_card(card_data: Dictionary, player_id: int):
	# Only process if this is for the local player
	if player_id == multiplayer.get_unique_id():
		var card_resource = CardResource.new()
		card_resource.from_dictionary(card_data)
		remove_local_card(card_resource)

func remove_local_card(card: CardResource):
	for i in range(player_hand.card_resources.size()):
		var existing = player_hand.card_resources[i]
		if existing.card_name == card.card_name and existing.card_type == card.card_type:
			player_hand.card_resources.remove_at(i)
			break
	player_hand._update_cards()

@rpc("any_peer")
func request_hand_resync():
	if !multiplayer.is_server():
		return
		
	var requesting_peer = multiplayer.get_remote_sender_id()
	if game.player_hands.has(requesting_peer):
		var cards_data = []
		for card in game.player_hands[requesting_peer]:
			cards_data.append(card.to_dictionary())
		get_parent().rpc_id(requesting_peer, "receive_initial_hand", cards_data)

# ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
# ---   Card Event Handlers    ---
# ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

func _on_card_placed(card: CardResource, slot_index: int, location_name: String) -> void:
	var current_player = multiplayer.get_unique_id()
	
	if !game_state_manager.is_valid_player_turn(current_player):
		return
	
	if multiplayer.is_server():
		# Store the card placement
		var placement_data = {
			"card_data": card.to_dictionary(),
			"slot_index": slot_index,
			"location_name": location_name,
			"player_id": current_player
		}
		placed_cards.append(placement_data)
		
		# Remove card from server's hand tracking
		remove_card_from_hand(current_player, card)
		
		# Broadcast placement to all clients
		get_parent().rpc("sync_card_played", card.to_dictionary(), slot_index, location_name, current_player)
	else:
		# Client requests server to validate placement
		get_parent().rpc_id(1, "request_card_placement", card.to_dictionary(), slot_index, location_name, current_player)

func _on_action_card_drawn(card: CardResource):
	if not card:
		return
		
	if multiplayer.is_server() and game.game_started:
		get_parent().rpc("sync_draw_card", card.to_dictionary())

func _on_area_card_drawn(card: CardResource):
	if not card:
		return
		
	if multiplayer.is_server() and game.game_started:
		get_parent().rpc("sync_draw_card", card.to_dictionary())

func _on_discard_card_button_pressed() -> void:
	if multiplayer.is_server():
		get_parent().rpc("sync_discard_card")
	else:
		get_parent().rpc_id(1, "request_discard_cards")

func _on_draw_action_button_pressed():
	var player_id = multiplayer.get_unique_id()
	
	# Check if it's the player's turn
	if !game_state_manager.is_valid_player_turn(player_id):
		print("Not your turn to draw!")
		return
	
	var current_count = count_cards_by_type(CardResource.CardType.ACTION)
	if current_count >= MAX_ACTION_CARDS:
		return
		
	if multiplayer.is_server():
		var card = action_deck.draw_card()
		if card:
			# Add to server's tracking
			game.player_hands[player_id].append(card)
			# Only sync to the current player
			get_parent().rpc_id(player_id, "sync_draw_card", card.to_dictionary())
			# Update local hand if server is the current player
			if player_id == multiplayer.get_unique_id():
				player_hand.draw(card)
	else:
		get_parent().rpc_id(1, "request_draw_card", true)

func _on_draw_area_button_pressed():
	var player_id = multiplayer.get_unique_id()
	
	# Check if it's the player's turn
	if !game_state_manager.is_valid_player_turn(player_id):
		print("Not your turn to draw!")
		return
	
	var current_count = count_cards_by_type(CardResource.CardType.AREA)
	if current_count >= MAX_AREA_CARDS:
		return
		
	if multiplayer.is_server():
		var card = area_deck.draw_card()
		if card:
			# Add to server's tracking
			game.player_hands[player_id].append(card)
			# Only sync to the current player
			get_parent().rpc_id(player_id, "sync_draw_card", card.to_dictionary())
			# Update local hand if server is the current player
			if player_id == multiplayer.get_unique_id():
				player_hand.draw(card)
	else:
		get_parent().rpc_id(1, "request_draw_card", false)

# ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
# ---   Card Utility Methods   ---
# ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

func _setup_area_picking(node: Node) -> void:
	if node is Area3D:
		node.input_ray_pickable = true
		node.collision_layer = 1
		node.collision_mask = 1
	for child in node.get_children():
		_setup_area_picking(child)

func print_hand_debug():
	var player_id = multiplayer.get_unique_id()
	print("\n=== Hand Debug ===")
	print("Player ID: ", player_id)
	print("Cards in hand: ", player_hand.get_card_count())
	print("Card resources: ", player_hand.card_resources.size())
	print("=================\n")


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
