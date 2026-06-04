extends Control

const DEBUG_PANEL_SCENE = preload("res://scenes/ui/story/debug_panel.tscn")

signal chat_closed

@export var ui_panel_path: NodePath = NodePath("UIPanel")
@export var dialogue_panel_path: NodePath = NodePath("UIPanel/DialoguePanel")
@export var deepseek_client_path: NodePath = NodePath("DeepSeekClient")
@export var audio_player_path: NodePath = NodePath("AudioStreamPlayer")
@export var click_blocker_path: NodePath = NodePath("ClickBlocker")
@export var character_layer_path: NodePath = NodePath("CharacterLayer")
@export var free_chat_info_layer_path: NodePath = NodePath("UIPanel/FreeChatInfoLayer")

var ui_panel: Control = null
var hide_ui_btn: Button = null
var camera_btn: Button = null

var dialogue_panel: Control = null
var name_label: Label = null
var dialogue_text: RichTextLabel = null
var input_layer: Panel = null
var input_field: TextEdit = null
var send_btn: Button = null
var voice_record_btn: Button = null
var quick_options_container: Node = null
var end_chat_btn: Button = null
var history_btn: Button = null

var character_layer: Node = null

var deepseek_client: DeepSeekClient = null
var audio_player: AudioStreamPlayer = null
var mic_capture: AudioStreamPlayer = null
var qwen_asr_client = null

var click_blocker: Control = null

var _ui_tween: Tween = null
var _typewriter_tween: Tween = null
var camera_panel_instance = null
var mobile_interface_instance = null
var _intro_playing: bool = false
var _intro_waiting_for_click: bool = false
var _waiting_for_chat_click: bool = false
var _current_story_speaker_id: String = ""

# Free Chat states
var is_free_chat_mode: bool = false
var free_chat_strategy: String = ""
var free_chat_max_rounds: int = 0
var free_chat_current_round: int = 0
var _script_ai_chat_active: bool = false
var _script_ai_chat_prompt_override: String = ""

var _accumulated_stats: Dictionary = {
	"intimacy": 0.0,
	"trust": 0.0,
	"openness": 0.0,
	"conscientiousness": 0.0,
	"extraversion": 0.0,
	"agreeableness": 0.0,
	"neuroticism": 0.0
}

var free_chat_info_layer: Control = null
var free_chat_round_label: Label = null
var free_chat_strategy_label: RichTextLabel = null

var history_panel = null
var gift_panel = null
var debug_panel = null

var incoming_call_notification_instance = null

var script_engine: ScriptEngineManager = null

signal _intro_click_proceed
signal _chat_click_proceed

const HISTORY_ITEM_SCENE = preload("res://scenes/ui/history/history_item.tscn")
const QUICK_OPTION_LIST_HELPER = preload("res://scripts/ui/story/quick_option_list_helper.gd")

func _resolve_nodes() -> void:
	if ui_panel_path != NodePath(""):
		ui_panel = get_node_or_null(ui_panel_path) as Control
	if dialogue_panel_path != NodePath(""):
		dialogue_panel = get_node_or_null(dialogue_panel_path) as Control

	if not dialogue_panel and ui_panel:
		dialogue_panel = ui_panel.get_node_or_null("DialoguePanel") as Control

	if not ui_panel and dialogue_panel:
		ui_panel = dialogue_panel

	if ui_panel and ui_panel != self and click_blocker_path == NodePath(""):
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	if ui_panel:
		hide_ui_btn = ui_panel.get_node_or_null("UIOverlay/HideUIButton") as Button
		camera_btn = ui_panel.get_node_or_null("UIOverlay/CameraButton") as Button
		free_chat_info_layer = ui_panel.get_node_or_null("FreeChatInfoLayer") as Control
	else:
		hide_ui_btn = null
		camera_btn = null
		free_chat_info_layer = null

	if free_chat_info_layer:
		free_chat_round_label = free_chat_info_layer.get_node_or_null("Panel/Margin/VBox/RoundLabel") as Label
		free_chat_strategy_label = free_chat_info_layer.get_node_or_null("Panel/Margin/VBox/StrategyLabel") as RichTextLabel
	else:
		free_chat_round_label = null
		free_chat_strategy_label = null

	if dialogue_panel:
		name_label = dialogue_panel.get_node_or_null("DialogueLayer/VBox/NameLabel") as Label
		dialogue_text = dialogue_panel.get_node_or_null("DialogueLayer/VBox/RichTextLabel") as RichTextLabel
		input_layer = dialogue_panel.get_node_or_null("InputLayer") as Panel
		input_field = dialogue_panel.get_node_or_null("InputLayer/HBoxContainer/InputField") as TextEdit
		send_btn = dialogue_panel.get_node_or_null("InputLayer/HBoxContainer/SendButton") as Button
		voice_record_btn = dialogue_panel.get_node_or_null("InputLayer/HBoxContainer/VoiceRecordButton") as Button
		quick_options_container = dialogue_panel.get_node_or_null("QuickOptionLayer/ScrollContainer/QuickOptions")
		end_chat_btn = dialogue_panel.get_node_or_null("EndChatButton") as Button
		history_btn = dialogue_panel.get_node_or_null("HistoryButton") as Button
	else:
		name_label = null
		dialogue_text = null
		input_layer = null
		input_field = null
		send_btn = null
		voice_record_btn = null
		quick_options_container = null
		end_chat_btn = null
		history_btn = null

	if character_layer_path != NodePath(""):
		character_layer = get_node_or_null(character_layer_path)
	if click_blocker_path != NodePath(""):
		click_blocker = get_node_or_null(click_blocker_path) as Control

	if deepseek_client_path != NodePath(""):
		deepseek_client = get_node_or_null(deepseek_client_path) as DeepSeekClient
	if not deepseek_client:
		deepseek_client = DeepSeekClient.new()
		deepseek_client.name = "DeepSeekClient"
		add_child(deepseek_client)

	if audio_player_path != NodePath(""):
		audio_player = get_node_or_null(audio_player_path) as AudioStreamPlayer
	if not audio_player:
		audio_player = AudioStreamPlayer.new()
		audio_player.name = "AudioStreamPlayer"
		add_child(audio_player)

	mic_capture = get_node_or_null("MicCapture") as AudioStreamPlayer
	if not mic_capture:
		mic_capture = AudioStreamPlayer.new()
		mic_capture.name = "MicCapture"
		add_child(mic_capture)

func _ready() -> void:
	_resolve_nodes()

	if dialogue_panel:
		dialogue_panel.show()
	
	# 故事场景中，我们现在使用结束按钮退出
	if end_chat_btn:
		end_chat_btn.show()
		# 断开面板自带的结束事件
		if dialogue_panel and dialogue_panel.has_method("_on_end_chat_pressed"):
			var panel_end_callable = Callable(dialogue_panel, "_on_end_chat_pressed")
			if end_chat_btn.pressed.is_connected(panel_end_callable):
				end_chat_btn.pressed.disconnect(panel_end_callable)
		end_chat_btn.pressed.connect(_on_end_chat_pressed)
		
	if click_blocker:
		click_blocker.gui_input.connect(_on_click_blocker_input)
	if dialogue_panel and dialogue_panel.has_signal("panel_clicked"):
		dialogue_panel.panel_clicked.connect(_on_click_blocker_input)
	
	if GameDataManager.config:
		GameDataManager.config.apply_settings()
		
	if hide_ui_btn: hide_ui_btn.pressed.connect(_on_hide_ui_pressed)
	if camera_btn: camera_btn.pressed.connect(_on_camera_pressed)
		
	if history_btn: history_btn.pressed.connect(_on_history_pressed)
	if voice_record_btn:
		voice_record_btn.button_down.connect(_on_voice_record_down)
		voice_record_btn.button_up.connect(_on_voice_record_up)
	if send_btn: send_btn.pressed.connect(_on_send_pressed)
	if input_field: input_field.text_changed.connect(_on_input_text_changed)
	
	GameDataManager.profile.stage_upgraded.connect(_on_stage_upgraded)
	GameDataManager.character_switched.connect(_on_character_switched)
	
	deepseek_client.chat_request_completed.connect(_on_chat_response)
	deepseek_client.chat_request_failed.connect(_on_chat_error)
	deepseek_client.chat_stream_started.connect(_on_chat_stream_started)
	deepseek_client.chat_stream_delta.connect(_on_chat_stream_delta)
	
	deepseek_client.emotion_request_completed.connect(_on_emotion_response)
	deepseek_client.emotion_request_failed.connect(_on_emotion_error)
	
	deepseek_client.memory_request_completed.connect(_on_memory_response)
	deepseek_client.memory_request_failed.connect(_on_memory_error)
	
	deepseek_client.options_request_completed.connect(_on_options_response)
	deepseek_client.options_request_failed.connect(_on_options_error)
	
	deepseek_client.narrator_request_completed.connect(_on_narrator_response)
	deepseek_client.narrator_request_failed.connect(_on_narrator_error)
	
	TTSManager.tts_success.connect(_on_tts_success)
	TTSManager.tts_failed.connect(_on_tts_failed)
	
	if GameDataManager.config.qwen_asr_enabled:
		var qwen_asr_client_script = load("res://scripts/api/qwen_asr_client.gd")
		if qwen_asr_client_script:
			qwen_asr_client = qwen_asr_client_script.new()
			qwen_asr_client.name = "QwenASRClient"
			add_child(qwen_asr_client)
			qwen_asr_client.transcribe_completed.connect(_on_asr_success)
			qwen_asr_client.transcribe_failed.connect(_on_asr_failed)
			print("[DialogueManager] 已启用千问 ASR")
	
	# 初始化并挂载 ScriptEngineManager
	script_engine = ScriptEngineManager.new()
	add_child(script_engine)
	script_engine.on_dialogue_requested.connect(_on_script_dialogue_requested)
	script_engine.on_character_show_requested.connect(_on_script_show_character)
	script_engine.on_character_move_requested.connect(_on_script_move_character)
	script_engine.on_character_hide_requested.connect(_on_script_hide_character)
	script_engine.on_player_info_requested.connect(_on_script_player_info)
	script_engine.on_voice_call_requested.connect(_on_script_voice_call)
	script_engine.on_start_free_chat_requested.connect(_on_script_start_free_chat)
	script_engine.on_background_requested.connect(_on_script_background_requested)
	script_engine.on_bgm_requested.connect(_on_script_bgm_requested)
	script_engine.on_audio_requested.connect(_on_script_audio_requested)
	script_engine.on_variable_set.connect(_on_script_variable_set)
	script_engine.on_ai_chat_requested.connect(_on_script_ai_chat_requested)
	script_engine.script_finished.connect(_on_script_finished)
	
	_update_ui()
	
	# Check if we should play the intro story
	if GameDataManager.has_meta("play_intro_story") and GameDataManager.get_meta("play_intro_story"):
		GameDataManager.remove_meta("play_intro_story")
		_play_intro_story()
		return
		
	# Check if we should play a specific story script
	if GameDataManager.has_meta("play_specific_story"):
		var script_path = GameDataManager.get_meta("play_specific_story")
		GameDataManager.remove_meta("play_specific_story")
		_play_story(script_path)
		return
	
	# 初始问候
	var messages = GameDataManager.history.messages
	if messages.size() == 0:
		var char_name = GameDataManager.profile.char_name
		_show_message("你好...今天想聊点什么？", char_name, false)
	else:
		# 有历史记录时，生成旁白并续写话题
		_generate_narrator_and_continue()

