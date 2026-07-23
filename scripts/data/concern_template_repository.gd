class_name ConcernTemplateRepository
extends RefCounted

const TEMPLATE_ROOT := "res://assets/data/interaction/concern_templates"


static func scan_templates(root_path: String = TEMPLATE_ROOT) -> Array[Dictionary]:
	var templates: Array[Dictionary] = []
	var directory := DirAccess.open(root_path)
	if directory == null:
		return templates
	var file_names := directory.get_files()
	file_names.sort()
	for file_name in file_names:
		if not file_name.to_lower().ends_with(".json"):
			continue
		var path := root_path.path_join(file_name)
		var template := load_template(path)
		if template.is_empty():
			continue
		template["source_path"] = path
		templates.append(template)
	return templates


static func load_template(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or not json.data is Dictionary:
		return {}
	var template := (json.data as Dictionary).duplicate(true)
	return template if validate_template(template).is_empty() else {}


static func validate_template(template: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if str(template.get("template_id", "")).strip_edges().is_empty():
		errors.append("缺少 template_id。")
	if str(template.get("title", "")).strip_edges().is_empty():
		errors.append("缺少 title。")
	if str(template.get("character_id", "")).strip_edges().is_empty():
		errors.append("缺少 character_id。")
	var intro_events: Variant = template.get("intro_events", [])
	if not intro_events is Array or (intro_events as Array).is_empty():
		errors.append("intro_events 至少需要一条内容。")
	var policy: Variant = template.get("guided_ai_policy", {})
	if not policy is Dictionary:
		errors.append("guided_ai_policy 必须是对象。")
	else:
		if str((policy as Dictionary).get("narrative_anchor", "")).strip_edges().is_empty():
			errors.append("guided_ai_policy 缺少 narrative_anchor。")
		if str((policy as Dictionary).get("scene_objective", "")).strip_edges().is_empty():
			errors.append("guided_ai_policy 缺少 scene_objective。")
		if int((policy as Dictionary).get("max_player_rounds", 0)) <= 0:
			errors.append("max_player_rounds 必须大于 0。")
	return errors


static func resolve_template(templates: Array[Dictionary], context: Dictionary, state: Dictionary = {}) -> Dictionary:
	var candidates: Array[Dictionary] = []
	for template in templates:
		if _matches(template, context, state):
			candidates.append(template)
	candidates.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_priority := int(left.get("priority", 0))
		var right_priority := int(right.get("priority", 0))
		if left_priority != right_priority:
			return left_priority > right_priority
		var left_character_specific := str(left.get("character_id", "")) != "*"
		var right_character_specific := str(right.get("character_id", "")) != "*"
		if left_character_specific != right_character_specific:
			return left_character_specific
		var left_specificity := _condition_specificity(left.get("conditions", {}) as Dictionary)
		var right_specificity := _condition_specificity(right.get("conditions", {}) as Dictionary)
		if left_specificity != right_specificity:
			return left_specificity > right_specificity
		return str(left.get("template_id", "")) < str(right.get("template_id", ""))
	)
	return candidates[0].duplicate(true) if not candidates.is_empty() else {}


static func resolve_for_context(context: Dictionary, state: Dictionary = {}, root_path: String = TEMPLATE_ROOT) -> Dictionary:
	return resolve_template(scan_templates(root_path), context, state)


static func _matches(template: Dictionary, context: Dictionary, state: Dictionary) -> bool:
	if not bool(template.get("enabled", true)):
		return false
	var template_character := str(template.get("character_id", "")).strip_edges().to_lower()
	var context_character := str(context.get("character_id", "")).strip_edges().to_lower()
	if template_character != "*" and template_character != context_character:
		return false
	var conditions: Dictionary = template.get("conditions", {})
	if not _matches_int_list(conditions.get("weekdays", []), int(context.get("weekday", -1))):
		return false
	if not _matches_string_list(conditions.get("time_periods", []), str(context.get("time_period", ""))):
		return false
	var stage := int(context.get("stage", 0))
	if stage < int(conditions.get("min_stage", 0)):
		return false
	var max_stage := int(conditions.get("max_stage", 0))
	if max_stage > 0 and stage > max_stage:
		return false
	if float(context.get("intimacy", 0.0)) < float(conditions.get("min_intimacy", 0.0)):
		return false
	if float(context.get("trust", 0.0)) < float(conditions.get("min_trust", 0.0)):
		return false
	var template_id := str(template.get("template_id", ""))
	var template_state: Dictionary = state.get(template_id, {})
	var availability: Dictionary = template.get("availability", {})
	var completion_count := int(template_state.get("completion_count", 0))
	if bool(availability.get("once", false)) and completion_count > 0:
		return false
	var max_completions := int(availability.get("max_completions", 0))
	if max_completions > 0 and completion_count >= max_completions:
		return false
	var cooldown_days := maxi(0, int(availability.get("cooldown_days", 0)))
	var last_started_day := int(template_state.get("last_started_day", -1000000))
	if cooldown_days > 0 and int(context.get("day_offset", 0)) - last_started_day < cooldown_days:
		return false
	return true


static func _matches_int_list(raw_values: Variant, value: int) -> bool:
	if not raw_values is Array or (raw_values as Array).is_empty():
		return true
	for raw_value in raw_values:
		if int(raw_value) == value:
			return true
	return false


static func _matches_string_list(raw_values: Variant, value: String) -> bool:
	if not raw_values is Array or (raw_values as Array).is_empty():
		return true
	for raw_value in raw_values:
		if str(raw_value) == value:
			return true
	return false


static func _condition_specificity(conditions: Dictionary) -> int:
	var specificity := 0
	for key in conditions.keys():
		var value: Variant = conditions.get(key)
		if value is Array and not (value as Array).is_empty():
			specificity += 1
		elif value is String and not str(value).is_empty():
			specificity += 1
		elif value is int or value is float:
			if float(value) != 0.0:
				specificity += 1
	return specificity
