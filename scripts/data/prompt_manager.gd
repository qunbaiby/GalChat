extends Node

const DYNAMIC_STYLES: Array[Dictionary] = [
    { "name": "单段回复", "weight": 35, "text": "【分段策略：单段回复】请将你的回答组织为连贯的一整段。要求：纯台词部分在 20 到 50 字之间，总字数不超过 65 字。【强制要求：请一次性发送完整内容，绝对不要使用 [SPLIT] 拆分段落】。【极度致命警告：你的整个回复中，绝对只能在最开头出现【唯一一个】用括号包裹的动作/神态描写，写完这个括号后必须全是台词，句尾或句中绝对、绝对不准再出现任何括号描写，否则系统会崩溃！】" },
    { "name": "双段连续", "weight": 40, "text": "【分段策略：双段连续】请将你的回答分成 2 段发送。要求：【绝对强制】你必须在两段之间严格插入 [SPLIT] 字符串作为唯一的分隔符（例如：第一段[SPLIT]第二段）！每段包含 40 到 80 字的真实台词对话（总字数不超过 250 字）。【极度致命警告：被 [SPLIT] 隔开的每一个段落，绝对只能在最开头出现【唯一一个】用括号包裹的动作/神态描写，写完括号后必须全是台词，段落中间或结尾绝对不准再出现任何括号描写，否则系统会崩溃！】" },
    { "name": "三段递进", "weight": 25, "text": "【分段策略：三段递进】请将你的回答分成 3 段发送，模拟递进或补充的语境。要求：【绝对强制】你必须在段落之间严格插入 [SPLIT] 字符串作为唯一的分隔符（例如：第一段[SPLIT]第二段[SPLIT]第三段）！每段包含 30 到 60 字的真实台词对话（总字数不超过 350 字）。【极度致命警告：被 [SPLIT] 隔开的每一个段落，绝对只能在最开头出现【唯一一个】用括号包裹的动作/神态描写，写完括号后必须全是台词，段落中间或结尾绝对不准再出现任何括号描写，否则系统会崩溃！】" }
]

const PET_DYNAMIC_STYLES: Array[Dictionary] = [
    { "name": "单段简短回复", "weight": 50, "text": "【分段策略：单段自然回复】请将你的回答组织为连贯的一整段。要求：纯台词部分在 10 到 30 字之间，保证说话内容的完整性和生动感。【强制要求：绝对不要使用 [SPLIT] 拆分！】【极度致命警告：你的整个回复中，绝对只能在最开头出现【唯一一个】用括号包裹的动作/神态描写，写完括号后必须全是台词，句尾或句中绝对不准再出现任何括号描写！】" },
    { "name": "双段轻快交流", "weight": 50, "text": "【分段策略：双段轻快交流】请将你的回答分成 2 段发送。要求：【绝对强制】必须在两句话之间插入 [SPLIT] 作为分隔符！每个分段的台词应在 15 到 40 字之间，表现出聊天的停顿感。【极度致命警告：被 [SPLIT] 隔开的每一个段落，绝对只能在最开头出现【唯一一个】用括号包裹的动作/神态描写，写完括号后必须全是台词，段落中间或结尾绝对不准再出现任何括号描写！】" }
]

const MOBILE_CHAT_DYNAMIC_STYLES: Array[Dictionary] = [
    { "name": "单段手机回复", "weight": 50, "text": "【分段策略：单段回复】请将你的回答组织为连贯的一整段。要求：纯台词部分在 10 到 50 字之间，总字数不超过 100 字。【绝对强制警告：这是实时语音/文字通话，系统只接受纯粹的台词！不要用括号、星号等任何符号包裹任何动作、神情、呼吸或心理描写（如(笑)、(深吸气)、*叹气*等全都不允许）！输出的内容必须全是角色嘴里说出来的话，否则系统会崩溃！】" },
    { "name": "双段手机连续", "weight": 50, "text": "【分段策略：双段连续】请将你的回答分成 2 段发送，模拟连发两条消息/说话停顿。要求：【绝对强制】你必须在两段之间严格插入 [SPLIT] 字符串作为唯一的分隔符（例如：第一段[SPLIT]第二段）！每段包含 10 到 30 字的真实对话（总字数不超过 80 字）。【绝对强制警告：这是实时语音/文字通话，系统只接受纯粹的台词！不要用括号、星号等任何符号包裹任何动作、神情、呼吸或心理描写（如(笑)、(深吸气)、*叹气*等全都不允许）！输出的内容必须全是角色嘴里说出来的话，否则系统会崩溃！】" }
]

