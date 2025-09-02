extends CPUParticles2D

const CURSOR_TRAIL = preload("res://scenes/cursor_trail.tscn")

func _ready():
	var new_cursor = load("res://assets/ui/cursor/cursor_32px.png")
	# Define the hotspot (the click point)
	var hotspot = Vector2(8, 0)
	# Apply the custom cursor
	Input.set_custom_mouse_cursor(new_cursor, Input.CURSOR_ARROW, hotspot)
	
	# Create a new tween to handle the animation
	var tween = create_tween()
	
	# Animate the 'modulate' property. We only want to change the alpha (transparency).
	# This will make the sprite fade from fully visible to fully transparent over its lifetime.
	tween.tween_property(self, "modulate:a", 0.0, lifetime)
	
	# Once the fade animation is finished, remove the trail piece from the scene
	tween.tween_callback(queue_free)
