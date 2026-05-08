extends Node

var bg_data: Dictionary = {}

func _ready() -> void:
	_load_bg_data()

func _load_bg_data() -> void:
	var path = "res://assets/data/backgrounds/background_data.json"
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			var data = json.data
			if typeof(data) == TYPE_DICTIONARY and data.has("backgrounds"):
				for item in data["backgrounds"]:
					if item.has("id") and item.has("path"):
						bg_data[item["id"]] = item["path"]

func get_bg_path(bg_id: String) -> String:
	if bg_data.has(bg_id):
		return bg_data[bg_id]
	push_warning("Background ID not found: " + bg_id)
	return ""