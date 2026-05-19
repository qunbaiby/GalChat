extends Control

@onready var ui_panel: Panel = $UIPanel
@onready var galchat_button: Button = $UIPanel/StoryButton
@onready var activity_button: Button = $UIPanel/ActivityButton
@onready var desktop_pet_button: Button = $UIPanel/BottomBarHBox/BtnHBox/DesktopPetButton
@onready var hide_ui_button: Button = $UIPanel/SystemButton/HideUIButton
@onready var settings_button: Button = $UIPanel/SystemButton/SettingsButton
@onready var save_button: Button = $UIPanel/SystemButton/SaveButton
@onready var load_button: Button = $UIPanel/SystemButton/LoadButton
@onready var affection_button: Button = $UIPanel/AffectionButton
@onready var phone_button: Button = $UIPanel/BottomBarHBox/BtnHBox/PhoneButton
@onready var diary_button: Button = $UIPanel/BottomBarHBox/BtnHBox/DiaryButton
@onready var pomodoro_button: Button = $UIPanel/PomodoroButton
@onready var map_button: Button = $UIPanel/MapButton
@onready var stats_panel = $UIPanel/StatsPanel
@onready var top_status_panel = $UIPanel/TopStatusPanel
@onready var bgm: AudioStreamPlayer = $BGM
@onready var music_player: Panel = $UIPanel/BottomBarHBox/MusicPlayer
@onready var diary_panel: Control = $UIPanel/DiaryPanel
@onready var diary_notification: PanelContainer = $UIPanel/DiaryNotification
@onready var topic_panel: Panel = $TopicPanel
@onready var topic_container: VBoxContainer = $TopicPanel/TopicContainer
@onready var dialogue_panel: Control = $DialoguePanel
@onready var dialogue_name_label: Label = $DialoguePanel/DialogueLayer/VBox/NameLabel
@onready var dialogue_text: RichTextLabel = $DialoguePanel/DialogueLayer/VBox/RichTextLabel
@onready var input_layer: Panel = $DialoguePanel/InputLayer
@onready var input_field: TextEdit = $DialoguePanel/InputLayer/HBoxContainer/InputField
@onready var send_btn: Button = $DialoguePanel/InputLayer/HBoxContainer/SendButton
@onready var end_chat_btn: Button = $DialoguePanel/EndChatButton
@onready var history_btn: Button = $DialoguePanel/HistoryButton
@onready var quick_options_container = $DialoguePanel/QuickOptionLayer/ScrollContainer/QuickOptions

@onready var deepseek_client = $DeepSeekClient

@onready var chat_button: Button = $UIPanel/InteractGroup/ChatButton
@onready var gift_button: Button = $UIPanel/InteractGroup/GiftButton
@onready var rest_button: Button = $UIPanel/InteractGroup/RestButton
@onready var co_create_button: Button = $UIPanel/InteractGroup/CoCreateButton

var activity_panel_instance = null
var drawing_board_instance = null

var _chat_tween: Tween = null
var _typewriter_tween: Tween = null
var stream_live_buffer: String = ""
var stream_live_active: bool = false

var _accumulated_stats: Dictionary = {
	"intimacy": 0.0,
	"trust": 0.0,
	"openness": 0.0,
	"conscientiousness": 0.0,
	"extraversion": 0.0,
	"agreeableness": 0.0,
	"neuroticism": 0.0
}

const QUICK_OPTION_ITEM_SCENE = preload("res://scenes/ui/story/quick_option_item.tscn")

var settings_panel_instance = null
var desktop_pet_instance: Window = null
var chat_scene_instance = null
var archive_panel_instance = null
var affection_panel_instance = null
var mobile_interface_instance = null
var incoming_call_notification_instance = null
var history_panel_instance = null
var pomodoro_panel_instance = null
var schedule_panel_instance = null
var save_load_panel_instance = null

var _window_detector: Node = null
var _is_afk: bool = false
var _afk_timer: Timer = null
var _ui_tween: Tween = null
var audio_player: AudioStreamPlayer = null

var map_scene_instance = null

const TOPIC_LIST = [
	"最近在忙些什么呢？",
	"今天天气真不错，对吧？",
	"有什么心事想和我聊聊吗？",
	"推荐一本你喜欢的书或电影吧。",
	"聊聊你的兴趣爱好吧！",
	"最近有遇到什么有趣的事吗？",
    "周末通常是怎么过的呢？"
]

var stream_live_queue: Array = []
var stream_live_worker_running: bool = false
var stream_live_done: bool = false

var is_proactive_greeting: bool = false
var proactive_greeting_step: int = 0
var _generated_image_panel: Panel = null

var _waiting_for_chat_click: bool = false
signal _chat_click_proceed

var pending_options_data = []
var is_text_playback_finished = true

func _on_main_chat_pressed() -> void:
	_animate_button(chat_button)
	
	if _ui_tween:
		_ui_tween.kill()
	_ui_tween = create_tween()
	_ui_tween.tween_property(ui_panel, "modulate:a", 0.0, 0.3)
	_ui_tween.tween_callback(func(): ui_panel.visible = false)
	
	topic_panel.visible = true
	topic_panel.modulate.a = 0.0
	var t_tween = create_tween()
	t_tween.tween_property(topic_panel, "modulate:a", 1.0, 0.3)
	
	_populate_topics()

func _populate_topics() -> void:
	for child in topic_container.get_children():
		child.queue_free()
		
	# 显示一个加载提示
	var loading_label = Label.new()
	loading_label.text = "正在思考话题..."
	loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading_label.add_theme_font_size_override("font_size", 20)
	topic_container.add_child(loading_label)
	
	# 请求 AI 动态生成话题
	var profile = GameDataManager.profile
	var stage_conf = profile.get_current_stage_config()
	var stage_title = stage_conf.get("stageTitle", "陌生人")
	var world_bg = profile.description.replace("{char_name}", profile.char_name)
	
	var prompt = "【系统指令】\n当前世界观与角色设定：%s\n\n请基于当前玩家作为少女【%s】的“指导人”身份，以及你们当前的情感阶段（当前阶段：%s），以指导人的口吻，生成 3 个符合当前关系深度的聊天话题选项。\n要求：\n1. 话题必须严格符合上述的世界观设定！绝对禁止凭空捏造“魔法”、“修仙”、“草药学”等不符合设定的元素。\n2. 话题可以是符合世界观的教导、关心、日常询问或指导性的话语。\n3. 直接输出 3 个选项，每行一个。\n4. 不要带有序号（如 1. 2. 3.）、破折号或其他前缀。\n5. 话题要自然、简短（20字以内）。" % [world_bg, profile.char_name, stage_title]
	
	deepseek_client.generate_dynamic_topics(prompt, func(text: String):
		if text.is_empty():
			_render_dynamic_topics("最近在忙些什么呢？\n今天天气真不错，对吧？\n有什么心事想和我聊聊吗？")
		else:
			_render_dynamic_topics(text)
	)

func _render_dynamic_topics(raw_text: String) -> void:
	for child in topic_container.get_children():
		child.queue_free()
		
	var lines = raw_text.split("\n", false)
	var topics = []
	for line in lines:
		var t = line.strip_edges()
		# 移除可能存在的序号前缀，如 "1. ", "- ", "* "
		var regex = RegEx.new()
		regex.compile("^(\\d+\\.|\\-|\\*)\\s*")
		t = regex.sub(t, "")
		if t != "":
			topics.append(t)
			
	if topics.size() > 3:
		topics = topics.slice(0, 3)
	elif topics.size() == 0:
		topics = ["聊点什么呢？", "天气不错", "分享件有趣的事"]
		
	for topic_text in topics:
		var btn = Button.new()
		btn.text = topic_text
		btn.custom_minimum_size = Vector2(0, 60)
		btn.add_theme_font_size_override("font_size", 20)
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		topic_container.add_child(btn)
		btn.pressed.connect(_on_topic_selected.bind(topic_text))

