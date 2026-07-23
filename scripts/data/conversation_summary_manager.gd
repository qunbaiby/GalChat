class_name ConversationSummaryManager
extends Node

const SafeFileAccessUtil = preload("res://scripts/utils/safe_file_access.gd")
const SAVE_FILE_NAME := "conversation_summaries.json"
const SCHEMA_VERSION := 1
const SUMMARY_TRIGGER_COUNT := 20
const SUMMARY_BATCH_LIMIT := 40
const RECENT_MESSAGES_TO_KEEP := 10
const SUMMARY_MAX_CHARS := 1800
const SUPPORTED_CHANNELS := ["main_chat", "story_chat", "desktop_pet"]

var summaries: Dictionary = {}
var save_path_override: String = ""


func get_save_path() -> String:
	if not save_path_override.is_empty():
		return save_path_override
	var character_id := "default"
	if GameDataManager.config and not str(GameDataManager.config.current_character_id).is_empty():
		character_id = str(GameDataManager.config.current_character_id)
	return GameDataManager.get_character_save_path(SAVE_FILE_NAME, character_id)


func load_summaries() -> void:
	summaries.clear()
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
	var loaded: Variant = parsed.get("summaries", {})
	if loaded is Dictionary:
		for channel in loaded.keys():
			if str(channel) in SUPPORTED_CHANNELS and loaded[channel] is Dictionary:
				summaries[channel] = _normalize_summary_state(loaded[channel])
	_reconcile_pending_tasks()


func on_history_message_added(channel: String) -> void:
	if channel == "fixed_story":
		channel = "story_chat"
	if not channel in SUPPORTED_CHANNELS:
		return
	queue_summary_if_needed(channel)


func clear_all() -> void:
	for state in summaries.values():
		if state is Dictionary:
			var task_id := str(state.get("pending_task_id", ""))
			if not task_id.is_empty() and GameDataManager.cognition_task_queue:
				GameDataManager.cognition_task_queue.complete(task_id)
	summaries.clear()
	_save_summaries()


func queue_summary_if_needed(channel: String) -> String:
	if not channel in SUPPORTED_CHANNELS or GameDataManager.history == null or GameDataManager.cognition_task_queue == null:
		return ""
	var state := get_summary_state(channel)
	if not str(state.get("pending_task_id", "")).is_empty():
		return ""
	var messages: Array = GameDataManager.history.get_messages_by_type(channel)
	var summarized_count := mini(int(state.get("summarized_message_count", 0)), messages.size())
	var unsummarized_count := messages.size() - summarized_count
	if unsummarized_count < SUMMARY_TRIGGER_COUNT:
		return ""
	var end_index := mini(messages.size() - RECENT_MESSAGES_TO_KEEP, summarized_count + SUMMARY_BATCH_LIMIT)
	if end_index <= summarized_count:
		return ""
	var batch: Array = messages.slice(summarized_count, end_index)
	var task_id: String = GameDataManager.cognition_task_queue.enqueue("conversation_summary", {
		"channel": channel,
		"previous_summary": str(state.get("summary", "")),
		"messages": _serialize_messages(batch),
		"covered_message_count": end_index
	}, MemoryManager.MEMORY_DOMAIN_PLAYER)
	state["pending_task_id"] = task_id
	summaries[channel] = state
	_save_summaries()
	return task_id


func apply_summary(channel: String, summary: String, covered_message_count: int, task_id: String) -> bool:
	if not channel in SUPPORTED_CHANNELS:
		return false
	var state := get_summary_state(channel)
	if str(state.get("pending_task_id", "")) != task_id:
		return false
	state["summary"] = _truncate_summary(summary.strip_edges())
	state["summarized_message_count"] = maxi(int(state.get("summarized_message_count", 0)), covered_message_count)
	state["pending_task_id"] = ""
	state["updated_at"] = Time.get_datetime_string_from_system()
	summaries[channel] = state
	return _save_summaries()


func rebuild_summary(channel: String) -> String:
	if not channel in SUPPORTED_CHANNELS:
		return ""
	var state := get_summary_state(channel)
	var pending_task_id := str(state.get("pending_task_id", ""))
	if not pending_task_id.is_empty() and GameDataManager.cognition_task_queue:
		GameDataManager.cognition_task_queue.complete(pending_task_id)
	summaries[channel] = _normalize_summary_state({})
	_save_summaries()
	return queue_summary_if_needed(channel)


func release_pending_task(channel: String, task_id: String) -> void:
	var state := get_summary_state(channel)
	if str(state.get("pending_task_id", "")) != task_id:
		return
	state["pending_task_id"] = ""
	summaries[channel] = state
	_save_summaries()


func get_summary(channel: String) -> String:
	return str(get_summary_state(channel).get("summary", "")).strip_edges()


func get_summary_state(channel: String) -> Dictionary:
	if summaries.has(channel) and summaries[channel] is Dictionary:
		return _normalize_summary_state(summaries[channel])
	return _normalize_summary_state({})


func get_prompt_block(channel: String) -> String:
	var summary := get_summary(channel)
	if summary.is_empty():
		return ""
	return "【较早对话滚动摘要】\n" + summary


func get_completed_summary_count() -> int:
	var count := 0
	for channel in summaries.keys():
		if not str(summaries[channel].get("summary", "")).strip_edges().is_empty():
			count += 1
	return count


func _reconcile_pending_tasks() -> void:
	if GameDataManager.cognition_task_queue == null:
		return
	var changed := false
	for channel in summaries.keys():
		var state: Dictionary = summaries[channel]
		var task_id := str(state.get("pending_task_id", ""))
		if task_id.is_empty():
			continue
		var task: Dictionary = GameDataManager.cognition_task_queue.get_task(task_id)
		if task.is_empty() or str(task.get("state", "")) == "failed":
			state["pending_task_id"] = ""
			summaries[channel] = state
			changed = true
	if changed:
		_save_summaries()


func _serialize_messages(messages: Array) -> Array:
	var result: Array = []
	for message in messages:
		if not message is Dictionary:
			continue
		result.append({
			"speaker": str(message.get("speaker", "")),
			"text": str(message.get("text", "")),
			"time": str(message.get("time", ""))
		})
	return result


func _normalize_summary_state(state: Dictionary) -> Dictionary:
	return {
		"summary": str(state.get("summary", "")),
		"summarized_message_count": maxi(0, int(state.get("summarized_message_count", 0))),
		"pending_task_id": str(state.get("pending_task_id", "")),
		"updated_at": str(state.get("updated_at", ""))
	}


func _truncate_summary(summary: String) -> String:
	if summary.length() <= SUMMARY_MAX_CHARS:
		return summary
	return summary.left(SUMMARY_MAX_CHARS - 1).strip_edges() + "…"


func _save_summaries() -> bool:
	return SafeFileAccessUtil.store_string(get_save_path(), JSON.stringify({
		"schema_version": SCHEMA_VERSION,
		"summaries": summaries
	}, "\t"))