extends CanvasLayer

signal closing_started

@onready var close_btn: Button = $MenuPanel/CloseBtn
@onready var course_vbox: VBoxContainer = $MenuPanel/ContentHBox/LeftPanel/CourseListPanel/ListMargin/ScrollContainer/CourseVBox
@onready var detail_title: Label = $MenuPanel/ContentHBox/RightPanel/DetailPanel/Margin/VBox/DetailTitle
@onready var detail_meta_label: Label = $MenuPanel/ContentHBox/RightPanel/DetailPanel/Margin/VBox/DetailMetaLabel
@onready var desc_label: RichTextLabel = $MenuPanel/ContentHBox/RightPanel/DetailPanel/Margin/VBox/DescLabel
@onready var preview_label: RichTextLabel = $MenuPanel/ContentHBox/RightPanel/DetailPanel/Margin/VBox/PreviewLabel
@onready var warning_label: Label = $MenuPanel/ContentHBox/RightPanel/DetailPanel/Margin/VBox/WarningLabel
@onready var cost_label: Label = $MenuPanel/ContentHBox/RightPanel/DetailPanel/Margin/VBox/CostLabel
@onready var start_btn: Button = $MenuPanel/ContentHBox/RightPanel/ActionHBox/StartBtn
@onready var reset_btn: Button = $MenuPanel/ContentHBox/RightPanel/ActionHBox/ResetBtn

var _activities_data: Array = []
var _course_buttons: Dictionary = {}
var _planned_counts: Dictionary = {} # Key: course_id, Value: planned times
var _guide_targets_ready: bool = false

const CourseItemScene = preload("res://scenes/ui/map/library/tutoring_course_item.tscn")
const MINUTES_PER_COURSE := 60
const MAX_TUTORING_COUNT_PER_SESSION := 5
const TUTORING_ENERGY_MULTIPLIER := 2

# 属性名映射
const STAT_NAME_MAP = {
	"stat_stamina": "体能",
	"stat_rhythm": "反应",
	"stat_knowledge": "学识",
	"stat_expression": "表达",
	"stat_temperament": "气质",
	"stat_etiquette": "礼仪",
	"stat_aesthetics": "审美",
	"stat_perception": "感知"
}

func _ready() -> void:
	$MenuPanel.modulate.a = 0.0
	var opening_tween := create_tween()
	opening_tween.tween_property($MenuPanel, "modulate:a", 1.0, 0.3)
	opening_tween.finished.connect(_on_tutoring_opening_finished, CONNECT_ONE_SHOT)
	
	close_btn.pressed.connect(_on_close_pressed)
	start_btn.pressed.connect(_on_start_pressed)
	reset_btn.pressed.connect(_on_reset_pressed)
	var guide_manager = get_node_or_null("/root/GuideManager")
	if guide_manager and guide_manager.has_method("on_tutoring_panel_ready"):
		guide_manager.on_tutoring_panel_ready(self)
	var detail_panel := get_guide_target("detail_panel") as Control
	if detail_panel and not detail_panel.gui_input.is_connected(_on_detail_panel_gui_input):
		detail_panel.gui_input.connect(_on_detail_panel_gui_input)
	
	_load_activities()
	_refresh_ui()

func _on_tutoring_opening_finished() -> void:
	_guide_targets_ready = true
	var guide_manager = get_node_or_null("/root/GuideManager")
	if guide_manager and guide_manager.has_method("on_tutoring_panel_ready"):
		guide_manager.on_tutoring_panel_ready(self)

func is_guide_target_ready() -> bool:
	return _guide_targets_ready

func _load_activities() -> void:
	var path = "res://assets/data/interaction/activity/activities.json"
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			var data = json.get_data()
			if data is Dictionary and data.has("activities"):
				_activities_data = data["activities"]

func _get_course_by_id(c_id: String) -> Dictionary:
	for course in _activities_data:
		if course.get("id", "") == c_id:
			return course
	return {}

func _get_course_energy_cost(course: Dictionary) -> int:
	var increment = int(course.get("progress_increment", 0))
	return max(1, int(ceil(float(increment) / 5.0))) * TUTORING_ENERGY_MULTIPLIER

