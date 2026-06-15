extends RefCounted

func send_narrator_generation(client) -> void:
	while not client.is_inside_tree():
		await Engine.get_main_loop().process_frame
	var profile = GameDataManager.profile
	var history_text: String = ""
	var history_msgs = GameDataManager.history.get_messages_by_type("story_chat")
	var start_idx: int = max(0, history_msgs.size() - 5)
	for i in range(start_idx, history_msgs.size()):
		var msg = history_msgs[i]
		history_text += msg["speaker"] + ": " + msg["text"] + "\n"
	var system_prompt: String = GameDataManager.prompt_manager.build_narrator_prompt(profile, history_text)
	if system_prompt == "":
		client.narrator_request_failed.emit("无法构建旁白提示词")
		return
	var api_messages = [
		{"role": "system", "content": system_prompt},
		{"role": "user", "content": "请生成进入场景时的旁白"}
	]
	var body = {
		"model": client.get_chat_model_id(),
		"messages": api_messages,
		"temperature": 0.7,
		"max_tokens": 100
	}
	if client.narrator_http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		client.narrator_http.cancel_request()
	client.narrator_http.request(client._get_url(), client._get_headers(), HTTPClient.METHOD_POST, JSON.stringify(body))

func send_character_mood_analysis(client, character_message: String) -> void:
	while not client.is_inside_tree():
		await Engine.get_main_loop().process_frame
	var system_prompt: String = GameDataManager.prompt_manager.build_character_mood_prompt(character_message)
	var api_messages = [{"role": "system", "content": system_prompt}]
	var body = {
		"model": client.get_chat_model_id(),
		"messages": api_messages,
		"temperature": 0.1,
		"max_tokens": 100
	}
	body["response_format"] = {"type": "json_object"}
	if client.character_mood_http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		client.character_mood_http.cancel_request()
	client.character_mood_http.request(client._get_url(), client._get_headers(), HTTPClient.METHOD_POST, JSON.stringify(body))

func analyze_mood_sync(client, character_message: String) -> String:
	while not client.is_inside_tree():
		await Engine.get_main_loop().process_frame
	var system_prompt: String = GameDataManager.prompt_manager.build_character_mood_prompt(character_message)
	var api_messages = [{"role": "system", "content": system_prompt}]
	var body = {
		"model": client.get_chat_model_id(),
		"messages": api_messages,
		"temperature": 0.1,
		"max_tokens": 100
	}
	body["response_format"] = {"type": "json_object"}
	var http := HTTPRequest.new()
	http.timeout = 10.0
	client.add_child(http)
	http.request(client._get_url(), client._get_headers(), HTTPClient.METHOD_POST, JSON.stringify(body))
	var result_array = await http.request_completed
	var result = result_array[0]
	var response_code = result_array[1]
	var response_body = result_array[3]
	http.queue_free()
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		var json := JSON.new()
		if json.parse(response_body.get_string_from_utf8()) == OK:
			var data: Variant = json.get_data()
			if data is Dictionary and data.has("choices") and data["choices"].size() > 0:
				var reply = data["choices"][0]["message"]["content"]
				print("\n========== [Character Mood Sync Output] ==========")
				print(reply)
				print("==================================================\n")
				var clean_reply: String = reply.strip_edges()
				if clean_reply.begins_with("```json"):
					clean_reply = clean_reply.replace("```json", "")
				if clean_reply.begins_with("```"):
					clean_reply = clean_reply.replace("```", "")
				if clean_reply.ends_with("```"):
					clean_reply = clean_reply.substr(0, clean_reply.length() - 3)
				clean_reply = clean_reply.strip_edges()
				var reply_json := JSON.new()
				var error: int = reply_json.parse(clean_reply)
				if error == OK:
					var reply_data: Variant = reply_json.get_data()
					if reply_data is Dictionary and reply_data.has("mood_id"):
						return reply_data["mood_id"]
				else:
					print("Character Mood Sync Failed: Inner JSON Parse Error (Code: ", error, ") - Text: ", clean_reply)
		else:
			print("Character Mood Sync Failed: Outer JSON Parse Error")
	else:
		print("Character Mood Sync HTTP Request Failed: Code ", response_code)
	return ""

func generate_dynamic_topics(client, prompt: String, callback: Callable) -> void:
	var request_data = {
		"model": client.get_chat_model_id(),
		"messages": [{"role": "user", "content": prompt}],
		"temperature": 0.7,
		"max_tokens": 150
	}
	var http_request := HTTPRequest.new()
	client.add_child(http_request)
	http_request.request_completed.connect(func(result, response_code, _headers_arr, body):
		http_request.queue_free()
		if response_code == 200:
			var json := JSON.new()
			if json.parse(body.get_string_from_utf8()) == OK:
				var res_data: Variant = json.get_data()
				if res_data.has("choices") and res_data["choices"].size() > 0:
					var text = res_data["choices"][0]["message"]["content"]
					callback.call(text)
					return
		callback.call("")
	)
	var err: int = http_request.request(client._get_url(), client._get_headers(), HTTPClient.METHOD_POST, JSON.stringify(request_data))
	if err != OK:
		http_request.queue_free()
		callback.call("")

