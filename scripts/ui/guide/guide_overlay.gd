extends Control

@warning_ignore("unused_signal")
signal skip_pressed
signal background_pressed(action_id: String)
signal focus_pressed(action_id: String)

const DIM_COLOR := Color(0.02, 0.03, 0.06, 0.64)
const ACCENT_SOFT_COLOR := Color(0.39, 0.96, 0.83, 1.0)
const WARM_ACCENT_COLOR := Color(0.94, 0.80, 0.61, 1.0)
const FOCUS_FILL_COLOR := Color(0.30, 1.0, 0.84, 0.0)
const FOCUS_FRAME_FILL_COLOR := Color(0.30, 1.0, 0.84, 0.0)
const FOCUS_GLOW_SHADOW_COLOR := Color(0.25, 1.0, 0.82, 0.38)
const FOCUS_GLOW_MIN_EXPANSION := 1.5
const FOCUS_GLOW_MAX_EXPANSION := 5.5
const FOCUS_AURA_MIN_EXPANSION := 4.0
const FOCUS_AURA_MAX_EXPANSION := 8.0
const MESSAGE_REVEAL_DELAY := 0.2
const MESSAGE_REVEAL_DURATION := 0.5
const MESSAGE_MIN_WIDTH := 300.0
const MESSAGE_MAX_WIDTH := 500.0
const MESSAGE_HORIZONTAL_PADDING := 44.0
const MESSAGE_FONT_SIZE := 17
const MESSAGE_BODY_HEIGHT := 66.0
const POINTER_SIZE := Vector2(88.0, 88.0)
const POINTER_HOTSPOT := Vector2(22.0, 16.0)
const HAND_BASE_SCALE := 1.12
const HAND_RUNTIME_OFFSET := Vector2(15.0, 3.0)
const FOCUS_SHAPE_RECT := "rect"
const FOCUS_SHAPE_TRAPEZOID_LEFT := "trapezoid_left"

@onready var _panel_root: PanelContainer = $GuidePanel
@onready var _input_blocker: ColorRect = $InputBlocker
@onready var _guide_row: HBoxContainer = $GuidePanel/GuideRow
@onready var _avatar_frame: PanelContainer = $GuidePanel/GuideRow/AvatarFrame
@onready var _message_panel: PanelContainer = $GuidePanel/GuideRow/MessagePanel
@onready var _body_label: RichTextLabel = $GuidePanel/GuideRow/MessagePanel/MessageMargin/BodyLabel
@onready var _click_pointer: Control = $ClickPointer
@onready var _click_ring: Panel = $ClickPointer/ClickRing
@onready var _hand_shadow: TextureRect = $ClickPointer/HandShadow
@onready var _hand_texture: TextureRect = $ClickPointer/HandTexture

var _focus_entries: Array[Dictionary] = []
var _focus_rects: Array[Rect2] = []
var _focus_bounds: Rect2 = Rect2()
var _show_pointer: bool = false
var _focus_interaction_allowed: bool = false
var _animation_time := 0.0
var _focus_pulse := 0.0
var _pointer_base_position := Vector2.ZERO
var _hand_shadow_base_position := Vector2.ZERO
var _hand_base_position := Vector2.ZERO
var _avatar_size := 135.0
var _message_height := 100.0
var _guide_row_overlap := 30.0
var _ui_built: bool = false
var _dim_draw_rects: Array[Rect2] = []
var _dim_overlay_polygons: Array[PackedVector2Array] = []
var _dim_segments: Array[ColorRect] = []
var _focus_auras: Array[Panel] = []
var _focus_glows: Array[Panel] = []
var _focus_frames: Array[Panel] = []
var _focus_capture_overlays: Array[ColorRect] = []
var _overlay_options: Dictionary = {}
var _message_reveal_token := 0
var _message_reveal_tween: Tween
var _presentation_signature := ""
var _focus_press_pending := false
var _focus_press_action_id := ""

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_input_blocker.gui_input.connect(_on_input_blocker_gui_input)
	_panel_root.visible = false
	_panel_root.modulate.a = 0.0
	visible = false
	_ensure_ui()
	set_process(true)

func _process(delta: float) -> void:
	if not visible:
		return
	_animation_time += delta
	_update_focus_animation()
	_update_click_pointer_animation()

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

