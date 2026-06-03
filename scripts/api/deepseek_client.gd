extends Node
class_name DeepSeekClient

signal chat_request_completed(response: Dictionary)
signal chat_request_failed(error_message: String)
signal chat_stream_delta(delta_text: String)
signal chat_stream_started()

signal emotion_request_completed(response: Dictionary)
signal emotion_request_failed(error_message: String)

signal memory_request_completed(response: Dictionary)
signal memory_request_failed(error_message: String)

signal options_request_completed(response: Dictionary)
signal options_request_failed(error_message: String)

signal narrator_request_completed(response: Dictionary)
signal narrator_request_failed(error_message: String)

signal character_mood_request_completed(response: Dictionary)
signal character_mood_request_failed(error_message: String)

signal npc_event_dialogue_completed(dialogue: String)
signal npc_event_dialogue_failed(error_message: String)

signal diary_generated(diary_entry: Dictionary)
signal diary_error(error_msg: String)

signal vision_request_completed(response: Dictionary)
signal vision_request_failed(error_message: String)

signal moment_generated(moment_data: Dictionary)
signal moment_error(error_msg: String)
signal moment_reply_generated(post_id: String, reply_text: String)
signal moment_reply_error(error_msg: String)

signal schedule_event_generated(event_data: Dictionary)
signal schedule_event_error(error_msg: String)
signal schedule_event_resolved(result_data: Dictionary)
signal schedule_event_resolve_error(error_msg: String)

signal image_to_image_completed(image_path: String)
signal image_to_image_failed(error_message: String)

var chat_http: HTTPRequest
var emotion_http: HTTPRequest
var memory_http: HTTPRequest
var options_http: HTTPRequest
var narrator_http: HTTPRequest
var character_mood_http: HTTPRequest
var npc_event_http: HTTPRequest
var diary_http: HTTPRequest
var vision_http: HTTPRequest
var moment_http: HTTPRequest
var moment_reply_http: HTTPRequest
var schedule_event_http: HTTPRequest
var schedule_resolve_http: HTTPRequest

var _chat_stream_client: HTTPClient
var _chat_stream_active: bool = false
var _chat_stream_request_sent: bool = false
var _chat_stream_body: String = ""
var _chat_stream_headers: Array = []
var _chat_stream_sse_buffer: String = ""
var _chat_stream_full_text: String = ""
var _chat_stream_response_code: int = 0
var _current_moment_reply_post_id: String = ""
var _pending_memory_context: Dictionary = {}
var _active_memory_context: Dictionary = {}

func _ready() -> void:
	_update_script()
	_reinitialize_http_nodes()

func _update_script() -> void:
	if GameDataManager.config.model.begins_with("doubao"):
		if get_script() != preload("res://scripts/api/doubao_chat_client.gd"):
			set_script(preload("res://scripts/api/doubao_chat_client.gd"))
			_reinitialize_http_nodes()
	else:
		if get_script() != preload("res://scripts/api/deepseek_client.gd"):
			set_script(preload("res://scripts/api/deepseek_client.gd"))
			_reinitialize_http_nodes()

func _reinitialize_http_nodes() -> void:
	if not is_inside_tree():
		return
		
	# Helper function to create or reset an HTTPRequest node
	var reset_node = func(node_name: String, timeout_val: float, signal_name: String, callback_name: String) -> HTTPRequest:
		var node = get_node_or_null(node_name)
		if node != null:
			if node.is_connected("request_completed", Callable(self, callback_name)):
				node.disconnect("request_completed", Callable(self, callback_name))
		else:
			node = HTTPRequest.new()
			node.name = node_name
			add_child(node)
			
		node.timeout = timeout_val
		if not node.is_connected("request_completed", Callable(self, callback_name)):
			node.request_completed.connect(Callable(self, callback_name))
		return node

	chat_http = reset_node.call("ChatHTTP", 60.0, "request_completed", "_on_chat_completed")
	emotion_http = reset_node.call("EmotionHTTP", 10.0, "request_completed", "_on_emotion_completed")
	memory_http = reset_node.call("MemoryHTTP", 10.0, "request_completed", "_on_memory_completed")
	options_http = reset_node.call("OptionsHTTP", 15.0, "request_completed", "_on_options_completed")
	narrator_http = reset_node.call("NarratorHTTP", 15.0, "request_completed", "_on_narrator_completed")
	character_mood_http = reset_node.call("CharacterMoodHTTP", 10.0, "request_completed", "_on_character_mood_completed")
	npc_event_http = reset_node.call("NPCEventHTTP", 20.0, "request_completed", "_on_npc_event_completed")
	diary_http = reset_node.call("DiaryHTTP", 0.0, "request_completed", "_on_diary_request_completed")
	vision_http = reset_node.call("VisionHTTP", 30.0, "request_completed", "_on_vision_completed")
	moment_http = reset_node.call("MomentHTTP", 0.0, "request_completed", "_on_moment_request_completed")
	moment_reply_http = reset_node.call("MomentReplyHTTP", 15.0, "request_completed", "_on_moment_reply_request_completed")
	schedule_event_http = reset_node.call("ScheduleEventHTTP", 20.0, "request_completed", "_on_schedule_event_completed")
	schedule_resolve_http = reset_node.call("ScheduleResolveHTTP", 20.0, "request_completed", "_on_schedule_resolve_completed")

func _is_api_key_empty() -> bool:
	return GameDataManager.config.api_key.is_empty()

func _get_headers() -> Array:
	var api_key = GameDataManager.config.api_key
	return [
		"Content-Type: application/json",
		"Authorization: Bearer " + api_key
	]

func _get_url() -> String:
	return "https://api.deepseek.com/v1/chat/completions"

func _get_stream_host() -> String:
	return "api.deepseek.com"

func _get_stream_path() -> String:
	return "/v1/chat/completions"

func _get_history_messages(limit: int = 10, is_chat: bool = true, history_type: String = "all") -> Array:
	var api_messages = []
	var history_msgs = GameDataManager.history.get_messages_by_type(history_type)
	var start_idx = max(0, history_msgs.size() - limit)
	var bbcode_regex = RegEx.new()
	bbcode_regex.compile("\\[/?color.*?\\]")
	
	for i in range(start_idx, history_msgs.size()):
		var msg = history_msgs[i]
		var role = "user" if msg["speaker"] == "玩家" or msg["speaker"] == "我" else "assistant"
		var clean_text = bbcode_regex.sub(msg["text"], "", true)
		
		# 对最后一条历史记录打上强提示标记，确保AI的注意力集中在此
		if i == history_msgs.size() - 1 and is_chat:
			clean_text += " <--- 【系统提示：这是你们上次聊天的最后一句话，请顺着这个话题继续延展，不要生硬地开启新话题】"
			
		api_messages.append({"role": role, "content": clean_text})
	return api_messages

func send_chat_message(user_message: String, history_type: String = "all") -> void:
	_update_script()
	send_chat_message_stream(user_message, history_type)

func send_chat_message_stream(user_message: String, history_type: String = "all") -> void:
	_update_script()
	if not is_inside_tree() or _is_api_key_empty():
		chat_request_failed.emit("API Key未设置，请在设置界面配置。")
		return
		
	if _chat_stream_active:
		_stop_chat_stream()
	
	# 聊天首响应优先，避免因 embedding 请求阻塞主回复。
	# 当没有 query_embedding 时，记忆系统会退化到直接注入长期记忆摘要。
	var system_prompt = GameDataManager.prompt_manager.build_chat_prompt(GameDataManager.profile, user_message, [])
	var api_messages = [{"role": "system", "content": system_prompt}]
	api_messages.append_array(_get_history_messages(10, true, history_type))
	
	# Check if the last message is the exact same user message, to avoid duplication
	var should_append = true
	if api_messages.size() > 1:
		var last_msg = api_messages[api_messages.size() - 1]
		if last_msg is Dictionary and last_msg.get("role", "") == "user":
			var cleaned_content = str(last_msg.get("content", "")).replace(" <--- 【系统提示：这是你们上次聊天的最后一句话，请顺着这个话题继续延展，不要生硬地开启新话题】", "").strip_edges()
			if cleaned_content == user_message.strip_edges():
				should_append = false
				
	if should_append:
		api_messages.append({"role": "user", "content": user_message})
	
	_start_stream_request(api_messages)
	
	# Trigger emotion agent in parallel
	_send_emotion_analysis(user_message)