const NPC_EVENT_DYNAMIC_STYLES: Array[Dictionary] = [
    { "name": "单段事件回复", "weight": 50, "text": "【分段策略：单段自然回复】请将你的回答组织为连贯的一整段。要求：纯台词部分在 10 到 30 字之间，保证说话内容的完整性和生动感。【强制要求：这段话中只能出现1个全角或半角圆括号动作描述，且必须在句首！绝对禁止使用星号等其他符号。】" },
    { "name": "双段事件交流", "weight": 50, "text": "【分段策略：双段轻快交流】请将你的回答自然换行分成 2 段。每个分段的台词应在 15 到 40 字之间，表现出聊天的停顿感。【强制要求：每个换行的段落里，最多只能包含1个全角或半角圆括号动作描述，并且只能放在该段落的开头！绝对禁止使用星号等其他符号。】" }
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
        
    var time_str = ""
    # 桌宠使用真实的现实时间，其他剧情对话使用虚构的剧情时间
    if template_name == "desktop_pet":
        time_str = Time.get_datetime_string_from_system()
    else:
        time_str = GameDataManager.story_time_manager.get_story_time_string()
        
    var mood_desc = ""
    var current_expression = profile.current_expression
    if current_expression != "calm" and current_expression != "":
        var expression_desc = GameDataManager.expression_system.get_expression_description(current_expression)
        mood_desc += "【角色当前瞬时表情】：\n" + expression_desc + "\n"
        
    var mood_name = GameDataManager.mood_system.get_macro_mood_name(profile.mood_value)
    mood_desc += "【角色当前整体心情】：\n" + mood_name + "\n"
    var memory_desc = GameDataManager.memory_manager.get_memory_prompt(query_embedding)
    
    # 注入近期日记作为长期上下文摘要
    var diaries = profile.get_diaries()
    if diaries.size() > 0:
        var diary_text = ""
        # 取最近3篇日记
        var start_idx = max(0, diaries.size() - 3)
        for i in range(start_idx, diaries.size()):
            var d = diaries[i]
            var content = d.get("content", "").replace("\n", " ")
            diary_text += "【" + d.get("date", "未知日期") + " 日记】" + content + "\n"
            
        if diary_text != "":
            if memory_desc != "":
                memory_desc += "\n\n"
            memory_desc += "- 历史日记摘要（这是你过去写下的日记摘要，反映了你与玩家之前的经历，请作为重要的长期上下文参考）：\n" + diary_text
    
    var stage_conf = profile.get_current_stage_config()
    
    # 提取并替换占位符
    var safe_char_name = profile.char_name
    var player_name = profile.player_title
    if player_name.is_empty():
        player_name = "老师"
        
    var world_bg = profile.description.replace("{char_name}", safe_char_name)
    var st_title = stage_conf.get("stageTitle", "").replace("{char_name}", safe_char_name)
    var st_desc = stage_conf.get("stageDesc", "").replace("{char_name}", safe_char_name)
    
    var base_traits = GameDataManager.personality_system.get_base_traits(profile).replace("{char_name}", safe_char_name)
    var dyn_traits = GameDataManager.personality_system.get_dynamic_traits(profile).replace("{char_name}", safe_char_name)
    var p_traits = base_traits + "\n\n" + dyn_traits
    
    var topic_prefs = GameDataManager.personality_system.get_topic_preferences(profile).replace("{char_name}", safe_char_name)
    var m_habits = GameDataManager.personality_system.get_micro_habits(profile).replace("{char_name}", safe_char_name)
    var scene_set = stage_conf.get("scene_setting", "").replace("{char_name}", safe_char_name)
    var imp_notes = stage_conf.get("important_notes", "").replace("{char_name}", safe_char_name)
    
    var random_style = ""
    var random_style_name = ""
    if template_name == "desktop_pet":
        var msg_len = player_message.length()
        var current_styles = PET_DYNAMIC_STYLES.duplicate(true)
        
        if msg_len <= 10 and msg_len > 0:
            for s in current_styles:
                if s["name"] == "单段简短回复":
                    s["weight"] += 30
                elif s["name"] == "双段轻快交流":
                    s["weight"] = 0
        elif msg_len > 20:
            for s in current_styles:
                if s["name"] == "双段轻快交流":
                    s["weight"] += 60
                elif s["name"] == "单段简短回复":
                    s["weight"] = 0
                    
        var total_weight = 0
        for s in current_styles:
            total_weight += s["weight"]
            
        var random_val = randi() % total_weight if total_weight > 0 else 0
        random_style = current_styles[0]["text"]
        random_style_name = current_styles[0]["name"]
        for s in current_styles:
            random_val -= s["weight"]
            if random_val < 0:
                random_style = s["text"]
                random_style_name = s["name"]
                break
    elif template_name == "mobile_chat":
        var msg_len = player_message.length()
        var current_styles = MOBILE_CHAT_DYNAMIC_STYLES.duplicate(true)
        
        if msg_len <= 10 and msg_len > 0:
            for s in current_styles:
                if s["name"] == "单段手机回复":
                    s["weight"] += 30
                elif s["name"] == "双段手机连续":
                    s["weight"] = 0
        elif msg_len > 20:
            for s in current_styles:
                if s["name"] == "双段手机连续":
                    s["weight"] += 60
                elif s["name"] == "单段手机回复":
                    s["weight"] = 0
                    
        var total_weight = 0
        for s in current_styles:
            total_weight += s["weight"]
            
        var random_val = randi() % total_weight if total_weight > 0 else 0
        random_style = current_styles[0]["text"]
        random_style_name = current_styles[0]["name"]
        for s in current_styles:
            random_val -= s["weight"]
            if random_val < 0:
                random_style = s["text"]
                random_style_name = s["name"]
                break
    else:
        var msg_len = player_message.length()
        var current_styles = DYNAMIC_STYLES.duplicate(true)
        
        if msg_len <= 10 and msg_len > 0:
            for s in current_styles:
                if s["name"] == "单段回复":
                    s["weight"] += 40
                elif s["name"] == "双段连续":
                    s["weight"] = 0
                elif s["name"] == "三段递进":
                    s["weight"] = 0
        elif msg_len > 20:
            for s in current_styles:
                if s["name"] == "三段递进":
                    s["weight"] += 50
                elif s["name"] == "双段连续":
                    s["weight"] += 30
                elif s["name"] == "单段回复":
                    s["weight"] = 0
                    
        var total_weight = 0
        for s in current_styles:
            total_weight += s["weight"]
            
        var random_val = randi() % total_weight if total_weight > 0 else 0
        random_style = current_styles[0]["text"]
        random_style_name = current_styles[0]["name"]
        for s in current_styles:
            random_val -= s["weight"]
            if random_val < 0:
                random_style = s["text"]
                random_style_name = s["name"]
                break
                
    print("[PromptManager] 当前输入字数: ", player_message.length(), " | 选定的分段策略: ", random_style_name)
    
    # 动态注入
    var base_prompt = template.format({
        "name": safe_char_name,
        "player_name": player_name,
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
    var mood_name = GameDataManager.mood_system.get_macro_mood_name(profile.mood_value)
    
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
    
    var player_name = profile.player_title
    if player_name.is_empty():
        player_name = "指导人"
        
    return template.format({
        "name": profile.char_name,
        "player_name": player_name,
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

func build_npc_event_prompt(npc_name: String, personality: String, protagonist_name: String, stage: int, stage_title: String, event_desc: String) -> String:
    var template = load_template("npc_event")
    if template == "":
        return ""
        
    var current_styles = NPC_EVENT_DYNAMIC_STYLES.duplicate(true)
    var total_weight = 0
    for s in current_styles:
        total_weight += s["weight"]
        
    var random_val = randi() % total_weight if total_weight > 0 else 0
    var random_style = current_styles[0]["text"]
    for s in current_styles:
        random_val -= s["weight"]
        if random_val < 0:
            random_style = s["text"]
            break
        
    return template.format({
        "npc_name": npc_name,
        "personality": personality,
        "protagonist_name": protagonist_name,
        "stage": str(stage),
        "stage_title": stage_title,
        "event_desc": event_desc,
        "dynamic_style": random_style
    })

func build_proactive_greeting_prompt(profile: CharacterProfile, prompt_type: String = "") -> String:
    var stage_conf = profile.get_current_stage_config()
    var stage_title = stage_conf.get("stageTitle", "陌生人")
    var stage_desc = stage_conf.get("stageDesc", "")
    var char_name = profile.char_name
    
    var prompt = "【系统指令】\n"
    prompt += "玩家刚刚打开了游戏主界面。\n"
    
    if prompt_type == "course":
        prompt += "今天是星期一。请基于当前的日期，主动聊一句关于新的一周、学业或者课程安排的话题。\n"
    elif prompt_type == "daily":
        prompt += "今天是周末（星期六或星期日）。请基于当前的日期，主动聊一句关于周末放松、休息或者日常活动的话题。\n"
    else:
        prompt += "请基于当前的情景，主动发出一句简短的问候。\n"
        
    prompt += "请基于当前你（%s）与玩家的情感阶段（当前阶段：%s，说明：%s），主动对玩家说话。\n" % [char_name, stage_title, stage_desc]
    prompt += "要求：\n"
    prompt += "1. 必须符合当前的情感深度和人设，语气要自然。\n"
    prompt += "2. 字数在15-40字之间。\n"
    prompt += "3. 【强制要求：你的回复中，绝对只能在最开头出现【唯一一个】用括号包裹的动作/神态描写，写完括号后必须全是台词，句尾或句中绝对不准再出现任何括号描写！】\n"
    prompt += "4. 不要输出任何系统提示，直接以第一人称代入角色进行对话。"
    return prompt

func build_moment_generation_prompt(profile: CharacterProfile) -> String:
    var char_name = "AI"
    var personality = "未知"
    var mood = "平静"
    
    if profile:
        char_name = profile.char_name
        personality = GameDataManager.personality_system.get_personality_summary(profile)
        mood = GameDataManager.mood_system.get_macro_mood_name(profile.mood_value)
    
    var prompt = "【系统指令】\n"
    prompt += "你扮演的角色是：%s。\n" % char_name
    prompt += "你的性格特征是：%s。\n" % personality
    prompt += "你当前的心情是：%s。\n" % mood
    prompt += "请根据你的性格和当前心情，写一条朋友圈动态（类似微信朋友圈）。\n"
    prompt += "要求：\n"
    prompt += "1. 内容要贴合现代生活，自然、生活化。\n"
    prompt += "2. 字数在20-80字之间。\n"
    prompt += "3. 直接输出朋友圈的正文内容，不要包含任何多余的系统提示或格式。\n"
    return prompt

func build_moment_reply_prompt(profile: CharacterProfile, moment_content: String, player_comment: String) -> String:
    var char_name = "AI"
    var personality = "未知"
    var mood = "平静"
    var player_name = "玩家"
    
    if profile:
        char_name = profile.char_name
        personality = GameDataManager.personality_system.get_personality_summary(profile)
        mood = GameDataManager.mood_system.get_macro_mood_name(profile.mood_value)
        player_name = profile.player_title
        if player_name.is_empty():
            player_name = "玩家"
        
    var prompt = "【系统指令】\n"
    prompt += "你扮演的角色是：%s。\n" % char_name
    prompt += "你的性格特征是：%s。\n" % personality
    prompt += "你当前的心情是：%s。\n" % mood
    prompt += "你刚刚发了一条朋友圈，内容是：“%s”\n" % moment_content
    prompt += "现在，【%s】评论了你的这条朋友圈：“%s”\n" % [player_name, player_comment]
    prompt += "请你回复【%s】的评论。\n" % player_name
    prompt += "要求：\n"
    prompt += "1. 回复要简短自然，像真实的社交软件互动一样。\n"
    prompt += "2. 字数在10-50字之间。\n"
    prompt += "3. 直接输出回复的正文内容，不要包含任何多余的系统提示或格式。\n"
    return prompt
