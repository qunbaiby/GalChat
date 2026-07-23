extends Node

var areas: Dictionary = {}
var locations: Dictionary = {}
var npcs_data: Dictionary = {}
var area_order: Array = []

var _last_visited_area: String = ""
var _last_visited_location: String = ""
var _entry_trigger_history: Dictionary = {}

const MAP_DATA_PATH = "res://assets/data/map/core/map_data.json"
const NPC_DATA_PATH = "res://assets/data/map/npc/npc_data.json"

func _ready():
	_load_map_data()
	_load_npcs_data()
	_load_entry_trigger_history()

func get_entry_trigger_state_path() -> String:
	var char_id := "default"
	if GameDataManager.config and GameDataManager.config.current_character_id != "":
		char_id = GameDataManager.config.current_character_id
	return GameDataManager.get_character_save_path("map_entry_trigger_history.json", char_id)

func _load_entry_trigger_history() -> void:
	_entry_trigger_history.clear()
	var save_path := get_entry_trigger_state_path()
	if not FileAccess.file_exists(save_path):
		return
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
		_entry_trigger_history = json.data
	file.close()

func _save_entry_trigger_history() -> bool:
	return SafeFileAccess.store_string(get_entry_trigger_state_path(), JSON.stringify(_entry_trigger_history))

func reload_for_current_character() -> void:
	_last_visited_area = ""
	_last_visited_location = ""
	_load_entry_trigger_history()

func _get_current_story_day_offset() -> int:
	if GameDataManager.story_time_manager:
		return int(GameDataManager.story_time_manager.current_day_offset)
	return 0

func _build_entry_trigger_key(source_type: String, source_id: String, location_id: String = "") -> String:
	var final_source_type := source_type.strip_edges()
	var final_source_id := source_id.strip_edges()
	var final_location_id := location_id.strip_edges()
	if final_source_type == "" or final_source_id == "":
		return ""
	return "%s|%s|%s" % [final_source_type, final_location_id, final_source_id]

func has_consumed_entry_trigger_today(source_type: String, source_id: String, location_id: String = "") -> bool:
	var trigger_key := _build_entry_trigger_key(source_type, source_id, location_id)
	if trigger_key == "":
		return false
	if not _entry_trigger_history.has(trigger_key):
		return false
	return int(_entry_trigger_history.get(trigger_key, -1)) == _get_current_story_day_offset()

func mark_entry_trigger_consumed(source_type: String, source_id: String, location_id: String = "") -> void:
	var trigger_key := _build_entry_trigger_key(source_type, source_id, location_id)
	if trigger_key == "":
		return
	var current_day_offset := _get_current_story_day_offset()
	if int(_entry_trigger_history.get(trigger_key, -1)) == current_day_offset:
		return
	_entry_trigger_history[trigger_key] = current_day_offset
	_save_entry_trigger_history()

func _load_npcs_data():
	if not FileAccess.file_exists(NPC_DATA_PATH):
		push_error("NPC data file not found: " + NPC_DATA_PATH)
		return
		
	var file = FileAccess.open(NPC_DATA_PATH, FileAccess.READ)
	var json_str = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_str)
	if error == OK:
		npcs_data = json.data
	else:
		push_error("Failed to parse NPC data JSON: " + json.get_error_message())

func _load_map_data():
	if not FileAccess.file_exists(MAP_DATA_PATH):
		push_error("Map data file not found: " + MAP_DATA_PATH)
		return
		
	var file = FileAccess.open(MAP_DATA_PATH, FileAccess.READ)
	var json_str = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_str)
	if error == OK:
		var data = json.data
		areas = data.get("areas", {})
		area_order = data.get("area_order", [])
		
		# Parse locations and convert dictionary map_position back to Vector2
		var raw_locations = data.get("locations", {})
		for loc_id in raw_locations:
			var loc = raw_locations[loc_id]
			if loc.has("map_position"):
				var pos_dict = loc["map_position"]
				loc["map_position"] = Vector2(pos_dict.get("x", 0), pos_dict.get("y", 0))
			locations[loc_id] = loc
	else:
		push_error("Failed to parse Map data JSON: " + json.get_error_message())

