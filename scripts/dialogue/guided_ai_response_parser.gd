extends RefCounted


static func parse_response(content: String, candidate_beat_ids: Array[String]) -> Dictionary:
	var normalized_content := content.strip_edges()
	if normalized_content.begins_with("```json"):
		normalized_content = normalized_content.substr(7)
	elif normalized_content.begins_with("```"):
		normalized_content = normalized_content.substr(3)
	if normalized_content.ends_with("```"):
		normalized_content = normalized_content.substr(0, normalized_content.length() - 3)
	var parsed: Variant = JSON.parse_string(normalized_content.strip_edges())
	if not parsed is Dictionary:
		return {"ok": false, "error": "响应不是有效 JSON 对象。"}
	var envelope := parsed as Dictionary
	var dialogue := str(envelope.get("dialogue", "")).strip_edges()
	if dialogue.is_empty():
		return {"ok": false, "error": "响应缺少 dialogue。"}
	var covered_beat_ids: Array[String] = []
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
	return {"ok": true, "dialogue": dialogue, "covered_beat_ids": covered_beat_ids}


static func _normalize_evidence_text(text: String) -> String:
	var normalized := text.replace("[SPLIT]", " ")
	for whitespace in ["\t", "\r", "\n", "\u00a0", "\u1680", "\u2000", "\u2001", "\u2002", "\u2003", "\u2004", "\u2005", "\u2006", "\u2007", "\u2008", "\u2009", "\u200a", "\u2028", "\u2029", "\u202f", "\u205f", "\u3000"]:
		normalized = normalized.replace(whitespace, " ")
	return " ".join(normalized.split(" ", false)).strip_edges()