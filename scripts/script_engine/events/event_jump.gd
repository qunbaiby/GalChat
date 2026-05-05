extends "res://scripts/script_engine/script_event.gd"

var target_chapter: String

func _init(data: Dictionary) -> void:
    super(data)
    target_chapter = data.get("target_chapter", "")

func process_event(manager: Node) -> bool:
    print("[ScriptEngine] Jump to chapter: ", target_chapter)
    manager.jump_to_chapter(target_chapter)
    return false
