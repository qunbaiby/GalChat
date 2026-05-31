extends CanvasLayer

signal closing_started

@onready var close_btn: Button = $MenuPanel/CloseBtn
@onready var course_vbox: VBoxContainer = $MenuPanel/ContentHBox/LeftPanel/CourseListPanel/ListMargin/ScrollContainer/CourseVBox
@onready var exp_label: Label = $MenuPanel/ContentHBox/RightPanel/ExpPanel/Margin/VBox/ExpLabel
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

const CourseItemScene = preload("res://scenes/ui/map/library/tutoring_course_item.tscn")

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
	create_tween().tween_property($MenuPanel, "modulate:a", 1.0, 0.3)
	
	close_btn.pressed.connect(_on_close_pressed)
	start_btn.pressed.connect(_on_start_pressed)
	reset_btn.pressed.connect(_on_reset_pressed)
	
	_load_activities()
	_refresh_ui()

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
	var increment = course.get("progress_increment", 0)
	var single_cost = increment * 5
	var max_prog = course.get("max_progress", 100)
	var cur_prog = profile.course_progress.get(c_id, 0)
	
	var planned_count = _planned_counts.get(c_id, 0)
	
	# 检查满级限制 (如果再点一次就超过或者等于 max_prog 且之前已经满了，拦截)
	if cur_prog + planned_count * increment >= max_prog:
		_show_warning("该课程进度已满！")
		return
		
	# 检查经验限制
	var total_planned_cost = _get_total_planned_cost()
	if profile.interaction_exp < total_planned_cost + single_cost:
		_show_warning("互动经验不足！")
		return
		
	# 隐藏警告
	warning_label.text = ""
		
	# 增加计划次数
	_planned_counts[c_id] = planned_count + 1
	
	# 局部更新左侧按钮 UI
	_update_course_button_visuals(c_id)
	
	# 整体更新右侧面板 UI
	_update_right_panel()

func _update_course_button_visuals(c_id: String) -> void:
	if not _course_buttons.has(c_id): return
	var item = _course_buttons[c_id]
	var planned_count = _planned_counts.get(c_id, 0)
	item.update_state(planned_count)

func _get_total_planned_cost() -> int:
	var total = 0
	for c_id in _planned_counts.keys():
		var course = _get_course_by_id(c_id)
		var increment = course.get("progress_increment", 0)
		total += increment * 5 * _planned_counts[c_id]
	return total

func _update_right_panel() -> void:
	var profile = GameDataManager.profile
	var total_cost = _get_total_planned_cost()
	var remaining_exp = profile.interaction_exp - total_cost
	
	exp_label.text = "%d" % remaining_exp
	
	var is_empty = _planned_counts.is_empty()
	start_btn.disabled = is_empty
	reset_btn.disabled = is_empty
	
	if is_empty:
		detail_title.text = "课业指导安排"
		detail_meta_label.text = "尚未安排指导内容"
		desc_label.text = "[color=#63708a]点击左侧课程可追加指导次数。[/color]\n[color=#7b8496]支持重复安排或组合多门课程。[/color]"
		cost_label.text = ""
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
		courses_summary += "• [b]%s[/b]  x%d\n" % [course.get("name", ""), count]
		
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
	detail_meta_label.text = "已安排 %d 次指导，涉及 %d 门课程" % [total_count, _planned_counts.size()]
	desc_label.text = courses_summary
	cost_label.text = "预计消耗互动经验：%d" % total_cost
	
	var preview_str = "[color=#e08b35][b]属性提升预览[/b][/color]\n"
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
	
	if profile.interaction_exp < total_cost:
		_show_warning("互动经验不足！")
		return
		
	profile.interaction_exp -= total_cost
	
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
		# ToastManager.show_toast(message, color, icon) - We can use a custom color for exp
		ToastManager.show_toast("互动经验 -%d" % total_cost, Color(0.9, 0.6, 0.4, 0.9))
		
		# 使用左侧带颜色的属性 Toast
		for stat_key in actual_stat_gains.keys():
			var display_name = STAT_NAME_MAP.get(stat_key, stat_key)
			ToastManager.show_stat_toast(stat_key, "%s +%d" % [display_name, actual_stat_gains[stat_key]])
			
	# 执行互动开销
	if GameDataManager.interaction_manager:
		GameDataManager.interaction_manager.execute_interaction("tutoring")
			
	_on_close_pressed()

func _on_close_pressed() -> void:
	closing_started.emit()
	var tween = create_tween()
	tween.tween_property($MenuPanel, "modulate:a", 0.0, 0.25)
	tween.tween_callback(queue_free)
