extends Control

const ChatSplitHelperScript = preload("res://scripts/utils/chat_split_helper.gd")

@onready var dialogue_layer = $DialogueLayer
@onready var toolbar_container = $ToolBarContainer if has_node("ToolBarContainer") else null
@onready var toolbar_margin = $ToolBarContainer/ToolBarMargin if has_node("ToolBarContainer/ToolBarMargin") else null
@onready var name_label = $DialogueLayer/VBox/NameLabel if has_node("DialogueLayer/VBox/NameLabel") else null
@onready var name_divider = $DialogueLayer/VBox/NameDivider if has_node("DialogueLayer/VBox/NameDivider") else null
@onready var rich_text_label = $DialogueLayer/VBox/RichTextLabel if has_node("DialogueLayer/VBox/RichTextLabel") else null
@onready var continue_indicator = $DialogueLayer/ContinueIndicator if has_node("DialogueLayer/ContinueIndicator") else null
@onready var quick_option_layer = $QuickOptionLayer
@onready var ai_player_option_layer = $AiPlayerOptionLayer if has_node("AiPlayerOptionLayer") else null
@onready var ai_player_option_status_label = $AiPlayerOptionLayer/Margin/Content/StatusLabel if has_node("AiPlayerOptionLayer/Margin/Content/StatusLabel") else null
@onready var ai_player_options_container = $AiPlayerOptionLayer/Margin/Content/OptionsGrid if has_node("AiPlayerOptionLayer/Margin/Content/OptionsGrid") else null
@onready var input_layer = $InputLayer
@onready var history_button = $ToolBarContainer/ToolBarMargin/HBox/HistoryButton if has_node("ToolBarContainer/ToolBarMargin/HBox/HistoryButton") else null
@onready var end_chat_button = $InputLayer/HBoxContainer/EndChatButton if has_node("InputLayer/HBoxContainer/EndChatButton") else null

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
var _continue_indicator_tween: Tween = null
var _continue_indicator_base_position := Vector2.ZERO
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
var _pending_tts_text: String = ""
var _input_waiting: bool = false
var _dialogue_default_offset_top: float = 0.0
var _dialogue_default_offset_bottom: float = 0.0
var _name_divider_has_speaker: bool = true
var _animated_ai_status_base: String = ""
var _animated_ai_status_elapsed: float = 0.0
var _animated_ai_status_frame: int = 0

const MAX_CHARS = 200
const DEFAULT_INPUT_PLACEHOLDER := "输入你想说的话..."
const INPUT_READY_FONT_COLOR := Color(0.95, 0.95, 0.98, 1)
const INPUT_WAITING_FONT_COLOR := Color(0.62, 0.66, 0.72, 1)
const CHAR_COUNT_READY_COLOR := Color(0.62, 0.62, 0.68, 1)
const CHAR_COUNT_LIMIT_COLOR := Color(1, 0.3, 0.3, 1)
const CHAR_COUNT_WAITING_COLOR := Color(0.62, 0.7, 0.76, 1)
const TOOLBAR_RIGHT_MARGIN := 14.0
const TOOLBAR_TOP_MARGIN := 10.0
const FIXED_STORY_VERTICAL_OFFSET := 60.0

func _ready():
	if dialogue_layer:
		_dialogue_default_offset_top = dialogue_layer.offset_top
		_dialogue_default_offset_bottom = dialogue_layer.offset_bottom
	gui_input.connect(_on_gui_input)
	if dialogue_layer:
		dialogue_layer.gui_input.connect(_on_gui_input)
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_update_toolbar_layout)

	# 清空场景里用于编辑器预览的占位文案，避免事件触发前短暂闪出默认文本。
	if name_label:
		name_label.text = ""
	_sync_name_divider_visibility()
	if rich_text_label:
		rich_text_label.text = ""
	if continue_indicator:
		_continue_indicator_base_position = continue_indicator.position
		continue_indicator.hide()
	
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
	_update_toolbar_layout()

	# Input Field logic
	if input_field:
		input_field.text_changed.connect(_on_input_text_changed)
		input_field.gui_input.connect(_on_input_gui_input)
		input_field.placeholder_text = DEFAULT_INPUT_PLACEHOLDER
		_update_char_count()

