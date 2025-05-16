# network_manager.gd
extends Node

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# References to other managers
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
@onready var game = get_parent()
@onready var token_manager = $"../TokenManager"
@onready var game_state_manager = $"../GameStateManager" 
@onready var card_manager = $"../CardManager"
@onready var ui_manager = $"../UIManager"
@onready var point_counter = $"../PointCounter"

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
		
		# Initialize host data
		game.players = [host_id]  # Reset players array
		game.player_hands[host_id] = []
		game.player_colors[host_id] = game.PLAYER_COLORS[0]
		
		# Initialize game state
		token_manager.initialize_player_tokens(host_id)
		var tokens = token_manager.get_player_tokens(host_id)
		token_manager.update_token_ui()
		card_manager.distribute_initial_hand()
		game_state_manager.setup_player(host_id)
		game_state_manager.start_game()
		
		# Start broadcasting server info
		setup_network_discovery()
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
		
		var network_display = get_parent().get_node("RightUI/NetworkInfo/NetworkSideDisplay")
		if network_display:
			network_display.text = "Client"
	else:
		if connect_status:
			connect_status.text = "Connection failed: " + str(error)
		# Retry after delay
		await get_tree().create_timer(1.0).timeout
		attempt_connection(target_ip)

# ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
# ---  Peer Connection Handling ---
# ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

func _on_peer_connected(new_peer_id):
	if multiplayer.is_server():
		await get_tree().create_timer(0.1).timeout
		
		# Check if game is full
		if game.players.size() >= game.max_players:
			# Disconnect the player if game is full
			multiplayer_peer.disconnect_peer(new_peer_id)
			return
			
		print("New peer connected: ", new_peer_id)
		game.players.append(new_peer_id)
		
		# Initialize new player's hand tracking
		game.player_hands[new_peer_id] = []
		
		# Assign a color to the new player
		var color_index = game.players.size() - 1
		if color_index < game.PLAYER_COLORS.size():
			game.player_colors[new_peer_id] = game.PLAYER_COLORS[color_index]
			# Sync colors to all clients including the new one
			game.rpc("sync_player_colors", game.player_colors)
		
		# Find first available slot
		var slot_index = game.player_slots.find(false)
		if slot_index != -1:
			game.player_slots[slot_index] = true
			
		# Sync game state to new player
		game.rpc_id(new_peer_id, "sync_game_state", game.players, game.game_started, game.card_manager.placed_cards)
		
		# Initialize player's tokens and hand
		if game.game_started:
			card_manager.distribute_initial_hand_to_client(new_peer_id)
		
		token_manager.initialize_player_tokens(new_peer_id)
		var player_tokens = token_manager.get_player_tokens(new_peer_id)
		game.rpc_id(new_peer_id, "sync_player_tokens", player_tokens)
		
		game_state_manager.setup_player(new_peer_id)
		
		# Update the player list UI
		ui_manager.update_player_list()
		token_manager.setup_player_token_indicators()

func _on_peer_disconnected(peer_id):
	if peer_id == null or peer_id == 0:  # Check for both null and invalid ID
		return
		
	#print("Peer disconnected: ", peer_id)
	if game.players.has(peer_id):
		var slot_index = game.players.find(peer_id)
		if slot_index != -1:
			game.player_slots[slot_index] = false
		game.players.erase(peer_id)
	
	# Clean up disconnected player's hand
	if game.player_hands.has(peer_id):
		game.player_hands.erase(peer_id)
	
	if multiplayer.is_server():
		game.rpc("remove_player", peer_id)
		
		# Update the player list UI
		ui_manager.update_player_list()
	token_manager.setup_player_token_indicators()

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
# ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓

func get_local_ip() -> String:
	var addresses = IP.get_local_addresses()
	#print("address : ", addresses)
	
	# Priority 1: Find a 192.168.x.x address (common home/office network)
	for ip in addresses:
		if ip.begins_with("192.168."):
			return ip
	
	# Priority 2: Find other common private network addresses
	for ip in addresses:
		if ip.begins_with("10.") or ip.begins_with("172.16.") or ip.begins_with("172.17.") or \
		   ip.begins_with("172.18.") or ip.begins_with("172.19.") or ip.begins_with("172.2") or \
		   ip.begins_with("172.30.") or ip.begins_with("172.31."):
			return ip
	
	# Priority 3: Only use link-local as a last resort before localhost
	for ip in addresses:
		if ip.begins_with("169.254."):
			return ip
	
	# Priority 4: Use localhost if nothing else is available
	for ip in addresses:
		if ip == "127.0.0.1":
			return ip
	
	return "IP not found"

func get_valid_ips() -> Array:
	var valid_ips = []
	var addresses = IP.get_local_addresses()
	
	for ip in addresses:
		# Filter for valid IPv4 addresses
		if ip.count(".") == 3 and not ip.begins_with("127."):
			# Check for mobile-specific IP patterns
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
			# Try to map both UDP and TCP
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
# ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓

func setup_mobile_ui():
	var ip_input = get_parent().get_node("RightUI/Menu/IPInput")
	if ip_input:
		ip_input.virtual_keyboard_enabled = true
		ip_input.placeholder_text = "Enter host IP..."

func setup_mobile_network():
	# Display local IP for hosting
	var ip_input = get_parent().get_node("RightUI/Menu/IPInput")
	var connect_status = get_parent().get_node("RightUI/Menu/ConnectStatus")
	
	if ip_input and connect_status:
		var addresses = IP.get_local_addresses()
		var ip_text = "Available IPs:\n"
		for ip in addresses:
			# Only show IPv4 addresses that aren't localhost
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
# ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓

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
# ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓

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
