extends Node

signal post_event_executed(event_type: String, timing: String, payload: Dictionary)

const SAVE_FILE_NAME := "story_post_events.json"
const STORY_SCRIPT_ROOT := "res://assets/data/story/scripts"
const SUPPORTED_TIMINGS := ["immediate", "next_main_scene"]
const MIGRATION_REVISION := 4

var _pending_events_by_timing: Dictionary = {}
var _migration_revision: int = 0

func _ready() -> void:
	reload_for_active_archive()

func reload_for_active_archive() -> void:
	_pending_events_by_timing.clear()
	_migration_revision = 0
	_load_state()
	_apply_legacy_migrations()

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

func register_time_completion(trigger_id: String) -> bool:
	if GameDataManager == null or GameDataManager.story_time_manager == null:
		return false
	if not GameDataManager.story_time_manager.has_method("get_current_completion_events"):
		return false
	var raw_events: Array = GameDataManager.story_time_manager.get_current_completion_events(trigger_id)
	var registered := false
	for raw_event in raw_events:
		var source_story_id := str(raw_event.get("source_story_id", "")).strip_edges()
		var normalized_event := _normalize_event(source_story_id, raw_event)
		if normalized_event.is_empty():
			continue
		var timing := str(normalized_event.get("timing", "immediate"))
		if timing == "immediate":
			registered = _execute_event(normalized_event, timing) or registered
		elif not _has_queued_event(normalized_event):
			_enqueue_event(timing, normalized_event)
			registered = true
	if registered:
		_save_state()
	return registered

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

func reconcile_completed_story_fixed_chats() -> Array[String]:
	var triggered: Array[String] = []
	if GameDataManager.profile == null or not GameDataManager.profile.has_method("has_finished_story"):
		return triggered
	for story_path in _find_story_script_paths(STORY_SCRIPT_ROOT):
		var file := FileAccess.open(story_path, FileAccess.READ)
		if file == null:
			continue
		var data: Variant = JSON.parse_string(file.get_as_text())
		file.close()
		if not data is Dictionary:
			continue
		var story_data := data as Dictionary
		var story_id := str(story_data.get("script_id", story_path.get_file().get_basename())).strip_edges()
		if story_id == "" or not bool(GameDataManager.profile.has_finished_story(story_id)):
			continue
		var raw_events: Variant = story_data.get("post_story_events", [])
		if not raw_events is Array:
			continue
		for raw_event in raw_events:
			if not raw_event is Dictionary or str((raw_event as Dictionary).get("type", "")).strip_edges() != "fixed_chat":
				continue
			var script_id := str((raw_event as Dictionary).get("script_id", "")).strip_edges()
			if script_id == "" or MobileFixedChatManager.is_script_active(script_id) or MobileFixedChatManager.is_script_completed(script_id):
				continue
			if MobileFixedChatManager.trigger_script(script_id):
				triggered.append(script_id)
	return triggered

func _find_story_script_paths(directory_path: String) -> Array[String]:
	var paths: Array[String] = []
	var directory := DirAccess.open(directory_path)
	if directory == null:
		return paths
	directory.list_dir_begin()
	var entry := directory.get_next()
	while entry != "":
		var entry_path := directory_path.path_join(entry)
		if directory.current_is_dir():
			paths.append_array(_find_story_script_paths(entry_path))
		elif entry.get_extension().to_lower() == "json":
			paths.append(entry_path)
		entry = directory.get_next()
	directory.list_dir_end()
	return paths

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
		"unlock_location":
			var location_id := str(normalized_event.get("location_id", "")).strip_edges()
			if location_id == "":
				return {}
			normalized_event["location_id"] = location_id
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
		"main_scene_presentation":
			var background_id := str(normalized_event.get("background_id", "")).strip_edges()
			var play_track_id := str(normalized_event.get("play_track_id", "")).strip_edges()
			var guide_id := str(normalized_event.get("guide_id", "")).strip_edges()
			if background_id == "" and play_track_id == "" and guide_id == "":
				return {}
			normalized_event["background_id"] = background_id
			normalized_event["play_track_id"] = play_track_id
			normalized_event["guide_id"] = guide_id
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