func _process(delta: float) -> void:
	_sync_name_divider_visibility()
	_update_ai_status_animation(delta)

func _update_ai_status_animation(delta: float) -> void:
	if _animated_ai_status_base.is_empty() or not is_instance_valid(ai_player_option_status_label) or not ai_player_option_status_label.visible:
		return
	_animated_ai_status_elapsed += delta
	if _animated_ai_status_elapsed < 0.35:
		return
	_animated_ai_status_elapsed = fmod(_animated_ai_status_elapsed, 0.35)
	_animated_ai_status_frame = (_animated_ai_status_frame + 1) % 4
	ai_player_option_status_label.text = _animated_ai_status_base + ".".repeat(_animated_ai_status_frame)

func _sync_name_divider_visibility() -> void:
	if name_label == null or name_divider == null:
		return
	var has_speaker: bool = not str(name_label.text).strip_edges().is_empty()
	if has_speaker == _name_divider_has_speaker and name_divider.visible == has_speaker:
		return
	_name_divider_has_speaker = has_speaker
	name_divider.visible = has_speaker

func _exit_tree() -> void:
	if _continue_indicator_tween:
		_continue_indicator_tween.kill()
	_pending_tts_text = ""
	if TTSManager:
		if TTSManager.tts_success.is_connected(_on_tts_success):
			TTSManager.tts_success.disconnect(_on_tts_success)
		if TTSManager.tts_failed.is_connected(_on_tts_failed):
			TTSManager.tts_failed.disconnect(_on_tts_failed)
	if is_instance_valid(audio_player):
		audio_player.stop()

func set_continue_indicator_visible(should_show: bool) -> void:
	if continue_indicator == null:
		return
	if _continue_indicator_tween:
		_continue_indicator_tween.kill()
		_continue_indicator_tween = null
	continue_indicator.position = _continue_indicator_base_position
	if not should_show:
		continue_indicator.hide()
		continue_indicator.modulate = Color.WHITE
		return
	continue_indicator.show()
	continue_indicator.modulate = Color(1, 1, 1, 0.58)
	_continue_indicator_tween = create_tween().set_loops()
	_continue_indicator_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_continue_indicator_tween.tween_property(continue_indicator, "position:y", _continue_indicator_base_position.y + 6.0, 0.55)
	_continue_indicator_tween.parallel().tween_property(continue_indicator, "modulate:a", 1.0, 0.55)
	_continue_indicator_tween.tween_property(continue_indicator, "position:y", _continue_indicator_base_position.y, 0.55)
	_continue_indicator_tween.parallel().tween_property(continue_indicator, "modulate:a", 0.58, 0.55)

func set_input_waiting_state(_char_name: String = "角色") -> void:
	_input_waiting = true
	if input_layer:
		input_layer.show()
		input_layer.mouse_filter = Control.MOUSE_FILTER_PASS
	if input_field:
		input_field.release_focus()
		input_field.text = ""
		input_field.placeholder_text = DEFAULT_INPUT_PLACEHOLDER
		input_field.editable = false
		input_field.mouse_filter = Control.MOUSE_FILTER_IGNORE
		input_field.add_theme_color_override("font_color", INPUT_WAITING_FONT_COLOR)
	if char_count_label:
		char_count_label.text = "请等待"
		char_count_label.add_theme_color_override("font_color", CHAR_COUNT_WAITING_COLOR)
	if send_btn:
		send_btn.disabled = true
		send_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if voice_btn:
		voice_btn.disabled = true
		voice_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if end_chat_button:
		end_chat_button.disabled = true

