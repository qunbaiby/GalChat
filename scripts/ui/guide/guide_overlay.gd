extends Control

signal skip_pressed

const DIM_COLOR := Color(0.02, 0.03, 0.06, 0.72)
const ACCENT_SOFT_COLOR := Color(0.76, 0.90, 0.96, 1.0)
const WARM_ACCENT_COLOR := Color(0.94, 0.80, 0.61, 1.0)
const POINTER_COLOR := Color(0.88, 0.96, 1.0, 0.96)
const PANEL_SIDE_MARGIN := 10.0
const PANEL_INNER_SPACING := 8.0
const BODY_SIDE_MARGIN := 14.0
const BODY_VERTICAL_PADDING := 20.0
const MIN_BODY_HEIGHT := 48.0
const MAX_BODY_HEIGHT := 180.0
@onready var _panel_root: PanelContainer = $GuidePanel
@onready var _guide_margin: MarginContainer = $GuidePanel/GuideMargin
@onready var _guide_container: VBoxContainer = $GuidePanel/GuideMargin/GuideContainer
@onready var _title_container: HBoxContainer = $GuidePanel/GuideMargin/GuideContainer/TitleContainer
@onready var _title_label: Label = $GuidePanel/GuideMargin/GuideContainer/TitleContainer/TitleLabel
@onready var _progress_chip: PanelContainer = $GuidePanel/GuideMargin/GuideContainer/TitleContainer/ProgressChip
@onready var _progress_chip_label: Label = $GuidePanel/GuideMargin/GuideContainer/TitleContainer/ProgressChip/ProgressChipMargin/ProgressChipLabel
@onready var _body_card: PanelContainer = $GuidePanel/GuideMargin/GuideContainer/BodyCard
@onready var _body_label: RichTextLabel = $GuidePanel/GuideMargin/GuideContainer/BodyCard/BodyMargin/BodyLabel
@onready var _footer_container: HBoxContainer = $GuidePanel/GuideMargin/GuideContainer/TitleContainer2
@onready var _hint_label: Label = $GuidePanel/GuideMargin/GuideContainer/TitleContainer2/HintLabel
@onready var _skip_button: Button = $GuidePanel/GuideMargin/GuideContainer/TitleContainer2/SkipButton

var _focus_rects: Array[Rect2] = []
var _focus_bounds: Rect2 = Rect2()
var _pointer_start: Vector2 = Vector2.ZERO
var _pointer_end: Vector2 = Vector2.ZERO
var _show_pointer: bool = false
var _ui_built: bool = false
var _dim_draw_rects: Array[Rect2] = []
var _dim_segments: Array[ColorRect] = []
var _focus_glows: Array[Panel] = []
var _focus_frames: Array[Panel] = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_ensure_ui()

func _ensure_ui() -> void:
	if _ui_built:
		return
	if _skip_button != null and not _skip_button.pressed.is_connected(_on_skip_pressed):
		_skip_button.pressed.connect(_on_skip_pressed)
	if _panel_root != null:
		_panel_root.mouse_filter = Control.MOUSE_FILTER_STOP
		_panel_root.z_index = 20
	if _body_label != null:
		_body_label.fit_content = false
		_body_label.scroll_active = true
		_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ui_built = true

func _build_dim_rect(node_name: String) -> ColorRect:
	var rect := ColorRect.new()
	rect.name = node_name
	rect.color = DIM_COLOR
	rect.mouse_filter = Control.MOUSE_FILTER_STOP
	rect.visible = false
	rect.z_index = 5
	return rect

func _build_focus_glow(node_name: String) -> Panel:
	var panel := Panel.new()
	panel.name = node_name
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.visible = false
	panel.z_index = 12
	var glow_style := StyleBoxFlat.new()
	glow_style.bg_color = Color(0.60, 0.86, 0.84, 0.08)
	glow_style.corner_radius_top_left = 22
	glow_style.corner_radius_top_right = 22
	glow_style.corner_radius_bottom_left = 22
	glow_style.corner_radius_bottom_right = 22
	glow_style.shadow_color = Color(0.60, 0.86, 0.84, 0.32)
	glow_style.shadow_size = 10
	glow_style.shadow_offset = Vector2.ZERO
	panel.add_theme_stylebox_override("panel", glow_style)
	return panel

