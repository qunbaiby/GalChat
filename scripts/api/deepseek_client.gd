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
signal date_story_generated(script_data: Dictionary)
signal date_story_error(error_msg: String)

signal idle_quote_completed(quote: String)
signal idle_quote_failed(error_msg: String)

signal image_to_image_completed(image_path: String)
signal image_to_image_failed(error_message: String)

const DeepSeekIdleQuoteService = preload("res://scripts/api/services/deepseek/deepseek_idle_quote_service.gd")
const DeepSeekSceneEventService = preload("res://scripts/api/services/deepseek/deepseek_scene_event_service.gd")
const DeepSeekSocialContentService = preload("res://scripts/api/services/deepseek/deepseek_social_content_service.gd")
const DeepSeekMemoryEmotionService = preload("res://scripts/api/services/deepseek/deepseek_memory_emotion_service.gd")
const DeepSeekNarrativeService = preload("res://scripts/api/services/deepseek/deepseek_narrative_service.gd")
const DeepSeekChatStreamService = preload("res://scripts/api/services/deepseek/deepseek_chat_stream_service.gd")

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
var date_story_http: HTTPRequest
var idle_quote_http: HTTPRequest

var _chat_stream_client: HTTPClient
var _chat_stream_active: bool = false
var _chat_stream_request_sent: bool = false
var _chat_stream_body: String = ""
var _chat_stream_headers: Array = []
var _chat_stream_sse_buffer: String = ""
var _chat_stream_full_text: String = ""
var _chat_stream_response_code: int = 0
var _pending_memory_context: Dictionary = {}
var _active_memory_context: Dictionary = {}
var _idle_quote_service = DeepSeekIdleQuoteService.new()
var _scene_event_service = DeepSeekSceneEventService.new()
var _social_content_service = DeepSeekSocialContentService.new()
var _memory_emotion_service = DeepSeekMemoryEmotionService.new()
var _narrative_service = DeepSeekNarrativeService.new()
var _chat_stream_service = DeepSeekChatStreamService.new()
var _debug_server_url: String = ""
var _debug_session_id: String = ""

func _ready() -> void:
	_update_script()
	_reinitialize_http_nodes()

func _update_script() -> void:
	_migrate_removed_chat_model()

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
	date_story_http = reset_node.call("DateStoryHTTP", 35.0, "request_completed", "_on_date_story_completed")
	idle_quote_http = reset_node.call("IdleQuoteHTTP", 15.0, "request_completed", "_on_idle_quote_completed")

func _is_api_key_empty() -> bool:
	return GameDataManager.config.api_key.is_empty()

func _migrate_removed_chat_model() -> void:
	if GameDataManager.config == null:
		return
	var model_id := str(GameDataManager.config.model).strip_edges()
	if not model_id.begins_with("doubao"):
		return
	GameDataManager.config.model = "deepseek-chat"
	if GameDataManager.config.has_method("save_config"):
		GameDataManager.config.save_config()

func get_chat_model_id() -> String:
	if GameDataManager.config == null:
		return "deepseek-chat"
	var model_id := str(GameDataManager.config.model).strip_edges()
	if model_id == "" or model_id.begins_with("doubao"):
		return "deepseek-chat"
	return model_id

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

func _debug_ensure_env() -> void:
	if _debug_server_url != "" and _debug_session_id != "":
		return
	_debug_server_url = "http://127.0.0.1:7777/event"
	_debug_session_id = "date-ai-fallback"
	var env_path := ProjectSettings.globalize_path("res://.dbg/date-ai-fallback.env")
	if not FileAccess.file_exists(env_path):
		return
	var file := FileAccess.open(env_path, FileAccess.READ)
	if file == null:
		return
	var content := file.get_as_text()
	file.close()
	for raw_line in content.split("\n"):
		var line := raw_line.strip_edges()
		if line.begins_with("DEBUG_SERVER_URL="):
			_debug_server_url = line.trim_prefix("DEBUG_SERVER_URL=").strip_edges()
		elif line.begins_with("DEBUG_SESSION_ID="):
			_debug_session_id = line.trim_prefix("DEBUG_SESSION_ID=").strip_edges()

