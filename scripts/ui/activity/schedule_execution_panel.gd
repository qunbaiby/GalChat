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
@onready var stats_vbox: GridContainer = $ResultPopup/VBox/Content/Margin/VBox/StatsVBox
@onready var close_button: Button = $ResultPopup/CloseButton

# Core stat UI nodes
@onready var core_phys_old: Label = $ResultPopup/VBox/Content/Margin/VBox/CoreStatsGrid/CorePhysical/Margin/HBox/OldVal
@onready var core_phys_new: Label = $ResultPopup/VBox/Content/Margin/VBox/CoreStatsGrid/CorePhysical/Margin/HBox/NewVal
@onready var core_phys_grade: Label = $ResultPopup/VBox/Content/Margin/VBox/CoreStatsGrid/CorePhysical/Margin/HBox/GradePanel/Margin/GradeLabel

@onready var core_int_old: Label = $ResultPopup/VBox/Content/Margin/VBox/CoreStatsGrid/CoreIntelligence/Margin/HBox/OldVal
@onready var core_int_new: Label = $ResultPopup/VBox/Content/Margin/VBox/CoreStatsGrid/CoreIntelligence/Margin/HBox/NewVal
@onready var core_int_grade: Label = $ResultPopup/VBox/Content/Margin/VBox/CoreStatsGrid/CoreIntelligence/Margin/HBox/GradePanel/Margin/GradeLabel

@onready var core_charm_old: Label = $ResultPopup/VBox/Content/Margin/VBox/CoreStatsGrid/CoreCharm/Margin/HBox/OldVal
@onready var core_charm_new: Label = $ResultPopup/VBox/Content/Margin/VBox/CoreStatsGrid/CoreCharm/Margin/HBox/NewVal
@onready var core_charm_grade: Label = $ResultPopup/VBox/Content/Margin/VBox/CoreStatsGrid/CoreCharm/Margin/HBox/GradePanel/Margin/GradeLabel

@onready var core_sens_old: Label = $ResultPopup/VBox/Content/Margin/VBox/CoreStatsGrid/CoreSensibility/Margin/HBox/OldVal
@onready var core_sens_new: Label = $ResultPopup/VBox/Content/Margin/VBox/CoreStatsGrid/CoreSensibility/Margin/HBox/NewVal
@onready var core_sens_grade: Label = $ResultPopup/VBox/Content/Margin/VBox/CoreStatsGrid/CoreSensibility/Margin/HBox/GradePanel/Margin/GradeLabel

# Footer UI nodes
@onready var footer_mood_val: Label = $ResultPopup/VBox/Footer/Margin/HBox/MoodHBox/Val
@onready var footer_mood_diff: Label = $ResultPopup/VBox/Footer/Margin/HBox/MoodHBox/Diff

@onready var footer_stress_val: Label = $ResultPopup/VBox/Footer/Margin/HBox/StressHBox/Val
@onready var footer_stress_diff: Label = $ResultPopup/VBox/Footer/Margin/HBox/StressHBox/Diff

@onready var footer_gold_val: Label = $ResultPopup/VBox/Footer/Margin/HBox/GoldHBox/Val
@onready var footer_gold_diff: Label = $ResultPopup/VBox/Footer/Margin/HBox/GoldHBox/Diff

@onready var auto_button: Button = $MainPanel/ControlButtons/AutoButton
@onready var skip_button: Button = $MainPanel/ControlButtons/SkipButton
@onready var loading_overlay: Control = $LoadingOverlay
@onready var loading_text: Label = $LoadingOverlay/VBox/LoadingText

var _is_auto_playing: bool = false
var _is_skipping: bool = false
var _result_anim_tween: Tween = null

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
	close_button.pressed.connect(_on_end_button_pressed)
	
	if auto_button: auto_button.pressed.connect(_on_auto_pressed)
	if skip_button: skip_button.pressed.connect(_on_skip_pressed)
	if loading_overlay: loading_overlay.hide()
	
	# 初始状态
	result_popup.hide()
	close_button.hide()

func setup(courses_data: Array, start_attrs: Dictionary, end_attrs: Dictionary) -> void:
	_courses_data = courses_data
	_start_attrs = start_attrs
	_end_attrs = end_attrs
	
	_init_slots()
	
	# 初始展示第 1 个课程的内容
	_update_course_info(0)
	
	# 5. 角色小人初始位置
	character_icon.modulate.a = 0.0 # 先隐藏，避免闪烁
	
	await get_tree().process_frame
	if not is_inside_tree(): return
	await get_tree().process_frame
	if not is_inside_tree(): return
	
	_reset_character_position()
	
	var t = create_tween()
	t.tween_property(character_icon, "modulate:a", 1.0, 0.2)