func _refresh_ui() -> void:
	var profile = GameDataManager.profile
	_planned_counts.clear()
	
	_course_buttons.clear()
	for child in course_vbox.get_children():
		child.queue_free()
		
	var has_available = false
	for course in _activities_data:
		var c_id = course.get("id", "")
		if course.get("category_id", "") == "rest":
			continue
			
		var max_prog = course.get("max_progress", 0)
		if max_prog <= 0:
			continue
			
		var cur_prog = profile.course_progress.get(c_id, 0)
		if cur_prog < max_prog:
			has_available = true
			var item = CourseItemScene.instantiate()
			course_vbox.add_child(item)
			item.setup(course, cur_prog, max_prog)
			item.course_clicked.connect(_on_course_clicked)
			_course_buttons[c_id] = item
			
	if not has_available:
		var empty_label = Label.new()
		empty_label.text = "所有课业均已完成\n今天已经没有需要补的内容了。"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_font_size_override("font_size", 18)
		empty_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_label.custom_minimum_size = Vector2(0, 180)
		course_vbox.add_child(empty_label)
		
	_update_right_panel()

func _on_course_clicked(course: Dictionary) -> void:
	var profile = GameDataManager.profile
	var c_id = course.get("id", "")
	var increment = int(course.get("progress_increment", 0))
	var single_cost = _get_course_energy_cost(course)
	var max_prog = course.get("max_progress", 100)
	var cur_prog = profile.course_progress.get(c_id, 0)
	
	var planned_count = _planned_counts.get(c_id, 0)
	
	# 检查满级限制 (如果再点一次就超过或者等于 max_prog 且之前已经满了，拦截)
	if cur_prog + planned_count * increment >= max_prog:
		_show_warning("该课程进度已满！")
		return
		
	if _get_total_planned_count() >= MAX_TUTORING_COUNT_PER_SESSION:
		_show_warning("一次最多安排 %d 次指导。" % MAX_TUTORING_COUNT_PER_SESSION)
		return

	var prospective_count := _get_total_planned_count() + 1
	var prospective_cost: int = _get_total_planned_cost() + int(single_cost)
	var prospective_minutes: int = prospective_count * MINUTES_PER_COURSE
	var unavailable := _get_unavailable_reason(prospective_cost, prospective_minutes)
	if not unavailable.is_empty():
		_show_warning(_format_unavailable_reason(unavailable))
		return
		
	# 隐藏警告
	warning_label.text = ""
		
	# 增加计划次数
	_planned_counts[c_id] = planned_count + 1
	
	# 局部更新左侧按钮 UI
	_update_course_button_visuals(c_id)
	
	# 整体更新右侧面板 UI
	_update_right_panel()
	if _get_total_planned_count() >= MAX_TUTORING_COUNT_PER_SESSION:
		_report_guide_action("tutoring_schedule_full", {"count": _get_total_planned_count()})

func _update_course_button_visuals(c_id: String) -> void:
	if not _course_buttons.has(c_id): return
	var item = _course_buttons[c_id]
	var planned_count = _planned_counts.get(c_id, 0)
	item.update_state(planned_count)

func _get_total_planned_cost() -> int:
	var total = 0
	for c_id in _planned_counts.keys():
		var course = _get_course_by_id(c_id)
		total += _get_course_energy_cost(course) * _planned_counts[c_id]
	return total

func _get_total_planned_count() -> int:
	var total := 0
	for count_value in _planned_counts.values():
		total += int(count_value)
	return total

func _get_total_planned_minutes() -> int:
	return _get_total_planned_count() * MINUTES_PER_COURSE

func _get_unavailable_reason(energy_cost: int, time_cost: int) -> Dictionary:
	if GameDataManager.interaction_manager:
		return GameDataManager.interaction_manager.get_cost_unavailable_reason(energy_cost, 0, time_cost)
	if GameDataManager.profile.current_energy < energy_cost:
		return {"reason": "energy", "required": energy_cost, "available": int(GameDataManager.profile.current_energy)}
	return {}

