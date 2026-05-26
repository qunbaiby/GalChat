class_name PhotoMemoryManager
extends RefCounted

const SafeFileAccess = preload("res://scripts/utils/safe_file_access.gd")

const LEGACY_GLOBAL_PHOTO_DIR := "user://saves/photos"
const LEGACY_GLOBAL_METADATA_FILE := "user://saves/photos/photo_metadata.json"
const PHOTO_SUBDIR := "photos"
const METADATA_FILE_NAME := "photo_metadata.json"
const STORY_SCRIPT_DIR := "res://assets/data/story/scripts"

const CATEGORY_ALL := "all"
const CATEGORY_CAMERA := "camera"
const CATEGORY_CHAT := "chat"
const CATEGORY_CG := "cg"
const CATEGORY_DIARY := "diary"
const CATEGORY_MOMENT := "moment"
const CATEGORY_DRAWING := "drawing"
const CATEGORY_OTHER := "other"

func register_photo(photo_path: String, source_type: String, extra: Dictionary = {}) -> Dictionary:
	if photo_path == "":
		return {}
	var all_data = _load_all_metadata()
	var record_key = photo_path
	var context = _resolve_context(extra)
	var related = _find_related_memory(context, extra)
	var previous = _get_existing_record(all_data, photo_path)
	var allow_update_existing = bool(extra.get("allow_update_existing", false))
	if not previous.is_empty() and not allow_update_existing:
		return _enrich_record(previous, str(previous.get("record_key", photo_path)))
	var saved_at = str(previous.get("saved_at", Time.get_datetime_string_from_system()))
	var album_category = _resolve_album_category(source_type, extra)
	var source_label = _resolve_source_label(source_type)
	var record = {
		"record_key": record_key,
		"photo_path": photo_path,
		"file_name": photo_path.get_file(),
		"saved_at": saved_at,
		"source_type": source_type,
		"album_category": album_category,
		"source_label": source_label,
		"source_title": str(extra.get("source_title", "")),
		"source_text": str(extra.get("source_text", "")),
		"source_id": str(extra.get("source_id", "")),
		"char_id": _get_current_char_id(),
		"context_domain": str(context.get("context_domain", "story")),
		"story_time": str(context.get("story_time", "")),
		"day_offset": int(context.get("day_offset", 0)),
		"story_period": str(context.get("story_period", "")),
		"story_weather": str(context.get("story_weather", "")),
		"story_location_id": str(context.get("story_location_id", "")),
		"story_area_id": str(context.get("story_area_id", "")),
		"real_date": str(context.get("real_date", "")),
		"real_period": str(context.get("real_period", "")),
		"real_weather": str(context.get("real_weather", "")),
		"related_memory_id": str(related.get("memory_id", "")),
		"related_memory_layer": str(related.get("layer", "")),
		"related_memory_content": str(related.get("content", "")),
		"related_memory_title": str(related.get("title", "")),
		"relation_reason": str(related.get("reason", "")),
		"origin_path": str(extra.get("origin_path", "")),
		"origin_message_text": str(extra.get("origin_message_text", "")),
		"source_char_id": str(extra.get("source_char_id", _get_current_char_id())),
		"story_id": str(extra.get("story_id", "")),
		"cg_id": str(extra.get("cg_id", "")),
		"prompt": str(extra.get("prompt", ""))
	}
	all_data[record_key] = record
	var legacy_key = photo_path.get_file()
	if legacy_key != record_key and all_data.has(legacy_key):
		all_data.erase(legacy_key)
	_save_all_metadata(all_data)
	return _enrich_record(record, record_key)

func get_photo_dir() -> String:
	var char_id = _get_current_char_id()
	return "user://saves/%s/%s" % [char_id, PHOTO_SUBDIR]

func get_metadata_file() -> String:
	return get_photo_dir().path_join(METADATA_FILE_NAME)

