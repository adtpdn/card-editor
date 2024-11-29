# card_resource_inspector.gd
@tool
extends EditorInspectorPlugin

var editor_interface

func set_editor_interface(interface):
	editor_interface = interface

func _can_handle(object):
	return object is CardResource

func _parse_begin(object):
	var container = VBoxContainer.new()
	
	var save_button = Button.new()
	save_button.text = "Save Card"
	save_button.connect("pressed", Callable(self, "_on_save_button_pressed").bind(object))
	container.add_child(save_button)
	
	var load_button = Button.new()
	load_button.text = "Load Card"
	load_button.connect("pressed", Callable(self, "_on_load_button_pressed").bind(object))
	container.add_child(load_button)
	
	var image_button = Button.new()
	image_button.text = "Select Card Image"
	image_button.connect("pressed", Callable(self, "_on_image_button_pressed").bind(object))
	container.add_child(image_button)
	
	var duplicate_button = Button.new()
	duplicate_button.text = "Duplicate Card"
	duplicate_button.connect("pressed", Callable(self, "_on_duplicate_card_pressed").bind(object))
	container.add_child(duplicate_button)
	
	add_custom_control(container)

func _parse_property(object, type, name, hint_type, hint_string, usage_flags, wide):
	if name == "card_type":
		var option_button = OptionButton.new()
		option_button.add_item("Action Card", CardResource.CardType.ACTION)
		option_button.add_item("Area Card", CardResource.CardType.AREA)
		option_button.selected = object.card_type
		option_button.connect("item_selected", Callable(self, "_on_card_type_selected").bind(object))
		add_custom_control(option_button)
		return true
	return false

func _on_card_type_selected(index, card):
	card.card_type = index
	card.notify_property_list_changed()

func _on_save_button_pressed(card: CardResource):
	var save_dialog = EditorFileDialog.new()
	save_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	save_dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
	save_dialog.add_filter("*.tres ; Card Resource")
	save_dialog.connect("file_selected", Callable(self, "_on_save_file_selected").bind(card))
	editor_interface.get_base_control().add_child(save_dialog)
	save_dialog.popup_centered_ratio()

func _on_save_file_selected(path: String, card: CardResource):
	card.save_to_file(path)
	print("Card saved to: ", path)

func _on_load_button_pressed(card: CardResource):
	var load_dialog = EditorFileDialog.new()
	load_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	load_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	load_dialog.add_filter("*.tres ; Card Resource")
	load_dialog.connect("file_selected", Callable(self, "_on_load_file_selected").bind(card))
	editor_interface.get_base_control().add_child(load_dialog)
	load_dialog.popup_centered_ratio()

func _on_load_file_selected(path: String, card: CardResource):
	if card.load_from_file(path):
		print("Card loaded from: ", path)
	else:
		print("Failed to load card from: ", path)

func _on_image_button_pressed(card: CardResource):
	var image_dialog = EditorFileDialog.new()
	image_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	image_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	image_dialog.add_filter("*.png ; PNG Images")
	image_dialog.add_filter("*.jpg ; JPEG Images")
	image_dialog.connect("file_selected", Callable(self, "_on_image_file_selected").bind(card))
	editor_interface.get_base_control().add_child(image_dialog)
	image_dialog.popup_centered_ratio()

func _on_image_file_selected(path: String, card: CardResource):
	var texture = load(path)
	if texture is Texture2D:
		card.card_image = texture
		print("Card image set from: ", path)
	else:
		print("Failed to load image from: ", path)

func _on_duplicate_card_pressed(card: CardResource):
	var duplicated_card = card.duplicate()
	duplicated_card.card_name = "Copy of " + card.card_name
	
	var save_dialog = EditorFileDialog.new()
	save_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	save_dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
	save_dialog.add_filter("*.tres ; Card Resource")
	save_dialog.connect("file_selected", Callable(self, "_on_duplicate_save_file_selected").bind(duplicated_card))
	editor_interface.get_base_control().add_child(save_dialog)
	save_dialog.popup_centered_ratio()

func _on_duplicate_save_file_selected(path: String, duplicated_card: CardResource):
	duplicated_card.save_to_file(path)
	print("Duplicated card saved to: ", path)
	
	# Refresh the editor to show the new card
	editor_interface.get_resource_filesystem().scan()