func _on_auto_pressed() -> void:
	_is_auto_playing = not _is_auto_playing
	if _is_auto_playing:
		auto_button.text = "停止"
		auto_button.add_theme_color_override("font_color", Color(0.26, 0.71, 0.97))
		_try_auto_next()
	else:
		auto_button.text = "自动"
		auto_button.remove_theme_color_override("font_color")

func _on_skip_pressed() -> void:
	_is_skipping = true
	_is_auto_playing = true
	auto_button.text = "自动"
	auto_button.remove_theme_color_override("font_color")
	_try_auto_next()

func _try_auto_next() -> void:
	if not is_inside_tree(): return
	if _is_auto_playing and not _is_moving and _current_slot_index < 4 and not result_popup.visible and (loading_overlay == null or not loading_overlay.visible) and _current_event_panel == null:
		_on_click_area_pressed()

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
	
	for i in range(5):
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
		
	if _current_slot_index >= 4:
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
	
	var duration = 0.05 if _is_skipping else 0.35
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(character_icon, "global_position", target_pos, duration)
	
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
	
	# 每完成1个课程，时间推进一天
	if _current_slot_index > 0 and _current_slot_index < 5:
		if GameDataManager.story_time_manager:
			GameDataManager.story_time_manager.advance_day(1)
		
	if _current_slot_index == 4:
		# 走到最后一个槽位时，立刻将最后一个也标为完成
		set_slot_status(_current_slot_index, true)
		course_completed.emit(_current_slot_index)
		all_courses_completed.emit()
		
		# 第5个课程完成，不跨天，时间设定为周五晚上 20:00
		if GameDataManager.story_time_manager:
			GameDataManager.story_time_manager.current_hour = 20
			GameDataManager.story_time_manager.current_minute = 0
			GameDataManager.story_time_manager.current_period = GameDataManager.story_time_manager.PERIOD_NIGHT
			GameDataManager.story_time_manager.time_advanced.emit(0, GameDataManager.story_time_manager.current_period)
			
		_show_result_popup()
	elif _is_auto_playing:
		if not _is_skipping:
			await get_tree().create_timer(0.3).timeout
			if not is_inside_tree(): return
		_try_auto_next()

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
	if not is_inside_tree(): return
	
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
	if not is_inside_tree(): return
	await get_tree().process_frame
	if not is_inside_tree(): return
	
	# 淡出黑屏
	var tween2 = create_tween()
	tween2.tween_property(transition_overlay, "modulate:a", 0.0, 0.5)
	await tween2.finished
	if not is_inside_tree(): return
	transition_overlay.queue_free()
	
	# 等待故事结束
	await story_scene.chat_closed
	if not is_inside_tree(): return
	
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
	if not is_inside_tree(): return
	
	# 在黑屏完全遮挡住的时候，销毁故事场景，这样就不会有弹出关闭的突兀感
	if is_instance_valid(story_scene):
		story_scene.queue_free()
		
	# 【修复延迟问题】：在黑屏结束前，提前让底层的逻辑往下走，更新下一个日程界面的 UI 元素
	# 这里只调用纯 UI 的更新逻辑（如果是执行下一次移动），但是我们不直接触发动画，
	# 让底下的课程封面图、标题先变过去，并在黑屏中完成加载
	_update_course_info(_current_slot_index)
		
	# 确保在黑屏期间，底下的日常界面（如新的课程封面图等）能完成加载并渲染出一帧
	await get_tree().create_timer(0.3).timeout
	if not is_inside_tree(): return
	await get_tree().process_frame
	if not is_inside_tree(): return
	await get_tree().process_frame
	if not is_inside_tree(): return
	
	# 然后再把黑屏淡出，展示底下的日常界面
	var tween4 = create_tween()
	tween4.tween_property(out_overlay, "modulate:a", 0.0, 0.5)
	await tween4.finished
	if not is_inside_tree(): return
	out_overlay.queue_free()
	
	# 由于前面已经提前更新了 UI，这里我们跳过 _update_course_info() 的二次调用，
	# 直接执行属性结算等后续动作
	_finish_slot_move(true)

