extends Node

const StoryMemoryManagerScript = preload("res://scripts/data/story_memory_manager.gd")
const CognitionTaskQueueScript = preload("res://scripts/data/cognition_task_queue.gd")

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var original_embedding_enabled: bool = GameDataManager.config.embedding_enabled
	GameDataManager.config.embedding_enabled = false
	var query_embedding: Array = await GameDataManager.memory_retrieval_service.get_query_embedding("无需联网的查询")
	_expect(query_embedding.is_empty(), "关闭 Embedding 时仍返回了查询向量。")

	var manager := MemoryManager.new()
	manager.memory_file_path_override = "user://memory_retrieval_governance_smoke_%d.json" % Time.get_ticks_usec()
	manager.memories = _build_test_memories()
	var original_queue = GameDataManager.cognition_task_queue
	var embedding_queue := CognitionTaskQueueScript.new()
	embedding_queue.save_path_override = "user://memory_embedding_queue_smoke_%d.json" % Time.get_ticks_usec()
	GameDataManager.cognition_task_queue = embedding_queue
	GameDataManager.config.embedding_enabled = true
	var stale_memory := _memory("需要重建向量", MemoryManager.MEMORY_VISIBILITY_PROMPT)
	stale_memory["embedding"] = [1.0, 0.0]
	stale_memory["embedding_status"] = "ready"
	stale_memory["embedding_model"] = "obsolete-model"
	manager.memories = {"core": [], "emotion": [], "habit": [stale_memory], "bond": []}
	var queued_embeddings := manager.queue_pending_memory_embeddings()
	var duplicate_embeddings := manager.queue_pending_memory_embeddings()
	_expect(queued_embeddings.size() == 1 and duplicate_embeddings.size() == 1 and queued_embeddings[0] == duplicate_embeddings[0], "模型失配记忆没有生成幂等的重建任务。")
	var embedding_task: Dictionary = embedding_queue.get_task(queued_embeddings[0])
	_expect(str(stale_memory.get("embedding_status", "")) == "pending" and stale_memory.get("embedding", []).is_empty(), "模型失配记忆没有清除旧向量并进入 pending。")
	_expect(not bool(manager.get_memory_embedding_task_state(embedding_task.get("payload", {})).get("obsolete", true)), "有效 embedding 任务被错误判为过期。")
	stale_memory["content"] = "内容已经变化"
	_expect(bool(manager.get_memory_embedding_task_state(embedding_task.get("payload", {})).get("obsolete", false)), "内容变化后旧 embedding 任务仍可写回。")
	GameDataManager.cognition_task_queue = original_queue
	GameDataManager.config.embedding_enabled = false
	if FileAccess.file_exists(embedding_queue.save_path_override):
		DirAccess.remove_absolute(embedding_queue.save_path_override)
	embedding_queue.queue_free()
	manager.memories = _build_test_memories()
	var fallback_prompt := manager.get_memory_prompt([])
	var fallback_result := manager.get_last_memory_prompt_result()
	var mismatched_prompt := manager.get_memory_prompt([1.0, 0.0])

	_expect(fallback_prompt.contains("core-visible"), "核心记忆没有进入降级 Prompt。")
	_expect(not fallback_prompt.contains("hidden-secret"), "隐藏记忆泄漏到无向量 Prompt。")
	_expect(not mismatched_prompt.contains("archive-secret"), "档案专属记忆泄漏到向量 Prompt。")
	_expect(mismatched_prompt.contains("habit-new-4"), "维度不匹配时没有使用最近记忆回退。")
	var mismatched_result := manager.get_last_memory_prompt_result()
	var mismatched_habits: Array = mismatched_result.get("selected", []).filter(func(candidate): return str(candidate.get("layer", "")) == "habit" and bool(candidate.get("rendered", false)))
	_expect(mismatched_habits.size() == int(MemoryManager.MEMORY_LAYER_LIMITS["habit"]), "习惯层回退超过了每层配额。")
	_expect(mismatched_prompt.contains("habit-old-0"), "短期曝光惩罚没有轮换未曝光记忆。")
	_expect(fallback_prompt.length() <= MemoryManager.MEMORY_PROMPT_MAX_CHARS, "记忆 Prompt 超出总字符预算。")
	_expect(bool(fallback_result.get("truncated", false)), "字符预算截断没有记录到检索结果。")
	var rendered_ids: Array = fallback_result.get("selected", []).filter(func(candidate): return bool(candidate.get("rendered", false))).map(func(candidate): return str(candidate.get("memory_id", "")))
	_expect(rendered_ids.has("core-visible"), "结构化检索结果没有标记实际渲染的核心记忆。")
	_expect(not rendered_ids.has("core-budget-0-%s" % "x".repeat(500)), "被字符预算裁掉的记忆仍标记为已渲染。")

	manager.memories = {"core": [], "emotion": [], "habit": [], "bond": []}
	manager.add_memory_quick("habit", "玩家喜欢热牛奶", {}, {
		"source_type": "chat_extraction",
		"source_id": "exchange-1",
		"source_title": "第一次提及"
	})
	manager.add_memory_quick("habit", "  玩家喜欢热牛奶  ", {}, {
		"source_type": "chat_extraction",
		"source_id": "exchange-2",
		"source_title": "再次确认"
	})
	_expect(manager.memories["habit"].size() == 1, "重复事实生成了新的记忆条目。")
	var reinforced: Dictionary = manager.memories["habit"][0]
	_expect(str(reinforced.get("consolidation_status", "")) == MemoryManager.CONSOLIDATION_STATUS_CONSOLIDATED and not str(reinforced.get("consolidated_at", "")).is_empty(), "重复证据没有将短期候选巩固为长期记忆。")
	_expect(int(reinforced.get("evidence_count", 0)) == 2, "重复事实没有增加证据计数。")
	_expect(float(reinforced.get("confidence", 0.0)) > MemoryManager.DEFAULT_MEMORY_CONFIDENCE, "重复事实没有提升可信度。")
	_expect(reinforced.get("evidence_sources", []).size() == 2, "证据来源链没有保留两次提取记录。")
	manager.add_memory_quick("habit", "玩家偶尔喝咖啡", {}, {"confidence": 0.2})
	var governed_results := manager.query_memories({"channel": "prompt", "layers": ["habit"], "max_count": 1})
	_expect(governed_results.size() == 1 and str(governed_results[0]["memory"].get("content", "")) == "玩家喜欢热牛奶", "查询没有优先返回高可信记忆。")
	var coffee_id := str(manager.memories["habit"][1].get("id", ""))
	_expect(manager.set_memory_pinned("habit", coffee_id, true), "记忆固定状态没有保存成功。")
	governed_results = manager.query_memories({"channel": "prompt", "layers": ["habit"], "max_count": 1})
	_expect(governed_results.size() == 1 and str(governed_results[0]["memory"].get("id", "")) == coffee_id, "固定记忆没有获得查询优先级。")
	_expect(manager.delete_memory("habit", coffee_id), "记忆删除操作失败。")
	_expect(manager.memories["habit"].size() == 2 and str(manager.memories["habit"][1].get("status", "")) == MemoryManager.MEMORY_STATUS_DELETED, "删除没有保留可恢复的软删除记录。")
	governed_results = manager.query_memories({"channel": "prompt", "layers": ["habit"], "max_count": 10})
	_expect(not governed_results.any(func(result): return str(result["memory"].get("id", "")) == coffee_id), "软删除记忆仍可被查询召回。")
	_expect(manager.restore_memory("habit", coffee_id), "软删除记忆恢复失败。")
	governed_results = manager.query_memories({"channel": "prompt", "layers": ["habit"], "max_count": 10})
	_expect(governed_results.any(func(result): return str(result["memory"].get("id", "")) == coffee_id), "恢复后的记忆没有重新进入查询。")
	_expect(manager.delete_memory("habit", coffee_id), "恢复后的记忆无法再次软删除。")
	var managed_id := str(manager.memories["habit"][0].get("id", ""))
	_expect(manager.update_memory_queued("habit", managed_id, "玩家每天喜欢喝热牛奶", {
		"source_type": "user_correction",
		"source_id": "trace-1",
		"source_title": "玩家纠正"
	}), "队列化编辑没有更新记忆。")
	var previous: Dictionary = manager.memories["habit"][0]
	var edited: Dictionary = manager.memories["habit"][-1]
	_expect(str(edited.get("content", "")) == "玩家每天喜欢喝热牛奶", "队列化编辑后的内容不正确。")
	_expect(edited.get("revision_history", []).size() == 1, "手动编辑没有保留修订记录。")
	_expect(int(edited.get("correction_count", 0)) == 1 and str(edited.get("revision_history", [])[0].get("source_id", "")) == "trace-1", "用户纠正没有记录次数和来源。")
	_expect(str(previous.get("status", "")) == MemoryManager.MEMORY_STATUS_SUPERSEDED and str(previous.get("superseded_by", "")) == str(edited.get("id", "")), "旧记忆没有建立被替代关系。")
	_expect(Array(edited.get("supersedes", [])).has(managed_id), "新记忆没有引用被纠正的旧记忆。")
	var corrected_prompt := manager.get_memory_prompt([])
	_expect(corrected_prompt.contains("玩家每天喜欢喝热牛奶") and not corrected_prompt.contains("玩家喜欢热牛奶"), "被替代的旧事实仍进入 Prompt。")
	_expect(int(edited.get("recall_count", 0)) == 1 and not str(edited.get("last_recalled_at", "")).is_empty(), "进入 Prompt 的记忆没有记录召回。")
	_expect(int(edited.get("exposure_count", 0)) == 1 and int(edited.get("successful_use_count", 0)) == 0, "Prompt 曝光被错误计为成功采用。")
	var confidence_before_confirmation := float(edited.get("confidence", 0.0))
	_expect(not manager.confirm_memory("habit", managed_id, {"source_id": "old-trace"}), "被替代记忆仍允许用户确认。")
	_expect(manager.confirm_memory("habit", str(edited.get("id", "")), {"source_id": "trace-2"}), "用户确认记忆失败。")
	_expect(int(edited.get("successful_use_count", 0)) == 1 and float(edited.get("confidence", 0.0)) > confidence_before_confirmation, "用户确认没有增加成功采用和可信度。")
	_expect(str(edited.get("evidence_sources", [])[-1].get("source_type", "")) == "user_confirmation", "用户确认没有写入证据类型。")
	_expect(not manager.confirm_memory("habit", "missing-memory", {}), "确认不存在的记忆没有返回失败。")
	manager.add_memory_quick("emotion", "玩家最近有些紧张", {}, {"source_type": "chat_extraction", "source_id": "candidate-1"})
	var candidate_memory: Dictionary = manager.memories["emotion"][0]
	_expect(str(candidate_memory.get("consolidation_status", "")) == MemoryManager.CONSOLIDATION_STATUS_CANDIDATE, "首次对话抽取没有进入短期候选状态。")
	_expect(manager.confirm_memory("emotion", str(candidate_memory.get("id", "")), {"source_id": "candidate-confirm"}), "用户确认短期候选失败。")
	_expect(str(candidate_memory.get("consolidation_status", "")) == MemoryManager.CONSOLIDATION_STATUS_CONSOLIDATED, "用户确认没有巩固短期候选。")
	var decay_before := float(edited.get("decay", 0.0))
	manager.process_daily_decay(1)
	_expect(float(edited.get("decay", 0.0)) > decay_before and float(edited.get("decay", 0.0)) < decay_before + 10.0, "治理元数据没有减缓日常衰减。")
	var fixed_now := Time.get_unix_time_from_datetime_string("2026-07-23T00:00:00")
	var recent_time_memory := _memory("recent-time-memory", MemoryManager.MEMORY_VISIBILITY_PROMPT)
	recent_time_memory["timestamp"] = "2026-07-22T00:00:00"
	recent_time_memory["last_confirmed_at"] = "2026-07-22T00:00:00"
	recent_time_memory["consolidation_status"] = MemoryManager.CONSOLIDATION_STATUS_CONSOLIDATED
	var old_time_memory := _memory("old-time-memory", MemoryManager.MEMORY_VISIBILITY_PROMPT)
	old_time_memory["timestamp"] = "2025-01-01T00:00:00"
	old_time_memory["last_confirmed_at"] = "2025-01-01T00:00:00"
	old_time_memory["consolidation_status"] = MemoryManager.CONSOLIDATION_STATUS_CONSOLIDATED
	var protected_time_memory := old_time_memory.duplicate(true)
	protected_time_memory["id"] = "protected-time-memory"
	protected_time_memory["content"] = "protected-time-memory"
	protected_time_memory["confidence"] = MemoryManager.PROTECTED_MEMORY_CONFIDENCE
	var recent_time := manager.get_memory_time_relevance(recent_time_memory, "habit", fixed_now)
	var old_time := manager.get_memory_time_relevance(old_time_memory, "habit", fixed_now)
	var protected_time := manager.get_memory_time_relevance(protected_time_memory, "habit", fixed_now)
	_expect(float(recent_time.get("time_relevance", 0.0)) > float(old_time.get("time_relevance", 1.0)), "查询时半衰期没有降低陈旧普通记忆的相关度。")
	_expect(float(protected_time.get("time_relevance", 0.0)) >= MemoryManager.PROTECTED_TIME_RELEVANCE, "高置信记忆没有获得时间保护下限。")
	var exposed_memory := recent_time_memory.duplicate(true)
	exposed_memory["last_recalled_at"] = "2026-07-23T00:00:00"
	exposed_memory["exposure_count"] = 3
	var fresh_exposure := manager.get_memory_exposure_relevance(exposed_memory, "habit", fixed_now)
	var recovering_exposure := manager.get_memory_exposure_relevance(exposed_memory, "habit", fixed_now + 12.0 * 3600.0)
	var core_exposure := manager.get_memory_exposure_relevance(exposed_memory, "core", fixed_now)
	_expect(float(fresh_exposure.get("exposure_factor", 1.0)) < float(recovering_exposure.get("exposure_factor", 0.0)) and float(recovering_exposure.get("exposure_factor", 1.0)) < 1.0, "短期曝光惩罚没有按半衰期恢复。")
	_expect(is_equal_approx(float(core_exposure.get("exposure_factor", 0.0)), 1.0) and bool(core_exposure.get("protected", false)), "核心记忆错误应用了曝光惩罚。")
	manager.memories["habit"] = [old_time_memory, recent_time_memory, protected_time_memory]
	var timed_result := manager.build_memory_prompt_result([], {"now_unix": fixed_now})
	var timed_selected: Array = timed_result.get("selected", []).filter(func(candidate): return str(candidate.get("layer", "")) == "habit")
	_expect(timed_selected.size() == 3 and str(timed_selected[0].get("memory_id", "")) == "recent-time-memory", "无向量降级排序没有应用查询时半衰期。")
	_expect(float(timed_selected[0].get("time_relevance", 0.0)) > float(timed_selected[1].get("time_relevance", 0.0)) or bool(timed_selected[1].get("time_protected", false)), "检索追踪没有公开半衰期状态。")
	var low_memory := _memory("low-emotion-memory", MemoryManager.MEMORY_VISIBILITY_PROMPT)
	low_memory["embedding"] = [1.0, 0.0]
	low_memory["last_confirmed_at"] = "2026-07-22T00:00:00"
	low_memory["consolidation_status"] = MemoryManager.CONSOLIDATION_STATUS_CONSOLIDATED
	low_memory["emotion_tags"] = ["low"]
	var pleasant_memory := low_memory.duplicate(true)
	pleasant_memory["id"] = "pleasant-emotion-memory"
	pleasant_memory["content"] = "pleasant-emotion-memory"
	pleasant_memory["emotion_tags"] = ["pleasant"]
	manager.memories = {"core": [_memory("emotion-isolated-core", MemoryManager.MEMORY_VISIBILITY_PROMPT)], "emotion": [pleasant_memory, low_memory], "habit": [], "bond": []}
	var low_result := manager.build_memory_prompt_result([1.0, 0.0], {"now_unix": fixed_now, "emotion_context": {"macro_mood_id": "low"}})
	var low_selected: Array = low_result.get("selected", []).filter(func(candidate): return str(candidate.get("layer", "")) == "emotion")
	_expect(low_selected.size() == 2 and str(low_selected[0].get("memory_id", "")) == "low-emotion-memory", "低落情绪没有优先匹配的情绪记忆。")
	_expect(is_equal_approx(float(low_selected[0].get("emotion_factor", 0.0)), MemoryManager.EMOTION_FACTOR_MATCH), "情绪匹配因子没有进入检索追踪。")
	var pleasant_result := manager.build_memory_prompt_result([1.0, 0.0], {"now_unix": fixed_now, "emotion_context": {"macro_mood_id": "pleasant"}})
	var pleasant_selected: Array = pleasant_result.get("selected", []).filter(func(candidate): return str(candidate.get("layer", "")) == "emotion")
	_expect(pleasant_selected.size() == 2 and str(pleasant_selected[0].get("memory_id", "")) == "pleasant-emotion-memory", "愉悦情绪没有交换情绪记忆排序。")
	var neutral_result := manager.build_memory_prompt_result([1.0, 0.0], {"now_unix": fixed_now})
	var neutral_selected: Array = neutral_result.get("selected", []).filter(func(candidate): return str(candidate.get("layer", "")) == "emotion")
	_expect(neutral_selected.all(func(candidate): return is_equal_approx(float(candidate.get("emotion_factor", 0.0)), 1.0)), "无情绪上下文时没有保持中性排序。")
	_expect(is_equal_approx(float(manager.get_memory_emotion_modulation(manager.memories["core"][0], "core", {"macro_mood_id": "low"}).get("emotion_factor", 0.0)), 1.0), "核心记忆被情绪上下文调制。")
	var expiring_candidate := _memory("expiring-candidate", MemoryManager.MEMORY_VISIBILITY_PROMPT)
	expiring_candidate["last_confirmed_at"] = "2026-01-01T00:00:00"
	expiring_candidate["consolidation_status"] = MemoryManager.CONSOLIDATION_STATUS_CANDIDATE
	manager.memories = {"core": [], "emotion": [], "habit": [expiring_candidate], "bond": []}
	_expect(manager.process_candidate_expiration(fixed_now) == 1, "长期未巩固候选没有进入过期流程。")
	_expect(manager.memories["habit"].size() == 1 and str(expiring_candidate.get("status", "")) == MemoryManager.MEMORY_STATUS_DELETED and str(expiring_candidate.get("deletion_reason", "")) == MemoryManager.DELETION_REASON_CANDIDATE_EXPIRED, "候选过期没有保留可恢复实体和原因。")
	_expect(manager.restore_memory("habit", "expiring-candidate", fixed_now), "过期候选无法恢复。")
	_expect(manager.process_candidate_expiration(fixed_now) == 0 and str(expiring_candidate.get("status", "")) == MemoryManager.MEMORY_STATUS_ACTIVE, "恢复候选在同一时间立即再次过期。")
	expiring_candidate["decay"] = 100.0
	manager.process_daily_decay(1)
	_expect(manager.memories["habit"].size() == 1 and str(expiring_candidate.get("status", "")) == MemoryManager.MEMORY_STATUS_DELETED, "衰减到期的候选被物理删除。")
	var weak_candidate := _memory("capacity-a-weak", MemoryManager.MEMORY_VISIBILITY_PROMPT)
	weak_candidate.merge({"status": MemoryManager.MEMORY_STATUS_ACTIVE, "consolidation_status": MemoryManager.CONSOLIDATION_STATUS_CANDIDATE, "confidence": 0.2, "evidence_count": 1}, true)
	var tie_candidate := weak_candidate.duplicate(true)
	tie_candidate["id"] = "capacity-b-tie"
	tie_candidate["content"] = "capacity-b-tie"
	var strong_candidate := weak_candidate.duplicate(true)
	strong_candidate.merge({"id": "capacity-c-strong", "content": "capacity-c-strong", "confidence": 0.6}, true)
	var consolidated_capacity := weak_candidate.duplicate(true)
	consolidated_capacity.merge({"id": "capacity-consolidated", "content": "capacity-consolidated", "consolidation_status": MemoryManager.CONSOLIDATION_STATUS_CONSOLIDATED}, true)
	var pinned_capacity := weak_candidate.duplicate(true)
	pinned_capacity.merge({"id": "capacity-pinned", "content": "capacity-pinned", "is_pinned": true}, true)
	manager.memories = {"core": [], "emotion": [weak_candidate, tie_candidate, strong_candidate, consolidated_capacity, pinned_capacity], "habit": [], "bond": []}
	var capacity_result: Dictionary = manager.process_candidate_capacity(fixed_now, {"emotion": 2, "habit": 2})
	_expect(int(capacity_result.get("evicted_count", 0)) == 1 and Array(capacity_result.get("evicted_ids", [])).has("capacity-a-weak"), "候选容量治理没有稳定逐出最弱候选。")
	_expect(manager.memories["emotion"].size() == 5 and str(weak_candidate.get("status", "")) == MemoryManager.MEMORY_STATUS_DELETED and str(weak_candidate.get("deletion_reason", "")) == MemoryManager.DELETION_REASON_CANDIDATE_CAPACITY, "容量逐出没有保留可恢复软删除实体。")
	_expect(str(consolidated_capacity.get("status", "")) == MemoryManager.MEMORY_STATUS_ACTIVE and str(pinned_capacity.get("status", "")) == MemoryManager.MEMORY_STATUS_ACTIVE, "容量治理错误逐出了已巩固或固定记忆。")
	_expect(int(manager.process_candidate_capacity(fixed_now, {"emotion": 2, "habit": 2}).get("evicted_count", -1)) == 0, "候选容量治理重复执行不稳定。")
	_expect(manager.format_deleted_memory_status(weak_candidate).contains("容量治理") and manager.format_deleted_memory_status(weak_candidate).contains("恢复"), "容量逐出没有可恢复归档文案。")
	var cluster_habit_a := _memory("cluster-habit-a", MemoryManager.MEMORY_VISIBILITY_PROMPT)
	cluster_habit_a.merge({"embedding": [1.0, 0.0], "embedding_status": "ready", "status": MemoryManager.MEMORY_STATUS_ACTIVE}, true)
	var cluster_habit_b := _memory("cluster-habit-b", MemoryManager.MEMORY_VISIBILITY_PROMPT)
	cluster_habit_b.merge({"embedding": [0.99, 0.01], "embedding_status": "ready", "status": MemoryManager.MEMORY_STATUS_ACTIVE}, true)
	var cluster_habit_c := _memory("cluster-habit-c", MemoryManager.MEMORY_VISIBILITY_PROMPT)
	cluster_habit_c.merge({"embedding": [0.98, 0.02], "embedding_status": "ready", "status": MemoryManager.MEMORY_STATUS_ACTIVE}, true)
	var unrelated_habit := _memory("cluster-unrelated", MemoryManager.MEMORY_VISIBILITY_PROMPT)
	unrelated_habit.merge({"embedding": [0.0, 1.0], "embedding_status": "ready", "status": MemoryManager.MEMORY_STATUS_ACTIVE}, true)
	manager.memories = {"core": [], "emotion": [], "habit": [cluster_habit_a, cluster_habit_b, cluster_habit_c, unrelated_habit], "bond": []}
	var habit_clusters: Array = manager.build_habit_clusters()
	_expect(habit_clusters.size() == 1 and int(habit_clusters[0].get("member_count", 0)) == 3, "习惯聚类没有隔离低相似度成员。")
	var stable_cluster_id := str(habit_clusters[0].get("cluster_id", ""))
	var stable_member_ids: Array = habit_clusters[0].get("member_memory_ids", [])
	manager.memories["habit"] = [unrelated_habit, cluster_habit_c, cluster_habit_a, cluster_habit_b]
	var reordered_clusters: Array = manager.build_habit_clusters()
	_expect(reordered_clusters.size() == 1 and str(reordered_clusters[0].get("cluster_id", "")) == stable_cluster_id and Array(reordered_clusters[0].get("member_memory_ids", [])) == stable_member_ids, "习惯聚类结果受记忆写入顺序影响。")
	var original_cognition_queue = GameDataManager.cognition_task_queue
	var cluster_queue = CognitionTaskQueueScript.new()
	cluster_queue.save_path_override = "user://memory_retrieval_cluster_queue_%d.json" % Time.get_ticks_usec()
	add_child(cluster_queue)
	GameDataManager.cognition_task_queue = cluster_queue
	var cluster_task_ids := manager.queue_habit_cluster_summary_tasks()
	var duplicate_cluster_task_ids := manager.queue_habit_cluster_summary_tasks()
	_expect(cluster_task_ids.size() == 1 and duplicate_cluster_task_ids.size() == 1 and cluster_task_ids[0] == duplicate_cluster_task_ids[0] and cluster_queue.tasks.size() == 1, "习惯聚类摘要候选没有按稳定快照去重入队。")
	var cluster_task: Dictionary = cluster_queue.get_task(cluster_task_ids[0])
	var cluster_payload: Dictionary = cluster_task.get("payload", {})
	var proposed_prompt_before := str(manager.build_memory_prompt_result([1.0, 0.0], {"now_unix": fixed_now}).get("prompt", ""))
	cluster_habit_a["content"] = "changed-cluster-habit-a"
	_expect(not manager.propose_habit_cluster_summary(stable_cluster_id, stable_member_ids, str(cluster_payload.get("snapshot_hash", "")), "玩家通常喜欢温热的牛奶饮品。", {"model": "smoke-model"}), "成员内容变化后仍接受了过期聚类摘要提案。")
	cluster_habit_a["content"] = "cluster-habit-a"
	_expect(manager.propose_habit_cluster_summary(stable_cluster_id, stable_member_ids, str(cluster_payload.get("snapshot_hash", "")), "玩家通常喜欢温热的牛奶饮品。", {"model": "smoke-model"}), "有效聚类摘要提案无法保存。")
	var proposed_prompt := str(manager.build_memory_prompt_result([1.0, 0.0], {"now_unix": fixed_now}).get("prompt", ""))
	_expect(str(cluster_habit_a.get("cluster_summary_status", "")) == "proposed" and not proposed_prompt.contains("玩家通常喜欢温热的牛奶饮品。") and proposed_prompt == proposed_prompt_before, "待审核摘要错误进入 Prompt 或改变原始检索。")
	_expect(manager.reject_habit_cluster_summary_proposal(stable_cluster_id), "人工拒绝聚类摘要提案失败。")
	var rejected_prompt := str(manager.build_memory_prompt_result([1.0, 0.0], {"now_unix": fixed_now}).get("prompt", ""))
	_expect(str(cluster_habit_a.get("cluster_summary_status", "")) == "rejected" and str(cluster_habit_a.get("cluster_summary_proposal", "")) == "" and rejected_prompt == proposed_prompt_before, "拒绝摘要后没有清空提案或保持原始检索。")
	_expect(manager.queue_habit_cluster_summary_tasks().is_empty(), "拒绝摘要后同一成员快照仍被自动重新入队。")
	_expect(not manager.rebuild_habit_cluster_summary(stable_cluster_id).is_empty(), "玩家无法显式重建已拒绝的习惯摘要。")
	_expect(manager.propose_habit_cluster_summary(stable_cluster_id, stable_member_ids, str(cluster_payload.get("snapshot_hash", "")), "玩家通常喜欢温热的牛奶饮品。", {"model": "smoke-model"}), "拒绝后无法对有效快照重新生成摘要提案。")
	_expect(manager.accept_habit_cluster_summary_proposal(stable_cluster_id), "人工接受聚类摘要提案失败。")
	_expect(str(cluster_habit_a.get("cluster_summary_generation_reason", "")) == "ai_proposal_accepted" and str(cluster_habit_a.get("cluster_summary_proposal_model", "")) == "smoke-model", "接受摘要后没有保留生成来源与模型审计。")
	GameDataManager.cognition_task_queue = original_cognition_queue
	cluster_queue.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(cluster_queue.save_path_override))
	_expect(str(cluster_habit_a.get("content", "")) == "cluster-habit-a" and str(cluster_habit_a.get("cluster_summary", "")) == "玩家通常喜欢温热的牛奶饮品。" and str(cluster_habit_a.get("cluster_summary_status", "")) == "active", "聚类摘要覆盖了原始记忆或缺少可追溯状态。")
	_expect(not manager.apply_habit_cluster_summary("wrong-cluster", stable_member_ids, "错误摘要"), "错误聚类 ID 仍能写入摘要。")
	var clustered_prompt_result: Dictionary = manager.build_memory_prompt_result([1.0, 0.0], {"now_unix": fixed_now})
	var clustered_prompt := str(clustered_prompt_result.get("prompt", ""))
	var clustered_selected: Array = clustered_prompt_result.get("selected", []).filter(func(candidate): return str(candidate.get("layer", "")) == "habit" and bool(candidate.get("uses_cluster_summary", false)))
	var collapsed_members: Array = clustered_prompt_result.get("rejected", []).filter(func(candidate): return str(candidate.get("reason", "")) == "cluster_member_collapsed")
	_expect(clustered_prompt.count("玩家通常喜欢温热的牛奶饮品。") == 1 and clustered_selected.size() == 1 and collapsed_members.size() == 2, "active 习惯摘要没有在 Prompt 中折叠同聚类成员。")
	_expect(Array(clustered_selected[0].get("cluster_member_memory_ids", [])).size() == 3, "聚类摘要候选没有保留完整成员审计。")
	_expect(manager.disable_habit_cluster_summary(stable_cluster_id), "有效习惯摘要无法停用。")
	var disabled_prompt := str(manager.build_memory_prompt_result([1.0, 0.0], {"now_unix": fixed_now}).get("prompt", ""))
	_expect(str(cluster_habit_a.get("cluster_summary_status", "")) == "disabled" and disabled_prompt.contains("cluster-habit-a") and not disabled_prompt.contains("玩家通常喜欢温热的牛奶饮品。") and manager.queue_habit_cluster_summary_tasks().is_empty(), "停用摘要后没有回退原始成员，或同快照被自动重建。")
	_expect(manager.apply_habit_cluster_summary(stable_cluster_id, stable_member_ids, "玩家通常喜欢温热的牛奶饮品。"), "停用后的摘要无法通过明确操作重新启用。")
	var first_summary_version := int(cluster_habit_a.get("cluster_summary_version", 0))
	_expect(manager.delete_memory("habit", "cluster-habit-b"), "聚类成员无法软删除。")
	_expect(str(cluster_habit_a.get("cluster_summary_status", "")) == "stale" and str(cluster_habit_c.get("cluster_summary_status", "")) == "stale", "成员删除没有使整个聚类摘要失效。")
	var stale_prompt_result: Dictionary = manager.build_memory_prompt_result([1.0, 0.0], {"now_unix": fixed_now})
	var stale_prompt := str(stale_prompt_result.get("prompt", ""))
	_expect(not stale_prompt.contains("玩家通常喜欢温热的牛奶饮品。") and stale_prompt.contains("cluster-habit-a") and stale_prompt.contains("cluster-habit-c"), "stale 聚类摘要没有自动回退剩余原始成员。")
	_expect(manager.restore_memory("habit", "cluster-habit-b", fixed_now), "聚类成员无法恢复。")
	_expect(manager.apply_habit_cluster_summary(stable_cluster_id, stable_member_ids, "玩家通常偏好温热的牛奶饮品。"), "成员恢复后无法重新生成聚类摘要。")
	_expect(int(cluster_habit_a.get("cluster_summary_version", 0)) == first_summary_version + 1 and str(cluster_habit_a.get("cluster_summary_status", "")) == "active", "重新生成摘要没有递增版本或恢复 active 状态。")
	_expect(manager.supersede_memory("habit", "cluster-habit-a", "玩家现在更喜欢常温牛奶", {}, {"source_type": "user_correction"}, "user_correction"), "聚类成员纠正无法创建替代实体。")
	var cluster_replacement: Dictionary = manager.memories["habit"][-1]
	_expect(str(cluster_habit_b.get("cluster_summary_status", "")) == "stale" and str(cluster_replacement.get("cluster_id", "")) == "" and str(cluster_replacement.get("cluster_summary", "")) == "", "成员替代没有使旧摘要失效，或新实体错误继承旧摘要。")
	var revisit_memory := _memory("revisit-memory", MemoryManager.MEMORY_VISIBILITY_PROMPT)
	revisit_memory.merge({"context_domain": MemoryManager.CONTEXT_DOMAIN_STORY, "day_offset": 1, "decay": 0.0, "evidence_count": 1, "consolidation_status": MemoryManager.CONSOLIDATION_STATUS_CANDIDATE}, true)
	manager.memories = {"core": [], "emotion": [], "habit": [revisit_memory], "bond": []}
	manager.revisit_state = manager._create_default_revisit_state()
	manager.revisit_state["revisited_memory_ids"] = ["revisit-memory"]
	var revisit_day_10 := {"context_domain": MemoryManager.CONTEXT_DOMAIN_STORY, "day_offset": 10, "now_unix": fixed_now}
	_expect(str(manager.get_revisit_event_candidate(revisit_day_10).get("memory_id", "")) == "revisit-memory", "旧永久重访集合仍然封禁记忆。")
	var evidence_before_revisit := int(revisit_memory.get("evidence_count", 1))
	var revisit_event_id := manager.mark_memory_revisited("revisit-memory", revisit_day_10)
	_expect(not revisit_event_id.is_empty() and str(revisit_memory.get("last_revisit_event_id", "")) == revisit_event_id and str(revisit_memory.get("last_revisit_outcome", "")) == MemoryManager.REVISIT_OUTCOME_PRESENTED, "主动重访没有建立独立事件或展示状态。")
	_expect(int(revisit_memory.get("revisit_count", 0)) == 1 and int(revisit_memory.get("exposure_count", 0)) == 1 and int(revisit_memory.get("last_revisited_story_day", -1)) == 10 and int(revisit_memory.get("evidence_count", 0)) == evidence_before_revisit, "主动重访展示错误增强记忆，或没有记录冷却与曝光审计。")
	_expect(not manager.record_revisit_feedback("habit", "revisit-memory", "wrong-event", MemoryManager.REVISIT_OUTCOME_CONFIRMED, {"now_unix": fixed_now}), "不匹配的重访事件错误修改了记忆。")
	_expect(manager.record_revisit_feedback("habit", "revisit-memory", revisit_event_id, MemoryManager.REVISIT_OUTCOME_CONFIRMED, {"now_unix": fixed_now}), "明确重访确认没有成功记录。")
	var revisit_sources: Array = revisit_memory.get("evidence_sources", [])
	_expect(int(revisit_memory.get("evidence_count", 0)) == evidence_before_revisit + 1 and int(revisit_memory.get("successful_revisit_count", 0)) == 1 and str(revisit_memory.get("consolidation_status", "")) == MemoryManager.CONSOLIDATION_STATUS_CONSOLIDATED and not revisit_sources.is_empty() and str(revisit_sources[-1].get("source_id", "")) == revisit_event_id, "明确重访确认没有再巩固记忆或保留事件来源。")
	manager.revisit_state["last_story_revisit_day"] = -9999
	_expect(manager.get_revisit_event_candidate({"context_domain": MemoryManager.CONTEXT_DOMAIN_STORY, "day_offset": 16, "now_unix": fixed_now + 6.0 * MemoryManager.SECONDS_PER_DAY}).is_empty(), "单记忆在七天冷却结束前再次重访。")
	manager.revisit_state["last_story_revisit_day"] = -9999
	_expect(str(manager.get_revisit_event_candidate({"context_domain": MemoryManager.CONTEXT_DOMAIN_STORY, "day_offset": 17, "now_unix": fixed_now + 7.0 * MemoryManager.SECONDS_PER_DAY}).get("memory_id", "")) == "revisit-memory", "单记忆在七天冷却结束后仍无法重访。")
	var dismissed_memory := _memory("dismissed-revisit", MemoryManager.MEMORY_VISIBILITY_PROMPT)
	dismissed_memory.merge({"context_domain": MemoryManager.CONTEXT_DOMAIN_STORY, "day_offset": 1, "decay": 0.0}, true)
	manager.memories = {"core": [], "emotion": [], "habit": [dismissed_memory], "bond": []}
	manager.revisit_state = manager._create_default_revisit_state()
	var dismissed_event_id := manager.mark_memory_revisited("dismissed-revisit", revisit_day_10)
	_expect(manager.record_revisit_feedback("habit", "dismissed-revisit", dismissed_event_id, MemoryManager.REVISIT_OUTCOME_DISMISSED, {"now_unix": fixed_now, "suppression_days": 30}), "明确拒绝重访没有建立暂缓状态。")
	manager.revisit_state["last_story_revisit_day"] = -9999
	_expect(manager.get_revisit_event_candidate({"context_domain": MemoryManager.CONTEXT_DOMAIN_STORY, "day_offset": 40, "now_unix": fixed_now + 29.0 * MemoryManager.SECONDS_PER_DAY}).is_empty(), "暂缓期结束前记忆再次自动重访。")
	manager.revisit_state["last_story_revisit_day"] = -9999
	_expect(str(manager.get_revisit_event_candidate({"context_domain": MemoryManager.CONTEXT_DOMAIN_STORY, "day_offset": 41, "now_unix": fixed_now + 30.0 * MemoryManager.SECONDS_PER_DAY}).get("memory_id", "")) == "dismissed-revisit", "暂缓期结束后记忆仍无法自动重访。")
	var corrected_memory := _memory("corrected-revisit", MemoryManager.MEMORY_VISIBILITY_PROMPT)
	corrected_memory.merge({"context_domain": MemoryManager.CONTEXT_DOMAIN_STORY, "day_offset": 1, "decay": 0.0}, true)
	manager.memories = {"core": [], "emotion": [], "habit": [corrected_memory], "bond": []}
	manager.revisit_state = manager._create_default_revisit_state()
	var corrected_event_id := manager.mark_memory_revisited("corrected-revisit", revisit_day_10)
	_expect(manager.record_revisit_feedback("habit", "corrected-revisit", corrected_event_id, MemoryManager.REVISIT_OUTCOME_CORRECTED, {"now_unix": fixed_now, "corrected_content": "玩家现在喜欢温牛奶"}), "重访纠正没有创建替代记忆。")
	var corrected_replacement: Dictionary = manager.memories["habit"][-1]
	_expect(str(corrected_memory.get("status", "")) == MemoryManager.MEMORY_STATUS_SUPERSEDED and str(corrected_memory.get("last_revisit_outcome", "")) == MemoryManager.REVISIT_OUTCOME_CORRECTED and str(corrected_replacement.get("source_id", "")) == corrected_event_id and str(corrected_replacement.get("content", "")) == "玩家现在喜欢温牛奶", "重访纠正没有保留事件来源或替代关系。")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(manager.memory_file_path_override))

	var legacy_path := "user://memory_retrieval_legacy_smoke.json"
	var legacy_file := FileAccess.open(legacy_path, FileAccess.WRITE)
	legacy_file.store_string(JSON.stringify({"core": ["玩家不喜欢剧透"]}))
	legacy_file.close()
	manager.memory_file_path_override = legacy_path
	manager.load_memory()
	var migrated: Dictionary = manager.memories["core"][0]
	_expect(is_equal_approx(float(migrated.get("confidence", 0.0)), MemoryManager.DEFAULT_MEMORY_CONFIDENCE), "旧版记忆没有迁移默认可信度。")
	_expect(int(migrated.get("evidence_count", 0)) == 1, "旧版记忆没有迁移默认证据计数。")
	_expect(migrated.has("evidence_sources") and migrated.has("revision_history"), "旧版记忆缺少治理历史字段。")
	_expect(migrated.has("exposure_count") and migrated.has("successful_use_count") and migrated.has("correction_count"), "旧版记忆缺少反馈闭环字段。")
	_expect(migrated.has("last_revisited_at") and migrated.has("last_revisited_story_day") and migrated.has("revisit_count") and migrated.has("last_revisit_event_id") and migrated.has("last_revisit_outcome") and migrated.has("successful_revisit_count") and migrated.has("revisit_suppressed_until"), "旧版记忆缺少重访反馈与冷却审计字段。")
	_expect(str(migrated.get("status", "")) == MemoryManager.MEMORY_STATUS_ACTIVE and migrated.has("deleted_at") and migrated.has("superseded_by"), "旧版记忆缺少生命周期字段。")
	_expect(migrated.has("emotion_tags") and migrated.has("deletion_reason") and migrated.has("restored_at"), "旧版记忆缺少情绪调制或候选过期字段。")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(legacy_path))

	var story_manager = StoryMemoryManagerScript.new()
	story_manager.memories = {"story": [
		_story_memory("known-story", "秘密花园已经开放", "story-finished", ["luna"], true, true),
		_story_memory("other-character", "只有另一角色知道的秘密", "story-finished", ["mio"], true, true),
		_story_memory("private-story", "玩家从未见证的私密事实", "story-finished", ["luna"], false, false),
		_story_memory("future-story", "尚未完成剧情的未来事实", "story-future", ["luna"], true, true),
		_story_memory("legacy-story", "缺少权限元数据的旧故事事实", "story-finished", [], true, true)
	]}
	var isolated_story_result: Dictionary = story_manager.build_story_knowledge_prompt_result({"channel": "main_chat", "allow_story_knowledge": true, "character_id": "luna", "finished_story_ids": ["story-finished"]})
	_expect(str(isolated_story_result.get("prompt", "")).is_empty(), "普通聊天泄漏了故事知识。")
	var story_result: Dictionary = story_manager.build_story_knowledge_prompt_result({"channel": "story_chat", "allow_story_knowledge": true, "character_id": "luna", "finished_story_ids": ["story-finished"]})
	var story_prompt := str(story_result.get("prompt", ""))
	_expect(story_prompt.contains("秘密花园已经开放"), "已授权故事事实没有进入故事对话。")
	_expect(not story_prompt.contains("另一角色") and not story_prompt.contains("私密事实") and not story_prompt.contains("未来事实") and not story_prompt.contains("旧故事事实"), "故事知识权限过滤发生泄漏。")
	var rejection_reasons: Array = story_result.get("rejected", []).map(func(candidate): return str(candidate.get("reason", "")))
	_expect(rejection_reasons.has("character_not_authorized") and rejection_reasons.has("player_not_authorized") and rejection_reasons.has("source_not_completed") and rejection_reasons.has("legacy_acl_unknown"), "故事知识拒绝原因不完整。")
	story_manager.queue_free()

	manager.queue_free()
	GameDataManager.config.embedding_enabled = original_embedding_enabled
	if failures.is_empty():
		print("MEMORY_RETRIEVAL_SMOKE_OK")
		get_tree().quit(0)
		return
	for failure in failures:
		push_error("MEMORY_RETRIEVAL_SMOKE: %s" % failure)
	get_tree().quit(1)


