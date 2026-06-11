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
var world_setting_cache: String = ""

func _resolve_flavor_label(profile: CharacterProfile) -> String:
	if profile == null or GameDataManager.personality_system == null:
		return "防备疏离"
	return GameDataManager.personality_system.get_relationship_flavor_label(profile)

func load_world_setting() -> String:
	if world_setting_cache != "":
		return world_setting_cache
		
	var path = "res://assets/data/world/world_setting.json"
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		var content = file.get_as_text()
		file.close()
		var json = JSON.new()
		if json.parse(content) == OK:
			var data = json.get_data()
			if data is Dictionary:
				world_setting_cache = data.get("world_background", "")
				return world_setting_cache
	return ""

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

func _get_relationship_prompt_floor(stage_num: int) -> float:
	if stage_num >= 9:
		return 220.0
	if stage_num >= 8:
		return 180.0
	if stage_num >= 6:
		return 140.0
	if stage_num >= 4:
		return 90.0
	if stage_num >= 3:
		return 60.0
	return 0.0

func build_chat_prompt(profile: CharacterProfile, player_message: String = "", query_embedding: Array = []) -> String:
	return build_system_prompt(profile, "default_chat", player_message, query_embedding)

func build_system_prompt(profile: CharacterProfile, template_name: String = "default_chat", player_message: String = "", query_embedding: Array = []) -> String:
	var template = load_template(template_name)
	if template == "":
		return ""
		
	var time_str = ""
	# 桌宠使用真实的现实时间，其他剧情对话使用虚构的剧情时间
	var weather_context = ""
	if template_name == "desktop_pet":
		time_str = Time.get_datetime_string_from_system()
		if GameDataManager.weather_manager and GameDataManager.weather_manager.is_weather_ready:
			weather_context = "【现实天气】：你感知到玩家窗外现在是%s，气温大约%d度。可以在适当时机自然地融入你的关心或吐槽中。" % [GameDataManager.weather_manager.current_weather_desc, GameDataManager.weather_manager.current_temp]
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
		
	var identity_bg = profile.description.replace("{char_name}", safe_char_name)
	var global_world_bg = load_world_setting()
	
	var st_title = stage_conf.get("stageTitle", "").replace("{char_name}", safe_char_name)
	var st_desc = stage_conf.get("stageDesc", "").replace("{char_name}", safe_char_name)
	var flavor_label = _resolve_flavor_label(profile)
	
	var intimacy_value = float(profile.intimacy)
	var intimacy_desc = ""
	if intimacy_value < 50:
		intimacy_desc = "【当前亲密度】：疏离。角色与你保持社交距离，言语客气但有分寸。"
	elif intimacy_value < 150:
		intimacy_desc = "【当前亲密度】：暧昧。角色对你有明显好感，偶尔会开一些亲近的玩笑。"
	else:
		intimacy_desc = "【当前亲密度】：炽热。角色与你建立了深厚的情感羁绊，言行间透露着强烈的依赖感。"
		
	var trust_value = float(profile.trust)
	var trust_desc = ""
	if trust_value < 50:
		trust_desc = "【当前信任度】：极低。角色对你极度缺乏安全感，心防很重，哪怕亲密度高也容易患得患失，不敢分享内心的秘密。"
	elif trust_value < 150:
		trust_desc = "【当前信任度】：中等。角色对你有了一定的信任，开始愿意尝试与你分享一些日常的烦恼，但内心深处的秘密依然会有所保留。"
	else:
		trust_desc = "【当前信任度】：极高。角色在你面前彻底卸下了伪装和心防，拥有绝对的安全感，敢于向你展露自己最脆弱、真实甚至任性的一面。"
		
	var rel_desc = intimacy_desc + "\n" + trust_desc
	var stage_guardrail = "【演化约束】当前处于“%s”阶段。动态人格只允许补充口吻、偏好和局部应激反应，不得覆盖该阶段的人际边界、scene_setting、important_notes，以及当前真实亲密度/信任度；若发生冲突，必须以阶段设定和重要备注为准。" % st_title
		
	var base_traits = GameDataManager.personality_system.get_base_traits(profile).replace("{char_name}", safe_char_name)
	var dyn_traits = GameDataManager.personality_system.get_dynamic_traits(profile).replace("{char_name}", safe_char_name)
	var p_traits = base_traits + "\n\n" + dyn_traits + "\n\n" + stage_guardrail
	
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
		"world_setting": "【世界观背景】：\n" + global_world_bg if global_world_bg != "" else "",
		"identity_background": "【角色身份背景】：\n" + identity_bg,
		"intimacy": str(profile.intimacy),
		"trust": str(profile.trust),
		"flavor": flavor_label,
		"stage_title": st_title,
		"stage_desc": st_desc,
		"trust_desc": rel_desc,
		"personality_traits": p_traits,
		"topic_preferences": topic_prefs,
		"micro_habits": m_habits,
		"scene_setting": scene_set,
		"important_notes": imp_notes,
		"time": time_str,
		"weather": weather_context,
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
		
	var current_memories = "{}"
	if GameDataManager.memory_manager and GameDataManager.memory_manager.has_method("get_memory_snapshot_for_extraction"):
		current_memories = JSON.stringify(GameDataManager.memory_manager.get_memory_snapshot_for_extraction(), "\t")
		
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
		
	var flavor_label = _resolve_flavor_label(profile)
	stage_desc += "\n当前情感状态：亲密度 %.1f，信任度 %.1f。情感风味：%s" % [profile.intimacy, profile.trust, flavor_label]
	var mood_data = GameDataManager.mood_system.get_macro_mood(profile.mood_value)
	var mood_name = str(mood_data.get("name", "平静"))
	var mood_guidance = _build_option_mood_guidance(str(mood_data.get("id", "calm")), mood_name)
		
	var option_constraints = GameDataManager.personality_system.get_option_constraints(profile)
	
	var player_name = profile.player_title
	if player_name.is_empty():
		player_name = "指导人"
		
	return template.format({
		"name": profile.char_name,
		"player_name": player_name,
		"stage_desc": stage_desc,
		"mood_name": mood_name,
		"mood_guidance": mood_guidance,
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

func build_npc_event_prompt(npc_name: String, personality: String, protagonist_name: String, stage: int, stage_title: String, event_desc: String, intimacy: float = 0.0, trust: float = 0.0) -> String:
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
			
	# 为了防止 template 没兼容 intimacy 和 trust，我们仍然传 stage
	return template.format({
		"npc_name": npc_name,
		"personality": personality,
		"protagonist_name": protagonist_name,
		"stage": str(stage),
		"intimacy": str(intimacy),
		"trust": str(trust),
		"stage_title": stage_title,
		"event_desc": event_desc,
		"dynamic_style": random_style
	})

func build_end_chat_prompt(profile: CharacterProfile, recent_history: String) -> String:
	var template = load_template("end_chat")
	var flavor_label = _resolve_flavor_label(profile)
	if template == "":
		return "【系统提示：玩家想要结束本次对话。请根据你们当前的关系状态（亲密度：%.1f，信任度：%.1f，风味：%s），并结合以下刚才聊天的上下文，给出自然的告别反应。注意：1. 只能回复单句告别语。2. 不要输出这段系统提示，直接以%s的口吻说话。】\n[近期聊天上下文]\n%s" % [profile.intimacy, profile.trust, flavor_label, profile.char_name, recent_history]
		
	return template.format({
		"stage": str(profile.current_stage),
		"intimacy": str(profile.intimacy),
		"trust": str(profile.trust),
		"flavor": flavor_label,
		"char_name": profile.char_name,
		"recent_history": recent_history
	})

func build_narrator_prompt(profile: CharacterProfile, recent_history: String, event_desc: String = "请生成进入场景时的旁白") -> String:
	var template = load_template("narrator_generation")
	if template == "":
		return ""
	var stage_conf = profile.get_current_stage_config()
	var player_name = ""
	if GameDataManager.player_profile:
		player_name = str(GameDataManager.player_profile.name)
	if player_name == "":
		player_name = "玩家"
	var weather_text = ""
	if GameDataManager.story_time_manager:
		weather_text = GameDataManager.story_time_manager.get_story_weather_desc()
	var flavor_label = _resolve_flavor_label(profile)
	return template.format({
		"time": GameDataManager.story_time_manager.get_story_time_string() if GameDataManager.story_time_manager else "",
		"weather": weather_text,
		"char_name": profile.char_name,
		"player_name": player_name,
		"intimacy": "%.1f" % profile.intimacy,
		"trust": "%.1f" % profile.trust,
		"flavor": flavor_label,
		"stage_title": str(stage_conf.get("stageTitle", "")),
		"stage_desc": str(stage_conf.get("stageDesc", "")),
		"event_desc": event_desc,
		"recent_history": recent_history
	})

func build_proactive_greeting_prompt(profile: CharacterProfile, prompt_type: String = "") -> String:
	var template = load_template("proactive_greeting")
	var stage_conf = profile.get_current_stage_config()
	var stage_title = stage_conf.get("stageTitle", "陌生人")
	var stage_desc = stage_conf.get("stageDesc", "")
	var flavor_label = _resolve_flavor_label(profile)
	var char_name = profile.char_name
	
	var type_desc = "请基于当前的情景，主动发出一句简短的问候。"
	if prompt_type == "course":
		type_desc = "今天是星期一。请基于当前的日期，主动聊一句关于新的一周、学业或者课程安排的话题。"
	elif prompt_type == "daily":
		type_desc = "今天是周末（星期六或星期日）。请基于当前的日期，主动聊一句关于周末放松、休息或者日常活动的话题。"
		
	if template == "":
		var prompt = "【系统指令】\n"
		prompt += "玩家刚刚打开了游戏主界面。\n"
		prompt += type_desc + "\n"
		prompt += "请基于当前你（%s）与玩家的情感状态（亲密度：%.1f，信任度：%.1f，风味：%s），主动对玩家说话。\n" % [char_name, profile.intimacy, profile.trust, flavor_label]
		prompt += "要求：\n"
		prompt += "1. 必须符合当前的情感深度和人设，语气要自然。\n"
		prompt += "2. 字数在15-40字之间。\n"
		prompt += "3. 【强制要求：你的回复中，绝对只能在最开头出现【唯一一个】用括号包裹的动作/神态描写，写完括号后必须全是台词，句尾或句中绝对不准再出现任何括号描写！】\n"
		prompt += "4. 不要输出任何系统提示，直接以第一人称代入角色进行对话。"
		return prompt
		
	return template.format({
		"type_desc": type_desc,
		"char_name": char_name,
		"intimacy": str(profile.intimacy),
		"trust": str(profile.trust),
		"flavor": flavor_label,
		"stage_title": stage_title,
		"stage_desc": stage_desc
	})

func build_memory_revisit_prompt(profile: CharacterProfile, revisit_data: Dictionary, trigger_context: Dictionary = {}) -> String:
	var char_name = profile.char_name
	var flavor_label = _resolve_flavor_label(profile)
	var stage_conf = profile.get_current_stage_config()
	var stage_title = stage_conf.get("stageTitle", "陌生人")
	var stage_desc = stage_conf.get("stageDesc", "")
	var player_name = profile.player_title
	if player_name.is_empty():
		player_name = "指导人"
	
	var memory_content = str(revisit_data.get("content", "")).strip_edges()
	var layer = str(revisit_data.get("layer", "bond"))
	var story_time = str(revisit_data.get("story_time", ""))
	var context_domain = str(trigger_context.get("context_domain", "story"))
	var layer_desc = {
		"bond": "共同经历或约定",
		"emotion": "情绪与关心相关的记忆",
		"habit": "关于玩家习惯与偏好的记忆"
	}.get(layer, "你们之间的重要记忆")
	
	var prompt = "【系统指令】\n"
	prompt += "你现在要主动发起一次“记忆回访事件”。\n"
	prompt += "你回想起了一段关于玩家的重要记忆，请自然地主动提起它，并围绕它开启一段新的对话。\n"
	prompt += "【角色】%s\n" % char_name
	prompt += "【玩家身份称呼】%s\n" % player_name
	prompt += "【当前关系阶段】%s\n" % stage_title
	prompt += "【当前关系描述】%s\n" % stage_desc
	prompt += "【当前关系风味】%s\n" % flavor_label
	prompt += "【回访记忆类型】%s\n" % layer_desc
	prompt += "【回访记忆内容】%s\n" % memory_content
	if context_domain == "reality":
		var real_hour = int(trigger_context.get("real_hour", Time.get_datetime_dict_from_system().get("hour", 0)))
		var real_period = str(trigger_context.get("real_period", ""))
		var real_weather = str(trigger_context.get("real_weather", ""))
		prompt += "【当前陪伴模式】现实桌宠陪伴\n"
		prompt += "【当前现实时间】%02d点，%s\n" % [real_hour, real_period if real_period != "" else "当前时段"]
		if real_weather != "":
			prompt += "【当前现实天气】%s\n" % real_weather
		prompt += "要求补充：\n"
		prompt += "- 这次回访发生在现实陪伴场景里，只能结合现实时间和现实天气来引出记忆。\n"
		prompt += "- 不要把剧情地图地点、剧情日程、剧情天气直接说出来。\n"
	else:
		var story_location_id = str(trigger_context.get("story_location_id", ""))
		var story_weather = str(trigger_context.get("story_weather", ""))
		var story_period = str(trigger_context.get("story_period", ""))
		prompt += "【当前陪伴模式】主场景剧情陪伴\n"
		if story_time != "":
			prompt += "【这段记忆发生时的剧情时间】%s\n" % story_time
		if story_period != "":
			prompt += "【当前剧情时段】%s\n" % story_period
		if story_weather != "":
			prompt += "【当前剧情天气】%s\n" % story_weather
		if story_location_id != "":
			prompt += "【当前剧情地点ID】%s\n" % story_location_id
		prompt += "要求补充：\n"
		prompt += "- 这次回访发生在剧情世界里，只能结合剧情时间、剧情天气、剧情地点来引出记忆。\n"
		prompt += "- 不要提到现实时间、窗外真实天气或桌面环境。\n"
	prompt += "要求：\n"
	prompt += "1. 以第一人称、角色口吻主动提起这段记忆，不要生硬复读原文。\n"
	prompt += "2. 语气要体现“我记得这件事”，并自然延展成当前可以继续聊的话题。\n"
	prompt += "3. 回复长度控制在 30 到 80 字之间。\n"
	prompt += "4. 必须包含且只能在最开头出现一个括号动作描写，之后全部是台词。\n"
	prompt += "5. 不要输出系统提示，不要解释你在调用记忆系统。\n"
	return prompt

func build_schedule_event_prompt(context: Dictionary) -> String:
	var course_name = str(context.get("course_name", "未知课程"))
	var course_desc = str(context.get("course_desc", ""))
	var category_name = str(context.get("category_name", "综合课程"))
	var day_label = str(context.get("day_label", "本日"))
	var bonus_summary = str(context.get("bonus_summary", "无"))
	var mood = int(context.get("mood", 50))
	var mood_name = str(context.get("mood_name", "平静"))
	var mood_bias = _build_schedule_event_mood_guidance(str(context.get("mood_tag", "calm")), mood_name)

	var prompt = "你是一个校园课程随机事件生成器。请围绕指定课程，生成一个与课程内容强相关的课堂/训练/实践中的小事件。\n"
	prompt += "课程名称：%s\n" % course_name
	prompt += "课程描述：%s\n" % course_desc
	prompt += "课程类别：%s\n" % category_name
	prompt += "发生时间：%s\n" % day_label
	prompt += "课程主要收益：%s\n" % bonus_summary
	prompt += "角色当前心情：%s（%d）\n" % [mood_name, mood]
	prompt += "心情偏向：%s\n" % mood_bias
	prompt += "要求：\n"
	prompt += "1. 事件必须与该课程强相关，不能写成泛化的日常事件。\n"
	prompt += "2. 事件描述 30 到 60 字，选项文案 12 字以内。\n"
	prompt += "3. 两个选项要体现不同倾向，例如稳妥/冒险、专注/社交、保守/激进。\n"
	prompt += "4. 五档心情要明确区分：崩溃=止损恢复，低落=被接住与回稳，平静=常规推进，愉悦=主动尝试，心花怒放=高光突破。\n"
	prompt += "5. 输出必须是纯 JSON，不要附加解释。\n"
	prompt += "JSON 格式如下：\n"
	prompt += "{\n"
	prompt += "  \"event_title\": \"事件标题\",\n"
	prompt += "  \"event_desc\": \"事件描述\",\n"
	prompt += "  \"options\": [\n"
	prompt += "    {\"text\": \"选项1\", \"style\": \"稳妥\", \"effects_hint\": \"偏向稳定收益\"},\n"
	prompt += "    {\"text\": \"选项2\", \"style\": \"冒险\", \"effects_hint\": \"偏向高风险高收益\"}\n"
	prompt += "  ]\n"
	prompt += "}\n"
	return prompt

func build_date_story_prompt(context: Dictionary) -> String:
	var character_name := str(context.get("character_name", "Luna"))
	var character_id := str(context.get("character_id", "luna"))
	var player_name := str(context.get("player_name", "玩家"))
	var player_title := str(context.get("player_title", "老师"))
	var stage_num := int(context.get("relationship_stage", 1))
	var stage_title := str(context.get("relationship_stage_title", "熟悉阶段"))
	var intimacy := float(context.get("intimacy", 0.0))
	var trust := float(context.get("trust", 0.0))
	var date_label := str(context.get("date_label", "未知日期"))
	var weather_desc := str(context.get("story_weather_desc", "晴天"))
	var temperature := int(context.get("temperature", 20))
	var plan_segments: Array = context.get("date_plan", [])

	var prompt := "你是一个 Galgame 约会剧情编剧，需要根据给定的约会计划，输出一份可以被游戏脚本引擎直接播放的 JSON 剧本。\n"
	prompt += "【主角信息】\n"
	prompt += "女主角色ID：%s\n" % character_id
	prompt += "女主名字：%s\n" % character_name
	prompt += "玩家名字：%s\n" % player_name
	prompt += "玩家称呼：%s\n" % player_title
	prompt += "当前关系阶段：第%d阶段（%s）\n" % [stage_num, stage_title]
	prompt += "亲密度：%.1f\n" % intimacy
	prompt += "信任度：%.1f\n" % trust
	prompt += "【约会环境】\n"
	prompt += "日期：%s\n" % date_label
	prompt += "天气：%s，气温：%d度\n" % [weather_desc, temperature]
	prompt += "【约会计划】\n"
	for i in range(plan_segments.size()):
		var segment: Dictionary = plan_segments[i]
		prompt += "%d. 时段：%s\n" % [i + 1, str(segment.get("period_label", "白天"))]
		prompt += "   地点：%s（%s）\n" % [
			str(segment.get("location_name", "未知地点")),
			str(segment.get("location_id", ""))
		]
		prompt += "   地点描述：%s\n" % str(segment.get("location_description", "暂无描述"))
		prompt += "   背景图ID：%s\n" % str(segment.get("bg_id", ""))
		prompt += "   约会类型：%s\n" % str(segment.get("type_name", "约会"))
		prompt += "   模板标题：%s\n" % str(segment.get("template_title", "约会片段"))
		prompt += "   模板大纲：%s\n" % str(segment.get("template_outline", ""))
		prompt += "   必须桥段：%s\n" % JSON.stringify(segment.get("must_have_beats", []))
		prompt += "   情绪标签：%s\n" % JSON.stringify(segment.get("mood_tags", []))

	prompt += "【输出要求】\n"
	prompt += "1. 输出必须是纯 JSON 对象，不要输出解释、不要输出 Markdown 代码块。\n"
	prompt += "2. 剧情风格要像 galgame 约会剧情，包含旁白、玩家对白、女主对白，并有明显演出感。\n"
	prompt += "3. 必须让每个已选时段都在剧情里出现，允许通过旁白完成转场。\n"
	prompt += "4. 请优先使用以下事件类型：background、audio、dialogue、show_character、move_character、hide_character。\n"
	prompt += "5. speaker 只能使用：旁白、player、%s。\n" % character_id
	prompt += "6. show_character / move_character / hide_character 中的 character 必须使用 %s。\n" % character_id
	prompt += "7. background 事件里的 bg_id 必须从提供的地点背景图ID中选择，不要杜撰不存在的 bg_id。\n"
	prompt += "8. audio 事件若需要播放 BGM，请使用：{\"type\":\"audio\",\"audio_id\":\"luna_bgm\",\"audio_type\":\"bgm\",\"action\":\"play\"}。\n"
	prompt += "9. 整体事件数量建议控制在 12 到 28 个之间，既要有内容，也不要拖沓。\n"
	prompt += "10. 女主台词要符合当前关系阶段，不能突然越界告白，也不能生硬疏离。\n"
	prompt += "11. memory_records 至少输出 1 条，用于记录这次约会回忆，content 需要是可直接存档的自然语言摘要。\n"
	prompt += "12. 如果有多个时段，剧情要体现感情递进，而不是把几个地点写成互不关联的独立短篇。\n"
	prompt += "【JSON 格式】\n"
	prompt += "{\n"
	prompt += "  \"script_id\": \"date_dynamic_xxx\",\n"
	prompt += "  \"story_location_id\": \"第一个地点的location_id\",\n"
	prompt += "  \"story_period\": \"第一个时段的中文名\",\n"
	prompt += "  \"use_portraits\": true,\n"
	prompt += "  \"summary\": \"30到80字的约会摘要\",\n"
	prompt += "  \"memory_enabled\": true,\n"
	prompt += "  \"memory_records\": [\n"
	prompt += "    {\n"
	prompt += "      \"title\": \"约会回忆标题\",\n"
	prompt += "      \"layer\": \"bond\",\n"
	prompt += "      \"scope\": \"player_shared\",\n"
	prompt += "      \"visibility\": \"prompt\",\n"
	prompt += "      \"participants\": [\"player\", \"%s\"],\n" % character_id
	prompt += "      \"player_involved\": true,\n"
	prompt += "      \"player_witnessed\": true,\n"
	prompt += "      \"is_bond_mark\": false,\n"
	prompt += "      \"content\": \"一句自然的回忆摘要\"\n"
	prompt += "    }\n"
	prompt += "  ],\n"
	prompt += "  \"chapters\": {\n"
	prompt += "    \"start\": {\n"
	prompt += "      \"events\": [\n"
	prompt += "        {\"type\": \"background\", \"bg_id\": \"...\", \"transition_type\": \"fade\", \"duration\": 0.4},\n"
	prompt += "        {\"type\": \"audio\", \"audio_id\": \"luna_bgm\", \"audio_type\": \"bgm\", \"action\": \"play\"},\n"
	prompt += "        {\"type\": \"show_character\", \"character\": \"%s\", \"display_name\": \"%s\", \"position\": \"center\", \"expression\": \"calm\", \"animation\": \"fade_in\", \"focus\": true},\n" % [character_id, character_name]
	prompt += "        {\"type\": \"dialogue\", \"speaker\": \"旁白\", \"content\": \"...\"},\n"
	prompt += "        {\"type\": \"dialogue\", \"speaker\": \"%s\", \"content\": \"...\"}\n" % character_id
	prompt += "      ]\n"
	prompt += "    }\n"
	prompt += "  }\n"
	prompt += "}\n"
	return prompt

func _build_option_mood_guidance(mood_id: String, mood_name: String) -> String:
	match mood_id:
		"broken":
			return "当前心情为%s。两个选项都必须先止损和接住情绪，优先安抚、陪伴、确认安全感，只能非常轻地表达在乎，绝对不要追问、施压或突然推进关系。" % mood_name
		"low":
			return "当前心情为%s。选项1要明显偏安抚、共情和温柔陪伴；选项2偏稳定承接与轻引导，可以小幅拉近距离，但整体仍以让对方放松下来为主。" % mood_name
		"calm":
			return "当前心情为%s。选项1偏温柔亲近，选项2偏可靠支持，整体自然平衡，不要刻意卖惨，也不要突然暧昧升温，重点是舒服顺畅地推进对话。" % mood_name
		"pleasant":
			return "当前心情为%s。选项1可以更自然地拉近距离、给出夸赞或亲近感；选项2可以更明确地表达支持、期待或下次一起做什么，允许适度推进关系。" % mood_name
		"ecstatic":
			return "当前心情为%s。选项整体可以更主动、更明亮，允许轻微暧昧、共享计划、确认彼此亲近感，甚至直接往下一步关系靠近，但仍要自然不油腻。" % mood_name
		_:
			return "当前心情为%s。保持一条偏温柔亲近、一条偏可靠支持，整体自然平衡。" % mood_name

func _build_schedule_event_mood_guidance(mood_id: String, mood_name: String) -> String:
	match mood_id:
		"broken":
			return "%s：事件应该优先止损与恢复，强调缓冲、喘息、被照顾、避免失控，尽量不要出现高压硬顶和强行表现。" % mood_name
		"low":
			return "%s：事件更偏向被接住、稳妥回稳、慢慢找回手感，可以有轻度坚持，但不能太冲太险。" % mood_name
		"calm":
			return "%s：事件保持常规平衡，更像正常发挥中的小岔路，重点是稳步推进、轻微取舍和节奏判断。" % mood_name
		"pleasant":
			return "%s：事件可以更偏向主动尝试、顺势表现、放大当前手感，允许适度挑战，但仍要留有稳定落点。" % mood_name
		"ecstatic":
			return "%s：事件可以更偏向高光表现、临场突破、抓住机会一口气往上冲，但必须仍然贴着课程内容，不能写飘。" % mood_name
		_:
			return "%s：事件保持常规平衡，同时让两个选项走向清晰区分。" % mood_name

func build_schedule_resolve_prompt(context: Dictionary) -> String:
	var course_name = str(context.get("course_name", "未知课程"))
	var category_name = str(context.get("category_name", "综合课程"))
	var bonus_summary = str(context.get("bonus_summary", "无"))

	var prompt = "你是一个课程随机事件结算生成器。请根据课程背景、事件描述和玩家选择，输出一次简洁明确的结算结果。\n"
	prompt += "课程名称：%s\n" % course_name
	prompt += "课程类别：%s\n" % category_name
	prompt += "课程主要收益：%s\n" % bonus_summary
	prompt += "要求：\n"
	prompt += "1. 结算必须与课程和选项倾向相关。\n"
	prompt += "2. 属性变化范围通常在 -12 到 12 之间，避免所有属性同时变化。\n"
	prompt += "3. 尽量只影响 1 到 3 个属性。\n"
	prompt += "4. 输出必须是纯 JSON，不要附加解释。\n"
	prompt += "JSON 格式如下：\n"
	prompt += "{\n"
	prompt += "  \"result_desc\": \"结果描述（20到50字）\",\n"
	prompt += "  \"attr_changes\": {\n"
	prompt += "    \"体能\": 0,\n"
	prompt += "    \"反应\": 0,\n"
	prompt += "    \"学识\": 0,\n"
	prompt += "    \"表达\": 0,\n"
	prompt += "    \"气质\": 0,\n"
	prompt += "    \"礼仪\": 0,\n"
	prompt += "    \"审美\": 0,\n"
	prompt += "    \"感知\": 0,\n"
	prompt += "    \"金币\": 0,\n"
	prompt += "    \"心情\": 0\n"
	prompt += "  }\n"
	prompt += "}\n"
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
