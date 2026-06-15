extends RefCounted

func generate_date_story(client, context: Dictionary) -> void:
	while not client.is_inside_tree():
		await Engine.get_main_loop().process_frame
	var system_prompt: String = GameDataManager.prompt_manager.build_date_story_prompt(context)
	var user_prompt: String = JSON.stringify(context, "\t")
	var api_messages = [
		{"role": "system", "content": system_prompt},
		{"role": "user", "content": user_prompt}
	]
	var body = {
		"model": client.get_chat_model_id(),
		"messages": api_messages,
		"temperature": 0.9,
		"max_tokens": 1800
	}
	body["response_format"] = {"type": "json_object"}
	if client.date_story_http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		client.date_story_http.cancel_request()
	client.date_story_http.request(client._get_url(), client._get_headers(), HTTPClient.METHOD_POST, JSON.stringify(body))

func generate_schedule_event(client, course_name: String, course_desc: String, context: Dictionary = {}) -> void:
	while not client.is_inside_tree():
		await Engine.get_main_loop().process_frame
	var full_context: Dictionary = context.duplicate()
	full_context["course_name"] = course_name
	full_context["course_desc"] = course_desc
	var system_prompt: String = GameDataManager.prompt_manager.build_schedule_event_prompt(full_context)
	var user_prompt: String = JSON.stringify(full_context, "\t")
	var api_messages = [
		{"role": "system", "content": system_prompt},
		{"role": "user", "content": user_prompt}
	]
	var body = {
		"model": client.get_chat_model_id(),
		"messages": api_messages,
		"temperature": 0.7,
		"max_tokens": 150
	}
	body["response_format"] = {"type": "json_object"}
	if client.schedule_event_http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		client.schedule_event_http.cancel_request()
	client.schedule_event_http.request(client._get_url(), client._get_headers(), HTTPClient.METHOD_POST, JSON.stringify(body))

func resolve_schedule_event(client, course_name: String, event_desc: String, chosen_option: String, context: Dictionary = {}) -> void:
	while not client.is_inside_tree():
		await Engine.get_main_loop().process_frame
	var full_context: Dictionary = context.duplicate()
	full_context["course_name"] = course_name
	full_context["event_desc"] = event_desc
	full_context["chosen_option"] = chosen_option
	var system_prompt: String = GameDataManager.prompt_manager.build_schedule_resolve_prompt(full_context)
	var user_prompt: String = JSON.stringify(full_context, "\t")
	var api_messages = [
		{"role": "system", "content": system_prompt},
		{"role": "user", "content": user_prompt}
	]
	var body = {
		"model": client.get_chat_model_id(),
		"messages": api_messages,
		"temperature": 0.7,
		"max_tokens": 150
	}
	body["response_format"] = {"type": "json_object"}
	if client.schedule_resolve_http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		client.schedule_resolve_http.cancel_request()
	client.schedule_resolve_http.request(client._get_url(), client._get_headers(), HTTPClient.METHOD_POST, JSON.stringify(body))

func _extract_json_object_from_response(body: PackedByteArray) -> Variant:
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		return null
	var data: Variant = json.get_data()
	if not (data is Dictionary and data.has("choices") and data["choices"].size() > 0):
		return null
	var content: String = str(data["choices"][0]["message"]["content"]).strip_edges()
	if content.begins_with("```json"):
		content = content.replace("```json", "")
	if content.begins_with("```"):
		content = content.replace("```", "")
	if content.ends_with("```"):
		content = content.substr(0, content.length() - 3)
	content = content.strip_edges()
	var content_json := JSON.new()
	if content_json.parse(content) != OK:
		return null
	return content_json.get_data()

func handle_date_story_completed(client, result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		var script_data: Variant = _extract_json_object_from_response(body)
		if script_data is Dictionary:
			client.date_story_generated.emit(script_data)
			return
	client.date_story_error.emit("约会剧情生成失败 (Code: %d)" % response_code)

func handle_schedule_event_completed(client, result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		var event_data: Variant = _extract_json_object_from_response(body)
		if event_data is Dictionary:
			if event_data.has("description") and not event_data.has("event_desc"):
				event_data["event_desc"] = event_data["description"]
			if not event_data.has("options"):
				var opts: Array = []
				if event_data.has("option1"):
					opts.append({"text": event_data["option1"]})
				if event_data.has("option2"):
					opts.append({"text": event_data["option2"]})
				event_data["options"] = opts
			client.schedule_event_generated.emit(event_data)
			return
	client.schedule_event_error.emit("事件生成失败 (Code: %d)" % response_code)

func handle_schedule_resolve_completed(client, result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		var result_data: Variant = _extract_json_object_from_response(body)
		if result_data is Dictionary:
			if result_data.has("rewards") and not result_data.has("attr_changes"):
				result_data["attr_changes"] = result_data["rewards"]
			client.schedule_event_resolved.emit(result_data)
			return
	client.schedule_event_resolve_error.emit("事件结算失败 (Code: %d)" % response_code)
