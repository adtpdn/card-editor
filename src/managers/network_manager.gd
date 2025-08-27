# network_manager.gd
extends Node

signal server_created

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# References to other managers
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
@onready var game = get_parent()
@onready var token_manager = $"../TokenManager"
@onready var game_state_manager = $"../GameStateManager" 
@onready var card_manager = $"../CardManager"
@onready var ui_manager = $"../UIManager"
@onready var point_counter = $"../PointCounter"
@onready var deck = $"../Deck"


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Multiplayer Dependencies
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
var multiplayer_peer = ENetMultiplayerPeer.new()
const PORT = 9999
const DEFAULT_IP = "127.0.0.1"

# Network Settings
var use_upnp = true  # Enable UPNP for mobile networking
var upnp_attempts = 0
const MAX_UPNP_ATTEMPTS = 10
var is_mobile = false
var local_ip = "127.0.0.1"
var is_host = false

# Connection Status
var peer_status = "Not Connected"
var last_error = ""
var connect_retries = 0
const MAX_CONNECT_RETRIES = 3

# Network Discovery
const BROADCAST_PORT = 9998  # Port for network discovery
var broadcast_timer: Timer
var discovery_socket: PacketPeerUDP
const BROADCAST_ADDRESS = "255.255.255.255"
var broadcast_enabled = false

# Network Sockets
var broadcast_socket: PacketPeerUDP
var listen_socket: PacketPeerUDP
const SERVER_BROADCAST_INTERVAL = 1.0

# Refresh Timers
var ip_display_timer: Timer
var last_ip_refresh_time = 0.0
const IP_REFRESH_INTERVAL = 5.0  # Refresh IPs every 5 seconds

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Initialization
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
func _ready():
	# Connect UI buttons
	var host_button = get_parent().get_node("RightUI/Menu/HostButton")
	var join_button = get_parent().get_node("RightUI/Menu/JoinButton")
	
	if host_button:
		if host_button.pressed.is_connected(_on_host_pressed):
			host_button.pressed.disconnect(_on_host_pressed)
		host_button.pressed.connect(_on_host_pressed)
	
	if join_button:
		if join_button.pressed.is_connected(_on_join_pressed):
			join_button.pressed.disconnect(_on_join_pressed)
		join_button.pressed.connect(_on_join_pressed)
	
	# Setup multiplayer connections
	multiplayer_peer.peer_connected.connect(_on_peer_connected)
	multiplayer_peer.peer_disconnected.connect(_on_peer_disconnected)
	
	# Check if running on mobile
	is_mobile = OS.has_feature("mobile")
	if is_mobile:
		setup_mobile_ui()
		setup_mobile_network()
	
	# Get local IP for display
	local_ip = get_local_ip()
	
	# Display IP in UI
	var connect_status = get_parent().get_node("RightUI/Menu/ConnectStatus")
	if connect_status:
		_refresh_ip_display()
	
	# Set up network discovery if on mobile
	if is_mobile:
		setup_network_discovery()

func initialize():
	# Initial setup for broadcasts and timers
	if is_host and !broadcast_timer:
		broadcast_timer = Timer.new()
		add_child(broadcast_timer)
		broadcast_timer.wait_time = SERVER_BROADCAST_INTERVAL
		broadcast_timer.timeout.connect(_broadcast_server_info)
		broadcast_timer.start()

# ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
# ---  Host & Client Functions  ---
# ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

