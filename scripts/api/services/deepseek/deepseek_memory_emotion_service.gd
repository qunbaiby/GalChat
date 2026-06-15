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

func set_next_memory_context(client, memory_context: Dictionary = {}) -> void:
	client._pending_memory_context = memory_context.duplicate(true)

func prepare_memory_request_context(client, memory_context: Dictionary = {}) -> void:
	if not memory_context.is_empty():
		client._active_memory_context = memory_context.duplicate(true)
	else:
		client._active_memory_context = client._pending_memory_context.duplicate(true)
	client._pending_memory_context = {}

func clear_memory_request_context(client) -> void:
	client._pending_memory_context = {}
	client._active_memory_context = {}

func send_memory_extraction(client, history_type: String = "story_chat") -> void:
	if not client.is_inside_tree() or client._is_api_key_empty():
		return
	prepare_memory_request_context(client)
	var system_prompt: String = GameDataManager.prompt_manager.build_memory_prompt(GameDataManager.profile)
	var history_text: String = ""
	var history_msgs = GameDataManager.history.get_messages_by_type(history_type)
	var start_idx: int = max(0, history_msgs.size() - 20)
	var bbcode_regex := RegEx.new()
	bbcode_regex.compile("\\[/?color.*?\\]")
	for i in range(start_idx, history_msgs.size()):
		var msg = history_msgs[i]
		var clean_text: String = bbcode_regex.sub(msg["text"], "", true)
		history_text += msg["speaker"] + ": " + clean_text + "\n"
	var safe_user_prompt: String = "以下是最近的对话记录：\n" + history_text + "\n\n【系统强制指令：请作为专业的记忆提取系统，严格按照规定的 JSON 格式输出操作数组。如果没有需要提取的记忆，请输出空的 operations 数组。绝对不要进行角色扮演！不要回复任何对话！】"
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
	if client.memory_http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		client.memory_http.cancel_request()
	var err: int = client.memory_http.request(client._get_url(), client._get_headers(), HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		clear_memory_request_context(client)
		client.memory_request_failed.emit("网络请求发送失败: " + str(err))

func extract_memory_from_chat(client, user_text: String, ai_reply: String, memory_context: Dictionary = {}) -> void:
	if not client.is_inside_tree() or client._is_api_key_empty():
		return
	if client.memory_http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		client.memory_http.cancel_request()
	prepare_memory_request_context(client, memory_context)
	var system_prompt: String = GameDataManager.prompt_manager.build_memory_prompt(GameDataManager.profile)
	var char_name: String = GameDataManager.profile.char_name
	if char_name == "":
		char_name = "AI"
	var safe_user_prompt: String = "以下是一次对话交换：\n玩家: " + user_text + "\n" + char_name + ": " + ai_reply + "\n\n【系统强制指令：请作为专业的记忆提取系统，严格按照规定的 JSON 格式输出操作数组。如果没有需要提取的记忆，请输出空的 operations 数组。绝对不要进行角色扮演！不要回复任何对话！】"
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
	var err: int = client.memory_http.request(client._get_url(), client._get_headers(), HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		clear_memory_request_context(client)
		client.memory_request_failed.emit("网络请求发送失败: " + str(err))

func handle_memory_completed(client, result: int, response_code: int, body: PackedByteArray) -> void:
	var request_memory_context: Dictionary = client._active_memory_context.duplicate(true)
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		var json := JSON.new()
		if json.parse(body.get_string_from_utf8()) == OK:
			var response_data: Variant = json.get_data()
			if response_data is Dictionary and response_data.has("choices") and response_data["choices"].size() > 0:
				var reply: String = response_data["choices"][0]["message"]["content"].strip_edges()
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
							var plain_text_changes: String = ""
							for op in data["operations"]:
								if not op is Dictionary or not op.has("action") or not op.has("layer"):
									continue
								var action = op["action"]
								var layer = op["layer"]
								var content = op.get("content", "")
								var id = op.get("id", "")
								if action == "ADD":
									await GameDataManager.memory_manager.add_memory(layer, content, request_memory_context)
									plain_text_changes += "新增记忆: %s\n" % content
								elif action == "UPDATE":
									var success = await GameDataManager.memory_manager.update_memory(layer, id, content, request_memory_context)
									if success:
										plain_text_changes += "更新记忆: %s\n" % content
								elif action == "DELETE":
									if GameDataManager.memory_manager.delete_memory(layer, id):
										plain_text_changes += "删除记忆 [%s]\n" % id
							if plain_text_changes != "":
								print("记忆系统更新: ", plain_text_changes.strip_edges())
					else:
						print("Memory Agent 无法解析JSON: ", parse_json.get_error_message())
	clear_memory_request_context(client)
	client._handle_response(result, response_code, body, client.memory_request_completed, client.memory_request_failed)
