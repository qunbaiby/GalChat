extends "res://scripts/script_engine/script_event.gd"

func _init(data: Dictionary) -> void:
    super(data)

func process_event(manager: Node) -> bool:
    print("[ScriptEngine] Show Player Info Popup")
    manager.emit_signal("on_player_info_requested")
    return true # 阻塞，等待玩家提交档案
