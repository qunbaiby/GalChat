@tool
extends RefCounted


static func validate(calls_value: Variant, catalogs: Dictionary = {}, references: Dictionary = {}) -> Array[Dictionary]:
	var diagnostics: Array[Dictionary] = []
	if not calls_value is Array:
		_add(diagnostics, "error", "根节点", "固定来电文件根节点必须是数组。")
		return diagnostics
	var calls := calls_value as Array
	var call_ids := {}
	var character_ids := catalogs.get("character_ids", []) as Array
	for call_index in calls.size():
		var location := "通话 #%d" % (call_index + 1)
		var call_value: Variant = calls[call_index]
		if not call_value is Dictionary:
			_add(diagnostics, "error", location, "固定来电必须是对象。")
			continue
		var call := call_value as Dictionary
		var call_id := str(call.get("id", "")).strip_edges()
		if call_id.is_empty():
			_add(diagnostics, "error", location, "缺少通话 id。")
		elif call_ids.has(call_id):
			_add(diagnostics, "error", location, "通话 ID 重复：%s" % call_id)
		else:
			call_ids[call_id] = true
		var character_id := str(call.get("char_id", "")).strip_edges()
		if character_id.is_empty():
			_add(diagnostics, "error", location, "缺少 char_id。")
		elif not character_ids.is_empty() and not character_ids.has(character_id):
			_add(diagnostics, "error", location, "角色不存在：%s" % character_id)
		if str(call.get("type", "")) != "voice_call":
			_add(diagnostics, "error", location, "type 必须为 voice_call。")
		var lines_value: Variant = call.get("lines")
		if not lines_value is Array or (lines_value as Array).is_empty():
			_add(diagnostics, "error", location, "lines 必须是非空数组。")
			continue
		for line_index in (lines_value as Array).size():
			var line_value: Variant = (lines_value as Array)[line_index]
			if not line_value is String or str(line_value).strip_edges().is_empty():
				_add(diagnostics, "error", "%s / 台词 #%d" % [location, line_index + 1], "台词必须是非空字符串。")
	for call_id_value in references.keys():
		var referenced_id := str(call_id_value)
		if not call_ids.has(referenced_id):
			for reference_value in references[referenced_id]:
				var reference := reference_value as Dictionary if reference_value is Dictionary else {}
				_add(diagnostics, "error", "%s / %s" % [str(reference.get("story_id", "剧情")), str(reference.get("chapter_id", "?"))], "引用的固定来电不存在：%s" % referenced_id)
	return diagnostics


static func _add(diagnostics: Array[Dictionary], severity: String, location: String, message: String) -> void:
	diagnostics.append({"severity": severity, "location": location, "message": message})