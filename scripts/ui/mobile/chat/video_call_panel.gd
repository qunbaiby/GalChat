extends Control

signal call_ended
signal message_sent(text)

@onready var bg_tex: TextureRect = $BackgroundTex
@onready var spine_container: Control = $Panel/SpineContainer
@onready var current_spine: SpineSprite = $Panel/SpineContainer/SpineSprite
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
		
		if GameDataManager.config:
			doubao_tts.setup_auth(
				GameDataManager.config.doubao_app_id,
				GameDataManager.config.doubao_token
			)
			
		doubao_tts.tts_success.connect(_on_tts_success)
		doubao_tts.tts_failed.connect(_on_tts_failed)
	else:
		print("Video Call: Could not load TTS service script.")

func setup(char_id: String, profile: CharacterProfile, is_incoming: bool = false) -> void:
	current_char_id = char_id
	char_profile = profile
	
	name_label.text = profile.char_name
	status_label.text = "接通中..."
	message_label.text = "[center]...[/center]"
	
	_load_spine(char_id)

func set_loading_state() -> void:
	status_label.text = "对方正在连接..."
	record_btn.disabled = true

func set_background(bg_path: String) -> void:
	if bg_path != "" and ResourceLoader.exists(bg_path):
		bg_tex.texture = load(bg_path)
	else:
		bg_tex.texture = null

func _load_spine(char_id: String) -> void:
	if not is_instance_valid(current_spine): return
	var path = char_profile.spine_path if char_profile else ""
	if path != "" and ResourceLoader.exists(path):
		var res = load(path)
		if res is SpineSkeletonDataResource:
			if current_spine.skeleton_data_res != res:
				current_spine.skeleton_data_res = res
			
			# 强行刷新一下材质和动画
			if current_spine.has_method("update_transform"):
				current_spine.update_transform()
			
			# Ensure the animation state is ready
			call_deferred("_play_spine_animation", "Idle", true)
	else:
		print("Spine not found for character: ", char_id)

func _play_spine_animation(anim_name: String, loop: bool = true) -> void:
	if not is_instance_valid(current_spine) or not current_spine is SpineSprite:
		print("Spine Error: Invalid SpineSprite instance")
		return
		
	var anim_state = current_spine.get_animation_state()
	if not anim_state:
		print("Spine Error: get_animation_state returned null")
		return
		
	var skeleton = current_spine.get_skeleton()
	if not skeleton or not skeleton.get_data():
		print("Spine Error: No skeleton or skeleton data")
		return
		
	var anims = skeleton.get_data().get_animations()
	var anim_names = []
	for a in anims:
		anim_names.append(a.get_name())
		
	var target_anim = anim_name
	if not target_anim in anim_names:
		print("Spine Warning: Target anim ", target_anim, " not found in ", anim_names)
		if "Idle" in anim_names:
			target_anim = "Idle"
		elif "idle" in anim_names:
			target_anim = "idle"
		elif anim_names.size() > 0:
			target_anim = anim_names[0]
		else:
			print("Spine Error: No fallback animations found")
			return
			
	var current_track = anim_state.get_current(0)
	if current_track and current_track.get_animation().get_name() == target_anim and loop:
		return
		
	print("Spine: Playing animation ", target_anim)
	anim_state.set_animation(target_anim, loop, 0)

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
		status_label.text = "视频通话中"
		record_btn.disabled = false
		return
		
	await _typewriter_effect("[color=#88ccff]" + text + "[/color]")
	
	await get_tree().create_timer(0.5).timeout
	message_sent.emit(text)

func _on_asr_failed(err_msg: String) -> void:
	record_btn.text = "按住说话"
	record_btn.disabled = false
	status_label.text = "语音识别失败"
	await get_tree().create_timer(2.0).timeout
	status_label.text = "视频通话中"

func add_character_message(text: String) -> void:
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
		record_btn.disabled = false
		status_label.text = "视频通话中"
		
		_play_spine_animation("Idle", true)
		return
		
	is_processing_queue = true
	is_character_speaking = true
	record_btn.disabled = true
	status_label.text = "对方正在讲话..."
	
	var chunk = message_queue.pop_front()
	var display_text = _extract_dialogue_text(chunk)
	var tts_text = display_text
	
	var raw_action = _extract_action_only(chunk)
	# Default speaking animation
	_play_spine_animation("Talk", true)
	
	if GameDataManager.config.voice_enabled and _has_readable_text(tts_text):
		var v_type = "ICL_zh_female_bingruoshaonv_tob"
		if GameDataManager.config.character_voice_types.has(current_char_id):
			v_type = GameDataManager.config.character_voice_types[current_char_id]
			
		doubao_tts.synthesize(tts_text, {"voice_type": v_type})
		
		_typewriter_effect("[color=#ffffff]" + display_text + "[/color]")
		
		var wait_net = 0
		while not audio_player.playing and wait_net < 100:
			await get_tree().create_timer(0.05).timeout
			wait_net += 1
			
		while audio_player.playing:
			await get_tree().create_timer(0.05).timeout
			
		await get_tree().create_timer(0.3).timeout
	else:
		await _typewriter_effect("[color=#ffffff]" + display_text + "[/color]")
		await get_tree().create_timer(1.0).timeout
		
	_process_next_message()

func _typewriter_effect(bbcode_text: String) -> void:
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

func _extract_action_only(text: String) -> String:
	var regex = RegEx.new()
	regex.compile("\\(([^)]+)\\)|\\（([^）]+)\\）")
	var result = regex.search(text)
	if result:
		return result.get_string(1) if result.get_string(1) != "" else result.get_string(2)
	return ""

func _has_readable_text(text: String) -> bool:
	var regex = RegEx.new()
	regex.compile("[a-zA-Z0-9\u4e00-\u9fa5]")
	return regex.search(text) != null

func _on_tts_success(stream: AudioStream, _text: String) -> void:
	if audio_player:
		audio_player.stream = stream
		audio_player.play()

func _on_tts_failed(err_msg: String, _text: String) -> void:
	print("Video Call TTS Failed: ", err_msg)
