extends Control

@export var labels: Array[String] = ["开放性", "尽责性", "外倾性", "宜人性", "神经质"]
@export var max_value: float = 100.0
@export var grid_color: Color = Color(0.77, 0.73, 0.68, 0.45)
@export var base_color: Color = Color(0.65, 0.66, 0.71, 0.22)
@export var dynamic_color: Color = Color(0.2, 0.75, 0.79, 0.58)
@export var label_color: Color = Color(0.43, 0.39, 0.35, 1)

var base_values: Array[float] = [50, 50, 50, 50, 50]
var dynamic_values: Array[float] = [50, 50, 50, 50, 50]

func set_values(base: Array[float], dynamic: Array[float]) -> void:
	base_values = base
	dynamic_values = dynamic
	queue_redraw()

func _draw() -> void:
	var padding: Vector2 = Vector2(42, 36)
	var chart_rect: Rect2 = Rect2(padding * 0.5, size - padding)
	var center: Vector2 = chart_rect.position + chart_rect.size * 0.5
	var radius: float = min(chart_rect.size.x, chart_rect.size.y) * 0.34
	var num_points: int = labels.size()

	if num_points < 3:
		return

	var grid_steps: int = 4
	for i in range(1, grid_steps + 1):
		var r: float = radius * (float(i) / grid_steps)
		var points: PackedVector2Array = PackedVector2Array()
		for j in range(num_points):
			var angle: float = _get_angle(j, num_points)
			points.append(center + Vector2(cos(angle), sin(angle)) * r)
		points.append(points[0])
		draw_polyline(points, grid_color, 1.0, true)

	var font: Font = ThemeDB.fallback_font
	var font_size: int = 14
	for j in range(num_points):
		var angle: float = _get_angle(j, num_points)
		var dir: Vector2 = Vector2(cos(angle), sin(angle))
		draw_line(center, center + dir * radius, grid_color, 1.0, true)

		var label_pos: Vector2 = center + dir * (radius + 24)
		var text: String = labels[j]
		var string_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		draw_string(font, label_pos - string_size / 2.0 + Vector2(0, font_size / 3.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, label_color)

    # 绘制初始性格多边形 (底色)
	_draw_data_polygon(center, radius, num_points, base_values, base_color, Color(0.54, 0.56, 0.62, 0.92))
    
    # 绘制动态性格多边形 (当前值)
	_draw_data_polygon(center, radius, num_points, dynamic_values, dynamic_color, Color(dynamic_color.r, dynamic_color.g, dynamic_color.b, 1.0))

func _draw_data_polygon(center: Vector2, radius: float, num_points: int, values: Array[float], fill_color: Color, stroke_color: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for j in range(num_points):
		var angle: float = _get_angle(j, num_points)
		var val: float = clamp(values[j] / max_value, 0.0, 1.0)
		points.append(center + Vector2(cos(angle), sin(angle)) * (radius * val))

	if points.size() >= 3:
		var poly_colors: PackedColorArray = PackedColorArray()
		for i in range(points.size()):
			poly_colors.append(fill_color)
		draw_polygon(points, poly_colors)

		var line_points: PackedVector2Array = points.duplicate()
		line_points.append(points[0])
		draw_polyline(line_points, stroke_color, 2.0, true)

func _get_angle(index: int, total: int) -> float:
	return -PI / 2.0 + (TAU * float(index) / total)