func _on_topic_selected(topic: String) -> void:
	if not GameDataManager.profile.consume_energy(5):
		ToastManager.show_system_toast("行动力不足，需要5点行动力", Color.RED)
		return
		
	if top_status_panel and top_status_panel.has_method("_update_ui"):
		top_status_panel._update_ui()
		
	var t_tween = create_tween()
	t_tween.tween_property(topic_panel, "modulate:a", 0.0, 0.3)
	t_tween.tween_callback(func(): topic_panel.visible = false)
	
	dialogue_panel.visible = true
	dialogue_panel.modulate.a = 0.0
	var d_tween = create_tween()
	d_tween.tween_property(dialogue_panel, "modulate:a", 1.0, 0.3)
	
	dialogue_name_label.text = GameDataManager.profile.char_name
	dialogue_text.text = "..."
	input_field.text = ""
	input_field.editable = false
	send_btn.disabled = true
	
	if end_chat_btn:
		end_chat_btn.show()
	if history_btn:
		history_btn.show()
	
	for child in quick_options_container.get_children():
		child.queue_free()
		
	var stage_conf = GameDataManager.profile.get_current_stage_config()
	var stage_desc = stage_conf.get("stageDesc", "")
	var player_name = GameDataManager.profile.player_title
	if player_name.is_empty():
		player_name = "指导人"
	var user_msg = "【系统提示】玩家主动选择了话题：“" + topic + "” 与你聊天。玩家当前的身份是你的指导人，且你对玩家的称呼是“" + player_name + "”。当前你们的情感阶段是：" + stage_desc + "。请你结合当前的身份、情感阶段和心情，以第一人称主动向玩家打招呼并展开这个话题。不要复述系统提示，直接给出纯台词回复（必须包含括号动作描写）。"
	deepseek_client.send_chat_message_stream(user_msg, "main_chat")

var is_ending_chat: bool = false

func _on_gift_pressed() -> void:
	_animate_button(gift_button)
	
	var gift_popup_path = "res://scenes/ui/gift/gift_panel.tscn"
	if FileAccess.file_exists(gift_popup_path):
		var gift_popup_scene = load(gift_popup_path)
		if gift_popup_scene:
			var popup = gift_popup_scene.instantiate()
			ui_panel.add_child(popup)
			
			if popup.has_signal("gift_sent"):
				popup.gift_sent.connect(_on_gift_sent)
				
			if popup.has_method("show_panel"):
				popup.show_panel()

func _on_gift_sent(gift_data: Dictionary) -> void:
	# 送礼后触发对话面板和特定话题
	if _ui_tween:
		_ui_tween.kill()
	_ui_tween = create_tween()
	_ui_tween.tween_property(ui_panel, "modulate:a", 0.0, 0.3)
	_ui_tween.tween_callback(func(): ui_panel.visible = false)
	
	dialogue_panel.visible = true
	dialogue_panel.modulate.a = 0.0
	var d_tween = create_tween()
	d_tween.tween_property(dialogue_panel, "modulate:a", 1.0, 0.3)
	
	dialogue_name_label.text = GameDataManager.profile.char_name
	dialogue_text.text = "..."
	input_field.text = ""
	input_field.editable = false
	send_btn.disabled = true
	
	if end_chat_btn:
		end_chat_btn.show()
	if history_btn:
		history_btn.show()
	
	for child in quick_options_container.get_children():
		child.queue_free()
		
	var gift_name = gift_data.get("name", "礼物")
	var stage_conf = GameDataManager.profile.get_current_stage_config()
	var stage_desc = stage_conf.get("stageDesc", "")
	var player_name = GameDataManager.profile.player_title
	if player_name.is_empty():
		player_name = "指导人"
		
	var user_msg = "【系统提示】玩家（当前身份：" + player_name + "）刚刚送给你一份礼物：【" + gift_name + "】。当前情感阶段是：" + stage_desc + "。请结合你的性格、心情和这份礼物的特点，主动对玩家说出你的感谢和反应（必须包含动作描写）。不要复述系统提示，直接给出台词。"
	deepseek_client.send_chat_message_stream(user_msg, "main_chat")

func _on_rest_pressed() -> void:
	_animate_button(rest_button)
	print("[MainScene] 休息按钮被点击，预留接口")

func _on_co_create_pressed() -> void:
	_animate_button(co_create_button)
	if drawing_board_instance == null:
		var DrawingBoardObj = load("res://scenes/ui/activity/drawing_board_panel.tscn")
		drawing_board_instance = DrawingBoardObj.instantiate()
		ui_panel.add_child(drawing_board_instance)
		drawing_board_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		if drawing_board_instance.has_signal("creation_completed"):
			drawing_board_instance.creation_completed.connect(_on_drawing_creation_completed)
		if drawing_board_instance.has_signal("creation_failed"):
			drawing_board_instance.creation_failed.connect(_on_drawing_creation_failed)
		if drawing_board_instance.has_signal("close_requested"):
			drawing_board_instance.close_requested.connect(func(): drawing_board_instance.hide())
	drawing_board_instance.show()

func _on_drawing_creation_completed(image_path: String, prompt: String) -> void:
	if drawing_board_instance:
		drawing_board_instance.hide()
	
	# 显示图片和对话
	_show_generated_image_and_dialogue(image_path)

func _on_drawing_creation_failed(error_msg: String) -> void:
	ToastManager.show_system_toast(error_msg, Color.RED)

func _show_generated_image_and_dialogue(image_path: String) -> void:
	if is_instance_valid(_generated_image_panel):
		_generated_image_panel.queue_free()
	_generated_image_panel = null

	# 利用系统的图库面板或者创建临时的面板显示图片
	var tex = ImageTexture.create_from_image(Image.load_from_file(image_path))
	if tex == null:
		ToastManager.show_system_toast("无法加载生成的图片", Color.RED)
		return
		
	var tex_rect = TextureRect.new()
	tex_rect.texture = tex
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	var panel = Panel.new()
	_generated_image_panel = panel
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.8)
	panel.add_theme_stylebox_override("panel", style)
	
	tex_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(tex_rect)
	
	var close_btn = Button.new()
	close_btn.text = "关闭"
	close_btn.position = Vector2(20, 20)
	close_btn.add_theme_font_size_override("font_size", 24)
	close_btn.pressed.connect(func(): panel.queue_free())
	panel.add_child(close_btn)
	
	add_child(panel)
	move_child(panel, dialogue_panel.get_index())
	
	# 显示对话
	if _ui_tween:
		_ui_tween.kill()
	_ui_tween = create_tween()
	_ui_tween.tween_property(ui_panel, "modulate:a", 0.0, 0.3)
	_ui_tween.tween_callback(func(): ui_panel.visible = false)
	
	dialogue_panel.visible = true
	dialogue_panel.modulate.a = 0.0
	var d_tween = create_tween()
	d_tween.tween_property(dialogue_panel, "modulate:a", 1.0, 0.3)
	
	dialogue_name_label.text = GameDataManager.profile.char_name
	dialogue_text.text = "哥哥，我根据你画的草图，丰富了一下细节，你看好看吗？"
	dialogue_text.visible_ratio = 0.0
	
	if _typewriter_tween:
		_typewriter_tween.kill()
	_typewriter_tween = create_tween()
	_typewriter_tween.tween_property(dialogue_text, "visible_ratio", 1.0, 1.5)
	
	input_field.text = ""
	input_field.editable = true
	send_btn.disabled = false
	
	if end_chat_btn:
		end_chat_btn.show()
	if history_btn:
		history_btn.show()
	
	for child in quick_options_container.get_children():
		child.queue_free()

func _on_end_chat_pressed() -> void:
	var event_manager = get_node_or_null("/root/EventManager")
	if event_manager and event_manager.has_method("execute_event"):
		event_manager.execute_event("farewell")

func _close_chat_panel() -> void:
	if is_instance_valid(_generated_image_panel):
		_generated_image_panel.queue_free()
	_generated_image_panel = null

	_show_accumulated_stats()
	
	var d_tween = create_tween()
	d_tween.tween_property(dialogue_panel, "modulate:a", 0.0, 0.3)
	d_tween.tween_callback(func(): dialogue_panel.visible = false)
	
	ui_panel.visible = true
	ui_panel.modulate.a = 0.0
	if _ui_tween:
		_ui_tween.kill()
	_ui_tween = create_tween()
	_ui_tween.tween_property(ui_panel, "modulate:a", 1.0, 0.3)

