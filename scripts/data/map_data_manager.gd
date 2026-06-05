extends Node

var areas: Dictionary = {}
var locations: Dictionary = {}
var npcs_data: Dictionary = {}
var area_order: Array = []

var _last_visited_area: String = ""
var _last_visited_location: String = ""
var is_quick_mode: bool = false

const MAP_DATA_PATH = "res://assets/data/map/core/map_data.json"
const NPC_DATA_PATH = "res://assets/data/map/npc/npc_data.json"

func _ready():
	_load_map_data()
	_load_npcs_data()

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

func get_resolved_dynamic_npcs() -> Dictionary:
	var time_sys = GameDataManager.story_time_manager
	var current_day_offset = time_sys.current_day_offset
	var current_period = time_sys.current_period
	var current_day_cfg = time_sys.get_current_day_config()
	var current_weather = current_day_cfg.get("weather", "")
	var current_events = current_day_cfg.get("events", [])
	
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
				
				var is_match = true
				
				if sched.has("day_offsets"):
					var offsets = sched["day_offsets"]
					if offsets is Array and offsets.size() > 0:
						if not (current_day_offset in offsets):
							is_match = false
							
				if is_match and sched.has("events"):
					var evts = sched["events"]
					if evts is Array and evts.size() > 0:
						var has_event = false
						for e in evts:
							if e in current_events:
								has_event = true
								break
						if not has_event:
							is_match = false
							
				if is_match and sched.has("weather"):
					var weathers = sched["weather"]
					if weathers is Array and weathers.size() > 0:
						if not (current_weather in weathers):
							is_match = false
							
				if is_match and sched.has("periods"):
					var periods = sched["periods"]
					if periods is Array and periods.size() > 0:
						if not (current_period in periods):
							is_match = false
							
				if is_match and sched.has("min_stage"):
					if current_stage < sched["min_stage"]:
						is_match = false
				if is_match and sched.has("max_stage"):
					if current_stage > sched["max_stage"]:
						is_match = false
						
				if is_match:
					if not npc_candidates.has(npc_id):
						npc_candidates[npc_id] = []
					npc_candidates[npc_id].append({
						"location_id": loc_id,
						"priority": sched.get("priority", 0),
						"trigger_script": sched.get("trigger_script", "")
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

func get_npc_trigger_script(npc_id: String) -> String:
	var resolved = get_resolved_dynamic_npcs()
	if resolved.has(npc_id):
		return resolved[npc_id]["trigger_script"]
	return ""

func set_last_area(area_id: String) -> void:
	_last_visited_area = area_id

func get_last_area() -> String:
	return _last_visited_area

func set_last_location(location_id: String) -> void:
	_last_visited_location = location_id

func get_last_location() -> String:
	return _last_visited_location
