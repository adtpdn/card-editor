extends Control

@onready var host_button = $BelowButtonContainer/HostButton
@onready var back_button = $BelowButtonContainer/BackButton
@onready var lobby_container = $ScrollContainer/LobbyContainer
@onready var network_manager = $"../NetworkManager"

const LOBBY_BOX = preload("res://scenes/lobby/lobby_box.tscn")

# This function is called by the server on all clients to build the lobby UI.
@rpc("any_peer", "call_local", "reliable")
func update_lobby_display(player_info: Dictionary):
	# Clear any existing lobby boxes to ensure a fresh display
	for child in lobby_container.get_children():
		child.queue_free()
	
	# Create a new lobby box for each player in the dictionary provided by the server
	print("player info : ", player_info)
	for player_id in player_info:
		var player_name = player_info[player_id]
		var lobby_box_instance = LOBBY_BOX.instantiate()
		
		# Find the label within the instanced scene and set its text
		var name_label = lobby_box_instance.get_node_or_null("PlayerNameLabel")
		if name_label:
			name_label.text = player_name
		else:
			print("ERROR: Could not find 'PlayerNameLabel' node in lobby_box.tscn")
		
		lobby_container.add_child(lobby_box_instance)
