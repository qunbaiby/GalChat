extends CanvasLayer

signal closed
signal closing_started

const StudyOptionItemScene = preload("res://scenes/ui/map/core/study_option_item.tscn")

var options = [
	{
		"id": "swim",
		"name": "游泳馆",
		"icon": "🏊",
		"subtitle": "- SWIMMING -",
		"desc": "在泳池里畅游，锻炼心肺与全身协调性。",
		"cost_lines": [
			{"icon": "⚡", "label": "行动力", "value": "-10"},
			{"icon": "◷", "label": "时间", "value": "+30"}
		],
		"gain_tags": [
			{"icon": "✦", "text": "体能 +3"}
		],
		"stats": {"stat_stamina": 3.0},
		"energy_cost": 10,
		"time_cost": 30,
		"fallback_review": "“游了几圈，感觉全身都舒展了。”"
	},
	{
		"id": "gym",
		"name": "健身房",
		"icon": "🏋️",
		"subtitle": "- FITNESS -",
		"desc": "通过器械训练提升肌肉力量，挥洒汗水。",
		"cost_lines": [
			{"icon": "⚡", "label": "行动力", "value": "-15"},
			{"icon": "◷", "label": "时间", "value": "+45"}
		],
		"gain_tags": [
			{"icon": "✦", "text": "体能 +5"}
		],
		"stats": {"stat_stamina": 5.0},
		"energy_cost": 15,
		"time_cost": 45,
		"fallback_review": "“举铁真的好累，不过感觉自己变强壮了！”"
	},
	{
		"id": "yoga",
		"name": "瑜伽馆",
		"icon": "🧘",
		"subtitle": "- YOGA -",
		"desc": "在舒缓的音乐中冥想拉伸，提升形体与内在气质。",
		"cost_lines": [
			{"icon": "⚡", "label": "行动力", "value": "-10"},
			{"icon": "◷", "label": "时间", "value": "+30"}
		],
		"gain_tags": [
			{"icon": "✦", "text": "气质 +3"}
		],
		"stats": {"stat_temperament": 3.0},
		"energy_cost": 10,
		"time_cost": 30,
		"fallback_review": "“内心好平静，感觉身体都变轻盈了。”"
	},
	{
		"id": "dance",
		"name": "舞室",
		"icon": "💃",
		"subtitle": "- DANCE -",
		"desc": "跟随节拍舞动，提升肢体表达和礼仪姿态。",
		"cost_lines": [
			{"icon": "⚡", "label": "行动力", "value": "-15"},
			{"icon": "◷", "label": "时间", "value": "+45"}
		],
		"gain_tags": [
			{"icon": "✦", "text": "气质 +2"},
			{"icon": "✦", "text": "礼仪 +3"}
		],
		"stats": {"stat_temperament": 2.0, "stat_etiquette": 3.0},
		"energy_cost": 15,
		"time_cost": 45,
		"fallback_review": "“出了一身汗，但是踩中节奏的感觉太棒了！”"
	}
]

var selected_option_id = ""
var is_studying = false
var _ai_finished = false
var _anim_finished = false
var _ai_result_text = ""
var _current_opt_name = ""
var _option_cards: Dictionary = {}

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
		start_btn.text = " 开始训练 "
		return
	start_btn.text = "开始 %s  ·  -%d行动力" % [selected_opt["name"], int(selected_opt.get("energy_cost", 0))]

func _get_selected_option() -> Dictionary:
	for opt in options:
		if opt["id"] == selected_option_id:
			return opt
	return {}

func _on_close_pressed():
	if not is_studying:
		closing_started.emit()
		closed.emit()
		var tween = create_tween()
		tween.tween_property($MenuPanel, "modulate:a", 0.0, 0.25)
		tween.tween_callback(queue_free)

func _on_start_pressed():
	if is_studying: return
	if selected_option_id == "": return
	
	var selected_opt := _get_selected_option()
	var energy_cost = selected_opt["energy_cost"]
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
	ai_label.text = "[center]训练中...[/center]"
	finish_btn.hide()
	
	_ai_finished = true
	_anim_finished = false
	_ai_result_text = opt.get("fallback_review", "“训练结束，感觉不错！”")
	_current_opt_name = opt["name"]
	
	# Start progress animation
	var tween = create_tween()
	tween.tween_property(progress_bar, "value", 100.0, 3.0)
	
	tween.tween_callback(func():
		_anim_finished = true
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
		
		# 推进时间
		if GameDataManager.story_time_manager:
			GameDataManager.story_time_manager.tick_minutes(selected_opt["time_cost"])
			
		for stat_name in selected_opt["stats"]:
			var val = selected_opt["stats"][stat_name]
			profile.set(stat_name, profile.get(stat_name) + val)
			
			var display_name = stat_name
			var stat_id = stat_name
			match stat_name:
				"stat_stamina":
					display_name = "体能"
					stat_id = "stamina"
				"stat_temperament":
					display_name = "气质"
					stat_id = "extraversion"
				"stat_etiquette":
					display_name = "礼仪"
					stat_id = "agreeableness"
			
			if ToastManager:
				ToastManager.show_stat_toast(stat_id, display_name + " +" + str(val))
			
		profile.save_profile()
		
		# 刷新顶部状态栏
		if GameDataManager.has_node("TopStatusPanel"):
			var top_panel = GameDataManager.get_node("TopStatusPanel")
			if top_panel.has_method("_update_ui"):
				top_panel._update_ui()
		
	closing_started.emit()
	closed.emit()
	var tween = create_tween()
	tween.tween_property($StudyPopup, "modulate:a", 0.0, 0.3)
		
	tween.tween_callback(queue_free)
