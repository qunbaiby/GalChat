extends Node

const PANEL_SCENE: PackedScene = preload("res://scenes/ui/settings/cognition_management_panel.tscn")
const CognitionTaskQueueScript = preload("res://scripts/data/cognition_task_queue.gd")

var failures: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var queue = GameDataManager.cognition_task_queue
	var summary_manager = GameDataManager.conversation_summary_manager
	var original_queue_path: String = queue.save_path_override
	var original_summary_path: String = summary_manager.save_path_override
	var original_tasks: Array = queue.tasks.duplicate(true)
	var original_summaries: Dictionary = summary_manager.summaries.duplicate(true)
	var trace_manager = GameDataManager.memory_retrieval_trace_service
	var original_trace_path: String = trace_manager.save_path_override
	var original_traces: Array = trace_manager.traces.duplicate(true)
	var emotion_state_manager = GameDataManager.player_emotion_state_manager
	var original_emotion_path: String = emotion_state_manager.save_path_override
	var original_emotion_state: Dictionary = emotion_state_manager.state.duplicate(true)
	var suffix := str(Time.get_ticks_usec())
	queue.save_path_override = "user://cognition_management_queue_%s.json" % suffix
	summary_manager.save_path_override = "user://cognition_management_summary_%s.json" % suffix
	trace_manager.save_path_override = "user://cognition_management_trace_%s.json" % suffix
	emotion_state_manager.save_path_override = "user://cognition_management_emotion_%s.json" % suffix
	emotion_state_manager.state.clear()
	queue.tasks = []
	summary_manager.summaries = {
		"main_chat": {
			"summary": "玩家和角色约定周末一起看电影。",
			"summarized_message_count": 12,
			"pending_task_id": "",
			"updated_at": "2026-07-23T14:30:00"
		}
	}
	trace_manager.traces = [{
		"created_at": "2026-07-23T15:00:00",
		"query_text": "今天喝什么？",
		"summary_channel": "main_chat",
		"access_subject_id": "luna",
		"has_query_embedding": true,
		"query_dimension": 2,
		"prompt_chars": 120,
		"max_prompt_chars": 2400,
		"truncated": false,
		"status": "response_adopted",
		"response_chars": 18,
		"adopted_chars": 12,
		"adopted_segment_count": 2,
		"revisit_event_id": "revisit-panel-1",
		"revisit_memory_id": "milk",
		"revisit_layer": "habit",
		"revisit_delivery_status": "presented",
		"revisit_outcome": MemoryManager.REVISIT_OUTCOME_CONFIRMED,
		"rendered_memory_ids": ["milk"],
		"selected": [{"memory_id": "milk", "layer": "habit", "selection_mode": "semantic", "content": "玩家喜欢热牛奶", "rendered": true, "consolidation_status": "candidate", "time_relevance": 0.62, "time_protected": false, "exposure_factor": 0.75, "emotion_affinity": "match", "emotion_factor": 1.1}]
		,"story_knowledge_chars": 42
		,"rejected": [{"memory_id": "future", "memory_domain": "story_memory", "reason": "source_not_completed", "content": "尚未完成的未来剧情", "rendered": false}]
	}]
	var failed_id: String = queue.enqueue("exchange", {"user_text": "测试", "ai_reply": "测试"}, MemoryManager.MEMORY_DOMAIN_PLAYER)
	queue.tasks[0]["state"] = "processing"
	for attempt in CognitionTaskQueueScript.MAX_ATTEMPTS:
		queue.fail(failed_id, "测试失败 %d" % attempt)

	var panel: Control = PANEL_SCENE.instantiate() as Control
	add_child(panel)
	await get_tree().process_frame
	var failed_list: VBoxContainer = panel.get_node("Center/Panel/Margin/RootVBox/Tabs/失败任务/FailedScroll/FailedTaskList") as VBoxContainer
	_expect(failed_list.get_child_count() == 1, "认知管理面板没有展示失败任务。")
	if failed_list.get_child_count() > 0:
		var item := failed_list.get_child(0)
		_expect(str(item.get_node("Margin/VBox/ErrorLabel").text).contains("测试失败"), "失败任务没有展示错误详情。")
		item.get_node("Margin/VBox/Footer/RetryButton").emit_signal("pressed")
		_expect(str(queue.get_task(failed_id).get("state", "")) == "pending", "面板重试按钮没有恢复失败任务。")

	var tabs: TabContainer = panel.get_node("Center/Panel/Margin/RootVBox/Tabs") as TabContainer
	tabs.current_tab = 1
	var channel_option: OptionButton = panel.get_node("Center/Panel/Margin/RootVBox/Tabs/滚动摘要/SummaryToolbar/ChannelOption") as OptionButton
	channel_option.select(0)
	panel.call("_refresh_summary")
	var summary_text: RichTextLabel = panel.get_node("Center/Panel/Margin/RootVBox/Tabs/滚动摘要/SummaryText") as RichTextLabel
	var summary_meta: Label = panel.get_node("Center/Panel/Margin/RootVBox/Tabs/滚动摘要/SummaryMetaLabel") as Label
	_expect(summary_text.text.contains("周末一起看电影"), "认知管理面板没有展示滚动摘要内容。")
	_expect(summary_meta.text.contains("已覆盖 12 条"), "认知管理面板没有展示摘要覆盖消息数。")
	tabs.current_tab = 2
	panel.call("_refresh_traces")
	var trace_summary: Label = panel.get_node("Center/Panel/Margin/RootVBox/Tabs/检索追踪/TraceToolbar/TraceSummaryLabel") as Label
	var trace_text: RichTextLabel = panel.get_node("Center/Panel/Margin/RootVBox/Tabs/检索追踪/TraceText") as RichTextLabel
	_expect(trace_summary.text.contains("最新渲染 1 条") and trace_summary.text.contains("120 / 2400 字"), "认知管理面板没有展示检索预算摘要。")
	_expect(trace_text.text.contains("今天喝什么") and trace_text.text.contains("玩家喜欢热牛奶"), "认知管理面板没有展示检索追踪明细。")
	_expect(trace_text.text.contains("已采用") and trace_text.text.contains("采用 12 字 / 2 段"), "认知管理面板没有展示回答采用状态。")
	_expect(trace_text.text.contains("故事权限主体：luna") and trace_text.text.contains("故事 42") and trace_text.text.contains("source_not_completed"), "认知管理面板没有展示故事权限审计信息。")
	_expect(trace_text.text.contains("候选") and trace_text.text.contains("时间 62%"), "认知管理面板没有展示记忆巩固与半衰期状态。")
	_expect(trace_text.text.contains("曝光恢复 75%"), "认知管理面板没有展示短期曝光恢复状态。")
	_expect(trace_text.text.contains("情绪匹配 ×1.10"), "认知管理面板没有展示情绪调制状态。")
	tabs.current_tab = 3
	panel.call("_refresh_governance")
	var governance_summary: Label = panel.get_node("Center/Panel/Margin/RootVBox/Tabs/治理质量/GovernanceSummaryLabel") as Label
	var governance_text: RichTextLabel = panel.get_node("Center/Panel/Margin/RootVBox/Tabs/治理质量/GovernanceText") as RichTextLabel
	_expect(governance_summary.text.contains("活跃候选") and governance_summary.text.contains("标签有效覆盖"), "认知管理面板没有展示治理质量摘要。")
	_expect(governance_text.text.contains("情绪 候选") and governance_text.text.contains("容量") and governance_text.text.contains("实际进入 Prompt 1"), "认知管理面板没有展示候选容量与情绪调制影响。")
	_expect(governance_text.text.contains("主动重访：发起 1") and governance_text.text.contains("展示 1") and governance_text.text.contains("确认 1") and governance_text.text.contains("反馈率 100%"), "认知管理面板没有展示主动重访反馈漏斗。")
	_expect(governance_text.text.contains("习惯摘要：有效 0 · 待审核 0 · 待重建 0 · 已拒绝 0 · 已停用 0") and governance_text.text.contains("摘要收益：聚合成员 0 · 节省候选 0") and governance_text.text.contains("摘要决策：提案 0 · 接受 0 · 拒绝 0"), "认知管理面板没有准确展示习惯摘要状态、收益与决策统计。")
	tabs.current_tab = 4
	var emotion_option: OptionButton = panel.get_node("Center/Panel/Margin/RootVBox/Tabs/即时状态/InputRow/PlayerEmotionOption") as OptionButton
	var confidence_input: SpinBox = panel.get_node("Center/Panel/Margin/RootVBox/Tabs/即时状态/InputRow/ConfidenceSpinBox") as SpinBox
	var duration_input: SpinBox = panel.get_node("Center/Panel/Margin/RootVBox/Tabs/即时状态/InputRow/DurationSpinBox") as SpinBox
	var apply_emotion_button: Button = panel.get_node("Center/Panel/Margin/RootVBox/Tabs/即时状态/InputRow/ApplyPlayerEmotionButton") as Button
	emotion_option.select(1)
	confidence_input.value = 90.0
	duration_input.value = 60.0
	apply_emotion_button.emit_signal("pressed")
	var emotion_summary: Label = panel.get_node("Center/Panel/Margin/RootVBox/Tabs/即时状态/StateToolbar/PlayerEmotionSummaryLabel") as Label
	var emotion_text: RichTextLabel = panel.get_node("Center/Panel/Margin/RootVBox/Tabs/即时状态/PlayerEmotionText") as RichTextLabel
	var clear_emotion_button: Button = panel.get_node("Center/Panel/Margin/RootVBox/Tabs/即时状态/StateToolbar/ClearPlayerEmotionButton") as Button
	_expect(str(emotion_state_manager.state.get("emotion_id", "")) == "low" and is_equal_approx(float(emotion_state_manager.state.get("confidence", 0.0)), 0.9), "认知管理面板没有保存玩家显式输入。")
	_expect(emotion_summary.text.contains("低落") and emotion_summary.text.contains("可用于 Prompt") and emotion_text.text.contains("玩家显式输入"), "认知管理面板没有展示可信玩家即时状态。")
	clear_emotion_button.emit_signal("pressed")
	_expect(emotion_state_manager.state.is_empty() and emotion_summary.text.contains("没有玩家显式情绪状态"), "认知管理面板没有清除玩家即时状态。")

	panel.queue_free()
	queue.save_path_override = original_queue_path
	summary_manager.save_path_override = original_summary_path
	trace_manager.save_path_override = original_trace_path
	emotion_state_manager.save_path_override = original_emotion_path
	queue.tasks = original_tasks
	summary_manager.summaries = original_summaries
	trace_manager.traces = original_traces
	emotion_state_manager.state = original_emotion_state
	_cleanup("user://cognition_management_queue_%s.json" % suffix)
	_cleanup("user://cognition_management_summary_%s.json" % suffix)
	_cleanup("user://cognition_management_trace_%s.json" % suffix)
	_cleanup("user://cognition_management_emotion_%s.json" % suffix)
	if failures.is_empty():
		print("COGNITION_MANAGEMENT_PANEL_SMOKE_OK")
		get_tree().quit(0)
		return
	for failure in failures:
		push_error("COGNITION_MANAGEMENT_PANEL_SMOKE: %s" % failure)
	get_tree().quit(1)

func _cleanup(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)