func _on_input_blocker_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	_input_blocker.accept_event()
	get_viewport().set_input_as_handled()
	if not mouse_event.pressed:
		return
	if not _focus_bounds.has_point(mouse_event.position):
		var background_action_id := str(_overlay_options.get("background_wait_action", "")).strip_edges()
		if background_action_id != "":
			background_pressed.emit(background_action_id)
		return
	var focus_action_id := str(_overlay_options.get("focus_wait_action", "")).strip_edges()
	if focus_action_id == "" or _focus_press_pending:
		return
	_focus_press_pending = true
	_focus_press_action_id = focus_action_id
	call_deferred("_emit_focus_pressed", focus_action_id)

func _ensure_ui() -> void:
	if _ui_built:
		return
	if _panel_root == null or _body_label == null or _avatar_frame == null or _message_panel == null or _guide_row == null:
		return
	if _panel_root != null:
		_panel_root.mouse_filter = Control.MOUSE_FILTER_STOP
		_panel_root.z_index = 50
	if _body_label != null:
		_body_label.fit_content = false
		_body_label.scroll_active = false
		_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if _avatar_frame != null:
		_avatar_size = maxf(_avatar_frame.custom_minimum_size.x, _avatar_frame.custom_minimum_size.y)
	if _message_panel != null:
		_message_height = _message_panel.custom_minimum_size.y
	if _guide_row != null:
		_guide_row_overlap = maxf(0.0, -float(_guide_row.get_theme_constant("separation")))
	if _click_pointer != null:
		_click_pointer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hand_shadow_base_position = _hand_shadow.position
		_hand_base_position = _hand_texture.position
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
	glow_style.draw_center = false
	glow_style.border_width_left = 2
	glow_style.border_width_top = 2
	glow_style.border_width_right = 2
	glow_style.border_width_bottom = 2
	glow_style.border_color = FOCUS_GLOW_SHADOW_COLOR
	glow_style.border_blend = true
	glow_style.anti_aliasing_size = 3.0
	glow_style.corner_radius_top_left = 12
	glow_style.corner_radius_top_right = 12
	glow_style.corner_radius_bottom_left = 12
	glow_style.corner_radius_bottom_right = 12
	panel.add_theme_stylebox_override("panel", glow_style)
	return panel

func _build_focus_aura(node_name: String) -> Panel:
	var panel := Panel.new()
	panel.name = node_name
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.visible = false
	panel.z_index = 11
	var aura_style := StyleBoxFlat.new()
	aura_style.bg_color = FOCUS_FILL_COLOR
	aura_style.draw_center = false
	aura_style.border_width_left = 1
	aura_style.border_width_top = 1
	aura_style.border_width_right = 1
	aura_style.border_width_bottom = 1
	aura_style.border_color = Color(0.32, 1.0, 0.88, 0.22)
	aura_style.border_blend = true
	aura_style.anti_aliasing_size = 6.0
	aura_style.corner_radius_top_left = 14
	aura_style.corner_radius_top_right = 14
	aura_style.corner_radius_bottom_left = 14
	aura_style.corner_radius_bottom_right = 14
	panel.add_theme_stylebox_override("panel", aura_style)
	return panel

func _build_focus_frame(node_name: String) -> Panel:
	var panel := Panel.new()
	panel.name = node_name
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.visible = false
	panel.z_index = 13
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = FOCUS_FRAME_FILL_COLOR
	frame_style.draw_center = false
	frame_style.border_width_left = 1
	frame_style.border_width_top = 1
	frame_style.border_width_right = 1
	frame_style.border_width_bottom = 1
	frame_style.border_color = ACCENT_SOFT_COLOR
	frame_style.corner_radius_top_left = 10
	frame_style.corner_radius_top_right = 10
	frame_style.corner_radius_bottom_left = 10
	frame_style.corner_radius_bottom_right = 10
	panel.add_theme_stylebox_override("panel", frame_style)
	return panel

func _build_focus_capture_overlay(node_name: String) -> ColorRect:
	var rect := ColorRect.new()
	rect.name = node_name
	rect.color = Color(1, 1, 1, 0)
	rect.mouse_filter = Control.MOUSE_FILTER_STOP
	rect.visible = false
	rect.z_index = 30
	if not rect.gui_input.is_connected(_on_focus_capture_gui_input):
		rect.gui_input.connect(_on_focus_capture_gui_input)
	return rect

