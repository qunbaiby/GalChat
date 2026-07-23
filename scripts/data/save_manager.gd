extends Node
class_name SaveManager

const SafeFileAccessUtil = preload("res://scripts/utils/safe_file_access.gd")
const DEFAULT_CHARACTER_ID := "luna"
const META_FILE_NAME := "meta.json"
const ACTIVE_STORY_STATE_FILE_NAME := "active_story_state.json"
const MAX_DISCOVERED_ARCHIVES := 300
const SAVE_SCHEMA_VERSION := 1
const SNAPSHOT_MANIFEST_SCHEMA := 1
const SNAPSHOT_DIR_NAME := ".generations"
const SNAPSHOT_DATA_DIR_NAME := "data"
const SNAPSHOT_MANIFEST_FILE_NAME := "generation_manifest.json"
const ARCHIVE_MANIFEST_FILE_NAME := "manifest.json"
const COMMIT_MARKER_FILE_NAME := "commit_in_progress.json"
const MAX_SNAPSHOT_GENERATIONS := 3

var current_slot_id: String = ""
var _exit_save_started: bool = false
var _save_in_progress: bool = false

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
	_save_active_archive_before_change(final_slot_id)
	delete_save(final_slot_id)
	GameDataManager.begin_archive_change(final_slot_id)
	GameDataManager.set_active_archive_id(final_slot_id, false)
	GameDataManager.clear_archive_custom_config(final_slot_id, false)
	current_slot_id = final_slot_id
	GameDataManager.config.reset_archive_settings()
	GameDataManager.config.current_character_id = DEFAULT_CHARACTER_ID
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
	if final_slot_id == "":
		return false
	if not recover_archive_if_interrupted(final_slot_id):
		return false
	if not _archive_has_runtime_data(final_slot_id):
		return false
	if final_slot_id == get_active_archive_id():
		return true
	_save_active_archive_before_change(final_slot_id)
	GameDataManager.begin_archive_change(final_slot_id)
	GameDataManager.set_active_archive_id(final_slot_id, false)
	current_slot_id = final_slot_id
	GameDataManager.reload_active_archive_data()
	update_active_archive_meta()
	return true

func _save_active_archive_before_change(target_slot_id: String) -> void:
	var active_slot := get_active_archive_id()
	if active_slot == "" or active_slot == target_slot_id:
		return
	if _archive_has_runtime_data(active_slot):
		auto_save("archive_switch", active_slot)

func load_game(slot_id: String) -> bool:
	return load_archive(slot_id)

func delete_save(slot_id: String) -> bool:
	var archive_root := _get_archive_root_path(slot_id)
	if not DirAccess.dir_exists_absolute(archive_root):
		GameDataManager.clear_archive_custom_config(slot_id)
		return false
	_remove_directory_recursive(archive_root)
	if DirAccess.dir_exists_absolute(archive_root):
		push_error("SaveManager 无法完整删除存档目录：%s" % archive_root)
		return false
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
	return auto_save("manual_save", target_slot)

func auto_save(reason: String = "auto", expected_archive_id: String = "") -> bool:
	if _save_in_progress:
		push_warning("SaveManager 拒绝重入存档请求：%s" % reason)
		return false
	var active_slot := get_active_archive_id()
	if active_slot == "":
		return false
	if expected_archive_id != "" and expected_archive_id != active_slot:
		push_warning("SaveManager 拒绝跨档存档请求：expected=%s active=%s reason=%s" % [expected_archive_id, active_slot, reason])
		return false
	var pointer := _read_archive_manifest(active_slot)
	var base_generation := int(pointer.get("generation", 0))
	var target_generation := base_generation + 1
	if not _write_commit_marker(active_slot, base_generation, target_generation, reason):
		return false
	_save_in_progress = true
	var flush_succeeded := _flush_runtime_state()
	_save_in_progress = false
	if not flush_succeeded:
		push_error("SaveManager 自动存档失败，未提交 meta：%s" % reason)
		return false
	var meta := _build_runtime_meta(active_slot)
	meta["schema_version"] = SAVE_SCHEMA_VERSION
	meta["save_generation"] = target_generation
	meta["save_reason"] = reason.strip_edges() if reason.strip_edges() != "" else "auto"
	if not _write_slot_meta(active_slot, meta):
		return false
	if not _publish_snapshot(active_slot, base_generation, target_generation, str(meta["save_reason"])):
		return false
	_remove_commit_marker(active_slot)
	_prune_snapshot_generations(active_slot)
	return true

