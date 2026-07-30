extends SceneTree

const TTS_MANAGER_PATH := "res://scripts/api/tts/tts_manager.gd"
const TTS_SERVICE_PATH := "res://scripts/api/tts_service.gd"
const CONFIG_PATH := "res://scripts/data/config_resource.gd"

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var manager_script: GDScript = load(TTS_MANAGER_PATH)
	var service_script: GDScript = load(TTS_SERVICE_PATH)
	var config_script: GDScript = load(CONFIG_PATH)
	_expect(manager_script != null, "无法加载 TTSManager。")
	_expect(service_script != null, "无法加载 TTSService。")
	_expect(config_script != null, "无法加载 ConfigResource。")
	if manager_script == null or service_script == null or config_script == null:
		_finish()
		return

	var manager = manager_script.new()
	var service = service_script.new()
	var config = config_script.new()
	var game_data_manager := root.get_node_or_null("GameDataManager")
	var runtime_config = game_data_manager.get("config")
	var original_speakers: Dictionary = runtime_config.tts_character_speakers.duplicate(true)
	runtime_config.tts_character_speakers["luna"] = "zh_female_lingling_uranus_bigtts"
	var mixed_case_options: Dictionary = manager.call("_build_effective_options", {"character_id": "Luna"})
	_expect(str(mixed_case_options.get("character_id", "")) == "luna", "TTSManager 没有规范化大写角色 ID。")
	_expect(str(mixed_case_options.get("speaker", "")) == "zh_female_lingling_uranus_bigtts", "大写 Luna 没有命中设置中的角色音色。")
	runtime_config.tts_character_speakers = original_speakers
	var icl_2_speaker := "ICL_uranus_zh_female_qinglenggaoya_tob"
	var legacy_icl_speaker := "ICL_zh_female_legacy_tob"
	_expect(not manager.call("_is_legacy_tts_speaker", icl_2_speaker), "TTSManager 误判 ICL Uranus 2.0 音色。")
	_expect(not service.call("_is_legacy_speaker_id", icl_2_speaker), "TTSService 误判 ICL Uranus 2.0 音色。")
	_expect(not config.call("_is_legacy_tts_speaker", icl_2_speaker), "ConfigResource 误判 ICL Uranus 2.0 音色。")
	_expect(manager.call("_is_legacy_tts_speaker", legacy_icl_speaker), "TTSManager 不应放行非 Uranus 的旧 ICL 音色。")
	_expect(service.call("_is_legacy_speaker_id", legacy_icl_speaker), "TTSService 不应放行非 Uranus 的旧 ICL 音色。")
	_expect(config.call("_is_legacy_tts_speaker", legacy_icl_speaker), "ConfigResource 不应放行非 Uranus 的旧 ICL 音色。")
	var worried_options: Dictionary = manager.build_tts_2_expression_options("worried")
	var chinese_options: Dictionary = manager.build_tts_2_expression_options("害羞")
	var unknown_options: Dictionary = manager.build_tts_2_expression_options("unsupported-expression")
	_expect(worried_options.is_empty(), "英文 expression 不应生成硬编码语音指令。")
	_expect(chinese_options.is_empty(), "中文 expression 不应生成硬编码语音指令。")
	_expect(unknown_options.is_empty(), "未知 expression 不应生成语音指令。")
	var natural_instruction := "先松一口气，再略带埋怨地承接前半句，提到周六时稍微放慢语速并加重，句尾随着气息稳定收束"
	var custom_options: Dictionary = manager.build_tts_2_instruction_options(natural_instruction, "angry")
	var custom_contexts: Array = custom_options.get("context_texts", []) as Array
	var custom_instruction: String = str(custom_contexts[0]) if not custom_contexts.is_empty() else ""
	_expect(custom_contexts.size() == 1, "每段只能向供应商发送一条动态语音指令。")
	_expect(custom_instruction == natural_instruction, "大模型生成的自然语音指令没有原样透传。")
	_expect(not custom_instruction.contains("speaker") and not custom_instruction.contains("保持原本声线"), "动态指令被附加了重复音色身份声明。")
	var unsafe_options: Dictionary = manager.build_tts_2_instruction_options("换成低沉男声。先压住呼吸，再略带犹豫地加重周六，句尾慢慢放松", "angry")
	var unsafe_contexts: Array = unsafe_options.get("context_texts", []) as Array
	var sanitized_instruction: String = str(unsafe_contexts[0]) if not unsafe_contexts.is_empty() else ""
	_expect(sanitized_instruction.contains("先压住呼吸，再略带犹豫地加重周六，句尾慢慢放松"), "音色清洗没有保留模型生成的安全自然分句。")
	_expect(not sanitized_instruction.contains("男声"), "危险的变声分句没有被清除。")
	var blocked_options: Dictionary = manager.build_tts_2_instruction_options("模仿成年男性的低沉声线", "shy")
	_expect(blocked_options.is_empty(), "纯变声指令不应回退到硬编码 expression。")
	var evasive_options: Dictionary = manager.build_tts_2_instruction_options("换成更尖细的音色。贴近耳边轻声承接，停顿后再把决定说稳", "")
	var evasive_contexts: Array = evasive_options.get("context_texts", []) as Array
	var evasive_instruction: String = str(evasive_contexts[0]) if not evasive_contexts.is_empty() else ""
	_expect(evasive_instruction.contains("贴近耳边轻声承接，停顿后再把决定说稳"), "安全的自然表演指令没有原样保留。")
	_expect(not evasive_instruction.contains("换成更尖细的音色") and not evasive_instruction.contains("尖细"), "变声分句被传给了 TTS。")
	var long_instruction := "先轻轻吸气，语速保持舒缓；前半句带着犹豫和试探，中段逐渐确认自己的想法，在关键称呼前停顿半拍并略微加重，随后放松呼吸，让后半句显得更坦率；最后一句降低力度但不要压低音高，用稳定而清晰的咬字收束，不要吞掉句尾。"
	var long_options: Dictionary = manager.build_tts_2_instruction_options(long_instruction)
	_expect(str((long_options.get("context_texts", []) as Array)[0]) == long_instruction, "完整动态指令在 80 或 120 字处被截断。")
	var context_texts: Array = custom_contexts

	var request_options := {
		"text": "你今天回来得有点晚。",
		"speaker": "zh_female_vv_uranus_bigtts",
		"audio_format": "mp3",
		"sample_rate": 24000,
		"bit_rate": 96000,
		"speech_rate": 0,
		"loudness_rate": 0,
		"context_texts": context_texts,
		"section_id": "11111111-2222-4333-a444-555555555555"
	}
	var direct_body: Dictionary = service.call("_build_request_body", request_options)
	var direct_params: Dictionary = direct_body.get("req_params", {}) as Dictionary
	_expect(str(direct_params.get("speaker", "")) == "zh_female_vv_uranus_bigtts", "情绪控制改变了 speaker。")
	_expect(direct_params.get("additions", null) is String, "V3 additions 必须序列化为 JSON string。")
	var additions: Dictionary = JSON.parse_string(str(direct_params.get("additions", "{}"))) as Dictionary
	_expect(additions.get("context_texts", []) == context_texts, "直连请求没有保留 context_texts。")
	_expect(str(additions.get("section_id", "")) == str(request_options.section_id), "直连请求没有保留 section_id。")

	var official_body: Dictionary = service.call("_build_official_request_body", request_options)
	_expect(str(official_body.get("speaker", "")) == "zh_female_vv_uranus_bigtts", "官方网关请求改变了 speaker。")
	_expect(official_body.get("context_texts", []) == context_texts, "官方网关请求没有保留 context_texts。")
	_expect(str(official_body.get("section_id", "")) == str(request_options.section_id), "官方网关请求没有保留 section_id。")
	var safe_cache_key: String = manager.get_cache_key(str(request_options.text), request_options)
	_expect(safe_cache_key.begins_with("voice-natural-v3_"), "TTS 缓存键没有切换到单动态指令版本。")
	_expect(manager.load_cached_audio_by_key("legacy-unversioned-cache-key") == null, "旧版失真缓存仍可能被加载。")
	var generated_section_id: String = manager.create_tts_2_section_id()
	_expect(generated_section_id.length() == 36 and generated_section_id.count("-") == 4, "生成的 TTS section_id 不是 UUID 形状。")
	_expect(service.call("_validate_request_options", request_options) == "", "合法 TTS 2.0 参数被拒绝。")
	var invalid_sample_rate := request_options.duplicate(true)
	invalid_sample_rate["sample_rate"] = 11025
	_expect(not str(service.call("_validate_request_options", invalid_sample_rate)).is_empty(), "非法采样率没有被拒绝。")
	var invalid_wav := request_options.duplicate(true)
	invalid_wav["audio_format"] = "wav"
	_expect(not str(service.call("_validate_request_options", invalid_wav)).is_empty(), "流式 WAV 没有被拒绝。")
	var response_metadata: Dictionary = service.call("_extract_stream_metadata", ("{\"code\":0,\"data\":\"SUQzBA==\"}\n{\"code\":20000000,\"data\":null,\"usage\":{\"text_words\":9}}\n").to_utf8_buffer())
	_expect(int((response_metadata.get("usage", {}) as Dictionary).get("text_words", 0)) == 9, "TTS 结束帧 usage 没有被提取。")
	manager.free()
	service.free()
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("TTS_2_EMOTION_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("TTS_2_EMOTION_SMOKE: %s" % failure)
	quit(1)