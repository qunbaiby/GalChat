@tool
extends RefCounted

const JsonService = preload("res://addons/story_editor/core/story_json_service.gd")
const ChatSplitHelper = preload("res://scripts/utils/chat_split_helper.gd")

const TEMPLATE_PATH := "res://scripts/templates/prompts/mobile_chat.txt"
const WORLD_PATH := "res://assets/data/world/world_setting.json"
const CHARACTER_ROOTS := ["res://assets/data/characters", "res://assets/data/characters/npc"]
const SINGLE_STYLE := "【分段策略：单段回复】回复 10 到 50 字，总字数不超过 100 字。只输出纯台词，不使用 [SPLIT]。"
const DOUBLE_STYLE := "【分段策略：双段连续】回复两段，每段 10 到 30 字，总字数不超过 80 字，两段之间只能使用 [SPLIT]。"


static func scan_characters() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for root in CHARACTER_ROOTS:
		var directory := DirAccess.open(root)
		if directory == null:
			continue
		directory.list_dir_begin()
		var entry := directory.get_next()
		while not entry.is_empty():
			if not directory.current_is_dir() and entry.get_extension().to_lower() == "json" and not entry.contains("_stages"):
				var result := JsonService.load_dictionary(root.path_join(entry))
				if result.get("ok", false):
					var data := result.get("data", {}) as Dictionary
					entries.append({"id": entry.get_basename(), "label": str(data.get("display_name", data.get("char_name", entry.get_basename()))), "path": root.path_join(entry)})
			entry = directory.get_next()
		directory.list_dir_end()
	entries.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return str(left.get("id", "")) < str(right.get("id", "")))
	return entries


static func build_context(overrides: Dictionary = {}) -> Dictionary:
	var character_id := str(overrides.get("character_id", "luna"))
	var static_data := _load_character(character_id)
	var stage := int(overrides.get("relationship_stage", 1))
	var stage_data := _load_stage(character_id, stage)
	var context := {
		"character_id": character_id,
		"character_name": str(overrides.get("character_name", static_data.get("display_name", static_data.get("char_name", character_id)))),
		"age": int(overrides.get("age", static_data.get("age", 22))),
		"player_name": str(overrides.get("player_name", "老师")),
		"identity_background": str(overrides.get("identity_background", static_data.get("identity_background", static_data.get("description", "")))),
		"intimacy": float(overrides.get("intimacy", 20.0)),
		"trust": float(overrides.get("trust", 20.0)),
		"flavor": str(overrides.get("flavor", "逐渐熟悉")),
		"relationship_stage": stage,
		"stage_title": str(overrides.get("stage_title", stage_data.get("stageTitle", "第%d阶段" % stage))),
		"stage_desc": str(overrides.get("stage_desc", stage_data.get("stageDesc", "保持符合当前关系阶段的交流边界。"))),
		"trust_desc": str(overrides.get("trust_desc", _relationship_description(float(overrides.get("intimacy", 20.0)), float(overrides.get("trust", 20.0))))),
		"personality_traits": str(overrides.get("personality_traits", (static_data.get("base_personality", {}) as Dictionary).get("core_traits", "自然、真诚、有分寸"))),
		"micro_habits": str(overrides.get("micro_habits", "保持角色既有口吻与微习惯。")),
		"scene_setting": str(overrides.get("scene_setting", stage_data.get("scene_setting", "手机即时通讯。"))),
		"important_notes": str(overrides.get("important_notes", stage_data.get("important_notes", "不得越过当前关系阶段。"))),
		"story_time": str(overrides.get("story_time", "2026年7月16日 星期四，下午，时间：15:00")),
		"weather": str(overrides.get("weather", "")),
		"mood_desc": str(overrides.get("mood_desc", "【角色当前整体心情】：\n平静")),
		"memory_desc": str(overrides.get("memory_desc", "")),
		"location_context": str(overrides.get("location_context", "")),
		"dynamic_style": str(overrides.get("dynamic_style", SINGLE_STYLE))
	}
	return context


