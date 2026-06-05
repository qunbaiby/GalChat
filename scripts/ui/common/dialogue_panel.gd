extends Control

@onready var dialogue_layer = $DialogueLayer
@onready var name_label = $DialogueLayer/VBox/NameLabel if has_node("DialogueLayer/VBox/NameLabel") else null
@onready var rich_text_label = $DialogueLayer/VBox/RichTextLabel if has_node("DialogueLayer/VBox/RichTextLabel") else null
@onready var quick_option_layer = $QuickOptionLayer
@onready var input_layer = $InputLayer
@onready var history_button = $ToolBarContainer/ToolBarMargin/HBox/HistoryButton if has_node("ToolBarContainer/ToolBarMargin/HBox/HistoryButton") else null
@onready var end_chat_button = $ToolBarContainer/ToolBarMargin/HBox/EndChatButton if has_node("ToolBarContainer/ToolBarMargin/HBox/EndChatButton") else null

@onready var input_field = $InputLayer/HBoxContainer/InputField if has_node("InputLayer/HBoxContainer/InputField") else null
@onready var char_count_label = $InputLayer/HBoxContainer/InputField/CharCountLabel if has_node("InputLayer/HBoxContainer/InputField/CharCountLabel") else null
@onready var send_btn = $InputLayer/HBoxContainer/SendButton if has_node("InputLayer/HBoxContainer/SendButton") else null
@onready var voice_btn = $InputLayer/HBoxContainer/VoiceRecordButton if has_node("InputLayer/HBoxContainer/VoiceRecordButton") else null
@onready var quick_options_container = $QuickOptionLayer/ScrollContainer/QuickOptions if has_node("QuickOptionLayer/ScrollContainer/QuickOptions") else null

signal dialogue_finished
signal single_line_finished
signal panel_clicked(event: InputEvent)
signal message_sent(text: String)

var _typewriter_tween: Tween = null
var audio_player: AudioStreamPlayer = null
var current_text: String = ""
var is_playing_single_line: bool = false
var character_id: String = ""
var is_story_mode: bool = false
var _auto_finish_single_line: bool = false
var _keep_panel_visible_on_finish: bool = false
var _typewriter_finished: bool = false
var _tts_pending: bool = false
var _tts_playing: bool = false

const MAX_CHARS = 200
const DEFAULT_INPUT_PLACEHOLDER := "输入你想说的话..."
const INPUT_WAITING_SUFFIX := "正在讲话中，请等待…"
const INPUT_READY_FONT_COLOR := Color(0.95, 0.95, 0.98, 1)
const INPUT_WAITING_FONT_COLOR := Color(0.62, 0.66, 0.72, 1)
const CHAR_COUNT_READY_COLOR := Color(0.62, 0.62, 0.68, 1)
const CHAR_COUNT_LIMIT_COLOR := Color(1, 0.3, 0.3, 1)
const CHAR_COUNT_WAITING_COLOR := Color(0.62, 0.7, 0.76, 1)

func _ready():
	gui_input.connect(_on_gui_input)
	if dialogue_layer:
		dialogue_layer.gui_input.connect(_on_gui_input)
	mouse_filter = Control.MOUSE_FILTER_STOP

	# 清空场景里用于编辑器预览的占位文案，避免事件触发前短暂闪出默认文本。
	if name_label:
		name_label.text = ""
	if rich_text_label:
		rich_text_label.text = ""
	
	if end_chat_button:
		end_chat_button.pressed.connect(_on_end_chat_pressed)
	
	if GameDataManager.config.voice_enabled:
		TTSManager.tts_success.connect(_on_tts_success)
		TTSManager.tts_failed.connect(_on_tts_failed)
		audio_player = AudioStreamPlayer.new()
		audio_player.finished.connect(_on_audio_finished)
		add_child(audio_player)

	# Determine if in story mode
	var p = get_parent()
	var in_story = false
	while p:
		if p.name == "ChatScene" or "Story" in p.name:
			in_story = true
			break
		p = p.get_parent()
	set_story_mode(in_story)

	# Input Field logic
	if input_field:
		input_field.text_changed.connect(_on_input_text_changed)
		input_field.gui_input.connect(_on_input_gui_input)
		input_field.placeholder_text = DEFAULT_INPUT_PLACEHOLDER
		_update_char_count()

