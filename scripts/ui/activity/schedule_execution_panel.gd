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
@onready var character_icon: Control = $MainPanel/TrackContainer/CharacterIcon
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
		top_image_rect.texture = load(current_course["image_path"])
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
	character_icon.global_position = current_slot.global_position + (current_slot.size - character_icon.size) / 2.0
	
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
	var target_pos = target_slot.global_position + (target_slot.size - character_icon.size) / 2.0
	
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(character_icon, "global_position", target_pos, 0.35)
	
	tween.finished.connect(func():
		_current_slot_index = next_index
		
		if randf() < 0.2:
			_trigger_schedule_event()
		else:
			_finish_slot_move()
	)

func _finish_slot_move() -> void:
	_is_moving = false
	
	# 走到下一个槽位时，立刻刷新顶部的当前课程图文信息
	_update_course_info(_current_slot_index)
	
	# 每完成2个课程，时间推进一天 (2, 4, 6, 8)
	if _current_slot_index % 2 == 0 and _current_slot_index < 10:
		GameDataManager.time_system.advance_time(1, 0, 0)
		
	if _current_slot_index == 9:
		# 走到最后一个槽位时，立刻将最后一个也标为完成
		set_slot_status(_current_slot_index, true)
		course_completed.emit(_current_slot_index)
		all_courses_completed.emit()
		# 第10个课程完成，推进最后一天
		GameDataManager.time_system.advance_time(1, 0, 0)
		_show_result_popup()

func _get_deepseek_client() -> Node:
	if get_tree().current_scene and get_tree().current_scene.has_node("DeepSeekClient"):
		return get_tree().current_scene.get_node("DeepSeekClient")
	if get_node_or_null("/root/DeepSeekClient"):
		return get_node("/root/DeepSeekClient")
	if get_tree().root.has_node("MainScene/DeepSeekClient"):
		return get_node("/root/MainScene/DeepSeekClient")
	return null

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
		var val_tween = create_tween().set_trans(Tween.TRANS_LINEAR)
		val_tween.tween_method(func(v: float):
			val_lbl.text = str(int(v)) + " (+" + str(int(new_val - old_val)) + ")"
			pb.value = v
		, float(old_val), float(new_val), 1.2)
		
	await get_tree().create_timer(1.2).timeout
	end_button.show()

func _on_end_button_pressed() -> void:
	var tween = create_tween()
	tween.tween_property(result_popup, "modulate:a", 0.0, 0.3)
	tween.finished.connect(func():
		schedule_finished.emit()
		queue_free()
	)

func _on_close_pressed() -> void:
	queue_free()