func send_vision_request(system_prompt: String, user_prompt: String, base64_image: String) -> void:
	if not is_inside_tree() or GameDataManager.config.vision_api_key.is_empty():
		vision_request_failed.emit("Vision API Key未设置，请在设置界面配置。")
		return
		
	var url = GameDataManager.config.vision_base_url
	if url.ends_with("/chat/completions"):
		url = url.replace("/chat/completions", "/responses")
	elif not url.ends_with("/responses"):
		url += "/responses"
		
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer " + GameDataManager.config.vision_api_key
	]
	
	var combined_prompt = system_prompt + "\n\n" + user_prompt
	
	var model_name = GameDataManager.config.vision_model
	if model_name.is_empty() or model_name == "ep-xxxxxx":
		model_name = "doubao-seed-2-0-mini-260428"
		
	var body = {
		"model": model_name,
		"input": [
			{
				"role": "user",
				"content": [
					{
						"type": "input_image",
						"image_url": "data:image/jpeg;base64," + base64_image
					},
					{
						"type": "input_text",
						"text": combined_prompt
					}
				]
			}
		]
	}
	
	if vision_http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		vision_http.cancel_request()
		
	vision_http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))

func _on_vision_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_handle_response(result, response_code, body, vision_request_completed, vision_request_failed)

func _start_stream_request(api_messages: Array) -> void:
	var body = {
		"model": GameDataManager.config.model,
		"messages": api_messages,
		"temperature": GameDataManager.config.temperature,
		"max_tokens": GameDataManager.config.max_tokens,
		"stream": true
	}
	
	_chat_stream_full_text = ""
	_chat_stream_sse_buffer = ""
	_chat_stream_request_sent = false
	_chat_stream_body = JSON.stringify(body)
	
	var host = _get_stream_host()
	
	_chat_stream_headers = [
		"Host: " + host,
		"Content-Type: application/json",
		"Authorization: " + _get_headers()[1].replace("Authorization: ", ""),
		"Accept: text/event-stream",
		"Connection: keep-alive"
	]
	
	_chat_stream_client = HTTPClient.new()
	var tls_options = TLSOptions.client()
	var err = _chat_stream_client.connect_to_host(host, 443, tls_options)
	if err != OK:
		_stop_chat_stream()
		chat_request_failed.emit("网络请求发送失败。")
		return
		
	_chat_stream_active = true
	set_process(true)
	chat_stream_started.emit()


func _send_emotion_analysis(user_message: String) -> void:
	_update_script()
	if not is_inside_tree() or _is_api_key_empty():
		return
		
	var system_prompt = GameDataManager.prompt_manager.build_emotion_prompt(GameDataManager.profile)
	# ONLY pass the system prompt and the latest user message. 
	# Do NOT pass the chat history to prevent the LLM from trying to roleplay.
	# 强制在 user message 前面加上警告，防止其被带偏进行角色扮演
	var safe_user_message = "【请作为分析系统，仅输出分析标签，绝对不要进行角色扮演，不要回复这句话：】" + user_message
	var api_messages = [
		{"role": "system", "content": system_prompt},
		{"role": "user", "content": safe_user_message}
	]
	
	var body = {
		"model": GameDataManager.config.model,
		"messages": api_messages,
		"temperature": 0.1, # Lower temperature for stable numerical output
		"max_tokens": 200
	}
	
	if emotion_http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		emotion_http.cancel_request()
		
	emotion_http.request(_get_url(), _get_headers(), HTTPClient.METHOD_POST, JSON.stringify(body))