func get_area(area_id: String) -> Dictionary:
	return areas.get(area_id, {})

func get_area_order() -> Array:
	var ordered_ids: Array = []
	for area_id in area_order:
		var area_id_str := str(area_id)
		if area_id_str != "" and areas.has(area_id_str):
			ordered_ids.append(area_id_str)
	
	for area_id in areas.keys():
		var area_id_str := str(area_id)
		if not ordered_ids.has(area_id_str):
			ordered_ids.append(area_id_str)
	
	return ordered_ids

func get_location(location_id: String) -> Dictionary:
	return locations.get(location_id, {})

func is_area_unlocked(area_id: String) -> bool:
	var area = get_area(area_id)
	if area.is_empty():
		return false
	
	if bool(area.get("default_unlocked", false)):
		return true
	
	if GameDataManager.config and GameDataManager.config.unlocked_area_ids.has(area_id):
		return true
	
	var conditions = area.get("unlock_conditions", [])
	if not (conditions is Array) or conditions.is_empty():
		return true
	
	var ConditionManager = preload("res://scripts/data/condition_manager.gd")
	var eval_result = ConditionManager.evaluate_conditions(conditions)
	if bool(eval_result.get("passed", false)):
		unlock_area(area_id)
		return true
	
	return false

func get_area_lock_reason(area_id: String) -> String:
	var area = get_area(area_id)
	if area.is_empty():
		return ""
	
	if is_area_unlocked(area_id):
		return ""
	
	var custom_reason := str(area.get("unlock_hint", "")).strip_edges()
	if custom_reason != "":
		return custom_reason
	
	var conditions = area.get("unlock_conditions", [])
	if not (conditions is Array) or conditions.is_empty():
		return "暂未解锁"
	
	var ConditionManager = preload("res://scripts/data/condition_manager.gd")
	var eval_result = ConditionManager.evaluate_conditions(conditions)
	if not bool(eval_result.get("passed", false)):
		return str(eval_result.get("failed_reason", "暂未解锁"))
	return "暂未解锁"

func unlock_area(area_id: String, save_now: bool = true) -> void:
	if area_id == "":
		return
	if not areas.has(area_id):
		return
	if GameDataManager.config == null:
		return
	if GameDataManager.config.unlocked_area_ids.has(area_id):
		return
	
	GameDataManager.config.unlocked_area_ids.append(area_id)
	if save_now:
		GameDataManager.config.save_config()

func is_location_unlocked(location_id: String) -> bool:
	var loc = get_location(location_id)
	if loc.is_empty():
		return false
		
	# 如果没有 conditions，默认解锁
	if not loc.has("conditions"):
		return true
		
	var conditions = loc["conditions"]
	if not (conditions is Array):
		return true
		
	var ConditionManager = preload("res://scripts/data/condition_manager.gd")
	var eval_result = ConditionManager.evaluate_conditions(conditions)
	return eval_result["passed"]
	
func is_location_visible(location_id: String) -> bool:
	var loc = get_location(location_id)
	if loc.is_empty():
		return false
		
	if not loc.has("visibility_conditions"):
		return true
		
	var v_conditions = loc["visibility_conditions"]
	if not (v_conditions is Array):
		return true
		
	var ConditionManager = preload("res://scripts/data/condition_manager.gd")
	var eval_result = ConditionManager.evaluate_conditions(v_conditions)
	return eval_result["passed"]

func get_location_lock_reason(location_id: String) -> String:
	var loc = get_location(location_id)
	if loc.is_empty() or not loc.has("conditions"):
		return ""
		
	var ConditionManager = preload("res://scripts/data/condition_manager.gd")
	var eval_result = ConditionManager.evaluate_conditions(loc["conditions"])
	if not eval_result["passed"]:
		return eval_result["failed_reason"]
	return ""