func _play_intro_story() -> void:
	_play_story("res://assets/data/story/scripts/main/intro_story.json")

func _play_story(path: String) -> void:
	_intro_playing = true
	_current_story_speaker_id = ""
	send_btn.disabled = true
	input_field.editable = false
	ui_panel.visible = true
	dialogue_panel.set_story_mode(true)
	input_layer.hide()
	if end_chat_btn:
		end_chat_btn.hide()
	
	modulate.a = 0.0
	var fade_tween = create_tween()
	fade_tween.tween_property(self, "modulate:a", 1.0, 1.0)
	
	if script_engine.load_script(path):
		if script_engine.use_story_portraits():
			if character_layer and character_layer.has_method("begin_story_mode"):
				character_layer.begin_story_mode()
			elif character_layer and character_layer.has_method("hide_character"):
				character_layer.hide()
		elif character_layer and character_layer.has_method("end_story_mode"):
			character_layer.end_story_mode()
		elif character_layer:
			character_layer.hide()
		script_engine.start_script("start")
	else:
		_intro_playing = false
		send_btn.disabled = false
		input_field.editable = true
		input_layer.show()

func _on_script_dialogue_requested(speaker: String, content: String, mood: String, presentation: Dictionary = {}) -> void:
	var portrait_speaker = str(presentation.get("character", "")).strip_edges()
	if portrait_speaker == "":
		portrait_speaker = speaker
	var char_name = _resolve_story_speaker_name(speaker)
	var display_name_override = str(presentation.get("display_name", "")).strip_edges()
	if display_name_override != "":
		char_name = display_name_override
	_current_story_speaker_id = _resolve_story_speaker_id(portrait_speaker)
		
	var actual_content = content
	if GameDataManager.profile:
		actual_content = actual_content.replace("{player_name}", GameDataManager.profile.player_name)
		var p_title = GameDataManager.profile.player_title
		if p_title == "":
			p_title = "老师"
		actual_content = actual_content.replace("{player_title}", p_title)
		
	if script_engine.use_story_portraits() and character_layer and character_layer.has_method("focus_story_speaker"):
		character_layer.focus_story_speaker(portrait_speaker, char_name, mood, presentation)
		
	dialogue_panel.set_story_mode(true)
	await _show_message_async(actual_content, char_name, true)
	script_engine.resume()

func _resolve_story_speaker_name(speaker: String) -> String:
	if speaker == "旁白":
		return " "
	if speaker == "player":
		return "我"
	if speaker == "char":
		return _get_current_story_character_name()

	var speaker_id = speaker.strip_edges().to_lower()
	if speaker_id == "":
		return ""

	if speaker_id == _get_current_story_character_id():
		return _get_current_story_character_name()

	var char_data = _load_story_character_data(speaker_id)
	var char_name = str(char_data.get("char_name", "")).strip_edges()
	if char_name != "":
		return _beautify_story_character_name(char_name)

	if typeof(MapDataManager) != TYPE_NIL:
		var npc_data = MapDataManager.get_npc_data(speaker_id)
		var npc_name = str(npc_data.get("name", "")).strip_edges()
		if npc_name != "":
			return npc_name

	return speaker.capitalize()

func _resolve_story_speaker_id(speaker: String) -> String:
	var normalized = speaker.strip_edges().to_lower()
	if normalized == "" or normalized == "旁白" or normalized == "player" or normalized == "我":
		return ""
	if normalized == "char":
		return _get_current_story_character_id()
	return normalized

func _get_current_story_character_id() -> String:
	if GameDataManager.config == null:
		return ""
	return str(GameDataManager.config.current_character_id).strip_edges().to_lower()

func _get_current_story_character_name() -> String:
	if GameDataManager.profile == null:
		return ""
	return _beautify_story_character_name(str(GameDataManager.profile.char_name).strip_edges())

func _load_story_character_data(char_id: String) -> Dictionary:
	var candidate_paths = [
		"res://assets/data/characters/%s.json" % char_id,
		"res://assets/data/characters/npc/%s.json" % char_id
	]
	for path in candidate_paths:
		if not ResourceLoader.exists(path):
			continue
		var file = FileAccess.open(path, FileAccess.READ)
		if file == null:
			continue
		var json = JSON.new()
		var parse_result = json.parse(file.get_as_text())
		file.close()
		if parse_result == OK and json.data is Dictionary:
			return json.data
	return {}

func _beautify_story_character_name(name: String) -> String:
	if name == "":
		return ""
	if name == name.to_lower():
		return name.capitalize()
	return name

func _on_script_show_character(animation: String, presentation: Dictionary = {}) -> void:
	if not script_engine.use_story_portraits():
		return
	var raw_char_id = str(presentation.get("character", "")).strip_edges()
	if character_layer and raw_char_id != "" and character_layer.has_method("show_story_character"):
		var display_name = str(presentation.get("display_name", "")).strip_edges()
		var full_presentation = presentation.duplicate()
		full_presentation["animation"] = animation
		character_layer.show_story_character(raw_char_id, display_name, full_presentation)
	elif character_layer and character_layer.has_method("show_character"):
		character_layer.show_character(animation)
	elif character_layer:
		character_layer.show()

func _on_script_move_character(animation: String, presentation: Dictionary = {}) -> void:
	if not script_engine.use_story_portraits():
		return
	var raw_char_id = str(presentation.get("character", "")).strip_edges()
	if character_layer and raw_char_id != "" and character_layer.has_method("move_story_character"):
		var display_name = str(presentation.get("display_name", "")).strip_edges()
		var full_presentation = presentation.duplicate()
		full_presentation["animation"] = animation
		character_layer.move_story_character(raw_char_id, display_name, full_presentation)

func _on_script_hide_character(animation: String, presentation: Dictionary = {}) -> void:
	if not script_engine.use_story_portraits():
		return
	var raw_char_id = str(presentation.get("character", "")).strip_edges()
	if character_layer and raw_char_id != "" and character_layer.has_method("hide_story_character"):
		character_layer.hide_story_character(raw_char_id, animation)
	elif character_layer and character_layer.has_method("hide_character"):
		character_layer.hide_character(animation)
	elif character_layer:
		character_layer.hide()

func _on_script_player_info() -> void:
	var popup_scene = load("res://scenes/ui/story/player_info_popup.tscn")
	if popup_scene:
		var popup = popup_scene.instantiate()
		add_child(popup)
		popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		await popup.info_submitted
		
		if popup.player_info.has("name"):
			GameDataManager.profile.player_name = popup.player_info["name"]
		if popup.player_info.has("preferred_title"):
			GameDataManager.profile.player_title = popup.player_info["preferred_title"]
		if popup.player_info.has("gender"):
			GameDataManager.profile.player_gender = popup.player_info["gender"]
		if popup.player_info.has("birthday"):
			GameDataManager.profile.player_birthday = popup.player_info["birthday"]
		if popup.player_info.has("zodiac"):
			GameDataManager.profile.player_zodiac = popup.player_info["zodiac"]
		if popup.player_info.has("mbti"):
			GameDataManager.profile.player_mbti = popup.player_info["mbti"]
		if popup.player_info.has("profession"):
			GameDataManager.profile.player_profession = popup.player_info["profession"]
		if popup.player_info.has("avatar_path"):
			GameDataManager.profile.player_avatar_path = popup.player_info["avatar_path"]

		if GameDataManager.config:
			if popup.player_info.has("name"):
				GameDataManager.config.player_name = popup.player_info["name"]
			if popup.player_info.has("preferred_title"):
				GameDataManager.config.player_nickname = popup.player_info["preferred_title"]
			GameDataManager.config.save_config()
			
		GameDataManager.profile.save_profile()
		popup.queue_free()
	script_engine.resume()

