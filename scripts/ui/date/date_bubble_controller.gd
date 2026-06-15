class_name DateBubbleController
extends Node

const BUBBLE_TYPEWRITER_CHAR_TIME := 0.045
const BUBBLE_HIDE_DELAY_AFTER_VOICE := 1.0

var bubble_panel: Control = null
var bubble_text: Label = null
var character_profile: Dictionary = {}
var character_id: String = "luna"

var _deepseek_client: Node = null
var _bubble_stream_buffer: String = ""
var _bubble_audio_player: AudioStreamPlayer = null
var _bubble_typewriter_tween: Tween = null
var _bubble_hide_tween: Tween = null
var _bubble_sequence_id: int = 0
var _bubble_current_tts_text: String = ""


func setup(panel: Control, text_label: Label, profile_data: Dictionary, current_character_id: String) -> void:
	bubble_panel = panel
	bubble_text = text_label
	character_profile = profile_data.duplicate(true)
	character_id = current_character_id
	_bubble_audio_player = AudioStreamPlayer.new()
	_bubble_audio_player.bus = "Voice"
	_bubble_audio_player.finished.connect(_on_bubble_audio_finished)
	add_child(_bubble_audio_player)
	if TTSManager:
		if not TTSManager.tts_success.is_connected(_on_bubble_tts_success):
			TTSManager.tts_success.connect(_on_bubble_tts_success)
		if not TTSManager.tts_failed.is_connected(_on_bubble_tts_failed):
			TTSManager.tts_failed.connect(_on_bubble_tts_failed)
	if bubble_panel:
		bubble_panel.hide()


func cleanup() -> void:
	_disconnect_ai_signals()
	if _bubble_audio_player:
		_bubble_audio_player.stop()
	if _bubble_hide_tween:
		_bubble_hide_tween.kill()
	if _bubble_typewriter_tween:
		_bubble_typewriter_tween.kill()
	if TTSManager:
		if TTSManager.tts_success.is_connected(_on_bubble_tts_success):
			TTSManager.tts_success.disconnect(_on_bubble_tts_success)
		if TTSManager.tts_failed.is_connected(_on_bubble_tts_failed):
			TTSManager.tts_failed.disconnect(_on_bubble_tts_failed)


func request_greeting(ai_client: Node) -> void:
	var prompt: String = str(character_profile.get("greeting_prompt", "")).strip_edges()
	var fallback: String = str(character_profile.get("greeting_fallback", "今天天气不错，你想带我去哪里？")).strip_edges()
	if ai_client == null or prompt == "":
		show_text(fallback)
		return
	_disconnect_ai_signals()
	_deepseek_client = ai_client
	if not _deepseek_client.is_connected("chat_stream_delta", _on_bubble_chunk_received):
		_deepseek_client.chat_stream_delta.connect(_on_bubble_chunk_received)
	if not _deepseek_client.is_connected("chat_request_completed", _on_bubble_completed):
		_deepseek_client.chat_request_completed.connect(_on_bubble_completed)
	if not _deepseek_client.is_connected("chat_request_failed", _on_bubble_failed):
		_deepseek_client.chat_request_failed.connect(_on_bubble_failed)
	_bubble_stream_buffer = ""
	_deepseek_client.send_chat_message_stream(prompt, "date_scene_greeting")


func show_slot_comment(slot_payload: Dictionary) -> void:
	var type_id: String = str(slot_payload.get("type_id", "")).strip_edges()
	var location_name: String = str(slot_payload.get("location_name", "")).strip_edges()
	var period_label: String = str(slot_payload.get("period_label", "")).strip_edges()
	var preference_block: Dictionary = character_profile.get("date_preferences", {})
	var slot_comments: Dictionary = preference_block.get("slot_comments", {})
	var candidates_variant: Variant = slot_comments.get(type_id, slot_comments.get("default", []))
	var candidates: Array[String] = []
	if candidates_variant is Array:
		for item in candidates_variant:
			var line: String = str(item).strip_edges()
			if line != "":
				candidates.append(line)
	if candidates.is_empty():
		candidates = [
			"%s听起来会很不错。".replace("%s", location_name),
			"把%s留给%s，感觉会是个好安排。".replace("%s", period_label).replace("%s", location_name)
		]
	var line_text: String = str(candidates.pick_random())
	line_text = line_text.replace("{location_name}", location_name)
	line_text = line_text.replace("{period_label}", period_label)
	show_text(line_text)


