extends Node

const EMBEDDING_URL = "https://ark.cn-beijing.volces.com/api/v3/embeddings/multimodal"

signal embedding_completed(result: Array)
signal embedding_failed(error_msg: String)

func get_embedding(text: String) -> Array:
	if not GameDataManager.config.embedding_enabled:
		return []
	return await _request_embedding(text, false)

func _request_embedding(text: String, auth_retried: bool) -> Array:
	var api_key = GameDataManager.config.doubao_embedding_api_key
	var model = GameDataManager.config.doubao_embedding_model
	var uses_official: bool = _uses_official_ai()

	if uses_official and not await OfficialAuthManager.ensure_valid_access_token():
		embedding_failed.emit("登录状态已失效，请重新登录后使用官方向量服务。")
		return []
	if not uses_official and (model == "ep-xxxxxx" or model.is_empty()):
		print("[DoubaoEmbedding] 未配置模型接入点 (ep-xxxxxx)，跳过 Embedding 请求。请在设置中配置你的模型 Endpoint。")
		return []
	if not uses_official and api_key.is_empty():
		print("[DoubaoEmbedding] API Key 为空，跳过 Embedding 请求。")
		return []

	var http_request = HTTPRequest.new()
	http_request.timeout = 90.0
	add_child(http_request)

	var url: String = EMBEDDING_URL
	var headers: PackedStringArray = ["Content-Type: application/json"]
	var body: Dictionary
	if uses_official:
		url = GameDataManager.config.official_ai_gateway_url.trim_suffix("/") + "/embeddings"
		headers.append("Authorization: Bearer " + GameDataManager.config.official_access_token)
		body = {"text": text}
	else:
		headers.append("Authorization: Bearer " + api_key)
		body = {
			"model": model,
			"input": [{"type": "text", "text": text}],
			"encoding_format": "float"
		}

	var json_body = JSON.stringify(body)
	var error = http_request.request(url, headers, HTTPClient.METHOD_POST, json_body)
	if error != OK:
		push_error("HTTP Request failed to send.")
		http_request.queue_free()
		embedding_failed.emit("请求发送失败")
		return []
		
	var result = await http_request.request_completed
	var result_code = result[0]
	var response_code = result[1]
	var response_body = result[3]

	http_request.queue_free()

	if response_code == 401 and uses_official and not auth_retried:
		if await OfficialAuthManager.force_refresh_access_token():
			return await _request_embedding(text, true)
		embedding_failed.emit("登录状态已失效，请重新登录后使用官方向量服务。")
		return []
	if result_code != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		var err_body = response_body.get_string_from_utf8() if response_body != null else ""
		push_error("HTTP Request failed: " + str(response_code) + " Body: " + err_body)
		embedding_failed.emit("请求失败，状态码：" + str(response_code))
		return []
		
	var json = JSON.new()
	var parse_error = json.parse(response_body.get_string_from_utf8())
	
	if parse_error != OK:
		push_error("Failed to parse JSON response.")
		embedding_failed.emit("JSON解析失败")
		return []
		
	var response_data = json.get_data()
	
	if response_data.has("data") and typeof(response_data["data"]) == TYPE_ARRAY and response_data["data"].size() > 0:
		var embedding_array = response_data["data"][0]["embedding"]
		embedding_completed.emit(embedding_array)
		return embedding_array
	elif response_data.has("data") and typeof(response_data["data"]) == TYPE_DICTIONARY and response_data["data"].has("embedding"):
		var embedding_array = response_data["data"]["embedding"]
		embedding_completed.emit(embedding_array)
		return embedding_array
	else:
		var error_msg = response_data.get("error", {}).get("message", "Unknown error")
		push_error("Embedding API error: " + str(error_msg))
		embedding_failed.emit("API错误：" + str(error_msg))
		return []

func _uses_official_ai() -> bool:
	return GameDataManager.config != null and GameDataManager.config.ai_service_mode == ConfigResource.AI_SERVICE_OFFICIAL
