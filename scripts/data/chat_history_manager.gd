class_name ChatHistoryManager
extends Resource

const SafeFileAccess = preload("res://scripts/utils/safe_file_access.gd")
const HISTORY_PATH = "user://chat_history.json"

# 每个记录包含: type (String), speaker (String), text (String), time (String), voice_cache_key (String, 可选)
# 额外可附带: module/subtype/topic/is_choice 等扩展字段
# type 当前主要包含:
# - "main_chat": 主场景日常对话
# - "story_chat": 剧情自由对话
# - "fixed_story": 固定剧情
# - "normal": 兼容旧数据
var messages: Array = []

func get_history_path() -> String:
	var char_id = GameDataManager.config.current_character_id if GameDataManager.config else "default"
	if char_id == "": char_id = "default"
	return GameDataManager.get_character_save_path("chat_history.json", char_id)

func add_message(speaker: String, text: String, voice_cache_key: String = "", type: String = "normal", extra_data: Dictionary = {}) -> void:
	var record = {
		"type": type,
		"speaker": speaker,
		"text": text,
		"time": Time.get_datetime_string_from_system(),
		"voice_cache_key": voice_cache_key
	}
	if not extra_data.is_empty():
		record.merge(extra_data, true)
	messages.append(record)
	save_history()

func save_history() -> void:
	var content = JSON.stringify(messages, "\t")
	SafeFileAccess.store_string(get_history_path(), content)

func load_history() -> void:
	var path = get_history_path()
	messages.clear()
	
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		var content = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var error = json.parse(content)
		if error == OK:
			var data = json.get_data()
			if data is Array:
				messages = data
	else:
		# 尝试迁移旧的历史记录
		var old_path = "user://chat_history.json"
		if FileAccess.file_exists(old_path):
			var dir = DirAccess.open("user://")
			dir.copy(old_path, path)
			load_history()

func clear_history() -> void:
	messages.clear()
	save_history()

func get_messages_by_type(type_filter: String) -> Array:
	if type_filter == "all" or type_filter == "":
		return messages.duplicate()
	var filtered = []
	for msg in messages:
		if msg.has("type"):
			var t = msg["type"]
			if t == type_filter:
				filtered.append(msg)
			elif type_filter == "story_chat" and t == "fixed_story":
				filtered.append(msg)
	return filtered

func get_messages_by_module(module_id: String) -> Array:
	match module_id:
		"daily":
			return get_messages_by_type("main_chat")
		"story":
			return get_messages_by_type("story_chat")
		_:
			return get_messages_by_type(module_id)

func get_module_title(module_id: String) -> String:
	match module_id:
		"daily":
			return "日常对话历史"
		"story":
			return "剧情对话历史"
		_:
			return "对话历史"
