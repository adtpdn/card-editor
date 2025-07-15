extends Control

@onready var panel = $Panel
@onready var player_turn_label = $Panel/PlayerTurnLabel
@onready var game = $".."
@onready var game_state_manager = $"../GameStateManager"

var last_player_id = -1  # Track the last player ID to detect changes
var update_timer = null

# Add a dictionary to store player names
var player_names = {}

func _ready():
	# Set up the timer for periodic checks
	update_timer = Timer.new()
	add_child(update_timer)
	update_timer.wait_time = 0.5
	update_timer.timeout.connect(_check_for_turn_changes)
	update_timer.start()
	
	# Connect to network manager's peer_connected signal to get player names
	if game.has_node("NetworkManager"):
		var network_manager = game.get_node("NetworkManager")
		if network_manager.multiplayer_peer and !network_manager.multiplayer_peer.peer_connected.is_connected(_on_peer_connected):
			network_manager.multiplayer_peer.peer_connected.connect(_on_peer_connected)
	
	# Initial update
	update_turn_display()
	
	# Request player names when joining a game
	if !game.multiplayer.is_server():
		request_player_names()

func _on_peer_connected(peer_id):
	# When a new peer connects, exchange player names
	#if game.multiplayer.is_server():
		## Send our name to the new peer
		#send_player_name(peer_id)
	#else:
		## Request names from the server
		#request_player_names()
	pass

func get_player_name_from_id(player_id):
	# Generate a name based on player ID
	var local_id = game.multiplayer.get_unique_id()
	
	if player_id == local_id:
		return "You"
	
	# For other players, use their position in the player array if available
	var player_index = game.players.find(player_id)
	if player_index != -1:
		#return "Player " + str(player_index + 1) # 
		return "Player " + str(player_id)
	else:
		return "Player " + str(player_id)

func _check_for_turn_changes():
	if !game_state_manager:
		return
		
	var current_player_id = game_state_manager.get_current_player_id()
	if current_player_id != last_player_id:
		last_player_id = current_player_id
		update_turn_display()
		print("Turn changed to player: " + str(current_player_id))

func update_turn_display():
	if !game_state_manager:
		print("ERROR: No game_state_manager when updating turn display")
		return
		
	var current_player_id = game_state_manager.get_current_player_id()
	if current_player_id == -1:
		player_turn_label.text = "Waiting for game..."
		panel.modulate = Color(0.5, 0.5, 0.5, 1.0)  # Gray when waiting
		return
	
	print("Updating turn display for player: " + str(current_player_id))
	
	var local_player_id = game.multiplayer.get_unique_id()
	var is_my_turn = (current_player_id == local_player_id)
	
	# Update label text
	if is_my_turn:
		player_turn_label.text = "YOUR TURN"
		panel.modulate = Color(0, 1, 0, 1.0)  # Green for your turn
	else:
		# Get name based on ID
		var player_name = get_player_name_from_id(current_player_id)
		print("player name : ", player_name)
		player_turn_label.text = player_name + "'s Turn"
		
		# Update label color based on player color if available
		if game.player_colors.has(current_player_id):
			panel.modulate = game.player_colors[current_player_id]
		else:
			# Default color for other players
			panel.modulate = Color(1, 0.7, 0, 1.0)  # Orange for other players
	
	print("Turn label updated to: " + player_turn_label.text)

# Add methods for syncing player names

# Send your player name to a specific peer
func send_player_name(peer_id = 0):
	var my_name = OS.get_environment("USERNAME") if OS.get_environment("USERNAME") else "Player"
	if peer_id > 0:
		rpc_id(peer_id, "receive_player_name", game.multiplayer.get_unique_id(), my_name)
	else:
		rpc("receive_player_name", game.multiplayer.get_unique_id(), my_name)

# Request all player names from the server
func request_player_names():
	if !game.multiplayer.is_server():
		rpc_id(1, "request_player_names_from_server", game.multiplayer.get_unique_id())
		# Also send our name to the server
		#send_player_name(1)

# Server responds to name request by sending all names
@rpc("any_peer")
func request_player_names_from_server(requesting_peer_id):
	if game.multiplayer.is_server():
		# Send all known player names to the requesting peer
		for player_id in player_names:
			rpc_id(requesting_peer_id, "receive_player_name", player_id, player_names[player_id])
		
		# Also send the server's name
		var server_name = OS.get_environment("USERNAME") if OS.get_environment("USERNAME") else "Host"
		rpc_id(requesting_peer_id, "receive_player_name", game.multiplayer.get_unique_id(), server_name)

# Receive and store a player's name
@rpc("any_peer", "call_local")
func receive_player_name(player_id, player_name):
	player_names[player_id] = player_name
	print("Received player name: " + player_name + " for ID: " + str(player_id))
	
	# Update the display if this is the current player
	if game_state_manager.get_current_player_id() == player_id:
		update_turn_display()
