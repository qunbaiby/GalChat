class_name CognitionTaskQueue
extends Node

signal task_enqueued()
signal queue_changed()

const SafeFileAccessUtil = preload("res://scripts/utils/safe_file_access.gd")
const SAVE_FILE_NAME := "cognition_tasks.json"
const SCHEMA_VERSION := 1
const MAX_ATTEMPTS := 5
const LEASE_SECONDS := 120
const BASE_RETRY_SECONDS := 15
const MAX_RETRY_SECONDS := 900
const LOCAL_TASK_TYPES := ["memory_edit"]
const MAX_QUEUE_SIZE := 200
const TASK_PRIORITIES := {
	"memory_edit": 100,
	"conversation_summary": 80,
	"habit_cluster_summary": 70,
	"history": 40,
	"exchange": 20
}

var tasks: Array = []
var save_path_override: String = ""


func get_save_path() -> String:
	if not save_path_override.is_empty():
		return save_path_override
	var character_id := "default"
	if GameDataManager.config and not str(GameDataManager.config.current_character_id).is_empty():
		character_id = str(GameDataManager.config.current_character_id)
	return GameDataManager.get_character_save_path(SAVE_FILE_NAME, character_id)


func load_queue() -> void:
	tasks.clear()
	var path := get_save_path()
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary or int(parsed.get("schema_version", 0)) != SCHEMA_VERSION:
		return
	var loaded_tasks: Variant = parsed.get("tasks", [])
	if not loaded_tasks is Array:
		return
	for raw_task in loaded_tasks:
		if raw_task is Dictionary and _is_valid_task(raw_task):
			tasks.append(raw_task.duplicate(true))
	_recover_expired_leases()
	_save_queue()


func enqueue(task_type: String, payload: Dictionary, memory_domain: String, memory_context: Dictionary = {}) -> String:
	var now := int(Time.get_unix_time_from_system())
	var duplicate_id := _merge_duplicate_pending_task(task_type, payload, memory_domain, memory_context, now)
	if not duplicate_id.is_empty():
		_save_queue()
		task_enqueued.emit()
		queue_changed.emit()
		return duplicate_id
	if not _ensure_queue_capacity(_get_task_priority(task_type)):
		return ""
	var task_id := _generate_id()
	tasks.append({
		"id": task_id,
		"type": task_type,
		"payload": payload.duplicate(true),
		"memory_domain": memory_domain,
		"memory_context": memory_context.duplicate(true),
		"archive_id": GameDataManager.get_active_archive_id(),
		"character_id": str(GameDataManager.config.current_character_id) if GameDataManager.config else "default",
		"state": "pending",
		"attempts": 0,
		"next_attempt_at": now,
		"lease_until": 0,
		"last_error": "",
		"created_at": now,
		"updated_at": now
		,"priority": _get_task_priority(task_type)
	})
	_save_queue()
	task_enqueued.emit()
	queue_changed.emit()
	return task_id


func get_status_counts() -> Dictionary:
	var counts := {"pending": 0, "processing": 0, "failed": 0}
	for task in tasks:
		var state := str(task.get("state", ""))
		if counts.has(state):
			counts[state] = int(counts[state]) + 1
	return counts


func get_failed_tasks() -> Array:
	var failed_tasks: Array = []
	for task in tasks:
		if str(task.get("state", "")) == "failed":
			failed_tasks.append(task.duplicate(true))
	failed_tasks.sort_custom(func(a, b): return int(a.get("updated_at", 0)) > int(b.get("updated_at", 0)))
	return failed_tasks


func retry_failed(task_id: String) -> bool:
	var now := int(Time.get_unix_time_from_system())
	for task in tasks:
		if str(task.get("id", "")) != task_id or str(task.get("state", "")) != "failed":
			continue
		task["state"] = "pending"
		task["attempts"] = 0
		task["next_attempt_at"] = now
		task["lease_until"] = 0
		task["last_error"] = ""
		task["updated_at"] = now
		var saved := _save_queue()
		queue_changed.emit()
		task_enqueued.emit()
		return saved
	return false


