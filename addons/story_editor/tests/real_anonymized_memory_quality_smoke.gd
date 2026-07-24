extends Node

const TraceServiceScript = preload("res://scripts/data/memory_retrieval_trace_service.gd")
const TEMPLATE_PATH := "res://addons/story_editor/tests/fixtures/real_anonymized_memory_baseline.template.json"

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var service := TraceServiceScript.new()
	var manager := MemoryManager.new()
	manager.memory_file_path_override = "user://real_anonymized_quality_smoke_%d.json" % Time.get_ticks_usec()
	var template := _load_json(TEMPLATE_PATH)
	var template_report := service.evaluate_real_anonymized_baseline(template, manager)
	_expect(not bool(template_report.get("ready", true)) and not bool(template_report.get("passed", true)), "空模板错误获得了真实基线就绪或通过状态。")

	var dataset := _build_compliant_dataset()
	manager.memories = _normalize_memories(dataset.get("memories", {}))
	var ready_report := service.evaluate_real_anonymized_baseline(dataset, manager)
	_expect(bool(ready_report.get("ready", false)) and bool(ready_report.get("passed", false)), "合规真实匿名数据契约无法进入回放评估。")
	_expect(int(ready_report.get("case_count", 0)) == TraceServiceScript.REAL_BASELINE_MIN_CASES, "真实基线没有执行完整最小样本集。")
	_expect(Array(ready_report.get("readiness_violations", [])).is_empty(), "合规真实匿名数据仍产生就绪违规。")

	var unsafe_dataset: Dictionary = dataset.duplicate(true)
	(unsafe_dataset["cases"][0] as Dictionary)["query_text"] = "不应保留的原始玩家文本"
	var unsafe_report := service.evaluate_real_anonymized_baseline(unsafe_dataset, manager)
	_expect(not bool(unsafe_report.get("ready", true)) and Array(unsafe_report.get("readiness_violations", [])).any(func(item): return str(item).contains("禁止字段 query_text")), "包含原始查询文本的数据集没有被阻断。")

	manager.queue_free()
	service.queue_free()
	if failures.is_empty():
		print("REAL_ANONYMIZED_MEMORY_QUALITY_SMOKE_OK")
		get_tree().quit(0)
		return
	for failure in failures:
		push_error("REAL_ANONYMIZED_MEMORY_QUALITY_SMOKE: %s" % failure)
	get_tree().quit(1)


func _build_compliant_dataset() -> Dictionary:
	var cases: Array = []
	var categories: Array[String] = ["positive", "near_negative", "negation", "conflict"]
	for index in TraceServiceScript.REAL_BASELINE_MIN_CASES:
		cases.append({
			"name": "reviewed-sample-%02d" % index,
			"category": categories[index % categories.size()],
			"sample_origin": "real_session",
			"anonymization_reviewed": true,
			"query_embedding": [1.0, 0.0],
			"expected_memory_ids": ["reviewed-memory"],
			"forbidden_memory_ids": ["reviewed-negative"]
		})
	return {
		"schema_version": TraceServiceScript.REAL_BASELINE_SCHEMA_VERSION,
		"dataset_kind": "real_anonymized_memory_retrieval",
		"provenance": {
			"source": "consented_local_sessions",
			"user_reviewed": true,
			"anonymization_status": "reviewed"
		},
		"embedding_model": "reviewed-model-v1",
		"embedding_dimension": 2,
		"memories": {
			"core": [],
			"emotion": [],
			"habit": [
				{"id": "reviewed-memory", "content": "经人工复核的匿名偏好", "embedding": [1.0, 0.0], "anonymization_reviewed": true},
				{"id": "reviewed-negative", "content": "经人工复核的匿名近邻负例", "embedding": [0.0, 1.0], "anonymization_reviewed": true}
			],
			"bond": []
		},
		"cases": cases
	}


func _normalize_memories(raw_memories: Dictionary) -> Dictionary:
	var normalized := {"core": [], "emotion": [], "habit": [], "bond": []}
	for layer in normalized.keys():
		for raw_memory in raw_memories.get(layer, []):
			var memory: Dictionary = raw_memory.duplicate(true)
			memory["memory_domain"] = MemoryManager.MEMORY_DOMAIN_PLAYER
			memory["memory_scope"] = MemoryManager.MEMORY_SCOPE_PLAYER_SHARED
			memory["memory_visibility"] = MemoryManager.MEMORY_VISIBILITY_PROMPT
			memory["status"] = MemoryManager.MEMORY_STATUS_ACTIVE
			memory["confidence"] = 0.8
			memory["consolidation_status"] = MemoryManager.CONSOLIDATION_STATUS_CONSOLIDATED
			normalized[layer].append(memory)
	return normalized


func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if parsed is Dictionary else {}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)