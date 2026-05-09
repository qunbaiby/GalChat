shader_type canvas_item;

// 梯形顶部的向右偏移量（相对于按钮高度的比例）
uniform float slant : hint_range(0.0, 1.0) = 0.3;
// 裁剪的圆角半径（相对于按钮高度的比例）
uniform float corner_radius : hint_range(0.0, 0.5) = 0.15;
// 按钮的宽高比 (宽度 / 高度)，用于保证圆角是正圆而不是椭圆
uniform float aspect_ratio = 2.2;

// 边框设置
uniform float border_width : hint_range(0.0, 0.2) = 0.02;
uniform vec4 border_color : source_color = vec4(0.5, 0.6, 0.7, 1.0);

void fragment() {
    // 归一化坐标，使 y 在 [0, 1]，x 在 [0, aspect_ratio]
    vec2 p = vec2(UV.x * aspect_ratio, UV.y);
    
    // 计算到三个边界的外向距离 (大于 0 表示在边界外)
    float d_top = -p.y;
    float d_bot = p.y - 1.0;
    
    // 倾斜边界的起点和法线
    vec2 A = vec2(slant, 0.0);
    float L = sqrt(1.0 + slant * slant);
    vec2 N = vec2(-1.0, -slant) / L; // 指向左上方（外部）
    
    float d_slant = dot(p - A, N);
    
    // 右侧边界距离计算 (右边缘是直角，在 aspect_ratio 处)
    float d_right = p.x - aspect_ratio;
    
    // 扩展边界以计算圆角
    float D1 = d_top + corner_radius;
    float D2 = d_bot + corner_radius;
    float D3 = d_slant + corner_radius;
    float D4 = d_right + corner_radius;
    
    // 计算到扩展后多边形的欧几里得距离
    vec4 D = vec4(D1, D2, D3, D4);
    vec4 D_max = max(D, vec4(0.0));
    float d_euclidean = length(D_max) + min(max(max(D1, D2), max(D3, D4)), 0.0);
    
    // 减去圆角半径得到最终的带圆角的距离场
    float d_final = d_euclidean - corner_radius;
    
    // 平滑边缘抗锯齿
    float edge_softness = fwidth(d_final);
    // 防止 fwidth 在某些设备上返回 0 导致除以 0
    edge_softness = max(edge_softness, 0.001);
    
    float mask = 1.0 - smoothstep(-edge_softness, edge_softness, d_final);
    
    // 边框掩码：当距离接近 0（即在边缘 border_width 范围内）时为 1
    float border_mask = smoothstep(-border_width - edge_softness, -border_width + edge_softness, d_final);
    
    // 混合边框颜色与原本的背景/内容颜色
    // 如果原本是透明背景，边框依然保持可见，所以使用 mix
    vec4 final_color = mix(COLOR, border_color, border_mask * border_color.a);
    
    // 裁剪外部
    final_color.a *= mask;
    
    COLOR = final_color;
}
