extends Control

const FAILED_TASK_ITEM_SCENE: PackedScene = preload("res://scenes/ui/settings/cognition_failed_task_item.tscn")
const SUMMARY_CHANNELS := ["main_chat", "story_chat", "desktop_pet"]

@onready var status_label: Label = %StatusLabel
@onready var close_button: Button = %CloseButton
@onready var clear_failed_button: Button = %ClearFailedButton
@onready var failed_task_list: VBoxContainer = %FailedTaskList
@onready var failed_empty_label: Label = %FailedEmptyLabel
@onready var channel_option: OptionButton = %ChannelOption
@onready var rebuild_summary_button: Button = %RebuildSummaryButton
@onready var summary_meta_label: Label = %SummaryMetaLabel
@onready var summary_text: RichTextLabel = %SummaryText
@onready var trace_summary_label: Label = %TraceSummaryLabel
@onready var clear_traces_button: Button = %ClearTracesButton
@onready var trace_text: RichTextLabel = %TraceText
@onready var governance_summary_label: Label = %GovernanceSummaryLabel
@onready var governance_text: RichTextLabel = %GovernanceText
@onready var player_emotion_summary_label: Label = %PlayerEmotionSummaryLabel
@onready var clear_player_emotion_button: Button = %ClearPlayerEmotionButton
@onready var player_emotion_text: RichTextLabel = %PlayerEmotionText
@onready var player_emotion_option: OptionButton = %PlayerEmotionOption
@onready var confidence_spin_box: SpinBox = %ConfidenceSpinBox
@onready var duration_spin_box: SpinBox = %DurationSpinBox
@onready var apply_player_emotion_button: Button = %ApplyPlayerEmotionButton

func _ready() -> void:
	close_button.pressed.connect(queue_free)
	clear_failed_button.pressed.connect(_on_clear_failed_pressed)
	rebuild_summary_button.pressed.connect(_on_rebuild_summary_pressed)
	clear_traces_button.pressed.connect(_on_clear_traces_pressed)
	clear_player_emotion_button.pressed.connect(_on_clear_player_emotion_pressed)
	apply_player_emotion_button.pressed.connect(_on_apply_player_emotion_pressed)
	channel_option.item_selected.connect(func(_index: int) -> void: _refresh_summary())
	channel_option.select(0)
	if GameDataManager.cognition_task_queue:
		GameDataManager.cognition_task_queue.queue_changed.connect(_refresh_all)
	if GameDataManager.memory_retrieval_trace_service:
		GameDataManager.memory_retrieval_trace_service.traces_changed.connect(_refresh_trace_views)
	if GameDataManager.player_emotion_state_manager:
		GameDataManager.player_emotion_state_manager.state_changed.connect(_refresh_player_emotion_state)
	_refresh_all()

func _refresh_trace_views() -> void:
	_refresh_traces()
	_refresh_governance()
	_refresh_player_emotion_state()

func _refresh_all() -> void:
	_refresh_status()
	_refresh_failed_tasks()
	_refresh_summary()
	_refresh_traces()
	_refresh_governance()

func _refresh_status() -> void:
	if GameDataManager.cognition_task_queue == null:
		status_label.text = "认知队列不可用"
		return
	var counts: Dictionary = GameDataManager.cognition_task_queue.get_status_counts()
	status_label.text = "待处理 %d · 处理中 %d · 失败 %d" % [
		int(counts.get("pending", 0)),
		int(counts.get("processing", 0)),
		int(counts.get("failed", 0))
	]

func _refresh_failed_tasks() -> void:
	for child in failed_task_list.get_children():
		child.queue_free()
	var failed_tasks: Array = GameDataManager.cognition_task_queue.get_failed_tasks() if GameDataManager.cognition_task_queue else []
	failed_empty_label.visible = failed_tasks.is_empty()
	clear_failed_button.disabled = failed_tasks.is_empty()
	for task in failed_tasks:
		var item := FAILED_TASK_ITEM_SCENE.instantiate()
		failed_task_list.add_child(item)
		_bind_failed_task_item(item, task)

