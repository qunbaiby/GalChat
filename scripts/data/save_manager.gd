extends Node
class_name SaveManager

const SafeFileAccess = preload("res://scripts/utils/safe_file_access.gd")
const DEFAULT_CHARACTER_ID := "luna"
const META_FILE_NAME := "meta.json"
const MAX_DISCOVERED_ARCHIVES := 300
const LEGACY_IMPORT_DECISION_KEY := "legacy_archive_import_decided"

var current_slot_id: String = ""

func _ready() -> void:
	current_slot_id = get_active_archive_id()

func get_archive_slot_ids() -> Array[String]:
	var slot_ids: Array[String] = []
	var root_dir := GameDataManager.get_archive_collection_dir()
	if not DirAccess.dir_exists_absolute(root_dir):
		return slot_ids
	var dir := DirAccess.open(root_dir)
	if dir == null:
		return slot_ids
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "" and slot_ids.size() < MAX_DISCOVERED_ARCHIVES:
		if entry != "." and entry != ".." and dir.current_is_dir() and _archive_meta_exists(entry):
			slot_ids.append(entry)
		entry = dir.get_next()
	dir.list_dir_end()
	return slot_ids

func generate_archive_id() -> String:
	var timestamp := Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "_")
	var base_id := "memory_%s" % timestamp
	var candidate := base_id
	var index := 1
	while DirAccess.dir_exists_absolute(_get_archive_root_path(candidate)):
		index += 1
		candidate = "%s_%d" % [base_id, index]
	return candidate

func get_active_archive_id() -> String:
	if GameDataManager:
		current_slot_id = GameDataManager.get_active_archive_id()
	return current_slot_id

func get_archive_root(slot_id: String = "") -> String:
	return GameDataManager.get_archive_root_dir(slot_id)

func _get_archive_root_path(slot_id: String) -> String:
	return GameDataManager.get_archive_collection_dir().path_join(slot_id.strip_edges())

func _archive_meta_exists(slot_id: String) -> bool:
	return FileAccess.file_exists(_get_archive_root_path(slot_id).path_join(META_FILE_NAME))

func get_meta_path(slot_id: String = "") -> String:
	return get_archive_root(slot_id).path_join(META_FILE_NAME)

func get_save_slots() -> Array:
	var slots: Array = []
	for slot_id in get_archive_slot_ids():
		var meta := load_slot_meta(slot_id)
		if not meta.is_empty():
			meta["slot_id"] = slot_id
			meta["is_empty"] = false
			slots.append(meta)
	slots.sort_custom(func(a, b): return str(a.get("last_played_at", "")) > str(b.get("last_played_at", "")))
	return slots

func has_pending_legacy_archive_import() -> bool:
	if bool(GameDataManager.config.get_custom_config(_get_legacy_import_config_key(), false)):
		return false
	return not get_legacy_archive_slot_ids().is_empty()

func get_legacy_archive_slot_ids() -> Array[String]:
	var slot_ids: Array[String] = []
	var root_dir := GameDataManager.LEGACY_ARCHIVE_ROOT_DIR
	if not DirAccess.dir_exists_absolute(root_dir):
		return slot_ids
	var dir := DirAccess.open(root_dir)
	if dir == null:
		return slot_ids
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "" and slot_ids.size() < MAX_DISCOVERED_ARCHIVES:
		var archive_path := root_dir.path_join(entry)
		if entry != "." and entry != ".." and dir.current_is_dir() and FileAccess.file_exists(archive_path.path_join(META_FILE_NAME)):
			slot_ids.append(entry)
		entry = dir.get_next()
	dir.list_dir_end()
	return slot_ids

func import_legacy_archives() -> int:
	var imported_count := 0
	for legacy_slot_id in get_legacy_archive_slot_ids():
		var target_slot_id := _resolve_import_slot_id(legacy_slot_id)
		var source_path := GameDataManager.LEGACY_ARCHIVE_ROOT_DIR.path_join(legacy_slot_id)
		var target_path := _get_archive_root_path(target_slot_id)
		if _copy_directory_recursive(source_path, target_path):
			GameDataManager.import_legacy_archive_custom_config(legacy_slot_id, target_slot_id)
			imported_count += 1
	mark_legacy_archive_import_decided()
	return imported_count

func mark_legacy_archive_import_decided() -> void:
	GameDataManager.config.set_custom_config(_get_legacy_import_config_key(), true)
	GameDataManager.config.save_config()

