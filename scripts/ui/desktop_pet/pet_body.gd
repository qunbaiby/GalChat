extends CharacterBody2D

signal pet_clicked()
signal pet_right_clicked()
signal bubbles_changed()

@onready var state_ring: Control = $MoodBubble/MoodRing
@onready var pet_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var mood_bubble: PanelContainer = $MoodBubble
@onready var mood_emoji_label: Label = $MoodBubble/MarginContainer/MoodHBox/MoodEmojiLabel
@onready var mood_name_label: Label = $MoodBubble/MarginContainer/MoodHBox/MoodNameLabel
@onready var bubble_container: VBoxContainer = $BubbleContainer
@onready var bubble_template: PanelContainer = $BubbleContainer/SpeechBubble
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var _click_start_pos: Vector2 = Vector2.ZERO
var _left_drag_tracking: bool = false
var _window_drag_offset: Vector2i = Vector2i.ZERO

# 状态环变量
var current_state: int = 0 # 0: Idle, 1: Thinking, 2: Speaking, 3: AfkCountdown, 4: ProactiveCooldown
var state_progress: float = 0.0
var ring_time: float = 0.0
var ring_volume: float = 0.0

var _breath_tween: Tween
var _current_modulate: Color = Color.WHITE
var _bound_profile = null
var _last_mood_display_key: String = ""
var _base_sprite_scale: Vector2 = Vector2.ONE
var _ring_color1: Color = Color(0.4, 0.75, 1.0, 0.8)
var _ring_color2: Color = Color(0.7, 0.95, 1.0, 0.8)
var _ring_progress: float = 1.0
var _ring_width: float = 0.75
var _ring_blur: float = 0.8
var _ring_speed: float = 0.4
var _ring_start_offset: float = 0.0

func _ready() -> void:
	bubble_template.hide()
	_refresh_mood_bubble()
	
	state_ring.draw.connect(_on_ring_draw)
	if pet_sprite:
		_base_sprite_scale = pet_sprite.scale
	
	# 动态创建一个 Control 用于可靠的点击检测
	var click_control = Control.new()
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
	
	if pet_sprite:
		_update_sprite_scale()
		
		# 尝试加载当前角色的桌宠立绘序列帧
		if GameDataManager.profile:
			var anim_path = GameDataManager.profile.desktop_pet_frames_path
			if anim_path == "" or not ResourceLoader.exists(anim_path):
				# 如果没有专门配置桌宠动画，则降级使用主立绘动画
				anim_path = GameDataManager.profile.sprite_frames_path
				
			if anim_path != "" and ResourceLoader.exists(anim_path):
				pet_sprite.sprite_frames = load(anim_path)
				pet_sprite.play("default")

