extends Control

signal course_completed(index: int)
signal all_courses_completed
signal schedule_finished

@export var slot_scene: PackedScene

const ScheduleEventPanelScene = preload("res://scenes/ui/activity/schedule_event_panel.tscn")

@onready var top_image_rect: TextureRect = $MainPanel/TopImageRect
@onready var title_label: Label = $MainPanel/TopImageRect/TitleContainer/TitleLabel
@onready var desc_label: Label = $MainPanel/DescLabel
@onready var bonus_hbox: HBoxContainer = $MainPanel/BonusHBox
@onready var track_container: HBoxContainer = $MainPanel/TrackContainer
@onready var character_icon: Node2D = $MainPanel/TrackContainer/CharacterIcon
@onready var click_area: Button = $ClickArea

@onready var result_popup: Control = $ResultPopup
@onready var stats_vbox: VBoxContainer = $ResultPopup/ResultPanel/Margin/VBox/StatsVBox
@onready var end_button: Button = $ResultPopup/ResultPanel/Margin/VBox/EndButton

var _courses_data: Array
var _start_attrs: Dictionary
var _end_attrs: Dictionary

var _current_slot_index: int = 0
var _is_moving: bool = false
var _slots: Array = []

var _current_event_panel: Node = null
var _current_event_desc: String = ""
var _current_event_options: Array = []

func _ready() -> void:
	click_area.pressed.connect(_on_click_area_pressed)
	end_button.pressed.connect(_on_end_button_pressed)
	
	# 初始状态
	result_popup.hide()
	end_button.hide()

func setup(courses_data: Array, start_attrs: Dictionary, end_attrs: Dictionary) -> void:
	_courses_data = courses_data
	_start_attrs = start_attrs
	_end_attrs = end_attrs
	
	_init_slots()
	
	# 初始展示第 1 个课程的内容
	_update_course_info(0)
	
	# 5. 角色小人初始位置
	# 等待所有容器重排完成，确保 global_position 计算正确
	await get_tree().process_frame
	await get_tree().process_frame
	_reset_character_position()

func _update_course_info(index: int) -> void:
	if index < 0 or index >= _courses_data.size(): return
	
	var current_course = _courses_data[index]
	
	# 1. 顶部配图
	if current_course.has("image_path") and not current_course["image_path"].is_empty():
		var img_path = current_course["image_path"]
		var bg_path = ImageManager.get_image_path(img_path)
		if bg_path != "":
			img_path = bg_path
		if ResourceLoader.exists(img_path):
			top_image_rect.texture = load(img_path)
		else:
			top_image_rect.texture = null
	else:
		top_image_rect.texture = null
		
	# 2. 标题与描述
	var c_name = current_course.get("name", "未知课程")
	title_label.text = tr(c_name)
	
	desc_label.text = current_course.get("desc", "缺少课程描述...")
	
	# 3. 属性加成展示
	update_bonus(current_course.get("bonus_list", []))

func update_bonus(bonus_list: Array) -> void:
	for child in bonus_hbox.get_children():
		child.queue_free()
		
	for bonus in bonus_list:
		var hbox = HBoxContainer.new()
		
		if bonus.has("icon"):
			var icon = TextureRect.new()
			icon.texture = load(bonus["icon"])
			icon.custom_minimum_size = Vector2(24, 24)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			hbox.add_child(icon)
			
		var name_lbl = Label.new()
		name_lbl.text = tr(bonus.get("name", ""))
		name_lbl.add_theme_color_override("font_color", Color(0.4, 0.3, 0.2))
		hbox.add_child(name_lbl)
		
		var val_lbl = Label.new()
		val_lbl.text = "+" + str(bonus.get("value", 0))
		val_lbl.add_theme_color_override("font_color", Color(0.2, 0.6, 0.2))
		hbox.add_child(val_lbl)
		
		bonus_hbox.add_child(hbox)

func _init_slots() -> void:
	for child in track_container.get_children():
		if child != character_icon:
			child.queue_free()
	_slots.clear()
	
	for i in range(10):
		var slot = slot_scene.instantiate()
		track_container.add_child(slot)
		# 让所有槽位都在小人节点之前
		track_container.move_child(slot, i)
		slot.setup(str(i + 1))
		slot.set_completed(false)
		_slots.append(slot)
	
	_current_slot_index = 0
	_slots[0].set_completed(false)
	
	# 重置小人的显示状态（修复“两个我”的问题）
	character_icon.show()
	character_icon.modulate.a = 1.0

