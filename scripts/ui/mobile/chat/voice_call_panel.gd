extends Control

signal call_ended
signal message_sent(text) # 发送给 mobile chat

@onready var avatar_tex: TextureRect = $Panel/VBox/AvatarCenter/AvatarPanel/AvatarTex
@onready var name_label: Label = $Panel/VBox/NameLabel
@onready var status_label: Label = $Panel/VBox/StatusLabel
@onready var message_label: RichTextLabel = $Panel/VBox/MessageCenter/MessageLabel
@onready var hangup_btn: Button = $Panel/VBox/BottomBar/HangupBtn
@onready var record_btn: Button = $Panel/VBox/BottomBar/RecordBtn
@onready var audio_player: AudioStreamPlayer = $AudioStreamPlayer
@onready var asr: Node = $LocalWhisperASR

var current_char_id: String = ""
var char_profile: CharacterProfile = null
var doubao_tts = null

var is_character_speaking: bool = false
var is_recording: bool = false

var message_queue: Array = []
var is_processing_queue: bool = false
var is_fixed_mode: bool = false
var fixed_call_data: Array = []
var current_fixed_idx: int = 0

func _ready() -> void:
	hangup_btn.pressed.connect(_on_hangup_pressed)
	record_btn.button_down.connect(_on_record_down)
	record_btn.button_up.connect(_on_record_up)
	
	if asr:
		asr.transcribe_completed.connect(_on_asr_completed)
		asr.transcribe_failed.connect(_on_asr_failed)
		
	var tts_script = load("res://scripts/api/doubao_TTS_Service.gd")
		
	if tts_script:
		doubao_tts = tts_script.new()
		add_child(doubao_tts)
		
		# Load API keys from config
		if GameDataManager.config:
			doubao_tts.setup_auth(
				GameDataManager.config.doubao_app_id,
				GameDataManager.config.doubao_token,
				GameDataManager.config.doubao_cluster
			)
			
		doubao_tts.tts_success.connect(_on_tts_success)
		doubao_tts.tts_failed.connect(_on_tts_failed)

func setup(char_id: String, profile: CharacterProfile, is_incoming: bool = false, is_fixed: bool = false) -> void:
	current_char_id = char_id
	char_profile = profile
	is_fixed_mode = is_fixed
	
	name_label.text = profile.char_name
	status_label.text = "接通中..."
	message_label.text = "[center]...[/center]"
	
	if is_fixed_mode:
		hangup_btn.show()
		record_btn.show()
		hangup_btn.disabled = true
		record_btn.disabled = true
		set_process_input(true)
		
		if GameDataManager.has_meta("pending_fixed_call_data"):
			set_fixed_call_data(GameDataManager.get_meta("pending_fixed_call_data"))
			GameDataManager.remove_meta("pending_fixed_call_data")
	else:
		hangup_btn.show()
		record_btn.show()
		hangup_btn.disabled = false
		record_btn.disabled = false
		set_process_input(false)
		
	var avatar_path = profile.avatar
	if avatar_path != "" and ResourceLoader.exists(avatar_path):
		avatar_tex.texture = load(avatar_path)
	else:
		avatar_tex.texture = load("res://assets/images/characters/desktop_pet/Q_desktop.png")

func set_fixed_call_data(data: Array) -> void:
	fixed_call_data = data
	current_fixed_idx = 0
	_advance_fixed_call()

func _input(event: InputEvent) -> void:
	if is_fixed_mode and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# If the character is currently speaking/typing, we could skip it, or we just ignore input until they finish
		if is_character_speaking:
			return
		_advance_fixed_call()

func _advance_fixed_call() -> void:
	if current_fixed_idx < fixed_call_data.size():
		var text = fixed_call_data[current_fixed_idx]
		current_fixed_idx += 1
		add_character_message(text)
	else:
		# 结束固定通话
		call_ended.emit()

func set_loading_state() -> void:
	status_label.text = "对方正在连接..."
	record_btn.disabled = true

func _on_hangup_pressed() -> void:
	if audio_player.playing:
		audio_player.stop()
	message_queue.clear()
	call_ended.emit()

func _on_record_down() -> void:
	if is_character_speaking: return
	is_recording = true
	record_btn.text = "松开发送"
	record_btn.modulate = Color(0.8, 1.0, 0.8)
	status_label.text = "聆听中..."
	if asr:
		asr.start_recording()

