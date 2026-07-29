extends RefCounted


static func build_user_message(policy: Dictionary, covered_beat_ids: Array[String], current_round: int, max_rounds: int, player_text: String) -> Dictionary:
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
	var prompt := """【引导式主线对话约束】
不可改写的剧情事实：%s
本场景目标：%s
允许讨论范围：%s
禁止改写或虚构：%s
偏题处理：%s
本轮需要自然推进的剧情点：%s
本轮之后剩余玩家回合：%d
要求：先自然回应玩家，再推进剧情点；保持角色第一人称，不得提及系统、Prompt、剧情点或回合限制。dialogue 必须至少包含一处使用全角圆括号包裹的动作、神态或细微反应，例如“（轻轻捏住衣角）”；不得使用星号、中括号或旁白标签代替动作描写。
必须只输出 JSON 对象，格式为：{"dialogue":"（角色动作）角色实际台词，可使用 [SPLIT] 分隔气泡","beat_evaluations":[{"id":"候选剧情点 ID","covered":true,"evidence":"dialogue 中逐字出现的证据片段"}]}。
只有 dialogue 确实表达了候选剧情点时才能标记 covered=true；evidence 必须逐字取自 dialogue。不得输出 Markdown 围栏或 JSON 之外的内容。

玩家输入：%s""" % [
		str(policy.get("narrative_anchor", "")),
		str(policy.get("scene_objective", "")),
		JSON.stringify(policy.get("allowed_topics", [])),
		JSON.stringify(policy.get("forbidden_facts", [])),
		str(policy.get("redirect_instruction", "")),
		JSON.stringify(candidate_beats),
		remaining_rounds,
		player_text
	]
	return {"prompt": prompt, "candidate_beat_ids": candidate_beat_ids}
