extends Control

@onready var close_button: Button = %CloseButton
@onready var content_label: Label = %ContentLabel
@onready var meta_label: Label = %MetaLabel
@onready var evidence_text: TextEdit = %EvidenceText
@onready var revision_text: TextEdit = %RevisionText

var _memory: Dictionary = {}

func _ready() -> void:
	close_button.pressed.connect(queue_free)
	_apply_memory()

func setup(memory: Dictionary) -> void:
	_memory = memory.duplicate(true)
	if is_node_ready():
		_apply_memory()

func _apply_memory() -> void:
	if _memory.is_empty() or not is_node_ready():
		return
	content_label.text = str(_memory.get("content", "暂无内容"))
	meta_label.text = "可信度 %d%% · 证据 %d 次 · 曝光 %d 次 · 主动重访 %d 次 · 成功重访 %d 次 · 成功采用 %d 次 · 纠正 %d 次 · 衰减 %d%%\n最后确认 %s · 最后曝光 %s · 最后重访 %s\n最近重访结果 %s · 暂缓重访至 %s\n习惯聚类 %s · 摘要版本 %d · 状态 %s\n提案 %d · 接受 %d · 拒绝 %d · 失效 %d · 模型 %s · 最近决定 %s\n聚类摘要 %s" % [
		roundi(clampf(float(_memory.get("confidence", MemoryManager.DEFAULT_MEMORY_CONFIDENCE)), 0.0, 1.0) * 100.0),
		maxi(1, int(_memory.get("evidence_count", 1))),
		maxi(0, int(_memory.get("recall_count", 0))),
		maxi(0, int(_memory.get("revisit_count", 0))),
		maxi(0, int(_memory.get("successful_revisit_count", 0))),
		maxi(0, int(_memory.get("successful_use_count", 0))),
		maxi(0, int(_memory.get("correction_count", 0))),
		roundi(clampf(float(_memory.get("decay", 0.0)), 0.0, 100.0)),
		_format_value(str(_memory.get("last_confirmed_at", ""))),
		_format_value(str(_memory.get("last_recalled_at", ""))),
		_format_value(str(_memory.get("last_revisited_at", ""))),
		_format_revisit_outcome(str(_memory.get("last_revisit_outcome", ""))),
		_format_value(str(_memory.get("revisit_suppressed_until", ""))),
		_format_value(str(_memory.get("cluster_id", ""))),
		maxi(0, int(_memory.get("cluster_summary_version", 0))),
		_format_cluster_summary_status(str(_memory.get("cluster_summary_status", ""))),
		maxi(0, int(_memory.get("cluster_summary_proposal_count", 0))),
		maxi(0, int(_memory.get("cluster_summary_accept_count", 0))),
		maxi(0, int(_memory.get("cluster_summary_reject_count", 0))),
		maxi(0, int(_memory.get("cluster_summary_stale_count", 0))),
		_format_value(str(_memory.get("cluster_summary_proposal_model", ""))),
		_format_value(str(_memory.get("cluster_summary_last_decision_at", ""))),
		_format_value(str(_memory.get("cluster_summary", "")))
	]
	evidence_text.text = _build_evidence_text()
	revision_text.text = _build_revision_text()

func _build_evidence_text() -> String:
	var sources: Variant = _memory.get("evidence_sources", [])
	if not sources is Array or sources.is_empty():
		return "暂无可追溯的证据来源。"
	var lines: Array[String] = []
	for index in range(sources.size() - 1, -1, -1):
		var source: Variant = sources[index]
		if not source is Dictionary:
			continue
		lines.append("%d. %s\n   类型：%s\n   来源 ID：%s\n   确认于：%s" % [
			sources.size() - index,
			_format_value(str(source.get("source_title", ""))),
			_format_value(str(source.get("source_type", ""))),
			_format_value(str(source.get("source_id", ""))),
			_format_value(str(source.get("confirmed_at", "")))
		])
	return "\n\n".join(lines) if not lines.is_empty() else "暂无可追溯的证据来源。"

func _build_revision_text() -> String:
	var revisions: Variant = _memory.get("revision_history", [])
	if not revisions is Array or revisions.is_empty():
		return "这条记忆尚未修订。"
	var lines: Array[String] = []
	for index in range(revisions.size() - 1, -1, -1):
		var revision: Variant = revisions[index]
		if not revision is Dictionary:
			continue
		lines.append("%d. %s · %s\n%s" % [
			revisions.size() - index,
			_format_revision_reason(str(revision.get("reason", ""))),
			_format_value(str(revision.get("revised_at", ""))),
			str(revision.get("content", ""))
		])
	return "\n\n".join(lines) if not lines.is_empty() else "这条记忆尚未修订。"

func _format_revision_reason(reason: String) -> String:
	match reason:
		"manual_edit": return "手动编辑"
		"user_correction": return "用户纠正"
		"supersede": return "冲突替代"
		"update": return "自动更新"
		_: return "内容修订"

func _format_revisit_outcome(outcome: String) -> String:
	match outcome:
		MemoryManager.REVISIT_OUTCOME_PRESENTED: return "已展示"
		MemoryManager.REVISIT_OUTCOME_ENGAGED: return "玩家继续谈论"
		MemoryManager.REVISIT_OUTCOME_CONFIRMED: return "玩家确认"
		MemoryManager.REVISIT_OUTCOME_CORRECTED: return "玩家纠正"
		MemoryManager.REVISIT_OUTCOME_DISMISSED: return "暂缓重提"
		_: return "未记录"

func _format_cluster_summary_status(status: String) -> String:
	match status:
		"active": return "有效"
		"proposed": return "待审核"
		"stale": return "待重建"
		"rejected": return "已拒绝"
		"disabled": return "已停用"
		_: return "未生成"

func _format_value(value: String) -> String:
	return value if not value.strip_edges().is_empty() else "未记录"