func _on_host_pressed():
	is_host = true
	var connect_status = get_parent().get_node("RightUI/Menu/ConnectStatus")
	
	if connect_status:
		connect_status.text = "Starting server..."
	
	# Get the first valid IP
	var host_ip = get_valid_ips()[0] if !get_valid_ips().is_empty() else "127.0.0.1"
	
	var error = multiplayer_peer.create_server(PORT)
	
	if error == OK:
		
		if is_mobile and use_upnp:
			if setup_upnp():
				if connect_status:
					connect_status.text += "\nUPnP setup successful"
			else:
				if connect_status:
					connect_status.text += "\nUPnP setup failed, port forwarding may be needed"
		
		var network_display = get_parent().get_node("RightUI/NetworkInfo/NetworkSideDisplay")
		if network_display:
			network_display.text = "Server"
		
		if connect_status:
			connect_status.text += "\nServer running on: " + host_ip + ":" + str(PORT)
		
		multiplayer.multiplayer_peer = multiplayer_peer
		var host_id = multiplayer.get_unique_id()
		
		game.deck.table.setup_decks_for_new_game()
		
		# Initialize host data
		game.players = [host_id]  # Reset players array
		game.initial_player_order = [host_id]
		game.player_hands[host_id] = []
		
		# Initialize game state
		token_manager.initialize_player_tokens(host_id)
		var tokens = token_manager.get_player_tokens(host_id)
		token_manager.update_token_ui()
		
		game_state_manager.setup_player(host_id)
		game_state_manager.start_game()
		
		# FIX: Deal initial hand to the host after the game has started.
		await get_tree().create_timer(0.1).timeout # Short delay for stability
		card_manager.initialize_starting_hand()
		
		# Start broadcasting server info
		setup_network_discovery()
		server_created.emit()
	else:
		if connect_status:
			connect_status.text = "Failed to create server: " + str(error)

func _on_join_pressed():
	is_host = false
	connect_retries = 0
	
	var ip_input = get_parent().get_node("RightUI/Menu/IPInput")
	var connect_status = get_parent().get_node("RightUI/Menu/ConnectStatus")
	
	if !ip_input or !connect_status:
		return
	
	var target_ip = ip_input.text.strip_edges()
	if target_ip.is_empty() or target_ip == "127.0.0.1":
		connect_status.text = "Searching for local servers..."
		# Start discovery process
		if !discovery_socket:
			setup_network_discovery()
		_start_server_discovery()
	else:
		attempt_connection(target_ip)

func attempt_connection(target_ip: String):
	var connect_status = get_parent().get_node("RightUI/Menu/ConnectStatus")
	
	if connect_retries >= MAX_CONNECT_RETRIES:
		if connect_status:
			connect_status.text = "Failed to connect after multiple attempts"
		return
	
	connect_retries += 1
	
	# Close existing connections
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer = null
	
	if multiplayer_peer:
		multiplayer_peer.close()
	
	multiplayer_peer = ENetMultiplayerPeer.new()
	
	print("Attempting to connect to: ", target_ip)
	if connect_status:
		connect_status.text = "Connecting to " + target_ip + "... (Attempt " + str(connect_retries) + ")"
	
	var error = multiplayer_peer.create_client(target_ip, PORT)
	print("error : ", error)
	if error == OK:
		multiplayer.multiplayer_peer = multiplayer_peer
		
		get_tree().create_timer(1.0).timeout.connect(func():
			if multiplayer.is_server():
				return
			var local_id = multiplayer.get_unique_id()
			if local_id > 0:
				print("Client requesting initial game state and cards")
				game.rpc_id(1, "request_game_state_sync", local_id)
		)
		
		var network_display = get_parent().get_node("RightUI/NetworkInfo/NetworkSideDisplay")
		if network_display:
			network_display.text = "Client"
	else:
		if connect_status:
			connect_status.text = "Connection failed: " + str(error)
		await get_tree().create_timer(1.0).timeout
		attempt_connection(target_ip)

# ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
# ---  Peer Connection Handling ---
# ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

