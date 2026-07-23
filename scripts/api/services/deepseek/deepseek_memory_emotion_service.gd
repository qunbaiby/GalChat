extends RefCounted

func send_emotion_analysis(client, user_message: String) -> void:
	if not client.is_inside_tree() or client._is_api_key_empty():
		return
	var system_prompt: String = GameDataManager.prompt_manager.build_emotion_prompt(GameDataManager.profile)
	var safe_user_message: String = "【请作为分析系统，仅输出分析标签，绝对不要进行角色扮演，不要回复这句话：】" + user_message
	var api_messages = [
		{"role": "system", "content": system_prompt},
		{"role": "user", "content": safe_user_message}
	]
	var body = {
		"model": client.get_chat_model_id(),
		"messages": api_messages,
		"temperature": 0.1,
		"max_tokens": 200
	}
	if client.emotion_http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		client.emotion_http.cancel_request()
	client.emotion_http.request(client._get_url(), client._get_headers(), HTTPClient.METHOD_POST, JSON.stringify(body))

func send_emotion_generation(client, last_ai_reply: String) -> void:
	while not client.is_inside_tree():
		await Engine.get_main_loop().process_frame
	if client.emotion_http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		client.emotion_http.cancel_request()
	var system_prompt: String = GameDataManager.prompt_manager.build_emotion_prompt(GameDataManager.profile)
	var api_messages = [
		{"role": "system", "content": system_prompt},
		{"role": "user", "content": last_ai_reply}
	]
	var body = {
		"model": client.get_chat_model_id(),
		"messages": api_messages,
		"temperature": 0.7,
		"max_tokens": 150
	}
	if client.emotion_http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		client.emotion_http.cancel_request()
	client.emotion_http.request(client._get_url(), client._get_headers(), HTTPClient.METHOD_POST, JSON.stringify(body))

func _resolve_target_memory_manager(memory_manager_override = null):
	if memory_manager_override != null:
		return memory_manager_override
	return GameDataManager.memory_manager

func set_next_memory_context(client, memory_context: Dictionary = {}, memory_manager_override = null) -> void:
	client._pending_memory_context = memory_context.duplicate(true)
	client._pending_memory_manager_override = memory_manager_override

func prepare_memory_request_context(client, memory_context: Dictionary = {}, memory_manager_override = null) -> void:
	if not memory_context.is_empty():
		client._active_memory_context = memory_context.duplicate(true)
	else:
		client._active_memory_context = client._pending_memory_context.duplicate(true)
	if memory_manager_override != null:
		client._active_memory_manager_override = memory_manager_override
	else:
		client._active_memory_manager_override = client._pending_memory_manager_override
	client._pending_memory_context = {}
	client._pending_memory_manager_override = null

func clear_memory_request_context(client) -> void:
	client._pending_memory_context = {}
	client._active_memory_context = {}
	client._pending_memory_manager_override = null
	client._active_memory_manager_override = null

func send_memory_extraction(client, history_type: String = "story_chat", memory_manager_override = null) -> void:
	var history_text: String = ""
	var history_msgs = GameDataManager.history.get_messages_by_type(history_type)
	var start_idx: int = max(0, history_msgs.size() - 20)
	var bbcode_regex := RegEx.new()
	bbcode_regex.compile("\\[/?color.*?\\]")
	for i in range(start_idx, history_msgs.size()):
		var msg = history_msgs[i]
		var clean_text: String = bbcode_regex.sub(msg["text"], "", true)
		history_text += msg["speaker"] + ": " + clean_text + "\n"
	var target_memory_manager = _resolve_target_memory_manager(memory_manager_override)
	_enqueue_memory_task(client, "history", {"history_text": history_text}, {}, target_memory_manager)

func extract_memory_from_chat(client, user_text: String, ai_reply: String, memory_context: Dictionary = {}, memory_manager_override = null) -> void:
	var target_memory_manager = _resolve_target_memory_manager(memory_manager_override)
	_enqueue_memory_task(client, "exchange", {
		"user_text": user_text,
		"ai_reply": ai_reply
	}, memory_context, target_memory_manager)

func _enqueue_memory_task(client, task_type: String, payload: Dictionary, memory_context: Dictionary, target_memory_manager) -> void:
	if GameDataManager.cognition_task_queue == null:
		return
	var memory_domain: String = str(target_memory_manager.get_memory_domain()) if target_memory_manager and target_memory_manager.has_method("get_memory_domain") else MemoryManager.MEMORY_DOMAIN_PLAYER
	GameDataManager.cognition_task_queue.enqueue(task_type, payload, memory_domain, memory_context)
	process_cognition_queue(client)