func _on_script_voice_call(call_id: String) -> void:
	var fixed_calls_path = "res://assets/data/story/scripts/calls/fixed_calls.json"
	var call_data = []
	if FileAccess.file_exists(fixed_calls_path):
		var file = FileAccess.open(fixed_calls_path, FileAccess.READ)
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			call_data = json.data
			
	var target_call_id = call_id
	var call_lines = []
	var char_id = "ya"
	for call in call_data:
		if call.get("id") == target_call_id:
			call_lines = call.get("lines", [])
			char_id = call.get("char_id", "ya")
			break
			
	GameDataManager.set_meta("pending_fixed_call_data", call_lines)
	
	if is_instance_valid(incoming_call_notification_instance):
		incoming_call_notification_instance.queue_free()
		
	var NotificationObj = load("res://scenes/ui/main/incoming_call_notification.tscn")
	var notification = NotificationObj.instantiate()
	incoming_call_notification_instance = notification
	add_child(notification)
	notification.show_incoming_call(char_id, false, true)
	
	var original_ui_visible = ui_panel.visible
	ui_panel.visible = false
	
	await notification.call_accepted
	notification.queue_free()
	
	if mobile_interface_instance == null:
		var MobileInterfaceObj = load("res://scenes/ui/mobile/mobile_interface.tscn")
		mobile_interface_instance = MobileInterfaceObj.instantiate()
		add_child(mobile_interface_instance)
		mobile_interface_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		
	mobile_interface_instance.show_phone()
	mobile_interface_instance.open_call_directly(char_id, false, true)
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	if mobile_interface_instance.chat_panel_instance:
		await mobile_interface_instance.chat_panel_instance.incoming_call_ended
	
	# If we created it just for this, we might want to hide it
	if is_instance_valid(mobile_interface_instance):
		mobile_interface_instance.hide_phone()
	
	ui_panel.visible = original_ui_visible
	script_engine.resume()

func _on_script_start_free_chat(strategy: String, max_rounds: int) -> void:
	is_free_chat_mode = true
	free_chat_strategy = strategy
	free_chat_max_rounds = max_rounds
	free_chat_current_round = 0
	_update_free_chat_info()
	free_chat_info_layer.show()
	
	_intro_playing = false
	input_layer.show()
	input_field.editable = true
	send_btn.disabled = false
	if end_chat_btn:
		end_chat_btn.show()
	
	var char_name = GameDataManager.profile.char_name
	dialogue_panel.set_story_mode(false)
	await _show_message_async("我们聊聊吧...", char_name, false)
	script_engine.resume()

func _on_script_background_requested(bg_path: String, duration: float, transition_type: String) -> void:
	if bg_path != "" and ResourceLoader.exists(bg_path):
		var tex = load(bg_path)
		# 尝试寻找所有可能的背景节点，优先寻找故事场景的 BackgroundLayer
		var bg_node = null
		if get_parent() and get_parent().has_node("BackgroundLayer"):
			bg_node = get_parent().get_node("BackgroundLayer")
		
		# 兼容旧逻辑和自身内部的节点
		if not bg_node:
			bg_node = get_node_or_null("BackgroundLayer")
		
		# 兼容 main_scene.gd 的结构
		if not bg_node and get_parent() and get_parent().has_node("MainBg"):
			bg_node = get_parent().get_node("MainBg")
		
		if bg_node and bg_node is TextureRect:
			if duration > 0:
				BackgroundTransitionHelper.execute_transition(bg_node, tex, duration, transition_type, func(): script_engine.resume())
			else:
				bg_node.texture = tex
				script_engine.resume()
		else:
			print("[ScriptEngine] 警告：找到了背景资源，但未找到对应的 TextureRect 背景节点！", bg_node)
			script_engine.resume()
	else:
		print("[ScriptEngine] 警告：无法加载背景图片 -> ", bg_path)
		script_engine.resume()

func _on_script_bgm_requested(audio_path: String, fade_time: float) -> void:
	# 如果有全局 AudioManager，最好调用它；这里演示使用自带的或全局逻辑
	# 假设 AudioManager 存在且支持 crossfade
	if has_node("/root/AudioManager"):
		var am = get_node("/root/AudioManager")
		if am.has_method("play_bgm"):
			am.play_bgm(audio_path, fade_time)
	else:
		print("[ScriptEngine] Warning: AudioManager not found, BGM skipped.")
	script_engine.resume()

func _on_script_audio_requested(audio_type: String, action: String, audio_id: String, fade_time: float, loop: bool) -> void:
	if action == "play":
		if audio_type == "bgm":
			AudioManager.play_bgm(audio_id, fade_time)
		elif audio_type == "bgs":
			AudioManager.play_bgs(audio_id, fade_time)
		elif audio_type == "se":
			AudioManager.play_se(audio_id, loop)
	elif action == "stop":
		if audio_type == "bgm":
			AudioManager.stop_bgm(fade_time)
		elif audio_type == "bgs":
			AudioManager.stop_bgs(fade_time)
		elif audio_type == "se":
			AudioManager.stop_se(audio_id)
	script_engine.resume()

func _on_script_variable_set(var_name: String, var_value: Variant) -> void:
	GameDataManager.set_meta(var_name, var_value)
	script_engine.resume()

func _on_script_ai_chat_requested(prompt_override: String) -> void:
	# 暂停脚本，进入临时 AI 自由对话，等待玩家主动结束后再恢复剧情。
	print("[ScriptEngine] 触发临时 AI Chat: ", prompt_override)
	_script_ai_chat_active = true
	_script_ai_chat_prompt_override = prompt_override
	is_free_chat_mode = true
	free_chat_strategy = prompt_override
	free_chat_max_rounds = 0
	free_chat_current_round = 0
	_update_free_chat_info()
	free_chat_info_layer.show()
	
	_intro_playing = false
	dialogue_panel.set_story_mode(false)
	quick_options_container.get_parent().show()
	input_layer.show()
	input_field.editable = true
	send_btn.disabled = false
	if end_chat_btn:
		end_chat_btn.show()

	var char_name = GameDataManager.profile.char_name
	var enter_text = "我们聊聊吧..."
	if prompt_override.strip_edges() != "":
		enter_text = "我们继续聊这个话题吧。\n[color=gray]%s[/color]" % prompt_override
	await _show_message_async(enter_text, char_name, true)

func _on_script_finished(script_id: String) -> void:
	print("Script finished: ", script_id)
	_current_story_speaker_id = ""
	if character_layer and character_layer.has_method("end_story_mode"):
		character_layer.end_story_mode()
	var is_first_completion := not GameDataManager.profile.has_finished_story(script_id)
	GameDataManager.profile.mark_story_finished(script_id)
	if is_first_completion:
		_register_story_completion_memory(script_id)
	if script_id == "intro_story":
		GameDataManager.set_meta("just_finished_intro_story", true)
		# 如果当前是根场景（例如初次进入的开场剧情），剧情结束应该切换到主场景
		if get_parent() == get_tree().root:
			if get_tree().root.has_node("SceneTransitionManager"):
				get_tree().root.get_node("SceneTransitionManager").transition_to_scene("res://scenes/ui/main/main_scene.tscn")
			else:
				get_tree().change_scene_to_file("res://scenes/ui/main/main_scene.tscn")
		else:
			# 如果 dialogue_manager 不是作为单独的 root 场景运行，
			# 说明它是嵌套在 main_scene 中的，我们直接触发跳转即可
			if get_tree().root.has_node("SceneTransitionManager"):
				get_tree().root.get_node("SceneTransitionManager").transition_to_scene("res://scenes/ui/main/main_scene.tscn")
			else:
				get_tree().change_scene_to_file("res://scenes/ui/main/main_scene.tscn")
	else:
		# 普通剧情剧本结束后，如果不是作为主界面常驻（比如是在日程执行中弹出的），则自动关闭
		if get_parent() != get_tree().root and not (get_parent().name == "MainScene" or get_parent().name == "UI"):
			# AI 聊天结束或者故事结束，发出信号，等待外部进行黑屏遮挡后再由外部负责 queue_free，
			# 从而避免默认的突兀消失效果。
			chat_closed.emit()

func _register_story_completion_memory(script_id: String) -> void:
	if GameDataManager.memory_manager == null or script_engine == null:
		return

	var script_meta = script_engine.get_current_script_meta() if script_engine.has_method("get_current_script_meta") else {}
	if not bool(script_meta.get("memory_enabled", true)):
		return

	var memory_records = _build_story_completion_memory_records(script_id, script_meta)
	for record in memory_records:
		if not record is Dictionary:
			continue
		var memory_content = _build_story_completion_memory_content(script_id, script_meta, record)
		if memory_content == "":
			continue
		var memory_layer = str(record.get("layer", script_meta.get("memory_layer", "bond"))).strip_edges()
		if memory_layer == "":
			memory_layer = "bond"
		var memory_context = _build_story_completion_memory_context(script_meta, record)
		var memory_scope = _resolve_story_memory_scope(record, script_meta)
		var memory_visibility = _resolve_story_memory_visibility(record, script_meta, memory_scope)
		var memory_participants = _resolve_story_memory_participants(record, script_meta)
		var memory_player_involved = _resolve_story_memory_player_involved(record, script_meta, memory_scope)
		var memory_player_witnessed = _resolve_story_memory_player_witnessed(record, script_meta, memory_scope)
		var memory_options = {
			"is_bond_mark": bool(record.get("is_bond_mark", script_meta.get("memory_is_bond_mark", memory_layer == "bond"))),
			"source_type": "story_script",
			"source_id": script_id,
			"source_title": str(record.get("title", script_meta.get("memory_title", script_id))),
			"memory_scope": memory_scope,
			"memory_visibility": memory_visibility,
			"memory_participants": memory_participants,
			"memory_player_involved": memory_player_involved,
			"memory_player_witnessed": memory_player_witnessed
		}
		GameDataManager.memory_manager.add_memory_quick(memory_layer, memory_content, memory_context, memory_options)

