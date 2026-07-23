extends RefCounted

func start_chat_stream(client, user_message: String, history_type: String = "all", prompt_access_context: Dictionary = {}) -> void:
	client._chat_stream_retry_count = 0
	if client._chat_stream_active:
		cancel_chat_stream(client)
	client._active_chat_request_context = {}
	if client._uses_official_ai() and not await OfficialAuthManager.ensure_valid_access_token():
		_emit_failure(client, "登录状态已过期，请重新登录后重试。")
		return
	if not client.is_inside_tree() or client._is_api_key_empty():
		_emit_failure(client, client._get_missing_credentials_message())
		return
	var prompt_result: Dictionary = await GameDataManager.memory_retrieval_service.build_chat_prompt_result(
		GameDataManager.profile,
		user_message,
		null,
		"story_chat" if history_type == "story_chat" else "main_chat",
		prompt_access_context
	)
	var system_prompt := str(prompt_result.get("prompt", ""))
	client._active_chat_request_context = {
		"request_id": str(prompt_result.get("request_id", "")),
		"trace_id": str(prompt_result.get("trace_id", "")),
		"rendered_memory_ids": prompt_result.get("rendered_memory_ids", []).duplicate()
	}
	var api_messages = [{"role": "system", "content": system_prompt}]
	api_messages.append_array(client._get_history_messages(10, true, history_type))
	var should_append: bool = true
	if api_messages.size() > 1:
		var last_msg = api_messages[api_messages.size() - 1]
		if last_msg is Dictionary and last_msg.get("role", "") == "user":
			var cleaned_content: String = str(last_msg.get("content", "")).replace(" <--- 【系统提示：这是你们上次聊天的最后一句话，请顺着这个话题继续延展，不要生硬地开启新话题】", "").strip_edges()
			if cleaned_content == user_message.strip_edges():
				should_append = false
	if should_append:
		api_messages.append({"role": "user", "content": user_message})
	_start_stream_request(client, api_messages)

func start_chat_stream_with_messages(client, api_messages: Array, request_context: Dictionary = {}) -> void:
	client._chat_stream_retry_count = 0
	if client._chat_stream_active:
		cancel_chat_stream(client)
	client._active_chat_request_context = request_context.duplicate(true)
	if client._uses_official_ai() and not await OfficialAuthManager.ensure_valid_access_token():
		_emit_failure(client, "登录状态已过期，请重新登录后重试。")
		return
	if not client.is_inside_tree() or client._is_api_key_empty():
		_emit_failure(client, client._get_missing_credentials_message())
		return
	_start_stream_request(client, api_messages)

func _start_stream_request(client, api_messages: Array) -> void:
	var body = {
		"model": client.get_chat_model_id(),
		"messages": api_messages,
		"temperature": GameDataManager.config.temperature,
		"max_tokens": GameDataManager.config.max_tokens,
		"stream": true
	}
	client._chat_stream_full_text = ""
	client._chat_stream_sse_buffer = ""
	client._chat_stream_request_sent = false
	client._chat_stream_body = JSON.stringify(body)
	if GameDataManager.memory_retrieval_trace_service:
		GameDataManager.memory_retrieval_trace_service.mark_request_started(str(client._active_chat_request_context.get("trace_id", "")))
	_connect_stream_request(client)

func _connect_stream_request(client) -> void:
	var endpoint: Dictionary = client._get_stream_endpoint()
	if endpoint.is_empty():
		_emit_failure(client, "AI 服务地址格式无效。")
		return
	var host: String = str(endpoint["host"])
	client._chat_stream_headers = [
		"Host: " + host,
		"Content-Type: application/json",
		"Authorization: " + client._get_headers()[1].replace("Authorization: ", ""),
		"Accept: text/event-stream",
		"Connection: keep-alive"
	]
	client._chat_stream_client = HTTPClient.new()
	var tls_options: TLSOptions = TLSOptions.client() if bool(endpoint["tls"]) else null
	var err: int = client._chat_stream_client.connect_to_host(host, int(endpoint["port"]), tls_options)
	if err != OK:
		_emit_failure(client, "网络请求发送失败。")
		return
	client._chat_stream_active = true
	client.set_process(true)
	client.chat_stream_started.emit()

func process_chat_stream(client) -> void:
	if not client._chat_stream_active or client._chat_stream_client == null:
		return
	client._chat_stream_client.poll()
	var status = client._chat_stream_client.get_status()
	var endpoint: Dictionary = client._get_stream_endpoint()
	var path: String = str(endpoint.get("path", "/"))
	if status == HTTPClient.STATUS_CONNECTED and not client._chat_stream_request_sent:
		var err: int = client._chat_stream_client.request(HTTPClient.METHOD_POST, path, client._chat_stream_headers, client._chat_stream_body)
		if err != OK:
			_emit_failure(client, "网络请求发送失败。")
			return
		client._chat_stream_request_sent = true
		return
	if status == HTTPClient.STATUS_BODY:
		if client._chat_stream_response_code == 0:
			client._chat_stream_response_code = client._chat_stream_client.get_response_code()
			if client._chat_stream_response_code != 200:
				var err_body: String = _read_all_stream_body(client)
				var response_code: int = client._chat_stream_response_code
				var request_body: String = client._chat_stream_body
				stop_chat_stream(client)
				if response_code == 401 and client._uses_official_ai() and client._chat_stream_retry_count == 0:
					client._chat_stream_retry_count = 1
					_retry_after_unauthorized(client, request_body)
					return
				client._chat_stream_retry_count = 0
				_emit_failure(client, _get_http_error_message(response_code, err_body))
				return
		var chunk: PackedByteArray = client._chat_stream_client.read_response_body_chunk()
		if chunk.size() > 0:
			client._chat_stream_sse_buffer += chunk.get_string_from_utf8()
			_consume_sse_buffer(client)
		return
	if status == HTTPClient.STATUS_DISCONNECTED:
		if client._chat_stream_full_text.strip_edges() == "":
			_emit_failure(client, "返回数据解析失败")
		else:
			_finish_chat_stream(client)