func get_area_locations(area_id: String) -> Array:
	var area = get_area(area_id)
	var locs = []
	
	# Handle fixed_locations
	if area.has("fixed_locations"):
		for loc_id in area["fixed_locations"]:
			var loc = get_location(loc_id)
			if not loc.is_empty():
				locs.append(loc)
				
	# Handle limited_locations
	if area.has("limited_locations"):
		for loc_id in area["limited_locations"]:
			var loc = get_location(loc_id)
			if not loc.is_empty() and is_location_unlocked(loc_id):
				locs.append(loc)
				
	# Backwards compatibility for old "locations" array
	if area.has("locations"):
		for loc_id in area["locations"]:
			var loc = get_location(loc_id)
			if not loc.is_empty():
				locs.append(loc)
				
	return locs

func get_npc_data(npc_id: String) -> Dictionary:
	return npcs_data.get(npc_id, {})

func _get_active_story_events(day_cfg: Dictionary, period: String) -> Array:
	var active_events: Array = []
	var base_events = day_cfg.get("events", [])
	if base_events is Array:
		for event_id in base_events:
			var event_key := str(event_id).strip_edges()
			if event_key != "" and not active_events.has(event_key):
				active_events.append(event_key)
	
	var period_event_key := ""
	match period:
		"上午":
			period_event_key = "morning_events"
		"下午":
			period_event_key = "afternoon_events"
		"傍晚":
			period_event_key = "evening_events"
		"夜晚":
			period_event_key = "night_events"
	
	if period_event_key != "":
		var period_events = day_cfg.get(period_event_key, [])
		if period_events is Array:
			for event_id in period_events:
				var event_key := str(event_id).strip_edges()
				if event_key != "" and not active_events.has(event_key):
					active_events.append(event_key)
	
	return active_events

func _matches_story_schedule(schedule: Dictionary, day_offset: int, current_period: String, current_weather: String, active_events: Array, current_stage: int) -> bool:
	if schedule.has("day_offsets"):
		var offsets = schedule["day_offsets"]
		if offsets is Array and offsets.size() > 0 and not (day_offset in offsets):
			return false
	
	if schedule.has("events"):
		var events = schedule["events"]
		if events is Array and events.size() > 0:
			var has_event := false
			for raw_event in events:
				var event_key := str(raw_event).strip_edges()
				if event_key != "" and active_events.has(event_key):
					has_event = true
					break
			if not has_event:
				return false
	
	if schedule.has("weather"):
		var weathers = schedule["weather"]
		if weathers is Array and weathers.size() > 0 and not (current_weather in weathers):
			return false
	
	if schedule.has("periods"):
		var periods = schedule["periods"]
		if periods is Array and periods.size() > 0 and not (current_period in periods):
			return false
	
	if schedule.has("min_stage") and current_stage < int(schedule["min_stage"]):
		return false
	if schedule.has("max_stage") and current_stage > int(schedule["max_stage"]):
		return false
	
	return true

func _analyze_story_schedule(schedule: Dictionary, day_offset: int, current_period: String, current_weather: String, active_events: Array, current_stage: int) -> Dictionary:
	var failure_reasons: Array[String] = []

	if schedule.has("day_offsets"):
		var offsets = schedule["day_offsets"]
		if offsets is Array and offsets.size() > 0 and not (day_offset in offsets):
			failure_reasons.append("日期不匹配：当前 day_offset=%d，需要 %s" % [day_offset, str(offsets)])

	if schedule.has("events"):
		var events = schedule["events"]
		if events is Array and events.size() > 0:
			var has_event := false
			for raw_event in events:
				var event_key := str(raw_event).strip_edges()
				if event_key != "" and active_events.has(event_key):
					has_event = true
					break
			if not has_event:
				failure_reasons.append("事件不匹配：当前激活 %s，需要命中 %s" % [str(active_events), str(events)])

	if schedule.has("weather"):
		var weathers = schedule["weather"]
		if weathers is Array and weathers.size() > 0 and not (current_weather in weathers):
			failure_reasons.append("天气不匹配：当前天气=%s，需要 %s" % [current_weather, str(weathers)])

	if schedule.has("periods"):
		var periods = schedule["periods"]
		if periods is Array and periods.size() > 0 and not (current_period in periods):
			failure_reasons.append("时段不匹配：当前时段=%s，需要 %s" % [current_period, str(periods)])

	if schedule.has("min_stage") and current_stage < int(schedule["min_stage"]):
		failure_reasons.append("阶段不足：当前阶段=%d，最低需要 %d" % [current_stage, int(schedule["min_stage"])])
	if schedule.has("max_stage") and current_stage > int(schedule["max_stage"]):
		failure_reasons.append("阶段过高：当前阶段=%d，最高允许 %d" % [current_stage, int(schedule["max_stage"])])

	return {
		"passed": failure_reasons.is_empty(),
		"failure_reasons": failure_reasons
	}

