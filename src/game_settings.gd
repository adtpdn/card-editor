extends Node

const SETTINGS_FILE = "user://game_settings.cfg"

# Graphics Settings
var graphics_quality = 1 # 0:Low, 1:Medium, 2:High
var aa_mode = 0 # Corresponds to the OptionButton index
var post_fx_enabled = true

# Display Settings
var resolution = Vector2i(1920, 1080)
var display_mode = 0 # 0:Fullscreen, 1:Windowed, 2:Borderless

# Sound Settings
var bgm_volume = 0.8
var sfx_volume = 0.8


func _ready():
	load_settings()
	apply_settings()

func set_graphics_quality(quality):
	graphics_quality = quality
	apply_graphics_settings()

func set_aa_mode(mode):
	aa_mode = mode
	apply_graphics_settings()
	
func set_post_fx(enabled):
	post_fx_enabled = enabled
	apply_graphics_settings()

func set_resolution(res):
	resolution = res
	apply_display_settings()

func set_display_mode(mode):
	display_mode = mode
	apply_display_settings()
	
func set_bgm_volume(volume):
	bgm_volume = volume
	apply_sound_settings()

func set_sfx_volume(volume):
	sfx_volume = volume
	apply_sound_settings()


func apply_settings():
	apply_graphics_settings()
	apply_display_settings()
	apply_sound_settings()

func apply_graphics_settings():
	# This is where you would change viewport settings, etc.
	# For now, we'll just print the changes
	print("Applying graphics settings:")
	print("  Quality: ", graphics_quality)
	print("  AA Mode: ", aa_mode)
	print("  Post FX: ", post_fx_enabled)
	
	# Example of changing MSAA
	if aa_mode == 0: # MSAA
		get_viewport().msaa_3d = Viewport.MSAA_2X if graphics_quality == 0 else Viewport.MSAA_4X if graphics_quality == 1 else Viewport.MSAA_8X
	else:
		get_viewport().msaa_3d = Viewport.MSAA_DISABLED

func apply_display_settings():
	DisplayServer.window_set_size(resolution)
	
	match display_mode:
		0: # Fullscreen
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		1: # Windowed
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		2: # Borderless
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)


func apply_sound_settings():
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(bgm_volume))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(sfx_volume)) # Assuming you have an "SFX" bus

func save_settings():
	var config = ConfigFile.new()
	config.set_value("graphics", "quality", graphics_quality)
	config.set_value("graphics", "aa_mode", aa_mode)
	config.set_value("graphics", "post_fx", post_fx_enabled)
	config.set_value("display", "resolution_x", resolution.x)
	config.set_value("display", "resolution_y", resolution.y)
	config.set_value("display", "mode", display_mode)
	config.set_value("sound", "bgm_volume", bgm_volume)
	config.set_value("sound", "sfx_volume", sfx_volume)
	config.save(SETTINGS_FILE)
	
func load_settings():
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_FILE)
	if err != OK:
		return

	graphics_quality = config.get_value("graphics", "quality", 1)
	aa_mode = config.get_value("graphics", "aa_mode", 0)
	post_fx_enabled = config.get_value("graphics", "post_fx", true)
	resolution.x = config.get_value("display", "resolution_x", 1920)
	resolution.y = config.get_value("display", "resolution_y", 1080)
	display_mode = config.get_value("display", "mode", 0)
	bgm_volume = config.get_value("sound", "bgm_volume", 0.8)
	sfx_volume = config.get_value("sound", "sfx_volume", 0.8)
