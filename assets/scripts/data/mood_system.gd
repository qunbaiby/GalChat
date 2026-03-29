class_name MoodSystem
extends Node

const MOOD_CONFIG_PATH = "res://assets/data/mood/mood_config.json"

# key 为心情的名称 (如 "惊喜")，value 为对应的字典数据
var mood_configs: Dictionary = {}
var all_mood_names: Array = []

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
                for item in data:
                    if item is Dictionary and item.has("name"):
                        mood_configs[item["name"]] = item
                all_mood_names = mood_configs.keys()
    else:
        printerr("Mood config not found: ", MOOD_CONFIG_PATH)

func get_random_mood() -> String:
    if all_mood_names.size() > 0:
        randomize()
        return all_mood_names[randi() % all_mood_names.size()]
    return "平静" # Fallback

func get_mood_description(mood_name: String) -> String:
    if mood_configs.has(mood_name):
        var config = mood_configs[mood_name]
        return "当前心情：{tag}。核心语气：{tone}。互动积极性：{activeness}。细节特征：{detail}".format({
            "tag": mood_name,
            "tone": config["tone"],
            "activeness": config["activeness"],
            "detail": config["detail"]
        })
    return "当前心情：平静。温和、淡然，无起伏。"

func is_valid_mood(mood_name: String) -> bool:
    return mood_configs.has(mood_name)

func get_mood_by_keywords(text: String) -> String:
    for mood_name in all_mood_names:
        var config = mood_configs[mood_name]
        if config.has("keywords"):
            for keyword in config["keywords"]:
                if text.find(keyword) != -1:
                    return mood_name
    return ""

func get_mood_sprite_path(mood_name: String) -> String:
    if mood_configs.has(mood_name):
        return mood_configs[mood_name].get("sprite_path", "")
    return ""

func get_intimacy_multiplier(mood_name: String) -> float:
    if mood_configs.has(mood_name):
        return mood_configs[mood_name].get("intimacy_multiplier", 1.0)
    return 1.0

func get_trust_multiplier(mood_name: String) -> float:
    if mood_configs.has(mood_name):
        return mood_configs[mood_name].get("trust_multiplier", 1.0)
    return 1.0

func get_exp_bonus(mood_name: String) -> int:
    if mood_configs.has(mood_name):
        return mood_configs[mood_name].get("exp_bonus", 0)
    return 0
