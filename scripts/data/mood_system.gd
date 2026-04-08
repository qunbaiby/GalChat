class_name MoodSystem
extends Node

const MOOD_CONFIG_PATH = "res://assets/data/mood/mood_config.json"

# key 为心情的 id (如 "surprise")，value 为对应的字典数据
var mood_configs: Dictionary = {}
var all_mood_ids: Array = []
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
                    if item is Dictionary and item.has("id"):
                        mood_configs[item["id"]] = item
                        if item.has("name"):
                            all_mood_names.append(item["name"])
                all_mood_ids = mood_configs.keys()
    else:
        printerr("Mood config not found: ", MOOD_CONFIG_PATH)

func get_random_mood() -> String:
    if all_mood_ids.size() > 0:
        randomize()
        return all_mood_ids[randi() % all_mood_ids.size()]
    return "calm" # Fallback

func get_mood_description(mood_id: String) -> String:
    if mood_configs.has(mood_id):
        var config = mood_configs[mood_id]
        return "当前心情：{tag}。核心语气：{tone}。互动积极性：{activeness}。细节特征：{detail}".format({
            "tag": config.get("name", mood_id),
            "tone": config["tone"],
            "activeness": config["activeness"],
            "detail": config["detail"]
        })
    return "当前心情：平静。温和、淡然，无起伏。"

func is_valid_mood(mood_id: String) -> bool:
    return mood_configs.has(mood_id)

func get_mood_by_keywords(text: String) -> String:
    for mood_id in all_mood_ids:
        var config = mood_configs[mood_id]
        if config.has("keywords"):
            for keyword in config["keywords"]:
                if text.find(keyword) != -1:
                    return mood_id
    return ""

func get_mood_sprite_path(mood_id: String) -> String:
    if mood_configs.has(mood_id):
        return mood_configs[mood_id].get("sprite_path", "")
    return ""

func get_intimacy_multiplier(mood_id: String) -> float:
    if mood_configs.has(mood_id):
        return mood_configs[mood_id].get("intimacy_multiplier", 1.0)
    return 1.0

func get_trust_multiplier(mood_id: String) -> float:
    if mood_configs.has(mood_id):
        return mood_configs[mood_id].get("trust_multiplier", 1.0)
    return 1.0

func get_exp_bonus(mood_id: String) -> int:
    if mood_configs.has(mood_id):
        return mood_configs[mood_id].get("exp_bonus", 0)
    return 0