func _on_send_pressed() -> void:
	var text = input_field.text.strip_edges()
	if text.is_empty():
		return
		
	input_field.text = ""
	input_field.editable = false
	send_btn.disabled = true
	
	for child in quick_options_container.get_children():
		child.queue_free()
		
	GameDataManager.history.add_message("player", text, "", "main_chat")
	
	dialogue_name_label.text = "我"
	
	var display_text = text
	var color_regex_zh = RegEx.new()
	color_regex_zh.compile("（(.*?)）")
	display_text = color_regex_zh.sub(display_text, "[color=green]（$1）[/color]", true)
	var color_regex_en = RegEx.new()
	color_regex_en.compile("\\((.*?)\\)")
	display_text = color_regex_en.sub(display_text, "[color=green]($1)[/color]", true)
	
	dialogue_text.bbcode_enabled = true
	dialogue_text.text = display_text
	dialogue_text.visible_ratio = 0.0
	
	if _typewriter_tween:
		_typewriter_tween.kill()
	_typewriter_tween = create_tween()
	var dur = max(0.5, text.length() * 0.05)
	_typewriter_tween.tween_property(dialogue_text, "visible_ratio", 1.0, dur)
	
	if is_inside_tree():
		while _typewriter_tween and _typewriter_tween.is_valid() and _typewriter_tween.is_running():
			await get_tree().process_frame
			
	dialogue_text.visible_ratio = 1.0
	dialogue_text.visible_characters = -1
	
	if is_proactive_greeting:
		is_proactive_greeting = false
		
	deepseek_client.send_chat_message_stream(text, "main_chat")

func _on_chat_stream_started() -> void:
	stream_live_active = true
	stream_live_done = false
	stream_live_buffer = ""
	stream_live_queue.clear()
	is_text_playback_finished = false
	pending_options_data.clear()
	
	if _waiting_for_chat_click:
		_waiting_for_chat_click = false
		_chat_click_proceed.emit()
		
	_try_start_stream_worker()

func _on_chat_stream_delta(delta_text: String) -> void:
	if not stream_live_active:
		return
	stream_live_buffer += delta_text
	_extract_stream_segments(false)
	_try_start_stream_worker()

func _on_chat_response(response: Dictionary) -> void:
	if stream_live_active:
		stream_live_done = true
		_extract_stream_segments(true)
		_try_start_stream_worker()
		
		# 我们不再在这里直接保存全量内容，因为 _stream_worker_loop 会逐句保存并附带语音缓存
		# GameDataManager.history.add_message("char", deepseek_client._chat_stream_full_text, "", "main_chat")
		deepseek_client.send_options_generation(deepseek_client._chat_stream_full_text, "", "main_chat")
		deepseek_client.send_emotion_generation(deepseek_client._chat_stream_full_text)
		return
		
	if response.has("choices") and response["choices"].size() > 0:
		var reply = response["choices"][0]["message"]["content"]
		# 我们不再在这里直接保存全量内容，因为 _stream_worker_loop 会逐句保存并附带语音缓存
		# GameDataManager.history.add_message("char", reply, "", "main_chat")
		deepseek_client.send_options_generation(reply, "", "main_chat")
		deepseek_client.send_emotion_generation(reply)
			
		dialogue_name_label.text = GameDataManager.profile.char_name
		
		var display_text = reply
		var color_regex_zh = RegEx.new()
		color_regex_zh.compile("（(.*?)）")
		display_text = color_regex_zh.sub(display_text, "[color=green]（$1）[/color]", true)
		var color_regex_en = RegEx.new()
		color_regex_en.compile("\\((.*?)\\)")
		display_text = color_regex_en.sub(display_text, "[color=green]($1)[/color]", true)
		
		dialogue_text.bbcode_enabled = true
		dialogue_text.text = display_text
		dialogue_text.visible_ratio = 1.0
		input_field.editable = true
		send_btn.disabled = false
	else:
		dialogue_name_label.text = GameDataManager.profile.char_name
		dialogue_text.text = "似乎走神了..."
		input_field.editable = true
		send_btn.disabled = false

func _extract_stream_segments(force_flush: bool) -> void:
	var delim = "[SPLIT]"
	while true:
		var idx = stream_live_buffer.find(delim)
		if idx == -1:
			break
		var part = stream_live_buffer.substr(0, idx).strip_edges()
		stream_live_buffer = stream_live_buffer.substr(idx + delim.length())
		if part != "":
			stream_live_queue.append(part)
			
	if force_flush:
		var last_part = stream_live_buffer.strip_edges()
		stream_live_buffer = ""
		if last_part != "":
			var parts = _auto_split_message(last_part)
			for p in parts:
				if typeof(p) == TYPE_STRING:
					var tp = p.strip_edges()
					if tp != "":
						stream_live_queue.append(tp)

func _auto_split_message(text: String) -> Array:
	if "[SPLIT]" in text:
		return text.split("[SPLIT]", false)
		
	var mood_tag = ""
	var pure_text = text
	var mood_regex = RegEx.new()
	mood_regex.compile("(?i)(?:<|\\<|《|\\[|【)\\s*(mood|心情)\\s*[:：]\\s*([^>\\>》\\]】]+)\\s*(?:>|\\>|》|\\]|】)")
	var mood_match = mood_regex.search(text)
	if mood_match:
		mood_tag = mood_match.get_string()
		pure_text = text.replace(mood_tag, "")
		
	var modified_text = pure_text
	
	# 新增策略0：优先将大模型输出的换行符视为消息分隔符
	# 很多时候AI会用换行来排版不同的动作和对话
	modified_text = modified_text.replace("\r\n", "\n")
	var nl_regex = RegEx.new()
	nl_regex.compile("\\n+")
	modified_text = nl_regex.sub(modified_text, "[SPLIT]", true)
	
	# 修复：确保连续的 [SPLIT] 被合并为一个
	modified_text = modified_text.replace("[SPLIT][SPLIT]", "[SPLIT]")
	modified_text = modified_text.replace("[SPLIT] [SPLIT]", "[SPLIT]")
	
	if not "[SPLIT]" in modified_text:
		var endings = ["。", "！", "？", "……", "”", "」", "~", "～"]
		var brackets = ["（", "("]
		
		# 策略1：根据“标点+动作括号”完美切分，这样刚好能保证切分后下一句以动作开头，带着后续的对话
		for end_char in endings:
			for bracket in brackets:
				modified_text = modified_text.replace(end_char + bracket, end_char + "[SPLIT]" + bracket)
				modified_text = modified_text.replace(end_char + " " + bracket, end_char + "[SPLIT]" + bracket)
				
		# 策略2：如果文本仍未切分且过长（>80字），强行按标点切分
		if not "[SPLIT]" in modified_text and modified_text.length() > 80:
			modified_text = modified_text.replace("。", "。[SPLIT]")
			modified_text = modified_text.replace("！", "！[SPLIT]")
			modified_text = modified_text.replace("？", "？[SPLIT]")
			# 避免把连续的标点切碎
			modified_text = modified_text.replace("[SPLIT][SPLIT]", "[SPLIT]")
		
	var parts = modified_text.split("[SPLIT]", false)
	var merged_parts = []
	var temp_str = ""
	
	for p in parts:
		var tp = p.strip_edges()
		if tp == "": continue
		
		if temp_str == "":
			temp_str = tp
		else:
			# 优化：判断当前片段(tp)或者暂存片段(temp_str)是否*仅仅*包含动作描写（没有实质对话内容）
			var tp_clean = tp
			var temp_clean = temp_str
			var action_regex = RegEx.new()
			action_regex.compile("（.*?）|\\(.*?\\)")
			tp_clean = action_regex.sub(tp_clean, "", true).strip_edges()
			temp_clean = action_regex.sub(temp_clean, "", true).strip_edges()
			
			# 如果其中一个片段仅仅只有动作描写（去掉括号后无内容），则必须合并
			if tp_clean == "" or temp_clean == "":
				temp_str += " " + tp
			else:
				merged_parts.append(temp_str)
				temp_str = tp
				
	if temp_str != "":
		merged_parts.append(temp_str)
		
	# 新增限制：如果某一条消息长度超过 60，强制进行二次切分
	var final_split_parts = []
	for part in merged_parts:
		if part.length() > 60:
			var split_part = part
			var endings = ["。", "！", "？", "……", "”", "」", "~", "～"]
			var brackets = ["（", "("]
			# 尝试在动作前切分
			for end_char in endings:
				for bracket in brackets:
					split_part = split_part.replace(end_char + bracket, end_char + "[FORCE_SPLIT]" + bracket)
					split_part = split_part.replace(end_char + " " + bracket, end_char + "[FORCE_SPLIT]" + bracket)
			
			# 如果依然没有切分开，强行按标点切分
			if not "[FORCE_SPLIT]" in split_part:
				split_part = split_part.replace("。", "。[FORCE_SPLIT]")
				split_part = split_part.replace("！", "！[FORCE_SPLIT]")
				split_part = split_part.replace("？", "？[FORCE_SPLIT]")
				split_part = split_part.replace("[FORCE_SPLIT][FORCE_SPLIT]", "[FORCE_SPLIT]")
				
			var sub_parts = split_part.split("[FORCE_SPLIT]", false)
			for sp in sub_parts:
				if sp.strip_edges() != "":
					final_split_parts.append(sp.strip_edges())
		else:
			final_split_parts.append(part)
			
	merged_parts = final_split_parts
		
	# 限制最多3条
	if merged_parts.size() > 3:
		# 只保留前3条，或者把后面的内容全部合并到第3条里
		var truncated_parts = []
		truncated_parts.append(merged_parts[0])
		truncated_parts.append(merged_parts[1])
		truncated_parts.append(merged_parts[2])
		merged_parts = truncated_parts
		
	if merged_parts.size() > 0 and mood_tag != "":
		merged_parts[merged_parts.size() - 1] += mood_tag
		
	if merged_parts.size() == 0:
		return [text]
		
	return merged_parts

