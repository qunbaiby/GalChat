@tool
extends RefCounted

signal runtime_event_received(session_id: int, event: Dictionary)
signal runtime_session_changed(session_id: int, active: bool)

const CAPACITY := 512

var session_events := {}
var active_sessions := {}


func start_session(session_id: int) -> void:
	active_sessions[session_id] = true
	if not session_events.has(session_id):
		session_events[session_id] = []
	runtime_session_changed.emit(session_id, true)


func stop_session(session_id: int) -> void:
	active_sessions[session_id] = false
	runtime_session_changed.emit(session_id, false)


func add_event(session_id: int, event: Dictionary) -> void:
	var events: Array = session_events.get(session_id, [])
	events.append(event.duplicate(true))
	while events.size() > CAPACITY:
		events.pop_front()
	session_events[session_id] = events
	runtime_event_received.emit(session_id, event.duplicate(true))


func get_session_ids() -> Array[int]:
	var ids: Array[int] = []
	for session_id in session_events.keys():
		ids.append(int(session_id))
	ids.sort()
	return ids


func get_events(session_id: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	result.assign((session_events.get(session_id, []) as Array).duplicate(true))
	return result


func clear_session(session_id: int) -> void:
	session_events[session_id] = []


func is_session_active(session_id: int) -> bool:
	return bool(active_sessions.get(session_id, false))


func snapshot_sessions() -> Dictionary:
	var result := {}
	for session_id in session_events:
		result[int(session_id)] = {
			"active": bool(active_sessions.get(session_id, false)),
			"events": (session_events[session_id] as Array).duplicate(true)
		}
	return result