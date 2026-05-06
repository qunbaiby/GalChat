class_name CharacterProfile
extends Resource

var char_name: String = ""
var player_name: String = ""
var age: int = 22
var description: String = ""
var tags: Array = []
var spine_path: String = ""
var avatar: String = ""

var intimacy: float = 0.0 # 0-9999
var current_mood: String = "平静" # 从 9 种状态中选取
var last_login_date: String = "" # 用于判断是否跨天
var trust: float = 10.0 # 0-9999
var current_stage: int = 1 # 1-8
var interaction_exp: int = 0

var stages_config: Array = []
var base_personality: Dictionary = {}

var openness: float = 50.0
var conscientiousness: float = 50.0
var extraversion: float = 50.0
var agreeableness: float = 50.0
var neuroticism: float = 50.0

var last_online_time: int = 0

# 四基十六维养成体系数值
# 体力 (Physical)
var stat_stamina: float = 0.0 # 体能续航
var stat_body_management: float = 0.0 # 形体管控
var stat_focus: float = 0.0 # 凝心专注
var stat_rhythm: float = 0.0 # 律动反应
# 智力 (Intelligence)
var stat_artistic_literacy: float = 0.0 # 艺术素养
var stat_verbal_expression: float = 0.0 # 言辞表达
var stat_planning: float = 0.0 # 统筹企划
var stat_art_theory: float = 0.0 # 艺理钻研
# 魅力 (Charm)
var stat_temperament: float = 0.0 # 格调气质
var stat_manner: float = 0.0 # 举止仪范
var stat_emotional_infection: float = 0.0 # 共情感染
var stat_stage_performance: float = 0.0 # 舞台表现
# 感性 (Sensibility)
var stat_empathy: float = 0.0 # 情思体悟
var stat_inspiration: float = 0.0 # 创想灵感
var stat_aesthetics: float = 0.0 # 美学品鉴
var stat_art_perception: float = 0.0 # 艺术感知

var current_energy: float = 100.0
var max_energy: float = 100.0
var gold: int = 500
var stress: float = 10.0 # 0-100
var max_stress: float = 100.0

var diaries: Array = []

signal stage_upgraded(new_stage: int, unlock_dialog: String)
signal profile_updated()

const PROFILE_PATH = "user://character_profile.json"
var current_character_id: String = ""

func get_profile_path() -> String:
    var char_id = current_character_id
    if char_id == "": char_id = "default"
    var dir_path = "user://saves/%s" % char_id
    if not DirAccess.dir_exists_absolute(dir_path):
        DirAccess.make_dir_recursive_absolute(dir_path)
    return "%s/character_profile.json" % dir_path

func _init():
    pass

