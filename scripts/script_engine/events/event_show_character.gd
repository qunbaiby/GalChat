extends "res://scripts/script_engine/script_event.gd"

var animation: String
var presentation: Dictionary

func _init(data: Dictionary) -> void:
    super(data)
    animation = data.get("animation", "fade_in")
    presentation = {
        "character": data.get("character", ""),
        "position": data.get("position", ""),
        "expression": data.get("expression", ""),
        "focus": data.get("focus", null),
        "display_name": data.get("display_name", "")
    }

func process_event(manager: Node) -> bool:
    print("[ScriptEngine] Show Character: ", animation)
    manager.emit_signal("on_character_show_requested", animation, presentation)
    return false # 不阻塞，允许同时播放对话
