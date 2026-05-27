class_name MemoryAlbumManager
extends RefCounted

const SafeFileAccess = preload("res://scripts/utils/safe_file_access.gd")
const PhotoMemoryManagerScript = preload("res://scripts/data/photo_memory_manager.gd")
const MAP_DATA_PATH := "res://assets/data/map/core/map_data.json"

const MAX_MEMORY_ENTRIES := 12
const MAX_DIARY_ENTRIES := 8
const MAX_MOMENT_ENTRIES := 8
const MAX_PHOTO_ENTRIES := 8
const ALBUM_TARGET_CHAR_ID := "luna"

const CATEGORY_MILESTONE := "milestone"
const STATE_FILE_NAME := "memory_album_state.json"
const PIN_BONUS := 40000000000
const MILESTONE_BONUS := 20000000000
const UNVIEWED_BONUS := 5000000000
const FAVORITE_BONUS := 2000000000

var _state_loaded := false
var _loaded_char_id := ""
var _state: Dictionary = _create_default_state()
var _location_name_cache: Dictionary = {}

func build_entries() -> Array:
	_ensure_state_loaded()
	if not _is_target_album_character():
		return []
	var entries: Array = []
	entries.append_array(_build_stage_milestones())
	entries.append_array(_build_memory_entries())
	entries.append_array(_build_diary_entries())
	entries.append_array(_build_moment_entries())
	entries.append_array(_build_photo_entries())
	for i in range(entries.size()):
		entries[i] = _apply_entry_state(entries[i])
	entries.sort_custom(func(a, b): return int(a.get("display_sort", 0)) > int(b.get("display_sort", 0)))
	return entries

func _is_target_album_character() -> bool:
	var current_char_id = _get_current_char_id().to_lower()
	if current_char_id == ALBUM_TARGET_CHAR_ID:
		return true
	if GameDataManager.profile and str(GameDataManager.profile.char_name).strip_edges().to_lower() == "luna":
		return true
	return false

func get_summary(entries: Array) -> Dictionary:
	var summary := {
		"total": entries.size(),
		"milestone": 0,
		"memory": 0,
		"diary": 0,
		"moment": 0,
		"photo": 0,
		"favorite": 0,
		"pinned": 0,
		"unviewed": 0
	}
	for entry in entries:
		var category = str(entry.get("category", ""))
		if summary.has(category):
			summary[category] += 1
		if bool(entry.get("is_favorite", false)):
			summary["favorite"] += 1
		if bool(entry.get("is_pinned", false)):
			summary["pinned"] += 1
		if not bool(entry.get("is_viewed", false)):
			summary["unviewed"] += 1
	return summary

func toggle_favorite(entry_id: String) -> bool:
	_ensure_state_loaded()
	var favorites: Array = _state.get("favorite_ids", [])
	if favorites.has(entry_id):
		favorites.erase(entry_id)
	else:
		favorites.append(entry_id)
	_state["favorite_ids"] = favorites
	_save_state()
	return favorites.has(entry_id)

func toggle_pinned(entry_id: String) -> bool:
	_ensure_state_loaded()
	var pinned: Array = _state.get("pinned_ids", [])
	if pinned.has(entry_id):
		pinned.erase(entry_id)
	else:
		pinned.erase(entry_id)
		pinned.insert(0, entry_id)
	_state["pinned_ids"] = pinned
	_save_state()
	return pinned.has(entry_id)

func mark_viewed(entry_id: String) -> void:
	_ensure_state_loaded()
	var viewed: Array = _state.get("viewed_ids", [])
	if viewed.has(entry_id):
		return
	viewed.append(entry_id)
	_state["viewed_ids"] = viewed
	_save_state()

func is_favorite(entry_id: String) -> bool:
	_ensure_state_loaded()
	return _state.get("favorite_ids", []).has(entry_id)

func is_pinned(entry_id: String) -> bool:
	_ensure_state_loaded()
	return _state.get("pinned_ids", []).has(entry_id)

func is_viewed(entry_id: String) -> bool:
	_ensure_state_loaded()
	return _state.get("viewed_ids", []).has(entry_id)

