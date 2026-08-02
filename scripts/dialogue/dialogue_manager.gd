extends Control

const DEBUG_PANEL_SCENE = preload("res://scenes/ui/story/debug_panel.tscn")
const STORY_PERIOD_CARD_SCENE = preload("res://scenes/ui/story/story_period_card.tscn")
const ChatSplitHelperScript = preload("res://scripts/utils/chat_split_helper.gd")
const GuidedAiResponseParser = preload("res://scripts/dialogue/guided_ai_response_parser.gd")
const GuidedAiRequestGuard = preload("res://scripts/dialogue/guided_ai_request_guard.gd")
const GuidedAiRoundPolicy = preload("res://scripts/dialogue/guided_ai_round_policy.gd")
const GuidedAiPromptBuilder = preload("res://scripts/dialogue/guided_ai_prompt_builder.gd")
const DailyChatRoundPolicyScript = preload("res://scripts/dialogue/daily_chat_round_policy.gd")

var _guided_ai_round_policy := GuidedAiRoundPolicy.new()

signal chat_closed
signal embedded_topic_selected(topic: String, metadata: Dictionary)
signal embedded_topic_options_ready(metadata: Dictionary)
signal embedded_session_completed(metadata: Dictionary)
signal embedded_story_choice_ready(metadata: Dictionary)
signal embedded_story_choice_selected(text: String, metadata: Dictionary)

@export var ui_panel_path: NodePath = NodePath("UIPanel")
@export var dialogue_panel_path: NodePath = NodePath("UIPanel/DialoguePanel")
@export var deepseek_client_path: NodePath = NodePath("DeepSeekClient")
@export var audio_player_path: NodePath = NodePath("AudioStreamPlayer")
@export var click_blocker_path: NodePath = NodePath("ClickBlocker")
@export var character_layer_path: NodePath = NodePath("CharacterLayer")
@export var free_chat_info_layer_path: NodePath = NodePath("UIPanel/FreeChatInfoLayer")
@export var conversation_subtype: String = "story_ai_chat"
@export var external_session_controlled: bool = false

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
var quick_option_layer: Control = null
var quick_options_container: Node = null
var ai_player_option_layer: Control = null
var ai_player_options_container: GridContainer = null
var end_chat_btn: Button = null
var history_btn: Button = null

var character_layer: Node = null

var deepseek_client: DeepSeekClient = null
var audio_player: AudioStreamPlayer = null
var mic_capture: AudioStreamPlayer = null
var qwen_asr_client = null

var click_blocker: Control = null
var story_period_card: Control = null

var _ui_tween: Tween = null
var _typewriter_tween: Tween = null
var camera_panel_instance = null
var mobile_interface_instance = null
var _intro_playing: bool = false
var _intro_waiting_for_click: bool = false
var _waiting_for_chat_click: bool = false
var _line_text_complete: bool = false
var _voice_record_press_active := false
var _line_advance_requested: bool = false
var _line_display_generation: int = 0
var _active_line_tts_text: String = ""
var _current_story_speaker_id: String = ""
var _return_to_main_on_story_finish: bool = false

# Free Chat states
var is_free_chat_mode: bool = false
var free_chat_strategy: String = ""
var free_chat_max_rounds: int = 0
var free_chat_current_round: int = 0
var _script_ai_chat_active: bool = false
var _guided_ai_chat_active: bool = false
var _guided_ai_policy: Dictionary = {}
var _guided_ai_covered_beats: Array[String] = []
var _guided_ai_candidate_beat_ids: Array[String] = []
var _guided_ai_close_after_reply: bool = false
var _guided_ai_closing_started: bool = false
var _guided_ai_session_id: String = ""
var _guided_ai_active_request_id: int = 0
var _guided_ai_turn_started_at_ms: int = 0
var _guided_ai_reply_available_at_ms: int = 0
var _guided_ai_last_request_text: String = ""
var _guided_ai_last_raw_response: String = ""
var _guided_ai_parse_retry_count: int = 0
var _guided_ai_request_retry_count: int = 0
var _guided_ai_reply_playback_active: bool = false
var _guided_ai_used_option_texts: Array[String] = []
var _guided_ai_used_reply_signatures: Array[String] = []
var _guided_ai_used_reply_texts: Array[String] = []
const GUIDED_AI_MAX_RETRIES := 3
const GUIDED_AI_INITIAL_TEMPERATURE := 0.6
const GUIDED_AI_REGENERATION_TEMPERATURE := 0.75
const GUIDED_AI_FIRST_REPAIR_TEMPERATURE := 0.25
const GUIDED_AI_LATER_REPAIR_TEMPERATURE := 0.15
const GUIDED_AI_EMERGENCY_OPTIONS := [
	{"text": "你可以慢慢说，我在听。", "focus": "intimacy"},
	{"text": "哪一点最让你在意？", "focus": "trust"},
	{"text": "我们一起把这件事理清楚。", "focus": "intimacy"},
	{"text": "你希望我怎么支持你？", "focus": "trust"},
	{"text": "先说说你现在的真实感受吧。", "focus": "intimacy"},
	{"text": "还有什么顾虑没有说出来？", "focus": "trust"},
	{"text": "不着急，我们一步一步来。", "focus": "intimacy"},
	{"text": "你准备先从哪里开始？", "focus": "trust"}
]
var _embedded_session_active: bool = false
var _embedded_session_request: Dictionary = {}
var _embedded_topic_options: Array = []
var _embedded_daily_turn_pending: bool = false
var _embedded_daily_close_queued: bool = false

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
var free_chat_time_label: Label = null
var free_chat_energy_layer: Control = null
var free_chat_energy_label: Label = null

var history_panel = null
var gift_panel = null
var debug_panel = null

var incoming_call_notification_instance = null

var script_engine: ScriptEngineManager = null

signal _intro_click_proceed
signal _chat_click_proceed

func _emit_chat_closed() -> void:
	if _embedded_session_active:
		_embedded_session_active = false
		_embedded_daily_turn_pending = false
		_embedded_daily_close_queued = false
		embedded_session_completed.emit(_embedded_session_request.duplicate(true))
		_embedded_session_request.clear()
		_embedded_topic_options.clear()
		_reset_free_chat_state()
	chat_closed.emit()

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

	if dialogue_panel:
		free_chat_info_layer = dialogue_panel.get_node_or_null("FreeChatInfoLayer") as Control
	if not free_chat_info_layer and ui_panel:
		free_chat_info_layer = ui_panel.get_node_or_null("FreeChatInfoLayer") as Control

	if dialogue_panel:
		hide_ui_btn = dialogue_panel.get_node_or_null("ToolBarContainer/ToolBarMargin/HBox/HideUIButton") as Button
		camera_btn = dialogue_panel.get_node_or_null("ToolBarContainer/ToolBarMargin/HBox/CameraButton") as Button
	else:
		hide_ui_btn = null
		camera_btn = null

	if free_chat_info_layer:
		free_chat_round_label = free_chat_info_layer.get_node_or_null("Panel/Margin/VBox/RoundLabel") as Label
		free_chat_time_label = free_chat_info_layer.get_node_or_null("Panel/Margin/VBox/TimeLabel") as Label
	else:
		free_chat_round_label = null
		free_chat_time_label = null
	if dialogue_panel:
		free_chat_energy_layer = dialogue_panel.get_node_or_null("EnergyInfoLayer") as Control
		free_chat_energy_label = dialogue_panel.get_node_or_null("EnergyInfoLayer/Panel/Margin/VBox/EnergyLabel") as Label
	else:
		free_chat_energy_layer = null
		free_chat_energy_label = null

	if dialogue_panel:
		name_label = dialogue_panel.get_node_or_null("DialogueLayer/VBox/NameLabel") as Label
		dialogue_text = dialogue_panel.get_node_or_null("DialogueLayer/VBox/RichTextLabel") as RichTextLabel
		input_layer = dialogue_panel.get_node_or_null("InputLayer") as Panel
		input_field = dialogue_panel.get_node_or_null("InputLayer/HBoxContainer/InputField") as TextEdit
		send_btn = dialogue_panel.get_node_or_null("InputLayer/HBoxContainer/SendButton") as Button
		voice_record_btn = dialogue_panel.get_node_or_null("InputLayer/HBoxContainer/VoiceRecordButton") as Button
		quick_option_layer = dialogue_panel.get_node_or_null("QuickOptionLayer") as Control
		quick_options_container = dialogue_panel.get_node_or_null("QuickOptionLayer/ScrollContainer/QuickOptions")
		ai_player_option_layer = dialogue_panel.get_node_or_null("AiPlayerOptionLayer") as Control
		ai_player_options_container = dialogue_panel.get_node_or_null("AiPlayerOptionLayer/Margin/Content/OptionsGrid") as GridContainer
		end_chat_btn = dialogue_panel.get_node_or_null("InputLayer/HBoxContainer/EndChatButton") as Button
		history_btn = dialogue_panel.get_node_or_null("ToolBarContainer/ToolBarMargin/HBox/HistoryButton") as Button
	else:
		name_label = null
		dialogue_text = null
		input_layer = null
		input_field = null
		send_btn = null
		voice_record_btn = null
		quick_option_layer = null
		quick_options_container = null
		ai_player_option_layer = null
		ai_player_options_container = null
		end_chat_btn = null
		history_btn = null

	if character_layer_path != NodePath(""):
		character_layer = get_node_or_null(character_layer_path)
	if click_blocker_path != NodePath(""):
		click_blocker = get_node_or_null(click_blocker_path) as Control

	if deepseek_client_path != NodePath(""):
		deepseek_client = get_node_or_null(deepseek_client_path) as DeepSeekClient
	if not deepseek_client:
		deepseek_client = DeepSeekClientLocator.find(self) as DeepSeekClient
	if not deepseek_client:
		push_error("[DialogueManager] 未找到 DeepSeekClient，请检查场景中的客户端挂载位置。")

	if audio_player_path != NodePath(""):
		audio_player = get_node_or_null(audio_player_path) as AudioStreamPlayer
	if not audio_player:
		audio_player = AudioStreamPlayer.new()
		audio_player.name = "AudioStreamPlayer"
		add_child(audio_player)
	if audio_player:
		audio_player.bus = "Voice"

	mic_capture = get_node_or_null("MicCapture") as AudioStreamPlayer
	if not mic_capture:
		mic_capture = AudioStreamPlayer.new()
		mic_capture.name = "MicCapture"
		add_child(mic_capture)

func _ready() -> void:
	_resolve_nodes()
	var guide_manager := get_node_or_null("/root/GuideManager")
	if guide_manager and guide_manager.has_method("on_story_scene_ready"):
		guide_manager.on_story_scene_ready()

	if dialogue_panel:
		dialogue_panel.show()

	if hide_ui_btn:
		hide_ui_btn.show()
	if camera_btn:
		camera_btn.show()
	
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
		GameDataManager.config.apply_runtime_settings()
		
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
	
	if deepseek_client:
		deepseek_client.chat_request_completed.connect(_on_chat_response)
		deepseek_client.chat_request_failed.connect(_on_chat_error)
		deepseek_client.realize_turn_completed.connect(_on_realize_turn_completed)
		deepseek_client.realize_turn_failed.connect(_on_realize_turn_failed)
		deepseek_client.structured_chat_request_completed.connect(_on_structured_chat_response)
		deepseek_client.structured_chat_request_failed.connect(_on_structured_chat_error)
		
		deepseek_client.emotion_request_completed.connect(_on_emotion_response)
		deepseek_client.emotion_request_failed.connect(_on_emotion_error)
		
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
	script_engine.on_choice_requested.connect(_on_script_choice_requested)
	script_engine.on_character_show_requested.connect(_on_script_show_character)
	script_engine.on_character_move_requested.connect(_on_script_move_character)
	script_engine.on_character_hide_requested.connect(_on_script_hide_character)
	script_engine.on_player_call_name_requested.connect(_on_script_player_call_name)
	script_engine.on_voice_call_requested.connect(_on_script_voice_call)
	script_engine.on_start_free_chat_requested.connect(_on_script_start_free_chat)
	script_engine.on_background_requested.connect(_on_script_background_requested)
	script_engine.on_period_card_requested.connect(_on_script_period_card_requested)
	script_engine.on_bgm_requested.connect(_on_script_bgm_requested)
	script_engine.on_audio_requested.connect(_on_script_audio_requested)
	script_engine.on_variable_set.connect(_on_script_variable_set)
	script_engine.on_ai_chat_requested.connect(_on_script_ai_chat_requested)
	script_engine.on_guided_ai_chat_requested.connect(_on_script_guided_ai_chat_requested)
	script_engine.script_finished.connect(_on_script_finished)
	script_engine.checkpoint_changed.connect(_on_story_checkpoint_changed)
	
	_update_ui()
	_ensure_story_period_card()

	if GameDataManager.has_meta("story_scene_return_to_main_on_finish"):
		_return_to_main_on_story_finish = bool(GameDataManager.get_meta("story_scene_return_to_main_on_finish"))
		GameDataManager.remove_meta("story_scene_return_to_main_on_finish")
	
	# Check if we should play the intro story
	if GameDataManager.has_meta("play_intro_story") and GameDataManager.get_meta("play_intro_story"):
		GameDataManager.remove_meta("play_intro_story")
		_play_intro_story()
		return

	if GameDataManager.has_meta("play_runtime_story_data"):
		var runtime_story_data = GameDataManager.get_meta("play_runtime_story_data")
		GameDataManager.remove_meta("play_runtime_story_data")
		_play_story_data(runtime_story_data)
		return
		
	# Check if we should play a specific story script
	if GameDataManager.has_meta("play_specific_story"):
		var script_path = GameDataManager.get_meta("play_specific_story")
		GameDataManager.remove_meta("play_specific_story")
		_play_story(script_path)
		return

	if external_session_controlled:
		hide()
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
	_story_archive_id = GameDataManager.get_active_archive_id()
	_intro_playing = true
	_current_story_speaker_id = ""
	send_btn.disabled = true
	input_field.editable = false
	ui_panel.visible = true
	dialogue_panel.set_story_mode(true)
	input_layer.hide()
	if end_chat_btn:
		end_chat_btn.hide()
	
	var transition_manager = get_tree().root.get_node_or_null("SceneTransitionManager")
	var skip_local_fade := false
	if transition_manager and transition_manager.has_method("is_transitioning"):
		skip_local_fade = bool(transition_manager.is_transitioning())
	if skip_local_fade:
		modulate.a = 1.0
	else:
		modulate.a = 0.0
		var fade_tween = create_tween()
		fade_tween.tween_property(self, "modulate:a", 1.0, 1.0)
	
	if script_engine.load_script(path):
		if not _prepare_story_cost_settlement():
			_restore_story_ui_after_unavailable_cost()
			return
		if script_engine.use_story_portraits():
			if character_layer and character_layer.has_method("begin_story_mode"):
				character_layer.begin_story_mode()
			elif character_layer and character_layer.has_method("hide_character"):
				character_layer.hide()
		elif character_layer and character_layer.has_method("end_story_mode"):
			character_layer.end_story_mode()
		elif character_layer:
			character_layer.hide()
		if not _restore_story_checkpoint():
			script_engine.start_script("start")
	else:
		_intro_playing = false
		send_btn.disabled = false
		input_field.editable = true
		input_layer.show()

