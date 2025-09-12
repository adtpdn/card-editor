class_name ResponsiveCamera
extends Camera3D

# --- CONFIGURATION ---
# Set the range of aspect ratios you want to support.
# 1.77 is a standard 16:9 widescreen, 0.56 is a common portrait phone ratio.
@export var min_aspect_ratio: float = 0.56
@export var max_aspect_ratio: float = 1.77

# Set the desired Field of View (FOV) for the min and max aspect ratios.
# A wider screen (max_aspect_ratio) will have a wider FOV.
@export var min_fov: float = 75.0
@export var max_fov: float = 90.0

# --- ZOOMING ---
@export var zoom_sensitivity: float = 0.5
@export var min_zoom_distance: float = 3.0
@export var max_zoom_distance: float = 10.0

# --- HAND POSITIONING ---
# In the Godot Editor, assign the path to your Hand node here.
# e.g., ../../Deck/Table/DragController/Hand
@export var hand_node_path: NodePath

# Adjust how far the hand appears from the camera.
@export var hand_distance_from_camera: float = 4.0

# Adjust the vertical position of the hand (e.g., 0.98 is 98% from the top).
@export var hand_bottom_margin_percent: float = 0.9

var hand_node: Node3D

# --- LIFECYCLE ---
func _ready():
	# Connect to the viewport's size_changed signal. This function will be called
	# automatically whenever the game window is resized.
	get_viewport().size_changed.connect(_on_viewport_size_changed)

	# Get the hand node from the path provided in the editor.
	if not hand_node_path.is_empty():
		hand_node = get_node_or_null(hand_node_path)
		if not hand_node:
			printerr("ResponsiveCamera: Hand node not found at path: ", hand_node_path)
	else:
		printerr("ResponsiveCamera: Hand Node Path is not set in the inspector.")
	
	# Call the function once at the start to set the initial camera properties.
	_on_viewport_size_changed()

# --- INPUT HANDLING ---
func _input(event: InputEvent):
	if event is InputEventMouseButton:
		var zoom_direction = 0.0
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_direction = 1.0 # Zoom in
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_direction = -1.0 # Zoom out

		if zoom_direction != 0.0:
			# Get the camera's forward vector to determine the zoom direction
			var forward_vector = -global_transform.basis.z
			var new_position = global_position + forward_vector * zoom_direction * zoom_sensitivity
			
			# Check the new distance from the origin (assuming we pivot around the center of the board)
			var distance_from_origin = new_position.length()
			
			# Only apply the new position if it's within the allowed zoom range
			if distance_from_origin >= min_zoom_distance and distance_from_origin <= max_zoom_distance:
				global_position = new_position
			
			# After any potential zoom, update the hand's position to keep it anchored.
			_update_hand_position()
			
			# Mark the event as handled to prevent other nodes from processing it.
			get_viewport().set_input_as_handled()


# --- PRIVATE METHODS ---

# This function is the core of the responsive logic.
func _on_viewport_size_changed():
	# 1. Get the current size of the game window (viewport).
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	
	# 2. Calculate the current aspect ratio.
	var current_aspect_ratio: float = viewport_size.x / viewport_size.y
	
	# 3. Use inverse_lerp to find out where our current aspect ratio sits
	#    within our defined min/max range, on a scale of 0.0 to 1.0.
	#    The clamp ensures the value doesn't go outside this range.
	var t: float = inverse_lerp(min_aspect_ratio, max_aspect_ratio, current_aspect_ratio)
	t = clamp(t, 0.0, 1.0)
	
	# 4. Use lerp to interpolate between our min and max FOV values using the
	#    factor 't' we just calculated. This gives us the ideal FOV for the
	#    current screen size.
	var new_fov: float = lerp(min_fov, max_fov, t)
	
	# 5. Apply the new FOV to the camera.
	self.fov = new_fov
	
	print("Viewport resized: Aspect Ratio=%.2f, New FOV=%.2f" % [current_aspect_ratio, new_fov])
	
	# --- Update Hand Position ---
	_update_hand_position()


# Recalculates and sets the 3D position of the hand node.
func _update_hand_position():
	# Exit if the hand node isn't valid.
	if not is_instance_valid(hand_node):
		return

	# 1. Get viewport and define the target 2D screen position for the hand (bottom center).
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var screen_pos := Vector2(viewport_size.x / 2.0, viewport_size.y * hand_bottom_margin_percent)

	# 2. Project a ray from the camera through that screen point into the 3D world.
	var ray_origin := self.project_ray_origin(screen_pos)
	var ray_normal := self.project_ray_normal(screen_pos)

	# 3. Calculate the target position in 3D space along the ray.
	var target_pos := ray_origin + ray_normal * hand_distance_from_camera

	# 4. Apply the new global position to the hand node.
	hand_node.global_position = target_pos