func discard_task(task_id: String) -> bool:
	for index in range(tasks.size()):
		if str(tasks[index].get("id", "")) != task_id or str(tasks[index].get("state", "")) != "failed":
			continue
		tasks.remove_at(index)
		var saved := _save_queue()
		queue_changed.emit()
		return saved
	return false


func clear_failed() -> int:
	var removed_count := 0
	for index in range(tasks.size() - 1, -1, -1):
		if str(tasks[index].get("state", "")) == "failed":
			tasks.remove_at(index)
			removed_count += 1
	if removed_count > 0:
		_save_queue()
		queue_changed.emit()
	return removed_count


func claim_next() -> Dictionary:
	_recover_expired_leases()
	var now := int(Time.get_unix_time_from_system())
	for task in tasks:
		if str(task.get("state", "")) == "processing":
			return {}
	var task := _find_next_pending_task(now, false)
	if not task.is_empty():
		task["state"] = "processing"
		task["lease_until"] = now + LEASE_SECONDS
		task["updated_at"] = now
		_save_queue()
		queue_changed.emit()
		return task.duplicate(true)
	return {}


func claim_next_local() -> Dictionary:
	_recover_expired_leases()
	var now := int(Time.get_unix_time_from_system())
	for task in tasks:
		if str(task.get("state", "")) == "processing":
			return {}
	var task := _find_next_pending_task(now, true)
	if not task.is_empty():
		task["state"] = "processing"
		task["lease_until"] = now + LEASE_SECONDS
		task["updated_at"] = now
		_save_queue()
		queue_changed.emit()
		return task.duplicate(true)
	return {}


func _find_next_pending_task(now: int, local_only: bool) -> Dictionary:
	var candidates: Array = []
	for task in tasks:
		if str(task.get("state", "")) != "pending" or int(task.get("next_attempt_at", 0)) > now:
			continue
		var is_local := str(task.get("type", "")) in LOCAL_TASK_TYPES
		if local_only != is_local:
			continue
		candidates.append(task)
	if candidates.is_empty():
		return {}
	candidates.sort_custom(func(a, b):
		var priority_a := int(a.get("priority", _get_task_priority(str(a.get("type", "")))))
		var priority_b := int(b.get("priority", _get_task_priority(str(b.get("type", "")))))
		if priority_a != priority_b:
			return priority_a > priority_b
		return int(a.get("created_at", 0)) < int(b.get("created_at", 0))
	)
	return candidates[0]


func _merge_duplicate_pending_task(task_type: String, payload: Dictionary, memory_domain: String, memory_context: Dictionary, now: int) -> String:
	var dedupe_key := _build_dedupe_key(task_type, payload, memory_domain)
	if dedupe_key.is_empty():
		return ""
	for task in tasks:
		var task_state := str(task.get("state", ""))
		if task_state not in ["pending", "processing"]:
			continue
		if _build_dedupe_key(str(task.get("type", "")), task.get("payload", {}), str(task.get("memory_domain", ""))) != dedupe_key:
			continue
		if task_state == "processing":
			return str(task.get("id", ""))
		task["payload"] = payload.duplicate(true)
		task["memory_context"] = memory_context.duplicate(true)
		task["attempts"] = 0
		task["next_attempt_at"] = now
		task["last_error"] = ""
		task["updated_at"] = now
		task["priority"] = _get_task_priority(task_type)
		return str(task.get("id", ""))
	return ""


func _build_dedupe_key(task_type: String, payload: Dictionary, memory_domain: String) -> String:
	match task_type:
		"memory_edit":
			return "%s|%s|%s|%s" % [task_type, memory_domain, str(payload.get("layer", "")), str(payload.get("memory_id", ""))]
		"conversation_summary":
			return "%s|%s" % [task_type, str(payload.get("channel", ""))]
		"habit_cluster_summary":
			return "%s|%s|%s|%s" % [
				task_type,
				memory_domain,
				str(payload.get("cluster_id", "")),
				str(payload.get("snapshot_hash", ""))
			]
		_:
			return ""