func get_photo_record(photo_path: String) -> Dictionary:
	if photo_path == "":
		return {}
	var all_data = _load_all_metadata()
	var record = _get_existing_record(all_data, photo_path)
	return _enrich_record(record, photo_path)

func get_all_photo_records() -> Dictionary:
	sync_album_sources()
	var all_data = _load_all_metadata()
	var result: Dictionary = {}
	for key in all_data.keys():
		var record = all_data[key]
		if record is Dictionary:
			result[str(key)] = _enrich_record(record, str(key))
	return result

func get_album_records(category: String = CATEGORY_ALL) -> Array:
	sync_album_sources()
	var all_data = _load_all_metadata()
	var current_char_id = _get_current_char_id()
	var result: Array = []
	for key in all_data.keys():
		var raw_record = all_data[key]
		if not raw_record is Dictionary:
			continue
		var record = _enrich_record(raw_record, str(key))
		if not _is_record_visible_for_char(record, current_char_id):
			continue
		if category != CATEGORY_ALL and str(record.get("album_category", CATEGORY_OTHER)) != category:
			continue
		var path = str(record.get("photo_path", ""))
		if not _path_exists(path):
			continue
		result.append(record)
	result.sort_custom(func(a, b): return _build_record_sort_value(a) > _build_record_sort_value(b))
	return result

func get_album_summary(records: Array = []) -> Dictionary:
	var source_records = records
	if source_records.is_empty():
		source_records = get_album_records()
	var summary := {
		"total": source_records.size(),
		CATEGORY_CAMERA: 0,
		CATEGORY_CHAT: 0,
		CATEGORY_CG: 0,
		CATEGORY_DIARY: 0,
		CATEGORY_MOMENT: 0,
		CATEGORY_DRAWING: 0,
		CATEGORY_OTHER: 0
	}
	for record in source_records:
		var category = str(record.get("album_category", CATEGORY_OTHER))
		if not summary.has(category):
			summary[category] = 0
		summary[category] += 1
	return summary

func sync_album_sources() -> void:
	_sync_local_photo_library()
	_sync_diary_sources()
	_sync_moment_sources()
	_sync_story_cg_sources()

func _resolve_context(extra: Dictionary) -> Dictionary:
	if extra.has("memory_context") and extra["memory_context"] is Dictionary:
		return extra["memory_context"]
	if GameDataManager.memory_manager:
		if bool(extra.get("prefer_reality", false)):
			return GameDataManager.memory_manager.build_reality_memory_context()
		return GameDataManager.memory_manager.build_story_memory_context()
	return {}

func _find_related_memory(context: Dictionary, extra: Dictionary) -> Dictionary:
	if GameDataManager.memory_manager == null:
		return {}
	var candidates: Array = []
	var preferred_layers = extra.get("preferred_layers", ["bond", "emotion", "habit"])
	if not preferred_layers is Array:
		preferred_layers = ["bond", "emotion", "habit"]
	for layer in preferred_layers:
		var layer_items = GameDataManager.memory_manager.memories.get(str(layer), [])
		for mem in layer_items:
			if not mem is Dictionary:
				continue
			var content = str(mem.get("content", "")).strip_edges()
			if content == "":
				continue
			var score = _score_memory_binding(mem, str(layer), context)
			if score <= 0.0:
				continue
			candidates.append({
				"layer": str(layer),
				"memory_id": str(mem.get("id", "")),
				"content": content,
				"title": _memory_layer_title(str(layer)),
				"score": score,
				"reason": _build_relation_reason(mem, context)
			})
	if candidates.is_empty():
		return {}
	candidates.sort_custom(func(a, b): return float(a.get("score", 0.0)) > float(b.get("score", 0.0)))
	return candidates[0]

