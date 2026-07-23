class_name ScriptEngineManager
extends Node

signal on_dialogue_requested(speaker: String, content: String, mood: String, presentation: Dictionary)
signal on_choice_requested(options: Array)
signal on_bgm_requested(audio_path: String, fade_time: float)
signal on_background_requested(bg_path: String, duration: float, transition_type: String)
signal on_period_card_requested(period_label: String, location_name: String, bg_path: String, hold_duration: float)
signal on_audio_requested(audio_type: String, action: String, audio_id: String, fade_time: float, loop: bool)
signal on_variable_set(var_name: String, var_value: Variant)
signal on_ai_chat_requested(prompt_override: String)
signal on_guided_ai_chat_requested(policy: Dictionary)
signal on_character_show_requested(animation: String, presentation: Dictionary)
signal on_character_move_requested(animation: String, presentation: Dictionary)
signal on_character_hide_requested(animation: String, presentation: Dictionary)
signal on_player_call_name_requested()
signal on_voice_call_requested(call_id: String)
signal on_start_free_chat_requested(strategy: String, max_rounds: int)
signal script_finished(script_id: String)
signal checkpoint_changed(state: Dictionary)

var current_script_id: String = ""
var current_script_path: String = ""
var current_script_data: Dictionary = {}
var current_script_meta: Dictionary = {}
var chapters: Dictionary = {} # chapter_id -> ScriptChapter
var current_chapter_id: String = ""
var current_event_index: int = 0
var is_running: bool = false
var is_waiting_for_resume: bool = false

func load_script(script_path: String) -> bool:
    _debug_record("story.load.started", "info", {"script_path": script_path})
    if not FileAccess.file_exists(script_path):
        printerr("[ScriptEngine] Script file not found: ", script_path)
        _debug_error("story.load.failed", "file_not_found", "Script file not found.", {"script_path": script_path})
        return false
        
    var file = FileAccess.open(script_path, FileAccess.READ)
    var content = file.get_as_text()
    file.close()
    
    var json = JSON.new()
    var err = json.parse(content)
    if err != OK:
        printerr("[ScriptEngine] Failed to parse script JSON: ", json.get_error_message())
        _debug_error("story.load.failed", "json_parse_failed", json.get_error_message(), {"script_path": script_path})
        return false
    return load_script_data(json.data, script_path)

func load_script_data(data: Variant, source_path: String = "") -> bool:
    if not data is Dictionary:
        printerr("[ScriptEngine] Invalid runtime script data.")
        _debug_error("story.load.failed", "invalid_root", "Runtime script root must be a Dictionary.", {"script_path": source_path})
        return false

    var script_data: Dictionary = data
    current_script_data = script_data.duplicate(true)
    current_script_id = script_data.get("script_id", "unknown")
    current_script_path = source_path
    current_script_meta = {
        "use_portraits": bool(script_data.get("use_portraits", true)),
        "summary": str(script_data.get("summary", "")),
        "story_location_id": str(script_data.get("story_location_id", "")),
        "story_area_id": str(script_data.get("story_area_id", "")),
        "day_offset": int(script_data.get("day_offset", 0)),
        "story_period": str(script_data.get("story_period", "")),
        "runtime_generated": bool(script_data.get("runtime_generated", false)),
        "story_category": str(script_data.get("story_category", "")),
        "location_names": script_data.get("location_names", []),
        "date_plan": script_data.get("date_plan", []),
        "date_settlement": script_data.get("date_settlement", {}),
        "memory_enabled": bool(script_data.get("memory_enabled", true)),
        "memory_layer": str(script_data.get("memory_layer", "bond")),
        "memory_summary": str(script_data.get("memory_summary", "")),
        "memory_is_bond_mark": bool(script_data.get("memory_is_bond_mark", true)),
        "memory_title": str(script_data.get("memory_title", "")),
        "memory_scope": str(script_data.get("memory_scope", "")),
        "memory_scope_explicit": bool(script_data.has("memory_scope")),
        "memory_visibility": str(script_data.get("memory_visibility", "")),
        "memory_visibility_explicit": bool(script_data.has("memory_visibility")),
        "memory_participants": script_data.get("memory_participants", []),
        "memory_participants_explicit": bool(script_data.has("memory_participants")),
        "memory_player_involved": bool(script_data.get("memory_player_involved", false)),
        "memory_player_involved_explicit": bool(script_data.has("memory_player_involved")),
        "memory_player_witnessed": bool(script_data.get("memory_player_witnessed", false)),
        "memory_player_witnessed_explicit": bool(script_data.has("memory_player_witnessed")),
        "memory_records": _sanitize_memory_records(script_data.get("memory_records", []))
    }
    var chapters_data = script_data.get("chapters", {})

    chapters.clear()
    for c_id in chapters_data.keys():
        chapters[c_id] = ScriptChapter.new(c_id, chapters_data[c_id])

    print("[ScriptEngine] Loaded script: ", current_script_id, " with ", chapters.size(), " chapters.")
    _debug_record("story.load.succeeded")
    return true

