extends SceneTree

const QueueScript = preload("res://addons/story_editor/core/date_ai_generation_queue.gd")

var failures: Array[String] = []


class FakeRequester extends Node:
	signal completed(job_id: String, raw_response: Dictionary, metadata: Dictionary)
	signal failed(job_id: String, error_message: String, metadata: Dictionary)

	var attempts := {}
	var requests: Array[String] = []
	var held_job_id := ""
	var cancelled_jobs: Array[String] = []

	func request(job_id: String, context: Dictionary) -> void:
		requests.append(job_id)
		attempts[job_id] = int(attempts.get(job_id, 0)) + 1
		var mode := str(context.get("mode", "success"))
		if mode == "hold":
			held_job_id = job_id
			return
		if mode == "retry" and int(attempts[job_id]) == 1:
			failed.emit.call_deferred(job_id, "temporary", {"duration_ms": 4})
			return
		completed.emit.call_deferred(job_id, {"summary": job_id, "segments": []}, {"duration_ms": 6, "usage": {"total_tokens": 12}})

	func cancel(job_id: String) -> void:
		cancelled_jobs.append(job_id)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var queue := QueueScript.new()
	var fake := FakeRequester.new()
	root.add_child(queue)
	queue.add_child(fake)
	queue.set_requester(fake)
	queue.start([{"mode": "success"}, {"mode": "retry"}], 1)
	await queue.queue_finished
	var completed_snapshot := queue.snapshot()
	_expect(int(completed_snapshot.counts.completed) == 2, "队列没有完成成功与重试任务。")
	_expect(int(completed_snapshot.total_attempts) == 3, "队列重试次数统计不正确。")
	_expect(int((completed_snapshot.jobs[1] as Dictionary).duration_ms) == 10, "队列没有累计重试耗时。")
	_expect(((completed_snapshot.jobs[0] as Dictionary).metadata as Dictionary).has("usage"), "队列没有保留请求元数据。")

	fake.requests.clear()
	queue.start([{"mode": "hold"}, {"mode": "success"}], 0)
	queue.pause()
	_expect(bool(queue.snapshot().paused), "队列没有进入暂停状态。")
	_expect(fake.requests.count("date_job_1") == 0, "暂停时提前派发了后续任务。")
	queue.cancel()
	var cancelled_snapshot := queue.snapshot()
	_expect(int(cancelled_snapshot.counts.cancelled) == 2, "取消没有覆盖运行中和等待中的任务。")
	_expect(fake.cancelled_jobs.has("date_job_0"), "取消没有通知活动请求器。")
	queue.queue_free()
	await process_frame
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("DATE_AI_GENERATION_QUEUE_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("DATE_AI_GENERATION_QUEUE_SMOKE: %s" % failure)
	quit(1)