extends RefCounted

const MAX_DELIVERY_INSTRUCTION_CHARS := 300

const MAX_BEATS := 3
const ALLOWED_EVENT_TYPES := [
	"observable_state",
	"distance_change",
	"contact_change",
	"stance_change"
]
const DELIVERY_IDENTITY_TERMS := ["音色", "声线", "音高", "年龄", "年龄感", "性别", "身份"]
const DELIVERY_OVERRIDE_VERBS := ["改变", "改成", "换成", "切换", "变成", "调整为", "模拟", "模仿", "伪装"]
const DELIVERY_FORBIDDEN_VOICE_TYPES := ["男声", "女声", "少女音", "萝莉音", "御姐音", "娃娃音", "童声", "少年音", "大叔音", "老人音"]
const ACTION_PLACEHOLDER_TERMS := ["本段未提供可见动作", "未提供动作", "没有动作", "无动作", "不做动作"]


func validate(raw_response: Variant) -> Dictionary:
	var parsed: Variant = raw_response
	if raw_response is String:
		var json := JSON.new()
		if json.parse(raw_response) != OK:
			return _failure(["REALIZE_TURN_JSON_INVALID"])
		parsed = json.get_data()
	if not parsed is Dictionary:
		return _failure(["REALIZE_TURN_JSON_INVALID"])

	var root := parsed as Dictionary
	var issues: Array[String] = []
	_require_exact_keys(root, ["turn_result", "segments"], "REALIZE_TURN_ROOT_INVALID", issues)
	if not root.get("turn_result") is Dictionary or not root.get("segments") is Array:
		_append_issue(issues, "REALIZE_TURN_ROOT_INVALID")
		return _failure(issues)

	var turn_result := root["turn_result"] as Dictionary
	_require_exact_keys(turn_result, [
		"player_input_addressed",
		"character_response",
		"interaction_change",
		"interaction_beats"
	], "TURN_RESULT_STRUCTURE_INVALID", issues)
	for field_name in ["player_input_addressed", "character_response", "interaction_change"]:
		if not _is_non_empty_text(turn_result.get(field_name), 500):
			_append_issue(issues, "TURN_RESULT_SUMMARY_INVALID")

	var beats_value: Variant = turn_result.get("interaction_beats")
	if not beats_value is Array:
		_append_issue(issues, "INTERACTION_BEATS_INVALID")
		return _failure(issues)
	var beats := beats_value as Array
	var segments := root["segments"] as Array
	if beats.is_empty() or beats.size() > MAX_BEATS:
		_append_issue(issues, "INTERACTION_BEATS_INVALID")
	if beats.size() != segments.size():
		_append_issue(issues, "SEGMENT_BEAT_COUNT_MISMATCH")

	for index in range(beats.size()):
		_validate_beat(beats[index], index, issues)
	for index in range(segments.size()):
		_validate_segment(segments[index], index, issues)
	var aligned_count: int = mini(beats.size(), segments.size())
	for index in range(aligned_count):
		if beats[index] is Dictionary and segments[index] is Dictionary:
			var expected_id := "beat_%d" % (index + 1)
			if str(beats[index].get("beat_id", "")) != expected_id or str(segments[index].get("beat_id", "")) != expected_id:
				_append_issue(issues, "SEGMENT_BEAT_ID_MISMATCH")
			_validate_vocalization_realization(beats[index], segments[index], issues)

	if not issues.is_empty():
		return _failure(issues)
	return {
		"ok": true,
		"value": root.duplicate(true),
		"issue_codes": []
	}


func _validate_beat(value: Variant, index: int, issues: Array[String]) -> void:
	if not value is Dictionary:
		_append_issue(issues, "INTERACTION_BEAT_STRUCTURE_INVALID")
		return
	var beat := value as Dictionary
	_require_exact_keys(beat, ["beat_id", "interaction_change", "felt_response", "speech_contribution"], "INTERACTION_BEAT_STRUCTURE_INVALID", issues)
	if str(beat.get("beat_id", "")) != "beat_%d" % (index + 1):
		_append_issue(issues, "INTERACTION_BEAT_ID_INVALID")
	if not _is_non_empty_text(beat.get("interaction_change"), 500) or not _is_non_empty_text(beat.get("speech_contribution"), 500):
		_append_issue(issues, "INTERACTION_BEAT_TEXT_INVALID")
	if not beat.get("felt_response") is Dictionary:
		_append_issue(issues, "FELT_RESPONSE_INVALID")
		return
	var felt := beat["felt_response"] as Dictionary
	_require_exact_keys(felt, ["physical", "psychological", "audible"], "FELT_RESPONSE_INVALID", issues)
	for field_name in ["physical", "psychological"]:
		var field_value: Variant = felt.get(field_name)
		if field_value != null and not _is_non_empty_text(field_value, 500):
			_append_issue(issues, "FELT_RESPONSE_INVALID")
	_validate_audible(felt.get("audible"), issues)


func _validate_audible(value: Variant, issues: Array[String]) -> void:
	if value == null:
		return
	if not value is Dictionary:
		_append_issue(issues, "AUDIBLE_RESPONSE_INVALID")
		return
	var audible := value as Dictionary
	_require_exact_keys(audible, ["description", "vocalizations"], "AUDIBLE_RESPONSE_INVALID", issues)
	if not _is_non_empty_text(audible.get("description"), 500) or not audible.get("vocalizations") is Array:
		_append_issue(issues, "AUDIBLE_RESPONSE_INVALID")
		return
	for item in audible["vocalizations"]:
		if not item is Dictionary:
			_append_issue(issues, "AUDIBLE_VOCALIZATION_INVALID")
			continue
		var vocalization := item as Dictionary
		_require_exact_keys(vocalization, ["text", "placement_hint", "performance_hint"], "AUDIBLE_VOCALIZATION_INVALID", issues)
		for field_name in ["text", "placement_hint", "performance_hint"]:
			if not _is_non_empty_text(vocalization.get(field_name), 200):
				_append_issue(issues, "AUDIBLE_VOCALIZATION_INVALID")