func _update_sprite_scale() -> void:
	if not pet_sprite: return
	
	if _breath_tween:
		_breath_tween.kill()
		
	var base_scale := _base_sprite_scale
	pet_sprite.scale = base_scale
	
	var scale_max := Vector2(base_scale.x * 1.015, base_scale.y * 0.985)
	var scale_min := Vector2(base_scale.x * 0.985, base_scale.y * 1.015)
	
	_breath_tween = create_tween().set_loops()
	_breath_tween.tween_property(pet_sprite, "scale", scale_max, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_breath_tween.tween_property(pet_sprite, "scale", scale_min, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _update_time_based_lighting() -> void:
	if not pet_sprite: return
	
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
	pet_sprite.modulate = _current_modulate
	if is_instance_valid(state_ring):
		state_ring.modulate = _current_modulate

func _process(delta: float) -> void:
	_ensure_profile_binding()
	_ensure_mood_bubble_visible()
	_update_time_based_lighting()
	
	ring_time += delta
	if is_instance_valid(state_ring):
		_update_ring_style()
		state_ring.queue_redraw()

func _ensure_profile_binding() -> void:
	var next_profile = GameDataManager.profile if GameDataManager else null
	if _bound_profile == next_profile:
		return
	if _bound_profile != null and _bound_profile.has_signal("profile_updated") and _bound_profile.profile_updated.is_connected(_on_profile_updated):
		_bound_profile.profile_updated.disconnect(_on_profile_updated)
	_bound_profile = next_profile
	if _bound_profile != null and _bound_profile.has_signal("profile_updated") and not _bound_profile.profile_updated.is_connected(_on_profile_updated):
		_bound_profile.profile_updated.connect(_on_profile_updated)
	_refresh_mood_bubble()

func _on_profile_updated() -> void:
	_refresh_mood_bubble()

func _refresh_mood_bubble() -> void:
	if not is_instance_valid(mood_bubble) or not is_instance_valid(mood_emoji_label) or not is_instance_valid(mood_name_label):
		return
	var mood_name: String = "平静"
	var mood_emoji: String = "🙂"
	if GameDataManager and GameDataManager.profile and GameDataManager.mood_system:
		var mood_info: Dictionary = GameDataManager.mood_system.get_macro_mood(GameDataManager.profile.mood_value)
		mood_name = str(mood_info.get("name", "平静")).strip_edges()
		mood_emoji = str(mood_info.get("emoji", "🙂")).strip_edges()
	if mood_name == "":
		mood_name = "平静"
	if mood_emoji == "":
		mood_emoji = "🙂"
	var display_key: String = "%s|%s" % [mood_emoji, mood_name]
	if display_key == _last_mood_display_key and mood_bubble.visible:
		return
	_last_mood_display_key = display_key
	mood_emoji_label.text = mood_emoji
	mood_name_label.text = mood_name
	_ensure_mood_bubble_visible()

func _ensure_mood_bubble_visible() -> void:
	if not is_instance_valid(mood_bubble):
		return
	if not mood_bubble.visible:
		mood_bubble.show()
	if mood_bubble.modulate.a < 1.0:
		mood_bubble.modulate = Color(mood_bubble.modulate.r, mood_bubble.modulate.g, mood_bubble.modulate.b, 1.0)

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
	var points := _build_rounded_rect_points(Rect2(Vector2.ZERO, state_ring.size).grow(-0.75), 11.0, 8)
	if points.size() < 2:
		return
	_draw_polyline_loop(points, Color(0.2, 0.2, 0.25, 0.22), _ring_width, true)
	if _ring_progress >= 0.985:
		if _ring_blur > 0.0:
			_draw_polyline_loop(points, Color(_ring_color1.r, _ring_color1.g, _ring_color1.b, _ring_color1.a * 0.18), _ring_width + _ring_blur, true)
		_draw_gradient_polyline(points, _ring_width, true)
		return
	var active_points := _slice_polyline(points, _ring_progress, _ring_start_offset)
	if _ring_blur > 0.0:
		_draw_polyline_loop(active_points, Color(_ring_color1.r, _ring_color1.g, _ring_color1.b, _ring_color1.a * 0.18), _ring_width + _ring_blur, false)
	_draw_gradient_polyline(active_points, _ring_width, false)

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

func _get_pet_body_shape_global_rect() -> Rect2:
	if collision_shape and collision_shape.shape is RectangleShape2D:
		var shape_size: Vector2 = (collision_shape.shape as RectangleShape2D).size * collision_shape.global_scale.abs()
		return Rect2(collision_shape.global_position - shape_size * 0.5, shape_size)
	return Rect2(global_position - Vector2(40, 90) * global_scale.abs(), Vector2(80, 180) * global_scale.abs())

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

func _on_click_control_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if _left_drag_tracking:
			_move_window_from_screen_pos(DisplayServer.mouse_get_position())
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			pet_right_clicked.emit()
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_request_collapse_tool_panel()
				_click_start_pos = Vector2(DisplayServer.mouse_get_position())
				_left_drag_tracking = true
				_window_drag_offset = DisplayServer.mouse_get_position() - get_window().position
			else:
				var current_pos = Vector2(DisplayServer.mouse_get_position())
				_left_drag_tracking = false
				var dist = current_pos.distance_to(_click_start_pos)
				if dist < 10.0:
					pet_clicked.emit()
					_play_interact_anim()

func _request_collapse_tool_panel() -> void:
	var pet_window := get_window()
	if pet_window and pet_window.has_method("_collapse_tool_panel_for_pet_interaction"):
		pet_window.call("_collapse_tool_panel_for_pet_interaction")

func _move_window_from_screen_pos(screen_pos: Vector2i) -> void:
	var pet_window := get_window()
	if pet_window == null:
		return
	var new_pos := screen_pos - _window_drag_offset
	var screen_idx = DisplayServer.get_screen_from_rect(Rect2i(screen_pos, Vector2i.ONE))
	var screen_rect = DisplayServer.screen_get_usable_rect(screen_idx)
	if pet_window.has_method("_clamp_window_position_to_pet_body"):
		pet_window.position = pet_window.call("_clamp_window_position_to_pet_body", new_pos, screen_rect)
	else:
		pet_window.position = new_pos

func _play_interact_anim() -> void:
	if not pet_sprite: return
	
	if _breath_tween:
		_breath_tween.kill()
		
	var base_scale := _base_sprite_scale
	var scale_1 := Vector2(base_scale.x * 1.1, base_scale.y * 0.9)
	var scale_2 := Vector2(base_scale.x * 0.96, base_scale.y * 1.04)
	
	var tween = create_tween()
	tween.tween_property(pet_sprite, "scale", scale_1, 0.1).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(pet_sprite, "scale", scale_2, 0.15).set_trans(Tween.TRANS_BOUNCE)
	tween.tween_property(pet_sprite, "scale", base_scale, 0.1).set_trans(Tween.TRANS_QUAD)
	tween.finished.connect(_update_sprite_scale)

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
	
	if pet_sprite and pet_sprite.is_visible_in_tree():
		rects.append(_get_pet_body_shape_global_rect().grow(5))
	if state_ring and state_ring.is_visible_in_tree():
		rects.append(state_ring.get_global_rect().grow(5))
	if mood_bubble and mood_bubble.is_visible_in_tree() and mood_bubble.modulate.a > 0.01:
		rects.append(mood_bubble.get_global_rect().grow(5))
		
	# 获取实际显示的对话气泡的区域
	if bubble_container and bubble_container.is_visible_in_tree():
		for child in bubble_container.get_children():
			if child is Control and child.visible and child.modulate.a > 0.01:
				# 仅将当前真正显示的气泡加入鼠标遮挡区域
				rects.append(child.get_global_rect().grow(5))
			
	return rects

func get_body_global_rect() -> Rect2:
	var body_rect := Rect2()
	var has_rect := false
	
	if pet_sprite and pet_sprite.is_visible_in_tree():
		body_rect = _get_pet_body_shape_global_rect().grow(5)
		has_rect = true
	
	if state_ring and state_ring.is_visible_in_tree():
		var ring_rect := state_ring.get_global_rect().grow(5)
		body_rect = body_rect.merge(ring_rect) if has_rect else ring_rect
		has_rect = true
	
	if mood_bubble and mood_bubble.is_visible_in_tree() and mood_bubble.modulate.a > 0.01:
		var mood_rect := mood_bubble.get_global_rect().grow(5)
		body_rect = body_rect.merge(mood_rect) if has_rect else mood_rect
		has_rect = true
	
	if has_rect:
		return body_rect
	return Rect2(global_position - Vector2(40, 90), Vector2(80, 180))
