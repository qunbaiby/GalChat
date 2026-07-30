extends SceneTree

const VALIDATOR_PATH := "res://scripts/api/chat_realize_turn_validator.gd"

var failures: Array[String] = []


func _initialize() -> void:
	print("REALIZE_TURN_VALIDATOR_SMOKE_STARTED")
	call_deferred("_run")


func _run() -> void:
	var validator_script: GDScript = load(VALIDATOR_PATH)
	_expect(validator_script != null and validator_script.can_instantiate(), "无法加载 RealizeTurn 验证器。")
	if validator_script == null or not validator_script.can_instantiate():
		_finish()
		return
	var validator = validator_script.new()
	var valid_turn := _build_valid_turn()
	_expect(bool(validator.validate(valid_turn).get("ok", false)), "合法 RealizeTurn 被拒绝。")

	var plain_text_result: Dictionary = validator.validate("（抬眼）我会留下。")
	_expect(_has_issue(plain_text_result, "REALIZE_TURN_JSON_INVALID"), "旧式纯文本回复没有被拒绝。")

	var mismatched := valid_turn.duplicate(true)
	mismatched["segments"][0]["beat_id"] = "beat_2"
	_expect(_has_issue(validator.validate(mismatched), "SEGMENT_BEAT_ID_MISMATCH"), "错位 beat_id 没有被拒绝。")

	var player_action := valid_turn.duplicate(true)
	player_action["segments"][0]["action"]["actor_id"] = "player"
	_expect(_has_issue(validator.validate(player_action), "ACTION_ACTOR_INVALID"), "玩家行动权违规没有被拒绝。")

	var staged_speech := valid_turn.duplicate(true)
	staged_speech["segments"][0]["speech"] = "（抬眼）嗯……我会留下。"
	_expect(_has_issue(validator.validate(staged_speech), "SPEECH_STAGE_DIRECTION_INVALID"), "speech 中的舞台说明没有被拒绝。")

	var missing_vocalization := valid_turn.duplicate(true)
	missing_vocalization["segments"][0]["speech"] = "我会留下。"
	_expect(_has_issue(validator.validate(missing_vocalization), "AUDIBLE_VOCALIZATION_MISSING"), "计划拟声未进入 speech 时没有被拒绝。")

	var missing_delivery := valid_turn.duplicate(true)
	missing_delivery["segments"][0]["delivery_instruction"] = "保持成熟贴近的基础声线，句尾稳定收束。"
	_expect(_has_issue(validator.validate(missing_delivery), "AUDIBLE_DELIVERY_MISSING"), "计划拟声未进入表演指令时没有被拒绝。")

	var identity_override := valid_turn.duplicate(true)
	identity_override["segments"][0]["delivery_instruction"] = "换成少女音；“嗯……”闭口轻哼并拖长，随后稳定说出决定。"
	_expect(_has_issue(validator.validate(identity_override), "DELIVERY_IDENTITY_OVERRIDE"), "要求改变角色音色的模型候选没有被拒绝重生成。")
	var contextual_delivery := valid_turn.duplicate(true)
	contextual_delivery["segments"][0]["delivery_instruction"] = "先压住迟疑的气息；“嗯……”闭口轻哼并拖长，承接决定时逐渐加重，句尾稳定落下。"
	_expect(bool(validator.validate(contextual_delivery).get("ok", false)), "根据本轮语境自然生成的动态语音指令被误判为非法。")

	var invalid_effect := valid_turn.duplicate(true)
	invalid_effect["segments"][0]["action"]["persistent_effect"]["target_id"] = "player"
	_expect(_has_issue(validator.validate(invalid_effect), "PERSISTENT_EFFECT_OWNERSHIP_INVALID"), "玩家所有的持续效果没有被拒绝。")

	_finish()


func _build_valid_turn() -> Dictionary:
	return {
		"turn_result": {
			"player_input_addressed": "玩家询问她是否愿意留下。",
			"character_response": "她经过判断后明确选择留下。",
			"interaction_change": "她从犹豫转为稳定地表明立场。",
			"interaction_beats": [{
				"beat_id": "beat_1",
				"interaction_change": "她抬眼确认自己的决定。",
				"felt_response": {
					"physical": "呼吸稍微放缓。",
					"psychological": "犹豫沉淀为确定。",
					"audible": {
						"description": "先轻哼停顿，再稳定说出决定。",
						"vocalizations": [{
							"text": "嗯……",
							"placement_hint": "在表达决定之前。",
							"performance_hint": "闭口轻哼，尾音自然拖长。"
						}]
					}
				},
				"speech_contribution": "明确给出她愿意留下的决定。"
			}]
		},
		"segments": [{
			"beat_id": "beat_1",
			"action": {
				"actor_id": "character",
				"description": "她抬眼看向你。",
				"persistent_effect": {
					"event_type": "stance_change",
					"target_id": "character",
					"status": "completed",
					"description": "她保持抬眼直视你的姿态。"
				}
			},
			"speech": "嗯……我会留下。",
			"delivery_instruction": "保持成熟贴近的基础声线；“嗯……”闭口轻哼并拖长，随后稳定说出决定。"
		}]
	}


func _has_issue(result: Dictionary, issue_code: String) -> bool:
	return (result.get("issue_codes", []) as Array).has(issue_code)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("REALIZE_TURN_VALIDATOR_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("REALIZE_TURN_VALIDATOR_SMOKE: %s" % failure)
	quit(1)