func _on_record_up() -> void:
	if not is_recording: return
	is_recording = false
	record_btn.text = "处理中..."
	record_btn.disabled = true
	record_btn.modulate = Color(1.0, 1.0, 1.0)
	status_label.text = "转换中..."
	if asr:
		asr.stop_recording()

func _on_asr_completed(text: String) -> void:
	record_btn.text = "按住说话"
	status_label.text = "发送中..."
	text = text.strip_edges()
	
	if text == "":
		status_label.text = "通话中"
		record_btn.disabled = false
		return
		
	# 逐字显示玩家的话
	await _typewriter_effect("[color=#88ccff]" + text + "[/color]")
	
	# 延迟一下发给AI
	await get_tree().create_timer(0.5).timeout
	message_sent.emit(text)

func _on_asr_failed(err_msg: String) -> void:
	record_btn.text = "按住说话"
	record_btn.disabled = false
	status_label.text = "语音识别失败"
	await get_tree().create_timer(2.0).timeout
	status_label.text = "通话中"

# 当 AI 有回复时调用
func add_character_message(text: String) -> void:
	# 拆分 [SPLIT]
	var parts = text.split("[SPLIT]")
	for p in parts:
		var c = p.strip_edges()
		if c != "":
			message_queue.append(c)
			
	if not is_processing_queue:
		_process_next_message()

func _process_next_message() -> void:
	if message_queue.is_empty():
		is_processing_queue = false
		is_character_speaking = false
		if not is_fixed_mode:
			record_btn.disabled = false
		status_label.text = "通话中"
		return
		
	is_processing_queue = true
	is_character_speaking = true
	record_btn.disabled = true
	status_label.text = "对方正在讲话..."
	
	var chunk = message_queue.pop_front()
	var display_text = _extract_dialogue_text(chunk)
	var tts_text = display_text
	
	# 开始 TTS
	if GameDataManager.config.voice_enabled and _has_readable_text(tts_text):
		var v_type = "ICL_zh_female_bingruoshaonv_tob"
		if GameDataManager.config.character_voice_types.has(current_char_id):
			v_type = GameDataManager.config.character_voice_types[current_char_id]
			
		doubao_tts.synthesize(tts_text, {"voice_type": v_type})
		
		# 逐字显示和等待语音
		_typewriter_effect("[color=#ffffff]" + display_text + "[/color]")
		
		# 稍微增加一点启动等待时间，防止网络抖动导致的音频状态未更新
		var wait_net = 0
		while not audio_player.playing and wait_net < 100:
			await get_tree().create_timer(0.05).timeout
			wait_net += 1
			
		while audio_player.playing:
			await get_tree().process_frame
			
		await get_tree().create_timer(0.3).timeout
	else:
		# 无语音模式，仅打字机
		await _typewriter_effect("[color=#ffffff]" + display_text + "[/color]")
		await get_tree().create_timer(1.0).timeout
		
	_process_next_message()

func _typewriter_effect(bbcode_text: String) -> void:
	# 简单的打字机：因为有 BBCode，所以需要计算可见字符
	# 为了简单，我们可以用 Regex 剥离 tag 算长度，或者用 RichTextLabel 的 visible_characters
	message_label.text = "[center]" + bbcode_text + "[/center]"
	message_label.visible_characters = 0
	
	var total_chars = message_label.get_total_character_count()
	var delay = 0.05
	
	for i in range(total_chars):
		message_label.visible_characters = i + 1
		await get_tree().create_timer(delay).timeout
	
	message_label.visible_characters = -1

func _extract_dialogue_text(text: String) -> String:
	var regex = RegEx.new()
	regex.compile("\\([^)]+\\)|\\（[^）]+\\）")
	return regex.sub(text, "", true).strip_edges()

func _has_readable_text(text: String) -> bool:
	var regex = RegEx.new()
	regex.compile("[a-zA-Z0-9\u4e00-\u9fa5]")
	return regex.search(text) != null

func _on_tts_success(stream: AudioStream, _text: String) -> void:
	if audio_player:
		audio_player.stream = stream
		audio_player.play()

func _on_tts_failed(err_msg: String, _text: String) -> void:
	print("Voice Call TTS Failed: ", err_msg)
