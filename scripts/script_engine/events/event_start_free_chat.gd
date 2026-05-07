extends "res://scripts/script_engine/script_event.gd"

var strategy: String
var max_rounds: int

func _init(data: Dictionary) -> void:
    super(data)
    strategy = data.get("strategy", "")
    max_rounds = data.get("max_rounds", 0)

func process_event(manager: Node) -> bool:
    print("[ScriptEngine] Start Free Chat Mode: ", strategy)
    manager.emit_signal("on_start_free_chat_requested", strategy, max_rounds)
    return true # 阻塞，通常这是脚本最后一步，进入自由对话后不再继续脚本
