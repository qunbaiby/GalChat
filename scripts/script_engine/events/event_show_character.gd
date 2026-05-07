extends "res://scripts/script_engine/script_event.gd"

var animation: String

func _init(data: Dictionary) -> void:
    super(data)
    animation = data.get("animation", "fade_in")

func process_event(manager: Node) -> bool:
    print("[ScriptEngine] Show Character: ", animation)
    manager.emit_signal("on_character_show_requested", animation)
    return false # 不阻塞，允许同时播放对话
