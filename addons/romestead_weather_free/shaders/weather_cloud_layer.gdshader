shader_type canvas_item;

uniform sampler2D detail_noise : repeat_enable, filter_linear;
uniform sampler2D flow_noise : repeat_enable, filter_linear;
uniform vec4 tint_color : source_color = vec4(0.82, 0.86, 0.93, 1.0);
uniform float layer_alpha : hint_range(0.0, 1.0) = 0.2;
uniform float density : hint_range(0.0, 1.0) = 0.56;
uniform float softness : hint_range(0.01, 0.5) = 0.18;
uniform vec2 base_scale = vec2(1.2, 0.85);
uniform vec2 detail_scale = vec2(3.5, 2.2);
uniform vec2 flow_scale = vec2(1.3, 1.0);
uniform vec2 drift_a = vec2(0.004, 0.0);
uniform vec2 drift_b = vec2(-0.002, 0.001);
uniform float time_sec = 0.0;
uniform float band_top : hint_range(0.0, 1.0) = 0.0;
uniform float band_bottom : hint_range(0.0, 1.2) = 0.58;
uniform float edge_breakup : hint_range(0.0, 1.0) = 0.32;
uniform float highlight : hint_range(0.0, 0.4) = 0.08;
uniform float storminess : hint_range(0.0, 1.0) = 0.0;
uniform vec2 world_offset = vec2(0.0);

void fragment() {
	vec2 uv = UV + world_offset;
	vec2 flow_uv = fract(uv * flow_scale + drift_b * time_sec);
	float flow = texture(flow_noise, flow_uv).r;

	vec2 base_uv_a = fract(uv * base_scale + drift_a * time_sec + vec2(flow * 0.08, flow * 0.03));
	vec2 base_uv_b = fract((uv + vec2(0.37, 0.11)) * (base_scale * vec2(1.13, 0.93)) - drift_a * time_sec * 0.42 + vec2(-flow * 0.05, flow * 0.02));
	float base_a = texture(TEXTURE, base_uv_a).r;
	float base_b = texture(TEXTURE, base_uv_b).r;
	float base_shape = mix(base_a, base_b, 0.42);

	float detail = texture(detail_noise, fract(uv * detail_scale + drift_b * time_sec * 0.6 + vec2(flow * 0.05, -flow * 0.03))).r;
	float breakup = mix(detail, flow, 0.4);
	float mask = mix(base_shape, base_shape * breakup + breakup * 0.25, edge_breakup);
	float band = 1.0 - smoothstep(band_top, band_bottom, UV.y);
	float alpha = smoothstep(1.0 - density - softness, 1.0 - density + softness, mask * band) * layer_alpha;

	vec3 rgb = tint_color.rgb;
	float top_light = (1.0 - smoothstep(band_top, mix(band_top, band_bottom, 0.78), UV.y)) * highlight * (1.0 - storminess);
	float underside = smoothstep(mix(band_top, band_bottom, 0.35), band_bottom, UV.y);
	rgb += vec3(top_light);
	rgb *= 1.0 - underside * mix(0.08, 0.24, storminess);

	COLOR = vec4(rgb, tint_color.a * alpha);
}
