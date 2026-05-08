class_name ScriptEventFactory
extends RefCounted

static func create_event(data: Dictionary): # 返回 ScriptEvent
    var type = data.get("type", "")
    match type:
        "dialogue":
            return preload("res://scripts/script_engine/events/event_dialogue.gd").new(data)
        "bgm":
            return preload("res://scripts/script_engine/events/event_bgm.gd").new(data)
        "audio":
            return preload("res://scripts/script_engine/events/event_audio.gd").new(data)
        "jump":
            return preload("res://scripts/script_engine/events/event_jump.gd").new(data)
        "set_variable":
            return preload("res://scripts/script_engine/events/event_set_variable.gd").new(data)
        "ai_chat":
            return preload("res://scripts/script_engine/events/event_ai_chat.gd").new(data)
        "background":
            return preload("res://scripts/script_engine/events/event_background.gd").new(data)
        "show_character":
            return preload("res://scripts/script_engine/events/event_show_character.gd").new(data)
        "hide_character":
            return preload("res://scripts/script_engine/events/event_hide_character.gd").new(data)
        "voice_call":
            return preload("res://scripts/script_engine/events/event_voice_call.gd").new(data)
        "show_player_info_popup":
            return preload("res://scripts/script_engine/events/event_show_player_info.gd").new(data)
        "start_free_chat":
            return preload("res://scripts/script_engine/events/event_start_free_chat.gd").new(data)
        _:
            push_warning("Unknown script event type: " + type)
            return preload("res://scripts/script_engine/script_event.gd").new(data) # Fallback to base
