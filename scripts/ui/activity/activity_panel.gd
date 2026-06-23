extends Control

const MAIN_EVENT_SLOT_ICON: Texture2D = preload("res://assets/images/icons/ui/main/book-open-cover.png")
const ActivityLoadingOverlayScene = preload("res://scenes/ui/activity/activity_loading_overlay.tscn")

@onready var main_panel: HBoxContainer = $BackgroundPanel/Margin/MainHBox
@onready var left_panel: Control = $BackgroundPanel/Margin/MainHBox/LeftPanel
@onready var left_panel_margin: MarginContainer = $BackgroundPanel/Margin/MainHBox/LeftPanel/Margin
@onready var left_panel_vbox: VBoxContainer = $BackgroundPanel/Margin/MainHBox/LeftPanel/Margin/VBox
@onready var back_button: Button = $BackgroundPanel/BackButton
@onready var place_into_button: Button = $BackgroundPanel/Margin/MainHBox/LeftPanel/Margin/VBox/CategoryTitle/PlaceIntoButton
@onready var category_tabs: HBoxContainer = $BackgroundPanel/Margin/MainHBox/LeftPanel/Margin/VBox/CategoryTabsContainer/CategoryTabsMargin/CategoryTabs
@onready var category_content_card: PanelContainer = $BackgroundPanel/Margin/MainHBox/LeftPanel/Margin/VBox/CategoryContentCard
@onready var category_content_margin: MarginContainer = $BackgroundPanel/Margin/MainHBox/LeftPanel/Margin/VBox/CategoryContentCard/CategoryContentMargin
@onready var activities_scroll: ScrollContainer = $BackgroundPanel/Margin/MainHBox/LeftPanel/Margin/VBox/CategoryContentCard/CategoryContentMargin/CategoryContentVBox/ScrollContainer
@onready var activities_grid: GridContainer = %ActivitiesGrid
@onready var schedule_label: Label = $BackgroundPanel/Margin/MainHBox/LeftPanel/Margin/VBox/ScheduleTitle/ScheduleLabel
@onready var schedule_slots: VBoxContainer = $BackgroundPanel/Margin/MainHBox/LeftPanel/Margin/VBox/BottomHBox/ScheduleSlots
@onready var undo_button: Button = $BackgroundPanel/Margin/MainHBox/LeftPanel/Margin/VBox/BottomHBox/ControlButtoon/UndoButton
@onready var clear_button: Button = $BackgroundPanel/Margin/MainHBox/LeftPanel/Margin/VBox/BottomHBox/ControlButtoon/ClearButton
@onready var right_panel: Control = $BackgroundPanel/Margin/MainHBox/RightPanel

@export var category_tab_scene: PackedScene = preload("res://scenes/ui/activity/category_tab_item.tscn")

@onready var avatar_rect: TextureRect = %AvatarRect
@onready var char_name_label: Label = %CharNameLabel
@onready var energy_label: Label = %EnergyLabel
@onready var energy_bubble: Label = %EnergyBubble
@onready var gold_label: Label = %GoldLabel
@onready var gold_sep: ColorRect = $BackgroundPanel/Margin/MainHBox/RightPanel/Margin/VBox/StatusHBox/Sep2
@onready var mood_bubble: Label = %MoodBubble
@onready var mood_label: Label = %MoodLabel
@onready var bonus_label: Label = %BonusLabel

@onready var phys_sub: GridContainer = $BackgroundPanel/Margin/MainHBox/RightPanel/Margin/VBox/ScrollContainer/StatsGrid/Block_Physical/Margin/VBox/SubStats
@onready var int_sub: GridContainer = $BackgroundPanel/Margin/MainHBox/RightPanel/Margin/VBox/ScrollContainer/StatsGrid/Block_Intelligence/Margin/VBox/SubStats
@onready var charm_sub: GridContainer = $BackgroundPanel/Margin/MainHBox/RightPanel/Margin/VBox/ScrollContainer/StatsGrid/Block_Charm/Margin/VBox/SubStats
@onready var sens_sub: GridContainer = $BackgroundPanel/Margin/MainHBox/RightPanel/Margin/VBox/ScrollContainer/StatsGrid/Block_Sensibility/Margin/VBox/SubStats

@onready var phys_val: Label = $BackgroundPanel/Margin/MainHBox/RightPanel/Margin/VBox/ScrollContainer/StatsGrid/Block_Physical/Margin/VBox/Header/TitleVBox/TitleHBox/ValLabel
@onready var int_val: Label = $BackgroundPanel/Margin/MainHBox/RightPanel/Margin/VBox/ScrollContainer/StatsGrid/Block_Intelligence/Margin/VBox/Header/TitleVBox/TitleHBox/ValLabel
@onready var charm_val: Label = $BackgroundPanel/Margin/MainHBox/RightPanel/Margin/VBox/ScrollContainer/StatsGrid/Block_Charm/Margin/VBox/Header/TitleVBox/TitleHBox/ValLabel
@onready var sens_val: Label = $BackgroundPanel/Margin/MainHBox/RightPanel/Margin/VBox/ScrollContainer/StatsGrid/Block_Sensibility/Margin/VBox/Header/TitleVBox/TitleHBox/ValLabel


@onready var execute_button: Button = $BackgroundPanel/Margin/MainHBox/RightPanel/Margin/VBox/ExecuteButton

var scheduled_activities: Array = []
const MAX_SLOTS = 5
var current_category_id: String = ""

var _pending_exec_data: Dictionary = {}
var _category_tab_group: ButtonGroup
var _category_tab_buttons: Dictionary = {}
var _activity_loading_overlay: ActivityLoadingOverlay = null
var _guide_reported_schedule_full: bool = false
var _last_guide_blocked_tip_ms: int = -1000

var stat_name_map = {
	"stat_stamina": "体能",
	"stat_rhythm": "反应",
	"stat_knowledge": "学识",
	"stat_expression": "表达",
	"stat_temperament": "气质",
	"stat_etiquette": "礼仪",
	"stat_aesthetics": "审美",
	"stat_perception": "感知"
}

var category_group_map = {}

var _style_bubble: StyleBox
var _style_bubble_neg: StyleBox
var _last_execute_press_frame: int = -1