func _build_focus_frame(node_name: String) -> Panel:
	var panel := Panel.new()
	panel.name = node_name
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.visible = false
	panel.z_index = 13
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(0.95, 0.98, 1.0, 0.05)
	frame_style.border_width_left = 2
	frame_style.border_width_top = 2
	frame_style.border_width_right = 2
	frame_style.border_width_bottom = 2
	frame_style.border_color = ACCENT_SOFT_COLOR
	frame_style.corner_radius_top_left = 20
	frame_style.corner_radius_top_right = 20
	frame_style.corner_radius_bottom_left = 20
	frame_style.corner_radius_bottom_right = 20
	panel.add_theme_stylebox_override("panel", frame_style)
	return panel

func show_step(guide_title: String, step_title: String, step_text: String, current_index: int, total_steps: int, focus_data: Variant = null, focus_interaction_allowed: bool = false) -> void:
	_ensure_ui()
	var final_step_title := step_title.strip_edges()
	if final_step_title == "":
		final_step_title = "当前步骤"
	_progress_chip_label.text = "%d / %d" % [maxi(1, current_index), maxi(1, total_steps)]
	_title_label.text = final_step_title
	_body_label.text = step_text.strip_edges()
	_body_label.scroll_to_line(0)
	_apply_focus_rects(_normalize_focus_input(focus_data))
	_hint_label.text = _build_hint_text(focus_interaction_allowed)
	show()
	_panel_root.visible = true
	call_deferred("_refresh_overlay_layout")

func hide_overlay() -> void:
	_ensure_ui()
	_clear_focus_rects()
	hide()

func _on_skip_pressed() -> void:
	skip_pressed.emit()

func _build_hint_text(focus_interaction_allowed: bool) -> String:
	if _focus_rects.is_empty():
		return "请阅读当前提示"
	if focus_interaction_allowed:
		return "请点击当前高亮区域继续"
	return "请按当前高亮区域完成操作"

func _normalize_focus_input(focus_data: Variant) -> Array[Rect2]:
	var focus_rects: Array[Rect2] = []
	if focus_data == null:
		return focus_rects
	if focus_data is Rect2:
		focus_rects.append(_sanitize_focus_rect(focus_data))
		return focus_rects
	if focus_data is Array:
		for item in focus_data:
			if item is Rect2:
				var rect := _sanitize_focus_rect(item)
				if rect.size.x > 1.0 and rect.size.y > 1.0:
					focus_rects.append(rect)
	return focus_rects

func _sanitize_focus_rect(focus_rect: Rect2) -> Rect2:
	var viewport_rect := get_viewport_rect()
	var safe_rect := focus_rect
	safe_rect.position.x = clampf(safe_rect.position.x, 0.0, viewport_rect.size.x)
	safe_rect.position.y = clampf(safe_rect.position.y, 0.0, viewport_rect.size.y)
	safe_rect.size.x = clampf(safe_rect.size.x, 0.0, viewport_rect.size.x - safe_rect.position.x)
	safe_rect.size.y = clampf(safe_rect.size.y, 0.0, viewport_rect.size.y - safe_rect.position.y)
	safe_rect.position = safe_rect.position.floor()
	safe_rect.size = Vector2(ceilf(safe_rect.size.x), ceilf(safe_rect.size.y))
	return safe_rect

func _apply_focus_rects(focus_rects: Array[Rect2]) -> void:
	_ensure_ui()
	_focus_rects = focus_rects
	_focus_bounds = _calculate_focus_bounds(_focus_rects)
	_rebuild_dim_segments()
	_rebuild_focus_frames()
	queue_redraw()

func _clear_focus_rects() -> void:
	_ensure_ui()
	_focus_rects.clear()
	_focus_bounds = Rect2()
	_dim_draw_rects.clear()
	_show_pointer = false
	for dim_rect in _dim_segments:
		dim_rect.visible = false
	for glow_panel in _focus_glows:
		glow_panel.visible = false
	for frame_panel in _focus_frames:
		frame_panel.visible = false
	queue_redraw()

func _calculate_focus_bounds(focus_rects: Array[Rect2]) -> Rect2:
	var merged := Rect2()
	var has_rect := false
	for rect in focus_rects:
		if rect.size.x <= 1.0 or rect.size.y <= 1.0:
			continue
		if not has_rect:
			merged = rect
			has_rect = true
		else:
			merged = merged.merge(rect)
	return merged

func _append_unique_float(values: Array, value: float, epsilon: float = 0.5) -> void:
	for existing in values:
		if absf(float(existing) - value) <= epsilon:
			return
	values.append(value)

