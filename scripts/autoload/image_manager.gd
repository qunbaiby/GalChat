extends Node

var image_data: Dictionary = {}

func _ready() -> void:
	_load_image_data()

func _load_image_data() -> void:
	var path = "res://assets/data/images/image_data.json"
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			var data = json.data
			if typeof(data) == TYPE_DICTIONARY:
				# Iterate over all categories like backgrounds, cgs, maps, ui, etc.
				for category in data.keys():
					var category_list = data[category]
					if typeof(category_list) == TYPE_ARRAY:
						for item in category_list:
							if typeof(item) == TYPE_DICTIONARY and item.has("id") and item.has("path"):
								image_data[item["id"]] = item["path"]

func get_image_path(img_id: String) -> String:
	if image_data.has(img_id):
		return image_data[img_id]
	push_warning("Image ID not found: " + img_id)
	return ""