func _score_memory_binding(mem: Dictionary, layer: String, context: Dictionary) -> float:
	var score = 0.0
	match layer:
		"bond":
			score += 80.0
		"emotion":
			score += 45.0
		"habit":
			score += 30.0
		_:
			score += 10.0
	if bool(mem.get("is_bond_mark", false)):
		score += 40.0
	score += max(0.0, 20.0 - float(mem.get("decay", 0.0)) * 0.2)
	var context_domain = str(context.get("context_domain", "story"))
	var mem_domain = str(mem.get("context_domain", "unknown"))
	if context_domain != "" and mem_domain == context_domain:
		score += 35.0
	elif mem_domain != "unknown" and context_domain != mem_domain:
		score -= 30.0
	if context_domain == "story":
		if str(context.get("story_location_id", "")) != "" and str(mem.get("story_location_id", "")) == str(context.get("story_location_id", "")):
			score += 45.0
		if str(context.get("story_weather", "")) != "" and str(mem.get("story_weather", "")) == str(context.get("story_weather", "")):
			score += 18.0
		if str(context.get("story_period", "")) != "" and str(mem.get("story_period", "")) == str(context.get("story_period", "")):
			score += 14.0
		var day_gap = abs(int(context.get("day_offset", 0)) - int(mem.get("day_offset", 0)))
		score += max(0.0, 18.0 - float(day_gap) * 6.0)
	else:
		if str(context.get("real_weather", "")) != "" and str(mem.get("real_weather", "")) == str(context.get("real_weather", "")):
			score += 18.0
		if str(context.get("real_period", "")) != "" and str(mem.get("real_period", "")) == str(context.get("real_period", "")):
			score += 16.0
	return score

func _build_relation_reason(mem: Dictionary, context: Dictionary) -> String:
	var context_domain = str(context.get("context_domain", "story"))
	if context_domain == "story":
		if str(context.get("story_location_id", "")) != "" and str(mem.get("story_location_id", "")) == str(context.get("story_location_id", "")):
			return "同地点回忆"
		if str(context.get("story_weather", "")) != "" and str(mem.get("story_weather", "")) == str(context.get("story_weather", "")):
			return "同天气回忆"
		if str(context.get("story_period", "")) != "" and str(mem.get("story_period", "")) == str(context.get("story_period", "")):
			return "同时段回忆"
		return "剧情语境接近"
	if str(context.get("real_weather", "")) != "" and str(mem.get("real_weather", "")) == str(context.get("real_weather", "")):
		return "同现实天气回忆"
	if str(context.get("real_period", "")) != "" and str(mem.get("real_period", "")) == str(context.get("real_period", "")):
		return "同现实时段回忆"
	return "现实语境接近"

func _memory_layer_title(layer: String) -> String:
	match layer:
		"bond":
			return "共同经历"
		"emotion":
			return "情绪记忆"
		"habit":
			return "习惯印象"
		_:
			return "关联回忆"

func _get_current_char_id() -> String:
	if GameDataManager.profile and str(GameDataManager.profile.current_character_id) != "":
		return str(GameDataManager.profile.current_character_id)
	if GameDataManager.config and str(GameDataManager.config.current_character_id) != "":
		return str(GameDataManager.config.current_character_id)
	return "default"

func _resolve_album_category(source_type: String, extra: Dictionary) -> String:
	if str(extra.get("album_category", "")).strip_edges() != "":
		return str(extra.get("album_category", "")).strip_edges()
	match source_type:
		"camera_capture":
			return CATEGORY_CAMERA
		"chat_image":
			return CATEGORY_CHAT
		"story_cg":
			return CATEGORY_CG
		"diary_image":
			return CATEGORY_DIARY
		"moment_image":
			return CATEGORY_MOMENT
		"drawing_image":
			return CATEGORY_DRAWING
		_:
			return CATEGORY_OTHER

func _resolve_source_label(source_type: String) -> String:
	match source_type:
		"camera_capture":
			return "手机拍摄"
		"chat_image":
			return "聊天保存"
		"story_cg":
			return "剧情CG"
		"diary_image":
			return "日记配图"
		"moment_image":
			return "朋友圈配图"
		"drawing_image":
			return "绘画生成"
		_:
			return "相册收录"