func _create_default_state() -> Dictionary:
	return {
		"favorite_ids": [],
		"pinned_ids": [],
		"viewed_ids": [],
		"custom_titles": {}
	}

func _ensure_state_loaded() -> void:
	var current_char_id = _get_current_char_id()
	if not _state_loaded or current_char_id != _loaded_char_id:
		_load_state()

func _get_current_char_id() -> String:
	if GameDataManager.profile and str(GameDataManager.profile.current_character_id) != "":
		return str(GameDataManager.profile.current_character_id)
	if GameDataManager.config and str(GameDataManager.config.current_character_id) != "":
		return str(GameDataManager.config.current_character_id)
	return "default"

func _get_state_path() -> String:
	var char_id = _get_current_char_id()
	var dir_path = "user://saves/%s" % char_id
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)
	return "%s/%s" % [dir_path, STATE_FILE_NAME]

func _load_state() -> void:
	_state_loaded = true
	_loaded_char_id = _get_current_char_id()
	_state = _create_default_state()
	var path = _get_state_path()
	if not FileAccess.file_exists(path):
		return
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var content = file.get_as_text()
	file.close()
	var json = JSON.new()
	if json.parse(content) != OK:
		return
	var data = json.get_data()
	if data is Dictionary:
		_state["favorite_ids"] = data.get("favorite_ids", [])
		_state["pinned_ids"] = data.get("pinned_ids", [])
		_state["viewed_ids"] = data.get("viewed_ids", [])
		_state["custom_titles"] = data.get("custom_titles", {})

func _save_state() -> void:
	SafeFileAccess.store_string(_get_state_path(), JSON.stringify(_state, "\t"))

func _apply_entry_state(entry: Dictionary) -> Dictionary:
	var result = entry.duplicate(true)
	var entry_id = str(result.get("id", ""))
	var custom_titles: Dictionary = _state.get("custom_titles", {})
	if custom_titles.has(entry_id):
		result["title"] = str(custom_titles[entry_id])
	result["is_favorite"] = is_favorite(entry_id)
	result["is_pinned"] = is_pinned(entry_id)
	result["is_viewed"] = is_viewed(entry_id)
	result["is_new"] = not bool(result.get("is_viewed", false))
	if bool(result.get("is_pinned", false)) and not result.get("tags", []).has("置顶"):
		result["tags"].append("置顶")
	if bool(result.get("is_favorite", false)) and not result.get("tags", []).has("收藏"):
		result["tags"].append("收藏")
	if bool(result.get("is_milestone", false)) and not result.get("tags", []).has("纪念节点"):
		result["tags"].append("纪念节点")
	result["display_sort"] = _build_display_sort(result)
	return result

func _build_display_sort(entry: Dictionary) -> int:
	var score = int(entry.get("sort_value", 0))
	if bool(entry.get("is_pinned", false)):
		score += PIN_BONUS
	if bool(entry.get("is_milestone", false)):
		score += MILESTONE_BONUS
	if not bool(entry.get("is_viewed", false)):
		score += UNVIEWED_BONUS
	if bool(entry.get("is_favorite", false)):
		score += FAVORITE_BONUS
	return score