func _play_story_data(data: Variant) -> void:
	_story_archive_id = GameDataManager.get_active_archive_id()
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

	if script_engine.load_script_data(data):
		if not _prepare_story_cost_settlement():
			_restore_story_ui_after_unavailable_cost()
			return
		if script_engine.use_story_portraits():
			if character_layer and character_layer.has_method("begin_story_mode"):
				character_layer.begin_story_mode()
			elif character_layer and character_layer.has_method("hide_character"):
				character_layer.hide()
		elif character_layer and character_layer.has_method("end_story_mode"):
			character_layer.end_story_mode()
		elif character_layer:
			character_layer.hide()
		if not _restore_story_checkpoint():
			script_engine.start_script("start")
	else:
		_intro_playing = false
		send_btn.disabled = false
		input_field.editable = true
		input_layer.show()

func _prepare_story_cost_settlement() -> bool:
	if _has_matching_story_checkpoint():
		return true
	var script_meta := script_engine.get_current_script_meta()
	var action_cost := maxi(0, int(script_meta.get("action_cost", 0)))
	var game_minutes := maxi(0, int(script_meta.get("game_minutes", 0)))
	if GameDataManager.interaction_manager:
		var unavailable: Dictionary = GameDataManager.interaction_manager.get_cost_unavailable_reason(action_cost, 0, game_minutes)
		if not unavailable.is_empty():
			GameDataManager.interaction_manager.show_unavailable_dialog(unavailable)
			return false
	elif action_cost > 0 and GameDataManager.profile.current_energy < action_cost:
		return false
	if action_cost > 0 and not GameDataManager.profile.consume_energy(action_cost):
		return false
	if action_cost > 0:
		GameDataManager.profile.save_profile()
	return true

func _has_matching_story_checkpoint() -> bool:
	var checkpoint := GameDataManager.load_active_story_checkpoint()
	if checkpoint.is_empty() or str(checkpoint.get("script_id", "")) != script_engine.current_script_id:
		return false
	var checkpoint_path := str(checkpoint.get("script_path", ""))
	return checkpoint_path.is_empty() or checkpoint_path == script_engine.current_script_path

func _restore_story_ui_after_unavailable_cost() -> void:
	_intro_playing = false
	send_btn.disabled = false
	input_field.editable = true
	input_layer.show()

func _settle_completed_story_time(script_meta: Dictionary) -> void:
	var game_minutes := maxi(0, int(script_meta.get("game_minutes", 0)))
	if game_minutes > 0 and GameDataManager.story_time_manager:
		GameDataManager.story_time_manager.tick_minutes(game_minutes)
		GameDataManager.profile.save_profile()

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
	var tts_expression: String = str(presentation.get("expression", mood)).strip_edges()
	if tts_expression.is_empty():
		tts_expression = mood.strip_edges()
	var voice_instruction: String = str(presentation.get("voice_instruction", "")).strip_edges()
	var auto_advance := bool(presentation.get("auto_advance", false))
	await _show_message_async(actual_content, char_name, true, "", tts_expression, voice_instruction, auto_advance)
	if script_engine and script_engine.is_running and script_engine.is_waiting_for_resume:
		script_engine.resume()

func _restore_story_checkpoint() -> bool:
	var checkpoint := GameDataManager.load_active_story_checkpoint()
	if checkpoint.is_empty():
		return false
	if str(checkpoint.get("script_id", "")) != script_engine.current_script_id:
		return false
	var checkpoint_path := str(checkpoint.get("script_path", ""))
	if not checkpoint_path.is_empty() and checkpoint_path != script_engine.current_script_path:
		return false
	return script_engine.restore_checkpoint(checkpoint)

func _on_story_checkpoint_changed(state: Dictionary) -> void:
	GameDataManager.save_story_checkpoint_for_archive(state, _story_archive_id)

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

func _build_story_knowledge_access_context() -> Dictionary:
	var character_id := _current_story_speaker_id.strip_edges().to_lower()
	if character_id.is_empty():
		character_id = _get_current_story_character_id()
	var finished_story_ids: Array = []
	if GameDataManager.profile and GameDataManager.profile.finished_stories is Array:
		finished_story_ids = GameDataManager.profile.finished_stories.duplicate()
	return {
		"channel": "story_chat",
		"allow_story_knowledge": not character_id.is_empty(),
		"character_id": character_id,
		"finished_story_ids": finished_story_ids
	}

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

func _beautify_story_character_name(character_name: String) -> String:
	if character_name == "":
		return ""
	if character_name == character_name.to_lower():
		return character_name.capitalize()
	return character_name

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

func _on_script_player_call_name() -> void:
	if GameDataManager.profile:
		var has_title := str(GameDataManager.profile.player_title).strip_edges() != ""
		if has_title:
			GameDataManager.sync_profile_to_config()
			if GameDataManager.config:
				GameDataManager.config.save_config()
			script_engine.resume()
			return
	var popup_scene = load("res://scenes/ui/story/player_call_name_popup.tscn")
	if popup_scene:
		var popup = popup_scene.instantiate()
		add_child(popup)
		popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		await popup.title_submitted

		var preferred_title := str(popup.preferred_title).strip_edges()
		if preferred_title != "" and GameDataManager.profile:
			GameDataManager.profile.player_title = preferred_title
			GameDataManager.sync_profile_to_config()
			if GameDataManager.config:
				GameDataManager.config.save_config()
			if GameDataManager.memory_manager:
				GameDataManager.memory_manager.save_memory()
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
	for call_entry in call_data:
		if call_entry.get("id") == target_call_id:
			call_lines = call_entry.get("lines", [])
			char_id = call_entry.get("char_id", "ya")
			break
			
	GameDataManager.set_meta("pending_fixed_call_data", call_lines)
	
	if is_instance_valid(incoming_call_notification_instance):
		incoming_call_notification_instance.queue_free()
		
	var NotificationObj = load("res://scenes/ui/main/incoming_call_notification.tscn")
	var call_notification = NotificationObj.instantiate()
	incoming_call_notification_instance = call_notification
	add_child(call_notification)
	call_notification.show_incoming_call(char_id, false, true)
	
	var original_ui_visible = ui_panel.visible
	ui_panel.visible = false
	
	await call_notification.call_accepted
	call_notification.queue_free()
	
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
				script_engine.call_deferred("resume")
		else:
			print("[ScriptEngine] 警告：找到了背景资源，但未找到对应的 TextureRect 背景节点！", bg_node)
			script_engine.call_deferred("resume")
	else:
		print("[ScriptEngine] 警告：无法加载背景图片 -> ", bg_path)
		script_engine.call_deferred("resume")

func _on_script_period_card_requested(period_label: String, location_name: String, bg_path: String, hold_duration: float) -> void:
	_ensure_story_period_card()
	var tex: Texture2D = null
	var ui_was_visible := ui_panel != null and ui_panel.visible
	if bg_path != "" and ResourceLoader.exists(bg_path):
		tex = load(bg_path)
		var bg_node = _find_story_background_node()
		if bg_node and bg_node is TextureRect:
			bg_node.texture = tex
	_prepare_for_period_card_transition()
	if ui_panel:
		ui_panel.hide()
	if story_period_card:
		await story_period_card.play_card(tex, period_label, location_name, hold_duration)
	if ui_panel and ui_was_visible:
		ui_panel.show()
	script_engine.resume()

func _prepare_for_period_card_transition() -> void:
	_current_story_speaker_id = ""
	if _typewriter_tween:
		_typewriter_tween.kill()
		_typewriter_tween = null
	if audio_player and audio_player.playing:
		audio_player.stop()
	if dialogue_text:
		dialogue_text.text = ""
		dialogue_text.visible_ratio = 1.0
		dialogue_text.visible_characters = -1
	if name_label:
		name_label.text = ""
	if character_layer and character_layer.has_method("end_story_mode"):
		character_layer.end_story_mode()
	elif character_layer and character_layer.has_method("hide_character"):
		character_layer.hide_character("fade_out")
	elif character_layer and character_layer is CanvasItem:
		character_layer.hide()

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
	if action == "play" or action == "switch":
		if audio_type == "bgm":
			if action == "switch" and AudioManager.has_method("switch_bgm"):
				AudioManager.switch_bgm(audio_id, fade_time)
			else:
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

func _ensure_story_period_card() -> void:
	if story_period_card and is_instance_valid(story_period_card):
		return
	story_period_card = STORY_PERIOD_CARD_SCENE.instantiate() as Control
	if story_period_card == null:
		return
	add_child(story_period_card)
	story_period_card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	move_child(story_period_card, get_child_count() - 1)

func _find_story_background_node() -> TextureRect:
	if get_parent() and get_parent().has_node("BackgroundLayer"):
		return get_parent().get_node("BackgroundLayer") as TextureRect
	var local_bg = get_node_or_null("BackgroundLayer") as TextureRect
	if local_bg:
		return local_bg
	if get_parent() and get_parent().has_node("MainBg"):
		return get_parent().get_node("MainBg") as TextureRect
	return null

func _on_script_variable_set(var_name: String, var_value: Variant) -> void:
	GameDataManager.set_meta(var_name, var_value)
	script_engine.resume()

func _on_script_ai_chat_requested(prompt_override: String) -> void:
	# 暂停脚本，进入临时 AI 自由对话，等待玩家主动结束后再恢复剧情。
	print("[ScriptEngine] 触发临时 AI Chat: ", prompt_override)
	_script_ai_chat_active = true
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

func _on_script_guided_ai_chat_requested(policy: Dictionary) -> void:
	_guided_ai_policy = policy.duplicate(true)
	_guided_ai_chat_active = true
	_guided_ai_session_id = str(policy.get("session_id", "")).strip_edges()
	_guided_ai_active_request_id = 0
	_guided_ai_covered_beats.clear()
	_guided_ai_candidate_beat_ids.clear()
	_guided_ai_close_after_reply = false
	_guided_ai_closing_started = false
	_guided_ai_reply_playback_active = false
	_guided_ai_used_option_texts.clear()
	_guided_ai_used_reply_signatures.clear()
	_guided_ai_used_reply_texts.clear()
	is_free_chat_mode = true
	free_chat_strategy = str(policy.get("scene_objective", "")).strip_edges()
	free_chat_max_rounds = maxi(1, int(policy.get("max_player_rounds", 4)))
	free_chat_current_round = 0
	_update_free_chat_info()
	if free_chat_info_layer:
		free_chat_info_layer.move_to_front()
		free_chat_info_layer.show()
	var host := get_parent()
	if is_instance_valid(host) and host.has_method("_report_guide_action"):
		host.call("_report_guide_action", "select_main_chat_topic")
	if is_instance_valid(host) and host.has_method("_refresh_guide_overlay_if_needed"):
		host.call_deferred("_refresh_guide_overlay_if_needed")
	_refresh_guided_ai_round_guide_when_ready(host)
	_intro_playing = false
	dialogue_panel.set_story_mode(false)
	if dialogue_panel.has_method("set_ai_player_option_status"):
		dialogue_panel.set_ai_player_option_status("Luna正在思考中")
	if input_layer:
		input_layer.show()
	input_field.editable = true
	send_btn.disabled = false
	if end_chat_btn:
		end_chat_btn.visible = not bool(policy.get("hide_manual_end", true))
	_request_guided_ai_opening()

