extends RefCounted

signal turn_completed(realized_turn: Dictionary, request_context: Dictionary)
signal turn_failed(error_message: String, request_context: Dictionary)

const PromptBuilderScript = preload("res://scripts/api/chat_realize_turn_prompt_builder.gd")
const ValidatorScript = preload("res://scripts/api/chat_realize_turn_validator.gd")
const ConfigResourceScript = preload("res://scripts/data/config_resource.gd")
const MAX_ATTEMPTS := 4

var _prompt_builder = PromptBuilderScript.new()
var _validator = ValidatorScript.new()
var _client = null
var _active_requests: Dictionary = {}
var _cancellation_generation: int = 0


func bind_client(client) -> void:
	_client = client
	if not client.structured_chat_request_completed.is_connected(_on_request_completed):
		client.structured_chat_request_completed.connect(_on_request_completed)
	if not client.structured_chat_request_failed.is_connected(_on_request_failed):
		client.structured_chat_request_failed.connect(_on_request_failed)


func request_turn(player_text: String, history_type: String = "main_chat", request_context: Dictionary = {}, prompt_access_context: Dictionary = {}) -> void:
	var normalized_text := player_text.strip_edges()
	if normalized_text.is_empty():
		turn_failed.emit("玩家输入为空。", request_context)
		return
	if GameDataManager.config.ai_service_mode == ConfigResourceScript.AI_SERVICE_OFFICIAL:
		if not await OfficialAuthManager.ensure_valid_access_token():
			var auth_context := request_context.duplicate(true)
			auth_context["failure_stage"] = "auth_preflight"
			turn_failed.emit("官方 AI 登录状态无法续期。", auth_context)
			return
	var request_generation := _cancellation_generation
	var prompt_result: Dictionary
	if history_type == "desktop_pet":
		prompt_result = await GameDataManager.memory_retrieval_service.build_system_prompt_result(
			GameDataManager.profile,
			"desktop_pet",
			normalized_text,
			GameDataManager.desktop_pet_memory_manager,
			"desktop_pet",
			prompt_access_context
		)
	elif history_type == "mobile_chat":
		prompt_result = await GameDataManager.memory_retrieval_service.build_system_prompt_result(
			GameDataManager.profile,
			"mobile_chat",
			normalized_text,
			null,
			"mobile_chat",
			prompt_access_context
		)
	else:
		prompt_result = await GameDataManager.memory_retrieval_service.build_chat_prompt_result(
			GameDataManager.profile,
			normalized_text,
			null,
			"story_chat" if history_type == "story_chat" else "main_chat",
			prompt_access_context
		)
	if request_generation != _cancellation_generation:
		return
	var context := request_context.duplicate(true)
	context["reply_pipeline"] = PromptBuilderScript.CONTRACT_VERSION
	context["player_text"] = normalized_text
	context["turn_origin"] = str(request_context.get("turn_origin", "player_input"))
	context["history_type"] = history_type
	var scene_state_block: String = str(GameDataManager.chat_scene_state_runtime.build_prompt_block()) if history_type == "main_chat" and GameDataManager.chat_scene_state_runtime else ""
	var additional_context := str(request_context.get("additional_authoritative_context", "")).strip_edges()
	context["authoritative_context"] = str(prompt_result.get("prompt", ""))
	if not scene_state_block.is_empty():
		context["authoritative_context"] += "\n\n" + scene_state_block
	if not additional_context.is_empty():
		context["authoritative_context"] += "\n\n【本轮程序已提交事实】\n" + additional_context
	context["request_id"] = str(prompt_result.get("request_id", ""))
	context["trace_id"] = str(prompt_result.get("trace_id", ""))
	context["rendered_memory_ids"] = prompt_result.get("rendered_memory_ids", []).duplicate()
	context["has_explicit_recent_messages"] = request_context.has("recent_messages") and request_context.get("recent_messages") is Array
	context["recent_messages"] = request_context.get("recent_messages", []).duplicate(true) if request_context.get("recent_messages", []) is Array else []
	context["attempt"] = 0
	context["retry_issue_codes"] = []
	context["force_text_response"] = true
	_start_attempt(context)


func cancel_all() -> void:
	_cancellation_generation += 1
	_active_requests.clear()


