shader_type canvas_item;

uniform sampler2D detail_noise : repeat_enable, filter_linear;
uniform sampler2D flow_noise : repeat_enable, filter_linear;
uniform vec4 tint_color : source_color = vec4(0.92, 0.95, 0.98, 1.0);
uniform float layer_alpha : hint_range(0.0, 1.0) = 0.16;
uniform float density : hint_range(0.0, 1.0) = 0.5;
uniform float softness : hint_range(0.01, 0.5) = 0.24;
uniform vec2 base_scale = vec2(0.9, 0.78);
uniform vec2 detail_scale = vec2(3.2, 1.9);
uniform vec2 flow_scale = vec2(1.2, 0.9);
uniform vec2 drift_a = vec2(0.0016, 0.0);
uniform vec2 drift_b = vec2(-0.001, 0.0007);
uniform float time_sec = 0.0;
uniform float band_top : hint_range(0.0, 1.0) = 0.46;
uniform float band_bottom : hint_range(0.6, 1.2) = 1.05;
uniform vec2 world_offset = vec2(0.0);

void fragment() {
	vec2 uv = UV + world_offset;
	float flow = texture(flow_noise, fract(uv * flow_scale + drift_b * time_sec)).r;
	float base_a = texture(TEXTURE, fract(uv * base_scale + drift_a * time_sec + vec2(flow * 0.06, 0.0))).r;
	float base_b = texture(TEXTURE, fract((uv + vec2(0.19, 0.07)) * (base_scale * vec2(1.24, 0.9)) - drift_a * time_sec * 0.35)).r;
	float detail = texture(detail_noise, fract(uv * detail_scale + drift_b * time_sec * 0.55 + vec2(flow * 0.04, -flow * 0.02))).r;
	float mask = mix(mix(base_a, base_b, 0.46), detail, 0.34);

	float height_band = smoothstep(band_top, band_bottom, UV.y);
	float alpha = smoothstep(1.0 - density - softness, 1.0 - density + softness, mask) * height_band;
	alpha *= mix(0.72, 1.0, smoothstep(0.0, 0.4, UV.y));
	alpha *= layer_alpha;

	vec3 rgb = tint_color.rgb * mix(1.04, 0.92, smoothstep(0.35, 1.0, UV.y));
	COLOR = vec4(rgb, tint_color.a * alpha);
}