func _ensure_queue_capacity(incoming_priority: int) -> bool:
	if tasks.size() < MAX_QUEUE_SIZE:
		return true
	var removable_index := -1
	var removable_priority := incoming_priority
	for index in range(tasks.size()):
		var task: Dictionary = tasks[index]
		var state := str(task.get("state", ""))
		if state == "failed":
			removable_index = index
			break
		if state != "pending":
			continue
		var priority := int(task.get("priority", _get_task_priority(str(task.get("type", "")))))
		if priority < removable_priority:
			removable_index = index
			removable_priority = priority
	if removable_index < 0:
		return false
	tasks.remove_at(removable_index)
	return true


func _get_task_priority(task_type: String) -> int:
	return int(TASK_PRIORITIES.get(task_type, 10))


func complete(task_id: String) -> bool:
	for index in range(tasks.size()):
		if str(tasks[index].get("id", "")) == task_id:
			tasks.remove_at(index)
			var saved := _save_queue()
			queue_changed.emit()
			return saved
	return false


func fail(task_id: String, error_message: String) -> bool:
	var now := int(Time.get_unix_time_from_system())
	for task in tasks:
		if str(task.get("id", "")) != task_id:
			continue
		var attempts := int(task.get("attempts", 0)) + 1
		task["attempts"] = attempts
		task["last_error"] = error_message
		task["lease_until"] = 0
		task["updated_at"] = now
		if attempts >= MAX_ATTEMPTS:
			task["state"] = "failed"
			task["next_attempt_at"] = 0
		else:
			task["state"] = "pending"
			task["next_attempt_at"] = now + _get_retry_delay(attempts)
		var saved := _save_queue()
		queue_changed.emit()
		return saved
	return false


func get_task(task_id: String) -> Dictionary:
	for task in tasks:
		if str(task.get("id", "")) == task_id:
			return task.duplicate(true)
	return {}


func get_pending_count() -> int:
	var count := 0
	for task in tasks:
		if str(task.get("state", "")) == "pending":
			count += 1
	return count


func get_seconds_until_next_pending() -> int:
	var now := int(Time.get_unix_time_from_system())
	var earliest := -1
	for task in tasks:
		var state := str(task.get("state", ""))
		if state == "processing":
			var lease_until := int(task.get("lease_until", now))
			if earliest < 0 or lease_until < earliest:
				earliest = lease_until
			continue
		if state != "pending":
			continue
		var next_attempt_at := int(task.get("next_attempt_at", now))
		if earliest < 0 or next_attempt_at < earliest:
			earliest = next_attempt_at
	return maxi(0, earliest - now) if earliest >= 0 else -1


func resolve_memory_manager(memory_domain: String):
	match memory_domain:
		MemoryManager.MEMORY_DOMAIN_DESKTOP_PET:
			return GameDataManager.desktop_pet_memory_manager
		MemoryManager.MEMORY_DOMAIN_STORY:
			return GameDataManager.story_memory_manager
		_:
			return GameDataManager.memory_manager


func _recover_expired_leases() -> void:
	var now := int(Time.get_unix_time_from_system())
	for task in tasks:
		if str(task.get("state", "")) == "processing" and int(task.get("lease_until", 0)) <= now:
			task["state"] = "pending"
			task["lease_until"] = 0
			task["next_attempt_at"] = now
			task["updated_at"] = now


func _get_retry_delay(attempts: int) -> int:
	return mini(BASE_RETRY_SECONDS * int(pow(2, maxi(0, attempts - 1))), MAX_RETRY_SECONDS)


func _is_valid_task(task: Dictionary) -> bool:
	return not str(task.get("id", "")).is_empty() \
		and not str(task.get("type", "")).is_empty() \
		and task.get("payload", null) is Dictionary \
		and str(task.get("state", "")) in ["pending", "processing", "failed"]


func _save_queue() -> bool:
	return SafeFileAccessUtil.store_string(get_save_path(), JSON.stringify({
		"schema_version": SCHEMA_VERSION,
		"tasks": tasks
	}, "\t"))


func _generate_id() -> String:
	return "%d-%d" % [Time.get_ticks_usec(), randi()]