func _ready() -> void:
	category_group_map = {
		"stat_stamina": phys_sub,
		"stat_rhythm": phys_sub,
		"stat_knowledge": int_sub,
		"stat_expression": int_sub,
		"stat_temperament": charm_sub,
		"stat_etiquette": charm_sub,
		"stat_aesthetics": sens_sub,
		"stat_perception": sens_sub
	}
	
	back_button.pressed.connect(_on_close_pressed)
	execute_button.pressed.connect(_on_execute_pressed)
	if not execute_button.gui_input.is_connected(_on_execute_button_gui_input):
		execute_button.gui_input.connect(_on_execute_button_gui_input)
	place_into_button.pressed.connect(_on_place_into_pressed)
	undo_button.pressed.connect(_on_undo_pressed)
	clear_button.pressed.connect(_on_clear_pressed)
	if right_panel and not right_panel.gui_input.is_connected(_on_right_panel_gui_input):
		right_panel.gui_input.connect(_on_right_panel_gui_input)
	
	_style_bubble = mood_bubble.get_theme_stylebox("normal")
	if _style_bubble and _style_bubble is StyleBoxFlat:
		_style_bubble_neg = (_style_bubble as StyleBoxFlat).duplicate()
		(_style_bubble_neg as StyleBoxFlat).bg_color = Color(0.95, 0.55, 0.55, 1)
	
	_init_slots()
	_init_category_tabs()
	_ensure_activity_loading_overlay()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	if not _is_guide_interaction_allowed("activity.preview_panel"):
		return
	if right_panel == null or not right_panel.is_visible_in_tree():
		return
	if is_instance_valid(execute_button) and execute_button.get_global_rect().has_point(mouse_event.global_position):
		return
	if right_panel.get_global_rect().has_point(mouse_event.global_position):
		_report_guide_action("activity_click_preview_panel")

func _get_guide_manager() -> Node:
	return get_node_or_null("/root/GuideManager")

func _is_guide_interaction_allowed(interaction_id: String) -> bool:
	var guide_manager := _get_guide_manager()
	if guide_manager and guide_manager.has_method("is_guide_interaction_allowed"):
		return bool(guide_manager.is_guide_interaction_allowed(interaction_id))
	return true

func _notify_guide_interaction_blocked() -> void:
	var now_ms := Time.get_ticks_msec()
	if now_ms - _last_guide_blocked_tip_ms < 900:
		return
	_last_guide_blocked_tip_ms = now_ms
	if typeof(ToastManager) != TYPE_NIL:
		ToastManager.show_system_toast("请按当前高亮区域完成引导操作")

func _report_guide_action(action_id: String, payload: Dictionary = {}) -> void:
	var guide_manager := _get_guide_manager()
	if guide_manager and guide_manager.has_method("report_action"):
		guide_manager.report_action(action_id, payload)

func _get_control_focus_rect(control: Control) -> Rect2:
	if not is_instance_valid(control):
		return Rect2()
	if not control.is_visible_in_tree():
		return Rect2()
	var rect := Rect2(Vector2.ZERO, control.size)
	var panel_origin: Vector2 = get_global_transform_with_canvas().origin
	var current: Node = control
	while current != null and current != self:
		if current is Control:
			rect.position += (current as Control).position
		current = current.get_parent()
	rect.position += panel_origin
	return rect

func _build_rounded_rect_polygon(rect: Rect2, radius: float, segments_per_corner: int = 6) -> PackedVector2Array:
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

func _make_focus_entry(rect: Rect2, radius: float, include_cutout_polygon: bool = false) -> Dictionary:
	if rect.size.x <= 1.0 or rect.size.y <= 1.0:
		return {}
	var focus_entry := {
		"rect": rect,
		"shape": "rect",
		"shape_params": {
			"corner_radius": radius
		}
	}
	if include_cutout_polygon:
		focus_entry["cutout_polygon"] = _build_rounded_rect_polygon(rect, radius)
	return focus_entry

func _merge_rects(rects: Array[Rect2]) -> Rect2:
	var merged := Rect2()
	var has_rect := false
	for rect in rects:
		if rect.size.x <= 1.0 or rect.size.y <= 1.0:
			continue
		if not has_rect:
			merged = rect
			has_rect = true
		else:
			merged = merged.merge(rect)
	return merged

func _get_controls_focus_rect(controls: Array) -> Rect2:
	var rects: Array[Rect2] = []
	for item in controls:
		if item is Control:
			var control := item as Control
			var rect := _get_control_focus_rect(control)
			if rect.size.x > 1.0 and rect.size.y > 1.0:
				rects.append(rect)
	return _merge_rects(rects)

func _get_container_children_focus_rect(container: Control) -> Rect2:
	if not is_instance_valid(container) or not container.is_visible_in_tree():
		return Rect2()
	var rects: Array[Rect2] = []
	for child in container.get_children():
		if child is Control:
			var child_rect: Rect2 = _get_control_focus_rect(child as Control)
			if child_rect.size.x > 1.0 and child_rect.size.y > 1.0:
				rects.append(child_rect)
	return _merge_rects(rects)

func _get_all_slot_buttons() -> Array:
	var morning_row: Control = schedule_slots.get_node("MorningRow") as Control
	
	var buttons: Array = []
	buttons.resize(5)
	buttons[0] = morning_row.get_node("Slot1")
	buttons[1] = morning_row.get_node("Slot2")
	buttons[2] = morning_row.get_node("Slot3")
	buttons[3] = morning_row.get_node("Slot4")
	buttons[4] = morning_row.get_node("Slot5")
	
	return buttons

func _init_slots() -> void:
	var index = 0
	for child in _get_all_slot_buttons():
		if child is Button:
			if not child.pressed.is_connected(_on_slot_pressed.bind(index)):
				child.pressed.connect(_on_slot_pressed.bind(index))
			child.mouse_filter = Control.MOUSE_FILTER_STOP
			child.focus_mode = Control.FOCUS_NONE
			child.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			child.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
			index += 1
			
	_init_schedule_slots()

func _init_schedule_slots() -> void:
	scheduled_activities.clear()
	scheduled_activities.resize(MAX_SLOTS)
	
	if not GameDataManager.story_time_manager: return
	
	var current_day_offset = GameDataManager.story_time_manager.current_day_offset
	
	for i in range(MAX_SLOTS):
		var day_offset = current_day_offset + i
		var config = GameDataManager.story_time_manager.get_day_config(day_offset)
		var event_entries = _build_story_event_entries(config)
		if event_entries.size() > 0:
			scheduled_activities[i] = {"type": "event", "event_entries": event_entries}

func _append_story_event_entries(event_entries: Array, raw_events: Variant, period: String) -> void:
	if not (raw_events is Array):
		return
	for raw_event_id in raw_events:
		var event_id := str(raw_event_id).strip_edges()
		if event_id == "":
			continue
		var script_path := "res://assets/data/story/scripts/main/%s.json" % event_id
		var cover_path := ""
		var summary := "推进主线剧情..."
		if FileAccess.file_exists(script_path):
			var file = FileAccess.open(script_path, FileAccess.READ)
			var json = JSON.new()
			if file != null and json.parse(file.get_as_text()) == OK and json.data is Dictionary:
				var script_data: Dictionary = json.data
				cover_path = str(script_data.get("cover_image", "")).strip_edges()
				summary = str(script_data.get("summary", summary)).strip_edges()
		event_entries.append({
			"event_id": event_id,
			"period": period,
			"script_path": script_path,
			"image_path": cover_path,
			"summary": summary
		})

func _build_story_event_entries(day_config: Dictionary) -> Array:
	var event_entries: Array = []
	_append_story_event_entries(event_entries, day_config.get("events", []), "全天")
	_append_story_event_entries(event_entries, day_config.get("morning_events", []), "上午")
	_append_story_event_entries(event_entries, day_config.get("afternoon_events", []), "下午")
	_append_story_event_entries(event_entries, day_config.get("evening_events", []), "傍晚")
	_append_story_event_entries(event_entries, day_config.get("night_events", []), "夜晚")
	return event_entries

