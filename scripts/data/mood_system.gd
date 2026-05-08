class_name MoodSystem
extends Node

const MOOD_CONFIG_PATH = "res://assets/data/mood/mood_config.json"

var macro_mood_configs: Array = []

func _init() -> void:
	_load_mood_configs()

func _load_mood_configs() -> void:
	if FileAccess.file_exists(MOOD_CONFIG_PATH):
		var file = FileAccess.open(MOOD_CONFIG_PATH, FileAccess.READ)
		var content = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		if json.parse(content) == OK:
			var data = json.get_data()
			if data is Array:
				macro_mood_configs = data
	else:
		printerr("Mood config not found: ", MOOD_CONFIG_PATH)

func get_macro_mood(mood_value: float) -> Dictionary:
	for config in macro_mood_configs:
		if mood_value >= config.get("min_value", 0) and mood_value <= config.get("max_value", 100):
			return config
	
	# Fallback to calm
	return {
		"id": "calm",
		"name": "平静",
		"intimacy_multiplier": 1.0,
		"trust_multiplier": 1.0,
		"exp_bonus": 0
	}

func get_macro_mood_name(mood_value: float) -> String:
	var mood = get_macro_mood(mood_value)
	return mood.get("name", "平静")

func get_intimacy_multiplier(mood_value: float) -> float:
	var mood = get_macro_mood(mood_value)
	return float(mood.get("intimacy_multiplier", 1.0))

func get_trust_multiplier(mood_value: float) -> float:
	var mood = get_macro_mood(mood_value)
	return float(mood.get("trust_multiplier", 1.0))

func get_exp_bonus(mood_value: float) -> int:
	var mood = get_macro_mood(mood_value)
	return int(mood.get("exp_bonus", 0))

func get_stat_bonus_rate(mood_value: float) -> float:
	var mood = get_macro_mood(mood_value)
	return float(mood.get("stat_bonus_rate", 0.0))