func _ensure_dim_segment_count(target_count: int) -> void:
	while _dim_segments.size() < target_count:
		var dim_rect := _build_dim_rect("DimSegment%d" % _dim_segments.size())
		_dim_segments.append(dim_rect)
		add_child(dim_rect)

func _ensure_focus_frame_count(target_count: int) -> void:
	while _focus_glows.size() < target_count:
		var glow_panel := _build_focus_glow("FocusGlow%d" % _focus_glows.size())
		_focus_glows.append(glow_panel)
		add_child(glow_panel)
	while _focus_frames.size() < target_count:
		var frame_panel := _build_focus_frame("FocusFrame%d" % _focus_frames.size())
		_focus_frames.append(frame_panel)
		add_child(frame_panel)

func _rebuild_dim_segments() -> void:
	var viewport_size := get_viewport_rect().size
	var rects := _focus_rects.duplicate()
	var xs: Array = [0.0, viewport_size.x]
	var ys: Array = [0.0, viewport_size.y]
	for rect in rects:
		if rect.size.x <= 1.0 or rect.size.y <= 1.0:
			continue
		_append_unique_float(xs, rect.position.x)
		_append_unique_float(xs, rect.end.x)
		_append_unique_float(ys, rect.position.y)
		_append_unique_float(ys, rect.end.y)
	xs.sort()
	ys.sort()
	var dim_rects: Array[Rect2] = []
	for x_index in range(xs.size() - 1):
		for y_index in range(ys.size() - 1):
			var rect := Rect2(
				Vector2(float(xs[x_index]), float(ys[y_index])),
				Vector2(float(xs[x_index + 1]) - float(xs[x_index]), float(ys[y_index + 1]) - float(ys[y_index]))
			)
			if rect.size.x <= 0.5 or rect.size.y <= 0.5:
				continue
			var sample_point := rect.position + rect.size * 0.5
			var covered := false
			for focus_rect in rects:
				if focus_rect.has_point(sample_point):
					covered = true
					break
			if not covered:
				dim_rects.append(rect)
	if dim_rects.is_empty():
		dim_rects.append(Rect2(Vector2.ZERO, viewport_size))
	_dim_draw_rects = dim_rects
	_ensure_dim_segment_count(dim_rects.size())
	for index in range(_dim_segments.size()):
		var dim_rect := _dim_segments[index]
		dim_rect.visible = false

func _rebuild_focus_frames() -> void:
	_ensure_focus_frame_count(_focus_rects.size())
	for index in range(_focus_glows.size()):
		var glow_panel := _focus_glows[index]
		var frame_panel := _focus_frames[index]
		if index < _focus_rects.size():
			var rect := _focus_rects[index]
			glow_panel.position = rect.position.floor()
			glow_panel.size = Vector2(ceilf(rect.size.x), ceilf(rect.size.y))
			frame_panel.position = rect.position.floor()
			frame_panel.size = Vector2(ceilf(rect.size.x), ceilf(rect.size.y))
			glow_panel.visible = true
			frame_panel.visible = true
		else:
			glow_panel.visible = false
			frame_panel.visible = false

func _layout_panel_relative_to_focus() -> void:
	_ensure_ui()
	var viewport_size := get_viewport_rect().size
	var viewport_rect := Rect2(Vector2.ZERO, viewport_size)
	var horizontal_margin := 28.0
	var vertical_margin := 24.0
	var panel_width := clampf(viewport_size.x - horizontal_margin * 2.0, 360.0, 440.0)
	_prepare_adaptive_panel_metrics(panel_width, viewport_size.y)
	var panel_height := clampf(_panel_root.get_combined_minimum_size().y, 170.0, minf(340.0, viewport_size.y * 0.48))
	var panel_size := Vector2(panel_width, panel_height)
	_panel_root.custom_minimum_size = Vector2.ZERO
	_panel_root.size = panel_size

	var default_position := Vector2((viewport_size.x - panel_size.x) * 0.5, 24.0)
	if _focus_bounds.size.x <= 1.0 or _focus_bounds.size.y <= 1.0:
		_panel_root.position = default_position
		_show_pointer = false
		queue_redraw()
		return

	var spacing := 18.0
	_panel_root.position = _find_best_panel_position(panel_size, viewport_rect, horizontal_margin, vertical_margin, spacing, default_position)
	_update_pointer(panel_size)
	queue_redraw()