func reset_legacy_archive_import_decision() -> void:
	GameDataManager.config.set_custom_config(_get_legacy_import_config_key(), false)
	GameDataManager.config.save_config()

func _get_legacy_import_config_key() -> String:
	var user_id := OfficialAuthManager.get_user_id().validate_filename()
	return "%s_%s" % [LEGACY_IMPORT_DECISION_KEY, user_id]

func _resolve_import_slot_id(slot_id: String) -> String:
	if not DirAccess.dir_exists_absolute(_get_archive_root_path(slot_id)):
		return slot_id
	var index := 2
	var candidate := "%s_imported_%d" % [slot_id, index]
	while DirAccess.dir_exists_absolute(_get_archive_root_path(candidate)):
		index += 1
		candidate = "%s_imported_%d" % [slot_id, index]
	return candidate

func _copy_directory_recursive(source_path: String, target_path: String) -> bool:
	var source_dir := DirAccess.open(source_path)
	if source_dir == null:
		return false
	if DirAccess.make_dir_recursive_absolute(target_path) != OK and not DirAccess.dir_exists_absolute(target_path):
		return false
	source_dir.list_dir_begin()
	var entry := source_dir.get_next()
	while entry != "":
		if entry == "." or entry == "..":
			entry = source_dir.get_next()
			continue
		var source_child := source_path.path_join(entry)
		var target_child := target_path.path_join(entry)
		var copied := _copy_directory_recursive(source_child, target_child) if source_dir.current_is_dir() else DirAccess.copy_absolute(source_child, target_child) == OK
		if not copied:
			source_dir.list_dir_end()
			_remove_directory_recursive(target_path)
			return false
		entry = source_dir.get_next()
	source_dir.list_dir_end()
	return true

func load_slot_meta(slot_id: String) -> Dictionary:
	var meta_path := get_meta_path(slot_id)
	if not FileAccess.file_exists(meta_path):
		if _archive_has_runtime_data(slot_id):
			var rebuilt := _build_meta_from_archive(slot_id)
			if not rebuilt.is_empty():
				_write_slot_meta(slot_id, rebuilt)
				return rebuilt
		return {}
	var file := FileAccess.open(meta_path, FileAccess.READ)
	if file == null:
		return {}
	var json := JSON.new()
	var result := json.parse(file.get_as_text())
	file.close()
	if result != OK or not json.data is Dictionary:
		return {}
	var meta: Dictionary = json.data
	meta["slot_id"] = slot_id
	return meta

func prepare_empty_archive(slot_id: String, archive_name: String = "") -> bool:
	var final_slot_id := slot_id.strip_edges()
	if final_slot_id == "":
		return false
	delete_save(final_slot_id)
	if GameDataManager.config and str(GameDataManager.config.current_character_id).strip_edges() == "":
		GameDataManager.config.current_character_id = DEFAULT_CHARACTER_ID
	GameDataManager.set_active_archive_id(final_slot_id, false)
	GameDataManager.clear_archive_custom_config(final_slot_id, false)
	current_slot_id = final_slot_id
	GameDataManager.reload_active_archive_data()
	var final_archive_name := archive_name.strip_edges()
	if final_archive_name == "":
		final_archive_name = "新的记忆"
	_write_slot_meta(final_slot_id, _build_initial_meta(final_slot_id, final_archive_name))
	if GameDataManager.config:
		GameDataManager.config.save_config()
	return true

func load_archive(slot_id: String) -> bool:
	var final_slot_id := slot_id.strip_edges()
	if final_slot_id == "" or not _archive_has_runtime_data(final_slot_id):
		return false
	if GameDataManager.config and str(GameDataManager.config.current_character_id).strip_edges() == "":
		GameDataManager.config.current_character_id = DEFAULT_CHARACTER_ID
	GameDataManager.set_active_archive_id(final_slot_id, false)
	current_slot_id = final_slot_id
	GameDataManager.reload_active_archive_data()
	update_active_archive_meta()
	return true

func load_game(slot_id: String) -> bool:
	return load_archive(slot_id)

func delete_save(slot_id: String) -> bool:
	var archive_root := _get_archive_root_path(slot_id)
	if not DirAccess.dir_exists_absolute(archive_root):
		GameDataManager.clear_archive_custom_config(slot_id)
		return false
	_remove_directory_recursive(archive_root)
	GameDataManager.clear_archive_custom_config(slot_id)
	if get_active_archive_id() == slot_id:
		current_slot_id = ""
		GameDataManager.set_active_archive_id("", true)
	return true

