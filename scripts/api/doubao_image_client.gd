extends Node
class_name DoubaoImageClient

const API_URL = "https://ark.cn-beijing.volces.com/api/v3/images/generations"
const MAX_RETRIES = 3
const API_TIMEOUT_SECONDS = 120.0
const DOWNLOAD_TIMEOUT_SECONDS = 30.0
const IMAGE_SIZE = "2K"

signal image_generated(diary_id: String, local_path: String, metadata: Dictionary)
signal image_generation_failed(diary_id: String, error_msg: String)

func generate_diary_illustration(diary_id: String, prompt: String) -> Dictionary:
	return await _generate_async(diary_id, prompt)

func _success_result(local_path: String, metadata: Dictionary) -> Dictionary:
	return {
		"success": true,
		"path": local_path,
		"metadata": metadata,
		"error": ""
	}

func _failure_result(error_msg: String) -> Dictionary:
	return {
		"success": false,
		"path": "",
		"metadata": {},
		"error": error_msg
	}

func _generate_async(diary_id: String, prompt: String) -> Dictionary:
	var start_time = Time.get_ticks_msec()
	
	if GameDataManager.config and not GameDataManager.config.image_generation_enabled:
		return _failure_result("Image generation is disabled in settings.")
		
	var api_key = ""
	var model = "doubao-seedream-5-0-260128"
	
	if GameDataManager.config and "doubao_image_api_key" in GameDataManager.config:
		api_key = GameDataManager.config.doubao_image_api_key
	if GameDataManager.config and "doubao_image_model" in GameDataManager.config:
		model = GameDataManager.config.doubao_image_model
		
	if api_key.is_empty():
		return _failure_result("Doubao Image API Key未设置，请在设置中配置。")
		
	var request_data = {
		"model": model,
		"prompt": prompt,
		"sequential_image_generation": "disabled",
		"response_format": "url",
		"size": IMAGE_SIZE,
		"stream": false,
		"watermark": true
	}
	print("[DoubaoImageClient] 开始生成图片 model=%s size=%s prompt_len=%d" % [model, IMAGE_SIZE, prompt.length()])
	
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer " + api_key
	]
	
	var image_url = ""
	var success = false
	var error_message = ""
	
	var http_request = HTTPRequest.new()
	http_request.timeout = API_TIMEOUT_SECONDS
	add_child(http_request)
	
	# 1. 请求 API (带重试)
	for attempt in range(MAX_RETRIES):
		print("[DoubaoImageClient] API 请求尝试 %d/%d" % [attempt + 1, MAX_RETRIES])
		var err = http_request.request(API_URL, headers, HTTPClient.METHOD_POST, JSON.stringify(request_data))
		if err != OK:
			error_message = "无法发起 API 请求: %d" % err
			await get_tree().create_timer(1.0).timeout
			continue
			
		var attempt_started_at := Time.get_ticks_msec()
		var response = await http_request.request_completed
		var elapsed := (Time.get_ticks_msec() - attempt_started_at) / 1000.0
		var result = response[0]
		var response_code = response[1]
		var body = response[3]
		print("[DoubaoImageClient] API 响应 result=%d code=%d seconds=%.2f body_bytes=%d" % [result, response_code, elapsed, body.size()])
		
		if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
			var json = JSON.new()
			if json.parse(body.get_string_from_utf8()) == OK:
				var res_dict = json.data
				if res_dict.has("data") and res_dict["data"].size() > 0 and res_dict["data"][0].has("url"):
					image_url = res_dict["data"][0]["url"]
					success = true
					break
					
		error_message = "API 请求失败. HTTP 状态码: %d" % response_code
		if body.size() > 0:
			var body_str = body.get_string_from_utf8()
			if body_str.length() < 200:
				error_message += " 详情: " + body_str
			else:
				error_message += " 详情: " + body_str.substr(0, 200) + "..."
				
		if attempt < MAX_RETRIES - 1:
			await get_tree().create_timer(2.0).timeout
			
	if not success or image_url.is_empty():
		http_request.queue_free()
		return _failure_result(error_message)
		
	# 2. 下载图像 (带重试)
	var img_download_success = false
	var img_body = PackedByteArray()
	http_request.timeout = DOWNLOAD_TIMEOUT_SECONDS
	
	for attempt in range(MAX_RETRIES):
		print("[DoubaoImageClient] 图片下载尝试 %d/%d" % [attempt + 1, MAX_RETRIES])
		var err = http_request.request(image_url, ["User-Agent: GodotEngine/4.5"], HTTPClient.METHOD_GET)
		if err != OK:
			error_message = "无法发起图像下载请求: %d" % err
			await get_tree().create_timer(1.0).timeout
			continue
			
		var download_started_at := Time.get_ticks_msec()
		var response = await http_request.request_completed
		var download_elapsed := (Time.get_ticks_msec() - download_started_at) / 1000.0
		var result = response[0]
		var response_code = response[1]
		var body = response[3]
		print("[DoubaoImageClient] 下载响应 result=%d code=%d seconds=%.2f body_bytes=%d" % [result, response_code, download_elapsed, body.size()])
		
		if result == HTTPRequest.RESULT_SUCCESS and response_code == 200 and body.size() > 0:
			img_body = body
			img_download_success = true
			break
			
		error_message = "图像下载失败. HTTP 状态码: %d" % response_code
		if attempt < MAX_RETRIES - 1:
			await get_tree().create_timer(2.0).timeout
			
	http_request.queue_free()
	
	if not img_download_success:
		return _failure_result(error_message)
		
	# 3. 保存原始图片字节，避免 2K 图片在主线程解码后重压 PNG 导致长时间卡住。
	var extension := "png"
	if img_body.size() > 3 and img_body[0] == 0xFF and img_body[1] == 0xD8 and img_body[2] == 0xFF:
		extension = "jpg"
	elif img_body.size() > 4 and img_body[0] == 0x89 and img_body[1] == 0x50 and img_body[2] == 0x4E and img_body[3] == 0x47:
		extension = "png"
	elif img_body.size() > 12 and img_body[0] == 0x52 and img_body[1] == 0x49 and img_body[2] == 0x46 and img_body[3] == 0x46:
		extension = "webp"
	else:
		return _failure_result("无法识别下载的图像格式 (大小: %d)" % img_body.size())

	var time_dict = Time.get_datetime_dict_from_system()
	var date_str = "%04d-%02d-%02d" % [time_dict.year, time_dict.month, time_dict.day]
	var timestamp = int(Time.get_unix_time_from_system())
	
	var dir_path = "user://generated_images/" + date_str
	if not DirAccess.dir_exists_absolute(dir_path):
		var dir_err = DirAccess.make_dir_recursive_absolute(dir_path)
		if dir_err != OK:
			return _failure_result("无法创建目录: " + dir_path)
			
	var file_name = "img_%s_%d.%s" % [diary_id, timestamp, extension]
	var file_path = dir_path + "/" + file_name
	
	var output_file := FileAccess.open(file_path, FileAccess.WRITE)
	if output_file == null:
		return _failure_result("打开图片保存路径失败: " + file_path)
	output_file.store_buffer(img_body)
	output_file.close()
	if not FileAccess.file_exists(file_path):
		return _failure_result("保存图片文件失败: " + file_path)
	print("[DoubaoImageClient] 图片已保存 path=%s bytes=%d" % [file_path, img_body.size()])
		
	var duration = (Time.get_ticks_msec() - start_time) / 1000.0
	var metadata = {
		"duration": duration,
		"prompt": prompt,
		"model": model
	}
	
	image_generated.emit(diary_id, file_path, metadata)
	return _success_result(file_path, metadata)
