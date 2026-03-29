extends Node

# 模拟关系型数据库与Redis缓存层
# 本地使用 JSON 存储，Dict 模拟内存缓存
const LOCK_FILE = "user://character_lock.json"
const THRESHOLD = 0.8

enum LockLevel { NONE = 0, LOOSE = 1, STRICT = 2 }

# 内存缓存层 (模拟 Redis, 暂未实现严格的 TTL 7天清除逻辑，仅作内存状态保持)
var active_locks: Dictionary = {}

func _ready() -> void:
    _load_locks_from_db()

# 核心功能：角色创建或加载阶段的冲突检测与锁定
func check_and_lock_character(char_name: String) -> void:
    if active_locks.has(char_name):
        return # 已存在锁或已检测过

    # 1. 实时调用名人冲突检测接口 (此处为模拟)
    var detection_result = _mock_collision_detection_api(char_name)
    
    # 2. 判断冲突概率阈值
    if detection_result["score"] >= THRESHOLD:
        _apply_persona_lock(
            char_name, 
            detection_result["recommended_level"], 
            detection_result["domain"],
            "Score %.2f exceeded threshold %.2f" % [detection_result["score"], THRESHOLD]
        )
    else:
        # 即使未命中，也可在缓存记录 NONE 防止重复检测
        active_locks[char_name] = {"lock_level": LockLevel.NONE}

# 为冲突角色生成人设指纹并入库
func _apply_persona_lock(char_name: String, level: int, domain: String, reason: String) -> void:
    var uuid_str = str(randi()) + "-" + str(Time.get_unix_time_from_system())
    var current_time = Time.get_datetime_string_from_system()
    
    var lock_data = {
        "uuid": uuid_str,
        "character_name": char_name,
        "lock_level": level,
        "domain": domain,
        "locked_dimensions": ["性格", "口吻", "背景故事", "价值观", "知识边界", "禁忌话题"],
        "created_at": current_time,
        "updated_at": current_time
    }
    
    # 写入缓存与DB
    active_locks[char_name] = lock_data
    _save_locks_to_db()
    
    # 记录审计日志
    var level_str = "STRICT" if level == LockLevel.STRICT else "LOOSE"
    GameDataManager.audit_logger.log_event(
        "LOCK_APPLIED", 
        "Locked character '%s' with level %s (Domain: %s). Reason: %s" % [char_name, level_str, domain, reason]
    )

# 获取用于提示词注入的锁定段落
func get_lock_constraint(char_name: String) -> String:
    if not active_locks.has(char_name):
        return ""
        
    var lock = active_locks[char_name]
    if lock["lock_level"] == LockLevel.NONE:
        return ""
        
    var constraint = "\n\n<|locked_persona|>\n"
    constraint += "[系统强制约束：人设锁激活]\n"
    constraint += "指纹: " + lock["uuid"] + "\n"
    constraint += "锁定维度: " + "、".join(lock["locked_dimensions"]) + "\n"
    
    if lock["lock_level"] == LockLevel.STRICT:
        constraint += "严格模式：完全禁止调用任何与现实世界中同名名人（领域：%s）相关的先验知识。你完全是一个虚构的普通人，必须严格遵守设定中的人设背景。绝对禁止任何OOC行为。\n" % lock["domain"]
    else:
        constraint += "宽松模式：允许使用公共常识，但禁止引用与现实世界同名名人（领域：%s）独有的私密或争议信息。保持上述虚构人设。\n" % lock["domain"]
        
    constraint += "</|locked_persona|>"
    return constraint

func inject_lock_to_prompt(prompt: String, char_name: String) -> String:
    var constraint = get_lock_constraint(char_name)
    if constraint != "":
        # GameDataManager.audit_logger.log_event("PROMPT_INJECTION", "Injected persona lock for character: " + char_name)
        return prompt + constraint
    return prompt

# 手动解锁或降级 (运营后台模拟)
func modify_lock(char_name: String, new_level: int, operator: String, reason: String) -> void:
    if active_locks.has(char_name) and active_locks[char_name]["lock_level"] != LockLevel.NONE:
        active_locks[char_name]["lock_level"] = new_level
        active_locks[char_name]["updated_at"] = Time.get_datetime_string_from_system()
        _save_locks_to_db()
        GameDataManager.audit_logger.log_event("LOCK_MODIFIED", "Modified lock for '%s' to level %d. Reason: %s" % [char_name, new_level, reason], operator)

# ==========================================
# 模拟后端基建：API & DB
# ==========================================

# 模拟 API：延迟 <= 200ms
func _mock_collision_detection_api(char_name: String) -> Dictionary:
    var lower_name = char_name.to_lower()
    # 模拟知识库黑名单 (针对 Luna)
    var hit_db = {
        "luna": {"domain": "多领域(动漫/加密货币/游戏)", "score": 0.99, "level": LockLevel.STRICT},
        "luna loud": {"domain": "动漫(喧闹一家亲)", "score": 0.95, "level": LockLevel.STRICT},
        "luna lovegood": {"domain": "文学/电影(哈利波特)", "score": 0.98, "level": LockLevel.STRICT},
        "luna inverse": {"domain": "动漫(秀逗魔导士)", "score": 0.92, "level": LockLevel.STRICT},
        "luna maximoff": {"domain": "漫画(漫威)", "score": 0.90, "level": LockLevel.STRICT},
        "luna (sailor moon)": {"domain": "动漫(美少女战士)", "score": 0.97, "level": LockLevel.STRICT},
        "luna (dota 2)": {"domain": "游戏/动漫(Dota 2)", "score": 0.95, "level": LockLevel.STRICT},
        "luna schweiger": {"domain": "娱乐(演员)", "score": 0.88, "level": LockLevel.LOOSE},
        "anna paulina luna": {"domain": "政治", "score": 0.85, "level": LockLevel.STRICT}
    }
    
    if hit_db.has(lower_name):
        return {
            "hit": true,
            "score": hit_db[lower_name]["score"],
            "domain": hit_db[lower_name]["domain"],
            "recommended_level": hit_db[lower_name]["level"]
        }
        
    return {"hit": false, "score": 0.1, "domain": "", "recommended_level": LockLevel.NONE}

func _save_locks_to_db() -> void:
    var file = FileAccess.open(LOCK_FILE, FileAccess.WRITE)
    if file:
        # 仅持久化真实存在的锁，忽略 NONE 状态的空壳
        var persistent_data = {}
        for key in active_locks:
            if active_locks[key]["lock_level"] != LockLevel.NONE:
                persistent_data[key] = active_locks[key]
        file.store_string(JSON.stringify(persistent_data, "\t"))
        file.close()

func _load_locks_from_db() -> void:
    if FileAccess.file_exists(LOCK_FILE):
        var file = FileAccess.open(LOCK_FILE, FileAccess.READ)
        var content = file.get_as_text()
        file.close()
        
        var json = JSON.new()
        if json.parse(content) == OK:
            var data = json.get_data()
            if data is Dictionary:
                active_locks = data