func _is_waiting_prompt_text(text: String) -> bool:
	return text.find(INPUT_WAITING_SUFFIX) != -1

func set_input_waiting_state(char_name: String = "角色") -> void:
	if input_layer:
		input_layer.show()
	var final_name := char_name.strip_edges()
	if final_name == "":
		final_name = "角色"
	if input_field:
		input_field.placeholder_text = DEFAULT_INPUT_PLACEHOLDER
		input_field.text = "【%s】%s" % [final_name, INPUT_WAITING_SUFFIX]
		input_field.editable = false
		input_field.set_caret_line(0)
		input_field.set_caret_column(0)
		input_field.add_theme_color_override("font_color", INPUT_WAITING_FONT_COLOR)
	if char_count_label:
		char_count_label.text = "请等待"
		char_count_label.add_theme_color_override("font_color", CHAR_COUNT_WAITING_COLOR)
	if send_btn:
		send_btn.disabled = true
	if voice_btn:
		voice_btn.disabled = true

func set_input_ready_state(clear_text: bool = true) -> void:
	if input_layer:
		input_layer.show()
	if input_field:
		input_field.placeholder_text = DEFAULT_INPUT_PLACEHOLDER
		if clear_text or _is_waiting_prompt_text(input_field.text):
			input_field.text = ""
		input_field.editable = true
		input_field.add_theme_color_override("font_color", INPUT_READY_FONT_COLOR)
	if send_btn:
		send_btn.disabled = false
	if voice_btn:
		voice_btn.disabled = false
	_update_char_count()

func set_story_mode(enabled: bool) -> void:
	is_story_mode = enabled
	if is_story_mode and end_chat_button:
		end_chat_button.hide()
	elif not is_story_mode and end_chat_button:
		end_chat_button.show()

func _on_input_text_changed():
	if not input_field: return
	
	var text = input_field.text
	
	# Check if Enter was pressed (indicated by a newline character)
	if "\n" in text:
		if Input.is_key_pressed(KEY_SHIFT) and is_story_mode:
			# Allow newline in story mode with Shift
			pass
		else:
			# Remove the newline
			input_field.text = text.replace("\n", "")
			input_field.set_caret_column(input_field.text.length())
			# Trigger send message
			_send_message()
			return
			
	# Max chars check
	text = input_field.text
	if text.length() > MAX_CHARS:
		input_field.text = text.substr(0, MAX_CHARS)
		input_field.set_caret_column(MAX_CHARS)
		_play_beep_sound()

	_update_char_count()

func _update_char_count():
	if not input_field: return
	if char_count_label:
		if _is_waiting_prompt_text(input_field.text):
			char_count_label.text = "请等待"
			char_count_label.add_theme_color_override("font_color", CHAR_COUNT_WAITING_COLOR)
			return
		char_count_label.text = "%d/%d" % [input_field.text.length(), MAX_CHARS]
		if input_field.text.length() >= MAX_CHARS:
			char_count_label.add_theme_color_override("font_color", CHAR_COUNT_LIMIT_COLOR)
		else:
			char_count_label.add_theme_color_override("font_color", CHAR_COUNT_READY_COLOR)

func _play_beep_sound():
	# Simple beep logic using AudioStreamPlayer with a generated sine wave or just print if no asset
	print("[DialoguePanel] BEEP! Max characters reached.")

func _on_input_gui_input(_event: InputEvent):
	pass

func submit_input_text() -> void:
	_send_message(false)

