// Godot 4.x Pulsating Fade and Shine Shader
shader_type spatial;

// This render_mode is essential for transparency to work.
// 'blend_mix' mixes the object's color with the background based on alpha.
// 'depth_draw_opaque' ensures it still interacts with the depth buffer correctly.
// 'cull_back' is the default but good to be explicit.
render_mode blend_mix, depth_draw_opaque, cull_back;

// --- Uniforms ---
// You can control these values from the Godot Inspector panel.

// Controls the color of the shine effect
uniform vec4 shine_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// Controls how fast the effect pulsates
uniform float shine_speed : hint_range(0.1, 10.0, 0.1) = 1.0;

// Controls the hardness of the effect's edge
uniform float smoothness : hint_range(0.0, 1.0, 0.01) = 0.5;


void vertex() {
	// No changes needed in the vertex function for this effect.
	// It processes the 3D model's geometry as usual.
}

void fragment() {
	// --- Pulsating Effect Logic ---
	// Create a pulsating value using a sine wave based on time.
	float shine = abs(sin(TIME * shine_speed));

	// Smooth the hard edge of the sine wave for a nicer glow.
	// This will be used for both color and fade for a cohesive effect.
	float smooth_shine = smoothstep(0.0, smoothness, shine);

	// Mix the object's original color (ALBEDO) with the shine color.
	// The 'smooth_shine' value determines the mix ratio.
	ALBEDO = mix(ALBEDO, shine_color.rgb, smooth_shine);

	// --- Fading Logic ---
	// Set the object's final alpha based on the same pulsating value.
	// The object will become more transparent as the shine effect fades out
	// and more opaque as it shines brightly.
	ALPHA = smooth_shine;
}
