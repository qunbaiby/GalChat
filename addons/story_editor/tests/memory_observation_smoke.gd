extends Node

const CognitionTaskQueueScript = preload("res://scripts/data/cognition_task_queue.gd")
const MemoryObservationServiceScript = preload("res://scripts/data/memory_observation_service.gd")

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var original_queue = GameDataManager.cognition_task_queue
	var original_player_turns := GameDataManager.memory_manager.turns_since_last_extract
	var original_pet_turns := GameDataManager.desktop_pet_memory_manager.turns_since_last_extract
	var queue := CognitionTaskQueueScript.new()
	queue.save_path_override = "user://memory_observation_smoke_%d.json" % Time.get_ticks_usec()
	GameDataManager.cognition_task_queue = queue
	GameDataManager.memory_manager.turns_since_last_extract = 0
	GameDataManager.desktop_pet_memory_manager.turns_since_last_extract = 0
	var service := MemoryObservationServiceScript.new()

	_expect(service.observe_completed_turn("mobile_chat", "第一条", "第一条回复").is_empty(), "首个手机回合错误触发了抽取。")
	_expect(service.observe_completed_turn("story_chat", "第二条", "第二条回复").is_empty(), "共享玩家域第二回合错误触发了抽取。")
	var player_task_id := service.observe_completed_turn("story_chat", "第三条", "第三条回复")
	_expect(not player_task_id.is_empty(), "玩家域第三个完整回合没有创建抽取任务。")
	var player_task := queue.get_task(player_task_id)
	_expect(str(player_task.get("memory_domain", "")) == MemoryManager.MEMORY_DOMAIN_PLAYER and str(player_task.get("payload", {}).get("channel", "")) == "story_chat", "玩家域观察任务缺少正确频道或记忆域。")

	service.observe_completed_turn("desktop_chat", "桌面一", "桌面回复一")
	service.observe_completed_turn("desktop_pet", "桌宠二", "桌宠回复二")
	var pet_task_id := service.observe_completed_turn("desktop_pet", "桌宠三", "桌宠回复三")
	_expect(not pet_task_id.is_empty() and str(queue.get_task(pet_task_id).get("memory_domain", "")) == MemoryManager.MEMORY_DOMAIN_DESKTOP_PET, "桌面与桌宠完整回合没有进入共享现实记忆域。")
	_expect(service.observe_completed_turn("fixed_story", "不观察", "不入队").is_empty(), "未启用频道错误创建了观察任务。")
	_expect(service.observe_completed_turn("mobile_chat", "", "空输入").is_empty(), "空玩家文本错误创建了观察任务。")

	queue.tasks.clear()
	for index in CognitionTaskQueueScript.MAX_QUEUE_SIZE:
		queue.tasks.append({
			"id": "capacity-%d" % index,
			"type": "history",
			"payload": {},
			"memory_domain": MemoryManager.MEMORY_DOMAIN_PLAYER,
			"state": "pending",
			"priority": 40,
			"created_at": index,
			"next_attempt_at": 0
		})
	GameDataManager.memory_manager.turns_since_last_extract = 2
	_expect(service.observe_completed_turn("mobile_chat", "容量满", "稍后重试").is_empty(), "队列拒绝时仍返回了观察任务。")
	_expect(GameDataManager.memory_manager.turns_since_last_extract == 2, "观察任务入队失败后没有回滚玩家域回合计数。")

	GameDataManager.cognition_task_queue = original_queue
	GameDataManager.memory_manager.turns_since_last_extract = original_player_turns
	GameDataManager.desktop_pet_memory_manager.turns_since_last_extract = original_pet_turns
	if FileAccess.file_exists(queue.save_path_override):
		DirAccess.remove_absolute(queue.save_path_override)
	queue.free()
	service.free()
	if failures.is_empty():
		print("MEMORY_OBSERVATION_SMOKE_OK")
		get_tree().quit(0)
		return
	for failure in failures:
		push_error("MEMORY_OBSERVATION_SMOKE: %s" % failure)
	get_tree().quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)