func _get_existing_record(all_data: Dictionary, photo_path: String) -> Dictionary:
	if all_data.has(photo_path) and all_data[photo_path] is Dictionary:
		return all_data[photo_path]
	var legacy_key = photo_path.get_file()
	if all_data.has(legacy_key) and all_data[legacy_key] is Dictionary:
		return all_data[legacy_key]
	return {}

func _enrich_record(record: Dictionary, record_key: String = "") -> Dictionary:
	if record.is_empty():
		return {}
	var result = record.duplicate(true)
	if str(result.get("record_key", "")).strip_edges() == "":
		result["record_key"] = record_key if record_key != "" else str(result.get("photo_path", ""))
	if str(result.get("album_category", "")).strip_edges() == "":
		result["album_category"] = _resolve_album_category(str(result.get("source_type", "")), result)
	if str(result.get("source_label", "")).strip_edges() == "":
		result["source_label"] = _resolve_source_label(str(result.get("source_type", "")))
	if str(result.get("source_title", "")).strip_edges() == "":
		result["source_title"] = str(result.get("source_label", "相册收录"))
	if str(result.get("source_char_id", "")).strip_edges() == "":
		result["source_char_id"] = str(result.get("char_id", ""))
	return result

func _is_record_visible_for_char(record: Dictionary, current_char_id: String) -> bool:
	var record_char_id = str(record.get("source_char_id", record.get("char_id", ""))).strip_edges()
	if current_char_id == "" or record_char_id == "":
		return true
	return current_char_id == record_char_id

func _path_exists(path: String) -> bool:
	if path == "":
		return false
	if path.begins_with("res://"):
		return ResourceLoader.exists(path)
	return FileAccess.file_exists(path)

func _build_record_sort_value(record: Dictionary) -> int:
	var saved_at = str(record.get("saved_at", ""))
	var digits := ""
	for c in saved_at:
		if c >= "0" and c <= "9":
			digits += c
	if digits != "":
		return int(digits)
	var file_name = str(record.get("file_name", ""))
	for c in file_name:
		if c >= "0" and c <= "9":
			digits += c
	if digits != "":
		return int(digits)
	return 0

func _should_skip_default_path(path: String) -> bool:
	if path.strip_edges() == "":
		return true
	if GameDataManager.config and str(GameDataManager.config.default_image_path) == path:
		return true
	return false

func _build_story_context(base_time: String = "", weather: String = "") -> Dictionary:
	var context = GameDataManager.memory_manager.build_story_memory_context() if GameDataManager.memory_manager else {}
	context["context_domain"] = "story"
	if base_time != "":
		context["story_time"] = base_time
	if weather != "":
		context["story_weather"] = weather
	return context

func _sync_diary_sources() -> void:
	if GameDataManager.profile == null or not GameDataManager.profile.has_method("get_diaries"):
		return
	for diary in GameDataManager.profile.get_diaries():
		if not diary is Dictionary:
			continue
		var diary_id = str(diary.get("id", diary.get("date", "")))
		var content = str(diary.get("content", "")).strip_edges()
		var image_paths: Array = []
		if diary.has("images") and diary["images"] is Array:
			for path in diary["images"]:
				if typeof(path) == TYPE_STRING:
					image_paths.append(str(path))
		if str(diary.get("image_url", "")).strip_edges() != "":
			image_paths.append(str(diary.get("image_url", "")))
		var context = _build_story_context(str(diary.get("date", "")), str(diary.get("weather", "")))
		for image_path in image_paths:
			if _should_skip_default_path(image_path):
				continue
			register_photo(image_path, "diary_image", {
				"album_category": CATEGORY_DIARY,
				"memory_context": context,
				"preferred_layers": ["bond", "emotion"],
				"source_title": "她写下的一页心情",
				"source_text": content,
				"source_id": diary_id,
				"source_char_id": _get_current_char_id()
			})

