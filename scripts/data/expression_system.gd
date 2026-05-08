class_name ExpressionSystem
extends Node

const EXPRESSION_CONFIG_PATH = "res://assets/data/mood/expression_config.json"

# key 为表情的 id (如 "surprise")，value 为对应的字典数据
var expression_configs: Dictionary = {}
var all_expression_ids: Array = []
var all_expression_names: Array = []

func _init() -> void:
	_load_expression_configs()

func _load_expression_configs() -> void:
	if FileAccess.file_exists(EXPRESSION_CONFIG_PATH):
		var file = FileAccess.open(EXPRESSION_CONFIG_PATH, FileAccess.READ)
		var content = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		if json.parse(content) == OK:
			var data = json.get_data()
			if data is Array:
				for item in data:
					if item is Dictionary and item.has("id"):
						expression_configs[item["id"]] = item
						if item.has("name"):
							all_expression_names.append(item["name"])
				all_expression_ids = expression_configs.keys()
	else:
		printerr("Expression config not found: ", EXPRESSION_CONFIG_PATH)

func get_random_expression() -> String:
	if all_expression_ids.size() > 0:
		randomize()
		return all_expression_ids[randi() % all_expression_ids.size()]
	return "calm" # Fallback

func get_expression_description(expression_id: String) -> String:
	if expression_configs.has(expression_id):
		var config = expression_configs[expression_id]
		return "当前表情：{tag}。核心语气：{tone}。互动积极性：{activeness}。细节特征：{detail}".format({
			"tag": config.get("name", expression_id),
			"tone": config["tone"],
			"activeness": config["activeness"],
			"detail": config["detail"]
		})
	return "当前表情：平静。温和、淡然，无起伏。"

func is_valid_expression(expression_id: String) -> bool:
	return expression_configs.has(expression_id)

func get_expression_by_keywords(text: String) -> String:
	for expression_id in all_expression_ids:
		var config = expression_configs[expression_id]
		if config.has("keywords"):
			for keyword in config["keywords"]:
				if text.find(keyword) != -1:
					return expression_id
	return ""

func get_expression_sprite_path(expression_id: String) -> String:
	var ext_path = "user://game_data/characters/%s/avatar/%s.webp" % [GameDataManager.config.current_character_id, expression_id]
	if FileAccess.file_exists(ext_path):
		return ext_path
		
	ext_path = "user://game_data/characters/%s/avatar/%s.png" % [GameDataManager.config.current_character_id, expression_id]
	if FileAccess.file_exists(ext_path):
		return ext_path
		
	if expression_configs.has(expression_id):
		return expression_configs[expression_id].get("sprite_path", "")
	return ""

func get_expression_impact(expression_id: String) -> float:
	if expression_configs.has(expression_id):
		return float(expression_configs[expression_id].get("mood_impact", 0.0))
	return 0.0
