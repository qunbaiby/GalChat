extends Node

signal tts_request_started(request_id: String, context: Dictionary)
signal tts_completed(request_id: String, result: Dictionary)
signal tts_failed(request_id: String, error_message: String, context: Dictionary)
signal tts_playback_started(request_id: String, metadata: Dictionary)
signal tts_playback_finished(request_id: String, metadata: Dictionary)

const HTTP_TTS_ENDPOINT := "https://openspeech.bytedance.com/api/v3/tts/unidirectional"
const RESOURCE_ID_TTS_2 := "seed-tts-2.0"
const CACHE_DIR := "user://tts_cache"
const REQUEST_TIMEOUT_SECONDS := 30.0
const DEFAULT_VOICE_ID := "zh_female_vv_uranus_bigtts"
const DEFAULT_AUDIO_FORMAT := "mp3"
const DEFAULT_SAMPLE_RATE := 24000
const DEFAULT_BIT_RATE := 96000
const DEFAULT_SPEECH_RATE := 0
const DEFAULT_LOUDNESS_RATE := 0

const AUDIO_FORMAT_OPTIONS := [
	{"id": "mp3", "label": "MP3"},
	{"id": "wav", "label": "WAV"}
]

var _http_request: HTTPRequest
var _playback_player: AudioStreamPlayer
var _request_queue: Array[Dictionary] = []
var _active_request: Dictionary = {}
var _active_playback_request_id: String = ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_http_request = HTTPRequest.new()
	_http_request.timeout = REQUEST_TIMEOUT_SECONDS
	add_child(_http_request)
	if not _http_request.request_completed.is_connected(_on_request_completed):
		_http_request.request_completed.connect(_on_request_completed)

	_playback_player = AudioStreamPlayer.new()
	_playback_player.name = "TTSPlaybackPlayer"
	_playback_player.bus = _resolve_bus_name("SFX")
	add_child(_playback_player)
	if not _playback_player.finished.is_connected(_on_playback_finished):
		_playback_player.finished.connect(_on_playback_finished)

	_ensure_cache_dir()

func get_audio_format_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	for entry in AUDIO_FORMAT_OPTIONS:
		options.append(entry.duplicate(true))
	return options

func is_configured() -> bool:
	return not _get_api_key().is_empty()

func is_enabled() -> bool:
	return bool(_get_game_settings_value("tts_enabled", false)) and is_configured()

func is_busy() -> bool:
	return not _active_request.is_empty()

func refresh_from_settings() -> void:
	# 当前实现按请求时实时读取设置，无需额外刷新缓存。
	pass

func request_speech(text: String, options: Dictionary = {}) -> String:
	var normalized_text: String = text.strip_edges()
	if normalized_text.is_empty():
		return ""

	var request_options: Dictionary = _build_request_options(normalized_text, options)
	var request_id: String = str(request_options.get("request_id", "")).strip_edges()
	if request_id.is_empty():
		return ""

	var validation_message: String = _validate_request_options(request_options)
	if not validation_message.is_empty():
		_emit_failure(request_id, validation_message, request_options)
		return ""

	_request_queue.append(request_options)
	_try_start_next_request()
	return request_id

func request_and_play(text: String, options: Dictionary = {}) -> String:
	var merged_options: Dictionary = options.duplicate(true)
	merged_options["autoplay"] = true
	return request_speech(text, merged_options)

func stop_playback() -> void:
	if _playback_player != null and _playback_player.playing:
		_playback_player.stop()
		_on_playback_finished()

func synthesize_preview(sample_text: String = "", options: Dictionary = {}) -> String:
	var preview_text: String = sample_text.strip_edges()
	if preview_text.is_empty():
		preview_text = "这是莎布涅拉的语音试听。若你能听见我，说明豆包语音合成已经接通。"
	var merged_options: Dictionary = options.duplicate(true)
	merged_options["request_source"] = "tts_preview"
	merged_options["autoplay"] = true
	return request_speech(preview_text, merged_options)

