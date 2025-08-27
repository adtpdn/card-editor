shader_type spatial;
// Use blend_mix to allow for transparency
render_mode blend_mix;

// Uniforms to control the effect from the Inspector
uniform sampler2D TEXTURE; // The main texture for the object
uniform vec4 tint_color : source_color = vec4(1.0, 1.0, 1.0, 1.0); // A color to tint the texture
uniform float frequency = 1.0; // How fast the pulse effect is
uniform float max_opacity : hint_range(0.0, 1.0) = 1.0; // The brightest the object will be
uniform float min_opacity : hint_range(0.0, 1.0) = 0.0; // The dimmest the object will be

void fragment() {
	// Sample the color from the texture at the current UV coordinate
	vec4 tex_color = texture(TEXTURE, UV);

	// Create a pulsating value between 0.0 and 1.0 using a sine wave.
	// (sin(TIME) gives a value from -1 to 1, so we remap it to 0 to 1 for a smooth pulse)
	float pulse = (sin(frequency * TIME) + 1.0) / 2.0;

	// Use the pulse to smoothly interpolate between the minimum and maximum opacity
	float final_opacity = mix(min_opacity, max_opacity, pulse);

	// Apply the tint color to the texture's RGB channels
	ALBEDO = tex_color.rgb * tint_color.rgb;

	// Combine the texture's alpha, the tint's alpha, and the final pulsating opacity
	ALPHA = tex_color.a * tint_color.a * final_opacity;
}