func _init_category_tabs() -> void:
	for child in category_tabs.get_children():
		child.queue_free()
	_category_tab_buttons.clear()
	_category_tab_group = ButtonGroup.new()
	var categories: Array = GameDataManager.activity_manager.get_categories()
	if categories.is_empty():
		current_category_id = ""
		return
	if current_category_id == "":
		current_category_id = str(categories[0].get("id", ""))
	for cat in categories:
		var cat_id: String = str(cat.get("id", "")).strip_edges()
		if cat_id == "":
			continue
		var tab_button := category_tab_scene.instantiate() as Button
		if tab_button == null:
			continue
		tab_button.text = str(cat.get("name", cat_id))
		tab_button.toggle_mode = true
		tab_button.button_group = _category_tab_group
		tab_button.pressed.connect(_on_category_pressed.bind(cat_id))
		category_tabs.add_child(tab_button)
		_category_tab_buttons[cat_id] = tab_button
	if not _category_tab_buttons.has(current_category_id):
		current_category_id = str(categories[0].get("id", ""))
	_refresh_category_tabs()

func _on_category_pressed(cat_id: String) -> void:
	if not _is_guide_interaction_allowed("activity.category_tabs"):
		_notify_guide_interaction_blocked()
		return
	current_category_id = cat_id
	_refresh_category_tabs()
	_populate_activities()
	_report_guide_action("activity_switch_category", {
		"category_id": cat_id
	})

func _refresh_category_tabs() -> void:
	for cat_id in _category_tab_buttons.keys():
		var button: Button = _category_tab_buttons.get(cat_id) as Button
		if button:
			button.button_pressed = (cat_id == current_category_id)

func _get_category_by_name(cat_name: String) -> Dictionary:
	var categories = GameDataManager.activity_manager.get_categories()
	for cat in categories:
		if cat.name == cat_name or cat.id == cat_name:
			return cat
	return {}

func _populate_activities() -> void:
	if not is_node_ready():
		await ready
		
	var item_scene = load("res://scenes/ui/activity/activity_item.tscn")
	if not activities_grid:
		return
	
	for child in activities_grid.get_children():
		child.queue_free()

	var profile = GameDataManager.profile
	var acts: Array = GameDataManager.activity_manager.get_activities_by_category(current_category_id)
	for act in acts:
		var c_id = act.get("id", "")
		var max_prog = act.get("max_progress", 0)
		var cur_prog = profile.course_progress.get(c_id, 0)
		if max_prog > 0 and cur_prog >= max_prog:
			continue
		var item = item_scene.instantiate()
		activities_grid.add_child(item)
		item.setup(act, cur_prog)
		item.activity_pressed.connect(_on_activity_pressed)

func show_panel() -> void:
	if not is_node_ready():
		await ready
		
	# 每次打开面板时，重新初始化槽位和事件（如果数组内没有玩家自己选的课程才重置，避免玩家选了一半关掉面板丢失）
	var has_user_course = false
	for item in scheduled_activities:
		if typeof(item) == TYPE_STRING:
			has_user_course = true
			break
	if not has_user_course:
		_init_schedule_slots()
		
	_init_category_tabs()
	_populate_activities()
	_refresh_category_tabs()
	_guide_reported_schedule_full = false
	_update_ui()
	if _activity_loading_overlay:
		_activity_loading_overlay.hide_immediately()
	main_panel.show()
	show()
	await get_tree().process_frame
	await get_tree().process_frame
	var guide_manager := _get_guide_manager()
	if guide_manager and guide_manager.has_method("on_activity_panel_ready"):
		guide_manager.on_activity_panel_ready(self)
	
	modulate.a = 0.0
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "modulate:a", 1.0, 0.3)

func hide_panel() -> void:
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.finished.connect(hide)

func _update_ui() -> void:
	if not is_node_ready():
		await ready
		
	var profile = GameDataManager.profile
	
	var scheduled_count = 0
	for item in scheduled_activities:
		if item != null:
			scheduled_count += 1
			
	schedule_label.text = "%d/%d" % [scheduled_count, MAX_SLOTS]
	if scheduled_count >= MAX_SLOTS:
		if not _guide_reported_schedule_full:
			_guide_reported_schedule_full = true
			_report_guide_action("activity_schedule_full")
	else:
		_guide_reported_schedule_full = false
	
	var slots = _get_all_slot_buttons()
	for i in range(MAX_SLOTS):
		var btn = slots[i] as Button
		var item = scheduled_activities[i]
		
		# 获取基础样式
		var base_style = btn.get_theme_stylebox("normal")
		var new_style = null
		if base_style and base_style is StyleBoxFlat:
			new_style = base_style.duplicate()
		else:
			new_style = StyleBoxFlat.new()
			new_style.bg_color = Color(0.9607843, 0.98039216, 0.96862745, 0.92)
			new_style.corner_radius_top_left = 14
			new_style.corner_radius_top_right = 14
			new_style.corner_radius_bottom_right = 14
			new_style.corner_radius_bottom_left = 14
			new_style.border_width_left = 1
			new_style.border_width_top = 1
			new_style.border_width_right = 1
			new_style.border_width_bottom = 1
			new_style.border_color = Color(0.82, 0.9, 0.88, 0.95)
			
		if typeof(item) == TYPE_DICTIONARY and item.get("type") == "event":
			new_style.border_width_left = 3
			new_style.border_width_top = 3
			new_style.border_width_right = 3
			new_style.border_width_bottom = 3
			new_style.border_color = Color(0.93, 0.74, 0.42, 0.95)
			new_style.bg_color = Color(1, 0.96, 0.9, 1)
		else:
			new_style.border_width_left = 1
			new_style.border_width_top = 1
			new_style.border_width_right = 1
			new_style.border_width_bottom = 1
			new_style.border_color = Color(0.82, 0.9, 0.88, 0.95)
			
		btn.add_theme_stylebox_override("normal", new_style)
		btn.add_theme_stylebox_override("hover", new_style)
		btn.add_theme_stylebox_override("pressed", new_style)
		btn.add_theme_stylebox_override("disabled", new_style)
		btn.set_meta("is_main_event_slot", typeof(item) == TYPE_DICTIONARY and item.get("type") == "event")
		
		if item == null:
			btn.text = ""
			btn.icon = null
		elif typeof(item) == TYPE_DICTIONARY and item.get("type") == "event":
			btn.text = ""
			btn.icon = MAIN_EVENT_SLOT_ICON
		elif typeof(item) == TYPE_STRING:
			var act = GameDataManager.activity_manager.get_activity_by_id(item)
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
			
	execute_button.disabled = scheduled_count < MAX_SLOTS
	
	var has_removable = false
	for item in scheduled_activities:
		if typeof(item) == TYPE_STRING:
			has_removable = true
			break
			
	undo_button.disabled = not has_removable
	clear_button.disabled = not has_removable
	
	_update_right_panel(profile)

