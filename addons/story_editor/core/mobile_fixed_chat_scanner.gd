@tool
extends RefCounted

const JsonService = preload("res://addons/story_editor/core/story_json_service.gd")
const StoryScanner = preload("res://addons/story_editor/core/story_scanner.gd")
const CHAT_ROOT := "res://assets/data/mobile/fixed_chats"


static func scan() -> Array[Dictionary]:
	var references := _scan_story_references()
	var chats: Array[Dictionary] = []
	var directory := DirAccess.open(CHAT_ROOT)
	if directory == null:
		return chats
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if not directory.current_is_dir() and entry.get_extension().to_lower() == "json":
			var path := CHAT_ROOT.path_join(entry)
			var result := JsonService.load_dictionary(path)
			if result.get("ok", false):
				var data := result.get("data", {}) as Dictionary
				var chat_id := str(data.get("id", entry.get_basename()))
				chats.append({
					"id": chat_id,
					"character_id": str(data.get("character_id", "")),
					"message_count": (data.get("messages", []) as Array).size(),
					"completion_event_count": (data.get("on_complete_events", []) as Array).size(),
					"path": path,
					"references": (references.get(chat_id, []) as Array).duplicate(true)
				})
		entry = directory.get_next()
	directory.list_dir_end()
	chats.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return str(left.get("id", "")) < str(right.get("id", ""))
	)
	return chats


static func _scan_story_references() -> Dictionary:
	var references := {}
	for story in StoryScanner.scan():
		var result := JsonService.load_dictionary(str(story.get("path", "")))
		if not result.get("ok", false):
			continue
		var data := result.get("data", {}) as Dictionary
		var story_id := str(data.get("script_id", story.get("name", "")))
		var events := data.get("post_story_events", []) as Array
		for event_value in events:
			if not event_value is Dictionary:
				continue
			var event := event_value as Dictionary
			if str(event.get("type", "")) != "fixed_chat":
				continue
			var chat_id := str(event.get("script_id", "")).strip_edges()
			if chat_id.is_empty():
				continue
			var chat_references: Array = references.get(chat_id, [])
			chat_references.append({"story_id": story_id, "path": story.get("path", ""), "timing": str(event.get("timing", "immediate"))})
			references[chat_id] = chat_references
	return references