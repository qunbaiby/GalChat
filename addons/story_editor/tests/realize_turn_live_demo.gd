extends SceneTree

const PLAYER_TEXT := "今天有点累，但又不想这么早睡。你愿意陪我聊一会儿吗？"
const TIMEOUT_SECONDS := 90.0

var _client: Node
var _finished := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== RealizeTurn 真实模拟对话 ===")
	print("玩家：%s" % PLAYER_TEXT)
	print("正在恢复官方 AI 会话并生成回复...")
	var auth_manager := get_root().get_node_or_null("OfficialAuthManager")
	if auth_manager == null or not await auth_manager.ensure_valid_access_token():
		_finish_failed("官方 AI 登录会话无法恢复，请先在游戏中重新登录。")
		return
	var client_script: GDScript = load("res://scripts/api/deepseek_client.gd")
	if client_script == null or not client_script.can_instantiate():
		_finish_failed("DeepSeekClient 无法加载。")
		return
	_client = client_script.new()
	_client.name = "LiveDemoDeepSeekClient"
	get_root().add_child(_client)
	_client.structured_chat_request_completed.connect(_on_raw_candidate_completed)
	_client.realize_turn_completed.connect(_on_turn_completed)
	_client.realize_turn_failed.connect(_on_turn_failed)
	_client.send_realize_turn_message(PLAYER_TEXT, "main_chat", {
		"channel": "terminal_live_demo",
		"additional_authoritative_context": "这是一轮终端真实模拟。角色与玩家正在安静的室内相处，可以自然回应玩家的疲惫和陪伴请求。"
	})
	await create_timer(TIMEOUT_SECONDS).timeout
	if not _finished:
		_finish_failed("真实请求等待超时。")


func _on_raw_candidate_completed(response: Dictionary, context: Dictionary) -> void:
	var choices: Array = response.get("choices", [])
	if choices.is_empty() or not choices[0] is Dictionary:
		return
	var message: Dictionary = choices[0].get("message", {})
	var content := str(message.get("content", ""))
	var validator_script: GDScript = load("res://scripts/api/chat_realize_turn_validator.gd")
	var validation: Dictionary = validator_script.new().validate(content)
	if bool(validation.get("ok", false)):
		return
	var parsed: Variant = JSON.parse_string(content)
	var turn_result: Dictionary = parsed.get("turn_result", {}) if parsed is Dictionary else {}
	var beats: Array = turn_result.get("interaction_beats", []) if turn_result.get("interaction_beats", []) is Array else []
	print("候选 %d 验收错误：%s" % [int(context.get("attempt", 0)), ", ".join(validation.get("issue_codes", []))])
	print("  摘要类型：addressed=%s response=%s change=%s" % [
		type_string(typeof(turn_result.get("player_input_addressed"))),
		type_string(typeof(turn_result.get("character_response"))),
		type_string(typeof(turn_result.get("interaction_change")))
	])
	for index in range(beats.size()):
		var beat: Dictionary = beats[index] if beats[index] is Dictionary else {}
		print("  beat_%d 文本类型：change=%s contribution=%s" % [
			index + 1,
			type_string(typeof(beat.get("interaction_change"))),
			type_string(typeof(beat.get("speech_contribution")))
		])


func _on_turn_completed(realized_turn: Dictionary, context: Dictionary) -> void:
	if _finished:
		return
	_finished = true
	var turn_result: Dictionary = realized_turn.get("turn_result", {})
	print("\n角色回应摘要：%s" % str(turn_result.get("character_response", "")))
	print("互动变化：%s" % str(turn_result.get("interaction_change", "")))
	var segments: Array = realized_turn.get("segments", [])
	for index in range(segments.size()):
		var segment: Dictionary = segments[index]
		var action: Dictionary = segment.get("action", {})
		print("\n--- 分段 %d / %s ---" % [index + 1, str(segment.get("beat_id", ""))])
		print("动作：%s" % str(action.get("description", "")))
		print("台词：%s" % str(segment.get("speech", "")))
		print("语音指令：%s" % str(segment.get("delivery_instruction", "")))
		var persistent_effect: Variant = action.get("persistent_effect")
		if persistent_effect is Dictionary:
			print("持续效果：%s" % str(persistent_effect.get("description", "")))
	print("\n验收尝试次数：%d" % int(context.get("accepted_attempt", 1)))
	print("REALIZE_TURN_LIVE_DEMO_OK")
	quit(0)


func _on_turn_failed(error_message: String, context: Dictionary) -> void:
	if _finished:
		return
	var attempt := int(context.get("attempt", 0))
	var issue_codes: Array = context.get("retry_issue_codes", [])
	_finish_failed("%s（尝试次数：%d，最终错误码：%s）" % [error_message, attempt, ", ".join(issue_codes)])


func _finish_failed(message: String) -> void:
	if _finished:
		return
	_finished = true
	push_error("REALIZE_TURN_LIVE_DEMO_FAILED: %s" % message)
	quit(1)