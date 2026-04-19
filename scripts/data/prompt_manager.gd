extends Node

const DYNAMIC_STYLES: Array[Dictionary] = [
    { "name": "单段回复", "weight": 20, "text": "【分段策略：单段回复】请将你的回答组织为连贯的一整段。要求：纯台词部分在 80 到 150 字之间，总字数不超过 300 字。【请一次性发送完整内容，完全不要拆分】。注意必须同时包含括号括起来的动作/神态描写和真实台词对话！" },
    { "name": "双段连续", "weight": 40, "text": "【分段策略：双段连续】请将你的回答分成 2 段发送。要求：必须使用 [SPLIT] 分隔符分隔这两段。每段包含 40 到 80 字的真实台词对话（总字数不超过 250 字）。每一段都必须同时包含括号括起来的动作/神态描写和真实台词对话！" },
    { "name": "三段递进", "weight": 25, "text": "【分段策略：三段递进】请将你的回答分成 3 段发送，模拟递进或补充的语境。要求：必须使用 [SPLIT] 分隔符分隔这三段。每段包含 30 到 60 字的真实台词对话（总字数不超过 350 字）。每一段都必须同时包含括号括起来的动作/神态描写和真实台词对话！" },
    { "name": "四段短促", "weight": 15, "text": "【分段策略：四段短促】请将你的回答分成 4 段发送，模拟连珠炮式或补充说明的短消息。要求：必须使用 [SPLIT] 分隔符分隔这四段。每段包含 20 到 40 字的真实台词对话（总字数不超过 300 字）。每一段都必须同时包含括号括起来的动作/神态描写和真实台词对话！" }
]

const PET_DYNAMIC_STYLES: Array[Dictionary] = [
    { "name": "单段简短回复", "weight": 40, "text": "【分段策略：单段简短回复】请将你的回答组织为连贯的一整段。要求：纯台词部分在 30 到 60 字之间，总字数不超过 100 字。【请一次性发送完整内容，完全不要拆分】。注意必须同时包含括号括起来的动作/神态描写和真实台词对话！" },
    { "name": "双段轻快交流", "weight": 45, "text": "【分段策略：双段轻快交流】请将你的回答分成 2 段发送。要求：必须使用 [SPLIT] 分隔符分隔这两段。每段包含 20 到 40 字的真实台词对话（总字数不超过 150 字）。每一段都必须同时包含括号括起来的动作/神态描写和真实台词对话！" },
    { "name": "三段碎碎念", "weight": 15, "text": "【分段策略：三段碎碎念】请将你的回答分成 3 段发送，模拟连续补充的短语境。要求：必须使用 [SPLIT] 分隔符分隔这三段。每段包含 15 到 30 字的真实台词对话（总字数不超过 180 字）。每一段都必须同时包含括号括起来的动作/神态描写和真实台词对话！" }
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

func build_chat_prompt(profile: CharacterProfile, player_message: String = "", query_embedding: Array = []) -> String:
    return build_system_prompt(profile, "default_chat", player_message, query_embedding)

func build_system_prompt(profile: CharacterProfile, template_name: String = "default_chat", player_message: String = "", query_embedding: Array = []) -> String:
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
        var msg_len = player_message.length()
        var current_styles = PET_DYNAMIC_STYLES.duplicate(true)
        
        if msg_len <= 10 and msg_len > 0:
            for s in current_styles:
                if s["name"] == "单段简短回复":
                    s["weight"] += 20
                elif s["name"] == "双段轻快交流":
                    s["weight"] += 10
                elif s["name"] == "三段碎碎念":
                    s["weight"] = 0
        elif msg_len > 20:
            for s in current_styles:
                if s["name"] == "三段碎碎念":
                    s["weight"] += 20
                elif s["name"] == "单段简短回复":
                    s["weight"] = 0
                    
        var total_weight = 0
        for s in current_styles:
            total_weight += s["weight"]
            
        var random_val = randi() % total_weight if total_weight > 0 else 0
        random_style = current_styles[0]["text"]
        for s in current_styles:
            random_val -= s["weight"]
            if random_val < 0:
                random_style = s["text"]
                break
    else:
        var msg_len = player_message.length()
        var current_styles = DYNAMIC_STYLES.duplicate(true)
        
        if msg_len <= 10 and msg_len > 0:
            for s in current_styles:
                if s["name"] == "单段回复":
                    s["weight"] += 20
                elif s["name"] == "双段连续":
                    s["weight"] += 20
                elif s["name"] == "三段递进":
                    s["weight"] = 0
        elif msg_len > 20:
            for s in current_styles:
                if s["name"] == "三段递进":
                    s["weight"] += 20
                elif s["name"] == "四段短促":
                    s["weight"] += 20
                elif s["name"] == "单段回复":
                    s["weight"] = 0
                    
        var total_weight = 0
        for s in current_styles:
            total_weight += s["weight"]
            
        var random_val = randi() % total_weight if total_weight > 0 else 0
        random_style = current_styles[0]["text"]
        for s in current_styles:
            random_val -= s["weight"]
            if random_val < 0:
                random_style = s["text"]
                break
    
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