func _validate_segment(value: Variant, index: int, issues: Array[String]) -> void:
	if not value is Dictionary:
		_append_issue(issues, "SEGMENT_STRUCTURE_INVALID")
		return
	var segment := value as Dictionary
	_require_exact_keys(segment, ["beat_id", "action", "speech", "delivery_instruction"], "SEGMENT_STRUCTURE_INVALID", issues)
	if str(segment.get("beat_id", "")) != "beat_%d" % (index + 1):
		_append_issue(issues, "SEGMENT_BEAT_ID_MISMATCH")
	var speech: String = str(segment.get("speech", "")).strip_edges()
	if speech.is_empty() or speech.length() > 1000:
		_append_issue(issues, "SPEECH_INVALID")
	if _contains_stage_direction(speech):
		_append_issue(issues, "SPEECH_STAGE_DIRECTION_INVALID")
	if not _is_non_empty_text(segment.get("delivery_instruction"), MAX_DELIVERY_INSTRUCTION_CHARS):
		_append_issue(issues, "DELIVERY_INSTRUCTION_INVALID")
	elif _contains_delivery_identity_override(str(segment.get("delivery_instruction", ""))):
		_append_issue(issues, "DELIVERY_IDENTITY_OVERRIDE")
	_validate_action(segment.get("action"), issues)


func _validate_action(value: Variant, issues: Array[String]) -> void:
	if not value is Dictionary:
		_append_issue(issues, "ACTION_STRUCTURE_INVALID")
		return
	var action := value as Dictionary
	_require_exact_keys(action, ["actor_id", "description", "persistent_effect"], "ACTION_STRUCTURE_INVALID", issues)
	if str(action.get("actor_id", "")) != "character":
		_append_issue(issues, "ACTION_ACTOR_INVALID")
	var description := str(action.get("description", "")).strip_edges()
	if not _is_non_empty_text(description, 500) or ACTION_PLACEHOLDER_TERMS.any(func(term: String): return description.contains(term)):
		_append_issue(issues, "ACTION_DESCRIPTION_INVALID")
	var effect: Variant = action.get("persistent_effect")
	if effect == null:
		return
	if not effect is Dictionary:
		_append_issue(issues, "PERSISTENT_EFFECT_INVALID")
		return
	var persistent_effect := effect as Dictionary
	_require_exact_keys(persistent_effect, ["event_type", "target_id", "status", "description"], "PERSISTENT_EFFECT_INVALID", issues)
	if not ALLOWED_EVENT_TYPES.has(str(persistent_effect.get("event_type", ""))):
		_append_issue(issues, "PERSISTENT_EFFECT_INVALID")
	if str(persistent_effect.get("target_id", "")) != "character" or str(persistent_effect.get("status", "")) != "completed":
		_append_issue(issues, "PERSISTENT_EFFECT_OWNERSHIP_INVALID")
	if not _is_non_empty_text(persistent_effect.get("description"), 500):
		_append_issue(issues, "PERSISTENT_EFFECT_INVALID")


func _validate_vocalization_realization(beat: Dictionary, segment: Dictionary, issues: Array[String]) -> void:
	var felt: Variant = beat.get("felt_response")
	if not felt is Dictionary:
		return
	var audible: Variant = felt.get("audible")
	if not audible is Dictionary or not audible.get("vocalizations") is Array:
		return
	var required_counts: Dictionary = {}
	for item in audible["vocalizations"]:
		if item is Dictionary:
			var text := str(item.get("text", ""))
			if not text.is_empty():
				required_counts[text] = int(required_counts.get(text, 0)) + 1
	var speech := str(segment.get("speech", ""))
	var delivery := str(segment.get("delivery_instruction", ""))
	for text in required_counts:
		var required_count := int(required_counts[text])
		if speech.count(text) < required_count:
			_append_issue(issues, "AUDIBLE_VOCALIZATION_MISSING")
		if delivery.count(text) < required_count:
			_append_issue(issues, "AUDIBLE_DELIVERY_MISSING")


func _contains_stage_direction(speech: String) -> bool:
	return speech.contains("(") or speech.contains(")") or speech.contains("（") or speech.contains("）") or speech.contains("<voice:")


func _contains_delivery_identity_override(instruction: String) -> bool:
	var normalized := instruction.to_lower()
	for voice_type in DELIVERY_FORBIDDEN_VOICE_TYPES:
		if normalized.contains(str(voice_type).to_lower()):
			return true
	for override_verb in DELIVERY_OVERRIDE_VERBS:
		if not normalized.contains(str(override_verb).to_lower()):
			continue
		for identity_term in DELIVERY_IDENTITY_TERMS:
			if normalized.contains(str(identity_term).to_lower()):
				return true
	return false


func _is_non_empty_text(value: Variant, max_length: int) -> bool:
	return value is String and not str(value).strip_edges().is_empty() and str(value).length() <= max_length


func _require_exact_keys(value: Dictionary, expected: Array, issue_code: String, issues: Array[String]) -> void:
	if value.size() != expected.size():
		_append_issue(issues, issue_code)
		return
	for key in expected:
		if not value.has(key):
			_append_issue(issues, issue_code)
			return


func _append_issue(issues: Array[String], issue_code: String) -> void:
	if not issues.has(issue_code):
		issues.append(issue_code)


func _failure(issues: Array[String]) -> Dictionary:
	return {
		"ok": false,
		"value": {},
		"issue_codes": issues.duplicate()
	}