func _try_start_next_request() -> void:
	if not _active_request.is_empty() or _request_queue.is_empty():
		return

	var next_request: Dictionary = _request_queue.pop_front()
	var headers: PackedStringArray = [
		"Content-Type: application/json",
		"X-Api-Key: %s" % str(next_request.get("api_key", "")).strip_edges(),
		"X-Api-Resource-Id: %s" % str(next_request.get("resource_id", RESOURCE_ID_TTS_2)).strip_edges(),
		"X-Api-Request-Id: %s" % str(next_request.get("request_id", "")).strip_edges(),
		"X-Control-Require-Usage-Tokens-Return: *"
	]
	var request_body: Dictionary = _build_request_body(next_request)
	var error: Error = _http_request.request(
		HTTP_TTS_ENDPOINT,
		headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(request_body)
	)
	if error != OK:
		var failed_request_id: String = str(next_request.get("request_id", "")).strip_edges()
		_emit_failure(failed_request_id, "TTS 请求发送失败，错误码：%d" % error, next_request)
		_try_start_next_request()
		return

	_active_request = next_request.duplicate(true)
	tts_request_started.emit(str(_active_request.get("request_id", "")), _build_context_payload(_active_request))

func _build_request_options(text: String, options: Dictionary) -> Dictionary:
	var format_id: String = _normalize_audio_format(str(options.get("audio_format", _get_game_settings_value("tts_audio_format", DEFAULT_AUDIO_FORMAT))).strip_edges())
	var request_id: String = _generate_request_id()
	var merged: Dictionary = {
		"request_id": request_id,
		"text": text,
		"api_key": str(options.get("api_key", _get_api_key())).strip_edges(),
		"resource_id": str(options.get("resource_id", RESOURCE_ID_TTS_2)).strip_edges(),
		"speaker": str(options.get("speaker", _get_game_settings_value("tts_voice_id", DEFAULT_VOICE_ID))).strip_edges(),
		"audio_format": format_id,
		"sample_rate": int(options.get("sample_rate", _get_game_settings_value("tts_sample_rate", DEFAULT_SAMPLE_RATE))),
		"bit_rate": int(options.get("bit_rate", DEFAULT_BIT_RATE)),
		"speech_rate": int(options.get("speech_rate", _get_game_settings_value("tts_speech_rate", DEFAULT_SPEECH_RATE))),
		"loudness_rate": int(options.get("loudness_rate", _get_game_settings_value("tts_loudness_rate", DEFAULT_LOUDNESS_RATE))),
		"autoplay": bool(options.get("autoplay", _get_game_settings_value("tts_autoplay_ai_chat", true))),
		"request_source": str(options.get("request_source", "tts_service")).strip_edges(),
		"character_id": str(options.get("character_id", "")).strip_edges(),
		"enable_subtitle": bool(options.get("enable_subtitle", false))
	}
	if options.has("model"):
		merged["model"] = str(options.get("model", "")).strip_edges()
	if options.has("ssml"):
		merged["ssml"] = str(options.get("ssml", "")).strip_edges()
	if options.has("additions") and options.get("additions", null) is Dictionary:
		merged["additions"] = (options.get("additions", {}) as Dictionary).duplicate(true)
	return merged

func _validate_request_options(options: Dictionary) -> String:
	if str(options.get("api_key", "")).strip_edges().is_empty():
		return "未配置豆包 TTS API Key。"
	if str(options.get("speaker", "")).strip_edges().is_empty():
		return "未配置豆包 TTS 音色 ID。"
	if _is_legacy_speaker_id(str(options.get("speaker", "")).strip_edges()):
		return "当前 speaker 属于旧版音色体系，不能用于 seed-tts-2.0，请改用新版 TTS 2.0 speaker。"
	var format_id: String = _normalize_audio_format(str(options.get("audio_format", DEFAULT_AUDIO_FORMAT)).strip_edges())
	if format_id.is_empty():
		return "不支持的音频格式，仅支持 mp3 或 wav。"
	return ""

