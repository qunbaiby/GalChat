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
var _bubble_pending_requests: Array[Dictionary] = []
var _bubble_request_in_flight: bool = false


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
	_bubble_pending_requests.clear()
	_bubble_request_in_flight = false
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
	var char_name: String = str(character_profile.get("char_name", "")).strip_edges()
	if char_name == "" and profile:
		char_name = str(profile.char_name).strip_edges()
	if char_name == "":
		char_name = character_id.capitalize()
	var stage_title: String = "熟悉阶段"
	var stage_desc: String = ""
	var intimacy: float = 0.0
	var trust: float = 0.0
	var flavor_label: String = ""
	var personality_summary: String = ""
	var dynamic_traits: String = ""
	var mood_name: String = "平静"
	var expression_name: String = ""
	var expression_desc: String = ""
	if profile:
		var stage_conf: Dictionary = profile.get_current_stage_config()
		stage_title = str(stage_conf.get("stageTitle", "熟悉阶段")).strip_edges()
		stage_desc = str(stage_conf.get("stageDesc", "")).strip_edges()
		intimacy = float(profile.intimacy)
		trust = float(profile.trust)
		if GameDataManager.personality_system:
			flavor_label = str(GameDataManager.personality_system.get_relationship_flavor_label(profile)).strip_edges()
			personality_summary = str(GameDataManager.personality_system.get_personality_summary(profile)).strip_edges()
			dynamic_traits = str(GameDataManager.personality_system.get_dynamic_traits(profile)).strip_edges()
		if GameDataManager.mood_system:
			mood_name = str(GameDataManager.mood_system.get_macro_mood_name(profile.mood_value)).strip_edges()
		var current_expression: String = str(profile.current_expression).strip_edges()
		if current_expression != "" and GameDataManager.expression_system:
			expression_name = str(GameDataManager.expression_system.expression_configs.get(current_expression, {}).get("expression_name", "")).strip_edges()
			expression_desc = str(GameDataManager.expression_system.get_expression_description(current_expression)).strip_edges()
	var weather_desc: String = ""
	if GameDataManager and GameDataManager.story_time_manager:
		weather_desc = str(GameDataManager.story_time_manager.get_story_weather_desc()).strip_edges()
	var prompt := "【系统指令】玩家刚刚把约会地点加入了行程。\n"
	prompt += "你现在要扮演%s本人，对这个安排立刻说一句短评。\n" % char_name
	prompt += "这句短评必须严格符合你当前的人设、关系阶段、心情和说话习惯，不能 OOC，不能像旁白或文案。\n"
	prompt += "已选地点：%s。\n" % location_name
	prompt += "时间段：%s。\n" % period_label
	if type_name != "":
		prompt += "约会类型：%s。\n" % type_name
	if weather_desc != "":
		prompt += "当前天气：%s。\n" % weather_desc
	if flavor_label != "":
		prompt += "当前关系风味：%s。\n" % flavor_label
	prompt += "当前关系阶段：%s。\n" % stage_title
	if stage_desc != "":
		prompt += "阶段描述：%s。\n" % stage_desc
	prompt += "当前亲密度：%.1f，信任度：%.1f。\n" % [intimacy, trust]
	prompt += "当前整体心情：%s。\n" % mood_name
	if expression_name != "":
		prompt += "当前瞬时表情：%s。\n" % expression_name
	if expression_desc != "":
		prompt += "当前表情说明：%s。\n" % expression_desc
	if personality_summary != "":
		prompt += "核心人格摘要：%s。\n" % personality_summary
	if dynamic_traits != "":
		prompt += "当前动态人格与边界：%s。\n" % dynamic_traits
	prompt += "要求：\n"
	prompt += "1. 只输出一句短评，10到26字。\n"
	prompt += "2. 必须像她本人自然开口，带一点真实情绪，不要像说明文，不要像 AI 总结。\n"
	prompt += "3. 要围绕这个具体地点和时间段，体现一点期待、在意、害羞、嘴硬、试探或放松感，但必须服从当前阶段边界。\n"
	prompt += "4. 不要输出多个选项，不要解释，不要使用引号。\n"
	prompt += "5. 不要写成完整长对话，也不要出现旁白口吻。\n"
	prompt += "6. 禁止突然过度亲密、突然告白、突然冷淡、突然成熟得不像%s本人。\n" % char_name
	prompt += "7. 如果你当前阶段更克制，就让短评保持克制；如果当前心情更明亮，可以稍微更主动一点，但仍要自然。\n"
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
	# #region debug-point A:bubble-request-entry
	if ai_client and ai_client.has_method("_debug_report"):
		ai_client._debug_report("A", "date_bubble_controller.gd:_request_bubble_stream", "bubble request entry", {
			"history_type": history_type,
			"prompt_empty": prompt == "",
			"fallback_preview": fallback.left(60)
		})
	# #endregion
	if ai_client == null or prompt == "":
		# #region debug-point A:bubble-request-fallback
		if ai_client and ai_client.has_method("_debug_report"):
			ai_client._debug_report("A", "date_bubble_controller.gd:_request_bubble_stream", "bubble request fallback before api call", {
				"ai_client_null": ai_client == null,
				"prompt_empty": prompt == ""
			})
		# #endregion
		show_text(fallback)
		return
	_bubble_pending_requests.append({
		"ai_client": ai_client,
		"prompt": prompt,
		"fallback": fallback,
		"history_type": history_type
	})
	if ai_client.has_method("_debug_report"):
		ai_client._debug_report("A", "date_bubble_controller.gd:_request_bubble_stream", "bubble request queued", {
			"history_type": history_type,
			"queue_size": _bubble_pending_requests.size(),
			"in_flight": _bubble_request_in_flight
		})
	if _bubble_request_in_flight:
		return
	_dispatch_next_bubble_request()


