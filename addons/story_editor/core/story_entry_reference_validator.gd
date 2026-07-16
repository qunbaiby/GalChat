@tool
extends RefCounted

const JsonService = preload("res://addons/story_editor/core/story_json_service.gd")


static func validate(scan_result: Dictionary) -> Array[Dictionary]:
	var diagnostics: Array[Dictionary] = []
	diagnostics.assign((scan_result.get("source_diagnostics", []) as Array).map(func(value: Variant) -> Dictionary:
		return (value as Dictionary).duplicate(true) if value is Dictionary else {}
	).filter(func(value: Dictionary) -> bool: return not value.is_empty()))
	_validate_event_entries(scan_result.get("event_entries", []) as Array, diagnostics)
	for reference_value in scan_result.get("references", []):
		if not reference_value is Dictionary:
			continue
		var reference := reference_value as Dictionary
		var target_path := str(reference.get("target_path", "")).strip_edges()
		var location := "%s / %s" % [str(reference.get("source_id", "未命名入口")), str(reference.get("location", "?"))]
		if target_path.is_empty():
			_add(diagnostics, "error", "missing_target", location, "剧情入口缺少目标剧情路径。", reference)
		elif not FileAccess.file_exists(target_path):
			_add(diagnostics, "error", "missing_target", location, "目标剧情不存在：%s" % target_path, reference)
		else:
			_validate_target_metadata(reference, target_path, location, diagnostics)
	_validate_unreferenced_stories(scan_result, diagnostics)
	return diagnostics


static func _validate_target_metadata(reference: Dictionary, target_path: String, location: String, diagnostics: Array[Dictionary]) -> void:
	var load_result := JsonService.load_dictionary(target_path)
	if not load_result.get("ok", false):
		_add(diagnostics, "error", "target_invalid", location, "目标剧情无法读取：%s" % str(load_result.get("error", "未知错误")), reference)
		return
	var target := load_result.get("data", {}) as Dictionary
	var expected_script_id := str(reference.get("expected_script_id", "")).strip_edges()
	var actual_script_id := str(target.get("script_id", "")).strip_edges()
	if not expected_script_id.is_empty() and expected_script_id != actual_script_id:
		_add(diagnostics, "error", "script_id_mismatch", location, "入口期望 script_id=%s，但目标剧情声明为 %s。" % [expected_script_id, actual_script_id if not actual_script_id.is_empty() else "<空>"], reference)
	if str(reference.get("source_type", "")) != "story_schedule" or not target.has("day_offset"):
		return
	var scheduled_day := int(reference.get("day_offset", -1))
	var declared_day := int(target.get("day_offset", -1))
	if scheduled_day != declared_day:
		_add(diagnostics, "warning", "schedule_day_mismatch", location, "日程安排 day_offset=%d，但目标剧情声明 day_offset=%d。" % [scheduled_day, declared_day], reference)


static func _validate_unreferenced_stories(scan_result: Dictionary, diagnostics: Array[Dictionary]) -> void:
	var referenced_paths := {}
	for reference_value in scan_result.get("references", []):
		if reference_value is Dictionary:
			var target_path := str((reference_value as Dictionary).get("target_path", "")).strip_edges()
			if not target_path.is_empty():
				referenced_paths[target_path] = true
	for story_path_value in scan_result.get("story_paths", []):
		var story_path := str(story_path_value).strip_edges()
		if not story_path.is_empty() and not referenced_paths.has(story_path):
			_add(diagnostics, "warning", "unreferenced_story", story_path, "固定剧情没有已扫描的运行时入口。", {"target_path": story_path})


