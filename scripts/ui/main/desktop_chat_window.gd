extends Window

signal reply_completed(text: String)

const WINDOW_SIZE := Vector2i(720, 72)
const TASKBAR_MARGIN := 22
const HISTORY_LIMIT := 10

@onready var input: LineEdit = $Panel/Margin/InputRow/Input
@onready var send_button: Button = $Panel/Margin/InputRow/SendButton
@onready var voice_record_button: Button = $Panel/Margin/InputRow/VoiceRecordButton
@onready var status_label: Label = $Panel/Margin/InputRow/StatusLabel
@onready var deepseek_client: DeepSeekClient = $DeepSeekClient
@onready var qwen_asr_client: QwenASRClient = $QwenASRClient
@onready var mic_capture: AudioStreamPlayer = $MicCapture

var _screen_index := 0
var _request_in_flight := false
var _is_recording := false
var _active_player_text := ""

func _ready() -> void:
	borderless = true
	transparent = true
	transparent_bg = true
	always_on_top = false
	transient = false
	exclusive = false
	unresizable = true
	size = WINDOW_SIZE
	input.text_submitted.connect(_submit_chat)
	send_button.pressed.connect(func() -> void: _submit_chat(input.text))
	voice_record_button.button_down.connect(_on_voice_record_down)
	voice_record_button.button_up.connect(_on_voice_record_up)
	close_requested.connect(close_chat)
	qwen_asr_client.transcribe_completed.connect(_on_asr_success)
	qwen_asr_client.transcribe_failed.connect(_on_asr_failed)
	deepseek_client.realize_turn_completed.connect(_on_realize_turn_completed)
	deepseek_client.realize_turn_failed.connect(_on_realize_turn_failed)
	_update_voice_button_state()

func toggle_on_screen(screen_index: int) -> void:
	_screen_index = screen_index
	if visible:
		hide()
		return
	_reposition()
	_update_voice_button_state()
	show()
	DisplayServer.window_set_mouse_passthrough(PackedVector2Array(), get_window_id())
	input.grab_focus()

func close_chat() -> void:
	if deepseek_client:
		deepseek_client.cancel_realize_turn_requests()
	_finish_request()
	hide()

func set_suspended(suspended: bool) -> void:
	input.editable = not suspended and not _request_in_flight
	send_button.disabled = suspended or _request_in_flight
	voice_record_button.disabled = suspended or _request_in_flight or not GameDataManager.config.qwen_asr_enabled
	if suspended:
		hide()

func _reposition() -> void:
	var screen_rect := DisplayServer.screen_get_usable_rect(_screen_index)
	size = WINDOW_SIZE
	position = Vector2i(
		screen_rect.position.x + (screen_rect.size.x - WINDOW_SIZE.x) / 2,
		screen_rect.end.y - WINDOW_SIZE.y - TASKBAR_MARGIN
	)

func _submit_chat(raw_text: String) -> void:
	var text := raw_text.strip_edges()
	if text == "" or _request_in_flight:
		return
	input.clear()
	_request_in_flight = true
	input.editable = false
	send_button.disabled = true
	voice_record_button.disabled = true
	status_label.text = "Luna 正在回复..."
	_active_player_text = text
	_append_history("玩家", text)
	deepseek_client.send_realize_turn_message(text, "desktop_pet", {
		"channel": "desktop_wallpaper_chat",
		"origin": "desktop_wallpaper",
		"recent_messages": _build_recent_messages(text)
	})

func _build_recent_messages(player_message: String) -> Array:
	var messages: Array = []
	var history: Array = GameDataManager.history.get_messages_by_type("desktop_pet")
	var start_index := maxi(0, history.size() - HISTORY_LIMIT)
	for index in range(start_index, history.size()):
		var record: Dictionary = history[index]
		if index == history.size() - 1 and str(record.get("speaker", "")) == "玩家" and str(record.get("text", "")) == player_message:
			continue
		messages.append({
			"role": "assistant" if str(record.get("speaker", "")) == "char" else "user",
			"content": str(record.get("text", ""))
		})
	return messages

func _append_history(speaker: String, text: String) -> void:
	GameDataManager.history.add_message(
		speaker,
		text,
		"",
		"desktop_pet",
		{"module": "desktop_pet", "subtype": "desktop_wallpaper"}
	)

func _on_realize_turn_completed(realized_turn: Dictionary, request_context: Dictionary) -> void:
	if str(request_context.get("channel", "")) != "desktop_wallpaper_chat":
		return
	var segments: Variant = realized_turn.get("segments")
	if not segments is Array or segments.is_empty():
		_on_realize_turn_failed("角色回复没有可展示内容。", request_context)
		return
	var speech_segments: Array[String] = []
	for index in range(segments.size()):
		var segment: Variant = segments[index]
		if not segment is Dictionary:
			continue
		var speech := str(segment.get("speech", "")).strip_edges()
		GameDataManager.history.add_message("char", speech, "", "desktop_pet", {
			"module": "desktop_pet",
			"subtype": "desktop_wallpaper",
			"delivery_instruction": str(segment.get("delivery_instruction", "")).strip_edges(),
			"reply_pipeline": str(request_context.get("reply_pipeline", "realize_turn_v6")),
			"ai_request_id": str(request_context.get("request_id", "")),
			"memory_trace_id": str(request_context.get("trace_id", "")),
			"response_segment_index": index,
			"response_adopted": true
		})
		if GameDataManager.memory_retrieval_trace_service:
			GameDataManager.memory_retrieval_trace_service.mark_response_adopted(str(request_context.get("trace_id", "")), speech, index)
		speech_segments.append(speech)
	var reply := "\n".join(speech_segments)
	if GameDataManager.memory_observation_service:
		GameDataManager.memory_observation_service.observe_completed_turn("desktop_chat", _active_player_text, reply)
	_finish_request()
	reply_completed.emit(reply)

func _on_realize_turn_failed(error_message: String, request_context: Dictionary) -> void:
	if str(request_context.get("channel", "")) != "desktop_wallpaper_chat":
		return
	_finish_request()
	status_label.text = "发送失败，请稍后重试"
	push_warning("桌面壁纸聊天失败: %s" % error_message)

func _finish_request() -> void:
	_active_player_text = ""
	_request_in_flight = false
	input.editable = true
	send_button.disabled = false
	_update_voice_button_state()
	status_label.text = ""

func _on_voice_record_down() -> void:
	if voice_record_button.disabled or _request_in_flight:
		return
	_is_recording = true
	voice_record_button.modulate = Color(0.9, 0.38, 0.38)
	status_label.text = "正在聆听..."
	mic_capture.play()
	qwen_asr_client.start_recording()

func _on_voice_record_up() -> void:
	if not _is_recording:
		return
	_is_recording = false
	voice_record_button.modulate = Color.WHITE
	status_label.text = "正在识别..."
	mic_capture.stop()
	qwen_asr_client.stop_recording()

func _on_asr_success(text: String) -> void:
	input.text = text.strip_edges()
	input.caret_column = input.text.length()
	status_label.text = ""
	input.grab_focus()

func _on_asr_failed(error_message: String) -> void:
	status_label.text = "识别失败"
	push_warning("桌面聊天语音识别失败: %s" % error_message)

func _update_voice_button_state() -> void:
	var asr_enabled := GameDataManager.config.qwen_asr_enabled
	voice_record_button.disabled = _request_in_flight or not asr_enabled
	voice_record_button.tooltip_text = "按住说话" if asr_enabled else "请先在设置中启用语音识别"