func _bind_failed_task_item(item: Control, task: Dictionary) -> void:
	var task_id := str(task.get("id", ""))
	item.get_node("Margin/VBox/Header/TypeLabel").text = _format_task_type(str(task.get("type", "")))
	item.get_node("Margin/VBox/Header/TimeLabel").text = _format_unix_time(int(task.get("updated_at", 0)))
	item.get_node("Margin/VBox/ErrorLabel").text = str(task.get("last_error", "未知错误"))
	item.get_node("Margin/VBox/Footer/AttemptsLabel").text = "已尝试 %d 次" % int(task.get("attempts", 0))
	item.get_node("Margin/VBox/Footer/RetryButton").pressed.connect(func() -> void:
		if GameDataManager.cognition_task_queue:
			GameDataManager.cognition_task_queue.retry_failed(task_id)
	)
	item.get_node("Margin/VBox/Footer/DiscardButton").pressed.connect(func() -> void:
		if GameDataManager.cognition_task_queue:
			GameDataManager.cognition_task_queue.discard_task(task_id)
	)

func _refresh_summary() -> void:
	var selected_index := clampi(channel_option.selected, 0, SUMMARY_CHANNELS.size() - 1)
	var channel: String = str(SUMMARY_CHANNELS[selected_index])
	var manager = GameDataManager.conversation_summary_manager
	var state: Dictionary = manager.get_summary_state(channel) if manager else {}
	var summary := str(state.get("summary", "")).strip_edges()
	var pending := not str(state.get("pending_task_id", "")).is_empty()
	var updated_at := str(state.get("updated_at", "")).strip_edges()
	summary_meta_label.text = "已覆盖 %d 条 · %s%s" % [
		int(state.get("summarized_message_count", 0)),
		"更新于 %s" % updated_at if not updated_at.is_empty() else "尚未更新",
		" · 正在生成" if pending else ""
	]
	summary_text.text = summary if not summary.is_empty() else "当前通道尚未生成滚动摘要。"

func _on_clear_failed_pressed() -> void:
	if GameDataManager.cognition_task_queue:
		GameDataManager.cognition_task_queue.clear_failed()

func _on_rebuild_summary_pressed() -> void:
	if GameDataManager.conversation_summary_manager == null:
		return
	var selected_index := clampi(channel_option.selected, 0, SUMMARY_CHANNELS.size() - 1)
	var channel := str(SUMMARY_CHANNELS[selected_index])
	var task_id: String = GameDataManager.conversation_summary_manager.rebuild_summary(channel)
	_refresh_summary()
	if task_id.is_empty():
		summary_meta_label.text = "历史消息不足 %d 条，暂时无法重新生成" % ConversationSummaryManager.SUMMARY_TRIGGER_COUNT

