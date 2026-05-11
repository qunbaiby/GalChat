shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D old_texture;

float random(vec2 uv) {
    return fract(sin(dot(uv.xy, vec2(12.9898,78.233))) * 43758.5453123);
}

void fragment() {
    vec2 uv = UV;
    
    float intensity = (0.5 - abs(progress - 0.5)) * 0.5; // Max intensity in the middle
    
    if (intensity > 0.0) {
        float glitch_band = step(0.8, random(vec2(floor(uv.y * 10.0), TIME)));
        float offset = (random(vec2(TIME, floor(uv.y * 10.0))) - 0.5) * intensity * glitch_band;
        uv.x += offset;
    }
    
    vec4 old_c = texture(old_texture, uv);
    vec4 new_c = texture(TEXTURE, uv);
    
    // RGB split effect during glitch
    if (intensity > 0.0) {
        float r_old = texture(old_texture, uv + vec2(intensity, 0.0)).r;
        float b_old = texture(old_texture, uv - vec2(intensity, 0.0)).b;
        old_c = vec4(r_old, old_c.g, b_old, old_c.a);
        
        float r_new = texture(TEXTURE, uv + vec2(intensity, 0.0)).r;
        float b_new = texture(TEXTURE, uv - vec2(intensity, 0.0)).b;
        new_c = vec4(r_new, new_c.g, b_new, new_c.a);
    }
    
    COLOR = mix(old_c, new_c, progress);
}