func _build_story_completion_memory_records(script_id: String, script_meta: Dictionary) -> Array:
	var configured = script_meta.get("memory_records", [])
	var results: Array = []
	if configured is Array:
		for item in configured:
			if item is Dictionary and bool(item.get("enabled", true)):
				results.append(item.duplicate(true))
	if not results.is_empty():
		return results
	return [{
		"layer": str(script_meta.get("memory_layer", "bond")),
		"title": str(script_meta.get("memory_title", script_id)),
		"content": str(script_meta.get("memory_summary", "")),
		"is_bond_mark": bool(script_meta.get("memory_is_bond_mark", true))
	}]

func _normalize_story_memory_participants(raw_value: Variant) -> Array:
	var results: Array = []
	if not raw_value is Array:
		return results
	for item in raw_value:
		var participant = str(item).strip_edges().to_lower()
		if participant != "" and not results.has(participant):
			results.append(participant)
	return results

func _resolve_story_memory_participants(record: Dictionary, script_meta: Dictionary) -> Array:
	if record.has("participants"):
		return _normalize_story_memory_participants(record.get("participants", []))
	if bool(script_meta.get("memory_participants_explicit", false)):
		return _normalize_story_memory_participants(script_meta.get("memory_participants", []))
	return []

func _resolve_story_memory_scope(record: Dictionary, script_meta: Dictionary) -> String:
	var explicit_scope = ""
	if record.has("scope"):
		explicit_scope = str(record.get("scope", "")).strip_edges()
	elif bool(script_meta.get("memory_scope_explicit", false)):
		explicit_scope = str(script_meta.get("memory_scope", "")).strip_edges()
	if explicit_scope != "":
		if GameDataManager.memory_manager and GameDataManager.memory_manager.has_method("normalize_memory_scope"):
			return GameDataManager.memory_manager.normalize_memory_scope(explicit_scope)
		return explicit_scope.to_lower()

	var participants = _resolve_story_memory_participants(record, script_meta)
	var has_player_involved = record.has("player_involved") or bool(script_meta.get("memory_player_involved_explicit", false))
	var has_player_witnessed = record.has("player_witnessed") or bool(script_meta.get("memory_player_witnessed_explicit", false))
	var player_involved = bool(record.get("player_involved", script_meta.get("memory_player_involved", false)))
	var player_witnessed = bool(record.get("player_witnessed", script_meta.get("memory_player_witnessed", false)))

	if has_player_involved or has_player_witnessed:
		if player_involved:
			return "player_shared"
		if player_witnessed:
			return "player_observed"
		if participants.size() >= 2:
			return "npc_social"
		if participants.size() == 1:
			return "private_self"
		return "world_fact"

	if participants.has("player"):
		return "player_shared"
	if participants.size() >= 2:
		return "npc_social"
	if participants.size() == 1:
		return "private_self"
	return "player_observed"

func _get_story_memory_default_visibility(scope: String) -> String:
	if GameDataManager.memory_manager and GameDataManager.memory_manager.has_method("get_default_visibility_for_scope"):
		return GameDataManager.memory_manager.get_default_visibility_for_scope(scope)
	match scope:
		"player_shared":
			return "prompt"
		"player_observed":
			return "conditional"
		"private_self":
			return "hidden"
		"npc_social", "world_fact":
			return "archive_only"
		_:
			return "conditional"

func _resolve_story_memory_visibility(record: Dictionary, script_meta: Dictionary, scope: String) -> String:
	var explicit_visibility = ""
	if record.has("visibility"):
		explicit_visibility = str(record.get("visibility", "")).strip_edges()
	elif bool(script_meta.get("memory_visibility_explicit", false)):
		explicit_visibility = str(script_meta.get("memory_visibility", "")).strip_edges()
	if explicit_visibility != "":
		if GameDataManager.memory_manager and GameDataManager.memory_manager.has_method("normalize_memory_visibility"):
			return GameDataManager.memory_manager.normalize_memory_visibility(explicit_visibility, scope)
		return explicit_visibility.to_lower()
	return _get_story_memory_default_visibility(scope)

func _resolve_story_memory_player_involved(record: Dictionary, script_meta: Dictionary, scope: String) -> bool:
	if record.has("player_involved"):
		return bool(record.get("player_involved", false))
	if bool(script_meta.get("memory_player_involved_explicit", false)):
		return bool(script_meta.get("memory_player_involved", false))
	return scope == "player_shared"

func _resolve_story_memory_player_witnessed(record: Dictionary, script_meta: Dictionary, scope: String) -> bool:
	if record.has("player_witnessed"):
		return bool(record.get("player_witnessed", false))
	if bool(script_meta.get("memory_player_witnessed_explicit", false)):
		return bool(script_meta.get("memory_player_witnessed", false))
	return scope == "player_shared" or scope == "player_observed"

func _build_story_completion_memory_context(script_meta: Dictionary, record: Dictionary = {}) -> Dictionary:
	var context = GameDataManager.memory_manager.build_story_memory_context() if GameDataManager.memory_manager else {}
	context["context_domain"] = "story"
	context["time_type"] = "story"
	context["day_offset"] = int(record.get("day_offset", script_meta.get("day_offset", 0)))
	context["story_period"] = str(record.get("story_period", script_meta.get("story_period", "")))
	context["story_location_id"] = str(record.get("story_location_id", script_meta.get("story_location_id", "")))
	context["story_area_id"] = str(record.get("story_area_id", script_meta.get("story_area_id", "")))
	context["story_time"] = _format_story_memory_time_label(context)
	return context

func _build_story_completion_memory_content(script_id: String, script_meta: Dictionary, record: Dictionary = {}) -> String:
	var configured = str(record.get("content", script_meta.get("memory_summary", ""))).strip_edges()
	if configured != "":
		return configured

	var summary = str(record.get("summary", script_meta.get("summary", ""))).strip_edges()
	if summary == "":
		return ""

	var story_period = str(record.get("story_period", script_meta.get("story_period", ""))).strip_edges()
	var location_name = _get_story_location_display_name(str(record.get("story_location_id", script_meta.get("story_location_id", ""))))
	var prefix_parts: Array[String] = []
	if location_name != "":
		prefix_parts.append(location_name)
	if story_period != "":
		prefix_parts.append(story_period)
	var prefix = "在%s，" % "·".join(prefix_parts) if not prefix_parts.is_empty() else ""
	return "%s%s" % [prefix, summary]

func _format_story_memory_time_label(context: Dictionary) -> String:
	var day_number = int(context.get("day_offset", 0)) + 1
	var period = str(context.get("story_period", "")).strip_edges()
	return "第%d天%s%s" % [day_number, "·" if period != "" else "", period]

func _get_story_location_display_name(location_id: String) -> String:
	var final_id = location_id.strip_edges()
	if final_id == "" or typeof(MapDataManager) == TYPE_NIL:
		return ""
	var location = MapDataManager.get_location(final_id)
	if location.is_empty():
		return ""
	return str(location.get("name", final_id))

func _update_free_chat_info() -> void:
	if free_chat_round_label:
		if free_chat_max_rounds > 0:
			free_chat_round_label.text = "自由对话轮次: %d / %d" % [free_chat_current_round, free_chat_max_rounds]
		else:
			free_chat_round_label.text = "自由对话"
		
	if free_chat_strategy_label:
		if free_chat_strategy != "":
			free_chat_strategy_label.text = "策略: " + free_chat_strategy
		else:
			free_chat_strategy_label.text = ""

func _reset_free_chat_state() -> void:
	is_free_chat_mode = false
	free_chat_strategy = ""
	free_chat_max_rounds = 0
	free_chat_current_round = 0
	_update_free_chat_info()
	if free_chat_info_layer:
		free_chat_info_layer.hide()

func _finish_script_ai_chat() -> void:
	_script_ai_chat_active = false
	_script_ai_chat_prompt_override = ""
	_reset_free_chat_state()
	_waiting_for_chat_exit = false
	dialogue_panel.set_story_mode(true)
	input_layer.hide()
	quick_options_container.get_parent().show()
	if end_chat_btn:
		end_chat_btn.hide()
	send_btn.disabled = true
	input_field.editable = false
	pending_options_data.clear()
	if script_engine and script_engine.is_running:
		script_engine.resume()

func _send_player_message(text: String, is_system_event: bool = false) -> void:
	if not is_system_event and input_field:
		input_field.text = ""
		
		if is_free_chat_mode:
			free_chat_current_round += 1
			_update_free_chat_info()
			
	send_btn.disabled = true
	input_field.editable = false
	
	# 发起请求前清除之前的选项
	pending_options_data.clear()
	for child in quick_options_container.get_children():
		child.queue_free()
		
	if not is_system_event:
		# Wait for the typewriter effect of the player's message to finish before requesting AI response
		await _show_message_async(text, "我")
	
	_request_ai_response(text, is_system_event)
	
	# 检查是否达到最大轮次，在发送请求后关闭模式，这样本次请求还能带上策略
	if is_free_chat_mode and free_chat_max_rounds > 0 and free_chat_current_round >= free_chat_max_rounds:
		_reset_free_chat_state()
		ToastManager.show_system_toast("自由对话阶段结束", Color(0.8, 0.4, 0.1, 0.9))
		
		# 如果是作为独立剧情执行的最后一个事件，手动调用恢复以触发 _on_script_finished
		if script_engine.is_running:
			script_engine.resume()

