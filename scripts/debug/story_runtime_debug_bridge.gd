extends Node

signal event_recorded(event: Dictionary)

const MESSAGE_NAME := "galchat_story:event"
const SCHEMA_VERSION := 1

@export var enabled := OS.is_debug_build()
@export var capacity := 512
@export var capture_event_payload := false

var sequence := 0
var events: Array[Dictionary] = []
var pending_source: Dictionary = {}
var active_source: Dictionary = {"type": "direct", "id": "", "context": {}}
var active_trace_id := ""


func prepare_story(source_type: String, source_id: String, script_path: String, context: Dictionary = {}) -> void:
	pending_source = {
		"type": source_type,
		"id": source_id,
		"script_path": script_path,
		"context": context.duplicate(true)
	}
	record("story.trigger.selected", "info", {"script_path": script_path}, {}, {}, pending_source)


func begin_story(script_id: String, script_path: String, runtime_generated: bool = false) -> Dictionary:
	active_source = pending_source.duplicate(true) if not pending_source.is_empty() else {"type": "direct", "id": script_id, "context": {}}
	pending_source.clear()
	active_trace_id = "%d-%d" % [Time.get_ticks_usec(), sequence + 1]
	return record("story.started", "info", {
		"script_id": script_id,
		"script_path": script_path,
		"runtime_generated": runtime_generated
	})


func record(event_name: String, severity: String = "info", story: Dictionary = {}, cursor: Dictionary = {}, data: Dictionary = {}, source_override: Dictionary = {}) -> Dictionary:
	if not enabled:
		return {}
	sequence += 1
	var safe_data := data.duplicate(true)
	if not capture_event_payload and safe_data.has("event"):
		safe_data.erase("event")
	var event := {
		"schema_version": SCHEMA_VERSION,
		"sequence": sequence,
		"timestamp_msec": int(Time.get_unix_time_from_system() * 1000.0),
		"monotonic_usec": Time.get_ticks_usec(),
		"trace_id": active_trace_id,
		"event": event_name,
		"severity": severity,
		"source": (source_override if not source_override.is_empty() else active_source).duplicate(true),
		"story": story.duplicate(true),
		"cursor": cursor.duplicate(true),
		"data": safe_data
	}
	events.append(event)
	while events.size() > max(1, capacity):
		events.pop_front()
	event_recorded.emit(event.duplicate(true))
	if EngineDebugger.is_active():
		EngineDebugger.send_message(MESSAGE_NAME, [event])
	return event


func record_error(event_name: String, code: String, message: String, story: Dictionary = {}, cursor: Dictionary = {}, details: Dictionary = {}) -> Dictionary:
	return record(event_name, "error", story, cursor, {
		"error": {"code": code, "message": message, "details": details.duplicate(true)}
	})


func snapshot() -> Array[Dictionary]:
	return events.duplicate(true)


func clear() -> void:
	events.clear()
	pending_source.clear()
	active_source = {"type": "direct", "id": "", "context": {}}
	active_trace_id = ""
