extends Control

@onready var quality_button = $Panel/VBoxContainer/TabContainer/Graphics/VBoxContainer/QualityOptionButton
@onready var aa_button = $Panel/VBoxContainer/TabContainer/Graphics/VBoxContainer/AAOptionButton
@onready var post_fx_checkbox = $Panel/VBoxContainer/TabContainer/Graphics/VBoxContainer/PostFXCheckBox
@onready var resolution_button = $Panel/VBoxContainer/TabContainer/Display/VBoxContainer/ResolutionOptionButton
@onready var display_mode_button = $Panel/VBoxContainer/TabContainer/Display/VBoxContainer/DisplayModeOptionButton
@onready var bgm_slider = $Panel/VBoxContainer/TabContainer/Sound/VBoxContainer/BGMHSlider
@onready var sfx_slider = $Panel/VBoxContainer/TabContainer/Sound/VBoxContainer/SFXHSlider
@onready var close_button = $Panel/VBoxContainer/BoxContainer/CloseButton


func _ready():
	
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	hide()
	populate_resolutions()
	load_settings()

	quality_button.item_selected.connect(_on_quality_selected)
	aa_button.item_selected.connect(_on_aa_selected)
	post_fx_checkbox.toggled.connect(_on_post_fx_toggled)
	resolution_button.item_selected.connect(_on_resolution_selected)
	display_mode_button.item_selected.connect(_on_display_mode_selected)
	bgm_slider.value_changed.connect(_on_bgm_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	close_button.pressed.connect(toggle_settings_menu)


func _input(event):
	if event.is_action_pressed("ui_cancel"):
		toggle_settings_menu()

func toggle_settings_menu():
	visible = not visible
	if visible:
		get_tree().paused = true
	else:
		get_tree().paused = false
		GameSettings.save_settings()


func populate_resolutions():
	var resolutions = [
		Vector2i(1280, 720),
		Vector2i(1920, 1080),
		Vector2i(2560, 1440),
	]
	
	for res in resolutions:
		resolution_button.add_item(str(res.x) + "x" + str(res.y))

func load_settings():
	quality_button.select(GameSettings.graphics_quality)
	aa_button.select(GameSettings.aa_mode)
	post_fx_checkbox.button_pressed = GameSettings.post_fx_enabled
	
	var res_string = str(GameSettings.resolution.x) + "x" + str(GameSettings.resolution.y)
	for i in resolution_button.item_count:
		if resolution_button.get_item_text(i) == res_string:
			resolution_button.select(i)
			break
			
	display_mode_button.select(GameSettings.display_mode)
	bgm_slider.value = GameSettings.bgm_volume
	sfx_slider.value = GameSettings.sfx_volume

func _on_quality_selected(index):
	GameSettings.set_graphics_quality(index)

func _on_aa_selected(index):
	GameSettings.set_aa_mode(index)

func _on_post_fx_toggled(toggled_on):
	GameSettings.set_post_fx(toggled_on)

func _on_resolution_selected(index):
	var res_string = resolution_button.get_item_text(index).split("x")
	var width = int(res_string[0])
	var height = int(res_string[1])
	GameSettings.set_resolution(Vector2i(width, height))

func _on_display_mode_selected(index):
	GameSettings.set_display_mode(index)

func _on_bgm_changed(value):
	GameSettings.set_bgm_volume(value)

func _on_sfx_changed(value):
	GameSettings.set_sfx_volume(value)