func set_input_ready_state(clear_text: bool = true) -> void:
	_input_waiting = false
	if input_layer:
		input_layer.show()
		input_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	if input_field:
		input_field.placeholder_text = DEFAULT_INPUT_PLACEHOLDER
		if clear_text:
			input_field.text = ""
		input_field.editable = true
		input_field.mouse_filter = Control.MOUSE_FILTER_STOP
		input_field.add_theme_color_override("font_color", INPUT_READY_FONT_COLOR)
		input_field.grab_focus()
		input_field.set_caret_line(input_field.get_line_count() - 1)
		input_field.set_caret_column(input_field.get_line(input_field.get_line_count() - 1).length())
	if send_btn:
		send_btn.disabled = false
		send_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	if voice_btn:
		voice_btn.disabled = false
		voice_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	if end_chat_button:
		end_chat_button.disabled = false
	_update_char_count()

func set_story_mode(enabled: bool) -> void:
	is_story_mode = enabled
	_apply_dialogue_mode_layout()
	if is_story_mode:
		clear_ai_player_options(true)
	if toolbar_container:
		toolbar_container.show()
	if is_story_mode and end_chat_button:
		end_chat_button.hide()
	elif not is_story_mode and end_chat_button:
		end_chat_button.show()
	call_deferred("_update_toolbar_layout")

func _apply_dialogue_mode_layout() -> void:
	if dialogue_layer == null:
		return
	var vertical_offset := FIXED_STORY_VERTICAL_OFFSET if is_story_mode else 0.0
	dialogue_layer.offset_top = _dialogue_default_offset_top + vertical_offset
	dialogue_layer.offset_bottom = _dialogue_default_offset_bottom + vertical_offset

func set_ai_player_option_status(status_text: String) -> void:
	clear_ai_player_options(false)
	_animated_ai_status_base = status_text if status_text == "Luna正在思考中" or status_text == "Luna正在讲话" else ""
	_animated_ai_status_elapsed = 0.0
	_animated_ai_status_frame = 0
	if ai_player_option_status_label:
		ai_player_option_status_label.text = status_text
		ai_player_option_status_label.show()
	if ai_player_options_container:
		ai_player_options_container.hide()
	if ai_player_option_layer:
		ai_player_option_layer.show()

func show_ai_player_options() -> void:
	_animated_ai_status_base = ""
	if ai_player_option_status_label:
		ai_player_option_status_label.hide()
	if ai_player_options_container:
		ai_player_options_container.show()
	if ai_player_option_layer:
		ai_player_option_layer.show()

func clear_ai_player_options(hide_layer: bool = true) -> void:
	_animated_ai_status_base = ""
	if ai_player_options_container:
		for child in ai_player_options_container.get_children():
			child.queue_free()
		ai_player_options_container.hide()
	if ai_player_option_status_label:
		ai_player_option_status_label.hide()
	if hide_layer and ai_player_option_layer:
		ai_player_option_layer.hide()


