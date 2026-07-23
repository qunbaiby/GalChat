extends Node

var failures: Array[String] = []
var queue_path: String
var summary_path: String
var memory_path: String


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var queue = GameDataManager.cognition_task_queue
	var summary_manager = GameDataManager.conversation_summary_manager
	var original_queue_path: String = queue.save_path_override
	var original_summary_path: String = summary_manager.save_path_override
	var original_tasks: Array = queue.tasks.duplicate(true)
	var original_summaries: Dictionary = summary_manager.summaries.duplicate(true)
	var original_messages: Array = GameDataManager.history.messages.duplicate(true)
	var original_embedding_enabled: bool = GameDataManager.config.embedding_enabled
	var suffix := str(Time.get_ticks_usec())
	queue_path = "user://summary_queue_smoke_%s.json" % suffix
	summary_path = "user://summary_state_smoke_%s.json" % suffix
	memory_path = "user://summary_memory_smoke_%s.json" % suffix
	queue.save_path_override = queue_path
	summary_manager.save_path_override = summary_path
	queue.tasks = []
	summary_manager.summaries = {}
	GameDataManager.history.messages = _build_messages(30)
	GameDataManager.config.embedding_enabled = false

	var task_id: String = summary_manager.queue_summary_if_needed("main_chat")
	_expect(not task_id.is_empty(), "达到阈值后没有创建摘要任务。")
	var task: Dictionary = queue.get_task(task_id)
	var payload: Dictionary = task.get("payload", {})
	_expect(Array(payload.get("messages", [])).size() == 20, "摘要批次没有保留最近 10 条原始消息。")
	_expect(int(payload.get("covered_message_count", 0)) == 20, "摘要覆盖消息计数不正确。")
	_expect(summary_manager.queue_summary_if_needed("main_chat").is_empty(), "同一通道重复创建了摘要任务。")

	var long_summary := "摘要".repeat(1000)
	_expect(summary_manager.apply_summary("main_chat", long_summary, 20, task_id), "摘要结果没有成功应用。")
	_expect(summary_manager.get_summary("main_chat").length() <= summary_manager.SUMMARY_MAX_CHARS, "摘要没有执行字符预算。")
	_expect(summary_manager.get_summary_state("main_chat").get("pending_task_id", "") == "", "摘要完成后没有释放通道锁。")
	var rebuilt_task_id: String = summary_manager.rebuild_summary("main_chat")
	_expect(not rebuilt_task_id.is_empty(), "手动重建摘要没有重新创建任务。")
	_expect(summary_manager.get_summary("main_chat").is_empty(), "手动重建前没有清除旧摘要。")
	_expect(str(summary_manager.get_summary_state("main_chat").get("pending_task_id", "")) == rebuilt_task_id, "手动重建任务没有重新锁定通道。")
	summary_manager.clear_all()
	_expect(summary_manager.get_summary("main_chat").is_empty(), "清空历史关联状态后摘要仍然残留。")

	var memory_manager := MemoryManager.new()
	memory_manager.memory_file_path_override = memory_path
	memory_manager.memories = {"core": [], "emotion": [], "habit": [], "bond": []}
	memory_manager.add_memory_quick("habit", "玩家 喜欢  咖啡")
	memory_manager.add_memory_quick("habit", "玩家 喜欢 咖啡")
	_expect(memory_manager.memories["habit"].size() == 1, "规范化后的重复记忆没有去重。")
	var memory_id := str(memory_manager.memories["habit"][0].get("id", ""))
	_expect(memory_manager.supersede_memory("habit", memory_id, "玩家现在更喜欢喝茶"), "冲突记忆没有完成替代。")
	var old_memory: Dictionary = memory_manager.memories["habit"][0]
	var revised: Dictionary = memory_manager.memories["habit"][1]
	_expect(str(old_memory.get("content", "")) == "玩家 喜欢  咖啡" and str(old_memory.get("status", "")) == MemoryManager.MEMORY_STATUS_SUPERSEDED, "替代没有保留并停用旧事实。")
	_expect(str(revised.get("content", "")) == "玩家现在更喜欢喝茶", "替代后没有创建新事实。")
	_expect(Array(revised.get("revision_history", [])).size() == 1, "替代后没有记录修订链。")
	_expect(str(revised.get("revision_history", [])[0].get("content", "")) == "玩家 喜欢  咖啡", "修订链没有保留旧事实。")
	var conflict_prompt := memory_manager.get_memory_prompt([])
	_expect(conflict_prompt.contains("玩家现在更喜欢喝茶") and not conflict_prompt.contains("玩家 喜欢  咖啡"), "被替代事实仍进入记忆 Prompt。")

	queue.save_path_override = original_queue_path
	summary_manager.save_path_override = original_summary_path
	queue.tasks = original_tasks
	summary_manager.summaries = original_summaries
	GameDataManager.history.messages = original_messages
	GameDataManager.config.embedding_enabled = original_embedding_enabled
	_cleanup_file(queue_path)
	_cleanup_file(summary_path)
	_cleanup_file(memory_path)
	if failures.is_empty():
		print("CONVERSATION_SUMMARY_CONFLICT_SMOKE_OK")
		get_tree().quit(0)
		return
	for failure in failures:
		push_error("CONVERSATION_SUMMARY_CONFLICT_SMOKE: %s" % failure)
	get_tree().quit(1)


func _build_messages(count: int) -> Array:
	var result: Array = []
	for index in count:
		result.append({
			"type": "main_chat",
			"speaker": "player" if index % 2 == 0 else "char",
			"text": "测试消息 %d" % index,
			"time": "2026-07-23T12:00:00"
		})
	return result


func _cleanup_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)