func _show_loading(text: String) -> void:
	if loading_overlay:
		loading_text.text = text
		loading_overlay.modulate.a = 0.0
		loading_overlay.show()
		var t = create_tween()
		t.tween_property(loading_overlay, "modulate:a", 1.0, 0.2)

func _hide_loading() -> void:
	if loading_overlay and loading_overlay.visible:
		var t = create_tween()
		t.tween_property(loading_overlay, "modulate:a", 0.0, 0.2)
		t.finished.connect(func(): loading_overlay.hide())

func _trigger_schedule_event() -> void:
	var client = _get_deepseek_client()
	if not client:
		_finish_slot_move()
		return
		
	var course_data = _courses_data[_current_slot_index]
	var course_name = course_data.get("name", "未知课程")
	var course_desc = course_data.get("desc", "")
	
	_show_loading("突发事件生成中...")
	
	if not client.is_connected("schedule_event_generated", _on_schedule_event_generated):
		client.schedule_event_generated.connect(_on_schedule_event_generated)
	if not client.is_connected("schedule_event_error", _on_schedule_event_error):
		client.schedule_event_error.connect(_on_schedule_event_error)
		
	client.generate_schedule_event(course_name, course_desc)

func _on_schedule_event_generated(event_data: Dictionary) -> void:
	_hide_loading()
	
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
	_hide_loading()
	
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
		
	_show_loading("事件结算中...")
	
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
	_hide_loading()
	
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
	
	var phys_keys = ["体能", "反应"]
	var int_keys = ["学识", "表达"]
	var charm_keys = ["气质", "礼仪"]
	var sens_keys = ["审美", "感知"]
	
	var get_core = func(attrs: Dictionary, keys: Array) -> int:
		var total = 0
		for k in keys:
			total += attrs.get(k, 0)
		return int(floor(total))
	
	var get_grade = func(val: float) -> String:
		var levels = [0, 800, 1400, 2000, 2800, 3600, 4400, 5200, 6000, 7200, 8000]
		var grades = ["E-", "E", "D", "D+", "C", "C+", "B", "B+", "A", "S"]
		var grade = "S+"
		for i in range(1, levels.size()):
			if val < levels[i]:
				grade = grades[i-1]
				break
		return grade
	
	var start_phys = get_core.call(_start_attrs, phys_keys)
	var end_phys = get_core.call(_end_attrs, phys_keys)
	core_phys_old.text = str(start_phys)
	core_phys_new.text = str(end_phys)
	core_phys_grade.text = " %s " % get_grade.call(end_phys)
	
	var start_int = get_core.call(_start_attrs, int_keys)
	var end_int = get_core.call(_end_attrs, int_keys)
	core_int_old.text = str(start_int)
	core_int_new.text = str(end_int)
	core_int_grade.text = " %s " % get_grade.call(end_int)
	
	var start_charm = get_core.call(_start_attrs, charm_keys)
	var end_charm = get_core.call(_end_attrs, charm_keys)
	core_charm_old.text = str(start_charm)
	core_charm_new.text = str(end_charm)
	core_charm_grade.text = " %s " % get_grade.call(end_charm)
	
	var start_sens = get_core.call(_start_attrs, sens_keys)
	var end_sens = get_core.call(_end_attrs, sens_keys)
	core_sens_old.text = str(start_sens)
	core_sens_new.text = str(end_sens)
	core_sens_grade.text = " %s " % get_grade.call(end_sens)
	
	# Footer variables
	var start_mood = _start_attrs.get("心情", GameDataManager.profile.mood_value)
	var end_mood = _end_attrs.get("心情", start_mood)
	footer_mood_val.text = str(end_mood)
	var diff_mood = end_mood - start_mood
	footer_mood_diff.text = ("+%d" % diff_mood) if diff_mood >= 0 else str(diff_mood)
	footer_mood_diff.add_theme_color_override("font_color", Color(0.26, 0.71, 0.97) if diff_mood >= 0 else Color(0.9, 0.4, 0.4))
	
	var start_stress = _start_attrs.get("压力", GameDataManager.profile.stress)
	var end_stress = _end_attrs.get("压力", start_stress)
	footer_stress_val.text = str(end_stress)
	var diff_stress = end_stress - start_stress
	footer_stress_diff.text = ("+%d" % diff_stress) if diff_stress >= 0 else str(diff_stress)
	footer_stress_diff.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4) if diff_stress > 0 else Color(0.26, 0.71, 0.97))
	
	var start_gold = _start_attrs.get("金币", GameDataManager.profile.gold)
	var end_gold = _end_attrs.get("金币", start_gold)
	footer_gold_val.text = str(end_gold)
	var diff_gold = end_gold - start_gold
	footer_gold_diff.text = ("+%d" % diff_gold) if diff_gold >= 0 else str(diff_gold)
	footer_gold_diff.add_theme_color_override("font_color", Color(0.26, 0.71, 0.97) if diff_gold >= 0 else Color(0.9, 0.4, 0.4))
	
	for child in stats_vbox.get_children():
		child.queue_free()
		
	var sub_keys = [
		"体能", "反应",
		"学识", "表达",
		"气质", "礼仪",
		"审美", "感知"
	]
	
	for attr in sub_keys:
		var old_val = _start_attrs.get(attr, 0)
		var new_val = _end_attrs.get(attr, old_val)
		
		var hbox = HBoxContainer.new()
		hbox.custom_minimum_size = Vector2(160, 24)
		
		var name_lbl = Label.new()
		name_lbl.text = tr(attr)
		name_lbl.custom_minimum_size = Vector2(50, 0)
		name_lbl.add_theme_color_override("font_color", Color(0.4, 0.3, 0.2))
		hbox.add_child(name_lbl)
		
		var val_lbl = Label.new()
		val_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		
		if new_val > old_val:
			var diff = new_val - old_val
			val_lbl.text = "%d (+%d)" % [old_val, diff]
			val_lbl.add_theme_color_override("font_color", Color(0.26, 0.71, 0.97))
			
			# 动画逻辑移出循环外统一处理
			pass
		else:
			val_lbl.text = str(old_val)
			val_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
			
		hbox.add_child(val_lbl)
		stats_vbox.add_child(hbox)
		
	_result_anim_tween = create_tween().set_trans(Tween.TRANS_LINEAR)
	_result_anim_tween.tween_method(func(v: float):
		for child in stats_vbox.get_children():
			var name_lbl = child.get_child(0)
			var val_lbl = child.get_child(1)
			var attr = name_lbl.text
			
			var old_v = _start_attrs.get(attr, 0)
			var new_v = _end_attrs.get(attr, old_v)
			if new_v > old_v:
				var diff = new_v - old_v
				var curr_v = lerp(float(old_v), float(new_v), v)
				val_lbl.text = "%d (+%d)" % [int(curr_v), diff]
	, 0.0, 1.0, 1.2)
	
	_result_anim_tween.finished.connect(func():
		_set_result_to_final()
	)

