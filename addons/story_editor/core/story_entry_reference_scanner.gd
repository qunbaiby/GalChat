@tool
extends RefCounted

const JsonService = preload("res://addons/story_editor/core/story_json_service.gd")
const StoryScanner = preload("res://addons/story_editor/core/story_scanner.gd")

const EVENT_REGISTRY_PATH := "res://assets/data/events/event_registry.json"
const GUIDE_FLOWS_PATH := "res://assets/data/guide/guide_flows.json"
const STORY_TIME_PATH := "res://assets/data/story/story_time.json"
const MAP_DATA_PATH := "res://assets/data/map/core/map_data.json"
const SCHEDULE_EVENT_FIELDS := ["events", "morning_events", "afternoon_events", "evening_events", "night_events"]


static func scan(event_registry_path: String = EVENT_REGISTRY_PATH, guide_flows_path: String = GUIDE_FLOWS_PATH, story_time_path: String = STORY_TIME_PATH, map_data_path: String = MAP_DATA_PATH) -> Dictionary:
	var result := {
		"references": [] as Array[Dictionary],
		"event_entries": [] as Array[Dictionary],
		"story_paths": [] as Array[String],
		"source_diagnostics": [] as Array[Dictionary]
	}
	_scan_event_registry(event_registry_path, result)
	_scan_guide_flows(guide_flows_path, result)
	if not story_time_path.is_empty():
		_scan_story_time(story_time_path, result)
	if not map_data_path.is_empty():
		_scan_map_data(map_data_path, result)
	for story in StoryScanner.scan():
		(result.story_paths as Array[String]).append(str(story.get("path", "")))
	return result


static func _scan_event_registry(path: String, result: Dictionary) -> void:
	var load_result := JsonService.load_dictionary(path)
	if not load_result.get("ok", false):
		_add_source_error(result, path, str(load_result.get("error", "读取失败。")))
		return
	_append_event_registry_data(load_result.get("data", {}) as Dictionary, path, result)


static func scan_event_registry_data(data: Dictionary, path: String = EVENT_REGISTRY_PATH) -> Dictionary:
	var result := {
		"references": [] as Array[Dictionary],
		"event_entries": [] as Array[Dictionary],
		"source_diagnostics": [] as Array[Dictionary]
	}
	_append_event_registry_data(data, path, result)
	return result


static func _append_event_registry_data(data: Dictionary, path: String, result: Dictionary) -> void:
	var events_value: Variant = data.get("events")
	if not events_value is Array:
		_add_source_error(result, path, "Event Registry 的 events 必须是数组。")
		return
	for event_index in (events_value as Array).size():
		var event_value: Variant = (events_value as Array)[event_index]
		var location := "events / #%d" % (event_index + 1)
		if not event_value is Dictionary:
			_add_source_error(result, "%s / %s" % [path, location], "事件入口必须是对象。")
			continue
		var event := event_value as Dictionary
		var entry := {
			"source_type": "event_registry",
			"source_id": str(event.get("event_id", "")).strip_edges(),
			"source_path": path,
			"target_path": str(event.get("trigger_script", "")).strip_edges(),
			"location": location,
			"conditions": (event.get("conditions", []) as Array).duplicate(true) if event.get("conditions", []) is Array else [],
			"event_type": str(event.get("event_type", "")).strip_edges(),
			"is_repeatable": bool(event.get("is_repeatable", false)),
			"event_index": event_index,
			"expected_script_id": str(event.get("event_id", "")).strip_edges()
		}
		(result.event_entries as Array[Dictionary]).append(entry)
		(result.references as Array[Dictionary]).append(entry.duplicate(true))


static func _scan_story_time(path: String, result: Dictionary) -> void:
	var load_result := JsonService.load_dictionary(path)
	if not load_result.get("ok", false):
		_add_source_error(result, path, str(load_result.get("error", "读取失败。")))
		return
	var days_value: Variant = (load_result.get("data", {}) as Dictionary).get("daily_data")
	if not days_value is Array:
		_add_source_error(result, path, "剧情日程的 daily_data 必须是数组。")
		return
	for day_index in (days_value as Array).size():
		var day_value: Variant = (days_value as Array)[day_index]
		if not day_value is Dictionary:
			_add_source_error(result, "%s / daily_data / #%d" % [path, day_index + 1], "日程条目必须是对象。")
			continue
		var day := day_value as Dictionary
		var day_offset := int(day.get("day_offset", day_index))
		for field in SCHEDULE_EVENT_FIELDS:
			var events_value: Variant = day.get(field, [])
			if not events_value is Array:
				_add_source_error(result, "%s / daily_data / #%d / %s" % [path, day_index + 1, field], "日程剧情字段必须是数组。")
				continue
			for event_index in (events_value as Array).size():
				var event_id := str((events_value as Array)[event_index]).strip_edges()
				(result.references as Array[Dictionary]).append({
					"source_type": "story_schedule",
					"source_id": event_id,
					"source_path": path,
					"target_path": "res://assets/data/story/scripts/main/%s.json" % event_id,
					"location": "daily_data / #%d / %s / #%d" % [day_index + 1, field, event_index + 1],
					"conditions": [{"type": "day_offset", "value": day_offset}, {"type": "period", "value": _schedule_period(field)}],
					"event_type": "scheduled_story",
					"expected_script_id": event_id,
					"day_offset": day_offset,
					"period": _schedule_period(field)
				})


