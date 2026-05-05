class_name ScriptChapter
extends RefCounted

var chapter_id: String
var events: Array = [] # Array[ScriptEvent]

func _init(c_id: String, chapter_data: Dictionary) -> void:
    chapter_id = c_id
    if chapter_data.has("events"):
        for e_data in chapter_data["events"]:
            var ev = preload("res://scripts/script_engine/script_event_factory.gd").create_event(e_data)
            if ev != null:
                events.append(ev)
