shader_type canvas_item;

// 梯形顶部的向右偏移量（相对于实际形状高度的比例）
uniform float slant : hint_range(0.0, 1.0) = 0.3;
// 裁剪的圆角半径（相对于实际形状高度的比例）
uniform float corner_radius : hint_range(0.0, 0.5) = 0.15;
// 按钮整体的宽高比 (宽度 / 高度)
uniform float aspect_ratio = 2.2;
// 新增：边距比例，用于在周围留出空间绘制外发光
uniform float padding : hint_range(0.0, 0.5) = 0.0;

// 边框设置
uniform float border_width : hint_range(0.0, 0.2) = 0.02;
uniform vec4 border_color : source_color = vec4(0.5, 0.6, 0.7, 1.0);

// 新增发光设置
uniform float glow_size : hint_range(0.0, 0.5) = 0.0;
uniform vec4 glow_color : source_color = vec4(0.0, 0.8, 1.0, 0.0);

// 新增背景颜色设置
uniform vec4 bg_color : source_color = vec4(0.0, 0.0, 0.0, 0.0);

void fragment() {
    // 将 UV 映射到实际坐标系
    vec2 p = vec2(UV.x * aspect_ratio, UV.y);
    
    // 实际形状的边界计算 (扣除 padding)
    float d_top = padding - p.y;
    float d_bot = p.y - (1.0 - padding);
    
    float shape_height = 1.0 - 2.0 * padding;
    
    // 斜边计算
    vec2 A = vec2(padding + slant * shape_height, padding);
    float L = sqrt(1.0 + slant * slant);
    vec2 N = vec2(-1.0, -slant) / L; // 指向左上方（外部）
    
    float d_slant = dot(p - A, N);
    
    // 右侧边界距离计算
    float d_right = p.x - (aspect_ratio - padding);
    
    // 扩展边界以计算圆角
    float r = corner_radius * shape_height;
    
    float D1 = d_top + r;
    float D2 = d_bot + r;
    float D3 = d_slant + r;
    float D4 = d_right + r;
    
    vec4 D = vec4(D1, D2, D3, D4);
    vec4 D_max = max(D, vec4(0.0));
    float d_euclidean = length(D_max) + min(max(max(D1, D2), max(D3, D4)), 0.0);
    
    // 减去圆角半径得到最终的带圆角的距离场
    float d_final = d_euclidean - r;
    
    // 平滑边缘抗锯齿
    float edge_softness = fwidth(d_final);
    edge_softness = max(edge_softness, 0.001);
    
    float mask = 1.0 - smoothstep(-edge_softness, edge_softness, d_final);
    
    // 边框掩码
    float border_mask = smoothstep(-border_width - edge_softness, -border_width + edge_softness, d_final);
    
    // 发光掩码：
    float glow_mask = 0.0;
    if (glow_size > 0.0) {
        glow_mask = 1.0 - smoothstep(0.0, glow_size, d_final);
        glow_mask *= smoothstep(-edge_softness, edge_softness, d_final); // 限制在外部
    }
    
    // 如果没有通过 COLOR 传入或者想要覆盖 COLOR，这里使用 bg_color 作为基础色
    vec4 base_color = bg_color.a > 0.0 ? bg_color : COLOR;
    
    // 混合边框颜色与原本的背景/内容颜色
    vec4 final_color = mix(base_color, border_color, border_mask * border_color.a);
    
    // 裁剪外部
    final_color.a *= mask;
    
    if (glow_size > 0.0) {
        vec4 glow = glow_color;
        glow.a *= glow_mask;
        final_color = final_color + glow * (1.0 - final_color.a);
    }
    
    COLOR = final_color;
}
