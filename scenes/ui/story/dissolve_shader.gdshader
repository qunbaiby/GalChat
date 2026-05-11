shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D old_texture;

float random(vec2 uv) {
    return fract(sin(dot(uv.xy, vec2(12.9898,78.233))) * 43758.5453123);
}

void fragment() {
    float noise = random(UV);
    if (noise < progress) {
        COLOR = texture(TEXTURE, UV); // New texture
    } else {
        COLOR = texture(old_texture, UV); // Old texture
    }
}
