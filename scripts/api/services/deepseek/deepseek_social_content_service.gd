extends RefCounted

var _current_moment_reply_post_id: String = ""

func _save_diary_to_profile(diary_entry: Dictionary) -> void:
	if GameDataManager.profile and GameDataManager.profile.has_method("add_diary"):
		GameDataManager.profile.add_diary(diary_entry)
		if GameDataManager.profile.has_method("save_profile"):
			GameDataManager.profile.save_profile()

func _create_image_client(client):
	var provider: int = 0
	if GameDataManager.config and "image_generation_provider" in GameDataManager.config:
		provider = GameDataManager.config.image_generation_provider
	var image_client
	if provider == 1:
		image_client = preload("res://scripts/api/doubao_image_client.gd").new()
	else:
		image_client = preload("res://scripts/api/openai_image_client.gd").new()
	client.add_child(image_client)
	return image_client

func send_diary_generation(client) -> void:
	while not client.is_inside_tree():
		await Engine.get_main_loop().process_frame
	var prompt_template: String = ""
	var file: FileAccess = FileAccess.open("res://scripts/templates/prompts/diary_generation.txt", FileAccess.READ)
	if file:
		prompt_template = file.get_as_text()
		file.close()
	else:
		client.diary_error.emit("找不到日记生成提示词模板")
		return
	var profile: CharacterProfile = GameDataManager.profile
	var char_name: String = profile.char_name
	var personality: String = GameDataManager.personality_system.get_personality_summary(profile)
	var flavor_label: String = GameDataManager.personality_system.get_relationship_flavor_label(profile)
	var emotion_stage: String = "Stage %d (%s) - 亲密度: %.1f, 信任度: %.1f, 情感风味: %s" % [profile.current_stage, profile.get_current_stage_config().get("stageTitle", ""), profile.intimacy, profile.trust, flavor_label]
	var mood: String = GameDataManager.mood_system.get_macro_mood_name(profile.mood_value)
	var current_expression: String = profile.current_expression
	var expression_db: Dictionary = GameDataManager.expression_system.expression_configs
	if expression_db and expression_db.has(current_expression):
		mood += " (表情：" + expression_db[current_expression].get("expression_name", "未知") + ")"
	var player_name: String = profile.player_title
	if player_name.is_empty():
		player_name = "指导人"
	var chat_history: String = profile.get_recent_chat_history_text(10)
	if chat_history.is_empty():
		chat_history = "今天没有太多的交流..."
	var system_prompt: String = prompt_template.replace("{char_name}", char_name)
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
		"model": client.get_chat_model_id(),
		"messages": api_messages,
		"temperature": 0.7,
		"max_tokens": 800
	}
	if client.diary_http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		client.diary_http.cancel_request()
	client.diary_http.request(client._get_url(), client._get_headers(), HTTPClient.METHOD_POST, JSON.stringify(body))

