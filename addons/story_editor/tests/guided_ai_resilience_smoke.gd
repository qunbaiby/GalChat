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
		_expect(int(guided_event.get("max_player_rounds", 0)) == 4, "调整后的专项辅导主线不再是 4 个玩家回合。")
		var prompt_result := GuidedAiPromptBuilder.build_user_message(guided_event, [], 0, 4, "（玩家尚未发言）", true)
		var prompt := str(prompt_result.get("prompt", ""))
		_expect(prompt.contains("至少 12 个汉字"), "Guided AI Prompt 没有动作长度约束。")
		_expect(prompt.contains("两个以上可观察细节"), "Guided AI Prompt 没有动作细节约束。")

	var short_response := GuidedAiResponseParser.parse_response("{\"dialogue\":\"（点头）我知道了。\",\"beat_evaluations\":[]}", [])
	_expect(bool(short_response.get("ok", false)), "动作较短但结构合法的回复被误判为生成失败。")
	var detailed_response := GuidedAiResponseParser.parse_response("{\"dialogue\":\"（她把画稿轻轻拢到身前，抬眼时眉间仍有一点犹豫）我知道了。\",\"beat_evaluations\":[]}", [])
	_expect(bool(detailed_response.get("ok", false)), "细腻动作被错误拒绝。")
	_expect(GuidedAiResponseParser.recover_dialogue("（她轻轻按住画稿）我愿意继续聊。") == "（她轻轻按住画稿）我愿意继续聊。", "校验耗尽后无法采纳模型返回的纯文本台词。")
	var broken_json := "{\"dialogue\":\"（她抬手整理好画稿）我会认真参加周六的辅导。\",\"beat_evaluations\":["
	_expect(GuidedAiResponseParser.recover_dialogue(broken_json) == "（她抬手整理好画稿）我会认真参加周六的辅导。", "校验耗尽后无法从破损 JSON 恢复 dialogue。")
	_expect(GuidedAiResponseParser.recover_dialogue("{\"beat_evaluations\":[]") == "", "不可恢复 JSON 被错误当作角色台词展示。")

	var manager_source := FileAccess.get_file_as_string("res://scripts/dialogue/dialogue_manager.gd")
	_expect(manager_source.contains("host.call(\"_report_guide_action\", \"select_main_chat_topic\")"), "Guided AI 实际启动时没有补推进回合引导。")
	_expect(not manager_source.contains("func _accept_guided_ai_continuity_fallback() -> void:"), "Guided AI 仍会用本地伪回复掩盖真实生成失败。")
	_expect(manager_source.contains("_guided_ai_request_retry_count >= GUIDED_AI_MAX_RETRIES"), "Guided AI 网络失败没有自动重试上限。")
	_expect(manager_source.contains("_guided_ai_parse_retry_count >= GUIDED_AI_MAX_RETRIES"), "Guided AI 格式失败没有自动重试上限。")
	_expect(manager_source.contains("stage=validation_exhausted_adopted"), "Guided AI 校验耗尽后没有降级采纳真实模型台词。")

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