func _on_peer_connected(new_peer_id):
	# This logic only runs on the server
	if multiplayer.is_server():
		await get_tree().create_timer(0.1).timeout # Short delay for stability

		if game.players.size() >= game.max_players:
			multiplayer_peer.disconnect_peer(new_peer_id)
			return
		
		print("New peer connected: ", new_peer_id)
		
		# 1. Add the new player to the server's master list
		game.players.append(new_peer_id)
		
		# Get the table node to access its data and RPCs
		var table = get_node("/root/Game/Deck/Table")
		
		# Send the already-shuffled decks to the NEW player ONLY.
		table.rpc_id(new_peer_id, "client_receive_shuffled_decks", table.available_cards, table.elementals_ids_arr)
		
		# Send the valid elemental indices to the NEW player ONLY
		table.rpc_id(new_peer_id, "sync_red_elemental_indices", table.red_elemental_indices)
		
		# Gather the current board state and send it to the NEW player ONLY.
		var elemental_slice_cards_data = []
		var drag_controller = table.get_node("DragController")
		for i in range(1, 9):
			var slice_name = "elemental_slice_" + str(i)
			var elemental_slice = drag_controller.get_node_or_null(slice_name)
			if elemental_slice and elemental_slice.cards.size() > 0:
				var card = elemental_slice.cards[0]
				var original_index = card.get_meta("original_card_index", -1)
				if original_index != -1:
					elemental_slice_cards_data.append({
						"card_index": original_index,
						"slice_index": i
					})
		
		if not elemental_slice_cards_data.is_empty():
			table.rpc_id(new_peer_id, "client_receive_initial_slices", elemental_slice_cards_data)
		
		# 2. Initialize the new player's tokens ON THE SERVER
		token_manager.initialize_player_tokens(new_peer_id)
		
		# Get the newly created token array from the token manager.
		var new_player_tokens = token_manager.get_player_tokens(new_peer_id)
		# Send this array specifically to the new client so they have their starting tokens.
		token_manager.rpc_id(new_peer_id, "sync_player_tokens", new_player_tokens, new_peer_id)
		
		# 3. Call the single authoritative function to sync the UI for ALL players
		game_state_manager.rpc("sync_player_list_and_uis", game.players)
		
		# 4. FIX: Deal the initial hand to the new client.
		await get_tree().create_timer(1.0).timeout
		#game.rpc_id(new_peer_id, "initialize_client_starting_hand")
		table.rpc_id(1, "request_server_draw_card", new_peer_id, false)
		table.server_draw_card(new_peer_id,false)


func _on_peer_disconnected(peer_id):
	# This logic only runs on the server
	if multiplayer.is_server() and game.players.has(peer_id):
		print("Peer disconnected: ", peer_id)
		
		# 1. Remove the player from the server's master list
		game.players.erase(peer_id)
		game.initial_player_order.erase(peer_id)
		
		# 2. Call the single authoritative function to update the UI for all remaining players
		game_state_manager.rpc("sync_player_list_and_uis", game.players)

# ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
# ---    Network Discovery     ---
# ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

func setup_network_discovery():
	if is_host:
		# Setup broadcasting socket
		broadcast_socket = PacketPeerUDP.new()
		broadcast_socket.set_broadcast_enabled(true)
		broadcast_timer = Timer.new()
		add_child(broadcast_timer)
		broadcast_timer.wait_time = SERVER_BROADCAST_INTERVAL
		broadcast_timer.timeout.connect(_broadcast_server_info)
		broadcast_timer.start()
	else:
		# Setup listening socket
		listen_socket = PacketPeerUDP.new()
		var err = listen_socket.bind(BROADCAST_PORT)
		if err == OK:
			print("Listening for servers on port ", BROADCAST_PORT)
		else:
			print("Failed to bind discovery port: ", err)

func _broadcast_server_info():
	if !is_host or !broadcast_socket:
		return
		
	var server_info = JSON.stringify({
		"server_ip": get_local_ip(),
		"server_port": PORT,
		"players": game.players.size()
	})
	
	broadcast_socket.set_dest_address("255.255.255.255", BROADCAST_PORT)
	broadcast_socket.put_packet(server_info.to_utf8_buffer())

func _start_server_discovery():
	if discovery_socket:
		# Listen for broadcast messages
		while discovery_socket.get_available_packet_count() > 0:
			var packet = discovery_socket.get_packet()
			var data_str = packet.get_string_from_utf8()
			var server_data = JSON.parse_string(data_str)
			
			if server_data and server_data.has("host_ip") and server_data.has("game_port"):
				print("Found server at: ", server_data.host_ip)
				attempt_connection(server_data.host_ip)
				return
	
	# Retry discovery after a delay if no server found
	get_tree().create_timer(1.0).timeout.connect(_start_server_discovery)

# ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
# ---    IP & UPnP Handling    ---
# ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

func get_local_ip() -> String:
	var addresses = IP.get_local_addresses()
	
	for ip in addresses:
		if ip.begins_with("192.168."):
			return ip
	
	for ip in addresses:
		if ip.begins_with("10.") or ip.begins_with("172.16.") or ip.begins_with("172.17.") or \
		   ip.begins_with("172.18.") or ip.begins_with("172.19.") or ip.begins_with("172.2") or \
		   ip.begins_with("172.30.") or ip.begins_with("172.31."):
			return ip
	
	for ip in addresses:
		if ip.begins_with("169.254."):
			return ip
	
	for ip in addresses:
		if ip == "127.0.0.1":
			return ip
	
	return "IP not found"