func _on_focus_capture_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	if mouse_event.pressed:
		var pressed_action_id := str(_overlay_options.get("focus_wait_action", "")).strip_edges()
		if pressed_action_id == "":
			return
		get_viewport().set_input_as_handled()
		if _focus_press_pending:
			return
		_focus_press_pending = true
		_focus_press_action_id = pressed_action_id
		call_deferred("_emit_focus_pressed", pressed_action_id)
		return
	get_viewport().set_input_as_handled()

func _emit_focus_pressed(action_id: String) -> void:
	if not _focus_press_pending or _focus_press_action_id != action_id:
		return
	_focus_press_pending = false
	_focus_press_action_id = ""
	focus_pressed.emit(action_id)

func show_step(guide_title: String, step_title: String, step_text: String, current_index: int, total_steps: int, focus_data: Variant = null, focus_interaction_allowed: bool = false, overlay_options: Dictionary = {}) -> void:
	_ensure_ui()
	var _unused_guide_title := guide_title
	var _unused_step_title := step_title
	var _unused_current_index := current_index
	var _unused_total_steps := total_steps
	_overlay_options = overlay_options.duplicate(true)
	_focus_interaction_allowed = focus_interaction_allowed
	_input_blocker.visible = bool(_overlay_options.get("capture_focus_clicks", false))
	if _panel_root != null:
		_set_control_tree_mouse_filter(_panel_root, Control.MOUSE_FILTER_IGNORE if focus_interaction_allowed else Control.MOUSE_FILTER_STOP)
	var hide_message_panel := bool(_overlay_options.get("hide_message_panel", false))
	var final_step_text := step_text.strip_edges()
	if final_step_text == "" and not hide_message_panel:
		final_step_text = "跟着我标出的地方继续吧。"
	var normalized_focus_entries := _normalize_focus_input(focus_data)
	var presentation_signature := _build_presentation_signature(final_step_text, hide_message_panel)
	var is_same_presentation := presentation_signature == _presentation_signature
	_presentation_signature = presentation_signature
	_body_label.text = final_step_text
	_apply_focus_entries(normalized_focus_entries)
	show()
	if is_same_presentation:
		call_deferred("_refresh_overlay_layout")
		return
	_animation_time = 0.0
	_message_reveal_token += 1
	if _message_reveal_tween != null and _message_reveal_tween.is_valid():
		_message_reveal_tween.kill()
	_panel_root.visible = false
	_panel_root.modulate.a = 0.0
	call_deferred("_refresh_overlay_layout")
	if not hide_message_panel:
		call_deferred("_reveal_message_panel", _message_reveal_token)

func _build_presentation_signature(step_text: String, hide_message_panel: bool) -> String:
	return "%s|%s|%s" % [str(_overlay_options.get("presentation_id", "")), step_text, str(hide_message_panel)]

func _reveal_message_panel(reveal_token: int) -> void:
	await get_tree().create_timer(MESSAGE_REVEAL_DELAY).timeout
	if reveal_token != _message_reveal_token or not visible:
		return
	_panel_root.visible = true
	_panel_root.modulate.a = 0.0
	_layout_panel_relative_to_focus()
	_message_reveal_tween = create_tween()
	_message_reveal_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_message_reveal_tween.tween_property(_panel_root, "modulate:a", 1.0, MESSAGE_REVEAL_DURATION)

func begin_step_transition() -> void:
	_ensure_ui()
	_focus_press_pending = false
	_focus_press_action_id = ""
	_focus_interaction_allowed = false
	if is_instance_valid(_input_blocker):
		_input_blocker.visible = false
	_show_pointer = false
	if is_instance_valid(_click_pointer):
		_click_pointer.visible = false
	for capture_overlay in _focus_capture_overlays:
		capture_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		capture_overlay.visible = false
	for dim_rect in _dim_segments:
		dim_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	if is_instance_valid(_panel_root):
		_set_control_tree_mouse_filter(_panel_root, Control.MOUSE_FILTER_STOP)

