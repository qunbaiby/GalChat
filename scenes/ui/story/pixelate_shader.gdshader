shader_type canvas_item;

uniform float pixel_size : hint_range(1.0, 100.0) = 1.0;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

void fragment() {
    vec2 size = 1.0 / SCREEN_PIXEL_SIZE;
    if (pixel_size > 1.0) {
        vec2 uv = floor(SCREEN_UV * size / pixel_size) * pixel_size / size;
        COLOR = textureLod(screen_texture, uv, 0.0);
    } else {
        COLOR = textureLod(screen_texture, SCREEN_UV, 0.0);
    }
}
