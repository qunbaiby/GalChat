extends Node

signal goals_updated
signal goal_activated(goal_id: String, goal_data: Dictionary)

const GOAL_DATA_PATH := "res://assets/data/goals/main_goals.json"
const SAVE_FILE_NAME := "goal_state.json"

var _goal_defs: Dictionary = {}
var _active_goal_ids: Array[String] = []
var _completed_goal_ids: Array[String] = []

func _ready() -> void:
	reload_for_active_archive()

func reload_for_active_archive() -> void:
	_goal_defs.clear()
	_active_goal_ids.clear()
	_completed_goal_ids.clear()
	_load_goal_defs()
	_load_state()
	goals_updated.emit()

func has_active_goals() -> bool:
	return not _active_goal_ids.is_empty()

func is_goal_active(goal_id: String) -> bool:
	var normalized_goal_id: String = goal_id.strip_edges()
	if normalized_goal_id == "":
		return false
	return _active_goal_ids.has(normalized_goal_id)

func get_active_goal_ids() -> Array[String]:
	return _active_goal_ids.duplicate()

func get_primary_active_goal() -> Dictionary:
	var active_goals: Array[Dictionary] = get_active_goals()
	if active_goals.is_empty():
		return {}
	return active_goals[0].duplicate(true)

func get_active_goals() -> Array[Dictionary]:
	var goals: Array[Dictionary] = []
	for goal_id in _active_goal_ids:
		var goal_data: Dictionary = _get_goal_def(goal_id)
		if goal_data.is_empty():
			continue
		goals.append(goal_data.duplicate(true))
	goals.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var order_a: int = int(a.get("sort_order", 9999))
		var order_b: int = int(b.get("sort_order", 9999))
		if order_a == order_b:
			return str(a.get("id", "")) < str(b.get("id", ""))
		return order_a < order_b
	)
	return goals

func activate_goal(goal_id: String) -> bool:
	var normalized_goal_id: String = goal_id.strip_edges()
	if normalized_goal_id == "" or not _goal_defs.has(normalized_goal_id):
		return false
	if _completed_goal_ids.has(normalized_goal_id):
		return false
	if _active_goal_ids.has(normalized_goal_id):
		return false
	_active_goal_ids.append(normalized_goal_id)
	_save_state()
	var goal_data: Dictionary = _get_goal_def(normalized_goal_id)
	goal_activated.emit(normalized_goal_id, goal_data.duplicate(true))
	goals_updated.emit()
	return true

func complete_goal(goal_id: String) -> bool:
	var normalized_goal_id: String = goal_id.strip_edges()
	if normalized_goal_id == "" or not _goal_defs.has(normalized_goal_id):
		return false
	var changed: bool = false
	if _active_goal_ids.has(normalized_goal_id):
		_active_goal_ids.erase(normalized_goal_id)
		changed = true
	if not _completed_goal_ids.has(normalized_goal_id):
		_completed_goal_ids.append(normalized_goal_id)
		changed = true
	if not changed:
		return false
	_save_state()
	goals_updated.emit()
	return true

func _get_goal_def(goal_id: String) -> Dictionary:
	var normalized_goal_id: String = goal_id.strip_edges()
	if normalized_goal_id == "" or not _goal_defs.has(normalized_goal_id):
		return {}
	var raw_goal: Variant = _goal_defs.get(normalized_goal_id, {})
	if raw_goal is Dictionary:
		return (raw_goal as Dictionary).duplicate(true)
	return {}

func _load_goal_defs() -> void:
	if not FileAccess.file_exists(GOAL_DATA_PATH):
		return
	var file: FileAccess = FileAccess.open(GOAL_DATA_PATH, FileAccess.READ)
	if file == null:
		return
	var json: JSON = JSON.new()
	var parse_result: int = json.parse(file.get_as_text())
	file.close()
	if parse_result != OK:
		return
	var data: Variant = json.data
	if not (data is Dictionary):
		return
	var raw_goals: Variant = (data as Dictionary).get("goals", [])
	if not (raw_goals is Array):
		return
	for raw_goal in raw_goals:
		if not (raw_goal is Dictionary):
			continue
		var goal_dict: Dictionary = (raw_goal as Dictionary).duplicate(true)
		var goal_id: String = str(goal_dict.get("id", "")).strip_edges()
		if goal_id == "":
			continue
		goal_dict["id"] = goal_id
		goal_dict["title"] = str(goal_dict.get("title", "")).strip_edges()
		goal_dict["summary"] = str(goal_dict.get("summary", "")).strip_edges()
		goal_dict["description"] = str(goal_dict.get("description", "")).strip_edges()
		goal_dict["sort_order"] = int(goal_dict.get("sort_order", 9999))
		_goal_defs[goal_id] = goal_dict

func _get_save_path() -> String:
	if GameDataManager == null or not GameDataManager.has_method("get_character_save_path"):
		return "user://%s" % SAVE_FILE_NAME
	var char_id: String = ""
	if GameDataManager.profile and str(GameDataManager.profile.current_character_id).strip_edges() != "":
		char_id = str(GameDataManager.profile.current_character_id).strip_edges()
	elif GameDataManager.config and str(GameDataManager.config.current_character_id).strip_edges() != "":
		char_id = str(GameDataManager.config.current_character_id).strip_edges()
	return GameDataManager.get_character_save_path(SAVE_FILE_NAME, char_id)

func _load_state() -> void:
	var save_path: String = _get_save_path()
	if not FileAccess.file_exists(save_path):
		return
	var file: FileAccess = FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return
	var json: JSON = JSON.new()
	var parse_result: int = json.parse(file.get_as_text())
	file.close()
	if parse_result != OK:
		return
	var data: Variant = json.data
	if not (data is Dictionary):
		return
	_active_goal_ids = _normalize_goal_id_list((data as Dictionary).get("active_goal_ids", []), false)
	_completed_goal_ids = _normalize_goal_id_list((data as Dictionary).get("completed_goal_ids", []), true)

func _save_state() -> bool:
	var save_path: String = _get_save_path()
	var save_dir: String = save_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(save_dir):
		DirAccess.make_dir_recursive_absolute(save_dir)
	var file: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({
		"active_goal_ids": _active_goal_ids,
		"completed_goal_ids": _completed_goal_ids
	}, "\t"))
	var write_error := file.get_error()
	file.close()
	return write_error == OK

func _normalize_goal_id_list(raw_list: Variant, allow_missing_defs: bool) -> Array[String]:
	var normalized: Array[String] = []
	if not (raw_list is Array):
		return normalized
	for raw_goal_id in raw_list:
		var goal_id: String = str(raw_goal_id).strip_edges()
		if goal_id == "":
			continue
		if not allow_missing_defs and not _goal_defs.has(goal_id):
			continue
		if not normalized.has(goal_id):
			normalized.append(goal_id)
	return normalized
