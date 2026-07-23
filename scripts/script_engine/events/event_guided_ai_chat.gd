extends "res://scripts/script_engine/script_event.gd"

var policy: Dictionary

func _init(data: Dictionary) -> void:
	super(data)
	policy = data.duplicate(true)

func process_event(manager: Node) -> bool:
	manager.emit_signal("on_guided_ai_chat_requested", policy)
	return true