func _dispatch_next_bubble_request() -> void:
	if _bubble_request_in_flight or _bubble_pending_requests.is_empty():
		return
	var request_data: Dictionary = _bubble_pending_requests[0]
	_bubble_pending_requests.remove_at(0)
	_bubble_request_in_flight = true
	_bubble_request_fallback_text = str(request_data.get("fallback", "")).strip_edges()
	_disconnect_ai_signals()
	_deepseek_client = request_data.get("ai_client", null)
	var prompt: String = str(request_data.get("prompt", "")).strip_edges()
	var history_type: String = str(request_data.get("history_type", "date_scene_slot_comment")).strip_edges()
	if not _deepseek_client.is_connected("chat_stream_delta", _on_bubble_chunk_received):
		_deepseek_client.chat_stream_delta.connect(_on_bubble_chunk_received)
	if not _deepseek_client.is_connected("chat_request_completed", _on_bubble_completed):
		_deepseek_client.chat_request_completed.connect(_on_bubble_completed)
	if not _deepseek_client.is_connected("chat_request_failed", _on_bubble_failed):
		_deepseek_client.chat_request_failed.connect(_on_bubble_failed)
	_bubble_stream_buffer = ""
	if _deepseek_client.has_method("start_chat_stream_with_messages"):
		_deepseek_client.start_chat_stream_with_messages([
			{"role": "system", "content": "你正在扮演约会中的角色本人。请严格贴合当前人设、关系阶段、心情和表情，只返回一句自然口语化短评。禁止旁白、禁止解释、禁止 OOC。"},
			{"role": "user", "content": prompt}
		])
	else:
		_deepseek_client.send_chat_message_stream(prompt, history_type)


func _finish_current_bubble_request() -> void:
	_disconnect_ai_signals()
	_bubble_request_in_flight = false
	call_deferred("_dispatch_next_bubble_request")


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
	var full_text: String = ""
	if response.has("choices") and response["choices"].size() > 0:
		full_text = response["choices"][0]["message"]["content"]
	var clean_text: String = _strip_bubble_action_descriptions(full_text)
	# #region debug-point D:bubble-completed
	if _deepseek_client and _deepseek_client.has_method("_debug_report"):
		_deepseek_client._debug_report("D", "date_bubble_controller.gd:_on_bubble_completed", "bubble request completed", {
			"raw_length": full_text.length(),
			"clean_length": clean_text.length(),
			"raw_preview": full_text.left(120)
		})
	# #endregion
	_finish_current_bubble_request()
	if clean_text.is_empty():
		clean_text = _bubble_request_fallback_text
	show_text(clean_text)


func _on_bubble_failed(error_msg: String) -> void:
	# #region debug-point C:bubble-failed
	if _deepseek_client and _deepseek_client.has_method("_debug_report"):
		_deepseek_client._debug_report("C", "date_bubble_controller.gd:_on_bubble_failed", "bubble request failed", {
			"error": error_msg,
			"fallback_preview": _bubble_request_fallback_text.left(80)
		})
	# #endregion
	_finish_current_bubble_request()
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
