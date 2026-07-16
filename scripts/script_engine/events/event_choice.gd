extends "res://scripts/script_engine/script_event.gd"

var options: Array

func _init(data: Dictionary) -> void:
    super(data)
    options = data.get("options", []).duplicate(true)

func process_event(manager: Node) -> bool:
    manager.emit_signal("on_choice_requested", options)
    return true