func process_cognition_queue(client) -> void:
	if not client.is_inside_tree() or client._active_cognition_task_id != "":
		return
	var local_task: Dictionary = GameDataManager.cognition_task_queue.claim_next_local()
	if not local_task.is_empty():
		_process_local_cognition_task(client, local_task)
		return
	if client.memory_http == null or client.memory_http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return
	if client._uses_official_ai() and not await OfficialAuthManager.ensure_valid_access_token():
		_schedule_queue_retry(client, 30)
		return
	if client._is_api_key_empty():
		_schedule_queue_retry(client, 30)
		return
	var task: Dictionary = GameDataManager.cognition_task_queue.claim_next()
	if task.is_empty():
		var wait_seconds: int = int(GameDataManager.cognition_task_queue.get_seconds_until_next_pending())
		if wait_seconds >= 0:
			_schedule_queue_retry(client, maxi(1, wait_seconds))
		return
	client._active_cognition_task_id = str(task["id"])
	client._active_cognition_task = task.duplicate(true)
	client._active_cognition_task_scope = {
		"archive_id": str(task.get("archive_id", "")),
		"character_id": str(task.get("character_id", ""))
	}
	client._active_memory_context = Dictionary(task.get("memory_context", {})).duplicate(true)
	client._active_memory_manager_override = GameDataManager.cognition_task_queue.resolve_memory_manager(str(task.get("memory_domain", "")))
	var request_error := _send_cognition_task(client, task)
	if request_error != OK:
		_fail_active_task(client, "网络请求发送失败: %s" % request_error)

func _process_local_cognition_task(client, task: Dictionary) -> void:
	client._active_cognition_task_id = str(task.get("id", ""))
	client._active_cognition_task = task.duplicate(true)
	client._active_cognition_task_scope = {
		"archive_id": str(task.get("archive_id", "")),
		"character_id": str(task.get("character_id", ""))
	}
	if not _active_task_matches_current_scope(client):
		_fail_active_task(client, "本地认知任务作用域已失效")
		return
	var target_memory_manager = GameDataManager.cognition_task_queue.resolve_memory_manager(str(task.get("memory_domain", "")))
	var payload: Dictionary = task.get("payload", {})
	var succeeded := false
	if str(task.get("type", "")) == "memory_edit" and target_memory_manager and target_memory_manager.has_method("update_memory_queued"):
		succeeded = target_memory_manager.update_memory_queued(
			str(payload.get("layer", "")),
			str(payload.get("memory_id", "")),
			str(payload.get("content", "")),
			payload.get("revision_source", {}) if payload.get("revision_source", {}) is Dictionary else {}
		)
	if succeeded:
		GameDataManager.cognition_task_queue.complete(client._active_cognition_task_id)
		client.memory_request_completed.emit({"memory_edited": true, "memory_id": str(payload.get("memory_id", ""))})
		_finish_active_task(client)
		return
	_fail_active_task(client, "本地记忆编辑失败")

func _send_cognition_task(client, task: Dictionary) -> int:
	if str(task.get("type", "")) == "conversation_summary":
		return _send_conversation_summary_task(client, task)
	if str(task.get("type", "")) == "habit_cluster_summary":
		return _send_habit_cluster_summary_task(client, task)
	var target_memory_manager = client._active_memory_manager_override
	var system_prompt: String = GameDataManager.prompt_manager.build_memory_prompt(GameDataManager.profile, target_memory_manager)
	var char_name: String = GameDataManager.profile.char_name
	if char_name == "":
		char_name = "AI"
	var payload: Dictionary = task.get("payload", {})
	var safe_user_prompt: String
	if str(task.get("type", "")) == "history":
		safe_user_prompt = "以下是最近的对话记录：\n" + str(payload.get("history_text", ""))
	else:
		safe_user_prompt = "以下是一次对话交换：\n玩家: " + str(payload.get("user_text", "")) + "\n" + char_name + ": " + str(payload.get("ai_reply", ""))
	safe_user_prompt += "\n\n【系统强制指令：请作为专业的记忆提取系统，严格按照规定的 JSON 格式输出操作数组。如果没有需要提取的记忆，请输出空的 operations 数组。绝对不要进行角色扮演！不要回复任何对话！】"
	var api_messages = [
		{"role": "system", "content": system_prompt},
		{"role": "user", "content": safe_user_prompt}
	]
	var body = {
		"model": client.get_chat_model_id(),
		"messages": api_messages,
		"temperature": 0.1,
		"max_tokens": 200
	}
	body["response_format"] = {"type": "json_object"}
	return client.memory_http.request(client._get_url(), client._get_headers(), HTTPClient.METHOD_POST, JSON.stringify(body))

