extends Control

@export var labels: Array[String] = ["开放性", "尽责性", "外倾性", "宜人性", "神经质"]
@export var max_value: float = 100.0
@export var grid_color: Color = Color(0.82, 0.79, 0.73, 0.55)
@export var text_color: Color = Color(0.46, 0.43, 0.39, 1)
@export var max_x_axis_labels: int = 6

# 颜色映射 (和雷达图/主题对齐)
var line_colors: Array[Color] = [
    Color(0.1, 0.8, 0.85, 1), # 开放性 - 青色
    Color(0.9, 0.4, 0.4, 1),  # 尽责性 - 红色
    Color(0.4, 0.9, 0.4, 1),  # 外倾性 - 绿色
    Color(0.9, 0.9, 0.4, 1),  # 宜人性 - 黄色
    Color(0.6, 0.4, 0.9, 1)   # 神经质 - 紫色
]

# 数据结构: [ {"day_offset": int, "openness": float, ...}, ... ]
var history_data: Array = []

func set_data(data: Array) -> void:
	history_data = data
	queue_redraw()

func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	var margin_left: float = 36.0
	var margin_bottom: float = 26.0
	var margin_top: float = 14.0
	var margin_right: float = 14.0

	var graph_w: float = w - margin_left - margin_right
	var graph_h: float = h - margin_top - margin_bottom
	var origin: Vector2 = Vector2(margin_left, h - margin_bottom)

	var font: Font = ThemeDB.fallback_font
	var font_size: int = 12

	var y_steps: int = 2
	for i in range(y_steps + 1):
		var val: float = float(i) / y_steps * max_value
		var y_pos: float = origin.y - (val / max_value) * graph_h
		draw_line(Vector2(origin.x, y_pos), Vector2(origin.x + graph_w, y_pos), grid_color, 1.0)
		draw_string(font, Vector2(0, y_pos + font_size / 3.0), str(int(val)), HORIZONTAL_ALIGNMENT_RIGHT, margin_left - 6, font_size, text_color)

	if history_data.size() < 2:
		draw_string(font, size / 2.0 + Vector2(-60, 0), "数据不足 (需>=2天)", HORIZONTAL_ALIGNMENT_CENTER, -1, 14, text_color)
		return

	var num_points: int = history_data.size()
	var x_step: float = graph_w / max(1, num_points - 1)
	var label_step: int = max(1, ceili(float(num_points) / max(1.0, float(max_x_axis_labels))))

	for i in range(num_points):
		var x_pos: float = origin.x + i * x_step
		var should_draw_label: bool = i == 0 or i == num_points - 1 or i % label_step == 0
		if should_draw_label:
			var day_offset: int = int(history_data[i].get("day_offset", 0))
			draw_string(
				font,
				Vector2(x_pos - 15, origin.y + 18),
				"D%d" % day_offset,
				HORIZONTAL_ALIGNMENT_CENTER,
				30,
				font_size,
				text_color
			)

	var traits: Array[String] = ["openness", "conscientiousness", "extraversion", "agreeableness", "neuroticism"]
	for t_idx in range(traits.size()):
		var trait_key: String = traits[t_idx]
		var color: Color = line_colors[t_idx]

		var points: PackedVector2Array = PackedVector2Array()
		for i in range(num_points):
			var val: float = history_data[i].get(trait_key, 50.0)
			val = clamp(val, 0.0, max_value)
			var x_pos: float = origin.x + i * x_step
			var y_pos: float = origin.y - (val / max_value) * graph_h
			points.append(Vector2(x_pos, y_pos))
			draw_circle(Vector2(x_pos, y_pos), 3.0, color)

		if points.size() >= 2:
			draw_polyline(points, color, 2.0, true)
