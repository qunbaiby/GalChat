extends Node

const SAVE_FILE_NAME := "main_chat_topic_state.json"

var _active_topics_by_character: Dictionary = {}

func _ready() -> void:
	reload_for_active_archive()

func reload_for_active_archive() -> void:
	_active_topics_by_character.clear()
	_load_state()

func activate_topic(event_data: Dictionary) -> bool:
	var normalized: Dictionary = _normalize_topic_event(event_data)
	if normalized.is_empty():
		return false
	var char_id: String = str(normalized.get("character_id", "")).strip_edges().to_lower()
	if char_id == "":
		return false
	_active_topics_by_character[char_id] = normalized
	_save_state()
	return true

func has_active_topic_for(char_id: String) -> bool:
	return not get_active_topic_for(char_id).is_empty()

func get_active_topic_for(char_id: String) -> Dictionary:
	var normalized_char_id: String = str(char_id).strip_edges().to_lower()
	if normalized_char_id == "":
		return {}
	if not _active_topics_by_character.has(normalized_char_id):
		return {}
	var topic_data: Variant = _active_topics_by_character.get(normalized_char_id, {})
	if topic_data is Dictionary:
		return (topic_data as Dictionary).duplicate(true)
	return {}

func consume_active_topic(char_id: String) -> bool:
	var normalized_char_id: String = str(char_id).strip_edges().to_lower()
	if normalized_char_id == "" or not _active_topics_by_character.has(normalized_char_id):
		return false
	_active_topics_by_character.erase(normalized_char_id)
	_save_state()
	return true

func clear_expired_topics(current_day_offset: int) -> Array[String]:
	var removed: Array[String] = []
	for raw_char_id in _active_topics_by_character.keys():
		var char_id: String = str(raw_char_id).strip_edges().to_lower()
		var topic_data: Variant = _active_topics_by_character.get(char_id, {})
		if not (topic_data is Dictionary):
			continue
		var topic_dict: Dictionary = topic_data as Dictionary
		if not bool(topic_dict.get("expire_on_next_day", false)):
			continue
		var unlock_day_offset: int = int(topic_dict.get("unlock_day_offset", current_day_offset))
		if current_day_offset <= unlock_day_offset:
			continue
		removed.append(char_id)
	for char_id in removed:
		_active_topics_by_character.erase(char_id)
	if not removed.is_empty():
		_save_state()
	return removed

func _normalize_topic_event(event_data: Dictionary) -> Dictionary:
	var normalized: Dictionary = event_data.duplicate(true)
	var char_id: String = str(normalized.get("character_id", "")).strip_edges().to_lower()
	var topic_text: String = str(normalized.get("topic_text", "")).strip_edges()
	if char_id == "" or topic_text == "":
		return {}
	var event_id: String = str(normalized.get("event_id", "")).strip_edges()
	if event_id == "":
		event_id = "%s_topic" % char_id
	var prompt_hint: String = str(normalized.get("topic_prompt_hint", "")).strip_edges()
	var unlock_day_offset: int = int(normalized.get("unlock_day_offset", _get_current_day_offset()))
	normalized["type"] = "main_chat_topic"
	normalized["event_id"] = event_id
	normalized["character_id"] = char_id
	normalized["topic_text"] = topic_text
	normalized["topic_prompt_hint"] = prompt_hint
	normalized["unlock_day_offset"] = unlock_day_offset
	normalized["expire_on_next_day"] = bool(normalized.get("expire_on_next_day", true))
	normalized["source_type"] = str(normalized.get("source_type", "")).strip_edges()
	normalized["source_id"] = str(normalized.get("source_id", "")).strip_edges()
	return normalized

func _get_current_day_offset() -> int:
	if GameDataManager and GameDataManager.story_time_manager:
		return int(GameDataManager.story_time_manager.current_day_offset)
	return 0

func _get_save_path() -> String:
	if GameDataManager == null or not GameDataManager.has_method("get_character_save_path"):
		return "user://%s" % SAVE_FILE_NAME
	var char_id: String = ""
	if GameDataManager.profile and str(GameDataManager.profile.current_character_id) != "":
		char_id = str(GameDataManager.profile.current_character_id)
	elif GameDataManager.config and str(GameDataManager.config.current_character_id) != "":
		char_id = str(GameDataManager.config.current_character_id)
	return GameDataManager.get_character_save_path(SAVE_FILE_NAME, char_id)

func _load_state() -> void:
	var save_path: String = _get_save_path()
	if not FileAccess.file_exists(save_path):
		return
	var file: FileAccess = FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return
	var content: String = file.get_as_text()
	file.close()
	var json: JSON = JSON.new()
	if json.parse(content) != OK:
		return
	var data: Variant = json.data
	if not (data is Dictionary):
		return
	var raw_topics: Variant = (data as Dictionary).get("active_topics_by_character", {})
	if not (raw_topics is Dictionary):
		return
	for raw_char_id in (raw_topics as Dictionary).keys():
		var char_id: String = str(raw_char_id).strip_edges().to_lower()
		var raw_topic: Variant = (raw_topics as Dictionary).get(raw_char_id, {})
		if char_id == "" or not (raw_topic is Dictionary):
			continue
		var normalized: Dictionary = _normalize_topic_event(raw_topic as Dictionary)
		if normalized.is_empty():
			continue
		_active_topics_by_character[char_id] = normalized

func _save_state() -> void:
	var save_path: String = _get_save_path()
	var save_dir: String = save_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(save_dir):
		DirAccess.make_dir_recursive_absolute(save_dir)
	var file: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"active_topics_by_character": _active_topics_by_character
	}, "\t"))
	file.close()
