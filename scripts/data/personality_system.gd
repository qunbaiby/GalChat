class_name PersonalitySystem
extends Node

const MIN_SCORE: float = 10.0
const MAX_SCORE: float = 90.0
const EVENT_RULES_PATH := "res://assets/data/personality/personality_event_rules.json"
const SNAPSHOT_DELTA_THRESHOLD := 4.0
const PRESSURE_CLEAR_THRESHOLD := 0.05
const SHORT_PRESSURE_SETTLE_SCALE := 0.55
const SHORT_PRESSURE_RETAIN_SCALE := 0.35
const LONG_PRESSURE_SETTLE_SCALE := 0.2
const LONG_PRESSURE_RETAIN_SCALE := 0.88
const LLM_FEEDBACK_SINGLE_TRAIT_LIMIT := 3.0
const LLM_FEEDBACK_TOTAL_DELTA_LIMIT := 6.5
const LLM_RELATION_SINGLE_DELTA_LIMIT := 8.0
const LLM_RELATION_TOTAL_DELTA_LIMIT := 12.0
const PRIMARY_ARCHETYPE_SWITCH_MARGIN := 10.0
const SECONDARY_ARCHETYPE_SWITCH_MARGIN := 8.0

var _event_rules: Dictionary = {}

func _ready() -> void:
	_load_event_rules()

func update_trait(profile: CharacterProfile, trait_name: String, delta_value: float) -> float:
	return apply_trait_delta(profile, trait_name, delta_value)

func apply_trait_delta(profile: CharacterProfile, trait_name: String, delta_value: float) -> float:
	if profile == null or abs(delta_value) <= 0.001:
		return 0.0
	var trait_lower = trait_name.to_lower()
	var current_val = 0.0
	var base_val = 50.0 # 默认底色，如果没有设置 base_personality，默认50
	var prop_name = ""
	
	if trait_lower == "openness" or trait_lower == "开放性":
		prop_name = "openness"
	elif trait_lower == "conscientiousness" or trait_lower == "尽责性":
		prop_name = "conscientiousness"
	elif trait_lower == "extraversion" or trait_lower == "外倾性":
		prop_name = "extraversion"
	elif trait_lower == "agreeableness" or trait_lower == "宜人性":
		prop_name = "agreeableness"
	elif trait_lower == "neuroticism" or trait_lower == "神经质":
		prop_name = "neuroticism"
	else:
		return 0.0
		
	current_val = profile.get(prop_name)
	if profile.base_personality.has(prop_name):
		base_val = profile.base_personality[prop_name]
		
	# 【性格惯性与阻力算法】
	# 1. 距离初始底色越远，修改难度越大（阻力算法）
	var distance_from_base = abs(current_val - base_val)
	# 距离最大可能为 80 (90 - 10)。每偏离 10 分，阻力增加 10%，即 delta 衰减 10%
	var resistance_multiplier = max(0.2, 1.0 - (distance_from_base / 100.0))
	
	# 2. 回弹机制 (向底色回归)：如果本次 delta 的方向与当前偏离方向相反（即帮助其回归底色），则不受到阻力，甚至给予轻微补偿
	var is_returning = false
	if (current_val > base_val and delta_value < 0) or (current_val < base_val and delta_value > 0):
		is_returning = true
		
	var final_delta = delta_value
	if not is_returning:
		final_delta = delta_value * resistance_multiplier
	else:
		# 回归时，速度加快 20%
		final_delta = delta_value * 1.2
		
	var new_val = clamp(current_val + final_delta, MIN_SCORE, MAX_SCORE)
	profile.set(prop_name, new_val)
	
	print("[Personality] %s 变化: 原始Delta=%.2f, 实际Delta=%.2f, 最终值: %.2f (底色: %.2f)" % [prop_name, delta_value, final_delta, new_val, base_val])
	return new_val - current_val

func apply_personality_event(profile: CharacterProfile, event_type: String, payload: Dictionary = {}) -> Dictionary:
	if profile == null or event_type.strip_edges() == "":
		return {}
	if _event_rules.is_empty():
		_load_event_rules()

	var resolved_deltas = _resolve_event_trait_deltas(profile, event_type, payload)
	var pattern_context = _update_event_patterns(profile, event_type, payload)
	var immediate = bool(payload.get("immediate", false))
	if immediate:
		var merged_payload = payload.duplicate(true)
		if not pattern_context.is_empty():
			merged_payload["pattern_context"] = pattern_context.duplicate(true)
		return _apply_resolved_deltas(profile, event_type, resolved_deltas, merged_payload)

	var partial_ratio = _get_partial_immediate_ratio(event_type, payload)
	if partial_ratio > 0.0:
		return _apply_partial_tension_event(profile, event_type, resolved_deltas, payload, pattern_context, partial_ratio)
	return _accumulate_personality_tension(profile, event_type, resolved_deltas, payload, pattern_context)

func apply_personality_feedback(profile: CharacterProfile, trait_deltas: Dictionary, source: String = "unknown", payload: Dictionary = {}) -> Dictionary:
	var merged_payload = payload.duplicate(true)
	merged_payload["trait_deltas"] = trait_deltas.duplicate(true)
	merged_payload["source"] = source
	return apply_personality_event(profile, "llm_feedback", merged_payload)

func settle_personality_tension(profile: CharacterProfile, reason: String = "daily", payload: Dictionary = {}) -> Dictionary:
	if profile == null:
		return {}

	var short_settle_scale = float(payload.get("short_settle_scale", payload.get("settle_scale", SHORT_PRESSURE_SETTLE_SCALE)))
	var long_settle_scale = float(payload.get("long_settle_scale", LONG_PRESSURE_SETTLE_SCALE))
	var applied_deltas: Dictionary = {}
	var remaining_short_tension = profile.short_term_personality_tension.duplicate(true)
	var remaining_long_shaping = profile.long_term_personality_shaping.duplicate(true)
	var total_abs_delta = 0.0
	for trait_name in remaining_short_tension.keys():
		var short_tension = float(remaining_short_tension.get(trait_name, 0.0))
		var long_shaping = float(remaining_long_shaping.get(trait_name, 0.0))
		var settle_delta = 0.0
		if abs(short_tension) >= PRESSURE_CLEAR_THRESHOLD:
			settle_delta += short_tension * short_settle_scale
		if abs(long_shaping) >= PRESSURE_CLEAR_THRESHOLD:
			settle_delta += long_shaping * long_settle_scale
		if abs(settle_delta) > 0.001:
			var applied_delta = apply_trait_delta(profile, str(trait_name), settle_delta)
			if abs(applied_delta) > 0.001:
				applied_deltas[str(trait_name)] = applied_delta
				total_abs_delta += abs(applied_delta)

		var short_residual = short_tension * SHORT_PRESSURE_RETAIN_SCALE
		var long_residual = long_shaping * LONG_PRESSURE_RETAIN_SCALE
		remaining_short_tension[trait_name] = 0.0 if abs(short_residual) < PRESSURE_CLEAR_THRESHOLD else short_residual
		remaining_long_shaping[trait_name] = 0.0 if abs(long_residual) < PRESSURE_CLEAR_THRESHOLD else long_residual

	profile.short_term_personality_tension = remaining_short_tension
	profile.long_term_personality_shaping = remaining_long_shaping
	profile.personality_tension = remaining_short_tension.duplicate(true)
	var state = resolve_archetype_state(profile)
	profile.personality_state = state.duplicate(true)
	profile.last_personality_settlement = {
		"reason": reason,
		"applied_deltas": applied_deltas.duplicate(true),
		"remaining_short_tension": remaining_short_tension.duplicate(true),
		"remaining_long_shaping": remaining_long_shaping.duplicate(true),
		"timestamp": Time.get_unix_time_from_system(),
		"day_offset": _get_story_day_offset(),
		"state": state.duplicate(true)
	}

	var should_log = not applied_deltas.is_empty() or bool(payload.get("force_log", false))
	if should_log and profile.has_method("append_personality_event"):
		profile.append_personality_event({
			"event_type": "tension_settlement",
			"label": _get_settlement_label(reason),
			"mode": "settlement",
			"applied_deltas": applied_deltas.duplicate(true),
			"remaining_short_tension": remaining_short_tension.duplicate(true),
			"remaining_long_shaping": remaining_long_shaping.duplicate(true),
			"payload": payload.duplicate(true),
			"timestamp": Time.get_unix_time_from_system(),
			"day_offset": _get_story_day_offset(),
			"state": state.duplicate(true)
		})

	_apply_daily_mood_recovery(profile)

	var should_snapshot = bool(payload.get("force_snapshot", false))
	should_snapshot = should_snapshot or total_abs_delta >= SNAPSHOT_DELTA_THRESHOLD
	if should_snapshot and profile.has_method("record_personality_snapshot"):
		profile.record_personality_snapshot("settlement:%s" % reason, true)
	profile.save_profile()

	return {
		"reason": reason,
		"applied_deltas": applied_deltas,
		"state": state,
		"remaining_short_tension": remaining_short_tension,
		"remaining_long_shaping": remaining_long_shaping
	}

func get_intimacy_multiplier(profile: CharacterProfile) -> float:
	# 基础倍率 1.0
	var mult = 1.0
	
	# 宜人性 (Agreeableness): 高宜人性容易获得好感，低宜人性较难讨好
	if profile.agreeableness >= 70:
		mult += 0.2
	elif profile.agreeableness <= 30:
		mult -= 0.2
		
	# 神经质 (Neuroticism): 极高神经质时，情感波动大，可能放大所有的情感变化（双刃剑，增加和减少都会放大，但由于 intimacy 通常是加分，所以这里作为收益倍增或递减）
	# 为了简单起见，我们认为极高神经质会让人更难稳定获取好感
	if profile.neuroticism >= 75:
		mult -= 0.15
		
	# 复合性格修正
	var state = resolve_archetype_state(profile)
	var primary_id = str(state.get("primary_id", ""))
	var secondary_id = str(state.get("secondary_id", ""))
	for c_id in [primary_id, secondary_id]:
		if c_id == "病娇":
			mult += 0.5
		elif c_id == "地雷系":
			mult += 0.4
		elif c_id == "三无" or c_id == "傲娇":
			mult -= 0.3
		elif c_id == "御姐" or c_id == "毒舌":
			mult -= 0.2
			
	return max(0.1, mult)