func _try_start_stream_worker() -> void:
	if stream_live_worker_running:
		return
	stream_live_worker_running = true
	_stream_worker_loop()

func _stream_worker_loop() -> void:
	while stream_live_queue.size() > 0 or (stream_live_active and not stream_live_done):
		if not stream_live_active and stream_live_queue.size() == 0:
			break
			
		if stream_live_queue.size() > 0:
			var text = stream_live_queue.pop_front()
			
			# 清理情绪标签等
			var mood_regex = RegEx.new()
			mood_regex.compile("(?i)(?:<|\\<|《|\\[|【)\\s*(mood|心情)\\s*[:：]\\s*([^>\\>》\\]】]+)\\s*(?:>|\\>|》|\\]|】)")
			var pure_text = mood_regex.sub(text, "", true).strip_edges()
			
			if pure_text == "":
				continue
				
			dialogue_name_label.text = GameDataManager.profile.char_name
			
			# 强制清理：只保留最开头的一个动作描述，移除其余所有动作描述
			var extract_regex = RegEx.new()
			extract_regex.compile("（.*?）|\\(.*?\\)")
			var matches = extract_regex.search_all(pure_text)
			if matches.size() > 0:
				var first_action = matches[0].get_string()
				var no_action_text = extract_regex.sub(pure_text, "", true).strip_edges()
				pure_text = first_action + " " + no_action_text
			
			var display_text = pure_text
			var color_regex_zh = RegEx.new()
			color_regex_zh.compile("（(.*?)）")
			display_text = color_regex_zh.sub(display_text, "[color=green]（$1）[/color]", true)
			var color_regex_en = RegEx.new()
			color_regex_en.compile("\\((.*?)\\)")
			display_text = color_regex_en.sub(display_text, "[color=green]($1)[/color]", true)
			
			dialogue_text.bbcode_enabled = true
			dialogue_text.text = display_text
			dialogue_text.visible_ratio = 0.0
			
			var current_cache_key = ""
			
			if _typewriter_tween:
				_typewriter_tween.kill()
			_typewriter_tween = create_tween()
			var dur = max(0.5, pure_text.length() * 0.05)
			_typewriter_tween.tween_property(dialogue_text, "visible_ratio", 1.0, dur)
			
			var is_tts_started = false
			var tts_text = pure_text
			var action_regex = RegEx.new()
			action_regex.compile("（.*?）|\\(.*?\\)")
			tts_text = action_regex.sub(tts_text, "", true).strip_edges()
			
			if GameDataManager.config.voice_enabled:
				var regex_tts = RegEx.new()
				regex_tts.compile("[a-zA-Z0-9\u4e00-\u9fa5]")
				if regex_tts.search(tts_text) != null:
					is_tts_started = true
					var options = {}
					# 保存 cache key，为了后续写入历史记录关联语音播放 (简单用md5替代原来的内部方法)
					current_cache_key = (tts_text + str(options)).md5_text()
					TTSManager.synthesize(tts_text, options)
			
			# 这里必须等待一帧，确保 TTS 组件内部有机会触发 success 信号
			await get_tree().process_frame
			
			# 将该条切分后的消息存入历史记录中
			GameDataManager.history.add_message("char", pure_text, current_cache_key, "main_chat")
			
			if is_inside_tree():
				while _typewriter_tween and _typewriter_tween.is_valid() and _typewriter_tween.is_running():
					if not stream_live_active:
						break
					await get_tree().process_frame
					
			if not stream_live_active:
				break
				
			dialogue_text.visible_ratio = 1.0
			dialogue_text.visible_characters = -1
			
			_waiting_for_chat_click = false
				
			if is_tts_started and is_inside_tree() and audio_player:
				var wait_count = 0
				while not audio_player.playing and wait_count < 10:
					if not stream_live_active:
						break
					await get_tree().create_timer(0.05).timeout
					wait_count += 1
					
				wait_count = 0
				while audio_player.playing and is_inside_tree() and wait_count < 1200:
					if not stream_live_active:
						if audio_player: audio_player.stop()
						break
					await get_tree().create_timer(0.05).timeout
					wait_count += 1
					
			if is_inside_tree():
				await get_tree().create_timer(1.0).timeout
				
			if audio_player and audio_player.playing:
				audio_player.stop()
				
			if not stream_live_active:
				break
		else:
			if is_inside_tree():
				await get_tree().create_timer(0.1).timeout

	stream_live_worker_running = false
	stream_live_active = false
	
	is_text_playback_finished = true
	
	if is_ending_chat or is_proactive_greeting:
		if audio_player and audio_player.playing:
			await audio_player.finished
		await get_tree().create_timer(1.0).timeout
		_close_chat_panel()
		if input_layer:
			input_layer.show()
		is_ending_chat = false
		is_proactive_greeting = false
		return
		
	_try_show_options()
	
	input_field.editable = true
	send_btn.disabled = false

func _on_chat_click_proceed_handler() -> void:
	pass

func _on_tts_success(audio_stream: AudioStream, text: String) -> void:
	if audio_player:
		audio_player.stream = audio_stream
		audio_player.play()

func _on_tts_failed(error_msg: String, text: String) -> void:
	print("MainScene TTS 失败: ", error_msg)

func _on_dialogue_panel_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if dialogue_text.visible_ratio < 1.0:
			if _typewriter_tween:
				_typewriter_tween.kill()
			dialogue_text.visible_ratio = 1.0
			dialogue_text.visible_characters = -1
		elif _waiting_for_chat_click:
			_waiting_for_chat_click = false
			_chat_click_proceed.emit()

func _show_accumulated_stats() -> void:
	var display_keys = {
		"intimacy": "亲密",
		"trust": "信任"
	}
	
	for key in _accumulated_stats.keys():
		var val = _accumulated_stats[key]
		if abs(val) > 0.01: # Avoid floating point inaccuracies
			if display_keys.has(key):
				var sign_str = "+" if val > 0 else ""
				var formatted_val = sign_str + ("%.1f" % val)
				ToastManager.show_stat_toast(key, display_keys[key] + " " + formatted_val)
		_accumulated_stats[key] = 0.0 # reset for next time

func _on_emotion_response(response: Dictionary) -> void:
	if response.has("choices") and response["choices"].size() > 0:
		var reply = response["choices"][0]["message"]["content"]
		var regex = RegEx.new()
		regex.compile("(?i)(?:<|\\<|《|\\[|【)\\s*(intimacy|trust|亲密度|亲密变化|信任度|信任值|信任变化|openness|conscientiousness|extraversion|agreeableness|neuroticism)\\s*[:：]\\s*([^>\\>》\\]】]+)\\s*(?:>|\\>|》|\\]|】)")
		var matches = regex.search_all(reply)
		var has_changes = false
		
		for m in matches:
			var tag = m.get_string(1).to_lower()
			var val = m.get_string(2).strip_edges()
			var f_val = val.to_float()
			
			if tag == "intimacy" or tag.begins_with("亲密"):
				GameDataManager.profile.update_intimacy(f_val)
				has_changes = true
				_accumulated_stats["intimacy"] += f_val
			elif tag == "trust" or tag.begins_with("信任"):
				GameDataManager.profile.update_trust(f_val)
				has_changes = true
				_accumulated_stats["trust"] += f_val
			elif tag in ["openness", "conscientiousness", "extraversion", "agreeableness", "neuroticism"]:
				if f_val != 0.0:
					GameDataManager.personality_system.update_trait(GameDataManager.profile, tag, f_val)
					has_changes = true
					_accumulated_stats[tag] += f_val
					
		if has_changes:
			GameDataManager.profile.save_profile()
			if stats_panel and stats_panel.has_method("_update_ui"):
				stats_panel._update_ui()
			if top_status_panel and top_status_panel.has_method("_update_ui"):
				top_status_panel._update_ui()

