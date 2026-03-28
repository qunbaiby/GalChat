class_name ChatHistoryManager
extends Resource

const HISTORY_PATH = "user://chat_history.json"

# 每个记录包含: speaker (String), text (String), time (String), voice_cache_key (String, 可选)
var messages: Array = []

func add_message(speaker: String, text: String, voice_cache_key: String = "") -> void:
    var record = {
        "speaker": speaker,
        "text": text,
        "time": Time.get_datetime_string_from_system(),
        "voice_cache_key": voice_cache_key
    }
    messages.append(record)
    save_history()

func save_history() -> void:
    var file = FileAccess.open(HISTORY_PATH, FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify(messages, "\t"))
        file.close()

func load_history() -> void:
    if FileAccess.file_exists(HISTORY_PATH):
        var file = FileAccess.open(HISTORY_PATH, FileAccess.READ)
        var content = file.get_as_text()
        file.close()
        
        var json = JSON.new()
        var error = json.parse(content)
        if error == OK:
            var data = json.get_data()
            if data is Array:
                messages = data

func clear_history() -> void:
    messages.clear()
    save_history()