func _refresh_guided_ai_round_guide_when_ready(host: Node) -> void:
	await get_tree().process_frame
	if not _guided_ai_chat_active or not is_instance_valid(host):
		return
	if free_chat_info_layer and free_chat_info_layer.is_visible_in_tree() and host.has_method("_refresh_guide_overlay_if_needed"):
		host.call("_refresh_guide_overlay_if_needed")

func _request_guided_ai_opening() -> void:
	if not _guided_ai_chat_active:
		return
	var opening_result: Dictionary = GuidedAiPromptBuilder.build_user_message(
		_guided_ai_policy,
		_guided_ai_covered_beats,
		0,
		free_chat_max_rounds,
		"（玩家尚未发言，请由角色主动开始这段对话。）",
		true
	)
	_guided_ai_candidate_beat_ids.assign(opening_result.get("candidate_beat_ids", []))
	_guided_ai_turn_started_at_ms = Time.get_ticks_msec()
	if input_field:
		input_field.editable = false
	if send_btn:
		send_btn.disabled = true
	_request_ai_response(str(opening_result.get("prompt", "")), true)

func _on_script_finished(script_id: String) -> void:
	print("Script finished: ", script_id)
	_current_story_speaker_id = ""
	if character_layer and character_layer.has_method("end_story_mode"):
		character_layer.end_story_mode()
	var script_meta = script_engine.get_current_script_meta() if script_engine else {}
	_settle_completed_story_time(script_meta)
	var is_runtime_generated := bool(script_meta.get("runtime_generated", false))
	var is_date_story := str(script_meta.get("story_category", "")).strip_edges() == "date_dynamic"
	var is_first_completion := true
	if not is_runtime_generated:
		is_first_completion = not GameDataManager.profile.has_finished_story(script_id)
		GameDataManager.profile.mark_story_finished(script_id)
		if GameDataManager.has_meta("pending_map_entry_trigger_completion"):
			var pending_trigger: Dictionary = GameDataManager.get_meta("pending_map_entry_trigger_completion")
			GameDataManager.remove_meta("pending_map_entry_trigger_completion")
			var source_type := str(pending_trigger.get("source_type", "")).strip_edges()
			var source_id := str(pending_trigger.get("source_id", "")).strip_edges()
			var location_id := str(pending_trigger.get("location_id", "")).strip_edges()
			if source_type != "" and source_id != "" and MapDataManager and MapDataManager.has_method("mark_entry_trigger_consumed"):
				MapDataManager.mark_entry_trigger_consumed(source_type, source_id, location_id)
		var event_manager = get_node_or_null("/root/EventManager")
		if event_manager and event_manager.has_method("try_mark_event_by_story"):
			event_manager.try_mark_event_by_story(script_id)
		if is_first_completion:
			var story_post_event_manager = get_node_or_null("/root/StoryPostEventManager")
			if story_post_event_manager and story_post_event_manager.has_method("register_story_completion"):
				story_post_event_manager.register_story_completion(script_id, script_meta, is_first_completion)
	var guide_manager = get_node_or_null("/root/GuideManager")
	if guide_manager and guide_manager.has_method("report_story_finished"):
		guide_manager.report_story_finished(script_id, script_meta)
	if is_runtime_generated or is_first_completion:
		_register_story_completion_memory(script_id)
	if is_date_story:
		_apply_date_story_settlement(script_id, script_meta)
	if not _story_archive_id.is_empty():
		var save_succeeded: bool = bool(GameDataManager.save_manager.auto_save("story_completed:%s" % script_id, _story_archive_id))
		if not save_succeeded:
			push_error("剧情结算存档失败，保留检查点并停止场景切换：%s" % script_id)
			if ToastManager:
				ToastManager.show_system_toast("自动存档失败，请重试后再继续", Color.RED)
			return
		GameDataManager.save_story_checkpoint_for_archive({}, _story_archive_id)
	if external_session_controlled and _embedded_session_active:
		hide_panel()
		return
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
	elif get_parent() == get_tree().root and GameDataManager.has_meta("story_scene_followup_quick_location"):
		var followup: Dictionary = GameDataManager.get_meta("story_scene_followup_quick_location")
		GameDataManager.remove_meta("story_scene_followup_quick_location")
		var location_id := str(followup.get("location_id", "")).strip_edges()
		var npc_id := str(followup.get("npc_id", "")).strip_edges()
		var quick_scene = load("res://scenes/ui/map/core/quick_location_scene.tscn")
		if quick_scene:
			var instance = quick_scene.instantiate()
			instance.location_id = location_id
			instance.initial_npc_id = npc_id
			if get_tree().root.has_node("SceneTransitionManager"):
				get_tree().root.get_node("SceneTransitionManager").transition_to_scene_instance(instance, 0.45)
			else:
				get_tree().current_scene.queue_free()
				get_tree().root.add_child(instance)
				get_tree().current_scene = instance
	elif _return_to_main_on_story_finish and get_parent() == get_tree().root:
		_return_to_main_on_story_finish = false
		if get_tree().root.has_node("SceneTransitionManager"):
			get_tree().root.get_node("SceneTransitionManager").transition_to_scene("res://scenes/ui/main/main_scene.tscn")
		else:
			get_tree().change_scene_to_file("res://scenes/ui/main/main_scene.tscn")
	else:
		# 普通剧情剧本结束后，如果不是作为主界面常驻（比如是在日程执行中弹出的），则自动关闭
		if get_parent() != get_tree().root and not (get_parent().name == "MainScene" or get_parent().name == "UI"):
			# AI 聊天结束或者故事结束，发出信号，等待外部进行黑屏遮挡后再由外部负责 queue_free，
			# 从而避免默认的突兀消失效果。
			_emit_chat_closed()

func _apply_date_story_settlement(script_id: String, script_meta: Dictionary) -> void:
	if GameDataManager.profile == null:
		return

	var settlement: Dictionary = script_meta.get("date_settlement", {})
	if settlement.is_empty():
		return

	var intimacy_delta := float(settlement.get("intimacy_delta", 0.0))
	var trust_delta := float(settlement.get("trust_delta", 0.0))
	var has_changes := false

	if absf(intimacy_delta) > 0.001:
		GameDataManager.profile.update_intimacy(intimacy_delta)
		has_changes = true
		if ToastManager:
			ToastManager.show_stat_toast("intimacy", "亲密 +%.1f" % intimacy_delta)

	if absf(trust_delta) > 0.001:
		GameDataManager.profile.update_trust(trust_delta)
		has_changes = true
		if ToastManager:
			ToastManager.show_stat_toast("trust", "信任 +%.1f" % trust_delta)

	if has_changes:
		GameDataManager.profile.save_profile()

	_apply_date_story_memory_boost(script_id, script_meta, settlement)

func _apply_date_story_memory_boost(script_id: String, script_meta: Dictionary, settlement: Dictionary) -> void:
	if GameDataManager.memory_manager == null:
		return

	var record: Dictionary = settlement.get("memory_record", {})
	if record.is_empty():
		return

	var memory_layer := str(record.get("layer", "bond")).strip_edges()
	if memory_layer == "":
		memory_layer = "bond"

	var memory_context := _build_story_completion_memory_context(script_meta, record)
	var memory_scope := str(record.get("scope", "player_shared")).strip_edges()
	if memory_scope == "":
		memory_scope = "player_shared"
	var memory_visibility := str(record.get("visibility", "prompt")).strip_edges()
	if memory_visibility == "":
		memory_visibility = "prompt"
	var memory_participants := _normalize_story_memory_participants(record.get("participants", []))
	var memory_options = {
		"is_bond_mark": bool(record.get("is_bond_mark", false)),
		"source_type": "date_settlement",
		"source_id": script_id,
		"source_title": str(record.get("title", "约会后的关系推进")),
		"memory_scope": memory_scope,
		"memory_visibility": memory_visibility,
		"memory_participants": memory_participants,
		"memory_player_involved": bool(record.get("player_involved", true)),
		"memory_player_witnessed": bool(record.get("player_witnessed", true))
	}
	GameDataManager.memory_manager.add_memory_quick(memory_layer, str(record.get("content", "")), memory_context, memory_options)

func _register_story_completion_memory(script_id: String) -> void:
	if script_engine == null:
		return
	var story_memory_manager = GameDataManager.story_memory_manager if GameDataManager else null
	if story_memory_manager == null:
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
			"story_layer": memory_layer,
			"memory_scope": memory_scope,
			"memory_visibility": memory_visibility,
			"memory_participants": memory_participants,
			"memory_player_involved": memory_player_involved,
			"memory_player_witnessed": memory_player_witnessed
		}
		story_memory_manager.call("add_story_memory", memory_content, memory_context, memory_options)

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

func _build_story_completion_memory_content(_script_id: String, script_meta: Dictionary, record: Dictionary = {}) -> String:
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
	var is_daily := _is_embedded_daily_chat()
	if free_chat_round_label:
		free_chat_round_label.visible = not is_daily
		if free_chat_max_rounds > 0:
			free_chat_round_label.text = "对话轮次%d/%d" % [free_chat_current_round, free_chat_max_rounds]
		else:
			free_chat_round_label.text = "对话轮次"
	if free_chat_time_label:
		free_chat_time_label.visible = is_daily
		if is_daily and GameDataManager.story_time_manager:
			free_chat_time_label.text = "时间 %02d:%02d" % [GameDataManager.story_time_manager.current_hour, GameDataManager.story_time_manager.current_minute]
	if free_chat_energy_layer:
		free_chat_energy_layer.visible = is_daily
	if free_chat_energy_label and is_daily:
		free_chat_energy_label.text = "精力 %d/%d" % [GameDataManager.profile.current_energy, GameDataManager.profile.max_energy]

func get_daily_resource_status_focus_entries() -> Array[Dictionary]:
	var focus_entries: Array[Dictionary] = []
	for target in [free_chat_info_layer, free_chat_energy_layer]:
		if not is_instance_valid(target) or not (target as Control).is_visible_in_tree():
			continue
		var rect := (target as Control).get_global_rect()
		if rect.size.x <= 1.0 or rect.size.y <= 1.0:
			continue
		focus_entries.append({
			"rect": rect,
			"shape": "rect",
			"shape_params": {"corner_radius": 8.0}
		})
	return focus_entries

func _reset_free_chat_state() -> void:
	is_free_chat_mode = false
	free_chat_strategy = ""
	free_chat_max_rounds = 0
	free_chat_current_round = 0
	_update_free_chat_info()
	if free_chat_info_layer:
		free_chat_info_layer.hide()
	if free_chat_energy_layer:
		free_chat_energy_layer.hide()

func _build_guided_ai_user_message(player_text: String) -> String:
	var result: Dictionary = GuidedAiPromptBuilder.build_user_message_with_used_options(
		_guided_ai_policy,
		_guided_ai_covered_beats,
		free_chat_current_round,
		free_chat_max_rounds,
		player_text,
		_guided_ai_used_option_texts
	)
	_guided_ai_candidate_beat_ids.assign(result.get("candidate_beat_ids", []))
	return str(result.get("prompt", ""))

func _begin_guided_ai_closing() -> void:
	if not _guided_ai_chat_active or _guided_ai_closing_started:
		return
	if _guided_ai_active_request_id > 0 and deepseek_client:
		deepseek_client.cancel_structured_chat_request(_guided_ai_active_request_id)
		_guided_ai_active_request_id = 0
	_guided_ai_closing_started = true
	_guided_ai_close_after_reply = false
	_set_chat_closing_input_state()
	if quick_options_container and quick_options_container.get_parent():
		quick_options_container.get_parent().hide()
	var missing_beats: Array[Dictionary] = []
	_guided_ai_candidate_beat_ids.clear()
	for beat_value in _guided_ai_policy.get("required_beats", []):
		if beat_value is Dictionary:
			var beat_id := str((beat_value as Dictionary).get("id", "")).strip_edges()
			if beat_id != "" and not _guided_ai_covered_beats.has(beat_id):
				_guided_ai_candidate_beat_ids.append(beat_id)
				missing_beats.append({"id": beat_id, "instruction": str((beat_value as Dictionary).get("instruction", ""))})
	var closing_prompt := "【系统指令】本轮主线对话现在需要自然结束。%s 结束前请自然覆盖这些尚未表达的信息：%s。完成必要信息后，只结束当前对话，不要开启或延伸新话题，并自然表达这次先聊到这里、之后有机会再聊。你和玩家住在同一栋房子里，不得说自己或玩家要回家、离开这栋房子。dialogue 必须包含至少 12 个汉字的全角括号动作描写，同时写出两个以上可观察细节，例如手部动作、视线、姿态、呼吸、表情或现场物件互动；不得只写‘点头’‘微笑’等简短概括。不得提及系统、回合数或限制。必须只输出 JSON 对象，格式为：{\"dialogue\":\"（细腻的角色动作）角色收束台词\",\"beat_evaluations\":[{\"id\":\"候选剧情点 ID\",\"covered\":true,\"evidence\":\"dialogue 中逐字出现的证据片段\"}]}。evidence 必须逐字取自 dialogue，不得输出 Markdown 围栏或额外内容。" % [
		str(_guided_ai_policy.get("closing_instruction", "")),
		JSON.stringify(missing_beats)
	]
	_waiting_for_chat_exit = true
	_request_ai_response(closing_prompt, true)