func save_game(slot_id: String = "", _custom_image: Image = null) -> bool:
	var target_slot := slot_id.strip_edges()
	if target_slot == "":
		target_slot = get_active_archive_id()
	if target_slot == "":
		return false
	if target_slot != get_active_archive_id():
		if not load_archive(target_slot):
			return false
	return auto_save()

func auto_save() -> bool:
	var active_slot := get_active_archive_id()
	if active_slot == "":
		return false
	_flush_runtime_state()
	_write_slot_meta(active_slot, _build_runtime_meta(active_slot))
	return true

func update_active_archive_meta() -> void:
	var active_slot := get_active_archive_id()
	if active_slot == "":
		return
	_write_slot_meta(active_slot, _build_runtime_meta(active_slot))

func _flush_runtime_state() -> void:
	if GameDataManager.profile != null:
		GameDataManager.profile.save_profile()
		GameDataManager.sync_profile_to_config()
	if GameDataManager.history != null:
		GameDataManager.history.save_history()
	if GameDataManager.npc_relationship_manager != null:
		GameDataManager.npc_relationship_manager.save_relationships()
	if GameDataManager.memory_manager != null:
		GameDataManager.memory_manager.save_memory()
	if GameDataManager.story_time_manager != null:
		GameDataManager.story_time_manager.save_data()
	if GameDataManager.gift_manager != null and GameDataManager.gift_manager.has_method("save_state"):
		GameDataManager.gift_manager.save_state()
	if GameDataManager.has_method("save_pomodoro_data"):
		GameDataManager.save_pomodoro_data()
	if is_instance_valid(MomentsManager) and MomentsManager.has_method("save_data"):
		MomentsManager.save_data()
	var event_manager = get_node_or_null("/root/EventManager")
	if event_manager and event_manager.has_method("_save_triggered_events"):
		event_manager._save_triggered_events()
	if GameDataManager.config:
		GameDataManager.config.save_config()

func _build_runtime_meta(slot_id: String) -> Dictionary:
	var now_text := _get_now_text()
	var existing_meta := load_slot_meta(slot_id)
	var archive_name := str(existing_meta.get("archive_name", "")).strip_edges()
	var profile := GameDataManager.profile
	var player_name := "未命名"
	var stage_title := "相识"
	var current_stage := 1
	var day_count := 1
	if profile != null:
		player_name = str(profile.player_name).strip_edges()
		if player_name == "":
			player_name = "未命名"
		current_stage = int(profile.current_stage)
		var stage_conf := profile.get_stage_config(current_stage)
		if not stage_conf.is_empty():
			stage_title = str(stage_conf.get("stageTitle", stage_title))
	if GameDataManager.story_time_manager != null:
		day_count = maxi(1, int(GameDataManager.story_time_manager.current_day_offset) + 1)
	if archive_name == "":
		archive_name = player_name if player_name != "未命名" else "新的记忆"
	return {
		"slot_id": slot_id,
		"archive_name": archive_name,
		"created_at": str(existing_meta.get("created_at", now_text)),
		"player_name": player_name,
		"day_count": day_count,
		"stage": current_stage,
		"stage_title": stage_title,
		"last_played_at": now_text,
		"display_line_1": "与 Luna 相处第%d天" % day_count,
		"display_line_2": "%s & Luna  当前情感阶段：%s" % [player_name, stage_title],
		"display_line_3": "最后游玩：%s" % now_text
	}

func _build_initial_meta(slot_id: String, archive_name: String) -> Dictionary:
	var now_text := _get_now_text()
	return {
		"slot_id": slot_id,
		"archive_name": archive_name,
		"created_at": now_text,
		"player_name": "未命名",
		"day_count": 1,
		"stage": 1,
		"stage_title": "相识",
		"last_played_at": now_text,
		"display_line_1": "与 Luna 相处第1天",
		"display_line_2": "未命名 & Luna  当前情感阶段：相识",
		"display_line_3": "最后游玩：%s" % now_text
	}