func _sync_local_photo_library() -> void:
	var photo_dir = get_photo_dir()
	if not DirAccess.dir_exists_absolute(photo_dir):
		return
	var dir = DirAccess.open(photo_dir)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			var lower_name = file_name.to_lower()
			if lower_name.ends_with(".png") or lower_name.ends_with(".jpg") or lower_name.ends_with(".jpeg") or lower_name.ends_with(".webp"):
				var path = photo_dir.path_join(file_name)
				var source_type = "chat_image" if file_name.begins_with("char_img_") else "camera_capture"
				register_photo(path, source_type, {
					"album_category": _resolve_album_category(source_type, {}),
					"memory_context": GameDataManager.memory_manager.build_story_memory_context() if GameDataManager.memory_manager else {},
					"preferred_layers": ["bond", "emotion", "habit"],
					"source_char_id": _get_current_char_id()
				})
		file_name = dir.get_next()

func _sync_moment_sources() -> void:
	if typeof(MomentsManager) == TYPE_NIL:
		return
	var current_char_name = GameDataManager.profile.char_name if GameDataManager.profile else ""
	for moment in MomentsManager.get_all_moments():
		if not moment is Dictionary:
			continue
		var author = str(moment.get("author", ""))
		if current_char_name != "" and author != "" and author != current_char_name:
			continue
		var images = moment.get("images", [])
		if not images is Array:
			continue
		var context = _build_story_context(str(moment.get("time", "")))
		for image_path in images:
			if typeof(image_path) != TYPE_STRING or _should_skip_default_path(str(image_path)):
				continue
			register_photo(str(image_path), "moment_image", {
				"album_category": CATEGORY_MOMENT,
				"memory_context": context,
				"preferred_layers": ["bond", "emotion"],
				"source_title": "她分享过的瞬间",
				"source_text": str(moment.get("content", "")),
				"source_id": str(moment.get("id", "")),
				"source_char_id": _get_current_char_id()
			})

func _sync_story_cg_sources() -> void:
	if GameDataManager.profile == null:
		return
	for story_id in GameDataManager.profile.finished_stories:
		var story_id_text = str(story_id)
		if story_id_text == "":
			continue
		var story_data = _load_story_data(story_id_text)
		if story_data.is_empty():
			continue
		var summary = str(story_data.get("summary", "")).strip_edges()
		for cg_id in _extract_story_cg_ids(story_data):
			var image_path = ImageManager.get_image_path(cg_id) if typeof(ImageManager) != TYPE_NIL else ""
			if image_path == "" or not _path_exists(image_path):
				continue
			register_photo(image_path, "story_cg", {
				"album_category": CATEGORY_CG,
				"memory_context": _build_story_context(story_id_text),
				"preferred_layers": ["bond", "emotion"],
				"source_title": "剧情CG · %s" % story_id_text,
				"source_text": summary,
				"source_id": story_id_text,
				"story_id": story_id_text,
				"cg_id": cg_id,
				"source_char_id": _get_current_char_id()
			})

func _load_story_data(story_id: String) -> Dictionary:
	var path = _find_story_script_path(story_id, STORY_SCRIPT_DIR)
	if path == "":
		return {}
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var json = JSON.new()
	var result = json.parse(file.get_as_text())
	file.close()
	if result != OK or not json.data is Dictionary:
		return {}
	return json.data

func _find_story_script_path(story_id: String, dir_path: String) -> String:
	var dir = DirAccess.open(dir_path)
	if dir == null:
		return ""
	dir.list_dir_begin()
	var entry = dir.get_next()
	while entry != "":
		if dir.current_is_dir():
			if entry != "." and entry != "..":
				var child_result = _find_story_script_path(story_id, dir_path.path_join(entry))
				if child_result != "":
					return child_result
		elif entry.ends_with(".json") and entry.replace(".json", "") == story_id:
			return dir_path.path_join(entry)
		entry = dir.get_next()
	return ""

