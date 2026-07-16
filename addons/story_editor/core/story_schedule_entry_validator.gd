@tool
extends RefCounted

const JsonService = preload("res://addons/story_editor/core/story_json_service.gd")
const EVENT_FIELDS := ["events", "morning_events", "afternoon_events", "evening_events", "night_events"]


static func validate(story_time: Dictionary, map_data: Dictionary) -> Array[Dictionary]:
	var diagnostics: Array[Dictionary] = []
	_validate_story_time(story_time, diagnostics)
	_validate_map_data(map_data, diagnostics)
	return diagnostics


static func _validate_story_time(data: Dictionary, diagnostics: Array[Dictionary]) -> void:
	var days_value: Variant = data.get("daily_data")
	if not days_value is Array:
		_add(diagnostics, "error", "invalid_daily_data", "剧情日程", "daily_data 必须是数组。")
		return
	var offsets := {}
	for day_index in (days_value as Array).size():
		var day_value: Variant = (days_value as Array)[day_index]
		var location := "剧情日程 / #%d" % (day_index + 1)
		if not day_value is Dictionary:
			_add(diagnostics, "error", "invalid_day", location, "日程条目必须是对象。")
			continue
		var day := day_value as Dictionary
		var day_offset := int(day.get("day_offset", day_index))
		if offsets.has(day_offset):
			_add(diagnostics, "error", "duplicate_day_offset", location, "day_offset 重复：%d" % day_offset)
		else:
			offsets[day_offset] = true
		for field in EVENT_FIELDS:
			if day.has(field) and not day[field] is Array:
				_add(diagnostics, "error", "invalid_event_list", "%s / %s" % [location, field], "剧情事件字段必须是数组。")
				continue
			for event_value in day.get(field, []):
				var event_id := str(event_value).strip_edges()
				var target_path := "res://assets/data/story/scripts/main/%s.json" % event_id
				if event_id.is_empty() or not FileAccess.file_exists(target_path):
					_add(diagnostics, "error", "missing_schedule_story", "%s / %s" % [location, field], "日程目标剧情不存在：%s" % (event_id if not event_id.is_empty() else "<空>"))


static func _validate_map_data(data: Dictionary, diagnostics: Array[Dictionary]) -> void:
	var locations_value: Variant = data.get("locations")
	if not locations_value is Dictionary:
		_add(diagnostics, "error", "invalid_locations", "地图入口", "locations 必须是对象。")
		return
	for location_id_value in (locations_value as Dictionary).keys():
		var location_id := str(location_id_value)
		var location_value: Variant = (locations_value as Dictionary)[location_id_value]
		if not location_value is Dictionary:
			continue
		var stories_value: Variant = (location_value as Dictionary).get("scheduled_entry_stories", [])
		if not stories_value is Array:
			_add(diagnostics, "error", "invalid_map_stories", "地图 / %s" % location_id, "scheduled_entry_stories 必须是数组。")
			continue
		var ids := {}
		var schedule_owners := {}
		for story_index in (stories_value as Array).size():
			var story_value: Variant = (stories_value as Array)[story_index]
			var location := "地图 / %s / #%d" % [location_id, story_index + 1]
			if not story_value is Dictionary:
				_add(diagnostics, "error", "invalid_map_story", location, "地图剧情入口必须是对象。")
				continue
			var story := story_value as Dictionary
			var story_id := str(story.get("id", "")).strip_edges()
			if story_id.is_empty():
				_add(diagnostics, "error", "missing_map_story_id", location, "地图剧情入口缺少 id。")
			elif ids.has(story_id):
				_add(diagnostics, "error", "duplicate_map_story_id", location, "同一地点入口 ID 重复：%s" % story_id)
			else:
				ids[story_id] = true
			_validate_map_target(story, location, diagnostics)
			var min_stage := int(story.get("min_stage", 0))
			var max_stage := int(story.get("max_stage", 999999))
			if min_stage > max_stage:
				_add(diagnostics, "error", "invalid_stage_range", location, "min_stage 不能大于 max_stage。")
			var signature := _map_signature(story)
			if schedule_owners.has(signature):
				_add(diagnostics, "warning", "map_schedule_conflict", location, "与 %s 的调度条件和优先级完全相同。" % str(schedule_owners[signature]))
			else:
				schedule_owners[signature] = story_id if not story_id.is_empty() else location


static func _validate_map_target(story: Dictionary, location: String, diagnostics: Array[Dictionary]) -> void:
	var target_path := str(story.get("trigger_script", "")).strip_edges()
	if target_path.is_empty() or not FileAccess.file_exists(target_path):
		_add(diagnostics, "error", "missing_map_story", location, "地图目标剧情不存在：%s" % (target_path if not target_path.is_empty() else "<空>"))
		return
	var load_result := JsonService.load_dictionary(target_path)
	if not load_result.get("ok", false):
		_add(diagnostics, "error", "invalid_map_story_target", location, "地图目标剧情无法读取。")
		return
	var expected_id := str(story.get("id", "")).strip_edges()
	var actual_id := str((load_result.get("data", {}) as Dictionary).get("script_id", "")).strip_edges()
	if not expected_id.is_empty() and expected_id != actual_id:
		_add(diagnostics, "error", "map_script_id_mismatch", location, "入口 id=%s，但目标剧情声明为 %s。" % [expected_id, actual_id])


static func _map_signature(story: Dictionary) -> String:
	var signature := {}
	for field in ["day_offsets", "events", "weather", "periods", "min_stage", "max_stage", "priority"]:
		if story.has(field):
			var value: Variant = story[field]
			if value is Array:
				var sorted := (value as Array).duplicate(true)
				sorted.sort_custom(func(left: Variant, right: Variant) -> bool: return str(left) < str(right))
				signature[field] = sorted
			else:
				signature[field] = value
	return JSON.stringify(signature)


static func _add(diagnostics: Array[Dictionary], severity: String, code: String, location: String, message: String) -> void:
	diagnostics.append({"severity": severity, "code": code, "location": location, "message": message})