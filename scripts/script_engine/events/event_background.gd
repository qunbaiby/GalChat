extends "res://scripts/script_engine/script_event.gd"

var bg_path: String
var fade_time: float

func _init(data: Dictionary) -> void:
    super(data)
    bg_path = data.get("bg_path", "")
    fade_time = data.get("fade_time", 0.5)

func process_event(manager: Node) -> bool:
    print("[ScriptEngine] Change Background: ", bg_path)
    manager.emit_signal("on_background_requested", bg_path, fade_time)
    return false