func _refresh_overlay_layout() -> void:
	if not visible:
		return
	_layout_panel_relative_to_focus()

func _prepare_adaptive_panel_metrics(panel_width: float, viewport_height: float) -> void:
	var content_width := maxf(220.0, panel_width - PANEL_SIDE_MARGIN * 2.0)
	var progress_chip_width := _progress_chip.get_combined_minimum_size().x
	var title_width := maxf(160.0, content_width - progress_chip_width - PANEL_INNER_SPACING)
	var footer_buttons_width := _skip_button.custom_minimum_size.x
	var hint_width := maxf(120.0, content_width - footer_buttons_width - PANEL_INNER_SPACING)
	var body_width := maxf(180.0, content_width - BODY_SIDE_MARGIN * 2.0)
	var body_max_height := minf(MAX_BODY_HEIGHT, viewport_height * 0.26)
	# 这些自动换行 Label 若在宽度仍为 1px 时参与最小尺寸计算，会把面板高度错误撑爆。
	_title_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_hint_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_title_label.size = Vector2(title_width, 0.0)
	_title_label.custom_minimum_size = Vector2(title_width, 0.0)
	_hint_label.size = Vector2(hint_width, 0.0)
	_hint_label.custom_minimum_size = Vector2(hint_width, 0.0)
	_title_label.update_minimum_size()
	_hint_label.update_minimum_size()
	_title_container.update_minimum_size()
	_footer_container.update_minimum_size()
	_body_card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_body_label.fit_content = false
	_body_label.scroll_active = true
	_body_label.size = Vector2(body_width, body_max_height)
	_body_label.custom_minimum_size = Vector2(body_width, 0.0)
	_body_label.update_minimum_size()
	var body_content_height := clampf(_body_label.get_content_height(), MIN_BODY_HEIGHT, body_max_height)
	_body_label.custom_minimum_size = Vector2(body_width, body_content_height)
	_body_card.custom_minimum_size = Vector2(0.0, body_content_height + BODY_VERTICAL_PADDING)
	_body_label.update_minimum_size()
	_body_card.update_minimum_size()
	_guide_container.update_minimum_size()
	_panel_root.update_minimum_size()

func _find_best_panel_position(panel_size: Vector2, viewport_rect: Rect2, horizontal_margin: float, vertical_margin: float, spacing: float, fallback_position: Vector2) -> Vector2:
	var focus_center := _focus_bounds.get_center()
	var candidate_positions: Array[Vector2] = [
		Vector2(focus_center.x - panel_size.x * 0.5, _focus_bounds.position.y - panel_size.y - spacing),
		Vector2(focus_center.x - panel_size.x * 0.5, _focus_bounds.end.y + spacing),
		Vector2(_focus_bounds.position.x - panel_size.x - spacing, focus_center.y - panel_size.y * 0.5),
		Vector2(_focus_bounds.end.x + spacing, focus_center.y - panel_size.y * 0.5),
		Vector2(_focus_bounds.position.x - panel_size.x - spacing, _focus_bounds.position.y - panel_size.y - spacing),
		Vector2(_focus_bounds.end.x + spacing, _focus_bounds.position.y - panel_size.y - spacing),
		Vector2(_focus_bounds.position.x - panel_size.x - spacing, _focus_bounds.end.y + spacing),
		Vector2(_focus_bounds.end.x + spacing, _focus_bounds.end.y + spacing),
		Vector2(viewport_rect.size.x - panel_size.x - horizontal_margin, vertical_margin),
		Vector2(horizontal_margin, vertical_margin),
		Vector2(viewport_rect.size.x - panel_size.x - horizontal_margin, viewport_rect.size.y - panel_size.y - vertical_margin),
		Vector2(horizontal_margin, viewport_rect.size.y - panel_size.y - vertical_margin)
	]
	var best_position := _clamp_panel_position(fallback_position, panel_size, viewport_rect, horizontal_margin, vertical_margin)
	var best_overlap := INF
	var best_distance := INF
	for raw_position in candidate_positions:
		var candidate_position := _clamp_panel_position(raw_position, panel_size, viewport_rect, horizontal_margin, vertical_margin)
		var panel_rect := Rect2(candidate_position, panel_size)
		var overlap_area := _get_focus_overlap_area(panel_rect)
		var distance := panel_rect.get_center().distance_squared_to(focus_center)
		if overlap_area < best_overlap - 0.5:
			best_overlap = overlap_area
			best_distance = distance
			best_position = candidate_position
			continue
		if absf(overlap_area - best_overlap) <= 0.5 and distance < best_distance:
			best_distance = distance
			best_position = candidate_position
	return best_position

