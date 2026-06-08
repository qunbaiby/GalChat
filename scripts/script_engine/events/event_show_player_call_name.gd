extends "res://scripts/script_engine/script_event.gd"

func _init(data: Dictionary) -> void:
    super(data)

func process_event(manager: Node) -> bool:
    print("[ScriptEngine] Show Player Call Name Popup")
    manager.emit_signal("on_player_call_name_requested")
    return true