func hide_overlay() -> void:
	_ensure_ui()
	if is_instance_valid(_input_blocker):
		_input_blocker.visible = false
	_focus_press_pending = false
	_focus_press_action_id = ""
	_message_reveal_token += 1
	if _message_reveal_tween != null and _message_reveal_tween.is_valid():
		_message_reveal_tween.kill()
	_overlay_options.clear()
	_presentation_signature = ""
	if is_instance_valid(_panel_root):
		_panel_root.visible = false
		_panel_root.modulate.a = 0.0
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
	if is_instance_valid(_click_pointer):
		_click_pointer.visible = false
	for dim_rect in _dim_segments:
		dim_rect.visible = false
	for glow_panel in _focus_glows:
		glow_panel.visible = false
	for aura_panel in _focus_auras:
		aura_panel.visible = false
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
	while _focus_auras.size() < target_count:
		var aura_panel := _build_focus_aura("FocusAura%d" % _focus_auras.size())
		_focus_auras.append(aura_panel)
		add_child(aura_panel)
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
		var segment_count := floori(float(mini(top_intersections.size(), bottom_intersections.size())) / 2.0)
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
		var aura_panel := _focus_auras[index]
		var glow_panel := _focus_glows[index]
		var frame_panel := _focus_frames[index]
		if index < _focus_entries.size():
			var entry := _focus_entries[index]
			var rect: Rect2 = entry.get("rect", Rect2())
			if _should_use_custom_focus_draw(entry):
				aura_panel.visible = false
				glow_panel.visible = false
				frame_panel.visible = false
				continue
			glow_panel.position = rect.position.floor()
			glow_panel.size = Vector2(ceilf(rect.size.x), ceilf(rect.size.y))
			frame_panel.position = rect.position.floor()
			frame_panel.size = Vector2(ceilf(rect.size.x), ceilf(rect.size.y))
			aura_panel.position = rect.position.floor()
			aura_panel.size = Vector2(ceilf(rect.size.x), ceilf(rect.size.y))
			_apply_focus_panel_style(aura_panel, entry, true, true)
			_apply_focus_panel_style(glow_panel, entry, true)
			_apply_focus_panel_style(frame_panel, entry, false)
			aura_panel.visible = true
			glow_panel.visible = true
			frame_panel.visible = true
		else:
			aura_panel.visible = false
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
			capture_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
			capture_overlay.visible = true
		else:
			capture_overlay.visible = false
	for dim_rect in _dim_segments:
		dim_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _should_use_custom_focus_draw(entry: Dictionary) -> bool:
	var shape := str(entry.get("shape", FOCUS_SHAPE_RECT)).strip_edges()
	return shape == FOCUS_SHAPE_TRAPEZOID_LEFT

func _apply_focus_panel_style(panel: Panel, entry: Dictionary, is_glow: bool, is_aura: bool = false) -> void:
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
		style.draw_center = false
		var border_width := 1 if is_aura else 2
		style.border_width_left = border_width
		style.border_width_top = border_width
		style.border_width_right = border_width
		style.border_width_bottom = border_width
		style.border_color = Color(0.32, 1.0, 0.88, 0.22) if is_aura else FOCUS_GLOW_SHADOW_COLOR
		style.border_blend = true
		style.anti_aliasing_size = 6.0 if is_aura else 3.0
	else:
		style.bg_color = FOCUS_FRAME_FILL_COLOR
		style.draw_center = false
		style.border_width_left = 1
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
		style.border_color = ACCENT_SOFT_COLOR
	panel.add_theme_stylebox_override("panel", style)

func _update_focus_animation() -> void:
	var pulse := (sin(_animation_time * TAU / 1.45) + 1.0) * 0.5
	var smooth_pulse := pulse * pulse * (3.0 - 2.0 * pulse)
	_focus_pulse = smooth_pulse
	for index in range(_focus_auras.size()):
		var aura_panel := _focus_auras[index]
		if not aura_panel.visible or index >= _focus_entries.size():
			continue
		var focus_rect: Rect2 = _focus_entries[index].get("rect", Rect2())
		var aura_pulse := (sin(_animation_time * TAU / 2.2 + 0.7) + 1.0) * 0.5
		var aura_expansion := lerpf(FOCUS_AURA_MIN_EXPANSION, FOCUS_AURA_MAX_EXPANSION, aura_pulse)
		aura_panel.position = focus_rect.position - Vector2.ONE * aura_expansion
		aura_panel.size = focus_rect.size + Vector2.ONE * aura_expansion * 2.0
		aura_panel.modulate = Color(0.72, 1.0, 0.94, lerpf(0.16, 0.34, aura_pulse))
	for index in range(_focus_glows.size()):
		var glow_panel := _focus_glows[index]
		if not glow_panel.visible or index >= _focus_entries.size():
			continue
		var focus_rect: Rect2 = _focus_entries[index].get("rect", Rect2())
		var expansion := lerpf(FOCUS_GLOW_MIN_EXPANSION, FOCUS_GLOW_MAX_EXPANSION, smooth_pulse)
		glow_panel.scale = Vector2.ONE
		glow_panel.position = focus_rect.position - Vector2.ONE * expansion
		glow_panel.size = focus_rect.size + Vector2.ONE * expansion * 2.0
		glow_panel.modulate = Color(0.88, 1.0, 0.97, lerpf(0.38, 0.76, smooth_pulse))
	for frame_panel in _focus_frames:
		if not frame_panel.visible:
			continue
		var shimmer_color := ACCENT_SOFT_COLOR.lerp(WARM_ACCENT_COLOR, smooth_pulse * 0.22)
		frame_panel.modulate = Color(shimmer_color.r, shimmer_color.g, shimmer_color.b, lerpf(0.78, 1.0, smooth_pulse))
	queue_redraw()