func _update_right_panel(profile) -> void:
	# 设置头像
	if profile.avatar != "" and FileAccess.file_exists(profile.avatar):
		avatar_rect.texture = load(profile.avatar)
		
	# 设置角色名
	if profile.char_name != "":
		char_name_label.text = profile.char_name.capitalize()
	else:
		char_name_label.text = "未知角色"
		
	var mood_data = GameDataManager.mood_system.get_macro_mood(profile.mood_value)
	var mood_name = mood_data.get("name", "平静")
	var stat_bonus_rate = GameDataManager.mood_system.get_stat_bonus_rate(profile.mood_value)
	var final_bonus_rate = stat_bonus_rate
	var final_multiplier = 1.0 + final_bonus_rate
	
	var bonus_text = ""
	if final_bonus_rate > 0:
		bonus_text = "收益增加%d%%（来源：%s心情，属性收益 x%.2f）" % [int(final_bonus_rate * 100), mood_name, final_multiplier]
	elif final_bonus_rate < 0:
		bonus_text = "收益减少%d%%（来源：%s心情，属性收益 x%.2f）" % [int(-final_bonus_rate * 100), mood_name, final_multiplier]
	else:
		bonus_text = "无特殊加成（来源：%s心情，属性收益 x%.2f）" % [mood_name, final_multiplier]
	bonus_label.remove_theme_color_override("font_color")
	bonus_label.text = bonus_text
	
	var total_rewards = {}
	var total_gold_cost = 0
	var total_mood_change = 0
	
	for item in scheduled_activities:
		if typeof(item) != TYPE_STRING: continue
		var act = GameDataManager.activity_manager.get_activity_by_id(item)
		if act.is_empty(): continue
		total_gold_cost += act.get("gold_cost", 0)
		total_mood_change += act.get("mood_change", 0)
		
		if act.has("rewards"):
			for key in act.rewards.keys():
				var range_arr = act.rewards[key]
				var avg_val = (range_arr[0] + range_arr[1]) / 2.0
				
				# 应用综合带来的收益加成 (排除体力恢复等非属性增益)
				if key.begins_with("stat_"):
					avg_val = avg_val * (1.0 + final_bonus_rate)
					
				if not total_rewards.has(key):
					total_rewards[key] = 0.0
				total_rewards[key] += avg_val
				
	# 行动力相关的 UI 气泡全部强行隐藏
	if energy_label: energy_label.hide()
	if energy_bubble: energy_bubble.hide()

	var end_mood = clamp(profile.mood_value + total_mood_change, 0, 100)
	var mood_diff = end_mood - profile.mood_value
	var end_mood_info: Dictionary = GameDataManager.mood_system.get_macro_mood(end_mood)
	var end_mood_id: String = str(end_mood_info.get("id", "calm"))
	var end_mood_name: String = str(end_mood_info.get("name", "未知"))
	var end_mood_palette: Dictionary = _get_mood_panel_palette(end_mood_id)
	mood_label.text = "心情 %s" % end_mood_name
	mood_label.add_theme_color_override("font_color", end_mood_palette.get("accent_color", Color(0.68, 0.84, 0.94, 1.0)))
	if mood_diff != 0:
		mood_bubble.show()
		mood_bubble.text = "%+d" % int(mood_diff)
		if mood_diff > 0:
			if _style_bubble: mood_bubble.add_theme_stylebox_override("normal", _style_bubble)
		else:
			if _style_bubble_neg: mood_bubble.add_theme_stylebox_override("normal", _style_bubble_neg)
	else:
		mood_bubble.hide()
		
	if total_gold_cost > 0:
		gold_sep.show()
		gold_label.show()
		gold_label.text = "金钱消耗: %d" % total_gold_cost
	else:
		gold_sep.hide()
		gold_label.hide()
		
	
	# Update core stats
	var start_core_phys = GameDataManager.stats_system.get_core_physical(profile)
	var start_core_int = GameDataManager.stats_system.get_core_intelligence(profile)
	var start_core_charm = GameDataManager.stats_system.get_core_charm(profile)
	var start_core_sens = GameDataManager.stats_system.get_core_sensibility(profile)
	
	var end_core_phys = int(floor((profile.stat_stamina + total_rewards.get("stat_stamina", 0)) + (profile.stat_rhythm + total_rewards.get("stat_rhythm", 0))))
	var end_core_int = int(floor((profile.stat_knowledge + total_rewards.get("stat_knowledge", 0)) + (profile.stat_expression + total_rewards.get("stat_expression", 0))))
	var end_core_charm = int(floor((profile.stat_temperament + total_rewards.get("stat_temperament", 0)) + (profile.stat_etiquette + total_rewards.get("stat_etiquette", 0))))
	var end_core_sens = int(floor((profile.stat_aesthetics + total_rewards.get("stat_aesthetics", 0)) + (profile.stat_perception + total_rewards.get("stat_perception", 0))))
	
	phys_val.text = "%d > %d" % [start_core_phys, end_core_phys]
	if end_core_phys > start_core_phys:
		phys_val.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))
	else:
		phys_val.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		
	int_val.text = "%d > %d" % [start_core_int, end_core_int]
	if end_core_int > start_core_int:
		int_val.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))
	else:
		int_val.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		
	charm_val.text = "%d > %d" % [start_core_charm, end_core_charm]
	if end_core_charm > start_core_charm:
		charm_val.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))
	else:
		charm_val.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		
	sens_val.text = "%d > %d" % [start_core_sens, end_core_sens]
	if end_core_sens > start_core_sens:
		sens_val.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))
	else:
		sens_val.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))

	var start_attrs = {
		"stat_stamina": profile.stat_stamina,
		"stat_rhythm": profile.stat_rhythm,
		"stat_knowledge": profile.stat_knowledge,
		"stat_expression": profile.stat_expression,
		"stat_temperament": profile.stat_temperament,
		"stat_etiquette": profile.stat_etiquette,
		"stat_aesthetics": profile.stat_aesthetics,
		"stat_perception": profile.stat_perception
	}
	
	for key in start_attrs.keys():
		var parent_grid = category_group_map.get(key)
		if not parent_grid: continue
		
		var sub_node = parent_grid.get_node_or_null("Sub_" + key)
		if sub_node:
			var val_lbl = sub_node.get_node("Val")
			var added_val = total_rewards.get(key, 0.0)
			
			if added_val > 0:
				val_lbl.text = "+%d" % int(added_val)
				val_lbl.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))
			else:
				val_lbl.text = "-"
				val_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
				
	# 更新左侧课程列表的进度预览
	var scheduled_counts = {}
	for item in scheduled_activities:
		if typeof(item) == TYPE_STRING:
			if not scheduled_counts.has(item):
				scheduled_counts[item] = 0
			scheduled_counts[item] += 1
			
	if not activities_grid:
		return
	for child in activities_grid.get_children():
		if child.has_method("update_preview"):
			var c_id = child.activity_data.get("id", "")
			child.update_preview(scheduled_counts.get(c_id, 0))

