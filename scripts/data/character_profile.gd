class_name CharacterProfile
extends Resource

const SafeFileAccess = preload("res://scripts/utils/safe_file_access.gd")

var char_name: String = ""
var player_name: String = ""
var player_title: String = ""
var age: int = 22
var description: String = ""
var tags: Array = []
var spine_path: String = ""
var sprite_frames_path: String = ""
var desktop_pet_frames_path: String = ""
var avatar: String = ""
var current_outfit: String = "default" # 当前穿着服装的 ID

var intimacy: float = 0.0 # 0-9999
var mood_value: float = 50.0 # 0-100, 长期心情值
var current_expression: String = "calm" # 瞬时表情ID
var current_mood: String: # 兼容旧存档或遗留逻辑，建议逐步废弃
    get: return current_expression
    set(value): current_expression = value
var last_login_date: String = "" # 用于判断是否跨天
var trust: float = 10.0 # 0-9999
var current_stage: int = 1 # 1-8
var interaction_exp: int = 10000 # 初始设置高一点用于测试

var stages_config: Array = []
var base_personality: Dictionary = {}

var openness: float = 50.0
var conscientiousness: float = 50.0
var extraversion: float = 50.0
var agreeableness: float = 50.0
var neuroticism: float = 50.0

var personality_history: Array = [] # 记录过去大五人格的数据，元素格式: {"day_offset": int, "openness": float, ...}

var last_online_time: int = 0

# 四基十六维养成体系数值
# 体力 (Physical)
var stat_stamina: float = 0.0 # 体能
var stat_body: float = 0.0 # 形体
var stat_focus: float = 0.0 # 专注
var stat_rhythm: float = 0.0 # 反应
# 智力 (Intelligence)
var stat_knowledge: float = 0.0 # 学识
var stat_expression: float = 0.0 # 表达
var stat_planning: float = 0.0 # 企划
var stat_art_theory: float = 0.0 # 艺理
# 魅力 (Charm)
var stat_temperament: float = 0.0 # 气质
var stat_manner: float = 0.0 # 举止
var stat_etiquette: float = 0.0 # 礼仪
var stat_stage: float = 0.0 # 舞台
# 感性 (Sensibility)
var stat_empathy: float = 0.0 # 共情
var stat_inspiration: float = 0.0 # 灵感
var stat_aesthetics: float = 0.0 # 审美
var stat_perception: float = 0.0 # 感知

var current_energy: float = 100.0
var max_energy: float = 100.0
var gold: int = 500
var stress: float = 10.0 # 0-100
var max_stress: float = 100.0

var unlocked_outfits: Array = ["default"] # 已解锁服装的 ID 列表

var course_progress: Dictionary = {}

