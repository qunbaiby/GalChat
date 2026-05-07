extends "res://scripts/script_engine/script_event.gd"

var animation: String

func _init(data: Dictionary) -> void:
    super(data)
    animation = data.get("animation", "fade_out")

func process_event(manager: Node) -> bool:
    print("[ScriptEngine] Hide Character: ", animation)
    manager.emit_signal("on_character_hide_requested", animation)
    return false # 不阻塞
