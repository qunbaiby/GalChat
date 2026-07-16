@tool
extends RefCounted


static func simulate(event_registry: Dictionary, story_time: Dictionary, map_data: Dictionary, context: Dictionary) -> Dictionary:
	var effective_context := context.duplicate(true)
	effective_context["active_events"] = _active_events(story_time, int(context.get("day_offset", 0)), str(context.get("period", "上午")))
	var map_candidates := _simulate_map(map_data, effective_context)
	var registry_candidates := _simulate_registry(event_registry, effective_context)
	var selected := {}
	for candidate in map_candidates:
		if bool(candidate.get("passed", false)):
			selected = candidate.duplicate(true)
			break
	if selected.is_empty():
		for candidate in registry_candidates:
			if bool(candidate.get("passed", false)):
				selected = candidate.duplicate(true)
				break
	return {
		"context": effective_context,
		"map_candidates": map_candidates,
		"registry_candidates": registry_candidates,
		"selected": selected
	}


static func _active_events(story_time: Dictionary, day_offset: int, period: String) -> Array[String]:
	var result: Array[String] = []
	var day := {}
	for day_value in story_time.get("daily_data", []):
		if day_value is Dictionary and int((day_value as Dictionary).get("day_offset", -1)) == day_offset:
			day = day_value as Dictionary
			break
	_append_unique(result, day.get("events", []))
	var period_field := {"上午": "morning_events", "下午": "afternoon_events", "傍晚": "evening_events", "夜晚": "night_events"}.get(period, "")
	if not str(period_field).is_empty():
		_append_unique(result, day.get(period_field, []))
	return result


static func _simulate_map(map_data: Dictionary, context: Dictionary) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var location_id := str(context.get("location_id", "")).strip_edges()
	var locations := map_data.get("locations", {}) as Dictionary if map_data.get("locations", {}) is Dictionary else {}
	var location := locations.get(location_id, {}) as Dictionary if locations.get(location_id, {}) is Dictionary else {}
	var stories := location.get("scheduled_entry_stories", []) as Array if location.get("scheduled_entry_stories", []) is Array else []
	for story_index in stories.size():
		var story_value: Variant = stories[story_index]
		if not story_value is Dictionary:
			continue
		var story := story_value as Dictionary
		var reasons := _map_failure_reasons(story, context)
		var target_path := str(story.get("trigger_script", "")).strip_edges()
		var source_id := str(story.get("id", "")).strip_edges()
		if source_id.is_empty() and not target_path.is_empty():
			source_id = target_path.get_file().get_basename()
		if (context.get("consumed_map_entry_ids", []) as Array).has(source_id):
			reasons.append("该地图入口今天已触发")
		results.append({
			"source_type": "map_schedule",
			"source_id": source_id,
			"target_path": target_path,
			"priority": int(story.get("priority", 0)),
			"source_index": story_index,
			"passed": reasons.is_empty(),
			"failure_reasons": reasons
		})
	results.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		if int(left.priority) == int(right.priority):
			return int(left.source_index) < int(right.source_index)
		return int(left.priority) > int(right.priority)
	)
	return results


static func _simulate_registry(event_registry: Dictionary, context: Dictionary) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var events := event_registry.get("events", []) as Array if event_registry.get("events", []) is Array else []
	for event_index in events.size():
		var event_value: Variant = events[event_index]
		if not event_value is Dictionary:
			continue
		var event := event_value as Dictionary
		var reasons: Array[String] = []
		if str(event.get("event_type", "")) != "auto_trigger":
			reasons.append("不是 auto_trigger")
		else:
			reasons = _condition_failure_reasons(event.get("conditions", []) as Array if event.get("conditions", []) is Array else [], context)
		var event_id := str(event.get("event_id", "")).strip_edges()
		var location_condition := _location_condition_value(event.get("conditions", []))
		if context.has("location_id"):
			if location_condition.is_empty():
				reasons.append("地点进入回退要求 location 条件")
			elif location_condition != str(context.get("location_id", "")):
				reasons.append("地点需要 %s" % location_condition)
			elif (context.get("consumed_location_event_ids", []) as Array).has(event_id):
				reasons.append("该地点事件今天已触发")
		elif not bool(event.get("is_repeatable", false)) and (context.get("triggered_event_ids", []) as Array).has(event_id):
			reasons.append("非重复事件已触发")
		results.append({
			"source_type": "event_registry",
			"source_id": event_id,
			"target_path": str(event.get("trigger_script", "")).strip_edges(),
			"priority": -event_index,
			"source_index": event_index,
			"passed": reasons.is_empty(),
			"failure_reasons": reasons
		})
	return results


