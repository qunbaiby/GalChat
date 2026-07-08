extends Node2D

signal pet_clicked()
signal pet_right_clicked()
signal pet_area_touched(hit_area: String)
signal app_observe_requested()
signal bubbles_changed()

@onready var state_ring: Control = $StateRing
@onready var state_clock_label: Label = $StateRing/ClockLabel
@onready var pet_model: Node2D = $GDCubismUserModel
@onready var target_point_effect: Node = get_node_or_null("GDCubismUserModel/GDCubismEffectTargetPoint")
@onready var hit_area_effect: Node = get_node_or_null("GDCubismUserModel/GDCubismEffectHitArea")
@onready var bubble_container: VBoxContainer = $BubbleContainer
@onready var bubble_template: PanelContainer = $BubbleContainer/SpeechBubble
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

const DEFAULT_LIVE2D_ASSET: String = "res://assets/live2d/Mao/Mao.model3.json"

var _click_start_pos: Vector2 = Vector2.ZERO
var _left_drag_tracking: bool = false
var _left_drag_started: bool = false
var _window_drag_offset: Vector2i = Vector2i.ZERO
var _click_control: Control
var _live2d_bounds_rect: Rect2 = Rect2()
var _live2d_bounds_valid: bool = false
var _live2d_bounds_elapsed: float = 0.0

# 状态环变量
var current_state: int = 0 # 0: Idle, 1: Thinking, 2: Speaking, 3: AfkCountdown, 4: ProactiveCooldown
var state_progress: float = 0.0
var ring_time: float = 0.0
var ring_volume: float = 0.0

var _current_modulate: Color = Color.WHITE
var _base_model_scale: Vector2 = Vector2.ONE
var _motions: Dictionary = {}
var _expressions: Array = []
var _current_hit_area: String = ""
var _touch_random := RandomNumberGenerator.new()
var _ring_color1: Color = Color(0.4, 0.75, 1.0, 0.8)
var _ring_color2: Color = Color(0.7, 0.95, 1.0, 0.8)
var _ring_progress: float = 1.0
var _ring_width: float = 0.75
var _ring_blur: float = 0.8
var _ring_speed: float = 0.4
var _ring_start_offset: float = 0.0
var _last_clock_text: String = ""
var _is_idle_motion_active: bool = false

func _ready() -> void:
	bubble_template.hide()
	_touch_random.randomize()
	
	state_ring.draw.connect(_on_ring_draw)
	state_ring.mouse_filter = Control.MOUSE_FILTER_STOP
	state_ring.gui_input.connect(_on_state_ring_gui_input)
	if pet_model:
		_base_model_scale = pet_model.scale
	
	# 动态创建一个 Control 用于可靠的点击检测
	var click_control = Control.new()
	_click_control = click_control
	click_control.position = Vector2(-40, -10)
	click_control.size = Vector2(80, 180)
		
	if collision_shape and collision_shape.shape is RectangleShape2D:
		var size = collision_shape.shape.size
		# 确保 size 不是 0
		if size.x > 0 and size.y > 0:
			var pos = collision_shape.position - size / 2.0
			click_control.position = pos
			click_control.size = size
			
	click_control.mouse_filter = Control.MOUSE_FILTER_STOP
	click_control.gui_input.connect(_on_click_control_gui_input)
	add_child(click_control)
	state_ring.move_to_front()
	
	if pet_model:
		_setup_live2d_model()
		_setup_live2d_interaction_effects()
		call_deferred("_refresh_live2d_bounds")

func _setup_live2d_model() -> void:
	if not pet_model:
		return
	if FileAccess.file_exists(DEFAULT_LIVE2D_ASSET):
		pet_model.set("assets", DEFAULT_LIVE2D_ASSET)
		call_deferred("_start_live2d_idle_motion")
	else:
		push_warning("Live2D desktop pet asset missing: %s" % DEFAULT_LIVE2D_ASSET)

func _setup_live2d_interaction_effects() -> void:
	if hit_area_effect:
		if hit_area_effect.has_signal("hit_area_entered") and not hit_area_effect.hit_area_entered.is_connected(_on_hit_area_entered):
			hit_area_effect.hit_area_entered.connect(_on_hit_area_entered)
		if hit_area_effect.has_signal("hit_area_exited") and not hit_area_effect.hit_area_exited.is_connected(_on_hit_area_exited):
			hit_area_effect.hit_area_exited.connect(_on_hit_area_exited)
	if pet_model and pet_model.has_signal("motion_finished") and not pet_model.motion_finished.is_connected(_on_live2d_motion_finished):
		pet_model.motion_finished.connect(_on_live2d_motion_finished)
	_refresh_live2d_animation_catalog()

