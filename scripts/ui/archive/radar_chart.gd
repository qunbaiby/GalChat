extends Control

@export var labels: Array[String] = ["开放性", "尽责性", "外倾性", "宜人性", "神经质"]
@export var max_value: float = 100.0
@export var grid_color: Color = Color(1, 1, 1, 0.15)
@export var base_color: Color = Color(0.6, 0.6, 0.6, 0.3)
@export var dynamic_color: Color = Color(0.1, 0.8, 0.85, 0.6)
@export var label_color: Color = Color(0.9, 0.9, 0.9, 1)

var base_values: Array[float] = [50, 50, 50, 50, 50]
var dynamic_values: Array[float] = [50, 50, 50, 50, 50]

func set_values(base: Array[float], dynamic: Array[float]):
    base_values = base
    dynamic_values = dynamic
    queue_redraw()

func _draw():
    var center = size / 2.0
    var radius = min(size.x, size.y) / 2.0 * 0.65 # 留出空间给标签
    var num_points = labels.size()
    
    if num_points < 3: return
    
    # 绘制网格 (五边形)
    var grid_steps = 4
    for i in range(1, grid_steps + 1):
        var r = radius * (float(i) / grid_steps)
        var points = PackedVector2Array()
        for j in range(num_points):
            var angle = _get_angle(j, num_points)
            points.append(center + Vector2(cos(angle), sin(angle)) * r)
        points.append(points[0]) # 闭合多边形
        draw_polyline(points, grid_color, 1.0, true)
        
    # 绘制轴线和标签
    var font = ThemeDB.fallback_font
    var font_size = 14
    for j in range(num_points):
        var angle = _get_angle(j, num_points)
        var dir = Vector2(cos(angle), sin(angle))
        draw_line(center, center + dir * radius, grid_color, 1.0, true)
        
        # 绘制标签
        var label_pos = center + dir * (radius + 25)
        var text = labels[j]
        var string_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
        draw_string(font, label_pos - string_size / 2.0 + Vector2(0, font_size/3.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, label_color)

    # 绘制初始性格多边形 (底色)
    _draw_data_polygon(center, radius, num_points, base_values, base_color, Color(base_color, 0.8))
    
    # 绘制动态性格多边形 (当前值)
    _draw_data_polygon(center, radius, num_points, dynamic_values, dynamic_color, Color(dynamic_color.r, dynamic_color.g, dynamic_color.b, 1.0))

func _draw_data_polygon(center: Vector2, radius: float, num_points: int, values: Array[float], fill_color: Color, stroke_color: Color):
    var points = PackedVector2Array()
    for j in range(num_points):
        var angle = _get_angle(j, num_points)
        var val = clamp(values[j] / max_value, 0.0, 1.0)
        points.append(center + Vector2(cos(angle), sin(angle)) * (radius * val))
    
    if points.size() >= 3:
        var poly_colors = PackedColorArray()
        for i in range(points.size()):
            poly_colors.append(fill_color)
        draw_polygon(points, poly_colors)
        
        # 绘制描边
        var line_points = points.duplicate()
        line_points.append(points[0])
        draw_polyline(line_points, stroke_color, 2.0, true)

func _get_angle(index: int, total: int) -> float:
    # 从顶部开始 (-PI/2)
    return -PI/2.0 + (TAU * float(index) / total)