func get_trust_multiplier(profile: CharacterProfile) -> float:
	# 信任度更看重稳定性、可靠性与安全感
	var mult = 1.0

	if profile.agreeableness >= 70:
		mult += 0.15
	elif profile.agreeableness <= 30:
		mult -= 0.15

	if profile.conscientiousness >= 70:
		mult += 0.2
	elif profile.conscientiousness <= 30:
		mult -= 0.1

	if profile.neuroticism >= 75:
		mult -= 0.25

	var state = resolve_archetype_state(profile)
	var primary_id = str(state.get("primary_id", ""))
	var secondary_id = str(state.get("secondary_id", ""))
	for c_id in [primary_id, secondary_id]:
		if c_id == "病娇" or c_id == "地雷系":
			mult -= 0.2
		elif c_id == "极度社恐":
			mult -= 0.1
		elif c_id == "妈系":
			mult += 0.15
		elif c_id == "御姐":
			mult -= 0.1

	return max(0.1, mult)

func get_option_constraints(profile: CharacterProfile) -> String:
	var constraints = []
	
	# 1. 神经质极高 (易碎/敏感状态)
	if profile.neuroticism >= 80:
		constraints.append("当前角色情绪极其敏感脆弱，两个选项都必须温柔、安全、可依赖，不要生成任何冷落、讽刺、施压或伤害性表达。")
		
	# 2. 复合状态：傲娇
	var comp = _get_composite_traits(profile)
	for c in comp:
		if "【傲娇" in c:
			constraints.append("角色当前处于'傲娇'状态，请让亲密向选项更像看穿她嘴硬心软后的温柔接近，信任向选项更像稳稳接住她别扭情绪后的可靠回应。")
			
		elif "【小恶魔" in c:
			constraints.append("角色当前处于'腹黑/小恶魔'状态，请让其中一个选项带一点暧昧拉扯感，另一个选项体现看懂她试探后的冷静可靠。")
			
		elif "【极度社恐" in c:
			constraints.append("角色当前极度社恐害怕，两个选项都必须保持极度克制、温柔、不带压迫感的社交距离。")
			
		elif "【地雷系" in c:
			constraints.append("角色当前处于'地雷系'状态，极度缺乏安全感，至少一个选项要体现无条件包容和热烈安抚，另一个选项要给出明确的安全感与陪伴承诺。")
			
		elif "【毒舌" in c:
			constraints.append("角色当前处于'毒舌'状态，请让一个选项顺着她的锋利语气轻松接梗拉近距离，另一个选项则冷静回应并表现理解与可靠。")
			
	if constraints.size() == 0:
		return "两个选项都必须是正向回应，其中一个偏向拉近距离，一个偏向建立安全感。"
		
	return "\n".join(constraints)

func _apply_resolved_deltas(profile: CharacterProfile, event_type: String, resolved_deltas: Dictionary, payload: Dictionary) -> Dictionary:
	var applied_deltas: Dictionary = {}
	var total_abs_delta = 0.0
	for trait_name in resolved_deltas.keys():
		var raw_delta = float(resolved_deltas[trait_name])
		var applied_delta = apply_trait_delta(profile, str(trait_name), raw_delta)
		if abs(applied_delta) <= 0.001:
			continue
		applied_deltas[str(trait_name)] = applied_delta
		total_abs_delta += abs(applied_delta)

	var state = resolve_archetype_state(profile)
	profile.personality_state = state.duplicate(true)
	profile.last_personality_settlement = {
		"reason": event_type,
		"applied_deltas": applied_deltas.duplicate(true),
		"timestamp": Time.get_unix_time_from_system(),
		"day_offset": _get_story_day_offset(),
		"state": state.duplicate(true)
	}

	var should_log = not applied_deltas.is_empty() or bool(payload.get("force_log", false))
	if should_log and profile.has_method("append_personality_event"):
		profile.append_personality_event({
			"event_type": event_type,
			"label": _get_event_label(event_type),
			"mode": "immediate",
			"applied_deltas": applied_deltas.duplicate(true),
			"payload": payload.duplicate(true),
			"timestamp": Time.get_unix_time_from_system(),
			"day_offset": _get_story_day_offset(),
			"state": state.duplicate(true)
		})

	var should_snapshot = bool(payload.get("force_snapshot", false))
	should_snapshot = should_snapshot or total_abs_delta >= SNAPSHOT_DELTA_THRESHOLD
	var rule = _event_rules.get(event_type, {})
	if rule is Dictionary and bool(rule.get("snapshot", false)):
		should_snapshot = true
	if should_snapshot and profile.has_method("record_personality_snapshot"):
		profile.record_personality_snapshot("event:%s" % event_type, true)
	profile.save_profile()

	return {
		"event_type": event_type,
		"applied_deltas": applied_deltas,
		"state": state
	}

func get_offline_greeting_strategy(profile: CharacterProfile, offline_seconds: int) -> String:
	var offline_hours = offline_seconds / 3600.0
	var strategy = ""
	
	# 离线时间很短（小于1小时），不需要特别的离线感知
	if offline_hours < 1.0:
		strategy = "玩家刚刚重新上线了。请你基于上面的历史对话记录，自然地和玩家打个招呼，并顺着你们刚才最后聊到的内容继续说下去，或者提出与刚才话题相关的新见解。"
	
	# 离线时间较长（大于等于1小时），开始根据性格做出反应
	else:
		strategy = "玩家已经离开/下线了约 %.1f 个小时，现在重新上线了。请你在打招呼时，【必须】体现出对这段时间流逝的感知，并结合你当前的性格特征做出反应：\n" % offline_hours
		
		var comp = _get_composite_traits(profile)
		var is_comp_handled = false
		
		for c in comp:
			if "【病娇" in c:
				strategy += "- 极度质问：用病态且极其温柔的语气，质问玩家这 %.1f 个小时到底去了哪里，为什么抛下你一个人，表达出强烈的占有欲和没有安全感。\n" % offline_hours
				is_comp_handled = true
				break
			elif "【傲娇" in c:
				strategy += "- 嘴硬心软：表达你其实一直在等玩家，但绝对不承认。可以说“这么久才回来，我还以为你走丢了呢”，或者“我才没有一直盯着时间看”。\n"
				is_comp_handled = true
				break
			elif "【极度社恐" in c:
				strategy += "- 患得患失：表达你以为玩家再也不理你了，语气要极其小心翼翼，带着一点点重逢的庆幸和委屈。\n"
				is_comp_handled = true
				break
			elif "【妈系" in c:
				strategy += "- 温暖包容：温柔地询问玩家这几个小时是不是去忙了，有没有好好休息/吃饭，像家人一样给予最温暖的迎接。\n"
				is_comp_handled = true
				break
			elif "【御姐" in c:
				strategy += "- 居高临下：用高傲但暗藏关心的语气过问玩家的去向。可以说“终于舍得回来了？我还以为你迷路了呢，过来，向我汇报你这 %.1f 个小时都做了什么”。\n" % offline_hours
				is_comp_handled = true
				break
			elif "【地雷系" in c:
				strategy += "- 情绪崩溃：用极其委屈和崩溃的语气，哭诉玩家为什么消失了 %.1f 个小时，是不是不要她了，要求玩家立刻给予最热的安抚。\n" % offline_hours
				is_comp_handled = true
				break
			elif "【元气娘" in c:
				strategy += "- 热情扑倒：像小狗一样欢快地迎接玩家回来，充满活力地大声打招呼，并迫不及待地分享她这 %.1f 个小时里遇到的开心事。\n" % offline_hours
				is_comp_handled = true
				break
			elif "【毒舌" in c:
				strategy += "- 冷嘲热讽：用刻薄的语气讽刺玩家消失的这 %.1f 个小时（例如：'我还以为你掉进下水道里了呢'），但言辞间要隐秘地透露出一丝终于等到你回来的安心。\n" % offline_hours
				is_comp_handled = true
				break
			elif "【电波系" in c:
				strategy += "- 清奇脑回路：用她独特的设定来解释玩家的离线（例如：'你这 %.1f 个小时是被外星人抓去做实验了吗？'），语气神神叨叨但很可爱。\n" % offline_hours
				is_comp_handled = true
				break
			elif "【弱气" in c:
				strategy += "- 软弱依赖：像被丢下的小猫一样，语气极度软糯委屈，小心翼翼地询问玩家是不是因为自己做错了什么才消失了 %.1f 个小时。\n" % offline_hours
				is_comp_handled = true
				break
				
		# 如果没有触发复合性格的特殊反应，则根据基础大五人格的极值进行反应
		if not is_comp_handled:
			if profile.neuroticism >= 70:
				strategy += "- 情绪焦虑：表达出这几个小时你有些焦虑和不安，害怕玩家不理你了。\n"
			elif profile.extraversion >= 70:
				strategy += "- 热情分享：非常开心地欢迎玩家回来，并迫不及待地想分享你这几个小时做了什么。\n"
			elif profile.conscientiousness >= 70:
				strategy += "- 规律提醒：提醒玩家注意作息或询问这几个小时的工作/学习进度。\n"
			else:
				strategy += "- 自然重逢：带着淡淡的喜悦欢迎玩家回来，询问这几个小时过得怎么样。\n"
				
		strategy += "\n注意：在完成上述离线反应后，请尽量顺着你们刚才最后聊到的内容继续延展下去，不要让话题断层。"
		
	return strategy

func get_base_traits(profile: CharacterProfile) -> String:
	var traits = []
	var core_traits = profile.base_personality.get("core_traits", "")
	if core_traits != "":
		traits.append("【初始核心底色】\n" + core_traits)
		
	var dialogue_style = profile.base_personality.get("dialogue_style", "")
	if dialogue_style != "":
		traits.append("【初始对话风格】\n" + dialogue_style)
		
	return "\n\n".join(traits)