func recover_archive_if_interrupted(slot_id: String) -> bool:
	var final_slot_id := slot_id.strip_edges()
	if final_slot_id == "":
		return true
	var archive_root := _get_archive_root_path(final_slot_id)
	var marker_path := archive_root.path_join(COMMIT_MARKER_FILE_NAME)
	var pointer := _read_archive_manifest(final_slot_id)
	var marker_exists := FileAccess.file_exists(marker_path)
	if not marker_exists:
		if pointer.is_empty():
			return true
		return not _validate_generation(final_slot_id, int(pointer.get("generation", 0))).is_empty()
	var generation := int(pointer.get("generation", 0))
	var generation_manifest := _validate_generation(final_slot_id, generation)
	if generation_manifest.is_empty():
		generation_manifest = _find_latest_valid_generation(final_slot_id)
	if generation_manifest.is_empty():
		push_error("SaveManager 找不到可恢复的完整快照：%s" % final_slot_id)
		return false
	if not _restore_generation_to_live(final_slot_id, generation_manifest):
		return false
	if generation != int(generation_manifest.get("generation", 0)):
		if not _write_archive_manifest(final_slot_id, generation_manifest):
			return false
	_remove_commit_marker(final_slot_id)
	_cleanup_staging_directories(final_slot_id)
	return true

func _write_commit_marker(slot_id: String, base_generation: int, target_generation: int, reason: String) -> bool:
	var marker := {
		"manifest_schema": SNAPSHOT_MANIFEST_SCHEMA,
		"archive_id": slot_id,
		"base_generation": base_generation,
		"target_generation": target_generation,
		"save_reason": reason,
		"started_at_unix": int(Time.get_unix_time_from_system())
	}
	return SafeFileAccessUtil.store_string(
		_get_archive_root_path(slot_id).path_join(COMMIT_MARKER_FILE_NAME),
		JSON.stringify(marker, "\t")
	)

func _remove_commit_marker(slot_id: String) -> void:
	var marker_path := _get_archive_root_path(slot_id).path_join(COMMIT_MARKER_FILE_NAME)
	if FileAccess.file_exists(marker_path):
		DirAccess.remove_absolute(marker_path)

func _publish_snapshot(slot_id: String, base_generation: int, generation: int, reason: String) -> bool:
	var archive_root := _get_archive_root_path(slot_id)
	var generations_root := archive_root.path_join(SNAPSHOT_DIR_NAME)
	if DirAccess.make_dir_recursive_absolute(generations_root) != OK and not DirAccess.dir_exists_absolute(generations_root):
		return false
	var staging_root := generations_root.path_join(".staging-gen-%08d" % generation)
	var final_root := generations_root.path_join("gen-%08d" % generation)
	_remove_directory_recursive(staging_root)
	if DirAccess.dir_exists_absolute(final_root):
		_remove_directory_recursive(final_root)
	var data_root := staging_root.path_join(SNAPSHOT_DATA_DIR_NAME)
	if DirAccess.make_dir_recursive_absolute(data_root) != OK:
		return false
	var relative_paths: PackedStringArray = []
	_collect_snapshot_files(archive_root, "", relative_paths)
	relative_paths.sort()
	var file_records: Array = []
	var total_bytes := 0
	for relative_path in relative_paths:
		var source_path := archive_root.path_join(relative_path)
		var destination_path := data_root.path_join(relative_path)
		var destination_dir := destination_path.get_base_dir()
		if DirAccess.make_dir_recursive_absolute(destination_dir) != OK and not DirAccess.dir_exists_absolute(destination_dir):
			return false
		if DirAccess.copy_absolute(source_path, destination_path) != OK:
			return false
		var file_size := int(FileAccess.get_size(destination_path))
		var file_hash := FileAccess.get_sha256(destination_path)
		if file_hash == "":
			return false
		total_bytes += file_size
		file_records.append({"path": relative_path, "size": file_size, "sha256": file_hash})
	var generation_manifest := {
		"manifest_schema": SNAPSHOT_MANIFEST_SCHEMA,
		"archive_schema": SAVE_SCHEMA_VERSION,
		"archive_id": slot_id,
		"generation": generation,
		"base_generation": base_generation,
		"created_at_unix": int(Time.get_unix_time_from_system()),
		"save_reason": reason,
		"file_count": file_records.size(),
		"total_bytes": total_bytes,
		"files": file_records
	}
	if not SafeFileAccessUtil.store_string(staging_root.path_join(SNAPSHOT_MANIFEST_FILE_NAME), JSON.stringify(generation_manifest, "\t")):
		return false
	if _validate_generation_directory(staging_root, generation_manifest).is_empty():
		return false
	if DirAccess.rename_absolute(staging_root, final_root) != OK:
		return false
	return _write_archive_manifest(slot_id, generation_manifest)

