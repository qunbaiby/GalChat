shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float shatter_scale = 10.0;

// Random noise function
float random(vec2 st) {
    return fract(sin(dot(st.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

void fragment() {
    vec2 uv = SCREEN_UV;
    
    // Scale UV for grid cells
    vec2 grid_uv = uv * shatter_scale;
    vec2 id = floor(grid_uv);
    
    // Create random rotation and offset for each cell based on progress
    float rand_val = random(id);
    float angle = rand_val * 6.28318 * progress * 2.0; // Rotate up to 2 full circles
    
    vec2 center = (id + 0.5) / shatter_scale;
    
    // Offset outwards from center based on progress and random value
    vec2 dir = normalize(center - vec2(0.5));
    vec2 offset = dir * progress * (0.5 + rand_val * 0.5);
    
    // Apply rotation
    vec2 diff = uv - center;
    float s = sin(angle);
    float c = cos(angle);
    vec2 rotated_diff = vec2(
        diff.x * c - diff.y * s,
        diff.x * s + diff.y * c
    );
    
    // Sample texture with distorted UV
    vec2 final_uv = center + rotated_diff - offset;
    
    // Fade out pieces that move too far or when progress is high
    float alpha = 1.0 - smoothstep(0.5, 1.0, progress);
    
    // Only draw if within screen bounds
    if (final_uv.x >= 0.0 && final_uv.x <= 1.0 && final_uv.y >= 0.0 && final_uv.y <= 1.0) {
        vec4 color = textureLod(screen_texture, final_uv, 0.0);
        COLOR = vec4(color.rgb, color.a * alpha);
    } else {
        COLOR = vec4(0.0);
    }
}
