extends RefCounted


static func build_user_message(policy: Dictionary, covered_beat_ids: Array[String], current_round: int, max_rounds: int, player_text: String, character_opens: bool = false) -> Dictionary:
	return _build_user_message(policy, covered_beat_ids, current_round, max_rounds, player_text, character_opens, [])


static func build_user_message_with_used_options(policy: Dictionary, covered_beat_ids: Array[String], current_round: int, max_rounds: int, player_text: String, used_option_texts: Array[String]) -> Dictionary:
	return _build_user_message(policy, covered_beat_ids, current_round, max_rounds, player_text, false, used_option_texts)


static func _build_user_message(policy: Dictionary, covered_beat_ids: Array[String], current_round: int, max_rounds: int, player_text: String, character_opens: bool, used_option_texts: Array[String]) -> Dictionary:
	var candidate_beats: Array[Dictionary] = []
	var candidate_beat_ids: Array[String] = []
	for beat_value in policy.get("required_beats", []):
		if not beat_value is Dictionary:
			continue
		var beat := beat_value as Dictionary
		var beat_id := str(beat.get("id", "")).strip_edges()
		if beat_id.is_empty() or covered_beat_ids.has(beat_id):
			continue
		candidate_beat_ids.append(beat_id)
		candidate_beats.append({"id": beat_id, "instruction": str(beat.get("instruction", "")).strip_edges()})
		break
	var remaining_rounds := maxi(0, max_rounds - current_round)
	var response_requirement := "这是角色主动开场，玩家尚未发言。请自然开启话题并推进剧情点；" if character_opens else "先自然回应玩家，再推进剧情点；"
	var option_requirement := "next_options 必须生成两个玩家可直接发送、内容不同且自然承接 dialogue 的选项；每项只能包含 text 和 focus，focus 只能是 intimacy 或 trust。" if remaining_rounds > 0 else "对话即将收束，next_options 必须为空数组。"
	var prompt := """【引导式主线对话约束】
不可改写的剧情事实：%s
本场景目标：%s
允许讨论范围：%s
禁止改写或虚构：%s
偏题处理：%s
本轮需要自然推进的剧情点：%s
本轮之后剩余玩家回合：%d
本次会话已经使用过的玩家选项：%s
要求：%s保持角色第一人称，不得提及系统、Prompt、剧情点或回合限制。dialogue 必须至少包含一处使用全角圆括号包裹的细腻动作描写。括号内至少 12 个汉字，并同时写出两个以上可观察细节，例如手部动作、视线、姿态、呼吸、表情或与画稿等现场物件的互动；动作必须贴合当前情绪和场景，不能只写“点头”“微笑”“看向你”等简短概括。例如“（指尖沿着画稿边缘慢慢停下，她抬眼望向你，眉间还藏着一点犹豫）”。不得使用星号、中括号或旁白标签代替动作描写。
必须只输出 JSON 对象，格式为：{"dialogue":"（角色动作）角色实际台词，可使用 [SPLIT] 分隔气泡","beat_evaluations":[{"id":"候选剧情点 ID","covered":true,"evidence":"dialogue 中逐字出现的证据片段"}],"next_options":[{"text":"玩家可直接发送的回复","focus":"intimacy"},{"text":"另一条玩家回复","focus":"trust"}]}。
只有 dialogue 确实表达了候选剧情点时才能标记 covered=true；evidence 必须逐字取自 dialogue。next_options 不得重复本次会话已经使用过的玩家选项。不得输出 Markdown 围栏或 JSON 之外的内容。
%s

玩家输入：%s""" % [
		str(policy.get("narrative_anchor", "")),
		str(policy.get("scene_objective", "")),
		JSON.stringify(policy.get("allowed_topics", [])),
		JSON.stringify(policy.get("forbidden_facts", [])),
		str(policy.get("redirect_instruction", "")),
		JSON.stringify(candidate_beats),
		remaining_rounds,
		JSON.stringify(used_option_texts),
		response_requirement,
		option_requirement,
		player_text
	]
	return {"prompt": prompt, "candidate_beat_ids": candidate_beat_ids}