func _clamp_panel_position(position: Vector2, panel_size: Vector2, viewport_rect: Rect2, horizontal_margin: float, vertical_margin: float) -> Vector2:
	return Vector2(
		clampf(position.x, horizontal_margin, maxf(horizontal_margin, viewport_rect.size.x - panel_size.x - horizontal_margin)),
		clampf(position.y, vertical_margin, maxf(vertical_margin, viewport_rect.size.y - panel_size.y - vertical_margin))
	)

func _get_focus_overlap_area(panel_rect: Rect2) -> float:
	var overlap_area := 0.0
	for focus_rect in _focus_rects:
		overlap_area += _get_rect_overlap_area(panel_rect, focus_rect)
	return overlap_area

func _get_rect_overlap_area(a: Rect2, b: Rect2) -> float:
	var left := maxf(a.position.x, b.position.x)
	var top := maxf(a.position.y, b.position.y)
	var right := minf(a.end.x, b.end.x)
	var bottom := minf(a.end.y, b.end.y)
	if right <= left or bottom <= top:
		return 0.0
	return (right - left) * (bottom - top)

func _update_pointer(panel_size: Vector2) -> void:
	if _focus_rects.is_empty():
		_show_pointer = false
		return
	var panel_rect := Rect2(_panel_root.position, panel_size)
	var panel_center := panel_rect.get_center()
	var pointer_rect := _pick_pointer_focus_rect(panel_center)
	var target_point := _closest_point_on_rect(pointer_rect.grow(-8.0), panel_center)
	_pointer_start = _panel_edge_point(panel_rect, target_point)
	_pointer_end = target_point
	_show_pointer = true

func _pick_pointer_focus_rect(panel_center: Vector2) -> Rect2:
	var best_rect := _focus_rects[0]
	var best_distance := panel_center.distance_squared_to(best_rect.get_center())
	for rect in _focus_rects:
		var distance := panel_center.distance_squared_to(rect.get_center())
		if distance < best_distance:
			best_distance = distance
			best_rect = rect
	return best_rect

func _closest_point_on_rect(rect: Rect2, point: Vector2) -> Vector2:
	var left := rect.position.x
	var right := rect.end.x
	var top := rect.position.y
	var bottom := rect.end.y
	if point.y < top:
		return Vector2(clampf(point.x, left, right), top)
	if point.y > bottom:
		return Vector2(clampf(point.x, left, right), bottom)
	if point.x < left:
		return Vector2(left, clampf(point.y, top, bottom))
	return Vector2(right, clampf(point.y, top, bottom))

func _panel_edge_point(panel_rect: Rect2, target_point: Vector2) -> Vector2:
	var center := panel_rect.get_center()
	var delta := target_point - center
	if absf(delta.x) > absf(delta.y):
		if delta.x >= 0.0:
			return Vector2(panel_rect.end.x, clampf(target_point.y, panel_rect.position.y + 20.0, panel_rect.end.y - 20.0))
		return Vector2(panel_rect.position.x, clampf(target_point.y, panel_rect.position.y + 20.0, panel_rect.end.y - 20.0))
	if delta.y >= 0.0:
		return Vector2(clampf(target_point.x, panel_rect.position.x + 24.0, panel_rect.end.x - 24.0), panel_rect.end.y)
	return Vector2(clampf(target_point.x, panel_rect.position.x + 24.0, panel_rect.end.x - 24.0), panel_rect.position.y)

func _draw() -> void:
	for dim_rect in _dim_draw_rects:
		draw_rect(dim_rect, DIM_COLOR, true)
	if not _show_pointer:
		return
	var bend_point := Vector2(_pointer_end.x, _pointer_start.y)
	if absf(_pointer_end.y - _pointer_start.y) < 24.0:
		bend_point = Vector2(_pointer_start.x, _pointer_end.y)
	var points := PackedVector2Array([_pointer_start, bend_point, _pointer_end])
	draw_polyline(points, POINTER_COLOR, 3.0, true)
	draw_circle(_pointer_end, 7.0, Color(0.86, 0.95, 1.0, 0.30))
	draw_circle(_pointer_end, 4.0, WARM_ACCENT_COLOR)