func _reset_character_position() -> void:
	if _slots.is_empty(): return
	var current_slot = _slots[_current_slot_index]
	# 需要在 yield 之后调用，确保 global_position 计算准确
	var char_size = Vector2(50, 50)
	if character_icon is AnimatedSprite2D:
		char_size = Vector2(0, 0) # AnimatedSprite2D 的中心通常在坐标原点
	character_icon.global_position = current_slot.global_position + (current_slot.size - char_size) / 2.0
	
func _on_click_area_pressed() -> void:
	if _is_moving:
		return
		
	if _current_slot_index >= 9:
		_show_result_popup()
		return
		
	_is_moving = true
	
	# 立即标记当前所在槽位为完成
	set_slot_status(_current_slot_index, true)
	course_completed.emit(_current_slot_index)
	
	var next_index = _current_slot_index + 1
	var target_slot = _slots[next_index]
	var char_size = Vector2(50, 50)
	if character_icon is AnimatedSprite2D:
		char_size = Vector2(0, 0)
	var target_pos = target_slot.global_position + (target_slot.size - char_size) / 2.0
	
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(character_icon, "global_position", target_pos, 0.35)
	
	tween.finished.connect(func():
		_current_slot_index = next_index
		
		var current_course = _courses_data[_current_slot_index]
		if current_course.get("is_event", false):
			_trigger_story_script(current_course)
		elif randf() < 0.2:
			_trigger_schedule_event()
		else:
			_finish_slot_move()
	)

func _finish_slot_move(skip_ui_update: bool = false) -> void:
	_is_moving = false
	
	# 走到下一个槽位时，立刻刷新顶部的当前课程图文信息
	if not skip_ui_update:
		_update_course_info(_current_slot_index)
	
	# 每完成2个课程，时间推进一天 (2, 4, 6, 8)
	if _current_slot_index % 2 == 0 and _current_slot_index < 10:
		if GameDataManager.story_time_manager:
			GameDataManager.story_time_manager.advance_day(1)
		
	if _current_slot_index == 9:
		# 走到最后一个槽位时，立刻将最后一个也标为完成
		set_slot_status(_current_slot_index, true)
		course_completed.emit(_current_slot_index)
		all_courses_completed.emit()
		# 第10个课程完成，推进最后一天
		if GameDataManager.story_time_manager:
			GameDataManager.story_time_manager.advance_day(1)
		_show_result_popup()

func _get_deepseek_client() -> Node:
	if get_tree().current_scene and get_tree().current_scene.has_node("DeepSeekClient"):
		return get_tree().current_scene.get_node("DeepSeekClient")
	if get_node_or_null("/root/DeepSeekClient"):
		return get_node("/root/DeepSeekClient")
	if get_tree().root.has_node("MainScene/DeepSeekClient"):
		return get_node("/root/MainScene/DeepSeekClient")
	return null

