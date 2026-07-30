extends Node

var revision: int = 0
var effects: Dictionary = {}


func recover_from_history(history_messages: Array) -> Dictionary:
	reset()
	for message in history_messages:
		if not message is Dictionary:
			continue
		var snapshot: Variant = message.get("scene_state_snapshot")
		if snapshot is Dictionary and int(snapshot.get("revision", -1)) >= revision:
			revision = int(snapshot.get("revision", 0))
			effects = snapshot.get("effects", {}).duplicate(true) if snapshot.get("effects", {}) is Dictionary else {}
	return get_snapshot()


func apply_realized_turn(realized_turn: Dictionary) -> Dictionary:
	var segments: Variant = realized_turn.get("segments")
	if not segments is Array:
		return {"changed": false, "snapshot": get_snapshot(), "accepted_effects": []}
	var accepted_effects: Array[Dictionary] = []
	var changed := false
	for segment in segments:
		if not segment is Dictionary or not segment.get("action") is Dictionary:
			continue
		var effect: Variant = segment["action"].get("persistent_effect")
		if not effect is Dictionary:
			continue
		var event_type := str(effect.get("event_type", ""))
		var normalized := {
			"event_type": event_type,
			"target_id": "character",
			"status": "completed",
			"description": str(effect.get("description", "")).strip_edges()
		}
		accepted_effects.append(normalized)
		if effects.get(event_type, {}) != normalized:
			effects[event_type] = normalized
			changed = true
	if changed:
		revision += 1
	return {"changed": changed, "snapshot": get_snapshot(), "accepted_effects": accepted_effects}


func get_snapshot() -> Dictionary:
	return {"revision": revision, "effects": effects.duplicate(true)}


func build_prompt_block() -> String:
	return "【scene_state；仅含已接受且仍成立的现场事实】\n" + JSON.stringify(get_snapshot())


func reset() -> void:
	revision = 0
	effects.clear()