func _refresh_live2d_animation_catalog() -> void:
	_motions.clear()
	_expressions.clear()
	if pet_model and pet_model.has_method("get_motions"):
		_motions = pet_model.call("get_motions")
	if pet_model and pet_model.has_method("get_expressions"):
		_expressions = pet_model.call("get_expressions")

func _start_live2d_idle_motion() -> void:
	if not is_instance_valid(pet_model) or not pet_model.has_method("get_motions"):
		return
	_refresh_live2d_animation_catalog()
	_play_random_motion("Idle", true)

func _play_random_motion(group_name: String, loop: bool = false) -> bool:
	if not is_instance_valid(pet_model) or not _motions.has(group_name):
		return false
	var items = _motions[group_name]
	var count := _get_motion_count(items)
	if count <= 0:
		return false
	var index := _touch_random.randi_range(0, count - 1)
	_is_idle_motion_active = loop and group_name == "Idle"
	if loop:
		pet_model.call("start_motion_loop", group_name, index, GDCubismUserModel.PRIORITY_FORCE, true, true)
	elif pet_model.has_method("start_motion"):
		pet_model.call("start_motion", group_name, index, GDCubismUserModel.PRIORITY_FORCE)
	else:
		pet_model.call("start_motion_loop", group_name, index, GDCubismUserModel.PRIORITY_FORCE, false, false)
	return true

func _get_motion_count(items) -> int:
	match typeof(items):
		TYPE_ARRAY, TYPE_DICTIONARY, TYPE_PACKED_STRING_ARRAY:
			return items.size()
		TYPE_INT:
			return int(items)
		_:
			return 0

func _play_random_expression() -> void:
	if not is_instance_valid(pet_model) or not pet_model.has_method("start_expression") or _expressions.is_empty():
		return
	var expression_id := str(_expressions[_touch_random.randi_range(0, _expressions.size() - 1)])
	pet_model.call("start_expression", expression_id)

func _on_live2d_motion_finished() -> void:
	if _is_idle_motion_active:
		return
	_play_random_motion("Idle", true)

func _update_time_based_lighting() -> void:
	if not pet_model: return
	
	var time_dict = Time.get_datetime_dict_from_system()
	var hour = time_dict["hour"]
	
	var target_color = Color.WHITE
	
	# 根据现实时间调整立绘和光环的整体色调与亮度
	if hour >= 6 and hour < 9:
		# 清晨：带点晨雾的偏蓝冷色，亮度正常
		target_color = Color(0.95, 0.98, 1.0, 1.0)
	elif hour >= 9 and hour < 16:
		# 白天：正常明亮
		target_color = Color.WHITE
	elif hour >= 16 and hour < 19:
		# 黄昏：偏暖黄/橙色，夕阳感
		target_color = Color(1.0, 0.95, 0.9, 1.0)
	elif hour >= 19 and hour < 22:
		# 傍晚：稍微变暗，轻微偏蓝紫
		target_color = Color(0.9, 0.9, 0.95, 1.0)
	else:
		# 深夜 (22~6)：明显变暗，降低刺眼感（夜间模式）
		target_color = Color(0.75, 0.75, 0.85, 1.0)
		
	# 平滑过渡颜色
	_current_modulate = _current_modulate.lerp(target_color, 0.05)
	pet_model.modulate = _current_modulate
	if is_instance_valid(state_ring):
		state_ring.modulate = _current_modulate

func _process(delta: float) -> void:
	_update_time_based_lighting()
	_update_live2d_pointer_target_from_global(get_global_mouse_position(), true)
	_live2d_bounds_elapsed += delta
	if _live2d_bounds_elapsed >= 0.35:
		_live2d_bounds_elapsed = 0.0
		_refresh_live2d_bounds()
	_update_click_control_bounds()
	
	ring_time += delta
	if is_instance_valid(state_ring):
		_update_ring_style()
		_update_clock_label()
		state_ring.visible = true
		state_ring.queue_redraw()

