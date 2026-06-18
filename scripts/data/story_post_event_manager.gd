extends Node

signal post_event_executed(event_type: String, timing: String, payload: Dictionary)

const SAVE_FILE_NAME := "story_post_events.json"
const SUPPORTED_TIMINGS := ["immediate", "next_main_scene"]

var _pending_events_by_timing: Dictionary = {}

func _ready() -> void:
	reload_for_active_archive()

func reload_for_active_archive() -> void:
	_pending_events_by_timing.clear()
	_load_state()

func register_story_completion(script_id: String, script_meta: Dictionary, is_first_completion: bool) -> void:
	if not is_first_completion:
		return
	var events := _extract_post_story_events(script_id, script_meta)
	if events.is_empty():
		return
	for event in events:
		var timing := str(event.get("timing", "immediate")).strip_edges()
		if timing == "immediate":
			_execute_event(event, timing)
			continue
		_enqueue_event(timing, event)
	_save_state()

func process_timing(timing: String) -> Array[Dictionary]:
	var normalized_timing := _normalize_timing(timing)
	var executed: Array[Dictionary] = []
	if normalized_timing == "":
		return executed
	var queued: Array = _pending_events_by_timing.get(normalized_timing, [])
	if queued.is_empty():
		return executed
	var pending_copy: Array = queued.duplicate(true)
	_pending_events_by_timing[normalized_timing] = []
	for raw_event in pending_copy:
		if not (raw_event is Dictionary):
			continue
		var event := raw_event as Dictionary
		if _execute_event(event, normalized_timing):
			executed.append(event)
		else:
			_enqueue_event(normalized_timing, event)
	_save_state()
	return executed

func _extract_post_story_events(script_id: String, script_meta: Dictionary) -> Array[Dictionary]:
	var normalized: Array[Dictionary] = []
	var raw_events: Variant = script_meta.get("post_story_events", [])
	if raw_events is Array:
		for raw_event in raw_events:
			if not (raw_event is Dictionary):
				continue
			var normalized_event := _normalize_event(script_id, raw_event as Dictionary)
			if normalized_event.is_empty():
				continue
			normalized.append(normalized_event)
	var legacy_fixed_chats: Variant = script_meta.get("fixed_chat_unlocks", [])
	if legacy_fixed_chats is Array:
		for raw_entry in legacy_fixed_chats:
			if not (raw_entry is Dictionary):
				continue
			var entry := raw_entry as Dictionary
			var converted := {
				"type": "fixed_chat",
				"script_id": str(entry.get("script_id", "")).strip_edges(),
				"timing": _normalize_timing(str(entry.get("trigger", "next_main_scene")).strip_edges()),
				"source_story_id": script_id
			}
			var normalized_legacy := _normalize_event(script_id, converted)
			if normalized_legacy.is_empty():
				continue
			normalized.append(normalized_legacy)
	return normalized

func _normalize_event(script_id: String, event: Dictionary) -> Dictionary:
	var normalized_type := str(event.get("type", "")).strip_edges()
	if normalized_type == "":
		return {}
	var normalized_timing := _normalize_timing(str(event.get("timing", event.get("trigger", "immediate"))).strip_edges())
	if normalized_timing == "":
		return {}
	var normalized_event := event.duplicate(true)
	normalized_event["type"] = normalized_type
	normalized_event["timing"] = normalized_timing
	normalized_event["source_story_id"] = script_id
	match normalized_type:
		"fixed_chat":
			var fixed_chat_id := str(normalized_event.get("script_id", "")).strip_edges()
			if fixed_chat_id == "":
				return {}
			normalized_event["script_id"] = fixed_chat_id
		"moment":
			var author := str(normalized_event.get("author", "")).strip_edges()
			var content := str(normalized_event.get("content", "")).strip_edges()
			if author == "" or content == "":
				return {}
			normalized_event["author"] = author
			normalized_event["content"] = content
		"unlock_area":
			var area_id := str(normalized_event.get("area_id", "")).strip_edges()
			if area_id == "":
				return {}
			normalized_event["area_id"] = area_id
		"set_meta":
			var meta_key := str(normalized_event.get("key", "")).strip_edges()
			if meta_key == "":
				return {}
			normalized_event["key"] = meta_key
		"toast":
			var text := str(normalized_event.get("text", "")).strip_edges()
			if text == "":
				return {}
			normalized_event["text"] = text
		_:
			return {}
	return normalized_event

func _normalize_timing(raw_timing: String) -> String:
	var normalized := raw_timing.strip_edges()
	if normalized == "":
		normalized = "immediate"
	if not SUPPORTED_TIMINGS.has(normalized):
		return ""
	return normalized

func _enqueue_event(timing: String, event: Dictionary) -> void:
	var normalized_timing := _normalize_timing(timing)
	if normalized_timing == "":
		return
	var queue: Array = _pending_events_by_timing.get(normalized_timing, [])
	queue.append(event.duplicate(true))
	_pending_events_by_timing[normalized_timing] = queue

