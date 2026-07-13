extends Window

signal reply_completed(text: String)

const WINDOW_SIZE := Vector2i(720, 72)
const TASKBAR_MARGIN := 22
const HISTORY_LIMIT := 10

@onready var input: LineEdit = $Panel/Margin/InputRow/Input
@onready var send_button: Button = $Panel/Margin/InputRow/SendButton
@onready var status_label: Label = $Panel/Margin/InputRow/StatusLabel
@onready var deepseek_client: DeepSeekClient = $DeepSeekClient

var _screen_index := 0
var _request_in_flight := false
var _response_buffer := ""

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
	close_requested.connect(hide)
	deepseek_client.chat_stream_started.connect(_on_chat_started)
	deepseek_client.chat_stream_delta.connect(_on_chat_delta)
	deepseek_client.chat_request_completed.connect(_on_chat_completed)
	deepseek_client.chat_request_failed.connect(_on_chat_failed)

func toggle_on_screen(screen_index: int) -> void:
	_screen_index = screen_index
	if visible:
		hide()
		return
	_reposition()
	show()
	DisplayServer.window_set_mouse_passthrough(PackedVector2Array(), get_window_id())
	input.grab_focus()

func close_chat() -> void:
	hide()

func set_suspended(suspended: bool) -> void:
	input.editable = not suspended and not _request_in_flight
	send_button.disabled = suspended or _request_in_flight
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
	status_label.text = "Luna 正在回复..."
	_append_history("玩家", text)
	deepseek_client.start_chat_stream_with_messages(_build_messages())

func _build_messages() -> Array:
	var prompt: String = GameDataManager.prompt_manager.build_system_prompt(
		GameDataManager.profile,
		"desktop_pet",
		"",
		[],
		GameDataManager.desktop_pet_memory_manager
	)
	var messages: Array = [{"role": "system", "content": prompt}]
	var history: Array = GameDataManager.history.get_messages_by_type("desktop_pet")
	var start_index := maxi(0, history.size() - HISTORY_LIMIT)
	for index in range(start_index, history.size()):
		var record: Dictionary = history[index]
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
	_finish_request()
	reply_completed.emit(reply)

func _on_chat_failed(error_message: String) -> void:
	_finish_request()
	status_label.text = "发送失败，请稍后重试"
	push_warning("桌面壁纸聊天失败: %s" % error_message)

func _finish_request() -> void:
	_request_in_flight = false
	input.editable = true
	send_button.disabled = false
	status_label.text = ""
