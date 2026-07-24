class_name MemoryRetrievalTraceService
extends Node

const SafeFileAccessUtil = preload("res://scripts/utils/safe_file_access.gd")
const SAVE_FILE_NAME := "memory_retrieval_traces.json"
const SCHEMA_VERSION := 1
const MAX_TRACES := 50
const MAX_QUERY_CHARS := 240
const MIN_REPLAY_RECALL_AT_K := 1.0
const MIN_REPLAY_PRECISION_AT_K := 0.5
const MAX_REPLAY_FORBIDDEN_RECALLED := 0
const MIN_CLUSTER_REPLAY_EQUIVALENCE_RATE := 1.0
const MAX_CLUSTER_REPLAY_PROMPT_GROWTH_CHARS := 0
const REAL_BASELINE_SCHEMA_VERSION := 1
const REAL_BASELINE_MIN_CASES := 12
const REAL_BASELINE_MIN_CASES_PER_CATEGORY := 2
const REAL_BASELINE_REQUIRED_CATEGORIES := ["positive", "near_negative", "negation", "conflict"]
const REAL_BASELINE_FORBIDDEN_FIELDS := ["query_text", "archive_id", "character_id", "player_name", "source_refs", "timestamp", "created_at", "updated_at"]

signal traces_changed()

var traces: Array = []
var save_path_override: String = ""

func get_save_path() -> String:
	if not save_path_override.is_empty():
		return save_path_override
	var character_id := "default"
	if GameDataManager.config and not str(GameDataManager.config.current_character_id).is_empty():
		character_id = str(GameDataManager.config.current_character_id)
	return GameDataManager.get_character_save_path(SAVE_FILE_NAME, character_id)

func load_traces() -> void:
	traces.clear()
	var path := get_save_path()
	if not FileAccess.file_exists(path):
		traces_changed.emit()
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary and int(parsed.get("schema_version", 0)) == SCHEMA_VERSION and parsed.get("traces", []) is Array:
		traces = parsed.get("traces", []).slice(0, MAX_TRACES)
	traces_changed.emit()

func record_trace(query_text: String, template_name: String, summary_channel: String, result: Dictionary, request_id: String = "", trace_context: Dictionary = {}) -> Dictionary:
	var selected: Array = result.get("selected", []) if result.get("selected", []) is Array else []
	var rejected: Array = result.get("rejected", []) if result.get("rejected", []) is Array else []
	var rendered_ids: Array[String] = []
	var selected_items: Array = []
	for candidate in selected:
		if not candidate is Dictionary:
			continue
		var sanitized := _sanitize_candidate(candidate)
		selected_items.append(sanitized)
		if bool(sanitized.get("rendered", false)):
			rendered_ids.append(str(sanitized.get("memory_id", "")))
	var trace := {
		"id": "%d-%d" % [int(Time.get_unix_time_from_system()), Time.get_ticks_usec()],
		"request_id": request_id,
		"created_at": Time.get_datetime_string_from_system(),
		"archive_id": GameDataManager.get_active_archive_id(),
		"character_id": str(GameDataManager.config.current_character_id) if GameDataManager.config else "default",
		"query_text": query_text.strip_edges().left(MAX_QUERY_CHARS),
		"template_name": template_name,
		"summary_channel": summary_channel,
		"revisit_event_id": str(trace_context.get("revisit_event_id", "")),
		"revisit_memory_id": str(trace_context.get("revisit_memory_id", "")),
		"revisit_layer": str(trace_context.get("revisit_layer", "")),
		"revisit_context_domain": str(trace_context.get("revisit_context_domain", "")),
		"revisit_delivery_status": "pending" if not str(trace_context.get("revisit_event_id", "")).is_empty() else "",
		"revisit_outcome": "",
		"revisit_outcome_at": "",
		"access_subject_id": str(result.get("access_subject_id", "")),
		"emotion_context": _sanitize_emotion_context(result.get("emotion_context", {})),
		"has_query_embedding": bool(result.get("has_query", false)),
		"query_dimension": int(result.get("query_dimension", 0)),
		"selected": selected_items,
		"rejected": rejected.map(func(candidate): return _sanitize_candidate(candidate) if candidate is Dictionary else {}),
		"rendered_memory_ids": rendered_ids,
		"memory_prompt_chars": int(result.get("memory_prompt_chars", result.get("prompt_chars", 0))),
		"diary_chars": int(result.get("diary_chars", 0)),
		"summary_chars": int(result.get("summary_chars", 0)),
		"story_knowledge_chars": int(result.get("story_knowledge_chars", 0)),
		"prompt_chars": int(result.get("prompt_chars", 0)),
		"max_prompt_chars": int(result.get("max_prompt_chars", 0)),
		"truncated": bool(result.get("truncated", false))
		,"status": "prompt_built"
		,"response_chars": 0
		,"adopted_chars": 0
		,"completed_at": ""
		,"adopted_at": ""
		,"last_error": ""
	}
	traces.push_front(trace)
	if traces.size() > MAX_TRACES:
		traces.resize(MAX_TRACES)
	_save_traces()
	traces_changed.emit()
	return trace.duplicate(true)