func generate_npc_event_dialogue(client, npc_id: String, event_desc: String) -> void:
	while not client.is_inside_tree():
		await Engine.get_main_loop().process_frame
	if client.npc_event_http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		client.npc_event_http.cancel_request()
	var npc_name: String = "未知NPC"
	var personality: String = "普通"
	var stage: int = 1
	var stage_title: String = "初识"
	var npc_file: FileAccess = FileAccess.open("res://assets/data/characters/npc/" + npc_id + ".json", FileAccess.READ)
	if npc_file:
		var json := JSON.new()
		if json.parse(npc_file.get_as_text()) == OK:
			var data: Variant = json.get_data()
			npc_name = data.get("char_name", npc_id)
			if data.has("base_personality"):
				personality = data["base_personality"].get("core_traits", "") + " " + data["base_personality"].get("dialogue_style", "")
	if GameDataManager.profile.current_character_id == npc_id:
		stage = GameDataManager.profile.current_stage
		stage_title = GameDataManager.profile.get_current_stage_config().get("stageTitle", "未知")
	else:
		var stages_file: FileAccess = FileAccess.open("res://assets/data/characters/npc/" + npc_id + "_stages.json", FileAccess.READ)
		if stages_file:
			var stages_json := JSON.new()
			if stages_json.parse(stages_file.get_as_text()) == OK:
				var stage_data: Variant = stages_json.get_data()
				if stage_data.has("stages") and stage_data["stages"].size() > 0:
					stage_title = stage_data["stages"][0].get("stageTitle", "未知")
	var protagonist_name: String = GameDataManager.profile.char_name
	if protagonist_name.is_empty():
		protagonist_name = "Luna"
	var intimacy: float = 0.0
	var trust: float = 0.0
	if GameDataManager.profile.current_character_id == npc_id:
		intimacy = GameDataManager.profile.intimacy
		trust = GameDataManager.profile.trust
	else:
		var npc_rel = GameDataManager.npc_relationship_manager
		if npc_rel:
			intimacy = npc_rel.get_intimacy(npc_id)
			trust = npc_rel.get_trust(npc_id)
	var system_prompt: String = GameDataManager.prompt_manager.build_npc_event_prompt(npc_name, personality, protagonist_name, stage, stage_title, event_desc, intimacy, trust)
	if system_prompt.is_empty():
		system_prompt = "【系统设定】\n你扮演的角色是：%s。\n你的性格特征和说话风格是：%s。\n注意：在这个世界里，你现在面对的是游戏世界中的少女【%s】。\n你当前与少女【%s】的情感关系处于【阶段%d：%s】（亲密度：%.1f，信任度：%.1f）。请严格根据这个情感状态对她表现出相应的态度。\n\n【当前事件】\n%s\n\n【任务要求】\n请结合你的性格、情感阶段以及当前发生的事件，作出非常符合你人设的回复。注意：\n1. 所有的动作、神态、心理描写，必须且只能使用全角或半角的圆括号 () 包裹。\n2. 绝对禁止使用星号 *、中括号 []、波浪号 ~ 等其他任何符号来表示动作或情绪。\n3. 直接输出台词和圆括号动作，不要包含任何旁白。\n4. 语气必须严格符合当前对【%s】的情感状态，且符合现代日常世界观（不要出现魔幻、修仙、系统、穿越等出戏话题）。\n5. 回复可以是多句话，以表达完整的情感和意思，如果有多句可以自然换行。像游戏里的即时互动反馈一样自然流畅。" % [npc_name, personality, protagonist_name, protagonist_name, stage, stage_title, intimacy, trust, event_desc, protagonist_name]
	var api_messages = [{"role": "system", "content": system_prompt}]
	var body = {
		"model": client.get_chat_model_id(),
		"messages": api_messages,
		"temperature": 0.7,
		"max_tokens": 500
	}
	if client.npc_event_http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		client.npc_event_http.cancel_request()
	client.npc_event_http.request(client._get_url(), client._get_headers(), HTTPClient.METHOD_POST, JSON.stringify(body))

func handle_npc_event_completed(client, response_code: int, body: PackedByteArray) -> void:
	if response_code == 200:
		var json := JSON.new()
		if json.parse(body.get_string_from_utf8()) == OK:
			var data: Variant = json.get_data()
			if typeof(data) == TYPE_DICTIONARY and data.has("choices") and data["choices"].size() > 0:
				var choice = data["choices"][0]
				if choice.has("message") and choice["message"].has("content"):
					var content: String = choice["message"]["content"].strip_edges()
					if content.is_empty() and choice["message"].has("reasoning_content"):
						client.npc_event_dialogue_completed.emit("（微笑着，没有说话）")
					else:
						client.npc_event_dialogue_completed.emit(content)
					return
	client.npc_event_dialogue_failed.emit("NPC 事件台词获取失败 (Code: %d)" % response_code)