func _collect_snapshot_files(archive_root: String, relative_dir: String, output: PackedStringArray) -> void:
	var current_path := archive_root if relative_dir == "" else archive_root.path_join(relative_dir)
	var dir := DirAccess.open(current_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var relative_path := entry if relative_dir == "" else relative_dir.path_join(entry)
		if dir.current_is_dir():
			if _should_visit_snapshot_directory(relative_path):
				_collect_snapshot_files(archive_root, relative_path, output)
		elif _should_snapshot_file(relative_path):
			output.append(relative_path)
		entry = dir.get_next()
	dir.list_dir_end()

func _should_visit_snapshot_directory(relative_path: String) -> bool:
	var normalized := relative_path.replace("\\", "/")
	if normalized == SNAPSHOT_DIR_NAME or normalized.begins_with(SNAPSHOT_DIR_NAME + "/"):
		return false
	if normalized.contains("/date_drafts"):
		return false
	if normalized.ends_with("/photos"):
		return true
	return not normalized.get_file().begins_with(".")

func _should_snapshot_file(relative_path: String) -> bool:
	var normalized := relative_path.replace("\\", "/")
	var file_name := normalized.get_file()
	if file_name in [ARCHIVE_MANIFEST_FILE_NAME, COMMIT_MARKER_FILE_NAME, ACTIVE_STORY_STATE_FILE_NAME]:
		return false
	if file_name.ends_with(".tmp") or file_name.begins_with("."):
		return false
	if normalized.contains("/photos/") and file_name != "photo_metadata.json":
		return false
	return file_name.get_extension().to_lower() == "json"

func _write_archive_manifest(slot_id: String, generation_manifest: Dictionary) -> bool:
	var archive_root := _get_archive_root_path(slot_id)
	var generation := int(generation_manifest.get("generation", 0))
	var generation_dir := SNAPSHOT_DIR_NAME.path_join("gen-%08d" % generation)
	var generation_manifest_path := archive_root.path_join(generation_dir).path_join(SNAPSHOT_MANIFEST_FILE_NAME)
	var pointer := {
		"manifest_schema": SNAPSHOT_MANIFEST_SCHEMA,
		"archive_schema": SAVE_SCHEMA_VERSION,
		"archive_id": slot_id,
		"generation": generation,
		"generation_dir": generation_dir,
		"generation_manifest_sha256": FileAccess.get_sha256(generation_manifest_path),
		"committed_at_unix": int(Time.get_unix_time_from_system()),
		"save_reason": str(generation_manifest.get("save_reason", "auto")),
		"file_count": int(generation_manifest.get("file_count", 0)),
		"total_bytes": int(generation_manifest.get("total_bytes", 0))
	}
	var manifest_path := archive_root.path_join(ARCHIVE_MANIFEST_FILE_NAME)
	var temp_path := manifest_path + ".tmp"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(pointer, "\t"))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		DirAccess.remove_absolute(temp_path)
		return false
	var rename_error := DirAccess.rename_absolute(temp_path, manifest_path)
	if rename_error != OK:
		DirAccess.remove_absolute(temp_path)
		return false
	return true

func _read_archive_manifest(slot_id: String) -> Dictionary:
	var path := _get_archive_root_path(slot_id).path_join(ARCHIVE_MANIFEST_FILE_NAME)
	return _read_json_dictionary(path)

func _read_json_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var json := JSON.new()
	var parse_result := json.parse(file.get_as_text())
	file.close()
	return json.data if parse_result == OK and json.data is Dictionary else {}

func _validate_generation(slot_id: String, generation: int) -> Dictionary:
	if generation <= 0:
		return {}
	var generation_root := _get_archive_root_path(slot_id).path_join(SNAPSHOT_DIR_NAME).path_join("gen-%08d" % generation)
	var manifest := _read_json_dictionary(generation_root.path_join(SNAPSHOT_MANIFEST_FILE_NAME))
	if int(manifest.get("generation", 0)) != generation or str(manifest.get("archive_id", "")) != slot_id:
		return {}
	return _validate_generation_directory(generation_root, manifest)

