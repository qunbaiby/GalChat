extends Node

const DETAIL_SCENE: PackedScene = preload("res://scenes/ui/archive/memory_governance_detail_dialog.tscn")
const MEMORY_ITEM_SCENE: PackedScene = preload("res://scenes/ui/archive/archive_memory_item.tscn")

var failures: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var dialog: Control = DETAIL_SCENE.instantiate() as Control
	add_child(dialog)
	dialog.setup({
		"content": "玩家每天喜欢喝热牛奶",
		"confidence": 0.81,
		"evidence_count": 2,
		"recall_count": 4,
		"successful_use_count": 2,
		"revisit_count": 3,
		"successful_revisit_count": 1,
		"last_revisit_outcome": MemoryManager.REVISIT_OUTCOME_CONFIRMED,
		"revisit_suppressed_until": "2026-08-22T12:30:00",
		"correction_count": 1,
		"decay": 12.0,
		"last_confirmed_at": "2026-07-23T12:00:00",
		"last_recalled_at": "2026-07-23T13:00:00",
		"last_revisited_at": "2026-07-23T12:30:00",
		"cluster_id": "habit-detail-cluster",
		"cluster_summary": "玩家通常喜欢热牛奶。",
		"cluster_summary_status": "active",
		"cluster_summary_version": 2,
		"cluster_summary_proposal_model": "summary-model",
		"cluster_summary_proposal_count": 3,
		"cluster_summary_accept_count": 2,
		"cluster_summary_reject_count": 1,
		"cluster_summary_stale_count": 4,
		"cluster_summary_last_decision_at": "2026-07-23T14:00:00",
		"evidence_sources": [{
			"source_title": "再次确认",
			"source_type": "chat_extraction",
			"source_id": "exchange-2",
			"confirmed_at": "2026-07-23T12:00:00"
		}],
		"revision_history": [{
			"content": "玩家喜欢热牛奶",
			"reason": "manual_edit",
			"revised_at": "2026-07-23T11:00:00"
		}]
	})
	await get_tree().process_frame
	var meta_label: Label = dialog.get_node("Center/Panel/Margin/VBox/MetaLabel") as Label
	var evidence_text: TextEdit = dialog.get_node("Center/Panel/Margin/VBox/Tabs/证据来源/EvidenceText") as TextEdit
	var revision_text: TextEdit = dialog.get_node("Center/Panel/Margin/VBox/Tabs/修订历史/RevisionText") as TextEdit
	_expect(meta_label.text.contains("可信度 81%") and meta_label.text.contains("曝光 4 次") and meta_label.text.contains("主动重访 3 次") and meta_label.text.contains("成功重访 1 次") and meta_label.text.contains("最后重访 2026-07-23T12:30:00") and meta_label.text.contains("最近重访结果 玩家确认") and meta_label.text.contains("暂缓重访至 2026-08-22T12:30:00") and meta_label.text.contains("成功采用 2 次") and meta_label.text.contains("纠正 1 次"), "治理详情没有展示反馈闭环与重访结果元数据。")
	_expect(meta_label.text.contains("习惯聚类 habit-detail-cluster") and meta_label.text.contains("摘要版本 2") and meta_label.text.contains("提案 3 · 接受 2 · 拒绝 1 · 失效 4") and meta_label.text.contains("模型 summary-model") and meta_label.text.contains("玩家通常喜欢热牛奶"), "治理详情没有展示习惯摘要质量与决策审计。")
	_expect(evidence_text.text.contains("再次确认") and evidence_text.text.contains("exchange-2"), "治理详情没有展示证据来源。")
	_expect(revision_text.text.contains("手动编辑") and revision_text.text.contains("玩家喜欢热牛奶"), "治理详情没有展示修订历史。")
	var memory_item: PanelContainer = MEMORY_ITEM_SCENE.instantiate() as PanelContainer
	add_child(memory_item)
	var restore_button: Button = memory_item.get_node("Margin/ItemVBox/ActionRow/RestoreButton") as Button
	_expect(restore_button != null and restore_button.text == "恢复", "记忆归档项缺少软删除恢复操作。")
	var disable_summary_button: Button = memory_item.get_node("Margin/ItemVBox/ClusterSummaryPanel/SummaryMargin/SummaryVBox/SummaryActions/DisableSummaryButton") as Button
	var rebuild_summary_button: Button = memory_item.get_node("Margin/ItemVBox/ClusterSummaryPanel/SummaryMargin/SummaryVBox/SummaryActions/RebuildSummaryButton") as Button
	_expect(disable_summary_button != null and disable_summary_button.text == "停用" and rebuild_summary_button != null and rebuild_summary_button.text == "重新生成", "记忆归档项缺少习惯摘要停用或重建操作。")
	var manager := MemoryManager.new()
	var expired_text := manager.format_deleted_memory_status({"deletion_reason": MemoryManager.DELETION_REASON_CANDIDATE_EXPIRED})
	_expect(expired_text.contains("候选长期未确认") and expired_text.contains("可随时恢复"), "归档没有区分可恢复候选过期和用户删除。")
	manager.queue_free()
	if failures.is_empty():
		print("MEMORY_GOVERNANCE_DETAIL_SMOKE_OK")
		get_tree().quit(0)
		return
	for failure in failures:
		push_error("MEMORY_GOVERNANCE_DETAIL_SMOKE: %s" % failure)
	get_tree().quit(1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)