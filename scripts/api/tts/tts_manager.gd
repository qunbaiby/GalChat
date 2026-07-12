extends Node

const TTS_SERVICE_SCRIPT = preload("res://scripts/api/tts_service.gd")
const ChatSplitHelper = preload("res://scripts/utils/chat_split_helper.gd")
const COMPAT_CACHE_DIR := "user://tts_cache/by_key"

signal tts_success(audio_stream: AudioStream, text: String)
signal tts_failed(error_msg: String, text: String)
signal tts_request_started(request_id: String, context: Dictionary)
signal tts_completed(request_id: String, result: Dictionary)
signal tts_playback_started(request_id: String, metadata: Dictionary)
signal tts_playback_finished(request_id: String, metadata: Dictionary)

var current_adapter: Node = null
var current_adapter_type: String = "doubao_tts_2"

var _service: Node = null
var _request_context_by_id: Dictionary = {}

func _ready() -> void:
	_ensure_service()
	_ensure_cache_dir()

func set_adapter(_adapter_type: String) -> void:
	# 旧接口保留为兼容层，当前项目统一收敛到豆包 TTS 2.0。
	current_adapter_type = "doubao_tts_2"
	_ensure_service()

func synthesize(text: String, options: Dictionary = {}) -> void:
	_ensure_service()
	if _service == null:
		tts_failed.emit("TTS 服务未初始化。", text)
		return

	var normalized_text: String = _normalize_spoken_text(text)
	if normalized_text.is_empty():
		tts_failed.emit("TTS 文本为空。", text)
		return

	var final_options: Dictionary = _build_effective_options(options)
	var request_id: String = str(_service.call("request_speech", normalized_text, final_options)).strip_edges()
	if request_id.is_empty():
		return

	_request_context_by_id[request_id] = {
		"text": normalized_text,
		"raw_text": text,
		"options": final_options.duplicate(true),
		"cache_key": get_cache_key(normalized_text, final_options)
	}

func get_cache_key(text: String, options: Dictionary = {}) -> String:
	var normalized_text: String = _normalize_spoken_text(text)
	if normalized_text.is_empty():
		return ""
	var final_options: Dictionary = _build_effective_options(options)
	var cache_payload: Dictionary = {
		"text": normalized_text,
		"speaker": str(final_options.get("speaker", "")).strip_edges(),
		"resource_id": str(final_options.get("resource_id", "seed-tts-2.0")).strip_edges(),
		"audio_format": str(final_options.get("audio_format", "mp3")).strip_edges(),
		"sample_rate": int(final_options.get("sample_rate", 24000)),
		"speech_rate": int(final_options.get("speech_rate", 0)),
		"loudness_rate": int(final_options.get("loudness_rate", 0)),
		"model": str(final_options.get("model", "")).strip_edges(),
		"ssml": str(final_options.get("ssml", "")).strip_edges()
	}
	if final_options.has("additions") and final_options.get("additions", null) is Dictionary:
		cache_payload["additions"] = (final_options.get("additions", {}) as Dictionary).duplicate(true)
	return JSON.stringify(cache_payload, "", true).md5_text()

func load_cached_audio_by_key(cache_key: String) -> AudioStream:
	var normalized_key: String = cache_key.strip_edges()
	if normalized_key.is_empty():
		return null
	for extension in ["mp3", "wav"]:
		var cache_path: String = _build_compat_cache_path(normalized_key, extension)
		if FileAccess.file_exists(cache_path):
			return _load_stream_from_path(cache_path, extension)
	return null

func clear_cache() -> void:
	_clear_dir(COMPAT_CACHE_DIR)
	_clear_dir("user://tts_cache")

func refresh_from_settings() -> void:
	_ensure_service()
	if _service != null and _service.has_method("refresh_from_settings"):
		_service.call("refresh_from_settings")

func stop_playback() -> void:
	_ensure_service()
	if _service != null and _service.has_method("stop_playback"):
		_service.call("stop_playback")

func _ensure_service() -> void:
	if _service != null and is_instance_valid(_service):
		current_adapter = _service
		return
	_service = TTS_SERVICE_SCRIPT.new()
	_service.name = "TTSServiceV2"
	add_child(_service)
	current_adapter = _service
	if not _service.tts_request_started.is_connected(_on_service_request_started):
		_service.tts_request_started.connect(_on_service_request_started)
	if not _service.tts_completed.is_connected(_on_service_completed):
		_service.tts_completed.connect(_on_service_completed)
	if not _service.tts_failed.is_connected(_on_service_failed):
		_service.tts_failed.connect(_on_service_failed)
	if not _service.tts_playback_started.is_connected(_on_service_playback_started):
		_service.tts_playback_started.connect(_on_service_playback_started)
	if not _service.tts_playback_finished.is_connected(_on_service_playback_finished):
		_service.tts_playback_finished.connect(_on_service_playback_finished)

