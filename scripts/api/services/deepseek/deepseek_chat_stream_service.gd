extends RefCounted

func start_chat_stream(client, user_message: String, history_type: String = "all") -> void:
	if not client.is_inside_tree() or client._is_api_key_empty():
		client.chat_request_failed.emit("API Key未设置，请在设置界面配置。")
		return
	if client._chat_stream_active:
		stop_chat_stream(client)
	var system_prompt: String = GameDataManager.prompt_manager.build_chat_prompt(GameDataManager.profile, user_message, [])
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

func start_chat_stream_with_messages(client, api_messages: Array) -> void:
	if not client.is_inside_tree() or client._is_api_key_empty():
		client.chat_request_failed.emit("API Key未设置，请在设置界面配置。")
		return
	if client._chat_stream_active:
		stop_chat_stream(client)
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
	var host: String = client._get_stream_host()
	client._chat_stream_headers = [
		"Host: " + host,
		"Content-Type: application/json",
		"Authorization: " + client._get_headers()[1].replace("Authorization: ", ""),
		"Accept: text/event-stream",
		"Connection: keep-alive"
	]
	client._chat_stream_client = HTTPClient.new()
	var tls_options := TLSOptions.client()
	var err: int = client._chat_stream_client.connect_to_host(host, 443, tls_options)
	if err != OK:
		stop_chat_stream(client)
		client.chat_request_failed.emit("网络请求发送失败。")
		return
	client._chat_stream_active = true
	client.set_process(true)
	client.chat_stream_started.emit()

func process_chat_stream(client) -> void:
	if not client._chat_stream_active or client._chat_stream_client == null:
		return
	client._chat_stream_client.poll()
	var status = client._chat_stream_client.get_status()
	var path: String = client._get_stream_path()
	if status == HTTPClient.STATUS_CONNECTED and not client._chat_stream_request_sent:
		var err: int = client._chat_stream_client.request(HTTPClient.METHOD_POST, path, client._chat_stream_headers, client._chat_stream_body)
		if err != OK:
			stop_chat_stream(client)
			client.chat_request_failed.emit("网络请求发送失败。")
			return
		client._chat_stream_request_sent = true
		return
	if status == HTTPClient.STATUS_BODY:
		if client._chat_stream_response_code == 0:
			client._chat_stream_response_code = client._chat_stream_client.get_response_code()
			if client._chat_stream_response_code != 200:
				var err_body: String = _read_all_stream_body(client)
				stop_chat_stream(client)
				var err_msg: String = "API 请求错误，状态码: " + str(client._chat_stream_response_code)
				var json := JSON.new()
				if json.parse(err_body) == OK and json.get_data() is Dictionary and json.get_data().has("error"):
					var api_error = json.get_data()["error"]
					if api_error is Dictionary and api_error.has("message"):
						err_msg += " - " + api_error["message"]
				else:
					err_msg += " Body: " + err_body
				client.chat_request_failed.emit(err_msg)
				return
		var chunk: PackedByteArray = client._chat_stream_client.read_response_body_chunk()
		if chunk.size() > 0:
			client._chat_stream_sse_buffer += chunk.get_string_from_utf8()
			_consume_sse_buffer(client)
		return
	if status == HTTPClient.STATUS_DISCONNECTED:
		if client._chat_stream_full_text.strip_edges() == "":
			stop_chat_stream(client)
			client.chat_request_failed.emit("返回数据解析失败")
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
	stop_chat_stream(client)
	client.chat_request_completed.emit({
		"choices": [
			{"message": {"content": final_text}}
		]
	})

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

func is_chat_streaming(client) -> bool:
	return client._chat_stream_active

func get_chat_stream_full_text(client) -> String:
	return client._chat_stream_full_text