func load_profile(force_char_id: String = "") -> void:
    # 确定要加载的角色ID
    if force_char_id != "":
        current_character_id = force_char_id
    elif GameDataManager.config and GameDataManager.config.current_character_id != "":
        current_character_id = GameDataManager.config.current_character_id
    else:
        # 如果未配置，优先寻找外部目录
        var ext_dir = DirAccess.open("user://game_data/characters")
        if ext_dir:
            ext_dir.list_dir_begin()
            var folder_name = ext_dir.get_next()
            while folder_name != "":
                if ext_dir.current_is_dir() and not folder_name.begins_with("."):
                    if FileAccess.file_exists("user://game_data/characters/" + folder_name + "/settings.json"):
                        current_character_id = folder_name
                        break
                folder_name = ext_dir.get_next()
                
        # 否则寻找内置目录
        if current_character_id == "":
            var dir = DirAccess.open("res://assets/data/characters")
            if dir:
                dir.list_dir_begin()
                var file_name = dir.get_next()
                while file_name != "":
                    if file_name.ends_with(".json") and not file_name.ends_with("_stages.json"):
                        current_character_id = file_name.replace(".json", "")
                        break
                    file_name = dir.get_next()
            
        if current_character_id == "":
            printerr("No character config found in res://assets/data/characters/")
            return
        elif GameDataManager.config:
            GameDataManager.config.current_character_id = current_character_id
            GameDataManager.config.save_config()
            
    # 先加载静态数据
    _load_static_data()
    _load_stage_data()
    
    # 如果当前角色文件不存在，但 base_personality 是在上一次加载的，我们需要先把它重置掉，
    # 因为 static_data 里的加载是只有在有数据时才会覆盖
    if not FileAccess.file_exists(_get_static_data_path()):
        base_personality = {
            "openness": 50.0,
            "conscientiousness": 50.0,
            "extraversion": 50.0,
            "agreeableness": 50.0,
            "neuroticism": 50.0
        }
    
    # 加载动态存档
    var path = get_profile_path()
    if FileAccess.file_exists(path):
        var file = FileAccess.open(path, FileAccess.READ)
        var content = file.get_as_text()
        file.close()
        
        var json = JSON.new()
        var error = json.parse(content)
        if error == OK:
            var data = json.get_data()
            if data is Dictionary:
                player_name = data.get("player_name", player_name)
                intimacy = float(str(data.get("intimacy", intimacy)))
                current_mood = data.get("current_mood", current_mood)
                last_login_date = data.get("last_login_date", last_login_date)
                trust = float(str(data.get("trust", trust)))
                current_stage = int(str(data.get("current_stage", current_stage)))
                interaction_exp = int(str(data.get("interaction_exp", interaction_exp)))
                openness = float(str(data.get("openness", base_personality.get("openness", 50.0))))
                conscientiousness = float(str(data.get("conscientiousness", base_personality.get("conscientiousness", 50.0))))
                extraversion = float(str(data.get("extraversion", base_personality.get("extraversion", 50.0))))
                agreeableness = float(str(data.get("agreeableness", base_personality.get("agreeableness", 50.0))))
                neuroticism = float(str(data.get("neuroticism", base_personality.get("neuroticism", 50.0))))
                
                last_online_time = int(str(data.get("last_online_time", 0)))
                
                # 四基十六维
                stat_stamina = float(str(data.get("stat_stamina", 0.0)))
                stat_body_management = float(str(data.get("stat_body_management", 0.0)))
                stat_focus = float(str(data.get("stat_focus", 0.0)))
                stat_rhythm = float(str(data.get("stat_rhythm", 0.0)))
                stat_artistic_literacy = float(str(data.get("stat_artistic_literacy", 0.0)))
                stat_verbal_expression = float(str(data.get("stat_verbal_expression", 0.0)))
                stat_planning = float(str(data.get("stat_planning", 0.0)))
                stat_art_theory = float(str(data.get("stat_art_theory", 0.0)))
                stat_temperament = float(str(data.get("stat_temperament", 0.0)))
                stat_manner = float(str(data.get("stat_manner", 0.0)))
                stat_emotional_infection = float(str(data.get("stat_emotional_infection", 0.0)))
                stat_stage_performance = float(str(data.get("stat_stage_performance", 0.0)))
                stat_empathy = float(str(data.get("stat_empathy", 0.0)))
                stat_inspiration = float(str(data.get("stat_inspiration", 0.0)))
                stat_aesthetics = float(str(data.get("stat_aesthetics", 0.0)))
                stat_art_perception = float(str(data.get("stat_art_perception", 0.0)))
                current_energy = float(str(data.get("current_energy", max_energy)))
                gold = int(str(data.get("gold", 500)))
                stress = float(str(data.get("stress", 10.0)))
                diaries = data.get("diaries", [])
    else:
        # 尝试迁移旧存档
        var old_path = "user://character_profile.json"
        if FileAccess.file_exists(old_path):
            var dir = DirAccess.open("user://")
            dir.copy(old_path, path)
            dir.rename(old_path, "user://character_profile_migrated.json")
            load_profile(force_char_id)
            return
        
        openness = float(str(base_personality.get("openness", 50.0)))
        conscientiousness = float(str(base_personality.get("conscientiousness", 50.0)))
        extraversion = float(str(base_personality.get("extraversion", 50.0)))
        agreeableness = float(str(base_personality.get("agreeableness", 50.0)))
        neuroticism = float(str(base_personality.get("neuroticism", 50.0)))
        
        # 四基十六维初始值
        stat_stamina = 0.0
        stat_body_management = 0.0
        stat_focus = 0.0
        stat_rhythm = 0.0
        stat_artistic_literacy = 0.0
        stat_verbal_expression = 0.0
        stat_planning = 0.0
        stat_art_theory = 0.0
        stat_temperament = 0.0
        stat_manner = 0.0
        stat_emotional_infection = 0.0
        stat_stage_performance = 0.0
        stat_empathy = 0.0
        stat_inspiration = 0.0
        stat_aesthetics = 0.0
        stat_art_perception = 0.0
        current_energy = max_energy
    
    init_daily_mood()