func _set_result_to_final() -> void:
	for child in stats_vbox.get_children():
		var name_lbl = child.get_child(0)
		var val_lbl = child.get_child(1)
		var attr = name_lbl.text
		var old_v = _start_attrs.get(attr, 0)
		var new_v = _end_attrs.get(attr, old_v)
		if new_v > old_v:
			val_lbl.text = "%d (+%d)" % [new_v, new_v - old_v]
			
	close_button.show()

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
	profile.stat_stamina = _end_attrs.get("体能", profile.stat_stamina)
	profile.stat_rhythm = _end_attrs.get("反应", profile.stat_rhythm)
	profile.stat_knowledge = _end_attrs.get("学识", profile.stat_knowledge)
	profile.stat_expression = _end_attrs.get("表达", profile.stat_expression)
	profile.stat_temperament = _end_attrs.get("气质", profile.stat_temperament)
	profile.stat_etiquette = _end_attrs.get("礼仪", profile.stat_etiquette)
	profile.stat_aesthetics = _end_attrs.get("审美", profile.stat_aesthetics)
	profile.stat_perception = _end_attrs.get("感知", profile.stat_perception)
	profile.gold = max(0, _end_attrs.get("金币", profile.gold))
	profile.stress = clamp(_end_attrs.get("压力", profile.stress), 0, profile.max_stress)
	profile.mood_value = clamp(_end_attrs.get("心情", profile.mood_value), 0, 100)

	profile.save_profile()
	if GameDataManager.story_time_manager:
		GameDataManager.story_time_manager.save_data()
	GameDataManager.save_manager.auto_save()

	# 使用现有的全局黑屏过渡管理器过渡回主场景
	SceneTransitionManager.transition_to_scene("res://scenes/ui/main/main_scene.tscn")
	schedule_finished.emit()
	queue_free()

func _on_close_pressed() -> void:
	_on_end_button_pressed()
