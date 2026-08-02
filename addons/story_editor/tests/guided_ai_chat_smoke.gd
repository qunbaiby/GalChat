extends SceneTree

const EditorMain = preload("res://addons/story_editor/ui/story_editor_main.gd")
const EventInspector = preload("res://addons/story_editor/ui/story_event_inspector.gd")
const StoryValidator = preload("res://addons/story_editor/core/story_validator.gd")
const JsonService = preload("res://addons/story_editor/core/story_json_service.gd")
const ScriptEngine = preload("res://scripts/script_engine/script_engine_manager.gd")
const GuidedAiResponseParser = preload("res://scripts/dialogue/guided_ai_response_parser.gd")
const GuidedAiRequestGuard = preload("res://scripts/dialogue/guided_ai_request_guard.gd")
const GuidedAiRoundPolicy = preload("res://scripts/dialogue/guided_ai_round_policy.gd")
const GuidedAiPromptBuilder = preload("res://scripts/dialogue/guided_ai_prompt_builder.gd")
const ChatSplitHelper = preload("res://scripts/utils/chat_split_helper.gd")

var failures: Array[String] = []
var received_policy: Dictionary = {}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_expect(EditorMain.CREATE_EVENT_TYPES.has("guided_ai_chat"), "创建菜单缺少 guided_ai_chat。")
	_expect(EditorMain.EVENT_DEFAULTS.has("guided_ai_chat"), "guided_ai_chat 缺少默认事件。")
	_expect(EventInspector.EVENT_TYPES.has("guided_ai_chat"), "Inspector 类型列表缺少 guided_ai_chat。")
	_expect(EventInspector.EVENT_SCHEMAS.has("guided_ai_chat"), "Inspector 缺少 guided_ai_chat 字段 schema。")

	var story_result := JsonService.load_dictionary("res://assets/data/story/scripts/main/jing_piano_practice_followup.json")
	_expect(bool(story_result.get("ok", false)), "无法加载首个引导式 AI 主线脚本。")
	var story_data: Dictionary = story_result.get("data", {})
	var diagnostics := StoryValidator.validate(story_data)
	_expect(not _has_errors(diagnostics), "首个引导式 AI 主线脚本未通过校验。")
	var story_events: Array = ((story_data.get("chapters", {}) as Dictionary).get("start", {}) as Dictionary).get("events", [])
	var guided_story_event: Dictionary = {}
	for story_event_value in story_events:
		if story_event_value is Dictionary and str((story_event_value as Dictionary).get("type", "")) == "guided_ai_chat":
			guided_story_event = story_event_value as Dictionary
			break
	_expect(int(guided_story_event.get("max_player_rounds", 0)) == 5, "首个 AI 主线没有配置为 5 个玩家回合。")
	_expect(int(story_data.get("action_cost", -1)) == 0, "目标引导后的整段固定剧情不应消耗精力。")
	_expect(int(story_data.get("game_minutes", 0)) == 60, "整段固定剧情时间推进不是 60 分钟。")
	_expect(not guided_story_event.has("action_cost") and not guided_story_event.has("game_minutes"), "Guided AI 事件仍持有整剧成本字段。")
	var guided_schema: Array = EventInspector.EVENT_SCHEMAS.get("guided_ai_chat", [])
	_expect(not _schema_has_field(guided_schema, "action_cost") and not _schema_has_field(guided_schema, "game_minutes"), "Guided AI Inspector 仍暴露整剧成本字段。")
	_expect(bool(guided_story_event.get("hide_manual_end", false)), "首个 AI 主线应由回合耗尽自然收尾，不能手动提前结束。")
	_expect(not bool(guided_story_event.get("allow_early_completion", true)), "首个 AI 主线不应在剧情点提前覆盖后提前结束。")
	var fallback_closing_text := str(guided_story_event.get("fallback_closing_text", ""))
	var fallback_display_text := ChatSplitHelper.format_actions(fallback_closing_text)
	_expect(fallback_display_text.contains("[color=green]（她轻轻抱紧怀里的琴谱，低头看了片刻，又抬起眼认真望向你）[/color]"), "guided AI fallback 收尾动作没有使用统一绿色格式。")
	_expect(not story_events.is_empty() and not bool((story_events.back() as Dictionary).get("auto_advance", false)), "AI 主线结尾固定旁白仍会自动结束，玩家来不及阅读。")
	var guided_prompt_result: Dictionary = GuidedAiPromptBuilder.build_user_message(guided_story_event, [], 1, 4, "我会陪着你。")
	_expect(str(guided_prompt_result.get("prompt", "")).contains("必须至少包含一处使用全角圆括号包裹"), "guided AI prompt 没有强制圆括号动作契约。")
	var used_option_prompt_result: Dictionary = GuidedAiPromptBuilder.build_user_message_with_used_options(guided_story_event, [], 2, 4, "我会陪着你。", ["你最担心什么？"])
	_expect(str(used_option_prompt_result.get("prompt", "")).contains("你最担心什么？"), "Guided AI Prompt 没有告知模型已使用选项，后续轮次可能重复生成。")
	var opening_prompt_result: Dictionary = GuidedAiPromptBuilder.build_user_message(guided_story_event, [], 0, 4, "（玩家尚未发言，请由角色主动开始这段对话。）", true)
	_expect(str(opening_prompt_result.get("prompt", "")).contains("这是角色主动开场，玩家尚未发言"), "guided AI 没有生成角色主动开场 Prompt。")
	_expect(str(opening_prompt_result.get("prompt", "")).contains("本轮之后剩余玩家回合：4"), "角色主动开场错误消耗了玩家回合。")
	var invalid_guided_response := GuidedAiResponseParser.parse_response("这不是 JSON", ["confirm"])
	_expect(not bool(invalid_guided_response.get("ok", true)), "guided AI 非 JSON 响应没有返回可控解析错误。")
	var wrapped_guided_response := GuidedAiResponseParser.parse_response("回复如下：{\"dialogue\":\"（她把手边的画稿慢慢拢好，抬起眼认真望向你）我明白。\",\"beat_evaluations\":[]}", ["confirm"])
	_expect(bool(wrapped_guided_response.get("ok", false)), "guided AI 无法从包裹文本中提取 JSON 对象。")
	var short_action_response := GuidedAiResponseParser.parse_response("{\"dialogue\":\"（点头）我明白。\",\"beat_evaluations\":[]}", ["confirm"])
	_expect(bool(short_action_response.get("ok", false)), "guided AI 把动作较短但结构合法的回复误判为生成失败。")
	var missing_options_response := GuidedAiResponseParser.parse_response_with_required_options("{\"dialogue\":\"（她轻轻按住琴谱，抬眼认真望向你）我会继续说下去。\",\"beat_evaluations\":[],\"next_options\":[]}", [])
	_expect(not bool(missing_options_response.get("ok", true)), "非收束轮缺少模型选项时被错误采用，可能静默使用本地兜底。")

	var event_data := (EditorMain.EVENT_DEFAULTS["guided_ai_chat"] as Dictionary).duplicate(true)
	event_data["narrative_anchor"] = "已发生的剧情事实"
	event_data["scene_objective"] = "完成本轮剧情交流"
	event_data["required_beats"] = [{"id": "confirm", "instruction": "确认约定"}]
	var engine := ScriptEngine.new()
	root.add_child(engine)
	engine.on_guided_ai_chat_requested.connect(func(policy: Dictionary): received_policy = policy.duplicate(true))
	_expect(engine.load_script_data({
		"script_id": "guided_ai_chat_smoke",
		"chapters": {"start": {"events": [event_data]}}
	}), "ScriptEngine 无法加载 guided_ai_chat。")
	engine.start_script()
	_expect(str(received_policy.get("session_id", "")) == "guided_story_chat", "运行时没有收到完整 guided policy。")
	_expect(engine.is_waiting_for_resume, "guided_ai_chat 没有阻塞剧情推进。")
	_expect(engine.is_guided_ai_blocked, "guided_ai_chat 没有启用专属完成锁。")
	var blocked_event_index := engine.current_event_index
	engine.resume()
	_expect(engine.current_event_index == blocked_event_index and engine.is_waiting_for_resume, "通用 resume 错误越过了 guided_ai_chat。")
	engine.complete_guided_ai_chat()
	_expect(not engine.is_guided_ai_blocked, "guided_ai_chat 显式完成后没有解除专属锁。")
	var continuation_engine := ScriptEngine.new()
	root.add_child(continuation_engine)
	var continuation_dialogues: Array[String] = []
	continuation_engine.on_dialogue_requested.connect(func(_speaker: String, content: String, _mood: String, _presentation: Dictionary): continuation_dialogues.append(content))
	_expect(continuation_engine.load_script_data({
		"script_id": "guided_ai_continuation",
		"chapters": {"start": {"events": [event_data, {"type": "dialogue", "speaker": "旁白", "content": "AI 后固定旁白"}]}}
	}), "ScriptEngine 无法加载 Guided AI 后续固定对话回归脚本。")
	continuation_engine.start_script()
	continuation_engine.complete_guided_ai_chat()
	_expect(continuation_dialogues == ["AI 后固定旁白"], "Guided AI 完成后没有播放后续固定对话。")
	_expect(continuation_engine.is_running and continuation_engine.is_waiting_for_resume, "后续固定对话尚未确认时脚本已经结束。")
	continuation_engine.resume()
	_expect(not continuation_engine.is_running, "确认后续固定对话后脚本没有正常结束。")
	continuation_engine.queue_free()
	var ending_engine := ScriptEngine.new()
	root.add_child(ending_engine)
	var finish_signal_state := {"count": 0}
	ending_engine.script_finished.connect(func(_script_id: String): finish_signal_state["count"] = int(finish_signal_state["count"]) + 1)
	_expect(ending_engine.load_script_data({
		"script_id": "jump_end_once",
		"chapters": {"start": {"events": [{"type": "jump", "target_chapter": "end"}]}}
	}), "ScriptEngine 无法加载 jump end 回归脚本。")
	ending_engine.start_script()
	await process_frame
	_expect(int(finish_signal_state["count"]) == 1, "jump end 没有恰好发出一次 script_finished，可能导致行程剧情重播。")
	ending_engine.queue_free()

	var parsed_response := GuidedAiResponseParser.parse_response(JSON.stringify({
		"dialogue": "（她握紧怀里的琴谱，视线在封面停了片刻才重新望向你）我很期待周六的辅导。[SPLIT]但也担心自己表现不好。",
		"next_options": [
			{"text": "你最期待哪一部分？", "focus": "intimacy"},
			{"text": "还有什么让你担心？", "focus": "trust"}
		],
		"beat_evaluations": [
			{"id": "expectation", "covered": true, "evidence": "我很期待周六的辅导"},
			{"id": "concern", "covered": true, "evidence": "并未出现在台词中的伪造证据"},
			{"id": "unknown", "covered": true, "evidence": "担心自己表现不好"}
		]
	}), ["expectation", "concern"])
	_expect(bool(parsed_response.get("ok", false)), "合法结构化 AI 回复无法解析。")
	_expect(str(parsed_response.get("dialogue", "")).contains("[SPLIT]"), "结构化解析丢失角色台词。")
	_expect(parsed_response.get("covered_beat_ids", []) == ["expectation"], "结构化解析接受了伪造 evidence 或未知剧情点。")
	_expect((parsed_response.get("next_options", []) as Array).size() == 2, "结构化解析没有保留同请求返回的下一轮选项。")
	_expect(GuidedAiResponseParser.has_parenthetical_action(str(parsed_response.get("dialogue", ""))), "结构化回复没有识别全角圆括号动作。")
	_expect(not GuidedAiResponseParser.has_parenthetical_action("我很期待周六的辅导。"), "纯台词被错误识别为括号动作。")
	var formatted_actions: String = ChatSplitHelper.format_leading_action("（握紧琴谱）我会认真准备。(轻轻点头)")
	_expect(formatted_actions.contains("[color=green]（握紧琴谱）[/color]"), "全角括号动作没有使用统一绿色格式。")
	_expect(formatted_actions.contains("[color=green](轻轻点头)[/color]"), "半角括号动作没有使用统一绿色格式。")
	_expect(formatted_actions.contains("我会认真准备。"), "统一动作格式化错误删除了角色台词。")
	var repaired_parts := ChatSplitHelper.merge_incomplete_parentheses(["（她按住画稿，抬眼望向你", "我会认真准备。"])
	_expect(repaired_parts.size() == 1 and str(repaired_parts[0]).ends_with("）"), "AI 对白末尾未闭合的全角括号没有自动补齐。")
	var dialogue_manager_source := FileAccess.get_file_as_string("res://scripts/dialogue/dialogue_manager.gd")
	_expect(dialogue_manager_source.contains("_prepare_story_cost_settlement()"), "固定剧情启动前没有统一结算根级成本。")
	_expect(dialogue_manager_source.contains("_settle_completed_story_time(script_meta)"), "固定剧情完成后没有统一推进根级时间。")
	_expect(dialogue_manager_source.contains("_guided_ai_reply_playback_active"), "Guided AI 缺少回复播放互斥锁。")
	_expect(dialogue_manager_source.contains("_refresh_guided_ai_round_guide_when_ready(host)"), "回合卡显示后没有再次刷新新手引导。")
	_expect(dialogue_manager_source.contains("_guided_ai_used_option_texts.has(option_text)"), "Guided AI 没有过滤已选择过的重复选项。")
	_expect(dialogue_manager_source.contains("_is_duplicate_guided_ai_reply(reply)"), "Guided AI 没有在采用前拒绝会话内重复回复。")
	_expect(dialogue_manager_source.contains('error_message.contains("429")'), "Guided AI 遇到 429 后仍可能立即连续重试。")
	_expect(dialogue_manager_source.contains("_resume_guided_ai_after_request_failure()"), "Guided AI 请求耗尽后没有保留当前 AI 会话。")
	_expect(dialogue_manager_source.contains('"trace_source": "guided_ai_chat",\n\t\t\t\t"turn_started_at_ms": _guided_ai_turn_started_at_ms,\n\t\t\t\t"force_text_response": true'), "Guided AI 首请求仍使用会返回全空白内容的 JSON 传输模式。")
	_expect(dialogue_manager_source.contains("if not is_system_event and is_free_chat_mode:\n\t\tfree_chat_current_round += 1"), "玩家自由输入没有在统一发送入口计入回合。")
	_expect(dialogue_manager_source.contains("func _on_quick_option_selected") and dialogue_manager_source.contains("_on_send_pressed()"), "AI 选项没有复用玩家发送入口，可能导致重复或遗漏计数。")
	_expect(dialogue_manager_source.contains('await _show_message_async(fallback_display_text, GameDataManager.profile.char_name, false, "", "", "", true)'), "Guided AI 本地收束对白仍会等待点击并阻断剧情。")
	var dialogue_event_source := FileAccess.get_file_as_string("res://scripts/script_engine/events/event_dialogue.gd")
	_expect(dialogue_event_source.contains('"auto_advance": data.get("auto_advance", false)'), "固定对白事件没有向播放层传递自动推进配置。")
	var schedule_source := FileAccess.get_file_as_string("res://scripts/ui/activity/schedule_execution_panel.gd")
	_expect(schedule_source.contains("_started_story_event_keys.has(event_id)"), "活动主线事件缺少执行周期内的原子去重锁。")
	var round_policy := GuidedAiRoundPolicy.new()
	for round_number in range(1, 4):
		_expect(not round_policy.should_close_after_round(round_number, 4), "guided AI 在第 %d 轮错误提前结束。" % round_number)
	_expect(round_policy.should_close_after_round(4, 4), "guided AI 第 4 轮后没有进入收尾。")
	var fenced_response := GuidedAiResponseParser.parse_response("```json\n{\"dialogue\":\"（她把画稿轻轻放回桌面，又抬起眼认真望向你）确认约定\",\"beat_evaluations\":[{\"id\":\"confirm\",\"covered\":true,\"evidence\":\"确认约定\"}]}\n```", ["confirm"])
	_expect(bool(fenced_response.get("ok", false)) and fenced_response.get("covered_beat_ids", []) == ["confirm"], "结构化解析无法兼容 JSON 代码围栏。")
	var strict_response := GuidedAiResponseParser.parse_response(JSON.stringify({
		"dialogue": "（她的指尖沿着画稿边缘停下，肩膀也随着呼吸慢慢放松）我很期待\t周六的辅导，也会认真准备。",
		"beat_evaluations": [
			{"id": "expectation", "covered": "false", "evidence": "我很期待 周六的辅导"},
			{"id": "confirmation", "covered": true, "evidence": "也会认真准备"}
		]
	}), ["expectation", "confirmation"])
	_expect(strict_response.get("covered_beat_ids", []) == ["confirmation"], "结构化解析接受了字符串布尔值。")
	var whitespace_response := GuidedAiResponseParser.parse_response(JSON.stringify({
		"dialogue": "（她轻轻抚平画稿上的折角，抬眼时目光比刚才坚定许多）我很期待　周六的辅导。",
		"beat_evaluations": [{"id": "expectation", "covered": true, "evidence": "我很期待 周六的辅导"}]
	}), ["expectation"])
	_expect(whitespace_response.get("covered_beat_ids", []) == ["expectation"], "结构化解析没有统一全角空格。")
	_expect(not bool(GuidedAiResponseParser.parse_response("not json", ["confirm"]).get("ok", false)), "结构化解析没有拒绝非法 JSON。")
	var current_request := {"session_id": "session_new", "request_id": 12, "request_kind": "normal"}
	_expect(GuidedAiRequestGuard.matches("session_new", 12, false, current_request), "当前 guided 请求上下文没有通过匹配。")
	_expect(not GuidedAiRequestGuard.matches("session_new", 12, false, {"session_id": "session_old", "request_id": 12, "request_kind": "normal"}), "旧 session 响应没有被拒绝。")
	_expect(not GuidedAiRequestGuard.matches("session_new", 12, false, {"session_id": "session_new", "request_id": 11, "request_kind": "normal"}), "旧 request 响应没有被拒绝。")
	_expect(not GuidedAiRequestGuard.matches("session_new", 12, true, current_request), "normal 响应在 closing 阶段没有被拒绝。")

	var invalid_event := event_data.duplicate(true)
	invalid_event["max_player_rounds"] = 0
	invalid_event["required_beats"] = [
		{"id": "duplicate", "instruction": "A"},
		{"id": "duplicate", "instruction": "B"},
		{"id": "missing_instruction", "instruction": ""}
	]
	invalid_event["outcome_branches"] = {"unknown": "end"}
	var invalid_diagnostics := StoryValidator.validate({
		"script_id": "invalid_guided_ai_chat",
		"chapters": {"start": {"events": [invalid_event]}}
	})
	_expect(_has_errors(invalid_diagnostics), "Validator 没有拒绝非法回合、剧情点或结果分支。")
	var legacy_cost_event := event_data.duplicate(true)
	legacy_cost_event["game_minutes"] = 30
	legacy_cost_event["action_cost"] = 10
	var legacy_cost_diagnostics := StoryValidator.validate({
		"script_id": "legacy_guided_ai_cost",
		"chapters": {"start": {"events": [legacy_cost_event]}}
	})
	_expect(_has_errors(legacy_cost_diagnostics), "Validator 没有拒绝 Guided AI 事件上的旧成本字段。")

	if failures.is_empty():
		print("GUIDED_AI_CHAT_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("GUIDED_AI_CHAT_SMOKE: %s" % failure)
	quit(1)

func _has_errors(diagnostics: Array[Dictionary]) -> bool:
	for diagnostic in diagnostics:
		if str(diagnostic.get("severity", "")) == "error":
			return true
	return false

func _schema_has_field(schema: Array, field_name: String) -> bool:
	for field_value in schema:
		if field_value is Array and not field_value.is_empty() and str(field_value[0]) == field_name:
			return true
	return false

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)