func _build_test_memories() -> Dictionary:
	var result := {"core": [], "emotion": [], "habit": [], "bond": []}
	result["core"].append(_memory("core-visible", MemoryManager.MEMORY_VISIBILITY_PROMPT))
	result["emotion"].append(_memory("hidden-secret", MemoryManager.MEMORY_VISIBILITY_HIDDEN))
	result["bond"].append(_memory("archive-secret", MemoryManager.MEMORY_VISIBILITY_ARCHIVE_ONLY))
	for index in 5:
		var memory := _memory("habit-%s-%d" % ["old" if index == 0 else "new", index], MemoryManager.MEMORY_VISIBILITY_PROMPT)
		memory["day_offset"] = index
		memory["embedding"] = [0.5, 0.5, 0.5]
		result["habit"].append(memory)
	for index in 20:
		result["core"].append(_memory("core-budget-%d-%s" % [index, "x".repeat(500)], MemoryManager.MEMORY_VISIBILITY_PROMPT))
	return result


func _memory(content: String, visibility: String) -> Dictionary:
	return {
		"id": content,
		"content": content,
		"timestamp": "2026-01-01T00:00:00",
		"day_offset": 0,
		"memory_domain": MemoryManager.MEMORY_DOMAIN_PLAYER,
		"memory_scope": MemoryManager.MEMORY_SCOPE_PLAYER_SHARED,
		"memory_visibility": visibility,
		"embedding": []
	}


func _story_memory(id: String, content: String, source_id: String, participants: Array, player_involved: bool, player_witnessed: bool) -> Dictionary:
	return {
		"id": id,
		"content": content,
		"source_id": source_id,
		"memory_participants": participants,
		"memory_player_involved": player_involved,
		"memory_player_witnessed": player_witnessed,
		"memory_scope": MemoryManager.MEMORY_SCOPE_WORLD_FACT,
		"memory_visibility": MemoryManager.MEMORY_VISIBILITY_ARCHIVE_ONLY,
		"memory_domain": MemoryManager.MEMORY_DOMAIN_STORY,
		"status": MemoryManager.MEMORY_STATUS_ACTIVE
	}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)