func _are_guided_ai_required_beats_covered() -> bool:
	for beat_value in _guided_ai_policy.get("required_beats", []):
		if not (beat_value is Dictionary):
			continue
		var beat_id := str((beat_value as Dictionary).get("id", "")).strip_edges()
		if beat_id != "" and not _guided_ai_covered_beats.has(beat_id):
			return false
	return true

func _finish_guided_ai_chat(outcome: String = "complete") -> void:
	var branches: Dictionary = _guided_ai_policy.get("outcome_branches", {})
	var target_chapter := str(branches.get(outcome, branches.get("complete", ""))).strip_edges()
	_clear_guided_ai_state()
	dialogue_panel.set_story_mode(true)
	_set_chat_closing_input_state()
	if target_chapter != "" and target_chapter != "end":
		script_engine.is_waiting_for_resume = false
		script_engine.jump_to_chapter(target_chapter)
		script_engine.call("_process_next_event")
	elif target_chapter == "end":
		script_engine._end_script()
	elif script_engine and script_engine.is_running:
		script_engine.complete_guided_ai_chat()

func _clear_guided_ai_state() -> void:
	if _guided_ai_active_request_id > 0 and deepseek_client:
		deepseek_client.cancel_structured_chat_request(_guided_ai_active_request_id)
	_guided_ai_chat_active = false
	_guided_ai_policy.clear()
	_guided_ai_session_id = ""
	_guided_ai_active_request_id = 0
	_guided_ai_covered_beats.clear()
	_guided_ai_candidate_beat_ids.clear()
	_guided_ai_close_after_reply = false
	_guided_ai_closing_started = false
	_guided_ai_last_request_text = ""
	_guided_ai_last_raw_response = ""
	_guided_ai_parse_retry_count = 0
	_guided_ai_request_retry_count = 0
	_guided_ai_reply_playback_active = false
	_guided_ai_used_option_texts.clear()
	_guided_ai_used_reply_signatures.clear()
	_guided_ai_used_reply_texts.clear()
	_waiting_for_chat_exit = false
	if dialogue_panel and dialogue_panel.has_method("clear_ai_player_options"):
		dialogue_panel.clear_ai_player_options(true)
	_reset_free_chat_state()

func _finish_script_ai_chat() -> void:
	_script_ai_chat_active = false
	_reset_free_chat_state()
	_waiting_for_chat_exit = false
	dialogue_panel.set_story_mode(true)
	_set_chat_closing_input_state()
	quick_options_container.get_parent().show()
	pending_options_data.clear()
	if script_engine and script_engine.is_running:
		script_engine.resume()

func _send_player_message(text: String, is_system_event: bool = false) -> void:
	if not is_system_event and _guided_ai_chat_active and free_chat_max_rounds > 0 and free_chat_current_round >= free_chat_max_rounds:
		_set_chat_closing_input_state()
		return
	if not is_system_event and _is_embedded_daily_chat():
		var unavailable_reason := _get_embedded_daily_reply_unavailable_reason()
		if unavailable_reason != "":
			_request_embedded_daily_closing(unavailable_reason)
			return
		_commit_embedded_daily_reply_cost()
	if not is_system_event and is_free_chat_mode:
		free_chat_current_round += 1
		_update_free_chat_info()
	if _guided_ai_chat_active:
		_guided_ai_turn_started_at_ms = Time.get_ticks_msec()
		_guided_ai_reply_available_at_ms = 0
		print("[GuidedAITrace] round=%d/%d stage=player_send_started chars=%d system_event=%s" % [
			free_chat_current_round,
			free_chat_max_rounds,
			text.length(),
			str(is_system_event)
		])
	if not is_system_event and input_field:
		input_field.text = ""
			
	send_btn.disabled = true
	input_field.editable = false
	if dialogue_panel and dialogue_panel.has_method("set_input_waiting_state"):
		dialogue_panel.set_input_waiting_state(GameDataManager.profile.char_name)
	
	# 发起请求前清除之前的选项
	pending_options_data.clear()
	if _uses_ai_player_option_layer() and dialogue_panel and dialogue_panel.has_method("set_ai_player_option_status"):
		dialogue_panel.set_ai_player_option_status("Luna正在思考中")
	elif dialogue_panel and dialogue_panel.has_method("clear_ai_player_options"):
		dialogue_panel.clear_ai_player_options(true)
	if quick_options_container and quick_options_container.get_parent():
		quick_options_container.get_parent().hide()
	for child in quick_options_container.get_children():
		child.queue_free()
		
	if not is_system_event:
		# Wait for the typewriter effect of the player's message to finish before requesting AI response
		await _show_message_async(text, "我", false, "", "", "", _guided_ai_chat_active)
		if _guided_ai_chat_active:
			print("[GuidedAITrace] round=%d/%d stage=player_message_playback_completed elapsed_ms=%d" % [
				free_chat_current_round,
				free_chat_max_rounds,
				Time.get_ticks_msec() - _guided_ai_turn_started_at_ms
			])
	
	var request_text := _build_guided_ai_user_message(text) if _guided_ai_chat_active and not is_system_event else text
	_request_ai_response(request_text, is_system_event, text if _guided_ai_chat_active and not is_system_event else "")
	
	# 检查是否达到最大轮次，在发送请求后关闭模式，这样本次请求还能带上策略
	if _guided_ai_chat_active and _guided_ai_round_policy.should_close_after_round(free_chat_current_round, free_chat_max_rounds):
		_guided_ai_close_after_reply = true
		input_field.editable = false
		send_btn.disabled = true
	elif is_free_chat_mode and free_chat_max_rounds > 0 and free_chat_current_round >= free_chat_max_rounds:
		if _is_embedded_daily_chat():
			_embedded_daily_close_queued = true
			input_field.editable = false
			send_btn.disabled = true
			if end_chat_btn:
				end_chat_btn.hide()
		else:
			_reset_free_chat_state()
			ToastManager.show_system_toast("自由对话阶段结束", Color(0.8, 0.4, 0.1, 0.9))
		
		# 如果是作为独立剧情执行的最后一个事件，手动调用恢复以触发 _on_script_finished
		if not _is_embedded_daily_chat() and script_engine.is_running:
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
		deepseek_client.send_realize_turn_message(continue_prompt, "story_chat", {
			"channel": "story_dialogue_event",
			"event_kind": "offline_continue",
			"turn_origin": "program_event",
			"conversation_subtype": conversation_subtype
		}, _build_story_knowledge_access_context())
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
	if external_session_controlled and not _embedded_session_active:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if ui_panel and (not ui_panel.visible or ui_panel.modulate.a < 0.99):
			get_viewport().set_input_as_handled()
			if _ui_tween:
				_ui_tween.kill()
			ui_panel.visible = true
			_ui_tween = create_tween()
			_ui_tween.tween_property(ui_panel, "modulate:a", 1.0, 0.3)
			return
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

func start_embedded_topic_session(request: Dictionary) -> void:
	set_process_input(true)
	_embedded_session_active = true
	_embedded_daily_turn_pending = false
	_embedded_daily_close_queued = false
	_embedded_session_request = request.duplicate(true)
	_embedded_topic_options = request.get("topic_options", []).duplicate(true)
	conversation_subtype = str(request.get("subtype", conversation_subtype)).strip_edges()
	free_chat_strategy = str(request.get("ai_context", "")).strip_edges()
	free_chat_max_rounds = 0
	free_chat_current_round = 0
	is_free_chat_mode = true
	_update_free_chat_info()
	if free_chat_info_layer:
		free_chat_info_layer.visible = str(request.get("mode", "")) == "daily"
	_intro_playing = true
	_waiting_for_chat_exit = false
	QuickOptionListHelper.clear_container(quick_options_container)
	if quick_option_layer:
		quick_option_layer.hide()
	if quick_options_container and quick_options_container.get_parent():
		quick_options_container.get_parent().hide()
	if input_layer:
		input_layer.hide()
	if end_chat_btn:
		end_chat_btn.hide()
	dialogue_panel.set_story_mode(true)
	show_panel()
	_play_embedded_intro()

func start_embedded_story_session(request: Dictionary, script_path: String) -> void:
	set_process_input(true)
	_embedded_session_active = true
	_embedded_session_request = request.duplicate(true)
	conversation_subtype = str(request.get("subtype", conversation_subtype)).strip_edges()
	show_panel()
	_play_story(script_path)

func start_embedded_story_data_session(request: Dictionary, script_data: Dictionary) -> void:
	set_process_input(true)
	_embedded_session_active = true
	_embedded_session_request = request.duplicate(true)
	conversation_subtype = str(request.get("subtype", conversation_subtype)).strip_edges()
	show_panel()
	_play_story_data(script_data)

func _play_embedded_intro() -> void:
	var intro_events: Array = _embedded_session_request.get("intro_events", [])
	for raw_event in intro_events:
		if not _embedded_session_active or not (raw_event is Dictionary):
			return
		var event_data := raw_event as Dictionary
		var content := str(event_data.get("content", "")).strip_edges()
		if content == "":
			continue
		var speaker := str(event_data.get("speaker", "旁白")).strip_edges()
		var display_speaker := " " if speaker == "旁白" else speaker
		var auto_advance := bool(event_data.get("auto_advance", false))
		await _show_message_async(content, display_speaker, true, "", "", "", auto_advance)
	_intro_playing = false
	if _embedded_topic_options.is_empty():
		_enter_embedded_free_chat()
		return
	if quick_option_layer:
		quick_option_layer.show()
	if quick_options_container and quick_options_container.get_parent():
		quick_options_container.get_parent().show()
	QuickOptionListHelper.populate_option_items_with_index(
		quick_options_container,
		_embedded_topic_options,
		_on_embedded_topic_selected
	)
	embedded_topic_options_ready.emit(_embedded_session_request.duplicate(true))

func _on_embedded_topic_selected(topic: String, index: int = -1) -> void:
	if not _embedded_session_active or index < 0 or index >= _embedded_topic_options.size():
		return
	var cost_action := str(_embedded_session_request.get("cost_action", "")).strip_edges()
	if cost_action != "" and GameDataManager.interaction_manager:
		if not GameDataManager.interaction_manager.execute_interaction(cost_action):
			return
	var option_data := (_embedded_topic_options[index] as Dictionary).duplicate(true)
	var subtype_by_kind: Dictionary = _embedded_session_request.get("subtype_by_kind", {})
	var option_kind := str(option_data.get("kind", "")).strip_edges()
	if subtype_by_kind.has(option_kind):
		conversation_subtype = str(subtype_by_kind.get(option_kind, conversation_subtype))
	QuickOptionListHelper.clear_container(quick_options_container)
	if quick_option_layer:
		quick_option_layer.hide()
	if quick_options_container and quick_options_container.get_parent():
		quick_options_container.get_parent().hide()
	embedded_topic_selected.emit(topic, option_data)
	_enter_embedded_free_chat()
	if _is_embedded_daily_chat():
		_embedded_daily_turn_pending = true
	var prompt_template := str(_embedded_session_request.get("topic_prompt_template", "")).strip_edges()
	var prompt := prompt_template.replace("{topic}", topic)
	if prompt == "":
		prompt = topic
	_send_player_message(prompt, true)

func _enter_embedded_free_chat() -> void:
	dialogue_panel.set_story_mode(false)
	if _is_embedded_daily_chat() and dialogue_panel.has_method("set_ai_player_option_status"):
		dialogue_panel.set_ai_player_option_status("Luna正在思考中")
	if input_layer:
		input_layer.show()
	input_field.editable = true
	send_btn.disabled = false
	if end_chat_btn:
		end_chat_btn.show()

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
		if external_session_controlled:
			set_process_input(false)
		_emit_chat_closed()
		
		# 强制检查：如果正在运行剧情且没有因为正常轮次耗尽而结束，玩家手动退出了界面，
		# 我们也视作当前挂起的剧情结束，防止无法保存剧情状态。
		if _guided_ai_chat_active:
			_clear_guided_ai_state()
		if script_engine.is_running:
			script_engine._end_script()
		_script_ai_chat_active = false
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
			if not _line_text_complete:
				get_viewport().set_input_as_handled()
				if _typewriter_tween:
					_typewriter_tween.kill()
				dialogue_text.visible_ratio = 1.0
				dialogue_text.visible_characters = -1
				_line_text_complete = true
				if dialogue_panel and dialogue_panel.has_method("set_continue_indicator_visible"):
					dialogue_panel.set_continue_indicator_visible(true)
			elif _intro_playing:
				if dialogue_panel and dialogue_panel.has_method("set_continue_indicator_visible"):
					dialogue_panel.set_continue_indicator_visible(false)
				get_viewport().set_input_as_handled()
				_line_advance_requested = true
				_intro_waiting_for_click = false
				_cancel_active_line_audio()
				_intro_click_proceed.emit()
			else:
				if dialogue_panel and dialogue_panel.has_method("set_continue_indicator_visible"):
					dialogue_panel.set_continue_indicator_visible(false)
				get_viewport().set_input_as_handled()
				_line_advance_requested = true
				_waiting_for_chat_click = false
				_cancel_active_line_audio()
				_chat_click_proceed.emit()

