shader_type canvas_item;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 centered = UV - vec2(0.5);
	float dist = length(centered);

	if (dist > 0.5) {
		discard;
	}

	COLOR = tex * COLOR;
}
