extends Node

signal completed(job_id: String, raw_response: Dictionary, metadata: Dictionary)
signal failed(job_id: String, error_message: String, metadata: Dictionary)

const CLIENT_PATH := "res://scripts/api/deepseek_client.gd"

var client: Node
var active_job_id := ""
var started_at_ms := 0


func _ready() -> void:
	if client == null:
		var client_script: GDScript = load(CLIENT_PATH)
		if client_script != null:
			client = client_script.new()
			add_child(client)
	_connect_client()


func set_client(value: Node) -> void:
	_disconnect_client()
	client = value
	if client != null and client.get_parent() == null:
		add_child(client)
	_connect_client()


func request(job_id: String, context: Dictionary) -> void:
	if client == null:
		failed.emit.call_deferred(job_id, "无法加载 DeepSeekClient。", {})
		return
	if not active_job_id.is_empty():
		failed.emit.call_deferred(job_id, "已有手机 AI 请求正在执行。", {})
		return
	var messages_value: Variant = context.get("messages")
	if not messages_value is Array or (messages_value as Array).is_empty():
		failed.emit.call_deferred(job_id, "请求缺少 messages。", {})
		return
	active_job_id = job_id
	started_at_ms = Time.get_ticks_msec()
	client.call_chat_api_non_stream((messages_value as Array).duplicate(true))


func cancel(job_id: String) -> void:
	if job_id != active_job_id:
		return
	if client != null and client.has_method("cancel_chat_request"):
		client.cancel_chat_request()
	active_job_id = ""


func _on_completed(response: Dictionary) -> void:
	if active_job_id.is_empty():
		return
	var job_id := active_job_id
	active_job_id = ""
	var metadata := _extract_metadata(response)
	metadata["duration_ms"] = Time.get_ticks_msec() - started_at_ms
	completed.emit(job_id, response.duplicate(true), metadata)


func _on_failed(error_message: String) -> void:
	if active_job_id.is_empty():
		return
	var job_id := active_job_id
	active_job_id = ""
	failed.emit(job_id, error_message, {"duration_ms": Time.get_ticks_msec() - started_at_ms})


func _extract_metadata(response: Dictionary) -> Dictionary:
	return {
		"model": str(response.get("model", client.get_chat_model_id() if client != null and client.has_method("get_chat_model_id") else "")),
		"response_id": str(response.get("id", "")),
		"http_status": 200,
		"usage": (response.get("usage", {}) as Dictionary).duplicate(true),
		"quota": {},
		"quota_available": false
	}


func _connect_client() -> void:
	if client == null:
		return
	if not client.chat_request_completed.is_connected(_on_completed):
		client.chat_request_completed.connect(_on_completed)
	if not client.chat_request_failed.is_connected(_on_failed):
		client.chat_request_failed.connect(_on_failed)


func _disconnect_client() -> void:
	if client == null:
		return
	if client.chat_request_completed.is_connected(_on_completed):
		client.chat_request_completed.disconnect(_on_completed)
	if client.chat_request_failed.is_connected(_on_failed):
		client.chat_request_failed.disconnect(_on_failed)