func _debug_report(hypothesis_id: String, location: String, msg: String, data: Dictionary = {}, run_id: String = "pre") -> void:
	_debug_ensure_env()
	if not is_inside_tree():
		return
	var req := HTTPRequest.new()
	req.timeout = 3.0
	req.request_completed.connect(func(_result: int, _code: int, _headers: PackedStringArray, _body: PackedByteArray): req.queue_free(), CONNECT_ONE_SHOT)
	add_child(req)
	var payload := {
		"sessionId": _debug_session_id,
		"runId": run_id,
		"hypothesisId": hypothesis_id,
		"location": location,
		"msg": "[DEBUG] " + msg,
		"data": data,
		"ts": Time.get_ticks_msec()
	}
	var err := req.request(_debug_server_url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(payload))
	if err != OK:
		req.queue_free()

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
	_chat_stream_service.start_chat_stream(self, user_message, history_type)
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

func _send_emotion_analysis(user_message: String) -> void:
	_update_script()
	_memory_emotion_service.send_emotion_analysis(self, user_message)

func _send_memory_extraction(history_type: String = "story_chat") -> void:
	_update_script()
	_memory_emotion_service.send_memory_extraction(self, history_type)

func set_next_memory_context(memory_context: Dictionary = {}) -> void:
	_memory_emotion_service.set_next_memory_context(self, memory_context)

func _prepare_memory_request_context(memory_context: Dictionary = {}) -> void:
	_memory_emotion_service.prepare_memory_request_context(self, memory_context)

func _clear_memory_request_context() -> void:
	_memory_emotion_service.clear_memory_request_context(self)

func extract_memory_from_chat(user_text: String, ai_reply: String, memory_context: Dictionary = {}) -> void:
	_update_script()
	_memory_emotion_service.extract_memory_from_chat(self, user_text, ai_reply, memory_context)


func call_chat_api_non_stream(api_messages: Array) -> void:
	_update_script()
	if not is_inside_tree() or _is_api_key_empty():
		chat_request_failed.emit("API Key未设置，请在设置界面配置。")
		return
		
	if chat_http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		chat_http.cancel_request()
		
	var body = {
		"model": get_chat_model_id(),
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

func get_history_messages(limit: int = 10, is_chat: bool = true, history_type: String = "all") -> Array:
	return _get_history_messages(limit, is_chat, history_type)

func start_chat_stream_with_messages(api_messages: Array) -> void:
	_update_script()
	if not is_inside_tree() or _is_api_key_empty():
		chat_request_failed.emit("API Key未设置，请在设置界面配置。")
		return
	_chat_stream_service.start_chat_stream_with_messages(self, api_messages)

func _process(_delta: float) -> void:
	_chat_stream_service.process_chat_stream(self)

func _stop_chat_stream() -> void:
	_chat_stream_service.stop_chat_stream(self)

func is_chat_streaming() -> bool:
	return _chat_stream_service.is_chat_streaming(self)

func get_chat_stream_full_text() -> String:
	return _chat_stream_service.get_chat_stream_full_text(self)

func stop_chat_stream() -> void:
	_stop_chat_stream()

func cancel_chat_request() -> void:
	_stop_chat_stream()
	if chat_http and chat_http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		chat_http.cancel_request()

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
		"model": get_chat_model_id(),
		"messages": api_messages,
		"temperature": 0.7,
		"max_tokens": 150
	}
	body["response_format"] = {"type": "json_object"}
	
	if options_http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		options_http.cancel_request()
		
	options_http.request(_get_url(), _get_headers(), HTTPClient.METHOD_POST, JSON.stringify(body))

func send_emotion_generation(last_ai_reply: String) -> void:
	_update_script()
	if _is_api_key_empty():
		emotion_request_failed.emit("API Key未设置")
		return
	_memory_emotion_service.send_emotion_generation(self, last_ai_reply)

func send_narrator_generation() -> void:
	_update_script()
	if _is_api_key_empty():
		narrator_request_failed.emit("API Key未设置")
		return
	_narrative_service.send_narrator_generation(self)