func get_valid_ips() -> Array:
	var valid_ips = []
	var addresses = IP.get_local_addresses()
	
	for ip in addresses:
		if ip.count(".") == 3 and not ip.begins_with("127."):
			if ip.begins_with("192.168.") or \
			   ip.begins_with("10.") or \
			   ip.begins_with("172."):
				valid_ips.append(ip)
	
	return valid_ips

func setup_upnp() -> bool:
	var upnp = UPNP.new()
	var discover_result = upnp.discover(2000, 2, "InternetGatewayDevice")
	
	if discover_result == UPNP.UPNP_RESULT_SUCCESS:
		if upnp.get_gateway() and upnp.get_gateway().is_valid_gateway():
			var map_result_udp = upnp.add_port_mapping(PORT, PORT, "GodotGameUDP", "UDP")
			var map_result_tcp = upnp.add_port_mapping(PORT, PORT, "GodotGameTCP", "TCP")
			
			if map_result_udp == UPNP.UPNP_RESULT_SUCCESS or map_result_tcp == UPNP.UPNP_RESULT_SUCCESS:
				print("External IP: ", upnp.query_external_address())
				return true
	
	return false

func cleanup_upnp():
	if !is_host:
		return
		
	var upnp = UPNP.new()
	if upnp.discover() == UPNP.UPNP_RESULT_SUCCESS:
		if upnp.get_gateway() and upnp.get_gateway().is_valid_gateway():
			upnp.delete_port_mapping(PORT, "UDP")
			upnp.delete_port_mapping(PORT, "TCP")

# ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
# ---    Mobile UI Support     ---
# ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

func setup_mobile_ui():
	var ip_input = get_parent().get_node("RightUI/Menu/IPInput")
	if ip_input:
		ip_input.virtual_keyboard_enabled = true
		ip_input.placeholder_text = "Enter host IP..."

func setup_mobile_network():
	var ip_input = get_parent().get_node("RightUI/Menu/IPInput")
	var connect_status = get_parent().get_node("RightUI/Menu/ConnectStatus")
	
	if ip_input and connect_status:
		var addresses = IP.get_local_addresses()
		var ip_text = "Available IPs:\n"
		for ip in addresses:
			if ip.count(".") == 3 and not ip.begins_with("127."):
				ip_text += ip + "\n"
		connect_status.text = ip_text

func _refresh_ip_display():
	var connect_status = get_parent().get_node("RightUI/Menu/ConnectStatus")
	if !connect_status:
		return
		
	var addresses = get_valid_ips()
	var ip_text = "Available IPs:\n"
	
	for ip in addresses:
		ip_text += ip + "\n"
	
	if is_host:
		ip_text += "\nHosting on port: " + str(PORT)
	
	connect_status.text = ip_text

# ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
# ---    Network Processing    ---
# ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

func _process(_delta):
	if !is_host and listen_socket:
		if listen_socket.get_available_packet_count() > 0:
			var server_ip = listen_socket.get_packet_ip()
			var server_data_raw = listen_socket.get_packet()
			var server_data_str = server_data_raw.get_string_from_utf8()
			var server_info = JSON.parse_string(server_data_str)
			
			if server_info and server_info.has("server_ip"):
				print("Found server at: ", server_info.server_ip)
				
				var connect_status = get_parent().get_node("RightUI/Menu/ConnectStatus")
				if connect_status:
					connect_status.text = "Found server at: " + server_info.server_ip
				
				attempt_connection(server_info.server_ip)
				listen_socket = null  # Stop listening once we find a server
	
	# Check connection status
	if multiplayer_peer:
		var connect_status = get_parent().get_node("RightUI/Menu/ConnectStatus")
		var menu = get_parent().get_node("RightUI/Menu")
		
		match multiplayer_peer.get_connection_status():
			MultiplayerPeer.CONNECTION_DISCONNECTED:
				if peer_status != "Disconnected":
					peer_status = "Disconnected"
					if connect_status:
						connect_status.text = "Disconnected from server"
					if menu:
						menu.visible = true
			MultiplayerPeer.CONNECTION_CONNECTED:
				if peer_status != "Connected":
					peer_status = "Connected"
					if connect_status:
						connect_status.text = "Connected!"
					if menu:
						menu.visible = false

# ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
# ---    Network Cleanup      ---
# ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

func cleanup_network():
	if broadcast_socket:
		broadcast_socket.close()
	if listen_socket:
		listen_socket.close()
	if broadcast_timer:
		broadcast_timer.stop()
	if multiplayer_peer:
		multiplayer_peer.close()

func is_valid_ip(ip: String) -> bool:
	if ip.is_empty():
		return false
	var parts = ip.split(".")
	if parts.size() != 4:
		return false
	for part in parts:
		if !part.is_valid_int():
			return false
		var num = part.to_int()
		if num < 0 or num > 255:
			return false
	return true

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		cleanup_network()
		get_tree().quit()

# ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
# ---         Draw Card        ---
# ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
func sync_card_draw():
	if multiplayer.is_server():
		# Just sync the available_cards state
		var table = deck.table
		rpc("sync_available_cards", table.available_cards)

# Sync the deck seed to all clients
func sync_deck_seed(seed_value: int):
	if multiplayer.is_server():
		rpc("receive_deck_seed", seed_value)

# Sync the full deck state (available_cards array)
func sync_deck_state(available_cards_array: Array):
	if multiplayer.is_server():
		rpc("receive_deck_state", available_cards_array)

# Client request for deck sync
func request_deck_sync():
	if !multiplayer.is_server():
		rpc_id(1, "server_send_deck_state")  # 1 is typically the server ID

@rpc("any_peer", "call_local")
func receive_deck_seed(seed_value: int):
	var table = get_node("/root/Game/Deck/Table")
	if table:
		table.initialize_deck_with_seed(seed_value)

@rpc("any_peer")
func receive_deck_state(available_cards_array: Array):
	var table = get_node("/root/Game/Deck/Table")
	if table:
		table.available_cards = available_cards_array
		print("Received deck state with ", available_cards_array.size(), " cards remaining")

@rpc("any_peer")
func server_send_deck_state():
	if multiplayer.is_server():
		var sender_id = multiplayer.get_remote_sender_id()
		var table = get_node("/root/Game/Deck/Table")
		if table:
			# Send the current deck state back to the client who requested it
			rpc_id(sender_id, "receive_deck_state", table.available_cards)

# Sync when a specific card is drawn - only update available_cards
func sync_card_drawn(card_id: int):
	if multiplayer.is_server():
		# Send the updated available_cards and the resource card_id
		var table = deck.table
		rpc("sync_available_cards", table.available_cards, card_id)

# New RPC to only sync the available_cards array without drawing a card
@rpc("any_peer", "call_local") 
func sync_available_cards(updated_available_cards: Array, card_id: int = -1):
	var table = get_node("/root/Game/Deck/Table")
	if table:
		# Just update the available cards array
		table.available_cards = updated_available_cards
		print("Synchronized deck state: ", updated_available_cards.size(), " cards remaining")
		
		# Log the card_id for debugging
		if card_id >= 0:
			print("Card with resource card_id", card_id, "was drawn remotely")

@rpc("any_peer", "call_local") 
func remote_specific_card_drawn(card_index: int, updated_available_cards = null):
	var game = get_node("/root/Game/")
	if game and game.card_manager:
		# Update the available cards array if provided
		if updated_available_cards != null and game.deck and game.deck.table:
			game.deck.table.available_cards = updated_available_cards
		
		# Draw the specific card that was drawn on the server
		game.card_manager.draw_specific_card(card_index)


# Sync when a card is planted
func sync_card_planted(card_id: int, biome_slot: int, player_id: int, card_name: String):
	if multiplayer.is_server():
		# Send to all clients
		rpc("remote_card_planted", card_id, biome_slot, player_id, card_name)
	else:
		# If client, send to server first for validation
		rpc_id(1, "request_card_plant", card_id, biome_slot, player_id, card_name)

# Server-side validation of a card plant request from a client
@rpc("any_peer")
func request_card_plant(card_id: int, biome_slot: int, player_id: int, card_name: String):
	if !multiplayer.is_server():
		return
		
	var sender_id = multiplayer.get_remote_sender_id()
	
	# Here you could add validation logic if needed
	# For now, we'll just forward the action to all clients
	
	rpc("remote_card_planted", card_id, biome_slot, sender_id, card_name)

