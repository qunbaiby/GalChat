extends Control

signal skip_pressed
signal background_pressed(action_id: String)
signal focus_pressed(action_id: String)

const DIM_COLOR := Color(0.02, 0.03, 0.06, 0.72)
const ACCENT_SOFT_COLOR := Color(0.76, 0.90, 0.96, 1.0)
const WARM_ACCENT_COLOR := Color(0.94, 0.80, 0.61, 1.0)
const POINTER_COLOR := Color(0.88, 0.96, 1.0, 0.96)
const POINTER_GLOW_COLOR := Color(0.72, 0.88, 0.97, 0.20)
const FOCUS_FILL_COLOR := Color(0.60, 0.86, 0.84, 0.04)
const FOCUS_FRAME_FILL_COLOR := Color(0.95, 0.98, 1.0, 0.025)
const FOCUS_GLOW_SHADOW_COLOR := Color(0.60, 0.86, 0.84, 0.16)
const PANEL_SIDE_MARGIN := 10.0
const BODY_SIDE_MARGIN := 14.0
const BODY_VERTICAL_PADDING := 20.0
const MIN_BODY_HEIGHT := 48.0
const MAX_BODY_HEIGHT := 220.0
const FOCUS_SHAPE_RECT := "rect"
const FOCUS_SHAPE_TRAPEZOID_LEFT := "trapezoid_left"

@onready var _panel_root: PanelContainer = $GuidePanel
@onready var _guide_margin: MarginContainer = $GuidePanel/GuideMargin
@onready var _body_card: PanelContainer = $GuidePanel/GuideMargin/BodyCard
@onready var _body_label: RichTextLabel = $GuidePanel/GuideMargin/BodyCard/BodyMargin/BodyLabel

