extends "res://scripts/script_engine/script_event.gd"

var audio_id: String
var audio_type: String # "bgm", "bgs", "se"
var action: String # "play", "stop", "switch"
var fade_time: float
var loop: bool

func _init(data: Dictionary) -> void:
	super(data)
	audio_id = data.get("audio_id", "")
	audio_type = data.get("audio_type", "se")
	action = data.get("action", "play")
	fade_time = data.get("fade_time", 0.0)
	loop = data.get("loop", false)

func process_event(manager: Node) -> bool:
	manager.emit_signal("on_audio_requested", audio_type, action, audio_id, fade_time, loop)
	return false # 不阻塞
