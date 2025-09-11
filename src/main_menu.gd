extends Control

@onready var start_button = $ButtonsContainer/StartButton
@onready var settings_button = $ButtonsContainer/SettingsButton
@onready var exit_button = $ButtonsContainer/ExitButton

var settings_menu_scene = preload("res://scenes/settings/settings_menu.tscn")

func _ready():
	start_button.connect("pressed", _on_start_game_pressed)
	settings_button.connect("pressed", _on_settings_button_pressed)
	exit_button.connect("pressed", _on_exit_button_pressed)
	var settings_menu_instance = settings_menu_scene.instantiate()
	add_child(settings_menu_instance)


func _on_start_game_pressed():
	print("start game pressed")
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_settings_button_pressed():
	print("settings game pressed")
	var setting_menu = get_node_or_null("SettingsMenu")
	setting_menu.toggle_settings_menu()


func _on_exit_button_pressed():
	print("exit button pressed")
	get_tree().quit()