func _update_ring_style() -> void:
	var base_width := 0.75
	var base_blur := 0.8
	_ring_start_offset = 0.0
	if current_state == 0:
		_ring_progress = 1.0
		var breath: float = (sin(ring_time * 2.5) + 1.0) * 0.5
		var alpha_mod: float = lerpf(0.18, 0.72, breath)
		_ring_color1 = Color(0.48, 0.82, 1.0, alpha_mod)
		_ring_color2 = Color(0.78, 0.96, 1.0, alpha_mod)
		_ring_speed = 0.4
		_ring_width = base_width
		_ring_blur = lerpf(base_blur, base_blur + 0.6, breath)
	elif current_state == 1:
		_ring_progress = 0.42
		_ring_start_offset = fposmod(ring_time * 0.65, 1.0)
		var flicker: float = (sin(ring_time * 8.0) + 1.0) * 0.5
		_ring_color1 = Color(0.18, 0.82, 1.0, 0.76 + flicker * 0.18)
		_ring_color2 = Color(0.74, 0.48, 1.0, 0.72 + flicker * 0.2)
		_ring_speed = 1.8
		_ring_width = base_width
		_ring_blur = base_blur + flicker * 0.5
	elif current_state == 2:
		_ring_progress = 1.0
		_ring_color1 = Color(1.0, 0.36, 0.55, 0.86)
		_ring_color2 = Color(1.0, 0.7, 0.28, 0.86)
		_ring_speed = 1.6
		_ring_width = base_width + ring_volume * 0.8
		_ring_blur = base_blur + ring_volume * 1.0
	elif current_state == 3:
		_ring_progress = state_progress
		var pulse: float = (sin(ring_time * 2.2) + 1.0) * 0.5
		_ring_color1 = Color(0.14, 0.84, 0.5, 0.66 + pulse * 0.1)
		_ring_color2 = Color(0.54, 0.94, 0.84, 0.68 + pulse * 0.1)
		_ring_speed = 0.8
		_ring_width = base_width
		_ring_blur = base_blur + pulse * 0.4
	elif current_state == 4:
		_ring_progress = state_progress
		var pulse: float = (sin(ring_time * 3.0) + 1.0) * 0.5
		_ring_color1 = Color(1.0, 0.45, 0.08, 0.72 + pulse * 0.14)
		_ring_color2 = Color(1.0, 0.82, 0.22, 0.72 + pulse * 0.14)
		_ring_speed = 1.0
		_ring_width = base_width
		_ring_blur = base_blur + pulse * 0.6

func _on_ring_draw() -> void:
	var center := state_ring.size * 0.5
	var radius: float = maxf(4.0, minf(state_ring.size.x, state_ring.size.y) * 0.5 - 5.0)
	var points := _build_circle_points(center, radius, 96)
	state_ring.draw_circle(center, radius + 5.0, Color(0.03, 0.05, 0.07, 0.52))
	state_ring.draw_circle(center, radius + 2.5, Color(0.88, 0.96, 0.98, 0.18))
	if current_state != 3:
		state_ring.draw_circle(center, radius + 1.0, Color(0.05, 0.07, 0.09, 0.28))
		_draw_polyline_loop(points, Color(0.2, 0.2, 0.25, 0.20), _ring_width + 1.2, true)
	else:
		state_ring.draw_circle(center, radius + 1.0, Color(0.05, 0.07, 0.09, 0.22))
	if _ring_progress >= 0.985:
		if _ring_blur > 0.0:
			_draw_polyline_loop(points, Color(_ring_color1.r, _ring_color1.g, _ring_color1.b, _ring_color1.a * 0.18), _ring_width + _ring_blur, true)
		_draw_gradient_polyline(points, _ring_width, true)
		return
	var active_points := _slice_polyline(points, _ring_progress, _ring_start_offset)
	if _ring_blur > 0.0:
		_draw_polyline_loop(active_points, Color(_ring_color1.r, _ring_color1.g, _ring_color1.b, _ring_color1.a * 0.18), _ring_width + _ring_blur, false)
	_draw_gradient_polyline(active_points, _ring_width, false)