# Remote execution of card planting
@rpc("any_peer", "call_local")
func remote_card_planted(card_id: int, biome_slot: int, player_id: int, card_name: String):
	print("Received remote_card_planted with resource card_id:", card_id)
	
	var game = get_node("/root/Game/")
	if !game or !game.card_manager:
		return
	
	# If this is coming from another player (not us)
	var our_id = multiplayer.get_unique_id()
	
	if player_id != our_id:  # If it's not our own action
		print("Processing remote card plant from player", player_id)
		# Create and place the card using the resource card_id
		create_and_place_card(card_id, biome_slot, card_name)
	
	# Execute the card effect based on resource card_id
	var card_collection = null
	match biome_slot:
		0: card_collection = game.deck.pile
	
	if card_collection:
		card_collection.execute_card_effect(card_id)

func create_and_place_card(card_id: int, biome_slot: int, card_name: String):
	var game = get_node("/root/Game/")
	if !game or !game.deck:
		return
	
	# Get the target biome slot
	var target_slot = null
	match biome_slot:
		0: target_slot = game.deck.pile
		_: 
			print("Invalid biome slot:", biome_slot)
			return
	
	if !target_slot:
		print("Target biome slot not found")
		return
	
	# Find the card index that corresponds to the resource card_id
	var found_index = -1
	var actions_cards = game.deck.table.actions_cards
	
	for i in range(actions_cards.cards.size()):
		if actions_cards.cards[i].card_id == card_id and actions_cards.cards[i].card_name == card_name:
			found_index = i
			break
	
	if found_index == -1:
		print("Error: Could not find index for resource card_id:", card_id)
		return
		
	print("Found index ", found_index, " for resource card_id", card_id)
	
	# Create the card instance using the found index
	var face_card = game.deck.table.instantiate_face_card(found_index)
	if !face_card:
		print("Failed to instantiate card with resource card_id:", card_id)
		return
	
	# Double-check the card_id is correct (should be the resource card_id)
	if face_card.card_id != card_id:
		print("Warning: Card ID mismatch. Expected resource card_id:", card_id, "Got:", face_card.card_id)
		face_card.card_id = card_id  # Force the correct resource card_id
	
	print("Created remote card with resource card_id:", face_card.card_id, "for biome slot:", biome_slot)
	
	# Add the card to the target slot
	# We'll set a flag to prevent it from triggering effects again
	face_card.set_meta("remote_planted", true)
	target_slot.append_card(face_card)
	target_slot.hide_last_card()


@rpc("any_peer", "call_local")
func remote_move_card_to_biome(card_id: int, biome_slot: int):
	var game = get_node("/root/Game/")
	if !game or !game.deck or !game.deck.hand:
		return
		
	# Find the card in the player's hand
	var hand = game.deck.hand
	var card_to_move = null
	
	for card in hand.cards:
		if card.card_id == card_id:
			card_to_move = card
			break
	
	if !card_to_move:
		print("Card with ID ", card_id, " not found in hand")
		return
	
	# Find the target biome slot
	var target_slot = null
	match biome_slot:
		0: target_slot = game.deck.card_slot_biome_1
		1: target_slot = game.deck.card_slot_biome_2
		2: target_slot = game.deck.card_slot_biome_3
		3: target_slot = game.deck.card_slot_biome_4
	
	if !target_slot:
		print("Target biome slot ", biome_slot, " not found")
		return
	
	# Get the card index
	var card_index = hand.card_indicies[card_to_move]
	
	# Remove from hand
	var card = hand.remove_card(card_index)
	
	# Add to biome slot
	target_slot.append_card(card)


@rpc("authority", "call_local")
func sync_players_list(players_array: Array):
	var game = get_parent()
	game.players = players_array.duplicate()
	print("Received updated players list: ", game.players)
	
	# Update any UI or game state that depends on the players list
	var ui_manager = get_parent().get_node("UIManager")
	if ui_manager:
		ui_manager.update_player_list()
	
	var token_manager = get_parent().get_node("TokenManager")
	if token_manager:
		
		# Force update of all token colors based on new player list
		if multiplayer.is_server():
			token_manager.force_resync_token_colors()
