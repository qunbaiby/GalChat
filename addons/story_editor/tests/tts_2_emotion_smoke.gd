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
	_expect(not worried_options.is_empty(), "英文表情没有映射为 TTS 2.0 指令。")
	_expect(not chinese_options.is_empty(), "中文情绪没有映射为 TTS 2.0 指令。")
	_expect(unknown_options.is_empty(), "未知情绪不应生成不可控的自由指令。")

	var context_texts: Array = worried_options.get("context_texts", []) as Array
	_expect(context_texts.size() == 1, "单个情绪应只生成一条短指令。")
	var instruction: String = str(context_texts[0]) if not context_texts.is_empty() else ""
	_expect(instruction.contains("克制"), "担心语气没有限制情绪强度。")
	_expect(instruction.contains("保持原本声线"), "语气指令没有要求保持角色音色。")
	var custom_options: Dictionary = manager.build_tts_2_instruction_options("略带害羞地慢一点说", "angry")
	var custom_contexts: Array = custom_options.get("context_texts", []) as Array
	var custom_instruction: String = str(custom_contexts[0]) if not custom_contexts.is_empty() else ""
	_expect(custom_instruction.begins_with("略带害羞地慢一点说"), "自定义语音指令没有优先于 expression。")
	_expect(custom_instruction.contains("保持原本声线"), "自定义语音指令没有自动附加音色保护。")

	var request_options := {
		"text": "你今天回来得有点晚。",
		"speaker": "zh_female_vv_uranus_bigtts",
		"audio_format": "mp3",
		"sample_rate": 24000,
		"bit_rate": 96000,
		"speech_rate": 0,
		"loudness_rate": 0,
		"context_texts": context_texts
	}
	var direct_body: Dictionary = service.call("_build_request_body", request_options)
	var direct_params: Dictionary = direct_body.get("req_params", {}) as Dictionary
	_expect(str(direct_params.get("speaker", "")) == "zh_female_vv_uranus_bigtts", "情绪控制改变了 speaker。")
	_expect(direct_params.get("additions", null) is String, "V3 additions 必须序列化为 JSON string。")
	var additions: Dictionary = JSON.parse_string(str(direct_params.get("additions", "{}"))) as Dictionary
	_expect(additions.get("context_texts", []) == context_texts, "直连请求没有保留 context_texts。")

	var official_body: Dictionary = service.call("_build_official_request_body", request_options)
	_expect(str(official_body.get("speaker", "")) == "zh_female_vv_uranus_bigtts", "官方网关请求改变了 speaker。")
	_expect(official_body.get("context_texts", []) == context_texts, "官方网关请求没有保留 context_texts。")
	manager.free()
	service.free()
	config.free()
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