func _get_static_data_path() -> String:
    # 优先检查外部动态目录
    var ext_path = "user://game_data/characters/%s/settings.json" % current_character_id
    if FileAccess.file_exists(ext_path):
        return ext_path
    return "res://assets/data/characters/%s.json" % current_character_id

func _get_stage_data_path() -> String:
    var ext_path = "user://game_data/characters/%s/stages.json" % current_character_id
    if FileAccess.file_exists(ext_path):
        return ext_path
    return "res://assets/data/characters/%s_stages.json" % current_character_id

func _load_static_data() -> void:
    var path = _get_static_data_path()
    if FileAccess.file_exists(path):
        var file = FileAccess.open(path, FileAccess.READ)
        var content = file.get_as_text()
        file.close()
        
        var json = JSON.new()
        var error = json.parse(content)
        if error == OK:
            var data = json.get_data()
            if data is Dictionary:
                char_name = data.get("char_name", "")
                age = data.get("age", 22)
                spine_path = data.get("spine_path", "")
                avatar = data.get("avatar", "")
                description = data.get("world_background", data.get("description", ""))
                tags = data.get("tags", [])
                if data.has("base_personality"):
                    base_personality = data["base_personality"]
    else:
        printerr("Character static data not found: ", path)

func _load_stage_data() -> void:
    var path = _get_stage_data_path()
    if FileAccess.file_exists(path):
        var file = FileAccess.open(path, FileAccess.READ)
        var content = file.get_as_text()
        file.close()
        
        var json = JSON.new()
        var error = json.parse(content)
        if error == OK:
            var data = json.get_data()
            if data is Dictionary and data.has("stages"):
                stages_config = data["stages"]
    else:
        printerr("Character stage data not found: ", path)

func init_daily_mood() -> void:
    var today = Time.get_date_string_from_system()
    if last_login_date != today:
        last_login_date = today
        if GameDataManager.mood_system != null:
            current_mood = GameDataManager.mood_system.get_random_mood()
            print("【心情系统】新的一天，抽取的初始心情为: ", current_mood)
        # 跨天恢复满精力
        current_energy = max_energy
        print("【精力系统】新的一天，精力已回满: ", current_energy)
        save_profile()

func get_stage_config(stage_num: int) -> Dictionary:
    for config in stages_config:
        if config["stage"] == stage_num:
            return config
    return {}

func get_current_stage_config() -> Dictionary:
    return get_stage_config(current_stage)

func force_set_stage(new_stage: int) -> void:
    current_stage = clamp(new_stage, 1, 9)
    
    # 获取前一个阶段的配置以确定当前阶段的起点
    var prev_stage = max(1, current_stage - 1)
    var prev_conf = get_stage_config(prev_stage)
    
    var min_value = 0.0
    if current_stage > 1 and not prev_conf.is_empty():
        min_value = float(prev_conf.get("threshold", 0))
    
    intimacy = min_value
    trust = min_value
    interaction_exp = int(min_value)
    
    save_profile()

func update_intimacy(amount: float) -> void:
    if amount > 0:
        var stage_conf = get_current_stage_config()
        var stage_multi = stage_conf.get("intimacy_multiplier", 1.0)
        var mood_multi = GameDataManager.mood_system.get_intimacy_multiplier(current_mood)
        # 获取动态人格倍率
        var personality_mult = GameDataManager.personality_system.get_intimacy_multiplier(self)
        amount = amount * stage_multi * mood_multi * personality_mult
    intimacy = max(intimacy + amount, 0.0)
    check_stage_upgrade()

func update_trust(amount: float) -> void:
    if amount > 0:
        var stage_conf = get_current_stage_config()
        var stage_multi = stage_conf.get("trust_multiplier", 1.0)
        var mood_multi = GameDataManager.mood_system.get_trust_multiplier(current_mood)
        # 信任度同样受人格倍率影响
        var personality_mult = GameDataManager.personality_system.get_intimacy_multiplier(self)
        amount = amount * stage_multi * mood_multi * personality_mult
    trust = max(trust + amount, 0.0)
    