func _build_request_body(options: Dictionary) -> Dictionary:
	var req_params: Dictionary = {
		"text": str(options.get("text", "")).strip_edges(),
		"speaker": str(options.get("speaker", "")).strip_edges(),
		"audio_params": {
			"format": str(options.get("audio_format", DEFAULT_AUDIO_FORMAT)).strip_edges(),
			"sample_rate": int(options.get("sample_rate", DEFAULT_SAMPLE_RATE)),
			"speech_rate": int(options.get("speech_rate", DEFAULT_SPEECH_RATE)),
			"loudness_rate": int(options.get("loudness_rate", DEFAULT_LOUDNESS_RATE))
		}
	}
	var model_name: String = str(options.get("model", "")).strip_edges()
	if not model_name.is_empty():
		req_params["model"] = model_name
	var ssml_text: String = str(options.get("ssml", "")).strip_edges()
	if not ssml_text.is_empty():
		req_params["ssml"] = ssml_text
	if bool(options.get("enable_subtitle", false)):
		(req_params["audio_params"] as Dictionary)["enable_subtitle"] = true
	var format_id: String = str((req_params["audio_params"] as Dictionary).get("format", DEFAULT_AUDIO_FORMAT)).strip_edges()
	if format_id == "mp3":
		(req_params["audio_params"] as Dictionary)["bit_rate"] = int(options.get("bit_rate", DEFAULT_BIT_RATE))
	var additions: Dictionary = (options.get("additions", {}) as Dictionary).duplicate(true) if options.get("additions", null) is Dictionary else {}
	if not additions.is_empty():
		req_params["additions"] = additions
	return {"req_params": req_params}

func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if _active_request.is_empty():
		return

	var request_info: Dictionary = _active_request.duplicate(true)
	_active_request.clear()
	var request_id: String = str(request_info.get("request_id", "")).strip_edges()
	var header_map: Dictionary = _headers_to_dictionary(headers)
	var log_id: String = str(header_map.get("x-tt-logid", "")).strip_edges()

	if result != HTTPRequest.RESULT_SUCCESS:
		_emit_failure(request_id, _map_transport_error(result), request_info, log_id)
		_try_start_next_request()
		return

	if response_code < 200 or response_code >= 300:
		_emit_failure(request_id, _build_http_error_message(response_code, body, log_id), request_info, log_id)
		_try_start_next_request()
		return

	var audio_format: String = _normalize_audio_format(str(request_info.get("audio_format", DEFAULT_AUDIO_FORMAT)).strip_edges())
	var resolved_audio_bytes: PackedByteArray = _extract_audio_bytes_from_response(body)
	if resolved_audio_bytes.is_empty():
		_emit_failure(request_id, "TTS 响应中未解析到有效音频数据。", request_info, log_id)
		_try_start_next_request()
		return
	var save_path: String = _build_cache_file_path(request_id, audio_format)
	var save_error: Error = _save_audio_bytes(save_path, resolved_audio_bytes)
	if save_error != OK:
		_emit_failure(request_id, "TTS 音频保存失败，错误码：%d" % save_error, request_info, log_id)
		_try_start_next_request()
		return
	var stream: AudioStream = _build_stream_from_bytes(resolved_audio_bytes, audio_format)
	var playback_supported: bool = stream != null
	if bool(request_info.get("autoplay", false)) and playback_supported:
		_active_playback_request_id = request_id
		_playback_player.stop()
		_playback_player.stream = stream
		_playback_player.play()
		tts_playback_started.emit(request_id, {
			"request_id": request_id,
			"audio_path": save_path,
			"audio_format": audio_format,
			"log_id": log_id
		})

	var result_payload: Dictionary = {
		"request_id": request_id,
		"audio_path": save_path,
		"audio_format": audio_format,
		"text": str(request_info.get("text", "")).strip_edges(),
		"speaker": str(request_info.get("speaker", "")).strip_edges(),
		"playback_supported": playback_supported,
		"log_id": log_id,
		"request_source": str(request_info.get("request_source", "")).strip_edges()
	}
	tts_completed.emit(request_id, result_payload)
	_try_start_next_request()

