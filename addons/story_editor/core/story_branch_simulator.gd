@tool
extends RefCounted

const MAX_STEPS := 512


static func simulate(data: Dictionary, initial_variables: Dictionary = {}) -> Array[Dictionary]:
	var chapters := data.get("chapters", {}) as Dictionary
	if not chapters.has("start"):
		return [{"status": "error", "message": "缺少 start 章节。", "trace": [], "choices": [], "variables": initial_variables.duplicate(true), "effects": {}}]
	var results: Array[Dictionary] = []
	_walk(chapters, "start", 0, initial_variables.duplicate(true), {}, [], [], {}, 0, results)
	return results


static func _walk(
	chapters: Dictionary,
	chapter_id: String,
	event_index: int,
	variables: Dictionary,
	effects: Dictionary,
	choices: Array,
	trace: Array,
	visited: Dictionary,
	step_count: int,
	results: Array[Dictionary]
) -> void:
	if step_count >= MAX_STEPS:
		_append_result(results, "error", "超过最大模拟步数。", trace, choices, variables, effects)
		return
	if chapter_id == "end":
		_append_result(results, "ended", "到达 end。", trace, choices, variables, effects)
		return
	if not chapters.has(chapter_id):
		_append_result(results, "error", "目标章节不存在：%s" % chapter_id, trace, choices, variables, effects)
		return
	var chapter := chapters.get(chapter_id, {}) as Dictionary
	var events := chapter.get("events", []) as Array
	if event_index >= events.size():
		_append_result(results, "ended", "章节 %s 执行完毕。" % chapter_id, trace, choices, variables, effects)
		return
	var state_key := "%s:%d" % [chapter_id, event_index]
	if visited.has(state_key):
		_append_result(results, "loop", "检测到循环：%s" % state_key, trace, choices, variables, effects)
		return
	var next_visited := visited.duplicate()
	next_visited[state_key] = true
	var event_value: Variant = events[event_index]
	if not event_value is Dictionary:
		_append_result(results, "error", "%s 事件不是对象。" % state_key, trace, choices, variables, effects)
		return
	var event := event_value as Dictionary
	var event_type := str(event.get("type", ""))
	var next_trace := trace.duplicate()
	next_trace.append({"chapter": chapter_id, "event_index": event_index, "type": event_type})
	if event_type == "jump":
		_walk(chapters, str(event.get("target_chapter", "")), 0, variables, effects, choices, next_trace, next_visited, step_count + 1, results)
		return
	if event_type == "choice":
		var options := event.get("options", []) as Array
		if options.is_empty():
			_append_result(results, "error", "%s 没有可模拟选项。" % state_key, next_trace, choices, variables, effects)
			return
		for option_index in options.size():
			var option_value: Variant = options[option_index]
			if not option_value is Dictionary:
				_append_result(results, "error", "%s 选项 #%d 不是对象。" % [state_key, option_index + 1], next_trace, choices, variables, effects)
				continue
			var option := option_value as Dictionary
			var next_choices := choices.duplicate()
			next_choices.append({"chapter": chapter_id, "event_index": event_index, "option_index": option_index, "id": str(option.get("id", "")), "text": str(option.get("text", option.get("label", "")))})
			var next_effects := effects.duplicate(true)
			_apply_effects(next_effects, option.get("effects", {}) as Dictionary)
			var target := str(option.get("target_chapter", "")).strip_edges()
			if target.is_empty():
				_walk(chapters, chapter_id, event_index + 1, variables.duplicate(true), next_effects, next_choices, next_trace.duplicate(), next_visited.duplicate(), step_count + 1, results)
			else:
				_walk(chapters, target, 0, variables.duplicate(true), next_effects, next_choices, next_trace.duplicate(), next_visited.duplicate(), step_count + 1, results)
		return
	var next_variables := variables
	if event_type == "set_variable":
		next_variables = variables.duplicate(true)
		next_variables[str(event.get("var_name", ""))] = event.get("var_value")
	_walk(chapters, chapter_id, event_index + 1, next_variables, effects, choices, next_trace, next_visited, step_count + 1, results)


static func _apply_effects(total: Dictionary, delta: Dictionary) -> void:
	for key_value in delta.keys():
		var key := str(key_value)
		var value: Variant = delta[key_value]
		if value is int or value is float:
			total[key] = float(total.get(key, 0.0)) + float(value)


static func _append_result(results: Array[Dictionary], status: String, message: String, trace: Array, choices: Array, variables: Dictionary, effects: Dictionary) -> void:
	results.append({
		"status": status,
		"message": message,
		"trace": trace.duplicate(true),
		"choices": choices.duplicate(true),
		"variables": variables.duplicate(true),
		"effects": effects.duplicate(true)
	})