static func build_prompt(context: Dictionary) -> String:
	var template := _read_text(TEMPLATE_PATH)
	var world := _load_world()
	var scene_setting := str(context.get("scene_setting", ""))
	var location_context := str(context.get("location_context", "")).strip_edges()
	if not location_context.is_empty():
		scene_setting += "\n【测试地点补充】：%s" % location_context
	return template.format({
		"name": context.get("character_name", context.get("character_id", "角色")),
		"age": str(context.get("age", 22)),
		"player_name": context.get("player_name", "老师"),
		"world_setting": "【世界观背景】：\n%s" % world if not world.is_empty() else "",
		"identity_background": "【角色身份背景】：\n%s" % str(context.get("identity_background", "")),
		"intimacy": str(context.get("intimacy", 0)),
		"trust": str(context.get("trust", 0)),
		"flavor": context.get("flavor", "防备疏离"),
		"stage_title": context.get("stage_title", "初遇"),
		"stage_desc": context.get("stage_desc", ""),
		"trust_desc": context.get("trust_desc", ""),
		"personality_traits": context.get("personality_traits", ""),
		"micro_habits": context.get("micro_habits", ""),
		"scene_setting": scene_setting,
		"important_notes": context.get("important_notes", ""),
		"time": context.get("story_time", ""),
		"weather": context.get("weather", ""),
		"mood_desc": context.get("mood_desc", ""),
		"memory_desc": context.get("memory_desc", ""),
		"dynamic_style": context.get("dynamic_style", SINGLE_STYLE)
	})


static func build_request(mode: String, context: Dictionary, history: Array, player_text: String = "", call_incoming := false, is_video := false) -> Dictionary:
	var messages: Array[Dictionary] = [{"role": "system", "content": build_prompt(context)}]
	if mode == "call_proactive":
		var call_type := "视频通话" if is_video else "语音通话"
		var scenario := "你刚刚主动给玩家打了一个%s，玩家刚刚接通了。" % call_type if call_incoming else "玩家刚刚给你打了一个%s，你接通了。" % call_type
		messages.append({"role": "user", "content": "【系统提示：%s请先用自然口吻说第一句话，只输出台词。】" % scenario})
	elif mode == "call_followup":
		messages.append_array(_map_call_history(history))
	else:
		messages.append_array(_map_text_history(history))
	return {
		"mode": mode,
		"player_text": _processed_player_text(player_text),
		"messages": messages,
		"persistent_history_writes": [],
		"network_requested": false
	}


static func parse_response(response: Variant) -> Dictionary:
	var diagnostics: Array[Dictionary] = []
	if not response is Dictionary:
		return {"ok": false, "raw_content": "", "parts": [], "history_records": [], "diagnostics": [{"severity": "error", "message": "响应必须是 JSON 对象。"}]}
	var choices_value: Variant = (response as Dictionary).get("choices")
	if not choices_value is Array or (choices_value as Array).is_empty() or not (choices_value as Array)[0] is Dictionary:
		return {"ok": false, "raw_content": "", "parts": [], "history_records": [], "diagnostics": [{"severity": "error", "message": "响应缺少 choices[0]。"}]}
	var message := ((choices_value as Array)[0] as Dictionary).get("message", {}) as Dictionary
	var content := str(message.get("content", ""))
	if content.strip_edges().is_empty():
		diagnostics.append({"severity": "error", "message": "AI 回复内容为空。"})
	var split_parts := ChatSplitHelper.merge_incomplete_parentheses(content.split("[SPLIT]"))
	var parts: Array[String] = []
	var action_pattern := RegEx.new()
	action_pattern.compile("(\\(.*?\\)|\\（.*?\\）|\\[.*?\\]|\\【.*?\\】|\\<.*?\\>|\\《.*?\\》|\\{.*?\\}|\\*.*?\\*)")
	for part_value in split_parts:
		var part := str(part_value)
		var clean_part := action_pattern.sub(part, "", true).strip_edges()
		if clean_part.is_empty() and not part.strip_edges().is_empty():
			diagnostics.append({"severity": "warning", "message": "分段仅包含动作或括号内容，运行时会退化为省略号。"})
			clean_part = "..."
		if not clean_part.is_empty():
			parts.append(clean_part)
	if content.contains("\n"):
		diagnostics.append({"severity": "warning", "message": "响应包含换行；生产协议要求使用 [SPLIT]。"})
	if content.length() > 350:
		diagnostics.append({"severity": "warning", "message": "响应超过 350 字，可能不适合手机交互。"})
	var records: Array[Dictionary] = []
	for part in parts:
		records.append({"speaker": "char", "text": part})
	return {"ok": not parts.is_empty() and not content.strip_edges().is_empty(), "raw_content": content, "parts": parts, "history_records": records, "diagnostics": diagnostics}


