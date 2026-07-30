extends RefCounted


static func parse_response(content: String, candidate_beat_ids: Array[String]) -> Dictionary:
	var normalized_content := _normalize_response_content(content)
	var parser := JSON.new()
	if parser.parse(normalized_content) != OK:
		return {"ok": false, "error": "响应不是有效 JSON 对象。"}
	var parsed: Variant = parser.data
	if not parsed is Dictionary:
		return {"ok": false, "error": "响应不是有效 JSON 对象。"}
	var envelope := parsed as Dictionary
	var dialogue := str(envelope.get("dialogue", "")).strip_edges()
	if dialogue.is_empty():
		return {"ok": false, "error": "响应缺少 dialogue。"}
	var covered_beat_ids: Array[String] = []
	var next_options: Array[Dictionary] = []
	var evaluations_value: Variant = envelope.get("beat_evaluations", [])
	if evaluations_value is Array:
		var searchable_dialogue := _normalize_evidence_text(dialogue)
		for evaluation_value in evaluations_value:
			if not evaluation_value is Dictionary:
				continue
			var evaluation := evaluation_value as Dictionary
			var beat_id_value: Variant = evaluation.get("id", "")
			var covered_value: Variant = evaluation.get("covered", false)
			var evidence_value: Variant = evaluation.get("evidence", "")
			if not beat_id_value is String or not covered_value is bool or not evidence_value is String or not covered_value:
				continue
			var beat_id := (beat_id_value as String).strip_edges()
			var evidence := _normalize_evidence_text(evidence_value as String)
			if candidate_beat_ids.has(beat_id) and not covered_beat_ids.has(beat_id) and not evidence.is_empty() and searchable_dialogue.contains(evidence):
				covered_beat_ids.append(beat_id)
	var options_value: Variant = envelope.get("next_options", [])
	if options_value is Array:
		for option_value in options_value:
			if not option_value is Dictionary or next_options.size() >= 2:
				continue
			var option := option_value as Dictionary
			var option_text := str(option.get("text", "")).strip_edges()
			var option_focus := str(option.get("focus", "intimacy")).strip_edges().to_lower()
			if option_text.is_empty() or next_options.any(func(existing: Dictionary) -> bool: return str(existing.get("text", "")) == option_text):
				continue
			next_options.append({"text": option_text, "focus": "trust" if option_focus == "trust" else "intimacy"})
	return {"ok": true, "dialogue": dialogue, "covered_beat_ids": covered_beat_ids, "next_options": next_options}


static func recover_dialogue(content: String) -> String:
	var normalized_content := _normalize_response_content(content)
	var parser := JSON.new()
	if parser.parse(normalized_content) == OK and parser.data is Dictionary:
		var parsed_dialogue := str((parser.data as Dictionary).get("dialogue", "")).strip_edges()
		if not parsed_dialogue.is_empty():
			return parsed_dialogue

	var dialogue_regex := RegEx.new()
	if dialogue_regex.compile('"dialogue"\\s*:\\s*"((?:\\\\.|[^"\\\\])*)"') == OK:
		var dialogue_match := dialogue_regex.search(normalized_content)
		if dialogue_match != null:
			var decoded: Variant = JSON.parse_string('"%s"' % dialogue_match.get_string(1))
			if decoded is String and not (decoded as String).strip_edges().is_empty():
				return (decoded as String).strip_edges()

	if normalized_content.begins_with("{") or normalized_content.begins_with("["):
		return ""
	for prefix in ["回复如下：", "回复如下:", "角色回复：", "角色回复:"]:
		if normalized_content.begins_with(prefix):
			normalized_content = normalized_content.trim_prefix(prefix).strip_edges()
	return normalized_content


static func _normalize_response_content(content: String) -> String:
	var normalized_content := content.strip_edges()
	if normalized_content.begins_with("```json"):
		normalized_content = normalized_content.substr(7)
	elif normalized_content.begins_with("```"):
		normalized_content = normalized_content.substr(3)
	if normalized_content.ends_with("```"):
		normalized_content = normalized_content.substr(0, normalized_content.length() - 3)
	normalized_content = normalized_content.strip_edges()
	var object_start := normalized_content.find("{")
	var object_end := normalized_content.rfind("}")
	if object_start >= 0 and object_end > object_start:
		normalized_content = normalized_content.substr(object_start, object_end - object_start + 1)
	return normalized_content


static func has_parenthetical_action(dialogue: String) -> bool:
	var action_regex := RegEx.new()
	if action_regex.compile("（[^（）]+）|\\([^()]+\\)") != OK:
		return false
	return action_regex.search(dialogue) != null


static func _normalize_evidence_text(text: String) -> String:
	var normalized := text.replace("[SPLIT]", " ")
	for whitespace in ["\t", "\r", "\n", "\u00a0", "\u1680", "\u2000", "\u2001", "\u2002", "\u2003", "\u2004", "\u2005", "\u2006", "\u2007", "\u2008", "\u2009", "\u200a", "\u2028", "\u2029", "\u202f", "\u205f", "\u3000"]:
		normalized = normalized.replace(whitespace, " ")
	return " ".join(normalized.split(" ", false)).strip_edges()