func _cancel_active_line_audio() -> void:
	_active_line_tts_text = ""
	if is_instance_valid(audio_player) and audio_player.playing:
		audio_player.stop()

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
	if _guided_ai_chat_active:
		if _guided_ai_reply_playback_active:
			_guided_ai_close_after_reply = true
			if end_chat_btn:
				end_chat_btn.hide()
			return
		_begin_guided_ai_closing()
		return
	if _is_embedded_daily_chat():
		_embedded_daily_close_queued = true
		_embedded_daily_turn_pending = false
		_set_chat_closing_input_state()
		if quick_options_container and quick_options_container.get_parent():
			quick_options_container.get_parent().hide()
		if dialogue_panel and dialogue_panel.has_method("clear_ai_player_options"):
			dialogue_panel.clear_ai_player_options(true)
		if end_chat_btn:
			end_chat_btn.hide()
		if is_text_playback_finished and not _waiting_for_chat_click and not (_typewriter_tween and _typewriter_tween.is_valid() and _typewriter_tween.is_running()):
			_request_embedded_daily_closing("manual")
		return
	_embedded_daily_turn_pending = false
	if not GameDataManager.config.ai_mode_enabled:
		_show_message("（离线模式）下次再见！", GameDataManager.profile.char_name)
		await get_tree().create_timer(1.5).timeout
		if _script_ai_chat_active:
			_finish_script_ai_chat()
		else:
			_emit_chat_closed()
		return
		
	# 保留输入区域作为请求状态反馈，只禁用交互。
	_set_chat_closing_input_state()
	quick_options_container.get_parent().hide() # 隐藏整个 QuickOptionLayer/ScrollContainer
	
	is_text_playback_finished = false
	pending_options_data.clear()
	
	# 从历史记录中提取最近的几条对话上下文作为参考
	var recent_history = GameDataManager.profile.get_recent_chat_history_text_by_type("story_chat", 3)
	
	var prompt = GameDataManager.prompt_manager.build_end_chat_prompt(GameDataManager.profile, recent_history)
	
	# 发送隐藏系统消息来获取告别回复
	deepseek_client.send_realize_turn_message(prompt, "story_chat", {
		"channel": "story_dialogue_event",
		"event_kind": "chat_exit",
		"turn_origin": "program_event",
		"conversation_subtype": conversation_subtype
	}, _build_story_knowledge_access_context())
	
	# 设定一个特殊标记，表示 AI 下一句话结束后应该退出面板
	_waiting_for_chat_exit = true

var _waiting_for_chat_exit: bool = false
var _mood_analysis_running: bool = false
var _pending_mood_analysis_line: String = ""

func _on_voice_record_down() -> void:
	_voice_record_press_active = false
	var guide_manager := get_node_or_null("/root/GuideManager")
	if guide_manager and guide_manager.has_method("get_current_step_id"):
		if str(guide_manager.get_current_step_id()) == "explain_guided_ai_voice_button":
			guide_manager.report_action("acknowledge_guided_ai_voice_button")
			return
	_voice_record_press_active = true
	if voice_record_btn:
		voice_record_btn.text = "松开发送"
		voice_record_btn.modulate = Color(0.8, 0.2, 0.2)
	if GameDataManager.config.qwen_asr_enabled and qwen_asr_client:
		qwen_asr_client.start_recording()

func _on_voice_record_up() -> void:
	if not _voice_record_press_active:
		return
	_voice_record_press_active = false
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
		deepseek_client.send_realize_turn_message(prompt, "story_chat", {
			"channel": "story_dialogue_event",
			"event_kind": "gift_reaction",
			"turn_origin": "program_event",
			"conversation_subtype": conversation_subtype
		}, _build_story_knowledge_access_context())
	else:
		if is_inside_tree():
			await get_tree().create_timer(1.0).timeout
		_show_message("（离线模式）谢谢你的礼物！我很喜欢。", char_name)
		send_btn.disabled = false
		input_field.editable = true

func _on_debug_stage_changed(stage: int) -> void:
	ToastManager.show_system_toast("【Debug】强制切换情感阶段至：" + str(stage), Color.CYAN)
	# Clear short term history so the AI doesn't get confused by previous stage's context
	GameDataManager.history.messages.clear()
	GameDataManager.history.save_history()
	_update_ui()
	ToastManager.show_system_toast("已清空上下文历史，以重新适配新阶段", Color.GRAY)

func _on_stage_upgraded(new_stage: int) -> void:
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
	if character_layer and character_layer.has_method("update_expression"):
		character_layer.update_expression(expression)
		return

	var sprite_path = GameDataManager.expression_system.get_expression_sprite_path(expression)
	if sprite_path != "" and ResourceLoader.exists(sprite_path):
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
	var history_character_id := ""
	for msg in GameDataManager.history.messages:
		if str(msg.get("voice_cache_key", "")) == cache_key:
			history_text = str(msg.get("text", ""))
			history_character_id = str(msg.get("character_id", "")).strip_edges().to_lower()
			if history_character_id.is_empty():
				history_character_id = _resolve_story_speaker_id(str(msg.get("speaker", "")))
			break

	if history_text != "":
		var bbcode_regex = RegEx.new()
		bbcode_regex.compile("\\[/?[^\\]]+\\]")
		var clean_text = bbcode_regex.sub(history_text, "", true).strip_edges()
		clean_text = ChatSplitHelper.strip_parentheses(clean_text).strip_edges()
		if clean_text != "":
			TTSManager.synthesize(clean_text, {"character_id": history_character_id})
			return

	print("未找到语音缓存: ", cache_key)

func _request_ai_response(text: String, is_system_event: bool, history_text: String = "") -> void:
	if not is_system_event and _guided_ai_chat_active:
		var saved_text := history_text if history_text != "" else text
		GameDataManager.history.add_message("我", saved_text, "", "story_chat", {"subtype": conversation_subtype})
		
	# Clear the flag for playback finish
	is_text_playback_finished = false
	
	if GameDataManager.config.ai_mode_enabled:
		if _guided_ai_chat_active:
			_guided_ai_last_request_text = text
			_guided_ai_parse_retry_count = 0
			_guided_ai_request_retry_count = 0
			var request_context := {
				"session_id": _guided_ai_session_id,
				"request_kind": "closing" if _guided_ai_closing_started else "normal",
				"candidate_beat_ids": _guided_ai_candidate_beat_ids.duplicate(),
				"trace_source": "guided_ai_chat",
				"turn_started_at_ms": _guided_ai_turn_started_at_ms,
				"force_text_response": true,
				"generation_temperature": GUIDED_AI_INITIAL_TEMPERATURE
			}
			_guided_ai_active_request_id = deepseek_client.send_chat_message_structured(text, "story_chat", request_context, _build_story_knowledge_access_context())
		else:
			deepseek_client.send_realize_turn_message(text, "story_chat", {
				"channel": "story_dialogue_event" if is_system_event else "story_dialogue_player",
				"event_kind": "daily_topic_selected" if is_system_event and _is_embedded_daily_chat() else "",
				"turn_origin": "program_event" if is_system_event else "player_input",
				"conversation_subtype": conversation_subtype
			}, _build_story_knowledge_access_context())
	else:
		if _guided_ai_chat_active:
			if is_system_event:
				_show_message("（轻轻看向你）我想继续聊聊刚才的事。", GameDataManager.profile.char_name)
				_set_dialogue_input_ready(false)
				return
			await _finish_guided_ai_chat_with_fallback()
			return
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
	if _is_embedded_daily_chat():
		_embedded_daily_turn_pending = true
	
	_send_player_message(text, false)

func _is_embedded_daily_chat() -> bool:
	return _embedded_session_active and str(_embedded_session_request.get("mode", "")) == "daily"

func _get_embedded_daily_reply_unavailable_reason() -> String:
	if not _is_embedded_daily_chat():
		return ""
	var current_minutes := 0
	if GameDataManager.story_time_manager:
		current_minutes = int(GameDataManager.story_time_manager.current_hour) * 60 + int(GameDataManager.story_time_manager.current_minute)
	return DailyChatRoundPolicyScript.get_unavailable_reason(
		int(GameDataManager.profile.current_energy),
		maxi(0, int(_embedded_session_request.get("reply_energy_cost", 0))),
		current_minutes,
		maxi(0, int(_embedded_session_request.get("reply_minutes", 0))),
		maxi(0, int(_embedded_session_request.get("daily_chat_cutoff_minutes", 24 * 60)))
	)

func _commit_embedded_daily_reply_cost() -> void:
	if not _is_embedded_daily_chat():
		return
	var energy_cost := maxi(0, int(_embedded_session_request.get("reply_energy_cost", 0)))
	var reply_minutes := maxi(0, int(_embedded_session_request.get("reply_minutes", 0)))
	if energy_cost > 0:
		GameDataManager.profile.consume_energy(energy_cost)
	if reply_minutes > 0 and GameDataManager.story_time_manager:
		GameDataManager.story_time_manager.tick_minutes(reply_minutes)
		GameDataManager.story_time_manager.save_data()
	_update_free_chat_info()

func _uses_ai_player_option_layer() -> bool:
	return _guided_ai_chat_active or _is_embedded_daily_chat()

func _settle_embedded_daily_turn() -> String:
	if not _embedded_daily_turn_pending or not _is_embedded_daily_chat():
		return ""
	_embedded_daily_turn_pending = false
	return _get_embedded_daily_reply_unavailable_reason()

func _request_embedded_daily_closing(reason: String) -> void:
	if not _is_embedded_daily_chat() or _waiting_for_chat_exit:
		return
	_embedded_daily_close_queued = false
	_embedded_daily_turn_pending = false
	_set_chat_closing_input_state()
	if quick_options_container and quick_options_container.get_parent():
		quick_options_container.get_parent().hide()
	var reason_instruction := "你有点累了，需要在家里休息一下" if reason == "energy" else ("玩家希望结束这次交谈" if reason == "manual" else "时间已经很晚了，需要结束交谈并在家里休息")
	var prompt := "【系统提示】%s。请以 Luna 的口吻自然表示这次先聊到这里、之后有机会再聊。只结束当前对话，不要开启或延伸新话题。你和玩家住在同一栋房子里，不得说自己或玩家要回家、离开这栋房子。只回复一句包含句首括号动作描写的结束语，不要复述系统提示。" % reason_instruction
	_waiting_for_chat_exit = true
	deepseek_client.send_realize_turn_message(prompt, "story_chat", {
		"channel": "story_dialogue_event",
		"event_kind": "chat_exit",
		"exit_reason": reason,
		"turn_origin": "program_event",
		"conversation_subtype": conversation_subtype
	}, _build_story_knowledge_access_context())

func _set_dialogue_input_ready(clear_text: bool = true) -> void:
	if dialogue_panel and dialogue_panel.has_method("set_input_ready_state"):
		dialogue_panel.set_input_ready_state(clear_text)
		if end_chat_btn:
			end_chat_btn.disabled = false
		return
	if input_field:
		if clear_text:
			input_field.text = ""
		input_field.editable = true
		input_field.grab_focus()
	if send_btn:
		send_btn.disabled = false
	if voice_record_btn:
		voice_record_btn.disabled = false
	if end_chat_btn:
		end_chat_btn.disabled = false

func _set_chat_closing_input_state() -> void:
	if dialogue_panel and dialogue_panel.has_method("set_input_waiting_state"):
		dialogue_panel.set_input_waiting_state(GameDataManager.profile.char_name)
	elif input_layer:
		input_layer.show()
	if input_field:
		input_field.editable = false
	if send_btn:
		send_btn.disabled = true
	if voice_record_btn:
		voice_record_btn.disabled = true
	if end_chat_btn:
		end_chat_btn.disabled = true

