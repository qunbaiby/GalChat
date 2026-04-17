extends Control

@onready var preview_title: Label = $Panel/Margin/MainHBox/LeftPanel/PreviewTitle
@onready var preview_image: TextureRect = $Panel/Margin/MainHBox/LeftPanel/PreviewImage
@onready var schedule_title: Label = $Panel/Margin/MainHBox/LeftPanel/ScheduleTitle
@onready var schedule_slots: GridContainer = $Panel/Margin/MainHBox/LeftPanel/ScheduleSlots
@onready var outcome_list: RichTextLabel = $Panel/Margin/MainHBox/LeftPanel/OutcomePanel/Margin/VBox/OutcomeList
@onready var undo_button: Button = $Panel/Margin/MainHBox/LeftPanel/BottomHBox/UndoButton
@onready var rest_hbox: HBoxContainer = $Panel/Margin/MainHBox/LeftPanel/BottomHBox/RestHBox

@onready var energy_label: Label = $Panel/Margin/MainHBox/RightPanel/EnergyLabel
@onready var category_tabs: HBoxContainer = $Panel/Margin/MainHBox/RightPanel/CategoryTabs
@onready var tab_container: TabContainer = $Panel/Margin/MainHBox/RightPanel/TabContainer
@onready var tech_list: VBoxContainer = $Panel/Margin/MainHBox/RightPanel/TabContainer/TechList/ScrollContainer/VBox
@onready var business_list: VBoxContainer = $Panel/Margin/MainHBox/RightPanel/TabContainer/BusinessList/ScrollContainer/VBox
@onready var art_list: VBoxContainer = $Panel/Margin/MainHBox/RightPanel/TabContainer/ArtList/ScrollContainer/VBox
@onready var sports_list: VBoxContainer = $Panel/Margin/MainHBox/RightPanel/TabContainer/SportsList/ScrollContainer/VBox
@onready var academic_list: VBoxContainer = $Panel/Margin/MainHBox/RightPanel/TabContainer/AcademicList/ScrollContainer/VBox
@onready var close_button: Button = $Panel/Margin/MainHBox/RightPanel/BottomHBox/CloseButton
@onready var execute_button: Button = $Panel/Margin/MainHBox/RightPanel/BottomHBox/ExecuteButton

var scheduled_activities: Array = []
var current_category_id: String = "tech"

const MAX_SLOTS = 10

var stat_name_map = {
	"physical_fitness": "身体素质",
	"vitality": "体能活力",
	"academic_quality": "学业素养",
	"knowledge_reserve": "知识储备",
	"social_eq": "社交情商",
	"creative_aesthetics": "创意审美",
	"energy_recovery": "精力恢复"
}

func _ready() -> void:
	close_button.pressed.connect(_on_close_pressed)
	execute_button.pressed.connect(_on_execute_pressed)
	undo_button.pressed.connect(_on_undo_pressed)
	
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
	
	var idx = 0
	for child in category_tabs.get_children():
		if child is Button and idx < categories.size():
			var cat = categories[idx]
			child.text = cat.name
			# Disconnect any existing connections to avoid duplicates if re-init happens
			if child.pressed.is_connected(_on_category_pressed):
				child.pressed.disconnect(_on_category_pressed)
			child.pressed.connect(_on_category_pressed.bind(cat.id, idx))
			idx += 1
		
	_populate_all_lists()
	
	# Dynamically populate rest options
	var rest_scene = load("res://scenes/ui/activity/rest_item.tscn")
	var rest_acts = GameDataManager.activity_manager.get_rest_activities()
	
	# Clear any existing non-label children just in case
	for child in rest_hbox.get_children():
		if child is PanelContainer:
			child.queue_free()
			
	for act in rest_acts:
		var item = rest_scene.instantiate()
		rest_hbox.add_child(item)
		item.setup(act)
		item.rest_pressed.connect(_on_activity_pressed)
		item.rest_hovered.connect(_on_activity_hovered)

func _populate_all_lists() -> void:
	var item_scene = load("res://scenes/ui/activity/activity_item.tscn")
	var categories = GameDataManager.activity_manager.get_categories()
	
	var lists = [tech_list, business_list, art_list, sports_list, academic_list]
	
	for i in range(categories.size()):
		var cat_id = categories[i].id
		var list_container = lists[i]
		
		# Clear existing
		for child in list_container.get_children():
			child.queue_free()
			
		var acts = GameDataManager.activity_manager.get_activities_by_category(cat_id)
		for act in acts:
			var item = item_scene.instantiate()
			list_container.add_child(item)
			item.setup(act)
			item.activity_pressed.connect(_on_activity_pressed)
			item.activity_hovered.connect(_on_activity_hovered)

