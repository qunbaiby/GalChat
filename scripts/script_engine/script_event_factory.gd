class_name ScriptEventFactory
extends RefCounted

static func create_event(data: Dictionary): # 返回 ScriptEvent
    var type = data.get("type", "")
    match type:
        "dialogue":
            return preload("res://scripts/script_engine/events/event_dialogue.gd").new(data)
        "bgm":
            return preload("res://scripts/script_engine/events/event_bgm.gd").new(data)
        "jump":
            return preload("res://scripts/script_engine/events/event_jump.gd").new(data)
        "set_variable":
            return preload("res://scripts/script_engine/events/event_set_variable.gd").new(data)
        "ai_chat":
            return preload("res://scripts/script_engine/events/event_ai_chat.gd").new(data)
        "background":
            return preload("res://scripts/script_engine/events/event_background.gd").new(data)
        _:
            push_warning("Unknown script event type: " + type)
            return preload("res://scripts/script_engine/script_event.gd").new(data) # Fallback to base