func _generate_narrator_and_continue() -> void:
	send_btn.disabled = true
	input_field.editable = false
	print("正在生成场景旁白...")
	# 清空对话框内容，保持干净
	if dialogue_text:
		dialogue_text.text = ""
	if name_label:
		name_label.text = ""
	deepseek_client.send_narrator_generation()

func _on_narrator_response(response: Dictionary) -> void:
	if response.has("choices") and response["choices"].size() > 0:
		var narrator_text = response["choices"][0]["message"]["content"].strip_edges()
		
		# 显示旁白，无角色名，不发声，不记录到历史
		await _show_message_async(narrator_text, " ", true)
		
		# 旁白显示完后等待一小段时间
		if is_inside_tree():
			await get_tree().create_timer(1.5).timeout
			
		# 触发角色续写话题
		_trigger_character_continue()
	else:
		_on_narrator_error("旁白生成为空")

func _on_narrator_error(error_msg: String) -> void:
	print("旁白生成失败: ", error_msg)
	# 兜底：如果旁白失败，直接恢复最后一条消息或让角色直接说话
	_restore_last_message()
	send_btn.disabled = false
	input_field.editable = true

func _trigger_character_continue() -> void:
	print("旁白生成完毕，正在思考后续对话...")
	var char_name = GameDataManager.profile.char_name
	
	is_text_playback_finished = false
	pending_options_data.clear()
	
	# 计算玩家离线时间
	var offline_seconds = 0
	var last_time = GameDataManager.profile.last_online_time
	if last_time > 0:
		offline_seconds = Time.get_unix_time_from_system() - last_time
	
	# 获取性格系统动态生成的重逢问候策略
	var greeting_strategy = GameDataManager.personality_system.get_offline_greeting_strategy(GameDataManager.profile, offline_seconds)
	
	# 构造一条系统级的隐式 prompt，让 LLM 知道它需要主动续写话题
	var continue_prompt = "【系统提示：%s。注意：绝对不要输出这段系统提示，直接以%s的口吻说话。】" % [greeting_strategy, char_name]
	
	if GameDataManager.config.ai_mode_enabled:
		# 续聊首句优先开口，避免 embedding 阻塞重逢问候。
		var system_prompt = GameDataManager.prompt_manager.build_chat_prompt(GameDataManager.profile, continue_prompt, [])
		var api_messages = [{"role": "system", "content": system_prompt}]
		api_messages.append_array(deepseek_client._get_history_messages(10))
		api_messages.append({"role": "user", "content": continue_prompt})
		
		var body = {
			"model": GameDataManager.config.model,
			"messages": api_messages,
			"temperature": GameDataManager.config.temperature,
			"max_tokens": GameDataManager.config.max_tokens
		}
		deepseek_client.chat_http.request(deepseek_client._get_url(), deepseek_client._get_headers(), HTTPClient.METHOD_POST, JSON.stringify(body))
	else:
		_show_message("（离线模式）你回来了，我们刚才聊到哪了？", char_name)
		send_btn.disabled = false
		input_field.editable = true

func _restore_last_message() -> void:
	var messages = GameDataManager.history.messages
	if messages.size() > 0:
		var last_msg = messages[messages.size() - 1]
		# 直接静默显示最后一条，不触发打字机和语音
		if dialogue_text:
			dialogue_text.text = last_msg["text"]
			dialogue_text.visible_characters = -1
		if name_label:
			name_label.text = last_msg["speaker"]
		
		# 恢复对应立绘
		if last_msg["speaker"] == GameDataManager.profile.char_name:
			var current_expression = GameDataManager.profile.current_expression
			_update_character_sprite(current_expression)
	else:
		var char_name = GameDataManager.profile.char_name
		# 如果没有历史记录，静默显示初始问候
		if dialogue_text:
			dialogue_text.text = "你好...今天想聊点什么？"
			dialogue_text.visible_characters = -1
		if name_label:
			name_label.text = char_name

func _on_input_text_changed() -> void:
	if input_field and input_field.text.length() > 120:
		input_field.text = input_field.text.substr(0, 120)
		input_field.set_caret_column(120)

func _update_ui() -> void:
	pass

func _on_character_switched(char_id: String) -> void:
	ToastManager.show_system_toast("已切换到角色：" + char_id, Color.CYAN)
	
	# 清空现有对话UI
	if dialogue_text:
		dialogue_text.text = ""
	if name_label:
		name_label.text = ""
	
	_update_ui()
	
	# 初始问候或恢复历史记录
	var messages = GameDataManager.history.messages
	if messages.size() == 0:
		var char_name = GameDataManager.profile.char_name
		_show_message("你好...今天想聊点什么？", char_name, false)
	else:
		_restore_last_message()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F10:
			GameDataManager.switch_character("luna")
		elif event.keycode == KEY_F11:
			GameDataManager.switch_character("ya")
		elif event.keycode == KEY_F12:
			if debug_panel == null:
				if DEBUG_PANEL_SCENE == null:
					push_error("[DialogueManager] 无法加载调试面板场景：res://scenes/ui/story/debug_panel.tscn")
					return
				debug_panel = DEBUG_PANEL_SCENE.instantiate()
				add_child(debug_panel)
				debug_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				debug_panel.stage_changed.connect(_on_debug_stage_changed)
				debug_panel.show_panel() # Instantiate and show directly
			elif debug_panel.visible:
				debug_panel.hide()
			else:
				debug_panel.show_panel()

func show_panel() -> void:
	show()
	var target: CanvasItem = ui_panel if ui_panel and ui_panel != self else self
	target.show()
	target.modulate.a = 0.0
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(target, "modulate:a", 1.0, 0.3)
	if target is Control:
		target.scale = Vector2(0.95, 0.95)
		target.pivot_offset = get_viewport_rect().size / 2.0
		var scale_tween = create_tween()
		scale_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		scale_tween.tween_property(target, "scale", Vector2(1.0, 1.0), 0.3)

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

func hide_panel() -> void:
	_show_accumulated_stats()
	var target: CanvasItem = ui_panel if ui_panel and ui_panel != self else self
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tween.tween_property(target, "modulate:a", 0.0, 0.2)
	if target is Control:
		var scale_tween = create_tween()
		scale_tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
		scale_tween.tween_property(target, "scale", Vector2(0.9, 0.9), 0.2)
	tween.finished.connect(func():
		if dialogue_panel and dialogue_panel.has_method("set_story_mode"):
			dialogue_panel.set_story_mode(false)
		if target != self:
			target.hide()
		hide()
		chat_closed.emit()
		
		# 强制检查：如果正在运行剧情且没有因为正常轮次耗尽而结束，玩家手动退出了界面，
		# 我们也视作当前挂起的剧情结束，防止无法保存剧情状态。
		if script_engine.is_running:
			script_engine._end_script()
		_script_ai_chat_active = false
		_script_ai_chat_prompt_override = ""
		_reset_free_chat_state()
			
		# 重置等待标志
		_waiting_for_chat_exit = false
		
		# 如果当前是根场景（例如初次进入的开场剧情），返回应该切换到主场景
		if get_parent() == get_tree().root:
			if get_tree().root.has_node("SceneTransitionManager"):
				get_tree().root.get_node("SceneTransitionManager").transition_to_scene("res://scenes/ui/main/main_scene.tscn")
			else:
				get_tree().change_scene_to_file("res://scenes/ui/main/main_scene.tscn")
	)

func _on_hide_ui_pressed() -> void:
	if _ui_tween:
		_ui_tween.kill()
	_ui_tween = create_tween()
	_ui_tween.tween_property(ui_panel, "modulate:a", 0.0, 0.3)
	_ui_tween.tween_callback(func(): ui_panel.visible = false)

func _on_click_blocker_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if camera_panel_instance and camera_panel_instance.visible:
			return
			
		if not ui_panel.visible or ui_panel.modulate.a < 0.99:
			get_viewport().set_input_as_handled()
			if _ui_tween:
				_ui_tween.kill()
			ui_panel.visible = true
			_ui_tween = create_tween()
			_ui_tween.tween_property(ui_panel, "modulate:a", 1.0, 0.3)
		else:
			if dialogue_text.visible_ratio < 1.0:
				get_viewport().set_input_as_handled()
				if _typewriter_tween:
					_typewriter_tween.kill()
				dialogue_text.visible_ratio = 1.0
				dialogue_text.visible_characters = -1
				
				# Make sure we finish the tween's intended outcome immediately if we killed it
				# We don't emit finished here, but we can wait briefly and then if it's intro we wait for next click
				
				# ADDED: If we just finished the text, we should NOT emit proceed immediately,
				# the next click should emit proceed.
			elif _intro_playing and _intro_waiting_for_click:
				get_viewport().set_input_as_handled()
				_intro_waiting_for_click = false
				_intro_click_proceed.emit()
				print("[Debug] _intro_click_proceed signal emitted")
			elif _waiting_for_chat_click:
				get_viewport().set_input_as_handled()
				_waiting_for_chat_click = false
				_chat_click_proceed.emit()
				print("[Debug] _chat_click_proceed signal emitted")

func _gui_input(event: InputEvent) -> void:
	pass

func _unhandled_input(event: InputEvent) -> void:
	pass

func _on_camera_pressed() -> void:
	if camera_panel_instance == null:
		var CameraPanelObj = load("res://scenes/ui/mobile/camera_panel.tscn")
		camera_panel_instance = CameraPanelObj.instantiate()
		get_tree().get_root().add_child(camera_panel_instance)
		camera_panel_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		camera_panel_instance.camera_closed.connect(_on_camera_closed)
		
	camera_panel_instance.show_panel()
	
	if _ui_tween:
		_ui_tween.kill()
	ui_panel.visible = false
	ui_panel.modulate.a = 0.0