func _on_category_pressed(cat_id: String, tab_index: int = 0) -> void:
	current_category_id = cat_id
	tab_container.current_tab = tab_index
	
	for child in category_tabs.get_children():
		if child is Button:
			var is_selected = false
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
	show()
	
	# Add popup animation
	modulate.a = 0.0
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "modulate:a", 1.0, 0.3)
	
	scale = Vector2(0.9, 0.9)
	pivot_offset = get_viewport_rect().size / 2.0
	var scale_tween = create_tween()
	scale_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	scale_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.3)

func hide_panel() -> void:
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	var scale_tween = create_tween()
	scale_tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	scale_tween.tween_property(self, "scale", Vector2(0.9, 0.9), 0.2)
	scale_tween.finished.connect(hide)

func _update_ui() -> void:
	var profile = GameDataManager.profile
	energy_label.text = "当前精力：%.1f / %.1f" % [profile.current_energy, profile.max_energy]
	
	schedule_title.text = "日程安排 (%d/%d)" % [scheduled_activities.size(), MAX_SLOTS]
	
	var slots = schedule_slots.get_children()
	for i in range(MAX_SLOTS):
		var btn = slots[i] as Button
		if i < scheduled_activities.size():
			var act_id = scheduled_activities[i]
			var act = GameDataManager.activity_manager.get_activity_by_id(act_id)
			if not act.is_empty():
				btn.text = "" 
				if act.has("icon_path"):
					var icon_res = load(act.icon_path)
					if icon_res:
						btn.icon = icon_res
				else:
					btn.text = act.name.substr(0, 1) 
			else:
				btn.text = "未知"
				btn.icon = null
		else:
			btn.text = "空"
			btn.icon = null
			
	execute_button.disabled = scheduled_activities.size() < MAX_SLOTS
	undo_button.disabled = scheduled_activities.size() == 0
	
	_update_outcome()

func _update_outcome() -> void:
	var total_rewards = {}
	var total_energy_cost = 0
	
	for act_id in scheduled_activities:
		var act = GameDataManager.activity_manager.get_activity_by_id(act_id)
		if act.is_empty(): continue
		
		total_energy_cost += act.get("energy_cost", 0)
		
		if act.has("rewards"):
			for key in act.rewards.keys():
				var range_arr = act.rewards[key]
				var avg_val = (range_arr[0] + range_arr[1]) / 2.0
				if not total_rewards.has(key):
					total_rewards[key] = 0.0
				total_rewards[key] += avg_val
				
	var outcome_text = ""
	if total_energy_cost > 0:
		outcome_text += "[color=#d05050]预计精力消耗: -%d[/color]\n" % total_energy_cost
		
	for key in total_rewards.keys():
		var display_name = stat_name_map.get(key, key)
		var val = total_rewards[key]
		outcome_text += "[color=#40a040]%s: +%.1f (预计)[/color]\n" % [display_name, val]
		
	if outcome_text == "":
		outcome_text = "[color=#888888]暂无安排[/color]"
		
	outcome_list.text = outcome_text

func _on_activity_hovered(act: Dictionary) -> void:
	preview_title.text = act.name
	if act.has("preview_image") and act.preview_image != "":
		var tex = load(act.preview_image)
		if tex:
			preview_image.texture = tex
		else:
			preview_image.texture = null
	else:
		preview_image.texture = null

func _on_activity_pressed(activity_id: String) -> void:
	if scheduled_activities.size() < MAX_SLOTS:
		scheduled_activities.append(activity_id)
		_update_ui()

func _on_slot_pressed(index: int) -> void:
	pass # 取消点击移除逻辑，只能通过撤销按钮

func _on_undo_pressed() -> void:
	if scheduled_activities.size() > 0:
		scheduled_activities.pop_back()
		_update_ui()

func _on_execute_pressed() -> void:
	if scheduled_activities.size() == MAX_SLOTS:
		hide()
		var main_scene = get_tree().current_scene
		var exec_panel_obj = load("res://scenes/ui/activity/schedule_execution_panel.tscn")
		var exec_panel = exec_panel_obj.instantiate()
		main_scene.add_child(exec_panel)
		exec_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		exec_panel.start_execution(scheduled_activities.duplicate())
		
		scheduled_activities.clear()

func _on_close_pressed() -> void:
	hide_panel()
