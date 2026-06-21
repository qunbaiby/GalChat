extends "res://scripts/script_engine/script_event.gd"

var audio_id: String
var audio_path: String
var action: String
var fade_time: float
var loop: bool

func _init(data: Dictionary) -> void:
    super(data)
    audio_id = str(data.get("audio_id", "")).strip_edges()
    audio_path = data.get("audio_path", "")
    action = str(data.get("action", "play")).strip_edges().to_lower()
    fade_time = data.get("fade_time", 1.0)
    loop = bool(data.get("loop", false))

func process_event(manager: Node) -> bool:
    if action == "stop":
        manager.emit_signal("on_audio_requested", "bgm", action, "", fade_time, false)
        return false

    if audio_id != "" or action == "switch":
        manager.emit_signal("on_audio_requested", "bgm", action, audio_id, fade_time, loop)
        return false

    print("[ScriptEngine] Play BGM: ", audio_path)
    manager.emit_signal("on_bgm_requested", audio_path, fade_time)
    return false # 不阻塞