func _on_camera_closed() -> void:
	ui_panel.visible = true
	if _ui_tween:
		_ui_tween.kill()
	_ui_tween = create_tween()
	_ui_tween.tween_property(ui_panel, "modulate:a", 1.0, 0.3)

func _on_end_chat_pressed() -> void:
	if not GameDataManager.config.ai_mode_enabled:
		_show_message("（离线模式）下次再见！", GameDataManager.profile.char_name)
		await get_tree().create_timer(1.5).timeout
		if _script_ai_chat_active:
			_finish_script_ai_chat()
		else:
			chat_closed.emit()
		return
		
	# 隐藏玩家输入框和玩家选项
	input_layer.hide()
	quick_options_container.get_parent().hide() # 隐藏整个 QuickOptionLayer/ScrollContainer
	end_chat_btn.hide()
	
	send_btn.disabled = true
	input_field.editable = false
	
	is_text_playback_finished = false
	pending_options_data.clear()
	
	var char_name = GameDataManager.profile.char_name
	
	# 从历史记录中提取最近的几条对话上下文作为参考
	var recent_history = GameDataManager.profile.get_recent_chat_history_text_by_type("story_chat", 3)
	
	var prompt = GameDataManager.prompt_manager.build_end_chat_prompt(GameDataManager.profile, recent_history)
	
	# 发送隐藏系统消息来获取告别回复
	deepseek_client.send_chat_message(prompt, "story_chat")
	
	# 设定一个特殊标记，表示 AI 下一句话结束后应该退出面板
	_waiting_for_chat_exit = true

var _waiting_for_chat_exit: bool = false
var _mood_analysis_running: bool = false
var _pending_mood_analysis_line: String = ""

func _on_voice_record_down() -> void:
	if voice_record_btn:
		voice_record_btn.text = "松开发送"
		voice_record_btn.modulate = Color(0.8, 0.2, 0.2)
	if GameDataManager.config.qwen_asr_enabled and qwen_asr_client:
		qwen_asr_client.start_recording()

func _on_voice_record_up() -> void:
	if voice_record_btn:
		voice_record_btn.text = "按住说话"
		voice_record_btn.modulate = Color(1, 1, 1)
	if GameDataManager.config.qwen_asr_enabled and qwen_asr_client:
		ToastManager.show_system_toast("正在识别语音...", Color.YELLOW)
		qwen_asr_client.stop_recording()

func _on_asr_success(text: String) -> void:
	if not text.is_empty() and input_field:
		input_field.text = text
		ToastManager.show_system_toast("语音识别成功", Color.GREEN)
	else:
		ToastManager.show_system_toast("未听清你说什么", Color.ORANGE)

func _on_asr_failed(err: String) -> void:
	ToastManager.show_system_toast("语音识别失败: " + err, Color.RED)
	print("ASR Error: ", err)

func _on_gift_pressed() -> void:
	if gift_panel == null:
		var GiftPanelObj = load("res://scenes/ui/gift/gift_panel.tscn")
		gift_panel = GiftPanelObj.instantiate()
		add_child(gift_panel)
		gift_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		gift_panel.gift_sent.connect(_on_gift_sent)
		
	gift_panel.show_panel()

func _on_gift_sent(gift_data: Dictionary) -> void:
	var profile = GameDataManager.profile
	var gift_id = gift_data.get("id", "")
	if gift_id == "":
		return
	var gift = GameDataManager.gift_manager.get_gift_by_id(gift_id)
	if gift.is_empty():
		return
		
	var res = GameDataManager.gift_manager.send_gift(profile, gift_id)
	if res.success:
		# 显示Toast
		ToastManager.show_toast("送出了 [%s]" % gift.name, Color(0.6, 0.4, 0.8, 0.9))
		if res.gained_intimacy > 0:
			ToastManager.show_stat_toast("intimacy", "亲密 +%.1f" % res.gained_intimacy)
		if res.gained_trust > 0:
			ToastManager.show_stat_toast("trust", "信任 +%.1f" % res.gained_trust)
		
		_update_ui()
		
		# 触发LLM生成对应的感谢/反应
		_trigger_gift_reaction(gift)
	else:
		ToastManager.show_system_toast(res.msg, Color.RED)

func _trigger_gift_reaction(gift: Dictionary) -> void:
	send_btn.disabled = true
	input_field.editable = false
	
	is_text_playback_finished = false
	pending_options_data.clear()
	
	var char_name = GameDataManager.profile.char_name
	var dyn_traits = GameDataManager.personality_system.get_dynamic_traits(GameDataManager.profile)
	var prompt = "【系统动作：玩家刚刚送给了你一份礼物，名称是：“%s”，描述是：“%s”。请根据你们当前的关系状态（亲密度：%.1f，信任度：%.1f，风味：%s）以及礼物的内容，给出自然的反应和台词。注意：不要输出这段系统提示，直接以%s的口吻说话。】" % [gift.name, gift.desc, GameDataManager.profile.intimacy, GameDataManager.profile.trust, dyn_traits, char_name]
	
	if GameDataManager.config.ai_mode_enabled:
		deepseek_client.send_chat_message(prompt)
	else:
		if is_inside_tree():
			await get_tree().create_timer(1.0).timeout
		_show_message("（离线模式）谢谢你的礼物！我很喜欢。", char_name)
		send_btn.disabled = false
		input_field.editable = true

func _on_debug_stage_changed(stage: int) -> void:
	ToastManager.show_system_toast("【Debug】强制切换情感阶段至：" + str(stage), Color.CYAN)
	GameDataManager.profile.force_set_stage(stage)
	# Clear short term history so the AI doesn't get confused by previous stage's context
	GameDataManager.history.messages.clear()
	GameDataManager.history.save_history()
	_update_ui()
	ToastManager.show_system_toast("已清空上下文历史，以重新适配新阶段", Color.GRAY)

func _on_stage_upgraded(new_stage: int, unlock_dialog: String) -> void:
	ToastManager.show_system_toast("情感阶段提升至: Stage " + str(new_stage), Color.YELLOW)
	
	var stage_conf = GameDataManager.profile.get_current_stage_config()
	if stage_conf.has("mood_switch"):
		var new_mood = stage_conf["mood_switch"]
		if GameDataManager.expression_system.is_valid_expression(new_mood):
			GameDataManager.profile.update_expression(new_mood)
			ToastManager.show_system_toast("表情切换为：" + new_mood, Color.ORANGE)

func _on_debug_mood_changed(expression: String) -> void:
	ToastManager.show_system_toast("【Debug】强制切换表情至：" + expression, Color.CYAN)
	GameDataManager.profile.update_expression(expression)
	_update_ui()

func _update_character_sprite(expression: String) -> void:
	var sprite_path = GameDataManager.expression_system.get_expression_sprite_path(expression)
	if sprite_path != "":
		var tex = load(sprite_path)
		if tex:
			if character_layer and character_layer.has_method("update_sprite"):
				character_layer.update_sprite(tex)
			elif character_layer is TextureRect:
				character_layer.texture = tex
			elif character_layer is Sprite2D:
				character_layer.texture = tex

func _on_history_pressed() -> void:
	if history_panel == null:
		var HistoryPanelObj = load("res://scenes/ui/history/history_panel.tscn")
		history_panel = HistoryPanelObj.instantiate()
		add_child(history_panel)
		history_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		if history_panel.has_signal("play_voice_requested"):
			history_panel.play_voice_requested.connect(_play_cached_voice)
	
	if history_panel.has_method("show_module"):
		history_panel.show_module("story")
	else:
		history_panel.show()

func _on_history_close_pressed() -> void:
	if history_panel:
		history_panel.hide()

func _play_cached_voice(cache_key: String) -> void:
	var stream = TTSManager.load_cached_audio_by_key(cache_key)
	if stream and audio_player:
		audio_player.stream = stream
		audio_player.play()
		return

	var history_text := ""
	for msg in GameDataManager.history.messages:
		if str(msg.get("voice_cache_key", "")) == cache_key:
			history_text = str(msg.get("text", ""))
			break

	if history_text != "":
		var bbcode_regex = RegEx.new()
		bbcode_regex.compile("\\[/?[^\\]]+\\]")
		var clean_text = bbcode_regex.sub(history_text, "", true).strip_edges()
		clean_text = ChatSplitHelper.strip_parentheses(clean_text).strip_edges()
		if clean_text != "":
			TTSManager.synthesize(clean_text, {})
			return

	print("未找到语音缓存: ", cache_key)

var pending_status_changes = []


func _request_ai_response(text: String, is_system_event: bool) -> void:
	if not is_system_event:
		# Save player message
		GameDataManager.history.add_message("我", text, "", "story_chat")
		
	# Clear the flag for playback finish
	is_text_playback_finished = false
	
	if GameDataManager.config.ai_mode_enabled:
		deepseek_client.send_chat_message(text, "story_chat")
	else:
		# 本地兜底对话
		if is_inside_tree():
			await get_tree().create_timer(1.0).timeout
		var char_name = GameDataManager.profile.char_name
		_show_message("（离线模式）我...我不知道该说什么...", char_name)
		send_btn.disabled = false
		input_field.editable = true

func _on_send_pressed() -> void:
	var text = input_field.text.strip_edges()
	if text.is_empty():
		return
	
	_send_player_message(text, false)

var pending_reply_lines = []
var stream_live_active: bool = false
var stream_live_done: bool = false
var stream_live_buffer: String = ""
var stream_live_queue: Array = []
var stream_live_worker_running: bool = false

