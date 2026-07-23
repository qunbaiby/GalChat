extends Node
class_name DeepSeekClient

signal chat_request_completed(response: Dictionary)
signal chat_request_failed(error_message: String)
signal chat_stream_delta(delta_text: String)
signal chat_stream_started()
signal structured_chat_request_completed(response: Dictionary, request_context: Dictionary)
signal structured_chat_request_failed(error_message: String, request_context: Dictionary)

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
signal date_story_generated_detailed(script_data: Dictionary, metadata: Dictionary)
signal date_story_error_detailed(error_msg: String, metadata: Dictionary)

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
var _chat_stream_retry_count: int = 0
var _active_chat_request_context: Dictionary = {}
var _last_chat_request_context: Dictionary = {}
var _structured_chat_request_id: int = 0
var _structured_chat_requests: Dictionary = {}
var _pending_memory_context: Dictionary = {}
var _active_memory_context: Dictionary = {}
var _pending_memory_manager_override = null
var _active_memory_manager_override = null
var _active_cognition_task_id: String = ""
var _active_cognition_task_scope: Dictionary = {}
var _active_cognition_task: Dictionary = {}
var _cognition_retry_timer: SceneTreeTimer
var _vision_request_context: Dictionary = {}
var _vision_auth_retried: bool = false
var _idle_quote_service = DeepSeekIdleQuoteService.new()
var _scene_event_service = DeepSeekSceneEventService.new()
var _social_content_service = DeepSeekSocialContentService.new()
var _memory_emotion_service = DeepSeekMemoryEmotionService.new()
var _narrative_service = DeepSeekNarrativeService.new()
var _chat_stream_service = DeepSeekChatStreamService.new()

func _ready() -> void:
	_update_script()
	_reinitialize_http_nodes()
	if GameDataManager.cognition_task_queue and not GameDataManager.cognition_task_queue.task_enqueued.is_connected(_process_cognition_queue):
		GameDataManager.cognition_task_queue.task_enqueued.connect(_process_cognition_queue)
	call_deferred("_process_cognition_queue")

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
	diary_http = reset_node.call("DiaryHTTP", 60.0, "request_completed", "_on_diary_request_completed")
	vision_http = reset_node.call("VisionHTTP", 30.0, "request_completed", "_on_vision_completed")
	moment_http = reset_node.call("MomentHTTP", 0.0, "request_completed", "_on_moment_request_completed")
	moment_reply_http = reset_node.call("MomentReplyHTTP", 15.0, "request_completed", "_on_moment_reply_request_completed")
	schedule_event_http = reset_node.call("ScheduleEventHTTP", 20.0, "request_completed", "_on_schedule_event_completed")
	schedule_resolve_http = reset_node.call("ScheduleResolveHTTP", 20.0, "request_completed", "_on_schedule_resolve_completed")
	date_story_http = reset_node.call("DateStoryHTTP", 35.0, "request_completed", "_on_date_story_completed")
	idle_quote_http = reset_node.call("IdleQuoteHTTP", 15.0, "request_completed", "_on_idle_quote_completed")

func _is_api_key_empty() -> bool:
	return not _has_chat_credentials()

func _uses_official_ai() -> bool:
	return GameDataManager.config.ai_service_mode == ConfigResource.AI_SERVICE_OFFICIAL

func _has_chat_credentials() -> bool:
	if _uses_official_ai():
		return not GameDataManager.config.official_access_token.is_empty()
	return not GameDataManager.config.api_key.is_empty()

func _get_missing_credentials_message() -> String:
	if _uses_official_ai():
		return "官方 AI 服务尚未登录或授权，请先登录后重试。"
	return "API Key 未设置，请在设置界面配置。"

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
	if _uses_official_ai() and model_id == "deepseek-coder":
		return "deepseek-chat"
	return model_id

func _get_headers() -> Array:
	var access_token: String = GameDataManager.config.official_access_token if _uses_official_ai() else GameDataManager.config.api_key
	return [
		"Content-Type: application/json",
		"Authorization: Bearer " + access_token
	]

func _get_url() -> String:
	if _uses_official_ai():
		return GameDataManager.config.official_ai_gateway_url.trim_suffix("/") + "/chat/completions"
	return "https://api.deepseek.com/v1/chat/completions"