func _has_queued_event(event: Dictionary) -> bool:
	var timing := str(event.get("timing", "")).strip_edges()
	var source_story_id := str(event.get("source_story_id", "")).strip_edges()
	var event_type := str(event.get("type", "")).strip_edges()
	for queued_event in _pending_events_by_timing.get(timing, []):
		if not queued_event is Dictionary:
			continue
		if str(queued_event.get("type", "")) != event_type:
			continue
		if event_type == "fixed_chat":
			if str(queued_event.get("script_id", "")) != str(event.get("script_id", "")):
				continue
			return true
		if str(queued_event.get("source_story_id", "")) != source_story_id:
			continue
		return true
	return false

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
		"unlock_location":
			success = _execute_unlock_location_event(event)
		"set_meta":
			success = _execute_set_meta_event(event)
		"toast":
			success = _execute_toast_event(event)
		"main_scene_presentation":
			success = true
		_:
			success = false
	if success:
		post_event_executed.emit(event_type, timing, event)
	return success

func _execute_fixed_chat_event(event: Dictionary) -> bool:
	if not is_instance_valid(MobileFixedChatManager):
		return false
	var script_id := str(event.get("script_id", "")).strip_edges()
	if MobileFixedChatManager.has_method("is_script_active") and bool(MobileFixedChatManager.is_script_active(script_id)):
		return true
	if MobileFixedChatManager.has_method("is_script_completed") and bool(MobileFixedChatManager.is_script_completed(script_id)):
		return true
	if not MobileFixedChatManager.has_method("trigger_script"):
		return false
	if not bool(MobileFixedChatManager.trigger_script(script_id)):
		return false
	return bool(MobileFixedChatManager.is_script_active(script_id)) or bool(MobileFixedChatManager.is_script_completed(script_id))

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

func _execute_unlock_location_event(event: Dictionary) -> bool:
	if not is_instance_valid(MapDataManager):
		return false
	if not MapDataManager.has_method("unlock_location"):
		return false
	MapDataManager.unlock_location(str(event.get("location_id", "")).strip_edges())
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
	_migration_revision = maxi(0, int((data as Dictionary).get("migration_revision", 0)))
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

func _apply_legacy_migrations(save_now: bool = true) -> void:
	var changed := false
	if _migration_revision < 1:
		changed = _migrate_jing_piano_practice_invite() or changed
		_migration_revision = 1
		changed = true
	if _migration_revision < 2:
		changed = _migrate_jing_piano_practice_invite() or changed
		_migration_revision = 2
		changed = true
	if _migration_revision < 3:
		changed = _migrate_jing_piano_practice_invite() or changed
		_migration_revision = 3
		changed = true
	if _migration_revision < 4:
		changed = _migrate_jing_piano_practice_invite() or changed
		_migration_revision = 4
		changed = true
	if changed and save_now:
		_save_state()

func _migrate_jing_piano_practice_invite() -> bool:
	if GameDataManager.profile == null or not GameDataManager.profile.has_method("has_finished_story"):
		return false
	if not bool(GameDataManager.profile.has_finished_story("luna_piano_practice")):
		return false
	if not is_instance_valid(MobileFixedChatManager):
		return false
	if MobileFixedChatManager.has_method("is_script_active") and bool(MobileFixedChatManager.is_script_active("jing_piano_practice_invite")):
		return false
	if MobileFixedChatManager.has_method("is_script_completed") and bool(MobileFixedChatManager.is_script_completed("jing_piano_practice_invite")):
		return false
	var event := _normalize_event("legacy_migration_v1", {
		"type": "fixed_chat",
		"script_id": "jing_piano_practice_invite",
		"timing": "next_main_scene"
	})
	if event.is_empty() or _has_queued_event(event):
		return false
	_enqueue_event("next_main_scene", event)
	return true

func _save_state() -> bool:
	var save_path := _get_save_path()
	var save_dir := save_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(save_dir):
		DirAccess.make_dir_recursive_absolute(save_dir)
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		return false
	var data := {
		"migration_revision": _migration_revision,
		"pending_events_by_timing": _pending_events_by_timing
	}
	file.store_string(JSON.stringify(data, "\t"))
	var write_error := file.get_error()
	file.close()
	return write_error == OK
