shader_type spatial;

uniform vec4 aoe_color : source_color = vec4(1.0, 0.0, 0.0, 0.3); // Color for filled area and solid outline
uniform float fill_value : hint_range(0.0, 1.0, 0.1) = 0.5; // Controls the filled circle radius as a fraction of solid_radius
uniform float solid_radius : hint_range(0.0, 0.5, 0.01) = 0.5; // Radius of the solid outline
uniform float solid_width : hint_range(0.001, 0.1, 0.001) = 0.01; // Width of the solid outline
uniform float dashed_radius : hint_range(0.0, 0.5, 0.01) = 0.4; // Radius of the dashed border
uniform float dashed_border_width : hint_range(0.001, 0.1, 0.001) = 0.02; // Width of the dashed border
uniform float dash_length : hint_range(0.01, 0.5, 0.01) = 0.1; // Length of each dash
uniform float dash_gap : hint_range(0.01, 0.5, 0.01) = 0.05; // Gap between dashes
uniform float speed : hint_range(0.0, 5.0, 0.1) = 1.0; // Speed of dash rotation
uniform vec4 dashed_border_color : source_color = vec4(1.0, 1.0, 1.0, 1.0); // Color of the dashed border

void fragment() {
    vec2 center = vec2(0.5, 0.5);
    vec2 uv = UV - center;
    float dist = length(uv);
    ALPHA = 0.0;
    ALBEDO = vec3(0.0);

    // Filled circle, scaled by solid_radius
    if (dist < fill_value * solid_radius) {
        ALPHA = aoe_color.a;
        ALBEDO = aoe_color.rgb;
    }

    // Solid outline
    float solid_edge = abs(dist - solid_radius);
    if (solid_edge < solid_width) {
        ALPHA = aoe_color.a;
        ALBEDO = aoe_color.rgb;
    }

    // Dashed border
    float angle = atan(uv.y, uv.x); // -PI..PI
    angle = (angle + 3.141592) / (2.0 * 3.141592); // 0..1
    angle = fract(angle + TIME * speed);
    float dash_cycle = dash_length + dash_gap;
    float pattern_pos = mod(angle, dash_cycle);
    float edge = abs(dist - dashed_radius);

    if (edge < dashed_border_width && pattern_pos < dash_length) {
        ALPHA = dashed_border_color.a;
        ALBEDO = dashed_border_color.rgb;
    }
}