func _refresh_traces() -> void:
	var manager = GameDataManager.memory_retrieval_trace_service
	var traces: Array = manager.get_recent_traces(12) if manager else []
	clear_traces_button.disabled = traces.is_empty()
	if traces.is_empty():
		trace_summary_label.text = "尚无检索记录"
		trace_text.text = "进行一次对话后，这里会显示记忆检索与预算明细。"
		return
	var latest: Dictionary = traces[0]
	var latest_rendered: Array = latest.get("rendered_memory_ids", []) if latest.get("rendered_memory_ids", []) is Array else []
	trace_summary_label.text = "最近 %d 次 · 最新渲染 %d 条 · %d / %d 字%s" % [
		traces.size(),
		latest_rendered.size(),
		int(latest.get("prompt_chars", 0)),
		int(latest.get("max_prompt_chars", 0)),
		" · 已截断" if bool(latest.get("truncated", false)) else ""
	]
	var lines: Array[String] = []
	for trace in traces:
		if not trace is Dictionary:
			continue
		var selected: Array = trace.get("selected", []) if trace.get("selected", []) is Array else []
		var rendered: Array = selected.filter(func(candidate): return candidate is Dictionary and bool(candidate.get("rendered", false)))
		lines.append("[b]%s[/b]  %s  %s" % [
			str(trace.get("created_at", "未记录")),
			_format_trace_channel(str(trace.get("summary_channel", ""))),
			"向量 %d 维" % int(trace.get("query_dimension", 0)) if bool(trace.get("has_query_embedding", false)) else "无向量降级"
		])
		lines.append("查询：%s" % str(trace.get("query_text", "")))
		if not str(trace.get("access_subject_id", "")).is_empty():
			lines.append("故事权限主体：%s" % str(trace.get("access_subject_id", "")))
		lines.append("状态：%s · 回答 %d 字 · 采用 %d 字 / %d 段" % [
			_format_trace_status(str(trace.get("status", "prompt_built"))),
			int(trace.get("response_chars", 0)),
			int(trace.get("adopted_chars", 0)),
			int(trace.get("adopted_segment_count", 0))
		])
		lines.append("结果：渲染 %d / 入选 %d · %d 字%s" % [
			rendered.size(),
			selected.size(),
			int(trace.get("prompt_chars", 0)),
			" · 截断" if bool(trace.get("truncated", false)) else ""
		])
		lines.append("预算：记忆 %d · 故事 %d · 日记 %d · 摘要 %d" % [
			int(trace.get("memory_prompt_chars", trace.get("prompt_chars", 0))),
			int(trace.get("story_knowledge_chars", 0)),
			int(trace.get("diary_chars", 0)),
			int(trace.get("summary_chars", 0))
		])
		for candidate in rendered:
			var consolidation_label := "候选" if str(candidate.get("consolidation_status", "")) == MemoryManager.CONSOLIDATION_STATUS_CANDIDATE else "已巩固"
			var time_label := "时间保护" if bool(candidate.get("time_protected", false)) else "时间 %.0f%%" % (float(candidate.get("time_relevance", 1.0)) * 100.0)
			var exposure_label := "曝光恢复 %.0f%%" % (float(candidate.get("exposure_factor", 1.0)) * 100.0)
			var emotion_label := _format_emotion_affinity(str(candidate.get("emotion_affinity", "neutral")), float(candidate.get("emotion_factor", 1.0)))
			lines.append("  • [%s/%s · %s · %s · %s · %s] %s" % [
				str(candidate.get("layer", "")),
				str(candidate.get("selection_mode", "")),
				consolidation_label,
				time_label,
				exposure_label,
				emotion_label,
				str(candidate.get("content", ""))
			])
		var story_rejected: Array = trace.get("rejected", []).filter(func(candidate): return candidate is Dictionary and str(candidate.get("memory_domain", "")) == MemoryManager.MEMORY_DOMAIN_STORY)
		for candidate in story_rejected:
			lines.append("  × [故事拒绝/%s] %s" % [str(candidate.get("reason", "unknown")), str(candidate.get("content", ""))])
		lines.append("")
	trace_text.text = "\n".join(lines)

func _format_emotion_affinity(affinity: String, factor: float) -> String:
	match affinity:
		"match": return "情绪匹配 ×%.2f" % factor
		"near": return "情绪邻近 ×%.2f" % factor
		"conflict": return "情绪冲突 ×%.2f" % factor
		"ignored_core": return "核心不调制"
		_: return "情绪中性"

func _on_clear_traces_pressed() -> void:
	if GameDataManager.memory_retrieval_trace_service:
		GameDataManager.memory_retrieval_trace_service.clear_traces()