func _build_stage_milestones() -> Array:
	var profile = GameDataManager.profile
	if profile == null or not profile.has_method("get_stage_config"):
		return []
	var results: Array = []
	var max_stage = max(1, int(profile.current_stage))
	for stage in range(2, max_stage + 1):
		var conf = profile.get_stage_config(stage)
		var stage_title = str(conf.get("stageTitle", "Stage %d" % stage))
		var stage_desc = str(conf.get("stageDesc", "你们的关系在这一阶段有了新的变化。")).strip_edges()
		var unlock_dialog = str(conf.get("unlockDialog", "")).strip_edges()
		var summary = stage_desc if stage_desc != "" else unlock_dialog
		if summary == "":
			summary = "从这一刻开始，你们之间的距离又近了一些。"
		results.append({
			"id": "milestone_stage_%d" % stage,
			"category": CATEGORY_MILESTONE,
			"title": "关系进入 %s" % stage_title,
			"subtitle": "Stage %d" % stage,
			"summary": summary,
			"quote": unlock_dialog if unlock_dialog != "" else "这是你们关系里的一个关键节点。",
			"time_label": "Stage %d" % stage,
			"cover_image": "",
			"tags": ["阶段成长", "纪念节点"],
			"context_domain": "story",
			"is_milestone": true,
			"sort_value": 900000000 + stage,
			"revisit_payload": {
				"memory_id": "",
				"layer": "bond",
				"content": "我们关系进入了%s，那是值得记住的一步。" % stage_title,
				"story_time": "Stage %d" % stage,
				"day_offset": 0,
				"context_domain": "story",
				"story_location_id": "",
				"story_weather": "",
				"story_period": "",
				"real_period": "",
				"real_weather": "",
				"trigger_context": GameDataManager.memory_manager.build_story_memory_context() if GameDataManager.memory_manager else {}
			}
		})
	return results

func _build_memory_entries() -> Array:
	if GameDataManager.memory_manager == null:
		return []
	var results: Array = []
	var layers = ["bond", "emotion", "habit"]
	for layer in layers:
		var layer_items = GameDataManager.memory_manager.memories.get(layer, [])
		for mem in layer_items:
			if not mem is Dictionary:
				continue
			if not GameDataManager.memory_manager.should_surface_memory_in_player_channels(mem, "album", false):
				continue
			var content = str(mem.get("content", "")).strip_edges()
			if content == "":
				continue
			results.append({
				"id": "memory_%s" % str(mem.get("id", Time.get_unix_time_from_system())),
				"category": "memory",
				"title": _build_memory_title(layer),
				"subtitle": _build_context_subtitle(mem),
				"summary": content,
				"quote": _extract_quote(content),
				"time_label": _build_time_label(mem),
				"cover_image": "",
				"tags": _build_memory_tags(layer, mem),
				"context_domain": str(mem.get("context_domain", "story")),
				"is_milestone": bool(mem.get("is_bond_mark", false)),
				"sort_value": _build_sort_value(str(mem.get("timestamp", "")), int(mem.get("day_offset", 0))),
				"revisit_payload": {
					"memory_id": str(mem.get("id", "")),
					"layer": layer,
					"content": content,
					"story_time": str(mem.get("story_time", "")),
					"day_offset": int(mem.get("day_offset", 0)),
					"context_domain": str(mem.get("context_domain", "story")),
					"story_location_id": str(mem.get("story_location_id", "")),
					"story_weather": str(mem.get("story_weather", "")),
					"story_period": str(mem.get("story_period", "")),
					"real_period": str(mem.get("real_period", "")),
					"real_weather": str(mem.get("real_weather", "")),
					"trigger_context": _build_trigger_context_from_memory(mem)
				}
			})
	if results.size() > MAX_MEMORY_ENTRIES:
		results = results.slice(0, MAX_MEMORY_ENTRIES)
	return results

func _build_diary_entries() -> Array:
	if GameDataManager.profile == null:
		return []
	var results: Array = []
	var diaries = GameDataManager.profile.get_diaries()
	for diary in diaries:
		if not diary is Dictionary:
			continue
		var content = str(diary.get("content", "")).strip_edges()
		if content == "":
			continue
		var cover_image = ""
		if diary.has("images") and diary["images"] is Array and diary["images"].size() > 0:
			cover_image = str(diary["images"][0])
		elif str(diary.get("image_url", "")) != "":
			cover_image = str(diary.get("image_url", ""))
		results.append({
			"id": "diary_%s" % str(diary.get("id", diary.get("date", Time.get_date_string_from_system()))),
			"category": "diary",
			"title": "她写下的一页心情",
			"subtitle": str(diary.get("date", "未记录日期")),
			"summary": content,
			"quote": _extract_quote(content),
			"time_label": str(diary.get("date", "")),
			"cover_image": cover_image,
			"tags": _build_diary_tags(diary),
			"context_domain": "story",
			"is_milestone": false,
			"sort_value": _build_sort_value(str(diary.get("date", "")), 0),
			"revisit_payload": {
				"memory_id": "",
				"layer": "bond",
				"content": content,
				"story_time": str(diary.get("date", "")),
				"day_offset": 0,
				"context_domain": "story",
				"story_location_id": "",
				"story_weather": str(diary.get("weather", "")),
				"story_period": "",
				"real_period": "",
				"real_weather": "",
				"trigger_context": GameDataManager.memory_manager.build_story_memory_context() if GameDataManager.memory_manager else {}
			}
		})
	results.reverse()
	if results.size() > MAX_DIARY_ENTRIES:
		results = results.slice(0, MAX_DIARY_ENTRIES)
	return results

