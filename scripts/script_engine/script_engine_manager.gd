class_name ScriptEngineManager
extends Node

signal on_dialogue_requested(speaker: String, content: String, mood: String, presentation: Dictionary)
signal on_bgm_requested(audio_path: String, fade_time: float)
signal on_background_requested(bg_path: String, duration: float, transition_type: String)
signal on_audio_requested(audio_type: String, action: String, audio_id: String, fade_time: float, loop: bool)
signal on_variable_set(var_name: String, var_value: Variant)
signal on_ai_chat_requested(prompt_override: String)
signal on_character_show_requested(animation: String, presentation: Dictionary)
signal on_character_move_requested(animation: String, presentation: Dictionary)
signal on_character_hide_requested(animation: String, presentation: Dictionary)
signal on_player_call_name_requested()
signal on_voice_call_requested(call_id: String)
signal on_start_free_chat_requested(strategy: String, max_rounds: int)
signal script_finished(script_id: String)

var current_script_id: String = ""
var current_script_path: String = ""
var current_script_meta: Dictionary = {}
var chapters: Dictionary = {} # chapter_id -> ScriptChapter
var current_chapter_id: String = ""
var current_event_index: int = 0
var is_running: bool = false
var is_waiting_for_resume: bool = false

func load_script(script_path: String) -> bool:
    if not FileAccess.file_exists(script_path):
        printerr("[ScriptEngine] Script file not found: ", script_path)
        return false
        
    var file = FileAccess.open(script_path, FileAccess.READ)
    var content = file.get_as_text()
    file.close()
    
    var json = JSON.new()
    var err = json.parse(content)
    if err != OK:
        printerr("[ScriptEngine] Failed to parse script JSON: ", json.get_error_message())
        return false
    return load_script_data(json.data, script_path)

func load_script_data(data: Variant, source_path: String = "") -> bool:
    if not data is Dictionary:
        printerr("[ScriptEngine] Invalid runtime script data.")
        return false

    var script_data: Dictionary = data
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
    return true

func start_script(start_chapter_id: String = "start") -> void:
    if not chapters.has(start_chapter_id):
        printerr("[ScriptEngine] Start chapter not found: ", start_chapter_id)
        return
        
    is_running = true
    is_waiting_for_resume = false
    current_chapter_id = start_chapter_id
    current_event_index = 0
    _process_next_event()

func jump_to_chapter(target_chapter_id: String) -> void:
    if target_chapter_id == "end" or not chapters.has(target_chapter_id):
        _end_script()
        return
        
    current_chapter_id = target_chapter_id
    current_event_index = 0

func resume() -> void:
    if not is_running or not is_waiting_for_resume:
        return
    is_waiting_for_resume = false
    current_event_index += 1
    _process_next_event()

func _process_next_event() -> void:
    if not is_running or is_waiting_for_resume:
        return
        
    var current_chapter: ScriptChapter = chapters[current_chapter_id]
    
    # 循环处理非阻塞事件，直到遇到阻塞事件或章节结束
    while current_event_index < current_chapter.events.size():
        var ev = current_chapter.events[current_event_index]
        var is_blocking = ev.process_event(self)
        
        if is_blocking:
            is_waiting_for_resume = true
            return # 退出循环，等待外部调用 resume()
            
        current_event_index += 1
        
    # 当前章节事件执行完毕，如果没有 jump，默认结束
    _end_script()

func _end_script() -> void:
    print("[ScriptEngine] Script finished: ", current_script_id)
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
