extends "res://scripts/script_engine/script_event.gd"

var call_id: String

func _init(data: Dictionary) -> void:
    super(data)
    call_id = data.get("call_id", "")

func process_event(manager: Node) -> bool:
    print("[ScriptEngine] Voice Call: ", call_id)
    manager.emit_signal("on_voice_call_requested", call_id)
    return true # 阻塞，等待语音通话结束