func _start_attempt(context: Dictionary) -> void:
	if _client == null or not is_instance_valid(_client):
		turn_failed.emit("AI 对话服务不可用。", context)
		return
	context["attempt"] = int(context.get("attempt", 0)) + 1
	if int(context["attempt"]) >= 2 and bool(context.get("provider_response_recovery", false)):
		context["force_text_response"] = true
	print("[RealizeTurnTrace] request=%s attempt=%d stage=request_started force_text_response=%s retry_issues=%s" % [
		str(context.get("request_id", "")),
		int(context["attempt"]),
		str(context.get("force_text_response", false)),
		str(context.get("retry_issue_codes", []))
	])
	if int(context["attempt"]) == 1 and GameDataManager.memory_retrieval_trace_service:
		GameDataManager.memory_retrieval_trace_service.mark_request_started(str(context.get("trace_id", "")))
	var recent_messages: Array = context.get("recent_messages", []) if context.get("recent_messages", []) is Array else []
	if not bool(context.get("has_explicit_recent_messages", false)):
		recent_messages = _client.get_history_messages(10, true, str(context.get("history_type", "main_chat")))
	var messages := _prompt_builder.build_messages(
		str(context.get("authoritative_context", "")),
		recent_messages,
		str(context.get("player_text", "")),
		context.get("retry_issue_codes", []),
		str(context.get("turn_origin", "player_input"))
	)
	var network_context := context.duplicate(true)
	var network_id: int = _client.send_structured_messages(messages, network_context)
	_active_requests[network_id] = context.duplicate(true)


func _on_request_completed(response: Dictionary, network_context: Dictionary) -> void:
	var network_id := int(network_context.get("network_request_id", 0))
	if not _active_requests.has(network_id):
		return
	var context: Dictionary = (_active_requests.get(network_id) as Dictionary).duplicate(true)
	_active_requests.erase(network_id)
	var content_result := _extract_content(response)
	if not bool(content_result.get("ok", false)):
		_retry_or_fail(context, ["REALIZE_TURN_PROVIDER_ENVELOPE_INVALID"])
		return
	var response_content := str(content_result.get("content", ""))
	var validation: Dictionary = _validator.validate(response_content)
	if not bool(validation.get("ok", false)):
		var repaired_turn := _repair_speech_stage_directions(response_content)
		if not repaired_turn.is_empty():
			var repaired_validation: Dictionary = _validator.validate(repaired_turn)
			if bool(repaired_validation.get("ok", false)):
				validation = repaired_validation
				context["response_compatibility_mode"] = "speech_stage_direction_repaired"
				print("[RealizeTurnTrace] request=%s attempt=%d stage=speech_stage_direction_repaired" % [
					str(context.get("request_id", "")),
					int(context.get("attempt", 0))
				])
	if not bool(validation.get("ok", false)) and _can_use_plain_text_fallback(response_content, validation, context):
		var fallback_turn := _build_plain_text_fallback(response_content, context)
		validation = _validator.validate(fallback_turn)
		if bool(validation.get("ok", false)):
			context["response_compatibility_mode"] = "plain_text_single_beat"
			print("[RealizeTurnTrace] request=%s attempt=%d stage=plain_text_fallback_accepted content_length=%d" % [
				str(context.get("request_id", "")),
				int(context.get("attempt", 0)),
				response_content.length()
			])
	if not bool(validation.get("ok", false)):
		print("[RealizeTurnTrace] request=%s attempt=%d stage=validation_failed issue_codes=%s force_text_response=%s content_preview=%s" % [
			str(context.get("request_id", "")),
			int(context.get("attempt", 0)),
			str(validation.get("issue_codes", [])),
			str(context.get("force_text_response", false)),
			response_content.left(500).replace("\n", "\\n")
		])
		_retry_or_fail(context, validation.get("issue_codes", []))
		return
	context["accepted_attempt"] = int(context.get("attempt", 1))
	context["retry_issue_codes"] = context.get("retry_issue_codes", []).duplicate()
	if GameDataManager.memory_retrieval_trace_service:
		GameDataManager.memory_retrieval_trace_service.mark_response_completed(str(context.get("trace_id", "")), JSON.stringify(validation.get("value", {})))
	turn_completed.emit(validation.get("value", {}).duplicate(true), context)