func _on_chat_stream_started() -> void:
	stream_live_active = true
	stream_live_done = false
	stream_live_buffer = ""
	stream_live_queue.clear()
	
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
	var char_name = GameDataManager.profile.char_name
	
	if stream_live_active:
		stream_live_done = true
		_extract_stream_segments(true)
		_try_start_stream_worker()
		
		# 当流式接收彻底完毕时，因为此时历史记录中还没有保存AI刚刚说的这句话，我们需要手动将它传给选项生成器
		if GameDataManager.config.ai_mode_enabled and not _waiting_for_chat_exit:
			var ai_reply = deepseek_client._chat_stream_full_text
			deepseek_client.send_options_generation(ai_reply, free_chat_strategy if is_free_chat_mode else "")
			
			# 触发记忆提取
			var messages = GameDataManager.history.get_messages_by_type("story_chat")
			if messages.size() > 0:
				var last_msg = messages[messages.size() - 1]
				if last_msg["speaker"] == "我" and GameDataManager.memory_manager.add_turn():
					deepseek_client.set_next_memory_context(GameDataManager.memory_manager.build_story_memory_context())
					deepseek_client.extract_memory_from_chat(last_msg["text"], ai_reply)
					
		return
		
	if response.has("choices") and response["choices"].size() > 0:
		var reply = response["choices"][0]["message"]["content"]
		
		# 非流式模式下，收到完整回复后也立刻提前触发选项生成，并手动传入最新回复
		if GameDataManager.config.ai_mode_enabled and not _waiting_for_chat_exit:
			deepseek_client.send_options_generation(reply, free_chat_strategy if is_free_chat_mode else "")
			
			# 触发记忆提取
			var messages = GameDataManager.history.get_messages_by_type("story_chat")
			if messages.size() > 0:
				var last_msg = messages[messages.size() - 1]
				if last_msg["speaker"] == "我" and GameDataManager.memory_manager.add_turn():
					deepseek_client.set_next_memory_context(GameDataManager.memory_manager.build_story_memory_context())
					deepseek_client.extract_memory_from_chat(last_msg["text"], reply)
			
		# 拦截 reply 进行预处理，提取纯净的消息序列
		var lines = _parse_reply_to_lines(reply)
		if lines.size() == 0:
			_show_message(char_name + " 似乎走神了...", char_name)
			send_btn.disabled = false
			input_field.editable = true
			return
			
		_play_message_sequence(lines, char_name)
	else:
		_show_message(char_name + " 似乎走神了...", char_name)
		send_btn.disabled = false
		input_field.editable = true

# 移除旧的 _on_character_mood_response 和 _on_character_mood_error 回调，
# 因为我们现在改为在 _play_message_sequence 中逐条进行同步等待分析了。

func _parse_reply_to_lines(reply: String) -> Array:
	# Print the raw reply to the console for debugging
	print("\n========== [Chat Agent Output] ==========")
	print(reply)
	print("=========================================\n")
	
	# Try to parse the reply as multiple bubbles using the [SPLIT] token
	var clean_reply = reply.strip_edges()
	
	# Remove any markdown formatting if the LLM still tries to output it
	if clean_reply.begins_with("```"):
		var lines = clean_reply.split("\n")
		if lines.size() > 2:
			lines.remove_at(0)
			if lines[lines.size()-1].begins_with("```"):
				lines.remove_at(lines.size()-1)
			clean_reply = "\n".join(lines).strip_edges()
			
	var message_list = _auto_split_message(clean_reply)
		
	var valid_lines = []
	for line in message_list:
		if typeof(line) == TYPE_STRING:
			var t = line.strip_edges()
			if t != "":
				valid_lines.append(t)
				
	return valid_lines

func _on_emotion_response(response: Dictionary) -> void:
	if response.has("choices") and response["choices"].size() > 0:
		var reply = response["choices"][0]["message"]["content"]
		
		print("\n========== [Emotion Agent Output] ==========")
		print(reply)
		print("============================================\n")
		
		var regex = RegEx.new()
		regex.compile("(?i)(?:<|\\<|《|\\[|【)\\s*(intimacy|trust|亲密度|亲密变化|信任度|信任值|信任变化|openness|conscientiousness|extraversion|agreeableness|neuroticism)\\s*[:：]\\s*([^>\\>》\\]】]+)\\s*(?:>|\\>|》|\\]|】)")
		var matches = regex.search_all(reply)
		var has_changes = false
		var personality_feedback: Dictionary = {}
		
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
					has_changes = true
					personality_feedback[tag] = float(personality_feedback.get(tag, 0.0)) + f_val
					_accumulated_stats[tag] += f_val
		if not personality_feedback.is_empty():
			GameDataManager.personality_system.apply_personality_feedback(
				GameDataManager.profile,
				personality_feedback,
				"dialogue_emotion",
				{
					"force_log": true
				}
			)
					
		if has_changes:
			GameDataManager.profile.save_profile()
			_update_ui()

func _on_emotion_error(error_msg: String) -> void:
	print("Emotion Agent Failed: ", error_msg)

func _on_memory_response(response: Dictionary) -> void:
	# 记忆的解析和存储现在已移至 deepseek_client.gd 的 _on_memory_completed 中集中处理。
	pass

func _on_memory_error(error_msg: String) -> void:
	print("Memory Agent Failed: ", error_msg)

var pending_options_data = []
var is_text_playback_finished = true

func _on_options_response(response: Dictionary) -> void:
	if response.has("choices") and response["choices"].size() > 0:
		var reply = response["choices"][0]["message"]["content"]
		
		print("\n========== [Options Agent Output] ==========")
		print(reply)
		print("============================================\n")
		
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
				
		print("Warning: Options Agent did not return valid JSON.")

func _try_show_options() -> void:
	# 只有当文本演出完全结束，且已经获取到了选项数据时，才将选项渲染到UI
	if is_text_playback_finished and pending_options_data.size() > 0:
		_populate_quick_options(pending_options_data)
		pending_options_data.clear()

func _on_options_error(error_msg: String) -> void:
	print("Options Agent Failed: ", error_msg)

func _populate_quick_options(options: Array) -> void:
	QUICK_OPTION_LIST_HELPER.populate_option_items_with_index(
		quick_options_container,
		options,
		_on_quick_option_selected
	)

func _on_quick_option_selected(text: String, index: int = -1) -> void:
	if index == 0:
		GameDataManager.profile.update_intimacy(5)
		GameDataManager.profile.update_trust(5)
	elif index == 1:
		GameDataManager.profile.update_intimacy(-5)
		GameDataManager.profile.update_trust(-5)
		
	if input_field:
		input_field.text = text
	_on_send_pressed()

func _on_chat_error(error_msg: String) -> void:
	var char_name = GameDataManager.profile.char_name
	send_btn.disabled = false
	input_field.editable = true
	stream_live_active = false
	stream_live_done = true
	stream_live_buffer = ""
	stream_live_queue.clear()
	ToastManager.show_system_toast(error_msg, Color.RED)
	# 本地兜底
	if is_inside_tree():
		await get_tree().create_timer(1.0).timeout
	_show_message("你在哪儿？我听不到你的声音了...", char_name)

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

func _try_start_stream_worker() -> void:
	if not stream_live_worker_running:
		stream_live_worker_running = true
		call_deferred("_run_stream_worker")

func _run_stream_worker() -> void:
	var char_name = GameDataManager.profile.char_name
	while true:
		while not is_inside_tree():
			if not stream_live_active: break
			await Engine.get_main_loop().process_frame
			
		if not stream_live_active and stream_live_queue.size() == 0:
			break
			
		if stream_live_queue.size() == 0:
			if stream_live_done:
				break
			if is_inside_tree():
				await get_tree().create_timer(0.05).timeout
			continue
			
		var line = stream_live_queue.pop_front()
		if typeof(line) != TYPE_STRING:
			continue
		var t = str(line).strip_edges()
		if t == "":
			continue
			
		if GameDataManager.config.ai_mode_enabled:
			# 异步发起分析，不阻塞当前流程的推进和打字机的显示
			_async_analyze_and_update_mood(t)
				
		await _process_single_message_line_async(t, char_name)
		
		if not stream_live_active:
			break
			
	stream_live_active = false
	stream_live_worker_running = false
	
	GameDataManager.profile.save_profile()
	_update_ui()
	
	# 因为选项生成请求已经提前到流式接收完毕时发送，这里只需要恢复UI交互即可
	is_text_playback_finished = true
	
	if _waiting_for_chat_exit:
		_waiting_for_chat_exit = false
		if is_inside_tree():
			await get_tree().create_timer(1.5).timeout
		hide_panel()
		return
		
	_try_show_options()
	send_btn.disabled = false
	input_field.editable = true

func _auto_split_message(text: String) -> Array:
	# 如果AI主动遵守了提示词，直接使用
	if "[SPLIT]" in text:
		return text.split("[SPLIT]", false)
		
	# 系统级强制干预：根据语境智能切分
	# 提取情绪标签，防止它在切分时被破坏或抛弃
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

	merged_parts = ChatSplitHelper.merge_incomplete_parentheses(merged_parts)
		
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
	merged_parts = ChatSplitHelper.merge_incomplete_parentheses(merged_parts)
		
	# 限制最多3条
	if merged_parts.size() > 3:
		# 只保留前3条，或者把后面的内容全部合并到第3条里
		# 这里选择把多余的部分直接丢弃，强制不超过3条
		var truncated_parts = []
		truncated_parts.append(merged_parts[0])
		truncated_parts.append(merged_parts[1])
		truncated_parts.append(merged_parts[2])
		merged_parts = truncated_parts
		
	# 将心情标签加回最后一条消息末尾
	if merged_parts.size() > 0 and mood_tag != "":
		merged_parts[merged_parts.size() - 1] += mood_tag
		
	if merged_parts.size() == 0:
		return [text]
		
	return merged_parts