func _refresh_governance() -> void:
	var trace_manager = GameDataManager.memory_retrieval_trace_service
	var memory_manager = GameDataManager.memory_manager
	if trace_manager == null or memory_manager == null or not trace_manager.has_method("evaluate_governance_report"):
		governance_summary_label.text = "治理质量报告不可用"
		governance_text.text = ""
		return
	var report: Dictionary = trace_manager.evaluate_governance_report(memory_manager)
	var capacity: Dictionary = report.get("candidate_capacity", {})
	var tags: Dictionary = report.get("emotion_tags", {})
	var effect: Dictionary = report.get("emotion_trace_effect", {})
	var revisit: Dictionary = report.get("revisit_feedback", {})
	var habit_clusters: Dictionary = report.get("habit_cluster_summaries", {})
	var by_layer: Dictionary = capacity.get("by_layer", {})
	governance_summary_label.text = "%s · 活跃候选 %d · 标签有效覆盖 %.0f%%" % [
		"通过" if bool(report.get("passed", false)) else "需要处理",
		int(capacity.get("active_candidates", 0)),
		float(tags.get("valid_coverage_rate", 0.0)) * 100.0
	]
	var lines: Array[String] = []
	for layer in ["emotion", "habit"]:
		var layer_state: Dictionary = by_layer.get(layer, {})
		lines.append("%s 候选：%d / %d" % [_format_governance_layer(layer), int(layer_state.get("active", 0)), int(layer_state.get("capacity", 0))])
	lines.append("候选归档：容量 %d · 到期 %d · 已恢复 %d · 受保护 %d" % [
		int(capacity.get("capacity_expired", 0)),
		int(capacity.get("time_expired", 0)),
		int(capacity.get("restored", 0)),
		int(capacity.get("protected", 0))
	])
	lines.append("情绪标签：覆盖 %.0f%% · 有效 %.0f%% · 非法 %d · 重复 %d" % [
		float(tags.get("coverage_rate", 0.0)) * 100.0,
		float(tags.get("valid_coverage_rate", 0.0)) * 100.0,
		int(tags.get("invalid_tag_count", 0)),
		int(tags.get("duplicate_tag_count", 0))
	])
	var affinity: Dictionary = effect.get("affinity_counts", {})
	lines.append("情绪调制：匹配 %d · 邻近 %d · 冲突 %d · 中性 %d · 实际进入 Prompt %d" % [
		int(affinity.get("match", 0)),
		int(affinity.get("near", 0)),
		int(affinity.get("conflict", 0)),
		int(affinity.get("neutral", 0)),
		int(effect.get("rendered_influenced_count", 0))
	])
	lines.append("主动重访：发起 %d · 展示 %d · 参与 %d · 确认 %d · 纠正 %d · 暂缓 %d · 失败/取消 %d · 反馈率 %.0f%%" % [
		int(revisit.get("started", 0)),
		int(revisit.get("presented", 0)),
		int(revisit.get("engaged", 0)),
		int(revisit.get("confirmed", 0)),
		int(revisit.get("corrected", 0)),
		int(revisit.get("dismissed", 0)),
		int(revisit.get("failed", 0)) + int(revisit.get("cancelled", 0)),
		float(revisit.get("feedback_rate", 0.0)) * 100.0
	])
	lines.append("习惯摘要：有效 %d · 待审核 %d · 待重建 %d · 已拒绝 %d · 已停用 %d" % [
		int(habit_clusters.get("active_count", 0)),
		int(habit_clusters.get("proposed_count", 0)),
		int(habit_clusters.get("stale_count", 0)),
		int(habit_clusters.get("rejected_count", 0)),
		int(habit_clusters.get("disabled_count", 0))
	])
	lines.append("摘要收益：聚合成员 %d · 节省候选 %d · 原文 %d 字 · 摘要 %d 字 · 净节省 %d 字" % [
		int(habit_clusters.get("member_count", 0)),
		int(habit_clusters.get("saved_candidate_count", 0)),
		int(habit_clusters.get("source_char_count", 0)),
		int(habit_clusters.get("summary_char_count", 0)),
		int(habit_clusters.get("saved_char_count", 0))
	])
	lines.append("摘要决策：提案 %d · 接受 %d · 拒绝 %d · 接受率 %.0f%% · 失效事件 %d" % [
		int(habit_clusters.get("proposal_total", 0)),
		int(habit_clusters.get("accept_total", 0)),
		int(habit_clusters.get("reject_total", 0)),
		float(habit_clusters.get("acceptance_rate", 0.0)) * 100.0,
		int(habit_clusters.get("stale_event_total", 0))
	])
	var violations: Array = report.get("violations", []) if report.get("violations", []) is Array else []
	if not violations.is_empty():
		lines.append("[color=#9a6268]违规：%s[/color]" % "；".join(violations))
	governance_text.text = "\n".join(lines)

