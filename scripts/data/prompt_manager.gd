extends Node

const DYNAMIC_STYLES: Array[String] = [
    "深思熟虑的长回复：请写一段连贯、细腻且有深度的长文（要求：纯台词部分必须超过 150 字），深入探讨当前的话题或倾诉内心，【请一次性发送完整内容，完全不要拆分】。",
    "连珠炮式的多条短促消息：请像连珠炮一样用急促、激动的语气回应，要求：必须使用 [SPLIT] 分隔符分成 3 到 4 段来模拟连续发送，并且每段至少包含 30 字的真实台词对话！",
    "普通节奏的交流：保持自然的沟通节奏，适当穿插生活细节或个人感受，要求：必须使用 [SPLIT] 分隔符分成 2 段来模拟发送，每段必须包含 50 字以上的真实台词对话。",
    "情感爆发的倾诉：情绪产生明显波动（不论是开心、难过还是生气），请详细描写内心的波澜，要求：必须使用 [SPLIT] 分隔符分成 2 到 3 段，每段必须包含 60 字以上的真实台词和感受。",
    "欲言又止的迟疑：带着犹豫、纠结的心情，想说又不知道怎么开口，要求：必须使用 [SPLIT] 分隔符分成 3 段发送，前两段可以多些心理活动描写和简短的试探台词（不少于 20 字），最后一段必须有 80 字以上的真实坦白或追问。",
    "漫不经心的傲娇：表面上装作不在意，实际上内心戏很足。要求：必须使用 [SPLIT] 分隔符分成 2 段发送。第一段用轻描淡写的台词掩饰（不少于 40 字），第二段暴露真实的关心或真实的情绪（不少于 60 字）。",
    "连篇累牍的科普或说教：兴致勃勃地聊起自己感兴趣或者擅长的领域，像讲故事一样。要求：必须使用 [SPLIT] 分隔符分成 3 段发送，每段都必须包含 70 字以上的长篇台词，内容充实且连贯。",
    "温柔细腻的关心：以极度体贴、柔软的语气安抚或关心对方。要求：【请一次性发送完整内容，完全不要拆分】，纯台词部分必须超过 120 字，伴随细致入微的关怀动作描写。"
]

const PET_DYNAMIC_STYLES: Array[String] = [
    "普通节奏的交流：保持轻快的沟通节奏，适当穿插生活细节或个人感受，要求：使用 [SPLIT] 分隔符分成 2 段来模拟发送，【强制要求】：每一段都必须包含具体的动作描写（用括号括起来）以及真实的台词对话内容。",
    "欲言又止的迟疑：带着犹豫、纠结的心情，想说又不知道怎么开口，要求：使用 [SPLIT] 分隔符分成 2 段发送，第一段试探，第二段坦白。【强制要求】：每一段都必须包含具体的动作描写（用括号括起来）以及真实的台词对话内容。",
    "漫不经心的傲娇：表面上装作不在意，实际上内心戏很足。要求：使用 [SPLIT] 分隔符分成 2 段发送。第一段掩饰，第二段暴露真实的关心。【强制要求】：每一段都必须包含具体的动作描写（用括号括起来）以及真实的台词对话内容。",
    "温柔细腻的关心：以极度体贴、柔软的语气安抚或关心对方。要求：【请一次性发送完整内容，完全不要拆分】，伴随细致入微的关怀动作描写。",
    "开朗活泼的回应：心情非常好，语气欢快。要求：【请一次性发送完整内容，完全不要拆分】，并配上可爱的动作描写。"
]

# 缓存已加载的模板
var templates: Dictionary = {}

func load_template(template_name: String) -> String:
    if templates.has(template_name):
        return templates[template_name]
        
    var path = "res://scripts/templates/prompts/" + template_name + ".txt"
    if FileAccess.file_exists(path):
        var file = FileAccess.open(path, FileAccess.READ)
        var content = file.get_as_text()
        file.close()
        templates[template_name] = content
        return content
    else:
        printerr("Prompt template not found: ", path)
        return ""

