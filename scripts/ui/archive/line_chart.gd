extends Control

@export var labels: Array[String] = ["开放性", "尽责性", "外倾性", "宜人性", "神经质"]
@export var max_value: float = 100.0
@export var grid_color: Color = Color(0.82, 0.79, 0.73, 0.55)
@export var text_color: Color = Color(0.46, 0.43, 0.39, 1)
@export var max_x_axis_labels: int = 6
@export var max_visible_weeks: int = 8
@export var emphasized_recent_weeks: int = 3
@export var current_week_guide_color: Color = Color(0.18, 0.72, 0.67, 0.22)
@export var current_week_label_color: Color = Color(0.14, 0.58, 0.54, 1)
@export var point_outline_color: Color = Color(1, 1, 1, 0.92)
@export var axis_color: Color = Color(0.72, 0.78, 0.8, 0.75)
@export var legend_text_color: Color = Color(0.35, 0.4, 0.46, 0.95)

# 颜色映射 (和雷达图/主题对齐)
var line_colors: Array[Color] = [
    Color(0.1, 0.8, 0.85, 1), # 开放性 - 青色
    Color(0.9, 0.4, 0.4, 1),  # 尽责性 - 红色
    Color(0.4, 0.9, 0.4, 1),  # 外倾性 - 绿色
    Color(0.9, 0.9, 0.4, 1),  # 宜人性 - 黄色
    Color(0.6, 0.4, 0.9, 1)   # 神经质 - 紫色
]

# 数据结构: [ {"week_index": int, "label": String, "openness": float, ...}, ... ]
var history_data: Array = []

func set_data(data: Array) -> void:
	history_data = data
	queue_redraw()

func _draw() -> void:
	var visible_history: Array = _get_visible_history()
	var w: float = size.x
	var h: float = size.y
	var margin_left: float = 38.0
	var margin_bottom: float = 30.0
	var margin_top: float = 30.0
	var margin_right: float = 16.0

	var graph_w: float = w - margin_left - margin_right
	var graph_h: float = h - margin_top - margin_bottom
	var origin: Vector2 = Vector2(margin_left, h - margin_bottom)
	var chart_top_left := Vector2(origin.x, margin_top)
	var chart_rect := Rect2(chart_top_left, Vector2(graph_w, graph_h))

	var font: Font = ThemeDB.fallback_font
	var font_size: int = 12
	var legend_font_size: int = 10

	draw_rect(chart_rect, Color(1, 1, 1, 0.18), true)
	draw_line(Vector2(origin.x, margin_top), origin, axis_color, 1.2)
	draw_line(origin, Vector2(origin.x + graph_w, origin.y), axis_color, 1.2)
	_draw_legend(font, legend_font_size, chart_top_left, graph_w)

	var y_steps: int = 4
	for i in range(y_steps + 1):
		var val: float = float(i) / y_steps * max_value
		var y_pos: float = origin.y - (val / max_value) * graph_h
		draw_line(Vector2(origin.x, y_pos), Vector2(origin.x + graph_w, y_pos), grid_color, 1.0)
		draw_string(font, Vector2(0, y_pos + font_size / 3.0), str(int(val)), HORIZONTAL_ALIGNMENT_RIGHT, margin_left - 6, font_size, text_color)

	if visible_history.size() < 2:
		draw_string(font, size / 2.0 + Vector2(-60, 0), "数据不足 (需>=2周)", HORIZONTAL_ALIGNMENT_CENTER, -1, 14, text_color)
		return

	var num_points: int = visible_history.size()
	var x_step: float = graph_w / max(1, num_points - 1)
	var label_step: int = max(1, ceili(float(num_points) / max(1.0, float(max_x_axis_labels))))
	var current_index: int = num_points - 1
	var current_x: float = origin.x + current_index * x_step
	draw_line(Vector2(current_x, margin_top), Vector2(current_x, origin.y), current_week_guide_color, 2.0)

	for i in range(num_points):
		var x_pos: float = origin.x + i * x_step
		draw_line(Vector2(x_pos, origin.y), Vector2(x_pos, origin.y + 4.0), axis_color, 1.0)
		var should_draw_label: bool = i == 0 or i == num_points - 1 or i % label_step == 0
		if should_draw_label:
			var label_text: String = _build_week_label(visible_history[i], i == current_index)
			if label_text == "":
				var week_index: int = int(visible_history[i].get("week_index", i + 1))
				label_text = "第%d周" % week_index
			var label_color := current_week_label_color if i == current_index else text_color
			draw_string(
				font,
				Vector2(x_pos - 24, origin.y + 19),
				label_text,
				HORIZONTAL_ALIGNMENT_CENTER,
				48,
				font_size,
				label_color
			)

	var traits: Array[String] = ["openness", "conscientiousness", "extraversion", "agreeableness", "neuroticism"]
	for t_idx in range(traits.size()):
		var trait_key: String = traits[t_idx]
		var color: Color = line_colors[t_idx]

		var points: PackedVector2Array = PackedVector2Array()
		for i in range(num_points):
			var val: float = visible_history[i].get(trait_key, 50.0)
			val = clamp(val, 0.0, max_value)
			var x_pos: float = origin.x + i * x_step
			var y_pos: float = origin.y - (val / max_value) * graph_h
			points.append(Vector2(x_pos, y_pos))

		for i in range(points.size() - 1):
			var segment_color := color
			segment_color.a = _get_point_alpha(i + 1, num_points)
			draw_line(points[i], points[i + 1], segment_color, 2.0, true)

		for i in range(points.size()):
			var point := points[i]
			var point_color := color
			point_color.a = _get_point_alpha(i, num_points)
			var radius := 2.8 if i != current_index else 4.8
			if _is_recent_index(i, num_points):
				radius += 0.6
			draw_circle(point, radius, point_color)
			var outline_color := point_outline_color
			outline_color.a = point_color.a
			draw_arc(point, radius + 0.8, 0.0, TAU, 20, outline_color, 1.4)


func _get_visible_history() -> Array:
	if history_data.size() <= max_visible_weeks:
		return history_data
	return history_data.slice(history_data.size() - max_visible_weeks, history_data.size())


func _build_week_label(item: Dictionary, is_current: bool) -> String:
	var week_index: int = int(item.get("week_index", 0))
	if week_index <= 0:
		return ""
	if is_current:
		return "本周"
	return "第%d周" % week_index


func _is_recent_index(index: int, total_points: int) -> bool:
	return index >= max(0, total_points - emphasized_recent_weeks)


func _get_point_alpha(index: int, total_points: int) -> float:
	if _is_recent_index(index, total_points):
		return 1.0
	return 0.26


func _draw_legend(font: Font, font_size: int, chart_top_left: Vector2, graph_width: float) -> void:
	var legend_labels := ["开放", "尽责", "外倾", "宜人", "神经"]
	var start_x := chart_top_left.x + 4.0
	var baseline_y := chart_top_left.y - 10.0
	var item_width := maxf(54.0, graph_width / 5.2)
	for i in range(min(legend_labels.size(), line_colors.size())):
		var item_x := start_x + item_width * i
		var line_color := line_colors[i]
		draw_line(Vector2(item_x, baseline_y), Vector2(item_x + 10.0, baseline_y), line_color, 2.4, true)
		draw_circle(Vector2(item_x + 5.0, baseline_y), 2.4, line_color)
		draw_string(
			font,
			Vector2(item_x + 14.0, baseline_y + font_size / 3.0),
			legend_labels[i],
			HORIZONTAL_ALIGNMENT_LEFT,
			item_width - 16.0,
			font_size,
			legend_text_color
		)