var _focus_entries: Array[Dictionary] = []
var _focus_rects: Array[Rect2] = []
var _focus_bounds: Rect2 = Rect2()
var _pointer_start: Vector2 = Vector2.ZERO
var _pointer_end: Vector2 = Vector2.ZERO
var _pointer_points: PackedVector2Array = PackedVector2Array()
var _show_pointer: bool = false
var _ui_built: bool = false
var _dim_draw_rects: Array[Rect2] = []
var _dim_overlay_polygons: Array[PackedVector2Array] = []
var _dim_segments: Array[ColorRect] = []
var _focus_glows: Array[Panel] = []
var _focus_frames: Array[Panel] = []
var _focus_capture_overlays: Array[ColorRect] = []
var _overlay_options: Dictionary = {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_ensure_ui()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_RIGHT:
		return
	var guide_manager := get_node_or_null("/root/GuideManager")
	if guide_manager and guide_manager.has_method("go_to_previous_step_in_current_scene"):
		if bool(guide_manager.go_to_previous_step_in_current_scene()):
			get_viewport().set_input_as_handled()

func _ensure_ui() -> void:
	if _ui_built:
		return
	if _panel_root != null:
		_panel_root.mouse_filter = Control.MOUSE_FILTER_STOP
		_panel_root.z_index = 20
	if _body_label != null:
		_body_label.fit_content = false
		_body_label.scroll_active = true
		_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ui_built = true

func _set_control_tree_mouse_filter(node: Node, filter_mode: Control.MouseFilter) -> void:
	if node is Control:
		(node as Control).mouse_filter = filter_mode
	for child in node.get_children():
		_set_control_tree_mouse_filter(child, filter_mode)

func _build_dim_rect(node_name: String) -> ColorRect:
	var rect := ColorRect.new()
	rect.name = node_name
	rect.color = Color(0, 0, 0, 0)
	rect.mouse_filter = Control.MOUSE_FILTER_STOP
	rect.visible = false
	rect.z_index = 5
	if not rect.gui_input.is_connected(_on_dim_rect_gui_input):
		rect.gui_input.connect(_on_dim_rect_gui_input)
	return rect

func _on_dim_rect_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	var action_id := str(_overlay_options.get("background_wait_action", "")).strip_edges()
	get_viewport().set_input_as_handled()
	if action_id == "":
		return
	background_pressed.emit(action_id)

func _build_focus_glow(node_name: String) -> Panel:
	var panel := Panel.new()
	panel.name = node_name
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.visible = false
	panel.z_index = 12
	var glow_style := StyleBoxFlat.new()
	glow_style.bg_color = FOCUS_FILL_COLOR
	glow_style.corner_radius_top_left = 22
	glow_style.corner_radius_top_right = 22
	glow_style.corner_radius_bottom_left = 22
	glow_style.corner_radius_bottom_right = 22
	glow_style.shadow_color = FOCUS_GLOW_SHADOW_COLOR
	glow_style.shadow_size = 6
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
	frame_style.bg_color = FOCUS_FRAME_FILL_COLOR
	frame_style.border_width_left = 1
	frame_style.border_width_top = 1
	frame_style.border_width_right = 1
	frame_style.border_width_bottom = 1
	frame_style.border_color = ACCENT_SOFT_COLOR
	frame_style.corner_radius_top_left = 20
	frame_style.corner_radius_top_right = 20
	frame_style.corner_radius_bottom_left = 20
	frame_style.corner_radius_bottom_right = 20
	panel.add_theme_stylebox_override("panel", frame_style)
	return panel

func _build_focus_capture_overlay(node_name: String) -> ColorRect:
	var rect := ColorRect.new()
	rect.name = node_name
	rect.color = Color(1, 1, 1, 0)
	rect.mouse_filter = Control.MOUSE_FILTER_STOP
	rect.visible = false
	rect.z_index = 14
	if not rect.gui_input.is_connected(_on_focus_capture_gui_input):
		rect.gui_input.connect(_on_focus_capture_gui_input)
	return rect

func _on_focus_capture_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	var action_id := str(_overlay_options.get("focus_wait_action", "")).strip_edges()
	if action_id == "":
		return
	focus_pressed.emit(action_id)
	get_viewport().set_input_as_handled()

func show_step(guide_title: String, step_title: String, step_text: String, current_index: int, total_steps: int, focus_data: Variant = null, focus_interaction_allowed: bool = false, overlay_options: Dictionary = {}) -> void:
	_ensure_ui()
	var _unused_guide_title := guide_title
	var _unused_step_title := step_title
	var _unused_current_index := current_index
	var _unused_total_steps := total_steps
	_overlay_options = overlay_options.duplicate(true)
	if _panel_root != null:
		_set_control_tree_mouse_filter(_panel_root, Control.MOUSE_FILTER_IGNORE if focus_interaction_allowed else Control.MOUSE_FILTER_STOP)
	var final_step_text := step_text.strip_edges()
	if final_step_text == "":
		final_step_text = "请根据当前提示继续操作。"
	_body_label.text = final_step_text
	_body_label.scroll_to_line(0)
	_apply_focus_entries(_normalize_focus_input(focus_data))
	show()
	_panel_root.visible = true
	call_deferred("_refresh_overlay_layout")

func hide_overlay() -> void:
	_ensure_ui()
	_overlay_options.clear()
	_clear_focus_rects()
	hide()

func _normalize_focus_input(focus_data: Variant) -> Array[Dictionary]:
	var focus_entries: Array[Dictionary] = []
	if focus_data == null:
		return focus_entries
	if focus_data is Rect2:
		var rect_entry := _make_focus_entry(_sanitize_focus_rect(focus_data))
		if not rect_entry.is_empty():
			focus_entries.append(rect_entry)
		return focus_entries
	if focus_data is Dictionary:
		var dict_entry := _normalize_focus_entry(focus_data)
		if not dict_entry.is_empty():
			focus_entries.append(dict_entry)
		return focus_entries
	if focus_data is Array:
		for item in focus_data:
			if item is Rect2:
				var rect_entry := _make_focus_entry(_sanitize_focus_rect(item))
				if not rect_entry.is_empty():
					focus_entries.append(rect_entry)
			elif item is Dictionary:
				var dict_entry := _normalize_focus_entry(item)
				if not dict_entry.is_empty():
					focus_entries.append(dict_entry)
	return focus_entries

func _make_focus_entry(rect: Rect2, shape: String = FOCUS_SHAPE_RECT, shape_params: Dictionary = {}) -> Dictionary:
	if rect.size.x <= 1.0 or rect.size.y <= 1.0:
		return {}
	return {
		"rect": rect,
		"shape": shape,
		"shape_params": shape_params.duplicate(true)
	}

func _normalize_focus_entry(raw_entry: Dictionary) -> Dictionary:
	var rect_value: Variant = raw_entry.get("rect", Rect2())
	if not (rect_value is Rect2):
		return {}
	var rect := _sanitize_focus_rect(rect_value)
	if rect.size.x <= 1.0 or rect.size.y <= 1.0:
		return {}
	var shape := str(raw_entry.get("shape", FOCUS_SHAPE_RECT)).strip_edges()
	if shape == "":
		shape = FOCUS_SHAPE_RECT
	var shape_params: Dictionary = {}
	var raw_shape_params: Variant = raw_entry.get("shape_params", {})
	if raw_shape_params is Dictionary:
		shape_params = (raw_shape_params as Dictionary).duplicate(true)
	var focus_entry := _make_focus_entry(rect, shape, shape_params)
	var raw_cutout_polygon: Variant = raw_entry.get("cutout_polygon", PackedVector2Array())
	var cutout_polygon := _normalize_cutout_polygon(raw_cutout_polygon)
	if cutout_polygon.size() >= 3:
		focus_entry["cutout_polygon"] = cutout_polygon
	return focus_entry

func _normalize_cutout_polygon(raw_polygon: Variant) -> PackedVector2Array:
	var cutout_polygon := PackedVector2Array()
	if raw_polygon is PackedVector2Array:
		cutout_polygon = raw_polygon
	elif raw_polygon is Array:
		for point in raw_polygon:
			if point is Vector2:
				cutout_polygon.append(point)
	if cutout_polygon.size() < 3:
		return PackedVector2Array()
	var sanitized := PackedVector2Array()
	for point in cutout_polygon:
		sanitized.append(Vector2(floorf(point.x), floorf(point.y)))
	return sanitized

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

func _apply_focus_entries(focus_entries: Array[Dictionary]) -> void:
	_ensure_ui()
	_focus_entries = focus_entries
	_focus_rects.clear()
	for entry in _focus_entries:
		var rect_value: Variant = entry.get("rect", Rect2())
		if rect_value is Rect2:
			var rect := rect_value as Rect2
			if rect.size.x > 1.0 and rect.size.y > 1.0:
				_focus_rects.append(rect)
	_focus_bounds = _calculate_focus_bounds(_focus_rects)
	_rebuild_dim_segments()
	_rebuild_focus_frames()
	queue_redraw()

func _clear_focus_rects() -> void:
	_ensure_ui()
	_focus_entries.clear()
	_focus_rects.clear()
	_focus_bounds = Rect2()
	_dim_draw_rects.clear()
	_dim_overlay_polygons.clear()
	_show_pointer = false
	_pointer_points = PackedVector2Array()
	for dim_rect in _dim_segments:
		dim_rect.visible = false
	for glow_panel in _focus_glows:
		glow_panel.visible = false
	for frame_panel in _focus_frames:
		frame_panel.visible = false
	for capture_overlay in _focus_capture_overlays:
		capture_overlay.visible = false
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

func _ensure_focus_capture_overlay_count(target_count: int) -> void:
	while _focus_capture_overlays.size() < target_count:
		var overlay := _build_focus_capture_overlay("FocusCaptureOverlay%d" % _focus_capture_overlays.size())
		_focus_capture_overlays.append(overlay)
		add_child(overlay)

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
	_rebuild_dim_overlay_polygons()
	_ensure_dim_segment_count(dim_rects.size())
	for index in range(_dim_segments.size()):
		var dim_rect := _dim_segments[index]
		if index < dim_rects.size():
			var blocking_rect := dim_rects[index]
			dim_rect.position = blocking_rect.position.floor()
			dim_rect.size = Vector2(ceilf(blocking_rect.size.x), ceilf(blocking_rect.size.y))
			dim_rect.visible = true
		else:
			dim_rect.visible = false

func _rebuild_dim_overlay_polygons() -> void:
	_dim_overlay_polygons.clear()
	for entry in _focus_entries:
		var cutout_polygon := _get_focus_cutout_polygon(entry)
		if cutout_polygon.size() < 3:
			continue
		var rect: Rect2 = entry.get("rect", Rect2())
		for dim_polygon in _build_rect_minus_polygon_overlays(rect, cutout_polygon):
			if dim_polygon.size() >= 3:
				_dim_overlay_polygons.append(dim_polygon)

func _get_focus_cutout_polygon(entry: Dictionary) -> PackedVector2Array:
	var explicit_polygon := _normalize_cutout_polygon(entry.get("cutout_polygon", PackedVector2Array()))
	if explicit_polygon.size() >= 3:
		return explicit_polygon
	var rect: Rect2 = entry.get("rect", Rect2())
	if rect.size.x <= 1.0 or rect.size.y <= 1.0:
		return PackedVector2Array()
	var shape := str(entry.get("shape", FOCUS_SHAPE_RECT)).strip_edges()
	var shape_params: Dictionary = {}
	var raw_shape_params: Variant = entry.get("shape_params", {})
	if raw_shape_params is Dictionary:
		shape_params = raw_shape_params as Dictionary
	match shape:
		FOCUS_SHAPE_RECT:
			var corner_radius := maxf(0.0, float(shape_params.get("corner_radius", 0.0)))
			if corner_radius > 0.5:
				return _build_rounded_rect_polygon(rect, corner_radius)
			return PackedVector2Array()
		FOCUS_SHAPE_TRAPEZOID_LEFT:
			var slant_ratio := clampf(float(shape_params.get("cutout_slant", shape_params.get("skew", 0.3))), 0.0, 1.0)
			var top_inset := minf(rect.size.x - 1.0, rect.size.y * slant_ratio)
			return PackedVector2Array([
				Vector2(rect.position.x + top_inset, rect.position.y),
				Vector2(rect.end.x, rect.position.y),
				Vector2(rect.end.x, rect.end.y),
				Vector2(rect.position.x, rect.end.y)
			])
		_:
			return PackedVector2Array()

func _build_rounded_rect_polygon(rect: Rect2, radius: float, segments_per_corner: int = 8) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	if rect.size.x <= 1.0 or rect.size.y <= 1.0:
		return polygon
	var final_radius := minf(radius, minf(rect.size.x * 0.5, rect.size.y * 0.5))
	if final_radius <= 0.5:
		return PackedVector2Array([
			rect.position,
			Vector2(rect.end.x, rect.position.y),
			rect.end,
			Vector2(rect.position.x, rect.end.y)
		])
	_append_arc_points(
		polygon,
		Vector2(rect.end.x - final_radius, rect.position.y + final_radius),
		final_radius,
		-PI * 0.5,
		0.0,
		segments_per_corner
	)
	_append_arc_points(
		polygon,
		Vector2(rect.end.x - final_radius, rect.end.y - final_radius),
		final_radius,
		0.0,
		PI * 0.5,
		segments_per_corner
	)
	_append_arc_points(
		polygon,
		Vector2(rect.position.x + final_radius, rect.end.y - final_radius),
		final_radius,
		PI * 0.5,
		PI,
		segments_per_corner
	)
	_append_arc_points(
		polygon,
		Vector2(rect.position.x + final_radius, rect.position.y + final_radius),
		final_radius,
		PI,
		PI * 1.5,
		segments_per_corner
	)
	return polygon

func _append_arc_points(target: PackedVector2Array, center: Vector2, radius: float, start_angle: float, end_angle: float, segments: int) -> void:
	for index in range(segments + 1):
		var t := float(index) / float(maxi(1, segments))
		var angle := lerpf(start_angle, end_angle, t)
		var point := center + Vector2(cos(angle), sin(angle)) * radius
		if target.is_empty() or target[target.size() - 1].distance_to(point) > 0.25:
			target.append(point)

func _build_rect_minus_polygon_overlays(rect: Rect2, polygon: PackedVector2Array) -> Array[PackedVector2Array]:
	var overlays: Array[PackedVector2Array] = []
	if polygon.size() < 3:
		return overlays
	var bands := _collect_cutout_band_edges(rect, polygon)
	if bands.size() < 2:
		return overlays
	var left_x := rect.position.x
	var right_x := rect.end.x
	for index in range(bands.size() - 1):
		var band_top := float(bands[index])
		var band_bottom := float(bands[index + 1])
		if band_bottom - band_top <= 0.5:
			continue
		var inset := minf(0.25, (band_bottom - band_top) * 0.25)
		var sample_top := band_top + inset
		var sample_bottom := band_bottom - inset
		var top_intersections := _get_polygon_horizontal_intersections(polygon, sample_top)
		var bottom_intersections := _get_polygon_horizontal_intersections(polygon, sample_bottom)
		if top_intersections.size() < 2 or bottom_intersections.size() < 2:
			continue
		var segment_count: int = int(mini(top_intersections.size(), bottom_intersections.size()) / 2)
		for segment_index in range(segment_count):
			var top_left_cutout := float(top_intersections[segment_index * 2])
			var top_right_cutout := float(top_intersections[segment_index * 2 + 1])
			var bottom_left_cutout := float(bottom_intersections[segment_index * 2])
			var bottom_right_cutout := float(bottom_intersections[segment_index * 2 + 1])
			if maxf(top_left_cutout, bottom_left_cutout) - left_x > 0.5:
				overlays.append(PackedVector2Array([
					Vector2(left_x, band_top),
					Vector2(top_left_cutout, band_top),
					Vector2(bottom_left_cutout, band_bottom),
					Vector2(left_x, band_bottom)
				]))
			if right_x - minf(top_right_cutout, bottom_right_cutout) > 0.5:
				overlays.append(PackedVector2Array([
					Vector2(top_right_cutout, band_top),
					Vector2(right_x, band_top),
					Vector2(right_x, band_bottom),
					Vector2(bottom_right_cutout, band_bottom)
				]))
	return overlays

func _collect_cutout_band_edges(rect: Rect2, polygon: PackedVector2Array) -> Array:
	var ys: Array = [rect.position.y, rect.end.y]
	for point in polygon:
		_append_unique_float(ys, clampf(point.y, rect.position.y, rect.end.y), 0.01)
	ys.sort()
	return ys

func _get_polygon_horizontal_intersections(polygon: PackedVector2Array, y: float) -> Array:
	var intersections: Array = []
	if polygon.size() < 2:
		return intersections
	for index in range(polygon.size()):
		var a: Vector2 = polygon[index]
		var b: Vector2 = polygon[(index + 1) % polygon.size()]
		if absf(a.y - b.y) <= 0.001:
			continue
		var min_y := minf(a.y, b.y)
		var max_y := maxf(a.y, b.y)
		if y < min_y or y >= max_y:
			continue
		var t := (y - a.y) / (b.y - a.y)
		intersections.append(lerpf(a.x, b.x, t))
	intersections.sort()
	return intersections

func _rebuild_focus_frames() -> void:
	_ensure_focus_frame_count(_focus_entries.size())
	for index in range(_focus_glows.size()):
		var glow_panel := _focus_glows[index]
		var frame_panel := _focus_frames[index]
		if index < _focus_entries.size():
			var entry := _focus_entries[index]
			var rect: Rect2 = entry.get("rect", Rect2())
			if _should_use_custom_focus_draw(entry):
				glow_panel.visible = false
				frame_panel.visible = false
				continue
			glow_panel.position = rect.position.floor()
			glow_panel.size = Vector2(ceilf(rect.size.x), ceilf(rect.size.y))
			frame_panel.position = rect.position.floor()
			frame_panel.size = Vector2(ceilf(rect.size.x), ceilf(rect.size.y))
			_apply_focus_panel_style(glow_panel, entry, true)
			_apply_focus_panel_style(frame_panel, entry, false)
			glow_panel.visible = true
			frame_panel.visible = true
		else:
			glow_panel.visible = false
			frame_panel.visible = false
	_rebuild_focus_capture_overlays()

func _rebuild_focus_capture_overlays() -> void:
	var should_capture_focus_clicks: bool = bool(_overlay_options.get("capture_focus_clicks", false))
	var focus_wait_action := str(_overlay_options.get("focus_wait_action", "")).strip_edges()
	if not should_capture_focus_clicks or focus_wait_action == "":
		for capture_overlay in _focus_capture_overlays:
			capture_overlay.visible = false
		return
	_ensure_focus_capture_overlay_count(_focus_entries.size())
	for index in range(_focus_capture_overlays.size()):
		var capture_overlay := _focus_capture_overlays[index]
		if index < _focus_entries.size():
			var entry := _focus_entries[index]
			var rect: Rect2 = entry.get("rect", Rect2())
			if rect.size.x <= 1.0 or rect.size.y <= 1.0:
				capture_overlay.visible = false
				continue
			capture_overlay.position = rect.position.floor()
			capture_overlay.size = Vector2(ceilf(rect.size.x), ceilf(rect.size.y))
			capture_overlay.visible = true
		else:
			capture_overlay.visible = false

func _should_use_custom_focus_draw(entry: Dictionary) -> bool:
	var shape := str(entry.get("shape", FOCUS_SHAPE_RECT)).strip_edges()
	return shape == FOCUS_SHAPE_TRAPEZOID_LEFT

func _apply_focus_panel_style(panel: Panel, entry: Dictionary, is_glow: bool) -> void:
	var style := StyleBoxFlat.new()
	var shape := str(entry.get("shape", FOCUS_SHAPE_RECT)).strip_edges()
	if shape == "":
		shape = FOCUS_SHAPE_RECT
	var shape_params: Dictionary = {}
	var raw_shape_params: Variant = entry.get("shape_params", {})
	if raw_shape_params is Dictionary:
		shape_params = raw_shape_params as Dictionary
	var corner_radius := int(round(float(shape_params.get("corner_radius", 20.0))))
	style.corner_radius_top_left = corner_radius
	style.corner_radius_top_right = corner_radius
	style.corner_radius_bottom_left = corner_radius
	style.corner_radius_bottom_right = corner_radius
	if shape == FOCUS_SHAPE_TRAPEZOID_LEFT:
		style.skew = Vector2(float(shape_params.get("skew", 0.3)), 0.0)
	if is_glow:
		style.bg_color = FOCUS_FILL_COLOR
		style.shadow_color = FOCUS_GLOW_SHADOW_COLOR
		style.shadow_size = 6
		style.shadow_offset = Vector2.ZERO
	else:
		style.bg_color = FOCUS_FRAME_FILL_COLOR
		style.border_width_left = 1
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
		style.border_color = ACCENT_SOFT_COLOR
	panel.add_theme_stylebox_override("panel", style)

func _layout_panel_relative_to_focus() -> void:
	_ensure_ui()
	var viewport_size := get_viewport_rect().size
	var viewport_rect := Rect2(Vector2.ZERO, viewport_size)
	var horizontal_margin := 28.0
	var vertical_margin := 24.0
	var spacing := 18.0
	var panel_width := _resolve_panel_width(viewport_size, horizontal_margin, spacing)
	_prepare_adaptive_panel_metrics(panel_width, viewport_size.y)
	var panel_height := minf(_panel_root.get_combined_minimum_size().y, minf(340.0, viewport_size.y * 0.48))
	panel_height = maxf(panel_height, 1.0)
	var panel_size := Vector2(panel_width, panel_height)
	_panel_root.custom_minimum_size = Vector2.ZERO
	_panel_root.size = panel_size

	var default_y := vertical_margin
	if _focus_bounds.size.x <= 1.0 or _focus_bounds.size.y <= 1.0:
		if bool(_overlay_options.get("center_panel_when_no_focus", false)):
			default_y = maxf(vertical_margin, (viewport_size.y - panel_size.y) * 0.5)
	var default_position := Vector2((viewport_size.x - panel_size.x) * 0.5, default_y)
	if _focus_bounds.size.x <= 1.0 or _focus_bounds.size.y <= 1.0:
		_panel_root.position = default_position
		_show_pointer = false
		queue_redraw()
		return

	_panel_root.position = _find_best_panel_position(panel_size, viewport_rect, horizontal_margin, vertical_margin, spacing, default_position)
	_update_pointer(panel_size)
	queue_redraw()

func _refresh_overlay_layout() -> void:
	if not visible:
		return
	_layout_panel_relative_to_focus()

func _resolve_panel_width(viewport_size: Vector2, horizontal_margin: float, spacing: float) -> float:
	var max_width := maxf(280.0, viewport_size.x - horizontal_margin * 2.0)
	var base_width := minf(440.0, max_width)
	if _focus_bounds.size.x <= 1.0 or _focus_bounds.size.y <= 1.0:
		return base_width
	var left_space := _focus_bounds.position.x - horizontal_margin - spacing
	var right_space := viewport_size.x - _focus_bounds.end.x - horizontal_margin - spacing
	var side_width := maxf(left_space, right_space)
	if side_width >= 300.0:
		return clampf(minf(base_width, side_width), 300.0, max_width)
	return base_width

func _prepare_adaptive_panel_metrics(panel_width: float, viewport_height: float) -> void:
	var content_width := maxf(220.0, panel_width - PANEL_SIDE_MARGIN * 2.0)
	var body_width := maxf(180.0, content_width - BODY_SIDE_MARGIN * 2.0)
	var body_max_height := minf(MAX_BODY_HEIGHT, viewport_height * 0.32)
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
	_guide_margin.update_minimum_size()
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

func _clamp_panel_position(panel_position: Vector2, panel_size: Vector2, viewport_rect: Rect2, horizontal_margin: float, vertical_margin: float) -> Vector2:
	return Vector2(
		clampf(panel_position.x, horizontal_margin, maxf(horizontal_margin, viewport_rect.size.x - panel_size.x - horizontal_margin)),
		clampf(panel_position.y, vertical_margin, maxf(vertical_margin, viewport_rect.size.y - panel_size.y - vertical_margin))
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
		_pointer_points = PackedVector2Array()
		return
	var panel_rect := Rect2(_panel_root.position, panel_size)
	var pointer_rect := _pick_pointer_focus_rect(panel_rect.get_center())
	var safe_target_rect := pointer_rect.grow(-6.0)
	if safe_target_rect.size.x <= 1.0 or safe_target_rect.size.y <= 1.0:
		safe_target_rect = pointer_rect
	if panel_rect.end.x <= safe_target_rect.position.x:
		var line_y := clampf(safe_target_rect.get_center().y, panel_rect.position.y + 24.0, panel_rect.end.y - 24.0)
		_pointer_points = PackedVector2Array([
			Vector2(panel_rect.end.x, line_y),
			Vector2(safe_target_rect.position.x, line_y)
		])
	elif safe_target_rect.end.x <= panel_rect.position.x:
		var line_y := clampf(safe_target_rect.get_center().y, panel_rect.position.y + 24.0, panel_rect.end.y - 24.0)
		_pointer_points = PackedVector2Array([
			Vector2(panel_rect.position.x, line_y),
			Vector2(safe_target_rect.end.x, line_y)
		])
	else:
		var line_x := clampf(safe_target_rect.get_center().x, panel_rect.position.x + 24.0, panel_rect.end.x - 24.0)
		var start_y := panel_rect.end.y
		var end_y := safe_target_rect.position.y
		if panel_rect.get_center().y > safe_target_rect.get_center().y:
			start_y = panel_rect.position.y
			end_y = safe_target_rect.end.y
		_pointer_points = PackedVector2Array([
			Vector2(line_x, start_y),
			Vector2(line_x, end_y)
		])
	if _pointer_points.size() < 2:
		_show_pointer = false
		return
	_pointer_start = _pointer_points[0]
	_pointer_end = _pointer_points[_pointer_points.size() - 1]
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

func _draw() -> void:
	for dim_rect in _dim_draw_rects:
		draw_rect(dim_rect, DIM_COLOR, true)
	for dim_polygon in _dim_overlay_polygons:
		draw_colored_polygon(dim_polygon, DIM_COLOR)
	_draw_custom_focus_highlights()
	if not _show_pointer:
		return
	if _pointer_points.size() < 2:
		return
	draw_polyline(_pointer_points, POINTER_GLOW_COLOR, 6.0, true)
	draw_polyline(_pointer_points, Color(0.88, 0.96, 1.0, 0.40), 3.0, true)
	draw_polyline(_pointer_points, POINTER_COLOR, 1.8, true)
	draw_circle(_pointer_end, 4.5, Color(0.86, 0.95, 1.0, 0.18))
	draw_circle(_pointer_end, 2.5, WARM_ACCENT_COLOR)

func _draw_custom_focus_highlights() -> void:
	for entry in _focus_entries:
		if not _should_use_custom_focus_draw(entry):
			continue
		var polygon := _get_focus_display_polygon(entry)
		if polygon.size() < 3:
			continue
		_draw_focus_polygon_highlight(polygon)

func _get_focus_display_polygon(entry: Dictionary) -> PackedVector2Array:
	var polygon := _get_focus_cutout_polygon(entry)
	if polygon.size() >= 3:
		return polygon
	var rect: Rect2 = entry.get("rect", Rect2())
	if rect.size.x <= 1.0 or rect.size.y <= 1.0:
		return PackedVector2Array()
	return PackedVector2Array([
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y)
	])

func _draw_focus_polygon_highlight(polygon: PackedVector2Array) -> void:
	draw_colored_polygon(polygon, FOCUS_FRAME_FILL_COLOR)
	var closed_points := _build_closed_polyline_points(polygon)
	if closed_points.size() < 2:
		return
	draw_polyline(closed_points, Color(0.60, 0.86, 0.84, 0.05), 8.0, true)
	draw_polyline(closed_points, Color(0.60, 0.86, 0.84, 0.12), 5.0, true)
	draw_polyline(closed_points, Color(0.60, 0.86, 0.84, 0.20), 3.0, true)
	draw_polyline(closed_points, ACCENT_SOFT_COLOR, 1.6, true)

func _build_closed_polyline_points(polygon: PackedVector2Array) -> PackedVector2Array:
	if polygon.size() < 3:
		return PackedVector2Array()
	var closed_points := PackedVector2Array()
	for point in polygon:
		closed_points.append(point)
	closed_points.append(polygon[0])
	return closed_points
