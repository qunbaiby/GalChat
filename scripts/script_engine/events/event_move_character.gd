extends "res://scripts/script_engine/script_event.gd"

var animation: String
var presentation: Dictionary

func _init(data: Dictionary) -> void:
    super(data)
    animation = data.get("animation", "move")
    presentation = {
        "character": data.get("character", ""),
        "position": data.get("position", ""),
        "expression": data.get("expression", ""),
        "focus": data.get("focus", null),
        "display_name": data.get("display_name", "")
    }

func process_event(manager: Node) -> bool:
    print("[ScriptEngine] Move Character: ", animation)
    manager.emit_signal("on_character_move_requested", animation, presentation)
    return false