func _build_moment_entries() -> Array:
	if typeof(MomentsManager) == TYPE_NIL:
		return []
	var results: Array = []
	var char_name = GameDataManager.profile.char_name if GameDataManager.profile else ""
	for moment in MomentsManager.get_all_moments():
		if not moment is Dictionary:
			continue
		var author = str(moment.get("author", ""))
		if char_name != "" and author != char_name:
			continue
		var content = str(moment.get("content", "")).strip_edges()
		if content == "":
			continue
		var cover_image = ""
		var images = moment.get("images", [])
		if images is Array and images.size() > 0:
			cover_image = str(images[0])
		results.append({
			"id": "moment_%s" % str(moment.get("id", Time.get_unix_time_from_system())),
			"category": "moment",
			"title": "她分享过的瞬间",
			"subtitle": author,
			"summary": content,
			"quote": _extract_comment_quote(moment.get("comments", [])),
			"time_label": str(moment.get("time", "")),
			"cover_image": cover_image,
			"tags": ["朋友圈", "分享", "动态"],
			"context_domain": "story",
			"is_milestone": false,
			"sort_value": _build_sort_value(str(moment.get("time", "")), 0),
			"revisit_payload": {
				"memory_id": "",
				"layer": "bond",
				"content": content,
				"story_time": str(moment.get("time", "")),
				"day_offset": 0,
				"context_domain": "story",
				"story_location_id": "",
				"story_weather": "",
				"story_period": "",
				"real_period": "",
				"real_weather": "",
				"trigger_context": GameDataManager.memory_manager.build_story_memory_context() if GameDataManager.memory_manager else {}
			}
		})
	if results.size() > MAX_MOMENT_ENTRIES:
		results = results.slice(0, MAX_MOMENT_ENTRIES)
	return results

func _build_photo_entries() -> Array:
	var results: Array = []
	var photo_manager = PhotoMemoryManagerScript.new()
	for record in photo_manager.get_album_records():
		var album_category = str(record.get("album_category", ""))
		if album_category == "diary" or album_category == "moment":
			continue
			
		var path = str(record.get("photo_path", ""))
		var record_key = str(record.get("record_key", record.get("file_name", "")))
		if path == "" or record_key == "":
			continue
		results.append({
			"id": "photo_%s" % record_key.md5_text(),
			"category": "photo",
			"title": _build_photo_title(record),
			"subtitle": _build_photo_subtitle(record),
			"summary": _build_photo_summary(record),
			"quote": _build_photo_quote(record),
			"time_label": _build_photo_time_label(record, str(record.get("file_name", ""))),
			"cover_image": path,
			"tags": _build_photo_tags(record),
			"source_type": str(record.get("source_type", "")),
			"album_category": str(record.get("album_category", "")),
			"source_label": str(record.get("source_label", "")),
			"source_title": str(record.get("source_title", "")),
			"relation_reason": str(record.get("relation_reason", "")),
			"related_memory_title": str(record.get("related_memory_title", "")),
			"related_memory_content": str(record.get("related_memory_content", "")),
			"binding_label": _build_photo_binding_label(record),
			"binding_summary": _build_photo_binding_summary(record),
			"context_domain": str(record.get("context_domain", "story")),
			"is_milestone": false,
			"sort_value": _build_photo_sort_value(record, str(record.get("file_name", ""))),
			"revisit_payload": {
				"memory_id": str(record.get("related_memory_id", "")),
				"layer": str(record.get("related_memory_layer", "bond")),
				"content": _build_photo_revisit_content(record),
				"story_time": str(record.get("story_time", _format_file_time(str(record.get("file_name", ""))))),
				"day_offset": int(record.get("day_offset", 0)),
				"context_domain": str(record.get("context_domain", "story")),
				"story_location_id": str(record.get("story_location_id", "")),
				"story_weather": str(record.get("story_weather", "")),
				"story_period": str(record.get("story_period", "")),
				"real_period": str(record.get("real_period", "")),
				"real_weather": str(record.get("real_weather", "")),
				"trigger_context": _build_photo_trigger_context(record)
			}
		})
	results.sort_custom(func(a, b): return int(a.get("sort_value", 0)) > int(b.get("sort_value", 0)))
	if results.size() > MAX_PHOTO_ENTRIES:
		results = results.slice(0, MAX_PHOTO_ENTRIES)
	return results

