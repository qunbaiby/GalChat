extends SceneTree

const SERVICE_PATH := "res://scripts/api/services/deepseek/deepseek_scene_event_service.gd"

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var service_script: GDScript = load(SERVICE_PATH)
	_expect(service_script != null, "无法加载 date-story 响应服务。")
	if service_script == null:
		_finish()
		return
	var service = service_script.new()
	var model_content := {"summary": "元数据测试", "segments": [{"lines": [{"speaker": "luna", "content": "测试对白"}]}]}
	var outer_response := {
		"id": "chatcmpl-test-42",
		"model": "deepseek-chat",
		"choices": [{"message": {"content": JSON.stringify(model_content)}}],
		"usage": {"prompt_tokens": 100, "completion_tokens": 40, "total_tokens": 140}
	}
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"X-Quota-Capability: chat",
		"x-quota-limit: 300",
		"X-QUOTA-REMAINING: 287"
	])
	var parsed: Dictionary = service.extract_date_story_response(JSON.stringify(outer_response).to_utf8_buffer(), 200, headers)
	_expect(bool(parsed.get("ok", false)), "有效 date-story 响应没有解析成功。")
	_expect(str((parsed.get("script_data", {}) as Dictionary).get("summary", "")) == "元数据测试", "模型内容没有从外层响应中提取。")
	var metadata := parsed.get("metadata", {}) as Dictionary
	_expect(str(metadata.get("model", "")) == "deepseek-chat", "没有保留模型 ID。")
	_expect(str(metadata.get("response_id", "")) == "chatcmpl-test-42", "没有保留响应 ID。")
	_expect(int(metadata.get("http_status", 0)) == 200, "没有保留 HTTP 状态。")
	_expect(int((metadata.get("usage", {}) as Dictionary).get("total_tokens", 0)) == 140, "没有保留 usage Token。")
	var quota := metadata.get("quota", {}) as Dictionary
	_expect(str(quota.get("capability", "")) == "chat", "没有大小写不敏感地解析配额能力。")
	_expect(int(quota.get("limit", 0)) == 300, "没有解析配额上限。")
	_expect(int(quota.get("remaining", 0)) == 287, "没有解析剩余配额。")
	var invalid: Dictionary = service.extract_date_story_response("not-json".to_utf8_buffer(), 502, PackedStringArray())
	_expect(not bool(invalid.get("ok", true)), "非法响应错误地解析成功。")
	_expect(int((invalid.get("metadata", {}) as Dictionary).get("http_status", 0)) == 502, "非法响应没有保留 HTTP 状态。")
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("DATE_AI_RESPONSE_METADATA_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("DATE_AI_RESPONSE_METADATA_SMOKE: %s" % failure)
	quit(1)