func _save_audio_bytes(save_path: String, audio_bytes: PackedByteArray) -> Error:
	var file: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_buffer(audio_bytes)
	file.close()
	return OK

func _extract_audio_bytes_from_response(body: PackedByteArray) -> PackedByteArray:
	var streamed_audio_bytes: PackedByteArray = _extract_streamed_audio_bytes(body)
	if not streamed_audio_bytes.is_empty():
		return streamed_audio_bytes
	var wrapped_payload: Dictionary = _parse_json_payload(body)
	if wrapped_payload.is_empty():
		wrapped_payload = _extract_wrapped_payload_fallback(body)
	if wrapped_payload.is_empty():
		return body

	var response_code: int = int(wrapped_payload.get("code", -1))
	if response_code != 0:
		return PackedByteArray()

	var data_field: Variant = wrapped_payload.get("data", null)
	if data_field is String:
		var encoded_audio: String = str(data_field).strip_edges()
		if encoded_audio.is_empty():
			return PackedByteArray()
		return Marshalls.base64_to_raw(encoded_audio)
	if data_field is PackedByteArray:
		return data_field
	return PackedByteArray()

func _extract_streamed_audio_bytes(body: PackedByteArray) -> PackedByteArray:
	var body_text: String = body.get_string_from_utf8()
	if body_text.is_empty():
		return PackedByteArray()
	var merged_audio: PackedByteArray = PackedByteArray()
	var chunk_count: int = 0
	var line_count: int = 0
	for raw_line in body_text.split("\n", false):
		var line_text: String = raw_line.strip_edges()
		if line_text.is_empty():
			continue
		line_count += 1
		var json := JSON.new()
		if json.parse(line_text) != OK:
			continue
		if not (json.data is Dictionary):
			continue
		var payload: Dictionary = json.data as Dictionary
		if int(payload.get("code", -1)) != 0:
			continue
		var data_field: Variant = payload.get("data", null)
		if not (data_field is String):
			continue
		var encoded_audio: String = str(data_field).strip_edges()
		if encoded_audio.is_empty():
			continue
		merged_audio.append_array(Marshalls.base64_to_raw(encoded_audio))
		chunk_count += 1
	return merged_audio

func _build_stream_from_bytes(audio_bytes: PackedByteArray, audio_format: String) -> AudioStream:
	match audio_format:
		"mp3":
			if audio_bytes.is_empty():
				return null
			var mp3_stream := AudioStreamMP3.new()
			mp3_stream.data = audio_bytes
			return mp3_stream
		"wav":
			return AudioStreamWAV.load_from_buffer(audio_bytes)
		_:
			return null

func _headers_to_dictionary(headers: PackedStringArray) -> Dictionary:
	var result: Dictionary = {}
	for entry in headers:
		var separator_index: int = entry.find(":")
		if separator_index <= 0:
			continue
		var key: String = entry.substr(0, separator_index).strip_edges().to_lower()
		var value: String = entry.substr(separator_index + 1).strip_edges()
		result[key] = value
	return result