func _send_habit_cluster_summary_task(client, task: Dictionary) -> int:
	var payload: Dictionary = task.get("payload", {})
	var member_lines: Array[String] = []
	var members: Variant = payload.get("members", [])
	if members is Array:
		for member in members:
			if member is Dictionary:
				member_lines.append("[%s] %s" % [str(member.get("id", "")), str(member.get("content", ""))])
	var system_prompt := "你是玩家习惯记忆压缩系统。只总结输入中重复表达的共同习惯，不得添加输入中不存在的事实、原因、时间、地点、情绪或关系判断。存在冲突或无法忠实合并时返回空摘要。仅输出 JSON：{\"summary\":\"...\"}。摘要使用中文，不超过 %d 字。" % MemoryManager.HABIT_CLUSTER_SUMMARY_MAX_CHARS
	var body := {
		"model": client.get_chat_model_id(),
		"messages": [
			{"role": "system", "content": system_prompt},
			{"role": "user", "content": "以下是同一习惯聚类的原始成员：\n%s" % "\n".join(member_lines)}
		],
		"temperature": 0.0,
		"max_tokens": 500,
		"response_format": {"type": "json_object"}
	}
	return client.memory_http.request(client._get_url(), client._get_headers(), HTTPClient.METHOD_POST, JSON.stringify(body))

func _send_conversation_summary_task(client, task: Dictionary) -> int:
	var payload: Dictionary = task.get("payload", {})
	var previous_summary := str(payload.get("previous_summary", "")).strip_edges()
	var message_lines: Array[String] = []
	var messages: Variant = payload.get("messages", [])
	if messages is Array:
		for message in messages:
			if message is Dictionary:
				message_lines.append("%s: %s" % [str(message.get("speaker", "")), str(message.get("text", ""))])
	var system_prompt := "你是长期对话摘要系统。请把旧摘要和新增对话合并成忠实、紧凑、可供后续角色对话使用的中文摘要。保留玩家偏好、关系变化、约定、未解决话题和关键事件；不得编造，不得角色扮演。仅输出 JSON：{\"summary\":\"...\"}。"
	var user_prompt := "旧摘要：\n%s\n\n新增对话：\n%s" % [previous_summary if not previous_summary.is_empty() else "（无）", "\n".join(message_lines)]
	var body := {
		"model": client.get_chat_model_id(),
		"messages": [
			{"role": "system", "content": system_prompt},
			{"role": "user", "content": user_prompt}
		],
		"temperature": 0.1,
		"max_tokens": 700,
		"response_format": {"type": "json_object"}
	}
	return client.memory_http.request(client._get_url(), client._get_headers(), HTTPClient.METHOD_POST, JSON.stringify(body))