func send_character_mood_analysis(character_message: String) -> void:
	_update_script()
	if _is_api_key_empty():
		character_mood_request_failed.emit("API Key未设置")
		return
	_narrative_service.send_character_mood_analysis(self, character_message)

func analyze_mood_sync(character_message: String) -> String:
	_update_script()
	if _is_api_key_empty():
		return ""
	return await _narrative_service.analyze_mood_sync(self, character_message)

func generate_dynamic_topics(prompt: String, callback: Callable) -> void:
	_update_script()
	_narrative_service.generate_dynamic_topics(self, prompt, callback)

func generate_npc_event_dialogue(npc_id: String, event_desc: String) -> void:
	_update_script()
	if _is_api_key_empty():
		print("未配置 API Key")
		npc_event_dialogue_failed.emit("未配置 API Key")
		return
	_narrative_service.generate_npc_event_dialogue(self, npc_id, event_desc)

func send_diary_generation() -> void:
	_update_script()
	if _is_api_key_empty():
		diary_error.emit("API Key未设置")
		return
	_social_content_service.send_diary_generation(self)

func _on_chat_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_handle_response(result, response_code, body, chat_request_completed, chat_request_failed)

func _on_emotion_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_handle_response(result, response_code, body, emotion_request_completed, emotion_request_failed)

func _on_memory_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_memory_emotion_service.handle_memory_completed(self, result, response_code, body)

func _on_options_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_handle_response(result, response_code, body, options_request_completed, options_request_failed)

func _on_narrator_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_handle_response(result, response_code, body, narrator_request_completed, narrator_request_failed)

func _on_character_mood_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_handle_response(result, response_code, body, character_mood_request_completed, character_mood_request_failed)

func _on_npc_event_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_narrative_service.handle_npc_event_completed(self, response_code, body)

func _on_diary_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_social_content_service.handle_diary_request_completed(self, result, response_code, _headers, body)

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
	_social_content_service.send_moment_generation(self, custom_profile)

func _on_moment_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_social_content_service.handle_moment_request_completed(self, result, response_code, _headers, body)

func send_moment_reply(post_id: String, comment: String) -> void:
	_update_script()
	if _is_api_key_empty():
		moment_reply_error.emit("API Key未设置")
		return
	_social_content_service.send_moment_reply(self, post_id, comment)

func _on_moment_reply_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_social_content_service.handle_moment_reply_request_completed(self, result, response_code, _headers, body)

func generate_date_story(context: Dictionary) -> void:
	_update_script()
	if _is_api_key_empty():
		date_story_error.emit("API Key未设置")
		return
	_scene_event_service.generate_date_story(self, context)

func generate_schedule_event(course_name: String, course_desc: String, context: Dictionary = {}) -> void:
	_update_script()
	if _is_api_key_empty():
		schedule_event_error.emit("API Key未设置")
		return
	_scene_event_service.generate_schedule_event(self, course_name, course_desc, context)

func resolve_schedule_event(course_name: String, event_desc: String, chosen_option: String, context: Dictionary = {}) -> void:
	_update_script()
	if _is_api_key_empty():
		schedule_event_resolve_error.emit("API Key未设置")
		return
	_scene_event_service.resolve_schedule_event(self, course_name, event_desc, chosen_option, context)

func _on_date_story_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_scene_event_service.handle_date_story_completed(self, result, response_code, _headers, body)

func _on_schedule_event_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_scene_event_service.handle_schedule_event_completed(self, result, response_code, _headers, body)

func _on_schedule_resolve_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_scene_event_service.handle_schedule_resolve_completed(self, result, response_code, _headers, body)

func send_image_to_image_request(base64_image: String, prompt: String) -> void:
	_update_script()
	_social_content_service.send_image_to_image_request(self, base64_image, prompt)

func send_idle_quote_generation(char_id: String) -> void:
	_update_script()
	if _is_api_key_empty():
		idle_quote_failed.emit("API Key未设置")
		return
	_idle_quote_service.send_idle_quote_generation(self, char_id)

func _on_idle_quote_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	_idle_quote_service.handle_idle_quote_completed(self, result, response_code, headers, body)