func _send_message(emit_button_signal: bool = true):
	if not input_field: return
	if not input_field.editable:
		return
	
	var text = input_field.text.strip_edges()
	if text == "":
		return
		
	# 先发送信号，让 main_scene 和 dialogue_manager 能读取到 text
	message_sent.emit(text)
	if emit_button_signal and send_btn:
		send_btn.pressed.emit()
	
	# 发送后再清空输入框和禁用按钮
	set_input_waiting_state(name_label.text if name_label else "")
	
	# Wait 0.5s to re-enable
	var t = get_tree().create_timer(0.5)
	t.timeout.connect(func():
		if is_instance_valid(input_field) and not _is_waiting_prompt_text(input_field.text):
			input_field.editable = true
			input_field.add_theme_color_override("font_color", INPUT_READY_FONT_COLOR)
		if is_instance_valid(send_btn) and not _is_waiting_prompt_text(input_field.text):
			send_btn.disabled = false
		if is_instance_valid(voice_btn) and not _is_waiting_prompt_text(input_field.text):
			voice_btn.disabled = false
	)

func play_single_line(char_id: String, char_name: String, text: String, hide_input: bool = true, auto_finish: bool = false, keep_panel_visible: bool = false):
	if text.strip_edges() == "":
		text = "（微笑着将单品递给了你，没有说话）"
	text = text.replace("\r", " ").replace("\n", " ").replace("\t", " ")
	var whitespace_regex = RegEx.new()
	whitespace_regex.compile("\\s+")
	text = whitespace_regex.sub(text, " ", true).strip_edges()
	
	if audio_player:
		audio_player.stop()
	
	character_id = char_id
	if name_label: name_label.text = char_name
	current_text = text
	is_playing_single_line = true
	_auto_finish_single_line = auto_finish
	_keep_panel_visible_on_finish = keep_panel_visible
	_typewriter_finished = false
	_tts_pending = false
	_tts_playing = false
	
	if hide_input:
		if quick_option_layer: quick_option_layer.hide()
		if keep_panel_visible:
			set_input_waiting_state(char_name)
		elif input_layer:
			input_layer.hide()
		if history_button: history_button.hide()
		# 修复需求：即使是 hide_input == true 的固定单句对话，如果处于故事模式，依然隐藏结束按钮
		if end_chat_button:
			if is_story_mode:
				end_chat_button.hide()
			else:
				end_chat_button.hide() # hide_input 状态下本身就不该显示，保持隐藏
	else:
		if quick_option_layer: quick_option_layer.show()
		set_input_ready_state()
		if history_button: history_button.show()
		# 修复需求：自由对话模式下，如果在故事模式中也隐藏结束按钮
		if end_chat_button:
			if is_story_mode:
				end_chat_button.hide()
			else:
				end_chat_button.show()
	
	show()
	if dialogue_layer: dialogue_layer.show()
	_start_typewriter()

func _start_typewriter():
	if current_text.is_empty():
		_finish_single_line()
		return
		
	var display_text = current_text
	
	# 强制清理：只保留最开头的一个动作描述，移除其余所有动作描述
	var extract_regex = RegEx.new()
	extract_regex.compile("（.*?）|\\(.*?\\)")
	var matches = extract_regex.search_all(display_text)
	if matches.size() > 0:
		var first_action = matches[0].get_string()
		var no_action_text = extract_regex.sub(display_text, "", true).strip_edges()
		display_text = first_action + " " + no_action_text
		current_text = display_text # Update current_text so TTS text also uses the cleaned version
		
	var color_regex_zh = RegEx.new()
	color_regex_zh.compile("（(.*?)）")
	display_text = color_regex_zh.sub(display_text, "[color=green]（$1）[/color]", true)
	var color_regex_en = RegEx.new()
	color_regex_en.compile("\\((.*?)\\)")
	display_text = color_regex_en.sub(display_text, "[color=green]($1)[/color]", true)
		
	# Center text per requirement
	display_text = "[center]" + display_text + "[/center]"
		
	if rich_text_label:
		rich_text_label.bbcode_enabled = true
		rich_text_label.text = display_text
		rich_text_label.visible_ratio = 0.0
		
		if _typewriter_tween:
			_typewriter_tween.kill()
		
		_typewriter_tween = create_tween()
		var dur = max(0.5, current_text.length() * 0.05)
		_typewriter_tween.tween_property(rich_text_label, "visible_ratio", 1.0, dur)
		_typewriter_tween.finished.connect(_on_typewriter_finished, CONNECT_ONE_SHOT)
	
	if GameDataManager.config.voice_enabled:
		var tts_text = current_text
		var action_regex = RegEx.new()
		action_regex.compile("（.*?）|\\(.*?\\)|\\*.*?\\*|\\[.*?\\]|~.*?~")
		tts_text = action_regex.sub(tts_text, "", true).strip_edges()
		tts_text = tts_text.replace("*", "")
		
		if tts_text != "":
			_tts_pending = true
			var options = {}
			if GameDataManager.config.character_voice_types.has(character_id):
				options["voice_type"] = GameDataManager.config.character_voice_types[character_id]
			TTSManager.synthesize(tts_text, options)
		else:
			_tts_pending = false
			_tts_playing = false
			_try_auto_finish_single_line()
	else:
		_tts_pending = false
		_tts_playing = false
		_try_auto_finish_single_line()

