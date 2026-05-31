extends TTSAdapter
class_name QwenTTSAdapter

# Qwen3-TTS (DashScope) 服务适配器
# 对接阿里云 DashScope Qwen-TTS 接口

var api_url: String = "https://dashscope.aliyuncs.com/api/v1/services/aigc/multimodal-generation/generation"
var api_key: String = ""
var default_voice: String = "Cherry" # 默认音色

const CACHE_DIR = "user://tts_cache/"

func _ready():
	if not DirAccess.dir_exists_absolute(CACHE_DIR):
		DirAccess.make_dir_absolute(CACHE_DIR)

# 设置配置
func setup_auth(config: Dictionary) -> void:
	if config.has("qwen_tts_api_key") and not str(config["qwen_tts_api_key"]).is_empty():
		api_key = config["qwen_tts_api_key"]

func synthesize(text: String, options: Dictionary = {}) -> void:
	if text.strip_edges().is_empty():
		tts_failed.emit("Text is empty", text)
		return

	if api_key.is_empty():
		tts_failed.emit("Qwen TTS API Key is not set", text)
		return

	# 1. 检查缓存
	var cache_key = _generate_cache_key(text, options)
	var cache_path = CACHE_DIR + cache_key + ".wav"
	
	if FileAccess.file_exists(cache_path):
		var stream = _load_audio_from_file(cache_path)
		if stream:
			tts_success.emit(stream, text)
			return

	# 2. 发起请求
	_start_request(text, options, cache_path)

func _start_request(text: String, options: Dictionary, cache_path: String):
	var voice_type = options.get("voice_type", default_voice)
			
	var request_body = {
		"model": "qwen3-tts-flash",
		"input": {
			"text": text,
			"voice": voice_type
		},
		"parameters": {}
	}
	
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer " + api_key
	]
	
	var http = HTTPRequest.new()
	add_child(http)
	
	http.request_completed.connect(
		func(result, response_code, response_headers, body): 
			_on_request_completed(result, response_code, body, http, text, cache_path)
	)
	
	var err = http.request(api_url, headers, HTTPClient.METHOD_POST, JSON.stringify(request_body))
	if err != OK:
		http.queue_free()
		tts_failed.emit("Failed to connect to Qwen TTS server", text)

func _on_request_completed(result, response_code, body, http_node: HTTPRequest, text: String, cache_path: String):
	http_node.queue_free()
	
	if result != HTTPRequest.RESULT_SUCCESS:
		tts_failed.emit("HTTP Connection Error: " + str(result), text)
		return
		
	var body_str = body.get_string_from_utf8()
	
	if response_code != 200:
		var err_msg = "API Error: " + str(response_code) + " " + body_str
		tts_failed.emit(err_msg, text)
		return

	# 解析 JSON 获取音频 URL
	var json = JSON.new()
	if json.parse(body_str) != OK:
		tts_failed.emit("Failed to parse API response", text)
		return
		
	var response_data = json.get_data()
	if not response_data is Dictionary or not response_data.has("output"):
		tts_failed.emit("Invalid API response format", text)
		return
		
	var output = response_data["output"]
	if not output.has("audio") or not output["audio"].has("url"):
		tts_failed.emit("Audio URL not found in response", text)
		return
		
	var audio_url = output["audio"]["url"]
	
	# 发起第二次请求下载音频文件
	_download_audio_file(audio_url, text, cache_path)

func _download_audio_file(url: String, text: String, cache_path: String):
	var http = HTTPRequest.new()
	add_child(http)
	
	http.request_completed.connect(
		func(result, response_code, response_headers, body):
			http.queue_free()
			if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
				tts_failed.emit("Failed to download audio file", text)
				return
				
			_save_and_emit_audio(body, cache_path, text)
	)
	
	var err = http.request(url)
	if err != OK:
		http.queue_free()
		tts_failed.emit("Failed to start audio download", text)

func _save_and_emit_audio(audio_data: PackedByteArray, cache_path: String, text: String):
	var file = FileAccess.open(cache_path, FileAccess.WRITE)
	if file:
		file.store_buffer(audio_data)
		file.close()
	
	var stream = _create_wav_stream(audio_data)
	if stream:
		tts_success.emit(stream, text)
	else:
		tts_failed.emit("Failed to decode WAV audio", text)

func _load_audio_from_file(path: String) -> AudioStream:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file: return null
	return _create_wav_stream(file.get_buffer(file.get_length()))

# 解析 WAV 二进制流，在 Godot 中动态生成 AudioStreamWAV
func _create_wav_stream(data: PackedByteArray) -> AudioStreamWAV:
	var stream = AudioStreamWAV.new()
	
	# WAV 文件前 44 字节是 Header，真实音频数据从 44 开始
	if data.size() <= 44:
		return null
		
	# 简单提取：Qwen-TTS 默认返回的可能是 16kHz 或 24kHz, 16-bit PCM WAV
	# 这里需要读取 WAV Header 里的采样率
	var sample_rate = 24000
	if data.size() >= 28:
		# 读取 24-27 字节的采样率 (little endian)
		sample_rate = data[24] | (data[25] << 8) | (data[26] << 16) | (data[27] << 24)
		
	stream.data = data.slice(44)
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	
	return stream

func _generate_cache_key(text: String, options: Dictionary) -> String:
	return (text + str(options)).md5_text()

func get_cache_key(text: String, options: Dictionary = {}) -> String:
	return _generate_cache_key(text, options)

func load_cached_audio_by_key(cache_key: String) -> AudioStream:
	var cache_path = CACHE_DIR + cache_key + ".wav"
	if not FileAccess.file_exists(cache_path):
		return null
	return _load_audio_from_file(cache_path)

func clear_cache():
	pass
