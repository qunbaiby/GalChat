class_name CharacterProfile
extends Resource

var char_name: String = "ayrrha"
var age: int = 22
var description: String = "大学刚毕业，计算机系，内向社恐，兴趣是独立游戏与蒸汽波音乐，对未来职业方向迷茫。"
var tags: Array = ["社恐", "温柔", "轻微傲娇", "依赖型"]

var intimacy: float = 0.0 # 0-100
var mood: float = 0.0 # -100 to +100
var trust: float = 10.0 # 0-100

const PROFILE_PATH = "user://character_profile.json"

func init_daily_mood() -> void:
    # 每日初始随机-20~+20
    randomize()
    mood = randf_range(-20.0, 20.0)

func update_intimacy(amount: float) -> void:
    intimacy = clamp(intimacy + amount, 0.0, 100.0)

func update_mood(amount: float) -> void:
    mood = clamp(mood + amount, -100.0, 100.0)

func update_trust(amount: float) -> void:
    trust = clamp(trust + amount, 0.0, 100.0)

func save_profile() -> void:
    var data = {
        "intimacy": intimacy,
        "mood": mood,
        "trust": trust
    }
    var file = FileAccess.open(PROFILE_PATH, FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify(data, "\t"))
        file.close()

func load_profile() -> void:
    if FileAccess.file_exists(PROFILE_PATH):
        var file = FileAccess.open(PROFILE_PATH, FileAccess.READ)
        var content = file.get_as_text()
        file.close()
        
        var json = JSON.new()
        var error = json.parse(content)
        if error == OK:
            var data = json.get_data()
            if data is Dictionary:
                intimacy = data.get("intimacy", intimacy)
                mood = data.get("mood", mood)
                trust = data.get("trust", trust)
    else:
        init_daily_mood()
        save_profile()
