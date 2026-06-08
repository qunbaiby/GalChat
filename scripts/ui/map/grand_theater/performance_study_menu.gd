extends CanvasLayer

signal closing_started

var energy_cost = 15
const StudyOptionItemScene = preload("res://scenes/ui/map/core/study_option_item.tscn")

var options = [
	{
		"id": "improv_acting",
		"name": "即兴表演",
		"icon": "🎭",
		"subtitle": "- IMPROV -",
		"desc": "跟着艾莉做情绪与反应训练，把角色状态从临场里逼出来。",
		"cost_lines": [
			{"icon": "⚡", "label": "行动力", "value": "-15"},
			{"icon": "◷", "label": "时间", "value": "+60"}
		],
		"gain_tags": [
			{"icon": "✦", "text": "表达 +3"},
			{"icon": "✦", "text": "感知 +2"}
		],
		"stats": {"stat_expression": 3.0, "stat_perception": 2.0},
		"review_focus": "围绕情绪反应、临场接戏和状态切换进行即兴训练，艾莉会点评Luna的放开程度、反应速度和情绪落点。",
		"fallback_review": "“这次反应终于跟上情绪了，舞台上的你开始活起来了。”"
	},
	{
		"id": "stage_rehearsal",
		"name": "同台排练",
		"icon": "🎬",
		"subtitle": "- REHEARSAL -",
		"desc": "和艾莉一起走位、接词、磨节奏，把同台时的气口和默契排出来。",
		"cost_lines": [
			{"icon": "⚡", "label": "行动力", "value": "-15"},
			{"icon": "◷", "label": "时间", "value": "+60"}
		],
		"gain_tags": [
			{"icon": "✦", "text": "气质 +3"},
			{"icon": "✦", "text": "反应 +2"}
		],
		"stats": {"stat_temperament": 3.0, "stat_rhythm": 2.0},
		"review_focus": "围绕走位、站位、接词与舞台默契做排练，艾莉会点评Luna的镜头感、节奏控制和同台稳定度。",
		"fallback_review": "“今天的站位和接词稳多了，终于有点同台演员的样子。”"
	},
	{
		"id": "classic_review",
		"name": "重温经典",
		"icon": "🎞",
		"subtitle": "- CLASSIC -",
		"desc": "和艾莉重看经典片段，拆角色、拆情绪，也拆那些真正打动人的表演细节。",
		"cost_lines": [
			{"icon": "⚡", "label": "行动力", "value": "-15"},
			{"icon": "◷", "label": "时间", "value": "+60"}
		],
		"gain_tags": [
			{"icon": "✦", "text": "学识 +3"},
			{"icon": "✦", "text": "审美 +2"}
		],
		"stats": {"stat_knowledge": 3.0, "stat_aesthetics": 2.0},
		"review_focus": "围绕经典角色与片段做表演分析，艾莉会点评Luna对人物层次、镜头节奏和情绪结构的理解。",
		"fallback_review": "“你终于不只是在看热闹了，开始真的读懂角色了。”"
	}
]

var selected_option_id = ""
var is_studying = false
var _ai_finished = false
var _anim_finished = false
var _ai_result_text = ""
var _current_opt_name = ""
var _option_cards: Dictionary = {}

func _sanitize_review_text(text: String) -> String:
	var cleaned := text.strip_edges()
	var patterns := [
		"\\([^()]*\\)",
		"（[^（）]*）"
	]
	for pattern in patterns:
		var regex := RegEx.new()
		if regex.compile(pattern) == OK:
			cleaned = regex.sub(cleaned, "", true)
	return cleaned.strip_edges()

@onready var menu_panel = $MenuPanel
@onready var close_btn = $MenuPanel/CloseBtn
@onready var start_btn = $MenuPanel/BottomHBox/StartBtn
@onready var options_container: HBoxContainer = $MenuPanel/OptionsHBox
@onready var cost_label: Label = $MenuPanel/BottomHBox/CostLabel
@onready var study_popup = $StudyPopup
@onready var popup_title = $StudyPopup/PopupTitle
@onready var progress_bar = $StudyPopup/ProgressBar
@onready var ai_label = $StudyPopup/AILabel
@onready var finish_btn = $StudyPopup/FinishBtn

func _ready():
	$MenuPanel.modulate.a = 0.0
	create_tween().tween_property($MenuPanel, "modulate:a", 1.0, 0.3)
	
	close_btn.pressed.connect(_on_close_pressed)
	start_btn.pressed.connect(_on_start_pressed)
	finish_btn.pressed.connect(_on_finish_pressed)
	_build_option_cards()
		
	# Initial selection
	if options.size() > 0:
		_on_option_selected(options[0]["id"])

func _build_option_cards() -> void:
	_option_cards.clear()
	for child in options_container.get_children():
		child.queue_free()
	for opt in options:
		var item := StudyOptionItemScene.instantiate()
		options_container.add_child(item)
		item.setup_option(opt)
		item.option_pressed.connect(_on_option_selected)
		_option_cards[opt["id"]] = item

func _on_option_selected(id: String):
	selected_option_id = id
	for opt in options:
		var card = _option_cards.get(opt["id"], null)
		if card:
			card.set_selected(opt["id"] == id)
	var selected_opt := _get_selected_option()
	if selected_opt:
		cost_label.text = "已选择：%s  |  消耗行动力：%d" % [selected_opt["name"], energy_cost]

func _get_selected_option() -> Dictionary:
	for opt in options:
		if opt["id"] == selected_option_id:
			return opt
	return {}