func _layout_panel_relative_to_focus() -> void:
	_ensure_ui()
	var viewport_size := get_viewport_rect().size
	var viewport_rect := Rect2(Vector2.ZERO, viewport_size)
	var horizontal_margin := 28.0
	var vertical_margin := 24.0
	var spacing := 18.0
	var panel_width := _resolve_panel_width(viewport_size, horizontal_margin)
	_prepare_adaptive_panel_metrics(panel_width, viewport_size.y)
	var panel_size := Vector2(panel_width, _avatar_size)
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
		_click_pointer.visible = false
		queue_redraw()
		return

	_panel_root.position = _find_best_panel_position(panel_size, viewport_rect, horizontal_margin, vertical_margin, spacing, default_position)
	_update_pointer(panel_size)
	queue_redraw()

func _refresh_overlay_layout() -> void:
	if not visible:
		return
	_layout_panel_relative_to_focus()

func _resolve_panel_width(viewport_size: Vector2, horizontal_margin: float) -> float:
	var max_total_width := maxf(280.0, viewport_size.x - horizontal_margin * 2.0)
	var plain_text := _body_label.get_parsed_text().strip_edges() if is_instance_valid(_body_label) else ""
	var text_font := _body_label.get_theme_font("normal_font")
	var message_max_width := minf(MESSAGE_MAX_WIDTH, max_total_width - _avatar_size + _guide_row_overlap)
	var message_width := minf(MESSAGE_MIN_WIDTH, message_max_width)
	while message_width < message_max_width:
		var body_width := maxf(220.0, message_width - MESSAGE_HORIZONTAL_PADDING)
		var text_size := text_font.get_multiline_string_size(plain_text, HORIZONTAL_ALIGNMENT_LEFT, body_width, MESSAGE_FONT_SIZE)
		if text_size.y <= MESSAGE_BODY_HEIGHT:
			break
		message_width = minf(message_max_width, message_width + 20.0)
	return minf(max_total_width, _avatar_size + message_width - _guide_row_overlap)

func _prepare_adaptive_panel_metrics(panel_width: float, viewport_height: float) -> void:
	var _unused_viewport_height := viewport_height
	var message_width := maxf(MESSAGE_MIN_WIDTH, panel_width - _avatar_size + _guide_row_overlap)
	var body_width := maxf(220.0, message_width - MESSAGE_HORIZONTAL_PADDING)
	_message_panel.custom_minimum_size = Vector2(message_width, _message_height)
	_message_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_body_label.fit_content = false
	_body_label.scroll_active = false
	_body_label.custom_minimum_size = Vector2(body_width, MESSAGE_BODY_HEIGHT)
	_body_label.size = Vector2(body_width, MESSAGE_BODY_HEIGHT)
	_body_label.update_minimum_size()
	_message_panel.update_minimum_size()
	_panel_root.update_minimum_size()

func _find_best_panel_position(panel_size: Vector2, viewport_rect: Rect2, horizontal_margin: float, vertical_margin: float, spacing: float, fallback_position: Vector2) -> Vector2:
	var focus_center := _focus_bounds.get_center()
	var panel_placement := str(_overlay_options.get("panel_placement", "")).strip_edges()
	if panel_placement == "below":
		return _clamp_panel_position(
			Vector2(focus_center.x - panel_size.x * 0.5, _focus_bounds.end.y + spacing),
			panel_size,
			viewport_rect,
			horizontal_margin,
			vertical_margin
		)
	if panel_placement == "left":
		return _clamp_panel_position(
			Vector2(_focus_bounds.position.x - panel_size.x - spacing, focus_center.y - panel_size.y * 0.5),
			panel_size,
			viewport_rect,
			horizontal_margin,
			vertical_margin
		)
	if panel_placement == "right":
		return _clamp_panel_position(
			Vector2(_focus_bounds.end.x + spacing, focus_center.y - panel_size.y * 0.5),
			panel_size,
			viewport_rect,
			horizontal_margin,
			vertical_margin
		)
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