func _build_http_error_message(response_code: int, body: PackedByteArray, log_id: String = "") -> String:
	var suffix: String = ""
	if not log_id.is_empty():
		suffix = "（logid：%s）" % log_id
	var parsed_error: Dictionary = _parse_error_body(body)
	var remote_message: String = str(parsed_error.get("message", parsed_error.get("msg", ""))).strip_edges()
	if remote_message.is_empty():
		remote_message = str(parsed_error.get("error", "")).strip_edges()
	match response_code:
		400:
			return "TTS 请求参数错误：%s%s" % [remote_message if not remote_message.is_empty() else "请检查文本、音色和音频参数。", suffix]
		401, 403:
			return "TTS 身份认证失败：%s%s" % [remote_message if not remote_message.is_empty() else "请检查 API Key 是否有效。", suffix]
		404:
			return "TTS 接口地址不可用，请检查豆包接口版本配置。%s" % suffix
		408:
			return "TTS 请求超时，请稍后重试。%s" % suffix
		409:
			return "TTS 请求冲突，请稍后重试。%s" % suffix
		429:
			return "TTS 调用超限或并发不足：%s%s" % [remote_message if not remote_message.is_empty() else "请稍后重试或检查账号额度。", suffix]
		500, 502, 503, 504:
			return "豆包 TTS 服务暂时不可用：%s%s" % [remote_message if not remote_message.is_empty() else "服务端返回异常。", suffix]
		_:
			if not remote_message.is_empty():
				return "TTS 请求失败：HTTP %d，%s%s" % [response_code, remote_message, suffix]
			return "TTS 请求失败：HTTP %d%s" % [response_code, suffix]

func _parse_error_body(body: PackedByteArray) -> Dictionary:
	var wrapped_payload: Dictionary = _parse_json_payload(body)
	if not wrapped_payload.is_empty():
		return wrapped_payload
	var body_text: String = body.get_string_from_utf8().strip_edges()
	if body_text.is_empty():
		return {}
	var json := JSON.new()
	if json.parse(body_text) == OK and json.data is Dictionary:
		return json.data as Dictionary
	return {"message": body_text}

func _parse_json_payload(body: PackedByteArray) -> Dictionary:
	var body_text: String = body.get_string_from_utf8().strip_edges()
	if body_text.is_empty() or not body_text.begins_with("{"):
		return {}
	var json := JSON.new()
	var candidate_text: String = body_text
	var parse_error: Error = json.parse(candidate_text)
	if parse_error != OK:
		var first_brace: int = body_text.find("{")
		var last_brace: int = body_text.rfind("}")
		if first_brace >= 0 and last_brace >= first_brace:
			candidate_text = body_text.substr(first_brace, last_brace - first_brace + 1)
			parse_error = json.parse(candidate_text)
	if parse_error != OK:
		return {}
	return json.data as Dictionary if json.data is Dictionary else {}

func _extract_wrapped_payload_fallback(body: PackedByteArray) -> Dictionary:
	var body_text: String = body.get_string_from_utf8()
	if body_text.is_empty():
		return {}
	var code_value: int = _extract_json_int_field(body_text, "code", -1)
	var data_value: String = _extract_json_string_field(body_text, "data")
	var message_value: String = _extract_json_string_field(body_text, "message")
	if code_value == -1 and data_value.is_empty() and message_value.is_empty():
		return {}
	var payload: Dictionary = {}
	if code_value != -1:
		payload["code"] = code_value
	if not data_value.is_empty():
		payload["data"] = data_value
	if not message_value.is_empty():
		payload["message"] = message_value
	return payload

func _extract_json_int_field(body_text: String, field_name: String, default_value: int = -1) -> int:
	var key: String = "\"%s\"" % field_name
	var key_index: int = body_text.find(key)
	if key_index < 0:
		return default_value
	var colon_index: int = body_text.find(":", key_index + key.length())
	if colon_index < 0:
		return default_value
	var cursor: int = colon_index + 1
	while cursor < body_text.length() and body_text[cursor] in [" ", "\t", "\r", "\n"]:
		cursor += 1
	var end: int = cursor
	while end < body_text.length() and (body_text[end] == "-" or body_text[end].is_valid_int() or (body_text[end] >= "0" and body_text[end] <= "9")):
		end += 1
	var value_text: String = body_text.substr(cursor, end - cursor).strip_edges()
	return int(value_text) if value_text.is_valid_int() else default_value