func _get_story_schedule_context() -> Dictionary:
	var time_sys = GameDataManager.story_time_manager
	var current_day_offset := 0
	var current_period := "上午"
	var current_day_cfg: Dictionary = {}
	if time_sys:
		current_day_offset = time_sys.current_day_offset
		current_period = time_sys.current_period
		current_day_cfg = time_sys.get_current_day_config()
	var current_weather := str(current_day_cfg.get("weather", "")).strip_edges()
	return {
		"day_offset": current_day_offset,
		"period": current_period,
		"weather": current_weather,
		"day_cfg": current_day_cfg,
		"active_events": _get_active_story_events(current_day_cfg, current_period)
	}

func get_resolved_dynamic_npcs() -> Dictionary:
	var schedule_ctx = _get_story_schedule_context()
	var current_day_offset: int = int(schedule_ctx.get("day_offset", 0))
	var current_period: String = str(schedule_ctx.get("period", "上午"))
	var current_weather: String = str(schedule_ctx.get("weather", ""))
	var active_events: Array = schedule_ctx.get("active_events", [])
	
	var profile = GameDataManager.profile
	var current_stage = 0
	if profile:
		current_stage = profile.current_stage
	
	var npc_candidates = {}
	
	for loc_id in locations:
		var loc = locations[loc_id]
		if loc.has("scheduled_npcs"):
			for sched in loc["scheduled_npcs"]:
				var npc_id = sched.get("id", "")
				if npc_id == "": continue
				
				if _matches_story_schedule(sched, current_day_offset, current_period, current_weather, active_events, current_stage):
					if not npc_candidates.has(npc_id):
						npc_candidates[npc_id] = []
					npc_candidates[npc_id].append({
						"location_id": loc_id,
						"priority": sched.get("priority", 0)
					})
					
	var resolved = {}
	for npc_id in npc_candidates:
		var candidates = npc_candidates[npc_id]
		candidates.sort_custom(func(a, b): return a["priority"] > b["priority"])
		resolved[npc_id] = candidates[0]
		
	return resolved

func generate_location_npcs(location_id: String) -> Array:
	# 生成当前地点的NPC列表
	var loc = get_location(location_id)
	var current_npcs = []
	
	# 1. 添加常驻NPC
	if loc.has("resident_npcs"):
		current_npcs.append_array(loc["resident_npcs"])
		
	# 2. 处理基于剧情时间/事件调度的NPC
	var resolved = get_resolved_dynamic_npcs()
	for npc_id in resolved:
		if resolved[npc_id]["location_id"] == location_id:
			if not (npc_id in current_npcs):
				current_npcs.append(npc_id)

	return current_npcs

func get_location_entry_story(location_id: String) -> Dictionary:
	var loc = get_location(location_id)
	if loc.is_empty():
		return {}
	if not loc.has("scheduled_entry_stories"):
		return {}
	
	var schedule_ctx = _get_story_schedule_context()
	var current_day_offset: int = int(schedule_ctx.get("day_offset", 0))
	var current_period: String = str(schedule_ctx.get("period", "上午"))
	var current_weather: String = str(schedule_ctx.get("weather", ""))
	var active_events: Array = schedule_ctx.get("active_events", [])
	
	var profile = GameDataManager.profile
	var current_stage := 0
	if profile:
		current_stage = profile.current_stage
	
	var candidates: Array = []
	var stories = loc.get("scheduled_entry_stories", [])
	if not (stories is Array):
		return {}
	
	for raw_story in stories:
		if not (raw_story is Dictionary):
			continue
		var story: Dictionary = raw_story
		if not _matches_story_schedule(story, current_day_offset, current_period, current_weather, active_events, current_stage):
			continue
		var script_path := str(story.get("trigger_script", "")).strip_edges()
		if script_path == "":
			continue
		var story_id := str(story.get("id", "")).strip_edges()
		if story_id == "":
			story_id = script_path.get_file().get_basename()
		if has_consumed_entry_trigger_today("scheduled_entry_story", story_id, location_id):
			continue
		var candidate := story.duplicate(true)
		candidate["trigger_script"] = script_path
		candidate["resolved_id"] = story_id
		candidates.append(candidate)
	
	if candidates.is_empty():
		return {}
	
	candidates.sort_custom(func(a, b): return int(a.get("priority", 0)) > int(b.get("priority", 0)))
	return candidates[0]