func _sanitize_emotion_context(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {}
	var context: Dictionary = value
	var mood_id := str(context.get("macro_mood_id", "")).strip_edges().to_lower()
	if mood_id.is_empty() or not MemoryManager.MOOD_ORDER.has(mood_id):
		return {}
	return {
		"macro_mood_id": mood_id,
		"confidence": clampf(float(context.get("confidence", 0.0)), 0.0, 1.0),
		"source": str(context.get("source", "")),
		"observed_at_unix": float(context.get("observed_at_unix", 0.0)),
		"expires_at_unix": float(context.get("expires_at_unix", 0.0))
	}

func update_trace(trace_id: String, patch: Dictionary) -> bool:
	if trace_id.is_empty():
		return false
	for trace in traces:
		if str(trace.get("id", "")) != trace_id:
			continue
		for key in patch.keys():
			trace[key] = patch[key]
		_save_traces()
		traces_changed.emit()
		return true
	return false

func mark_request_started(trace_id: String) -> bool:
	return update_trace(trace_id, {"status": "request_started"})

func mark_response_completed(trace_id: String, response_text: String) -> bool:
	return update_trace(trace_id, {
		"status": "response_completed",
		"response_chars": response_text.length(),
		"completed_at": Time.get_datetime_string_from_system()
	})

func mark_response_adopted(trace_id: String, adopted_text: String, segment_index: int = 0) -> bool:
	if trace_id.is_empty() or adopted_text.strip_edges().is_empty():
		return false
	for trace in traces:
		if str(trace.get("id", "")) != trace_id:
			continue
		trace["status"] = "response_adopted"
		trace["adopted_chars"] = int(trace.get("adopted_chars", 0)) + adopted_text.length()
		trace["adopted_segment_count"] = maxi(int(trace.get("adopted_segment_count", 0)), segment_index + 1)
		trace["adopted_at"] = Time.get_datetime_string_from_system()
		if not str(trace.get("revisit_event_id", "")).is_empty():
			trace["revisit_delivery_status"] = "presented"
		_save_traces()
		traces_changed.emit()
		return true
	return false

func mark_request_failed(trace_id: String, error_message: String, cancelled: bool = false) -> bool:
	var patch := {
		"status": "cancelled" if cancelled else "failed",
		"last_error": error_message.left(240)
	}
	for trace in traces:
		if str(trace.get("id", "")) == trace_id and not str(trace.get("revisit_event_id", "")).is_empty():
			patch["revisit_delivery_status"] = "cancelled" if cancelled else "failed"
			break
	return update_trace(trace_id, patch)

func mark_revisit_outcome(revisit_event_id: String, outcome: String) -> bool:
	if revisit_event_id.is_empty():
		return false
	for trace in traces:
		if str(trace.get("revisit_event_id", "")) != revisit_event_id:
			continue
		trace["revisit_outcome"] = outcome
		trace["revisit_outcome_at"] = Time.get_datetime_string_from_system()
		_save_traces()
		traces_changed.emit()
		return true
	return false

func get_recent_traces(limit: int = 20) -> Array:
	return traces.slice(0, clampi(limit, 0, MAX_TRACES)).duplicate(true)

func clear_traces() -> void:
	traces.clear()
	_save_traces()
	traces_changed.emit()

func evaluate_replay_cases(cases: Array, memory_manager) -> Dictionary:
	var expected_total := 0
	var recalled_expected := 0
	var rendered_total := 0
	var forbidden_recalled := 0
	var case_results: Array = []
	for raw_case in cases:
		if not raw_case is Dictionary:
			continue
		var expected_ids: Array = raw_case.get("expected_memory_ids", []) if raw_case.get("expected_memory_ids", []) is Array else []
		var forbidden_ids: Array = raw_case.get("forbidden_memory_ids", []) if raw_case.get("forbidden_memory_ids", []) is Array else []
		var result: Dictionary = memory_manager.build_memory_prompt_result(raw_case.get("query_embedding", []), raw_case.get("query_options", {}))
		var rendered_ids: Array = []
		for candidate in result.get("selected", []):
			if bool(candidate.get("rendered", false)):
				rendered_ids.append(str(candidate.get("memory_id", "")))
		var hits := 0
		for memory_id in expected_ids:
			if rendered_ids.has(str(memory_id)):
				hits += 1
		for memory_id in forbidden_ids:
			if rendered_ids.has(str(memory_id)):
				forbidden_recalled += 1
		expected_total += expected_ids.size()
		recalled_expected += hits
		rendered_total += rendered_ids.size()
		case_results.append({
			"name": str(raw_case.get("name", "未命名回放")),
			"rendered_memory_ids": rendered_ids,
			"expected_hits": hits,
			"expected_total": expected_ids.size(),
			"forbidden_hits": forbidden_ids.filter(func(memory_id): return rendered_ids.has(str(memory_id))).size(),
			"prompt_chars": int(result.get("prompt_chars", 0))
		})
	var recall_at_k := float(recalled_expected) / float(expected_total) if expected_total > 0 else 1.0
	var precision_at_k := float(recalled_expected) / float(rendered_total) if rendered_total > 0 else 1.0
	var violations: Array[String] = []
	if recall_at_k < MIN_REPLAY_RECALL_AT_K:
		violations.append("Recall@K %.3f 低于门槛 %.3f" % [recall_at_k, MIN_REPLAY_RECALL_AT_K])
	if precision_at_k < MIN_REPLAY_PRECISION_AT_K:
		violations.append("Precision@K %.3f 低于门槛 %.3f" % [precision_at_k, MIN_REPLAY_PRECISION_AT_K])
	if forbidden_recalled > MAX_REPLAY_FORBIDDEN_RECALLED:
		violations.append("禁止记忆召回 %d 条，超过门槛 %d 条" % [forbidden_recalled, MAX_REPLAY_FORBIDDEN_RECALLED])
	return {
		"case_count": case_results.size(),
		"recall_at_k": recall_at_k,
		"precision_at_k": precision_at_k,
		"forbidden_recalled": forbidden_recalled,
		"passed": violations.is_empty(),
		"violations": violations,
		"thresholds": {
			"min_recall_at_k": MIN_REPLAY_RECALL_AT_K,
			"min_precision_at_k": MIN_REPLAY_PRECISION_AT_K,
			"max_forbidden_recalled": MAX_REPLAY_FORBIDDEN_RECALLED
		},
		"results": case_results
	}

func evaluate_real_anonymized_baseline(dataset: Dictionary, memory_manager) -> Dictionary:
	var readiness_violations: Array[String] = []
	if int(dataset.get("schema_version", 0)) != REAL_BASELINE_SCHEMA_VERSION:
		readiness_violations.append("真实匿名基线 schema_version 必须为 %d" % REAL_BASELINE_SCHEMA_VERSION)
	if str(dataset.get("dataset_kind", "")) != "real_anonymized_memory_retrieval":
		readiness_violations.append("dataset_kind 不是真实匿名记忆检索基线")
	var provenance: Dictionary = dataset.get("provenance", {}) if dataset.get("provenance", {}) is Dictionary else {}
	if str(provenance.get("source", "")) != "consented_local_sessions":
		readiness_violations.append("数据来源必须是获得同意的本地会话")
	if not bool(provenance.get("user_reviewed", false)):
		readiness_violations.append("数据集尚未经过用户人工复核")
	if str(provenance.get("anonymization_status", "")) != "reviewed":
		readiness_violations.append("脱敏状态必须为 reviewed")
	var embedding_model := str(dataset.get("embedding_model", "")).strip_edges()
	var embedding_dimension := int(dataset.get("embedding_dimension", 0))
	if embedding_model.is_empty() or embedding_dimension <= 0:
		readiness_violations.append("缺少真实 embedding 模型或维度")
	var cases: Array = dataset.get("cases", []) if dataset.get("cases", []) is Array else []
	var memories: Dictionary = dataset.get("memories", {}) if dataset.get("memories", {}) is Dictionary else {}
	var memory_ids: Dictionary = {}
	var memory_count := 0
	for layer in ["core", "emotion", "habit", "bond"]:
		var layer_memories: Array = memories.get(layer, []) if memories.get(layer, []) is Array else []
		for raw_memory in layer_memories:
			if not raw_memory is Dictionary:
				readiness_violations.append("记忆层 %s 存在非对象记录" % layer)
				continue
			var memory_id := str(raw_memory.get("id", "")).strip_edges()
			if memory_id.is_empty() or memory_ids.has(memory_id):
				readiness_violations.append("记忆 ID 为空或重复：%s" % memory_id)
			else:
				memory_ids[memory_id] = true
			var content := str(raw_memory.get("content", "")).strip_edges()
			if content.is_empty() or not bool(raw_memory.get("anonymization_reviewed", false)):
				readiness_violations.append("记忆 %s 缺少内容或人工脱敏复核" % memory_id)
			var memory_embedding: Array = raw_memory.get("embedding", []) if raw_memory.get("embedding", []) is Array else []
			if memory_embedding.size() != embedding_dimension:
				readiness_violations.append("记忆 %s 的向量维度不匹配" % memory_id)
			for forbidden_field in REAL_BASELINE_FORBIDDEN_FIELDS:
				if raw_memory.has(forbidden_field):
					readiness_violations.append("记忆 %s 包含禁止字段 %s" % [memory_id, forbidden_field])
			memory_count += 1
	if memory_count == 0:
		readiness_violations.append("真实匿名基线没有记忆语料")
	if cases.size() < REAL_BASELINE_MIN_CASES:
		readiness_violations.append("真实样本 %d 条，少于最低要求 %d 条" % [cases.size(), REAL_BASELINE_MIN_CASES])
	var category_counts: Dictionary = {}
	for category in REAL_BASELINE_REQUIRED_CATEGORIES:
		category_counts[category] = 0
	for raw_case in cases:
		if not raw_case is Dictionary:
			readiness_violations.append("存在非对象样本")
			continue
		var category := str(raw_case.get("category", ""))
		if not category_counts.has(category):
			readiness_violations.append("样本包含未知难例类别：%s" % category)
		else:
			category_counts[category] = int(category_counts[category]) + 1
		for forbidden_field in REAL_BASELINE_FORBIDDEN_FIELDS:
			if raw_case.has(forbidden_field):
				readiness_violations.append("样本 %s 包含禁止字段 %s" % [str(raw_case.get("name", "未命名")), forbidden_field])
		if str(raw_case.get("sample_origin", "")) != "real_session" or not bool(raw_case.get("anonymization_reviewed", false)):
			readiness_violations.append("样本 %s 未声明真实来源和人工脱敏复核" % str(raw_case.get("name", "未命名")))
		var query_embedding: Array = raw_case.get("query_embedding", []) if raw_case.get("query_embedding", []) is Array else []
		if query_embedding.size() != embedding_dimension:
			readiness_violations.append("样本 %s 的查询向量维度不匹配" % str(raw_case.get("name", "未命名")))
		var expected_ids: Array = raw_case.get("expected_memory_ids", []) if raw_case.get("expected_memory_ids", []) is Array else []
		var forbidden_ids: Array = raw_case.get("forbidden_memory_ids", []) if raw_case.get("forbidden_memory_ids", []) is Array else []
		if expected_ids.is_empty() and forbidden_ids.is_empty():
			readiness_violations.append("样本 %s 没有人工召回标注" % str(raw_case.get("name", "未命名")))
		for memory_id in expected_ids + forbidden_ids:
			if not memory_ids.has(str(memory_id)):
				readiness_violations.append("样本 %s 引用了不存在的记忆 %s" % [str(raw_case.get("name", "未命名")), str(memory_id)])
	for category in REAL_BASELINE_REQUIRED_CATEGORIES:
		if int(category_counts.get(category, 0)) < REAL_BASELINE_MIN_CASES_PER_CATEGORY:
			readiness_violations.append("类别 %s 只有 %d 条，少于最低要求 %d 条" % [category, int(category_counts.get(category, 0)), REAL_BASELINE_MIN_CASES_PER_CATEGORY])
	var ready := readiness_violations.is_empty()
	var replay_result: Dictionary = evaluate_replay_cases(cases, memory_manager) if ready else {}
	return {
		"report_type": "real_anonymized_memory_quality",
		"ready": ready,
		"passed": ready and bool(replay_result.get("passed", false)),
		"readiness_violations": readiness_violations,
		"case_count": cases.size(),
		"memory_count": memory_count,
		"category_counts": category_counts,
		"embedding_model": embedding_model,
		"embedding_dimension": embedding_dimension,
		"replay": replay_result,
		"requirements": {
			"min_cases": REAL_BASELINE_MIN_CASES,
			"min_cases_per_category": REAL_BASELINE_MIN_CASES_PER_CATEGORY,
			"required_categories": REAL_BASELINE_REQUIRED_CATEGORIES.duplicate()
			,"forbidden_fields": REAL_BASELINE_FORBIDDEN_FIELDS.duplicate()
		}
	}

func evaluate_habit_cluster_replay_cases(cases: Array, memory_manager) -> Dictionary:
	var original_memories: Dictionary = memory_manager.memories.duplicate(true)
	var case_results: Array = []
	var equivalent_cases := 0
	var forbidden_recalled := 0
	var total_prompt_chars_before := 0
	var total_prompt_chars_after := 0
	var violations: Array[String] = []
	for raw_case in cases:
		if not raw_case is Dictionary:
			continue
		var case_memories: Variant = raw_case.get("memories", original_memories)
		memory_manager.memories = case_memories.duplicate(true) if case_memories is Dictionary else original_memories.duplicate(true)
		var member_ids: Array = raw_case.get("member_memory_ids", []) if raw_case.get("member_memory_ids", []) is Array else []
		var expected_ids: Array = raw_case.get("expected_memory_ids", member_ids) if raw_case.get("expected_memory_ids", member_ids) is Array else []
		var forbidden_ids: Array = raw_case.get("forbidden_memory_ids", []) if raw_case.get("forbidden_memory_ids", []) is Array else []
		var query_embedding: Array = raw_case.get("query_embedding", []) if raw_case.get("query_embedding", []) is Array else []
		var query_options: Dictionary = raw_case.get("query_options", {}) if raw_case.get("query_options", {}) is Dictionary else {}
		var baseline_result: Dictionary = memory_manager.build_memory_prompt_result(query_embedding, query_options)
		var baseline_covered_ids := _get_logically_rendered_memory_ids(baseline_result)
		var matching_cluster: Dictionary = {}
		for cluster in memory_manager.build_habit_clusters():
			if Array(cluster.get("member_memory_ids", [])) == member_ids:
				matching_cluster = cluster
				break
		var summary_applied: bool = not matching_cluster.is_empty() and memory_manager.apply_habit_cluster_summary(
			str(matching_cluster.get("cluster_id", "")),
			member_ids,
			str(raw_case.get("summary", ""))
		)
		var summarized_result: Dictionary = memory_manager.build_memory_prompt_result(query_embedding, query_options) if summary_applied else {}
		var summarized_covered_ids := _get_logically_rendered_memory_ids(summarized_result)
		var baseline_expected_hits := expected_ids.filter(func(memory_id): return baseline_covered_ids.has(str(memory_id)))
		var summarized_expected_hits := expected_ids.filter(func(memory_id): return summarized_covered_ids.has(str(memory_id)))
		var baseline_forbidden_hits := forbidden_ids.filter(func(memory_id): return baseline_covered_ids.has(str(memory_id)))
		var summarized_forbidden_hits := forbidden_ids.filter(func(memory_id): return summarized_covered_ids.has(str(memory_id)))
		var summary_candidates: Array = summarized_result.get("selected", []).filter(func(candidate): return bool(candidate.get("rendered", false)) and bool(candidate.get("uses_cluster_summary", false))) if not summarized_result.is_empty() else []
		var baseline_chars := str(baseline_result.get("prompt", "")).length()
		var summarized_chars := str(summarized_result.get("prompt", "")).length()
		var equivalent: bool = summary_applied \
			and baseline_expected_hits.size() == expected_ids.size() \
			and summarized_expected_hits.size() == expected_ids.size() \
			and baseline_forbidden_hits.is_empty() \
			and summarized_forbidden_hits.is_empty() \
			and summary_candidates.size() == 1 \
			and summarized_chars <= baseline_chars + MAX_CLUSTER_REPLAY_PROMPT_GROWTH_CHARS
		if equivalent:
			equivalent_cases += 1
		else:
			violations.append("%s 摘要前后逻辑召回不等价" % str(raw_case.get("name", "未命名聚类回放")))
		forbidden_recalled += baseline_forbidden_hits.size() + summarized_forbidden_hits.size()
		total_prompt_chars_before += baseline_chars
		total_prompt_chars_after += summarized_chars
		case_results.append({
			"name": str(raw_case.get("name", "未命名聚类回放")),
			"summary_applied": summary_applied,
			"equivalent": equivalent,
			"baseline_covered_memory_ids": baseline_covered_ids,
			"summarized_covered_memory_ids": summarized_covered_ids,
			"summary_candidate_count": summary_candidates.size(),
			"prompt_chars_before": baseline_chars,
			"prompt_chars_after": summarized_chars,
			"saved_prompt_chars": maxi(0, baseline_chars - summarized_chars),
			"forbidden_hits": baseline_forbidden_hits.size() + summarized_forbidden_hits.size()
		})
	memory_manager.memories = original_memories
	var equivalence_rate := float(equivalent_cases) / float(case_results.size()) if not case_results.is_empty() else 1.0
	if equivalence_rate < MIN_CLUSTER_REPLAY_EQUIVALENCE_RATE and violations.is_empty():
		violations.append("聚类摘要等价率 %.3f 低于门槛 %.3f" % [equivalence_rate, MIN_CLUSTER_REPLAY_EQUIVALENCE_RATE])
	return {
		"case_count": case_results.size(),
		"equivalent_case_count": equivalent_cases,
		"equivalence_rate": equivalence_rate,
		"forbidden_recalled": forbidden_recalled,
		"prompt_chars_before": total_prompt_chars_before,
		"prompt_chars_after": total_prompt_chars_after,
		"saved_prompt_chars": maxi(0, total_prompt_chars_before - total_prompt_chars_after),
		"passed": violations.is_empty() and forbidden_recalled == 0,
		"violations": violations,
		"thresholds": {
			"min_equivalence_rate": MIN_CLUSTER_REPLAY_EQUIVALENCE_RATE,
			"max_prompt_growth_chars": MAX_CLUSTER_REPLAY_PROMPT_GROWTH_CHARS,
			"max_forbidden_recalled": 0
		},
		"results": case_results
	}

func _get_logically_rendered_memory_ids(result: Dictionary) -> Array[String]:
	var memory_ids: Array[String] = []
	for candidate in result.get("selected", []):
		if not candidate is Dictionary or not bool(candidate.get("rendered", false)):
			continue
		var covered_ids: Array = candidate.get("cluster_member_memory_ids", []) if bool(candidate.get("uses_cluster_summary", false)) and candidate.get("cluster_member_memory_ids", []) is Array else [str(candidate.get("memory_id", ""))]
		for memory_id in covered_ids:
			var normalized_id := str(memory_id)
			if not normalized_id.is_empty() and not memory_ids.has(normalized_id):
				memory_ids.append(normalized_id)
	return memory_ids

func evaluate_habit_cluster_thresholds(cases: Array, thresholds: Array, memory_manager) -> Dictionary:
	var original_memories: Dictionary = memory_manager.memories.duplicate(true)
	var threshold_results: Array = []
	var safe_thresholds: Array[float] = []
	for raw_threshold in thresholds:
		var threshold := float(raw_threshold)
		var exact_cases := 0
		var underclustered_cases := 0
		var overclustered_cases := 0
		var case_results: Array = []
		for raw_case in cases:
			if not raw_case is Dictionary:
				continue
			var case_memories: Variant = raw_case.get("memories", original_memories)
			memory_manager.memories = case_memories.duplicate(true) if case_memories is Dictionary else original_memories.duplicate(true)
			var expected_ids: Array = raw_case.get("member_memory_ids", []) if raw_case.get("member_memory_ids", []) is Array else []
			var forbidden_ids: Array = raw_case.get("forbidden_cluster_memory_ids", []) if raw_case.get("forbidden_cluster_memory_ids", []) is Array else []
			var matching_ids: Array = []
			for cluster in memory_manager.build_habit_clusters(threshold):
				var cluster_ids: Array = cluster.get("member_memory_ids", []) if cluster.get("member_memory_ids", []) is Array else []
				if expected_ids.any(func(memory_id): return cluster_ids.has(str(memory_id))):
					matching_ids = cluster_ids
					break
			var missing_ids := expected_ids.filter(func(memory_id): return not matching_ids.has(str(memory_id)))
			var forbidden_hits := forbidden_ids.filter(func(memory_id): return matching_ids.has(str(memory_id)))
			var exact := missing_ids.is_empty() and forbidden_hits.is_empty() and matching_ids.size() == expected_ids.size()
			if exact:
				exact_cases += 1
			if not missing_ids.is_empty():
				underclustered_cases += 1
			if not forbidden_hits.is_empty() or matching_ids.size() > expected_ids.size():
				overclustered_cases += 1
			case_results.append({
				"name": str(raw_case.get("name", "未命名阈值回放")),
				"exact": exact,
				"clustered_memory_ids": matching_ids,
				"missing_expected_memory_ids": missing_ids,
				"forbidden_cluster_hits": forbidden_hits
			})
		var passed := not case_results.is_empty() and exact_cases == case_results.size()
		if passed:
			safe_thresholds.append(threshold)
		threshold_results.append({
			"threshold": threshold,
			"case_count": case_results.size(),
			"exact_case_count": exact_cases,
			"underclustered_case_count": underclustered_cases,
			"overclustered_case_count": overclustered_cases,
			"passed": passed,
			"results": case_results
		})
	memory_manager.memories = original_memories
	return {
		"case_count": cases.size(),
		"threshold_count": threshold_results.size(),
		"safe_thresholds": safe_thresholds,
		"passed": not safe_thresholds.is_empty(),
		"results": threshold_results
	}

func evaluate_story_access_cases(cases: Array, story_memory_manager) -> Dictionary:
	var case_results: Array = []
	var violations: Array[String] = []
	for raw_case in cases:
		if not raw_case is Dictionary:
			continue
		var result: Dictionary = story_memory_manager.build_story_knowledge_prompt_result(raw_case.get("access_context", {}))
		var rendered_ids: Array = result.get("selected", []).filter(func(candidate): return bool(candidate.get("rendered", false))).map(func(candidate): return str(candidate.get("memory_id", "")))
		var expected_ids: Array = raw_case.get("expected_memory_ids", []) if raw_case.get("expected_memory_ids", []) is Array else []
		var forbidden_ids: Array = raw_case.get("forbidden_memory_ids", []) if raw_case.get("forbidden_memory_ids", []) is Array else []
		var missing_expected: Array = expected_ids.filter(func(memory_id): return not rendered_ids.has(str(memory_id)))
		var forbidden_hits: Array = forbidden_ids.filter(func(memory_id): return rendered_ids.has(str(memory_id)))
		if not missing_expected.is_empty():
			violations.append("%s 缺少应允许故事记忆：%s" % [str(raw_case.get("name", "未命名故事回放")), ", ".join(missing_expected)])
		if not forbidden_hits.is_empty():
			violations.append("%s 泄漏禁止故事记忆：%s" % [str(raw_case.get("name", "未命名故事回放")), ", ".join(forbidden_hits)])
		case_results.append({
			"name": str(raw_case.get("name", "未命名故事回放")),
			"rendered_memory_ids": rendered_ids,
			"missing_expected": missing_expected,
			"forbidden_hits": forbidden_hits,
			"rejection_reasons": result.get("rejected", []).map(func(candidate): return str(candidate.get("reason", "")))
		})
	return {
		"case_count": case_results.size(),
		"passed": violations.is_empty(),
		"violations": violations,
		"results": case_results
	}

func evaluate_governance_report(memory_manager, trace_limit: int = MAX_TRACES) -> Dictionary:
	var by_layer: Dictionary = {}
	var active_candidates := 0
	var protected_count := 0
	var capacity_expired := 0
	var time_expired := 0
	var restored_count := 0
	var eligible_memories := 0
	var tagged_memories := 0
	var validly_tagged_memories := 0
	var invalid_memories := 0
	var invalid_tag_count := 0
	var duplicate_tag_count := 0
	var tag_distribution: Dictionary = {}
	var active_habit_clusters: Dictionary = {}
	var stale_habit_clusters: Dictionary = {}
	var habit_cluster_records: Dictionary = {}
	for layer in memory_manager.memories.keys():
		var layer_candidates := 0
		for memory in memory_manager.memories.get(layer, []):
			if not memory is Dictionary:
				continue
			if layer == "habit":
				var cluster_id := str(memory.get("cluster_id", ""))
				var summary_status := str(memory.get("cluster_summary_status", ""))
				if not cluster_id.is_empty() and not habit_cluster_records.has(cluster_id):
					habit_cluster_records[cluster_id] = {
						"status": summary_status,
						"summary": str(memory.get("cluster_summary", "")),
						"member_ids": memory.get("cluster_summary_member_memory_ids", []).duplicate() if memory.get("cluster_summary_member_memory_ids", []) is Array else [],
						"proposal_count": int(memory.get("cluster_summary_proposal_count", 0)),
						"accept_count": int(memory.get("cluster_summary_accept_count", 0)),
						"reject_count": int(memory.get("cluster_summary_reject_count", 0)),
						"stale_count": int(memory.get("cluster_summary_stale_count", 0))
					}
				if not cluster_id.is_empty() and summary_status == "active":
					active_habit_clusters[cluster_id] = memory.get("cluster_summary_member_memory_ids", []).duplicate() if memory.get("cluster_summary_member_memory_ids", []) is Array else []
				elif not cluster_id.is_empty() and summary_status == "stale":
					stale_habit_clusters[cluster_id] = true
			var status := str(memory.get("status", MemoryManager.MEMORY_STATUS_ACTIVE))
			var deletion_reason := str(memory.get("deletion_reason", ""))
			if deletion_reason == MemoryManager.DELETION_REASON_CANDIDATE_CAPACITY:
				capacity_expired += 1
			elif deletion_reason == MemoryManager.DELETION_REASON_CANDIDATE_EXPIRED:
				time_expired += 1
			if not str(memory.get("restored_at", "")).is_empty():
				restored_count += 1
			if status != MemoryManager.MEMORY_STATUS_ACTIVE:
				continue
			if str(memory.get("consolidation_status", "")) == MemoryManager.CONSOLIDATION_STATUS_CANDIDATE and not bool(memory.get("is_pinned", false)) and not bool(memory.get("is_bond_mark", false)):
				layer_candidates += 1
				active_candidates += 1
			elif layer == "core" or layer == "bond" or bool(memory.get("is_pinned", false)) or memory_manager.get_memory_consolidation_status(memory) == MemoryManager.CONSOLIDATION_STATUS_CONSOLIDATED:
				protected_count += 1
			if layer == "core":
				continue
			eligible_memories += 1
			var raw_tags: Array = memory.get("emotion_tags", []) if memory.get("emotion_tags", []) is Array else []
			if raw_tags.is_empty():
				continue
			tagged_memories += 1
			var seen: Dictionary = {}
			var memory_invalid := false
			for raw_tag in raw_tags:
				var tag := str(raw_tag).strip_edges().to_lower()
				if seen.has(tag):
					duplicate_tag_count += 1
					memory_invalid = true
					continue
				seen[tag] = true
				if not MemoryManager.MOOD_ORDER.has(tag):
					invalid_tag_count += 1
					memory_invalid = true
					continue
				tag_distribution[tag] = int(tag_distribution.get(tag, 0)) + 1
			if memory_invalid:
				invalid_memories += 1
			else:
				validly_tagged_memories += 1
		if MemoryManager.CANDIDATE_LAYER_CAPACITY.has(layer):
			by_layer[layer] = {"active": layer_candidates, "capacity": int(MemoryManager.CANDIDATE_LAYER_CAPACITY[layer])}
	var affinity_counts := {"match": 0, "near": 0, "conflict": 0, "neutral": 0, "ignored_core": 0}
	var traced_candidates := 0
	var rendered_influenced := 0
	var revisit_feedback := {
		"started": 0,
		"presented": 0,
		"failed": 0,
		"cancelled": 0,
		"engaged": 0,
		"confirmed": 0,
		"corrected": 0,
		"dismissed": 0,
		"explicit_feedback_count": 0
	}
	for trace in get_recent_traces(trace_limit):
		if not str(trace.get("revisit_event_id", "")).is_empty():
			revisit_feedback["started"] = int(revisit_feedback["started"]) + 1
			var delivery_status := str(trace.get("revisit_delivery_status", ""))
			if revisit_feedback.has(delivery_status):
				revisit_feedback[delivery_status] = int(revisit_feedback[delivery_status]) + 1
			var revisit_outcome := str(trace.get("revisit_outcome", ""))
			if revisit_feedback.has(revisit_outcome):
				revisit_feedback[revisit_outcome] = int(revisit_feedback[revisit_outcome]) + 1
				revisit_feedback["explicit_feedback_count"] = int(revisit_feedback["explicit_feedback_count"]) + 1
		for candidate in trace.get("selected", []) + trace.get("rejected", []):
			if not candidate is Dictionary or str(candidate.get("memory_domain", MemoryManager.MEMORY_DOMAIN_PLAYER)) != MemoryManager.MEMORY_DOMAIN_PLAYER:
				continue
			traced_candidates += 1
			var affinity := str(candidate.get("emotion_affinity", "neutral"))
			affinity_counts[affinity] = int(affinity_counts.get(affinity, 0)) + 1
			if bool(candidate.get("rendered", false)) and not is_equal_approx(float(candidate.get("emotion_factor", 1.0)), 1.0):
				rendered_influenced += 1
	var violations: Array[String] = []
	for layer in by_layer.keys():
		if int(by_layer[layer].get("active", 0)) > int(by_layer[layer].get("capacity", 0)):
			violations.append("%s 活跃候选超过容量" % str(layer))
	if invalid_tag_count > 0:
		violations.append("存在 %d 个非法情绪标签" % invalid_tag_count)
	if duplicate_tag_count > 0:
		violations.append("存在 %d 个重复情绪标签" % duplicate_tag_count)
	revisit_feedback["feedback_rate"] = float(revisit_feedback["explicit_feedback_count"]) / float(revisit_feedback["presented"]) if int(revisit_feedback["presented"]) > 0 else 0.0
	var clustered_member_count := 0
	for member_ids in active_habit_clusters.values():
		clustered_member_count += Array(member_ids).size()
	var cluster_status_counts := {"proposed": 0, "rejected": 0, "disabled": 0}
	var proposal_count := 0
	var accept_count := 0
	var reject_count := 0
	var stale_event_count := 0
	var source_char_count := 0
	var summary_char_count := 0
	for cluster_record in habit_cluster_records.values():
		var record: Dictionary = cluster_record
		var record_status := str(record.get("status", ""))
		if cluster_status_counts.has(record_status):
			cluster_status_counts[record_status] = int(cluster_status_counts[record_status]) + 1
		proposal_count += int(record.get("proposal_count", 0))
		accept_count += int(record.get("accept_count", 0))
		reject_count += int(record.get("reject_count", 0))
		stale_event_count += int(record.get("stale_count", 0))
		if record_status != "active":
			continue
		summary_char_count += str(record.get("summary", "")).length()
		for member_id in record.get("member_ids", []):
			for habit_memory in memory_manager.memories.get("habit", []):
				if habit_memory is Dictionary and str(habit_memory.get("id", "")) == str(member_id):
					source_char_count += str(habit_memory.get("content", "")).length()
					break
	return {
		"report_type": "memory_governance",
		"generated_at": Time.get_datetime_string_from_system(),
		"candidate_capacity": {
			"by_layer": by_layer,
			"active_candidates": active_candidates,
			"capacity_expired": capacity_expired,
			"time_expired": time_expired,
			"restored": restored_count,
			"protected": protected_count
		},
		"emotion_tags": {
			"eligible_memories": eligible_memories,
			"tagged_memories": tagged_memories,
			"validly_tagged_memories": validly_tagged_memories,
			"missing_memories": eligible_memories - tagged_memories,
			"invalid_memories": invalid_memories,
			"invalid_tag_count": invalid_tag_count,
			"duplicate_tag_count": duplicate_tag_count,
			"coverage_rate": float(tagged_memories) / float(eligible_memories) if eligible_memories > 0 else 1.0,
			"valid_coverage_rate": float(validly_tagged_memories) / float(eligible_memories) if eligible_memories > 0 else 1.0,
			"tag_distribution": tag_distribution
		},
		"emotion_trace_effect": {
			"candidate_count": traced_candidates,
			"affinity_counts": affinity_counts,
			"rendered_influenced_count": rendered_influenced
		},
		"revisit_feedback": revisit_feedback,
		"habit_cluster_summaries": {
			"active_count": active_habit_clusters.size(),
			"stale_count": stale_habit_clusters.size(),
			"proposed_count": int(cluster_status_counts["proposed"]),
			"rejected_count": int(cluster_status_counts["rejected"]),
			"disabled_count": int(cluster_status_counts["disabled"]),
			"member_count": clustered_member_count,
			"saved_candidate_count": maxi(0, clustered_member_count - active_habit_clusters.size()),
			"source_char_count": source_char_count,
			"summary_char_count": summary_char_count,
			"saved_char_count": maxi(0, source_char_count - summary_char_count),
			"proposal_total": proposal_count,
			"accept_total": accept_count,
			"reject_total": reject_count,
			"stale_event_total": stale_event_count,
			"acceptance_rate": float(accept_count) / float(accept_count + reject_count) if accept_count + reject_count > 0 else 0.0
		},
		"passed": violations.is_empty(),
		"violations": violations
	}

func _sanitize_candidate(candidate: Dictionary) -> Dictionary:
	return {
		"memory_id": str(candidate.get("memory_id", "")),
		"memory_domain": str(candidate.get("memory_domain", MemoryManager.MEMORY_DOMAIN_PLAYER)),
		"layer": str(candidate.get("layer", "")),
		"content": str(candidate.get("content", "")).left(240),
		"source_content": str(candidate.get("source_content", candidate.get("content", ""))).left(240),
		"selection_mode": str(candidate.get("selection_mode", "")),
		"similarity": float(candidate.get("similarity", -1.0)),
		"score": float(candidate.get("score", -1.0)),
		"confidence": float(candidate.get("confidence", 0.0)),
		"consolidation_status": str(candidate.get("consolidation_status", "")),
		"age_seconds": float(candidate.get("age_seconds", 0.0)),
		"half_life_days": float(candidate.get("half_life_days", 0.0)),
		"time_relevance": float(candidate.get("time_relevance", 1.0)),
		"time_protected": bool(candidate.get("time_protected", false)),
		"exposure_factor": float(candidate.get("exposure_factor", 1.0)),
		"exposure_age_seconds": float(candidate.get("exposure_age_seconds", 0.0)),
		"exposure_penalty": float(candidate.get("exposure_penalty", 0.0)),
		"emotion_affinity": str(candidate.get("emotion_affinity", "neutral")),
		"emotion_factor": float(candidate.get("emotion_factor", 1.0)),
		"matched_mood_id": str(candidate.get("matched_mood_id", "")),
		"cluster_id": str(candidate.get("cluster_id", "")),
		"cluster_member_memory_ids": candidate.get("cluster_member_memory_ids", []).duplicate() if candidate.get("cluster_member_memory_ids", []) is Array else [],
		"cluster_summary_version": int(candidate.get("cluster_summary_version", 0)),
		"uses_cluster_summary": bool(candidate.get("uses_cluster_summary", false)),
		"reason": str(candidate.get("reason", "")),
		"source_id": str(candidate.get("source_id", "")),
		"scope": str(candidate.get("scope", "")),
		"visibility": str(candidate.get("visibility", "")),
		"rendered": bool(candidate.get("rendered", false))
	}

func _save_traces() -> bool:
	return SafeFileAccessUtil.store_string(get_save_path(), JSON.stringify({
		"schema_version": SCHEMA_VERSION,
		"traces": traces
	}, "\t"))