func _on_options_response(response: Dictionary) -> void:
	if response.has("choices") and response["choices"].size() > 0:
		var reply = response["choices"][0]["message"]["content"]
		var json = JSON.new()
		
		# 提取可能的 JSON 代码块
		var json_str = reply
		var regex = RegEx.new()
		regex.compile("```(?:json)?\\s*(\\{[\\s\\S]*?\\})\\s*```")
		var match = regex.search(reply)
		if match:
			json_str = match.get_string(1).strip_edges()
		else:
			var start_idx = reply.find("{")
			var end_idx = reply.rfind("}")
			if start_idx != -1 and end_idx != -1 and end_idx > start_idx:
				json_str = reply.substr(start_idx, end_idx - start_idx + 1)
				
		if json.parse(json_str.strip_edges()) == OK:
			var data = json.get_data()
			if data is Dictionary and data.has("options") and data["options"] is Array:
				pending_options_data = data["options"]
				_try_show_options()
				return

func _try_show_options() -> void:
	if is_text_playback_finished and pending_options_data.size() > 0:
		for child in quick_options_container.get_children():
			child.queue_free()
			
		for i in range(pending_options_data.size()):
			var opt_text = pending_options_data[i]
			if typeof(opt_text) == TYPE_STRING:
				var item = QUICK_OPTION_ITEM_SCENE.instantiate()
				quick_options_container.add_child(item)
				item.setup(opt_text)
				item.option_selected.connect(_on_quick_option_selected.bind(i))
				
		pending_options_data.clear()

func _on_quick_option_selected(text: String, index: int = -1) -> void:
	if index == 0:
		# 正面选项
		GameDataManager.profile.update_intimacy(5)
		GameDataManager.profile.update_trust(5)
	elif index == 1:
		# 负面选项
		GameDataManager.profile.update_intimacy(-5)
		GameDataManager.profile.update_trust(-5)
		
	input_field.text = text
	_on_send_pressed()

func _ready() -> void:
	var main_bg_path = ImageManager.get_image_path("main_bg")
	if main_bg_path != "" and ResourceLoader.exists(main_bg_path):
		var bg_node = get_node_or_null("MainBg")
		if bg_node and bg_node is TextureRect:
			bg_node.texture = load(main_bg_path)
			
	if GameDataManager.config:
		GameDataManager.config.apply_settings()
		
	var window = get_window()
	if GameDataManager.has_meta("last_window_pos"):
		var last_pos = GameDataManager.get_meta("last_window_pos")
		if typeof(last_pos) == TYPE_VECTOR2I or typeof(last_pos) == TYPE_VECTOR2:
			window.position = last_pos
		else:
			window.move_to_center()
	else:
		window.move_to_center()
		
	window.close_requested.connect(_on_close_requested)
	
	galchat_button.pressed.connect(_on_galchat_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	save_button.pressed.connect(_on_save_pressed)
	load_button.pressed.connect(_on_load_pressed)
	hide_ui_button.pressed.connect(_on_hide_ui_pressed)
	affection_button.pressed.connect(_on_affection_pressed)
	phone_button.pressed.connect(_on_phone_pressed)
	activity_button.pressed.connect(_on_activity_pressed)
	desktop_pet_button.pressed.connect(_on_desktop_pet_pressed)
	diary_button.pressed.connect(_on_diary_pressed)
	pomodoro_button.pressed.connect(_on_pomodoro_pressed)
	
	if has_node("UIPanel/MapButton"):
		$UIPanel/MapButton.pressed.connect(_on_map_pressed)
		
	chat_button.pressed.connect(_on_main_chat_pressed)
	gift_button.pressed.connect(_on_gift_pressed)
	rest_button.pressed.connect(_on_rest_pressed)
	co_create_button.pressed.connect(_on_co_create_pressed)
	if end_chat_btn:
		end_chat_btn.pressed.connect(_on_end_chat_pressed)
	if history_btn:
		history_btn.pressed.connect(_on_history_pressed)
	if send_btn:
		send_btn.pressed.connect(_on_send_pressed)
	
	deepseek_client.chat_stream_started.connect(_on_chat_stream_started)
	deepseek_client.chat_stream_delta.connect(_on_chat_stream_delta)
	deepseek_client.chat_request_completed.connect(_on_chat_response)
	deepseek_client.options_request_completed.connect(_on_options_response)
	deepseek_client.emotion_request_completed.connect(_on_emotion_response)
	
	topic_panel.visible = false
	topic_panel.modulate.a = 0.0
	dialogue_panel.visible = false
	dialogue_panel.modulate.a = 0.0
	if dialogue_panel.has_signal("panel_clicked"):
		dialogue_panel.panel_clicked.connect(_on_dialogue_panel_gui_input)
	
	diary_notification.modulate.a = 0.0
	diary_notification.position.x = 1300 # Initial off-screen position
	
	audio_player = AudioStreamPlayer.new()
	add_child(audio_player)
	
	TTSManager.tts_success.connect(_on_tts_success)
	TTSManager.tts_failed.connect(_on_tts_failed)
			
	GameDataManager.character_switched.connect(_on_character_switched)
	
	if chat_button and GameDataManager.profile:
		chat_button.text = "与 " + GameDataManager.profile.char_name + " 聊天"
	
	var level_label = affection_button.get_node("HBoxContainer/LevelLabel")
	if level_label and GameDataManager.profile:
		var stage_conf = GameDataManager.profile.get_current_stage_config()
		level_label.text = stage_conf.get("stageTitle", "陌生人")
		
	# 动画：按钮点击弹性反馈
	galchat_button.pivot_offset = galchat_button.size / 2
	settings_button.pivot_offset = settings_button.size / 2
	phone_button.pivot_offset = phone_button.size / 2
	activity_button.pivot_offset = activity_button.size / 2
	desktop_pet_button.pivot_offset = desktop_pet_button.size / 2
	hide_ui_button.pivot_offset = hide_ui_button.size / 2
	save_button.pivot_offset = save_button.size / 2
	load_button.pivot_offset = load_button.size / 2
	affection_button.pivot_offset = affection_button.size / 2
	if has_node("UIPanel/MapButton"):
		map_button.pivot_offset = map_button.size / 2
		
	_add_neon_effect_to_button(activity_button)
	if has_node("UIPanel/MapButton"):
		_add_neon_effect_to_button(map_button)
	
	# 恢复整个主窗口的鼠标输入响应，清除可能因为之前透明测试遗留的 passthrough 多边形
	if not is_queued_for_deletion():
		DisplayServer.window_set_mouse_passthrough(PackedVector2Array(), get_window().get_window_id())
	
	# Update StatsPanel explicitly when returning to main scene
	if stats_panel and stats_panel.has_method("_update_ui"):
		stats_panel._update_ui()
		
	if top_status_panel and top_status_panel.has_method("_update_ui"):
		top_status_panel._update_ui()
		
	# 尝试找回已存在的桌宠实例
	if get_tree().root.has_node("DesktopPet"):
		desktop_pet_instance = get_tree().root.get_node("DesktopPet")
		
	# 关联音乐播放器
	if is_instance_valid(music_player) and is_instance_valid(bgm):
		music_player.set_audio_player(bgm)
		
	# 初始化挂机检测
	var window_detector_path = "res://scripts/csharp/WindowDetector.cs"
	if FileAccess.file_exists(window_detector_path):
		var WindowDetectorObj = load(window_detector_path)
		if WindowDetectorObj:
			_window_detector = WindowDetectorObj.new()
			add_child(_window_detector)
			# 把当前主窗口的真实 HWND 传给 C# 层，用于精准判断
			var win_id = get_window().get_window_id()
			var hwnd = DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE, win_id)
			if hwnd:
				_window_detector.call("SetMainHwnd", hwnd)
			
	_afk_timer = Timer.new()
	_afk_timer.wait_time = 1.0
	_afk_timer.autostart = true
	_afk_timer.timeout.connect(_check_afk_status)
	add_child(_afk_timer)
	
	# 检查是否刚刚完成开场剧情，如果是则触发主动问候
	if GameDataManager.get_meta("just_finished_intro_story", false):
		GameDataManager.set_meta("just_finished_intro_story", false)
		# 延迟 1.5 秒再触发主动问候，使得场景过渡更加平滑
		await get_tree().create_timer(1.5).timeout
		_trigger_proactive_greeting()

	# Update button states based on current weekday
	_update_button_states_by_time()
	if GameDataManager.story_time_manager:
		GameDataManager.story_time_manager.time_advanced.connect(_on_story_time_advanced)