func _build_meta_from_archive(slot_id: String) -> Dictionary:
	var profile_path: String = GameDataManager.get_character_save_path("character_profile.json", DEFAULT_CHARACTER_ID, slot_id)
	var profile_data: Dictionary = {}
	if FileAccess.file_exists(profile_path):
		var file := FileAccess.open(profile_path, FileAccess.READ)
		if file != null:
			var json := JSON.new()
			if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
				profile_data = json.data
			file.close()
	if profile_data.is_empty():
		return {}
	var day_count := 1
	var time_path: String = GameDataManager.get_character_save_path("story_time_save.json", DEFAULT_CHARACTER_ID, slot_id)
	if FileAccess.file_exists(time_path):
		var time_file := FileAccess.open(time_path, FileAccess.READ)
		if time_file != null:
			var time_json := JSON.new()
			if time_json.parse(time_file.get_as_text()) == OK and time_json.data is Dictionary:
				day_count = maxi(1, int(time_json.data.get("current_day_offset", 0)) + 1)
			time_file.close()
	var current_stage := int(profile_data.get("current_stage", 1))
	var player_name := str(profile_data.get("player_name", "未命名")).strip_edges()
	if player_name == "":
		player_name = "未命名"
	var stage_title := "相识"
	if GameDataManager.profile != null:
		var stage_conf := GameDataManager.profile.get_stage_config(current_stage)
		if not stage_conf.is_empty():
			stage_title = str(stage_conf.get("stageTitle", stage_title))
	var last_played_at := _resolve_archive_last_played_at(slot_id, profile_path, time_path)
	return {
		"slot_id": slot_id,
		"archive_name": player_name,
		"player_name": player_name,
		"day_count": day_count,
		"stage": current_stage,
		"stage_title": stage_title,
		"last_played_at": last_played_at,
		"display_line_1": "与 Luna 相处第%d天" % day_count,
		"display_line_2": "%s & Luna  当前情感阶段：%s" % [player_name, stage_title],
		"display_line_3": "最后游玩：%s" % last_played_at
	}

func _archive_has_runtime_data(slot_id: String) -> bool:
	var profile_path: String = GameDataManager.get_character_save_path("character_profile.json", DEFAULT_CHARACTER_ID, slot_id)
	return FileAccess.file_exists(profile_path)

func _write_slot_meta(slot_id: String, meta: Dictionary) -> void:
	var meta_path := get_meta_path(slot_id)
	SafeFileAccess.store_string(meta_path, JSON.stringify(meta, "\t"))

func _get_now_text() -> String:
	var now := Time.get_datetime_dict_from_system()
	return "%04d/%02d/%02d %02d:%02d:%02d" % [
		int(now.get("year", 0)),
		int(now.get("month", 0)),
		int(now.get("day", 0)),
		int(now.get("hour", 0)),
		int(now.get("minute", 0)),
		int(now.get("second", 0))
	]

func _resolve_archive_last_played_at(slot_id: String, profile_path: String, time_path: String) -> String:
	var latest_unix := 0
	if FileAccess.file_exists(profile_path):
		latest_unix = maxi(latest_unix, int(FileAccess.get_modified_time(profile_path)))
	if FileAccess.file_exists(time_path):
		latest_unix = maxi(latest_unix, int(FileAccess.get_modified_time(time_path)))
	var meta_path := get_meta_path(slot_id)
	if FileAccess.file_exists(meta_path):
		latest_unix = maxi(latest_unix, int(FileAccess.get_modified_time(meta_path)))
	if latest_unix <= 0:
		return _get_now_text()
	return _format_unix_time(latest_unix)

func _format_unix_time(unix_time: int) -> String:
	var time_dict := Time.get_datetime_dict_from_unix_time(unix_time)
	return "%04d/%02d/%02d %02d:%02d:%02d" % [
		int(time_dict.get("year", 0)),
		int(time_dict.get("month", 0)),
		int(time_dict.get("day", 0)),
		int(time_dict.get("hour", 0)),
		int(time_dict.get("minute", 0)),
		int(time_dict.get("second", 0))
	]

func _remove_directory_recursive(dir_path: String) -> void:
	if not DirAccess.dir_exists_absolute(dir_path):
		return
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry == "." or entry == "..":
			entry = dir.get_next()
			continue
		var child_path := dir_path.path_join(entry)
		if dir.current_is_dir():
			_remove_directory_recursive(child_path)
			DirAccess.remove_absolute(child_path)
		else:
			DirAccess.remove_absolute(child_path)
		entry = dir.get_next()
	DirAccess.remove_absolute(dir_path)
