extends Control

@onready var main_panel: HBoxContainer = $Margin/MainHBox
@onready var back_button: Button = $Margin/MainHBox/LeftPanel/Margin/VBox/TopHBox/BackButton
@onready var round_info: Label = $Margin/MainHBox/LeftPanel/Margin/VBox/TopHBox/RoundInfo
@onready var category_tabs: HBoxContainer = $Margin/MainHBox/LeftPanel/Margin/VBox/CategoryTabs
@onready var activity_grid: GridContainer = $Margin/MainHBox/LeftPanel/Margin/VBox/ScrollContainer/ActivityGrid
@onready var schedule_title: Label = $Margin/MainHBox/LeftPanel/Margin/VBox/BottomHBox/ScheduleTitle
@onready var schedule_slots: GridContainer = $Margin/MainHBox/LeftPanel/Margin/VBox/BottomHBox/ScheduleSlots
@onready var undo_button: Button = $Margin/MainHBox/LeftPanel/Margin/VBox/BottomHBox/ControlButtoon/UndoButton
@onready var clear_button: Button = $Margin/MainHBox/LeftPanel/Margin/VBox/BottomHBox/ControlButtoon/ClearButton

@onready var avatar_rect: TextureRect = %AvatarRect
@onready var char_name_label: Label = %CharNameLabel
@onready var energy_label: Label = %EnergyLabel
@onready var energy_bubble: Label = %EnergyBubble
@onready var mood_label: Label = %MoodLabel
@onready var stress_label: Label = %StressLabel
@onready var stress_bubble: Label = %StressBubble
@onready var bonus_label: Label = %BonusLabel

@onready var phys_sub: GridContainer = $Margin/MainHBox/RightPanel/Margin/VBox/ScrollContainer/StatsGrid/Block_Physical/Margin/VBox/SubStats
@onready var int_sub: GridContainer = $Margin/MainHBox/RightPanel/Margin/VBox/ScrollContainer/StatsGrid/Block_Intelligence/Margin/VBox/SubStats
@onready var charm_sub: GridContainer = $Margin/MainHBox/RightPanel/Margin/VBox/ScrollContainer/StatsGrid/Block_Charm/Margin/VBox/SubStats
@onready var sens_sub: GridContainer = $Margin/MainHBox/RightPanel/Margin/VBox/ScrollContainer/StatsGrid/Block_Sensibility/Margin/VBox/SubStats

@onready var phys_val: Label = $Margin/MainHBox/RightPanel/Margin/VBox/ScrollContainer/StatsGrid/Block_Physical/Margin/VBox/Header/TitleVBox/TitleHBox/ValLabel
@onready var int_val: Label = $Margin/MainHBox/RightPanel/Margin/VBox/ScrollContainer/StatsGrid/Block_Intelligence/Margin/VBox/Header/TitleVBox/TitleHBox/ValLabel
@onready var charm_val: Label = $Margin/MainHBox/RightPanel/Margin/VBox/ScrollContainer/StatsGrid/Block_Charm/Margin/VBox/Header/TitleVBox/TitleHBox/ValLabel
@onready var sens_val: Label = $Margin/MainHBox/RightPanel/Margin/VBox/ScrollContainer/StatsGrid/Block_Sensibility/Margin/VBox/Header/TitleVBox/TitleHBox/ValLabel


@onready var execute_button: Button = $Margin/MainHBox/RightPanel/Margin/VBox/ExecuteButton

@onready var loading_overlay: Control = $LoadingOverlay
@onready var loading_progress: ProgressBar = $LoadingOverlay/LoadingPanel/ProgressBar
@onready var walker_icon: Control = $LoadingOverlay/LoadingPanel/TrackControl/WalkerIcon
@onready var track_control: Control = $LoadingOverlay/LoadingPanel/TrackControl

var scheduled_activities: Array = []
const MAX_SLOTS = 10
var current_category_id: String = ""

var _pending_progress_tween: Tween
var _walker_tween: Tween
var _pending_exec_data: Dictionary = {}