func handle_memory_completed(client, result: int, response_code: int, body: PackedByteArray) -> void:
	if not _active_task_matches_current_scope(client):
		_finish_active_task(client)
		return
	if str(client._active_cognition_task.get("type", "")) == "conversation_summary":
		_handle_summary_completed(client, result, response_code, body)
		return
	if str(client._active_cognition_task.get("type", "")) == "habit_cluster_summary":
		_handle_habit_cluster_summary_completed(client, result, response_code, body)
		return
	var request_memory_context: Dictionary = client._active_memory_context.duplicate(true)
	var target_memory_manager = _resolve_target_memory_manager(client._active_memory_manager_override)
	var operations_applied := false
	var failure_message := _get_memory_failure_message(result, response_code)
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		var json := JSON.new()
		if json.parse(body.get_string_from_utf8()) == OK:
			var response_data: Variant = json.get_data()
			if response_data is Dictionary and response_data.has("choices") and response_data["choices"].size() > 0:
				var first_choice: Variant = response_data["choices"][0]
				if not first_choice is Dictionary:
					_fail_active_task(client, "记忆提取响应缺少有效 choice")
					return
				var message: Variant = first_choice.get("message", {})
				if not message is Dictionary or not message.has("content"):
					_fail_active_task(client, "记忆提取响应缺少消息内容")
					return
				var reply: String = str(message.get("content", "")).strip_edges()
				print("\n========== [Memory Agent Output] ==========")
				print(reply)
				print("===========================================\n")
				var json_str: String = reply
				var regex := RegEx.new()
				regex.compile("```(?:json)?\\s*(\\{[\\s\\S]*?\\})\\s*```")
				var match := regex.search(reply)
				if match:
					json_str = match.get_string(1).strip_edges()
				else:
					var start_idx: int = reply.find("{")
					var end_idx: int = reply.rfind("}")
					if start_idx != -1 and end_idx != -1 and end_idx > start_idx:
						json_str = reply.substr(start_idx, end_idx - start_idx + 1)
				if json_str != "" and json_str != "无新增记忆":
					var parse_json := JSON.new()
					if parse_json.parse(json_str) == OK:
						var data: Variant = parse_json.get_data()
						if data is Dictionary and data.has("operations") and data["operations"] is Array:
							operations_applied = true
							var plain_text_changes: String = ""
							for op in data["operations"]:
								if not op is Dictionary or not op.has("action") or not op.has("layer"):
									continue
								var action = op["action"]
								var layer = op["layer"]
								var content = op.get("content", "")
								var id = op.get("id", "")
								if action == "ADD":
									var memory_options := _build_memory_options_from_operation(op, target_memory_manager)
									var supersedes_id := str(op.get("supersedes_id", "")).strip_edges()
									if not supersedes_id.is_empty() and target_memory_manager.has_method("supersede_memory"):
										if target_memory_manager.supersede_memory(layer, supersedes_id, content, request_memory_context, memory_options):
											plain_text_changes += "合并冲突记忆: %s\n" % content
										else:
											target_memory_manager.add_memory_quick(layer, content, request_memory_context, memory_options)
											plain_text_changes += "新增记忆: %s\n" % content
									else:
										target_memory_manager.add_memory_quick(layer, content, request_memory_context, memory_options)
										plain_text_changes += "新增记忆: %s\n" % content
								elif action == "UPDATE":
									var success = await target_memory_manager.update_memory(layer, id, content, request_memory_context)
									if success:
										plain_text_changes += "更新记忆: %s\n" % content
								elif action == "DELETE":
									if target_memory_manager.delete_memory(layer, id):
										plain_text_changes += "删除记忆 [%s]\n" % id
							if plain_text_changes != "":
								print("记忆系统更新: ", plain_text_changes.strip_edges())
					else:
						print("Memory Agent 无法解析JSON: ", parse_json.get_error_message())
	if operations_applied:
		GameDataManager.cognition_task_queue.complete(client._active_cognition_task_id)
		client.memory_request_completed.emit({"operations_applied": true})
		_finish_active_task(client)
		return
	if failure_message.is_empty():
		failure_message = "记忆提取响应格式无效"
	_fail_active_task(client, failure_message)

func _handle_summary_completed(client, result: int, response_code: int, body: PackedByteArray) -> void:
	var failure_message := _get_memory_failure_message(result, response_code)
	if failure_message.is_empty():
		var response: Variant = JSON.parse_string(body.get_string_from_utf8())
		if response is Dictionary:
			var choices: Variant = response.get("choices", [])
			if choices is Array and not choices.is_empty() and choices[0] is Dictionary:
				var message: Variant = choices[0].get("message", {})
				if message is Dictionary:
					var content: Variant = JSON.parse_string(str(message.get("content", "")))
					if content is Dictionary:
						var summary := str(content.get("summary", "")).strip_edges()
						if not summary.is_empty():
							var payload: Dictionary = client._active_cognition_task.get("payload", {})
							var channel := str(payload.get("channel", ""))
							var covered_count := int(payload.get("covered_message_count", 0))
							if GameDataManager.conversation_summary_manager.apply_summary(channel, summary, covered_count, client._active_cognition_task_id):
								GameDataManager.cognition_task_queue.complete(client._active_cognition_task_id)
								client.memory_request_completed.emit({"summary_updated": true, "channel": channel})
								_finish_active_task(client)
								GameDataManager.conversation_summary_manager.queue_summary_if_needed(channel)
								return
	if failure_message.is_empty():
		failure_message = "对话摘要响应格式无效"
	_fail_active_task(client, failure_message)