func _format_unavailable_reason(unavailable: Dictionary) -> String:
	match str(unavailable.get("reason", "")):
		"energy":
			return "行动力不足：安排后共需 %d 点，当前只有 %d 点。" % [int(unavailable.get("required", 0)), int(unavailable.get("available", 0))]
		"late":
			return "时间不足：所选课程共需 %d 分钟，无法在 23:00 前完成。" % int(unavailable.get("required_minutes", 0))
	return "当前无法追加这门课程。"

func _update_right_panel() -> void:
	var profile = GameDataManager.profile
	var total_cost = _get_total_planned_cost()
	var total_minutes := _get_total_planned_minutes()
	var remaining_energy = profile.current_energy - total_cost
	
	var is_empty = _planned_counts.is_empty()
	start_btn.disabled = is_empty
	reset_btn.disabled = is_empty
	
	if is_empty:
		detail_title.text = "课业指导安排"
		detail_meta_label.text = "当前行动力 %d / %d" % [profile.current_energy, profile.max_energy]
		desc_label.text = "点击左侧课程可追加指导次数。\n支持重复安排或组合多门课程。"
		cost_label.text = "安排后将自动结算行动力消耗"
		preview_label.text = ""
		return
		
	# 生成汇总信息
	var aggregate_rewards = {}
	var courses_summary = ""
	var total_count := 0
	
	for c_id in _planned_counts.keys():
		var count = _planned_counts[c_id]
		total_count += count
		var course = _get_course_by_id(c_id)
		courses_summary += "• %s  x%d\n" % [course.get("name", ""), count]
		
		var rewards = course.get("rewards", {})
		for stat_key in rewards.keys():
			var val = rewards[stat_key]
			if not aggregate_rewards.has(stat_key):
				aggregate_rewards[stat_key] = [0, 0] # [min_total, max_total]
				
			if val is Array and val.size() >= 2:
				aggregate_rewards[stat_key][0] += val[0] * count
				aggregate_rewards[stat_key][1] += val[1] * count
			else:
				aggregate_rewards[stat_key][0] += int(val) * count
				aggregate_rewards[stat_key][1] += int(val) * count

	detail_title.text = "指导安排确认"
	detail_meta_label.text = "已安排 %d 次指导，涉及 %d 门课程，共需 %d 分钟" % [total_count, _planned_counts.size(), total_minutes]
	desc_label.text = courses_summary
	cost_label.text = "预计消耗：%d 行动力、%d 分钟   |   剩余行动力：%d / %d" % [total_cost, total_minutes, remaining_energy, profile.max_energy]
	
	var preview_str = "属性提升预览\n"
	if aggregate_rewards.size() > 0:
		for stat_key in aggregate_rewards.keys():
			var stat_name = STAT_NAME_MAP.get(stat_key, stat_key)
			var min_val = aggregate_rewards[stat_key][0]
			var max_val = aggregate_rewards[stat_key][1]
			
			if min_val == max_val:
				preview_str += "• %s：+%d\n" % [stat_name, min_val]
			else:
				preview_str += "• %s：+%d ~ %d\n" % [stat_name, min_val, max_val]
	else:
		preview_str += "暂无额外属性提升"
		
	preview_label.text = preview_str

func _on_reset_pressed() -> void:
	_planned_counts.clear()
	for c_id in _course_buttons.keys():
		_update_course_button_visuals(c_id)
	_update_right_panel()

func _show_warning(msg: String) -> void:
	warning_label.text = msg
	
	# 添加简单的震动动画
	var tween = create_tween()
	warning_label.position.x = 0
	tween.tween_property(warning_label, "position:x", 5, 0.05)
	tween.tween_property(warning_label, "position:x", -5, 0.05)
	tween.tween_property(warning_label, "position:x", 5, 0.05)
	tween.tween_property(warning_label, "position:x", 0, 0.05)
	
	# 2秒后自动消失
	var fade_tween = create_tween()
	fade_tween.tween_interval(2.0)
	fade_tween.tween_callback(func(): warning_label.text = "")

