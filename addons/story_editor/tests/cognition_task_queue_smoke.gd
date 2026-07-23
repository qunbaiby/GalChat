extends Node

const CognitionTaskQueueScript = preload("res://scripts/data/cognition_task_queue.gd")

var failures: Array[String] = []
var test_path: String


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	test_path = "user://cognition_task_queue_smoke_%d.json" % Time.get_ticks_usec()
	var queue = CognitionTaskQueueScript.new()
	queue.save_path_override = test_path
	add_child(queue)

	var first_id: String = queue.enqueue("exchange", {"user_text": "你好", "ai_reply": "晚上好"}, MemoryManager.MEMORY_DOMAIN_PLAYER, {"context_domain": "story"})
	var second_id: String = queue.enqueue("exchange", {"user_text": "桌宠", "ai_reply": "在呢"}, MemoryManager.MEMORY_DOMAIN_DESKTOP_PET)
	_expect(FileAccess.file_exists(test_path), "任务入队后没有持久化队列文件。")
	_expect(queue.get_pending_count() == 2, "任务入队数量不正确。")

	var claimed: Dictionary = queue.claim_next()
	_expect(str(claimed.get("id", "")) == first_id, "队列没有按顺序领取首个任务。")
	_expect(str(claimed.get("character_id", "")).strip_edges() != "", "任务没有记录角色作用域。")
	_expect(queue.claim_next().is_empty(), "已有租约时仍领取了第二个任务。")
	queue.tasks[0]["lease_until"] = int(Time.get_unix_time_from_system()) - 1
	var reclaimed: Dictionary = queue.claim_next()
	_expect(str(reclaimed.get("id", "")) == first_id, "租约过期后没有恢复并重新领取任务。")

	queue.fail(first_id, "模拟网络失败")
	var failed_once: Dictionary = queue.get_task(first_id)
	_expect(int(failed_once.get("attempts", 0)) == 1, "失败后没有增加尝试次数。")
	_expect(str(failed_once.get("state", "")) == "pending", "首次失败后任务没有返回待处理状态。")
	_expect(int(failed_once.get("next_attempt_at", 0)) > int(Time.get_unix_time_from_system()), "失败后没有设置退避时间。")

	var restored = CognitionTaskQueueScript.new()
	restored.save_path_override = test_path
	add_child(restored)
	restored.load_queue()
	_expect(restored.get_task(first_id).get("last_error", "") == "模拟网络失败", "重载后失败信息丢失。")
	_expect(restored.get_task(second_id).get("memory_domain", "") == MemoryManager.MEMORY_DOMAIN_DESKTOP_PET, "重载后记忆域丢失。")

	for attempt in range(1, CognitionTaskQueueScript.MAX_ATTEMPTS):
		restored.tasks[0]["state"] = "processing"
		restored.fail(first_id, "失败 %d" % attempt)
	var terminal_task: Dictionary = restored.get_task(first_id)
	_expect(str(terminal_task.get("state", "")) == "failed", "达到最大次数后任务没有进入失败终态。")
	_expect(int(terminal_task.get("attempts", 0)) == CognitionTaskQueueScript.MAX_ATTEMPTS, "失败终态尝试次数不正确。")
	var failed_tasks: Array = restored.get_failed_tasks()
	_expect(failed_tasks.size() == 1 and str(failed_tasks[0].get("id", "")) == first_id, "失败任务列表没有返回终态任务。")
	_expect(restored.retry_failed(first_id), "失败任务无法立即重试。")
	var retried_task: Dictionary = restored.get_task(first_id)
	_expect(str(retried_task.get("state", "")) == "pending", "重试后任务没有回到待处理状态。")
	_expect(int(retried_task.get("attempts", -1)) == 0 and str(retried_task.get("last_error", "")) == "", "重试后没有清理失败状态。")
	for attempt in CognitionTaskQueueScript.MAX_ATTEMPTS:
		restored.tasks[0]["state"] = "processing"
		restored.fail(first_id, "再次失败 %d" % attempt)
	_expect(restored.discard_task(first_id), "无法丢弃失败任务。")
	_expect(restored.get_task(first_id).is_empty(), "丢弃后失败任务仍残留。")
	_expect(restored.complete(second_id), "完成任务时没有成功移除。")
	_expect(restored.get_task(second_id).is_empty(), "已完成任务仍残留在队列。")
	var edit_id: String = restored.enqueue("memory_edit", {"layer": "habit", "memory_id": "memory-1", "content": "修改内容"}, MemoryManager.MEMORY_DOMAIN_PLAYER)
	var local_task: Dictionary = restored.claim_next_local()
	_expect(str(local_task.get("id", "")) == edit_id, "本地记忆编辑任务没有被本地领取通道领取。")
	_expect(str(local_task.get("state", "")) == "processing", "本地任务领取后没有进入处理状态。")
	_expect(restored.complete(edit_id), "本地任务完成后没有移除。")

	restored.tasks = []
	var exchange_id := restored.enqueue("exchange", {"user_text": "普通", "ai_reply": "回复"}, MemoryManager.MEMORY_DOMAIN_PLAYER)
	var history_id := restored.enqueue("history", {"history_text": "历史"}, MemoryManager.MEMORY_DOMAIN_PLAYER)
	var priority_task: Dictionary = restored.claim_next()
	_expect(str(priority_task.get("id", "")) == history_id, "高优先级历史任务没有先于普通提取任务领取。")
	restored.complete(history_id)
	restored.complete(exchange_id)

	var first_edit_id := restored.enqueue("memory_edit", {"layer": "habit", "memory_id": "same-memory", "content": "旧内容"}, MemoryManager.MEMORY_DOMAIN_PLAYER)
	var merged_edit_id := restored.enqueue("memory_edit", {"layer": "habit", "memory_id": "same-memory", "content": "最新内容"}, MemoryManager.MEMORY_DOMAIN_PLAYER)
	_expect(first_edit_id == merged_edit_id, "同一记忆的待处理编辑任务没有合并。")
	_expect(restored.tasks.size() == 1 and str(restored.tasks[0].get("payload", {}).get("content", "")) == "最新内容", "合并编辑任务没有保留最新内容。")
	restored.complete(first_edit_id)

	var first_summary_id := restored.enqueue("conversation_summary", {"channel": "main_chat", "covered_message_count": 20}, MemoryManager.MEMORY_DOMAIN_PLAYER)
	var merged_summary_id := restored.enqueue("conversation_summary", {"channel": "main_chat", "covered_message_count": 30}, MemoryManager.MEMORY_DOMAIN_PLAYER)
	_expect(first_summary_id == merged_summary_id and restored.tasks.size() == 1, "同一通道的摘要任务没有合并。")
	_expect(int(restored.tasks[0].get("payload", {}).get("covered_message_count", 0)) == 30, "摘要任务合并后没有保留最新覆盖范围。")
	restored.complete(first_summary_id)

	var first_cluster_summary_id := restored.enqueue("habit_cluster_summary", {"cluster_id": "habit-cluster", "snapshot_hash": "snapshot-1", "member_memory_ids": ["a", "b", "c"]}, MemoryManager.MEMORY_DOMAIN_PLAYER)
	var merged_cluster_summary_id := restored.enqueue("habit_cluster_summary", {"cluster_id": "habit-cluster", "snapshot_hash": "snapshot-1", "member_memory_ids": ["a", "b", "c"], "member_contents": ["A", "B", "C"]}, MemoryManager.MEMORY_DOMAIN_PLAYER)
	var changed_cluster_summary_id := restored.enqueue("habit_cluster_summary", {"cluster_id": "habit-cluster", "snapshot_hash": "snapshot-2", "member_memory_ids": ["a", "b", "c"]}, MemoryManager.MEMORY_DOMAIN_PLAYER)
	_expect(first_cluster_summary_id == merged_cluster_summary_id and changed_cluster_summary_id != first_cluster_summary_id, "习惯聚类摘要任务没有按稳定成员快照去重。")
	_expect(restored.tasks.size() == 2 and Array(restored.get_task(first_cluster_summary_id).get("payload", {}).get("member_contents", [])).size() == 3, "聚类摘要任务合并没有保留最新完整负载。")
	restored.tasks[0]["state"] = "processing"
	var processing_cluster_summary_id := restored.enqueue("habit_cluster_summary", {"cluster_id": "habit-cluster", "snapshot_hash": "snapshot-1", "member_memory_ids": ["a", "b", "c"]}, MemoryManager.MEMORY_DOMAIN_PLAYER)
	_expect(processing_cluster_summary_id == first_cluster_summary_id and restored.tasks.size() == 2, "正在处理的聚类摘要快照仍被重复入队。")
	restored.complete(first_cluster_summary_id)
	restored.complete(changed_cluster_summary_id)

	restored.tasks = []
	for index in CognitionTaskQueueScript.MAX_QUEUE_SIZE:
		restored.tasks.append({
			"id": "capacity-%d" % index,
			"type": "exchange",
			"payload": {},
			"memory_domain": MemoryManager.MEMORY_DOMAIN_PLAYER,
			"state": "pending",
			"priority": 20,
			"created_at": index,
			"next_attempt_at": 0
		})
	var capacity_edit_id := restored.enqueue("memory_edit", {"layer": "core", "memory_id": "important", "content": "高优先级修改"}, MemoryManager.MEMORY_DOMAIN_PLAYER)
	_expect(not capacity_edit_id.is_empty(), "队列满时拒绝了可替换低优先级任务的记忆编辑。")
	_expect(restored.tasks.size() == CognitionTaskQueueScript.MAX_QUEUE_SIZE, "容量替换后队列大小不正确。")
	_expect(restored.get_task("capacity-0").is_empty(), "队列满时没有淘汰低优先级待处理任务。")

	queue.queue_free()
	restored.queue_free()
	if FileAccess.file_exists(test_path):
		DirAccess.remove_absolute(test_path)
	if failures.is_empty():
		print("COGNITION_TASK_QUEUE_SMOKE_OK")
		get_tree().quit(0)
		return
	for failure in failures:
		push_error("COGNITION_TASK_QUEUE_SMOKE: %s" % failure)
	get_tree().quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)