func _validate_generation_directory(generation_root: String, manifest: Dictionary) -> Dictionary:
	var files: Variant = manifest.get("files", [])
	if not files is Array or int(manifest.get("file_count", -1)) != files.size():
		return {}
	var seen_paths: Dictionary = {}
	for raw_record in files:
		if not raw_record is Dictionary:
			return {}
		var relative_path := str(raw_record.get("path", "")).replace("\\", "/")
		if relative_path == "" or relative_path.begins_with("/") or relative_path.contains("..") or seen_paths.has(relative_path):
			return {}
		seen_paths[relative_path] = true
		var file_path := generation_root.path_join(SNAPSHOT_DATA_DIR_NAME).path_join(relative_path)
		if not FileAccess.file_exists(file_path):
			return {}
		if int(FileAccess.get_size(file_path)) != int(raw_record.get("size", -1)):
			return {}
		if FileAccess.get_sha256(file_path) != str(raw_record.get("sha256", "")):
			return {}
	return manifest

func _find_latest_valid_generation(slot_id: String) -> Dictionary:
	var generations_root := _get_archive_root_path(slot_id).path_join(SNAPSHOT_DIR_NAME)
	var dir := DirAccess.open(generations_root)
	if dir == null:
		return {}
	var generations: Array[int] = []
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir() and entry.begins_with("gen-"):
			generations.append(int(entry.trim_prefix("gen-")))
		entry = dir.get_next()
	dir.list_dir_end()
	generations.sort()
	generations.reverse()
	for generation in generations:
		var manifest := _validate_generation(slot_id, generation)
		if not manifest.is_empty():
			return manifest
	return {}

func _restore_generation_to_live(slot_id: String, manifest: Dictionary) -> bool:
	var archive_root := _get_archive_root_path(slot_id)
	var generation := int(manifest.get("generation", 0))
	var data_root := archive_root.path_join(SNAPSHOT_DIR_NAME).path_join("gen-%08d" % generation).path_join(SNAPSHOT_DATA_DIR_NAME)
	var expected_paths: Dictionary = {}
	for raw_record in manifest.get("files", []):
		expected_paths[str(raw_record.get("path", "")).replace("\\", "/")] = true
	var live_paths: PackedStringArray = []
	_collect_snapshot_files(archive_root, "", live_paths)
	for live_relative_path in live_paths:
		if not expected_paths.has(live_relative_path.replace("\\", "/")):
			if DirAccess.remove_absolute(archive_root.path_join(live_relative_path)) != OK:
				return false
	for raw_record in manifest.get("files", []):
		var relative_path := str(raw_record.get("path", ""))
		var destination_path := archive_root.path_join(relative_path)
		var destination_dir := destination_path.get_base_dir()
		if DirAccess.make_dir_recursive_absolute(destination_dir) != OK and not DirAccess.dir_exists_absolute(destination_dir):
			return false
		if DirAccess.copy_absolute(data_root.path_join(relative_path), destination_path) != OK:
			return false
	return true

func _prune_snapshot_generations(slot_id: String) -> void:
	var generations_root := _get_archive_root_path(slot_id).path_join(SNAPSHOT_DIR_NAME)
	var dir := DirAccess.open(generations_root)
	if dir == null:
		return
	var entries: Array[String] = []
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir() and entry.begins_with("gen-"):
			entries.append(entry)
		entry = dir.get_next()
	dir.list_dir_end()
	entries.sort()
	while entries.size() > MAX_SNAPSHOT_GENERATIONS:
		_remove_directory_recursive(generations_root.path_join(entries.pop_front()))

func _cleanup_staging_directories(slot_id: String) -> void:
	var generations_root := _get_archive_root_path(slot_id).path_join(SNAPSHOT_DIR_NAME)
	var dir := DirAccess.open(generations_root)
	if dir == null:
		return
	var staging_entries: Array[String] = []
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir() and entry.begins_with(".staging-"):
			staging_entries.append(entry)
		entry = dir.get_next()
	dir.list_dir_end()
	for staging_entry in staging_entries:
		_remove_directory_recursive(generations_root.path_join(staging_entry))