var stat_name_map = {
	"stat_stamina": "体能续航",
	"stat_body_management": "形体管控",
	"stat_focus": "凝心专注",
	"stat_rhythm": "律动反应",
	"stat_artistic_literacy": "艺术素养",
	"stat_verbal_expression": "言辞表达",
	"stat_planning": "统筹企划",
	"stat_art_theory": "艺理钻研",
	"stat_temperament": "格调气质",
	"stat_manner": "举止仪范",
	"stat_emotional_infection": "共情感染",
	"stat_stage_performance": "舞台表现",
	"stat_empathy": "情思体悟",
	"stat_inspiration": "创想灵感",
	"stat_aesthetics": "美学品鉴",
	"stat_art_perception": "艺术感知"
}

var category_group_map = {}

func _ready() -> void:
	category_group_map = {
		"stat_stamina": phys_sub,
		"stat_body_management": phys_sub,
		"stat_focus": phys_sub,
		"stat_rhythm": phys_sub,
		"stat_artistic_literacy": int_sub,
		"stat_verbal_expression": int_sub,
		"stat_planning": int_sub,
		"stat_art_theory": int_sub,
		"stat_temperament": charm_sub,
		"stat_manner": charm_sub,
		"stat_emotional_infection": charm_sub,
		"stat_stage_performance": charm_sub,
		"stat_empathy": sens_sub,
		"stat_inspiration": sens_sub,
		"stat_aesthetics": sens_sub,
		"stat_art_perception": sens_sub
	}
	
	back_button.pressed.connect(_on_close_pressed)
	execute_button.pressed.connect(_on_execute_pressed)
	undo_button.pressed.connect(_on_undo_pressed)
	clear_button.pressed.connect(_on_clear_pressed)
	
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
		btn.custom_minimum_size = Vector2(80, 35)
		btn.pressed.connect(_on_category_pressed.bind(cat.id))
		category_tabs.add_child(btn)
		
	if categories.size() > 0:
		current_category_id = categories[0].id

func _on_category_pressed(cat_id: String) -> void:
	current_category_id = cat_id
	
	for child in category_tabs.get_children():
		var is_selected = false
		var cat_info = _get_category_by_name(child.text)
		if cat_info and cat_info.id == cat_id:
			is_selected = true
			
		if is_selected:
			child.modulate = Color(1.2, 1.2, 1.2)
		else:
			child.modulate = Color(0.8, 0.8, 0.8)
			
	_populate_activities()

func _get_category_by_name(cat_name: String) -> Dictionary:
	var categories = GameDataManager.activity_manager.get_categories()
	for cat in categories:
		if cat.name == cat_name:
			return cat
	return {}

func _populate_activities() -> void:
	var item_scene = load("res://scenes/ui/activity/activity_item.tscn")
	for child in activity_grid.get_children():
		child.queue_free()
		
	var acts = GameDataManager.activity_manager.get_activities_by_category(current_category_id)
	for act in acts:
		var item = item_scene.instantiate()
		activity_grid.add_child(item)
		item.setup(act)
		item.activity_pressed.connect(_on_activity_pressed)