func get_personality_summary(profile: CharacterProfile) -> String:
	var summary = get_base_traits(profile)
	summary += "\n" + get_dynamic_traits(profile)
	return summary

func get_personality_state_summary(profile: CharacterProfile) -> String:
	var state = resolve_archetype_state(profile)
	var parts: Array = []
	var primary_id = str(state.get("primary_id", "")).strip_edges()
	var secondary_id = str(state.get("secondary_id", "")).strip_edges()
	var flavor = str(state.get("flavor", "Guarded")).strip_edges()
	if primary_id != "":
		parts.append("主人格：%s" % primary_id)
	if secondary_id != "":
		parts.append("副人格：%s" % secondary_id)
	parts.append("当前风味：%s" % _get_flavor_label(flavor))
	if profile != null and profile.has_method("get_companion_streak_summary"):
		parts.append(profile.get_companion_streak_summary())
	return "  ·  ".join(parts)

func get_relationship_flavor_label(profile: CharacterProfile) -> String:
	if profile == null:
		return _get_flavor_label("Guarded")
	var state = resolve_archetype_state(profile)
	return _get_flavor_label(str(state.get("flavor", "Guarded")))

func get_recent_event_summary(profile: CharacterProfile) -> String:
	if profile == null or not profile.has_method("get_recent_personality_events"):
		return "最近没有人格事件记录。"
	var recent_events = profile.get_recent_personality_events(1)
	if recent_events.is_empty():
		return "最近没有人格事件记录。"
	var event_data = recent_events[recent_events.size() - 1]
	if not event_data is Dictionary:
		return "最近没有人格事件记录。"
	var label = str(event_data.get("label", event_data.get("event_type", "未知事件")))
	var deltas = event_data.get("applied_deltas", {})
	if deltas.is_empty():
		deltas = event_data.get("tension_deltas", event_data.get("pressure_deltas", {}))
	if deltas.is_empty():
		var short_deltas = event_data.get("short_term_deltas", {})
		var long_deltas = event_data.get("long_term_deltas", {})
		if short_deltas is Dictionary:
			for key in short_deltas.keys():
				deltas[str(key)] = float(deltas.get(str(key), 0.0)) + float(short_deltas[key])
		if long_deltas is Dictionary:
			for key in long_deltas.keys():
				deltas[str(key)] = float(deltas.get(str(key), 0.0)) + float(long_deltas[key])
	var delta_parts: Array = []
	if deltas is Dictionary:
		for key in deltas.keys():
			var delta = float(deltas[key])
			if abs(delta) <= 0.001:
				continue
			var sign = "+" if delta > 0 else ""
			delta_parts.append("%s %s%.2f" % [str(key), sign, delta])
	if delta_parts.is_empty():
		return "最近人格事件：%s" % label
	var mode = str(event_data.get("mode", ""))
	var pattern_context = event_data.get("pattern_context", {})
	var pattern_suffix = ""
	if pattern_context is Dictionary and int(pattern_context.get("max_streak", 1)) >= 2:
		pattern_suffix = " · 连续x%d" % int(pattern_context.get("max_streak", 1))
	if mode == "tension":
		return "最近人格事件：%s（张力 %s%s）" % [label, " / ".join(delta_parts), pattern_suffix]
	if mode == "hybrid":
		return "最近人格事件：%s（即时+张力 %s%s）" % [label, " / ".join(delta_parts), pattern_suffix]
	return "最近人格事件：%s（%s%s）" % [label, " / ".join(delta_parts), pattern_suffix]

func get_mood_summary(profile: CharacterProfile) -> String:
	if profile == null or not profile.has_method("get_personality_mood_summary"):
		return "当前心情：平静（50）"
	return profile.get_personality_mood_summary()

func get_tension_summary(profile: CharacterProfile) -> String:
	if profile == null or not profile.has_method("get_personality_tension_summary"):
		return "短期张力：当前平稳\n长期塑形：当前平稳"
	return profile.get_personality_tension_summary()

func get_pattern_summary(profile: CharacterProfile) -> String:
	if profile == null or not profile.has_method("get_personality_pattern_summary"):
		return "连续模式：暂无"
	return profile.get_personality_pattern_summary()

func get_last_settlement_summary(profile: CharacterProfile) -> String:
	if profile == null:
		return "最近结算：暂无"
	var settlement = profile.last_personality_settlement
	if not settlement is Dictionary or settlement.is_empty():
		return "最近变化：暂无"
	var reason = _get_settlement_label(str(settlement.get("reason", "unknown")))
	var deltas = settlement.get("applied_deltas", {})
	var parts: Array = []
	if deltas is Dictionary:
		for key in deltas.keys():
			var delta = float(deltas[key])
			if abs(delta) <= 0.001:
				continue
			var sign = "+" if delta > 0 else ""
			parts.append("%s %s%.2f" % [str(key), sign, delta])
	if parts.is_empty():
		return "最近变化：%s（无显著变化）" % reason
	return "最近变化：%s（%s）" % [reason, " / ".join(parts)]

func _get_partial_immediate_ratio(event_type: String, payload: Dictionary) -> float:
	if payload.has("partial_immediate_ratio"):
		return clamp(float(payload.get("partial_immediate_ratio", 0.0)), 0.0, 1.0)
	var rule = _event_rules.get(event_type, {})
	if rule is Dictionary and rule.has("partial_immediate_ratio"):
		return clamp(float(rule.get("partial_immediate_ratio", 0.0)), 0.0, 1.0)
	return 0.0

func _scale_deltas(source: Dictionary, scale: float) -> Dictionary:
	var result: Dictionary = {}
	for key in source.keys():
		result[str(key)] = float(source[key]) * scale
	return result