func _update_toolbar_layout() -> void:
	if toolbar_container == null or toolbar_margin == null:
		return

	var desired_size: Vector2 = toolbar_margin.get_combined_minimum_size()
	if desired_size.x <= 0.0 or desired_size.y <= 0.0:
		return

	toolbar_container.offset_top = TOOLBAR_TOP_MARGIN
	toolbar_container.offset_bottom = TOOLBAR_TOP_MARGIN + desired_size.y
	toolbar_container.offset_right = -TOOLBAR_RIGHT_MARGIN
	toolbar_container.offset_left = toolbar_container.offset_right - desired_size.x

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
		if _input_waiting:
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
		if is_instance_valid(input_field) and not _input_waiting:
			input_field.editable = true
			input_field.add_theme_color_override("font_color", INPUT_READY_FONT_COLOR)
		if is_instance_valid(send_btn) and not _input_waiting:
			send_btn.disabled = false
		if is_instance_valid(voice_btn) and not _input_waiting:
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
	
	character_id = char_id.strip_edges().to_lower()
	if name_label: name_label.text = char_name
	current_text = text
	is_playing_single_line = true
	_auto_finish_single_line = auto_finish
	_keep_panel_visible_on_finish = keep_panel_visible
	_typewriter_finished = false
	_tts_pending = false
	_tts_playing = false
	_pending_tts_text = ""
	
	if toolbar_container:
		toolbar_container.show()
	
	if hide_input:
		if quick_option_layer: quick_option_layer.hide()
		if keep_panel_visible:
			set_input_waiting_state(char_name)
			if history_button:
				history_button.show()
			if end_chat_button:
				if is_story_mode:
					end_chat_button.hide()
				else:
					end_chat_button.show()
		elif input_layer:
			input_layer.hide()
		else:
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
	set_continue_indicator_visible(false)
	if current_text.is_empty():
		_finish_single_line()
		return
		
	var display_text = current_text
	
	display_text = ChatSplitHelperScript.format_leading_action(display_text)
		
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
			_pending_tts_text = ChatSplitHelperScript.strip_parentheses(tts_text)
			var normalized_character_id := character_id.strip_edges().to_lower()
			var options := {"character_id": normalized_character_id}
			if GameDataManager.config.tts_character_speakers.has(normalized_character_id):
				options["speaker"] = GameDataManager.config.tts_character_speakers[normalized_character_id]
			TTSManager.synthesize(tts_text, options)
		else:
			_tts_pending = false
			_tts_playing = false
			_pending_tts_text = ""
			_try_auto_finish_single_line()
	else:
		_tts_pending = false
		_tts_playing = false
		_pending_tts_text = ""
		_try_auto_finish_single_line()

func _on_tts_success(audio_stream: AudioStream, text: String):
	if not _tts_pending or text.strip_edges() != _pending_tts_text:
		return
	_pending_tts_text = ""
	if not is_inside_tree() or not is_instance_valid(audio_player) or not audio_player.is_inside_tree():
		_tts_pending = false
		_tts_playing = false
		return
	if audio_stream:
		_tts_pending = false
		_tts_playing = true
		audio_player.stream = audio_stream
		audio_player.play()
	else:
		_tts_pending = false
		_tts_playing = false
		_try_auto_finish_single_line()

func _on_tts_failed(_error_msg: String, text: String) -> void:
	if not _tts_pending or text.strip_edges() != _pending_tts_text:
		return
	_pending_tts_text = ""
	_tts_pending = false
	_tts_playing = false
	_try_auto_finish_single_line()

func _on_audio_finished() -> void:
	_tts_playing = false
	_try_auto_finish_single_line()

func _on_typewriter_finished() -> void:
	_typewriter_finished = true
	if not _auto_finish_single_line:
		set_continue_indicator_visible(true)
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
	if _typewriter_tween and _typewriter_tween.is_running():
		_typewriter_tween.kill()
		_typewriter_finished = true
		_auto_finish_single_line = false
		if rich_text_label:
			rich_text_label.visible_ratio = 1.0
		set_continue_indicator_visible(true)
	else:
		set_continue_indicator_visible(false)
		_finish_single_line()

func _finish_single_line():
	set_continue_indicator_visible(false)
	is_playing_single_line = false
	_auto_finish_single_line = false
	_typewriter_finished = false
	_tts_pending = false
	_tts_playing = false
	_pending_tts_text = ""
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
	set_continue_indicator_visible(false)
	if _typewriter_tween and _typewriter_tween.is_running():
		_typewriter_tween.kill()
	is_playing_single_line = false
	_auto_finish_single_line = false
	_keep_panel_visible_on_finish = false
	_typewriter_finished = false
	_tts_pending = false
	_tts_playing = false
	_pending_tts_text = ""
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
	if toolbar_container:
		toolbar_container.hide()
	if is_playing_single_line:
		_finish_single_line()
