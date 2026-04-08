extends Control

@onready var energy_label: Label = $Panel/VBoxContainer/EnergyLabel
@onready var activity_list: VBoxContainer = $Panel/VBoxContainer/ScrollContainer/ActivityList
@onready var result_label: Label = $Panel/VBoxContainer/ResultLabel
@onready var close_button: Button = $Panel/VBoxContainer/CloseButton
@onready var execute_button: Button = $Panel/VBoxContainer/ExecuteButton
@onready var schedule_slots: HBoxContainer = $Panel/VBoxContainer/ScheduleSlots
@onready var schedule_title: Label = $Panel/VBoxContainer/ScheduleTitle
@onready var category_tabs: HBoxContainer = $Panel/VBoxContainer/CategoryTabs

var scheduled_activities: Array = []
var current_category_id: String = "tech"

func _ready() -> void:
	close_button.pressed.connect(_on_close_pressed)
	execute_button.pressed.connect(_on_execute_pressed)
	_init_slots()
	_init_category_tabs()

func _init_slots() -> void:
	var index = 0
	for child in schedule_slots.get_children():
		if child is Button:
			child.pressed.connect(_on_slot_pressed.bind(index))
			child.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			child.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
			index += 1

func _init_category_tabs() -> void:
	var categories = GameDataManager.activity_manager.get_categories()
	for child in category_tabs.get_children():
		child.queue_free()
		
	for cat in categories:
		var btn = Button.new()
		btn.text = cat.name
		btn.custom_minimum_size = Vector2(80, 40)
		btn.add_theme_font_size_override("font_size", 18)
		btn.pressed.connect(_on_category_pressed.bind(cat.id))
		category_tabs.add_child(btn)
		
	# 添加休息Tab
	var rest_btn = Button.new()
	rest_btn.text = "休息"
	rest_btn.custom_minimum_size = Vector2(80, 40)
	rest_btn.add_theme_font_size_override("font_size", 18)
	rest_btn.pressed.connect(_on_category_pressed.bind("rest"))
	category_tabs.add_child(rest_btn)

func _on_category_pressed(cat_id: String) -> void:
	current_category_id = cat_id
	_refresh_activity_list()
	
	# 更新Tab按钮的视觉状态（高亮当前选中）
	for child in category_tabs.get_children():
		if child is Button:
			var is_selected = false
			if cat_id == "rest" and child.text == "休息":
				is_selected = true
			else:
				var cat_info = _get_category_by_name(child.text)
				if cat_info and cat_info.id == cat_id:
					is_selected = true
			
			if is_selected:
				child.modulate = Color(1.2, 1.2, 1.2)
			else:
				child.modulate = Color(0.8, 0.8, 0.8)

func _get_category_by_name(cat_name: String) -> Dictionary:
	var categories = GameDataManager.activity_manager.get_categories()
	for cat in categories:
		if cat.name == cat_name:
			return cat
	return {}

func show_panel() -> void:
	_update_ui()
	if current_category_id == "":
		current_category_id = "tech"
	_on_category_pressed(current_category_id)
	
	result_label.text = "请安排本周行程..."
	result_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	show()

func _update_ui() -> void:
	var profile = GameDataManager.profile
	energy_label.text = "当前精力：%.1f / %.1f" % [profile.current_energy, profile.max_energy]
	
	schedule_title.text = "本周日程 (%d/7)" % scheduled_activities.size()
	
	var slots = schedule_slots.get_children()
	for i in range(7):
		var btn = slots[i] as Button
		if i < scheduled_activities.size():
			var act_id = scheduled_activities[i]
			var act = GameDataManager.activity_manager.get_activity_by_id(act_id)
			if not act.is_empty():
				btn.text = "" # 不显示文字
				if act.has("icon_path"):
					var icon_res = load(act.icon_path)
					if icon_res:
						btn.icon = icon_res
				else:
					btn.text = act.name.substr(0, 1) # 图标丢失时显示首字
			else:
				btn.text = "未知"
				btn.icon = null
		else:
			btn.text = "空"
			btn.icon = null
			
	execute_button.disabled = scheduled_activities.size() < 7

func _refresh_activity_list() -> void:
	for child in activity_list.get_children():
		child.queue_free()
		
	var acts = []
	if current_category_id == "rest":
		acts = GameDataManager.activity_manager.get_rest_activities()
	else:
		acts = GameDataManager.activity_manager.get_activities_by_category(current_category_id)
	
	for act in acts:
		var btn = Button.new()
		var btn_text = "%s - 消耗精力: %d\n" % [act.name, act.energy_cost]
		btn_text += act.desc
		btn.text = btn_text
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override("font_size", 20)
		btn.custom_minimum_size = Vector2(0, 80)
		
		if act.has("icon_path"):
			var icon_res = load(act.icon_path)
			if icon_res:
				btn.icon = icon_res
				btn.expand_icon = true
				
		btn.pressed.connect(_on_activity_pressed.bind(act.id))
		activity_list.add_child(btn)

func _on_activity_pressed(activity_id: String) -> void:
	if scheduled_activities.size() < 7:
		scheduled_activities.append(activity_id)
		_update_ui()
	else:
		result_label.add_theme_color_override("font_color", Color(0.8, 0.4, 0.4))
		result_label.text = "日程已满，请先执行安排或撤销已有课程！"

func _on_slot_pressed(index: int) -> void:
	if index < scheduled_activities.size():
		scheduled_activities.remove_at(index)
		_update_ui()

func _on_execute_pressed() -> void:
	if scheduled_activities.size() == 7:
		hide()
		# 实例化执行面板
		var main_scene = get_tree().current_scene
		var exec_panel_obj = load("res://scenes/ui/activity/schedule_execution_panel.tscn")
		var exec_panel = exec_panel_obj.instantiate()
		main_scene.add_child(exec_panel)
		exec_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		exec_panel.start_execution(scheduled_activities.duplicate())
		
		# 清空日程
		scheduled_activities.clear()

func _on_close_pressed() -> void:
	hide()