func _play_message_sequence(lines: Array, char_name: String) -> void:
	for line in lines:
		if GameDataManager.config.ai_mode_enabled:
			_async_analyze_and_update_mood(line)
				
		await _process_single_message_line_async(line, char_name)
		
	GameDataManager.profile.save_profile()
	_update_ui()
	
	if is_inside_tree():
		await get_tree().create_timer(1.0).timeout
		
	is_text_playback_finished = true
	
	if _waiting_for_chat_exit:
		# AI 聊天结束，直接抛出事件让外部来处理后续（比如外部加上黑屏动画后再销毁）
		_waiting_for_chat_exit = false
		if _script_ai_chat_active:
			_finish_script_ai_chat()
		else:
			chat_closed.emit()
		return
	else:
		_try_show_options()
		send_btn.disabled = false
		input_field.editable = true

func _async_analyze_and_update_mood(line: String) -> void:
	_pending_mood_analysis_line = line.strip_edges()
	if _pending_mood_analysis_line == "" or _mood_analysis_running:
		return
	
	_mood_analysis_running = true
	while _pending_mood_analysis_line != "":
		var current_line = _pending_mood_analysis_line
		_pending_mood_analysis_line = ""
		print("正在异步分析单条消息的心情: ", current_line)
		
		var expression_id = await deepseek_client.analyze_mood_sync(current_line)
		print("【Debug】异步 analyze_mood_sync 返回值: '", expression_id, "'")
		if expression_id != "":
			if GameDataManager.expression_system.is_valid_expression(expression_id):
				print("异步分析结果 -> ", expression_id)
				GameDataManager.profile.update_expression(expression_id)
				print("【心情更新（不弹窗）】表情变为：" + GameDataManager.expression_system.expression_configs[expression_id]["name"])
				_update_ui()
				_update_character_sprite(expression_id)
			else:
				print("【Debug】异步心情分析返回了未知的 expression_id: '", expression_id, "'")
		else:
			print("异步心情分析未匹配或请求失败")
	
	_mood_analysis_running = false

func _process_single_message_line_async(raw_line: String, char_name: String) -> void:
	var regex = RegEx.new()
	regex.compile("(?i)(?:<|\\<|《|\\[|【)\\s*(mood|心情)\\s*[:：]\\s*([^>\\>》\\]】]+)\\s*(?:>|\\>|》|\\]|】)")
	
	var clean_text = raw_line
	var matches = regex.search_all(raw_line)
	for m in matches:
		clean_text = clean_text.replace(m.get_string(0), "")
			
	var any_tag_regex = RegEx.new()
	any_tag_regex.compile("(?i)(?:<|\\<|《|\\[|【)[^>\\>》\\]】]*?[:：][^>\\>》\\]】]*?(?:>|\\>|》|\\]|】)")
	if any_tag_regex.is_valid():
		clean_text = any_tag_regex.sub(clean_text, "", true)
		
	clean_text = clean_text.strip_edges()
	
	# 强制清理：只保留最开头的一个动作描述，移除其余所有动作描述
	var extract_regex = RegEx.new()
	extract_regex.compile("（.*?）|\\(.*?\\)")
	var extract_matches = extract_regex.search_all(clean_text)
	if extract_matches.size() > 0:
		var first_action = extract_matches[0].get_string()
		var no_action_text = extract_regex.sub(clean_text, "", true).strip_edges()
		clean_text = first_action + " " + no_action_text
	
	var tts_text = ChatSplitHelper.strip_parentheses(clean_text)
	
	var display_text = clean_text
	var color_regex_zh = RegEx.new()
	color_regex_zh.compile("（(.*?)）")
	display_text = color_regex_zh.sub(display_text, "[color=green]（$1）[/color]", true)
	var color_regex_en = RegEx.new()
	color_regex_en.compile("\\((.*?)\\)")
	display_text = color_regex_en.sub(display_text, "[color=green]($1)[/color]", true)
	
	await _show_message_async(display_text, char_name, false, tts_text)

func _show_message(text: String, speaker_name: String = "", is_restore: bool = false, tts_text: String = "") -> void:
	_show_message_async(text, speaker_name, is_restore, tts_text)

func _show_message_async(text: String, speaker_name: String = "", is_restore: bool = false, tts_text: String = "") -> void:
	if speaker_name == "":
		speaker_name = GameDataManager.profile.char_name
		
	if speaker_name != "" and name_label:
		name_label.text = speaker_name
		
	# 根据当前心情更新立绘
	if _intro_playing and _current_story_speaker_id == _get_current_story_character_id():
		var story_expression = GameDataManager.profile.current_expression
		_update_character_sprite(story_expression)
	elif speaker_name == GameDataManager.profile.char_name:
		var current_expression = GameDataManager.profile.current_expression
		_update_character_sprite(current_expression)
		
	# 开启 BBCode 渲染
	if not dialogue_text:
		return
	dialogue_text.bbcode_enabled = true
	dialogue_text.text = text
	dialogue_text.visible_ratio = 0.0
	
	# 简单的打字机效果
	if _typewriter_tween:
		_typewriter_tween.kill()
	_typewriter_tween = create_tween()
	var duration = max(0.5, text.length() * 0.05) # 每个字符 0.05 秒，至少0.5秒
	_typewriter_tween.tween_property(dialogue_text, "visible_ratio", 1.0, duration)
	# We will handle visible_characters = -1 after tween finishes or gets killed
	
	var cache_key = ""
	var is_tts_started = false
	
	# 触发TTS语音合成 (仅对 角色 发声)，如果是恢复记录则不发声
	# 在固定剧情模式下，判断 speaker_name 是不是玩家或旁白，都不是的话说明是配音角色，也可以发声
	var is_player_or_narrator = (speaker_name == "我" or speaker_name == "旁白" or speaker_name == " ")
	
	# 如果是固定剧情（_intro_playing），即使 is_restore 为 true，也允许发声
	if GameDataManager.config.voice_enabled and (not is_restore or _intro_playing) and not is_player_or_narrator:
		# 优先使用专属的 tts_text (过滤了动作描写的纯净文本)
		var text_to_speak = text
		if tts_text != "":
			text_to_speak = tts_text
		elif tts_text == "" and text != "":
			# 如果明确传了空字符串的 tts_text，说明文本里全是动作，不应该发声
			# 但是GDScript 默认参数 "" 无法区分是否显式传入。我们用 strip_parentheses 兜底检查
			text_to_speak = ChatSplitHelper.strip_parentheses(text)
		
		var regex = RegEx.new()
		regex.compile("[a-zA-Z0-9\u4e00-\u9fa5]")
		if regex.search(text_to_speak) != null:
			is_tts_started = true
			
			# 如果是固定剧情的配音，优先尝试用 speaker_name 作为角色 ID 查找音色
			# 否则使用当前全局角色的音色
			var char_id = GameDataManager.config.current_character_id
			if _intro_playing and _current_story_speaker_id != "":
				char_id = _current_story_speaker_id
				
			var options = {}
			if GameDataManager.config.character_voice_types.has(char_id):
				options["voice_type"] = GameDataManager.config.character_voice_types[char_id]
				
			cache_key = TTSManager.get_cache_key(text_to_speak, options)
			TTSManager.synthesize(text_to_speak, options)
		
	# 保存记录到历史管理器 (只有在非恢复模式时保存)
	if not is_restore:
		GameDataManager.history.add_message(speaker_name, text, cache_key, "story_chat")
	elif _intro_playing and text != "":
		# 因为 _intro_playing 调用时是 is_restore=true 专门为了避开 normal 的保存
		GameDataManager.history.add_message(speaker_name, text, cache_key, "fixed_story")

	# 等待打字机效果完成
	if is_inside_tree():
		while _typewriter_tween and _typewriter_tween.is_valid() and _typewriter_tween.is_running():
			await get_tree().process_frame
			
	if not is_inside_tree():
		return
		
	# If we killed the tween, make sure the text is fully shown
	dialogue_text.visible_ratio = 1.0
	dialogue_text.visible_characters = -1
	
	# For regular AI chat, disable click to skip and auto-play
	if not _intro_playing:
		_waiting_for_chat_click = false
	else:
		_intro_waiting_for_click = true
	
	# Wait for TTS if playing
	if is_tts_started and is_inside_tree():
		var wait_count = 0
		while not audio_player.playing and wait_count < 10:
			if _intro_playing and not _intro_waiting_for_click:
				break
			await get_tree().create_timer(0.05).timeout
			wait_count += 1
			
		wait_count = 0
		var max_wait_count = 1200 if _intro_playing else 24
		while audio_player.playing and is_inside_tree() and wait_count < max_wait_count:
			if _intro_playing and not _intro_waiting_for_click:
				audio_player.stop()
				break
			await get_tree().create_timer(0.05).timeout
			wait_count += 1
			
	if _intro_playing:
		if is_inside_tree() and _intro_waiting_for_click:
			await _intro_click_proceed
	else:
		if is_inside_tree():
			await get_tree().create_timer(1.0).timeout

func _on_tts_success(audio_stream: AudioStream, text: String) -> void:
	if audio_player:
		audio_player.stream = audio_stream
		audio_player.play()

func _on_tts_failed(error_msg: String, text: String) -> void:
	print("TTS 失败: ", error_msg)