func start_script(start_chapter_id: String = "start") -> void:
    if not chapters.has(start_chapter_id):
        printerr("[ScriptEngine] Start chapter not found: ", start_chapter_id)
        _debug_error("story.start.failed", "missing_start_chapter", "Start chapter not found: %s" % start_chapter_id)
        return
        
    is_running = true
    is_waiting_for_resume = false
    current_chapter_id = start_chapter_id
    current_event_index = 0
    var bridge := _debug_bridge()
    if bridge != null:
        bridge.begin_story(current_script_id, current_script_path, bool(current_script_meta.get("runtime_generated", false)))
    _debug_record("story.chapter.entered")
    _process_next_event()

func restore_checkpoint(state: Dictionary) -> bool:
    var chapter_id := str(state.get("chapter_id", "")).strip_edges()
    var event_index := int(state.get("event_index", -1))
    if str(state.get("script_id", "")) != current_script_id:
        return false
    if not chapters.has(chapter_id):
        return false
    var chapter: ScriptChapter = chapters[chapter_id]
    if event_index < 0 or event_index >= chapter.events.size():
        return false
    is_running = true
    is_waiting_for_resume = false
    current_chapter_id = chapter_id
    current_event_index = event_index
    _debug_record("story.checkpoint.restored")
    _process_next_event()
    return true

func get_checkpoint() -> Dictionary:
    if not is_running or not is_waiting_for_resume:
        return {}
    var state := {
        "script_id": current_script_id,
        "script_path": current_script_path,
        "chapter_id": current_chapter_id,
        "event_index": current_event_index
    }
    if current_script_path.is_empty():
        state["script_data"] = current_script_data.duplicate(true)
    return state

func jump_to_chapter(target_chapter_id: String) -> void:
    _debug_record("story.jump.requested", "info", {}, {"target_chapter": target_chapter_id})
    if target_chapter_id == "end" or not chapters.has(target_chapter_id):
        if target_chapter_id != "end":
            _debug_record("story.warning", "warning", {}, {"code": "missing_jump_target", "target_chapter": target_chapter_id})
        _end_script()
        return
        
    current_chapter_id = target_chapter_id
    current_event_index = 0
    _debug_record("story.chapter.entered")

func resume() -> void:
    if not is_running or not is_waiting_for_resume:
        return
    is_waiting_for_resume = false
    _debug_record("story.resumed")
    current_event_index += 1
    _process_next_event()

func _process_next_event() -> void:
    if not is_running or is_waiting_for_resume:
        return
        
    var current_chapter: ScriptChapter = chapters[current_chapter_id]
    
    # 循环处理非阻塞事件，直到遇到阻塞事件或章节结束
    while current_event_index < current_chapter.events.size():
        var processed_chapter_id := current_chapter_id
        var ev = current_chapter.events[current_event_index]
        _debug_record("story.event.started", "info", {"event_type": str(ev.type)}, {"event": ev.raw_data})
        var is_blocking = ev.process_event(self)
        
        if is_blocking:
            is_waiting_for_resume = true
            _debug_record("story.event.blocked", "info", {"event_type": str(ev.type)})
            checkpoint_changed.emit(get_checkpoint())
            return # 退出循环，等待外部调用 resume()

        if not is_running:
            return

        if current_chapter_id != processed_chapter_id:
            current_chapter = chapters[current_chapter_id]
            continue
            
        current_event_index += 1
        
    # 当前章节事件执行完毕，如果没有 jump，默认结束
    _end_script()

func _end_script() -> void:
    print("[ScriptEngine] Script finished: ", current_script_id)
    _debug_record("story.engine.finished")
    is_running = false
    is_waiting_for_resume = false
    script_finished.emit(current_script_id)

func use_story_portraits() -> bool:
    return bool(current_script_meta.get("use_portraits", true))

func get_current_script_meta() -> Dictionary:
    return current_script_meta.duplicate(true)

func _sanitize_memory_records(raw_records: Variant) -> Array:
    var results: Array = []
    if not raw_records is Array:
        return results
    for item in raw_records:
        if item is Dictionary:
            results.append(item.duplicate(true))
    return results

func _debug_bridge() -> Node:
    return get_node_or_null("/root/StoryRuntimeDebugBridge")

func _debug_story() -> Dictionary:
    return {
        "script_id": current_script_id,
        "script_path": current_script_path,
        "runtime_generated": bool(current_script_meta.get("runtime_generated", false))
    }

func _debug_cursor(extra: Dictionary = {}) -> Dictionary:
    var cursor := {
        "chapter_id": current_chapter_id,
        "event_index": current_event_index,
        "running": is_running,
        "waiting": is_waiting_for_resume
    }
    cursor.merge(extra, true)
    return cursor

func _debug_record(event_name: String, severity: String = "info", story_extra: Dictionary = {}, data: Dictionary = {}) -> void:
    var bridge := _debug_bridge()
    if bridge == null or not bool(bridge.get("enabled")):
        return
    var story := _debug_story()
    story.merge(story_extra, true)
    bridge.record(event_name, severity, story, _debug_cursor(), data)

func _debug_error(event_name: String, code: String, message: String, story_extra: Dictionary = {}) -> void:
    var bridge := _debug_bridge()
    if bridge == null or not bool(bridge.get("enabled")):
        return
    var story := _debug_story()
    story.merge(story_extra, true)
    bridge.record_error(event_name, code, message, story, _debug_cursor())
