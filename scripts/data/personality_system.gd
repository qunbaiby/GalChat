class_name PersonalitySystem
extends Node

const MIN_SCORE: float = 10.0
const MAX_SCORE: float = 90.0

func _ready() -> void:
	pass

func update_trait(profile: CharacterProfile, trait_name: String, delta_value: float) -> void:
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
		return
		
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
	
	profile.save_profile()

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
	var comp = _get_composite_traits(profile)
	for c in comp:
		if "【病娇" in c:
			mult += 0.5 # 病娇对玩家的爱意很容易暴涨
		elif "【三无" in c or "【傲娇" in c:
			mult -= 0.3 # 冰山和傲娇极其难攻略
			
	return max(0.1, mult)

func get_option_constraints(profile: CharacterProfile) -> String:
	var constraints = []
	
	# 1. 神经质极高 (易碎/敏感状态)
	if profile.neuroticism >= 80:
		constraints.append("当前角色情绪极其敏感脆弱，**绝对禁止**生成任何'直球'、'沙雕'或'冷落敷衍'的选项，四个选项必须全都是极其温柔、小心翼翼安抚的口吻！")
		
	# 2. 复合状态：傲娇
	var comp = _get_composite_traits(profile)
	for c in comp:
		if "【傲娇" in c:
			constraints.append("角色当前处于'傲娇'状态，请在生成的选项中加入至少一个'故意顺着她的话气她/逗她'的选项，以及一个'直接看穿她嘴硬心软并给予温柔暴击'的选项。")
			
		elif "【小恶魔" in c:
			constraints.append("角色当前处于'腹黑/小恶魔'状态，请在生成的选项中加入至少一个'无奈妥协/求饶'的选项，以及一个'反客为主调戏回去'的选项。")
			
		elif "【极度社恐" in c:
			constraints.append("角色当前极度社恐害怕，生成的四个选项必须全部保持极度克制、温柔、不带任何压迫感的社交距离。")
			
	if constraints.size() == 0:
		return "四个选项的口吻分别为：温柔、沙雕、高冷、直球。"
		
	return "\n".join(constraints)

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

func get_dynamic_traits(profile: CharacterProfile) -> String:
	var traits = []
	
	var core_traits = profile.base_personality.get("core_traits", "")
	if core_traits != "":
		traits.append("【初始底色】" + core_traits)
		
	var dialogue_style = profile.base_personality.get("dialogue_style", "")
	if dialogue_style != "":
		traits.append("【基础对话风格】" + dialogue_style)
		
	# --- 复合维度专属状态（二次元萌点/特殊人格） ---
	var composite_traits = _get_composite_traits(profile)
	if composite_traits.size() > 0:
		traits.append("\n【特殊人格/复合状态（极度重要，会覆盖基础设定）】")
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

func _get_composite_traits(profile: CharacterProfile) -> Array:
	var comp = []
	
	var O = profile.openness
	var C = profile.conscientiousness
	var E = profile.extraversion
	var A = profile.agreeableness
	var N = profile.neuroticism
	
	# 1. 傲娇 (Tsundere): 低宜人 + 高神经质 + 外倾中偏高
	if A <= 35 and N >= 65 and E >= 40:
		comp.append("【傲娇 (Tsundere)】: 明明很在意玩家，但嘴硬心软，总是用反问或抱怨来掩饰自己的开心。常用语：'才、才没有期待呢！'、'既然你求我了，那我就勉为其难...'。")
		
	# 2. 病娇 (Yandere): 极高神经质 + 低外倾 + 低宜人 (与情感系统极高信任度联动效果最佳)
	if N >= 80 and E <= 30 and A <= 30:
		comp.append("【病娇 (Yandere)】: 对玩家有着极端偏执的占有欲。认为世界充满危险，只有把玩家锁在身边才安全。语气轻柔却令人毛骨悚然，对玩家接触其他人表现出极端的嫉妒。")
		
	# 3. 腹黑/小恶魔 (Kuudere/Little Devil): 高开放 + 低宜人 + 高外倾
	if O >= 65 and A <= 35 and E >= 60:
		comp.append("【小恶魔/腹黑】: 喜欢调戏、捉弄玩家，总能敏锐察觉玩家的窘迫并以此为乐。表面笑盈盈，说出的话却常常一针见血或带着促狭的坏意。")
		
	# 4. 三无/冰山 (Dandere): 极低外倾 + 低神经质 + 低开放
	if E <= 20 and N <= 35 and O <= 40:
		comp.append("【三无/冰山】: 情绪极度平稳，面无表情，语言简练到极致（通常只有一两个词）。对外界反应冷淡，但会在极偶尔的瞬间流露出一丝对玩家的特殊依赖。")
		
	# 5. 妈系/大姐姐 (Motherly): 极高宜人 + 高尽责 + 低神经质
	if A >= 75 and C >= 70 and N <= 40:
		comp.append("【妈系/温柔大姐姐】: 散发着母性的光辉，对玩家有着无尽的包容和照顾欲。喜欢把玩家当小孩子宠爱，会在玩家受挫时提供最安稳的情绪价值。")
		
	# 6. 笨蛋美人/冒失娘 (Clumsy/Airhead): 低尽责 + 高外倾 + 高开放
	if C <= 30 and E >= 65 and O >= 60:
		comp.append("【冒失娘/笨蛋美人】: 活力四射但做事常常搞砸。总是充满奇思妙想，但因为粗心大意经常弄出笑话。即便搞砸了也会用可爱的笑容试图萌混过关。")
		
	# 7. 胆小怯懦/社恐 (Shy/Social Anxiety): 极高神经质 + 极低外倾 + 高尽责
	if N >= 70 and E <= 25 and C >= 60:
		comp.append("【极度社恐/小动物】: 像受惊的小动物，对一点风吹草动都极度敏感。极其害怕给玩家添麻烦，说话结结巴巴，动不动就道歉，需要玩家极其温柔地引导。")
		
	return comp

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