var diaries: Array = []
var finished_stories: Array = []

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
                player_title = data.get("player_title", player_title)
                intimacy = float(str(data.get("intimacy", intimacy)))
                mood_value = float(str(data.get("mood_value", 50.0)))
                current_expression = data.get("current_expression", "calm")
                
                # 兼容旧存档的 current_mood
                if data.has("current_mood"):
                    var old_mood = data.get("current_mood")
                    if GameDataManager.expression_system.is_valid_expression(old_mood):
                        current_expression = old_mood
                        
                last_login_date = data.get("last_login_date", last_login_date)
                trust = float(str(data.get("trust", trust)))
                current_stage = int(str(data.get("current_stage", current_stage)))
                interaction_exp = int(str(data.get("interaction_exp", interaction_exp)))
                openness = float(str(data.get("openness", base_personality.get("openness", 50.0))))
                conscientiousness = float(str(data.get("conscientiousness", base_personality.get("conscientiousness", 50.0))))
                extraversion = float(str(data.get("extraversion", base_personality.get("extraversion", 50.0))))
                agreeableness = float(str(data.get("agreeableness", base_personality.get("agreeableness", 50.0))))
                neuroticism = float(str(data.get("neuroticism", base_personality.get("neuroticism", 50.0))))
                
                personality_history = data.get("personality_history", [])
                
                last_online_time = int(str(data.get("last_online_time", 0)))
                
                # 四基十六维
                stat_stamina = float(str(data.get("stat_stamina", 0.0)))
                stat_body = float(str(data.get("stat_body", data.get("stat_body_management", 0.0))))
                stat_focus = float(str(data.get("stat_focus", 0.0)))
                stat_rhythm = float(str(data.get("stat_rhythm", 0.0)))
                stat_knowledge = float(str(data.get("stat_knowledge", data.get("stat_artistic_literacy", 0.0))))
                stat_expression = float(str(data.get("stat_expression", data.get("stat_verbal_expression", 0.0))))
                stat_planning = float(str(data.get("stat_planning", 0.0)))
                stat_art_theory = float(str(data.get("stat_art_theory", 0.0)))
                stat_temperament = float(str(data.get("stat_temperament", 0.0)))
                stat_manner = float(str(data.get("stat_manner", 0.0)))
                stat_etiquette = float(str(data.get("stat_etiquette", data.get("stat_emotional_infection", 0.0))))
                stat_stage = float(str(data.get("stat_stage", data.get("stat_stage_performance", 0.0))))
                stat_empathy = float(str(data.get("stat_empathy", 0.0)))
                stat_inspiration = float(str(data.get("stat_inspiration", 0.0)))
                stat_aesthetics = float(str(data.get("stat_aesthetics", 0.0)))
                stat_perception = float(str(data.get("stat_perception", data.get("stat_art_perception", 0.0))))
                current_energy = float(str(data.get("current_energy", max_energy)))
                current_outfit = data.get("current_outfit", "default")
                unlocked_outfits = data.get("unlocked_outfits", ["default"])
                gold = int(str(data.get("gold", 500)))
                stress = data.get("stress", 10.0)
                course_progress = data.get("course_progress", {})
                diaries = data.get("diaries", [])
                finished_stories = data.get("finished_stories", [])
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
        stat_body = 0.0
        stat_focus = 0.0
        stat_rhythm = 0.0
        stat_knowledge = 0.0
        stat_expression = 0.0
        stat_planning = 0.0
        stat_art_theory = 0.0
        stat_temperament = 0.0
        stat_manner = 0.0
        stat_etiquette = 0.0
        stat_stage = 0.0
        stat_empathy = 0.0
        stat_inspiration = 0.0
        stat_aesthetics = 0.0
        stat_perception = 0.0
        current_energy = max_energy
    
    init_daily_mood()

func _get_static_data_path() -> String:
    # 优先检查外部动态目录
    var ext_path = "user://game_data/characters/%s/settings.json" % current_character_id
    if FileAccess.file_exists(ext_path):
        return ext_path
    
    # 兼容 npc 目录
    var npc_path = "res://assets/data/characters/npc/%s.json" % current_character_id
    if FileAccess.file_exists(npc_path):
        return npc_path
        
    return "res://assets/data/characters/%s.json" % current_character_id

func _get_stage_data_path() -> String:
    var ext_path = "user://game_data/characters/%s/stages.json" % current_character_id
    if FileAccess.file_exists(ext_path):
        return ext_path
        
    # 兼容 npc 目录
    var npc_path = "res://assets/data/characters/npc/%s_stages.json" % current_character_id
    if FileAccess.file_exists(npc_path):
        return npc_path
        
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
                sprite_frames_path = data.get("sprite_frames_path", "")
                desktop_pet_frames_path = data.get("desktop_pet_frames_path", "")
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

func update_expression(expression_id: String) -> void:
    if GameDataManager.expression_system.is_valid_expression(expression_id):
        current_expression = expression_id
        save_profile()
        print("【表情更新】强制切换瞬时表情为: ", expression_id)

