extends CanvasLayer

signal closing_started

var energy_cost = 15
const StudyOptionItemScene = preload("res://scenes/ui/map/core/study_option_item.tscn")

var options = [
	{
		"id": "drawing_guidance",
		"icon": "✏",
		"name": "作画指导",
		"subtitle": "- DRAWING -",
		"desc": "由朔帮你改画、抓速写问题，把构图和线条讲透。",
		"cost_lines": [
			{"icon": "⚡", "label": "行动力", "value": "-15"},
			{"icon": "◷", "label": "时间", "value": "+60"}
		],
		"gain_tags": [
			{"icon": "✦", "text": "表达 +3"},
			{"icon": "✦", "text": "感知 +2"}
		],
		"stats": {"stat_expression": 3.0, "stat_perception": 2.0},
		"review_focus": "帮助Luna改画、指导速写并点评作业完成度，朔会从构图、线条和观察力角度做点评。",
		"fallback_review": "“这次线条顺多了，至少你的观察终于跟上手了。”"
	},
	{
		"id": "gallery_study",
		"icon": "🖼",
		"name": "展馆学习",
		"subtitle": "- GALLERY -",
		"desc": "一起看展、聊作品，在讨论里练出自己的判断。",
		"cost_lines": [
			{"icon": "⚡", "label": "行动力", "value": "-15"},
			{"icon": "◷", "label": "时间", "value": "+60"}
		],
		"gain_tags": [
			{"icon": "✦", "text": "审美 +3"},
			{"icon": "✦", "text": "学识 +2"}
		],
		"stats": {"stat_aesthetics": 3.0, "stat_knowledge": 2.0},
		"review_focus": "与朔结伴看画展、讨论画作并互相点评作品，朔会点评Luna的观察角度与作品理解。",
		"fallback_review": "“你今天看的不只热闹，判断也开始有自己的方向了。”"
	},
	{
		"id": "workshop_practice",
		"icon": "🛠",
		"name": "工坊实训",
		"subtitle": "- WORKSHOP -",
		"desc": "进入雕塑与版画工坊，把想法一步步做成真正的作品。",
		"cost_lines": [
			{"icon": "⚡", "label": "行动力", "value": "-15"},
			{"icon": "◷", "label": "时间", "value": "+60"}
		],
		"gain_tags": [
			{"icon": "✦", "text": "气质 +2"},
			{"icon": "✦", "text": "表达 +2 | 审美 +1"}
		],
		"stats": {"stat_temperament": 2.0, "stat_expression": 2.0, "stat_aesthetics": 1.0},
		"review_focus": "在雕塑或版画工坊协作完成手工创作，朔会点评Luna的动手稳定度、耐心和完成效果。",
		"fallback_review": "“手上终于不慌了，做工也比我预想的稳。”"
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
	_update_start_button_text()

func _update_start_button_text() -> void:
	var selected_opt := _get_selected_option()
	if selected_opt.is_empty():
		start_btn.text = " 开始学习 "
		return
	start_btn.text = "开始 %s  ·  -%d行动力" % [selected_opt["name"], energy_cost]

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
		if not GameDataManager.interaction_manager.execute_interaction("art_study"):
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
	ai_label.text = "[center]等待朔的点评...[/center]"
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
	var prompt = "【系统指令】\n%s刚刚和朔完成了一次【%s】。\n学习内容：%s\n请以朔的口吻给出一句简短点评。\n人设要求：朔是美术馆里的学长，寡言、审美锋利、说话直接，但会认真指导Luna。\n输出要求：\n1. 只输出一句点评，不要解释。\n2. 16到24字。\n3. 只保留说话内容，不要括号动作，不要旁白。" % [char_name, opt["name"], opt.get("review_focus", "请结合本次学习内容进行点评。")]
	
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
		_ai_result_text = opt.get("fallback_review", "“这次比上回稳，至少不是只靠运气。”")
		_ai_finished = true
		_check_finish()
	else:
		deepseek_client.generate_dynamic_topics(prompt, func(text: String):
			if text.is_empty():
				_ai_result_text = opt.get("fallback_review", "“这次比上回稳，至少不是只靠运气。”")
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
	
	# 完成学习后，通知主场景刷新动作气泡
	var parent_scene = get_parent()
	while parent_scene and not parent_scene.has_method("_on_menu_action_pressed"):
		parent_scene = parent_scene.get_parent()
	if parent_scene and parent_scene.has_method("_show_action_bubble_from_ai"):
		parent_scene._show_action_bubble_from_ai("study", _ai_result_text)
		
	tween.tween_callback(queue_free)
