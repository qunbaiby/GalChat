@tool
extends RefCounted

const JsonService = preload("res://addons/story_editor/core/story_json_service.gd")
const DEFAULT_PATH := "res://assets/data/config/story_editor_event_templates.json"
const SCHEMA_VERSION := 2


static func load_templates(path: String = DEFAULT_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": true, "templates": []}
	var result := JsonService.load_dictionary(path)
	if not result.get("ok", false):
		return result
	var data := result.get("data", {}) as Dictionary
	var schema_version := int(data.get("schema_version", -1))
	if schema_version not in [1, SCHEMA_VERSION]:
		return {"ok": false, "error": "自定义模板版本不受支持。"}
	var templates_value: Variant = data.get("templates", null)
	if not templates_value is Array:
		return {"ok": false, "error": "自定义模板列表必须是数组。"}
	var templates: Array[Dictionary] = []
	var names := {}
	var ids := {}
	for template_value in templates_value as Array:
		if not template_value is Dictionary:
			return {"ok": false, "error": "自定义模板项必须是对象。"}
		var template := template_value as Dictionary
		var template_id := str(template.get("id", "")).strip_edges()
		var template_name := str(template.get("name", "")).strip_edges()
		var normalized := template.duplicate(true)
		if schema_version == 1:
			var legacy_events := template.get("events", []) as Array
			normalized["kind"] = "event" if legacy_events.size() == 1 else "fragment"
			normalized["payload"] = {"events": legacy_events.duplicate(true)}
			normalized["parameters"] = []
		var payload := normalized.get("payload", {}) as Dictionary
		var events_value: Variant = payload.get("events", payload.get("entry_events", []))
		if template_id.is_empty() or template_name.is_empty() or not events_value is Array or (events_value as Array).is_empty():
			return {"ok": false, "error": "自定义模板缺少有效的 id、name 或 payload 事件。"}
		if ids.has(template_id) or names.has(template_name):
			return {"ok": false, "error": "自定义模板 ID 或名称重复。"}
		for event_value in events_value as Array:
			if not event_value is Dictionary or str((event_value as Dictionary).get("type", "")).is_empty():
				return {"ok": false, "error": "自定义模板包含无效事件。"}
		ids[template_id] = true
		names[template_name] = true
		normalized["events"] = (events_value as Array).duplicate(true)
		templates.append(normalized)
	return {"ok": true, "templates": templates}


static func save_event(name: String, event: Dictionary, path: String = DEFAULT_PATH) -> Dictionary:
	return save_events(name, [event], path)


static func save_events(name: String, events: Array, path: String = DEFAULT_PATH) -> Dictionary:
	var normalized_name := name.strip_edges()
	if normalized_name.is_empty():
		return {"ok": false, "error": "模板名称不能为空。"}
	if events.is_empty():
		return {"ok": false, "error": "至少需要选择一个事件。"}
	var stored_events: Array[Dictionary] = []
	for event_value in events:
		if not event_value is Dictionary or str((event_value as Dictionary).get("type", "")).is_empty():
			return {"ok": false, "error": "选区包含无效事件。"}
		stored_events.append((event_value as Dictionary).duplicate(true))
	var load_result := load_templates(path)
	if not load_result.get("ok", false):
		return load_result
	var templates := load_result.get("templates", []) as Array
	for template_value in templates:
		if template_value is Dictionary and str((template_value as Dictionary).get("name", "")) == normalized_name:
			return {"ok": false, "error": "已存在同名自定义模板。"}
	var template_id := _make_template_id(templates)
	templates.append({"id": template_id, "name": normalized_name, "kind": "event" if stored_events.size() == 1 else "fragment", "parameters": [], "payload": {"events": stored_events}})
	var save_result := JsonService.save_dictionary(path, {"schema_version": SCHEMA_VERSION, "templates": templates})
	if not save_result.get("ok", false):
		return save_result
	return {"ok": true, "templates": templates, "template_id": template_id}


static func save_template(template: Dictionary, path: String = DEFAULT_PATH) -> Dictionary:
	var candidate := template.duplicate(true)
	if str(candidate.get("name", "")).strip_edges().is_empty():
		return {"ok": false, "error": "模板名称不能为空。"}
	var load_result := load_templates(path)
	if not load_result.get("ok", false):
		return load_result
	var templates := load_result.get("templates", []) as Array
	if str(candidate.get("id", "")).is_empty():
		candidate["id"] = _make_template_id(templates)
	for existing in templates:
		if existing is Dictionary and (str(existing.get("id", "")) == str(candidate.id) or str(existing.get("name", "")) == str(candidate.name)):
			return {"ok": false, "error": "模板 ID 或名称重复。"}
	templates.append(candidate)
	var save_result := JsonService.save_dictionary(path, {"schema_version": SCHEMA_VERSION, "templates": templates})
	return {"ok": true, "templates": templates, "template_id": candidate.id} if save_result.get("ok", false) else save_result


static func delete_template(template_id: String, path: String = DEFAULT_PATH) -> Dictionary:
	var load_result := load_templates(path)
	if not load_result.get("ok", false):
		return load_result
	var templates := load_result.get("templates", []) as Array
	var remove_index := -1
	for index in templates.size():
		var template := templates[index] as Dictionary
		if str(template.get("id", "")) == template_id:
			remove_index = index
			break
	if remove_index < 0:
		return {"ok": false, "error": "自定义模板不存在。"}
	templates.remove_at(remove_index)
	var save_result := JsonService.save_dictionary(path, {"schema_version": SCHEMA_VERSION, "templates": templates})
	if not save_result.get("ok", false):
		return save_result
	return {"ok": true, "templates": templates}


static func rename_template(template_id: String, new_name: String, path: String = DEFAULT_PATH) -> Dictionary:
	var normalized_name := new_name.strip_edges()
	if normalized_name.is_empty():
		return {"ok": false, "error": "模板名称不能为空。"}
	var load_result := load_templates(path)
	if not load_result.get("ok", false):
		return load_result
	var templates := load_result.get("templates", []) as Array
	var found := false
	for template in templates:
		if template is Dictionary and str(template.get("name", "")) == normalized_name and str(template.get("id", "")) != template_id:
			return {"ok": false, "error": "已存在同名模板。"}
		if template is Dictionary and str(template.get("id", "")) == template_id:
			template.name = normalized_name
			found = true
	if not found:
		return {"ok": false, "error": "自定义模板不存在。"}
	var save_result := JsonService.save_dictionary(path, {"schema_version": SCHEMA_VERSION, "templates": templates})
	return {"ok": true, "templates": templates} if save_result.get("ok", false) else save_result


static func _make_template_id(templates: Array) -> String:
	var base_id := "event_template_%d" % int(Time.get_unix_time_from_system() * 1000.0)
	var candidate := base_id
	var suffix := 2
	while _has_template_id(templates, candidate):
		candidate = "%s_%d" % [base_id, suffix]
		suffix += 1
	return candidate


static func _has_template_id(templates: Array, template_id: String) -> bool:
	for template_value in templates:
		if template_value is Dictionary and str((template_value as Dictionary).get("id", "")) == template_id:
			return true
	return false