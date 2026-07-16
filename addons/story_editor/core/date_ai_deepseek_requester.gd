extends Node

signal completed(job_id: String, raw_response: Dictionary, metadata: Dictionary)
signal failed(job_id: String, error_message: String, metadata: Dictionary)

const CLIENT_PATH := "res://scripts/api/deepseek_client.gd"

var client: Node
var active_job_id := ""
var started_at_ms := 0


func _ready() -> void:
	var client_script: GDScript = load(CLIENT_PATH)
	if client_script == null:
		return
	client = client_script.new()
	add_child(client)
	client.date_story_generated_detailed.connect(_on_generated)
	client.date_story_error_detailed.connect(_on_error)


func request(job_id: String, context: Dictionary) -> void:
	if client == null:
		failed.emit.call_deferred(job_id, "无法加载 DeepSeekClient。", {})
		return
	if not active_job_id.is_empty():
		failed.emit.call_deferred(job_id, "已有 AI 生成请求正在执行。", {})
		return
	active_job_id = job_id
	started_at_ms = Time.get_ticks_msec()
	client.generate_date_story(context)


func cancel(job_id: String) -> void:
	if job_id != active_job_id:
		return
	if client != null and client.date_story_http != null:
		client.date_story_http.cancel_request()
	active_job_id = ""


func _on_generated(raw_response: Dictionary, response_metadata: Dictionary) -> void:
	if active_job_id.is_empty():
		return
	var job_id := active_job_id
	active_job_id = ""
	var metadata := response_metadata.duplicate(true)
	metadata["duration_ms"] = Time.get_ticks_msec() - started_at_ms
	completed.emit(job_id, raw_response, metadata)


func _on_error(error_message: String, response_metadata: Dictionary) -> void:
	if active_job_id.is_empty():
		return
	var job_id := active_job_id
	active_job_id = ""
	var metadata := response_metadata.duplicate(true)
	metadata["duration_ms"] = Time.get_ticks_msec() - started_at_ms
	failed.emit(job_id, error_message, metadata)