static func _validate_event_entries(entries: Array, diagnostics: Array[Dictionary]) -> void:
	var ids := {}
	var condition_owners := {}
	for entry_value in entries:
		if not entry_value is Dictionary:
			continue
		var entry := entry_value as Dictionary
		var event_id := str(entry.get("source_id", "")).strip_edges()
		var location := str(entry.get("location", "Event Registry"))
		if event_id.is_empty():
			_add(diagnostics, "error", "missing_event_id", location, "事件入口缺少 event_id。", entry)
		elif ids.has(event_id):
			_add(diagnostics, "error", "duplicate_event_id", location, "event_id 重复：%s" % event_id, entry)
		else:
			ids[event_id] = true
		_validate_conditions(entry, diagnostics)
		if str(entry.get("event_type", "")) != "auto_trigger":
			continue
		var signature := _condition_signature(entry.get("conditions", []) as Array)
		if condition_owners.has(signature):
			_add(diagnostics, "warning", "condition_conflict", location, "自动事件条件与 %s 完全相同，运行时只会触发首个匹配项。" % str(condition_owners[signature]), entry)
		else:
			condition_owners[signature] = event_id if not event_id.is_empty() else location


static func _validate_conditions(entry: Dictionary, diagnostics: Array[Dictionary]) -> void:
	var conditions_value: Variant = entry.get("conditions", [])
	if not conditions_value is Array:
		_add(diagnostics, "error", "invalid_conditions", str(entry.get("location", "Event Registry")), "conditions 必须是数组。", entry)
		return
	for condition_index in (conditions_value as Array).size():
		var condition_value: Variant = (conditions_value as Array)[condition_index]
		var location := "%s / conditions / #%d" % [str(entry.get("location", "Event Registry")), condition_index + 1]
		if not condition_value is Dictionary:
			_add(diagnostics, "error", "invalid_condition", location, "条件必须是对象。", entry)
			continue
		var condition := condition_value as Dictionary
		var condition_type := str(condition.get("type", "")).strip_edges()
		match condition_type:
			"location", "time_period", "weather":
				_require_text(condition, "value", condition_type, location, entry, diagnostics)
			"time":
				var start_hour := int(condition.get("start_hour", -1))
				var end_hour := int(condition.get("end_hour", -1))
				if start_hour < 0 or start_hour > 23 or end_hour < 1 or end_hour > 24 or start_hour >= end_hour:
					_add(diagnostics, "error", "invalid_condition_value", location, "小时范围必须满足 0 <= start_hour < end_hour <= 24。", entry)
			"stat":
				_require_text(condition, "stat_name", condition_type, location, entry, diagnostics)
			"stage":
				if int(condition.get("min_stage", -1)) < 0:
					_add(diagnostics, "error", "invalid_condition_value", location, "min_stage 不能小于 0。", entry)
			"npc_stage":
				_require_text(condition, "npc_id", condition_type, location, entry, diagnostics)
				if int(condition.get("min_stage", -1)) < 0:
					_add(diagnostics, "error", "invalid_condition_value", location, "min_stage 不能小于 0。", entry)
			_:
				_add(diagnostics, "error", "unsupported_condition", location, "运行时不支持条件类型：%s" % (condition_type if not condition_type.is_empty() else "<空>"), entry)


static func _require_text(condition: Dictionary, field: String, condition_type: String, location: String, entry: Dictionary, diagnostics: Array[Dictionary]) -> void:
	if str(condition.get(field, "")).strip_edges().is_empty():
		_add(diagnostics, "error", "invalid_condition_value", location, "%s 条件缺少 %s。" % [condition_type, field], entry)


static func _condition_signature(conditions: Array) -> String:
	var normalized: Array[String] = []
	for condition_value in conditions:
		if condition_value is Dictionary:
			normalized.append(JSON.stringify(_sorted_dictionary(condition_value as Dictionary)))
		else:
			normalized.append(JSON.stringify(condition_value))
	normalized.sort()
	return "|".join(normalized)


static func _sorted_dictionary(value: Dictionary) -> Dictionary:
	var result := {}
	var keys: Array = value.keys()
	keys.sort_custom(func(left: Variant, right: Variant) -> bool: return str(left) < str(right))
	for key in keys:
		var child: Variant = value[key]
		result[str(key)] = _sorted_dictionary(child as Dictionary) if child is Dictionary else child
	return result


static func _add(diagnostics: Array[Dictionary], severity: String, code: String, location: String, message: String, reference: Dictionary) -> void:
	diagnostics.append({
		"severity": severity,
		"code": code,
		"location": location,
		"message": message,
		"reference": reference.duplicate(true)
	})