func _has_only_issue(validation: Dictionary, issue_code: String) -> bool:
	var issue_codes: Variant = validation.get("issue_codes", [])
	return JSON.stringify(issue_codes) == '["%s"]' % issue_code


func _repair_speech_stage_directions(content: String) -> Dictionary:
	var json := JSON.new()
	if json.parse(content) != OK or not json.get_data() is Dictionary:
		return {}
	var repaired := (json.get_data() as Dictionary).duplicate(true)
	var segments: Variant = repaired.get("segments")
	if not segments is Array:
		return {}
	var stage_direction_pattern := RegEx.new()
	if stage_direction_pattern.compile("[（(][^（）()]*[）)]") != OK:
		return {}
	var changed := false
	for segment_value in segments:
		if not segment_value is Dictionary:
			continue
		var segment := segment_value as Dictionary
		var speech := str(segment.get("speech", ""))
		var stage_directions: Array[String] = []
		for match_result in stage_direction_pattern.search_all(speech):
			var direction := str(match_result.get_string()).trim_prefix("（").trim_prefix("(").trim_suffix("）").trim_suffix(")").strip_edges()
			if not direction.is_empty():
				stage_directions.append(direction)
		var cleaned_speech := stage_direction_pattern.sub(speech, "", true).strip_edges()
		if stage_directions.is_empty() or cleaned_speech.is_empty():
			continue
		var action: Variant = segment.get("action")
		if not action is Dictionary:
			continue
		var action_description := str(action.get("description", "")).strip_edges()
		(action as Dictionary)["description"] = "%s %s" % [" ".join(stage_directions), action_description]
		segment["speech"] = cleaned_speech
		changed = true
	return repaired if changed else {}


func _can_use_plain_text_fallback(content: String, validation: Dictionary, context: Dictionary) -> bool:
	if not bool(context.get("force_text_response", false)):
		return false
	if not _has_only_issue(validation, "REALIZE_TURN_JSON_INVALID"):
		return false
	var normalized := content.strip_edges()
	if normalized.is_empty() or normalized.length() > 1000:
		return false
	return not normalized.begins_with("```") and not normalized.begins_with("{") and not normalized.begins_with("[")


func _build_plain_text_fallback(content: String, context: Dictionary) -> Dictionary:
	var performances := _parse_plain_text_performances(content)
	var player_text := str(context.get("player_text", "")).strip_edges()
	if player_text.length() > 500:
		player_text = player_text.left(500)
	var speech_parts: Array[String] = []
	var beats: Array[Dictionary] = []
	var segments: Array[Dictionary] = []
	for index in range(performances.size()):
		var performance: Dictionary = performances[index]
		var speech := str(performance.get("speech", "")).strip_edges()
		if speech.is_empty():
			continue
		var beat_id := "beat_%d" % (segments.size() + 1)
		var response_summary := speech if speech.length() <= 500 else speech.left(500)
		speech_parts.append(speech)
		beats.append({
			"beat_id": beat_id,
			"interaction_change": "角色继续当前对话。",
			"felt_response": {"physical": null, "psychological": "保持对当前话题的关注。", "audible": null},
			"speech_contribution": response_summary
		})
		segments.append({
			"beat_id": beat_id,
			"action": {"actor_id": "character", "description": str(performance.get("action", "本段未提供可见动作。")), "persistent_effect": null},
			"speech": speech,
			"delivery_instruction": str(performance.get("delivery", "保持角色当前声线，以自然、连贯的语气表达。"))
		})
	var combined_speech := " ".join(speech_parts)
	var combined_summary := combined_speech if combined_speech.length() <= 500 else combined_speech.left(500)
	return {
		"turn_result": {
			"player_input_addressed": player_text,
			"character_response": combined_summary,
			"interaction_change": "角色回应了当前话题。",
			"interaction_beats": beats
		},
		"segments": segments
	}


func _parse_plain_text_performances(content: String) -> Array[Dictionary]:
	var normalized := content.replace("[SPLIT]", "\n")
	var repeated_voice_pattern := RegEx.new()
	if repeated_voice_pattern.compile("(?i)(?<!^)<voice:") == OK:
		normalized = repeated_voice_pattern.sub(normalized, "\n<voice:", true)
	var performances: Array[Dictionary] = []
	for raw_part in normalized.split("\n", false):
		var part := str(raw_part).strip_edges()
		if not part.is_empty() and performances.size() < 3:
			performances.append(_parse_plain_text_performance(part))
	return performances


