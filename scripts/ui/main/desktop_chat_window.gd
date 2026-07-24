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
var _response_buffer := ""
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
	close_requested.connect(hide)
	qwen_asr_client.transcribe_completed.connect(_on_asr_success)
	qwen_asr_client.transcribe_failed.connect(_on_asr_failed)
	deepseek_client.chat_stream_started.connect(_on_chat_started)
	deepseek_client.chat_stream_delta.connect(_on_chat_delta)
	deepseek_client.chat_request_completed.connect(_on_chat_completed)
	deepseek_client.chat_request_failed.connect(_on_chat_failed)
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
	var prompt_result: Dictionary = await _build_messages(text)
	deepseek_client.start_chat_stream_with_messages(prompt_result.get("messages", []), prompt_result.get("request_context", {}))

func _build_messages(player_message: String) -> Dictionary:
	var prompt_result: Dictionary = await GameDataManager.memory_retrieval_service.build_system_prompt_result(
		GameDataManager.profile,
		"desktop_pet",
		player_message,
		GameDataManager.desktop_pet_memory_manager,
		"desktop_pet"
	)
	var prompt := str(prompt_result.get("prompt", ""))
	var messages: Array = [{"role": "system", "content": prompt}]
	var history: Array = GameDataManager.history.get_messages_by_type("desktop_pet")
	var start_index := maxi(0, history.size() - HISTORY_LIMIT)
	for index in range(start_index, history.size()):
		var record: Dictionary = history[index]
		messages.append({
			"role": "assistant" if str(record.get("speaker", "")) == "char" else "user",
			"content": str(record.get("text", ""))
		})
	return {
		"messages": messages,
		"request_context": {
			"request_id": str(prompt_result.get("request_id", "")),
			"trace_id": str(prompt_result.get("trace_id", "")),
			"rendered_memory_ids": prompt_result.get("rendered_memory_ids", []).duplicate()
		}
	}

func _append_history(speaker: String, text: String) -> void:
	GameDataManager.history.add_message(
		speaker,
		text,
		"",
		"desktop_pet",
		{"module": "desktop_pet", "subtype": "desktop_wallpaper"}
	)

func _on_chat_started() -> void:
	_response_buffer = ""

func _on_chat_delta(delta_text: String) -> void:
	_response_buffer += delta_text

func _on_chat_completed(response: Dictionary) -> void:
	var reply := _response_buffer.strip_edges()
	if response.has("choices") and response.choices.size() > 0:
		reply = str(response.choices[0].message.content).strip_edges()
	if reply == "":
		reply = "我在听。"
	_append_history("char", reply)
	deepseek_client.mark_chat_response_adopted(reply)
	if GameDataManager.memory_observation_service:
		GameDataManager.memory_observation_service.observe_completed_turn("desktop_chat", _active_player_text, reply)
	_finish_request()
	reply_completed.emit(reply)

func _on_chat_failed(error_message: String) -> void:
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