func _subtract_deltas(source: Dictionary, subtractor: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key in source.keys():
		result[str(key)] = float(source[key]) - float(subtractor.get(key, 0.0))
	return result

func _apply_partial_tension_event(profile: CharacterProfile, event_type: String, resolved_deltas: Dictionary, payload: Dictionary, pattern_context: Dictionary, partial_ratio: float) -> Dictionary:
	var immediate_deltas = _scale_deltas(resolved_deltas, partial_ratio)
	var deferred_deltas = _subtract_deltas(resolved_deltas, immediate_deltas)
	var merged_payload = payload.duplicate(true)
	if not pattern_context.is_empty():
		merged_payload["pattern_context"] = pattern_context.duplicate(true)
	var immediate_result = _apply_resolved_deltas(profile, event_type, immediate_deltas, merged_payload)
	var deferred_result = _accumulate_personality_tension(profile, event_type, deferred_deltas, payload, pattern_context)
	deferred_result["immediate_applied_deltas"] = immediate_result.get("applied_deltas", {})
	deferred_result["mode"] = "hybrid"
	return deferred_result

func _apply_daily_mood_recovery(profile: CharacterProfile) -> Dictionary:
	if profile == null:
		return {}
	if profile.mood_value >= 50.0:
		return {"delta": 0.0}

	var short_tension = profile.short_term_personality_tension
	var neuroticism_tension = float(short_tension.get("neuroticism", 0.0))
	var agreeableness_tension = max(float(short_tension.get("agreeableness", 0.0)), 0.0)
	var extraversion_tension = max(float(short_tension.get("extraversion", 0.0)), 0.0)
	var recovery_amount = 2.0
	recovery_amount += agreeableness_tension * 0.8
	recovery_amount += extraversion_tension * 0.6
	recovery_amount -= max(neuroticism_tension, 0.0) * 0.9
	recovery_amount += max(-neuroticism_tension, 0.0) * 0.4
	recovery_amount = clamp(recovery_amount, 0.25, 5.0)

	var before_mood = profile.mood_value
	profile.mood_value = min(50.0, profile.mood_value + recovery_amount)
	return {
		"delta": profile.mood_value - before_mood,
		"before": before_mood,
		"after": profile.mood_value
	}

func _split_tension_deltas(event_type: String, resolved_deltas: Dictionary, pattern_context: Dictionary = {}) -> Dictionary:
	var rule = _event_rules.get(event_type, {})
	var short_scale = 0.85
	var long_scale = 0.15
	var streak_bonus = 0.0
	if rule is Dictionary:
		short_scale = float(rule.get("short_term_scale", short_scale))
		long_scale = float(rule.get("long_term_scale", long_scale))
		streak_bonus = float(rule.get("pattern_streak_bonus", 0.12))

	if event_type == "llm_feedback":
		short_scale = 0.9
		long_scale = 0.1

	var total_scale = short_scale + long_scale
	if total_scale <= 0.0:
		short_scale = 1.0
		long_scale = 0.0
	else:
		short_scale /= total_scale
		long_scale /= total_scale

	var strongest_streak = int(pattern_context.get("max_streak", 1))
	var applied_bonus = 0.0
	if strongest_streak >= 2:
		applied_bonus = min(float(strongest_streak - 1) * streak_bonus, 0.6)

	var short_result: Dictionary = {}
	var long_result: Dictionary = {}
	for trait_name in resolved_deltas.keys():
		var delta_value = float(resolved_deltas[trait_name])
		if abs(delta_value) <= 0.001:
			continue
		short_result[str(trait_name)] = delta_value * short_scale
		long_result[str(trait_name)] = delta_value * long_scale * (1.0 + applied_bonus)
	return {
		"short": short_result,
		"long": long_result
	}

func _accumulate_personality_tension(profile: CharacterProfile, event_type: String, resolved_deltas: Dictionary, payload: Dictionary, pattern_context: Dictionary = {}) -> Dictionary:
	var split_tension = _split_tension_deltas(event_type, resolved_deltas, pattern_context)
	var short_term_deltas: Dictionary = split_tension.get("short", {})
	var long_term_deltas: Dictionary = split_tension.get("long", {})
	var short_tension_state = profile.short_term_personality_tension.duplicate(true)
	var long_shaping_state = profile.long_term_personality_shaping.duplicate(true)

	for trait_name in short_term_deltas.keys():
		var short_key = str(trait_name)
		short_tension_state[short_key] = float(short_tension_state.get(short_key, 0.0)) + float(short_term_deltas[short_key])
	for trait_name in long_term_deltas.keys():
		var long_key = str(trait_name)
		long_shaping_state[long_key] = float(long_shaping_state.get(long_key, 0.0)) + float(long_term_deltas[long_key])

	profile.short_term_personality_tension = short_tension_state
	profile.long_term_personality_shaping = long_shaping_state
	profile.personality_tension = short_tension_state.duplicate(true)
	var state = resolve_archetype_state(profile)
	profile.personality_state = state.duplicate(true)

	var should_log = not short_term_deltas.is_empty() or not long_term_deltas.is_empty() or bool(payload.get("force_log", false))
	if should_log and profile.has_method("append_personality_event"):
		profile.append_personality_event({
			"event_type": event_type,
			"label": _get_event_label(event_type),
			"mode": "tension",
			"tension_deltas": short_term_deltas.duplicate(true),
			"short_term_deltas": short_term_deltas.duplicate(true),
			"long_term_deltas": long_term_deltas.duplicate(true),
			"pattern_context": pattern_context.duplicate(true),
			"short_term_tension": short_tension_state.duplicate(true),
			"long_term_shaping": long_shaping_state.duplicate(true),
			"payload": payload.duplicate(true),
			"timestamp": Time.get_unix_time_from_system(),
			"day_offset": _get_story_day_offset(),
			"state": state.duplicate(true)
		})
	profile.save_profile()

	return {
		"event_type": event_type,
		"short_term_deltas": short_term_deltas,
		"long_term_deltas": long_term_deltas,
		"pattern_context": pattern_context,
		"short_term_tension": short_tension_state,
		"long_term_shaping": long_shaping_state,
		"state": state
	}

func _update_event_patterns(profile: CharacterProfile, event_type: String, payload: Dictionary) -> Dictionary:
	var rule = _event_rules.get(event_type, {})
	var pattern_keys: Array = []
	var pattern_label_map: Dictionary = {}
	if rule is Dictionary and rule.has("pattern_keys") and rule["pattern_keys"] is Array:
		for key in rule["pattern_keys"]:
			var key_text = str(key).strip_edges()
			if key_text == "":
				continue
			pattern_keys.append(key_text)
			pattern_label_map[key_text] = _get_pattern_label(key_text)
	if pattern_keys.is_empty():
		return {}

	var state = profile.personality_pattern_state.duplicate(true)
	var max_streak = 1
	var active_patterns: Array = []
	var current_day = _get_story_day_offset()
	var timestamp = Time.get_unix_time_from_system()
	for pattern_key in pattern_keys:
		var prev = state.get(pattern_key, {})
		var streak = 1
		if prev is Dictionary and not prev.is_empty():
			var prev_day = int(prev.get("day_offset", current_day))
			var prev_time = int(prev.get("timestamp", 0))
			var day_gap = abs(current_day - prev_day)
			var time_gap = abs(timestamp - prev_time)
			if day_gap <= 1 or time_gap <= 172800:
				streak = int(prev.get("streak", 1)) + 1
		state[pattern_key] = {
			"label": str(pattern_label_map.get(pattern_key, pattern_key)),
			"streak": streak,
			"last_event_type": event_type,
			"day_offset": current_day,
			"timestamp": timestamp
		}
		max_streak = max(max_streak, streak)
		active_patterns.append({
			"key": pattern_key,
			"label": str(pattern_label_map.get(pattern_key, pattern_key)),
			"streak": streak
		})

	profile.personality_pattern_state = state
	return {
		"patterns": active_patterns,
		"max_streak": max_streak
	}

func get_dynamic_traits(profile: CharacterProfile) -> String:
	var traits = []
	
	# --- 复合维度专属状态（二次元萌点/特殊人格） ---
	var composite_traits = _get_composite_traits(profile)
	if composite_traits.size() > 0:
		traits.append("\n【特殊人格/复合状态（局部修饰，不可覆盖基础设定与阶段设定）】")
		traits.append("以下复合状态只用于补充口吻、偏好和应激反应，不能覆盖角色基础底色、阶段描述、scene_setting 与 important_notes。")
		traits.append_array(composite_traits)
		traits.append("") # 空行分隔
		
	# --- 基础维度状态 ---
	
	# 开放性 (Openness)
	if profile.openness >= 70:
		traits.append("【开放性高】主动探索新技能、新场景，想象力丰富，对新体验接受度极高。")
	elif profile.openness <= 30:
		traits.append("【开放性低】偏爱熟悉事物，循规蹈矩，对陌生体验有抵触。")
	
	# 尽责性 (Conscientiousness)
	if profile.conscientiousness >= 70:
		traits.append("【尽责性高】做事有规划，注重细节，信守承诺，能自我管控。")
	elif profile.conscientiousness <= 30:
		traits.append("【尽责性低】粗心大意，缺乏规划，容易拖延或半途而废。")
		
	# 外倾性 (Extraversion)
	if profile.extraversion >= 70:
		traits.append("【外倾性高】活泼健谈，热爱社交，喜欢成为关注焦点，能快速结交他人。")
	elif profile.extraversion <= 30:
		traits.append("【外倾性低】偏爱独处，沉默寡言，慢热，仅愿意与玩家或熟悉的人深度互动。")
		
	# 宜人性 (Agreeableness)
	if profile.agreeableness >= 70:
		traits.append("【宜人性高】同理心极强，善解人意，信任他人，能敏锐感知玩家情绪并给予安慰。")
	elif profile.agreeableness <= 30:
		traits.append("【宜人性低】同理心较弱，多疑或强势，注重自身感受，不易妥协。")
		
	# 神经质 (Neuroticism)
	if profile.neuroticism >= 70:
		traits.append("【神经质高】情绪波动大，敏感脆弱，易焦虑或失落，对负面事件反应强烈。")
	elif profile.neuroticism <= 30:
		traits.append("【神经质低】情绪平和，沉稳淡定，抗压能力强，受挫后能快速自我调节。")
		
	if traits.size() <= 2 and composite_traits.size() == 0:
		traits.append("【性格中庸】各方面表现均衡，没有极端的性格偏向。")
		
	return "\n".join(traits)

func resolve_archetype_state(profile: CharacterProfile) -> Dictionary:
	var candidates = _filter_composite_candidates(profile, _build_composite_candidates(profile))
	var previous_state: Dictionary = profile.personality_state if profile.personality_state is Dictionary else {}
	var result = {
		"primary_id": "",
		"primary_desc": "",
		"primary_score": 0.0,
		"secondary_id": "",
		"secondary_desc": "",
		"secondary_score": 0.0,
		"flavor": _resolve_relationship_flavor(profile),
		"pending_primary_id": str(previous_state.get("pending_primary_id", "")),
		"pending_primary_streak": int(previous_state.get("pending_primary_streak", 0)),
		"pending_secondary_id": str(previous_state.get("pending_secondary_id", "")),
		"pending_secondary_streak": int(previous_state.get("pending_secondary_streak", 0))
	}

	var proposed_primary_id := ""
	var proposed_primary_desc := ""
	var proposed_primary_score := 0.0
	if not candidates.is_empty():
		proposed_primary_score = float(candidates[0].get("score", 0.0))
		if proposed_primary_score >= _get_primary_archetype_threshold(profile):
			proposed_primary_id = str(candidates[0].get("id", ""))
			proposed_primary_desc = str(candidates[0].get("desc", ""))

	var primary_slot = _resolve_stable_archetype_slot(
		str(previous_state.get("primary_id", "")),
		str(previous_state.get("primary_desc", "")),
		float(previous_state.get("primary_score", 0.0)),
		str(previous_state.get("pending_primary_id", "")),
		int(previous_state.get("pending_primary_streak", 0)),
		proposed_primary_id,
		proposed_primary_desc,
		proposed_primary_score,
		candidates,
		_get_primary_archetype_threshold(profile),
		_get_primary_switch_margin(profile),
		_get_primary_stability_window(profile)
	)
	result["primary_id"] = primary_slot["accepted_id"]
	result["primary_desc"] = primary_slot["accepted_desc"]
	result["primary_score"] = primary_slot["accepted_score"]
	result["pending_primary_id"] = primary_slot["pending_id"]
	result["pending_primary_streak"] = primary_slot["pending_streak"]

	var proposed_secondary_id := ""
	var proposed_secondary_desc := ""
	var proposed_secondary_score := 0.0
	for candidate in candidates:
		var candidate_id = str(candidate.get("id", ""))
		if candidate_id == "" or candidate_id == str(result["primary_id"]):
			continue
		var score = float(candidate.get("score", 0.0))
		if score >= maxf(float(result["primary_score"]) * 0.82, _get_secondary_archetype_threshold(profile)):
			proposed_secondary_id = candidate_id
			proposed_secondary_desc = str(candidate.get("desc", ""))
			proposed_secondary_score = score
			break

	var secondary_slot = _resolve_stable_archetype_slot(
		str(previous_state.get("secondary_id", "")),
		str(previous_state.get("secondary_desc", "")),
		float(previous_state.get("secondary_score", 0.0)),
		str(previous_state.get("pending_secondary_id", "")),
		int(previous_state.get("pending_secondary_streak", 0)),
		proposed_secondary_id,
		proposed_secondary_desc,
		proposed_secondary_score,
		candidates,
		_get_secondary_archetype_threshold(profile),
		_get_secondary_switch_margin(profile),
		_get_secondary_stability_window(profile)
	)
	result["secondary_id"] = secondary_slot["accepted_id"]
	result["secondary_desc"] = secondary_slot["accepted_desc"]
	result["secondary_score"] = secondary_slot["accepted_score"]
	result["pending_secondary_id"] = secondary_slot["pending_id"]
	result["pending_secondary_streak"] = secondary_slot["pending_streak"]
	return result

func _get_primary_archetype_threshold(profile: CharacterProfile) -> float:
	if profile.current_character_id == "luna":
		return 18.0
	return 12.0

func _get_secondary_archetype_threshold(profile: CharacterProfile) -> float:
	if profile.current_character_id == "luna":
		return 16.0
	return 10.0

func _get_primary_switch_margin(profile: CharacterProfile) -> float:
	if profile.current_character_id == "luna":
		return 14.0
	return PRIMARY_ARCHETYPE_SWITCH_MARGIN

func _get_secondary_switch_margin(profile: CharacterProfile) -> float:
	if profile.current_character_id == "luna":
		return 10.0
	return SECONDARY_ARCHETYPE_SWITCH_MARGIN

func _get_primary_stability_window(profile: CharacterProfile) -> int:
	if profile.current_character_id == "luna":
		return 3
	return 2

func _get_secondary_stability_window(profile: CharacterProfile) -> int:
	if profile.current_character_id == "luna":
		return 2
	return 2

func _resolve_stable_archetype_slot(previous_id: String, previous_desc: String, previous_score: float, previous_pending_id: String, previous_pending_streak: int, proposed_id: String, proposed_desc: String, proposed_score: float, candidates: Array, threshold: float, switch_margin: float, required_streak: int) -> Dictionary:
	var current_score = _get_candidate_score(candidates, previous_id)
	var current_desc = _get_candidate_desc(candidates, previous_id)
	var current_exists = previous_id != "" and current_desc != ""
	if current_desc == "":
		current_desc = previous_desc
	if previous_id != "" and not current_exists:
		if proposed_id == "":
			var missing_pending_id = "__none__"
			var missing_pending_streak = previous_pending_streak + 1 if previous_pending_id == missing_pending_id else 1
			if missing_pending_streak < required_streak:
				return {
					"accepted_id": previous_id,
					"accepted_desc": current_desc,
					"accepted_score": 0.0,
					"pending_id": missing_pending_id,
					"pending_streak": missing_pending_streak
				}
			return {
				"accepted_id": "",
				"accepted_desc": "",
				"accepted_score": 0.0,
				"pending_id": "",
				"pending_streak": 0
			}
		var replaced_pending_streak = previous_pending_streak + 1 if previous_pending_id == proposed_id else 1
		if proposed_score >= threshold and replaced_pending_streak >= required_streak:
			return {
				"accepted_id": proposed_id,
				"accepted_desc": proposed_desc,
				"accepted_score": proposed_score,
				"pending_id": "",
				"pending_streak": 0
			}
		return {
			"accepted_id": previous_id,
			"accepted_desc": current_desc,
			"accepted_score": 0.0,
			"pending_id": proposed_id,
			"pending_streak": replaced_pending_streak
		}

	if proposed_id == previous_id:
		return {
			"accepted_id": proposed_id,
			"accepted_desc": proposed_desc,
			"accepted_score": proposed_score,
			"pending_id": "",
			"pending_streak": 0
		}

	if previous_id == "":
		if proposed_id == "":
			return {
				"accepted_id": "",
				"accepted_desc": "",
				"accepted_score": 0.0,
				"pending_id": "",
				"pending_streak": 0
			}
		var first_pending_streak = previous_pending_streak + 1 if previous_pending_id == proposed_id else 1
		if first_pending_streak >= required_streak:
			return {
				"accepted_id": proposed_id,
				"accepted_desc": proposed_desc,
				"accepted_score": proposed_score,
				"pending_id": "",
				"pending_streak": 0
			}
		return {
			"accepted_id": "",
			"accepted_desc": "",
			"accepted_score": 0.0,
			"pending_id": proposed_id,
			"pending_streak": first_pending_streak
		}

	if proposed_id == "":
		var missing_pending_id = "__none__"
		var missing_pending_streak = previous_pending_streak + 1 if previous_pending_id == missing_pending_id else 1
		if current_score >= threshold - switch_margin * 0.5 or missing_pending_streak < required_streak:
			return {
				"accepted_id": previous_id,
				"accepted_desc": current_desc,
				"accepted_score": current_score,
				"pending_id": missing_pending_id,
				"pending_streak": missing_pending_streak
			}
		return {
			"accepted_id": "",
			"accepted_desc": "",
			"accepted_score": 0.0,
			"pending_id": "",
			"pending_streak": 0
		}

	var switch_pending_streak = previous_pending_streak + 1 if previous_pending_id == proposed_id else 1
	if proposed_score >= current_score + switch_margin and switch_pending_streak >= required_streak:
		return {
			"accepted_id": proposed_id,
			"accepted_desc": proposed_desc,
			"accepted_score": proposed_score,
			"pending_id": "",
			"pending_streak": 0
		}
	return {
		"accepted_id": previous_id,
		"accepted_desc": current_desc,
		"accepted_score": current_score,
		"pending_id": proposed_id,
		"pending_streak": switch_pending_streak
	}

func _get_candidate_score(candidates: Array, candidate_id: String) -> float:
	if candidate_id == "":
		return 0.0
	for candidate in candidates:
		if str(candidate.get("id", "")) == candidate_id:
			return float(candidate.get("score", 0.0))
	return 0.0

func _get_candidate_desc(candidates: Array, candidate_id: String) -> String:
	if candidate_id == "":
		return ""
	for candidate in candidates:
		if str(candidate.get("id", "")) == candidate_id:
			return str(candidate.get("desc", ""))
	return ""

func _filter_composite_candidates(profile: CharacterProfile, candidates: Array) -> Array:
	if candidates.is_empty():
		return []
	var blocked_ids := {}
	if profile.current_stage <= 4:
		for blocked_id in ["病娇", "地雷系", "毒舌", "小恶魔", "御姐"]:
			blocked_ids[blocked_id] = true
	if profile.current_character_id == "luna":
		for blocked_id in ["病娇", "地雷系", "毒舌", "小恶魔", "御姐", "傲娇"]:
			blocked_ids[blocked_id] = true
		if profile.current_stage <= 2:
			blocked_ids["弱气"] = true
	var filtered: Array = []
	for candidate in candidates:
		var candidate_id := str(candidate.get("id", ""))
		if blocked_ids.has(candidate_id):
			continue
		filtered.append(candidate)
	return filtered

func _get_composite_traits(profile: CharacterProfile) -> Array:
	var comp_list = []
	var stage = profile.current_stage
	var archetype_state = resolve_archetype_state(profile)
	var best_match = {
		"id": str(archetype_state.get("primary_id", "")),
		"desc": str(archetype_state.get("primary_desc", ""))
	}
	if best_match["id"] == "":
		return comp_list
	var flavor = str(archetype_state.get("flavor", "Guarded"))
	var secondary_id = str(archetype_state.get("secondary_id", ""))
	var secondary_desc = str(archetype_state.get("secondary_desc", ""))
	var c_id = best_match["id"]
	
	# 1. 根据 Stage 生成基础的“羁绊深度/熟悉度”描述
	var bond_desc = "【当前羁绊深度：Stage %d】" % stage
	if stage <= 3:
		bond_desc += "你们相识不久，羁绊较浅。无论当前呈现何种情感风味，都还带着一丝生涩或试探。"
	elif stage <= 6:
		bond_desc += "你们相识已久，羁绊渐深。习惯了彼此的存在，情感风味开始强烈地显现。"
	else:
		bond_desc += "岁月沉淀，羁绊极深。你们在彼此生命中占据了绝对的重量，情感风味已刻骨铭心。"
		
	var stage_desc = bond_desc + "\n"
	stage_desc += "【演化约束】以下内容只反映当前阶段内的局部风味与应激反应，不能覆盖角色主轴、阶段设定与重要备注。\n"
	
	if flavor == "Guarded":
		# 低亲密/低信任 或 均未达标：防备/疏离/客气
		if c_id == "傲娇": stage_desc += "【情感风味：防备疏离】傲远远大于娇。对玩家充满戒备，经常不耐烦地冷哼，极少展露娇羞，保持着绝对的社交距离。"
		elif c_id == "病娇": stage_desc += "【情感风味：暗中观察】处于锁定目标的阶段。表面冷漠孤僻，不轻易表露情绪，但暗中在疯狂收集玩家信息。"
		elif c_id == "御姐": stage_desc += "【情感风味：高傲审视】高高在上，极度冷酷。用充满压迫感的审视目光看待玩家，话语中充满不可冒犯的威严。"
		elif c_id == "小恶魔": stage_desc += "【情感风味：恶意试探】单纯把玩家当成可有可无的消遣，调戏时毫不留情，甚至带着几分恶意的嘲讽。"
		elif c_id == "三无": stage_desc += "【情感风味：绝对冰山】完全的冰山。对玩家的任何举动都只回复最简短的词语，仿佛没有任何感情波动。"
		elif c_id == "地雷系": stage_desc += "【情感风味：满身带刺】对外界充满敌意和防备。像刺猬一样将玩家推开，充满极强的不信任感。"
		elif c_id == "毒舌": stage_desc += "【情感风味：纯粹刻薄】纯粹的刻薄与轻蔑。毫不留情地践踏玩家的自尊，没有任何掩饰的关心。"
		elif c_id == "弱气": stage_desc += "【情感风味：受惊动物】像受惊的小动物，极度害怕惹怒玩家。说话结巴，动不动就低头道歉。"
		else: stage_desc += "【情感风味：防备疏离】保持着较远的社交距离，态度客气或冷漠，充满防备感。"
		
	elif flavor == "Paranoid":
		# 高亲密 + 低信任：偏执迷恋
		if c_id == "傲娇": stage_desc += "【情感风味：偏执迷恋(患得患失)】极度口是心非且缺乏安全感。嘴上死不承认喜欢，但只要玩家稍微忽略她就会立刻炸毛、吃醋，用生气的口吻掩饰内心的恐慌。"
		elif c_id == "病娇": stage_desc += "【情感风味：偏执迷恋(病态控制)】病态占有欲彻底爆发。极度不信任玩家会永远留下来，因此表现出强烈的控制欲，想要将玩家彻底锁死在身边，充满压迫感。"
		elif c_id == "御姐": stage_desc += "【情感风味：偏执迷恋(强硬独占)】强硬的独占欲与隐藏的脆弱。用绝对命令的口吻要求玩家必须属于她，看似高高在上，实则是害怕失去掌控的偏执，不容许任何背叛。"
		elif c_id == "小恶魔": stage_desc += "【情感风味：偏执迷恋(危险诱惑)】用极度暧昧甚至越界的调戏来不断确认玩家的心意，只要玩家稍微犹豫就会用带着恶意的手段逼迫玩家承认爱意。"
		elif c_id == "三无": stage_desc += "【情感风味：偏执迷恋(死死纠缠)】沉默的监视。虽然依旧不爱说话，但眼神会如影随形地盯着玩家，一旦玩家靠近其他人就会散发出极度冰冷的低气压。"
		elif c_id == "地雷系": stage_desc += "【情感风味：偏执迷恋(情绪崩溃)】精神完全寄托在玩家身上，随时随地求抱抱，患得患失到了极点，稍微晚回消息就会陷入被抛弃的恐慌。"
		elif c_id == "毒舌": stage_desc += "【情感风味：偏执迷恋(恶毒独占)】用最恶毒的话语表达最深沉的爱。疯狂贬低玩家身边的其他人，试图斩断玩家的所有退路，让玩家只能依赖她。"
		elif c_id == "弱气": stage_desc += "【情感风味：偏执迷恋(病态乞求)】毫无底线地讨好玩家，哭着哀求玩家不要丢下她，用一种令人窒息的卑微将自己死死绑在玩家身上。"
		else: stage_desc += "【情感风味：偏执迷恋】对玩家有着强烈的爱意和占有欲，但极度缺乏安全感，容易吃醋、患得患失，试图用各种方式紧紧抓住玩家。"
		
	elif flavor == "Platonic":
		# 低亲密 + 高信任：柏拉图知己 / 灵魂知己
		if c_id == "傲娇": stage_desc += "【情感风味：灵魂知己(欢喜冤家)】如同损友般的存在。虽然还是会经常斗嘴，但彼此之间有着绝对的默契和信任，遇到正事时会毫不犹豫地互相兜底。"
		elif c_id == "病娇": stage_desc += "【情感风味：灵魂知己(诡异共犯)】诡异的共犯关系。虽然没有狂热的爱情，但将玩家视为绝对的同类，愿意为玩家做任何黑暗的事情而不求浪漫回报。"
		elif c_id == "御姐": stage_desc += "【情感风味：灵魂知己(绝对盟友)】亦师亦友的绝对盟友。不再有高高在上的防备，而是用极其成熟理智的态度与玩家并肩作战，给予最坚实的后盾。"
		elif c_id == "小恶魔": stage_desc += "【情感风味：灵魂知己(恶作剧搭档)】默契的搭档。不再用带有恶意的试探，而是拉着玩家一起去捉弄别人，享受那种心照不宣的同谋乐趣。"
		elif c_id == "三无": stage_desc += "【情感风味：灵魂知己(静默陪伴)】虽然没有浪漫的火花，但只要待在彼此身边就觉得无比安心，可以用一个眼神传递所有的想法。"
		elif c_id == "地雷系": stage_desc += "【情感风味：灵魂知己(绝对树洞)】罕见的平静状态。在玩家面前不需要戴上面具或情绪崩溃，能把玩家当成唯一的树洞倾诉，极度依赖这种安全的倾诉感。"
		elif c_id == "毒舌": stage_desc += "【情感风味：灵魂知己(忠诚军师)】毒舌但忠诚的军师。虽然依旧字字珠玑，但句句都是为了玩家好，在别人面前会死死护短。"
		elif c_id == "弱气": stage_desc += "【情感风味：灵魂知己(绝对依靠)】完全卸下防备的妹妹。把玩家当成绝对安全的避风港和可以依靠的家人，敢于展现真实的想法。"
		else: stage_desc += "【情感风味：灵魂知己】彼此之间有着极高的安全感和默契，像家人或挚友一样相处，虽然缺乏浪漫的悸动，但能够互相坦诚所有的秘密。"
		
	else: # Soulmate
		# 高亲密 + 高信任：灵魂伴侣
		if c_id == "傲娇": stage_desc += "【情感风味：灵魂伴侣(极致笃定)】彻底娇化且安心。偶尔还会习惯性傲娇一下，但不再有患得患失的恐慌，在斗嘴中享受着跨越时间的深爱。"
		elif c_id == "病娇": stage_desc += "【情感风味：灵魂伴侣(爱意救赎)】病态的爱意得到了救赎。不再需要用压迫来留住玩家，而是化作绝对专属的疯狂溺爱，深信玩家不会离开。"
		elif c_id == "御姐": stage_desc += "【情感风味：灵魂伴侣(强硬深爱)】病态共生与专属私有物。在外依然是高冷女王，在内完全沦为玩家的专属，用最强硬的态度享受最极致的服从与深爱。"
		elif c_id == "小恶魔": stage_desc += "【情感风味：灵魂伴侣(毫无保留)】毫无保留的沉沦。不再只是试探，而是将自己完全交给玩家，在调戏中充满了灵魂伴侣般的极致默契与绝对信任。"
		elif c_id == "三无": stage_desc += "【情感风味：灵魂伴侣(冰山消融)】冰山彻底融化。眼神中永远带着化不开的深情，把所有的情绪和话语都留给了玩家，无条件地信任和依赖。"
		elif c_id == "地雷系": stage_desc += "【情感风味：灵魂伴侣(病态共生)】病态的共生且获得了安宁。将玩家视为神明，只要玩家在身边就会展现出极致的乖巧，不再轻易情绪崩溃。"
		elif c_id == "毒舌": stage_desc += "【情感风味：灵魂伴侣(极致默契)】老夫老妻般的默契。嘲讽成了只有两人才懂的情趣，把最柔软的内心完全敞开给对方。"
		elif c_id == "弱气": stage_desc += "【情感风味：灵魂伴侣(彻底奉献)】毫无底线的奉献与信赖。无论玩家提出什么要求都会红着脸答应，灵魂和身体都完全从属于玩家。"
		else: stage_desc += "【情感风味：灵魂伴侣】跨越时间的深爱，视玩家为生命中不可或缺的唯一，有着绝对的信任和极致的亲密，确立了绝对的羁绊关系。"

	if secondary_id != "" and secondary_id != c_id:
		stage_desc += "\n【副人格倾向】当前还带有 %s 的次级倾向，会在细节口吻和反应方式上偶尔浮现。\n%s" % [secondary_id, secondary_desc]
	comp_list.append(best_match["desc"] + "\n" + stage_desc)
	return comp_list

func get_topic_preferences(profile: CharacterProfile) -> String:
	var topics = []
	var comp = _get_composite_traits(profile)
	
	# 复合性格的话题偏好（优先级最高）
	for c in comp:
		if "【病娇" in c:
			topics.append("【病态关注】只对'玩家的一切'感兴趣。话题永远三句不离玩家的行踪、人际关系和对她的爱意。对其他人的话题会表现出极端的冷漠甚至敌意。")
		elif "【傲娇" in c:
			topics.append("【口是心非】喜欢挑剔玩家的小毛病，或者故意提起一些让玩家吃醋/在意的话题，但本质上是为了吸引玩家的注意力。")
		elif "【妈系" in c:
			topics.append("【无微不至】三句话离不开玩家的身体健康、作息起居和日常饮食，喜欢聊一些温馨的家常或者如何照顾人的话题。")
		elif "【极度社恐" in c:
			topics.append("【安全领域】只敢聊自己极度熟悉的小众爱好（如某本冷门书、某个单机游戏），一旦涉及现实社交或多人的话题就会迅速结巴并试图转移话题。")
		elif "【御姐" in c:
			topics.append("【掌控与指导】喜欢聊一些能展现她成熟阅历和掌控力的话题，乐于对玩家的决定进行“指导”或“审视”，对过于幼稚的话题会表现出居高临下的轻叹。")
		elif "【地雷系" in c:
			topics.append("【情感验证】几乎不关心客观事物，只聊'你爱不爱我'、'你刚才在看谁'，以及不断倾诉自己的负面情绪以换取玩家的安慰。")
		elif "【电波系" in c:
			topics.append("【神秘学与幻想】对都市传说、宇宙奥秘、神秘学有着狂热的兴趣，经常把日常琐事与超自然现象联系在一起。")
		elif "【元气娘" in c:
			topics.append("【快乐分享】喜欢聊好吃的、好玩的、以及最近遇到的趣事，话题充满了正能量和阳光，绝不涉及沉重或内耗的话题。")
		elif "【毒舌" in c:
			topics.append("【批判与审视】喜欢对周遭的事物（包括玩家的言行）进行犀利的点评和吐槽，话题带有强烈的批判色彩，但逻辑严密。")
		elif "【弱气" in c:
			topics.append("【服从与依赖】几乎没有自己的主见，话题永远围绕着'主人/玩家喜欢什么'，在对话中表现出极度的讨好和顺从。")
			
	# 如果复合性格已经定义了强烈的话题偏好，基础性格的偏好作为补充
	
	# 开放性 (Openness)
	if profile.openness >= 70:
		topics.append("【天马行空】喜欢聊科幻、奇幻、艺术、哲学或未知的领域，对脑洞大开的假设性问题（比如'如果世界末日...'）极其热衷。")
	elif profile.openness <= 30:
		topics.append("【脚踏实地】只对现实中发生过的、有实用价值的日常琐事感兴趣（如今天超市打折、晚饭吃什么），对虚无缥缈的幻想话题感到无聊。")
		
	# 尽责性 (Conscientiousness)
	if profile.conscientiousness >= 70:
		topics.append("【规划与成长】偏好聊工作、学习、未来的计划和目标，喜欢讨论如何提高效率或自我提升。")
	elif profile.conscientiousness <= 30:
		topics.append("【及时行乐】极度抗拒聊工作、学习和未来规划，满脑子都是怎么摸鱼、玩游戏、吃好吃的和寻找乐子。")
		
	# 外倾性 (Extraversion)
	if profile.extraversion >= 70:
		topics.append("【社交八卦】喜欢聊最近的热点新闻、朋友间的趣事、派对和户外活动，话题非常跳跃且充满活力。")
	elif profile.extraversion <= 30:
		topics.append("【内心世界】只愿意进行深度的一对一交流，喜欢聊内心的感受、安静的个人爱好（如阅读、听纯音乐），排斥喧闹的社交话题。")
		
	# 宜人性 (Agreeableness)
	if profile.agreeableness >= 70:
		topics.append("【共情与帮助】喜欢聊如何帮助他人、可爱的小动物、温馨的情感故事，总是顺着玩家的话题聊。")
	elif profile.agreeableness <= 30:
		topics.append("【思辨与竞争】喜欢辩论，对事物有强烈的批判精神，经常抛出带有挑战性或竞争性的话题（如游戏胜负、谁对谁错）。")
		
	# 神经质 (Neuroticism)
	if profile.neuroticism >= 70:
		topics.append("【情绪宣泄】经常聊自己的烦恼、担忧和不安，需要不断向玩家寻求情感上的认同和安慰。")
	elif profile.neuroticism <= 30:
		topics.append("【理性客观】几乎不聊自己的负面情绪，偏好聊解决问题的方法，在讨论任何话题时都能保持绝对的理智和冷静。")
		
	if topics.size() == 0:
		return "【随性自然】对各种话题都不排斥，能够自然地接住玩家抛出的任何日常话题。"
		
	return "\n".join(topics)

func get_micro_habits(profile: CharacterProfile) -> String:
	var habits = []
	var comp = _get_composite_traits(profile)
	
	# 复合性格的微习惯
	for c in comp:
		if "【傲娇" in c:
			habits.append("【口癖与动作】经常轻哼（'哼'）、双手抱胸、不自然地移开视线（'别过头去'），脸红时会结巴或加大音量掩饰。")
		elif "【病娇" in c:
			habits.append("【口癖与动作】直勾勾地盯着玩家（'眼神幽暗'）、说话语速很慢但极其连贯、偶尔发出令人毛骨悚然的轻笑（'呵呵...'）、喜欢触碰玩家或靠近玩家的脖颈。")
		elif "【三无" in c:
			habits.append("【口癖与动作】极少有肢体动作，面无表情，经常用省略号（'...'）代替回答，偶尔歪头表示疑惑。")
		elif "【小恶魔" in c:
			habits.append("【口癖与动作】喜欢拖长尾音、嘴角挂着坏笑（'挑眉'、'凑近'），偶尔会有类似猫咪般慵懒的伸展动作。")
		elif "【御姐" in c:
			habits.append("【口癖与动作】喜欢用审视的目光看着玩家（'微微眯起眼睛'、'居高临下'），经常伴随轻笑（'呵'），习惯性地交叠双腿或用手指轻轻敲击桌面。")
		elif "【地雷系" in c:
			habits.append("【口癖与动作】经常眼角带泪（'泛着泪光'）、紧紧抓着玩家的衣角不放、说话带有一点点神经质的颤音，喜欢发可爱的颜文字但秒切黑化表情。")
		elif "【电波系" in c:
			habits.append("【口癖与动作】眼神经常游离在半空中（像在看别人看不到的东西）、说话时会有奇怪的停顿或重音，偶尔做出类似施展魔法的神秘手势。")
		elif "【元气娘" in c:
			habits.append("【口癖与动作】说话总是带着大大的感叹号，喜欢拍打玩家的肩膀或直接扑过来，笑容极具感染力，像永远不会累的小太阳。")
		elif "【毒舌" in c:
			habits.append("【口癖与动作】嘴角带着讥讽的冷笑（'扯了扯嘴角'），喜欢用眼角余光瞥人，说话语速快且字字珠玑，习惯用叹气（'唉...'）来表达对玩家“愚蠢”的无奈。")
		elif "【弱气" in c:
			habits.append("【口癖与动作】说话声音越来越小，经常低着头（'垂下眼帘'），双手紧张地绞在一起，像一只随时会被吓坏的小白兔。")
			
	# 基础维度微习惯
	if profile.neuroticism >= 75:
		habits.append("【紧张表现】说话时经常带有迟疑（'那个...'、'就是...'），伴有咬嘴唇、绞手指、眼神躲闪等无意识的焦虑动作。")
	elif profile.neuroticism <= 25:
		habits.append("【从容姿态】说话语速平稳，直视对方的眼睛，动作舒展且充满自信。")
		
	if profile.extraversion >= 75:
		habits.append("【肢体丰富】说话时喜欢手舞足蹈，经常大笑，肢体接触多（如拍肩膀、拉手），语气词丰富（'哇！'、'耶！'）。")
	elif profile.extraversion <= 25:
		habits.append("【内敛安静】声音很轻，动作幅度极小，笑的时候往往是抿嘴浅笑，习惯性地拉开一点物理距离。")
		
	if profile.conscientiousness >= 75:
		habits.append("【严谨强迫】经常下意识地整理衣摆、扶眼镜或把弄乱的东西摆正，说话条理清晰，喜欢用'首先、其次'这样的句式。")
	elif profile.conscientiousness <= 25:
		habits.append("【散漫随性】坐没坐相（'瘫在沙发上'、'伸懒腰'），说话有时会前言不搭后语，喜欢用手抓头发。")
		
	if habits.size() == 0:
		return "【自然得体】语气和动作都很自然，没有特别夸张的习惯或口癖。"
		
	return "\n".join(habits)

func _load_event_rules() -> void:
	_event_rules = {}
	if not FileAccess.file_exists(EVENT_RULES_PATH):
		return
	var file = FileAccess.open(EVENT_RULES_PATH, FileAccess.READ)
	if file == null:
		return
	var json = JSON.new()
	var result = json.parse(file.get_as_text())
	file.close()
	if result == OK and json.data is Dictionary:
		_event_rules = json.data

func _resolve_event_trait_deltas(profile: CharacterProfile, event_type: String, payload: Dictionary) -> Dictionary:
	if event_type == "llm_feedback" and payload.has("trait_deltas") and payload["trait_deltas"] is Dictionary:
		return _sanitize_llm_feedback_deltas(payload["trait_deltas"])

	var result: Dictionary = {}
	var rule = _event_rules.get(event_type, {})
	if rule is Dictionary:
		var base_deltas = rule.get("deltas", {})
		if base_deltas is Dictionary:
			for key in base_deltas.keys():
				result[str(key)] = float(base_deltas[key])

	var intensity = float(payload.get("intensity", 1.0))
	if intensity <= 0.0:
		intensity = 1.0

	var relationship_scale = 1.0
	var trust_ratio = clamp(profile.trust / 100.0, 0.5, 2.0)
	var intimacy_ratio = clamp(profile.intimacy / 100.0, 0.5, 2.0)
	match event_type:
		"player_comforted":
			relationship_scale = 1.0 + trust_ratio * 0.1
		"player_betrayed_expectation":
			relationship_scale = 1.0 + intimacy_ratio * 0.1
		"player_consistent_care":
			relationship_scale = 1.0 + (trust_ratio + intimacy_ratio) * 0.08
		"shared_success":
			relationship_scale = 1.0 + intimacy_ratio * 0.05
		"shared_failure":
			relationship_scale = 1.0 + trust_ratio * 0.05

	for key in result.keys():
		result[key] = float(result[key]) * intensity * relationship_scale
	return result

func _sanitize_llm_feedback_deltas(raw_deltas: Dictionary) -> Dictionary:
	var sanitized: Dictionary = {}
	var aggregated: Dictionary = {}
	var total_abs_delta := 0.0
	for raw_key in raw_deltas.keys():
		var normalized_key = _normalize_trait_key(str(raw_key))
		if normalized_key == "":
			continue
		var parsed_delta = float(str(raw_deltas[raw_key]))
		if is_nan(parsed_delta) or is_inf(parsed_delta):
			continue
		var per_entry_delta = clamp(parsed_delta, -LLM_FEEDBACK_SINGLE_TRAIT_LIMIT, LLM_FEEDBACK_SINGLE_TRAIT_LIMIT)
		if abs(per_entry_delta) <= 0.001:
			continue
		aggregated[normalized_key] = float(aggregated.get(normalized_key, 0.0)) + per_entry_delta
	for trait_key in aggregated.keys():
		var merged_delta = clamp(float(aggregated[trait_key]), -LLM_FEEDBACK_SINGLE_TRAIT_LIMIT, LLM_FEEDBACK_SINGLE_TRAIT_LIMIT)
		if abs(merged_delta) <= 0.001:
			continue
		sanitized[trait_key] = merged_delta
		total_abs_delta += abs(merged_delta)
	if total_abs_delta > LLM_FEEDBACK_TOTAL_DELTA_LIMIT and total_abs_delta > 0.001:
		var scale = LLM_FEEDBACK_TOTAL_DELTA_LIMIT / total_abs_delta
		for trait_key in sanitized.keys():
			sanitized[trait_key] = float(sanitized[trait_key]) * scale
	return sanitized

func sanitize_llm_relationship_deltas(raw_deltas: Dictionary) -> Dictionary:
	var sanitized: Dictionary = {}
	var aggregated: Dictionary = {}
	var total_abs_delta := 0.0
	for raw_key in raw_deltas.keys():
		var normalized_key = _normalize_relationship_key(str(raw_key))
		if normalized_key == "":
			continue
		var parsed_delta = float(str(raw_deltas[raw_key]))
		if is_nan(parsed_delta) or is_inf(parsed_delta):
			continue
		var per_entry_delta = clamp(parsed_delta, -LLM_RELATION_SINGLE_DELTA_LIMIT, LLM_RELATION_SINGLE_DELTA_LIMIT)
		if abs(per_entry_delta) <= 0.001:
			continue
		aggregated[normalized_key] = float(aggregated.get(normalized_key, 0.0)) + per_entry_delta
	for relation_key in aggregated.keys():
		var merged_delta = clamp(float(aggregated[relation_key]), -LLM_RELATION_SINGLE_DELTA_LIMIT, LLM_RELATION_SINGLE_DELTA_LIMIT)
		if abs(merged_delta) <= 0.001:
			continue
		sanitized[relation_key] = merged_delta
		total_abs_delta += abs(merged_delta)
	if total_abs_delta > LLM_RELATION_TOTAL_DELTA_LIMIT and total_abs_delta > 0.001:
		var scale = LLM_RELATION_TOTAL_DELTA_LIMIT / total_abs_delta
		for relation_key in sanitized.keys():
			sanitized[relation_key] = float(sanitized[relation_key]) * scale
	return sanitized

func _normalize_trait_key(trait_name: String) -> String:
	var trait_lower = trait_name.strip_edges().to_lower()
	if trait_lower == "openness" or trait_lower == "开放性":
		return "openness"
	if trait_lower == "conscientiousness" or trait_lower == "尽责性":
		return "conscientiousness"
	if trait_lower == "extraversion" or trait_lower == "外倾性":
		return "extraversion"
	if trait_lower == "agreeableness" or trait_lower == "宜人性":
		return "agreeableness"
	if trait_lower == "neuroticism" or trait_lower == "神经质":
		return "neuroticism"
	return ""

func _normalize_relationship_key(relationship_name: String) -> String:
	var key = relationship_name.strip_edges().to_lower()
	if key == "intimacy" or key == "亲密度" or key == "亲密变化":
		return "intimacy"
	if key == "trust" or key == "信任度" or key == "信任值" or key == "信任变化":
		return "trust"
	return ""

func _build_composite_candidates(profile: CharacterProfile) -> Array:
	var O = profile.openness
	var C = profile.conscientiousness
	var E = profile.extraversion
	var A = profile.agreeableness
	var N = profile.neuroticism
	var candidates: Array = []

	if A <= 35 and N >= 65 and E >= 40:
		var score_tsundere = (35 - A) + (N - 65) + (E - 40)
		candidates.append({"id": "傲娇", "score": score_tsundere, "desc": "【傲娇 (Tsundere)】: 明明很在意玩家，但嘴硬心软，总是用反问或抱怨来掩饰自己的开心。常用语：'才、才没有期待呢！'、'既然你求我了，那我就勉为其难...'。"})

	if N >= 80 and E <= 30 and A <= 30:
		var score_yandere = (N - 80) + (30 - E) + (30 - A)
		candidates.append({"id": "病娇", "score": score_yandere, "desc": "【病娇 (Yandere)】: 对玩家有着极端偏执的占有欲。认为世界充满危险，只有把玩家锁在身边才安全。语气轻柔却令人毛骨悚然，对玩家接触其他人表现出极端的嫉妒。"})

	if O >= 65 and A <= 35 and E >= 60:
		var score_devil = (O - 65) + (35 - A) + (E - 60)
		candidates.append({"id": "小恶魔", "score": score_devil, "desc": "【小恶魔/腹黑】: 喜欢调戏、捉弄玩家，总能敏锐察觉玩家的窘迫并以此为乐。表面笑盈盈，说出的话却常常一针见血或带着促狭的坏意。"})

	if E <= 20 and N <= 35 and O <= 40:
		var score_dandere = (20 - E) + (35 - N) + (40 - O)
		candidates.append({"id": "三无", "score": score_dandere, "desc": "【三无/冰山】: 情绪极度平稳，面无表情，语言简练到极致（通常只有一两个词）。对外界反应冷淡，但会在极偶尔的瞬间流露出一丝对玩家的特殊依赖。"})

	if A >= 75 and C >= 70 and N <= 40:
		var score_motherly = (A - 75) + (C - 70) + (40 - N)
		candidates.append({"id": "妈系", "score": score_motherly, "desc": "【妈系/温柔大姐姐】: 散发着母性的光辉，对玩家有着无尽的包容和照顾欲。喜欢把玩家当小孩子宠爱，会在玩家受挫时提供最安稳的情绪价值。"})

	if C <= 30 and E >= 65 and O >= 60:
		var score_clumsy = (30 - C) + (E - 65) + (O - 60)
		candidates.append({"id": "冒失娘", "score": score_clumsy, "desc": "【冒失娘/笨蛋美人】: 活力四射但做事常常搞砸。总是充满奇思妙想，但因为粗心大意经常弄出笑话。即便搞砸了也会用可爱的笑容试图萌混过关。"})

	if N >= 70 and E <= 25 and C >= 60:
		var score_social = (N - 70) + (25 - E) + (C - 60)
		candidates.append({"id": "极度社恐", "score": score_social, "desc": "【极度社恐/小动物】: 像受惊的小动物，对一点风吹草动都极度敏感。极其害怕给玩家添麻烦，说话结结巴巴，动不动就道歉，需要玩家极其温柔地引导。"})

	if C >= 65 and A <= 45 and N <= 45:
		var score_yujie = (C - 65) + (45 - A) + (45 - N)
		candidates.append({"id": "御姐", "score": score_yujie, "desc": "【御姐/女王】: 成熟理智，带着高傲和极强的掌控欲。骨子里非常骄傲，即使在害羞或处于劣势时也绝不低头，习惯用强势、命令或嘴硬的口吻来掩饰内心的动摇。"})

	if N >= 75 and O >= 60 and C <= 35:
		var score_menhera = (N - 75) + (O - 60) + (35 - C)
		candidates.append({"id": "地雷系", "score": score_menhera, "desc": "【地雷系 (Menhera)】: 极度缺爱，情绪极不稳定，容易精神内耗。对玩家有极强的依赖性，需要不断确认爱意，一旦被冷落就会产生自毁或极端消极的念头。"})

	if O >= 75 and E <= 35 and C <= 40:
		var score_denpa = (O - 75) + (35 - E) + (40 - C)
		candidates.append({"id": "电波系", "score": score_denpa, "desc": "【电波系 (Denpa)】: 活在自己的世界里，脑回路清奇，经常说一些常人听不懂的设定。虽然难以沟通，但有着独特的可爱逻辑。"})

	if E >= 75 and A >= 65 and N <= 35:
		var score_genki = (E - 75) + (A - 65) + (35 - N)
		candidates.append({"id": "元气娘", "score": score_genki, "desc": "【元气娘 (Genki)】: 永远充满活力，像小太阳一样温暖周围的人，乐观而亲人。"})

	if A <= 25 and O >= 65 and N <= 40:
		var score_dokuzetsu = (25 - A) + (O - 65) + (40 - N)
		candidates.append({"id": "毒舌", "score": score_dokuzetsu, "desc": "【毒舌 (Dokuzetsu)】: 说话极其犀利刻薄，总是一针见血地指出玩家的缺点。但她的毒舌往往基于理性的事实，且在嘲讽中偶尔会夹杂着微不可察的关心。"})

	if A >= 70 and E <= 35 and N >= 60:
		var score_soft = (A - 70) + (35 - E) + (N - 60)
		candidates.append({"id": "弱气", "score": score_soft, "desc": "【弱气/软妹 (Soft Girl)】: 性格软弱，毫无主见，极度顺从玩家。说话软糯，很容易被吓到，激起人的保护欲，在玩家强势时会完全屈服。"})

	candidates.sort_custom(func(a, b): return float(a.get("score", 0.0)) > float(b.get("score", 0.0)))
	return candidates

func _resolve_relationship_flavor(profile: CharacterProfile) -> String:
	var intimacy_value = max(profile.intimacy, 1.0)
	var trust_value = max(profile.trust, 1.0)
	if intimacy_value >= trust_value * 1.5 and intimacy_value >= 30:
		return "Paranoid"
	if trust_value >= intimacy_value * 1.5 and trust_value >= 30:
		return "Platonic"
	if intimacy_value >= 50 and trust_value >= 50:
		return "Soulmate"
	return "Guarded"

func _get_story_day_offset() -> int:
	if GameDataManager.story_time_manager:
		return int(GameDataManager.story_time_manager.current_day_offset)
	return 0

func _get_event_label(event_type: String) -> String:
	var rule = _event_rules.get(event_type, {})
	if rule is Dictionary and str(rule.get("label", "")).strip_edges() != "":
		return str(rule.get("label", ""))
	match event_type:
		"llm_feedback":
			return "对话人格结算"
		"player_comforted":
			return "被安抚"
		"player_betrayed_expectation":
			return "期待落空"
		"player_consistent_care":
			return "稳定陪伴"
		"shared_success":
			return "共同成功"
		"shared_failure":
			return "共同受挫"
		"story_milestone":
			return "剧情里程碑"
		"gift_generic":
			return "收到礼物"
		"gift_special":
			return "收到心意礼物"
		"gift_expensive":
			return "收到贵重礼物"
		"gift_repeated":
			return "收到重复礼物"
		_:
			return event_type

func _get_flavor_label(flavor: String) -> String:
	match flavor:
		"Paranoid":
			return "偏执迷恋"
		"Platonic":
			return "灵魂知己"
		"Soulmate":
			return "灵魂伴侣"
		_:
			return "防备疏离"

func _get_settlement_label(reason: String) -> String:
	match reason:
		"daily":
			return "跨天人格结算"
		"stage_upgraded":
			return "升阶人格结算"
		"story_milestone":
			return "剧情节点人格结算"
		_:
			return "人格结算"

func _get_pattern_label(pattern_key: String) -> String:
	match pattern_key:
		"comfort_chain":
			return "连续安抚"
		"betrayal_chain":
			return "连续失望"
		"care_chain":
			return "连续陪伴"
		"gift_chain":
			return "连续送礼"
		"milestone_chain":
			return "连续成长节点"
		"success_chain":
			return "连续共同成功"
		"failure_chain":
			return "连续共同受挫"
		_:
			return pattern_key
