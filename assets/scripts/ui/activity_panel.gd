extends Control

@onready var energy_label: Label = $Panel/VBoxContainer/EnergyLabel
@onready var activity_list: VBoxContainer = $Panel/VBoxContainer/ScrollContainer/ActivityList
@onready var result_label: Label = $Panel/VBoxContainer/ResultLabel
@onready var close_button: Button = $Panel/VBoxContainer/CloseButton
@onready var execute_button: Button = $Panel/VBoxContainer/ExecuteButton
@onready var schedule_slots: HBoxContainer = $Panel/VBoxContainer/ScheduleSlots
@onready var schedule_title: Label = $Panel/VBoxContainer/ScheduleTitle

var scheduled_activities: Array = []

# 用于将英文属性名映射为中文展示
const STAT_NAME_MAP = {
	"physical_fitness": "身体素质",
	"vitality": "体能活力",
	"academic_quality": "学业素养",
	"knowledge_reserve": "知识储备",
	"social_eq": "社交情商",
	"creative_aesthetics": "创意审美",
	"energy_recovery": "恢复精力"
}

func _ready() -> void:
	close_button.pressed.connect(_on_close_pressed)
	execute_button.pressed.connect(_on_execute_pressed)
	_init_activities()
	_init_slots()

func _init_slots() -> void:
	var index = 0
	for child in schedule_slots.get_children():
		if child is Button:
			child.pressed.connect(_on_slot_pressed.bind(index))
			index += 1

func show_panel() -> void:
	_update_ui()
	result_label.text = "请安排本周行程..."
	result_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	show()

func _update_ui() -> void:
	var profile = GameDataManager.profile
	energy_label.text = "当前精力：%.1f / %.1f" % [profile.current_energy, profile.max_energy]
	
	schedule_title.text = "本周日程 (%d/7)" % scheduled_activities.size()
	
	var all_acts = GameDataManager.activity_manager.get_all_activities()
	
	var slots = schedule_slots.get_children()
	for i in range(7):
		var btn = slots[i] as Button
		if i < scheduled_activities.size():
			var act_id = scheduled_activities[i]
			var act_name = "未知"
			for a in all_acts:
				if a.id == act_id:
					act_name = a.name
					break
			btn.text = act_name
		else:
			btn.text = "空"
			
	execute_button.disabled = scheduled_activities.size() < 7

func _init_activities() -> void:
	# 清空旧列表
	for child in activity_list.get_children():
		child.queue_free()
		
	var activities = GameDataManager.activity_manager.get_all_activities()
	
	for act in activities:
		var btn = Button.new()
		var btn_text = "%s (%s) - 消耗精力: %d\n" % [act.name, act.type, act.energy_cost]
		btn_text += act.desc
		btn.text = btn_text
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override("font_size", 20)
		btn.custom_minimum_size = Vector2(0, 80)
		
		# 连接点击信号，使用 Callable 绑定参数
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
		var exec_panel_obj = load("res://assets/scenes/ui/schedule_execution_panel.tscn")
		var exec_panel = exec_panel_obj.instantiate()
		main_scene.add_child(exec_panel)
		exec_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		exec_panel.start_execution(scheduled_activities.duplicate())
		
		# 清空日程
		scheduled_activities.clear()

func _on_close_pressed() -> void:
	hide()