func _on_close_pressed():
	if not is_studying:
		closing_started.emit()
		var tween = create_tween()
		tween.tween_property($MenuPanel, "modulate:a", 0.0, 0.25)
		tween.tween_callback(queue_free)

func _on_start_pressed():
	if is_studying: return
	if selected_option_id == "": return
	
	if GameDataManager.interaction_manager:
		if not GameDataManager.interaction_manager.execute_interaction("performance_study"):
			return
	else:
		var profile = GameDataManager.profile
		if profile.current_energy < energy_cost:
			if ToastManager:
				ToastManager.show_system_toast("行动力不足！")
			return
			
		if profile.has_method("consume_energy"):
			profile.consume_energy(energy_cost)
		else:
			profile.current_energy -= energy_cost
			profile.save_profile()
			
	is_studying = true
	
	var selected_opt := _get_selected_option()
			
	# Hide menu content
	menu_panel.hide()
			
	# Show studying popup
	_show_studying_popup(selected_opt)

func _show_studying_popup(opt: Dictionary):
	study_popup.show()
	study_popup.modulate.a = 0.0
	var tween_popup = create_tween()
	tween_popup.tween_property(study_popup, "modulate:a", 1.0, 0.3)
	
	popup_title.text = "正在进行 " + opt["name"] + "..."
	progress_bar.value = 0
	ai_label.text = "[center]等待艾莉的点评...[/center]"
	finish_btn.hide()
	
	_ai_finished = false
	_anim_finished = false
	_ai_result_text = ""
	_current_opt_name = opt["name"]
	
	# Start progress animation
	var tween = create_tween()
	tween.tween_property(progress_bar, "value", 100.0, 3.0)
	
	tween.tween_callback(func():
		_anim_finished = true
		_check_finish()
	)
	
	# Call AI
	var profile = GameDataManager.profile
	var char_name = profile.char_name if profile.char_name != "" else "Luna"
	var prompt = "【系统指令】\n%s刚刚和艾莉完成了一次【%s】。\n学习内容：%s\n请以艾莉的口吻给出一句简短点评。\n人设要求：艾莉是从江屿走出去的当红演员，台前气场强、专业而从容，私下温柔、护短、会认真照顾后辈，但在表演问题上标准很高。\n输出要求：\n1. 只输出一句点评，不要解释。\n2. 16到24字。\n3. 只保留说话内容，不要括号动作，不要旁白。" % [char_name, opt["name"], opt.get("review_focus", "请结合本次练习内容进行点评。")]
	
	var deepseek_client = null
	for child in get_tree().root.get_children():
		if child.name == "DeepSeekClient":
			deepseek_client = child
			break
		var c = child.get_node_or_null("DeepSeekClient")
		if c:
			deepseek_client = c
			break
				
	if not deepseek_client:
		_ai_result_text = opt.get("fallback_review", "“今天的状态比我预想的好，再往前一步就更稳了。”")
		_ai_finished = true
		_check_finish()
	else:
		deepseek_client.generate_dynamic_topics(prompt, func(text: String):
			if text.is_empty():
				_ai_result_text = opt.get("fallback_review", "“今天的状态比我预想的好，再往前一步就更稳了。”")
			else:
				text = _sanitize_review_text(text)
				if text.begins_with("\"") or text.begins_with("“"): text = text.substr(1)
				if text.ends_with("\"") or text.ends_with("”"): text = text.substr(0, text.length()-1)
				_ai_result_text = "“" + text + "”"
			_ai_finished = true
			_check_finish()
		)

func _check_finish():
	if _ai_finished and _anim_finished:
		ai_label.text = "[center]" + _ai_result_text + "[/center]"
		finish_btn.show()
		popup_title.text = _current_opt_name + " 完成！"

func _on_finish_pressed():
	var selected_opt := _get_selected_option()
			
	if selected_opt:
		var profile = GameDataManager.profile
		for stat_name in selected_opt["stats"]:
			var val = selected_opt["stats"][stat_name]
			profile.set(stat_name, profile.get(stat_name) + val)
			
			var display_name = stat_name
			var stat_id = stat_name
			match stat_name:
				"stat_expression":
					display_name = "表达"
					stat_id = "openness" # 借用图标
				"stat_temperament":
					display_name = "气质"
					stat_id = "extraversion"
				"stat_perception":
					display_name = "感知"
					stat_id = "conscientiousness"
				"stat_rhythm":
					display_name = "反应"
					stat_id = "trust"
				"stat_knowledge":
					display_name = "学识"
					stat_id = "neuroticism"
				"stat_aesthetics":
					display_name = "审美"
					stat_id = "agreeableness"
			
			# 调用左侧不同颜色的 Toast，使用 stat_toast 方法自带对应图标和颜色
			if ToastManager:
				ToastManager.show_stat_toast(stat_id, display_name + " +" + str(val))
			
		profile.save_profile()
		
	closing_started.emit()
	var tween = create_tween()
	tween.tween_property($StudyPopup, "modulate:a", 0.0, 0.3)
	
	# 这里新增：完成学习后，通知主场景刷新动作气泡
	var parent_scene = get_parent()
	while parent_scene and not parent_scene.has_method("_on_menu_action_pressed"):
		parent_scene = parent_scene.get_parent()
	if parent_scene and parent_scene.has_method("_show_action_bubble_from_ai"):
		parent_scene._show_action_bubble_from_ai("study", _ai_result_text)
		
	tween.tween_callback(queue_free)