func _update_button_states_by_time() -> void:
	if not GameDataManager.story_time_manager: return
	var date_dict = GameDataManager.story_time_manager.get_current_date_dict()
	var weekday = date_dict.weekday
	
	# 周末（星期六(6)、星期日(0)）: 外出启用，行程安排禁用
	# 工作日（星期一到五）: 行程安排启用，外出禁用
	if weekday == 0 or weekday == 6:
		if map_button: map_button.disabled = false
		if activity_button: activity_button.disabled = true
	else:
		if map_button: map_button.disabled = true
		if activity_button: activity_button.disabled = false

func _on_story_time_advanced(days: int, current_period: String) -> void:
	if days > 0:
		_update_button_states_by_time()

func _trigger_proactive_greeting() -> void:
	var event_manager = get_node_or_null("/root/EventManager")
	if event_manager and event_manager.has_method("execute_event"):
		event_manager.execute_event("proactive_greeting")

func start_proactive_greeting(prompt_type: String) -> void:
	is_proactive_greeting = true
	proactive_greeting_step = 0
	
	if _ui_tween:
		_ui_tween.kill()
	_ui_tween = create_tween()
	_ui_tween.tween_property(ui_panel, "modulate:a", 0.0, 0.3)
	_ui_tween.tween_callback(func(): ui_panel.visible = false)
	
	dialogue_panel.visible = true
	dialogue_panel.modulate.a = 0.0
	var d_tween = create_tween()
	d_tween.tween_property(dialogue_panel, "modulate:a", 1.0, 0.3)
	
	dialogue_name_label.text = GameDataManager.profile.char_name
	dialogue_text.text = "..."
	input_field.text = ""
	input_field.editable = false
	send_btn.disabled = true
	
	# 隐藏不需要的按钮和输入框
	if end_chat_btn:
		end_chat_btn.hide()
	if history_btn:
		history_btn.hide()
	if input_layer:
		input_layer.hide()
	
	for child in quick_options_container.get_children():
		child.queue_free()
		
	# 使用传入的 prompt_type 生成对应的主动问候 prompt
	var user_msg = GameDataManager.prompt_manager.build_proactive_greeting_prompt(GameDataManager.profile, prompt_type)
	deepseek_client.send_chat_message_stream(user_msg, "main_chat")

func start_farewell() -> void:
	if is_ending_chat:
		return
		
	if deepseek_client._chat_stream_active:
		deepseek_client._stop_chat_stream()
		
	stream_live_active = false
	stream_live_worker_running = false
	stream_live_queue.clear()
	
	if audio_player and audio_player.playing:
		audio_player.stop()
		
	if _typewriter_tween:
		_typewriter_tween.kill()
		
	is_ending_chat = true
	
	input_field.editable = false
	send_btn.disabled = true
	
	if end_chat_btn:
		end_chat_btn.hide()
	if history_btn:
		history_btn.hide()
	if input_layer:
		input_layer.hide()
		
	for child in quick_options_container.get_children():
		child.queue_free()
		
	var prompt = "【系统提示：玩家想要结束对话。请结合你当前的身份、心情和性格，说一句简短的结束语作为告别（必须包含括号动作描写）。绝对不要提到你是AI。】"
	deepseek_client.send_chat_message_stream(prompt, "main_chat")

func _add_neon_effect_to_button(btn: Button) -> void:
	if btn.name == "ActivityButton":
		var style = btn.get_theme_stylebox("normal").duplicate()
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", style)
		btn.add_theme_stylebox_override("pressed", style)
		btn.add_theme_stylebox_override("focus", style)
		style.border_color = Color(0, 0, 0, 0)
		style.shadow_color = Color(0, 0, 0, 0)
		style.shadow_size = 0
		btn.set_meta("neon_style", style)
	elif btn.name == "MapButton":
		var mat = btn.material.duplicate() as ShaderMaterial
		var style = btn.get_theme_stylebox("normal")
		var bg_color = Color(0.1, 0.1, 0.1, 0.9)
		if style is StyleBoxFlat:
			bg_color = style.bg_color
			
		btn.material = null
		
		var empty_style = StyleBoxEmpty.new()
		btn.add_theme_stylebox_override("normal", empty_style)
		btn.add_theme_stylebox_override("hover", empty_style)
		btn.add_theme_stylebox_override("pressed", empty_style)
		btn.add_theme_stylebox_override("focus", empty_style)
		
		var bg_rect = ColorRect.new()
		bg_rect.color = bg_color
		
		var pad = 0.15
		var h = btn.size.y / (1.0 - 2.0 * pad)
		var w = btn.size.x + h * 2.0 * pad
		bg_rect.size = Vector2(w, h)
		bg_rect.position = Vector2(-h * pad, -h * pad)
		bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg_rect.show_behind_parent = true
		
		mat.set_shader_parameter("padding", pad)
		mat.set_shader_parameter("aspect_ratio", w / h)
		mat.set_shader_parameter("border_width", 0.0)
		mat.set_shader_parameter("border_color", Color(0, 0, 0, 0))
		mat.set_shader_parameter("glow_size", 0.0)
		mat.set_shader_parameter("glow_color", Color(0, 0, 0, 0))
		
		bg_rect.material = mat
		btn.add_child(bg_rect)
		btn.set_meta("neon_mat", mat)
		
	btn.mouse_entered.connect(_on_neon_btn_hover.bind(btn, true))
	btn.mouse_exited.connect(_on_neon_btn_hover.bind(btn, false))
	btn.button_down.connect(_on_neon_btn_press.bind(btn, true))
	btn.button_up.connect(_on_neon_btn_press.bind(btn, false))

func _on_neon_btn_hover(btn: Button, is_hover: bool) -> void:
	if btn.has_meta("neon_tween"):
		var tween = btn.get_meta("neon_tween") as Tween
		if tween: tween.kill()
	if btn.has_meta("neon_loop"):
		var loop = btn.get_meta("neon_loop") as Tween
		if loop: loop.kill()
		
	if btn.button_pressed: return
	
	var tween = create_tween().set_parallel(true)
	btn.set_meta("neon_tween", tween)
	
	var target_color = Color(0.0, 0.8, 1.0, 0.8) # 青蓝色
	var target_border = 1
	var target_shadow = 2
	var target_shader_border = 0.008
	var target_shader_glow = 0.015
	
	if not is_hover:
		target_color = Color(0, 0, 0, 0)
		target_border = 0
		target_shadow = 0
		target_shader_border = 0.0
		target_shader_glow = 0.0
		
	if btn.has_meta("neon_style"):
		var style = btn.get_meta("neon_style") as StyleBoxFlat
		tween.tween_property(style, "border_color", target_color, 0.3)
		tween.tween_property(style, "shadow_color", target_color, 0.3)
		tween.tween_property(style, "border_width_left", target_border, 0.3)
		tween.tween_property(style, "border_width_top", target_border, 0.3)
		tween.tween_property(style, "border_width_right", target_border, 0.3)
		tween.tween_property(style, "border_width_bottom", target_border, 0.3)
		tween.tween_property(style, "shadow_size", target_shadow, 0.3)
	elif btn.has_meta("neon_mat"):
		var mat = btn.get_meta("neon_mat") as ShaderMaterial
		tween.tween_method(func(v): mat.set_shader_parameter("border_color", v), mat.get_shader_parameter("border_color"), target_color, 0.3)
		tween.tween_method(func(v): mat.set_shader_parameter("glow_color", v), mat.get_shader_parameter("glow_color"), target_color, 0.3)
		tween.tween_method(func(v): mat.set_shader_parameter("border_width", v), mat.get_shader_parameter("border_width"), target_shader_border, 0.3)
		tween.tween_method(func(v): mat.set_shader_parameter("glow_size", v), mat.get_shader_parameter("glow_size"), target_shader_glow, 0.3)
		
	if is_hover:
		tween.chain().tween_callback(_start_neon_loop.bind(btn, Color(0.0, 0.8, 1.0, 0.8), Color(1.0, 0.0, 0.5, 0.8), 1.0))

