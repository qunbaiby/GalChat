extends SceneTree

const GuidedAiPromptBuilder = preload("res://scripts/dialogue/guided_ai_prompt_builder.gd")
const GuidedAiResponseParser = preload("res://scripts/dialogue/guided_ai_response_parser.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var story_text := FileAccess.get_file_as_string("res://assets/data/story/scripts/main/jing_piano_practice_followup.json")
	var story_data: Variant = JSON.parse_string(story_text)
	_expect(story_data is Dictionary, "无法解析专项辅导主线。")
	if story_data is Dictionary:
		var events: Array = (((story_data as Dictionary).get("chapters", {}) as Dictionary).get("start", {}) as Dictionary).get("events", [])
		var guided_event: Dictionary = {}
		for event_value in events:
			if event_value is Dictionary and str((event_value as Dictionary).get("type", "")) == "guided_ai_chat":
				guided_event = event_value as Dictionary
				break
		_expect(int(guided_event.get("max_player_rounds", 0)) == 5, "调整后的专项辅导主线不再是 5 个玩家回合。")
		_expect((guided_event.get("fallback_options", []) as Array).size() >= 8, "专项辅导主线没有为全部玩家回合准备足够的备用选项。")
		var prompt_result := GuidedAiPromptBuilder.build_user_message(guided_event, [], 0, 5, "（玩家尚未发言）", true)
		var prompt := str(prompt_result.get("prompt", ""))
		_expect(prompt.contains("至少 12 个汉字"), "Guided AI Prompt 没有动作长度约束。")
		_expect(prompt.contains("两个以上可观察细节"), "Guided AI Prompt 没有动作细节约束。")
		_expect(prompt.contains("玩家不是静老师") and prompt.contains("绝不能对玩家使用‘静老师’称呼"), "专项辅导主线没有明确隔离玩家与静老师的身份。")

	var short_response := GuidedAiResponseParser.parse_response("{\"dialogue\":\"（点头）我知道了。\",\"beat_evaluations\":[]}", [])
	_expect(bool(short_response.get("ok", false)), "动作较短但结构合法的回复被误判为生成失败。")
	var detailed_response := GuidedAiResponseParser.parse_response("{\"dialogue\":\"（她把画稿轻轻拢到身前，抬眼时眉间仍有一点犹豫）我知道了。\",\"beat_evaluations\":[]}", [])
	_expect(bool(detailed_response.get("ok", false)), "细腻动作被错误拒绝。")
	_expect(GuidedAiResponseParser.recover_dialogue("（她轻轻按住画稿）我愿意继续聊。") == "（她轻轻按住画稿）我愿意继续聊。", "校验耗尽后无法采纳模型返回的纯文本台词。")
	var broken_json := "{\"dialogue\":\"（她抬手整理好画稿）我会认真参加周六的辅导。\",\"beat_evaluations\":["
	_expect(GuidedAiResponseParser.recover_dialogue(broken_json) == "（她抬手整理好画稿）我会认真参加周六的辅导。", "校验耗尽后无法从破损 JSON 恢复 dialogue。")
	_expect(GuidedAiResponseParser.recover_dialogue("{\"beat_evaluations\":[]") == "", "不可恢复 JSON 被错误当作角色台词展示。")

	var manager_source := FileAccess.get_file_as_string("res://scripts/dialogue/dialogue_manager.gd")
	var client_source := FileAccess.get_file_as_string("res://scripts/api/deepseek_client.gd")
	_expect(manager_source.contains("host.call(\"_report_guide_action\", \"select_main_chat_topic\")"), "Guided AI 实际启动时没有补推进回合引导。")
	_expect(not manager_source.contains("func _accept_guided_ai_continuity_fallback() -> void:"), "Guided AI 仍会用本地伪回复掩盖真实生成失败。")
	_expect(manager_source.contains("_guided_ai_request_retry_count >= GUIDED_AI_MAX_RETRIES"), "Guided AI 网络失败没有自动重试上限。")
	_expect(manager_source.contains("_guided_ai_parse_retry_count >= GUIDED_AI_MAX_RETRIES"), "Guided AI 格式失败没有自动重试上限。")
	_expect(manager_source.contains("stage=validation_exhausted_adopted"), "Guided AI 校验耗尽后没有降级采纳真实模型台词。")
	_expect(manager_source.contains('"turn_started_at_ms": _guided_ai_turn_started_at_ms,\n\t\t\t\t"force_text_response": true'), "Guided AI 首请求仍使用会返回全空白内容的 JSON 传输模式。")
	_expect(manager_source.contains('provider_content_empty := failure_stage == "provider_content"') and manager_source.contains('retry_metadata["force_text_response"] = true'), "Guided AI 遇到 provider 空白内容后仍重复使用故障 JSON 传输模式。")
	_expect(manager_source.contains("<待修复响应>") and manager_source.contains("_guided_ai_last_raw_response.left(4000)"), "Guided AI 格式重试没有基于原始响应执行模型端结构修复。")
	_expect(manager_source.contains("【重新生成任务】") and manager_source.contains("必须完全舍弃") and manager_source.contains("GUIDED_AI_REGENERATION_TEMPERATURE := 0.75"), "Guided AI 检出语义重复后仍在低温修补并保留原回复。")
	_expect(manager_source.contains('"turn_started_at_ms": _guided_ai_turn_started_at_ms,\n\t\t"force_text_response": true'), "Guided AI 结构或重复重试重新启用了故障 JSON 传输模式。")
	_expect(manager_source.contains("GUIDED_AI_INITIAL_TEMPERATURE := 0.6") and manager_source.contains("GUIDED_AI_FIRST_REPAIR_TEMPERATURE := 0.25") and manager_source.contains("GUIDED_AI_LATER_REPAIR_TEMPERATURE := 0.15"), "Guided AI 没有按首次创作与后续结构修复使用分阶段温度。")
	_expect(manager_source.contains("_guided_ai_reply_overlap(normalized, used_reply) >= 0.5"), "Guided AI 仍只能识别逐字完全相同的回复，无法拦截换动作或少量改写的重复内容。")
	_expect(manager_source.contains("_guided_ai_reply_has_duplicate_segment(reply, used_reply)") and manager_source.contains("normalized_used_reply.contains(normalized_segment)") and manager_source.contains("_guided_ai_reply_overlap(normalized_segment, normalized_used_reply) >= 0.72"), "Guided AI 没有逐气泡拦截被整段平均相似度掩盖的重复回复。")
	_expect(manager_source.contains("if normalized.length() < 12:") and manager_source.contains("used_reply.length() >= 12"), "Guided AI 语义重复检测没有排除容易误判的短回复。")
	_expect(manager_source.contains("free_chat_current_round >= free_chat_max_rounds:\n\t\t_set_chat_closing_input_state()\n\t\treturn"), "Guided AI 发送入口没有硬性阻止超出最大回合的输入。")
	_expect(manager_source.contains('"next_options 必须是空数组。" if _guided_ai_close_after_reply or _guided_ai_closing_started'), "Guided AI 收束轮结构修复仍错误要求生成下一轮选项。")
	_expect(manager_source.contains("func _resume_guided_ai_after_request_failure() -> void:") and manager_source.contains("pending_options_data = _build_guided_ai_fallback_options()"), "Guided AI 请求耗尽后会结束剧情而不是恢复当前会话。")
	_expect(manager_source.contains("GUIDED_AI_EMERGENCY_OPTIONS") and manager_source.contains("AI 服务繁忙，已恢复当前对话。"), "Guided AI 限流或缺少剧情备用项时仍可能阻断会话。")
	_expect(manager_source.contains("func _set_chat_closing_input_state() -> void:") and manager_source.contains("dialogue_panel.set_input_waiting_state"), "AI 对话请求结束语时没有保留并禁用输入区。")
	_expect(not manager_source.contains("func _begin_guided_ai_closing() -> void:\n") or not manager_source.contains("_guided_ai_close_after_reply = false\n\tif input_layer:\n\t\tinput_layer.hide()"), "Guided AI 正常收束仍会隐藏输入区。")
	_expect(client_source.contains("json_mode=%s"), "Guided AI 请求日志没有暴露 JSON 模式，协议回归难以及时定位。")
	var dialogue_manager_script := load("res://scripts/dialogue/dialogue_manager.gd") as GDScript
	var duplicate_probe = dialogue_manager_script.new()
	var previous_reply := "（指尖轻轻抚过琴键边缘，她垂下眼帘）我最担心静老师会不会觉得我太慢热。[SPLIT]（她忽然抬头，目光里带着一点认真的光）不过既然哥哥愿意陪我练，我就当是提前适应了。周六的辅导，我会去的。"
	var repeated_second_bubble := "（她低头看着琴谱，声音里带着一丝迟疑）我怕准备得不够充分，让静老师失望。[SPLIT]（她忽然抬头，目光里带着一点认真的光）不过既然哥哥愿意陪我练，我就当是提前适应了。周六的辅导，我会去的。"
	_expect(duplicate_probe._register_guided_ai_reply(previous_reply), "Guided AI 重复检测夹具无法登记首条回复。")
	_expect(duplicate_probe._is_duplicate_guided_ai_reply(repeated_second_bubble), "Guided AI 没有拦截第一气泡改写、第二气泡复读的真实重复模式。")
	duplicate_probe.free()

	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("GUIDED_AI_RESILIENCE_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)