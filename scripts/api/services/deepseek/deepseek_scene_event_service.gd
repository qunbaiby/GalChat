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
	var retry_count: int = int(context.get("date_story_retry_count", 0))
	var plan_segments: Array = context.get("date_plan", [])
	var single_segment_mode: bool = plan_segments.size() <= 1
	var body = {
		"model": client.get_chat_model_id(),
		"messages": api_messages,
		"temperature": 0.3 if retry_count > 0 else 0.38,
		"max_tokens": 1000 if retry_count > 0 else (1400 if single_segment_mode else 1500)
	}
	body["response_format"] = {"type": "json_object"}
	# #region debug-point A:date-story-request
	client._debug_report("A", "deepseek_scene_event_service.gd:generate_date_story", "prepare date story request", {
		"model": client.get_chat_model_id(),
		"temperature": body.get("temperature", null),
		"max_tokens": body.get("max_tokens", null),
		"retry_count": retry_count,
		"plan_count": plan_segments.size(),
		"location_names": context.get("location_names", [])
	})
	# #endregion
	if client.date_story_http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		client.date_story_http.cancel_request()
	var err: int = client.date_story_http.request(client._get_url(), client._get_headers(), HTTPClient.METHOD_POST, JSON.stringify(body))
	# #region debug-point A:date-story-request-dispatch
	client._debug_report("A", "deepseek_scene_event_service.gd:generate_date_story", "dispatch date story request", {
		"request_error": err,
		"url": client._get_url()
	})
	# #endregion

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

func _inspect_json_object_from_response(body: PackedByteArray) -> Dictionary:
	var result := {
		"outer_ok": false,
		"content_ok": false,
		"outer_error_line": -1,
		"outer_error_message": "",
		"content_error_line": -1,
		"content_error_message": "",
		"content_length": 0,
		"content_prefix": "",
		"content_suffix": ""
	}
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		result["outer_error_line"] = json.get_error_line()
		result["outer_error_message"] = json.get_error_message()
		return result
	result["outer_ok"] = true
	var data: Variant = json.get_data()
	if not (data is Dictionary and data.has("choices") and data["choices"].size() > 0):
		result["outer_error_message"] = "outer payload missing choices"
		return result
	var content: String = str(data["choices"][0]["message"]["content"]).strip_edges()
	if content.begins_with("```json"):
		content = content.replace("```json", "")
	if content.begins_with("```"):
		content = content.replace("```", "")
	if content.ends_with("```"):
		content = content.substr(0, content.length() - 3)
	content = content.strip_edges()
	result["content_length"] = content.length()
	result["content_prefix"] = content.left(200)
	result["content_suffix"] = content.right(min(200, content.length()))
	var content_json := JSON.new()
	if content_json.parse(content) != OK:
		result["content_error_line"] = content_json.get_error_line()
		result["content_error_message"] = content_json.get_error_message()
		return result
	result["content_ok"] = true
	return result

func _extract_error_message(body: PackedByteArray) -> String:
	var raw_text := body.get_string_from_utf8().strip_edges()
	if raw_text == "":
		return ""
	var json := JSON.new()
	if json.parse(raw_text) != OK:
		return raw_text.left(180)
	var data: Variant = json.get_data()
	if data is Dictionary:
		var error_data: Variant = data.get("error", null)
		if error_data is Dictionary:
			var message := str(error_data.get("message", "")).strip_edges()
			if message != "":
				return message
		var message := str(data.get("message", "")).strip_edges()
		if message != "":
			return message
	return raw_text.left(180)

func handle_date_story_completed(client, result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	# #region debug-point B:date-story-response
	client._debug_report("B", "deepseek_scene_event_service.gd:handle_date_story_completed", "date story response received", {
		"result": result,
		"http_code": response_code,
		"body_preview": body.get_string_from_utf8().strip_edges().left(240)
	})
	# #endregion
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		var script_data: Variant = _extract_json_object_from_response(body)
		if script_data is Dictionary:
			# #region debug-point C:date-story-parse-ok
			client._debug_report("C", "deepseek_scene_event_service.gd:handle_date_story_completed", "date story parsed as dictionary", {
				"top_level_keys": (script_data as Dictionary).keys(),
				"has_segments": (script_data as Dictionary).get("segments", null) is Array,
				"segment_count": ((script_data as Dictionary).get("segments", []) as Array).size(),
				"segment_line_counts": _summarize_segment_line_counts((script_data as Dictionary).get("segments", [])),
				"segment_char_counts": _summarize_segment_char_counts((script_data as Dictionary).get("segments", []))
			})
			# #endregion
			client.date_story_generated.emit(script_data)
			return
		var raw_preview := body.get_string_from_utf8().strip_edges().left(240)
		var inspect := _inspect_json_object_from_response(body)
		# #region debug-point C:date-story-parse-failed
		client._debug_report("C", "deepseek_scene_event_service.gd:handle_date_story_completed", "date story parse failed", {
			"http_code": response_code,
			"raw_preview": raw_preview,
			"inspect": inspect
		})
		# #endregion
		client.date_story_error.emit("约会剧情响应不是有效 JSON，可能是模型输出被截断或格式不符。响应片段：%s" % raw_preview)
		return
	var detail := _extract_error_message(body)
	var message := "约会剧情生成失败 (HTTP %d)" % response_code
	if result != HTTPRequest.RESULT_SUCCESS:
		message = "约会剧情请求失败 (Result %d, HTTP %d)" % [result, response_code]
	if detail != "":
		message += "：%s" % detail
	# #region debug-point B:date-story-failed
	client._debug_report("B", "deepseek_scene_event_service.gd:handle_date_story_completed", "date story request failed", {
		"result": result,
		"http_code": response_code,
		"detail": detail
	})
	# #endregion
	client.date_story_error.emit(message)


func _summarize_segment_line_counts(raw_segments: Variant) -> Array:
	var counts: Array = []
	if not raw_segments is Array:
		return counts
	for segment in raw_segments:
		if segment is Dictionary:
			var lines: Variant = (segment as Dictionary).get("lines", [])
			counts.append((lines as Array).size() if lines is Array else 0)
		else:
			counts.append(0)
	return counts


func _summarize_segment_char_counts(raw_segments: Variant) -> Array:
	var counts: Array = []
	if not raw_segments is Array:
		return counts
	for segment in raw_segments:
		var total: int = 0
		if segment is Dictionary:
			var lines: Variant = (segment as Dictionary).get("lines", [])
			if lines is Array:
				for line in lines:
					if line is Dictionary:
						total += str((line as Dictionary).get("content", "")).strip_edges().length()
		counts.append(total)
	return counts

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