func handle_diary_request_completed(client, result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		var response_str: String = body.get_string_from_utf8()
		var json := JSON.new()
		if json.parse(response_str) == OK:
			var response_data: Variant = json.data
			if response_data.has("choices") and response_data.choices.size() > 0:
				var content: String = response_data.choices[0].message.content
				var diary_entry := {
					"id": str(int(Time.get_unix_time_from_system())),
					"date": Time.get_date_string_from_system(),
					"weather": "晴",
					"content": content,
					"image_url": "",
					"image_generation_time": 0.0,
					"image_prompt": "",
					"image_model_version": ""
				}
				var enable_illustration: bool = true
				if "enable_ai_diary_illustration" in GameDataManager.config:
					enable_illustration = GameDataManager.config.enable_ai_diary_illustration
				if enable_illustration:
					_process_diary_illustration(client, diary_entry)
				else:
					_save_diary_to_profile(diary_entry)
					client.diary_generated.emit(diary_entry)
			else:
				client.diary_error.emit("找不到 choices 字段")
		else:
			client.diary_error.emit("JSON 解析失败: " + json.get_error_message())
	else:
		var err_msg: String = "请求失败 (Code: %d)" % response_code
		if body.size() > 0:
			var error_json := JSON.new()
			if error_json.parse(body.get_string_from_utf8()) == OK and error_json.data is Dictionary and error_json.data.has("error"):
				err_msg += " - " + error_json.data["error"].get("message", "")
		client.diary_error.emit(err_msg)

func _process_diary_illustration(client, diary_entry: Dictionary) -> void:
	var prompt_template: String = ""
	var file: FileAccess = FileAccess.open("res://scripts/templates/prompts/diary_illustration.txt", FileAccess.READ)
	if file:
		prompt_template = file.get_as_text()
		file.close()
	else:
		print("[DeepSeekClient] 找不到日记插图提示词模板，跳过插图生成")
		_save_diary_to_profile(diary_entry)
		client.diary_generated.emit(diary_entry)
		return
	var system_prompt: String = prompt_template.replace("{diary_content}", diary_entry.content)
	var api_messages = [{"role": "system", "content": system_prompt}]
	var body = {
		"model": client.get_chat_model_id(),
		"messages": api_messages,
		"temperature": 0.7,
		"max_tokens": 300
	}
	var http := HTTPRequest.new()
	client.add_child(http)
	var err: int = http.request(client._get_url(), client._get_headers(), HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		http.queue_free()
		client.diary_generated.emit(diary_entry)
		return
	var response = await http.request_completed
	var result: int = response[0]
	var response_code: int = response[1]
	var res_body: PackedByteArray = response[3]
	var image_prompt: String = ""
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		var json := JSON.new()
		if json.parse(res_body.get_string_from_utf8()) == OK and json.data.has("choices") and json.data.choices.size() > 0:
			image_prompt = json.data.choices[0].message.content.strip_edges()
	http.queue_free()
	if image_prompt.is_empty():
		print("[DeepSeekClient] 无法生成插图提示词，跳过插图生成")
		if GameDataManager.config and "default_image_path" in GameDataManager.config:
			diary_entry["image_url"] = GameDataManager.config.default_image_path
		_save_diary_to_profile(diary_entry)
		client.diary_generated.emit(diary_entry)
		return
	if GameDataManager.config and not GameDataManager.config.image_generation_enabled:
		print("[DeepSeekClient] 图像生成已禁用，使用默认占位图")
		diary_entry["image_url"] = GameDataManager.config.default_image_path
		client.diary_generated.emit(diary_entry)
		return
	var image_client = _create_image_client(client)
	var on_success = func(_diary_id: String, local_path: String, metadata: Dictionary):
		diary_entry["image_url"] = local_path
		diary_entry["image_generation_time"] = metadata.get("duration", 0.0)
		diary_entry["image_prompt"] = metadata.get("prompt", "")
		diary_entry["image_model_version"] = metadata.get("model", "")
		_save_diary_to_profile(diary_entry)
		image_client.queue_free()
		client.diary_generated.emit(diary_entry)
	var on_failed = func(_diary_id: String, error_msg: String):
		print("[DeepSeekClient] 日记插图生成失败: ", error_msg)
		if GameDataManager.config and "default_image_path" in GameDataManager.config:
			diary_entry["image_url"] = GameDataManager.config.default_image_path
		_save_diary_to_profile(diary_entry)
		image_client.queue_free()
		client.diary_generated.emit(diary_entry)
	image_client.image_generated.connect(on_success)
	image_client.image_generation_failed.connect(on_failed)
	image_client.generate_diary_illustration(diary_entry.id, image_prompt)

func send_moment_generation(client, custom_profile: CharacterProfile = null) -> void:
	while not client.is_inside_tree():
		await Engine.get_main_loop().process_frame
	var profile: CharacterProfile = custom_profile if custom_profile else GameDataManager.profile
	var author_name: String = profile.char_name if profile else "AI"
	var avatar_path: String = profile.avatar if profile and profile.avatar != "" else "res://icon.svg"
	client.set_meta("current_moment_author", author_name)
	client.set_meta("current_moment_avatar", avatar_path)
	var system_prompt: String = GameDataManager.prompt_manager.build_moment_generation_prompt(profile)
	var api_messages = [
		{"role": "system", "content": system_prompt},
		{"role": "user", "content": "请写一条朋友圈。"}
	]
	var body = {
		"model": client.get_chat_model_id(),
		"messages": api_messages,
		"temperature": 0.7,
		"max_tokens": 800
	}
	if client.moment_http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		client.moment_http.cancel_request()
	client.moment_http.request(client._get_url(), client._get_headers(), HTTPClient.METHOD_POST, JSON.stringify(body))

func handle_moment_request_completed(client, result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		var response_str: String = body.get_string_from_utf8()
		var json := JSON.new()
		if json.parse(response_str) == OK:
			var response_data: Variant = json.data
			if response_data.has("choices") and response_data.choices.size() > 0:
				var content: String = response_data.choices[0].message.content
				var moment_data := {
					"id": str(int(Time.get_unix_time_from_system())),
					"timestamp": Time.get_unix_time_from_system(),
					"date": Time.get_date_string_from_system(),
					"content": content,
					"image_url": "",
					"likes": 0,
					"comments": [],
					"author": client.get_meta("current_moment_author", "AI"),
					"avatar": client.get_meta("current_moment_avatar", "res://icon.svg")
				}
				var enable_illustration: bool = true
				if "enable_ai_moment_illustration" in GameDataManager.config:
					enable_illustration = GameDataManager.config.enable_ai_moment_illustration
				if enable_illustration:
					_process_moment_illustration(client, moment_data)
				else:
					client.moment_generated.emit(moment_data)
			else:
				client.moment_error.emit("找不到 choices 字段")
		else:
			client.moment_error.emit("JSON 解析失败: " + json.get_error_message())
	else:
		var err_msg: String = "请求失败 (Code: %d)" % response_code
		if body.size() > 0:
			var error_json := JSON.new()
			if error_json.parse(body.get_string_from_utf8()) == OK and error_json.data is Dictionary and error_json.data.has("error"):
				err_msg += " - " + error_json.data["error"].get("message", "")
		client.moment_error.emit(err_msg)

func _process_moment_illustration(client, moment_data: Dictionary) -> void:
	var image_prompt: String = "请根据这段朋友圈内容生成一张配图的提示词（要求为英文）：" + moment_data.content
	var api_messages = [{"role": "user", "content": image_prompt}]
	var body = {
		"model": client.get_chat_model_id(),
		"messages": api_messages,
		"temperature": 0.7,
		"max_tokens": 300
	}
	var http := HTTPRequest.new()
	client.add_child(http)
	var err: int = http.request(client._get_url(), client._get_headers(), HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		http.queue_free()
		client.moment_generated.emit(moment_data)
		return
	var response = await http.request_completed
	var result: int = response[0]
	var response_code: int = response[1]
	var res_body: PackedByteArray = response[3]
	var en_prompt: String = ""
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		var json := JSON.new()
		if json.parse(res_body.get_string_from_utf8()) == OK and json.data.has("choices") and json.data.choices.size() > 0:
			en_prompt = json.data.choices[0].message.content.strip_edges()
	http.queue_free()
	if en_prompt.is_empty():
		print("[DeepSeekClient] 无法生成朋友圈插图提示词，跳过插图生成")
		if GameDataManager.config and "default_image_path" in GameDataManager.config:
			moment_data["image_url"] = GameDataManager.config.default_image_path
		client.moment_generated.emit(moment_data)
		return
	if GameDataManager.config and not GameDataManager.config.image_generation_enabled:
		print("[DeepSeekClient] 图像生成已禁用，使用默认占位图")
		moment_data["image_url"] = GameDataManager.config.default_image_path
		client.moment_generated.emit(moment_data)
		return
	var image_client = _create_image_client(client)
	var on_success = func(_id: String, local_path: String, _metadata: Dictionary):
		moment_data["image_url"] = local_path
		image_client.queue_free()
		client.moment_generated.emit(moment_data)
	var on_failed = func(_id: String, error_msg: String):
		print("[DeepSeekClient] 朋友圈插图生成失败: ", error_msg)
		if GameDataManager.config and "default_image_path" in GameDataManager.config:
			moment_data["image_url"] = GameDataManager.config.default_image_path
		image_client.queue_free()
		client.moment_generated.emit(moment_data)
	image_client.image_generated.connect(on_success)
	image_client.image_generation_failed.connect(on_failed)
	image_client.generate_diary_illustration(moment_data.id, en_prompt)

func send_moment_reply(client, post_id: String, comment: String) -> void:
	while not client.is_inside_tree():
		await Engine.get_main_loop().process_frame
	var moments_manager = client.get_node_or_null("/root/MomentsManager")
	var moment_data: Dictionary = {}
	if moments_manager:
		moment_data = moments_manager.get_moment(post_id)
	if moment_data.is_empty():
		client.moment_reply_error.emit("找不到朋友圈内容")
		return
	_current_moment_reply_post_id = post_id
	var profile: CharacterProfile = GameDataManager.profile
	var moment_content: String = moment_data.get("content", "")
	var system_prompt: String = GameDataManager.prompt_manager.build_moment_reply_prompt(profile, moment_content, comment)
	var api_messages = [
		{"role": "system", "content": system_prompt}
	]
	var body = {
		"model": client.get_chat_model_id(),
		"messages": api_messages,
		"temperature": 0.7,
		"max_tokens": 150
	}
	if client.moment_reply_http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		client.moment_reply_http.cancel_request()
	client.moment_reply_http.request(client._get_url(), client._get_headers(), HTTPClient.METHOD_POST, JSON.stringify(body))

func handle_moment_reply_request_completed(client, result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		var json := JSON.new()
		if json.parse(body.get_string_from_utf8()) == OK:
			var data: Variant = json.get_data()
			if typeof(data) == TYPE_DICTIONARY and data.has("choices") and data["choices"].size() > 0:
				var choice: Variant = data["choices"][0]
				if choice.has("message") and choice["message"].has("content"):
					var content: String = choice["message"]["content"].strip_edges()
					client.moment_reply_generated.emit(_current_moment_reply_post_id, content)
					return
	var err_msg: String = "朋友圈回复获取失败 (Code: %d)" % response_code
	if body.size() > 0:
		var error_json := JSON.new()
		if error_json.parse(body.get_string_from_utf8()) == OK and error_json.data is Dictionary and error_json.data.has("error"):
			err_msg += " - " + error_json.data["error"].get("message", "")
	client.moment_reply_error.emit(err_msg)

func send_image_to_image_request(client, _base64_image: String, prompt: String) -> void:
	if not client.is_inside_tree():
		await Engine.get_main_loop().process_frame
	print("[DeepSeekClient] 收到 Image-to-Image 请求, 提示词: ", prompt)
	if GameDataManager.config and not GameDataManager.config.image_generation_enabled:
		client.image_to_image_failed.emit("图像生成功能已在设置中禁用。")
		return
	var image_client = _create_image_client(client)
	var on_success = func(_id: String, local_path: String, _metadata: Dictionary):
		image_client.queue_free()
		client.image_to_image_completed.emit(local_path)
	var on_failed = func(_id: String, error_msg: String):
		image_client.queue_free()
		client.image_to_image_failed.emit(error_msg)
	image_client.image_generated.connect(on_success)
	image_client.image_generation_failed.connect(on_failed)
	image_client.generate_diary_illustration("i2i", prompt)