func _on_chat_response(response: Dictionary) -> void:
	var char_name = GameDataManager.profile.char_name
	if _guided_ai_chat_active and _guided_ai_reply_playback_active:
		print("[GuidedAITrace] stage=response_discarded reason=reply_playback_active")
		return
	if response.has("choices") and response["choices"].size() > 0:
		var reply = response["choices"][0]["message"]["content"]
		if _guided_ai_chat_active:
			_guided_ai_last_raw_response = str(reply)
			var require_next_options := not _guided_ai_close_after_reply and not _guided_ai_closing_started
			var parsed_guided: Dictionary = GuidedAiResponseParser.parse_response_with_required_options(str(reply), _guided_ai_candidate_beat_ids) if require_next_options else GuidedAiResponseParser.parse_response(str(reply), _guided_ai_candidate_beat_ids)
			if not bool(parsed_guided.get("ok", false)):
				_retry_guided_ai_response(str(parsed_guided.get("error", "响应格式错误。")))
				return
			reply = str(parsed_guided.get("dialogue", ""))
			if _is_duplicate_guided_ai_reply(reply):
				_retry_guided_ai_response("dialogue 与本次会话已经播放的角色回复重复；必须回应玩家的新输入并推进当前剧情点，不得复述上一句。")
				return
			for beat_id in parsed_guided.get("covered_beat_ids", []):
				var normalized_beat_id := str(beat_id)
				if not _guided_ai_covered_beats.has(normalized_beat_id):
					_guided_ai_covered_beats.append(normalized_beat_id)
			_guided_ai_candidate_beat_ids.clear()
			if not _guided_ai_close_after_reply and not _guided_ai_closing_started:
				pending_options_data = _filter_guided_ai_options(parsed_guided.get("next_options", []))
				if pending_options_data.is_empty():
					pending_options_data = _build_guided_ai_fallback_options()
		
		# 非流式模式下，收到完整回复后也立刻提前触发选项生成，并手动传入最新回复
		if not _guided_ai_chat_active and GameDataManager.config.ai_mode_enabled and not _waiting_for_chat_exit and not _guided_ai_close_after_reply:
			deepseek_client.send_options_generation(reply, free_chat_strategy if is_free_chat_mode else "", "story_chat", conversation_subtype)
			
			# 提交完整回合记忆观察
			var messages = GameDataManager.history.get_messages_by_type("story_chat").filter(func(message: Dictionary) -> bool:
				return str(message.get("subtype", "")) == conversation_subtype
			)
			if messages.size() > 0:
				var last_msg = messages[messages.size() - 1]
				if last_msg["speaker"] == "我" and GameDataManager.memory_observation_service:
					GameDataManager.memory_observation_service.observe_completed_turn("story_chat", str(last_msg["text"]), str(reply))
			
		# 拦截 reply 进行预处理，提取纯净的消息序列
		var lines = _parse_reply_to_lines(reply)
		if lines.size() == 0:
			if _guided_ai_chat_active:
				_retry_guided_ai_response("dialogue 没有可播放内容。")
				return
			_show_message(char_name + " 似乎走神了...", char_name)
			_set_dialogue_input_ready()
			return
			
		if _guided_ai_chat_active:
			if dialogue_panel and dialogue_panel.has_method("set_ai_player_option_status"):
				dialogue_panel.set_ai_player_option_status("Luna正在讲话")
			_guided_ai_reply_playback_active = true
		_play_message_sequence(lines, char_name)
	else:
		if _guided_ai_chat_active:
			_retry_guided_ai_response("响应缺少 choices。")
			return
		_show_message(char_name + " 似乎走神了...", char_name)
		_set_dialogue_input_ready()

func _on_realize_turn_completed(realized_turn: Dictionary, request_context: Dictionary) -> void:
	var channel := str(request_context.get("channel", ""))
	if channel != "story_dialogue_player" and channel != "story_dialogue_event":
		return
	var segments: Variant = realized_turn.get("segments")
	if not segments is Array or segments.is_empty():
		_on_realize_turn_failed("角色回复没有可展示内容。", request_context)
		return
	var lines: Array = []
	var accepted_speech: Array[String] = []
	for index in range(segments.size()):
		var segment: Variant = segments[index]
		if not segment is Dictionary:
			continue
		var line_data := (segment as Dictionary).duplicate(true)
		line_data["reply_pipeline"] = str(request_context.get("reply_pipeline", "realize_turn_v6"))
		line_data["ai_request_id"] = str(request_context.get("request_id", ""))
		line_data["memory_trace_id"] = str(request_context.get("trace_id", ""))
		line_data["response_segment_index"] = index
		line_data["response_adopted"] = true
		lines.append(line_data)
		accepted_speech.append(str(line_data.get("speech", "")).strip_edges())
	var combined_speech := "\n".join(accepted_speech)
	if GameDataManager.config.ai_mode_enabled and not _waiting_for_chat_exit:
		deepseek_client.send_options_generation(combined_speech, free_chat_strategy if is_free_chat_mode else "", "story_chat", conversation_subtype)
	var player_text := str(request_context.get("player_text", "")).strip_edges()
	if channel == "story_dialogue_player" and not player_text.is_empty() and GameDataManager.memory_observation_service:
		GameDataManager.memory_observation_service.observe_completed_turn("story_chat", player_text, combined_speech)
	if _uses_ai_player_option_layer() and dialogue_panel and dialogue_panel.has_method("set_ai_player_option_status"):
		dialogue_panel.set_ai_player_option_status("Luna正在讲话")
	_play_message_sequence(lines, GameDataManager.profile.char_name)

func _on_realize_turn_failed(error_message: String, request_context: Dictionary) -> void:
	var channel := str(request_context.get("channel", ""))
	if channel != "story_dialogue_player" and channel != "story_dialogue_event":
		return
	_embedded_daily_turn_pending = false
	if _waiting_for_chat_exit:
		_waiting_for_chat_exit = false
		var exit_reason := str(request_context.get("exit_reason", ""))
		var fallback_text := "（轻轻合上手边的东西）那我们先聊到这里，我就在旁边待着。"
		if exit_reason == "energy":
			fallback_text = "（轻轻揉了揉眼睛）我有点累了，先在这里歇一会儿吧。"
		elif exit_reason == "late":
			fallback_text = "（抬眼看了看时间）已经很晚了，我们先休息吧。"
		await _show_message_async(fallback_text, GameDataManager.profile.char_name, false, "", "", "", true)
		_emit_chat_closed()
		return
	_set_dialogue_input_ready()
	ToastManager.show_system_toast(error_message, Color.RED)

func _on_structured_chat_response(response: Dictionary, request_context: Dictionary) -> void:
	if str(request_context.get("reply_pipeline", "")) == "realize_turn_v6":
		return
	if not _is_current_guided_request(request_context):
		print("[GuidedAITrace] request=%d stage=response_discarded active=%s active_request=%d active_session=%s response_session=%s closing=%s response_kind=%s" % [
			int(request_context.get("request_id", 0)),
			str(_guided_ai_chat_active),
			_guided_ai_active_request_id,
			_guided_ai_session_id,
			str(request_context.get("session_id", "")),
			str(_guided_ai_closing_started),
			str(request_context.get("request_kind", ""))
		])
		return
	_guided_ai_reply_available_at_ms = Time.get_ticks_msec()
	print("[GuidedAITrace] request=%d stage=reply_available elapsed_from_send_ms=%d prompt_ms=%d embedding_ms=%d render_ms=%d http_ms=%d" % [
		int(request_context.get("request_id", 0)),
		_guided_ai_reply_available_at_ms - int(request_context.get("turn_started_at_ms", _guided_ai_reply_available_at_ms)),
		int(request_context.get("prompt_build_ms", -1)),
		int(request_context.get("query_embedding_ms", -1)),
		int(request_context.get("prompt_render_ms", -1)),
		int(request_context.get("model_http_ms", -1))
	])
	_guided_ai_candidate_beat_ids.assign(request_context.get("candidate_beat_ids", []))
	_guided_ai_active_request_id = 0
	_on_chat_response(response)

func _retry_guided_ai_response(parse_error: String) -> void:
	if not _guided_ai_chat_active:
		return
	if _guided_ai_parse_retry_count >= GUIDED_AI_MAX_RETRIES:
		_guided_ai_active_request_id = 0
		var recovered_dialogue := GuidedAiResponseParser.recover_dialogue(_guided_ai_last_raw_response)
		if not recovered_dialogue.is_empty() and not _is_duplicate_guided_ai_reply(recovered_dialogue):
			print("[GuidedAITrace] stage=validation_exhausted_adopted error=%s chars=%d" % [parse_error, recovered_dialogue.length()])
			_guided_ai_candidate_beat_ids.clear()
			_accept_guided_ai_dialogue(recovered_dialogue)
			return
		push_error("[GuidedAI] 模型连续返回无法提取台词的响应：%s raw=%s" % [parse_error, _guided_ai_last_raw_response])
		ToastManager.show_system_toast("AI 回复格式异常，已恢复当前对话。", Color.ORANGE)
		_resume_guided_ai_after_request_failure()
		return
	_guided_ai_parse_retry_count += 1
	if parse_error.begins_with("dialogue 与本次会话已经播放的角色回复重复"):
		var regeneration_prompt := "%s\n\n【重新生成任务】上一次候选回复与本次会话已经播放的内容语义重复，必须完全舍弃，重新回应玩家最新输入。使用不同的动作、关注点和信息推进，不得再次表达相同的担忧、承诺或结论。只输出约定的合法 JSON 对象。" % _guided_ai_last_request_text
		_send_guided_ai_retry(regeneration_prompt, {
			"parse_retry": _guided_ai_parse_retry_count,
			"generation_temperature": GUIDED_AI_REGENERATION_TEMPERATURE
		})
		return
	var repair_source := _guided_ai_last_raw_response.left(4000)
	var repair_options_requirement := "next_options 必须是空数组。" if _guided_ai_close_after_reply or _guided_ai_closing_started else "next_options 必须是两个内容不同、未在本次会话使用过、玩家可直接发送的选项。"
	var retry_prompt := "%s\n\n【结构修复任务】上一次响应存在问题：%s。请修复下方响应，不要重新偏离本轮语义；优先保留其中可用的 dialogue，并补齐缺失或无效的 beat_evaluations 与 next_options。%s 最终只输出一个合法 JSON 对象，不要输出解释、Markdown 或额外文字。\n<待修复响应>\n%s\n</待修复响应>" % [_guided_ai_last_request_text, parse_error, repair_options_requirement, repair_source]
	var repair_temperature := GUIDED_AI_FIRST_REPAIR_TEMPERATURE if _guided_ai_parse_retry_count == 1 else GUIDED_AI_LATER_REPAIR_TEMPERATURE
	_send_guided_ai_retry(retry_prompt, {
		"parse_retry": _guided_ai_parse_retry_count,
		"generation_temperature": repair_temperature
	})

func _accept_guided_ai_dialogue(reply: String) -> void:
	if _guided_ai_reply_playback_active:
		return
	if not _register_guided_ai_reply(reply):
		_finish_guided_ai_chat_with_fallback()
		return
	if not _guided_ai_close_after_reply and not _guided_ai_closing_started:
		pending_options_data = _build_guided_ai_fallback_options()
	var lines := _parse_reply_to_lines(reply)
	if lines.is_empty():
		_set_dialogue_input_ready(false)
		return
	if dialogue_panel and dialogue_panel.has_method("set_ai_player_option_status"):
		dialogue_panel.set_ai_player_option_status("Luna正在讲话")
	_guided_ai_reply_playback_active = true
	_play_message_sequence(lines, GameDataManager.profile.char_name)

func _on_structured_chat_error(error_message: String, request_context: Dictionary) -> void:
	if not _is_current_guided_request(request_context):
		return
	_guided_ai_active_request_id = 0
	if error_message.contains("429"):
		push_warning("[GuidedAI] 请求被限流，跳过立即重试并恢复当前会话。")
		ToastManager.show_system_toast("AI 服务繁忙，已恢复当前对话。", Color.ORANGE)
		_resume_guided_ai_after_request_failure()
		return
	if _guided_ai_request_retry_count >= GUIDED_AI_MAX_RETRIES:
		var exhausted_failure_stage := str(request_context.get("failure_stage", "unknown"))
		push_warning("[GuidedAI] 请求恢复耗尽，保持当前会话 stage=%s error=%s context=%s" % [exhausted_failure_stage, error_message, JSON.stringify(request_context)])
		ToastManager.show_system_toast("AI 回复暂时异常，已保留当前对话。", Color.ORANGE)
		_resume_guided_ai_after_request_failure()
		return
	_guided_ai_request_retry_count += 1
	var failure_stage := str(request_context.get("failure_stage", "unknown"))
	print("[GuidedAITrace] stage=request_retry retry=%d/%d failure_stage=%s error=%s" % [
		_guided_ai_request_retry_count,
		GUIDED_AI_MAX_RETRIES,
		failure_stage,
		error_message
	])
	var provider_content_empty := failure_stage == "provider_content"
	var recovery_instruction := "上一次服务端 JSON 模式返回了空白内容。本次改用文本传输，但输出内容仍必须是约定的单个合法 JSON 对象。" if provider_content_empty else "上一次请求未成功（%s）。" % error_message
	var retry_prompt := "%s\n\n【请求恢复】%s 请继续完成同一轮回复，不要提及错误、模式切换或重试，只输出约定的合法 JSON。" % [_guided_ai_last_request_text, recovery_instruction]
	var retry_metadata := {
		"request_retry": _guided_ai_request_retry_count,
		"generation_temperature": GUIDED_AI_INITIAL_TEMPERATURE
	}
	if provider_content_empty:
		retry_metadata["force_text_response"] = true
	_send_guided_ai_retry(retry_prompt, retry_metadata)