func _update_pointer(_panel_size: Vector2) -> void:
	var show_click_pointer := bool(_overlay_options.get("show_click_pointer", _focus_interaction_allowed))
	if _focus_rects.is_empty() or not show_click_pointer:
		_show_pointer = false
		_click_pointer.visible = false
		return
	var pointer_index := clampi(int(_overlay_options.get("pointer_focus_index", 0)), 0, _focus_rects.size() - 1)
	var target_center := _focus_rects[pointer_index].get_center()
	var raw_offset: Variant = _overlay_options.get("pointer_offset", Vector2.ZERO)
	var pointer_offset := raw_offset as Vector2 if raw_offset is Vector2 else Vector2.ZERO
	_pointer_base_position = target_center - POINTER_HOTSPOT + pointer_offset
	_click_pointer.position = _pointer_base_position
	_click_pointer.pivot_offset = POINTER_HOTSPOT
	_click_ring.position = POINTER_HOTSPOT - _click_ring.size * 0.5
	_click_pointer.visible = true
	_show_pointer = true

func _update_click_pointer_animation() -> void:
	if not _show_pointer or not is_instance_valid(_click_pointer):
		return
	var cycle := fmod(_animation_time, 1.2) / 1.2
	var press_amount := 0.0
	if cycle < 0.28:
		press_amount = sin((cycle / 0.28) * PI * 0.5)
	elif cycle < 0.48:
		press_amount = cos(((cycle - 0.28) / 0.20) * PI * 0.5)
	_click_pointer.position = _pointer_base_position
	_hand_shadow.position = _hand_shadow_base_position + HAND_RUNTIME_OFFSET
	_hand_shadow.pivot_offset = POINTER_HOTSPOT - _hand_shadow.position
	_hand_shadow.scale = Vector2.ONE * lerpf(HAND_BASE_SCALE, 0.98, press_amount)
	_hand_texture.position = _hand_base_position + HAND_RUNTIME_OFFSET
	_hand_texture.pivot_offset = POINTER_HOTSPOT - _hand_texture.position
	_hand_texture.scale = Vector2.ONE * lerpf(HAND_BASE_SCALE, 0.98, press_amount)
	var ring_progress := clampf((cycle - 0.20) / 0.48, 0.0, 1.0)
	_click_ring.pivot_offset = _click_ring.size * 0.5
	_click_ring.scale = Vector2.ONE * lerpf(0.55, 1.35, ring_progress)
	_click_ring.modulate.a = 1.0 - ring_progress

func _draw() -> void:
	for dim_rect in _dim_draw_rects:
		draw_rect(dim_rect, DIM_COLOR, true)
	for dim_polygon in _dim_overlay_polygons:
		draw_colored_polygon(dim_polygon, DIM_COLOR)
	_draw_custom_focus_highlights()

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
	var pulse_alpha := lerpf(0.52, 1.0, _focus_pulse)
	var fill_color := FOCUS_FRAME_FILL_COLOR
	fill_color.a *= pulse_alpha
	draw_colored_polygon(polygon, fill_color)
	var closed_points := _build_closed_polyline_points(polygon)
	if closed_points.size() < 2:
		return
	draw_polyline(closed_points, Color(0.25, 1.0, 0.82, lerpf(0.05, 0.22, _focus_pulse)), lerpf(3.0, 7.0, _focus_pulse), true)
	draw_polyline(closed_points, Color(0.30, 1.0, 0.84, lerpf(0.16, 0.44, _focus_pulse)), lerpf(1.5, 2.5, _focus_pulse), true)
	var frame_color := ACCENT_SOFT_COLOR.lerp(WARM_ACCENT_COLOR, _focus_pulse * 0.22)
	frame_color.a = pulse_alpha
	draw_polyline(closed_points, frame_color, 1.0, true)

func _build_closed_polyline_points(polygon: PackedVector2Array) -> PackedVector2Array:
	if polygon.size() < 3:
		return PackedVector2Array()
	var closed_points := PackedVector2Array()
	for point in polygon:
		closed_points.append(point)
	closed_points.append(polygon[0])
	return closed_points
