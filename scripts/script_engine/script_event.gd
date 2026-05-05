class_name ScriptEvent
extends RefCounted

var type: String
var raw_data: Dictionary

func _init(data: Dictionary) -> void:
    raw_data = data
    type = data.get("type", "unknown")

# 返回是否阻断（比如等待玩家点击或等待播放完成）
# 如果返回 true，ScriptManager 会暂停推进，直到接收到 resume 信号
func process_event(manager: Node) -> bool:
    return false