func _get_stream_endpoint() -> Dictionary:
	var url: String = _get_url()
	var regex := RegEx.new()
	if regex.compile("^(https?)://([^/:]+)(?::([0-9]+))?(/.*)$") != OK:
		return {}
	var matched := regex.search(url)
	if matched == null:
		return {}
	var scheme: String = matched.get_string(1)
	var port_text: String = matched.get_string(3)
	return {
		"host": matched.get_string(2),
		"port": int(port_text) if not port_text.is_empty() else (443 if scheme == "https" else 80),
		"path": matched.get_string(4),
		"tls": scheme == "https"
	}

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

func send_chat_message(user_message: String, history_type: String = "all", prompt_access_context: Dictionary = {}) -> void:
	_update_script()
	send_chat_message_stream(user_message, history_type, prompt_access_context)

func send_chat_message_stream(user_message: String, history_type: String = "all", prompt_access_context: Dictionary = {}) -> void:
	_update_script()
	_chat_stream_service.start_chat_stream(self, user_message, history_type, prompt_access_context)
	_send_emotion_analysis(user_message)

func send_chat_message_structured(user_message: String, history_type: String = "all", request_context: Dictionary = {}, prompt_access_context: Dictionary = {}) -> int:
	_update_script()
	_structured_chat_request_id += 1
	var context := request_context.duplicate(true)
	context["request_id"] = _structured_chat_request_id
	_prepare_structured_chat_request(user_message, history_type, context, prompt_access_context)
	_send_emotion_analysis(user_message)
	return _structured_chat_request_id

func _prepare_structured_chat_request(user_message: String, history_type: String, context: Dictionary, prompt_access_context: Dictionary = {}) -> void:
	var system_prompt: String = await GameDataManager.memory_retrieval_service.build_chat_prompt(
		GameDataManager.profile,
		user_message,
		null,
		"story_chat" if history_type == "story_chat" else "main_chat",
		prompt_access_context
	)
	var api_messages: Array = [{"role": "system", "content": system_prompt}]
	api_messages.append_array(_get_history_messages(10, true, history_type))
	api_messages.append({"role": "user", "content": user_message})
	_start_structured_chat_request(api_messages, context)

func _start_structured_chat_request(api_messages: Array, request_context: Dictionary) -> void:
	if not is_inside_tree() or _is_api_key_empty():
		structured_chat_request_failed.emit.call_deferred(_get_missing_credentials_message(), request_context)
		return
	var request := HTTPRequest.new()
	request.timeout = 60.0
	add_child(request)
	var request_id := int(request_context.get("request_id", 0))
	_structured_chat_requests[request_id] = request
	request.request_completed.connect(_on_structured_chat_completed.bind(request, request_context), CONNECT_ONE_SHOT)
	var body := {
		"model": get_chat_model_id(),
		"messages": api_messages,
		"temperature": GameDataManager.config.temperature,
		"max_tokens": GameDataManager.config.max_tokens,
		"stream": false,
		"response_format": {"type": "json_object"}
	}
	var error := request.request(_get_url(), _get_headers(), HTTPClient.METHOD_POST, JSON.stringify(body))
	if error != OK:
		_cleanup_structured_chat_request(request_id, request)
		structured_chat_request_failed.emit.call_deferred("网络请求发送失败: %s" % error, request_context)

func _on_structured_chat_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, request: HTTPRequest, request_context: Dictionary) -> void:
	var request_id := int(request_context.get("request_id", 0))
	_cleanup_structured_chat_request(request_id, request)
	if result == HTTPRequest.RESULT_TIMEOUT:
		structured_chat_request_failed.emit(GameDataManager.profile.char_name + " 似乎走神了...", request_context)
		return
	if response_code != 200:
		structured_chat_request_failed.emit("API 请求错误，状态码: %d" % response_code, request_context)
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if parsed is Dictionary:
		structured_chat_request_completed.emit(parsed, request_context)
	else:
		structured_chat_request_failed.emit("返回数据解析失败", request_context)

func _cleanup_structured_chat_request(request_id: int, request: HTTPRequest) -> void:
	_structured_chat_requests.erase(request_id)
	if is_instance_valid(request):
		request.queue_free()

func cancel_structured_chat_requests() -> void:
	for request_value in _structured_chat_requests.values():
		if request_value is HTTPRequest and is_instance_valid(request_value):
			(request_value as HTTPRequest).cancel_request()
			(request_value as HTTPRequest).queue_free()
	_structured_chat_requests.clear()

