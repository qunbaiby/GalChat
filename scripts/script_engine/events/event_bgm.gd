extends "res://scripts/script_engine/script_event.gd"

var audio_path: String
var fade_time: float

func _init(data: Dictionary) -> void:
    super(data)
    audio_path = data.get("audio_path", "")
    fade_time = data.get("fade_time", 1.0)

func process_event(manager: Node) -> bool:
    print("[ScriptEngine] Play BGM: ", audio_path)
    manager.emit_signal("on_bgm_requested", audio_path, fade_time)
    return false # 不阻塞