func _extract_json_string_field(body_text: String, field_name: String) -> String:
	var key: String = "\"%s\"" % field_name
	var key_index: int = body_text.find(key)
	if key_index < 0:
		return ""
	var colon_index: int = body_text.find(":", key_index + key.length())
	if colon_index < 0:
		return ""
	var quote_start: int = body_text.find("\"", colon_index + 1)
	if quote_start < 0:
		return ""
	var cursor: int = quote_start + 1
	var escaped: bool = false
	var result: PackedStringArray = []
	while cursor < body_text.length():
		var char_text: String = body_text[cursor]
		if escaped:
			result.append(char_text)
			escaped = false
		elif char_text == "\\":
			escaped = true
		elif char_text == "\"":
			return "".join(result)
		else:
			result.append(char_text)
		cursor += 1
	return ""

func _map_transport_error(result: int) -> String:
	match result:
		HTTPRequest.RESULT_CANT_RESOLVE:
			return "TTS 网络错误：无法解析豆包服务地址。"
		HTTPRequest.RESULT_CANT_CONNECT:
			return "TTS 网络错误：无法连接豆包服务。"
		HTTPRequest.RESULT_CONNECTION_ERROR:
			return "TTS 网络错误：连接过程中断。"
		HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR:
			return "TTS TLS 握手失败，请检查网络环境。"
		HTTPRequest.RESULT_TIMEOUT:
			return "TTS 请求超时，请稍后重试。"
		_:
			return "TTS 请求未成功完成，结果码：%d" % result

func _emit_failure(request_id: String, error_message: String, context: Dictionary, log_id: String = "") -> void:
	var payload: Dictionary = _build_context_payload(context)
	if not log_id.is_empty():
		payload["log_id"] = log_id
	tts_failed.emit(request_id, error_message, payload)

func _build_context_payload(context: Dictionary) -> Dictionary:
	return {
		"request_id": str(context.get("request_id", "")).strip_edges(),
		"text": str(context.get("text", "")).strip_edges(),
		"speaker": str(context.get("speaker", "")).strip_edges(),
		"audio_format": str(context.get("audio_format", DEFAULT_AUDIO_FORMAT)).strip_edges(),
		"request_source": str(context.get("request_source", "")).strip_edges(),
		"character_id": str(context.get("character_id", "")).strip_edges()
	}

func _build_cache_file_path(request_id: String, audio_format: String) -> String:
	var extension: String = "mp3" if audio_format == "mp3" else "wav"
	return "%s/%s.%s" % [CACHE_DIR, request_id, extension]

func _generate_request_id() -> String:
	return "tts_%s_%d" % [str(Time.get_unix_time_from_system()), randi()]

func _normalize_audio_format(format_id: String) -> String:
	var normalized: String = format_id.to_lower().strip_edges()
	match normalized:
		"mp3", "wav":
			return normalized
		_:
			return ""

func _is_legacy_speaker_id(speaker_id: String) -> bool:
	var normalized: String = speaker_id.strip_edges()
	if normalized.is_empty():
		return false
	if normalized.begins_with("ICL_"):
		return true
	if normalized.ends_with("_tob"):
		return true
	if normalized == "BV001_streaming":
		return true
	return false

func _get_api_key() -> String:
	return str(_get_game_settings_value("tts_api_key", "")).strip_edges()

func _get_game_settings_value(key: String, fallback: Variant) -> Variant:
	var settings: Node = get_node_or_null("/root/GameSettings")
	if settings == null:
		return fallback
	return settings.call("get_setting", key, fallback)

func _ensure_cache_dir() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CACHE_DIR))

func _resolve_bus_name(bus_name: String) -> String:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return bus_name
	return "Master"

func _on_playback_finished() -> void:
	if _active_playback_request_id.is_empty():
		return
	var finished_request_id: String = _active_playback_request_id
	_active_playback_request_id = ""
	tts_playback_finished.emit(finished_request_id, {"request_id": finished_request_id})
