extends "res://scripts/script_engine/script_event.gd"

var speaker: String
var content: String
var mood: String
var presentation: Dictionary

func _init(data: Dictionary) -> void:
    super(data)
    speaker = data.get("speaker", "")
    content = data.get("content", "")
    mood = data.get("mood", "")
    presentation = {
        "character": data.get("character", ""),
        "enter": bool(data.get("enter", false)),
        "exit": bool(data.get("exit", false)),
        "position": data.get("position", ""),
        "expression": data.get("expression", ""),
        "focus": data.get("focus", null),
        "animation": data.get("animation", ""),
        "exit_animation": data.get("exit_animation", ""),
        "display_name": data.get("display_name", "")
    }

func process_event(manager: Node) -> bool:
    print("[ScriptEngine] Dialogue: ", speaker, " -> ", content)
    # 调用 manager 里的委托方法显示对话UI
    manager.emit_signal("on_dialogue_requested", speaker, content, mood, presentation)
    return true # 阻塞，等待玩家点击继续
