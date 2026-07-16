extends Node

signal queue_changed(snapshot: Dictionary)
signal queue_finished(snapshot: Dictionary)

var requester: Node
var jobs: Array[Dictionary] = []
var max_retries := 1
var paused := false
var cancelled := false
var _active_index := -1
var _started_at_ms := 0


func set_requester(value: Node) -> void:
	if requester != null:
		_disconnect_requester()
	requester = value
	if requester != null:
		requester.completed.connect(_on_request_completed)
		requester.failed.connect(_on_request_failed)


func start(contexts: Array, retry_limit: int = 1) -> void:
	cancelled = false
	paused = false
	max_retries = maxi(retry_limit, 0)
	_active_index = -1
	jobs.clear()
	for job_index in contexts.size():
		jobs.append({
			"id": "date_job_%d" % job_index,
			"index": job_index,
			"context": (contexts[job_index] as Dictionary).duplicate(true),
			"status": "pending",
			"attempts": 0,
			"duration_ms": 0,
			"raw": {},
			"error": "",
			"metadata": {}
		})
	_emit_changed()
	_dispatch_next()


func pause() -> void:
	paused = true
	_emit_changed()


func resume() -> void:
	if cancelled:
		return
	paused = false
	_emit_changed()
	_dispatch_next()


func cancel() -> void:
	cancelled = true
	paused = false
	if _active_index >= 0 and requester != null and requester.has_method("cancel"):
		requester.cancel(str(jobs[_active_index].id))
	for job in jobs:
		if str(job.status) in ["pending", "running"]:
			job.status = "cancelled"
	_active_index = -1
	_emit_changed()
	queue_finished.emit(snapshot())


func snapshot() -> Dictionary:
	var counts := {"pending": 0, "running": 0, "completed": 0, "failed": 0, "cancelled": 0}
	var total_duration_ms := 0
	var total_attempts := 0
	for job in jobs:
		var status := str(job.status)
		counts[status] = int(counts.get(status, 0)) + 1
		total_duration_ms += int(job.duration_ms)
		total_attempts += int(job.attempts)
	return {
		"jobs": jobs.duplicate(true),
		"counts": counts,
		"paused": paused,
		"cancelled": cancelled,
		"active_index": _active_index,
		"total_duration_ms": total_duration_ms,
		"total_attempts": total_attempts
	}


func _dispatch_next() -> void:
	if paused or cancelled or _active_index >= 0 or requester == null:
		return
	for job_index in jobs.size():
		if str(jobs[job_index].status) != "pending":
			continue
		_active_index = job_index
		jobs[job_index].status = "running"
		jobs[job_index].attempts = int(jobs[job_index].attempts) + 1
		_started_at_ms = Time.get_ticks_msec()
		_emit_changed()
		requester.request(str(jobs[job_index].id), jobs[job_index].context)
		return
	queue_finished.emit(snapshot())


func _on_request_completed(job_id: String, raw_response: Dictionary, metadata: Dictionary = {}) -> void:
	if not _is_active_job(job_id):
		return
	var job := jobs[_active_index]
	job.status = "completed"
	job.raw = raw_response.duplicate(true)
	job.metadata = metadata.duplicate(true)
	job.error = ""
	job.duration_ms = int(job.duration_ms) + int(metadata.get("duration_ms", Time.get_ticks_msec() - _started_at_ms))
	_active_index = -1
	_emit_changed()
	_dispatch_next()


func _on_request_failed(job_id: String, error_message: String, metadata: Dictionary = {}) -> void:
	if not _is_active_job(job_id):
		return
	var job := jobs[_active_index]
	job.duration_ms = int(job.duration_ms) + int(metadata.get("duration_ms", Time.get_ticks_msec() - _started_at_ms))
	job.metadata = metadata.duplicate(true)
	job.error = error_message
	if int(job.attempts) <= max_retries and not cancelled:
		job.status = "pending"
	else:
		job.status = "failed"
	_active_index = -1
	_emit_changed()
	_dispatch_next()


func _is_active_job(job_id: String) -> bool:
	return _active_index >= 0 and _active_index < jobs.size() and str(jobs[_active_index].id) == job_id and not cancelled


func _emit_changed() -> void:
	queue_changed.emit(snapshot())


func _disconnect_requester() -> void:
	if requester.completed.is_connected(_on_request_completed):
		requester.completed.disconnect(_on_request_completed)
	if requester.failed.is_connected(_on_request_failed):
		requester.failed.disconnect(_on_request_failed)