func _get_mood_panel_palette(mood_id: String) -> Dictionary:
	match mood_id:
		"broken":
			return {
				"accent_color": Color(0.93, 0.47, 0.60, 1.0),
				"name_color": Color(1.0, 0.86, 0.90, 1.0),
				"value_color": Color(1.0, 0.78, 0.84, 1.0),
				"hint_color": Color(0.98, 0.84, 0.88, 1.0),
				"bar_color": Color(0.92, 0.36, 0.56, 1.0)
			}
		"low":
			return {
				"accent_color": Color(0.97, 0.67, 0.42, 1.0),
				"name_color": Color(1.0, 0.90, 0.80, 1.0),
				"value_color": Color(1.0, 0.84, 0.70, 1.0),
				"hint_color": Color(0.98, 0.88, 0.78, 1.0),
				"bar_color": Color(0.95, 0.60, 0.30, 1.0)
			}
		"pleasant":
			return {
				"accent_color": Color(0.37, 0.84, 0.64, 1.0),
				"name_color": Color(0.90, 1.0, 0.94, 1.0),
				"value_color": Color(0.82, 0.98, 0.88, 1.0),
				"hint_color": Color(0.86, 0.97, 0.90, 1.0),
				"bar_color": Color(0.31, 0.82, 0.58, 1.0)
			}
		"ecstatic":
			return {
				"accent_color": Color(0.42, 0.74, 1.0, 1.0),
				"name_color": Color(0.87, 0.94, 1.0, 1.0),
				"value_color": Color(0.78, 0.89, 1.0, 1.0),
				"hint_color": Color(0.84, 0.92, 1.0, 1.0),
				"bar_color": Color(0.29, 0.63, 1.0, 1.0)
			}
		_:
			return {
				"accent_color": Color(0.68, 0.84, 0.94, 1.0),
				"name_color": Color(0.96, 0.98, 1.0, 1.0),
				"value_color": Color(0.84, 0.92, 0.97, 1.0),
				"hint_color": Color(0.88, 0.93, 0.96, 1.0),
				"bar_color": Color(0.55, 0.79, 0.76, 1.0)
			}

func _on_activity_pressed(activity_id: String) -> void:
	if not _is_guide_interaction_allowed("activity.activity_list"):
		_notify_guide_interaction_blocked()
		return
	for i in range(MAX_SLOTS):
		if scheduled_activities[i] == null:
			scheduled_activities[i] = activity_id
			_update_ui()
			_report_guide_action("activity_add_course", {
				"activity_id": activity_id,
				"slot_index": i
			})
			return

func _on_slot_pressed(index: int) -> void:
	if index < 0 or index >= scheduled_activities.size():
		return
	var slots := _get_all_slot_buttons()
	var clicked_slot := slots[index] as Button if index < slots.size() else null
	var is_main_event_slot := clicked_slot != null and bool(clicked_slot.get_meta("is_main_event_slot", false))
	var item = scheduled_activities[index]
	if is_main_event_slot or (typeof(item) == TYPE_DICTIONARY and item.get("type") == "event"):
		if not _is_guide_interaction_allowed("activity.main_event_slot"):
			_notify_guide_interaction_blocked()
			return
		_report_guide_action("activity_click_main_event_slot", {
			"slot_index": index
		})

func _on_place_into_pressed() -> void:
	if not _is_guide_interaction_allowed("activity.schedule_controls"):
		_notify_guide_interaction_blocked()
		return

	var auto_plan: Array = _build_auto_schedule_plan()
	if auto_plan.is_empty():
		ToastManager.show_system_toast("当前没有可自动安排的课程")
		return

	for i in range(MAX_SLOTS):
		if typeof(scheduled_activities[i]) == TYPE_STRING or scheduled_activities[i] == null:
			scheduled_activities[i] = auto_plan[i]

	_update_ui()
	ToastManager.show_system_toast("已为你生成一套推荐行程")

func _build_auto_schedule_plan() -> Array:
	var result: Array = scheduled_activities.duplicate(true)
	var profile = GameDataManager.profile
	if profile == null:
		return []

	var remaining_gold: int = int(profile.gold)
	var simulated_progress: Dictionary = profile.course_progress.duplicate(true)
	var mood_bonus_rate: float = GameDataManager.mood_system.get_stat_bonus_rate(profile.mood_value)

	for item in result:
		if typeof(item) != TYPE_STRING:
			continue
		var existing_act: Dictionary = GameDataManager.activity_manager.get_activity_by_id(item)
		if existing_act.is_empty():
			continue
		remaining_gold -= int(existing_act.get("gold_cost", 0))
		var existing_id := str(existing_act.get("id", "")).strip_edges()
		if existing_id != "":
			simulated_progress[existing_id] = int(simulated_progress.get(existing_id, 0)) + int(existing_act.get("progress_increment", 0))

	if remaining_gold < 0:
		remaining_gold = 0

	var filled_any: bool = false
	for slot_index in range(MAX_SLOTS):
		if typeof(result[slot_index]) == TYPE_DICTIONARY and result[slot_index].get("type") == "event":
			continue

		var best_activity: Dictionary = _pick_best_activity_for_auto_plan(simulated_progress, remaining_gold, mood_bonus_rate)
		if best_activity.is_empty():
			if result[slot_index] == null:
				break
			result[slot_index] = null
			continue

		var best_id := str(best_activity.get("id", "")).strip_edges()
		result[slot_index] = best_id
		filled_any = true
		remaining_gold -= int(best_activity.get("gold_cost", 0))
		simulated_progress[best_id] = int(simulated_progress.get(best_id, 0)) + int(best_activity.get("progress_increment", 0))

	if not filled_any:
		return []
	return result

func _pick_best_activity_for_auto_plan(simulated_progress: Dictionary, remaining_gold: int, mood_bonus_rate: float) -> Dictionary:
	var best_activity: Dictionary = {}
	var best_score: float = -INF

	for act in GameDataManager.activity_manager.activities:
		if not _can_auto_schedule_activity(act, simulated_progress, remaining_gold):
			continue
		var score := _score_activity_for_auto_plan(act, mood_bonus_rate)
		if score > best_score:
			best_score = score
			best_activity = act

	return best_activity

func _can_auto_schedule_activity(act: Dictionary, simulated_progress: Dictionary, remaining_gold: int) -> bool:
	if act.is_empty():
		return false
	var activity_id := str(act.get("id", "")).strip_edges()
	if activity_id == "":
		return false

	var gold_cost: int = int(act.get("gold_cost", 0))
	if gold_cost > remaining_gold:
		return false

	var max_progress: int = int(act.get("max_progress", 0))
	if max_progress > 0:
		var current_progress: int = int(simulated_progress.get(activity_id, 0))
		if current_progress >= max_progress:
			return false

	return true

