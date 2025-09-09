extends Control

@onready var host_button = $BelowButtonContainer/HostButton
@onready var back_button = $BelowButtonContainer/BackButton
@onready var lobby_container = $ScrollContainer/LobbyContainer
@onready var network_manager = $"../NetworkManager"

const LOBBY_BOX = preload("res://scenes/lobby/lobby_box.tscn")