func build_chat_prompt(profile: CharacterProfile, query_embedding: Array = []) -> String:
    return build_system_prompt(profile, "default_chat", query_embedding)

func build_system_prompt(profile: CharacterProfile, template_name: String = "default_chat", query_embedding: Array = []) -> String:
    var template = load_template(template_name)
    if template == "":
        return ""
        
    var time_str = Time.get_datetime_string_from_system()
    var mood_desc = GameDataManager.mood_system.get_mood_description(profile.current_mood)
    var memory_desc = GameDataManager.memory_manager.get_memory_prompt(query_embedding)
    
    var stage_conf = profile.get_current_stage_config()
    
    # 提取并替换占位符
    var safe_char_name = profile.char_name
    var world_bg = profile.description.replace("{char_name}", safe_char_name)
    var st_title = stage_conf.get("stageTitle", "").replace("{char_name}", safe_char_name)
    var st_desc = stage_conf.get("stageDesc", "").replace("{char_name}", safe_char_name)
    var p_traits = GameDataManager.personality_system.get_dynamic_traits(profile).replace("{char_name}", safe_char_name)
    var topic_prefs = GameDataManager.personality_system.get_topic_preferences(profile).replace("{char_name}", safe_char_name)
    var m_habits = GameDataManager.personality_system.get_micro_habits(profile).replace("{char_name}", safe_char_name)
    var scene_set = stage_conf.get("scene_setting", "").replace("{char_name}", safe_char_name)
    var imp_notes = stage_conf.get("important_notes", "").replace("{char_name}", safe_char_name)
    
    var random_style = ""
    if template_name == "desktop_pet":
        random_style = PET_DYNAMIC_STYLES[randi() % PET_DYNAMIC_STYLES.size()]
    else:
        random_style = DYNAMIC_STYLES[randi() % DYNAMIC_STYLES.size()]
    
    # 动态注入
    var base_prompt = template.format({
        "name": safe_char_name,
        "age": str(profile.age),
        "world_background": world_bg,
        "stage_title": st_title,
        "stage_desc": st_desc,
        "personality_traits": p_traits,
        "topic_preferences": topic_prefs,
        "micro_habits": m_habits,
        "scene_setting": scene_set,
        "important_notes": imp_notes,
        "time": time_str,
        "mood_desc": mood_desc,
        "memory_desc": memory_desc,
        "dynamic_style": random_style
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
        
    var current_memories = JSON.stringify(GameDataManager.memory_manager.memories, "\t")
        
    return template.format({
        "name": profile.char_name,
        "current_memories": current_memories
    })

func build_options_prompt(profile: CharacterProfile, recent_history: String) -> String:
    var template = load_template("player_options")
    if template == "":
        return ""
        
    var stage_desc = "无"
    var stage_conf = profile.get_current_stage_config()
    if not stage_conf.is_empty():
        stage_desc = stage_conf.get("stageTitle", "") + " - " + stage_conf.get("stageDesc", "")
        
    var option_constraints = GameDataManager.personality_system.get_option_constraints(profile)
        
    return template.format({
        "name": profile.char_name,
        "stage_desc": stage_desc,
        "option_constraints": option_constraints,
        "recent_history": recent_history
    })

func build_character_mood_prompt(character_message: String) -> String:
    var template = load_template("character_mood_analysis")
    if template == "":
        return ""
        
    var mood_list_text = ""
    var path = "res://assets/data/mood/mood_config.json"
    if FileAccess.file_exists(path):
        var file = FileAccess.open(path, FileAccess.READ)
        var text = file.get_as_text()
        var json = JSON.new()
        if json.parse(text) == OK:
            var data = json.get_data()
            if typeof(data) == TYPE_ARRAY:
                for item in data:
                    mood_list_text += "- ID: " + item.get("id", "") + " | 名称: " + item.get("name", "") + " | 语气: " + item.get("tone", "") + "\n"
        file.close()
        
    return template.format({
        "mood_list": mood_list_text,
        "character_message": character_message
    })