static func _scan_map_data(path: String, result: Dictionary) -> void:
	var load_result := JsonService.load_dictionary(path)
	if not load_result.get("ok", false):
		_add_source_error(result, path, str(load_result.get("error", "读取失败。")))
		return
	var locations_value: Variant = (load_result.get("data", {}) as Dictionary).get("locations")
	if not locations_value is Dictionary:
		_add_source_error(result, path, "地图数据的 locations 必须是对象。")
		return
	for location_id_value in (locations_value as Dictionary).keys():
		var location_id := str(location_id_value)
		var location_value: Variant = (locations_value as Dictionary)[location_id_value]
		if not location_value is Dictionary:
			continue
		var stories_value: Variant = (location_value as Dictionary).get("scheduled_entry_stories", [])
		if not stories_value is Array:
			_add_source_error(result, "%s / locations / %s" % [path, location_id], "scheduled_entry_stories 必须是数组。")
			continue
		for story_index in (stories_value as Array).size():
			var story_value: Variant = (stories_value as Array)[story_index]
			if not story_value is Dictionary:
				_add_source_error(result, "%s / locations / %s / scheduled_entry_stories / #%d" % [path, location_id, story_index + 1], "地图剧情入口必须是对象。")
				continue
			var story := story_value as Dictionary
			var source_id := str(story.get("id", "")).strip_edges()
			(result.references as Array[Dictionary]).append({
				"source_type": "map_schedule",
				"source_id": source_id,
				"source_path": path,
				"target_path": str(story.get("trigger_script", "")).strip_edges(),
				"location": "locations / %s / scheduled_entry_stories / #%d" % [location_id, story_index + 1],
				"conditions": _map_story_conditions(location_id, story),
				"event_type": "scheduled_entry_story",
				"expected_script_id": source_id
			})


static func _scan_guide_flows(path: String, result: Dictionary) -> void:
	var load_result := JsonService.load_dictionary(path)
	if not load_result.get("ok", false):
		_add_source_error(result, path, str(load_result.get("error", "读取失败。")))
		return
	var guides_value: Variant = (load_result.get("data", {}) as Dictionary).get("guides")
	if not guides_value is Array:
		_add_source_error(result, path, "Guide Flow 的 guides 必须是数组。")
		return
	for guide_index in (guides_value as Array).size():
		var guide_value: Variant = (guides_value as Array)[guide_index]
		if not guide_value is Dictionary:
			_add_source_error(result, "%s / guides / #%d" % [path, guide_index + 1], "Guide 必须是对象。")
			continue
		var guide := guide_value as Dictionary
		var guide_id := str(guide.get("id", "guide_%d" % (guide_index + 1))).strip_edges()
		_scan_guide_value(guide.get("steps", []), path, guide_id, "guides / #%d / steps" % (guide_index + 1), result)


static func _scan_guide_value(value: Variant, source_path: String, guide_id: String, location: String, result: Dictionary) -> void:
	if value is Array:
		for value_index in (value as Array).size():
			_scan_guide_value((value as Array)[value_index], source_path, guide_id, "%s / #%d" % [location, value_index + 1], result)
		return
	if not value is Dictionary:
		return
	var entry := value as Dictionary
	if str(entry.get("type", "")).strip_edges() == "play_story":
		(result.references as Array[Dictionary]).append({
			"source_type": "guide_flow",
			"source_id": "%s / %s" % [guide_id, str(entry.get("id", "未命名步骤"))],
			"source_path": source_path,
			"target_path": str(entry.get("story_path", "")).strip_edges(),
			"location": location,
			"conditions": [],
			"event_type": "play_story",
			"expected_script_id": str(entry.get("script_id", "")).strip_edges()
		})
	for key in entry.keys():
		var child: Variant = entry[key]
		if child is Array or child is Dictionary:
			_scan_guide_value(child, source_path, guide_id, "%s / %s" % [location, str(key)], result)


static func _schedule_period(field: String) -> String:
	match field:
		"morning_events":
			return "上午"
		"afternoon_events":
			return "下午"
		"evening_events":
			return "傍晚"
		"night_events":
			return "夜晚"
		_:
			return "全天"


static func _map_story_conditions(location_id: String, story: Dictionary) -> Array[Dictionary]:
	var conditions: Array[Dictionary] = [{"type": "location", "value": location_id}]
	for field in ["day_offsets", "events", "weather", "periods", "min_stage", "max_stage", "priority"]:
		if story.has(field):
			conditions.append({"type": field, "value": (story[field] as Array).duplicate(true) if story[field] is Array else story[field]})
	return conditions


static func _add_source_error(result: Dictionary, location: String, message: String) -> void:
	(result.source_diagnostics as Array[Dictionary]).append({
		"severity": "error",
		"code": "source_invalid",
		"location": location,
		"message": message
	})