func _parse_plain_text_performance(content: String) -> Dictionary:
	var speech := content.strip_edges()
	var delivery := "保持角色当前声线，以自然、连贯的语气表达。"
	var action := "本段未提供可见动作。"
	var voice_pattern := RegEx.new()
	if voice_pattern.compile("^<voice:([^>]*)>") == OK:
		var voice_match := voice_pattern.search(speech)
		if voice_match:
			var voice_direction := str(voice_match.get_string(1)).strip_edges()
			if not voice_direction.is_empty():
				delivery = "保持角色当前声线，%s。" % voice_direction
			speech = voice_pattern.sub(speech, "", false).strip_edges()
	var action_pattern := RegEx.new()
	if action_pattern.compile("^[（(]([^（）()]*)[）)]") == OK:
		var action_match := action_pattern.search(speech)
		if action_match:
			var action_direction := str(action_match.get_string(1)).strip_edges()
			if not action_direction.is_empty():
				action = action_direction
			speech = action_pattern.sub(speech, "", false).strip_edges()
	elif GameDataManager.profile:
		var character_name := str(GameDataManager.profile.char_name).strip_edges()
		var first_sentence_end := speech.find("。")
		if not character_name.is_empty() and speech.begins_with(character_name) and first_sentence_end >= 0 and first_sentence_end < speech.length() - 1:
			action = speech.left(first_sentence_end + 1)
			speech = speech.substr(first_sentence_end + 1).strip_edges()
	return {"speech": speech, "delivery": delivery, "action": action}


func _on_request_failed(error_message: String, network_context: Dictionary) -> void:
	var network_id := int(network_context.get("network_request_id", 0))
	if not _active_requests.has(network_id):
		return
	var context: Dictionary = (_active_requests.get(network_id) as Dictionary).duplicate(true)
	_active_requests.erase(network_id)
	context["failure_stage"] = str(network_context.get("failure_stage", ""))
	context["response_code"] = network_context.get("response_code", "")
	if _is_recoverable_request_failure(context) and int(context.get("attempt", 0)) < MAX_ATTEMPTS:
		var failure_stage := str(context.get("failure_stage", ""))
		context["provider_response_recovery"] = true
		context["retry_issue_codes"] = ["REALIZE_TURN_PROVIDER_CONTENT_EMPTY"] if failure_stage == "provider_content" else ["REALIZE_TURN_PROVIDER_REQUEST_FAILED"]
		print("[RealizeTurnTrace] request=%s attempt=%d stage=request_retry failure_stage=%s error=%s" % [
			str(context.get("request_id", "")),
			int(context.get("attempt", 0)),
			failure_stage,
			error_message
		])
		_start_attempt(context)
		return
	if GameDataManager.memory_retrieval_trace_service:
		GameDataManager.memory_retrieval_trace_service.mark_request_failed(str(context.get("trace_id", "")), error_message)
	turn_failed.emit(error_message, context)


func _is_recoverable_request_failure(context: Dictionary) -> bool:
	return str(context.get("failure_stage", "")) in [
		"http_timeout",
		"request_start",
		"provider_json",
		"provider_envelope",
		"provider_content"
	]


func _retry_or_fail(context: Dictionary, issue_codes: Array) -> void:
	context["retry_issue_codes"] = issue_codes.duplicate()
	if int(context.get("attempt", 0)) < MAX_ATTEMPTS:
		context["provider_response_recovery"] = true
		_start_attempt(context)
		return
	if GameDataManager.memory_retrieval_trace_service:
		GameDataManager.memory_retrieval_trace_service.mark_request_failed(str(context.get("trace_id", "")), "协议验证失败：%s" % ",".join(issue_codes))
	turn_failed.emit("角色回复未通过协议验证，请重试。", context)


func _extract_content(response: Dictionary) -> Dictionary:
	var choices: Variant = response.get("choices")
	if not choices is Array or choices.is_empty() or not choices[0] is Dictionary:
		return {"ok": false}
	var message: Variant = choices[0].get("message")
	if not message is Dictionary:
		return {"ok": false}
	var content := str(message.get("content", "")).strip_edges()
	return {"ok": not content.is_empty(), "content": content}