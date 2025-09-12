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

# --- HAND POSITIONING ---
@export_group("Hand Positioning")
# In the Godot Editor, assign the path to your Hand node here.
# e.g., ../../Deck/Table/DragController/Hand
@export var hand_node_path: NodePath
# Adjust how far the hand appears from the camera (forward/backward).
@export var hand_distance_from_camera: float = 4.0
# Adjust the vertical position of the hand relative to the camera's center.
@export var hand_vertical_offset: float = -0.8
# Adjust the horizontal position of the hand relative to the camera's center.
@export var hand_horizontal_offset: float = 0.0

var hand_node: Node3D
var is_rotating = false

# --- Camera Defaults ---
# A tiny offset on the Z-axis prevents gimbal lock when looking straight down.
var _default_position := Vector3(0, 8.212, 0.001)
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
		printerr("ResponsiveCamera: Hand Node Path is not set in the inspector.")
	
	# Set and store the camera's default starting transform.
	# We create the transform at the default position and make it look at the origin.
	# This is more stable than setting position and rotation separately.
	_default_transform = Transform3D(Basis(), _default_position).looking_at(Vector3.ZERO, Vector3.UP)
	global_transform = _default_transform
	
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
		
		# After moving, orient the camera to look at the center of the board.
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

	# 1. Define the hand's position relative to the camera's local space.
	# The X is for left/right, Y for up/down, and Z for forward/backward from the camera.
	var local_offset = Vector3(hand_horizontal_offset, hand_vertical_offset, -hand_distance_from_camera)

	# 2. Calculate the target world position by transforming the local offset
	#    by the camera's current global transform.
	var target_position = self.global_transform * local_offset
	
	# 3. Calculate the target rotation. We want the hand to have the same
	#    orientation as the camera.
	var target_rotation_basis = self.global_transform.basis

	# 4. Apply the new transform to the hand node.
	hand_node.global_position = target_position
	hand_node.global_transform.basis = target_rotation_basis
