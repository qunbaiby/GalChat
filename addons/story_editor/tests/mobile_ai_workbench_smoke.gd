extends SceneTree

const Service = preload("res://addons/story_editor/core/mobile_ai_workbench_service.gd")
const WorkbenchScene = preload("res://addons/story_editor/ui/mobile_ai_workbench.tscn")

var failures: Array[String] = []


class FakeRequester extends Node:
	signal completed(job_id: String, raw_response: Dictionary, metadata: Dictionary)
	signal failed(job_id: String, error_message: String, metadata: Dictionary)

	var request_count := 0
	var last_job_id := ""
	var last_context: Dictionary = {}
	var cancelled_job_id := ""

	func request(job_id: String, context: Dictionary) -> void:
		request_count += 1
		last_job_id = job_id
		last_context = context.duplicate(true)

	func cancel(job_id: String) -> void:
		cancelled_job_id = job_id


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var history: Array = []
	for index in 8:
		history.append({"speaker": "player" if index % 2 == 0 else "char", "text": "历史%d" % index})
	history.append({"speaker": "system", "type": "system", "text": "系统事件"})
	history.append({"speaker": "player", "type": "red_packet", "text": "测试红包"})
	history.append({"speaker": "player", "text": "[img]photo.png[/img]"})
	var overrides := {
		"character_id": "luna",
		"relationship_stage": 1,
		"intimacy": 32.0,
		"trust": 44.0,
		"story_time": "2026年7月16日 星期四，夜晚，时间：21:00",
		"mood_desc": "【角色当前整体心情】：\n期待",
		"memory_desc": "【测试记忆】：玩家答应陪她练琴。",
		"location_context": "音乐馆外的长椅",
		"dynamic_style": Service.DOUBLE_STYLE
	}
	var response := {"choices": [{"message": {"content": "第一句[SPLIT]（轻轻笑）第二句"}}]}
	var preview := Service.preview("text", overrides, history, "看看照片", response)
	var prompt := str((preview.get("request", {}) as Dictionary).get("messages", [])[0].get("content", ""))
	_expect(prompt.contains("Luna") and prompt.contains("32") and prompt.contains("44"), "Prompt 缺少角色或关系值。")
	_expect(prompt.contains("期待") and prompt.contains("21:00") and prompt.contains("玩家答应陪她练琴"), "Prompt 缺少心情、时间或显式记忆。")
	_expect(prompt.contains("音乐馆外的长椅"), "显式地点说明没有进入测试 Prompt。")
	_expect(not prompt.contains("{name}") and not prompt.contains("{dynamic_style}"), "Prompt 仍有未替换占位符。")
	var messages := (preview.get("request", {}) as Dictionary).get("messages", []) as Array
	_expect(messages.size() == 11, "文字请求应为 system 加最近 10 条历史。")
	_expect(str((messages[8] as Dictionary).get("content", "")).contains("系统提示"), "system 历史没有按生产规则转换。")
	_expect(str((messages[9] as Dictionary).get("content", "")).contains("红包"), "红包历史没有按生产规则转换。")
	_expect(str((messages[10] as Dictionary).get("content", "")).contains("发送了一张照片"), "图片历史没有按生产规则转换。")
	var parsed := preview.get("response", {}) as Dictionary
	_expect((parsed.get("parts", []) as Array) == ["第一句", "第二句"], "[SPLIT] 或动作过滤结果不正确。")
	_expect((parsed.get("history_records", []) as Array).size() == 2, "响应没有生成两条内存历史预览。")
	_expect((preview.get("request", {}) as Dictionary).get("persistent_history_writes", [1]).is_empty(), "工作台不应产生持久历史写入。")
	_expect(not bool((preview.get("request", {}) as Dictionary).get("network_requested", true)), "工作台不应发起网络请求。")
	var proactive := Service.build_request("call_proactive", Service.build_context(overrides), history, "", false, false)
	_expect((proactive.get("messages", []) as Array).size() == 2, "主动通话首句不应注入持久聊天历史。")
	var call_followup := Service.build_request("call_followup", Service.build_context(overrides), [{"speaker": "player", "text": "听得到吗"}, {"speaker": "char", "text": "听得到"}], "继续")
	_expect((call_followup.get("messages", []) as Array).size() == 3, "通话后续没有使用独立通话历史。")
	_expect(not bool(Service.parse_response({}).get("ok", true)), "缺失 choices 的响应不应通过。")
	_expect(not bool(Service.parse_response({"choices": [{"message": {"content": ""}}]}).get("ok", true)), "空回复不应通过。")
	var workbench := WorkbenchScene.instantiate() as Window
	root.add_child(workbench)
	await process_frame
	_expect(workbench.build_preview(), "工作台默认输入无法构建预览。")
	var workbench_messages := (workbench.last_preview.get("request", {}) as Dictionary).get("messages", []) as Array
	var workbench_parts := ((workbench.last_preview.get("response", {}) as Dictionary).get("parts", []) as Array)
	_expect(workbench_messages.size() == 3, "工作台默认历史应生成 system 加两条消息。")
	_expect(workbench_parts.size() == 2, "工作台默认响应应清洗为两段。")
	var fake_requester := FakeRequester.new()
	workbench.set_generation_requester(fake_requester)
	_expect(fake_requester.request_count == 0, "注入 requester 或打开工作台时不应自动联网。")
	workbench.start_real_request()
	_expect(fake_requester.request_count == 1, "显式真实请求没有转发给 requester。")
	_expect((fake_requester.last_context.get("messages", []) as Array) == workbench_messages, "真实请求 payload 与当前预览 messages 不一致。")
	var completed_job_id := fake_requester.last_job_id
	fake_requester.completed.emit(completed_job_id, {"choices": [{"message": {"content": "真实第一句[SPLIT]真实第二句"}}]}, {"duration_ms": 42, "model": "fake-chat", "http_status": 200, "usage": {"total_tokens": 18}})
	var completed_parts := ((workbench.last_preview.get("response", {}) as Dictionary).get("parts", []) as Array)
	_expect(completed_parts == ["真实第一句", "真实第二句"], "真实响应没有自动回填并按生产规则清洗。")
	var metadata_edit := workbench.get_node("Root/Body/Results/ResultTabs/请求元数据") as TextEdit
	var metadata_value: Variant = JSON.parse_string(metadata_edit.text)
	_expect(metadata_value is Dictionary and str((metadata_value as Dictionary).get("status", "")) == "completed", "成功请求状态没有写入元数据页。")
	_expect(int((((metadata_value as Dictionary).get("metadata", {}) as Dictionary).get("usage", {}) as Dictionary).get("total_tokens", 0)) == 18, "响应 Token 元数据没有显示。")
	workbench.start_real_request()
	var cancelled_job_id := fake_requester.last_job_id
	workbench.cancel_real_request()
	_expect(fake_requester.cancelled_job_id == cancelled_job_id and workbench.active_job_id.is_empty(), "取消请求没有转发或清理活动状态。")
	workbench.start_real_request()
	var failed_job_id := fake_requester.last_job_id
	fake_requester.failed.emit(failed_job_id, "模拟网络失败", {"duration_ms": 7})
	_expect(workbench.get_node("Root/Body/Results/StatusLabel").text.contains("模拟网络失败"), "请求失败状态在界面中不可见。")
	var previous_preview: Dictionary = workbench.last_preview.duplicate(true)
	var history_edit := workbench.get_node("Root/Body/InputScroll/Inputs/HistoryEdit") as TextEdit
	history_edit.text = "{}"
	_expect(not workbench.build_preview(), "非数组历史不应构建预览。")
	_expect(workbench.last_preview == previous_preview, "非法输入不应覆盖上一份有效预览。")
	workbench.queue_free()
	await process_frame

	if failures.is_empty():
		print("MOBILE_AI_WORKBENCH_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("MOBILE_AI_WORKBENCH_SMOKE: %s" % failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)