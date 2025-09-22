extends MeshInstance3D

enum BiomeType {FOREST, WATER, MOUNTAIN, DESERT}

@export var biome_id : BiomeType
@onready var static_body_3d = $StaticBody3D
# Get absolute paths to nodes for better stability
@onready var notification = get_node("/root/Game/Notification")
@onready var point_counter = get_node("/root/Game/PointCounter")


#func _ready():
	## Connect signals only if the static body exists
	#if static_body_3d:
		#static_body_3d.mouse_entered.connect(_on_static_body_3d_mouse_entered)
		#static_body_3d.mouse_exited.connect(_on_static_body_3d_mouse_exited)

func _on_static_body_3d_mouse_entered():
	# Ensure the required nodes are available to prevent errors
	if not point_counter or not notification:
		return

	# Get the biome name as a lowercase string (e.g., "forest")
	var biome_name_str = BiomeType.keys()[biome_id].to_lower()
	
	# Get the points and mana from the point_counter node
	var points = point_counter.get_points(biome_name_str)
	var magic_points = point_counter.get_points(biome_name_str + "_magic")
	
	# Create the notification text using the retrieved data
	var notification_text = "Biome: %s\nPoints: %d\nMana: %d" % [biome_name_str.capitalize(), points, magic_points]
	
	# Show the notification with the formatted text
	notification.show_instruction_label(notification_text)

func _on_static_body_3d_mouse_exited():
	# Hide the notification panel when the mouse leaves
	if notification:
		notification.hide_panel()