func save_before_exit() -> bool:
	if _exit_save_started:
		return true
	_exit_save_started = true
	var active_slot := get_active_archive_id()
	if active_slot == "" or not _archive_has_runtime_data(active_slot):
		return true
	var succeeded := auto_save("application_exit", active_slot)
	if not succeeded:
		_exit_save_started = false
	return succeeded

func update_active_archive_meta() -> void:
	var active_slot := get_active_archive_id()
	if active_slot == "":
		return
	_write_slot_meta(active_slot, _build_runtime_meta(active_slot))

func _flush_runtime_state() -> bool:
	var all_succeeded := true
	if GameDataManager.profile != null:
		if not _call_save_method(GameDataManager.profile, "save_profile"):
			all_succeeded = false
		GameDataManager.sync_profile_to_config()
	if GameDataManager.history != null:
		if not _call_save_method(GameDataManager.history, "save_history"):
			all_succeeded = false
	if GameDataManager.npc_relationship_manager != null:
		if not _call_save_method(GameDataManager.npc_relationship_manager, "save_relationships"):
			all_succeeded = false
	if GameDataManager.memory_manager != null:
		if not _call_save_method(GameDataManager.memory_manager, "save_memory"):
			all_succeeded = false
	if GameDataManager.desktop_pet_memory_manager != null:
		if not _call_save_method(GameDataManager.desktop_pet_memory_manager, "save_memory"):
			all_succeeded = false
	if GameDataManager.story_memory_manager != null:
		if not _call_save_method(GameDataManager.story_memory_manager, "save_memory"):
			all_succeeded = false
	if GameDataManager.story_time_manager != null:
		if not _call_save_method(GameDataManager.story_time_manager, "save_data"):
			all_succeeded = false
	if GameDataManager.gift_manager != null and GameDataManager.gift_manager.has_method("save_state"):
		if not _call_save_method(GameDataManager.gift_manager, "save_state"):
			all_succeeded = false
	if GameDataManager.has_method("save_pomodoro_data"):
		if not _call_save_method(GameDataManager, "save_pomodoro_data"):
			all_succeeded = false
	if is_instance_valid(MomentsManager) and MomentsManager.has_method("save_data"):
		if not _call_save_method(MomentsManager, "save_data"):
			all_succeeded = false
	if not _flush_node_state("/root/GoalManager", "_save_state"):
		all_succeeded = false
	if not _flush_node_state("/root/MainChatTopicManager", "_save_state"):
		all_succeeded = false
	if not _flush_node_state("/root/StoryPostEventManager", "_save_state"):
		all_succeeded = false
	if not _flush_node_state("/root/GuideManager", "_save_state"):
		all_succeeded = false
	if not _flush_node_state("/root/MobileFixedChatManager", "_save_states"):
		all_succeeded = false
	if not _flush_node_state("/root/MemoryAlbumManager", "_save_state"):
		all_succeeded = false
	if is_instance_valid(MapDataManager) and MapDataManager.has_method("_save_entry_trigger_history"):
		if not _call_save_method(MapDataManager, "_save_entry_trigger_history"):
			all_succeeded = false
	var event_manager = get_node_or_null("/root/EventManager")
	if event_manager and event_manager.has_method("_save_triggered_events"):
		if not _call_save_method(event_manager, "_save_triggered_events"):
			all_succeeded = false
	if GameDataManager.config:
		if not _call_save_method(GameDataManager.config, "save_config"):
			all_succeeded = false
	return all_succeeded

func _call_save_method(target: Object, method_name: String) -> bool:
	if target == null or not target.has_method(method_name):
		return false
	var result: Variant = target.call(method_name)
	return result is bool and bool(result)

func _flush_node_state(node_path: String, method_name: String) -> bool:
	var manager := get_node_or_null(node_path)
	if manager == null:
		return true
	return _call_save_method(manager, method_name)

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
		"schema_version": SAVE_SCHEMA_VERSION,
		"save_generation": int(existing_meta.get("save_generation", 0)),
		"save_reason": str(existing_meta.get("save_reason", "auto")),
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
		"schema_version": SAVE_SCHEMA_VERSION,
		"save_generation": 0,
		"save_reason": "archive_created",
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

func _write_slot_meta(slot_id: String, meta: Dictionary) -> bool:
	var meta_path := get_meta_path(slot_id)
	return SafeFileAccessUtil.store_string(meta_path, JSON.stringify(meta, "\t"))

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