static func _map_failure_reasons(story: Dictionary, context: Dictionary) -> Array[String]:
	var reasons: Array[String] = []
	_check_array_match(reasons, story, "day_offsets", int(context.get("day_offset", 0)), "日期")
	if story.get("events", []) is Array and not (story.get("events", []) as Array).is_empty():
		var matched := false
		for event_value in story.get("events", []):
			if (context.get("active_events", []) as Array).has(str(event_value).strip_edges()):
				matched = true
				break
		if not matched:
			reasons.append("激活事件未命中 %s" % str(story.get("events", [])))
	_check_array_match(reasons, story, "weather", str(context.get("weather", "")), "天气")
	_check_array_match(reasons, story, "periods", str(context.get("period", "")), "时段")
	var stage := int(context.get("stage", 0))
	if story.has("min_stage") and stage < int(story.min_stage):
		reasons.append("阶段 %d 低于 %d" % [stage, int(story.min_stage)])
	if story.has("max_stage") and stage > int(story.max_stage):
		reasons.append("阶段 %d 高于 %d" % [stage, int(story.max_stage)])
	if str(story.get("trigger_script", "")).strip_edges().is_empty():
		reasons.append("缺少 trigger_script")
	return reasons


static func _condition_failure_reasons(conditions: Array, context: Dictionary) -> Array[String]:
	var reasons: Array[String] = []
	for condition_value in conditions:
		if not condition_value is Dictionary:
			continue
		var condition := condition_value as Dictionary
		var condition_type := str(condition.get("type", ""))
		match condition_type:
			"location":
				if str(context.get("location_id", "")) != str(condition.get("value", "")):
					reasons.append("地点需要 %s" % str(condition.get("value", "")))
			"time_period":
				if str(context.get("period", "")) != str(condition.get("value", "")):
					reasons.append("时段需要 %s" % str(condition.get("value", "")))
			"weather":
				var required := str(condition.get("value", ""))
				var weather := str(context.get("weather", ""))
				if required.is_empty() or (required != weather and not weather.contains(required)):
					reasons.append("天气需要 %s" % required)
			"time":
				var hour := int(context.get("hour", 0))
				if hour < int(condition.get("start_hour", 0)) or hour >= int(condition.get("end_hour", 24)):
					reasons.append("小时需在 %d-%d" % [int(condition.get("start_hour", 0)), int(condition.get("end_hour", 24))])
			"stage":
				if int(context.get("stage", 0)) < int(condition.get("min_stage", 0)):
					reasons.append("好感阶段不足")
			"npc_stage":
				var npc_id := str(condition.get("npc_id", ""))
				var npc_stages := context.get("npc_stages", {}) as Dictionary if context.get("npc_stages", {}) is Dictionary else {}
				if int(npc_stages.get(npc_id, 0)) < int(condition.get("min_stage", 0)):
					reasons.append("NPC %s 阶段不足" % npc_id)
			"stat":
				var stat_name := str(condition.get("stat_name", ""))
				var stats := context.get("stats", {}) as Dictionary if context.get("stats", {}) is Dictionary else {}
				if float(stats.get(stat_name, 0)) < float(condition.get("value", 0)):
					reasons.append("属性 %s 不足" % stat_name)
			_:
				reasons.append("不支持条件 %s" % condition_type)
	return reasons


static func _check_array_match(reasons: Array[String], source: Dictionary, field: String, actual: Variant, label: String) -> void:
	if source.get(field, []) is Array and not (source.get(field, []) as Array).is_empty() and not (source.get(field, []) as Array).has(actual):
		reasons.append("%s不匹配，需要 %s" % [label, str(source.get(field, []))])


static func _location_condition_value(conditions: Variant) -> String:
	if not conditions is Array:
		return ""
	for condition_value in conditions:
		if condition_value is Dictionary and str((condition_value as Dictionary).get("type", "")).strip_edges() == "location":
			return str((condition_value as Dictionary).get("value", "")).strip_edges()
	return ""


static func _append_unique(target: Array[String], values: Variant) -> void:
	if not values is Array:
		return
	for value in values:
		var normalized := str(value).strip_edges()
		if not normalized.is_empty() and not target.has(normalized):
			target.append(normalized)