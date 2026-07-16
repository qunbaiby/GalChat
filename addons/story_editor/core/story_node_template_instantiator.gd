@tool
extends RefCounted


static func instantiate_template(template: Dictionary, parameters: Dictionary, current_data: Dictionary, anchor: Vector2 = Vector2.ZERO) -> Dictionary:
	var missing: Array[String] = []
	for definition in template.get("parameters", []):
		if definition is Dictionary:
			var name := str(definition.get("name", ""))
			if bool(definition.get("required", false)) and not parameters.has(name) and not definition.has("default"):
				missing.append(name)
	if not missing.is_empty():
		return {"ok": false, "diagnostics": [{"severity": "error", "message": "缺少参数：%s" % ", ".join(missing)}]}
	var values := {}
	for definition in template.get("parameters", []):
		if definition is Dictionary:
			var name := str(definition.get("name", ""))
			values[name] = parameters.get(name, definition.get("default"))
	var payload := template.get("payload", {}) as Dictionary
	var existing_chapters := current_data.get("chapters", {}) as Dictionary
	var chapter_map := {}
	for local_id in (payload.get("chapters", {}) as Dictionary).keys():
		chapter_map[str(local_id)] = _unique_id("%s_%s" % [str(template.get("id", "template")), str(local_id)], existing_chapters.keys() + chapter_map.values())
	var events_source := payload.get("events", payload.get("entry_events", [])) as Array
	var events: Array[Dictionary] = []
	for index in events_source.size():
		var event := _resolve(events_source[index], values, chapter_map) as Dictionary
		if event.has("event_id"):
			event.event_id = _unique_event_id(str(event.event_id), current_data)
		_refresh_option_ids(event)
		var position := event.get("_editor_position", {}) as Dictionary
		event["_editor_position"] = {"x": anchor.x + float(position.get("x", index * 280)), "y": anchor.y + float(position.get("y", 0))}
		events.append(event)
	var chapters := {}
	for local_id in (payload.get("chapters", {}) as Dictionary).keys():
		chapters[chapter_map[str(local_id)]] = _resolve((payload.chapters as Dictionary)[local_id], values, chapter_map)
	return {"ok": true, "events": events, "chapters": chapters, "chapter_map": chapter_map, "diagnostics": []}


static func _resolve(value: Variant, parameters: Dictionary, chapter_map: Dictionary) -> Variant:
	if value is Dictionary:
		if value.has("$param"):
			return parameters.get(str(value["$param"]), null)
		if value.has("$chapter"):
			return chapter_map.get(str(value["$chapter"]), str(value["$chapter"]))
		var result := {}
		for key in value.keys():
			result[key] = _resolve(value[key], parameters, chapter_map)
		return result
	if value is Array:
		var result := []
		for item in value:
			result.append(_resolve(item, parameters, chapter_map))
		return result
	if value is String:
		var text := value as String
		for key in parameters:
			text = text.replace("${%s}" % key, str(parameters[key]))
		return text
	return value


static func _refresh_option_ids(event: Dictionary) -> void:
	if str(event.get("type", "")) != "choice":
		return
	var used := {}
	for option in event.get("options", []):
		if option is Dictionary:
			var base := str(option.get("id", "option")).strip_edges()
			option.id = _unique_id(base if not base.is_empty() else "option", used.keys())
			used[option.id] = true


static func _unique_event_id(base: String, data: Dictionary) -> String:
	var ids: Array = []
	for chapter in (data.get("chapters", {}) as Dictionary).values():
		if chapter is Dictionary:
			for event in chapter.get("events", []):
				if event is Dictionary and event.has("event_id"):
					ids.append(str(event.event_id))
	return _unique_id(base, ids)


static func _unique_id(base: String, existing: Array) -> String:
	var candidate := base
	var suffix := 2
	while existing.has(candidate):
		candidate = "%s_%d" % [base, suffix]
		suffix += 1
	return candidate