func cancel_structured_chat_request(request_id: int) -> void:
	var request_value: Variant = _structured_chat_requests.get(request_id)
	if request_value is HTTPRequest and is_instance_valid(request_value):
		(request_value as HTTPRequest).cancel_request()
		(request_value as HTTPRequest).queue_free()
	_structured_chat_requests.erase(request_id)



func send_vision_request(system_prompt: String, user_prompt: String, base64_image: String, image_media_type: String = "image/jpeg", auth_retried: bool = false) -> void:
	if not is_inside_tree():
		vision_request_failed.emit("Vision 服务尚未就绪。")
		return
	if image_media_type != "image/jpeg" and image_media_type != "image/png":
		vision_request_failed.emit("Vision 仅支持 JPEG 或 PNG 图片。")
		return
	if _uses_official_ai() and not await OfficialAuthManager.ensure_valid_access_token():
		vision_request_failed.emit("登录状态已失效，请重新登录后使用官方图像理解服务。")
		return
	if not _uses_official_ai() and GameDataManager.config.vision_api_key.is_empty():
		vision_request_failed.emit("Vision API Key未设置，请在设置界面配置。")
		return

	var url: String
	var headers: PackedStringArray = ["Content-Type: application/json"]
	var body: Dictionary
	if _uses_official_ai():
		url = GameDataManager.config.official_ai_gateway_url.trim_suffix("/") + "/vision/responses"
		headers.append("Authorization: Bearer " + GameDataManager.config.official_access_token)
		body = {
			"system_prompt": system_prompt,
			"user_prompt": user_prompt,
			"image_base64": base64_image,
			"image_media_type": image_media_type
		}
	else:
		url = GameDataManager.config.vision_base_url
		if url.ends_with("/chat/completions"):
			url = url.replace("/chat/completions", "/responses")
		elif not url.ends_with("/responses"):
			url += "/responses"
		headers.append("Authorization: Bearer " + GameDataManager.config.vision_api_key)
		var model_name: String = GameDataManager.config.vision_model
		if model_name.is_empty() or model_name == "ep-xxxxxx":
			model_name = "doubao-seed-2-0-lite-260428"
		body = {
			"model": model_name,
			"input": [{
				"role": "user",
				"content": [
					{"type": "input_image", "image_url": "data:%s;base64,%s" % [image_media_type, base64_image]},
					{"type": "input_text", "text": system_prompt + "\n\n" + user_prompt}
				]
			}]
		}

	_vision_request_context = {
		"system_prompt": system_prompt,
		"user_prompt": user_prompt,
		"base64_image": base64_image,
		"image_media_type": image_media_type
	}
	_vision_auth_retried = auth_retried
	
	if vision_http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		vision_http.cancel_request()

	var request_error: Error = vision_http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if request_error != OK:
		vision_request_failed.emit("Vision 请求发送失败，错误码：%d" % request_error)

func _on_vision_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code == 401 and _uses_official_ai() and not _vision_auth_retried:
		var request_context: Dictionary = _vision_request_context.duplicate(true)
		if await OfficialAuthManager.force_refresh_access_token():
			send_vision_request(
				str(request_context.get("system_prompt", "")),
				str(request_context.get("user_prompt", "")),
				str(request_context.get("base64_image", "")),
				str(request_context.get("image_media_type", "image/jpeg")),
				true
			)
		else:
			vision_request_failed.emit("登录状态已失效，请重新登录后使用官方图像理解服务。")
		return
	_handle_response(result, response_code, body, vision_request_completed, vision_request_failed)

func _send_emotion_analysis(user_message: String) -> void:
	_update_script()
	_memory_emotion_service.send_emotion_analysis(self, user_message)

func _send_memory_extraction(history_type: String = "story_chat") -> void:
	_update_script()
	_memory_emotion_service.send_memory_extraction(self, history_type)

func _send_memory_extraction_with_manager(history_type: String = "story_chat", memory_manager_override = null) -> void:
	_update_script()
	_memory_emotion_service.send_memory_extraction(self, history_type, memory_manager_override)

func set_next_memory_context(memory_context: Dictionary = {}) -> void:
	_memory_emotion_service.set_next_memory_context(self, memory_context)