func _extract_story_cg_ids(story_data: Dictionary) -> Array:
	var cg_ids: Array = []
	var cover_image = str(story_data.get("cover_image", "")).strip_edges()
	if cover_image.begins_with("story_cg_") and not cg_ids.has(cover_image):
		cg_ids.append(cover_image)
	var chapters = story_data.get("chapters", {})
	if chapters is Dictionary:
		for chapter in chapters.values():
			if not chapter is Dictionary:
				continue
			var events = chapter.get("events", [])
			if not events is Array:
				continue
			for event in events:
				if not event is Dictionary:
					continue
				var bg_id = str(event.get("bg_id", "")).strip_edges()
				if bg_id.begins_with("story_cg_") and not cg_ids.has(bg_id):
					cg_ids.append(bg_id)
	return cg_ids

func _load_all_metadata() -> Dictionary:
	var photo_dir = get_photo_dir()
	if not DirAccess.dir_exists_absolute(photo_dir):
		DirAccess.make_dir_recursive_absolute(photo_dir)
	var metadata_file = get_metadata_file()
	if not FileAccess.file_exists(metadata_file):
		_migrate_legacy_global_photo_storage()
	if not FileAccess.file_exists(metadata_file):
		return {}
	var file = FileAccess.open(metadata_file, FileAccess.READ)
	if file == null:
		return {}
	var content = file.get_as_text()
	file.close()
	var json = JSON.new()
	if json.parse(content) != OK:
		return {}
	var data = json.get_data()
	return data if data is Dictionary else {}

func _save_all_metadata(all_data: Dictionary) -> void:
	var photo_dir = get_photo_dir()
	if not DirAccess.dir_exists_absolute(photo_dir):
		DirAccess.make_dir_recursive_absolute(photo_dir)
	SafeFileAccess.store_string(get_metadata_file(), JSON.stringify(all_data, "\t"))

func _migrate_legacy_global_photo_storage() -> void:
	var metadata_file = get_metadata_file()
	if FileAccess.file_exists(metadata_file) or not FileAccess.file_exists(LEGACY_GLOBAL_METADATA_FILE):
		return
	var legacy_file = FileAccess.open(LEGACY_GLOBAL_METADATA_FILE, FileAccess.READ)
	if legacy_file == null:
		return
	var legacy_content = legacy_file.get_as_text()
	legacy_file.close()
	var json = JSON.new()
	if json.parse(legacy_content) != OK or not json.data is Dictionary:
		return
	var current_char_id = _get_current_char_id()
	var migrated: Dictionary = {}
	var target_dir = get_photo_dir()
	if not DirAccess.dir_exists_absolute(target_dir):
		DirAccess.make_dir_recursive_absolute(target_dir)
	var target_dir_access = DirAccess.open(target_dir)
	if target_dir_access == null:
		return
	for legacy_key in json.data.keys():
		var raw_record = json.data[legacy_key]
		if not raw_record is Dictionary:
			continue
		var record = _enrich_record(raw_record, str(legacy_key))
		if not _is_record_visible_for_char(record, current_char_id):
			continue
		var migrated_record = record.duplicate(true)
		var old_path = str(migrated_record.get("photo_path", ""))
		if old_path.begins_with(LEGACY_GLOBAL_PHOTO_DIR):
			var new_path = target_dir.path_join(old_path.get_file())
			if FileAccess.file_exists(old_path) and not FileAccess.file_exists(new_path):
				target_dir_access.copy(old_path, new_path)
			migrated_record["photo_path"] = new_path
			migrated_record["record_key"] = new_path
			migrated[str(new_path)] = migrated_record
		else:
			migrated[str(migrated_record.get("record_key", old_path))] = migrated_record
	if not migrated.is_empty():
		_save_all_metadata(migrated)