func _execute_event(event: Dictionary, timing: String) -> bool:
	var event_type := str(event.get("type", "")).strip_edges()
	var success := false
	match event_type:
		"fixed_chat":
			success = _execute_fixed_chat_event(event)
		"moment":
			success = _execute_moment_event(event)
		"unlock_area":
			success = _execute_unlock_area_event(event)
		"set_meta":
			success = _execute_set_meta_event(event)
		"toast":
			success = _execute_toast_event(event)
		_:
			success = false
	if success:
		post_event_executed.emit(event_type, timing, event)
	return success

func _execute_fixed_chat_event(event: Dictionary) -> bool:
	if not is_instance_valid(MobileFixedChatManager):
		return false
	if not MobileFixedChatManager.has_method("trigger_script"):
		return false
	return bool(MobileFixedChatManager.trigger_script(str(event.get("script_id", "")).strip_edges()))

func _execute_moment_event(event: Dictionary) -> bool:
	if not is_instance_valid(MomentsManager):
		return false
	if not MomentsManager.has_method("add_moment"):
		return false
	var images: Array = []
	if event.get("images", []) is Array:
		images = (event.get("images", []) as Array).duplicate(true)
	var comments: Array = []
	if event.get("comments", []) is Array:
		comments = (event.get("comments", []) as Array).duplicate(true)
	MomentsManager.add_moment(
		str(event.get("author", "")),
		str(event.get("time", Time.get_date_string_from_system())),
		str(event.get("content", "")),
		images,
		int(event.get("likes", 0)),
		bool(event.get("is_liked", false)),
		comments,
		str(event.get("avatar", "")),
		bool(event.get("is_unread", true))
	)
	return true

func _execute_unlock_area_event(event: Dictionary) -> bool:
	if not is_instance_valid(MapDataManager):
		return false
	if not MapDataManager.has_method("unlock_area"):
		return false
	MapDataManager.unlock_area(str(event.get("area_id", "")).strip_edges())
	return true

func _execute_set_meta_event(event: Dictionary) -> bool:
	if GameDataManager == null:
		return false
	GameDataManager.set_meta(str(event.get("key", "")).strip_edges(), event.get("value"))
	return true

func _execute_toast_event(event: Dictionary) -> bool:
	if typeof(ToastManager) == TYPE_NIL or not ToastManager.has_method("show_system_toast"):
		return false
	ToastManager.show_system_toast(str(event.get("text", "")), _resolve_event_color(event.get("color", null)))
	return true

func _resolve_event_color(raw_color: Variant) -> Color:
	if raw_color is Color:
		return raw_color
	if raw_color is Array:
		var values := raw_color as Array
		if values.size() >= 3:
			var alpha := float(values[3]) if values.size() >= 4 else 1.0
			return Color(float(values[0]), float(values[1]), float(values[2]), alpha)
	return Color(0.57, 0.82, 0.76, 1.0)

func _get_save_path() -> String:
	if GameDataManager == null or not GameDataManager.has_method("get_character_save_path"):
		return "user://story_post_events.json"
	var char_id := ""
	if GameDataManager.profile and str(GameDataManager.profile.current_character_id) != "":
		char_id = str(GameDataManager.profile.current_character_id)
	elif GameDataManager.config and str(GameDataManager.config.current_character_id) != "":
		char_id = str(GameDataManager.config.current_character_id)
	return GameDataManager.get_character_save_path(SAVE_FILE_NAME, char_id)

func _load_state() -> void:
	for timing in SUPPORTED_TIMINGS:
		_pending_events_by_timing[timing] = []
	var save_path := _get_save_path()
	if not FileAccess.file_exists(save_path):
		return
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return
	var content := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(content) != OK:
		return
	var data: Variant = json.data
	if not (data is Dictionary):
		return
	var raw_pending: Variant = (data as Dictionary).get("pending_events_by_timing", {})
	if not (raw_pending is Dictionary):
		return
	for timing in SUPPORTED_TIMINGS:
		var normalized_queue: Array = []
		var raw_queue: Variant = (raw_pending as Dictionary).get(timing, [])
		if raw_queue is Array:
			for raw_event in raw_queue:
				if not (raw_event is Dictionary):
					continue
				var normalized_event := _normalize_event(str((raw_event as Dictionary).get("source_story_id", "")).strip_edges(), raw_event as Dictionary)
				if normalized_event.is_empty():
					continue
				normalized_queue.append(normalized_event)
		_pending_events_by_timing[timing] = normalized_queue

func _save_state() -> void:
	var save_path := _get_save_path()
	var save_dir := save_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(save_dir):
		DirAccess.make_dir_recursive_absolute(save_dir)
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		return
	var data := {
		"pending_events_by_timing": _pending_events_by_timing
	}
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
