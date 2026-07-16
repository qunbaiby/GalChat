extends SceneTree

const Requester = preload("res://addons/story_editor/core/mobile_ai_deepseek_requester.gd")

var failures: Array[String] = []
var completed_result: Dictionary = {}
var failed_result: Dictionary = {}


class FakeClient extends Node:
	signal chat_request_completed(response: Dictionary)
	signal chat_request_failed(error_message: String)

	var received_messages: Array = []
	var cancelled := false

	func call_chat_api_non_stream(messages: Array) -> void:
		received_messages = messages.duplicate(true)

	func cancel_chat_request() -> void:
		cancelled = true

	func get_chat_model_id() -> String:
		return "fake-mobile-model"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var requester := Requester.new()
	var fake := FakeClient.new()
	requester.set_client(fake)
	root.add_child(requester)
	requester.completed.connect(_on_completed)
	requester.failed.connect(_on_failed)
	var messages: Array = [{"role": "system", "content": "测试 Prompt"}, {"role": "user", "content": "你好"}]
	requester.request("mobile_job_1", {"messages": messages})
	_expect(fake.received_messages == messages, "Requester 没有原样转发 messages。")
	fake.chat_request_completed.emit({"id": "chatcmpl-mobile-1", "model": "deepseek-chat", "usage": {"total_tokens": 33}, "choices": [{"message": {"content": "你好"}}]})
	_expect(str(completed_result.get("job_id", "")) == "mobile_job_1", "成功回调 job_id 不正确。")
	var metadata := completed_result.get("metadata", {}) as Dictionary
	_expect(str(metadata.get("response_id", "")) == "chatcmpl-mobile-1", "没有提取响应 ID。")
	_expect(int((metadata.get("usage", {}) as Dictionary).get("total_tokens", 0)) == 33, "没有提取 Token usage。")
	_expect(not bool(metadata.get("quota_available", true)), "聊天客户端无法提供配额时应明确标记不可用。")
	requester.request("mobile_job_2", {"messages": messages})
	fake.chat_request_failed.emit("模拟失败")
	_expect(str(failed_result.get("job_id", "")) == "mobile_job_2" and str(failed_result.get("error", "")) == "模拟失败", "失败回调不正确。")
	requester.request("mobile_job_3", {"messages": messages})
	requester.cancel("mobile_job_3")
	_expect(fake.cancelled and requester.active_job_id.is_empty(), "取消没有终止活动请求。")
	requester.queue_free()
	await process_frame

	if failures.is_empty():
		print("MOBILE_AI_REQUESTER_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("MOBILE_AI_REQUESTER_SMOKE: %s" % failure)
	quit(1)


func _on_completed(job_id: String, raw: Dictionary, metadata: Dictionary) -> void:
	completed_result = {"job_id": job_id, "raw": raw, "metadata": metadata}


func _on_failed(job_id: String, error_message: String, metadata: Dictionary) -> void:
	failed_result = {"job_id": job_id, "error": error_message, "metadata": metadata}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)