func _build_effective_options(options: Dictionary = {}) -> Dictionary:
	var final_options: Dictionary = options.duplicate(true)
	var config = GameDataManager.config if GameDataManager != null else null
	var profile = GameDataManager.profile if GameDataManager != null else null

	var char_id: String = str(final_options.get("character_id", "")).strip_edges().to_lower()
	if char_id.is_empty() and profile != null:
		char_id = str(profile.current_character_id).strip_edges().to_lower()
	if char_id.is_empty() and config != null:
		char_id = str(config.current_character_id).strip_edges().to_lower()
	if not char_id.is_empty():
		final_options["character_id"] = char_id

	if not final_options.has("speaker") and final_options.has("voice_type"):
		final_options["speaker"] = str(final_options.get("voice_type", "")).strip_edges()
	if not final_options.has("speaker") and config != null and config.tts_character_speakers.has(char_id):
		final_options["speaker"] = str(config.tts_character_speakers.get(char_id, "")).strip_edges()
	final_options["speaker"] = _resolve_tts_2_speaker(str(final_options.get("speaker", "")).strip_edges(), char_id, config)

	if not final_options.has("api_key") and config != null:
		final_options["api_key"] = str(config.tts_api_key).strip_edges()
	if not final_options.has("resource_id"):
		final_options["resource_id"] = "seed-tts-2.0"
	if not final_options.has("audio_format") and config != null:
		final_options["audio_format"] = str(config.tts_audio_format).strip_edges()
	if not final_options.has("sample_rate") and config != null:
		final_options["sample_rate"] = int(config.tts_sample_rate)
	if not final_options.has("speech_rate") and config != null:
		final_options["speech_rate"] = int(config.tts_speech_rate)
	if not final_options.has("loudness_rate") and config != null:
		final_options["loudness_rate"] = int(config.tts_loudness_rate)
	if not final_options.has("request_source"):
		final_options["request_source"] = "tts_manager"

	# 业务层自行控制播放节点，这里统一禁用服务内部自动播报，避免重复出声。
	final_options["autoplay"] = false
	return final_options

func _normalize_spoken_text(text: String) -> String:
	return ChatSplitHelper.strip_parentheses(text).strip_edges()

func _resolve_tts_2_speaker(speaker_id: String, char_id: String, config) -> String:
	var normalized_speaker: String = speaker_id.strip_edges()
	if not _is_legacy_tts_speaker(normalized_speaker):
		return normalized_speaker
	if config != null and config.has_method("get_default_tts_speaker"):
		var fallback_speaker: String = str(config.get_default_tts_speaker(char_id)).strip_edges()
		if not _is_legacy_tts_speaker(fallback_speaker):
			return fallback_speaker
	return "zh_female_vv_uranus_bigtts"

func _is_legacy_tts_speaker(speaker_id: String) -> bool:
	var normalized: String = speaker_id.strip_edges()
	if normalized.is_empty():
		return true
	if normalized.begins_with("S_"):
		return false
	if normalized.find("_uranus_bigtts") >= 0 or normalized.find("_saturn_bigtts") >= 0:
		return false
	if normalized.begins_with("ICL_") or normalized.ends_with("_tob"):
		return true
	if normalized == "BV001_streaming":
		return true
	if normalized.find("_moon_bigtts") >= 0 or normalized.find("_mars_bigtts") >= 0:
		return true
	if normalized.find("_emo_v2_") >= 0:
		return true
	return false

func _on_service_request_started(request_id: String, context: Dictionary) -> void:
	tts_request_started.emit(request_id, context)

