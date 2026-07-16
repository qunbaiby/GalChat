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
        "expression": data.get("expression", ""),
		"voice_instruction": data.get("voice_instruction", ""),
        "focus": data.get("focus", null),
        "display_name": data.get("display_name", "")
    }

func process_event(manager: Node) -> bool:
    print("[ScriptEngine] Dialogue: ", speaker, " -> ", content)
    # 调用 manager 里的委托方法显示对话UI
    manager.emit_signal("on_dialogue_requested", speaker, content, mood, presentation)
    return true # 阻塞，等待玩家点击继续