func add_interaction_exp() -> void:
    var stage_conf = get_current_stage_config()
    var base_exp = stage_conf.get("exp_per_interaction", 10)
    var mood_bonus = GameDataManager.mood_system.get_exp_bonus(current_mood)
    var total_exp = base_exp + mood_bonus
    if total_exp < 0:
        total_exp = 0
        
    interaction_exp += total_exp
    check_stage_upgrade()

func check_stage_upgrade() -> void:
    var stage_conf = get_current_stage_config()
    if stage_conf.is_empty(): return
    
    # 假设突破阈值是亲密度要求，如果当前亲密度达到了阈值，并且互动经验也满了（或者不限制经验），
    # 这里根据题意"不可突破阶段上限"是指经验不能超过当前阶段某个值？
    # 或者说突破阈值就是经验的阈值？
    # “阶段突破阈值（int，达标后才允许进入下一阶段）”
    # “互动经验累计值（int，每次互动累加，可溢出但不可突破阶段上限）”
    # 看起来经验有一个阶段上限。假设 threshold 既是亲密度阈值也是经验上限。
    # 让我们假设经验满 threshold 后可以升阶。
    
    var threshold = stage_conf.get("threshold", 9999)
    if interaction_exp > threshold:
        interaction_exp = threshold
        
    if current_stage < 9 and intimacy >= threshold and interaction_exp >= threshold:
        current_stage += 1
        # 经验不再重置为0，而是像亲密度一样继承，以适配绝对值的目标上限展示
        print("【情感系统】升阶！当前阶段: Stage", current_stage)
        var next_stage_conf = get_current_stage_config()
        var unlock_dialog = next_stage_conf.get("unlockDialog", "")
        stage_upgraded.emit(current_stage, unlock_dialog)

func update_mood(new_mood: String) -> void:
    if GameDataManager.mood_system.is_valid_mood(new_mood):
        current_mood = new_mood
        save_profile()

func save_profile() -> void:
    var data = {
        "player_name": player_name,
        "intimacy": intimacy,
        "current_mood": current_mood,
        "last_login_date": last_login_date,
        "trust": trust,
        "current_stage": current_stage,
        "interaction_exp": interaction_exp,
        "openness": openness,
        "conscientiousness": conscientiousness,
        "extraversion": extraversion,
        "agreeableness": agreeableness,
        "neuroticism": neuroticism,
        "last_online_time": Time.get_unix_time_from_system(),
        "stat_stamina": stat_stamina,
        "stat_body_management": stat_body_management,
        "stat_focus": stat_focus,
        "stat_rhythm": stat_rhythm,
        "stat_artistic_literacy": stat_artistic_literacy,
        "stat_verbal_expression": stat_verbal_expression,
        "stat_planning": stat_planning,
        "stat_art_theory": stat_art_theory,
        "stat_temperament": stat_temperament,
        "stat_manner": stat_manner,
        "stat_emotional_infection": stat_emotional_infection,
        "stat_stage_performance": stat_stage_performance,
        "stat_empathy": stat_empathy,
        "stat_inspiration": stat_inspiration,
        "stat_aesthetics": stat_aesthetics,
        "stat_art_perception": stat_art_perception,
        "current_energy": current_energy,
        "gold": gold,
        "stress": stress,
        "diaries": diaries
    }
    var file = FileAccess.open(get_profile_path(), FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify(data, "\t"))
        file.close()

func get_diaries() -> Array:
    return diaries

func add_diary(diary_entry: Dictionary) -> void:
    diaries.append(diary_entry)
    profile_updated.emit()
    save_profile()
    
func get_recent_chat_history_text(limit: int = 10) -> String:
    var history_text = ""
    var history = get_chat_history()
    var start_idx = max(0, history.size() - limit)
    
    for i in range(start_idx, history.size()):
        var msg = history[i]
        var sender = "玩家" if msg.get("is_user", false) else char_name
        history_text += sender + "：" + msg.get("content", "") + "\n"
        
    return history_text

func get_chat_history() -> Array:
    return []