func _on_service_completed(request_id: String, result: Dictionary) -> void:
	var request_info: Dictionary = {}
	if _request_context_by_id.has(request_id):
		request_info = (_request_context_by_id.get(request_id, {}) as Dictionary).duplicate(true)
		_request_context_by_id.erase(request_id)

	var final_result: Dictionary = result.duplicate(true)
	var source_audio_path: String = str(final_result.get("audio_path", "")).strip_edges()
	var audio_format: String = str(final_result.get("audio_format", "mp3")).strip_edges()
	var cache_key: String = str(request_info.get("cache_key", "")).strip_edges()
	if not cache_key.is_empty() and not source_audio_path.is_empty():
		var compat_path: String = _build_compat_cache_path(cache_key, audio_format)
		var copy_error: Error = _copy_file(source_audio_path, compat_path)
		if copy_error == OK:
			final_result["cache_key"] = cache_key
			final_result["compat_audio_path"] = compat_path

	var audio_stream: AudioStream = null
	var load_path: String = str(final_result.get("compat_audio_path", source_audio_path)).strip_edges()
	if not load_path.is_empty():
		audio_stream = _load_stream_from_path(load_path, audio_format)

	tts_completed.emit(request_id, final_result)
	if audio_stream != null:
		tts_success.emit(audio_stream, str(request_info.get("text", final_result.get("text", ""))).strip_edges())
	else:
		var failed_text: String = str(request_info.get("text", final_result.get("text", ""))).strip_edges()
		tts_failed.emit("TTS 音频解码失败。", failed_text)

func _on_service_failed(request_id: String, error_message: String, context: Dictionary) -> void:
	var raw_text: String = str(context.get("text", "")).strip_edges()
	if _request_context_by_id.has(request_id):
		var request_info: Dictionary = _request_context_by_id.get(request_id, {}) as Dictionary
		raw_text = str(request_info.get("text", raw_text)).strip_edges()
		_request_context_by_id.erase(request_id)
	tts_failed.emit(error_message, raw_text)

func _on_service_playback_started(request_id: String, metadata: Dictionary) -> void:
	tts_playback_started.emit(request_id, metadata)

func _on_service_playback_finished(request_id: String, metadata: Dictionary) -> void:
	tts_playback_finished.emit(request_id, metadata)

func _build_compat_cache_path(cache_key: String, audio_format: String) -> String:
	var normalized_format: String = audio_format.to_lower().strip_edges()
	var extension: String = "wav" if normalized_format == "wav" else "mp3"
	return "%s/%s.%s" % [COMPAT_CACHE_DIR, cache_key, extension]

func _load_stream_from_path(path: String, audio_format: String) -> AudioStream:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var audio_bytes: PackedByteArray = file.get_buffer(file.get_length())
	file.close()
	match audio_format.to_lower().strip_edges():
		"wav":
			if not _is_valid_wav_payload(audio_bytes):
				return null
			return AudioStreamWAV.load_from_buffer(audio_bytes)
		_:
			if not _is_valid_mp3_payload(audio_bytes):
				return null
			var stream := AudioStreamMP3.new()
			stream.data = audio_bytes
			return stream

func _is_valid_mp3_payload(audio_bytes: PackedByteArray) -> bool:
	if audio_bytes.size() < 4:
		return false
	var scan_limit: int = mini(audio_bytes.size() - 2, 256)
	for index in range(scan_limit):
		if char(audio_bytes[index]) == "I" and char(audio_bytes[index + 1]) == "D" and char(audio_bytes[index + 2]) == "3":
			return true
		if audio_bytes[index] == 0xff and (audio_bytes[index + 1] & 0xe0) == 0xe0:
			return true
	return false

func _is_valid_wav_payload(audio_bytes: PackedByteArray) -> bool:
	if audio_bytes.size() < 12:
		return false
	return char(audio_bytes[0]) == "R" and char(audio_bytes[1]) == "I" and char(audio_bytes[2]) == "F" and char(audio_bytes[3]) == "F" and char(audio_bytes[8]) == "W" and char(audio_bytes[9]) == "A" and char(audio_bytes[10]) == "V" and char(audio_bytes[11]) == "E"

func _ensure_cache_dir() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(COMPAT_CACHE_DIR))

func _copy_file(source_path: String, target_path: String) -> Error:
	var source_file: FileAccess = FileAccess.open(source_path, FileAccess.READ)
	if source_file == null:
		return FileAccess.get_open_error()
	var target_file: FileAccess = FileAccess.open(target_path, FileAccess.WRITE)
	if target_file == null:
		var open_error: Error = FileAccess.get_open_error()
		source_file.close()
		return open_error
	target_file.store_buffer(source_file.get_buffer(source_file.get_length()))
	source_file.close()
	target_file.close()
	return OK

func _clear_dir(dir_path: String) -> void:
	var absolute_path: String = ProjectSettings.globalize_path(dir_path)
	var dir: DirAccess = DirAccess.open(absolute_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if entry != "." and entry != "..":
			var full_path: String = absolute_path.path_join(entry)
			if dir.current_is_dir():
				_clear_dir(dir_path.path_join(entry))
			else:
				DirAccess.remove_absolute(full_path)
		entry = dir.get_next()
	dir.list_dir_end()