func _send_guided_ai_retry(prompt: String, retry_metadata: Dictionary) -> void:
	var request_context := {
		"session_id": _guided_ai_session_id,
		"request_kind": "closing" if _guided_ai_closing_started else "normal",
		"candidate_beat_ids": _guided_ai_candidate_beat_ids.duplicate(),
		"trace_source": "guided_ai_chat",
		"turn_started_at_ms": _guided_ai_turn_started_at_ms,
		"force_text_response": true
	}
	request_context.merge(retry_metadata, true)
	_guided_ai_active_request_id = deepseek_client.send_chat_message_structured(prompt, "story_chat", request_context, _build_story_knowledge_access_context())

func _resume_guided_ai_after_request_failure() -> void:
	if not _guided_ai_chat_active or _guided_ai_reply_playback_active:
		return
	_guided_ai_request_retry_count = 0
	_guided_ai_parse_retry_count = 0
	_guided_ai_candidate_beat_ids.clear()
	pending_options_data = _build_guided_ai_fallback_options()
	var recovery_text := "（她稍稍停顿，重新整理了一下思绪，认真地看向你）刚才有点走神了，我们继续说这件事吧。"
	var recovery_lines := _parse_reply_to_lines(recovery_text)
	if recovery_lines.is_empty():
		is_text_playback_finished = true
		_try_show_options()
		_set_dialogue_input_ready(false)
		return
	if dialogue_panel and dialogue_panel.has_method("set_ai_player_option_status"):
		dialogue_panel.set_ai_player_option_status("Luna正在讲话")
	_guided_ai_reply_playback_active = true
	_play_message_sequence(recovery_lines, GameDataManager.profile.char_name)

func _is_current_guided_request(request_context: Dictionary) -> bool:
	if not _guided_ai_chat_active:
		return false
	return GuidedAiRequestGuard.matches(_guided_ai_session_id, _guided_ai_active_request_id, _guided_ai_closing_started, request_context)

func _is_duplicate_guided_ai_reply(reply: String) -> bool:
	var normalized := _normalize_guided_ai_reply(reply)
	if normalized.is_empty():
		return false
	if _guided_ai_used_reply_signatures.has(normalized.md5_text()):
		return true
	if normalized.length() < 12:
		return false
	for used_reply in _guided_ai_used_reply_texts:
		if used_reply.length() >= 12 and (
			_guided_ai_reply_overlap(normalized, used_reply) >= 0.5
			or _guided_ai_reply_has_duplicate_segment(reply, used_reply)
		):
			return true
	return false

func _guided_ai_reply_has_duplicate_segment(reply: String, normalized_used_reply: String) -> bool:
	var raw_segments := reply.replace("[split]", "[SPLIT]").split("[SPLIT]", false)
	for raw_segment in raw_segments:
		var normalized_segment := _normalize_guided_ai_reply(str(raw_segment))
		if normalized_segment.length() < 16:
			continue
		if normalized_used_reply.contains(normalized_segment):
			return true
		if _guided_ai_reply_overlap(normalized_segment, normalized_used_reply) >= 0.72:
			return true
	return false

func _register_guided_ai_reply(reply: String) -> bool:
	var normalized := _normalize_guided_ai_reply(reply)
	if normalized.is_empty() or _is_duplicate_guided_ai_reply(normalized):
		return false
	_guided_ai_used_reply_signatures.append(normalized.md5_text())
	_guided_ai_used_reply_texts.append(normalized)
	return true

func _normalize_guided_ai_reply(reply: String) -> String:
	var normalized := reply.strip_edges().to_lower().replace("[split]", " ")
	var voice_tag_regex := RegEx.new()
	if voice_tag_regex.compile("(?i)(?:<|《|\\[|【)\\s*(voice|语音指令)\\s*[:：][^>》\\]】]*(?:>|》|\\]|】)") == OK:
		normalized = voice_tag_regex.sub(normalized, "", true)
	normalized = ChatSplitHelper.strip_parentheses(normalized)
	for token in [" ", "\t", "\r", "\n", "，", ",", "。", ".", "！", "!", "？", "?", "；", ";", "：", ":", "…", "~", "～"]:
		normalized = normalized.replace(token, "")
	return normalized

func _guided_ai_reply_overlap(left: String, right: String) -> float:
	if left.length() < 2 or right.length() < 2:
		return 0.0
	var left_pairs: Dictionary = {}
	var right_pairs: Dictionary = {}
	for index in range(left.length() - 1):
		left_pairs[left.substr(index, 2)] = true
	for index in range(right.length() - 1):
		right_pairs[right.substr(index, 2)] = true
	var shared_count := 0
	for pair in left_pairs:
		if right_pairs.has(pair):
			shared_count += 1
	return float(shared_count) / float(mini(left_pairs.size(), right_pairs.size()))

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
		var relationship_feedback: Dictionary = {}
		var personality_feedback: Dictionary = {}
		
		for m in matches:
			var tag = m.get_string(1).to_lower()
			var val = m.get_string(2).strip_edges()
			var f_val = val.to_float()
			
			if tag == "intimacy" or tag.begins_with("亲密"):
				relationship_feedback["intimacy"] = float(relationship_feedback.get("intimacy", 0.0)) + f_val
			elif tag == "trust" or tag.begins_with("信任"):
				relationship_feedback["trust"] = float(relationship_feedback.get("trust", 0.0)) + f_val
			elif tag in ["openness", "conscientiousness", "extraversion", "agreeableness", "neuroticism"]:
				if f_val != 0.0:
					has_changes = true
					personality_feedback[tag] = float(personality_feedback.get(tag, 0.0)) + f_val
					_accumulated_stats[tag] += f_val
		if not relationship_feedback.is_empty():
			var sanitized_relationships = GameDataManager.personality_system.sanitize_llm_relationship_deltas(relationship_feedback)
			var intimacy_delta = float(sanitized_relationships.get("intimacy", 0.0))
			var trust_delta = float(sanitized_relationships.get("trust", 0.0))
			if abs(intimacy_delta) > 0.001:
				GameDataManager.profile.update_intimacy(intimacy_delta)
				has_changes = true
				_accumulated_stats["intimacy"] += intimacy_delta
			if abs(trust_delta) > 0.001:
				GameDataManager.profile.update_trust(trust_delta)
				has_changes = true
				_accumulated_stats["trust"] += trust_delta
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

func _on_memory_error(error_msg: String) -> void:
	print("Memory Agent Failed: ", error_msg)

var pending_options_data = []
var _rendered_quick_options: Array = []
var _story_choice_options: Array = []
var _story_choice_active: bool = false
var _story_archive_id: String = ""
var is_text_playback_finished = true

func _on_script_choice_requested(options: Array) -> void:
	_story_choice_options = QuickOptionListHelper.normalize_dialogue_choice_options(options)
	if _story_choice_options.is_empty():
		script_engine.resume()
		return
	_story_choice_active = true
	if input_layer:
		input_layer.hide()
	if quick_option_layer:
		quick_option_layer.show()
	if quick_options_container and quick_options_container.get_parent():
		quick_options_container.get_parent().show()
	QuickOptionListHelper.populate_option_items_with_index(
		quick_options_container,
		_story_choice_options,
		_on_story_choice_selected
	)
	if _embedded_session_active:
		embedded_story_choice_ready.emit(_embedded_session_request.duplicate(true))

func _on_story_choice_selected(_text: String, index: int = -1) -> void:
	if not _story_choice_active or index < 0 or index >= _story_choice_options.size():
		return
	_story_choice_active = false
	var option_data := _story_choice_options[index] as Dictionary
	if _embedded_session_active:
		embedded_story_choice_selected.emit(str(option_data.get("text", _text)), _embedded_session_request.duplicate(true))
	var effects: Dictionary = option_data.get("effects", {})
	var intimacy_delta := clampf(float(effects.get("intimacy", 0.0)), 0.0, 10.0)
	var trust_delta := clampf(float(effects.get("trust", 0.0)), 0.0, 10.0)
	if intimacy_delta > 0.0:
		GameDataManager.profile.update_intimacy(intimacy_delta)
		ToastManager.show_stat_toast("intimacy", "亲密 +%.1f" % intimacy_delta)
	if trust_delta > 0.0:
		GameDataManager.profile.update_trust(trust_delta)
		ToastManager.show_stat_toast("trust", "信任 +%.1f" % trust_delta)
	GameDataManager.profile.save_profile()
	var response_text := str(option_data.get("response", option_data.get("text", ""))).strip_edges()
	QuickOptionListHelper.clear_container(quick_options_container)
	if quick_option_layer:
		quick_option_layer.hide()
	if quick_options_container and quick_options_container.get_parent():
		quick_options_container.get_parent().hide()
	_story_choice_options.clear()
	if response_text != "":
		await _show_message_async(response_text, "我", true)
	var target_chapter := str(option_data.get("target_chapter", "")).strip_edges()
	if target_chapter.is_empty():
		script_engine.resume()
	else:
		script_engine.is_waiting_for_resume = false
		script_engine.jump_to_chapter(target_chapter)
		script_engine.call("_process_next_event")

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
				pending_options_data = _filter_guided_ai_options(data["options"])
				_try_show_options()
				return
				
		print("Warning: Options Agent did not return valid JSON.")

func _filter_guided_ai_options(options: Array) -> Array:
	if not _guided_ai_chat_active:
		return options
	var filtered: Array = []
	var seen_texts: Array[String] = []
	for option_value in options:
		var normalized_items := QuickOptionListHelper.normalize_dialogue_choice_options([option_value])
		if normalized_items.is_empty():
			continue
		var option_text := str((normalized_items[0] as Dictionary).get("text", "")).strip_edges()
		if option_text.is_empty() or seen_texts.has(option_text) or _guided_ai_used_option_texts.has(option_text):
			continue
		seen_texts.append(option_text)
		filtered.append(option_value)
	return filtered

func _build_guided_ai_fallback_options() -> Array:
	var configured_value: Variant = _guided_ai_policy.get("fallback_options", [])
	var configured: Array = configured_value if configured_value is Array else []
	var filtered := _filter_guided_ai_options(configured)
	if filtered.size() < 2:
		for emergency_option in GUIDED_AI_EMERGENCY_OPTIONS:
			var emergency_filtered := _filter_guided_ai_options([emergency_option])
			if emergency_filtered.is_empty():
				continue
			filtered.append(emergency_filtered[0])
			if filtered.size() >= 2:
				break
	return filtered.slice(0, mini(2, filtered.size()))

func _try_show_options() -> void:
	# 只有当文本演出完全结束，且已经获取到了选项数据时，才将选项渲染到UI
	if is_text_playback_finished and pending_options_data.size() > 0:
		_populate_quick_options(pending_options_data)
		pending_options_data.clear()

func _on_options_error(error_msg: String) -> void:
	print("Options Agent Failed: ", error_msg)

func _populate_quick_options(options: Array) -> void:
	_rendered_quick_options = QuickOptionListHelper.normalize_dialogue_choice_options(options)
	if _uses_ai_player_option_layer() and is_instance_valid(ai_player_options_container):
		if quick_option_layer:
			quick_option_layer.hide()
		if quick_options_container and quick_options_container.get_parent():
			quick_options_container.get_parent().hide()
		QuickOptionListHelper.clear_container(ai_player_options_container)
		_rendered_quick_options = _rendered_quick_options.slice(0, mini(2, _rendered_quick_options.size()))
		QuickOptionListHelper.populate_ai_reply_items_with_index(
			ai_player_options_container,
			_rendered_quick_options,
			_on_quick_option_selected
		)
		if dialogue_panel and dialogue_panel.has_method("show_ai_player_options"):
			dialogue_panel.show_ai_player_options()
		var host := get_parent()
		if _guided_ai_chat_active and is_instance_valid(host) and host.has_method("_refresh_guide_overlay_if_needed"):
			host.call_deferred("_refresh_guide_overlay_if_needed")
		if _is_embedded_daily_chat() and free_chat_current_round == 0:
			if is_instance_valid(host) and host.has_method("_report_guide_action"):
				host.call("_report_guide_action", "daily_chat_first_options_ready")
		return
	if quick_option_layer:
		quick_option_layer.show()
	if quick_options_container and quick_options_container.get_parent():
		quick_options_container.get_parent().show()
	QuickOptionListHelper.populate_option_items_with_index(
		quick_options_container,
		_rendered_quick_options,
		_on_quick_option_selected
	)

func _on_quick_option_selected(text: String, index: int = -1) -> void:
	if _uses_ai_player_option_layer():
		if dialogue_panel and dialogue_panel.has_method("set_ai_player_option_status"):
			dialogue_panel.set_ai_player_option_status("Luna正在思考中")
	if _guided_ai_chat_active:
		var normalized_text := text.strip_edges()
		if normalized_text != "" and not _guided_ai_used_option_texts.has(normalized_text):
			_guided_ai_used_option_texts.append(normalized_text)
	if index >= 0 and index < _rendered_quick_options.size():
		var option_data := _rendered_quick_options[index] as Dictionary
		var kind := str(option_data.get("kind", "")).strip_edges()
		if kind == "trust":
			GameDataManager.profile.update_intimacy(2)
			GameDataManager.profile.update_trust(6)
		else:
			GameDataManager.profile.update_intimacy(6)
			GameDataManager.profile.update_trust(2)
		
	if input_field:
		input_field.text = text
	_on_send_pressed()

