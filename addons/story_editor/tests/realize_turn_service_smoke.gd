extends SceneTree

const SERVICE_PATH := "res://scripts/api/chat_realize_turn_service.gd"

var failures: Array[String] = []


class FakeClient extends RefCounted:
	signal structured_chat_request_completed(response: Dictionary, request_context: Dictionary)
	signal structured_chat_request_failed(error_message: String, request_context: Dictionary)

	var next_id: int = 0
	var requests: Array[Dictionary] = []

	func get_history_messages(_limit: int, _is_chat: bool, _history_type: String) -> Array:
		return [
			{"role": "assistant", "content": "上一轮已接受回复。"},
			{"role": "user", "content": "你愿意留下吗？ <--- 【系统提示：这是你们上次聊天的最后一句话，请顺着这个话题继续延展，不要生硬地开启新话题】"}
		]

	func send_structured_messages(messages: Array, context: Dictionary = {}) -> int:
		next_id += 1
		var network_context := context.duplicate(true)
		network_context["network_request_id"] = next_id
		requests.append({"id": next_id, "messages": messages.duplicate(true), "context": network_context})
		return next_id


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var service_script: GDScript = load(SERVICE_PATH)
	_expect(service_script != null and service_script.can_instantiate(), "无法加载 RealizeTurn 编排服务。")
	if service_script == null or not service_script.can_instantiate():
		_finish()
		return
	var service = service_script.new()
	var client := FakeClient.new()
	service.bind_client(client)
	var completed: Array[Dictionary] = []
	var failed: Array[Dictionary] = []
	service.turn_completed.connect(func(turn: Dictionary, context: Dictionary): completed.append({"turn": turn, "context": context}))
	service.turn_failed.connect(func(error: String, context: Dictionary): failed.append({"error": error, "context": context}))

	var context := {
		"authoritative_context": "角色与玩家正在安静交谈。",
		"player_text": "你愿意留下吗？",
		"history_type": "main_chat",
		"recent_messages": [
			{"role": "user", "content": "这是手机渠道的上一句。"},
			{"role": "assistant", "content": "我记得，这是手机渠道的上一轮回复。"}
		],
		"has_explicit_recent_messages": true,
		"attempt": 0,
		"retry_issue_codes": []
	}
	service.call("_start_attempt", context)
	_expect(client.requests.size() == 1, "首次生成请求没有发出。")
	var first_messages: Array = client.requests[0].get("messages", [])
	_expect(str(first_messages.back().get("content", "")).ends_with("你愿意留下吗？"), "当前玩家原文不是上下文最后一条。")
	_expect(first_messages.any(func(message): return str(message.get("content", "")).contains("手机渠道的上一句")), "显式渠道历史没有进入请求。")
	_expect(first_messages.all(func(message): return not str(message.get("content", "")).contains("上一轮已接受回复")), "显式渠道历史没有覆盖统一历史。")
	var player_message_count := first_messages.filter(func(message): return str(message.get("role", "")) == "user").size()
	_expect(player_message_count == 2, "当前玩家输入被重复注入，或显式玩家历史丢失。")
	_expect(str(first_messages[0].get("content", "")).contains("RealizeTurn v6"), "系统提示未声明 v6 合同。")
	var empty_history_context := context.duplicate(true)
	empty_history_context["recent_messages"] = []
	empty_history_context["attempt"] = 0
	service.call("_start_attempt", empty_history_context)
	var empty_history_messages: Array = client.requests[1].get("messages", [])
	_expect(empty_history_messages.size() == 2, "显式空渠道历史错误回退到了统一历史。")
	client.requests.remove_at(1)

	service.call("_on_request_completed", _envelope("旧式纯文本回复"), client.requests[0].get("context", {}))
	_expect(client.requests.size() == 2, "协议失败没有触发整轮重试。")
	var retry_prompt := str((client.requests[1].get("messages", []) as Array)[0].get("content", ""))
	_expect(retry_prompt.contains("REALIZE_TURN_JSON_INVALID"), "重试提示没有携带稳定错误码。")
	_expect(not retry_prompt.contains("旧式纯文本回复"), "失败候选污染了重试提示。")

	service.call("_on_request_completed", _envelope(JSON.stringify(_valid_turn())), client.requests[1].get("context", {}))
	_expect(completed.size() == 1, "合法候选没有被提交。")
	_expect(failed.is_empty(), "合法候选错误触发失败事件。")
	_expect(int(completed[0].get("context", {}).get("accepted_attempt", 0)) == 2, "接受尝试次数记录错误。")
	var recovery_context := context.duplicate(true)
	recovery_context["attempt"] = 0
	service.call("_start_attempt", recovery_context)
	var recovery_first_context: Dictionary = client.requests.back().get("context", {})
	recovery_first_context["failure_stage"] = "provider_content"
	service.call("_on_request_failed", "AI 服务响应缺少角色回复内容。", recovery_first_context)
	_expect(client.requests.size() == 4, "第一次空 content 没有触发恢复请求。")
	var recovery_second_context: Dictionary = client.requests.back().get("context", {})
	_expect(bool(recovery_second_context.get("force_text_response", false)), "第二次尝试没有立即切换为文本响应模式。")
	service.call("_on_request_completed", _envelope("{不是合法 JSON"), recovery_second_context)
	_expect(client.requests.size() == 5, "第二次协议失败没有触发最终恢复请求。")
	var recovery_third_context: Dictionary = client.requests.back().get("context", {})
	_expect(bool(recovery_third_context.get("force_text_response", false)), "协议纠错重试没有保持文本响应模式。")
	var recovery_prompt := str((client.requests.back().get("messages", []) as Array)[0].get("content", ""))
	_expect(recovery_prompt.contains("REALIZE_TURN_JSON_INVALID"), "协议恢复提示没有携带稳定错误码。")
	service.call("_on_request_completed", _envelope(JSON.stringify(_valid_turn())), recovery_third_context)
	_expect(completed.size() == 2, "文本响应恢复后的合法候选没有被提交。")
	_expect(failed.is_empty(), "空 content 恢复流程错误触发失败事件。")
	var fallback_context := context.duplicate(true)
	fallback_context["attempt"] = 0
	fallback_context["force_text_response"] = true
	service.call("_start_attempt", fallback_context)
	var fallback_request_count := client.requests.size()
	var fallback_network_context: Dictionary = client.requests.back().get("context", {})
	service.call("_on_request_completed", _envelope("我愿意留下。"), fallback_network_context)
	_expect(client.requests.size() == fallback_request_count + 1, "没有动作的纯台词兼容响应未触发重试。")
	var missing_action_retry_context: Dictionary = client.requests.back().get("context", {})
	_expect((missing_action_retry_context.get("retry_issue_codes", []) as Array).has("ACTION_DESCRIPTION_INVALID"), "缺少可见动作的重试没有携带 ACTION_DESCRIPTION_INVALID。")
	fallback_request_count = client.requests.size()
	fallback_network_context = missing_action_retry_context
	service.call("_on_request_completed", _envelope("<voice:温和而认真地回应>（轻轻坐直身子）我愿意留下。[SPLIT]<voice:稍微放慢语速>（指尖停在画稿边缘）我们慢慢聊。"), fallback_network_context)
	_expect(client.requests.size() == fallback_request_count, "纯台词兼容响应触发了不必要的额外网络请求。")
	_expect(completed.size() == 3, "纯台词兼容响应没有被提交。")
	_expect(str(completed.back().get("context", {}).get("response_compatibility_mode", "")) == "plain_text_single_beat", "纯台词兼容模式没有写入请求上下文。")
	_expect(completed.back().get("turn", {}).get("segments", []).size() == 2, "旧式 [SPLIT] 响应没有转换为两个独立 segment。")
	_expect(str(completed.back().get("turn", {}).get("segments", [])[0].get("speech", "")) == "我愿意留下。", "第一组台词没有独立保留。")
	_expect(str(completed.back().get("turn", {}).get("segments", [])[0].get("action", {}).get("description", "")) == "轻轻坐直身子", "旧式动作说明没有从台词中拆出。")
	_expect(str(completed.back().get("turn", {}).get("segments", [])[0].get("delivery_instruction", "")).contains("温和而认真地回应"), "旧式 voice 指令没有转换为表演指令。")
	_expect(str(completed.back().get("turn", {}).get("segments", [])[1].get("speech", "")) == "我们慢慢聊。", "第二组台词没有独立保留。")
	_expect(str(completed.back().get("turn", {}).get("segments", [])[1].get("action", {}).get("description", "")) == "指尖停在画稿边缘", "第二组动作没有保持独立分组。")
	var cancelled_context := context.duplicate(true)
	cancelled_context["attempt"] = 0
	service.call("_start_attempt", cancelled_context)
	var cancelled_network_context: Dictionary = client.requests.back().get("context", {})
	service.cancel_all()
	service.call("_on_request_completed", _envelope(JSON.stringify(_valid_turn())), cancelled_network_context)
	service.call("_on_request_failed", "迟到的网络失败", cancelled_network_context)
	_expect(completed.size() == 3, "取消后的迟到成功响应仍被提交。")
	_expect(failed.is_empty(), "取消后的迟到失败响应仍污染 UI。")
	_finish()


func _envelope(content: String) -> Dictionary:
	return {"choices": [{"message": {"content": content}}]}


func _valid_turn() -> Dictionary:
	return {
		"turn_result": {
			"player_input_addressed": "玩家询问她是否愿意留下。",
			"character_response": "她明确选择留下。",
			"interaction_change": "她给出确定答复。",
			"interaction_beats": [{
				"beat_id": "beat_1",
				"interaction_change": "她确认自己的决定。",
				"felt_response": {"physical": null, "psychological": "态度变得确定。", "audible": null},
				"speech_contribution": "明确表示愿意留下。"
			}]
		},
		"segments": [{
			"beat_id": "beat_1",
			"action": {"actor_id": "character", "description": "她抬眼看向你。", "persistent_effect": null},
			"speech": "我愿意留下。",
			"delivery_instruction": "语速平稳，句尾明确收束。"
		}]
	}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("REALIZE_TURN_SERVICE_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("REALIZE_TURN_SERVICE_SMOKE: %s" % failure)
	quit(1)