func show_panel() -> void:
	if current_category_id == "":
		var categories = GameDataManager.activity_manager.get_categories()
		if categories.size() > 0:
			current_category_id = categories[0].id
	_on_category_pressed(current_category_id)
	_update_ui()
	
	loading_overlay.hide()
	main_panel.show()
	show()
	
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
	var profile = GameDataManager.profile
	
	round_info.text = "第 %d 回合" % profile.current_stage
	
	schedule_title.text = "已安排行程 %d/%d" % [scheduled_activities.size(), MAX_SLOTS]
	
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
			btn.text = ""
			btn.icon = null
			
	execute_button.disabled = scheduled_activities.size() < MAX_SLOTS
	undo_button.disabled = scheduled_activities.size() == 0
	clear_button.disabled = scheduled_activities.size() == 0
	
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
	
	# 根据压力额外影响加成，暂定压力每 10 点减少 2% 加成，且基础为 0
	# 假设压力超过 50 开始减少，或者这里暂不引入复杂的计算，只做个简单映射
	# 综合加成 = mood_bonus - stress_penalty
	var stress_penalty = 0.0
	if profile.stress > 50:
		stress_penalty = (profile.stress - 50) * 0.005 # 最大惩罚 25%
	
	var final_bonus_rate = stat_bonus_rate - stress_penalty
	
	var bonus_text = ""
	if final_bonus_rate > 0:
		bonus_text = "收益增加%d%%" % int(final_bonus_rate * 100)
		bonus_label.add_theme_color_override("font_color", Color("2a9d8f")) # 正面绿色
	elif final_bonus_rate < 0:
		bonus_text = "收益减少%d%%" % int(-final_bonus_rate * 100)
		bonus_label.add_theme_color_override("font_color", Color("e76f51")) # 负面红色
	else:
		bonus_text = "无特殊加成"
		bonus_label.add_theme_color_override("font_color", Color("555555")) # 平静灰色
		
	bonus_label.text = bonus_text
	
	var total_rewards = {}
	var total_energy_cost = 0
	var total_stress_cost = 0
	var total_mood_cost = 0
	
	for act_id in scheduled_activities:
		var act = GameDataManager.activity_manager.get_activity_by_id(act_id)
		if act.is_empty(): continue
		total_energy_cost += act.get("energy_cost", 0)
		
		# 预留压力和心情的消耗/恢复字段
		# act 里可能会配置 stress_change 和 mood_change
		# 由于当前活动数据里没有这些，默认暂不计算，或在未来加入
		
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
				
	var end_energy = profile.current_energy - total_energy_cost + total_rewards.get("energy_recovery", 0.0)
	end_energy = clamp(end_energy, 0, profile.max_energy)
	
	var energy_diff = end_energy - profile.current_energy
	energy_label.text = "精力 %d" % int(end_energy)
	if energy_diff != 0:
		energy_bubble.show()
		energy_bubble.text = "%+d" % int(energy_diff)
		if energy_diff > 0:
			energy_bubble.add_theme_stylebox_override("normal", load("res://scenes/ui/activity/activity_panel.tscn::StyleBoxFlat_Bubble"))
		else:
			energy_bubble.add_theme_stylebox_override("normal", load("res://scenes/ui/activity/activity_panel.tscn::StyleBoxFlat_BubbleNeg"))
	else:
		energy_bubble.hide()
		
	var end_stress = clamp(profile.stress + total_stress_cost, 0, profile.max_stress)
	var stress_diff = end_stress - profile.stress
	stress_label.text = "压力 %d" % int(end_stress)
	if stress_diff != 0:
		stress_bubble.show()
		stress_bubble.text = "%+d" % int(stress_diff)
		if stress_diff > 0:
			stress_bubble.add_theme_stylebox_override("normal", load("res://scenes/ui/activity/activity_panel.tscn::StyleBoxFlat_BubbleNeg")) # 压力增加是坏事
		else:
			stress_bubble.add_theme_stylebox_override("normal", load("res://scenes/ui/activity/activity_panel.tscn::StyleBoxFlat_Bubble"))
	else:
		stress_bubble.hide()
		
	var end_mood = clamp(profile.mood_value + total_mood_cost, 0, 100)
	mood_label.text = "心情 %s" % GameDataManager.mood_system.get_macro_mood(end_mood).get("name", "未知")
		
	
	# Update core stats
	var start_core_phys = GameDataManager.stats_system.get_core_physical(profile)
	var start_core_int = GameDataManager.stats_system.get_core_intelligence(profile)
	var start_core_charm = GameDataManager.stats_system.get_core_charm(profile)
	var start_core_sens = GameDataManager.stats_system.get_core_sensibility(profile)
	
	var end_core_phys = int(floor((profile.stat_stamina + total_rewards.get("stat_stamina", 0)) + (profile.stat_body_management + total_rewards.get("stat_body_management", 0)) + (profile.stat_focus + total_rewards.get("stat_focus", 0)) + (profile.stat_rhythm + total_rewards.get("stat_rhythm", 0))))
	var end_core_int = int(floor((profile.stat_artistic_literacy + total_rewards.get("stat_artistic_literacy", 0)) + (profile.stat_verbal_expression + total_rewards.get("stat_verbal_expression", 0)) + (profile.stat_planning + total_rewards.get("stat_planning", 0)) + (profile.stat_art_theory + total_rewards.get("stat_art_theory", 0))))
	var end_core_charm = int(floor((profile.stat_temperament + total_rewards.get("stat_temperament", 0)) + (profile.stat_manner + total_rewards.get("stat_manner", 0)) + (profile.stat_emotional_infection + total_rewards.get("stat_emotional_infection", 0)) + (profile.stat_stage_performance + total_rewards.get("stat_stage_performance", 0))))
	var end_core_sens = int(floor((profile.stat_empathy + total_rewards.get("stat_empathy", 0)) + (profile.stat_inspiration + total_rewards.get("stat_inspiration", 0)) + (profile.stat_aesthetics + total_rewards.get("stat_aesthetics", 0)) + (profile.stat_art_perception + total_rewards.get("stat_art_perception", 0))))
	
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
		"stat_body_management": profile.stat_body_management,
		"stat_focus": profile.stat_focus,
		"stat_rhythm": profile.stat_rhythm,
		"stat_artistic_literacy": profile.stat_artistic_literacy,
		"stat_verbal_expression": profile.stat_verbal_expression,
		"stat_planning": profile.stat_planning,
		"stat_art_theory": profile.stat_art_theory,
		"stat_temperament": profile.stat_temperament,
		"stat_manner": profile.stat_manner,
		"stat_emotional_infection": profile.stat_emotional_infection,
		"stat_stage_performance": profile.stat_stage_performance,
		"stat_empathy": profile.stat_empathy,
		"stat_inspiration": profile.stat_inspiration,
		"stat_aesthetics": profile.stat_aesthetics,
		"stat_art_perception": profile.stat_art_perception
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

