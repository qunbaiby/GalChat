@tool
extends RefCounted

const JsonService = preload("res://addons/story_editor/core/story_json_service.gd")
const StoryScanner = preload("res://addons/story_editor/core/story_scanner.gd")
const CALL_PATH := "res://assets/data/story/scripts/calls/fixed_calls.json"


static func scan(path: String = CALL_PATH) -> Array[Dictionary]:
	var references := scan_story_references()
	var calls: Array[Dictionary] = []
	var load_result := _load_array(path)
	if not load_result.get("ok", false):
		return calls
	for call_value in load_result.get("data", []):
		if not call_value is Dictionary:
			continue
		var call := call_value as Dictionary
		var call_id := str(call.get("id", ""))
		calls.append({
			"id": call_id,
			"character_id": str(call.get("char_id", "")),
			"line_count": (call.get("lines", []) as Array).size(),
			"path": path,
			"references": (references.get(call_id, []) as Array).duplicate(true)
		})
	return calls


static func scan_story_references() -> Dictionary:
	var references := {}
	for story in StoryScanner.scan():
		var result := JsonService.load_dictionary(str(story.get("path", "")))
		if not result.get("ok", false):
			continue
		var data := result.get("data", {}) as Dictionary
		var story_id := str(data.get("script_id", story.get("name", "")))
		var chapters := data.get("chapters", {}) as Dictionary
		for chapter_id_value in chapters.keys():
			var chapter_id := str(chapter_id_value)
			var chapter := chapters.get(chapter_id, {}) as Dictionary
			for event_index in (chapter.get("events", []) as Array).size():
				var event_value: Variant = (chapter.get("events", []) as Array)[event_index]
				if not event_value is Dictionary:
					continue
				var event := event_value as Dictionary
				if str(event.get("type", "")) != "voice_call":
					continue
				var call_id := str(event.get("call_id", "")).strip_edges()
				if call_id.is_empty():
					continue
				var call_references: Array = references.get(call_id, [])
				call_references.append({
					"story_id": story_id,
					"chapter_id": chapter_id,
					"event_index": event_index,
					"path": story.get("path", "")
				})
				references[call_id] = call_references
	return references


static func load_calls(path: String = CALL_PATH) -> Dictionary:
	return _load_array(path)


static func _load_array(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "文件不存在：%s" % path}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "error": "无法读取：%s" % path}
	var json := JSON.new()
	var parse_error := json.parse(file.get_as_text())
	if parse_error != OK:
		return {"ok": false, "error": "JSON 解析失败（第 %d 行）：%s" % [json.get_error_line(), json.get_error_message()]}
	if not json.data is Array:
		return {"ok": false, "error": "固定来电文件根节点必须是数组。"}
	return {"ok": true, "data": (json.data as Array).duplicate(true)}