func _format_governance_layer(layer: String) -> String:
	match layer:
		"emotion": return "情绪"
		"habit": return "习惯"
		_: return layer

func _refresh_player_emotion_state() -> void:
	var manager = GameDataManager.player_emotion_state_manager
	if manager == null:
		player_emotion_summary_label.text = "玩家即时状态服务不可用"
		player_emotion_text.text = ""
		clear_player_emotion_button.disabled = true
		return
	var evaluation: Dictionary = manager.get_state_evaluation()
	var reason := str(evaluation.get("reason", "missing"))
	var has_state := reason != "missing"
	clear_player_emotion_button.disabled = not has_state
	if not has_state:
		player_emotion_summary_label.text = "没有玩家显式情绪状态"
		player_emotion_text.text = "记忆排序保持中性，不会从消息文本或角色心情推断玩家情绪。"
		return
	var usable := bool(evaluation.get("usable", false))
	player_emotion_summary_label.text = "%s · %s · 置信度 %.0f%%" % [
		_format_player_emotion(str(evaluation.get("emotion_id", ""))),
		"可用于 Prompt" if usable else "不会用于 Prompt",
		float(evaluation.get("confidence", 0.0)) * 100.0
	]
	player_emotion_text.text = "来源：%s\n观测时间：%s\n过期时间：%s\n判定：%s" % [
		"玩家显式输入" if str(evaluation.get("source", "")) == "player_explicit" else "不可信来源",
		_format_unix_time(int(evaluation.get("observed_at_unix", 0.0))),
		_format_unix_time(int(evaluation.get("expires_at_unix", 0.0))),
		_format_player_emotion_reason(reason)
	]

func _on_clear_player_emotion_pressed() -> void:
	if GameDataManager.player_emotion_state_manager:
		GameDataManager.player_emotion_state_manager.clear_state()

func _on_apply_player_emotion_pressed() -> void:
	if GameDataManager.player_emotion_state_manager == null:
		return
	var emotion_ids := ["broken", "low", "calm", "pleasant", "ecstatic"]
	var selected_index := clampi(player_emotion_option.selected, 0, emotion_ids.size() - 1)
	GameDataManager.player_emotion_state_manager.set_explicit_state(
		str(emotion_ids[selected_index]),
		confidence_spin_box.value / 100.0,
		duration_spin_box.value * 60.0
	)

func _format_player_emotion(emotion_id: String) -> String:
	match emotion_id:
		"broken": return "崩溃"
		"low": return "低落"
		"calm": return "平静"
		"pleasant": return "愉快"
		"ecstatic": return "高兴奋"
		_: return "未知"

func _format_player_emotion_reason(reason: String) -> String:
	match reason:
		"usable": return "可信且有效"
		"low_confidence": return "置信度不足"
		"expired": return "状态已过期"
		"untrusted_source": return "来源不可信"
		"invalid_emotion": return "标签无效"
		"invalid_time_range": return "时间范围无效"
		_: return "无可用状态"

func _format_trace_channel(channel: String) -> String:
	match channel:
		"main_chat": return "主对话"
		"story_chat": return "故事对话"
		"desktop_pet": return "桌宠对话"
		_: return "通用对话"

func _format_trace_status(status: String) -> String:
	match status:
		"request_started": return "请求中"
		"response_completed": return "回答完成"
		"response_adopted": return "已采用"
		"failed": return "失败"
		"cancelled": return "已取消"
		_: return "提示词已构建"

func _format_task_type(task_type: String) -> String:
	match task_type:
		"conversation_summary": return "滚动摘要"
		"habit_cluster_summary": return "习惯摘要提案"
		"memory_edit": return "记忆编辑"
		"history": return "历史记忆提取"
		_: return "对话记忆提取"

func _format_unix_time(value: int) -> String:
	if value <= 0:
		return "未记录"
	var datetime := Time.get_datetime_dict_from_unix_time(value)
	return "%04d-%02d-%02d %02d:%02d" % [datetime.year, datetime.month, datetime.day, datetime.hour, datetime.minute]