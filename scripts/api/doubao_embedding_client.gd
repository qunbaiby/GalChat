extends Node

const EMBEDDING_URL = "https://ark.cn-beijing.volces.com/api/v3/embeddings/multimodal"

signal embedding_completed(result: Array)
signal embedding_failed(error_msg: String)

func get_embedding(text: String) -> Array:
	var api_key = GameDataManager.config.doubao_embedding_api_key
	var model = GameDataManager.config.doubao_embedding_model
	
	if api_key.is_empty():
		push_error("Doubao Embedding API Key is empty!")
		embedding_failed.emit("API Key 为空")
		return []
		
	var http_request = HTTPRequest.new()
	add_child(http_request)
	
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer " + api_key
	]
	
	var body = {
		"model": model,
		"input": [
			{
				"type": "text",
				"text": text
			}
		],
		"encoding_format": "float"
	}
	
	var json_body = JSON.stringify(body)
	
	var error = http_request.request(EMBEDDING_URL, headers, HTTPClient.METHOD_POST, json_body)
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
