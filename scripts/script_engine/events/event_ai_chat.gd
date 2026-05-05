extends "res://scripts/script_engine/script_event.gd"

var prompt_override: String

func _init(data: Dictionary) -> void:
    super(data)
    prompt_override = data.get("prompt_override", "")

func process_event(manager: Node) -> bool:
    print("[ScriptEngine] Enter AI Free Chat Mode")
    manager.emit_signal("on_ai_chat_requested", prompt_override)
    return true # 阻塞，直到退出 AI 聊天状态