func _on_neon_btn_press(btn: Button, is_pressed: bool) -> void:
	if btn.has_meta("neon_tween"):
		var tween = btn.get_meta("neon_tween") as Tween
		if tween: tween.kill()
	if btn.has_meta("neon_loop"):
		var loop = btn.get_meta("neon_loop") as Tween
		if loop: loop.kill()
		
	var tween = create_tween().set_parallel(true)
	btn.set_meta("neon_tween", tween)
	
	if is_pressed:
		var target_color = Color(1.0, 0.9, 0.2, 1.0) # 黄色/爆亮
		if btn.has_meta("neon_style"):
			var style = btn.get_meta("neon_style") as StyleBoxFlat
			tween.tween_property(style, "border_color", target_color, 0.1)
			tween.tween_property(style, "shadow_color", target_color, 0.1)
			tween.tween_property(style, "border_width_left", 2, 0.1)
			tween.tween_property(style, "border_width_top", 2, 0.1)
			tween.tween_property(style, "border_width_right", 2, 0.1)
			tween.tween_property(style, "border_width_bottom", 2, 0.1)
			tween.tween_property(style, "shadow_size", 4, 0.1)
		elif btn.has_meta("neon_mat"):
			var mat = btn.get_meta("neon_mat") as ShaderMaterial
			tween.tween_method(func(v): mat.set_shader_parameter("border_color", v), mat.get_shader_parameter("border_color"), target_color, 0.1)
			tween.tween_method(func(v): mat.set_shader_parameter("glow_color", v), mat.get_shader_parameter("glow_color"), target_color, 0.1)
			tween.tween_method(func(v): mat.set_shader_parameter("border_width", v), mat.get_shader_parameter("border_width"), 0.015, 0.1)
			tween.tween_method(func(v): mat.set_shader_parameter("glow_size", v), mat.get_shader_parameter("glow_size"), 0.03, 0.1)
			
		tween.chain().tween_callback(_start_neon_loop.bind(btn, Color(1.0, 0.9, 0.2, 1.0), Color(1.0, 0.2, 0.2, 1.0), 0.2))
	else:
		_on_neon_btn_hover(btn, btn.is_hovered())

func _start_neon_loop(btn: Button, color1: Color, color2: Color, duration: float) -> void:
	var loop = create_tween().set_loops()
	btn.set_meta("neon_loop", loop)
	
	if btn.has_meta("neon_style"):
		var style = btn.get_meta("neon_style") as StyleBoxFlat
		loop.tween_property(style, "border_color", color2, duration)
		loop.parallel().tween_property(style, "shadow_color", color2, duration)
		loop.tween_property(style, "border_color", color1, duration)
		loop.parallel().tween_property(style, "shadow_color", color1, duration)
	elif btn.has_meta("neon_mat"):
		var mat = btn.get_meta("neon_mat") as ShaderMaterial
		loop.tween_method(func(v): mat.set_shader_parameter("border_color", v), color1, color2, duration)
		loop.parallel().tween_method(func(v): mat.set_shader_parameter("glow_color", v), color1, color2, duration)
		loop.tween_method(func(v): mat.set_shader_parameter("border_color", v), color2, color1, duration)
		loop.parallel().tween_method(func(v): mat.set_shader_parameter("glow_color", v), color2, color1, duration)

func _check_afk_status() -> void:
	var window = get_window()
	var is_minimized = window.mode == Window.MODE_MINIMIZED
	
	var is_covered_fullscreen = false
	if is_instance_valid(_window_detector):
		is_covered_fullscreen = _window_detector.call("IsAnyFullScreenWindowCovering")
		
	var should_be_afk = is_minimized or is_covered_fullscreen
	
	if should_be_afk != _is_afk:
		_is_afk = should_be_afk
		if _is_afk:
			_on_enter_afk()
		else:
			_on_exit_afk()

func _on_enter_afk() -> void:
	print("[MainScene] 视为主场景后台挂机，暂停音乐与进度")
	if bgm:
		bgm.stream_paused = true
		
func _on_exit_afk() -> void:
	print("[MainScene] 退出后台挂机模式，恢复音乐与进度")
	if bgm:
		bgm.stream_paused = false

func _on_desktop_pet_pressed() -> void:
	_animate_button(desktop_pet_button)
	if is_instance_valid(desktop_pet_instance):
		# 桌宠已存在，关闭它。先隐藏以防止输入系统报错
		desktop_pet_instance.hide()
		desktop_pet_instance.queue_free()
		desktop_pet_instance = null
	else:
		# 创建桌宠，直接挂载在 root 下，这样切换场景也不会被销毁
		var DesktopPetObj = load("res://scenes/ui/desktop_pet/desktop_pet.tscn")
		desktop_pet_instance = DesktopPetObj.instantiate()
		get_tree().root.add_child(desktop_pet_instance)

func _on_incoming_call_accepted(char_id: String, is_video: bool, is_fixed: bool = false) -> void:
	# 接听电话：打开手机面板
	if mobile_interface_instance == null:
		_on_phone_pressed()
	else:
		mobile_interface_instance.show_phone()
		
	# 告诉手机面板直接跳转到通话界面
	mobile_interface_instance.open_call_directly(char_id, is_video, is_fixed)

func _on_phone_pressed() -> void:
	_animate_button(phone_button)
	if mobile_interface_instance == null:
		var MobileInterfaceObj = load("res://scenes/ui/mobile/mobile_interface.tscn")
		mobile_interface_instance = MobileInterfaceObj.instantiate()
		ui_panel.add_child(mobile_interface_instance)
		mobile_interface_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mobile_interface_instance.app_opened.connect(_on_mobile_app_opened)
	
	# 如果当前在故事剧情场景中触发手机，需要把它提到最前面防止被剧情场景遮挡
	if is_instance_valid(chat_scene_instance) and chat_scene_instance.visible:
		mobile_interface_instance.get_parent().remove_child(mobile_interface_instance)
		add_child(mobile_interface_instance)
		move_child(mobile_interface_instance, -1)
		
	mobile_interface_instance.show_phone()

func _on_mobile_app_opened(app_name: String) -> void:
	pass # 目前 archive 由 mobile_interface 自己处理，如果有其他 app 可以加在这里

func _on_activity_pressed() -> void:
	_animate_button(activity_button)
	if activity_panel_instance == null:
		var ActivityPanelObj = load("res://scenes/ui/activity/activity_panel.tscn")
		activity_panel_instance = ActivityPanelObj.instantiate()
		add_child(activity_panel_instance)
		# 确保它盖在最上面
		activity_panel_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	activity_panel_instance.show_panel()

func _on_galchat_pressed() -> void:
	_animate_button(galchat_button)
	
	if chat_scene_instance == null:
		var ChatSceneObj = load("res://scenes/ui/story/story_scene.tscn")
		chat_scene_instance = ChatSceneObj.instantiate()
		add_child(chat_scene_instance)
		move_child(chat_scene_instance, -1)
		
		chat_scene_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		chat_scene_instance.chat_closed.connect(_on_chat_closed)
		
	chat_scene_instance.show_panel()
	if bgm.playing:
		bgm.stop()

func _on_chat_closed() -> void:
	if not bgm.playing:
		bgm.play()

func _on_history_pressed() -> void:
	if history_panel_instance == null:
		var HistoryPanelObj = load("res://scenes/ui/history/history_panel.tscn")
		history_panel_instance = HistoryPanelObj.instantiate()
		add_child(history_panel_instance)
		history_panel_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		
		# We need to hook up the close button of history panel manually if it doesn't self-close
		var close_btn = history_panel_instance.get_node_or_null("HistoryTopBar/HistoryCloseButton")
		if close_btn:
			close_btn.pressed.connect(func(): history_panel_instance.hide())
			
	history_panel_instance.show()
	_populate_history_ui()

func _populate_history_ui() -> void:
	if not history_panel_instance: return
	var history_vbox = history_panel_instance.get_node_or_null("ScrollContainer/VBoxContainer")
	if not history_vbox: return
	
	# 清空现有子节点
	for child in history_vbox.get_children():
		child.queue_free()
		
	var HISTORY_ITEM_SCENE = load("res://scenes/ui/history/history_item.tscn")
	var messages = GameDataManager.history.get_messages_by_type("main_chat")
	for msg in messages:
		var item = HISTORY_ITEM_SCENE.instantiate()
		history_vbox.add_child(item)
		item.setup(msg)
		item.play_voice_requested.connect(_play_cached_voice)
		
	# 延迟一帧等待容器布局完成，然后滚动到底部
	if is_inside_tree():
		await get_tree().process_frame
	var scroll = history_panel_instance.get_node_or_null("ScrollContainer")
	if scroll:
		var v_scroll = scroll.get_v_scroll_bar()
		v_scroll.value = v_scroll.max_value

