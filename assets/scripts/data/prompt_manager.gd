extends Node

# 缓存已加载的模板
var templates: Dictionary = {}

func load_template(template_name: String) -> String:
    if templates.has(template_name):
        return templates[template_name]
        
    var path = "res://assets/templates/prompts/" + template_name + ".txt"
    if FileAccess.file_exists(path):
        var file = FileAccess.open(path, FileAccess.READ)
        var content = file.get_as_text()
        file.close()
        templates[template_name] = content
        return content
    else:
        printerr("Prompt template not found: ", path)
        return ""

func build_chat_prompt(profile: CharacterProfile) -> String:
    var template = load_template("default_chat")
    if template == "":
        return ""
        
    var time_str = Time.get_datetime_string_from_system()
    var mood_desc = GameDataManager.mood_system.get_mood_description(profile.current_mood)
    var memory_desc = GameDataManager.memory_manager.get_memory_prompt()
    
    var full_desc = "世界观背景：" + profile.description
    var stage_conf = profile.get_current_stage_config()
    if not stage_conf.is_empty():
        full_desc += "\n【当前情感阶段】" + stage_conf.get("stageTitle", "") + " - " + stage_conf.get("stageDesc", "")
        full_desc += "\n【性格特征】" + stage_conf.get("personality_traits", "")
        full_desc += "\n【场景设定】" + stage_conf.get("scene_setting", "")
        full_desc += "\n【重要提示】" + stage_conf.get("important_notes", "")
        var tags = stage_conf.get("tags", [])
        if tags is Array and tags.size() > 0:
            full_desc += "\n【Tags】" + ", ".join(tags)
    
    var base_prompt = template.format({
        "name": profile.char_name,
        "age": str(profile.age),
        "desc": full_desc,
        "time": time_str,
        "mood_desc": mood_desc,
        "memory_desc": memory_desc
    })
    
    # 注入人设锁（如果存在）
    var lock_constraint = GameDataManager.persona_lock.get_lock_constraint(profile.char_name)
    if lock_constraint != "":
        base_prompt += lock_constraint
        # GameDataManager.audit_logger.log_event("PROMPT_INJECTION", "Injected persona lock for character: " + profile.char_name)
        
    return base_prompt

func build_emotion_prompt(profile: CharacterProfile) -> String:
    var template = load_template("emotion_analysis")
    if template == "":
        return ""
        
    var stage_conf = profile.get_current_stage_config()
    var stage_desc = stage_conf.get("stageTitle", "") + " - " + stage_conf.get("stageDesc", "")
    var mood_name = profile.current_mood
    
    # Load interaction behaviors
    var behaviors_text = ""
    var path = "res://assets/data/rules/interaction_behaviors.json"
    if FileAccess.file_exists(path):
        var file = FileAccess.open(path, FileAccess.READ)
        behaviors_text = file.get_as_text()
        file.close()
    
    return template.format({
        "name": profile.char_name,
        "intimacy": str(profile.intimacy),
        "trust": str(profile.trust),
        "stage_desc": stage_desc,
        "mood_name": mood_name,
        "interaction_behaviors": behaviors_text
    })

func build_memory_prompt(profile: CharacterProfile) -> String:
    var template = load_template("memory_extraction")
    if template == "":
        return ""
        
    return template.format({
        "name": profile.char_name
    })

func build_options_prompt(profile: CharacterProfile, last_msg: String) -> String:
    var template = load_template("player_options")
    if template == "":
        return ""
        
    var stage_desc = "无"
    var stage_conf = profile.get_current_stage_config()
    if not stage_conf.is_empty():
        stage_desc = stage_conf.get("stageTitle", "") + " - " + stage_conf.get("stageDesc", "")
        
    return template.format({
        "name": profile.char_name,
        "stage_desc": stage_desc,
        "last_msg": last_msg
    })
