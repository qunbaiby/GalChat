shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D old_texture;
uniform vec2 direction = vec2(1.0, 0.0); // (1,0) for right, (-1,0) for left, (0,1) for down, (0,-1) for up

void fragment() {
    vec2 uv = UV;
    
    float wipe_pos = 0.0;
    if (direction.x > 0.5) wipe_pos = uv.x;
    else if (direction.x < -0.5) wipe_pos = 1.0 - uv.x;
    else if (direction.y > 0.5) wipe_pos = uv.y;
    else if (direction.y < -0.5) wipe_pos = 1.0 - uv.y;
    
    if (wipe_pos < progress) {
        COLOR = texture(TEXTURE, UV); // New texture
    } else {
        COLOR = texture(old_texture, UV); // Old texture
    }
}
