@tool
extends RefCounted

const JsonService = preload("res://addons/story_editor/core/story_json_service.gd")

const IMAGE_DATA := "res://assets/data/images/image_data.json"
const AUDIO_DATA := "res://assets/data/audio/audio_data.json"
const EXPRESSION_DATA := "res://assets/data/mood/expression_config.json"
const CALL_DATA := "res://assets/data/story/scripts/calls/fixed_calls.json"
const CHARACTER_ROOTS := [
	"res://assets/data/characters",
	"res://assets/data/characters/npc"
]


static func build() -> Dictionary:
	return {
		"image": _collect_grouped_ids(IMAGE_DATA),
		"audio": _collect_grouped_ids(AUDIO_DATA),
		"expression": _collect_root_array_ids(EXPRESSION_DATA, "id"),
		"call": _collect_root_array_ids(CALL_DATA, "id"),
		"character": _collect_characters()
	}


static func _collect_grouped_ids(path: String) -> Array[Dictionary]:
	var result := JsonService.load_dictionary(path)
	var entries: Array[Dictionary] = []
	if not result.get("ok", false):
		return entries
	var data := result.get("data", {}) as Dictionary
	for group_value in data.keys():
		var group := str(group_value)
		var items_value: Variant = data[group_value]
		if not items_value is Array:
			continue
		for item_value in items_value:
			if item_value is Dictionary:
				var item := item_value as Dictionary
				var id := str(item.get("id", ""))
				if not id.is_empty():
					entries.append({"id": id, "label": str(item.get("name", id)), "group": group, "path": str(item.get("path", ""))})
	return entries


static func _collect_object_array_ids(path: String, id_key: String) -> Array[Dictionary]:
	var result := JsonService.load_dictionary(path)
	var entries: Array[Dictionary] = []
	if not result.get("ok", false):
		return entries
	var data := result.get("data", {}) as Dictionary
	for value in data.values():
		if not value is Array:
			continue
		for item_value in value:
			if item_value is Dictionary:
				var id := str((item_value as Dictionary).get(id_key, ""))
				if not id.is_empty():
					entries.append({"id": id, "label": id})
	return entries


static func _collect_root_array_ids(path: String, id_key: String) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if not FileAccess.file_exists(path):
		return entries
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return entries
	var value: Variant = JSON.parse_string(file.get_as_text())
	if not value is Array:
		return entries
	for item_value in value:
		if item_value is Dictionary:
			var item := item_value as Dictionary
			var id := str(item.get(id_key, ""))
			if not id.is_empty():
				entries.append({"id": id, "label": str(item.get("name", "%s · %s" % [id, str(item.get("char_id", ""))]))})
	return entries


static func _collect_characters() -> Array[Dictionary]:
	var entries: Array[Dictionary] = [
		{"id": "旁白", "label": "旁白"},
		{"id": "player", "label": "玩家"}
	]
	for root in CHARACTER_ROOTS:
		var directory := DirAccess.open(root)
		if directory == null:
			continue
		directory.list_dir_begin()
		var entry := directory.get_next()
		while not entry.is_empty():
			if not directory.current_is_dir() and entry.get_extension().to_lower() == "json" and not entry.contains("_stages"):
				var result := JsonService.load_dictionary(root.path_join(entry))
				if result.get("ok", false):
					var data := result.get("data", {}) as Dictionary
					var id := entry.get_basename()
					var label := str(data.get("display_name", data.get("char_name", id)))
					entries.append({"id": id, "label": label})
			entry = directory.get_next()
		directory.list_dir_end()
	return entries