func init_daily_mood() -> void:
    var today = Time.get_date_string_from_system()
    if last_login_date != today:
        last_login_date = today
        if GameDataManager.mood_system != null:
            print("【心情系统】新的一天，当前心情数值为: ", mood_value)
        # 跨天恢复满精力
        current_energy = max_energy
        print("【精力系统】新的一天，精力已回满: ", current_energy)
        save_profile()

func record_daily_personality(day_offset: int) -> void:
    # 每天记录一次性格数据，保留最近7天
    var snapshot = {
        "day_offset": day_offset,
        "openness": openness,
        "conscientiousness": conscientiousness,
        "extraversion": extraversion,
        "agreeableness": agreeableness,
        "neuroticism": neuroticism
    }
    personality_history.append(snapshot)
    if personality_history.size() > 7:
        personality_history.pop_front()
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
    
    # 获取前一个阶段的配置以确定当前阶段的起点 (由于解耦，此逻辑可能已不再需要强绑定，但保留兼容)
    var prev_stage = max(1, current_stage - 1)
    
    # 强制跳阶时，不再重置 intimacy 和 trust 为配置表最低值，保留其浮动状态
    interaction_exp = 0 # 互动经验已改为消耗品，强制跳阶时重置为0避免溢出
    
    save_profile()

func update_intimacy(amount: float) -> void:
    if amount > 0:
        var stage_conf = get_current_stage_config()
        var stage_multi = stage_conf.get("intimacy_multiplier", 1.0)
        var mood_multi = GameDataManager.mood_system.get_intimacy_multiplier(mood_value)
        # 获取动态人格倍率
        var personality_mult = GameDataManager.personality_system.get_intimacy_multiplier(self)
        amount = amount * stage_multi * mood_multi * personality_mult
    intimacy = max(intimacy + amount, 0.0)
    check_stage_upgrade()

func update_trust(amount: float) -> void:
    if amount > 0:
        var stage_conf = get_current_stage_config()
        var stage_multi = stage_conf.get("trust_multiplier", 1.0)
        var mood_multi = GameDataManager.mood_system.get_trust_multiplier(mood_value)
        # 信任度同样受人格倍率影响
        var personality_mult = GameDataManager.personality_system.get_intimacy_multiplier(self)
        amount = amount * stage_multi * mood_multi * personality_mult
    trust = max(trust + amount, 0.0)
    
func add_interaction_exp() -> void:
    var stage_conf = get_current_stage_config()
    var base_exp = stage_conf.get("exp_per_interaction", 10)
    var mood_bonus = GameDataManager.mood_system.get_exp_bonus(mood_value)
    var total_exp = base_exp + mood_bonus
    if total_exp < 0:
        total_exp = 0
        
    interaction_exp += total_exp
    check_stage_upgrade()

