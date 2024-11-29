# card_deck_builder.gd
@tool
extends EditorPlugin

var card_resource_inspector

func _enter_tree():
	# Initialization of the plugin goes here
	add_custom_type("CardResource", "Resource", preload("res://addons/card_deck_builder/card_resources.gd"), preload("res://addons/card_deck_builder/icon.png"))
	add_custom_type("CardInstance", "Node2D", preload("res://addons/card_deck_builder/card_instance.gd"), preload("res://addons/card_deck_builder/icon.png"))
	add_custom_type("DeckBuilder", "Node", preload("res://addons/card_deck_builder/deck_builder.gd"), preload("res://addons/card_deck_builder/icon.png"))
	
	# Add custom inspector for CardResource
	card_resource_inspector = preload("card_resource_inspector.gd").new()
	card_resource_inspector.set_editor_interface(get_editor_interface())
	add_inspector_plugin(card_resource_inspector)

func _exit_tree():
	# Clean-up of the plugin goes here
	remove_custom_type("CardResource")
	remove_custom_type("CardInstance")
	remove_custom_type("DeckBuilder")
	
	# Remove custom inspector
	remove_inspector_plugin(card_resource_inspector)