func _trigger_story_script(course_data: Dictionary) -> void:
	var script_path = course_data.get("script_path", "")
	if script_path == "" or not FileAccess.file_exists(script_path):
		_finish_slot_move()
		return
		
	# 实例化故事场景作为子节点
	# 黑屏过渡
	var transition_overlay = ColorRect.new()
	transition_overlay.color = Color.BLACK
	transition_overlay.modulate.a = 0.0
	transition_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	transition_overlay.z_index = 100
	add_child(transition_overlay)
	
	var tween = create_tween()
	tween.tween_property(transition_overlay, "modulate:a", 1.0, 0.5)
	await tween.finished
	
	var story_scene = load("res://scenes/ui/story/story_scene.tscn").instantiate()
	GameDataManager.set_meta("play_specific_story", script_path)
	add_child(story_scene)
	story_scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	story_scene.z_index = 50
	
	# 因为 story_scene 刚被 add_child，它可能会在 transition_overlay 之上
	# 确保 transition_overlay 在最上层
	move_child(transition_overlay, -1)
	
	# 【修复时序问题】：等待场景内部的 _ready 执行完毕，并让引擎完成第一帧渲染
	# 稍微加一点点延迟，确保剧情的背景和立绘都已经挂载完毕再淡出黑屏
	await get_tree().create_timer(0.5).timeout
	await get_tree().process_frame
	
	# 淡出黑屏
	var tween2 = create_tween()
	tween2.tween_property(transition_overlay, "modulate:a", 0.0, 0.5)
	await tween2.finished
	transition_overlay.queue_free()
	
	# 等待故事结束
	await story_scene.chat_closed
	
	# 故事结束后，恢复黑屏过渡效果
	var out_overlay = ColorRect.new()
	out_overlay.color = Color.BLACK
	out_overlay.modulate.a = 0.0
	out_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	out_overlay.z_index = 100
	add_child(out_overlay)
	
	var tween3 = create_tween()
	tween3.tween_property(out_overlay, "modulate:a", 1.0, 0.5)
	await tween3.finished
	
	# 在黑屏完全遮挡住的时候，销毁故事场景，这样就不会有弹出关闭的突兀感
	if is_instance_valid(story_scene):
		story_scene.queue_free()
		
	# 【修复延迟问题】：在黑屏结束前，提前让底层的逻辑往下走，更新下一个日程界面的 UI 元素
	# 这里只调用纯 UI 的更新逻辑（如果是执行下一次移动），但是我们不直接触发动画，
	# 让底下的课程封面图、标题先变过去，并在黑屏中完成加载
	_update_course_info(_current_slot_index)
		
	# 确保在黑屏期间，底下的日常界面（如新的课程封面图等）能完成加载并渲染出一帧
	await get_tree().create_timer(0.3).timeout
	await get_tree().process_frame
	await get_tree().process_frame
	
	# 然后再把黑屏淡出，展示底下的日常界面
	var tween4 = create_tween()
	tween4.tween_property(out_overlay, "modulate:a", 0.0, 0.5)
	await tween4.finished
	out_overlay.queue_free()
	
	# 由于前面已经提前更新了 UI，这里我们跳过 _update_course_info() 的二次调用，
	# 直接执行属性结算等后续动作
	_finish_slot_move(true)

func _trigger_schedule_event() -> void:
	var client = _get_deepseek_client()
	if not client:
		_finish_slot_move()
		return
		
	var course_data = _courses_data[_current_slot_index]
	var course_name = course_data.get("name", "未知课程")
	var course_desc = course_data.get("desc", "")
	
	var loading_label = Label.new()
	loading_label.text = "突发事件生成中..."
	loading_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	loading_label.add_theme_font_size_override("font_size", 32)
	loading_label.add_theme_color_override("font_color", Color(1, 1, 1))
	loading_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	loading_label.add_theme_constant_override("outline_size", 4)
	loading_label.name = "EventLoadingLabel"
	add_child(loading_label)
	
	if not client.is_connected("schedule_event_generated", _on_schedule_event_generated):
		client.schedule_event_generated.connect(_on_schedule_event_generated)
	if not client.is_connected("schedule_event_error", _on_schedule_event_error):
		client.schedule_event_error.connect(_on_schedule_event_error)
		
	client.generate_schedule_event(course_name, course_desc)

func _on_schedule_event_generated(event_data: Dictionary) -> void:
	var loading = get_node_or_null("EventLoadingLabel")
	if loading:
		loading.queue_free()
		
	var client = _get_deepseek_client()
	if client:
		if client.is_connected("schedule_event_generated", _on_schedule_event_generated):
			client.schedule_event_generated.disconnect(_on_schedule_event_generated)
		if client.is_connected("schedule_event_error", _on_schedule_event_error):
			client.schedule_event_error.disconnect(_on_schedule_event_error)
			
	_current_event_panel = ScheduleEventPanelScene.instantiate()
	add_child(_current_event_panel)
	
	_current_event_desc = event_data.get("event_desc", "发生了一个随机事件。")
	var options = event_data.get("options", [])
	_current_event_options.clear()
	
	var opt1 = "选项 1"
	var opt2 = "选项 2"
	if options.size() > 0:
		opt1 = options[0].get("text", "选项 1")
		_current_event_options.append(opt1)
	if options.size() > 1:
		opt2 = options[1].get("text", "选项 2")
		_current_event_options.append(opt2)
		
	_current_event_panel.setup(_current_event_desc, opt1, opt2)
	_current_event_panel.option_selected.connect(_on_event_option_selected)

