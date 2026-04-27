extends Control

signal course_completed(index: int)
signal all_courses_completed
signal schedule_finished

@export var slot_scene: PackedScene

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
		_is_moving = false
		
		# 走到下一个槽位时，立刻刷新顶部的当前课程图文信息
		_update_course_info(_current_slot_index)
		
		if _current_slot_index == 9:
			# 走到最后一个槽位时，立刻将最后一个也标为完成
			set_slot_status(_current_slot_index, true)
			course_completed.emit(_current_slot_index)
			all_courses_completed.emit()
			_show_result_popup()
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
