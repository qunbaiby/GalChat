class_name DoubaoASRService
extends Node

## 火山引擎一句话语音识别（ASR）服务
## 负责将音频数据发送至火山引擎进行语音转文字

signal asr_success(text: String)
signal asr_failed(error_msg: String)

const API_URL = "https://openspeech.bytedance.com/api/v1/asr"

var _http_request: HTTPRequest

func _ready() -> void:
	_http_request = HTTPRequest.new()
	add_child(_http_request)
	_http_request.request_completed.connect(_on_request_completed)

## 执行语音识别
## [param audio_data] 录音的 WAV 格式二进制数据
func recognize(audio_data: PackedByteArray) -> void:
	if not GameDataManager.config:
		asr_failed.emit("配置未初始化")
		return
		
	var app_id = GameDataManager.config.doubao_app_id
	var token = GameDataManager.config.doubao_token
	var asr_cluster = GameDataManager.config.doubao_asr_cluster
	
	if app_id.is_empty() or token.is_empty():
		asr_failed.emit("火山引擎 App ID 或 Token 未配置")
		return

	# 将音频数据转换为 Base64
	var base64_audio = Marshalls.raw_to_base64(audio_data)
	
	# 生成唯一请求 ID
	var req_id = str(randi()) + str(Time.get_ticks_msec())

	# 构建请求体 JSON 数据
	var payload_dict = {
		"app": {
			"appid": app_id,
			"token": token,
			"cluster": asr_cluster
		},
		"user": {
			"uid": "godot_player"
		},
		"audio": {
			"format": "wav",
			"rate": AudioServer.get_mix_rate(),
			"language": "zh-CN",
			"bits": 16,
			"channel": 1,
			"codec": "raw"
		},
		"request": {
			"reqid": req_id,
			"sequence": 1,
			"action": 1,
			"nbest": 1
		},
		"payload": base64_audio
	}
	
	var json_data = JSON.stringify(payload_dict)
	
	var headers = [
		"Authorization: Bearer; " + token,
		"Content-Type: application/json"
	]
	
	var error = _http_request.request(API_URL, headers, HTTPClient.METHOD_POST, json_data)
	if error != OK:
		asr_failed.emit("发送请求失败，错误码：" + str(error))

func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		asr_failed.emit("网络请求失败，Result Code: " + str(result))
		return
		
	if response_code != 200:
		var err_msg = body.get_string_from_utf8()
		asr_failed.emit("API返回错误，HTTP Code: " + str(response_code) + " Msg: " + err_msg)
		return
		
	var response_text = body.get_string_from_utf8()
	var json = JSON.new()
	var err = json.parse(response_text)
	
	if err != OK:
		asr_failed.emit("JSON解析失败：" + response_text)
		return
		
	var data = json.get_data()
	
	if data.has("code") and str(data["code"]) == "1000":
		if data.has("result") and typeof(data["result"]) == TYPE_ARRAY and data["result"].size() > 0:
			var recognized_text = data["result"][0].get("text", "")
			asr_success.emit(recognized_text)
		else:
			asr_failed.emit("识别结果为空")
	else:
		var msg = data.get("message", "未知错误")
		asr_failed.emit("识别失败：" + msg + " (" + response_text + ")")