func _play_cached_voice(cache_key: String) -> void:
	var cache_path = "user://tts_cache/" + cache_key + ".mp3"
	if FileAccess.file_exists(cache_path):
		var file = FileAccess.open(cache_path, FileAccess.READ)
		if file:
			var data = file.get_buffer(file.get_length())
			var stream = AudioStreamMP3.new()
			stream.data = data
			if audio_player:
				audio_player.stream = stream
				audio_player.play()
	else:
		print("未找到语音缓存: ", cache_key)

func _on_close_requested() -> void:
	pass

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		var desktop_pet = get_tree().root.get_node_or_null("DesktopPet")
		if is_instance_valid(desktop_pet) and desktop_pet.visible:
			# Godot 4 中，主场景是 Control 时，我们应该隐藏对应的 Window
			get_tree().root.hide()
		else:
			get_tree().quit()

func _on_settings_pressed() -> void:
	_animate_button(settings_button)
	if settings_panel_instance == null:
		var SettingsPanelObj = load("res://scenes/ui/settings/settings_scene.tscn")
		settings_panel_instance = SettingsPanelObj.instantiate()
		add_child(settings_panel_instance)
		settings_panel_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings_panel_instance.show_panel()

func _on_save_pressed() -> void:
	_animate_button(save_button)
	if save_load_panel_instance == null:
		var SaveLoadPanelObj = load("res://scenes/ui/save_load/save_load_panel.tscn")
		save_load_panel_instance = SaveLoadPanelObj.instantiate()
		add_child(save_load_panel_instance)
		save_load_panel_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	save_load_panel_instance.show_panel(true)

func _on_load_pressed() -> void:
	_animate_button(load_button)
	if save_load_panel_instance == null:
		var SaveLoadPanelObj = load("res://scenes/ui/save_load/save_load_panel.tscn")
		save_load_panel_instance = SaveLoadPanelObj.instantiate()
		add_child(save_load_panel_instance)
		save_load_panel_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	save_load_panel_instance.show_panel(false)

func _on_affection_pressed() -> void:
	_animate_button(affection_button)
	var was_visible = false
	if affection_panel_instance == null:
		var AffectionPanelObj = load("res://scenes/ui/story/affection_panel.tscn")
		affection_panel_instance = AffectionPanelObj.instantiate()
		ui_panel.add_child(affection_panel_instance)
		was_visible = false # 初次实例化，视为原本是隐藏的
	else:
		was_visible = affection_panel_instance.visible
		
	if not was_visible:
		# 修改为显示在按钮下方靠右位置
		var button_width = affection_button.size.x
		var panel_size = affection_panel_instance.size
		
		# 强制刷新一下 panel size
		affection_panel_instance.reset_size()
		
		affection_panel_instance.position = Vector2(
			affection_button.position.x + button_width - affection_panel_instance.size.x, # 右对齐
			affection_button.position.y + affection_button.size.y + 10 # 下方偏移10
		)
		affection_panel_instance.show()
	else:
		affection_panel_instance.hide()

func _on_diary_pressed() -> void:
	_animate_button(diary_button)
	diary_panel.show_diary()

func _on_pomodoro_pressed() -> void:
	_animate_button(pomodoro_button)
	if pomodoro_panel_instance == null:
		var PomodoroPanelObj = load("res://scenes/ui/main/pomodoro_panel.tscn")
		pomodoro_panel_instance = PomodoroPanelObj.instantiate()
		add_child(pomodoro_panel_instance)
		pomodoro_panel_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pomodoro_panel_instance.show()

func _on_map_pressed() -> void:
	_animate_button(map_button)
	print("[MainScene] Map button pressed")
	if not map_scene_instance:
		var map_scene = load("res://scenes/ui/map/core/world_map_scene.tscn")
		map_scene_instance = map_scene.instantiate()
		add_child(map_scene_instance)
		# Move map scene to top so it overlays everything
		move_child(map_scene_instance, get_child_count() - 1)
		
		# When location is selected, we want to transition to it
		map_scene_instance.location_selected.connect(_on_location_selected)
	
	map_scene_instance.show_map()

func _on_location_selected(location_id: String):
	print("[MainScene] Transitioning to location: ", location_id)
	# The actual transition is currently handled inside world_map_scene.gd
	# But we can also handle hiding main UI here if needed

func show_diary_notification() -> void:
	var tween = create_tween().set_parallel(true)
	tween.tween_property(diary_notification, "position:x", 1280 - 300, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(diary_notification, "modulate:a", 1.0, 0.5)
	
	var out_tween = create_tween()
	out_tween.tween_interval(3.0)
	out_tween.tween_property(diary_notification, "position:x", 1300, 0.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	out_tween.parallel().tween_property(diary_notification, "modulate:a", 0.0, 0.5)

func _on_hide_ui_pressed() -> void:
	_animate_button(hide_ui_button)
	if _ui_tween:
		_ui_tween.kill()
	_ui_tween = create_tween()
	_ui_tween.tween_property(ui_panel, "modulate:a", 0.0, 0.3)
	_ui_tween.tween_callback(func(): ui_panel.visible = false)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F12:
		var root = get_tree().root
		var debug_panel = root.get_node_or_null("GlobalDebugPanel")
		if debug_panel == null:
			var DebugPanelObj = load("res://scenes/ui/story/debug_panel.tscn")
			debug_panel = DebugPanelObj.instantiate()
			debug_panel.name = "GlobalDebugPanel"
			root.add_child(debug_panel)
			debug_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			
			# 如果当前是主场景，连上信号
			debug_panel.stage_changed.connect(func(stage: int):
				GameDataManager.profile.force_set_stage(stage)
				GameDataManager.history.messages.clear()
				GameDataManager.history.save_history()
				print("【Debug】强制切换情感阶段至：" + str(stage))
			)
			debug_panel.mood_changed.connect(func(mood: String):
				GameDataManager.profile.update_mood(mood)
				print("【Debug】强制切换心情至：" + mood)
			)
			debug_panel.show_panel() # Instantiate and show directly
		elif debug_panel.visible:
			debug_panel.hide()
		else:
			debug_panel.show_panel()
		get_viewport().set_input_as_handled()
		return
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# 如果手机界面存在且正在显示相机，不要显示UI
		if mobile_interface_instance and mobile_interface_instance.camera_panel_instance and mobile_interface_instance.camera_panel_instance.visible:
			return
			
		if not ui_panel.visible or ui_panel.modulate.a < 0.99:
			get_viewport().set_input_as_handled()
			if _ui_tween:
				_ui_tween.kill()
			ui_panel.visible = true
			_ui_tween = create_tween()
			_ui_tween.tween_property(ui_panel, "modulate:a", 1.0, 0.3)
			
			if topic_panel and topic_panel.visible:
				var t_tween = create_tween()
				t_tween.tween_property(topic_panel, "modulate:a", 0.0, 0.3)
				t_tween.tween_callback(func(): topic_panel.visible = false)
			
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		# 如果话题面板正在显示，右键点击则隐藏它并返回主界面UI
		if topic_panel and topic_panel.visible:
			get_viewport().set_input_as_handled()
			var t_tween = create_tween()
			t_tween.tween_property(topic_panel, "modulate:a", 0.0, 0.3)
			t_tween.tween_callback(func(): topic_panel.visible = false)
			
			if _ui_tween:
				_ui_tween.kill()
			ui_panel.visible = true
			_ui_tween = create_tween()
			_ui_tween.tween_property(ui_panel, "modulate:a", 1.0, 0.3)

func _on_character_switched(char_id: String) -> void:
	# 角色切换后更新主界面的面板（特别是数值显示）
	if stats_panel and stats_panel.has_method("_update_ui"):
		stats_panel._update_ui()
		
	if top_status_panel and top_status_panel.has_method("_update_ui"):
		top_status_panel._update_ui()
	
	# 更新右上角的 AffectionPanel
	if is_instance_valid(affection_panel_instance) and affection_panel_instance.has_method("update_ui"):
		affection_panel_instance.update_ui()
		
	if chat_button and GameDataManager.profile:
		chat_button.text = "与 " + GameDataManager.profile.char_name + " 聊天"
		
	# 注意：ChatScene 的更新由它自己内部监听信号处理

func _animate_button(btn: Button) -> void:
	var tween = create_tween()
	tween.tween_property(btn, "scale", Vector2(0.9, 0.9), 0.05)
	tween.tween_property(btn, "scale", Vector2(1.1, 1.1), 0.05)
	tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.05)
