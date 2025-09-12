class_name GameCamera3D
extends Camera3D

# --- CONFIGURATION ---
@export_group("Responsiveness")
# Set the range of aspect ratios you want to support.
# 1.77 is a standard 16:9 widescreen, 0.56 is a common portrait phone ratio.
@export var min_aspect_ratio: float = 0.56
@export var max_aspect_ratio: float = 1.77
# Set the desired Field of View (FOV) for the min and max aspect ratios.
# A wider screen (max_aspect_ratio) will have a wider FOV.
@export var min_fov: float = 75.0
@export var max_fov: float = 90.0

# --- ZOOMING ---
@export_group("Zooming")
# A smaller value creates a smoother, slower zoom interpolation.
@export var zoom_speed: float = 0.1

# --- ROTATION ---
@export_group("Rotation")
@export var rotation_sensitivity: float = 0.005
@export var min_pitch_degrees: float = 15.0 # How close to horizontal the camera can get
@export var max_pitch_degrees: float = 85.0 # How close to top-down the camera can get

# --- HAND POSITIONING ---
@export_group("Hand Positioning")
# In the Godot Editor, assign the path to your Hand node here.
# e.g., ../../Deck/Table/DragController/Hand
@export var hand_node_path: NodePath
# Adjust how far the hand appears from the camera.
@export var hand_distance_from_camera: float = 4.0
# Adjust the vertical position of the hand (e.g., 0.98 is 98% from the top).
@export var hand_bottom_margin_percent: float = 0.9

var hand_node: Node3D
var is_rotating = false
var initial_hand_rotation: Vector3

# --- Camera Defaults ---
var _default_position := Vector3(0, 8.212, 0)
var _default_rotation_degrees := Vector3(-90, 0, 0) # -90 is a stable top-down view
var _default_transform: Transform3D

var _max_zoom_in_position := Vector3(0, 6.181, -0.01)
# We only need the distance (length) for the new zoom logic.
var _max_zoom_in_distance: float


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
			# Store the initial rotation of the hand node.
			initial_hand_rotation = hand_node.global_rotation
	else:
		printerr("ResponsiveCamera: Hand Node Path is not set in the inspector.")
	
	# Set and store the camera's default starting transform.
	global_position = _default_position
	rotation_degrees = _default_rotation_degrees
	_default_transform = global_transform
	
	# Calculate the zoom-in distance from the position vector's length.
	_max_zoom_in_distance = _max_zoom_in_position.length()
	
	# Call the function once at the start to set the initial camera properties.
	_on_viewport_size_changed()

func _process(_delta):
	# The _process function is no longer needed for input handling.
	# All logic has been moved to _unhandled_input for better reliability.
	pass

# --- INPUT HANDLING ---
func _unhandled_input(event: InputEvent):
	# --- MOUSE BUTTON PRESS/RELEASE for ROTATION ---
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			is_rotating = true
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		else:
			is_rotating = false
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		get_viewport().set_input_as_handled() # Consume the click event so UI doesn't react
		return

	# --- MOUSE ROTATION (MOTION ONLY) ---
	if event is InputEventMouseMotion and is_rotating:
		# --- Improved Orbit Rotation ---
		# Horizontal rotation (Yaw) rotates the camera's position around the world's UP vector.
		var yaw_change = -event.relative.x * rotation_sensitivity
		global_position = global_position.rotated(Vector3.UP, yaw_change)
		
		# Vertical rotation (Pitch) rotates the camera's position around its local right vector.
		var pitch_change = -event.relative.y * rotation_sensitivity
		var right_vector = global_transform.basis.x
		global_position = global_position.rotated(right_vector, pitch_change)
		
		# Clamp the vertical angle to prevent flipping over.
		var direction_to_center = (Vector3.ZERO - global_position).normalized()
		var angle_with_up = rad_to_deg(direction_to_center.angle_to(Vector3.DOWN))
		
		var min_angle = min_pitch_degrees
		var max_angle = max_pitch_degrees

		if angle_with_up < min_angle or angle_with_up > max_angle:
			# If the angle is out of bounds, revert the last pitch change.
			global_position = global_position.rotated(right_vector, -pitch_change)
		
		# After moving, orient the camera to look at the center of the board.
		# This replaces the look_at() function by creating a new transform with the correct orientation.
		global_transform = global_transform.looking_at(Vector3.ZERO, Vector3.UP)
		
		# Force the Z-axis rotation (roll) to zero.
		# This ensures the camera never tilts sideways.
		var new_rotation = rotation_degrees
		new_rotation.z = 0
		rotation_degrees = new_rotation
		
		# Update the hand's position to keep it anchored after rotation.
		_update_hand_position()
		
		get_viewport().set_input_as_handled()
		return # Exit after handling rotation

	# --- MOUSE ZOOM ---
	if event is InputEventMouseButton:
		var zoom_direction = 0.0
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_direction = 1.0 # Zoom in
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_direction = -1.0 # Zoom out

		if zoom_direction != 0.0:
			# ZOOM IN: Move towards the max zoom-in distance while preserving rotation.
			if zoom_direction > 0:
				# 1. Get the direction from the camera to the board's center.
				var direction_to_center = (global_position - Vector3.ZERO).normalized()
				
				# 2. Calculate the target position by starting at the center and moving
				#    outwards along the current direction by the max zoom-in distance.
				var target_position = Vector3.ZERO + direction_to_center * _max_zoom_in_distance
				
				# 3. Smoothly interpolate only the camera's position towards the target.
				global_position = global_position.lerp(target_position, zoom_speed)
			
			# ZOOM OUT: Move back towards the default top-down view (position and rotation)
			else:
				global_transform = global_transform.interpolate_with(_default_transform, zoom_speed)
			
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
	
	# 5. Reset the hand's global rotation to its initial state to prevent it from moving with the camera.
	hand_node.global_rotation = initial_hand_rotation