func _on_activity_pressed(activity_id: String) -> void:
	if scheduled_activities.size() < MAX_SLOTS:
		scheduled_activities.append(activity_id)
		_update_ui()

func _on_slot_pressed(index: int) -> void:
	pass

func _on_undo_pressed() -> void:
	if scheduled_activities.size() > 0:
		scheduled_activities.pop_back()
		_update_ui()

func _on_clear_pressed() -> void:
	if scheduled_activities.size() > 0:
		scheduled_activities.clear()
		_update_ui()

func _on_execute_pressed() -> void:
	if scheduled_activities.size() == MAX_SLOTS:
		main_panel.hide()
		loading_overlay.modulate.a = 0.0
		loading_overlay.show()
		
		var tween = create_tween()
		tween.tween_property(loading_overlay, "modulate:a", 1.0, 0.3)
		
		loading_progress.value = 0.0
		walker_icon.position.x = 0.0
		walker_icon.position.y = -40.0
		
		if _pending_progress_tween: _pending_progress_tween.kill()
		if _walker_tween: _walker_tween.kill()
		
		_pending_progress_tween = create_tween()
		_pending_progress_tween.tween_method(_update_loading_progress, 0.0, 90.0, 5.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		
		_walker_tween = create_tween().set_loops()
		_walker_tween.tween_property(walker_icon, "position:y", -50.0, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_walker_tween.tween_property(walker_icon, "position:y", -40.0, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		
		var courses_data = []
		
		for act_id in scheduled_activities:
			var act = GameDataManager.activity_manager.get_activity_by_id(act_id)
			var single_course = {
				"name": act.get("name", "未知课程"),
				"image_path": act.get("preview_image", ""),
				"bonus_list": [],
				"desc": "正在生成描述中..." 
			}
			
			if act.has("rewards"):
				for stat_key in act["rewards"]:
					var range_arr = act["rewards"][stat_key]
					var avg_val = (range_arr[0] + range_arr[1]) / 2.0
					
					var zh_name = stat_name_map.get(stat_key, stat_key)
					single_course["bonus_list"].append({"name": zh_name, "value": avg_val})
			
			courses_data.append(single_course)
			
		_fetch_all_course_descriptions_from_ai(courses_data)
		
		var profile = GameDataManager.profile
		var start_attrs = {
			"体能续航": profile.stat_stamina,
			"形体管控": profile.stat_body_management,
			"凝心专注": profile.stat_focus,
			"律动反应": profile.stat_rhythm,
			"艺术素养": profile.stat_artistic_literacy,
			"言辞表达": profile.stat_verbal_expression,
			"统筹企划": profile.stat_planning,
			"艺理钻研": profile.stat_art_theory,
			"格调气质": profile.stat_temperament,
			"举止仪范": profile.stat_manner,
			"共情感染": profile.stat_emotional_infection,
			"舞台表现": profile.stat_stage_performance,
			"情思体悟": profile.stat_empathy,
			"创想灵感": profile.stat_inspiration,
			"美学品鉴": profile.stat_aesthetics,
			"艺术感知": profile.stat_art_perception,
			"精力": profile.current_energy
		}
		var end_attrs = start_attrs.duplicate()
		
		var stat_bonus_rate = GameDataManager.mood_system.get_stat_bonus_rate(profile.mood_value)
		var stress_penalty = 0.0
		if profile.stress > 50:
			stress_penalty = (profile.stress - 50) * 0.005
		var final_bonus_rate = stat_bonus_rate - stress_penalty
		
		for course in courses_data:
			for bonus in course["bonus_list"]:
				var zh_name = bonus["name"]
				var val = bonus["value"]
				if zh_name == "精力恢复":
					end_attrs["精力"] += val
				else:
					if not end_attrs.has(zh_name):
						end_attrs[zh_name] = start_attrs.get(zh_name, 0)
					end_attrs[zh_name] += (val * (1.0 + final_bonus_rate))
				
		_pending_exec_data = {
			"courses_data": courses_data,
			"start_attrs": start_attrs,
			"end_attrs": end_attrs
		}
		
		scheduled_activities.clear()

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
		course_list_str += "%d. 【%s】\n" % [i + 1, courses_data[i]["name"]]
		
	var profile = GameDataManager.profile
	var char_name = profile.char_name if profile else "角色"
		
	var prompt = "这里有一份本周的学习计划，共 10 节课（包含休息）。请你作为旁白（第三人称视角），针对这 10 节课依次生成一段 20 到 50 字以内、生动形象的文字，描述 %s 正在进行该课程时的画面和状态。注意必须严格按顺序，用一个 JSON 数组返回。格式要求如下：\n" % char_name
	prompt += "```json\n[\n  \"(针对第1节课的描述)\",\n  \"(针对第2节课的描述)\",\n  ... (共10个元素)\n]\n```\n"
	prompt += "以下是这周的课程列表：\n" + course_list_str
	
	var body = {
		"model": GameDataManager.config.model if "model" in GameDataManager.config else "deepseek-chat",
		"messages": [{"role": "user", "content": prompt}],
		"temperature": 0.7,
		"response_format": {"type": "json_object"}
	}
	
	var err = http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		_fallback_all_descriptions()

func _update_loading_progress(val: float) -> void:
	if not is_instance_valid(loading_progress): return
	loading_progress.value = val
	var max_x = track_control.size.x - walker_icon.size.x
	walker_icon.position.x = max_x * (val / 100.0)

func _finish_loading_and_open() -> void:
	if _pending_progress_tween: _pending_progress_tween.kill()
	
	var finish_tween = create_tween()
	var start_val = loading_progress.value
	finish_tween.tween_method(_update_loading_progress, start_val, 100.0, 0.3).set_ease(Tween.EASE_IN_OUT)
	finish_tween.finished.connect(func():
		if _walker_tween: _walker_tween.kill()
		walker_icon.position.y = -40.0
		await get_tree().create_timer(0.2).timeout
		_open_execution_panel()
	)

func _on_all_ai_descriptions_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest) -> void:
	http.queue_free()
	
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_fallback_all_descriptions()
		return
		
	var json = JSON.parse_string(body.get_string_from_utf8())
	if json and json.has("choices") and json["choices"].size() > 0:
		var text = json["choices"][0]["message"]["content"].strip_edges()
		var extracted_json_str = _extract_json_array(text)
		var parsed_array = JSON.parse_string(extracted_json_str)
		
		if parsed_array is Array and parsed_array.size() >= 1:
			var courses = _pending_exec_data["courses_data"]
			for i in range(min(parsed_array.size(), courses.size())):
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

func _fallback_all_descriptions() -> void:
	if _pending_exec_data.is_empty(): return
	var courses = _pending_exec_data["courses_data"]
	for course in courses:
		var c_name = course["name"]
		if "休息" in c_name:
			course["desc"] = "今天给自己放了个假，彻底放松下来，恢复了精力。"
		else:
			course["desc"] = "今天也是按部就班地完成了【%s】的训练，感觉收获颇丰。" % c_name
			
	_finish_loading_and_open()

func _open_execution_panel() -> void:
	if _pending_exec_data.is_empty():
		return
		
	var main_scene = get_tree().current_scene
	var exec_panel_obj = load("res://scenes/ui/activity/schedule_execution_panel.tscn")
	var exec_panel = exec_panel_obj.instantiate()
	main_scene.add_child(exec_panel)
	exec_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	exec_panel.setup(
		_pending_exec_data["courses_data"],
		_pending_exec_data["start_attrs"],
		_pending_exec_data["end_attrs"]
	)
	
	_pending_exec_data.clear()
	hide()

func _on_close_pressed() -> void:
	hide_panel()