func _on_schedule_event_error(_error_msg: String) -> void:
	var loading = get_node_or_null("EventLoadingLabel")
	if loading:
		loading.queue_free()
		
	var client = _get_deepseek_client()
	if client:
		if client.is_connected("schedule_event_generated", _on_schedule_event_generated):
			client.schedule_event_generated.disconnect(_on_schedule_event_generated)
		if client.is_connected("schedule_event_error", _on_schedule_event_error):
			client.schedule_event_error.disconnect(_on_schedule_event_error)
			
	_finish_slot_move()

func _on_event_option_selected(idx: int) -> void:
	if _current_event_panel:
		_current_event_panel.hide()
		
	var loading_label = Label.new()
	loading_label.text = "事件结算中..."
	loading_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	loading_label.add_theme_font_size_override("font_size", 32)
	loading_label.add_theme_color_override("font_color", Color(1, 1, 1))
	loading_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	loading_label.add_theme_constant_override("outline_size", 4)
	loading_label.name = "EventResolvingLabel"
	add_child(loading_label)
	
	var client = _get_deepseek_client()
	var course_data = _courses_data[_current_slot_index]
	var course_name = course_data.get("name", "未知课程")
	
	var chosen_option = "未知选项"
	if idx >= 0 and idx < _current_event_options.size():
		chosen_option = _current_event_options[idx]
		
	if not client.is_connected("schedule_event_resolved", _on_schedule_event_resolved):
		client.schedule_event_resolved.connect(_on_schedule_event_resolved)
	if not client.is_connected("schedule_event_resolve_error", _on_schedule_event_resolve_error):
		client.schedule_event_resolve_error.connect(_on_schedule_event_resolve_error)
		
	client.resolve_schedule_event(course_name, _current_event_desc, chosen_option)

func _cleanup_resolve_state() -> void:
	var loading = get_node_or_null("EventResolvingLabel")
	if loading:
		loading.queue_free()
		
	if _current_event_panel:
		_current_event_panel.queue_free()
		_current_event_panel = null
		
	var client = _get_deepseek_client()
	if client:
		if client.is_connected("schedule_event_resolved", _on_schedule_event_resolved):
			client.schedule_event_resolved.disconnect(_on_schedule_event_resolved)
		if client.is_connected("schedule_event_resolve_error", _on_schedule_event_resolve_error):
			client.schedule_event_resolve_error.disconnect(_on_schedule_event_resolve_error)

func _on_schedule_event_resolved(result_data: Dictionary) -> void:
	_cleanup_resolve_state()
	
	var changes = result_data.get("stat_changes", {})
	for attr in changes.keys():
		var val = changes[attr]
		if _end_attrs.has(attr):
			_end_attrs[attr] += val
		else:
			_end_attrs[attr] = _start_attrs.get(attr, 0) + val
			
	_show_event_result_toast(result_data.get("result_desc", "事件已解决。"))

func _on_schedule_event_resolve_error(_error_msg: String) -> void:
	_cleanup_resolve_state()
	_finish_slot_move()

func _show_event_result_toast(msg: String) -> void:
	var toast = Label.new()
	toast.text = msg
	toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	toast.add_theme_font_size_override("font_size", 24)
	toast.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2))
	toast.add_theme_color_override("font_outline_color", Color(1, 1, 1))
	toast.add_theme_constant_override("outline_size", 4)
	add_child(toast)
	
	var t = create_tween().set_parallel(true)
	t.tween_property(toast, "position:y", toast.position.y - 50, 2.0)
	t.tween_property(toast, "modulate:a", 0.0, 2.0)
	t.chain().tween_callback(func():
		toast.queue_free()
		_finish_slot_move()
	)

func set_slot_status(index: int, completed: bool) -> void:
	if index >= 0 and index < _slots.size():
		_slots[index].set_completed(completed)