func _build_memory_title(layer: String) -> String:
	match layer:
		"bond":
			return "你们一起记住的事"
		"emotion":
			return "她记得你的情绪"
		"habit":
			return "她记得你的习惯"
		_:
			return "共同回忆"

func _build_memory_tags(layer: String, mem: Dictionary) -> Array:
	var tags: Array = []
	match layer:
		"bond":
			tags.append("共同经历")
		"emotion":
			tags.append("情绪记忆")
		"habit":
			tags.append("习惯印象")
	if str(mem.get("context_domain", "")) == "reality":
		tags.append("现实陪伴")
	else:
		tags.append("剧情世界")
	if str(mem.get("story_weather", "")) != "":
		tags.append(str(mem.get("story_weather", "")))
	if str(mem.get("real_period", "")) != "":
		tags.append(str(mem.get("real_period", "")))
	if bool(mem.get("is_bond_mark", false)):
		tags.append("重要羁绊")
	return tags

func _build_diary_tags(diary: Dictionary) -> Array:
	var tags: Array = ["日记"]
	var weather = str(diary.get("weather", ""))
	if weather != "":
		tags.append(weather)
	if diary.has("images") or str(diary.get("image_url", "")) != "":
		tags.append("配图")
	return tags

func _build_context_subtitle(mem: Dictionary) -> String:
	var context_domain = str(mem.get("context_domain", "story"))
	if context_domain == "reality":
		var real_period = str(mem.get("real_period", ""))
		var real_weather = str(mem.get("real_weather", ""))
		var parts: Array = ["现实陪伴"]
		if real_period != "":
			parts.append(real_period)
		if real_weather != "":
			parts.append(real_weather)
		return " / ".join(parts)
	var story_location = _resolve_location_display_name(str(mem.get("story_location_id", "")))
	var story_period = str(mem.get("story_period", ""))
	var parts: Array = ["剧情回忆"]
	if story_location != "":
		parts.append(story_location)
	if story_period != "":
		parts.append(story_period)
	return " / ".join(parts)

func _resolve_location_display_name(location_id: String) -> String:
	var clean_id = str(location_id).strip_edges()
	if clean_id == "":
		return ""
	if clean_id.find("_") == -1:
		return clean_id
	if _location_name_cache.has(clean_id):
		return str(_location_name_cache[clean_id])
	if not FileAccess.file_exists(MAP_DATA_PATH):
		_location_name_cache[clean_id] = clean_id
		return clean_id
	var file = FileAccess.open(MAP_DATA_PATH, FileAccess.READ)
	if file == null:
		_location_name_cache[clean_id] = clean_id
		return clean_id
	var json = JSON.new()
	var parse_result = json.parse(file.get_as_text())
	file.close()
	if parse_result != OK or not json.data is Dictionary:
		_location_name_cache[clean_id] = clean_id
		return clean_id
	var locations = json.data.get("locations", {})
	if locations is Dictionary and locations.has(clean_id):
		var location_conf = locations[clean_id]
		if location_conf is Dictionary:
			var location_name = str(location_conf.get("name", clean_id)).strip_edges()
			_location_name_cache[clean_id] = location_name
			return location_name
	_location_name_cache[clean_id] = clean_id
	return clean_id

