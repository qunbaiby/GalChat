extends Node

const MemoryRetrievalTraceServiceScript = preload("res://scripts/data/memory_retrieval_trace_service.gd")
const StoryMemoryManagerScript = preload("res://scripts/data/story_memory_manager.gd")
const REPLAY_FIXTURE_PATH := "res://addons/story_editor/tests/fixtures/memory_retrieval_replay_baseline.json"
const CLUSTER_REPLAY_FIXTURE_PATH := "res://addons/story_editor/tests/fixtures/habit_cluster_replay_baseline.json"

var failures: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var suffix := str(Time.get_ticks_usec())
	var trace_service = MemoryRetrievalTraceServiceScript.new()
	trace_service.save_path_override = "user://memory_retrieval_trace_%s.json" % suffix
	add_child(trace_service)
	var fixture := _load_replay_fixture()
	var manager := MemoryManager.new()
	manager.memory_file_path_override = "user://memory_retrieval_trace_memory_%s.json" % suffix
	manager.memories = _normalize_fixture_memories(fixture.get("memories", {}))
	add_child(manager)
	var result := manager.build_memory_prompt_result([1.0, 0.0, 0.0])
	var trace := trace_service.record_trace("今天喝什么？", "default_chat", "main_chat", result, "request-a")
	_expect(trace.get("rendered_memory_ids", []).has("habit-hot-milk"), "追踪没有记录实际渲染记忆。")
	_expect(trace.get("selected", [])[0].has("exposure_factor") and is_equal_approx(float(trace.get("selected", [])[0].get("exposure_factor", 0.0)), 1.0), "追踪没有持久化曝光恢复因子。")
	_expect(not trace.get("rendered_memory_ids", []).has("habit-bitter-coffee"), "追踪错误记录低相似度记忆。")
	var other_trace := trace_service.record_trace("周末做什么？", "default_chat", "story_chat", result, "request-b")
	var trace_id := str(trace.get("id", ""))
	var other_trace_id := str(other_trace.get("id", ""))
	_expect(trace_id != other_trace_id and str(trace.get("request_id", "")) == "request-a" and str(other_trace.get("request_id", "")) == "request-b", "交错请求没有获得独立 request/trace 标识。")
	_expect(trace_service.mark_request_started(trace_id), "追踪无法进入请求已启动状态。")
	_expect(trace_service.mark_response_completed(other_trace_id, "另一个回答"), "交错追踪无法记录回答完成。")
	_expect(trace_service.mark_response_completed(trace_id, "第一个回答") and trace_service.mark_response_adopted(trace_id, "采用的回答"), "追踪生命周期更新失败。")
	var lifecycle_traces := trace_service.get_recent_traces(2)
	var lifecycle_by_request := {}
	for lifecycle_trace in lifecycle_traces:
		lifecycle_by_request[str(lifecycle_trace.get("request_id", ""))] = lifecycle_trace
	_expect(str(lifecycle_by_request.get("request-a", {}).get("status", "")) == "response_adopted", "第一个请求没有进入实际采用状态。")
	_expect(int(lifecycle_by_request.get("request-a", {}).get("adopted_chars", 0)) > 0, "实际采用文本长度没有记录。")
	_expect(str(lifecycle_by_request.get("request-b", {}).get("status", "")) == "response_completed" and int(lifecycle_by_request.get("request-b", {}).get("adopted_chars", 0)) == 0, "交错请求的追踪状态发生串线。")
	var revisit_trace_a := trace_service.record_trace("重访甲", "default_chat", "main_chat", result, "revisit-request-a", {
		"revisit_event_id": "revisit-event-a",
		"revisit_memory_id": "habit-hot-milk",
		"revisit_layer": "habit",
		"revisit_context_domain": MemoryManager.CONTEXT_DOMAIN_REALITY
	})
	var revisit_trace_b := trace_service.record_trace("重访乙", "default_chat", "main_chat", result, "revisit-request-b", {
		"revisit_event_id": "revisit-event-b",
		"revisit_memory_id": "habit-bitter-coffee",
		"revisit_layer": "habit",
		"revisit_context_domain": MemoryManager.CONTEXT_DOMAIN_REALITY
	})
	_expect(trace_service.mark_response_adopted(str(revisit_trace_a.get("id", "")), "已展示的重访") and trace_service.mark_request_failed(str(revisit_trace_b.get("id", "")), "请求失败"), "重访请求生命周期无法更新。")
	_expect(trace_service.mark_revisit_outcome("revisit-event-a", MemoryManager.REVISIT_OUTCOME_CONFIRMED), "明确重访反馈无法关联 trace。")
	var revisit_traces := trace_service.get_recent_traces(2)
	var revisit_by_event := {}
	for revisit_trace in revisit_traces:
		revisit_by_event[str(revisit_trace.get("revisit_event_id", ""))] = revisit_trace
	_expect(str(revisit_by_event.get("revisit-event-a", {}).get("revisit_delivery_status", "")) == "presented" and str(revisit_by_event.get("revisit-event-a", {}).get("revisit_outcome", "")) == MemoryManager.REVISIT_OUTCOME_CONFIRMED, "已展示重访没有保存独立反馈结果。")
	_expect(str(revisit_by_event.get("revisit-event-b", {}).get("revisit_delivery_status", "")) == "failed" and str(revisit_by_event.get("revisit-event-b", {}).get("revisit_outcome", "")) == "", "交错重访事件的交付或反馈状态发生串线。")
	trace_service.traces = []
	for index in MemoryRetrievalTraceServiceScript.MAX_TRACES:
		trace_service.traces.append({"id": "existing-%d" % index})
	trace_service.record_trace("容量边界", "default_chat", "main_chat", result)
	_expect(trace_service.get_recent_traces(100).size() == MemoryRetrievalTraceServiceScript.MAX_TRACES, "追踪记录没有执行容量限制。")
	trace_service.load_traces()
	_expect(trace_service.get_recent_traces(1).size() == 1, "持久追踪没有成功恢复。")
	var metrics := trace_service.evaluate_replay_cases(fixture.get("cases", []), manager)
	_expect(is_equal_approx(float(metrics.get("recall_at_k", 0.0)), 1.0), "回放 Recall@K 计算错误。")
	_expect(float(metrics.get("precision_at_k", 0.0)) >= 0.5, "回放 Precision@K 低于基线。")
	_expect(int(metrics.get("forbidden_recalled", -1)) == 0, "回放错误召回禁止记忆。")
	_expect(int(metrics.get("case_count", 0)) == 3, "固定回放集没有完整执行。")
	_expect(bool(metrics.get("passed", false)) and Array(metrics.get("violations", [])).is_empty(), "固定回放基线没有通过质量门禁。")
	_expect(is_equal_approx(float(metrics.get("thresholds", {}).get("min_recall_at_k", 0.0)), MemoryRetrievalTraceServiceScript.MIN_REPLAY_RECALL_AT_K), "回放结果没有公开统一质量阈值。")
	var failing_metrics := trace_service.evaluate_replay_cases([{
		"name": "故意退化",
		"query_embedding": [1.0, 0.0, 0.0],
		"expected_memory_ids": ["missing-memory"],
		"forbidden_memory_ids": ["habit-hot-milk"]
	}], manager)
	_expect(not bool(failing_metrics.get("passed", true)) and not Array(failing_metrics.get("violations", [])).is_empty(), "退化回放没有触发质量门禁。")
	var cluster_fixture := _load_json_fixture(CLUSTER_REPLAY_FIXTURE_PATH)
	var cluster_cases: Array = cluster_fixture.get("cases", []).duplicate(true)
	for cluster_case in cluster_cases:
		if cluster_case is Dictionary and cluster_case.get("memories", {}) is Dictionary:
			cluster_case["memories"] = _normalize_fixture_memories(cluster_case.get("memories", {}))
	var cluster_metrics := trace_service.evaluate_habit_cluster_replay_cases(cluster_cases, manager)
	_expect(bool(cluster_metrics.get("passed", false)) and int(cluster_metrics.get("case_count", 0)) == 2 and is_equal_approx(float(cluster_metrics.get("equivalence_rate", 0.0)), 1.0), "习惯聚类摘要固定回放没有达到 100% 逻辑等价。")
	_expect(int(cluster_metrics.get("forbidden_recalled", -1)) == 0 and int(cluster_metrics.get("saved_prompt_chars", 0)) > 0 and int(cluster_metrics.get("prompt_chars_after", 0)) < int(cluster_metrics.get("prompt_chars_before", 0)), "习惯聚类摘要回放没有保持禁止召回或减少 Prompt 字符。")
	_expect(Array(cluster_metrics.get("results", [])).all(func(case_result): return int(case_result.get("summary_candidate_count", 0)) == 1 and bool(case_result.get("equivalent", false))), "习惯聚类摘要回放没有稳定折叠为单一候选。")
	var degraded_cluster_case: Dictionary = cluster_cases[0].duplicate(true)
	degraded_cluster_case["summary"] = "这是一个故意制造的冗长摘要。".repeat(20)
	var degraded_cluster_metrics := trace_service.evaluate_habit_cluster_replay_cases([degraded_cluster_case], manager)
	_expect(not bool(degraded_cluster_metrics.get("passed", true)) and not Array(degraded_cluster_metrics.get("violations", [])).is_empty(), "聚类摘要字符增长或应用失败没有触发回放门禁。")
	var threshold_cases: Array = cluster_fixture.get("threshold_cases", []).duplicate(true)
	for threshold_case in threshold_cases:
		if threshold_case is Dictionary and threshold_case.get("memories", {}) is Dictionary:
			threshold_case["memories"] = _normalize_fixture_memories(threshold_case.get("memories", {}))
	var threshold_metrics := trace_service.evaluate_habit_cluster_thresholds(
		threshold_cases,
		cluster_fixture.get("threshold_candidates", []),
		manager
	)
	var safe_thresholds: Array = threshold_metrics.get("safe_thresholds", [])
	var threshold_results: Array = threshold_metrics.get("results", [])
	var low_threshold_result: Dictionary = threshold_results[0] if threshold_results.size() > 0 else {}
	var default_threshold_result: Dictionary = threshold_results[1] if threshold_results.size() > 1 else {}
	var high_threshold_result: Dictionary = threshold_results[2] if threshold_results.size() > 2 else {}
	_expect(bool(threshold_metrics.get("passed", false)) and safe_thresholds.size() == 1 and is_equal_approx(float(safe_thresholds[0]), MemoryManager.HABIT_CLUSTER_SIMILARITY_THRESHOLD), "固定阈值扫描没有将当前 0.82 识别为唯一安全候选。")
	_expect(int(low_threshold_result.get("overclustered_case_count", 0)) == threshold_cases.size() and not bool(low_threshold_result.get("passed", true)), "较低阈值没有稳定触发近邻记忆误聚合。")
	_expect(bool(default_threshold_result.get("passed", false)) and int(default_threshold_result.get("exact_case_count", 0)) == threshold_cases.size(), "当前聚类阈值没有精确覆盖全部边界正样本。")
	_expect(int(high_threshold_result.get("underclustered_case_count", 0)) == threshold_cases.size() and not bool(high_threshold_result.get("passed", true)), "较高阈值没有稳定触发正样本误拆分。")
	var emotion_manager := MemoryManager.new()
	emotion_manager.memory_file_path_override = "user://memory_retrieval_emotion_%s.json" % suffix
	emotion_manager.memories = {"core": [], "emotion": [], "habit": [], "bond": []}
	for raw_emotion_memory in fixture.get("emotion_memories", []):
		var emotion_memory: Dictionary = raw_emotion_memory.duplicate(true)
		emotion_memory["memory_domain"] = MemoryManager.MEMORY_DOMAIN_PLAYER
		emotion_memory["memory_scope"] = MemoryManager.MEMORY_SCOPE_PLAYER_SHARED
		emotion_memory["memory_visibility"] = MemoryManager.MEMORY_VISIBILITY_PROMPT
		emotion_memory["status"] = MemoryManager.MEMORY_STATUS_ACTIVE
		emotion_memory["confidence"] = 0.8
		emotion_memory["evidence_count"] = 2
		emotion_memory["consolidation_status"] = MemoryManager.CONSOLIDATION_STATUS_CONSOLIDATED
		emotion_memory["last_confirmed_at"] = "2026-07-23T00:00:00"
		emotion_manager.memories["emotion"].append(emotion_memory)
	for emotion_case in fixture.get("emotion_cases", []):
		var mood_id := str(emotion_case.get("macro_mood_id", ""))
		var query_options := {"now_unix": Time.get_unix_time_from_datetime_string("2026-07-23T00:00:00")}
		if not mood_id.is_empty():
			query_options["emotion_context"] = {"macro_mood_id": mood_id}
		var emotion_result := emotion_manager.build_memory_prompt_result([1.0, 0.0], query_options)
		var emotion_selected: Array = emotion_result.get("selected", []).filter(func(candidate): return str(candidate.get("layer", "")) == "emotion")
		_expect(not emotion_selected.is_empty() and str(emotion_selected[0].get("memory_id", "")) == str(emotion_case.get("first_memory_id", "")), "情绪固定回放排序错误：%s" % str(emotion_case.get("name", "")))
	var emotion_result: Dictionary = emotion_manager.build_memory_prompt_result([1.0, 0.0], {"now_unix": Time.get_unix_time_from_datetime_string("2026-07-23T00:00:00"), "emotion_context": {"macro_mood_id": "low"}})
	emotion_result["emotion_context"] = {"macro_mood_id": "low", "confidence": 0.9, "source": "player_explicit", "observed_at_unix": 1784764800.0, "expires_at_unix": 1784772000.0}
	var emotion_trace := trace_service.record_trace("情绪回放", "default_chat", "main_chat", emotion_result)
	_expect(str(emotion_trace.get("selected", [])[0].get("emotion_affinity", "")) == "match" and is_equal_approx(float(emotion_trace.get("selected", [])[0].get("emotion_factor", 0.0)), MemoryManager.EMOTION_FACTOR_MATCH), "情绪调制元数据没有持久化到检索追踪。")
	_expect(str(emotion_trace.get("emotion_context", {}).get("source", "")) == "player_explicit" and is_equal_approx(float(emotion_trace.get("emotion_context", {}).get("confidence", 0.0)), 0.9) and float(emotion_trace.get("emotion_context", {}).get("expires_at_unix", 0.0)) > float(emotion_trace.get("emotion_context", {}).get("observed_at_unix", 0.0)), "检索追踪没有保存清洗后的玩家显式情绪状态。")
	for index in 3:
		emotion_manager.memories["habit"].append({
			"id": "trace-cluster-%d" % index,
			"content": "cluster source %d" % index,
			"memory_domain": MemoryManager.MEMORY_DOMAIN_PLAYER,
			"memory_scope": MemoryManager.MEMORY_SCOPE_PLAYER_SHARED,
			"memory_visibility": MemoryManager.MEMORY_VISIBILITY_PROMPT,
			"status": MemoryManager.MEMORY_STATUS_ACTIVE,
			"confidence": 0.9,
			"emotion_tags": ["low"],
			"embedding": [1.0, 0.0],
			"embedding_status": "ready"
		})
	var trace_clusters := emotion_manager.build_habit_clusters()
	var trace_cluster: Dictionary = trace_clusters[0]
	var trace_snapshot: Dictionary = emotion_manager._build_habit_cluster_snapshot(trace_cluster.get("member_memory_ids", []))
	_expect(emotion_manager.propose_habit_cluster_summary(str(trace_cluster.get("cluster_id", "")), trace_cluster.get("member_memory_ids", []), str(trace_snapshot.get("snapshot_hash", "")), "玩家反复表现出相同习惯。", {"model": "trace-smoke"}), "trace 治理夹具无法保存习惯摘要提案。")
	_expect(emotion_manager.accept_habit_cluster_summary_proposal(str(trace_cluster.get("cluster_id", ""))), "trace 治理夹具无法接受习惯摘要提案。")
	var cluster_result := emotion_manager.build_memory_prompt_result([1.0, 0.0], {"now_unix": Time.get_unix_time_from_datetime_string("2026-07-23T00:00:00")})
	var cluster_trace := trace_service.record_trace("习惯聚类回放", "default_chat", "main_chat", cluster_result)
	var summary_candidates: Array = cluster_trace.get("selected", []).filter(func(candidate): return bool(candidate.get("uses_cluster_summary", false)))
	_expect(summary_candidates.size() == 1 and Array(summary_candidates[0].get("cluster_member_memory_ids", [])).size() == 3 and str(summary_candidates[0].get("source_content", "")).begins_with("cluster source"), "检索追踪没有保留聚类摘要来源审计。")
	var governance_report := trace_service.evaluate_governance_report(emotion_manager)
	_expect(str(governance_report.get("report_type", "")) == "memory_governance" and not governance_report.has("recall_at_k") and not governance_report.has("precision_at_k"), "治理报告错误混入了基础检索质量指标。")
	_expect(is_equal_approx(float(governance_report.get("emotion_tags", {}).get("valid_coverage_rate", 0.0)), 1.0), "治理报告情绪标签覆盖率计算错误。")
	_expect(int(governance_report.get("emotion_trace_effect", {}).get("rendered_influenced_count", 0)) > 0 and bool(governance_report.get("passed", false)), "治理报告没有统计实际进入 Prompt 的情绪调制。")
	_expect(int(governance_report.get("habit_cluster_summaries", {}).get("active_count", 0)) == 1 and int(governance_report.get("habit_cluster_summaries", {}).get("member_count", 0)) == 3 and int(governance_report.get("habit_cluster_summaries", {}).get("saved_candidate_count", 0)) == 2, "治理报告没有正确统计有效习惯聚类摘要。")
	var cluster_governance: Dictionary = governance_report.get("habit_cluster_summaries", {})
	_expect(int(cluster_governance.get("proposal_total", 0)) == 1 and int(cluster_governance.get("accept_total", 0)) == 1 and int(cluster_governance.get("reject_total", 0)) == 0 and is_equal_approx(float(cluster_governance.get("acceptance_rate", 0.0)), 1.0), "聚类摘要决策漏斗按成员重复计数或接受率错误。")
	_expect(int(cluster_governance.get("source_char_count", 0)) == 48 and int(cluster_governance.get("summary_char_count", 0)) > 0 and int(cluster_governance.get("saved_char_count", 0)) == int(cluster_governance.get("source_char_count", 0)) - int(cluster_governance.get("summary_char_count", 0)), "聚类摘要实际字符节省统计错误。")
	emotion_manager.memories["emotion"][0]["emotion_tags"] = ["low", "LOW", "invalid"]
	var invalid_governance_report := trace_service.evaluate_governance_report(emotion_manager)
	_expect(not bool(invalid_governance_report.get("passed", true)) and int(invalid_governance_report.get("emotion_tags", {}).get("invalid_tag_count", 0)) == 1 and int(invalid_governance_report.get("emotion_tags", {}).get("duplicate_tag_count", 0)) == 1, "治理报告没有识别非法或重复情绪标签。")
	emotion_manager.memories["emotion"][0]["emotion_tags"] = ["low"]
	var story_manager = StoryMemoryManagerScript.new()
	story_manager.memories = {"story": []}
	for raw_story_memory in fixture.get("story_memories", []):
		var story_memory: Dictionary = raw_story_memory.duplicate(true)
		story_memory["memory_domain"] = MemoryManager.MEMORY_DOMAIN_STORY
		story_memory["memory_scope"] = MemoryManager.MEMORY_SCOPE_WORLD_FACT
		story_memory["memory_visibility"] = MemoryManager.MEMORY_VISIBILITY_ARCHIVE_ONLY
		story_memory["status"] = MemoryManager.MEMORY_STATUS_ACTIVE
		story_manager.memories["story"].append(story_memory)
	var story_metrics := trace_service.evaluate_story_access_cases(fixture.get("story_cases", []), story_manager)
	_expect(bool(story_metrics.get("passed", false)) and int(story_metrics.get("case_count", 0)) == 2, "故事知识权限固定回放没有通过。")
	var story_results: Array = story_metrics.get("results", [])
	_expect(story_results.size() > 0 and Array(story_results[0].get("rejection_reasons", [])).has("source_not_completed"), "故事权限回放没有记录拒绝原因。")
	var original_embedding_enabled: bool = GameDataManager.config.embedding_enabled
	var global_story_manager = GameDataManager.story_memory_manager
	var original_story_memories: Dictionary = global_story_manager.memories.duplicate(true)
	var original_trace_service = GameDataManager.memory_retrieval_trace_service
	GameDataManager.config.embedding_enabled = false
	global_story_manager.memories = story_manager.memories.duplicate(true)
	GameDataManager.memory_retrieval_trace_service = trace_service
	var integrated_result: Dictionary = await GameDataManager.memory_retrieval_service.build_chat_prompt_result(
		GameDataManager.profile,
		"花园后来怎么样了？",
		manager,
		"story_chat",
		{"channel": "story_chat", "allow_story_knowledge": true, "character_id": "luna", "finished_story_ids": ["story-garden"]}
	)
	_expect(str(integrated_result.get("prompt", "")).contains("露娜和玩家一起发现了秘密花园"), "授权故事事实没有进入最终系统 Prompt。")
	var integrated_trace: Dictionary = trace_service.get_recent_traces(1)[0]
	var integrated_domains: Array = integrated_trace.get("selected", []).map(func(candidate): return str(candidate.get("memory_domain", "")))
	var integrated_reasons: Array = integrated_trace.get("rejected", []).map(func(candidate): return str(candidate.get("reason", "")))
	_expect(integrated_domains.has(MemoryManager.MEMORY_DOMAIN_STORY) and integrated_reasons.has("source_not_completed"), "最终检索追踪没有合并故事权限结果。")
	var isolated_result: Dictionary = await GameDataManager.memory_retrieval_service.build_chat_prompt_result(
		GameDataManager.profile,
		"花园后来怎么样了？",
		manager,
		"main_chat",
		{"channel": "main_chat", "allow_story_knowledge": true, "character_id": "luna", "finished_story_ids": ["story-garden"]}
	)
	_expect(not str(isolated_result.get("prompt", "")).contains("露娜和玩家一起发现了秘密花园"), "普通聊天最终 Prompt 泄漏了故事事实。")
	GameDataManager.memory_retrieval_trace_service = original_trace_service
	global_story_manager.memories = original_story_memories
	GameDataManager.config.embedding_enabled = original_embedding_enabled
	story_manager.queue_free()
	trace_service.clear_traces()
	_expect(trace_service.get_recent_traces().is_empty(), "清理追踪失败。")
	_cleanup(trace_service.save_path_override)
	_cleanup(manager.memory_file_path_override)
	_cleanup(emotion_manager.memory_file_path_override)
	emotion_manager.queue_free()
	if failures.is_empty():
		print("MEMORY_RETRIEVAL_TRACE_SMOKE_OK")
		get_tree().quit(0)
		return
	for failure in failures:
		push_error("MEMORY_RETRIEVAL_TRACE_SMOKE: %s" % failure)
	get_tree().quit(1)

func _load_replay_fixture() -> Dictionary:
	return _load_json_fixture(REPLAY_FIXTURE_PATH)

func _load_json_fixture(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		failures.append("无法读取固定回放集。")
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary or int(parsed.get("schema_version", 0)) != 1:
		failures.append("固定回放集格式无效。")
		return {}
	return parsed

func _normalize_fixture_memories(raw_memories: Dictionary) -> Dictionary:
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
			entry["embedding_status"] = "ready" if entry.get("embedding", []) is Array and not entry.get("embedding", []).is_empty() else "missing"
			normalized[layer].append(entry)
	return normalized

func _cleanup(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)