func _on_tts_success(audio_stream: AudioStream, _text: String):
	if audio_player and audio_stream:
		_tts_pending = false
		_tts_playing = true
		audio_player.stream = audio_stream
		audio_player.play()
	else:
		_tts_pending = false
		_tts_playing = false
		_try_auto_finish_single_line()

func _on_tts_failed(_error_msg: String, _text: String) -> void:
	_tts_pending = false
	_tts_playing = false
	_try_auto_finish_single_line()

func _on_audio_finished() -> void:
	_tts_playing = false
	_try_auto_finish_single_line()

func _on_typewriter_finished() -> void:
	_typewriter_finished = true
	_try_auto_finish_single_line()

func _try_auto_finish_single_line() -> void:
	if not _auto_finish_single_line:
		return
	if not _typewriter_finished:
		return
	if _tts_pending or _tts_playing:
		return
	_finish_single_line()

func _on_gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if is_playing_single_line:
			_advance_dialogue()
			get_viewport().set_input_as_handled()
		else:
			panel_clicked.emit(event)

func _advance_dialogue():
	if _auto_finish_single_line:
		if _typewriter_tween and _typewriter_tween.is_running():
			_typewriter_tween.kill()
			_typewriter_finished = true
			if rich_text_label:
				rich_text_label.visible_ratio = 1.0
		if audio_player:
			audio_player.stop()
		_tts_pending = false
		_tts_playing = false
		_finish_single_line()
		return
	if _typewriter_tween and _typewriter_tween.is_running():
		_typewriter_tween.kill()
		_typewriter_finished = true
		if rich_text_label:
			rich_text_label.visible_ratio = 1.0
	else:
		_finish_single_line()

func _finish_single_line():
	is_playing_single_line = false
	_auto_finish_single_line = false
	_typewriter_finished = false
	_tts_pending = false
	_tts_playing = false
	if audio_player:
		audio_player.stop()
	if _keep_panel_visible_on_finish:
		set_input_ready_state()
	if not _keep_panel_visible_on_finish:
		hide()
	single_line_finished.emit()
	if not _keep_panel_visible_on_finish:
		dialogue_finished.emit()
	_keep_panel_visible_on_finish = false

func cancel_single_line(hide_panel: bool = true) -> void:
	if _typewriter_tween and _typewriter_tween.is_running():
		_typewriter_tween.kill()
	is_playing_single_line = false
	_auto_finish_single_line = false
	_keep_panel_visible_on_finish = false
	_typewriter_finished = false
	_tts_pending = false
	_tts_playing = false
	if audio_player:
		audio_player.stop()
	if rich_text_label:
		rich_text_label.visible_ratio = 1.0
	if hide_panel:
		hide()

func _on_skip_pressed():
	if is_playing_single_line:
		_advance_dialogue()

func _on_end_chat_pressed():
	if is_playing_single_line:
		_finish_single_line()