func _build_time_label(data: Dictionary) -> String:
	var context_domain = str(data.get("context_domain", "story"))
	if context_domain == "reality":
		var real_date = str(data.get("real_date", ""))
		var real_period = str(data.get("real_period", ""))
		return ("%s %s" % [real_date, real_period]).strip_edges()
	var story_time = str(data.get("story_time", ""))
	if story_time != "":
		return story_time.split(",")[0].strip_edges()
	var timestamp = str(data.get("timestamp", ""))
	return timestamp.split("T")[0] if "T" in timestamp else timestamp

func _build_sort_value(time_text: String, day_offset: int) -> int:
	if day_offset > 0:
		return day_offset * 1000000
	var digits := ""
	for c in time_text:
		if c >= "0" and c <= "9":
			digits += c
	if digits == "":
		return 0
	return int(digits)

func _extract_quote(text: String) -> String:
	var cleaned = text.strip_edges()
	if cleaned.length() <= 28:
		return cleaned
	return cleaned.substr(0, 28) + "..."

func _extract_comment_quote(comments: Array) -> String:
	if comments is Array and comments.size() > 0:
		var last_comment = comments[comments.size() - 1]
		var author = str(last_comment.get("author", ""))
		var content = str(last_comment.get("content", "")).strip_edges()
		if content != "":
			return "%s：%s" % [author, _extract_quote(content)]
	return "你们在这条动态下也留下过互动。"

func _build_trigger_context_from_memory(mem: Dictionary) -> Dictionary:
	if str(mem.get("context_domain", "")) == "reality":
		return {
			"context_domain": "reality",
			"time_type": "reality",
			"real_date": str(mem.get("real_date", "")),
			"real_hour": int(mem.get("real_hour", -1)),
			"real_period": str(mem.get("real_period", "")),
			"real_weather": str(mem.get("real_weather", "")),
			"real_temp": float(mem.get("real_temp", 0.0)),
			"real_datetime": str(mem.get("real_datetime", ""))
		}
	return {
		"context_domain": "story",
		"time_type": "story",
		"story_time": str(mem.get("story_time", "")),
		"day_offset": int(mem.get("day_offset", 0)),
		"story_period": str(mem.get("story_period", "")),
		"story_weather": str(mem.get("story_weather", "")),
		"story_location_id": str(mem.get("story_location_id", "")),
		"story_area_id": str(mem.get("story_area_id", ""))
	}

func _format_file_time(file_name: String) -> String:
	var digits := ""
	for c in file_name:
		if c >= "0" and c <= "9":
			digits += c
	if digits.length() >= 8:
		return "%s-%s-%s" % [digits.substr(0, 4), digits.substr(4, 2), digits.substr(6, 2)]
	return file_name

func _build_photo_title(record: Dictionary) -> String:
	if record.is_empty():
		return "被保存下来的瞬间"
	var display_title = str(record.get("album_display_title", "")).strip_edges()
	if display_title != "":
		return display_title
	return "被保存下来的瞬间"

func _build_photo_subtitle(record: Dictionary) -> String:
	if record.is_empty():
		return "相册照片"
	var display_subtitle = str(record.get("album_display_subtitle", "")).strip_edges()
	var display_source = str(record.get("album_display_source", "")).strip_edges()
	var scene_name = str(record.get("album_display_scene", "")).strip_edges()
	var parts: Array = []
	if display_subtitle != "":
		parts.append(display_subtitle)
	if display_source != "" and not parts.has(display_source):
		parts.append(display_source)
	if scene_name != "" and not parts.has(scene_name):
		parts.append(scene_name)
	return " · ".join(parts) if not parts.is_empty() else "相册照片"