func _on_start_pressed() -> void:
	if _planned_counts.is_empty():
		return
		
	var profile = GameDataManager.profile
	var total_cost = _get_total_planned_cost()
	var total_minutes := _get_total_planned_minutes()
	var unavailable := _get_unavailable_reason(total_cost, total_minutes)
	if not unavailable.is_empty():
		_show_warning(_format_unavailable_reason(unavailable))
		return
		
	if not profile.consume_energy(total_cost):
		_show_warning("行动力不足！")
		return
	_report_guide_action("tutoring_start")
	
	var actual_stat_gains = {}
	var progress_gains = {}
	
	# 计算实际获得的属性和进度
	for c_id in _planned_counts.keys():
		var count = _planned_counts[c_id]
		var course = _get_course_by_id(c_id)
		var increment = course.get("progress_increment", 0)
		
		progress_gains[c_id] = increment * count
		
		var rewards = course.get("rewards", {})
		for i in range(count):
			for stat_key in rewards.keys():
				var val = rewards[stat_key]
				var actual_val = 0
				if val is Array and val.size() >= 2:
					actual_val = randi_range(val[0], val[1])
				else:
					actual_val = int(val)
				actual_stat_gains[stat_key] = actual_stat_gains.get(stat_key, 0) + actual_val
				
	# 应用进度
	for c_id in progress_gains.keys():
		var cur = profile.course_progress.get(c_id, 0)
		var max_p = _get_course_by_id(c_id).get("max_progress", 100)
		profile.course_progress[c_id] = min(cur + progress_gains[c_id], max_p)
		
	# 应用属性
	for stat_key in actual_stat_gains.keys():
		if stat_key in profile:
			profile.set(stat_key, profile.get(stat_key) + actual_stat_gains[stat_key])
			
	profile.save_profile()
	
	if ToastManager:
		ToastManager.show_toast("行动力 -%d" % total_cost, Color(0.9, 0.6, 0.4, 0.9))
		
		# 使用左侧带颜色的属性 Toast
		for stat_key in actual_stat_gains.keys():
			var display_name = STAT_NAME_MAP.get(stat_key, stat_key)
			ToastManager.show_stat_toast(stat_key, "%s +%d" % [display_name, actual_stat_gains[stat_key]])
			
	if GameDataManager.story_time_manager:
		GameDataManager.story_time_manager.tick_minutes(total_minutes)
	var story_post_event_manager := get_node_or_null("/root/StoryPostEventManager")
	if story_post_event_manager and story_post_event_manager.has_method("register_time_completion"):
		story_post_event_manager.register_time_completion("tutoring_completed")
			
	closing_started.emit()
	var tween = create_tween()
	tween.tween_property($MenuPanel, "modulate:a", 0.0, 0.25)
	
	# 完成学习后，通知主场景刷新动作气泡
	var parent_scene = get_parent()
	while parent_scene and not parent_scene.has_method("_on_menu_action_pressed"):
		parent_scene = parent_scene.get_parent()
	if parent_scene and parent_scene.has_method("_show_action_bubble_from_ai"):
		parent_scene._show_action_bubble_from_ai("tutoring")
		
	tween.tween_callback(queue_free)

func _on_close_pressed():
	closing_started.emit()
	var tween = create_tween()
	tween.tween_property($MenuPanel, "modulate:a", 0.0, 0.25)
	tween.tween_callback(queue_free)

func get_guide_target(target_mode: String) -> Node:
	match target_mode:
		"course_list":
			return $MenuPanel/ContentHBox/LeftPanel
		"detail_panel":
			return $MenuPanel/ContentHBox/RightPanel/DetailPanel
		"start_button":
			return start_btn
	return null

func get_guide_focus_data(target_mode: String) -> Variant:
	var target := get_guide_target(target_mode) as Control
	if not is_instance_valid(target) or not target.is_visible_in_tree():
		return Rect2()
	var focus_rect := Rect2(Vector2.ZERO, target.size)
	var panel_origin: Vector2 = $MenuPanel.get_global_transform_with_canvas().origin
	var current: Node = target
	while current != null and current != $MenuPanel:
		if current is Control:
			focus_rect.position += (current as Control).position
		current = current.get_parent()
	focus_rect.position += panel_origin
	return focus_rect

func _on_detail_panel_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_report_guide_action("tutoring_click_details")

func _report_guide_action(action_id: String, payload: Dictionary = {}) -> void:
	var guide_manager = get_node_or_null("/root/GuideManager")
	if guide_manager and guide_manager.has_method("report_action"):
		guide_manager.report_action(action_id, payload)
