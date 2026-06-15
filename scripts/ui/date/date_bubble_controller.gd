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
var _bubble_request_fallback_text: String = ""


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
	_request_bubble_stream(ai_client, prompt, fallback, "date_scene_greeting")


func request_slot_comment(ai_client: Node, slot_payload: Dictionary) -> void:
	var fallback: String = _build_slot_comment_fallback(slot_payload)
	var prompt: String = _build_slot_comment_prompt(slot_payload)
	_request_bubble_stream(ai_client, prompt, fallback, "date_scene_slot_comment")


func show_slot_comment(slot_payload: Dictionary) -> void:
	show_text(_build_slot_comment_fallback(slot_payload))


func _build_slot_comment_fallback(slot_payload: Dictionary) -> String:
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
	return line_text


func _build_slot_comment_prompt(slot_payload: Dictionary) -> String:
	var location_name: String = str(slot_payload.get("location_name", "")).strip_edges()
	var period_label: String = str(slot_payload.get("period_label", "")).strip_edges()
	var type_id: String = str(slot_payload.get("type_id", "")).strip_edges()
	var type_name: String = _resolve_date_type_name(type_id)
	if location_name == "":
		return ""
	var profile = GameDataManager.profile if GameDataManager else null
	var stage_title: String = "熟悉阶段"
	var stage_desc: String = ""
	var intimacy: float = 0.0
	var trust: float = 0.0
	if profile:
		var stage_conf: Dictionary = profile.get_current_stage_config()
		stage_title = str(stage_conf.get("stageTitle", "熟悉阶段")).strip_edges()
		stage_desc = str(stage_conf.get("stageDesc", "")).strip_edges()
		intimacy = float(profile.intimacy)
		trust = float(profile.trust)
	var weather_desc: String = ""
	if GameDataManager and GameDataManager.story_time_manager:
		weather_desc = str(GameDataManager.story_time_manager.get_story_weather_desc()).strip_edges()
	var prompt := "【系统指令】玩家刚刚把约会地点加入了行程。\n"
	prompt += "请你以%s现在的口吻，对这个安排说一句简短短评。\n" % character_id.capitalize()
	prompt += "已选地点：%s。\n" % location_name
	prompt += "时间段：%s。\n" % period_label
	if type_name != "":
		prompt += "约会类型：%s。\n" % type_name
	if weather_desc != "":
		prompt += "当前天气：%s。\n" % weather_desc
	prompt += "当前关系阶段：%s。\n" % stage_title
	if stage_desc != "":
		prompt += "阶段描述：%s。\n" % stage_desc
	prompt += "当前亲密度：%.1f，信任度：%.1f。\n" % [intimacy, trust]
	prompt += "要求：\n"
	prompt += "1. 只输出一句短评，10到26字。\n"
	prompt += "2. 必须像她本人自然开口，带一点真实情绪，不要像说明文。\n"
	prompt += "3. 要围绕这个具体地点和时间段，体现一点期待、在意、害羞、嘴硬或放松感。\n"
	prompt += "4. 不要输出多个选项，不要解释，不要使用引号。\n"
	prompt += "5. 不要写成完整长对话，也不要出现旁白口吻。\n"
	return prompt


func _resolve_date_type_name(type_id: String) -> String:
	match type_id:
		"stroll":
			return "漫步散心"
		"shopping":
			return "逛街购物"
		"exhibition":
			return "观影看展"
		"dining":
			return "餐饮小聚"
		"real_photo":
			return "现实邀约"
	return type_id


func _request_bubble_stream(ai_client: Node, prompt: String, fallback: String, history_type: String) -> void:
	_bubble_request_fallback_text = fallback
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
	if _deepseek_client.has_method("start_chat_stream_with_messages"):
		_deepseek_client.start_chat_stream_with_messages([
			{"role": "system", "content": "你正在扮演约会中的角色本人，请只返回一句自然口语化台词。"},
			{"role": "user", "content": prompt}
		])
	else:
		_deepseek_client.send_chat_message_stream(prompt, history_type)


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
		clean_text = _bubble_request_fallback_text
	show_text(clean_text)


func _on_bubble_failed(_error_msg: String) -> void:
	_disconnect_ai_signals()
	show_text(_bubble_request_fallback_text)


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
