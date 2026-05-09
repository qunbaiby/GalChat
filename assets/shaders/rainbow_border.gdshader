shader_type canvas_item;

uniform vec4 color1 : source_color = vec4(0.0, 0.8, 1.0, 1.0); // 青蓝色
uniform vec4 color2 : source_color = vec4(1.0, 0.0, 0.5, 1.0); // 品红色
uniform float speed : hint_range(0.1, 5.0) = 1.0;
uniform float border_width : hint_range(0.01, 0.5) = 0.015; // 极细边框
uniform float blur : hint_range(0.0, 0.1) = 0.005; // 边缘轻微发光
uniform float progress : hint_range(0.0, 1.0) = 1.0; // 进度条进度

void fragment() {
    // 将 UV 坐标映射到以中心为原点 (-0.5 到 0.5)
    vec2 center_uv = UV - vec2(0.5);
    
    // 计算当前像素点到中心的距离
    float dist = length(center_uv);
    
    // 计算当前像素点的进度角度 (以顶部为起点，顺时针方向，范围 0 到 1)
    float angle_prog = atan(center_uv.x, -center_uv.y);
    if (angle_prog < 0.0) {
        angle_prog += 6.28318530718;
    }
    float p = angle_prog / 6.28318530718;
    
    // 进度掩码：大于进度的部分将被过滤
    float progress_mask = step(p, progress);
    
    // 计算当前像素点的旋转渐变角度
    float angle_rot = atan(center_uv.y, center_uv.x);
    
    // 旋转效果：角度加上随时间变化的值
    angle_rot += TIME * speed;
    
    // 将角度映射到 0.0 到 1.0 之间，用于渐变混合
    float t = fract((angle_rot + 3.14159265) / 6.28318530718);
    
    // 使用 smoothstep 计算渐变，让两端可以平滑过渡
    vec4 gradient_color = mix(color1, color2, smoothstep(0.0, 1.0, t < 0.5 ? t * 2.0 : (1.0 - t) * 2.0));
    
    // 绘制圆环边框：在半径 (0.5 - border_width) 到 0.5 之间渲染
    float inner_circle = smoothstep(0.5 - border_width - blur, 0.5 - border_width, dist);
    float outer_circle = smoothstep(0.5, 0.5 - blur, dist);
    
    // 边框的 alpha 掩码
    float border_mask = inner_circle * outer_circle;
    
    // 最终输出：只有进度以内的部分显示高亮渐变色，未达到的部分显示微弱的底色
    vec4 bg_ring = vec4(0.2, 0.2, 0.25, 0.5); // 未激活时的底环颜色
    COLOR = mix(bg_ring, gradient_color, progress_mask);
    COLOR.a *= border_mask;
}
