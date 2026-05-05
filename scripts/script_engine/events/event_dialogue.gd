extends "res://scripts/script_engine/script_event.gd"

var speaker: String
var content: String
var mood: String

func _init(data: Dictionary) -> void:
    super(data)
    speaker = data.get("speaker", "")
    content = data.get("content", "")
    mood = data.get("mood", "")

func process_event(manager: Node) -> bool:
    print("[ScriptEngine] Dialogue: ", speaker, " -> ", content)
    # 调用 manager 里的委托方法显示对话UI
    manager.emit_signal("on_dialogue_requested", speaker, content, mood)
    return true # 阻塞，等待玩家点击继续