func _score_activity_for_auto_plan(act: Dictionary, mood_bonus_rate: float) -> float:
	var stat_score: float = 0.0
	var rewards: Dictionary = act.get("rewards", {})
	for stat_key in rewards.keys():
		var reward_range: Variant = rewards.get(stat_key, [])
		if reward_range is Array and reward_range.size() >= 2:
			var min_val: float = float(reward_range[0])
			var max_val: float = float(reward_range[1])
			var average_gain: float = (min_val + max_val) * 0.5
			if String(stat_key).begins_with("stat_"):
				average_gain *= (1.0 + mood_bonus_rate)
			stat_score += average_gain

	var progress_value: float = float(act.get("progress_increment", 0)) * 0.35
	var mood_change: float = float(act.get("mood_change", 0))
	var mood_value: float = 0.0
	if mood_change > 0.0:
		mood_value = mood_change * 0.65
	elif mood_change < 0.0:
		mood_value = mood_change * 0.15

	var gold_penalty: float = float(act.get("gold_cost", 0)) * 0.6
	return stat_score + progress_value + mood_value - gold_penalty

func _on_right_panel_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if is_instance_valid(execute_button) and execute_button.get_global_rect().has_point(mouse_event.global_position):
				return
			if not _is_guide_interaction_allowed("activity.preview_panel"):
				return
			_report_guide_action("activity_click_preview_panel")

func _on_execute_button_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	if execute_button.disabled:
		return
	var guide_manager := _get_guide_manager()
	if guide_manager and guide_manager.has_method("get_current_step_id"):
		var current_step_id := str(guide_manager.get_current_step_id()).strip_edges()
		if current_step_id == "explain_schedule_preview":
			if guide_manager.has_method("report_action"):
				guide_manager.report_action("activity_click_preview_panel")
			accept_event()
			return
	_on_execute_pressed()

func _on_undo_pressed() -> void:
	if not _is_guide_interaction_allowed("activity.schedule_controls"):
		_notify_guide_interaction_blocked()
		return
	for i in range(MAX_SLOTS - 1, -1, -1):
		if typeof(scheduled_activities[i]) == TYPE_STRING:
			scheduled_activities[i] = null
			_update_ui()
			return

func _on_clear_pressed() -> void:
	if not _is_guide_interaction_allowed("activity.schedule_controls"):
		_notify_guide_interaction_blocked()
		return
	for i in range(MAX_SLOTS):
		if typeof(scheduled_activities[i]) == TYPE_STRING:
			scheduled_activities[i] = null
	_update_ui()

func _on_execute_pressed() -> void:
	var current_frame := Engine.get_process_frames()
	if _last_execute_press_frame == current_frame:
		return
	_last_execute_press_frame = current_frame
	if not _is_guide_interaction_allowed("activity.execute_button"):
		_notify_guide_interaction_blocked()
		return
	var scheduled_count = 0
	for item in scheduled_activities:
		if item != null:
			scheduled_count += 1
			
	if scheduled_count < MAX_SLOTS:
		ToastManager.show_system_toast("请先排满 %d 项行程" % MAX_SLOTS)
		return
		
	var profile = GameDataManager.profile
	var total_gold_cost = 0
	
	for item in scheduled_activities:
		if typeof(item) == TYPE_STRING:
			var act = GameDataManager.activity_manager.get_activity_by_id(item)
			if not act.is_empty():
				total_gold_cost += act.get("gold_cost", 0)
				
	if profile.gold < total_gold_cost:
		ToastManager.show_system_toast("金币不足，无法执行计划")
		return
	_report_guide_action("activity_execute_schedule")
		
	var courses_data: Array = []
	
	for item in scheduled_activities:
		if typeof(item) == TYPE_DICTIONARY and item.get("type") == "event":
			var event_entries: Array = item.get("event_entries", [])
			var primary_entry: Dictionary = event_entries[0] if event_entries.size() > 0 else {}
			var cover_path := str(primary_entry.get("image_path", "")).strip_edges()
			var summary := str(primary_entry.get("summary", "推进主线剧情...")).strip_edges()
			var script_path := str(primary_entry.get("script_path", "")).strip_edges()
			var period := str(primary_entry.get("period", "")).strip_edges()
			var event_count := event_entries.size()
			if event_count > 1:
				summary = "当日共有 %d 段固定剧情会依次触发。\n%s" % [event_count, summary]
			
			courses_data.append({
				"name": "主线事件",
				"image_path": cover_path,
				"icon_path": "res://assets/images/icons/ui/main/diary_book.svg",
				"bonus_list": [],
				"desc": summary,
				"is_event": true,
				"events": item.get("events", []),
				"period": period,
				"script_path": script_path,
				"event_entries": event_entries
			})
		elif typeof(item) == TYPE_STRING:
			var act = GameDataManager.activity_manager.get_activity_by_id(item)
			var single_course = {
				"id": act.get("id", ""),
				"name": act.get("name", "未知课程"),
				"category_id": act.get("category_id", ""),
				"category_name": _get_category_by_name(act.get("category_id", "")).get("name", ""),
				"image_path": act.get("preview_image", ""),
				"icon_path": act.get("icon_path", ""),
				"bonus_list": [],
				"rewards": act.get("rewards", {}),
				"desc": "正在生成描述中...",
				"progress_increment": act.get("progress_increment", 0),
				"max_progress": act.get("max_progress", 0)
			}
			
			if act.has("rewards"):
				for stat_key in act["rewards"]:
					var range_arr = act["rewards"][stat_key]
					var avg_val = (range_arr[0] + range_arr[1]) / 2.0
					
					var zh_name = stat_name_map.get(stat_key, stat_key)
					single_course["bonus_list"].append({"name": zh_name, "value": avg_val})
			
			courses_data.append(single_course)
	
	main_panel.hide()
	if _activity_loading_overlay:
		_activity_loading_overlay.show_for_context(_build_execution_loading_context(courses_data))

	_fetch_all_course_descriptions_from_ai(courses_data)
	
	var profile_for_exec = GameDataManager.profile
	var start_attrs = {
		"体能": profile_for_exec.stat_stamina,
		"反应": profile_for_exec.stat_rhythm,
		"学识": profile_for_exec.stat_knowledge,
		"表达": profile_for_exec.stat_expression,
		"气质": profile_for_exec.stat_temperament,
		"礼仪": profile_for_exec.stat_etiquette,
		"审美": profile_for_exec.stat_aesthetics,
		"感知": profile_for_exec.stat_perception,
		"金币": profile_for_exec.gold,
		"心情": profile_for_exec.mood_value
	}
	var end_attrs = start_attrs.duplicate()
	
	var stat_bonus_rate = GameDataManager.mood_system.get_stat_bonus_rate(profile_for_exec.mood_value)
	var final_bonus_rate = stat_bonus_rate
	
	for item in scheduled_activities:
		if typeof(item) == TYPE_STRING:
			var act = GameDataManager.activity_manager.get_activity_by_id(item)
			if act.is_empty(): continue
			end_attrs["金币"] -= act.get("gold_cost", 0)
			end_attrs["心情"] += act.get("mood_change", 0)
	
	for course in courses_data:
		for bonus in course["bonus_list"]:
			var zh_name = bonus["name"]
			var val = bonus["value"]
			if not end_attrs.has(zh_name):
				end_attrs[zh_name] = start_attrs.get(zh_name, 0)
			end_attrs[zh_name] += (val * (1.0 + final_bonus_rate))
				
	end_attrs["心情"] = clamp(end_attrs["心情"], 0, 100)
	end_attrs["金币"] = max(0, end_attrs["金币"])
			
	_pending_exec_data = {
		"courses_data": courses_data,
		"start_attrs": start_attrs,
		"end_attrs": end_attrs
	}
	
	for i in range(MAX_SLOTS):
		if typeof(scheduled_activities[i]) == TYPE_STRING:
			scheduled_activities[i] = null