func check_stage_upgrade() -> void:
    var stage_conf = get_current_stage_config()
    if stage_conf.is_empty(): return
    
    # 解耦1：获取亲密度的绝对值阈值 (兼容旧表中的 threshold 字段)
    var intimacy_threshold = stage_conf.get("intimacy_threshold", stage_conf.get("threshold", 9999))
    
    # 解耦2：获取信任度的绝对值阈值 (如果配置表未填写，则默认不需要信任度门槛)
    var trust_threshold = stage_conf.get("trust_threshold", 0)
    
    # 解耦3：获取本次升阶需要【消耗】的互动经验值 (默认100，实际由JSON配置决定)
    var exp_cost = stage_conf.get("exp_cost", 100)
    
    # 解耦4：获取升阶的共感值门槛 (共感值 = 亲密 + 信任)
    var resonance_threshold = stage_conf.get("resonance_threshold", 0)
    var current_resonance = intimacy + trust
    
    # 解耦5：获取升阶的里程碑剧情事件限制
    var milestone_event = stage_conf.get("milestone_event", "")
    var is_milestone_met = true
    if milestone_event != "":
        # GameDataManager 已经作为 Autoload 存在，而且 event_manager 也是 autoload (或者通过其他方式访问)
        # 因为 event_manager 是 Autoload 的 "EventManager"，可以直接通过 Engine/SceneTree 获取
        var event_manager = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("EventManager")
        if event_manager and event_manager.has_method("is_event_triggered"):
            is_milestone_met = event_manager.is_event_triggered(milestone_event)
        else:
            # 如果配置了里程碑但系统未就绪，则判定为不满足
            is_milestone_met = false
    
    # 互动经验作为可积累的消耗资源，不再根据当前阶段截断
    if interaction_exp > 999999: # 兜底防止数值过大溢出
        interaction_exp = 999999
        
    # 条件：Stage 代表“羁绊深度/认识时间”，受到共感值（情感总容量）的硬门槛限制。
    # 只要共感值达标、拥有的互动经验足够支付消耗成本、且完成了里程碑事件，即可升级 Stage。
    if current_stage < 9 and current_resonance >= resonance_threshold and interaction_exp >= exp_cost and is_milestone_met:
        interaction_exp -= exp_cost # 扣除消耗的互动经验
        current_stage += 1
        
        print("【情感系统】升阶！消耗经验: %d, 当前阶段: Stage %d" % [exp_cost, current_stage])
        
        var next_stage_conf = get_current_stage_config()
        var unlock_dialog = next_stage_conf.get("unlockDialog", "")
        stage_upgraded.emit(current_stage, unlock_dialog)
        
        if GameDataManager.save_manager:
            GameDataManager.save_manager.call_deferred("auto_save")

func consume_energy(amount: float) -> bool:
    if current_energy >= amount:
        current_energy -= amount
        save_profile()
        profile_updated.emit()
        return true
    return false

func save_profile() -> void:
    var data = {
        "player_name": player_name,
        "player_title": player_title,
        "intimacy": intimacy,
        "mood_value": mood_value,
        "current_expression": current_expression,
        "last_login_date": last_login_date,
        "trust": trust,
        "current_stage": current_stage,
        "interaction_exp": interaction_exp,
        "openness": openness,
        "conscientiousness": conscientiousness,
        "extraversion": extraversion,
        "agreeableness": agreeableness,
        "neuroticism": neuroticism,
        "personality_history": personality_history,
        "last_online_time": Time.get_unix_time_from_system(),
        "stat_stamina": stat_stamina,
        "stat_body": stat_body,
        "stat_focus": stat_focus,
        "stat_rhythm": stat_rhythm,
        "stat_knowledge": stat_knowledge,
        "stat_expression": stat_expression,
        "stat_planning": stat_planning,
        "stat_art_theory": stat_art_theory,
        "stat_temperament": stat_temperament,
        "stat_manner": stat_manner,
        "stat_etiquette": stat_etiquette,
        "stat_stage": stat_stage,
        "stat_empathy": stat_empathy,
        "stat_inspiration": stat_inspiration,
        "stat_aesthetics": stat_aesthetics,
        "stat_perception": stat_perception,
        "current_energy": current_energy,
        "current_outfit": current_outfit,
        "unlocked_outfits": unlocked_outfits,
        "gold": gold,
        "stress": stress,
        "course_progress": course_progress,
        "diaries": diaries,
        "finished_stories": finished_stories
    }
    var content = JSON.stringify(data, "\t")
    SafeFileAccess.store_string(get_profile_path(), content)

func get_diaries() -> Array:
    return diaries

func add_diary(diary_entry: Dictionary) -> void:
    diaries.append(diary_entry)
    profile_updated.emit()
    save_profile()

func mark_story_finished(story_id: String) -> void:
    if not finished_stories.has(story_id):
        finished_stories.append(story_id)
        save_profile()
        if GameDataManager.save_manager:
            GameDataManager.save_manager.call_deferred("auto_save")

func has_finished_story(story_id: String) -> bool:
    return finished_stories.has(story_id)
    
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
