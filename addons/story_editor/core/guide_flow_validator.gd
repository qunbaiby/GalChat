@tool
extends RefCounted

const JsonService = preload("res://addons/story_editor/core/story_json_service.gd")
const SUPPORTED_STEP_TYPES := ["message", "wait_action", "play_story"]


static func validate(root_data: Dictionary) -> Array[Dictionary]:
	var diagnostics: Array[Dictionary] = []
	var guides_value: Variant = root_data.get("guides")
	if not guides_value is Array:
		_add(diagnostics, "error", "invalid_guides", "根节点", "guides 必须是数组。")
		return diagnostics
	var guide_ids := {}
	for guide_index in (guides_value as Array).size():
		var guide_value: Variant = (guides_value as Array)[guide_index]
		var guide_location := "guides / #%d" % (guide_index + 1)
		if not guide_value is Dictionary:
			_add(diagnostics, "error", "invalid_guide", guide_location, "Guide 必须是对象。")
			continue
		var guide := guide_value as Dictionary
		var guide_id := str(guide.get("id", "")).strip_edges()
		if guide_id.is_empty():
			_add(diagnostics, "error", "missing_guide_id", guide_location, "Guide 缺少 id。")
		elif guide_ids.has(guide_id):
			_add(diagnostics, "error", "duplicate_guide_id", guide_location, "Guide ID 重复：%s" % guide_id)
		else:
			guide_ids[guide_id] = true
		_validate_steps(guide, guide_location, diagnostics)
	return diagnostics


static func _validate_steps(guide: Dictionary, guide_location: String, diagnostics: Array[Dictionary]) -> void:
	var steps_value: Variant = guide.get("steps")
	if not steps_value is Array or (steps_value as Array).is_empty():
		_add(diagnostics, "error", "invalid_steps", guide_location, "steps 必须是非空数组。")
		return
	var step_ids := {}
	for step_index in (steps_value as Array).size():
		var step_value: Variant = (steps_value as Array)[step_index]
		var location := "%s / steps / #%d" % [guide_location, step_index + 1]
		if not step_value is Dictionary:
			_add(diagnostics, "error", "invalid_step", location, "步骤必须是对象。")
			continue
		var step := step_value as Dictionary
		var step_id := str(step.get("id", "")).strip_edges()
		if step_id.is_empty():
			_add(diagnostics, "error", "missing_step_id", location, "步骤缺少 id。")
		elif step_ids.has(step_id):
			_add(diagnostics, "error", "duplicate_step_id", location, "同一 Guide 内步骤 ID 重复：%s" % step_id)
		else:
			step_ids[step_id] = true
		var step_type := str(step.get("type", "message")).strip_edges()
		if not SUPPORTED_STEP_TYPES.has(step_type):
			_add(diagnostics, "error", "unsupported_step_type", location, "不支持的步骤类型：%s" % step_type)
		if step_type == "wait_action" and str(step.get("wait_action", "")).strip_edges().is_empty():
			_add(diagnostics, "error", "missing_wait_action", location, "wait_action 步骤缺少 wait_action。")
		if step_type == "play_story":
			_validate_story_step(step, location, diagnostics)


static func _validate_story_step(step: Dictionary, location: String, diagnostics: Array[Dictionary]) -> void:
	var story_path := str(step.get("story_path", "")).strip_edges()
	if story_path.is_empty() or not FileAccess.file_exists(story_path):
		_add(diagnostics, "error", "missing_story_target", location, "Guide 剧情目标不存在：%s" % (story_path if not story_path.is_empty() else "<空>"))
		return
	var load_result := JsonService.load_dictionary(story_path)
	if not load_result.get("ok", false):
		_add(diagnostics, "error", "invalid_story_target", location, "Guide 剧情目标无法读取。")
		return
	var expected_id := str(step.get("script_id", "")).strip_edges()
	var actual_id := str((load_result.get("data", {}) as Dictionary).get("script_id", "")).strip_edges()
	if not expected_id.is_empty() and expected_id != actual_id:
		_add(diagnostics, "error", "guide_script_id_mismatch", location, "步骤 script_id=%s，但目标剧情声明为 %s。" % [expected_id, actual_id])


static func _add(diagnostics: Array[Dictionary], severity: String, code: String, location: String, message: String) -> void:
	diagnostics.append({"severity": severity, "code": code, "location": location, "message": message})