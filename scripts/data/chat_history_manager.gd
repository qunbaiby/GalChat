class_name ChatHistoryManager
extends Resource

const HISTORY_PATH = "user://chat_history.json"

# 每个记录包含: type (String), speaker (String), text (String), time (String), voice_cache_key (String, 可选)
# type 包含: "normal" (普通对话), "fixed_story" (固定剧情), "fixed_call" (固定语音/视频通话)
var messages: Array = []

func get_history_path() -> String:
	var char_id = GameDataManager.config.current_character_id if GameDataManager.config else "default"
	if char_id == "": char_id = "default"
	var dir_path = "user://saves/%s" % char_id
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)
	return "%s/chat_history.json" % dir_path

func add_message(speaker: String, text: String, voice_cache_key: String = "", type: String = "normal") -> void:
	var record = {
		"type": type,
		"speaker": speaker,
		"text": text,
		"time": Time.get_datetime_string_from_system(),
		"voice_cache_key": voice_cache_key
	}
	messages.append(record)
	save_history()

func save_history() -> void:
	var file = FileAccess.open(get_history_path(), FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(messages, "\t"))
		file.close()

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
