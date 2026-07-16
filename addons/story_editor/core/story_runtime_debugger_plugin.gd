@tool
extends EditorDebuggerPlugin

const CAPTURE_NAME := "galchat_story"
const DebugStore = preload("res://addons/story_editor/core/story_runtime_debug_store.gd")

var store := DebugStore.new()


func _has_capture(capture: String) -> bool:
	return capture == CAPTURE_NAME


func _capture(message: String, data: Array, session_id: int) -> bool:
	if message != "galchat_story:event" or data.is_empty() or not data[0] is Dictionary:
		return false
	store.add_event(session_id, data[0] as Dictionary)
	return true


func _setup_session(session_id: int) -> void:
	store.start_session(session_id)


func _stop_session(session_id: int) -> void:
	store.stop_session(session_id)