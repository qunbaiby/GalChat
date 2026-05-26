extends CanvasLayer

var energy_cost = 15

var options = [
	{
		"id": "vocal",
		"name": "声乐补习",
		"stats": {"stat_expression": 2.0, "stat_stage": 3.0},
		"node_path": "MenuPanel/OptionsHBox/VocalBtn"
	},
	{
		"id": "instrumental",
		"name": "器乐补习",
		"stats": {"stat_focus": 3.0, "stat_rhythm": 2.0},
		"node_path": "MenuPanel/OptionsHBox/InstrumentalBtn"
	},
	{
		"id": "theory",
		"name": "乐理补习",
		"stats": {"stat_knowledge": 3.0, "stat_art_theory": 2.0},
		"node_path": "MenuPanel/OptionsHBox/TheoryBtn"
	}
]

var selected_option_id = ""
var is_studying = false
var _ai_finished = false
var _anim_finished = false
var _ai_result_text = ""
var _current_opt_name = ""

@onready var menu_panel = $MenuPanel
@onready var close_btn = $MenuPanel/CloseBtn
@onready var start_btn = $MenuPanel/BottomHBox/StartBtn
@onready var study_popup = $StudyPopup
@onready var popup_title = $StudyPopup/PopupTitle
@onready var progress_bar = $StudyPopup/ProgressBar
@onready var ai_label = $StudyPopup/AILabel
@onready var finish_btn = $StudyPopup/FinishBtn

func _ready():
	close_btn.pressed.connect(_on_close_pressed)
	start_btn.pressed.connect(_on_start_pressed)
	finish_btn.pressed.connect(_on_finish_pressed)
	
	for i in range(options.size()):
		var opt = options[i]
		var btn = get_node(opt["node_path"]) as Button
		opt["button"] = btn
		
		# 绑定选择事件
		btn.pressed.connect(_on_option_selected.bind(opt["id"]))
		
	# Initial selection
	if options.size() > 0:
		_on_option_selected(options[0]["id"])

func _on_option_selected(id: String):
	selected_option_id = id
	for i in range(options.size()):
		var opt = options[i]
		var btn = opt["button"] as Button
		
		var hover_style = btn.get_theme_stylebox("hover") as StyleBoxFlat
		
		if opt["id"] == id:
			# 选中状态，可以设置边框高亮
			btn.add_theme_stylebox_override("normal", hover_style)
		else:
			# 恢复默认
			btn.remove_theme_stylebox_override("normal")

func _on_close_pressed():
	if not is_studying:
		queue_free()

func _on_start_pressed():
	if is_studying: return
	if selected_option_id == "": return
	
	if GameDataManager.interaction_manager:
		if not GameDataManager.interaction_manager.execute_interaction("music_study"):
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
	
	var selected_opt = null
	for i in range(options.size()):
		var o = options[i]
		if o["id"] == selected_option_id:
			selected_opt = o
			break
			
	# Hide menu content
	menu_panel.hide()
			
	# Show studying popup
	_show_studying_popup(selected_opt)

func _show_studying_popup(opt: Dictionary):
	study_popup.show()
	popup_title.text = "正在进行 " + opt["name"] + "..."
	progress_bar.value = 0
	ai_label.text = "[center]等待静的评价...[/center]"
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
	var prompt = "【系统指令】\n%s刚刚完成了一节【%s】。\n请以静（高冷、严厉但内心护短的高级辅导员）的口吻，给出一句简短的评价（20字以内）。" % [char_name, opt["name"]]
	
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
		_ai_result_text = "“还算差强人意，继续保持。”"
		_ai_finished = true
		_check_finish()
	else:
		deepseek_client.generate_dynamic_topics(prompt, func(text: String):
			if text.is_empty():
				_ai_result_text = "“还算差强人意，继续保持。”"
			else:
				text = text.strip_edges()
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
	var selected_opt = null
	for i in range(options.size()):
		var o = options[i]
		if o["id"] == selected_option_id:
			selected_opt = o
			break
			
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
				"stat_stage":
					display_name = "舞台"
					stat_id = "extraversion"
				"stat_focus":
					display_name = "专注"
					stat_id = "conscientiousness"
				"stat_rhythm":
					display_name = "反应"
					stat_id = "trust"
				"stat_knowledge":
					display_name = "学识"
					stat_id = "neuroticism"
				"stat_art_theory":
					display_name = "艺理"
					stat_id = "agreeableness"
			
			# 调用左侧不同颜色的 Toast，使用 stat_toast 方法自带对应图标和颜色
			if ToastManager:
				ToastManager.show_stat_toast(stat_id, display_name + " +" + str(val))
			
		profile.save_profile()
		
	queue_free()
