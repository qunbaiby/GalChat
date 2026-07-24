extends Node

const TraceServiceScript = preload("res://scripts/data/memory_retrieval_trace_service.gd")
const DEFAULT_DATASET_PATH := "user://quality_baselines/real_anonymized_memory_baseline.json"


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var dataset_path := _get_dataset_path()
	var dataset := _load_dataset(dataset_path)
	if dataset.is_empty():
		print("REAL_MEMORY_BASELINE_NOT_READY: 未找到或无法解析 %s" % dataset_path)
		get_tree().quit(2)
		return
	var manager := MemoryManager.new()
	manager.memories = _normalize_memories(dataset.get("memories", {}))
	var service := TraceServiceScript.new()
	var report := service.evaluate_real_anonymized_baseline(dataset, manager)
	if not bool(report.get("ready", false)):
		print("REAL_MEMORY_BASELINE_NOT_READY")
		for violation in report.get("readiness_violations", []):
			print("- %s" % str(violation))
		get_tree().quit(2)
		return
	var replay: Dictionary = report.get("replay", {})
	print("真实匿名样本 %d 条，记忆 %d 条，模型 %s，维度 %d" % [
		int(report.get("case_count", 0)),
		int(report.get("memory_count", 0)),
		str(report.get("embedding_model", "")),
		int(report.get("embedding_dimension", 0))
	])
	print("Recall@K %.3f，Precision@K %.3f，禁止召回 %d" % [
		float(replay.get("recall_at_k", 0.0)),
		float(replay.get("precision_at_k", 0.0)),
		int(replay.get("forbidden_recalled", 0))
	])
	if not bool(report.get("passed", false)):
		print("REAL_MEMORY_BASELINE_FAILED")
		for violation in replay.get("violations", []):
			print("- %s" % str(violation))
		get_tree().quit(1)
		return
	print("REAL_MEMORY_BASELINE_OK")
	get_tree().quit(0)


func _get_dataset_path() -> String:
	var args := OS.get_cmdline_user_args()
	for index in range(args.size() - 1):
		if args[index] == "--dataset":
			return str(args[index + 1])
	return DEFAULT_DATASET_PATH


func _load_dataset(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if parsed is Dictionary else {}


func _normalize_memories(raw_memories: Dictionary) -> Dictionary:
	var normalized := {"core": [], "emotion": [], "habit": [], "bond": []}
	for layer in normalized.keys():
		var entries: Array = raw_memories.get(layer, []) if raw_memories.get(layer, []) is Array else []
		for raw_entry in entries:
			if not raw_entry is Dictionary:
				continue
			var entry: Dictionary = raw_entry.duplicate(true)
			entry["confidence"] = float(entry.get("confidence", 0.8))
			entry["evidence_count"] = int(entry.get("evidence_count", 1))
			entry["day_offset"] = int(entry.get("day_offset", 0))
			entry["memory_domain"] = MemoryManager.MEMORY_DOMAIN_PLAYER
			entry["memory_scope"] = MemoryManager.MEMORY_SCOPE_PLAYER_SHARED
			entry["memory_visibility"] = MemoryManager.MEMORY_VISIBILITY_PROMPT
			entry["embedding_status"] = "ready"
			entry["status"] = MemoryManager.MEMORY_STATUS_ACTIVE
			entry["consolidation_status"] = MemoryManager.CONSOLIDATION_STATUS_CONSOLIDATED
			normalized[layer].append(entry)
	return normalized