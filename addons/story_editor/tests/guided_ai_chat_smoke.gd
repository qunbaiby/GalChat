extends SceneTree

const EditorMain = preload("res://addons/story_editor/ui/story_editor_main.gd")
const EventInspector = preload("res://addons/story_editor/ui/story_event_inspector.gd")
const StoryValidator = preload("res://addons/story_editor/core/story_validator.gd")
const JsonService = preload("res://addons/story_editor/core/story_json_service.gd")
const ScriptEngine = preload("res://scripts/script_engine/script_engine_manager.gd")
const GuidedAiResponseParser = preload("res://scripts/dialogue/guided_ai_response_parser.gd")
const GuidedAiRequestGuard = preload("res://scripts/dialogue/guided_ai_request_guard.gd")

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

	var parsed_response := GuidedAiResponseParser.parse_response(JSON.stringify({
		"dialogue": "（握紧琴谱）我很期待周六的辅导。[SPLIT]但也担心自己表现不好。",
		"beat_evaluations": [
			{"id": "expectation", "covered": true, "evidence": "我很期待周六的辅导"},
			{"id": "concern", "covered": true, "evidence": "并未出现在台词中的伪造证据"},
			{"id": "unknown", "covered": true, "evidence": "担心自己表现不好"}
		]
	}), ["expectation", "concern"])
	_expect(bool(parsed_response.get("ok", false)), "合法结构化 AI 回复无法解析。")
	_expect(str(parsed_response.get("dialogue", "")).contains("[SPLIT]"), "结构化解析丢失角色台词。")
	_expect(parsed_response.get("covered_beat_ids", []) == ["expectation"], "结构化解析接受了伪造 evidence 或未知剧情点。")
	var fenced_response := GuidedAiResponseParser.parse_response("```json\n{\"dialogue\":\"确认约定\",\"beat_evaluations\":[{\"id\":\"confirm\",\"covered\":true,\"evidence\":\"确认约定\"}]}\n```", ["confirm"])
	_expect(bool(fenced_response.get("ok", false)) and fenced_response.get("covered_beat_ids", []) == ["confirm"], "结构化解析无法兼容 JSON 代码围栏。")
	var strict_response := GuidedAiResponseParser.parse_response(JSON.stringify({
		"dialogue": "我很期待\t周六的辅导，也会认真准备。",
		"beat_evaluations": [
			{"id": "expectation", "covered": "false", "evidence": "我很期待 周六的辅导"},
			{"id": "confirmation", "covered": true, "evidence": "也会认真准备"}
		]
	}), ["expectation", "confirmation"])
	_expect(strict_response.get("covered_beat_ids", []) == ["confirmation"], "结构化解析接受了字符串布尔值。")
	var whitespace_response := GuidedAiResponseParser.parse_response(JSON.stringify({
		"dialogue": "我很期待　周六的辅导。",
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

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)