func show_text(text: String) -> void:
	if bubble_panel == null or bubble_text == null:
		return
	_bubble_sequence_id += 1
	_bubble_current_tts_text = text
	if _bubble_hide_tween:
		_bubble_hide_tween.kill()
	if _bubble_typewriter_tween:
		_bubble_typewriter_tween.kill()
	if _bubble_audio_player:
		_bubble_audio_player.stop()
	bubble_text.text = text
	bubble_text.visible_ratio = 0.0
	bubble_panel.show()
	bubble_panel.modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(bubble_panel, "modulate:a", 1.0, 0.2)
	var typewriter_duration: float = maxf(0.35, float(text.length()) * BUBBLE_TYPEWRITER_CHAR_TIME)
	_bubble_typewriter_tween = create_tween()
	_bubble_typewriter_tween.tween_property(bubble_text, "visible_ratio", 1.0, typewriter_duration)
	_play_bubble_tts(text)


func hide_bubble() -> void:
	if bubble_panel == null or not bubble_panel.visible:
		return
	if _bubble_hide_tween:
		_bubble_hide_tween.kill()
	_bubble_hide_tween = create_tween()
	_bubble_hide_tween.tween_property(bubble_panel, "modulate:a", 0.0, 0.18)
	_bubble_hide_tween.tween_callback(bubble_panel.hide)


func _play_bubble_tts(text: String) -> void:
	if not GameDataManager or not GameDataManager.config:
		return
	if not GameDataManager.config.voice_enabled:
		return
	var spoken_text: String = text.strip_edges()
	if spoken_text == "":
		return
	var options: Dictionary = {}
	var backend: String = str(GameDataManager.config.tts_backend)
	var tts_config: Dictionary = character_profile.get("tts", {})
	if backend == "qwen_tts":
		var qwen_voice: String = str(tts_config.get("qwen_voice_type", "")).strip_edges()
		if qwen_voice != "":
			options["voice_type"] = qwen_voice
	elif str(tts_config.get("doubao_voice_type", "")).strip_edges() != "":
		options["voice_type"] = str(tts_config.get("doubao_voice_type", "")).strip_edges()
	if options.is_empty():
		if backend == "qwen_tts":
			if GameDataManager.config.qwen_tts_voice_types.has(character_id):
				options["voice_type"] = GameDataManager.config.qwen_tts_voice_types[character_id]
		else:
			if GameDataManager.config.character_voice_types.has(character_id):
				options["voice_type"] = GameDataManager.config.character_voice_types[character_id]
	TTSManager.synthesize(spoken_text, options)


func _on_bubble_chunk_received(chunk: String) -> void:
	_bubble_stream_buffer += chunk


func _on_bubble_completed(response: Dictionary) -> void:
	_disconnect_ai_signals()
	var full_text: String = ""
	if response.has("choices") and response["choices"].size() > 0:
		full_text = response["choices"][0]["message"]["content"]
	var clean_text: String = _strip_bubble_action_descriptions(full_text)
	if clean_text.is_empty():
		clean_text = str(character_profile.get("greeting_fallback", "今天天气不错，你想带我去哪里？"))
	show_text(clean_text)


func _on_bubble_failed(_error_msg: String) -> void:
	_disconnect_ai_signals()
	show_text(str(character_profile.get("greeting_fallback", "今天天气不错，你想带我去哪里？")))


func _on_bubble_tts_success(audio_stream: AudioStream, text: String) -> void:
	if text != _bubble_current_tts_text:
		return
	if _bubble_audio_player and audio_stream:
		_bubble_audio_player.stream = audio_stream
		_bubble_audio_player.play()


func _on_bubble_tts_failed(_error_msg: String, text: String) -> void:
	if text != _bubble_current_tts_text:
		return


func _on_bubble_audio_finished() -> void:
	if bubble_panel and bubble_panel.visible:
		var seq: int = _bubble_sequence_id
		await get_tree().create_timer(BUBBLE_HIDE_DELAY_AFTER_VOICE).timeout
		if not is_inside_tree():
			return
		if seq != _bubble_sequence_id:
			return
		if bubble_panel and bubble_panel.visible:
			hide_bubble()


func _disconnect_ai_signals() -> void:
	if _deepseek_client:
		if _deepseek_client.is_connected("chat_stream_delta", _on_bubble_chunk_received):
			_deepseek_client.chat_stream_delta.disconnect(_on_bubble_chunk_received)
		if _deepseek_client.is_connected("chat_request_completed", _on_bubble_completed):
			_deepseek_client.chat_request_completed.disconnect(_on_bubble_completed)
		if _deepseek_client.is_connected("chat_request_failed", _on_bubble_failed):
			_deepseek_client.chat_request_failed.disconnect(_on_bubble_failed)
	_deepseek_client = null


func _strip_bubble_action_descriptions(text: String) -> String:
	var cleaned: String = text.strip_edges()
	var patterns: Array[String] = ["\\([^()]*\\)", "（[^（）]*）"]
	for pattern in patterns:
		var regex := RegEx.new()
		if regex.compile(pattern) == OK:
			cleaned = regex.sub(cleaned, "", true)
	return cleaned.strip_edges()