func _on_chat_error(error_msg: String) -> void:
	_embedded_daily_turn_pending = false
	_set_dialogue_input_ready()
	ToastManager.show_system_toast(error_msg, Color.RED)
	if _guided_ai_chat_active:
		await _finish_guided_ai_chat_with_fallback()

func _finish_guided_ai_chat_with_fallback() -> void:
	if not _guided_ai_chat_active:
		return
	_guided_ai_closing_started = true
	_guided_ai_close_after_reply = false
	_set_chat_closing_input_state()
	var fallback_text := str(_guided_ai_policy.get("fallback_closing_text", "（轻轻点头）那今天就先聊到这里吧。")).strip_edges()
	var fallback_display_text := ChatSplitHelperScript.format_actions(fallback_text)
	await _show_message_async(fallback_display_text, GameDataManager.profile.char_name, false, "", "", "", true)
	_finish_guided_ai_chat("incomplete")

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
	if _guided_ai_chat_active and _guided_ai_reply_available_at_ms > 0:
		print("[GuidedAITrace] stage=reply_playback_started bubbles=%d elapsed_from_send_ms=%d" % [
			lines.size(),
			Time.get_ticks_msec() - _guided_ai_turn_started_at_ms
		])
	if _guided_ai_chat_active:
		var combined_reply_parts: Array[String] = []
		for reply_line in lines:
			combined_reply_parts.append(str(reply_line.get("speech", "")) if reply_line is Dictionary else str(reply_line))
		_register_guided_ai_reply(" ".join(combined_reply_parts))
	for line in lines:
		var mood_line := str(line.get("speech", "")) if line is Dictionary else str(line)
		if GameDataManager.config.ai_mode_enabled and not _guided_ai_chat_active:
			_async_analyze_and_update_mood(mood_line)
		if line is Dictionary:
			await _process_realized_story_segment(line, char_name)
		else:
			await _process_single_message_line_async(str(line), char_name)
		
	GameDataManager.profile.save_profile()
	_update_ui()
	
	if is_inside_tree():
		await get_tree().create_timer(1.0).timeout
		
	is_text_playback_finished = true
	var daily_close_reason := _settle_embedded_daily_turn()
	if _guided_ai_chat_active:
		_guided_ai_reply_playback_active = false
	if _guided_ai_chat_active and _guided_ai_reply_available_at_ms > 0:
		print("[GuidedAITrace] stage=reply_playback_completed display_ms=%d total_turn_ms=%d" % [
			Time.get_ticks_msec() - _guided_ai_reply_available_at_ms,
			Time.get_ticks_msec() - _guided_ai_turn_started_at_ms
		])
	if _guided_ai_chat_active and bool(_guided_ai_policy.get("allow_early_completion", false)) and _are_guided_ai_required_beats_covered():
		_guided_ai_close_after_reply = true
	
	if _waiting_for_chat_exit:
		# AI 聊天结束，直接抛出事件让外部来处理后续（比如外部加上黑屏动画后再销毁）
		_waiting_for_chat_exit = false
		if _guided_ai_chat_active:
			_finish_guided_ai_chat("complete" if _are_guided_ai_required_beats_covered() else "incomplete")
		elif _script_ai_chat_active:
			_finish_script_ai_chat()
		else:
			_emit_chat_closed()
		return
	elif _embedded_daily_close_queued:
		_request_embedded_daily_closing("manual")
	elif daily_close_reason != "":
		_request_embedded_daily_closing(daily_close_reason)
	elif _guided_ai_close_after_reply:
		_begin_guided_ai_closing()
	else:
		_try_show_options()
		_set_dialogue_input_ready()

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
	var voice_regex = RegEx.new()
	voice_regex.compile("(?i)(?:<|\\<|《|\\[|【)\\s*(voice|语音指令)\\s*[:：]\\s*([^>\\>》\\]】]+)\\s*(?:>|\\>|》|\\]|】)")
	
	var clean_text = raw_line
	var matches = regex.search_all(raw_line)
	var tts_expression: String = ""
	for m in matches:
		if tts_expression.is_empty():
			tts_expression = m.get_string(2).strip_edges()
		clean_text = clean_text.replace(m.get_string(0), "")
	var voice_instruction: String = ""
	var voice_match = voice_regex.search(raw_line)
	if voice_match:
		voice_instruction = voice_match.get_string(2).strip_edges()
		clean_text = clean_text.replace(voice_match.get_string(0), "")
			
	var any_tag_regex = RegEx.new()
	any_tag_regex.compile("(?i)(?:<|\\<|《|\\[|【)[^>\\>》\\]】]*?[:：][^>\\>》\\]】]*?(?:>|\\>|》|\\]|】)")
	if any_tag_regex.is_valid():
		clean_text = any_tag_regex.sub(clean_text, "", true)
		
	clean_text = clean_text.strip_edges()
	
	var tts_text = ChatSplitHelper.strip_parentheses(clean_text)
	var display_text = ChatSplitHelperScript.format_leading_action(clean_text)
	
	await _show_message_async(display_text, char_name, false, tts_text, tts_expression, voice_instruction)

func _process_realized_story_segment(segment: Dictionary, char_name: String) -> void:
	var speech := str(segment.get("speech", "")).strip_edges()
	var action: Variant = segment.get("action")
	var action_description := str(action.get("description", "")).strip_edges() if action is Dictionary else ""
	var display_text := speech
	if not action_description.is_empty() and action_description != "本段未提供可见动作。":
		display_text = "[color=green]（%s）[/color]%s" % [action_description, speech]
	var response_meta := {
		"reply_pipeline": str(segment.get("reply_pipeline", "realize_turn_v6")),
		"ai_request_id": str(segment.get("ai_request_id", "")),
		"memory_trace_id": str(segment.get("memory_trace_id", "")),
		"response_segment_index": int(segment.get("response_segment_index", 0)),
		"response_adopted": true
	}
	await _show_message_async(
		display_text,
		char_name,
		false,
		speech,
		"",
		str(segment.get("delivery_instruction", "")).strip_edges(),
		false,
		response_meta
	)
	if GameDataManager.memory_retrieval_trace_service:
		GameDataManager.memory_retrieval_trace_service.mark_response_adopted(
			str(segment.get("memory_trace_id", "")),
			speech,
			int(segment.get("response_segment_index", 0))
		)

func _show_message(text: String, speaker_name: String = "", is_restore: bool = false, tts_text: String = "") -> void:
	_show_message_async(text, speaker_name, is_restore, tts_text)

func _show_message_async(text: String, speaker_name: String = "", is_restore: bool = false, tts_text: String = "", tts_expression: String = "", voice_instruction: String = "", auto_advance: bool = false, response_meta: Dictionary = {}) -> void:
	_line_display_generation += 1
	var line_generation := _line_display_generation
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
	dialogue_text.visible_characters = 0
	dialogue_text.visible_ratio = 0.0
	_line_text_complete = false
	_line_advance_requested = false
	if dialogue_panel and dialogue_panel.has_method("set_continue_indicator_visible"):
		dialogue_panel.set_continue_indicator_visible(false)
	
	# 简单的打字机效果
	if _typewriter_tween:
		_typewriter_tween.kill()
	_typewriter_tween = create_tween()
	var duration = max(0.5, text.length() * 0.05) # 每个字符 0.05 秒，至少0.5秒
	_typewriter_tween.tween_property(dialogue_text, "visible_ratio", 1.0, duration)
	# We will handle visible_characters = -1 after tween finishes or gets killed
	
	var cache_key = ""
	var is_tts_started = false
	_active_line_tts_text = ""
	
	# 触发TTS语音合成 (仅对 角色 发声)，如果是恢复记录则不发声
	# 在固定剧情模式下，判断 speaker_name 是不是玩家或旁白，都不是的话说明是配音角色，也可以发声
	var is_player_or_narrator = (speaker_name == "我" or speaker_name == "旁白" or speaker_name == " ")
	var message_character_id := str(GameDataManager.config.current_character_id).strip_edges().to_lower()
	if _intro_playing and not _current_story_speaker_id.is_empty():
		message_character_id = _current_story_speaker_id.strip_edges().to_lower()
	
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
			_active_line_tts_text = text_to_speak.strip_edges()
			
			# 如果是固定剧情的配音，优先尝试用 speaker_name 作为角色 ID 查找音色
			# 否则使用当前全局角色的音色
			var options = {}
			if GameDataManager.config.tts_character_speakers.has(message_character_id):
				options["speaker"] = GameDataManager.config.tts_character_speakers[message_character_id]
			options["character_id"] = message_character_id
			options.merge(TTSManager.build_tts_2_instruction_options(voice_instruction, tts_expression), true)
				
			cache_key = TTSManager.get_cache_key(text_to_speak, options)
			TTSManager.synthesize(text_to_speak, options)
		
	# 保存记录到历史管理器 (只有在非恢复模式时保存)
	if not is_restore:
		var history_meta := {"subtype": conversation_subtype}
		history_meta.merge(response_meta, true)
		if speaker_name != "玩家" and speaker_name != "我" and response_meta.is_empty():
			history_meta.merge(deepseek_client.mark_chat_response_adopted(text), true)
		if not is_player_or_narrator and not message_character_id.is_empty():
			history_meta["character_id"] = message_character_id
		GameDataManager.history.add_message(speaker_name, text, cache_key, "story_chat", history_meta)
	elif _intro_playing and text != "":
		# 因为 _intro_playing 调用时是 is_restore=true 专门为了避开 normal 的保存
		var fixed_story_meta := {"subtype": "fixed_story"}
		if not is_player_or_narrator and not message_character_id.is_empty():
			fixed_story_meta["character_id"] = message_character_id
		GameDataManager.history.add_message(speaker_name, text, cache_key, "fixed_story", fixed_story_meta)

	# 等待打字机效果完成
	if not is_inside_tree():
		return
	var scene_tree := get_tree()
	if scene_tree == null:
		return
	while _typewriter_tween and _typewriter_tween.is_valid() and _typewriter_tween.is_running():
		if not is_instance_valid(scene_tree):
			return
		await scene_tree.process_frame
		if line_generation != _line_display_generation:
			return
			
	if not is_inside_tree() or line_generation != _line_display_generation:
		return
		
	# If we killed the tween, make sure the text is fully shown
	dialogue_text.visible_ratio = 1.0
	dialogue_text.visible_characters = -1
	_line_text_complete = true
	if not auto_advance and not _line_advance_requested and dialogue_panel and dialogue_panel.has_method("set_continue_indicator_visible"):
		dialogue_panel.set_continue_indicator_visible(true)
	
	var close_auto_advance := _is_embedded_daily_chat() and (_embedded_daily_close_queued or _waiting_for_chat_exit)
	if auto_advance or close_auto_advance:
		_line_advance_requested = true
		_cancel_active_line_audio()
	elif _line_advance_requested:
		_cancel_active_line_audio()
	elif _intro_playing:
		_intro_waiting_for_click = true
	else:
		_waiting_for_chat_click = true
	
	# Wait for TTS if playing
	if is_tts_started and is_inside_tree() and not _line_advance_requested:
		var wait_count = 0
		while not audio_player.playing and wait_count < 10:
			if line_generation != _line_display_generation:
				return
			if (_intro_playing and not _intro_waiting_for_click) or (not _intro_playing and not _waiting_for_chat_click):
				break
			if not is_instance_valid(scene_tree):
				return
			await scene_tree.create_timer(0.05).timeout
			wait_count += 1
			
		wait_count = 0
		var max_wait_count = 1200
		while audio_player.playing and is_inside_tree() and wait_count < max_wait_count:
			if line_generation != _line_display_generation:
				return
			if (_intro_playing and not _intro_waiting_for_click) or (not _intro_playing and not _waiting_for_chat_click):
				_cancel_active_line_audio()
				break
			if not is_instance_valid(scene_tree):
				return
			await scene_tree.create_timer(0.05).timeout
			wait_count += 1
			
	if _line_advance_requested:
		pass
	elif _intro_playing:
		if is_inside_tree() and _intro_waiting_for_click:
			await _intro_click_proceed
	else:
		if is_inside_tree() and _waiting_for_chat_click:
			await _chat_click_proceed
	if line_generation != _line_display_generation:
		return
	if dialogue_panel and dialogue_panel.has_method("set_continue_indicator_visible"):
		dialogue_panel.set_continue_indicator_visible(false)
	_active_line_tts_text = ""

func _on_tts_success(audio_stream: AudioStream, text: String) -> void:
	if audio_player and text.strip_edges() == _active_line_tts_text:
		audio_player.stream = audio_stream
		audio_player.play()

func _on_tts_failed(error_msg: String, _text: String) -> void:
	print("TTS 失败: ", error_msg)
