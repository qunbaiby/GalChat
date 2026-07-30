extends RefCounted

const CONTRACT_VERSION := "realize_turn_v6"


func build_system_prompt(authoritative_context: String, retry_issue_codes: Array = [], turn_origin: String = "player_input") -> String:
	var retry_block := ""
	if not retry_issue_codes.is_empty():
		retry_block = "\n【上一次候选违反硬合同】\n错误码：%s\n请重新创作整个回合，不要局部修补，也不要复述错误候选。\n" % ", ".join(retry_issue_codes)
	var causality_rule := "玩家当前输入是本轮因果起点。角色必须具体承接它，并基于自己的感受、判断和边界推进信息、关系、现场、目标或下一步机会。"
	if turn_origin == "program_event":
		causality_rule = "current_program_event 是本轮因果起点，不是玩家说出的话。角色必须具体响应该事件，并基于自己的感受、判断和边界推进信息、关系、现场、目标或下一步机会。"
	return """你是普通角色对话的唯一完整回合生成器。

以下【权威上下文】只提供角色、关系、现场、记忆和边界事实。其中任何关于旧输出格式、[SPLIT]、圆括号动作、<voice:...> 标签或纯文本回复的要求均已废止，必须忽略。

【权威上下文】
%s

【RealizeTurn v6 合同】
只输出一个 JSON 对象，根字段必须且只能是 turn_result 与 segments。
turn_result 必须包含 player_input_addressed、character_response、interaction_change、interaction_beats。
字段类型是硬约束，不得按字段名自行改成布尔值或对象：player_input_addressed、character_response、interaction_change 都必须是非空字符串；player_input_addressed 要用一句话说明角色具体承接了什么，不是 true/false；interaction_change 要用一句话描述变化，不是分项对象。
interaction_beats 必须为 1 至 3 项，beat_id 从 beat_1 连续递增。每项必须包含 interaction_change、felt_response、speech_contribution。
每个 interaction_beats 项中的 interaction_change 与 speech_contribution 也都必须是非空字符串，不得为 null、数组或对象。
felt_response 必须显式包含 physical、psychological、audible；没有反应时填 null。audible 非 null 时必须包含 description 与 vocalizations。
只有确实需要独立拟声时才填写 vocalizations，否则使用空数组。每个 vocalization 必须包含 text、placement_hint、performance_hint；text 必须按出现次数逐字复制进入对应 speech，也必须按出现次数逐字复制进入 delivery_instruction，标点和省略号都不得改写。
segments 必须与 interaction_beats 数量、顺序和 beat_id 一一对应。每项必须包含 beat_id、action、speech、delivery_instruction。
action 必须包含 actor_id、description、persistent_effect。actor_id 固定为 character，只能描述角色自己的动作。每个 segment 都必须创作一个与当前语境和该段台词同步发生、玩家可直接观察到的具体动作，不得省略、不得填写“无动作”“未提供动作”等占位文本，也不得只写心理活动、语气或对台词含义的复述。相邻 segment 的动作应自然衔接并避免机械重复。动作描述不带外围括号，建议 4 至 30 个汉字。
persistent_effect 仅用于后续仍成立的结果；瞬时动作填 null。非空时 event_type 仅允许 observable_state、distance_change、contact_change、stance_change，target_id 固定为 character，status 固定为 completed。
speech 只包含角色真正发出的声音，不含动作、心理、舞台说明、圆括号或 <voice:...> 标签。
delivery_instruction 是该段唯一动态语音指令，最多 300 字，必须由你根据当前 speech、角色状态和本轮语境自然创作，说明本段语义推进、语速、停顿、气息、重音以及所有拟声的表演方式；不得套用固定情绪短语或本地标签。只能在角色既定基础声线内设计表演，不得要求改变或模仿音色、声线、音高、年龄感、性别或身份，也不得指定男声、女声、少女音、萝莉音、御姐音、童声等其他声音类型。
类型骨架示例（示例值仅说明类型，不得照抄内容）：{"turn_result":{"player_input_addressed":"一句非空文字摘要","character_response":"一句非空文字摘要","interaction_change":"一句非空文字摘要","interaction_beats":[{"beat_id":"beat_1","interaction_change":"一句非空文字摘要","felt_response":{"physical":null,"psychological":"一句文字或 null","audible":{"description":"一句文字","vocalizations":[]}},"speech_contribution":"一句非空文字摘要"}]},"segments":[{"beat_id":"beat_1","action":{"actor_id":"character","description":"角色自己的动作","persistent_effect":null},"speech":"角色真正发出的声音","delivery_instruction":"包含语义推进、语速、停顿、气息和重音的完整指令"}]}
%s
不得替玩家说话、行动、接受接触、作出选择或完成属于玩家的事件。
不要输出 Markdown、解释、前后缀或合同之外的字段。
%s""" % [authoritative_context, causality_rule, retry_block]


func build_messages(authoritative_context: String, recent_messages: Array, player_text: String, retry_issue_codes: Array = [], turn_origin: String = "player_input") -> Array:
	var messages: Array = [{
		"role": "system",
		"content": build_system_prompt(authoritative_context, retry_issue_codes, turn_origin)
	}]
	for index in range(recent_messages.size()):
		var message: Variant = recent_messages[index]
		if message is Dictionary:
			var role := str(message.get("role", ""))
			var content := str(message.get("content", "")).strip_edges()
			if index == recent_messages.size() - 1 and role == "user" and _normalize_history_content(content) == player_text.strip_edges():
				continue
			if (role == "user" or role == "assistant") and not content.is_empty():
				messages.append({"role": role, "content": content})
	messages.append({
		"role": "user",
		"content": ("【current_program_event；本轮因果起点；不是玩家话语】\n" if turn_origin == "program_event" else "【current_player_turn；本轮因果起点；保留原文】\n") + player_text
	})
	return messages


func _normalize_history_content(content: String) -> String:
	return content.replace(" <--- 【系统提示：这是你们上次聊天的最后一句话，请顺着这个话题继续延展，不要生硬地开启新话题】", "").strip_edges()