func _handle_habit_cluster_summary_completed(client, result: int, response_code: int, body: PackedByteArray) -> void:
	var failure_message := _get_memory_failure_message(result, response_code)
	if failure_message.is_empty():
		var response: Variant = JSON.parse_string(body.get_string_from_utf8())
		if response is Dictionary:
			var choices: Variant = response.get("choices", [])
			if choices is Array and not choices.is_empty() and choices[0] is Dictionary:
				var message: Variant = choices[0].get("message", {})
				if message is Dictionary:
					var content: Variant = JSON.parse_string(str(message.get("content", "")))
					if content is Dictionary:
						var summary := str(content.get("summary", "")).strip_edges()
						var payload: Dictionary = client._active_cognition_task.get("payload", {})
						var target_memory_manager = _resolve_target_memory_manager(client._active_memory_manager_override)
						if not summary.is_empty() and target_memory_manager and target_memory_manager.has_method("propose_habit_cluster_summary") and target_memory_manager.propose_habit_cluster_summary(
							str(payload.get("cluster_id", "")),
							payload.get("member_memory_ids", []) if payload.get("member_memory_ids", []) is Array else [],
							str(payload.get("snapshot_hash", "")),
							summary,
							{"model": client.get_chat_model_id()}
						):
							GameDataManager.cognition_task_queue.complete(client._active_cognition_task_id)
							client.memory_request_completed.emit({"habit_cluster_summary_proposed": true, "cluster_id": str(payload.get("cluster_id", ""))})
							_finish_active_task(client)
							return
	if failure_message.is_empty():
		failure_message = "习惯聚类摘要响应无效或成员快照已过期"
	_fail_active_task(client, failure_message)

func _get_memory_failure_message(result: int, response_code: int) -> String:
	if result == HTTPRequest.RESULT_TIMEOUT or response_code == 0:
		return "记忆提取请求超时"
	if response_code != 200:
		return "记忆提取 API 请求错误，状态码: %d" % response_code
	return ""

func _fail_active_task(client, error_message: String) -> void:
	if not client._active_cognition_task_id.is_empty():
		GameDataManager.cognition_task_queue.fail(client._active_cognition_task_id, error_message)
		var failed_task: Dictionary = GameDataManager.cognition_task_queue.get_task(client._active_cognition_task_id)
		if str(failed_task.get("state", "")) == "failed" and str(client._active_cognition_task.get("type", "")) == "conversation_summary":
			var payload: Dictionary = client._active_cognition_task.get("payload", {})
			GameDataManager.conversation_summary_manager.release_pending_task(str(payload.get("channel", "")), client._active_cognition_task_id)
	client.memory_request_failed.emit(error_message)
	_finish_active_task(client)

func _finish_active_task(client) -> void:
	client._active_cognition_task_id = ""
	client._active_cognition_task_scope = {}
	client._active_cognition_task = {}
	clear_memory_request_context(client)
	process_cognition_queue(client)

func _active_task_matches_current_scope(client) -> bool:
	var scope: Dictionary = client._active_cognition_task_scope
	if scope.is_empty():
		return false
	var current_character_id := str(GameDataManager.config.current_character_id) if GameDataManager.config else "default"
	return str(scope.get("archive_id", "")) == GameDataManager.get_active_archive_id() \
		and str(scope.get("character_id", "")) == current_character_id

func _schedule_queue_retry(client, delay_seconds: int) -> void:
	if client._cognition_retry_timer != null:
		return
	client._cognition_retry_timer = client.get_tree().create_timer(float(delay_seconds))
	client._cognition_retry_timer.timeout.connect(func() -> void:
		client._cognition_retry_timer = null
		process_cognition_queue(client)
	, CONNECT_ONE_SHOT)

func _build_memory_options_from_operation(op: Dictionary, target_memory_manager) -> Dictionary:
	var default_scope = target_memory_manager.get_default_memory_scope() if target_memory_manager and target_memory_manager.has_method("get_default_memory_scope") else "player_shared"
	var default_visibility = target_memory_manager.get_default_memory_visibility() if target_memory_manager and target_memory_manager.has_method("get_default_memory_visibility") else "prompt"
	var default_domain = target_memory_manager.get_memory_domain() if target_memory_manager and target_memory_manager.has_method("get_memory_domain") else "player_memory"
	return {
		"is_bond_mark": bool(op.get("is_bond_mark", str(op.get("layer", "")) == "bond")),
		"source_type": str(op.get("source_type", "chat_extraction")),
		"source_id": str(op.get("source_id", "")),
		"source_title": str(op.get("source_title", "AI 对话提取")),
		"memory_domain": str(op.get("memory_domain", default_domain)),
		"memory_scope": str(op.get("memory_scope", default_scope)),
		"memory_visibility": str(op.get("memory_visibility", default_visibility)),
		"memory_participants": op.get("memory_participants", ["player"]),
		"memory_player_involved": bool(op.get("memory_player_involved", true)),
		"memory_player_witnessed": bool(op.get("memory_player_witnessed", true)),
		"emotion_tags": op.get("emotion_tags", []) if op.get("emotion_tags", []) is Array else []
	}