func _build_circle_points(center: Vector2, radius: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for step in range(segments):
		var angle: float = -PI * 0.5 + (float(step) / float(segments)) * TAU
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points

func _draw_clock_ticks(center: Vector2, radius: float) -> void:
	for tick in range(12):
		var angle: float = -PI * 0.5 + (float(tick) / 12.0) * TAU
		var outer := center + Vector2(cos(angle), sin(angle)) * (radius - 1.0)
		var inner_length := 5.0 if tick % 3 == 0 else 3.0
		var inner := center + Vector2(cos(angle), sin(angle)) * (radius - inner_length)
		var alpha := 0.42 if tick % 3 == 0 else 0.24
		state_ring.draw_line(inner, outer, Color(1.0, 1.0, 1.0, alpha), 1.0, true)

func _update_clock_label() -> void:
	if not is_instance_valid(state_clock_label):
		return
	var now := Time.get_datetime_dict_from_system()
	var clock_text := "%02d:%02d" % [int(now.get("hour", 0)), int(now.get("minute", 0))]
	if clock_text == _last_clock_text:
		return
	_last_clock_text = clock_text
	state_clock_label.text = clock_text

func _on_state_ring_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		app_observe_requested.emit()
		state_ring.accept_event()

func _is_screen_pos_over_state_ring(screen_pos: Vector2i) -> bool:
	if not is_instance_valid(state_ring) or not state_ring.is_visible_in_tree():
		return false
	var window_pos := Vector2.ZERO
	var window := get_window()
	if window != null:
		window_pos = Vector2(window.position)
	return state_ring.get_global_rect().has_point(Vector2(screen_pos) - window_pos)

func _build_rounded_rect_points(rect: Rect2, radius: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return points
	var corner_radius := minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	var centers := [
		rect.position + Vector2(rect.size.x - corner_radius, corner_radius),
		rect.position + rect.size - Vector2(corner_radius, corner_radius),
		rect.position + Vector2(corner_radius, rect.size.y - corner_radius),
		rect.position + Vector2(corner_radius, corner_radius),
	]
	var starts: Array[float] = [-PI * 0.5, 0.0, PI * 0.5, PI]
	for corner_index in range(4):
		for step in range(segments + 1):
			var angle: float = starts[corner_index] + (float(step) / float(segments)) * PI * 0.5
			points.append(centers[corner_index] + Vector2(cos(angle), sin(angle)) * corner_radius)
	return points

func _slice_polyline(points: PackedVector2Array, progress: float, start_offset: float = 0.0) -> PackedVector2Array:
	var clamped_progress := clampf(progress, 0.0, 1.0)
	if clamped_progress >= 0.985:
		return points
	var result := PackedVector2Array()
	if points.size() < 2 or clamped_progress <= 0.0:
		return result
	var total_length := _polyline_length(points, true)
	var target_length := total_length * clamped_progress
	var start_length := total_length * fposmod(start_offset, 1.0)
	var walked_total := 0.0
	var walked_active := 0.0
	var did_start := false
	for step in range(points.size() * 2):
		var index := step % points.size()
		var from_point := points[index]
		var to_point := points[(index + 1) % points.size()]
		var segment_length := from_point.distance_to(to_point)
		if not did_start:
			if walked_total + segment_length < start_length:
				walked_total += segment_length
				continue
			var start_segment_progress := (start_length - walked_total) / segment_length if segment_length > 0.0 else 0.0
			var start_point := from_point.lerp(to_point, start_segment_progress)
			result.append(start_point)
			from_point = start_point
			segment_length = from_point.distance_to(to_point)
			did_start = true
		if walked_active + segment_length >= target_length:
			var segment_progress := (target_length - walked_active) / segment_length if segment_length > 0.0 else 0.0
			result.append(from_point.lerp(to_point, segment_progress))
			break
		result.append(to_point)
		walked_active += segment_length
	return result

func _get_pet_body_global_rect() -> Rect2:
	if _live2d_bounds_valid:
		return _live2d_bounds_rect
	_refresh_live2d_bounds()
	if _live2d_bounds_valid:
		return _live2d_bounds_rect
	if collision_shape and collision_shape.shape is RectangleShape2D:
		var shape_size: Vector2 = (collision_shape.shape as RectangleShape2D).size * collision_shape.global_scale.abs()
		return Rect2(collision_shape.global_position - shape_size * 0.5, shape_size)
	return Rect2(global_position - Vector2(40, 90) * global_scale.abs(), Vector2(80, 180) * global_scale.abs())

func _refresh_live2d_bounds() -> void:
	_live2d_bounds_valid = false
	if not is_instance_valid(pet_model) or not pet_model.has_method("get_meshes"):
		return
	var meshes: Dictionary = pet_model.call("get_meshes")
	var has_point := false
	var min_point := Vector2.ZERO
	var max_point := Vector2.ZERO
	for mesh_node in meshes.values():
		if mesh_node is MeshInstance2D and mesh_node.mesh != null:
			var mesh: Mesh = mesh_node.mesh
			for surface_index in range(mesh.get_surface_count()):
				var surface_arrays: Array = mesh.surface_get_arrays(surface_index)
				if surface_arrays.size() <= Mesh.ARRAY_VERTEX:
					continue
				var mesh_vertices: PackedVector2Array = surface_arrays[Mesh.ARRAY_VERTEX]
				for vertex in mesh_vertices:
					var point: Vector2 = mesh_node.to_global(vertex)
					if not has_point:
						min_point = point
						max_point = point
						has_point = true
					else:
						min_point = Vector2(minf(min_point.x, point.x), minf(min_point.y, point.y))
						max_point = Vector2(maxf(max_point.x, point.x), maxf(max_point.y, point.y))
	if has_point:
		_live2d_bounds_rect = Rect2(min_point, max_point - min_point).grow(6)
		_live2d_bounds_valid = _live2d_bounds_rect.size.x > 0.0 and _live2d_bounds_rect.size.y > 0.0

func _get_polygon_rect(polygon: PackedVector2Array) -> Rect2:
	if polygon.is_empty():
		return Rect2()
	var min_point := polygon[0]
	var max_point := polygon[0]
	for point in polygon:
		min_point = Vector2(minf(min_point.x, point.x), minf(min_point.y, point.y))
		max_point = Vector2(maxf(max_point.x, point.x), maxf(max_point.y, point.y))
	return Rect2(min_point, max_point - min_point)

func _update_click_control_bounds() -> void:
	if not is_instance_valid(_click_control):
		return
	if not _live2d_bounds_valid:
		return
	var local_rect := Rect2(to_local(_live2d_bounds_rect.position), _live2d_bounds_rect.size)
	if local_rect.size.x > 0.0 and local_rect.size.y > 0.0:
		_click_control.position = local_rect.position
		_click_control.size = local_rect.size

func _polyline_length(points: PackedVector2Array, closed: bool) -> float:
	var total := 0.0
	var segment_count := points.size() if closed else points.size() - 1
	for index in range(segment_count):
		total += points[index].distance_to(points[(index + 1) % points.size()])
	return total

func _draw_polyline_loop(points: PackedVector2Array, color: Color, width: float, closed: bool) -> void:
	if points.size() < 2:
		return
	state_ring.draw_polyline(points, color, width, true)
	if closed:
		state_ring.draw_line(points[points.size() - 1], points[0], color, width, true)

func _draw_gradient_polyline(points: PackedVector2Array, width: float, closed: bool) -> void:
	if points.size() < 2:
		return
	var phase: float = ring_time * _ring_speed
	var segment_count := points.size() if closed else points.size() - 1
	for index in range(segment_count):
		var value: float = fposmod((float(index) / float(maxi(points.size() - 1, 1))) + phase, 1.0)
		var mix_value: float = smoothstep(0.0, 1.0, value * 2.0 if value < 0.5 else (1.0 - value) * 2.0)
		state_ring.draw_line(points[index], points[(index + 1) % points.size()], _ring_color1.lerp(_ring_color2, mix_value), width, true)

func set_pet_state(state: int, progress: float = 0.0) -> void:
	current_state = state
	state_progress = progress

func update_voice_volume(vol: float) -> void:
	ring_volume = lerp(ring_volume, vol, 0.2)
	if is_instance_valid(pet_model):
		pet_model.set("ParamA", clampf(ring_volume, 0.0, 1.0))

func _on_click_control_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if _left_drag_tracking and Vector2(DisplayServer.mouse_get_position()).distance_to(_click_start_pos) >= 10.0:
			_left_drag_started = true
			_move_window_from_screen_pos(DisplayServer.mouse_get_position())
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed and _is_screen_pos_over_state_ring(DisplayServer.mouse_get_position()):
			_left_drag_tracking = false
			_left_drag_started = false
			app_observe_requested.emit()
			return
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			pet_right_clicked.emit()
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_request_collapse_tool_panel()
				_click_start_pos = Vector2(DisplayServer.mouse_get_position())
				_left_drag_tracking = true
				_left_drag_started = false
				_window_drag_offset = DisplayServer.mouse_get_position() - get_window().position
				_update_live2d_pointer_target(event.position, true)
				_update_live2d_hit_area(event.position)
			else:
				var current_pos = Vector2(DisplayServer.mouse_get_position())
				_left_drag_tracking = false
				_update_live2d_pointer_target(event.position, false)
				var dist = current_pos.distance_to(_click_start_pos)
				if not _left_drag_started and dist < 10.0:
					_update_live2d_hit_area(event.position)
					var hit_area := _normalize_hit_area(_current_hit_area)
					pet_area_touched.emit(hit_area)
					pet_clicked.emit()
					play_touch_reaction(hit_area)
				elif _left_drag_started:
					var pet_window := get_window()
					if pet_window and pet_window.has_method("refresh_desktop_pet_passthrough_after_drag"):
						pet_window.call("refresh_desktop_pet_passthrough_after_drag")
				_left_drag_started = false

func _update_live2d_pointer_target(local_event_pos: Vector2, active: bool) -> void:
	if not is_instance_valid(target_point_effect) or not target_point_effect.has_method("set_target") or not is_instance_valid(pet_model):
		return
	if active:
		var calc_pos: Vector2 = pet_model.to_local(_click_control.get_global_transform_with_canvas() * local_event_pos) * Vector2(1, -1)
		target_point_effect.call("set_target", calc_pos.normalized())
	else:
		target_point_effect.call("set_target", Vector2.ZERO)

func _update_live2d_pointer_target_from_global(global_pos: Vector2, active: bool) -> void:
	if not is_instance_valid(target_point_effect) or not target_point_effect.has_method("set_target") or not is_instance_valid(pet_model):
		return
	if active:
		var calc_pos: Vector2 = pet_model.to_local(global_pos) * Vector2(1, -1)
		target_point_effect.call("set_target", calc_pos.normalized())
	else:
		target_point_effect.call("set_target", Vector2.ZERO)

func _update_live2d_hit_area(local_event_pos: Vector2) -> void:
	if not is_instance_valid(hit_area_effect) or not hit_area_effect.has_method("set_target") or not is_instance_valid(pet_model):
		_current_hit_area = "body"
		return
	var model_local_pos: Vector2 = pet_model.to_local(_click_control.get_global_transform_with_canvas() * local_event_pos)
	hit_area_effect.call("set_target", model_local_pos)

func _on_hit_area_entered(_model, id: String) -> void:
	_current_hit_area = str(id)

func _on_hit_area_exited(_model, id: String) -> void:
	if _current_hit_area == str(id):
		_current_hit_area = ""

func _normalize_hit_area(hit_area_id: String) -> String:
	var lowered := hit_area_id.to_lower()
	if lowered.contains("head"):
		return "head"
	if lowered.contains("body"):
		return "body"
	return "body"

func play_touch_reaction(hit_area: String) -> void:
	_play_interact_anim()
	_play_random_expression()
	if hit_area == "head":
		_play_random_motion("Idle", false)
	elif not _play_random_motion("TapBody", false):
		_play_random_motion("Idle", true)

func play_mood_expression(expression_key: String) -> void:
	if not is_instance_valid(pet_model) or not pet_model.has_method("start_expression"):
		return
	if _expressions.is_empty():
		_refresh_live2d_animation_catalog()
	if _expressions.is_empty():
		return
	var direct_key := expression_key.strip_edges()
	if direct_key in _expressions:
		pet_model.call("start_expression", direct_key)
		return
	var index: int = int(abs(hash(direct_key)) % _expressions.size())
	pet_model.call("start_expression", str(_expressions[index]))

func _request_collapse_tool_panel() -> void:
	var pet_window := get_window()
	if pet_window and pet_window.has_method("_collapse_tool_panel_for_pet_interaction"):
		pet_window.call("_collapse_tool_panel_for_pet_interaction")

func _move_window_from_screen_pos(screen_pos: Vector2i) -> void:
	var pet_window := get_window()
	if pet_window == null:
		return
	var new_pos := screen_pos - _window_drag_offset
	pet_window.position = new_pos

func _play_interact_anim() -> void:
	if not pet_model: return
		
	var base_scale := _base_model_scale
	var scale_1 := Vector2(base_scale.x * 1.1, base_scale.y * 0.9)
	var scale_2 := Vector2(base_scale.x * 0.96, base_scale.y * 1.04)
	
	var tween = create_tween()
	tween.tween_property(pet_model, "scale", scale_1, 0.1).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(pet_model, "scale", scale_2, 0.15).set_trans(Tween.TRANS_BOUNCE)
	tween.tween_property(pet_model, "scale", base_scale, 0.1).set_trans(Tween.TRANS_QUAD)

func clear_bubbles() -> void:
	for child in bubble_container.get_children():
		if child != bubble_template:
			child.queue_free()
	bubbles_changed.emit()

func add_bubble(text: String, is_typewriter: bool = false) -> void:
	var bubble = bubble_template.duplicate()
	bubble.visible = true
	bubble_container.add_child(bubble)
	
	var label: RichTextLabel = bubble.get_node("MarginContainer/RichTextLabel")
	label.text = text
	
	# 彻底解决导出后气泡不换行、不撑开高度的终极方案：
	# 1. 强制赋予绝对宽度，让底层 TextServer 有换行的物理依据
	label.custom_minimum_size.x = 250
	label.size.x = 250
	
	# 2. 使用智能换行，避免括号描述和正文在任意字符位置被硬切开
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.fit_content = false
	label.fit_content = true
	
	# 3. 给予极小延迟，等待底层字体排版完成后，连续强制赋高度
	var check_timer = get_tree().create_timer(0.01)
	check_timer.timeout.connect(func():
		if is_instance_valid(label) and is_instance_valid(bubble):
			label.size.x = 250
			var content_h = label.get_content_height()
			if content_h > 0:
				label.custom_minimum_size.y = content_h
				bubble.size = Vector2.ZERO # 强制父级 PanelContainer 贴合收缩
				
				# 再次延迟一帧进行最终画面确认
				get_tree().process_frame.connect(func():
					if is_instance_valid(label) and is_instance_valid(bubble):
						label.custom_minimum_size.y = label.get_content_height()
						bubble.size = Vector2.ZERO
				, CONNECT_ONE_SHOT)
	)
	
	if is_typewriter:
		label.visible_ratio = 0.0
		var plain_text = text.replace("[color=green]", "").replace("[/color]", "")
		var parsed_len = plain_text.length()
		var duration = parsed_len * 0.05
		if duration <= 0: duration = 0.5
		var tween = create_tween()
		tween.tween_property(label, "visible_ratio", 1.0, duration)
	
	var bubbles = bubble_container.get_children()
	if bubbles.size() > 4: # 包括隐藏的template
		bubbles[1].queue_free()
		
	bubbles_changed.emit()
	
	var timer = get_tree().create_timer(10.0)
	var bubble_ref = weakref(bubble)
	timer.timeout.connect(func():
		var b = bubble_ref.get_ref()
		if b and is_instance_valid(b):
			var fade_tween = create_tween()
			fade_tween.tween_property(b, "modulate:a", 0.0, 0.5)
			fade_tween.finished.connect(func(): 
				if is_instance_valid(b): 
					b.queue_free()
					bubbles_changed.emit()
			)
	)

func get_passthrough_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	
	if pet_model and pet_model.is_visible_in_tree():
		rects.append(_get_pet_body_global_rect())
	if state_ring and state_ring.is_visible_in_tree():
		rects.append(state_ring.get_global_rect().grow(5))
		
	# 获取实际显示的对话气泡的区域
	if bubble_container and bubble_container.is_visible_in_tree():
		for child in bubble_container.get_children():
			if child is Control and child.visible and child.modulate.a > 0.01:
				# 仅将当前真正显示的气泡加入鼠标遮挡区域
				rects.append(child.get_global_rect().grow(5))
			
	return rects

func get_body_global_rect() -> Rect2:
	if pet_model and pet_model.is_visible_in_tree():
		return _get_pet_body_global_rect().grow(5)
	return Rect2(global_position - Vector2(40, 90), Vector2(80, 180))
