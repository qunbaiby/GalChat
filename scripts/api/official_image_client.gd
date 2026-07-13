extends Node
class_name OfficialImageClient

const REQUEST_TIMEOUT_SECONDS := 180.0

signal image_generated(diary_id: String, local_path: String, metadata: Dictionary)
signal image_generation_failed(diary_id: String, error_msg: String)

func generate_diary_illustration(diary_id: String, prompt: String) -> Dictionary:
	return await _generate_async(diary_id, prompt, false)

func _generate_async(diary_id: String, prompt: String, auth_retried: bool) -> Dictionary:
	var started_at := Time.get_ticks_msec()
	if not await OfficialAuthManager.ensure_valid_access_token():
		return _fail(diary_id, "登录状态已失效，请重新登录后使用官方图像生成服务。")

	var http_request := HTTPRequest.new()
	http_request.timeout = REQUEST_TIMEOUT_SECONDS
	add_child(http_request)
	var endpoint: String = GameDataManager.config.official_ai_gateway_url.trim_suffix("/") + "/images/generations"
	var headers: PackedStringArray = [
		"Content-Type: application/json",
		"Authorization: Bearer " + GameDataManager.config.official_access_token
	]
	var request_error: Error = http_request.request(
		endpoint,
		headers,
		HTTPClient.METHOD_POST,
		JSON.stringify({"prompt": prompt})
	)
	if request_error != OK:
		http_request.queue_free()
		return _fail(diary_id, "图像生成请求发送失败，错误码：%d" % request_error)

	var response: Array = await http_request.request_completed
	http_request.queue_free()
	var result: int = int(response[0])
	var response_code: int = int(response[1])
	var response_body: PackedByteArray = response[3]
	if response_code == 401 and not auth_retried:
		if await OfficialAuthManager.force_refresh_access_token():
			return await _generate_async(diary_id, prompt, true)
		return _fail(diary_id, "登录状态已失效，请重新登录后使用官方图像生成服务。")
	if result != HTTPRequest.RESULT_SUCCESS:
		return _fail(diary_id, "官方图像生成服务连接失败。")
	if response_code != 200:
		return _fail(diary_id, _get_error_message(response_code, response_body))

	var json := JSON.new()
	if json.parse(response_body.get_string_from_utf8()) != OK or not json.data is Dictionary:
		return _fail(diary_id, "官方图像生成响应解析失败。")
	var response_data: Dictionary = json.data
	var media_type: String = str(response_data.get("image_media_type", ""))
	var image_bytes: PackedByteArray = Marshalls.base64_to_raw(str(response_data.get("image_base64", "")))
	var extension := _get_image_extension(image_bytes, media_type)
	if extension.is_empty():
		return _fail(diary_id, "官方图像生成服务返回了无效图片。")

	var time_dict := Time.get_datetime_dict_from_system()
	var date_text := "%04d-%02d-%02d" % [time_dict.year, time_dict.month, time_dict.day]
	var directory_path := "user://generated_images/" + date_text
	if not DirAccess.dir_exists_absolute(directory_path):
		var directory_error: Error = DirAccess.make_dir_recursive_absolute(directory_path)
		if directory_error != OK:
			return _fail(diary_id, "无法创建图片保存目录。")
	var file_path := "%s/img_%s_%d.%s" % [directory_path, diary_id, Time.get_ticks_msec(), extension]
	var output_file := FileAccess.open(file_path, FileAccess.WRITE)
	if output_file == null:
		return _fail(diary_id, "无法打开图片保存路径。")
	output_file.store_buffer(image_bytes)
	output_file.close()
	if not FileAccess.file_exists(file_path):
		return _fail(diary_id, "图片文件保存失败。")

	var metadata := {
		"duration": (Time.get_ticks_msec() - started_at) / 1000.0,
		"prompt": prompt,
		"model": "official"
	}
	image_generated.emit(diary_id, file_path, metadata)
	return {"success": true, "path": file_path, "metadata": metadata, "error": ""}

func _get_image_extension(image_bytes: PackedByteArray, media_type: String) -> String:
	if media_type == "image/jpeg" and image_bytes.size() > 3 and image_bytes[0] == 0xFF and image_bytes[1] == 0xD8 and image_bytes[2] == 0xFF:
		return "jpg"
	if media_type == "image/png" and image_bytes.size() > 8 and image_bytes[0] == 0x89 and image_bytes[1] == 0x50 and image_bytes[2] == 0x4E and image_bytes[3] == 0x47:
		return "png"
	if media_type == "image/webp" and image_bytes.size() > 12 and image_bytes[0] == 0x52 and image_bytes[1] == 0x49 and image_bytes[2] == 0x46 and image_bytes[3] == 0x46:
		return "webp"
	return ""

func _get_error_message(response_code: int, response_body: PackedByteArray) -> String:
	var detail := ""
	var json := JSON.new()
	if json.parse(response_body.get_string_from_utf8()) == OK and json.data is Dictionary:
		detail = str(json.data.get("detail", ""))
		if detail.is_empty() and json.data.get("error") is Dictionary:
			detail = str(json.data["error"].get("message", ""))
	return "图像生成失败（HTTP %d）%s" % [response_code, "：" + detail if not detail.is_empty() else ""]

func _fail(diary_id: String, error_message: String) -> Dictionary:
	image_generation_failed.emit(diary_id, error_message)
	return {"success": false, "path": "", "metadata": {}, "error": error_message}