func _build_photo_summary(record: Dictionary) -> String:
	if record.is_empty():
		return "这张照片后来被你好好留了下来，成为你们关系里可以反复翻看的一个瞬间。"
	var display_note = str(record.get("album_display_note", "")).strip_edges()
	if display_note != "":
		return display_note
	var related_content = str(record.get("related_memory_content", "")).strip_edges()
	var reason = str(record.get("relation_reason", "")).strip_edges()
	var source_text = str(record.get("source_text", "")).strip_edges()
	var source_label = _get_photo_source_label(record)
	if related_content != "":
		var short_content = _extract_quote(related_content)
		if reason != "":
			return "这张%s被收进纪念册时，也和%s悄悄连在了一起：%s" % [source_label, reason, short_content]
		return "这张%s后来被留了下来，也自然连到了你们当时的那段回忆：%s" % [source_label, short_content]
	if source_text != "":
		return "这张%s被留住时，旁边留下的一句说明是：%s" % [source_label, _extract_quote(source_text)]
	var source_type = str(record.get("source_type", ""))
	if source_type == "chat_image":
		return "这是她发来后又被你留进相册的一张图片，后来慢慢变成了可以回看的共同片段。"
	if source_type == "camera_capture":
		return "你在那个时刻按下了快门，也把当时的时间、地点和氛围一起留进了纪念册。"
	if source_type == "story_cg":
		return "这张剧情 CG 被正式收进相册，代表你们共同经历过的一段主线片段已经留下了视觉痕迹。"
	if source_type == "diary_image":
		return "这张日记配图把那一天的文字心情补成了更具体的画面，也因此被收进了你们的相册。"
	if source_type == "moment_image":
		return "她发过的这张朋友圈配图被好好留了下来，后来也成了你们关系里能反复翻看的一个瞬间。"
	if source_type == "drawing_image":
		return "这张画是你们一起完成的创作结果，比普通照片更像一段被保存下来的共同作品。"
	return "这张照片后来被你好好留了下来，成为你们关系里可以反复翻看的一个瞬间。"

func _build_photo_quote(record: Dictionary) -> String:
	var related_content = str(record.get("related_memory_content", "")).strip_edges()
	if related_content != "":
		return _extract_quote(related_content)
	var source_text = str(record.get("source_text", "")).strip_edges()
	if source_text != "":
		return _extract_quote(source_text)
	return "有些事情会慢慢模糊，但照片会把那一刻留住。"

func _build_photo_tags(record: Dictionary) -> Array:
	var tags: Array = ["相册", "照片", "留存"]
	if record.is_empty():
		return tags
	var source_label = str(record.get("album_display_source", record.get("source_label", ""))).strip_edges()
	if source_label != "":
		tags.append(source_label)
	var mood_tag = str(record.get("album_mood_tag", "")).strip_edges()
	if mood_tag != "":
		tags.append(mood_tag)
	var scene_name = str(record.get("album_display_scene", "")).strip_edges()
	if scene_name != "":
		tags.append(scene_name)
	var source_type = str(record.get("source_type", ""))
	if source_type == "chat_image":
		tags.append("聊天图片")
	elif source_type == "camera_capture":
		tags.append("即时拍照")
	elif source_type == "story_cg":
		tags.append("剧情CG")
	elif source_type == "diary_image":
		tags.append("日记配图")
	elif source_type == "moment_image":
		tags.append("朋友圈配图")
	elif source_type == "drawing_image":
		tags.append("绘画生成")
	var reason = str(record.get("relation_reason", ""))
	if reason != "":
		tags.append(reason)
	var related_title = str(record.get("related_memory_title", ""))
	if related_title != "":
		tags.append(related_title)
	return tags

func _build_photo_time_label(record: Dictionary, file_name: String) -> String:
	if not record.is_empty():
		var display_time = str(record.get("album_display_time", "")).strip_edges()
		if display_time != "":
			return display_time.split(",")[0].strip_edges()
		var context_domain = str(record.get("context_domain", "story"))
		if context_domain == "reality":
			var real_date = str(record.get("real_date", ""))
			var real_period = str(record.get("real_period", ""))
			var merged = ("%s %s" % [real_date, real_period]).strip_edges()
			if merged != "":
				return merged
		if str(record.get("story_time", "")) != "":
			return str(record.get("story_time", "")).split(",")[0].strip_edges()
	return _format_file_time(file_name)