func get_active_location_story_trigger(location_id: String) -> Dictionary:
	var entry_story := get_location_entry_story(location_id)
	if not entry_story.is_empty():
		return entry_story
	var event_manager = get_node_or_null("/root/EventManager")
	if event_manager and event_manager.has_method("find_matching_auto_trigger_event"):
		var matched_event: Dictionary = event_manager.find_matching_auto_trigger_event({
			"location_id": location_id
		})
		if not matched_event.is_empty():
			return matched_event
	return {}

func _extract_story_badge_npcs_from_conditions(conditions: Array) -> Array:
	var result: Array = []
	for raw_condition in conditions:
		if not (raw_condition is Dictionary):
			continue
		var condition: Dictionary = raw_condition
		var npc_id := str(condition.get("npc_id", "")).strip_edges()
		if npc_id != "" and not result.has(npc_id):
			result.append(npc_id)
	return result

func _extract_story_badge_npcs_from_script(script_path: String) -> Array:
	var result: Array = []
	var final_path := script_path.strip_edges()
	if final_path == "" or not FileAccess.file_exists(final_path):
		return result
	var file := FileAccess.open(final_path, FileAccess.READ)
	if file == null:
		return result
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or not (json.data is Dictionary):
		file.close()
		return result
	var script_data: Dictionary = json.data
	file.close()

	var memory_records = script_data.get("memory_records", [])
	if memory_records is Array:
		for raw_record in memory_records:
			if not (raw_record is Dictionary):
				continue
			var record: Dictionary = raw_record
			var participants = record.get("participants", [])
			if not (participants is Array):
				continue
			for raw_participant in participants:
				var participant := str(raw_participant).strip_edges().to_lower()
				if participant == "" or participant == "player" or participant == "旁白" or participant == "narrator":
					continue
				if not result.has(participant):
					result.append(participant)
	if not result.is_empty():
		return result

	var chapters = script_data.get("chapters", {})
	if chapters is Dictionary:
		for raw_chapter_key in chapters.keys():
			var chapter = chapters[raw_chapter_key]
			if not (chapter is Dictionary):
				continue
			var events = chapter.get("events", [])
			if not (events is Array):
				continue
			for raw_event in events:
				if not (raw_event is Dictionary):
					continue
				var event_data: Dictionary = raw_event
				if str(event_data.get("type", "")).strip_edges() != "dialogue":
					continue
				var speaker := str(event_data.get("speaker", "")).strip_edges().to_lower()
				if speaker == "" or speaker == "player" or speaker == "旁白" or speaker == "narrator":
					continue
				if not result.has(speaker):
					result.append(speaker)
	return result

func _resolve_story_badge_npcs(story_trigger: Dictionary, location_id: String) -> Array:
	var explicit_badge_npcs = story_trigger.get("badge_npcs", [])
	var result: Array = []
	if explicit_badge_npcs is Array:
		for raw_npc in explicit_badge_npcs:
			var npc_id := str(raw_npc).strip_edges()
			if npc_id != "" and not result.has(npc_id):
				result.append(npc_id)
	if not result.is_empty():
		return result

	var condition_badge_npcs := _extract_story_badge_npcs_from_conditions(story_trigger.get("conditions", []))
	for npc_id in condition_badge_npcs:
		if not result.has(npc_id):
			result.append(npc_id)
	if not result.is_empty():
		return result

	var script_path := str(story_trigger.get("trigger_script", "")).strip_edges()
	var script_badge_npcs := _extract_story_badge_npcs_from_script(script_path)
	for npc_id in script_badge_npcs:
		if not result.has(npc_id):
			result.append(npc_id)
	if not result.is_empty():
		return result

	var current_npcs := generate_location_npcs(location_id)
	if current_npcs.size() == 1:
		var fallback_npc := str(current_npcs[0]).strip_edges()
		if fallback_npc != "":
			result.append(fallback_npc)
	return result

