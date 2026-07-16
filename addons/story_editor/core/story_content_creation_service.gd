@tool
extends RefCounted

const JsonService = preload("res://addons/story_editor/core/story_json_service.gd")
const FixedCallScanner = preload("res://addons/story_editor/core/fixed_voice_call_scanner.gd")

const DEFAULT_ROOTS := {
	"main_story": "res://assets/data/story/scripts/main",
	"map_story": "res://assets/data/story/scripts/events",
	"mobile_chat": "res://assets/data/mobile/fixed_chats"
}

static func create(kind: String, content_id: String, options: Dictionary = {}, roots: Dictionary = DEFAULT_ROOTS, calls_path: String = FixedCallScanner.CALL_PATH) -> Dictionary:
	var normalized_id := content_id.strip_edges()
	if not normalized_id.is_valid_filename() or normalized_id.is_empty() or normalized_id.contains(" ") or normalized_id.contains("."):
		return {"ok": false, "error": "ID 只能包含字母、数字、下划线和连字符。"}
	match kind:
		"main_story", "map_story":
			var path := str(roots.get(kind, "")).path_join(normalized_id + ".json")
			return _save_new_dictionary(path, {"script_id": normalized_id, "summary": str(options.get("name", "")), "chapters": {"start": {"events": [{"type": "dialogue", "speaker": "旁白", "content": "新剧情开始。"}]}}}, {"kind": "story", "path": path})
		"mobile_chat":
			var character_id := str(options.get("character_id", "")).strip_edges()
			if character_id.is_empty(): return {"ok": false, "error": "手机消息需要角色 ID。"}
			var path := str(roots.get(kind, "")).path_join(normalized_id + ".json")
			return _save_new_dictionary(path, {"id": normalized_id, "character_id": character_id, "messages": [{"id": "m1", "speaker": character_id, "text": "新消息", "delay": 0}], "on_complete_events": []}, {"kind": "mobile_chat", "id": normalized_id})
		"fixed_call":
			var character_id := str(options.get("character_id", "")).strip_edges()
			if character_id.is_empty(): return {"ok": false, "error": "固定来电需要角色 ID。"}
			var load_result := FixedCallScanner.load_calls(calls_path)
			if not load_result.get("ok", false): return load_result
			var calls := load_result.get("data", []) as Array
			for call in calls:
				if call is Dictionary and str(call.get("id", "")) == normalized_id: return {"ok": false, "error": "固定来电 ID 已存在。"}
			calls.append({"id": normalized_id, "char_id": character_id, "type": "voice_call", "lines": ["新通话台词"]})
			var save_result := JsonService.save_array(calls_path, calls)
			return {"ok": true, "target": {"kind": "fixed_call", "id": normalized_id}} if save_result.get("ok", false) else save_result
	return {"ok": false, "error": "不支持的固定内容类型。"}

static func _save_new_dictionary(path: String, data: Dictionary, target: Dictionary) -> Dictionary:
	if FileAccess.file_exists(path): return {"ok": false, "error": "目标 ID 已存在，未覆盖原文件。"}
	var result := JsonService.save_dictionary(path, data)
	return {"ok": true, "path": path, "target": target} if result.get("ok", false) else result