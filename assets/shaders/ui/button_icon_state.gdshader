shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(0.07, 0.24, 0.22, 1.0);
uniform vec4 shadow_color : source_color = vec4(0.02, 0.12, 0.11, 0.78);
uniform float outline_size : hint_range(0.0, 4.0) = 1.35;
uniform float shadow_size : hint_range(0.0, 8.0) = 2.4;

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	vec2 pixel = TEXTURE_PIXEL_SIZE;
	float outline_alpha = 0.0;
	float shadow_alpha = 0.0;

	for (int x = -2; x <= 2; x++) {
		for (int y = -2; y <= 2; y++) {
			vec2 direction = vec2(float(x), float(y));
			float distance_factor = length(direction);
			if (distance_factor > 0.0 && distance_factor <= outline_size + 0.75) {
				outline_alpha = max(outline_alpha, texture(TEXTURE, UV + direction * pixel).a);
			}
		}
	}

	vec2 shadow_offset = vec2(shadow_size, shadow_size) * pixel;
	shadow_alpha = texture(TEXTURE, UV - shadow_offset).a;
	vec4 result = shadow_color * shadow_alpha * (1.0 - outline_alpha);
	result = mix(result, outline_color, outline_alpha * (1.0 - source.a));
	result = mix(result, source, source.a);
	COLOR = result * COLOR;
}