func _fetch_all_course_descriptions_from_ai(courses_data: Array) -> void:
	var api_key = ""
	if GameDataManager.config != null:
		api_key = GameDataManager.config.api_key
		
	if api_key.is_empty():
		_fallback_all_descriptions()
		return
		
	var http = HTTPRequest.new()
	http.timeout = 10.0
	add_child(http)
	http.request_completed.connect(func(res, code, hdrs, body): _on_all_ai_descriptions_completed(res, code, hdrs, body, http))
	
	var url = "https://api.deepseek.com/v1/chat/completions" 
	if "api_url" in GameDataManager.config and not GameDataManager.config.api_url.is_empty():
		url = GameDataManager.config.api_url
		
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer " + api_key
	]
	
	var course_list_str = ""
	for i in range(courses_data.size()):
		if courses_data[i].get("is_event", false):
			var p = courses_data[i].get("period", "")
			if p != "":
				course_list_str += "%d. 【特殊事件 - %s】\n" % [i + 1, p]
			else:
				course_list_str += "%d. 【特殊事件】\n" % [i + 1]
		else:
			course_list_str += "%d. 【%s】\n" % [i + 1, courses_data[i]["name"]]
		
	var profile = GameDataManager.profile
	var char_name = profile.char_name if profile else "角色"
		
	var prompt = "这里有一份本周的学习计划，共 %d 节课（包含休息）。请你作为旁白（第三人称视角），针对这 %d 节课依次生成一段 20 到 50 字以内、生动形象的文字，描述 %s 正在进行该课程时的画面和状态。注意必须严格按顺序，用一个 JSON 数组返回。格式要求如下：\n" % [MAX_SLOTS, MAX_SLOTS, char_name]
	prompt += "```json\n[\n  \"(针对第1节课的描述)\",\n  \"(针对第2节课的描述)\",\n  ... (共%d个元素)\n]\n```\n" % MAX_SLOTS
	prompt += "以下是这周的课程列表：\n" + course_list_str
	
	var chat_model_id := "deepseek-chat"
	if GameDataManager.config and "model" in GameDataManager.config:
		var configured_model := str(GameDataManager.config.model).strip_edges()
		if configured_model != "" and not configured_model.begins_with("doubao"):
			chat_model_id = configured_model
	var body = {
		"model": chat_model_id,
		"messages": [{"role": "user", "content": prompt}],
		"temperature": 0.7
	}
	
	var err = http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		_fallback_all_descriptions()

func _finish_loading_and_open() -> void:
	if _activity_loading_overlay:
		await _activity_loading_overlay.complete(
			"Luna 已经准备好了，本周安排即将开始...",
			"本周课程节奏已经整理完成..."
		)
	_open_execution_panel()

func _on_all_ai_descriptions_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest) -> void:
	http.queue_free()
	
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_fallback_all_descriptions()
		return
		
	var json = JSON.parse_string(body.get_string_from_utf8())
	if json and json.has("choices") and json["choices"].size() > 0:
		var text = json["choices"][0]["message"]["content"].strip_edges()
		var parsed_array = _parse_ai_description_array(text)
		
		if parsed_array is Array and parsed_array.size() >= 1:
			var courses = _pending_exec_data["courses_data"]
			for i in range(min(parsed_array.size(), courses.size())):
				if courses[i].get("is_event", false):
					continue
				var desc_str = str(parsed_array[i]).strip_edges()
				desc_str = desc_str.replace("\"", "").replace("'", "").replace("“", "").replace("”", "")
				if desc_str != "":
					courses[i]["desc"] = desc_str
			_finish_loading_and_open()
			return
			
	_fallback_all_descriptions()

func _extract_json_array(text: String) -> String:
	var start = text.find("[")
	var end = text.rfind("]")
	if start != -1 and end != -1 and end > start:
		return text.substr(start, end - start + 1)
	return "[]"

func _parse_ai_description_array(text: String) -> Array:
	var extracted_json_str := _extract_json_array(text)
	var strict_result: Variant = JSON.parse_string(extracted_json_str)
	if strict_result is Array:
		return strict_result as Array
	var fallback_items: Array = []
	var normalized_text := extracted_json_str.replace("\r\n", "\n").replace("\r", "\n").strip_edges()
	if normalized_text.begins_with("["):
		normalized_text = normalized_text.substr(1)
	if normalized_text.ends_with("]"):
		normalized_text = normalized_text.substr(0, normalized_text.length() - 1)
	for raw_line in normalized_text.split("\n", false):
		var line := str(raw_line).strip_edges()
		if line == "":
			continue
		if line.ends_with(","):
			line = line.substr(0, line.length() - 1).strip_edges()
		line = _strip_wrapping_quotes(line)
		line = line.replace("\\n", " ").replace("\\\"", "\"").replace("\\'", "'").strip_edges()
		if line != "":
			fallback_items.append(line)
	return fallback_items

func _strip_wrapping_quotes(text: String) -> String:
	var normalized := text.strip_edges()
	if normalized.length() < 2:
		return normalized
	var quote_pairs := [
		['"', '"'],
		["'", "'"],
		["“", "”"],
		["‘", "’"],
		["「", "」"],
		["『", "』"]
	]
	for pair in quote_pairs:
		var start_quote := str(pair[0])
		var end_quote := str(pair[1])
		if normalized.begins_with(start_quote) and normalized.ends_with(end_quote):
			return normalized.substr(start_quote.length(), normalized.length() - start_quote.length() - end_quote.length()).strip_edges()
	return normalized

func _fallback_all_descriptions() -> void:
	if _pending_exec_data.is_empty(): return
	var courses = _pending_exec_data["courses_data"]
	for course in courses:
		if course.get("is_event", false):
			# 保留预先读取的剧情简述
			continue
			
		var c_name = course["name"]
		if "休息" in c_name:
			course["desc"] = "今天给自己放了个假，彻底放松下来，调整了状态。"
		else:
			course["desc"] = "今天也是按部就班地完成了【%s】的训练，感觉收获颇丰。" % c_name
			
	_finish_loading_and_open()


func _ensure_activity_loading_overlay() -> void:
	if _activity_loading_overlay != null:
		return
	_activity_loading_overlay = ActivityLoadingOverlayScene.instantiate()
	add_child(_activity_loading_overlay)
	_activity_loading_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_activity_loading_overlay.z_index = 120


