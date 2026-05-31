shader_type canvas_item;

uniform vec4 center_color : source_color = vec4(0.02, 0.02, 0.03, 0.9);
uniform vec4 edge_color : source_color = vec4(0.02, 0.02, 0.03, 0.45);
uniform float edge_softness : hint_range(0.0, 1.0) = 0.85;

void fragment() {
	float distance_to_center = abs(UV.x - 0.5) * 2.0;
	float t = smoothstep(0.0, max(edge_softness, 0.001), distance_to_center);
	COLOR = mix(center_color, edge_color, t);
}