static func preview(mode: String, overrides: Dictionary, history: Array, player_text: String, response: Variant, call_incoming := false, is_video := false) -> Dictionary:
	var context := build_context(overrides)
	return {"context": context, "request": build_request(mode, context, history, player_text, call_incoming, is_video), "response": parse_response(response)}


static func _map_text_history(history: Array) -> Array[Dictionary]:
	var messages: Array[Dictionary] = []
	for value in history.slice(-10):
		if not value is Dictionary:
			continue
		var entry := value as Dictionary
		var speaker := str(entry.get("speaker", ""))
		var text := str(entry.get("text", entry.get("content", "")))
		var role := "user" if ["player", "user", "system"].has(speaker) else "assistant"
		if str(entry.get("type", "")) == "system":
			text = "【系统提示：%s】" % text
		elif str(entry.get("type", "")) == "red_packet":
			text = "【系统提示：[%s发了一个红包: %s]】" % ["玩家" if ["player", "user"].has(speaker) else "你", text]
		elif text.begins_with("[img]") and text.ends_with("[/img]"):
			text = "【系统提示：[%s发送了一张照片]】" % ("玩家" if ["player", "user"].has(speaker) else "你")
		messages.append({"role": role, "content": text})
	return messages


static func _map_call_history(history: Array) -> Array[Dictionary]:
	var messages: Array[Dictionary] = []
	for value in history.slice(-10):
		if value is Dictionary:
			var entry := value as Dictionary
			messages.append({"role": "user" if ["player", "user"].has(str(entry.get("speaker", ""))) else "assistant", "content": str(entry.get("text", entry.get("content", "")))})
	return messages


static func _processed_player_text(text: String) -> String:
	return "【系统动作：玩家向你发送了一张刚刚拍摄的照片。】" if text.begins_with("[img]") and text.ends_with("[/img]") else text


static func _load_character(character_id: String) -> Dictionary:
	for root in CHARACTER_ROOTS:
		var result := JsonService.load_dictionary(root.path_join(character_id + ".json"))
		if result.get("ok", false):
			return result.get("data", {}) as Dictionary
	return {}


static func _load_stage(character_id: String, stage: int) -> Dictionary:
	for root in CHARACTER_ROOTS:
		var result := JsonService.load_dictionary(root.path_join(character_id + "_stages.json"))
		if not result.get("ok", false):
			continue
		var data := result.get("data", {}) as Dictionary
		for value in data.values():
			if value is Array:
				for stage_value in value:
					if stage_value is Dictionary and int((stage_value as Dictionary).get("stage", (stage_value as Dictionary).get("stageNum", 0))) == stage:
						return stage_value as Dictionary
	return {}


static func _load_world() -> String:
	var result := JsonService.load_dictionary(WORLD_PATH)
	return str((result.get("data", {}) as Dictionary).get("world_background", "")) if result.get("ok", false) else ""


static func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	return file.get_as_text() if file != null else ""


static func _relationship_description(intimacy: float, trust: float) -> String:
	return "【关系数值解释】：亲密度 %.1f，信任度 %.1f；必须以当前阶段边界为最高约束。" % [intimacy, trust]