func set_next_memory_context_with_manager(memory_context: Dictionary = {}, memory_manager_override = null) -> void:
	_memory_emotion_service.set_next_memory_context(self, memory_context, memory_manager_override)

func _prepare_memory_request_context(memory_context: Dictionary = {}) -> void:
	_memory_emotion_service.prepare_memory_request_context(self, memory_context)

func _clear_memory_request_context() -> void:
	_memory_emotion_service.clear_memory_request_context(self)

func extract_memory_from_chat(user_text: String, ai_reply: String, memory_context: Dictionary = {}) -> void:
	_update_script()
	_memory_emotion_service.extract_memory_from_chat(self, user_text, ai_reply, memory_context)

func extract_memory_from_chat_with_manager(user_text: String, ai_reply: String, memory_context: Dictionary = {}, memory_manager_override = null) -> void:
	_update_script()
	_memory_emotion_service.extract_memory_from_chat(self, user_text, ai_reply, memory_context, memory_manager_override)

func _process_cognition_queue() -> void:
	_memory_emotion_service.process_cognition_queue(self)


func call_chat_api_non_stream(api_messages: Array, response_format: Dictionary = {}) -> void:
	_update_script()
	if not is_inside_tree() or _is_api_key_empty():
		chat_request_failed.emit(_get_missing_credentials_message())
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
	if not response_format.is_empty():
		body["response_format"] = response_format.duplicate(true)
	
	if chat_http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		chat_http.cancel_request()
		
	var err = chat_http.request(_get_url(), _get_headers(), HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		chat_request_failed.emit("网络请求发送失败: " + str(err))

func get_history_messages(limit: int = 10, is_chat: bool = true, history_type: String = "all") -> Array:
	return _get_history_messages(limit, is_chat, history_type)

func start_chat_stream_with_messages(api_messages: Array, request_context: Dictionary = {}) -> void:
	_update_script()
	if not is_inside_tree() or _is_api_key_empty():
		chat_request_failed.emit(_get_missing_credentials_message())
		return
	_chat_stream_service.start_chat_stream_with_messages(self, api_messages, request_context)

func mark_chat_response_adopted(adopted_text: String, segment_index: int = 0) -> Dictionary:
	var context := _last_chat_request_context.duplicate(true)
	var trace_id := str(context.get("trace_id", ""))
	if trace_id.is_empty() or adopted_text.strip_edges().is_empty() or GameDataManager.memory_retrieval_trace_service == null:
		return {}
	if not GameDataManager.memory_retrieval_trace_service.mark_response_adopted(trace_id, adopted_text, segment_index):
		return {}
	return {
		"ai_request_id": str(context.get("request_id", "")),
		"memory_trace_id": trace_id,
		"response_segment_index": segment_index,
		"response_adopted": true
	}

func _process(_delta: float) -> void:
	_chat_stream_service.process_chat_stream(self)

func _stop_chat_stream() -> void:
	_chat_stream_service.stop_chat_stream(self)

func is_chat_streaming() -> bool:
	return _chat_stream_service.is_chat_streaming(self)

func get_chat_stream_full_text() -> String:
	return _chat_stream_service.get_chat_stream_full_text(self)

func stop_chat_stream() -> void:
	_chat_stream_service.cancel_chat_stream(self)

func cancel_chat_request() -> void:
	_chat_stream_service.cancel_chat_stream(self)
	if chat_http and chat_http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		chat_http.cancel_request()

func send_options_generation(last_ai_reply: String = "", free_chat_strategy: String = "", history_type: String = "all", history_subtype: String = "") -> void:
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
	if history_subtype != "":
		history_msgs = history_msgs.filter(func(message: Dictionary) -> bool:
			return str(message.get("subtype", "")) == history_subtype
		)
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
		var error_message := _get_missing_credentials_message()
		date_story_error.emit(error_message)
		date_story_error_detailed.emit(error_message, {"http_status": 0, "request_result": -1})
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

func send_idle_quote_generation(char_id: String, options: Dictionary = {}) -> void:
	_update_script()
	if _is_api_key_empty():
		idle_quote_failed.emit("API Key未设置")
		return
	_idle_quote_service.set_request_options(options)
	_idle_quote_service.send_idle_quote_generation(self, char_id)

func _on_idle_quote_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	_idle_quote_service.handle_idle_quote_completed(self, result, response_code, headers, body)