func _build_photo_sort_value(record: Dictionary, file_name: String) -> int:
	if not record.is_empty():
		var saved_at = str(record.get("saved_at", ""))
		if saved_at != "":
			return _build_sort_value(saved_at, int(record.get("day_offset", 0)))
	return _build_sort_value(_format_file_time(file_name), 0)

func _build_photo_revisit_content(record: Dictionary) -> String:
	var related_content = str(record.get("related_memory_content", "")).strip_edges()
	if related_content != "":
		return "后来看到这张照片时，我们又想起了当时的那段事：%s" % related_content
	var source_text = str(record.get("source_text", "")).strip_edges()
	if source_text != "":
		return "后来翻到这张照片时，我们也会想起它当时留下的说明：%s" % source_text
	return "后来我们把这张照片留了下来，变成能随时翻看的回忆。"

func _build_photo_binding_label(record: Dictionary) -> String:
	if record.is_empty():
		return "暂时还没有补充具体回忆"
	var related_title = str(record.get("related_memory_title", "")).strip_edges()
	var reason = str(record.get("relation_reason", "")).strip_edges()
	if related_title != "" and reason != "":
		return "这张图会让人想起%s · %s" % [related_title, reason]
	if related_title != "":
		return "这张图会让人想起%s" % related_title
	if reason != "":
		return "它被归进了%s的那类回忆" % reason
	return "暂时还没有补充具体回忆"

func _build_photo_binding_summary(record: Dictionary) -> String:
	if record.is_empty():
		return "这张照片目前还没有补充更具体的回忆说明，之后整理新的瞬间时会继续慢慢补上。"
	var related_content = str(record.get("related_memory_content", "")).strip_edges()
	var reason = str(record.get("relation_reason", "")).strip_edges()
	var source_label = _get_photo_source_label(record)
	if related_content != "":
		if reason != "":
			return "收进纪念册时，这张%s因为%s，被一并记到了这段回忆里：%s" % [source_label, reason, _extract_quote(related_content)]
		return "收进纪念册时，这张%s也自然连到了这段回忆：%s" % [source_label, _extract_quote(related_content)]
	if reason != "":
		return "这张%s已经按%s收好，但还没有补到更具体的回忆正文。" % [source_label, reason]
	return "这张%s已经被收进纪念册，只是暂时还没有补上更明确的回忆来源。" % source_label

func _get_photo_source_label(record: Dictionary) -> String:
	var source_label = str(record.get("source_label", "")).strip_edges()
	if source_label != "":
		return source_label
	var source_type = str(record.get("source_type", "")).strip_edges()
	match source_type:
		"chat_image":
			return "聊天留图"
		"camera_capture":
			return "即时拍照"
		"story_cg":
			return "剧情CG"
		"diary_image":
			return "日记配图"
		"moment_image":
			return "朋友圈配图"
		"drawing_image":
			return "绘画生成"
		_:
			return "相册照片"

func _build_photo_trigger_context(record: Dictionary) -> Dictionary:
	if record.is_empty():
		return GameDataManager.memory_manager.build_story_memory_context() if GameDataManager.memory_manager else {}
	if str(record.get("context_domain", "story")) == "reality":
		return {
			"context_domain": "reality",
			"time_type": "reality",
			"real_date": str(record.get("real_date", "")),
			"real_period": str(record.get("real_period", "")),
			"real_weather": str(record.get("real_weather", ""))
		}
	return {
		"context_domain": "story",
		"time_type": "story",
		"story_time": str(record.get("story_time", "")),
		"day_offset": int(record.get("day_offset", 0)),
		"story_period": str(record.get("story_period", "")),
		"story_weather": str(record.get("story_weather", "")),
		"story_location_id": str(record.get("story_location_id", "")),
		"story_area_id": str(record.get("story_area_id", ""))
	}