func _read_all_stream_body(client) -> String:
	var out: String = ""
	if client._chat_stream_client == null:
		return out
	while true:
		var chunk: PackedByteArray = client._chat_stream_client.read_response_body_chunk()
		if chunk.size() == 0:
			break
		out += chunk.get_string_from_utf8()
	return out

func _retry_after_unauthorized(client, request_body: String) -> void:
	if not await OfficialAuthManager.force_refresh_access_token():
		client._chat_stream_retry_count = 0
		_emit_failure(client, "登录状态已过期，请重新登录后重试。")
		return
	client._chat_stream_body = request_body
	client._chat_stream_full_text = ""
	client._chat_stream_sse_buffer = ""
	client._chat_stream_request_sent = false
	_connect_stream_request(client)

func _get_http_error_message(response_code: int, response_body: String) -> String:
	var detail: String = ""
	var json := JSON.new()
	if json.parse(response_body) == OK and json.get_data() is Dictionary:
		var data: Dictionary = json.get_data()
		detail = str(data.get("detail", "")).strip_edges()
		if detail.is_empty() and data.get("error") is Dictionary:
			detail = str(data["error"].get("message", "")).strip_edges()
	match response_code:
		400:
			if detail == "Requested model is not allowed.":
				return "当前模型不受官方服务支持，请在设置中切换模型。"
			return "AI 请求参数无效，请检查模型设置。"
		401:
			return "登录状态已过期，请重新登录后重试。"
		429:
			if detail == "Daily AI quota exceeded.":
				return "今日官方 AI 额度已用完，请明天再试或切换个人 API。"
			return "请求过于频繁，请稍后再试。"
		503:
			return "官方 AI 服务暂不可用，请稍后重试。"
		_:
			return "AI 服务请求失败（%d）。" % response_code

func _consume_sse_buffer(client) -> void:
	while true:
		var idx: int = client._chat_stream_sse_buffer.find("\n\n")
		if idx == -1:
			break
		var event_text: String = client._chat_stream_sse_buffer.substr(0, idx)
		client._chat_stream_sse_buffer = client._chat_stream_sse_buffer.substr(idx + 2)
		_consume_sse_event(client, event_text)

func _consume_sse_event(client, event_text: String) -> void:
	var lines: PackedStringArray = event_text.split("\n")
	for line in lines:
		var trimmed: String = line.strip_edges()
		if not trimmed.begins_with("data:"):
			continue
		var payload: String = trimmed.substr(5).strip_edges()
		if payload == "" or payload == "[DONE]":
			if payload == "[DONE]":
				_finish_chat_stream(client)
			continue
		var json := JSON.new()
		if json.parse(payload) != OK:
			continue
		var data: Variant = json.get_data()
		if not (data is Dictionary):
			continue
		if data.has("error"):
			var error_message: String = "AI 服务返回错误"
			var api_error: Variant = data["error"]
			if api_error is Dictionary:
				error_message = str(api_error.get("message", error_message)).strip_edges()
			_emit_failure(client, error_message)
			return
		var delta_text: String = ""
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
			client._chat_stream_full_text += delta_text
			client.chat_stream_delta.emit(delta_text)

func _finish_chat_stream(client) -> void:
	if not client._chat_stream_active:
		return
	var final_text: String = client._chat_stream_full_text
	var request_context: Dictionary = client._active_chat_request_context.duplicate(true)
	client._last_chat_request_context = request_context.duplicate(true)
	if GameDataManager.memory_retrieval_trace_service:
		GameDataManager.memory_retrieval_trace_service.mark_response_completed(str(request_context.get("trace_id", "")), final_text)
	stop_chat_stream(client)
	client._chat_stream_retry_count = 0
	var response := {
		"choices": [
			{"message": {"content": final_text}}
		]
	}
	client.chat_request_completed.emit(response)

func stop_chat_stream(client) -> void:
	client._chat_stream_active = false
	client._chat_stream_request_sent = false
	client._chat_stream_body = ""
	client._chat_stream_headers = []
	client._chat_stream_sse_buffer = ""
	client._chat_stream_response_code = 0
	if client._chat_stream_client != null:
		client._chat_stream_client.close()
		client._chat_stream_client = null
	client.set_process(false)

func cancel_chat_stream(client) -> void:
	var context: Dictionary = client._active_chat_request_context.duplicate(true)
	client._last_chat_request_context = context.duplicate(true)
	if GameDataManager.memory_retrieval_trace_service:
		GameDataManager.memory_retrieval_trace_service.mark_request_failed(str(context.get("trace_id", "")), "用户取消请求", true)
	stop_chat_stream(client)
	client._active_chat_request_context = {}

func _emit_failure(client, error_message: String) -> void:
	var context: Dictionary = client._active_chat_request_context.duplicate(true)
	client._last_chat_request_context = context.duplicate(true)
	if GameDataManager.memory_retrieval_trace_service:
		GameDataManager.memory_retrieval_trace_service.mark_request_failed(str(context.get("trace_id", "")), error_message)
	stop_chat_stream(client)
	client._active_chat_request_context = {}
	client.chat_request_failed.emit(error_message)

func is_chat_streaming(client) -> bool:
	return client._chat_stream_active

func get_chat_stream_full_text(client) -> String:
	return client._chat_stream_full_text