func _build_execution_loading_context(courses_data: Array) -> Dictionary:
	var summary_lines: Array[String] = []
	var phase_1_tips: Array[String] = [
		"Luna 正在整理这周的课程顺序...",
		"Luna 正在把这一周的安排慢慢排开..."
	]
	var phase_2_tips: Array[String] = [
		"Luna 正在确认每天该如何分配状态...",
		"Luna 正在衡量这周课程之间的节奏..."
	]
	var phase_3_tips: Array[String] = [
		"Luna 正在给这一周做出门前的准备...",
		"Luna 已经快把这周安排整理好了..."
	]
	var category_names: Array[String] = []
	var has_main_event: bool = false

	for i in range(courses_data.size()):
		var course: Dictionary = courses_data[i]
		var course_name := str(course.get("name", "未知课程")).strip_edges()
		var category_name := str(course.get("category_name", "")).strip_edges()
		if bool(course.get("is_event", false)):
			has_main_event = true
		if course_name != "":
			summary_lines.append("%d. %s" % [i + 1, course_name])
			if i == 0:
				phase_1_tips.append("Luna 正在想，这周要先从「%s」进入状态..." % course_name)
			elif i == courses_data.size() - 1:
				phase_3_tips.append("Luna 正在把最后一项「%s」也记进这周安排里..." % course_name)
		if category_name != "" and not category_names.has(category_name):
			category_names.append(category_name)

	if not category_names.is_empty():
		phase_2_tips.append("Luna 正在想着，这周要在 %s 之间切换节奏..." % " / ".join(category_names))
	if has_main_event:
		phase_3_tips.append("Luna 正在把这周的重要事件也一起记在心里...")

	var summary_text := "\n".join(summary_lines)
	var hint_text := "这周的课程安排正在慢慢展开..."
	if not category_names.is_empty():
		hint_text = "本周会接触：%s" % " / ".join(category_names)

	return {
		"title": "课程安排执行中",
		"kicker": "Luna 正在开始本周安排",
		"status": phase_1_tips[0],
		"summary": summary_text,
		"hint": hint_text,
		"visual_caption": "本周安排",
		"tips": phase_1_tips + phase_2_tips + phase_3_tips,
		"phased_tips": [
			{
				"until": 35.0,
				"tips": phase_1_tips
			},
			{
				"until": 70.0,
				"tips": phase_2_tips
			},
			{
				"until": 90.0,
				"tips": phase_3_tips
			}
		],
		"progress_duration": 5.0,
		"min_duration": 1.1,
		"progress_cap": 90.0,
		"tip_interval": 1.15
	}

func _open_execution_panel() -> void:
	if _pending_exec_data.is_empty():
		return
		
	var main_scene = get_tree().current_scene
	var exec_panel_obj = load("res://scenes/ui/activity/schedule_execution_panel.tscn")
	var exec_panel = exec_panel_obj.instantiate()
	main_scene.add_child(exec_panel)
	exec_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var guide_manager := _get_guide_manager()
	if guide_manager and guide_manager.has_method("on_schedule_execution_panel_ready"):
		guide_manager.on_schedule_execution_panel_ready(exec_panel)
	
	exec_panel.setup(
		_pending_exec_data["courses_data"],
		_pending_exec_data["start_attrs"],
		_pending_exec_data["end_attrs"]
	)
	
	_pending_exec_data.clear()
	hide()

func _on_close_pressed() -> void:
	if not _is_guide_interaction_allowed("activity.close"):
		_notify_guide_interaction_blocked()
		return
	hide_panel()

func get_first_activity_item() -> Control:
	for child in activities_grid.get_children():
		if child is Control:
			return child
	return null

func get_category_tabs_focus_rect() -> Variant:
	var rect: Rect2 = _get_container_children_focus_rect(category_tabs)
	if rect.size.x <= 1.0 or rect.size.y <= 1.0:
		rect = _get_controls_focus_rect(_category_tab_buttons.values())
	if rect.size.x <= 1.0 or rect.size.y <= 1.0:
		rect = _get_control_focus_rect(category_tabs)
	if rect.size.x <= 1.0 or rect.size.y <= 1.0:
		return Rect2()
	return _make_focus_entry(rect, 16.0)

func get_activity_list_focus_rect() -> Variant:
	var item_rects: Array[Rect2] = []
	for child in activities_grid.get_children():
		if child is Control:
			var child_rect: Rect2 = _get_control_focus_rect(child as Control)
			if child_rect.size.x > 1.0 and child_rect.size.y > 1.0:
				item_rects.append(child_rect)
	var rect: Rect2 = _merge_rects(item_rects)
	if rect.size.x <= 1.0 or rect.size.y <= 1.0:
		rect = _get_control_focus_rect(activities_scroll)
	if rect.size.x <= 1.0 or rect.size.y <= 1.0:
		rect = _get_control_focus_rect(category_content_margin)
	if rect.size.x <= 1.0 or rect.size.y <= 1.0:
		rect = _get_control_focus_rect(category_content_card)
	if rect.size.x <= 1.0 or rect.size.y <= 1.0:
		return Rect2()
	return _make_focus_entry(rect, 18.0)

func get_tabs_and_list_focus_rect() -> Array:
	return [
		get_category_tabs_focus_rect(),
		get_activity_list_focus_rect()
	]

func get_schedule_slots_focus_rect() -> Variant:
	var slot_rect: Rect2 = _get_control_focus_rect(schedule_slots.get_node_or_null("MorningRow") as Control)
	if slot_rect.size.x > 1.0 and slot_rect.size.y > 1.0:
		return _make_focus_entry(slot_rect, 16.0)
	var fallback_rect := _get_control_focus_rect(schedule_slots)
	if fallback_rect.size.x <= 1.0 or fallback_rect.size.y <= 1.0:
		return Rect2()
	return _make_focus_entry(fallback_rect, 16.0)

func get_preview_panel_focus_data() -> Variant:
	var rect: Rect2 = _get_control_focus_rect(right_panel)
	if rect.size.x <= 1.0 or rect.size.y <= 1.0:
		return Rect2()
	return _make_focus_entry(rect, 18.0)

func get_execute_button_focus_data() -> Variant:
	var rect: Rect2 = _get_control_focus_rect(execute_button)
	if rect.size.x <= 1.0 or rect.size.y <= 1.0:
		return Rect2()
	return _make_focus_entry(rect, 12.0)

func get_main_event_slot_button() -> Control:
	var slots := _get_all_slot_buttons()
	for i in range(mini(slots.size(), scheduled_activities.size())):
		var slot_button := slots[i] as Button
		if slot_button != null and bool(slot_button.get_meta("is_main_event_slot", false)):
			return slot_button
		var item = scheduled_activities[i]
		if typeof(item) == TYPE_DICTIONARY and item.get("type") == "event":
			return slots[i] as Control
	return null

func get_user_selected_course_count() -> int:
	var count := 0
	for item in scheduled_activities:
		if typeof(item) == TYPE_STRING:
			count += 1
	return count

func get_total_scheduled_count() -> int:
	var count := 0
	for item in scheduled_activities:
		if item != null:
			count += 1
	return count