func _show_result_popup() -> void:
	result_popup.modulate.a = 0
	result_popup.show()
	click_area.hide()
	
	var tween = create_tween()
	tween.tween_property(result_popup, "modulate:a", 1.0, 0.3)
	
	for child in stats_vbox.get_children():
		child.queue_free()
		
	for attr in _start_attrs.keys():
		var old_val = _start_attrs[attr]
		var new_val = _end_attrs.get(attr, old_val)
		if new_val == old_val: continue
		
		var hbox = HBoxContainer.new()
		var name_lbl = Label.new()
		name_lbl.text = tr(attr)
		name_lbl.custom_minimum_size = Vector2(80, 0)
		name_lbl.add_theme_color_override("font_color", Color(0.4, 0.3, 0.2))
		hbox.add_child(name_lbl)
		
		var val_lbl = Label.new()
		val_lbl.text = str(old_val)
		val_lbl.add_theme_color_override("font_color", Color(0.2, 0.6, 0.2))
		hbox.add_child(val_lbl)
		
		var pb = ProgressBar.new()
		pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pb.custom_minimum_size = Vector2(0, 20)
		pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pb.max_value = max(100, new_val * 1.5)
		pb.value = old_val
		hbox.add_child(pb)
		
		stats_vbox.add_child(hbox)
		
		# 动态增长动画
		var diff = int(new_val - old_val)
		var val_tween = create_tween().set_trans(Tween.TRANS_LINEAR)
		val_tween.tween_method(func(v: float):
			if diff >= 0:
				val_lbl.text = "%d (+%d)" % [int(v), diff]
			else:
				val_lbl.text = "%d (%d)" % [int(v), diff]
			pb.value = v
		, float(old_val), float(new_val), 1.2)
		
	await get_tree().create_timer(1.2).timeout
	end_button.show()

func _on_end_button_pressed() -> void:
	var profile = GameDataManager.profile
	
	# Save course progress
	for course in _courses_data:
		var c_id = course.get("id", "")
		if c_id != "":
			var max_prog = course.get("max_progress", 0)
			if max_prog > 0:
				var increment = course.get("progress_increment", 0)
				var cur_prog = profile.course_progress.get(c_id, 0)
				profile.course_progress[c_id] = min(cur_prog + increment, max_prog)
	
	# Save attrs back to profile
	profile.stat_stamina = _end_attrs.get("体能续航", profile.stat_stamina)
	profile.stat_body_management = _end_attrs.get("形体管控", profile.stat_body_management)
	profile.stat_focus = _end_attrs.get("凝心专注", profile.stat_focus)
	profile.stat_rhythm = _end_attrs.get("律动反应", profile.stat_rhythm)
	profile.stat_artistic_literacy = _end_attrs.get("艺术素养", profile.stat_artistic_literacy)
	profile.stat_verbal_expression = _end_attrs.get("言辞表达", profile.stat_verbal_expression)
	profile.stat_planning = _end_attrs.get("统筹企划", profile.stat_planning)
	profile.stat_art_theory = _end_attrs.get("艺理钻研", profile.stat_art_theory)
	profile.stat_temperament = _end_attrs.get("格调气质", profile.stat_temperament)
	profile.stat_manner = _end_attrs.get("举止仪范", profile.stat_manner)
	profile.stat_emotional_infection = _end_attrs.get("共情感染", profile.stat_emotional_infection)
	profile.stat_stage_performance = _end_attrs.get("舞台表现", profile.stat_stage_performance)
	profile.stat_empathy = _end_attrs.get("情思体悟", profile.stat_empathy)
	profile.stat_inspiration = _end_attrs.get("创想灵感", profile.stat_inspiration)
	profile.stat_aesthetics = _end_attrs.get("美学品鉴", profile.stat_aesthetics)
	profile.stat_art_perception = _end_attrs.get("艺术感知", profile.stat_art_perception)
	profile.current_energy = clamp(_end_attrs.get("精力", profile.current_energy), 0, profile.max_energy)
	profile.gold = max(0, _end_attrs.get("金币", profile.gold))
	profile.stress = clamp(_end_attrs.get("压力", profile.stress), 0, profile.max_stress)
	profile.mood_value = clamp(_end_attrs.get("心情", profile.mood_value), 0, 100)
	
	profile.save_profile()
	
	var tween = create_tween()
	tween.tween_property(result_popup, "modulate:a", 0.0, 0.3)
	tween.finished.connect(func():
		schedule_finished.emit()
		queue_free()
	)

func _on_close_pressed() -> void:
	queue_free()