func analyze_location_entry_stories(location_id: String) -> Dictionary:
	var loc = get_location(location_id)
	if loc.is_empty():
		return {
			"location_id": location_id,
			"current_story": {},
			"entries": [],
			"context": {}
		}
	if not loc.has("scheduled_entry_stories"):
		return {
			"location_id": location_id,
			"current_story": {},
			"entries": [],
			"context": _get_story_schedule_context()
		}

	var schedule_ctx = _get_story_schedule_context()
	var current_day_offset: int = int(schedule_ctx.get("day_offset", 0))
	var current_period: String = str(schedule_ctx.get("period", "上午"))
	var current_weather: String = str(schedule_ctx.get("weather", ""))
	var active_events: Array = schedule_ctx.get("active_events", [])

	var profile = GameDataManager.profile
	var current_stage := 0
	if GameDataManager.profile:
		current_stage = profile.current_stage

	var entries: Array = []
	var stories = loc.get("scheduled_entry_stories", [])
	if stories is Array:
		for raw_story in stories:
			if not (raw_story is Dictionary):
				continue
			var story: Dictionary = raw_story
			var story_copy: Dictionary = story.duplicate(true)
			var script_path := str(story_copy.get("trigger_script", "")).strip_edges()
			var story_id := str(story_copy.get("id", "")).strip_edges()
			if story_id == "":
				story_id = script_path.get_file().get_basename() if script_path != "" else ""
			var schedule_analysis := _analyze_story_schedule(story_copy, current_day_offset, current_period, current_weather, active_events, current_stage)
			var blocked_today := false
			var today_reason := ""
			if story_id != "" and has_consumed_entry_trigger_today("scheduled_entry_story", story_id, location_id):
				blocked_today = true
				today_reason = "该地点入口剧情今天已触发：%s" % story_id
			var missing_script := script_path == ""
			var missing_script_reason := "未配置 trigger_script" if missing_script else ""
			var final_passed := bool(schedule_analysis.get("passed", false)) and not blocked_today and not missing_script
			var reasons: Array[String] = []
			for reason in schedule_analysis.get("failure_reasons", []):
				reasons.append(str(reason))
			if blocked_today:
				reasons.append(today_reason)
			if missing_script:
				reasons.append(missing_script_reason)
			story_copy["resolved_id"] = story_id
			entries.append({
				"story": story_copy,
				"passed": final_passed,
				"failure_reasons": reasons,
				"blocked_today": blocked_today,
				"missing_script": missing_script
			})

	var current_story := get_location_entry_story(location_id)
	return {
		"location_id": location_id,
		"current_story": current_story,
		"entries": entries,
		"context": {
			"day_offset": current_day_offset,
			"period": current_period,
			"weather": current_weather,
			"active_events": active_events,
			"stage": current_stage
		}
	}

func get_location_story_badges(location_id: String) -> Dictionary:
	var story = get_active_location_story_trigger(location_id)
	if story.is_empty():
		return {}
	
	var badge_text := str(story.get("badge_text", "")).strip_edges()
	if badge_text == "":
		if str(story.get("event_type", "")).strip_edges() == "auto_trigger":
			badge_text = "事件"
		else:
			badge_text = "主线"
	var badge_map: Dictionary = {}
	var badge_npcs := _resolve_story_badge_npcs(story, location_id)
	for raw_npc in badge_npcs:
		var npc_id := str(raw_npc).strip_edges()
		if npc_id != "":
			badge_map[npc_id] = badge_text
	return badge_map

func set_last_area(area_id: String) -> void:
	_last_visited_area = area_id

func get_last_area() -> String:
	return _last_visited_area

func set_last_location(location_id: String) -> void:
	_last_visited_location = location_id

func get_last_location() -> String:
	return _last_visited_location