func _send_memory_extraction(history_type: String = "story_chat") -> void:
	_update_script()
	if not is_inside_tree() or _is_api_key_empty():
		return
	_prepare_memory_request_context()
		
	var system_prompt = GameDataManager.prompt_manager.build_memory_prompt(GameDataManager.profile)
	
	# 将历史记录转化为纯文本传入，防止 AI 根据 role="assistant" 顺着往下进行角色扮演
	var history_text = ""
	var history_msgs = GameDataManager.history.get_messages_by_type(history_type)
	var start_idx = max(0, history_msgs.size() - 20)
	var bbcode_regex = RegEx.new()
	bbcode_regex.compile("\\[/?color.*?\\]")
	
	for i in range(start_idx, history_msgs.size()):
		var msg = history_msgs[i]
		var clean_text = bbcode_regex.sub(msg["text"], "", true)
		history_text += msg["speaker"] + ": " + clean_text + "\n"
		
	var safe_user_prompt = "以下是最近的对话记录：\n" + history_text + "\n\n【系统强制指令：请作为专业的记忆提取系统，严格按照规定的 JSON 格式输出操作数组。如果没有需要提取的记忆，请输出空的 operations 数组。绝对不要进行角色扮演！不要回复任何对话！】"
	
	var api_messages = [
		{"role": "system", "content": system_prompt},
		{"role": "user", "content": safe_user_prompt}
	]
	
	var body = {
		"model": GameDataManager.config.model,
		"messages": api_messages,
		"temperature": 0.1,
		"max_tokens": 200
	}
	
	if not GameDataManager.config.model.begins_with("doubao"):
		body["response_format"] = {"type": "json_object"}
	
	if memory_http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		memory_http.cancel_request()
		
	var err = memory_http.request(_get_url(), _get_headers(), HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		_clear_memory_request_context()
		memory_request_failed.emit("网络请求发送失败: " + str(err))

func set_next_memory_context(memory_context: Dictionary = {}) -> void:
	_pending_memory_context = memory_context.duplicate(true)

func _prepare_memory_request_context(memory_context: Dictionary = {}) -> void:
	if not memory_context.is_empty():
		_active_memory_context = memory_context.duplicate(true)
	else:
		_active_memory_context = _pending_memory_context.duplicate(true)
	_pending_memory_context = {}

func _clear_memory_request_context() -> void:
	_pending_memory_context = {}
	_active_memory_context = {}

func extract_memory_from_chat(user_text: String, ai_reply: String, memory_context: Dictionary = {}) -> void:
	_update_script()
	if not is_inside_tree() or _is_api_key_empty():
		return
		
	if memory_http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		memory_http.cancel_request()
	_prepare_memory_request_context(memory_context)
		
	var system_prompt = GameDataManager.prompt_manager.build_memory_prompt(GameDataManager.profile)
	
	var char_name = GameDataManager.profile.char_name
	if char_name == "":
		char_name = "AI"
		
	var safe_user_prompt = "以下是一次对话交换：\n玩家: " + user_text + "\n" + char_name + ": " + ai_reply + "\n\n【系统强制指令：请作为专业的记忆提取系统，严格按照规定的 JSON 格式输出操作数组。如果没有需要提取的记忆，请输出空的 operations 数组。绝对不要进行角色扮演！不要回复任何对话！】"
	
	var api_messages = [
		{"role": "system", "content": system_prompt},
		{"role": "user", "content": safe_user_prompt}
	]
	
	var body = {
		"model": GameDataManager.config.model,
		"messages": api_messages,
		"temperature": 0.1,
		"max_tokens": 200
	}
	
	if not GameDataManager.config.model.begins_with("doubao"):
		body["response_format"] = {"type": "json_object"}
	
	var err = memory_http.request(_get_url(), _get_headers(), HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		_clear_memory_request_context()
		memory_request_failed.emit("网络请求发送失败: " + str(err))


func call_chat_api_non_stream(api_messages: Array) -> void:
	_update_script()
	if not is_inside_tree() or _is_api_key_empty():
		chat_request_failed.emit("API Key未设置，请在设置界面配置。")
		return
		
	if chat_http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		chat_http.cancel_request()
		
	var body = {
		"model": GameDataManager.config.model,
		"messages": api_messages,
		"temperature": GameDataManager.config.temperature,
		"max_tokens": GameDataManager.config.max_tokens,
		"stream": false
	}
	
	if chat_http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		chat_http.cancel_request()
		
	var err = chat_http.request(_get_url(), _get_headers(), HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		chat_request_failed.emit("网络请求发送失败: " + str(err))

func _process(_delta: float) -> void:
	if not _chat_stream_active or _chat_stream_client == null:
		return
		
	_chat_stream_client.poll()
	var status = _chat_stream_client.get_status()
	
	var path = _get_stream_path()
		
	if status == HTTPClient.STATUS_CONNECTED and not _chat_stream_request_sent:
		var err = _chat_stream_client.request(HTTPClient.METHOD_POST, path, _chat_stream_headers, _chat_stream_body)
		if err != OK:
			_stop_chat_stream()
			chat_request_failed.emit("网络请求发送失败。")
			return
		_chat_stream_request_sent = true
		return
		
	if status == HTTPClient.STATUS_BODY:
		if _chat_stream_response_code == 0:
			_chat_stream_response_code = _chat_stream_client.get_response_code()
			if _chat_stream_response_code != 200:
				var err_body = _read_all_stream_body()
				_stop_chat_stream()
				
				var err_msg = "API 请求错误，状态码: " + str(_chat_stream_response_code)
				var json = JSON.new()
				if json.parse(err_body) == OK and json.get_data() is Dictionary and json.get_data().has("error"):
					var api_error = json.get_data()["error"]
					if api_error is Dictionary and api_error.has("message"):
						err_msg += " - " + api_error["message"]
				else:
					err_msg += " Body: " + err_body
					
				chat_request_failed.emit(err_msg)
				return
				
		var chunk = _chat_stream_client.read_response_body_chunk()
		if chunk.size() > 0:
			_chat_stream_sse_buffer += chunk.get_string_from_utf8()
			_consume_sse_buffer()
		return
		
	if status == HTTPClient.STATUS_DISCONNECTED:
		if _chat_stream_full_text.strip_edges() == "":
			_stop_chat_stream()
			chat_request_failed.emit("返回数据解析失败")
		else:
			_finish_chat_stream()

func _read_all_stream_body() -> String:
	var out = ""
	if _chat_stream_client == null:
		return out
	while true:
		var chunk = _chat_stream_client.read_response_body_chunk()
		if chunk.size() == 0:
			break
		out += chunk.get_string_from_utf8()
	return out

func _consume_sse_buffer() -> void:
	while true:
		var idx = _chat_stream_sse_buffer.find("\n\n")
		if idx == -1:
			break
		var event_text = _chat_stream_sse_buffer.substr(0, idx)
		_chat_stream_sse_buffer = _chat_stream_sse_buffer.substr(idx + 2)
		_consume_sse_event(event_text)

func _consume_sse_event(event_text: String) -> void:
	var lines = event_text.split("\n")
	for line in lines:
		var trimmed = line.strip_edges()
		if not trimmed.begins_with("data:"):
			continue
		var payload = trimmed.substr(5).strip_edges()
		if payload == "" or payload == "[DONE]":
			if payload == "[DONE]":
				_finish_chat_stream()
			continue
			
		var json = JSON.new()
		if json.parse(payload) != OK:
			continue
		var data = json.get_data()
		if not (data is Dictionary):
			continue
			
		var delta_text = ""
		if data.has("choices") and data["choices"] is Array and data["choices"].size() > 0:
			var c0 = data["choices"][0]
			if c0 is Dictionary:
				if c0.has("delta") and c0["delta"] is Dictionary:
					if c0["delta"].has("content") and c0["delta"]["content"] != null:
						delta_text = str(c0["delta"]["content"])
				elif c0.has("message") and c0["message"] is Dictionary:
					if c0["message"].has("content") and c0["message"]["content"] != null:
						delta_text = str(c0["message"]["content"])
					
		if delta_text != "":
			_chat_stream_full_text += delta_text
			chat_stream_delta.emit(delta_text)

func _finish_chat_stream() -> void:
	if not _chat_stream_active:
		return
	var final_text = _chat_stream_full_text
	_stop_chat_stream()
	chat_request_completed.emit({
		"choices": [
			{"message": {"content": final_text}}
		]
	})

func _stop_chat_stream() -> void:
	_chat_stream_active = false
	_chat_stream_request_sent = false
	_chat_stream_body = ""
	_chat_stream_headers = []
	_chat_stream_sse_buffer = ""
	_chat_stream_response_code = 0
	if _chat_stream_client != null:
		_chat_stream_client.close()
		_chat_stream_client = null
	set_process(false)

func send_options_generation(last_ai_reply: String = "", free_chat_strategy: String = "", history_type: String = "all") -> void:
	_update_script()
	if _is_api_key_empty():
		return
		
	# 如果调用时不在树上（极小概率，但为了安全起见），等待其重新入树
	while not is_inside_tree():
		await Engine.get_main_loop().process_frame
		
	# 防止正在处理上一个请求时产生冲突 (ERR_BUSY)
	if options_http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		options_http.cancel_request()
		
	var history_text = ""
	var history_msgs = GameDataManager.history.get_messages_by_type(history_type)
	var start_idx = max(0, history_msgs.size() - 10) # 仅取最近10条，避免长上下文导致AI转移话题
	
	# 提取所有包含“玩家”和角色的有效对话文本，去掉 BBCode
	var bbcode_regex = RegEx.new()
	bbcode_regex.compile("\\[/?color.*?\\]")
	
	for i in range(start_idx, history_msgs.size()):
		var msg = history_msgs[i]
		var clean_text = bbcode_regex.sub(msg["text"], "", true)
		
		# 彻底移除 " <--- 【系统提示..." 这种可能被污染到历史记录里的内部标签
		var prompt_tag_idx = clean_text.find(" <--- 【")
		if prompt_tag_idx != -1:
			clean_text = clean_text.substr(0, prompt_tag_idx).strip_edges()
			
		if i == history_msgs.size() - 1 and msg["speaker"] != "玩家" and last_ai_reply == "":
			history_text += msg["speaker"] + ": " + clean_text + " <--- 【这是你们上次聊天的最后一句话，请顺着这个话题继续延展，不要生硬地开启新话题】\n"
		else:
			history_text += msg["speaker"] + ": " + clean_text + "\n"
			
	# 如果有提前生成选项时传入的最新AI回复，将其拼接到历史最后，并打上强提示标记
	if last_ai_reply != "":
		var char_name = GameDataManager.profile.char_name
		
		var clean_reply = last_ai_reply
		var prompt_tag_idx = clean_reply.find(" <--- 【")
		if prompt_tag_idx != -1:
			clean_reply = clean_reply.substr(0, prompt_tag_idx).strip_edges()
			
		history_text += char_name + ": " + clean_reply + " <--- 【这是你们上次聊天的最后一句话，请顺着这个话题继续延展，不要生硬地开启新话题】\n"
		
	var system_prompt = GameDataManager.prompt_manager.build_options_prompt(GameDataManager.profile, history_text)
	
	if free_chat_strategy != "":
		system_prompt += "\n\n【特别对话策略引导】：当前处于特定自由对话模式，请你为玩家生成的这3个回复选项，必须重点围绕以下策略或话题展开：%s" % free_chat_strategy
		
	var api_messages = [
		{"role": "system", "content": system_prompt}
	]
	
	var body = {
		"model": GameDataManager.config.model,
		"messages": api_messages,
		"temperature": 0.7,
		"max_tokens": 150
	}
	
	if not GameDataManager.config.model.begins_with("doubao"):
		body["response_format"] = {"type": "json_object"}
	
	if options_http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		options_http.cancel_request()
		
	options_http.request(_get_url(), _get_headers(), HTTPClient.METHOD_POST, JSON.stringify(body))

func send_emotion_generation(last_ai_reply: String) -> void:
	_update_script()
	if _is_api_key_empty():
		emotion_request_failed.emit("API Key未设置")
		return
		
	# 如果调用时不在树上（极小概率，但为了安全起见），等待其重新入树
	while not is_inside_tree():
		await Engine.get_main_loop().process_frame
		
	# 防止正在处理上一个请求时产生冲突 (ERR_BUSY)
	if emotion_http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		emotion_http.cancel_request()
		
	var system_prompt = GameDataManager.prompt_manager.build_emotion_prompt(GameDataManager.profile)
	
	var api_messages = [
		{"role": "system", "content": system_prompt},
		{"role": "user", "content": last_ai_reply}
	]
	
	var body = {
		"model": GameDataManager.config.model,
		"messages": api_messages,
		"temperature": 0.7,
		"max_tokens": 150
	}
	
	if emotion_http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		emotion_http.cancel_request()
		
	emotion_http.request(_get_url(), _get_headers(), HTTPClient.METHOD_POST, JSON.stringify(body))

func send_narrator_generation() -> void:
	_update_script()
	if _is_api_key_empty():
		narrator_request_failed.emit("API Key未设置")
		return
		
	while not is_inside_tree():
		await Engine.get_main_loop().process_frame
		
	var prompt_template = ""
	var file = FileAccess.open("res://scripts/templates/prompts/narrator_generation.txt", FileAccess.READ)
	if file:
		prompt_template = file.get_as_text()
		file.close()
	else:
		narrator_request_failed.emit("无法读取旁白提示词模板")
		return
		
	var profile = GameDataManager.profile
	var stage_conf = profile.get_current_stage_config()
	
	var history_text = ""
	var history_msgs = GameDataManager.history.get_messages_by_type("story_chat")
	var start_idx = max(0, history_msgs.size() - 5)
	for i in range(start_idx, history_msgs.size()):
		var msg = history_msgs[i]
		history_text += msg["speaker"] + ": " + msg["text"] + "\n"
		
	var system_prompt = prompt_template.replace("{{current_stage}}", str(profile.current_stage))
	system_prompt = system_prompt.replace("{{stage_traits}}", stage_conf.get("personality_traits", ""))
	system_prompt = system_prompt.replace("{{recent_history}}", history_text)
	system_prompt = system_prompt.replace("{{char_name}}", profile.char_name)
	
	var api_messages = [
		{"role": "system", "content": system_prompt},
		{"role": "user", "content": "请生成进入场景时的旁白"}
	]
	
	var body = {
		"model": GameDataManager.config.model,
		"messages": api_messages,
		"temperature": 0.7,
		"max_tokens": 100
	}
	
	if narrator_http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		narrator_http.cancel_request()
		
	narrator_http.request(_get_url(), _get_headers(), HTTPClient.METHOD_POST, JSON.stringify(body))

func send_character_mood_analysis(character_message: String) -> void:
	_update_script()
	if _is_api_key_empty():
		character_mood_request_failed.emit("API Key未设置")
		return
		
	# 如果调用时不在树上（极小概率，但为了安全起见），等待其重新入树
	while not is_inside_tree():
		await Engine.get_main_loop().process_frame
		
	var system_prompt = GameDataManager.prompt_manager.build_character_mood_prompt(character_message)
	var api_messages = [
		{"role": "system", "content": system_prompt}
	]
	
	var body = {
		"model": GameDataManager.config.model,
		"messages": api_messages,
		"temperature": 0.1,
		"max_tokens": 100
	}
	if not GameDataManager.config.model.begins_with("doubao"):
		body["response_format"] = {"type": "json_object"}
	
	if character_mood_http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		character_mood_http.cancel_request()
		
	character_mood_http.request(_get_url(), _get_headers(), HTTPClient.METHOD_POST, JSON.stringify(body))

func analyze_mood_sync(character_message: String) -> String:
	_update_script()
	if _is_api_key_empty():
		return ""
		
	while not is_inside_tree():
		await Engine.get_main_loop().process_frame
		
	var system_prompt = GameDataManager.prompt_manager.build_character_mood_prompt(character_message)
	var api_messages = [
		{"role": "system", "content": system_prompt}
	]
	
	var body = {
		"model": GameDataManager.config.model,
		"messages": api_messages,
		"temperature": 0.1,
		"max_tokens": 100
	}
	
	if not GameDataManager.config.model.begins_with("doubao"):
		body["response_format"] = {"type": "json_object"}
	
	# Create a temporary HTTPRequest node for this sync call
	var http = HTTPRequest.new()
	http.timeout = 10.0
	add_child(http)
	
	http.request(_get_url(), _get_headers(), HTTPClient.METHOD_POST, JSON.stringify(body))
	
	# Wait for the request to complete
	var result_array = await http.request_completed
	var result = result_array[0]
	var response_code = result_array[1]
	var response_body = result_array[3]
	
	http.queue_free()
	
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		var json = JSON.new()
		if json.parse(response_body.get_string_from_utf8()) == OK:
			var data = json.get_data()
			if data is Dictionary and data.has("choices") and data["choices"].size() > 0:
				var reply = data["choices"][0]["message"]["content"]
				print("\n========== [Character Mood Sync Output] ==========")
				print(reply)
				print("==================================================\n")
				
				var clean_reply = reply.strip_edges()
				if clean_reply.begins_with("```json"):
					clean_reply = clean_reply.replace("```json", "")
				if clean_reply.begins_with("```"):
					clean_reply = clean_reply.replace("```", "")
				if clean_reply.ends_with("```"):
					clean_reply = clean_reply.substr(0, clean_reply.length() - 3)
				
				clean_reply = clean_reply.strip_edges()
						
				var reply_json = JSON.new()
				var error = reply_json.parse(clean_reply)
				if error == OK:
					var reply_data = reply_json.get_data()
					if reply_data is Dictionary and reply_data.has("mood_id"):
						return reply_data["mood_id"]
				else:
					print("Character Mood Sync Failed: Inner JSON Parse Error (Code: ", error, ") - Text: ", clean_reply)
		else:
			print("Character Mood Sync Failed: Outer JSON Parse Error")
	else:
		print("Character Mood Sync HTTP Request Failed: Code ", response_code)
	
	return ""

func generate_dynamic_topics(prompt: String, callback: Callable) -> void:
	_update_script()
	var request_data = {
		"model": GameDataManager.config.model,
		"messages": [{"role": "user", "content": prompt}],
		"temperature": 0.7,
		"max_tokens": 150
	}
	
	var url = _get_url()
	var headers = _get_headers()
	
	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(func(result, response_code, headers_arr, body):
		http_request.queue_free()
		if response_code == 200:
			var json = JSON.new()
			if json.parse(body.get_string_from_utf8()) == OK:
				var res_data = json.get_data()
				if res_data.has("choices") and res_data["choices"].size() > 0:
					var text = res_data["choices"][0]["message"]["content"]
					callback.call(text)
					return
		callback.call("") # 失败时返回空字符串，让调用方走 fallback
	)
	var err = http_request.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(request_data))
	if err != OK:
		http_request.queue_free()
		callback.call("")

func generate_npc_event_dialogue(npc_id: String, event_desc: String) -> void:
	_update_script()
	if _is_api_key_empty():
		print("未配置 API Key")
		npc_event_dialogue_failed.emit("未配置 API Key")
		return
		
	while not is_inside_tree():
		await Engine.get_main_loop().process_frame
		
	if npc_event_http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		npc_event_http.cancel_request()
		
	var npc_name = "未知NPC"
	var personality = "普通"
	var stage = 1
	var stage_title = "初识"
	
	# 获取 NPC 基础设定
	var npc_file = FileAccess.open("res://assets/data/characters/npc/" + npc_id + ".json", FileAccess.READ)
	if npc_file:
		var json = JSON.new()
		if json.parse(npc_file.get_as_text()) == OK:
			var data = json.get_data()
			npc_name = data.get("char_name", npc_id)
			if data.has("base_personality"):
				personality = data["base_personality"].get("core_traits", "") + " " + data["base_personality"].get("dialogue_style", "")
	
	# 获取好感度阶段
	if GameDataManager.profile.current_character_id == npc_id:
		stage = GameDataManager.profile.current_stage
		stage_title = GameDataManager.profile.get_current_stage_config().get("stageTitle", "未知")
	else:
		var stages_file = FileAccess.open("res://assets/data/characters/npc/" + npc_id + "_stages.json", FileAccess.READ)
		if stages_file:
			var json = JSON.new()
			if json.parse(stages_file.get_as_text()) == OK:
				var data = json.get_data()
				if data.has("stages") and data["stages"].size() > 0:
					stage_title = data["stages"][0].get("stageTitle", "未知")
	
	var protagonist_name = GameDataManager.profile.char_name # 当前游戏的女主(例如Luna)
	if protagonist_name.is_empty():
		protagonist_name = "Luna"
		
	var intimacy = 0.0
	var trust = 0.0
	if GameDataManager.profile.current_character_id == npc_id:
		intimacy = GameDataManager.profile.intimacy
		trust = GameDataManager.profile.trust
	else:
		var npc_rel = GameDataManager.npc_relationship_manager
		if npc_rel:
			intimacy = npc_rel.get_intimacy(npc_id)
			trust = npc_rel.get_trust(npc_id)
		
	# 解析事件详情，构建当前事件描述
	var system_prompt = GameDataManager.prompt_manager.build_npc_event_prompt(npc_name, personality, protagonist_name, stage, stage_title, event_desc, intimacy, trust)
	
	if system_prompt.is_empty():
		# Fallback in case file read fails
		system_prompt = "【系统设定】\n你扮演的角色是：%s。\n你的性格特征和说话风格是：%s。\n注意：在这个世界里，你现在面对的是游戏世界中的少女【%s】。\n你当前与少女【%s】的情感关系处于【阶段%d：%s】（亲密度：%.1f，信任度：%.1f）。请严格根据这个情感状态对她表现出相应的态度。\n\n【当前事件】\n%s\n\n【任务要求】\n请结合你的性格、情感阶段以及当前发生的事件，作出非常符合你人设的回复。注意：\n1. 所有的动作、神态、心理描写，必须且只能使用全角或半角的圆括号 () 包裹。\n2. 绝对禁止使用星号 *、中括号 []、波浪号 ~ 等其他任何符号来表示动作或情绪。\n3. 直接输出台词和圆括号动作，不要包含任何旁白。\n4. 语气必须严格符合当前对【%s】的情感状态，且符合现代日常世界观（不要出现魔幻、修仙、系统、穿越等出戏话题）。\n5. 回复可以是多句话，以表达完整的情感和意思，如果有多句可以自然换行。像游戏里的即时互动反馈一样自然流畅。" % [npc_name, personality, protagonist_name, protagonist_name, stage, stage_title, intimacy, trust, event_desc, protagonist_name]
	
	var api_messages = [
		{"role": "system", "content": system_prompt}
	]
	
	var body = {
		"model": GameDataManager.config.model,
		"messages": api_messages,
		"temperature": 0.7,
		"max_tokens": 500 # 防止 reasoning 截断
	}
	
	if npc_event_http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		npc_event_http.cancel_request()
		
	npc_event_http.request(_get_url(), _get_headers(), HTTPClient.METHOD_POST, JSON.stringify(body))

func send_diary_generation() -> void:
	_update_script()
	if _is_api_key_empty():
		diary_error.emit("API Key未设置")
		return
		
	while not is_inside_tree():
		await Engine.get_main_loop().process_frame
		
	var prompt_template = ""
	var file = FileAccess.open("res://scripts/templates/prompts/diary_generation.txt", FileAccess.READ)
	if file:
		prompt_template = file.get_as_text()
		file.close()
	else:
		diary_error.emit("找不到日记生成提示词模板")
		return
		
	var profile = GameDataManager.profile
	var char_name = profile.char_name
	var personality = GameDataManager.personality_system.get_personality_summary(profile)
	var emotion_stage = "Stage %d (%s) - 亲密度: %.1f, 信任度: %.1f, 情感风味: %s" % [profile.current_stage, profile.get_current_stage_config().get("stageTitle", ""), profile.intimacy, profile.trust, GameDataManager.personality_system.get_dynamic_traits(profile)]
	var mood = GameDataManager.mood_system.get_macro_mood_name(profile.mood_value)
	var current_expression = profile.current_expression
	var expression_db = GameDataManager.expression_system.expression_configs
	if expression_db and expression_db.has(current_expression):
		mood += " (表情：" + expression_db[current_expression].get("expression_name", "未知") + ")"
	
	# if current_expression != "calm" and current_expression != "":
	# 	var expression_desc = GameDataManager.expression_system.get_expression_description(current_expression)
	# 	prompt += "【角色当前表情与行为特征】：\n" + expression_desc + "\n"
		
	var player_name = profile.player_title
	if player_name.is_empty():
		player_name = "指导人"
	var chat_history = profile.get_recent_chat_history_text(10)
	
	if chat_history.is_empty():
		chat_history = "今天没有太多的交流..."
		
	var system_prompt = prompt_template.replace("{char_name}", char_name)
	system_prompt = system_prompt.replace("{personality}", personality)
	system_prompt = system_prompt.replace("{emotion_stage}", emotion_stage)
	system_prompt = system_prompt.replace("{mood}", mood)
	system_prompt = system_prompt.replace("{player_name}", player_name)
	system_prompt = system_prompt.replace("{chat_history}", chat_history)
	
	var api_messages = [
		{"role": "system", "content": system_prompt},
		{"role": "user", "content": "请写下今天的日记。"}
	]
	
	var body = {
		"model": GameDataManager.config.model,
		"messages": api_messages,
		"temperature": 0.7,
		"max_tokens": 800
	}
	
	if diary_http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		diary_http.cancel_request()
		
	diary_http.request(_get_url(), _get_headers(), HTTPClient.METHOD_POST, JSON.stringify(body))

func _on_chat_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_handle_response(result, response_code, body, chat_request_completed, chat_request_failed)

func _on_emotion_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_handle_response(result, response_code, body, emotion_request_completed, emotion_request_failed)

func _on_memory_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var request_memory_context = _active_memory_context.duplicate(true)
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		var json = JSON.new()
		if json.parse(body.get_string_from_utf8()) == OK:
			var response_data = json.get_data()
			if response_data is Dictionary and response_data.has("choices") and response_data["choices"].size() > 0:
				var reply = response_data["choices"][0]["message"]["content"].strip_edges()
				
				print("\n========== [Memory Agent Output] ==========")
				print(reply)
				print("===========================================\n")
				
				var json_str = reply
				var regex = RegEx.new()
				regex.compile("```(?:json)?\\s*(\\{[\\s\\S]*?\\})\\s*```")
				var match = regex.search(reply)
				if match:
					json_str = match.get_string(1).strip_edges()
				else:
					var start_idx = reply.find("{")
					var end_idx = reply.rfind("}")
					if start_idx != -1 and end_idx != -1 and end_idx > start_idx:
						json_str = reply.substr(start_idx, end_idx - start_idx + 1)
					
				if json_str != "" and json_str != "无新增记忆":
					var parse_json = JSON.new()
					if parse_json.parse(json_str) == OK:
						var data = parse_json.get_data()
						if data is Dictionary and data.has("operations") and data["operations"] is Array:
							var plain_text_changes = ""
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
	_clear_memory_request_context()
	_handle_response(result, response_code, body, memory_request_completed, memory_request_failed)

func _on_options_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_handle_response(result, response_code, body, options_request_completed, options_request_failed)

func _on_narrator_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_handle_response(result, response_code, body, narrator_request_completed, narrator_request_failed)

func _on_character_mood_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_handle_response(result, response_code, body, character_mood_request_completed, character_mood_request_failed)

func _on_npc_event_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code == 200:
		var json = JSON.new()
		if json.parse(body.get_string_from_utf8()) == OK:
			var data = json.get_data()
			if typeof(data) == TYPE_DICTIONARY and data.has("choices") and data["choices"].size() > 0:
				var choice = data["choices"][0]
				if choice.has("message") and choice["message"].has("content"):
					var content = choice["message"]["content"].strip_edges()
					if content.is_empty() and choice["message"].has("reasoning_content"):
						npc_event_dialogue_completed.emit("（微笑着，没有说话）")
					else:
						npc_event_dialogue_completed.emit(content)
					return
	
	npc_event_dialogue_failed.emit("NPC 事件台词获取失败 (Code: %d)" % response_code)

func _on_diary_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		var response_str = body.get_string_from_utf8()
		var json = JSON.new()
		if json.parse(response_str) == OK:
			var response_data = json.data
			if response_data.has("choices") and response_data.choices.size() > 0:
				var content = response_data.choices[0].message.content
				var diary_entry = {
					"id": str(int(Time.get_unix_time_from_system())),
					"date": Time.get_date_string_from_system(),
					"weather": "晴",
					"content": content,
					"image_url": "",
					"image_generation_time": 0.0,
					"image_prompt": "",
					"image_model_version": ""
				}
				
				var enable_illustration = true
				if "enable_ai_diary_illustration" in GameDataManager.config:
					enable_illustration = GameDataManager.config.enable_ai_diary_illustration
					
				if enable_illustration:
					_process_diary_illustration(diary_entry)
				else:
					# 自动保存到 profile
					if GameDataManager.profile and GameDataManager.profile.has_method("add_diary"):
						GameDataManager.profile.add_diary(diary_entry)
						if GameDataManager.profile.has_method("save_profile"):
							GameDataManager.profile.save_profile()
					diary_generated.emit(diary_entry)
			else:
				diary_error.emit("找不到 choices 字段")
		else:
			diary_error.emit("JSON 解析失败: " + json.get_error_message())
	else:
		var err_msg = "请求失败 (Code: %d)" % response_code
		if body.size() > 0:
			var json = JSON.new()
			if json.parse(body.get_string_from_utf8()) == OK and json.data is Dictionary and json.data.has("error"):
				err_msg += " - " + json.data["error"].get("message", "")
		diary_error.emit(err_msg)

func _process_diary_illustration(diary_entry: Dictionary) -> void:
	# 1. 使用当前的大模型获取图片的 Prompt
	var prompt_template = ""
	var file = FileAccess.open("res://scripts/templates/prompts/diary_illustration.txt", FileAccess.READ)
	if file:
		prompt_template = file.get_as_text()
		file.close()
	else:
		print("[DeepSeekClient] 找不到日记插图提示词模板，跳过插图生成")
		# 自动保存到 profile
		if GameDataManager.profile and GameDataManager.profile.has_method("add_diary"):
			GameDataManager.profile.add_diary(diary_entry)
			if GameDataManager.profile.has_method("save_profile"):
				GameDataManager.profile.save_profile()
		diary_generated.emit(diary_entry)
		return
		
	var system_prompt = prompt_template.replace("{diary_content}", diary_entry.content)
	var api_messages = [{"role": "system", "content": system_prompt}]
	var body = {
		"model": GameDataManager.config.model,
		"messages": api_messages,
		"temperature": 0.7,
		"max_tokens": 300
	}
	
	var http = HTTPRequest.new()
	add_child(http)
	
	var err = http.request(_get_url(), _get_headers(), HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		http.queue_free()
		diary_generated.emit(diary_entry)
		return
		
	var response = await http.request_completed
	var result = response[0]
	var response_code = response[1]
	var res_body = response[3]
	
	var image_prompt = ""
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		var json = JSON.new()
		if json.parse(res_body.get_string_from_utf8()) == OK and json.data.has("choices") and json.data.choices.size() > 0:
			image_prompt = json.data.choices[0].message.content.strip_edges()
			
	http.queue_free()
	
	if image_prompt.is_empty():
		print("[DeepSeekClient] 无法生成插图提示词，跳过插图生成")
		if GameDataManager.config and "default_image_path" in GameDataManager.config:
			diary_entry["image_url"] = GameDataManager.config.default_image_path
			
		# 自动保存到 profile
		if GameDataManager.profile and GameDataManager.profile.has_method("add_diary"):
			GameDataManager.profile.add_diary(diary_entry)
			if GameDataManager.profile.has_method("save_profile"):
				GameDataManager.profile.save_profile()
				
		diary_generated.emit(diary_entry)
		return
		
	# 2. 调用 Image Client
	if GameDataManager.config and not GameDataManager.config.image_generation_enabled:
		print("[DeepSeekClient] 图像生成已禁用，使用默认占位图")
		diary_entry["image_url"] = GameDataManager.config.default_image_path
		diary_generated.emit(diary_entry)
		return
		
	var provider = 0 # 0: OpenAI, 1: Doubao
	if GameDataManager.config and "image_generation_provider" in GameDataManager.config:
		provider = GameDataManager.config.image_generation_provider
		
	var image_client
	if provider == 1:
		image_client = preload("res://scripts/api/doubao_image_client.gd").new()
	else:
		image_client = preload("res://scripts/api/openai_image_client.gd").new()
		
	add_child(image_client)
	
	var on_success = func(_diary_id: String, local_path: String, metadata: Dictionary):
		diary_entry["image_url"] = local_path
		diary_entry["image_generation_time"] = metadata.get("duration", 0.0)
		diary_entry["image_prompt"] = metadata.get("prompt", "")
		diary_entry["image_model_version"] = metadata.get("model", "")
		
		# 自动保存到 profile
		if GameDataManager.profile and GameDataManager.profile.has_method("add_diary"):
			GameDataManager.profile.add_diary(diary_entry)
			if GameDataManager.profile.has_method("save_profile"):
				GameDataManager.profile.save_profile()
		
		image_client.queue_free()
		diary_generated.emit(diary_entry)
		
	var on_failed = func(_diary_id: String, error_msg: String):
		print("[DeepSeekClient] 日记插图生成失败: ", error_msg)
		# 失败时使用默认占位图或留空，依然发送成功信号保证日记正常保存
		if GameDataManager.config and "default_image_path" in GameDataManager.config:
			diary_entry["image_url"] = GameDataManager.config.default_image_path
			
		# 自动保存到 profile
		if GameDataManager.profile and GameDataManager.profile.has_method("add_diary"):
			GameDataManager.profile.add_diary(diary_entry)
			if GameDataManager.profile.has_method("save_profile"):
				GameDataManager.profile.save_profile()
				
		image_client.queue_free()
		diary_generated.emit(diary_entry)
		
	image_client.image_generated.connect(on_success)
	image_client.image_generation_failed.connect(on_failed)
	
	image_client.generate_diary_illustration(diary_entry.id, image_prompt)

func _handle_response(result: int, response_code: int, body: PackedByteArray, success_signal: Signal, fail_signal: Signal) -> void:
	var char_name = GameDataManager.profile.char_name
	
	if result == HTTPRequest.RESULT_TIMEOUT:
		fail_signal.emit(char_name + " 似乎走神了...")
		return
		
	if response_code == 200:
		var json = JSON.new()
		var error = json.parse(body.get_string_from_utf8())
		if error == OK:
			success_signal.emit(json.get_data())
		else:
			fail_signal.emit("返回数据解析失败")
	else:
		if response_code == 0:
			fail_signal.emit(char_name + " 似乎走神了...")
		elif response_code == 429:
			var err_msg = "请求过于频繁(429)，AI服务商限制了调用速率，请稍后再试。"
			var json = JSON.new()
			if json.parse(body.get_string_from_utf8()) == OK and json.get_data() is Dictionary and json.get_data().has("error"):
				var api_error = json.get_data()["error"]
				if api_error is Dictionary and api_error.has("message"):
					err_msg += " (" + api_error["message"] + ")"
			fail_signal.emit(err_msg)
		else:
			var err_msg = "API 请求错误，状态码: " + str(response_code)
			var json = JSON.new()
			if json.parse(body.get_string_from_utf8()) == OK and json.get_data() is Dictionary and json.get_data().has("error"):
				var api_error = json.get_data()["error"]
				if api_error is Dictionary and api_error.has("message"):
					err_msg += " - " + api_error["message"]
			fail_signal.emit(err_msg)

func send_moment_generation(custom_profile: CharacterProfile = null) -> void:
	_update_script()
	if _is_api_key_empty():
		moment_error.emit("API Key未设置")
		return
		
	while not is_inside_tree():
		await Engine.get_main_loop().process_frame
		
	var profile = custom_profile if custom_profile else GameDataManager.profile
	
	# Store the profile name so _on_moment_request_completed can use it
	var author_name = profile.char_name if profile else "AI"
	var avatar_path = profile.avatar if profile and profile.avatar != "" else "res://icon.svg"
	
	set_meta("current_moment_author", author_name)
	set_meta("current_moment_avatar", avatar_path)
	
	var system_prompt = GameDataManager.prompt_manager.build_moment_generation_prompt(profile)
	
	var api_messages = [
		{"role": "system", "content": system_prompt},
		{"role": "user", "content": "请写一条朋友圈。"}
	]
	
	var body = {
		"model": GameDataManager.config.model,
		"messages": api_messages,
		"temperature": 0.7,
		"max_tokens": 800
	}
	
	if moment_http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		moment_http.cancel_request()
		
	moment_http.request(_get_url(), _get_headers(), HTTPClient.METHOD_POST, JSON.stringify(body))

func _on_moment_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		var response_str = body.get_string_from_utf8()
		var json = JSON.new()
		if json.parse(response_str) == OK:
			var response_data = json.data
			if response_data.has("choices") and response_data.choices.size() > 0:
				var content = response_data.choices[0].message.content
				var moment_data = {
					"id": str(int(Time.get_unix_time_from_system())),
					"timestamp": Time.get_unix_time_from_system(),
					"date": Time.get_date_string_from_system(),
					"content": content,
					"image_url": "",
					"likes": 0,
					"comments": [],
					"author": get_meta("current_moment_author", "AI"),
					"avatar": get_meta("current_moment_avatar", "res://icon.svg")
				}
				
				var enable_illustration = true
				if "enable_ai_moment_illustration" in GameDataManager.config:
					enable_illustration = GameDataManager.config.enable_ai_moment_illustration
				
				if enable_illustration:
					_process_moment_illustration(moment_data)
				else:
					moment_generated.emit(moment_data)
			else:
				moment_error.emit("找不到 choices 字段")
		else:
			moment_error.emit("JSON 解析失败: " + json.get_error_message())
	else:
		var err_msg = "请求失败 (Code: %d)" % response_code
		if body.size() > 0:
			var json = JSON.new()
			if json.parse(body.get_string_from_utf8()) == OK and json.data is Dictionary and json.data.has("error"):
				err_msg += " - " + json.data["error"].get("message", "")
		moment_error.emit(err_msg)

func _process_moment_illustration(moment_data: Dictionary) -> void:
	var image_prompt = "请根据这段朋友圈内容生成一张配图的提示词（要求为英文）：" + moment_data.content
	var api_messages = [{"role": "user", "content": image_prompt}]
	var body = {
		"model": GameDataManager.config.model,
		"messages": api_messages,
		"temperature": 0.7,
		"max_tokens": 300
	}
	
	var http = HTTPRequest.new()
	add_child(http)
	
	var err = http.request(_get_url(), _get_headers(), HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		http.queue_free()
		moment_generated.emit(moment_data)
		return
		
	var response = await http.request_completed
	var result = response[0]
	var response_code = response[1]
	var res_body = response[3]
	
	var en_prompt = ""
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		var json = JSON.new()
		if json.parse(res_body.get_string_from_utf8()) == OK and json.data.has("choices") and json.data.choices.size() > 0:
			en_prompt = json.data.choices[0].message.content.strip_edges()
			
	http.queue_free()
	
	if en_prompt.is_empty():
		print("[DeepSeekClient] 无法生成朋友圈插图提示词，跳过插图生成")
		if GameDataManager.config and "default_image_path" in GameDataManager.config:
			moment_data["image_url"] = GameDataManager.config.default_image_path
		moment_generated.emit(moment_data)
		return
		
	if GameDataManager.config and not GameDataManager.config.image_generation_enabled:
		print("[DeepSeekClient] 图像生成已禁用，使用默认占位图")
		moment_data["image_url"] = GameDataManager.config.default_image_path
		moment_generated.emit(moment_data)
		return
		
	var provider = 0
	if GameDataManager.config and "image_generation_provider" in GameDataManager.config:
		provider = GameDataManager.config.image_generation_provider
		
	var image_client
	if provider == 1:
		image_client = preload("res://scripts/api/doubao_image_client.gd").new()
	else:
		image_client = preload("res://scripts/api/openai_image_client.gd").new()
		
	add_child(image_client)
	
	var on_success = func(_id: String, local_path: String, _metadata: Dictionary):
		moment_data["image_url"] = local_path
		image_client.queue_free()
		moment_generated.emit(moment_data)
		
	var on_failed = func(_id: String, error_msg: String):
		print("[DeepSeekClient] 朋友圈插图生成失败: ", error_msg)
		if GameDataManager.config and "default_image_path" in GameDataManager.config:
			moment_data["image_url"] = GameDataManager.config.default_image_path
		image_client.queue_free()
		moment_generated.emit(moment_data)
		
	image_client.image_generated.connect(on_success)
	image_client.image_generation_failed.connect(on_failed)
	
	image_client.generate_diary_illustration(moment_data.id, en_prompt)

func send_moment_reply(post_id: String, comment: String) -> void:
	_update_script()
	if _is_api_key_empty():
		moment_reply_error.emit("API Key未设置")
		return
		
	while not is_inside_tree():
		await Engine.get_main_loop().process_frame
		
	var moments_manager = get_node_or_null("/root/MomentsManager")
	var moment_data = {}
	if moments_manager:
		moment_data = moments_manager.get_moment(post_id)
		
	if moment_data.is_empty():
		moment_reply_error.emit("找不到朋友圈内容")
		return
		
	_current_moment_reply_post_id = post_id
	var profile = GameDataManager.profile
	var moment_content = moment_data.get("content", "")
	var system_prompt = GameDataManager.prompt_manager.build_moment_reply_prompt(profile, moment_content, comment)
	
	var api_messages = [
		{"role": "system", "content": system_prompt}
	]
	
	var body = {
		"model": GameDataManager.config.model,
		"messages": api_messages,
		"temperature": 0.7,
		"max_tokens": 150
	}
	
	if moment_reply_http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		moment_reply_http.cancel_request()
		
	moment_reply_http.request(_get_url(), _get_headers(), HTTPClient.METHOD_POST, JSON.stringify(body))

func _on_moment_reply_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		var json = JSON.new()
		if json.parse(body.get_string_from_utf8()) == OK:
			var data = json.get_data()
			if typeof(data) == TYPE_DICTIONARY and data.has("choices") and data["choices"].size() > 0:
				var choice = data["choices"][0]
				if choice.has("message") and choice["message"].has("content"):
					var content = choice["message"]["content"].strip_edges()
					moment_reply_generated.emit(_current_moment_reply_post_id, content)
					return
	
	var err_msg = "朋友圈回复获取失败 (Code: %d)" % response_code
	if body.size() > 0:
		var json = JSON.new()
		if json.parse(body.get_string_from_utf8()) == OK and json.data is Dictionary and json.data.has("error"):
			err_msg += " - " + json.data["error"].get("message", "")
	moment_reply_error.emit(err_msg)

func generate_schedule_event(course_name: String, course_desc: String, context: Dictionary = {}) -> void:
	_update_script()
	if _is_api_key_empty():
		schedule_event_error.emit("API Key未设置")
		return
		
	while not is_inside_tree():
		await Engine.get_main_loop().process_frame
		
	var full_context = context.duplicate()
	full_context["course_name"] = course_name
	full_context["course_desc"] = course_desc
	var system_prompt = GameDataManager.prompt_manager.build_schedule_event_prompt(full_context)
	var user_prompt = JSON.stringify(full_context, "\t")
	
	var api_messages = [
		{"role": "system", "content": system_prompt},
		{"role": "user", "content": user_prompt}
	]
	
	var body = {
		"model": GameDataManager.config.model,
		"messages": api_messages,
		"temperature": 0.7,
		"max_tokens": 150
	}
	if not GameDataManager.config.model.begins_with("doubao"):
		body["response_format"] = {"type": "json_object"}
	
	if schedule_event_http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		schedule_event_http.cancel_request()
		
	schedule_event_http.request(_get_url(), _get_headers(), HTTPClient.METHOD_POST, JSON.stringify(body))

func resolve_schedule_event(course_name: String, event_desc: String, chosen_option: String, context: Dictionary = {}) -> void:
	_update_script()
	if _is_api_key_empty():
		schedule_event_resolve_error.emit("API Key未设置")
		return
		
	while not is_inside_tree():
		await Engine.get_main_loop().process_frame
		
	var full_context = context.duplicate()
	full_context["course_name"] = course_name
	full_context["event_desc"] = event_desc
	full_context["chosen_option"] = chosen_option
	var system_prompt = GameDataManager.prompt_manager.build_schedule_resolve_prompt(full_context)
	var user_prompt = JSON.stringify(full_context, "\t")
	
	var api_messages = [
		{"role": "system", "content": system_prompt},
		{"role": "user", "content": user_prompt}
	]
	
	var body = {
		"model": GameDataManager.config.model,
		"messages": api_messages,
		"temperature": 0.7,
		"max_tokens": 150
	}
	if not GameDataManager.config.model.begins_with("doubao"):
		body["response_format"] = {"type": "json_object"}
	
	if schedule_resolve_http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		schedule_resolve_http.cancel_request()
		
	schedule_resolve_http.request(_get_url(), _get_headers(), HTTPClient.METHOD_POST, JSON.stringify(body))

func _on_schedule_event_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		var json = JSON.new()
		if json.parse(body.get_string_from_utf8()) == OK:
			var data = json.get_data()
			if data is Dictionary and data.has("choices") and data["choices"].size() > 0:
				var content = data["choices"][0]["message"]["content"]
				var content_json = JSON.new()
				var clean_content = content.strip_edges()
				if clean_content.begins_with("```json"):
					clean_content = clean_content.replace("```json", "")
				if clean_content.begins_with("```"):
					clean_content = clean_content.replace("```", "")
				if clean_content.ends_with("```"):
					clean_content = clean_content.substr(0, clean_content.length() - 3)
				clean_content = clean_content.strip_edges()
				
				if content_json.parse(clean_content) == OK:
					var event_data = content_json.get_data()
					# 兼容 prompt 里要求输出的 description / option1 / option2 字段
					if event_data.has("description") and not event_data.has("event_desc"):
						event_data["event_desc"] = event_data["description"]
					if not event_data.has("options"):
						var opts = []
						if event_data.has("option1"):
							opts.append({"text": event_data["option1"]})
						if event_data.has("option2"):
							opts.append({"text": event_data["option2"]})
						event_data["options"] = opts
						
					schedule_event_generated.emit(event_data)
					return
				else:
					print("[DeepSeekClient] Failed to parse schedule event JSON: ", clean_content)
	schedule_event_error.emit("事件生成失败 (Code: %d)" % response_code)

func _on_schedule_resolve_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		var json = JSON.new()
		if json.parse(body.get_string_from_utf8()) == OK:
			var data = json.get_data()
			if data is Dictionary and data.has("choices") and data["choices"].size() > 0:
				var content = data["choices"][0]["message"]["content"]
				var content_json = JSON.new()
				var clean_content = content.strip_edges()
				if clean_content.begins_with("```json"):
					clean_content = clean_content.replace("```json", "")
				if clean_content.begins_with("```"):
					clean_content = clean_content.replace("```", "")
				if clean_content.ends_with("```"):
					clean_content = clean_content.substr(0, clean_content.length() - 3)
				clean_content = clean_content.strip_edges()
				
				if content_json.parse(clean_content) == OK:
					var result_data = content_json.get_data()
					if result_data.has("rewards") and not result_data.has("attr_changes"):
						result_data["attr_changes"] = result_data["rewards"]
					schedule_event_resolved.emit(result_data)
					return
				else:
					print("[DeepSeekClient] Failed to parse schedule resolve JSON: ", clean_content)
	schedule_event_resolve_error.emit("事件结算失败 (Code: %d)" % response_code)

func send_image_to_image_request(base64_image: String, prompt: String) -> void:
	_update_script()
	if not is_inside_tree():
		await Engine.get_main_loop().process_frame
		
	print("[DeepSeekClient] 收到 Image-to-Image 请求, 提示词: ", prompt)
	# 如果以后API支持真实的I2I（如ControlNet），可以将 base64_image 作为参考图传入。
	# 目前我们使用现有的图像生成客户端 (Text-to-Image) 来模拟I2I请求，
	# 并在后台保存图片，随后返回本地路径。
	
	if GameDataManager.config and not GameDataManager.config.image_generation_enabled:
		image_to_image_failed.emit("图像生成功能已在设置中禁用。")
		return
		
	var provider = 0
	if GameDataManager.config and "image_generation_provider" in GameDataManager.config:
		provider = GameDataManager.config.image_generation_provider
		
	var image_client
	if provider == 1:
		image_client = preload("res://scripts/api/doubao_image_client.gd").new()
	else:
		image_client = preload("res://scripts/api/openai_image_client.gd").new()
		
	add_child(image_client)
	
	var on_success = func(_id: String, local_path: String, _metadata: Dictionary):
		image_client.queue_free()
		image_to_image_completed.emit(local_path)
		
	var on_failed = func(_id: String, error_msg: String):
		image_client.queue_free()
		image_to_image_failed.emit(error_msg)
		
	image_client.image_generated.connect(on_success)
	image_client.image_generation_failed.connect(on_failed)
	
	# 使用 "i2i" 作为ID标识，底层会复用生成逻辑并返回保存的路径
	image_client.generate_diary_illustration("i2i", prompt)
