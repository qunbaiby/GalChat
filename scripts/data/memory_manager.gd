class_name MemoryManager
extends Node

const SafeFileAccessUtil = preload("res://scripts/utils/safe_file_access.gd")
const MEMORY_FILE_PATH = "user://player_memory.json"
const CONTEXT_DOMAIN_UNKNOWN = "unknown"
const CONTEXT_DOMAIN_STORY = "story"
const CONTEXT_DOMAIN_REALITY = "reality"
const MEMORY_SCOPE_PLAYER_SHARED = "player_shared"
const MEMORY_SCOPE_PLAYER_OBSERVED = "player_observed"
const MEMORY_SCOPE_PRIVATE_SELF = "private_self"
const MEMORY_SCOPE_NPC_SOCIAL = "npc_social"
const MEMORY_SCOPE_WORLD_FACT = "world_fact"
const MEMORY_VISIBILITY_PROMPT = "prompt"
const MEMORY_VISIBILITY_CONDITIONAL = "conditional"
const MEMORY_VISIBILITY_HIDDEN = "hidden"
const MEMORY_VISIBILITY_ARCHIVE_ONLY = "archive_only"
const MEMORY_DOMAIN_PLAYER = "player_memory"
const MEMORY_DOMAIN_DESKTOP_PET = "desktop_pet_memory"
const MEMORY_DOMAIN_STORY = "story_memory"
const MEMORY_STATUS_ACTIVE = "active"
const MEMORY_STATUS_DELETED = "deleted"
const MEMORY_STATUS_SUPERSEDED = "superseded"
const PLAYER_MEMORY_ALLOWED_LAYERS := ["core", "emotion", "habit", "bond"]
const MEMORY_PROMPT_MAX_CHARS := 2400
const MEMORY_LAYER_LIMITS := {
	"core": 8,
	"emotion": 3,
	"habit": 3,
	"bond": 4
}
const MEMORY_LAYER_CHAR_LIMITS := {
	"core": 850,
	"emotion": 450,
	"habit": 450,
	"bond": 550
}
const DEFAULT_MEMORY_CONFIDENCE := 0.45
const BOND_MEMORY_CONFIDENCE := 0.60
const CONFIDENCE_REINFORCEMENT_STEP := 0.12
const MAX_MEMORY_CONFIDENCE := 0.95
const MAX_EVIDENCE_SOURCES := 8
const PROTECTED_MEMORY_CONFIDENCE := 0.75
const CONSOLIDATION_STATUS_CANDIDATE := "candidate"
const CONSOLIDATION_STATUS_CONSOLIDATED := "consolidated"
const CONSOLIDATION_EVIDENCE_REQUIRED := 2
const CANDIDATE_RETRIEVAL_FACTOR := 0.85
const SECONDS_PER_DAY := 86400.0
const HALF_LIFE_DAYS := {
	"emotion": 14.0,
	"habit": 45.0,
	"bond": 180.0
}
const MIN_TIME_RELEVANCE := 0.12
const PROTECTED_TIME_RELEVANCE := 0.80
const CANDIDATE_EXPIRATION_DAYS := 30.0
const DELETION_REASON_USER := "user_deleted"
const DELETION_REASON_CANDIDATE_EXPIRED := "candidate_expired"
const DELETION_REASON_CANDIDATE_CAPACITY := "candidate_capacity"
const CANDIDATE_LAYER_CAPACITY := {
	"emotion": 32,
	"habit": 64
}
const MOOD_ORDER := ["broken", "low", "calm", "pleasant", "ecstatic"]
const EMOTION_FACTOR_MATCH := 1.10
const EMOTION_FACTOR_NEAR := 1.03
const EMOTION_FACTOR_CONFLICT := 0.90
const EXPOSURE_PENALTY_BASE := 0.20
const EXPOSURE_PENALTY_LOG_STEP := 0.10
const EXPOSURE_PENALTY_MAX := 0.60
const EXPOSURE_PENALTY_HALF_LIFE_HOURS := 12.0
const REVISIT_COOLDOWN_DAYS := 7
const REVISIT_DISMISSAL_DAYS := 30
const HABIT_CLUSTER_SIMILARITY_THRESHOLD := 0.82
const HABIT_CLUSTER_MIN_MEMBERS := 2
const HABIT_CLUSTER_SUMMARY_MIN_MEMBERS := 3
const HABIT_CLUSTER_SUMMARY_MAX_CHARS := 320
const REVISIT_OUTCOME_PRESENTED := "presented"
const REVISIT_OUTCOME_ENGAGED := "engaged"
const REVISIT_OUTCOME_CONFIRMED := "confirmed"
const REVISIT_OUTCOME_CORRECTED := "corrected"
const REVISIT_OUTCOME_DISMISSED := "dismissed"
const REVISIT_OUTCOMES := [
	REVISIT_OUTCOME_PRESENTED,
	REVISIT_OUTCOME_ENGAGED,
	REVISIT_OUTCOME_CONFIRMED,
	REVISIT_OUTCOME_CORRECTED,
	REVISIT_OUTCOME_DISMISSED
]

# 四级记忆分层架构，每层存储字典列表 [{"id": String, "content": String, "timestamp": String}]
var memories: Dictionary = {
	"core": [],     # 核心记忆层：用户姓名、禁忌、核心价值观、人生大事、不可逆选择
	"emotion": [],  # 情绪记忆层：用户的情绪触发点、雷区、情感偏好
	"habit": [],    # 习惯记忆层：用户作息、饮食喜好、兴趣、日常习惯
	"bond": []      # 羁绊记忆层：专属约定、共同经历、纪念日、一起完成的事
}
var last_memory_prompt_result: Dictionary = {}
var memory_file_path_override: String = ""

var turns_since_last_extract: int = 0
var revisit_state: Dictionary = _create_default_revisit_state()

func get_memory_file_path() -> String:
	if not memory_file_path_override.is_empty():
		return memory_file_path_override
	var char_id = "default"
	if GameDataManager.config and GameDataManager.config.current_character_id != "":
		char_id = GameDataManager.config.current_character_id
	return GameDataManager.get_character_save_path("player_memory.json", char_id)

func get_memory_domain() -> String:
	return MEMORY_DOMAIN_PLAYER

func get_default_context_domain() -> String:
	return CONTEXT_DOMAIN_STORY

func get_default_memory_scope() -> String:
	return MEMORY_SCOPE_PLAYER_SHARED

func get_default_memory_visibility() -> String:
	return MEMORY_VISIBILITY_PROMPT

func _init() -> void:
	# 不在_init()加载，等待GameDataManager显式调用load_memory()
	pass

func _create_default_revisit_state() -> Dictionary:
	return {
		"last_story_revisit_memory_id": "",
		"last_story_revisit_day": -9999,
		"last_reality_revisit_memory_id": "",
		"last_reality_revisit_date": "",
		"revisited_memory_ids": []
	}

func _get_real_date_key() -> String:
	var dt = Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02d" % [dt.get("year", 0), dt.get("month", 0), dt.get("day", 0)]

func _get_real_period_label(hour: int) -> String:
	if hour >= 6 and hour < 12:
		return "上午"
	if hour >= 12 and hour < 18:
		return "下午"
	if hour >= 18 and hour < 23:
		return "晚上"
	return "深夜"

func normalize_memory_scope(scope: String) -> String:
	var final_scope = scope.strip_edges().to_lower()
	var allowed = [
		MEMORY_SCOPE_PLAYER_SHARED,
		MEMORY_SCOPE_PLAYER_OBSERVED,
		MEMORY_SCOPE_PRIVATE_SELF,
		MEMORY_SCOPE_NPC_SOCIAL,
		MEMORY_SCOPE_WORLD_FACT
	]
	if allowed.has(final_scope):
		return final_scope
	return MEMORY_SCOPE_PLAYER_SHARED

func get_default_visibility_for_scope(scope: String) -> String:
	match normalize_memory_scope(scope):
		MEMORY_SCOPE_PLAYER_SHARED:
			return MEMORY_VISIBILITY_PROMPT
		MEMORY_SCOPE_PLAYER_OBSERVED:
			return MEMORY_VISIBILITY_CONDITIONAL
		MEMORY_SCOPE_PRIVATE_SELF:
			return MEMORY_VISIBILITY_HIDDEN
		MEMORY_SCOPE_NPC_SOCIAL:
			return MEMORY_VISIBILITY_ARCHIVE_ONLY
		MEMORY_SCOPE_WORLD_FACT:
			return MEMORY_VISIBILITY_ARCHIVE_ONLY
		_:
			return MEMORY_VISIBILITY_PROMPT

func normalize_memory_visibility(visibility: String, scope: String = MEMORY_SCOPE_PLAYER_SHARED) -> String:
	var final_visibility = visibility.strip_edges().to_lower()
	var allowed = [
		MEMORY_VISIBILITY_PROMPT,
		MEMORY_VISIBILITY_CONDITIONAL,
		MEMORY_VISIBILITY_HIDDEN,
		MEMORY_VISIBILITY_ARCHIVE_ONLY
	]
	if allowed.has(final_visibility):
		return final_visibility
	return get_default_visibility_for_scope(scope)

func _is_duplicate_memory_entry(mem: Dictionary, content: String, _source_type: String = "", _source_id: String = "") -> bool:
	if str(mem.get("status", MEMORY_STATUS_ACTIVE)) != MEMORY_STATUS_ACTIVE:
		return false
	return _normalize_memory_content(str(mem.get("content", ""))) == _normalize_memory_content(content)

func _normalize_memory_content(content: String) -> String:
	return " ".join(content.strip_edges().to_lower().split(" ", false))

func _initialize_habit_cluster_fields(memory: Dictionary) -> void:
	memory["cluster_id"] = str(memory.get("cluster_id", ""))
	memory["cluster_summary"] = str(memory.get("cluster_summary", ""))
	memory["cluster_summary_status"] = str(memory.get("cluster_summary_status", ""))
	memory["cluster_summary_version"] = int(memory.get("cluster_summary_version", 0))
	memory["cluster_summary_generated_at"] = str(memory.get("cluster_summary_generated_at", ""))
	memory["cluster_summary_member_memory_ids"] = memory.get("cluster_summary_member_memory_ids", []).duplicate() if memory.get("cluster_summary_member_memory_ids", []) is Array else []
	memory["cluster_summary_generation_reason"] = str(memory.get("cluster_summary_generation_reason", ""))
	memory["cluster_summary_confidence"] = clampf(float(memory.get("cluster_summary_confidence", 0.0)), 0.0, 1.0)
	memory["cluster_summary_proposal"] = str(memory.get("cluster_summary_proposal", ""))
	memory["cluster_summary_proposal_snapshot_hash"] = str(memory.get("cluster_summary_proposal_snapshot_hash", ""))
	memory["cluster_summary_proposal_model"] = str(memory.get("cluster_summary_proposal_model", ""))
	memory["cluster_summary_proposed_at"] = str(memory.get("cluster_summary_proposed_at", ""))
	memory["cluster_summary_rejected_snapshot_hash"] = str(memory.get("cluster_summary_rejected_snapshot_hash", ""))
	memory["cluster_summary_disabled_snapshot_hash"] = str(memory.get("cluster_summary_disabled_snapshot_hash", ""))
	memory["cluster_summary_proposal_count"] = maxi(0, int(memory.get("cluster_summary_proposal_count", 0)))
	memory["cluster_summary_accept_count"] = maxi(0, int(memory.get("cluster_summary_accept_count", 0)))
	memory["cluster_summary_reject_count"] = maxi(0, int(memory.get("cluster_summary_reject_count", 0)))
	memory["cluster_summary_stale_count"] = maxi(0, int(memory.get("cluster_summary_stale_count", 0)))
	memory["cluster_summary_last_decision_at"] = str(memory.get("cluster_summary_last_decision_at", ""))

func _invalidate_habit_cluster_summary(cluster_id: String = "") -> void:
	if get_memory_domain() != MEMORY_DOMAIN_PLAYER:
		return
	for memory in memories.get("habit", []):
		if not memory is Dictionary:
			continue
		var memory_cluster_id := str(memory.get("cluster_id", ""))
		if memory_cluster_id.is_empty() or (not cluster_id.is_empty() and memory_cluster_id != cluster_id):
			continue
		if (not str(memory.get("cluster_summary", "")).is_empty() or str(memory.get("cluster_summary_status", "")) == "proposed") and str(memory.get("cluster_summary_status", "")) != "stale":
			memory["cluster_summary_status"] = "stale"
			memory["cluster_summary_stale_count"] = int(memory.get("cluster_summary_stale_count", 0)) + 1

func build_habit_clusters(similarity_threshold: float = HABIT_CLUSTER_SIMILARITY_THRESHOLD) -> Array:
	if get_memory_domain() != MEMORY_DOMAIN_PLAYER:
		return []
	var eligible: Array = []
	for memory in memories.get("habit", []):
		if not memory is Dictionary or not should_surface_memory_in_player_channels(memory, "prompt", true):
			continue
		var embedding: Array = memory.get("embedding", []) if memory.get("embedding", []) is Array else []
		if str(memory.get("embedding_status", "")) != "ready" or embedding.is_empty():
			continue
		eligible.append(memory)
	eligible.sort_custom(func(left, right): return str(left.get("id", "")) < str(right.get("id", "")))
	var assigned: Dictionary = {}
	var clusters: Array = []
	for leader in eligible:
		var leader_id := str(leader.get("id", ""))
		if assigned.has(leader_id):
			continue
		var leader_embedding: Array = leader.get("embedding", [])
		var members: Array = [leader]
		assigned[leader_id] = true
		for candidate in eligible:
			var candidate_id := str(candidate.get("id", ""))
			if assigned.has(candidate_id):
				continue
			var candidate_embedding: Array = candidate.get("embedding", [])
			if candidate_embedding.size() != leader_embedding.size():
				continue
			if _cosine_similarity(leader_embedding, candidate_embedding) < similarity_threshold:
				continue
			members.append(candidate)
			assigned[candidate_id] = true
		if members.size() < HABIT_CLUSTER_MIN_MEMBERS:
			continue
		var member_ids: Array[String] = []
		for member in members:
			member_ids.append(str(member.get("id", "")))
		member_ids.sort()
		clusters.append({
			"cluster_id": "habit-%s" % "|".join(member_ids).sha256_text().left(16),
			"member_memory_ids": member_ids,
			"member_count": member_ids.size()
		})
	return clusters

func queue_habit_cluster_summary_tasks() -> Array[String]:
	var task_ids: Array[String] = []
	if get_memory_domain() != MEMORY_DOMAIN_PLAYER or GameDataManager.cognition_task_queue == null:
		return task_ids
	for cluster in build_habit_clusters():
		var member_ids: Array = cluster.get("member_memory_ids", [])
		if member_ids.size() < HABIT_CLUSTER_SUMMARY_MIN_MEMBERS:
			continue
		var snapshot := _build_habit_cluster_snapshot(member_ids)
		if snapshot.is_empty() or _cluster_blocks_automatic_summary_task(str(cluster.get("cluster_id", "")), str(snapshot.get("snapshot_hash", ""))):
			continue
		var task_id := _enqueue_habit_cluster_summary_snapshot(str(cluster.get("cluster_id", "")), snapshot, "automatic")
		if not task_id.is_empty():
			task_ids.append(task_id)
	return task_ids

func rebuild_habit_cluster_summary(cluster_id: String) -> String:
	if get_memory_domain() != MEMORY_DOMAIN_PLAYER or GameDataManager.cognition_task_queue == null:
		return ""
	var matching_cluster: Dictionary = {}
	for cluster in build_habit_clusters():
		if str(cluster.get("cluster_id", "")) == cluster_id and int(cluster.get("member_count", 0)) >= HABIT_CLUSTER_SUMMARY_MIN_MEMBERS:
			matching_cluster = cluster
			break
	if matching_cluster.is_empty():
		return ""
	var snapshot := _build_habit_cluster_snapshot(matching_cluster.get("member_memory_ids", []))
	if snapshot.is_empty():
		return ""
	for memory in memories.get("habit", []):
		if memory is Dictionary and Array(snapshot.get("member_memory_ids", [])).has(str(memory.get("id", ""))):
			memory["cluster_id"] = cluster_id
			memory["cluster_summary_status"] = "stale"
			memory["cluster_summary_rejected_snapshot_hash"] = ""
			memory["cluster_summary_disabled_snapshot_hash"] = ""
	if not save_memory():
		return ""
	return _enqueue_habit_cluster_summary_snapshot(cluster_id, snapshot, "manual_rebuild")

func disable_habit_cluster_summary(cluster_id: String) -> bool:
	var member_ids: Array = []
	for memory in memories.get("habit", []):
		if memory is Dictionary and str(memory.get("cluster_id", "")) == cluster_id and str(memory.get("status", MEMORY_STATUS_ACTIVE)) == MEMORY_STATUS_ACTIVE:
			member_ids.append(str(memory.get("id", "")))
	var snapshot := _build_habit_cluster_snapshot(member_ids)
	if snapshot.is_empty():
		return false
	var disabled_at := Time.get_datetime_string_from_system()
	for memory in memories.get("habit", []):
		if memory is Dictionary and Array(snapshot.get("member_memory_ids", [])).has(str(memory.get("id", ""))):
			memory["cluster_summary_status"] = "disabled"
			memory["cluster_summary_disabled_snapshot_hash"] = str(snapshot.get("snapshot_hash", ""))
			memory["cluster_summary_proposal"] = ""
			memory["cluster_summary_proposal_snapshot_hash"] = ""
			memory["cluster_summary_last_decision_at"] = disabled_at
	return save_memory()

func _enqueue_habit_cluster_summary_snapshot(cluster_id: String, snapshot: Dictionary, reason: String) -> String:
	return GameDataManager.cognition_task_queue.enqueue("habit_cluster_summary", {
		"cluster_id": cluster_id,
		"snapshot_hash": str(snapshot.get("snapshot_hash", "")),
		"member_memory_ids": snapshot.get("member_memory_ids", []).duplicate(),
		"members": snapshot.get("members", []).duplicate(true),
		"generation_reason": reason
	}, MEMORY_DOMAIN_PLAYER)

func propose_habit_cluster_summary(cluster_id: String, member_memory_ids: Array, snapshot_hash: String, summary: String, proposal_options: Dictionary = {}) -> bool:
	var final_summary := summary.strip_edges()
	if get_memory_domain() != MEMORY_DOMAIN_PLAYER or cluster_id.is_empty() or snapshot_hash.is_empty() or final_summary.is_empty() or final_summary.length() > HABIT_CLUSTER_SUMMARY_MAX_CHARS:
		return false
	var snapshot := _build_habit_cluster_snapshot(member_memory_ids)
	if snapshot.is_empty() or str(snapshot.get("snapshot_hash", "")) != snapshot_hash or not _habit_cluster_matches_snapshot(cluster_id, snapshot):
		return false
	var proposed_at := Time.get_datetime_string_from_system()
	for memory in memories.get("habit", []):
		if memory is Dictionary and Array(snapshot.get("member_memory_ids", [])).has(str(memory.get("id", ""))):
			memory["cluster_id"] = cluster_id
			memory["cluster_summary_status"] = "proposed"
			memory["cluster_summary_proposal"] = final_summary
			memory["cluster_summary_proposal_snapshot_hash"] = snapshot_hash
			memory["cluster_summary_proposal_model"] = str(proposal_options.get("model", ""))
			memory["cluster_summary_proposed_at"] = proposed_at
			memory["cluster_summary_proposal_count"] = int(memory.get("cluster_summary_proposal_count", 0)) + 1
	return save_memory()

func accept_habit_cluster_summary_proposal(cluster_id: String) -> bool:
	var representative: Dictionary = {}
	for memory in memories.get("habit", []):
		if memory is Dictionary and str(memory.get("cluster_id", "")) == cluster_id and str(memory.get("cluster_summary_status", "")) == "proposed":
			representative = memory
			break
	if representative.is_empty():
		return false
	var member_ids: Array = []
	for memory in memories.get("habit", []):
		if memory is Dictionary and str(memory.get("cluster_id", "")) == cluster_id and str(memory.get("cluster_summary_status", "")) == "proposed":
			member_ids.append(str(memory.get("id", "")))
	var snapshot := _build_habit_cluster_snapshot(member_ids)
	if snapshot.is_empty() or str(snapshot.get("snapshot_hash", "")) != str(representative.get("cluster_summary_proposal_snapshot_hash", "")):
		return false
	return apply_habit_cluster_summary(cluster_id, member_ids, str(representative.get("cluster_summary_proposal", "")), {
		"generation_reason": "ai_proposal_accepted",
		"model": str(representative.get("cluster_summary_proposal_model", ""))
	})

func reject_habit_cluster_summary_proposal(cluster_id: String) -> bool:
	var rejected := false
	var rejected_at := Time.get_datetime_string_from_system()
	for memory in memories.get("habit", []):
		if not memory is Dictionary or str(memory.get("cluster_id", "")) != cluster_id or str(memory.get("cluster_summary_status", "")) != "proposed":
			continue
		memory["cluster_summary_status"] = "rejected"
		memory["cluster_summary_rejected_snapshot_hash"] = str(memory.get("cluster_summary_proposal_snapshot_hash", ""))
		memory["cluster_summary_proposal"] = ""
		memory["cluster_summary_proposal_snapshot_hash"] = ""
		memory["cluster_summary_proposed_at"] = ""
		memory["cluster_summary_reject_count"] = int(memory.get("cluster_summary_reject_count", 0)) + 1
		memory["cluster_summary_last_decision_at"] = rejected_at
		rejected = true
	return rejected and save_memory()

func _build_habit_cluster_snapshot(member_memory_ids: Array) -> Dictionary:
	var expected_ids: Array[String] = []
	for raw_id in member_memory_ids:
		expected_ids.append(str(raw_id))
	expected_ids.sort()
	var members: Array = []
	var hash_parts: Array[String] = []
	for memory_id in expected_ids:
		var matched: Dictionary = {}
		for memory in memories.get("habit", []):
			if memory is Dictionary and str(memory.get("id", "")) == memory_id and str(memory.get("status", MEMORY_STATUS_ACTIVE)) == MEMORY_STATUS_ACTIVE:
				matched = memory
				break
		if matched.is_empty():
			return {}
		var content := str(matched.get("content", "")).strip_edges()
		members.append({"id": memory_id, "content": content})
		hash_parts.append("%s\n%s" % [memory_id, content])
	return {
		"member_memory_ids": expected_ids,
		"members": members,
		"snapshot_hash": "\n---\n".join(hash_parts).sha256_text()
	}

func _habit_cluster_matches_snapshot(cluster_id: String, snapshot: Dictionary) -> bool:
	for cluster in build_habit_clusters():
		if str(cluster.get("cluster_id", "")) == cluster_id and Array(cluster.get("member_memory_ids", [])) == Array(snapshot.get("member_memory_ids", [])):
			return true
	return false

func _cluster_blocks_automatic_summary_task(cluster_id: String, snapshot_hash: String) -> bool:
	for memory in memories.get("habit", []):
		if not memory is Dictionary or str(memory.get("cluster_id", "")) != cluster_id:
			continue
		if str(memory.get("cluster_summary_status", "")) == "active":
			return true
		if str(memory.get("cluster_summary_status", "")) == "proposed" and str(memory.get("cluster_summary_proposal_snapshot_hash", "")) == snapshot_hash:
			return true
		if str(memory.get("cluster_summary_rejected_snapshot_hash", "")) == snapshot_hash or str(memory.get("cluster_summary_disabled_snapshot_hash", "")) == snapshot_hash:
			return true
	return false

func apply_habit_cluster_summary(cluster_id: String, member_memory_ids: Array, summary: String, summary_options: Dictionary = {}) -> bool:
	var final_summary := summary.strip_edges()
	if get_memory_domain() != MEMORY_DOMAIN_PLAYER or cluster_id.is_empty() or final_summary.is_empty() or final_summary.length() > HABIT_CLUSTER_SUMMARY_MAX_CHARS:
		return false
	var expected_ids: Array[String] = []
	for raw_id in member_memory_ids:
		expected_ids.append(str(raw_id))
	expected_ids.sort()
	if expected_ids.size() < HABIT_CLUSTER_SUMMARY_MIN_MEMBERS:
		return false
	var matching_cluster: Dictionary = {}
	for cluster in build_habit_clusters():
		if str(cluster.get("cluster_id", "")) == cluster_id and Array(cluster.get("member_memory_ids", [])) == expected_ids:
			matching_cluster = cluster
			break
	if matching_cluster.is_empty():
		return false
	var updated_count := 0
	var confidence_total := 0.0
	for memory in memories.get("habit", []):
		if memory is Dictionary and expected_ids.has(str(memory.get("id", ""))):
			confidence_total += clampf(float(memory.get("confidence", DEFAULT_MEMORY_CONFIDENCE)), 0.0, 1.0)
	var summary_confidence := confidence_total / float(expected_ids.size())
	var accepted_at := Time.get_datetime_string_from_system()
	for memory in memories.get("habit", []):
		if memory is Dictionary and expected_ids.has(str(memory.get("id", ""))):
			memory["cluster_id"] = cluster_id
			memory["cluster_summary"] = final_summary
			memory["cluster_summary_status"] = "active"
			memory["cluster_summary_version"] = maxi(1, int(memory.get("cluster_summary_version", 0)) + 1)
			memory["cluster_summary_generated_at"] = accepted_at
			memory["cluster_summary_member_memory_ids"] = expected_ids.duplicate()
			memory["cluster_summary_generation_reason"] = str(summary_options.get("generation_reason", "explicit_cluster_summary"))
			memory["cluster_summary_confidence"] = summary_confidence
			memory["cluster_summary_proposal"] = ""
			memory["cluster_summary_proposal_snapshot_hash"] = ""
			memory["cluster_summary_proposal_model"] = str(summary_options.get("model", ""))
			memory["cluster_summary_proposed_at"] = ""
			memory["cluster_summary_rejected_snapshot_hash"] = ""
			memory["cluster_summary_disabled_snapshot_hash"] = ""
			if str(summary_options.get("generation_reason", "")) == "ai_proposal_accepted":
				memory["cluster_summary_accept_count"] = int(memory.get("cluster_summary_accept_count", 0)) + 1
				memory["cluster_summary_last_decision_at"] = accepted_at
			updated_count += 1
	return updated_count == expected_ids.size() and save_memory()

func _get_active_habit_cluster_id(memory: Dictionary, layer: String) -> String:
	if layer != "habit" or str(memory.get("cluster_summary_status", "")) != "active" or str(memory.get("cluster_summary", "")).is_empty():
		return ""
	return str(memory.get("cluster_id", ""))

func _get_habit_cluster_member_ids(memory: Dictionary) -> Array[String]:
	var cluster_id := _get_active_habit_cluster_id(memory, "habit")
	var member_ids: Array[String] = []
	if cluster_id.is_empty():
		return member_ids
	for candidate in memories.get("habit", []):
		if candidate is Dictionary and str(candidate.get("cluster_id", "")) == cluster_id and str(candidate.get("status", MEMORY_STATUS_ACTIVE)) == MEMORY_STATUS_ACTIVE:
			member_ids.append(str(candidate.get("id", "")))
	member_ids.sort()
	return member_ids

func _get_memory_prompt_content(memory: Dictionary, layer: String) -> String:
	if not _get_active_habit_cluster_id(memory, layer).is_empty():
		return str(memory.get("cluster_summary", ""))
	return str(memory.get("content", ""))

func should_surface_memory_in_player_channels(mem: Dictionary, channel: String = "prompt", has_query: bool = false) -> bool:
	if mem.is_empty():
		return false
	if str(mem.get("status", MEMORY_STATUS_ACTIVE)) != MEMORY_STATUS_ACTIVE:
		return false
	if str(mem.get("memory_domain", get_memory_domain())) != get_memory_domain():
		return false
	var scope = normalize_memory_scope(str(mem.get("memory_scope", MEMORY_SCOPE_PLAYER_SHARED)))
	var visibility = normalize_memory_visibility(str(mem.get("memory_visibility", "")), scope)
	if visibility == MEMORY_VISIBILITY_HIDDEN or visibility == MEMORY_VISIBILITY_ARCHIVE_ONLY:
		return false

	if channel == "prompt":
		if visibility == MEMORY_VISIBILITY_PROMPT:
			return true
		return visibility == MEMORY_VISIBILITY_CONDITIONAL and has_query

	if channel == "album" or channel == "revisit":
		return scope == MEMORY_SCOPE_PLAYER_SHARED or scope == MEMORY_SCOPE_PLAYER_OBSERVED

	return visibility == MEMORY_VISIBILITY_PROMPT

func accepts_memory_entry(layer: String, content: String, _memory_context: Dictionary = {}, memory_options: Dictionary = {}) -> bool:
	var final_layer = layer.strip_edges().to_lower()
	if not PLAYER_MEMORY_ALLOWED_LAYERS.has(final_layer):
		return false
	if content.strip_edges() == "":
		return false
	if str(memory_options.get("source_type", "")).strip_edges() == "story_script":
		return false
	var scope = normalize_memory_scope(str(memory_options.get("memory_scope", get_default_memory_scope())))
	if scope != MEMORY_SCOPE_PLAYER_SHARED:
		return false
	return true

func query_memories(query_options: Dictionary = {}) -> Array:
	var channel := str(query_options.get("channel", "prompt"))
	var layers = query_options.get("layers", PLAYER_MEMORY_ALLOWED_LAYERS)
	var max_count := int(query_options.get("max_count", 12))
	var require_player_shared := bool(query_options.get("require_player_shared", channel == "prompt" or channel == "archive"))
	var results: Array = []
	if not layers is Array:
		layers = PLAYER_MEMORY_ALLOWED_LAYERS
	for raw_layer in layers:
		var layer := str(raw_layer)
		if not memories.has(layer):
			continue
		for mem in memories[layer]:
			if not mem is Dictionary:
				continue
			if require_player_shared and normalize_memory_scope(str(mem.get("memory_scope", get_default_memory_scope()))) != MEMORY_SCOPE_PLAYER_SHARED:
				continue
			if not should_surface_memory_in_player_channels(mem, channel, bool(query_options.get("has_query", false))):
				continue
			results.append({"layer": layer, "memory": mem})
	results.sort_custom(func(a, b): return _is_memory_governance_higher(a["memory"], b["memory"]))
	if max_count > 0 and results.size() > max_count:
		return results.slice(0, max_count)
	return results

func _is_memory_governance_higher(a: Dictionary, b: Dictionary) -> bool:
	if bool(a.get("is_pinned", false)) != bool(b.get("is_pinned", false)):
		return bool(a.get("is_pinned", false))
	var confidence_a := float(a.get("confidence", DEFAULT_MEMORY_CONFIDENCE))
	var confidence_b := float(b.get("confidence", DEFAULT_MEMORY_CONFIDENCE))
	if not is_equal_approx(confidence_a, confidence_b):
		return confidence_a > confidence_b
	var evidence_a := int(a.get("evidence_count", 1))
	var evidence_b := int(b.get("evidence_count", 1))
	if evidence_a != evidence_b:
		return evidence_a > evidence_b
	var day_offset_a := int(a.get("day_offset", 0))
	var day_offset_b := int(b.get("day_offset", 0))
	if day_offset_a != day_offset_b:
		return day_offset_a > day_offset_b
	var confirmed_a := str(a.get("last_confirmed_at", a.get("timestamp", "")))
	var confirmed_b := str(b.get("last_confirmed_at", b.get("timestamp", "")))
	if confirmed_a != confirmed_b:
		return confirmed_a > confirmed_b
	return str(a.get("id", "")) > str(b.get("id", ""))

func get_memory_time_relevance(memory: Dictionary, layer: String, now_unix: float = -1.0) -> Dictionary:
	var reference_unix: float = now_unix if now_unix >= 0.0 else Time.get_unix_time_from_system()
	var confirmed_at := str(memory.get("last_confirmed_at", memory.get("timestamp", "")))
	var confirmed_unix: float = float(Time.get_unix_time_from_datetime_string(confirmed_at)) if not confirmed_at.is_empty() else reference_unix
	var age_seconds: float = maxf(0.0, reference_unix - confirmed_unix)
	var base_half_life_days := float(HALF_LIFE_DAYS.get(layer, 90.0))
	var confidence := clampf(float(memory.get("confidence", DEFAULT_MEMORY_CONFIDENCE)), 0.0, 1.0)
	var evidence_count := maxi(1, int(memory.get("evidence_count", 1)))
	var half_life_days: float = base_half_life_days * (0.75 + confidence * 0.75) * sqrt(float(evidence_count))
	var relevance: float = pow(0.5, age_seconds / maxf(SECONDS_PER_DAY, half_life_days * SECONDS_PER_DAY))
	var protected: bool = layer == "core" or layer == "bond" or bool(memory.get("is_bond_mark", false)) or bool(memory.get("is_pinned", false)) or confidence >= PROTECTED_MEMORY_CONFIDENCE
	relevance = maxf(PROTECTED_TIME_RELEVANCE if protected else MIN_TIME_RELEVANCE, relevance)
	return {
		"age_seconds": age_seconds,
		"half_life_days": half_life_days,
		"time_relevance": relevance,
		"protected": protected
	}

func get_memory_consolidation_status(memory: Dictionary) -> String:
	var status := str(memory.get("consolidation_status", ""))
	if status == CONSOLIDATION_STATUS_CANDIDATE or status == CONSOLIDATION_STATUS_CONSOLIDATED:
		return status
	if bool(memory.get("is_bond_mark", false)) or bool(memory.get("is_pinned", false)) or int(memory.get("evidence_count", 1)) >= CONSOLIDATION_EVIDENCE_REQUIRED or float(memory.get("confidence", DEFAULT_MEMORY_CONFIDENCE)) >= PROTECTED_MEMORY_CONFIDENCE:
		return CONSOLIDATION_STATUS_CONSOLIDATED
	return CONSOLIDATION_STATUS_CANDIDATE

func format_deleted_memory_status(memory: Dictionary) -> String:
	if str(memory.get("deletion_reason", "")) == DELETION_REASON_CANDIDATE_EXPIRED:
		return "候选长期未确认，已暂时过期 · 不会进入对话记忆，可随时恢复。"
	if str(memory.get("deletion_reason", "")) == DELETION_REASON_CANDIDATE_CAPACITY:
		return "候选因容量治理暂时归档 · 不会进入对话记忆，可随时恢复。"
	return "已删除 · 不会进入对话记忆，可随时恢复。"

func _get_memory_retrieval_factor(memory: Dictionary, layer: String, now_unix: float) -> float:
	var time_relevance := float(get_memory_time_relevance(memory, layer, now_unix).get("time_relevance", 1.0))
	var consolidation_factor := CANDIDATE_RETRIEVAL_FACTOR if get_memory_consolidation_status(memory) == CONSOLIDATION_STATUS_CANDIDATE else 1.0
	var exposure_factor := float(get_memory_exposure_relevance(memory, layer, now_unix).get("exposure_factor", 1.0))
	return time_relevance * consolidation_factor * exposure_factor

func get_memory_exposure_relevance(memory: Dictionary, layer: String, now_unix: float = -1.0) -> Dictionary:
	if layer == "core":
		return {"exposure_factor": 1.0, "exposure_age_seconds": 0.0, "exposure_penalty": 0.0, "protected": true}
	var last_recalled_at := str(memory.get("last_recalled_at", "")).strip_edges()
	var exposure_count := maxi(0, int(memory.get("exposure_count", 0)))
	if last_recalled_at.is_empty() or exposure_count <= 0:
		return {"exposure_factor": 1.0, "exposure_age_seconds": 0.0, "exposure_penalty": 0.0, "protected": false}
	var reference_unix: float = now_unix if now_unix >= 0.0 else Time.get_unix_time_from_system()
	var recalled_unix := float(Time.get_unix_time_from_datetime_string(last_recalled_at))
	var age_seconds := maxf(0.0, reference_unix - recalled_unix)
	var peak_penalty := minf(EXPOSURE_PENALTY_MAX, EXPOSURE_PENALTY_BASE + EXPOSURE_PENALTY_LOG_STEP * log(float(1 + exposure_count)) / log(2.0))
	var recovered_penalty := peak_penalty * pow(0.5, age_seconds / (EXPOSURE_PENALTY_HALF_LIFE_HOURS * 3600.0))
	return {
		"exposure_factor": 1.0 - recovered_penalty,
		"exposure_age_seconds": age_seconds,
		"exposure_penalty": recovered_penalty,
		"protected": false
	}

func get_memory_emotion_modulation(memory: Dictionary, layer: String, emotion_context: Dictionary = {}) -> Dictionary:
	if layer == "core":
		return {"emotion_affinity": "ignored_core", "emotion_factor": 1.0, "matched_mood_id": ""}
	var mood_id := str(emotion_context.get("macro_mood_id", "")).strip_edges().to_lower()
	var raw_tags: Array = memory.get("emotion_tags", []) if memory.get("emotion_tags", []) is Array else []
	var tags: Array[String] = []
	for raw_tag in raw_tags:
		var tag := str(raw_tag).strip_edges().to_lower()
		if MOOD_ORDER.has(tag) and not tags.has(tag):
			tags.append(tag)
	if mood_id.is_empty() or not MOOD_ORDER.has(mood_id) or tags.is_empty():
		return {"emotion_affinity": "neutral", "emotion_factor": 1.0, "matched_mood_id": ""}
	var mood_index := MOOD_ORDER.find(mood_id)
	var nearest_distance := MOOD_ORDER.size()
	var matched_mood_id := ""
	for tag in tags:
		var distance: int = absi(MOOD_ORDER.find(tag) - mood_index)
		if distance < nearest_distance:
			nearest_distance = distance
			matched_mood_id = tag
	var factor := EMOTION_FACTOR_CONFLICT
	var affinity := "conflict"
	if nearest_distance == 0:
		factor = EMOTION_FACTOR_MATCH
		affinity = "match"
	elif nearest_distance == 1:
		factor = EMOTION_FACTOR_NEAR
		affinity = "near"
	return {"emotion_affinity": affinity, "emotion_factor": factor, "matched_mood_id": matched_mood_id}

func process_candidate_expiration(now_unix: float = -1.0) -> int:
	var reference_unix: float = now_unix if now_unix >= 0.0 else Time.get_unix_time_from_system()
	var expired_count := 0
	for layer in ["emotion", "habit"]:
		for memory in memories.get(layer, []):
			if not memory is Dictionary or str(memory.get("status", MEMORY_STATUS_ACTIVE)) != MEMORY_STATUS_ACTIVE:
				continue
			if str(memory.get("consolidation_status", "")) != CONSOLIDATION_STATUS_CANDIDATE or bool(memory.get("is_pinned", false)):
				continue
			var anchor := str(memory.get("restored_at", memory.get("last_confirmed_at", memory.get("timestamp", ""))))
			var anchor_unix: float = float(Time.get_unix_time_from_datetime_string(anchor)) if not anchor.is_empty() else reference_unix
			if reference_unix - anchor_unix < CANDIDATE_EXPIRATION_DAYS * SECONDS_PER_DAY:
				continue
			memory["status"] = MEMORY_STATUS_DELETED
			memory["deleted_at"] = Time.get_datetime_string_from_unix_time(int(reference_unix))
			memory["deletion_reason"] = DELETION_REASON_CANDIDATE_EXPIRED
			memory["candidate_expired_at"] = memory["deleted_at"]
			if layer == "habit":
				_invalidate_habit_cluster_summary(str(memory.get("cluster_id", "")))
			expired_count += 1
	if expired_count > 0:
		save_memory()
	return expired_count

func process_candidate_capacity(now_unix: float = -1.0, capacity_override: Dictionary = {}) -> Dictionary:
	var reference_unix: float = now_unix if now_unix >= 0.0 else Time.get_unix_time_from_system()
	var deleted_at := Time.get_datetime_string_from_unix_time(int(reference_unix))
	var evicted_ids: Array[String] = []
	var by_layer: Dictionary = {}
	for layer in CANDIDATE_LAYER_CAPACITY.keys():
		var capacity := maxi(0, int(capacity_override.get(layer, CANDIDATE_LAYER_CAPACITY[layer])))
		var candidates: Array = []
		for memory in memories.get(layer, []):
			if not memory is Dictionary or str(memory.get("status", MEMORY_STATUS_ACTIVE)) != MEMORY_STATUS_ACTIVE:
				continue
			if str(memory.get("consolidation_status", "")) != CONSOLIDATION_STATUS_CANDIDATE:
				continue
			if get_memory_consolidation_status(memory) != CONSOLIDATION_STATUS_CANDIDATE or bool(memory.get("is_pinned", false)) or bool(memory.get("is_bond_mark", false)):
				continue
			candidates.append(memory)
		candidates.sort_custom(func(a, b): return _is_weaker_candidate(a, b))
		var evict_count := maxi(0, candidates.size() - capacity)
		var layer_ids: Array[String] = []
		for index in evict_count:
			var memory: Dictionary = candidates[index]
			memory["status"] = MEMORY_STATUS_DELETED
			memory["deleted_at"] = deleted_at
			memory["deletion_reason"] = DELETION_REASON_CANDIDATE_CAPACITY
			memory["candidate_expired_at"] = deleted_at
			if layer == "habit":
				_invalidate_habit_cluster_summary(str(memory.get("cluster_id", "")))
			var memory_id := str(memory.get("id", ""))
			layer_ids.append(memory_id)
			evicted_ids.append(memory_id)
		by_layer[layer] = {"capacity": capacity, "active_candidates": candidates.size() - evict_count, "evicted_ids": layer_ids}
	return {"evicted_count": evicted_ids.size(), "evicted_ids": evicted_ids, "by_layer": by_layer}

func _is_weaker_candidate(a: Dictionary, b: Dictionary) -> bool:
	var confidence_a := float(a.get("confidence", DEFAULT_MEMORY_CONFIDENCE))
	var confidence_b := float(b.get("confidence", DEFAULT_MEMORY_CONFIDENCE))
	if not is_equal_approx(confidence_a, confidence_b):
		return confidence_a < confidence_b
	var evidence_a := int(a.get("evidence_count", 1))
	var evidence_b := int(b.get("evidence_count", 1))
	if evidence_a != evidence_b:
		return evidence_a < evidence_b
	var adopted_a := int(a.get("successful_use_count", 0))
	var adopted_b := int(b.get("successful_use_count", 0))
	if adopted_a != adopted_b:
		return adopted_a < adopted_b
	var recall_a := int(a.get("recall_count", 0))
	var recall_b := int(b.get("recall_count", 0))
	if recall_a != recall_b:
		return recall_a < recall_b
	var confirmed_a := str(a.get("last_confirmed_at", a.get("timestamp", "")))
	var confirmed_b := str(b.get("last_confirmed_at", b.get("timestamp", "")))
	if confirmed_a != confirmed_b:
		return confirmed_a < confirmed_b
	return str(a.get("id", "")) < str(b.get("id", ""))

func get_memory_snapshot_for_extraction() -> Dictionary:
	var snapshot: Dictionary = {}
	for layer in memories.keys():
		snapshot[layer] = []
		for mem in memories[layer]:
			if not mem is Dictionary:
				continue
			if not should_surface_memory_in_player_channels(mem, "prompt", true):
				continue
			snapshot[layer].append({
				"id": str(mem.get("id", "")),
				"content": str(mem.get("content", "")).strip_edges(),
				"source_type": str(mem.get("source_type", "")),
				"source_id": str(mem.get("source_id", ""))
			})
	return snapshot

func build_story_memory_context() -> Dictionary:
	var context = {
		"context_domain": CONTEXT_DOMAIN_STORY,
		"time_type": "story",
		"story_time": "",
		"day_offset": 0,
		"story_period": "",
		"story_weather": "",
		"story_location_id": "",
		"story_area_id": ""
	}
	if GameDataManager.story_time_manager:
		context["story_time"] = GameDataManager.story_time_manager.get_story_time_string()
		context["day_offset"] = GameDataManager.story_time_manager.current_day_offset
		context["story_period"] = GameDataManager.story_time_manager.current_period
		var day_cfg = GameDataManager.story_time_manager.get_current_day_config()
		context["story_weather"] = str(day_cfg.get("weather", ""))
	if typeof(MapDataManager) != TYPE_NIL:
		context["story_location_id"] = MapDataManager.get_last_location()
		context["story_area_id"] = MapDataManager.get_last_area()
	return context

func build_reality_memory_context() -> Dictionary:
	var dt = Time.get_datetime_dict_from_system()
	var current_hour = int(dt.get("hour", 0))
	var context = {
		"context_domain": CONTEXT_DOMAIN_REALITY,
		"time_type": "reality",
		"real_datetime": Time.get_datetime_string_from_system(),
		"real_date": _get_real_date_key(),
		"real_hour": current_hour,
		"real_period": _get_real_period_label(current_hour),
		"real_weather": "",
		"real_temp": 0.0
	}
	if GameDataManager.weather_manager and GameDataManager.weather_manager.is_weather_ready:
		context["real_weather"] = GameDataManager.weather_manager.current_weather_desc
		context["real_temp"] = GameDataManager.weather_manager.current_temp
	return context

func load_memory() -> void:
	var path = get_memory_file_path()
	# 切换角色时清空旧数据
	memories = {
		"core": [],
		"emotion": [],
		"habit": [],
		"bond": []
	}
	turns_since_last_extract = 0
	revisit_state = _create_default_revisit_state()
	
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		var content = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		if json.parse(content) == OK:
			var data = json.get_data()
			if data is Dictionary:
				for key in memories.keys():
					if data.has(key) and data[key] is Array:
						var layer_mems = []
						for item in data[key]:
							# 兼容旧版本纯字符串记忆
							if item is String:
								layer_mems.append({
									"id": _generate_id(),
									"content": item,
									"timestamp": Time.get_datetime_string_from_system(),
									"story_time": "",
									"day_offset": 0,
									"decay": 0.0,
									"is_bond_mark": false,
									"source_type": "",
									"source_id": "",
									"source_title": "",
									"memory_scope": MEMORY_SCOPE_PLAYER_SHARED,
									"memory_visibility": MEMORY_VISIBILITY_PROMPT,
									"memory_participants": [],
									"memory_player_involved": true,
									"memory_player_witnessed": true,
									"context_domain": CONTEXT_DOMAIN_UNKNOWN,
									"context_time_type": "unknown",
									"story_period": "",
									"story_weather": "",
									"story_location_id": "",
									"story_area_id": "",
									"real_datetime": "",
									"real_date": "",
									"real_hour": -1,
									"real_period": "",
									"real_weather": "",
									"real_temp": 0.0,
									"embedding": [],
									"embedding_status": "missing",
									"embedding_model": "",
									"embedding_dimension": 0,
									"confidence": DEFAULT_MEMORY_CONFIDENCE,
									"evidence_count": 1,
									"last_confirmed_at": Time.get_datetime_string_from_system(),
									"last_recalled_at": "",
									"recall_count": 0,
									"exposure_count": 0,
									"last_revisited_at": "",
									"last_revisited_story_day": -9999,
									"revisit_count": 0,
									"last_revisit_event_id": "",
									"last_revisit_outcome": "",
									"last_revisit_outcome_at": "",
									"successful_revisit_count": 0,
									"revisit_suppressed_until": "",
									"successful_use_count": 0,
									"correction_count": 0,
									"status": MEMORY_STATUS_ACTIVE,
									"deleted_at": "",
									"superseded_at": "",
									"superseded_by": "",
									"supersedes": [],
									"is_pinned": false,
									"evidence_sources": [],
									"revision_history": []
									,"consolidation_status": CONSOLIDATION_STATUS_CANDIDATE
									,"consolidated_at": ""
									,"emotion_tags": []
									,"deletion_reason": ""
									,"candidate_expired_at": ""
									,"restored_at": ""
									,"cluster_id": ""
									,"cluster_summary": ""
									,"cluster_summary_status": ""
									,"cluster_summary_version": 0
									,"cluster_summary_generated_at": ""
								})
							elif item is Dictionary and item.has("id") and item.has("content"):
								if not item.has("decay"): item["decay"] = 0.0
								if not item.has("is_bond_mark"): item["is_bond_mark"] = false
								if not item.has("source_type"): item["source_type"] = ""
								if not item.has("source_id"): item["source_id"] = ""
								if not item.has("source_title"): item["source_title"] = ""
								if not item.has("memory_scope"): item["memory_scope"] = MEMORY_SCOPE_PLAYER_SHARED
								if not item.has("memory_visibility"): item["memory_visibility"] = get_default_visibility_for_scope(str(item.get("memory_scope", MEMORY_SCOPE_PLAYER_SHARED)))
								if not item.has("memory_participants"): item["memory_participants"] = []
								if not item.has("memory_player_involved"): item["memory_player_involved"] = true
								if not item.has("memory_player_witnessed"): item["memory_player_witnessed"] = true
								if not item.has("story_time"): item["story_time"] = ""
								if not item.has("day_offset"): item["day_offset"] = 0
								if not item.has("context_domain"): item["context_domain"] = CONTEXT_DOMAIN_UNKNOWN
								if not item.has("context_time_type"): item["context_time_type"] = "unknown"
								if not item.has("story_period"): item["story_period"] = ""
								if not item.has("story_weather"): item["story_weather"] = ""
								if not item.has("story_location_id"): item["story_location_id"] = ""
								if not item.has("story_area_id"): item["story_area_id"] = ""
								if not item.has("real_datetime"): item["real_datetime"] = ""
								if not item.has("real_date"): item["real_date"] = ""
								if not item.has("real_hour"): item["real_hour"] = -1
								if not item.has("real_period"): item["real_period"] = ""
								if not item.has("real_weather"): item["real_weather"] = ""
								if not item.has("real_temp"): item["real_temp"] = 0.0
								if not item.has("memory_domain"): item["memory_domain"] = get_memory_domain()
								if not item.has("embedding"): item["embedding"] = []
								if not item.has("embedding_status"): item["embedding_status"] = "ready" if not item["embedding"].is_empty() else "missing"
								if not item.has("embedding_model"): item["embedding_model"] = ""
								if not item.has("embedding_dimension"): item["embedding_dimension"] = item["embedding"].size()
								if not item.has("confidence"): item["confidence"] = DEFAULT_MEMORY_CONFIDENCE
								if not item.has("evidence_count"): item["evidence_count"] = 1
								if not item.has("last_confirmed_at"): item["last_confirmed_at"] = str(item.get("timestamp", ""))
								if not item.has("last_recalled_at"): item["last_recalled_at"] = ""
								if not item.has("recall_count"): item["recall_count"] = 0
								if not item.has("exposure_count"): item["exposure_count"] = int(item.get("recall_count", 0))
								if not item.has("last_revisited_at"): item["last_revisited_at"] = ""
								if not item.has("last_revisited_story_day"): item["last_revisited_story_day"] = -9999
								if not item.has("revisit_count"): item["revisit_count"] = 0
								if not item.has("last_revisit_event_id"): item["last_revisit_event_id"] = ""
								if not item.has("last_revisit_outcome"): item["last_revisit_outcome"] = ""
								if not item.has("last_revisit_outcome_at"): item["last_revisit_outcome_at"] = ""
								if not item.has("successful_revisit_count"): item["successful_revisit_count"] = 0
								if not item.has("revisit_suppressed_until"): item["revisit_suppressed_until"] = ""
								if not item.has("successful_use_count"): item["successful_use_count"] = 0
								if not item.has("correction_count"): item["correction_count"] = 0
								if not item.has("status"): item["status"] = MEMORY_STATUS_ACTIVE
								if not item.has("deleted_at"): item["deleted_at"] = ""
								if not item.has("superseded_at"): item["superseded_at"] = ""
								if not item.has("superseded_by"): item["superseded_by"] = ""
								if not item.has("supersedes"): item["supersedes"] = []
								if not item.has("is_pinned"): item["is_pinned"] = false
								if not item.has("evidence_sources"): item["evidence_sources"] = []
								if not item.has("revision_history"): item["revision_history"] = []
								if not item.has("consolidation_status"): item["consolidation_status"] = CONSOLIDATION_STATUS_CONSOLIDATED
								if not item.has("consolidated_at"): item["consolidated_at"] = str(item.get("last_confirmed_at", "")) if str(item.get("consolidation_status", "")) == CONSOLIDATION_STATUS_CONSOLIDATED else ""
								if not item.has("emotion_tags"): item["emotion_tags"] = []
								if not item.has("deletion_reason"): item["deletion_reason"] = ""
								if not item.has("candidate_expired_at"): item["candidate_expired_at"] = ""
								if not item.has("restored_at"): item["restored_at"] = ""
								if key == "habit":
									_initialize_habit_cluster_fields(item)
								layer_mems.append(item)
						memories[key] = layer_mems
				turns_since_last_extract = int(data.get("_turns_since_last_extract", turns_since_last_extract))
				var loaded_revisit = data.get("_revisit_state", {})
				if loaded_revisit is Dictionary:
					revisit_state["last_story_revisit_memory_id"] = str(loaded_revisit.get("last_story_revisit_memory_id", loaded_revisit.get("last_revisit_memory_id", "")))
					revisit_state["last_story_revisit_day"] = int(loaded_revisit.get("last_story_revisit_day", loaded_revisit.get("last_revisit_day", -9999)))
					revisit_state["last_reality_revisit_memory_id"] = str(loaded_revisit.get("last_reality_revisit_memory_id", ""))
					revisit_state["last_reality_revisit_date"] = str(loaded_revisit.get("last_reality_revisit_date", ""))
					var revisited_ids = loaded_revisit.get("revisited_memory_ids", [])
					revisit_state["revisited_memory_ids"] = revisited_ids if revisited_ids is Array else []

func save_memory() -> bool:
	process_candidate_capacity()
	var data = memories.duplicate(true)
	data["_turns_since_last_extract"] = turns_since_last_extract
	data["_revisit_state"] = revisit_state.duplicate(true)
	var content = JSON.stringify(data, "\t")
	return SafeFileAccessUtil.store_string(get_memory_file_path(), content)

func _generate_id() -> String:
	return str(Time.get_unix_time_from_system() * 1000 + randi() % 1000)

func add_memory(layer: String, content: String, memory_context: Dictionary = {}) -> void:
	if not accepts_memory_entry(layer, content, memory_context, {}):
		return
	if memories.has(layer):
		# 防止重复内容添加
		for mem in memories[layer]:
			if _is_duplicate_memory_entry(mem, content):
				_reinforce_memory_evidence(mem, {})
				save_memory()
				return
				
		var embedding = await DoubaoEmbeddingClient.get_embedding(content)
				
		var new_mem = {
			"id": _generate_id(),
			"content": content,
			"timestamp": Time.get_datetime_string_from_system(),
			"story_time": GameDataManager.story_time_manager.get_story_time_string() if GameDataManager.story_time_manager else "",
			"day_offset": GameDataManager.story_time_manager.current_day_offset if GameDataManager.story_time_manager else 0,
			"decay": 0.0, # 0.0-100.0，达到100则可能被遗忘
			"is_bond_mark": false, # 是否带有羁绊印记（重要记忆）
			"embedding": embedding,
			"embedding_status": "ready" if not embedding.is_empty() else "failed",
			"embedding_model": _get_current_embedding_model(),
			"embedding_dimension": embedding.size(),
			"source_type": "",
			"source_id": "",
			"source_title": "",
			"memory_domain": get_memory_domain(),
			"memory_scope": get_default_memory_scope(),
			"memory_visibility": get_default_memory_visibility(),
			"memory_participants": [],
			"memory_player_involved": true,
			"memory_player_witnessed": true,
			"context_domain": CONTEXT_DOMAIN_UNKNOWN,
			"context_time_type": "unknown",
			"story_period": "",
			"story_weather": "",
			"story_location_id": "",
			"story_area_id": "",
			"real_datetime": "",
			"real_date": "",
			"real_hour": -1,
			"real_period": "",
			"real_weather": "",
			"real_temp": 0.0,
			"confidence": DEFAULT_MEMORY_CONFIDENCE,
			"evidence_count": 1,
			"last_confirmed_at": Time.get_datetime_string_from_system(),
			"last_recalled_at": "",
			"recall_count": 0,
			"exposure_count": 0,
			"successful_use_count": 0,
			"correction_count": 0,
			"status": MEMORY_STATUS_ACTIVE,
			"deleted_at": "",
			"superseded_at": "",
			"superseded_by": "",
			"supersedes": [],
			"is_pinned": false,
			"evidence_sources": [],
			"revision_history": []
			,"consolidation_status": CONSOLIDATION_STATUS_CONSOLIDATED if layer == "core" else CONSOLIDATION_STATUS_CANDIDATE
			,"consolidated_at": Time.get_datetime_string_from_system() if layer == "core" else ""
			,"emotion_tags": []
			,"deletion_reason": ""
			,"candidate_expired_at": ""
			,"restored_at": ""
		}
		if layer == "habit":
			_initialize_habit_cluster_fields(new_mem)
		_apply_memory_context(new_mem, memory_context)
		memories[layer].append(new_mem)
		if layer == "habit":
			_invalidate_habit_cluster_summary()
		save_memory()
		print("【记忆管理器】新增 %s 记忆: [%s] %s" % [layer, new_mem["id"], content])

func add_memory_quick(layer: String, content: String, memory_context: Dictionary = {}, memory_options: Dictionary = {}) -> void:
	layer = layer.strip_edges().to_lower()
	if not accepts_memory_entry(layer, content, memory_context, memory_options):
		return
	if not memories.has(layer):
		return
	var final_content = content.strip_edges()
	if final_content == "":
		return
	var source_type = str(memory_options.get("source_type", "")).strip_edges()
	var source_id = str(memory_options.get("source_id", "")).strip_edges()
	for mem in memories[layer]:
		if _is_duplicate_memory_entry(mem, final_content, source_type, source_id):
			_reinforce_memory_evidence(mem, memory_options)
			save_memory()
			return
	var initial_confidence := clampf(float(memory_options.get("confidence", BOND_MEMORY_CONFIDENCE if bool(memory_options.get("is_bond_mark", false)) else DEFAULT_MEMORY_CONFIDENCE)), 0.0, MAX_MEMORY_CONFIDENCE)
	var confirmed_at := Time.get_datetime_string_from_system()

	var initial_consolidation_status := CONSOLIDATION_STATUS_CONSOLIDATED if layer == "core" or layer == "bond" or bool(memory_options.get("is_bond_mark", false)) or bool(memory_options.get("is_pinned", false)) or initial_confidence >= PROTECTED_MEMORY_CONFIDENCE else CONSOLIDATION_STATUS_CANDIDATE
	var new_mem = {
		"id": _generate_id(),
		"content": final_content,
		"timestamp": Time.get_datetime_string_from_system(),
		"story_time": GameDataManager.story_time_manager.get_story_time_string() if GameDataManager.story_time_manager else "",
		"day_offset": GameDataManager.story_time_manager.current_day_offset if GameDataManager.story_time_manager else 0,
		"decay": 0.0,
		"is_bond_mark": bool(memory_options.get("is_bond_mark", false)),
		"embedding": [],
		"embedding_status": "pending" if GameDataManager.config and GameDataManager.config.embedding_enabled else "disabled",
		"embedding_model": _get_current_embedding_model(),
		"embedding_dimension": 0,
		"source_type": source_type,
		"source_id": source_id,
		"source_title": str(memory_options.get("source_title", "")),
		"memory_domain": str(memory_options.get("memory_domain", get_memory_domain())),
		"memory_scope": normalize_memory_scope(str(memory_options.get("memory_scope", get_default_memory_scope()))),
		"memory_visibility": normalize_memory_visibility(str(memory_options.get("memory_visibility", get_default_memory_visibility())), str(memory_options.get("memory_scope", get_default_memory_scope()))),
		"memory_participants": memory_options.get("memory_participants", []),
		"memory_player_involved": bool(memory_options.get("memory_player_involved", true)),
		"memory_player_witnessed": bool(memory_options.get("memory_player_witnessed", true)),
		"context_domain": CONTEXT_DOMAIN_UNKNOWN,
		"context_time_type": "unknown",
		"story_period": "",
		"story_weather": "",
		"story_location_id": "",
		"story_area_id": "",
		"real_datetime": "",
		"real_date": "",
		"real_hour": -1,
		"real_period": "",
		"real_weather": "",
		"real_temp": 0.0,
		"confidence": initial_confidence,
		"evidence_count": 1,
		"last_confirmed_at": confirmed_at,
		"last_recalled_at": "",
		"recall_count": 0,
		"exposure_count": 0,
		"successful_use_count": 0,
		"correction_count": 0,
		"status": MEMORY_STATUS_ACTIVE,
		"deleted_at": "",
		"superseded_at": "",
		"superseded_by": "",
		"supersedes": [],
		"is_pinned": bool(memory_options.get("is_pinned", false)),
		"evidence_sources": [_build_evidence_source(memory_options, confirmed_at)],
		"revision_history": []
		,"consolidation_status": initial_consolidation_status
		,"consolidated_at": confirmed_at if initial_consolidation_status == CONSOLIDATION_STATUS_CONSOLIDATED else ""
		,"emotion_tags": memory_options.get("emotion_tags", []).duplicate() if memory_options.get("emotion_tags", []) is Array else []
		,"deletion_reason": ""
		,"candidate_expired_at": ""
		,"restored_at": ""
	}
	if layer == "habit":
		_initialize_habit_cluster_fields(new_mem)
	_apply_memory_context(new_mem, memory_context)
	memories[layer].append(new_mem)
	if layer == "habit":
		_invalidate_habit_cluster_summary()
	save_memory()
	if GameDataManager.memory_retrieval_service:
		GameDataManager.memory_retrieval_service.request_memory_embedding(self, layer, str(new_mem["id"]), final_content)
	print("【记忆管理器】快速新增 %s 记忆: [%s] %s" % [layer, new_mem["id"], final_content])

func update_memory(layer: String, id: String, new_content: String, memory_context: Dictionary = {}) -> bool:
	if memories.has(layer):
		for i in range(memories[layer].size()):
			if memories[layer][i]["id"] == id and str(memories[layer][i].get("status", MEMORY_STATUS_ACTIVE)) == MEMORY_STATUS_ACTIVE:
				_append_memory_revision(memories[layer][i], str(memories[layer][i].get("content", "")), "update")
				memories[layer][i]["content"] = new_content
				memories[layer][i]["timestamp"] = Time.get_datetime_string_from_system()
				
				var embedding = await DoubaoEmbeddingClient.get_embedding(new_content)
				memories[layer][i]["embedding"] = embedding
				memories[layer][i]["embedding_status"] = "ready" if not embedding.is_empty() else "failed"
				memories[layer][i]["embedding_model"] = _get_current_embedding_model()
				memories[layer][i]["embedding_dimension"] = embedding.size()
				if layer == "habit":
					_invalidate_habit_cluster_summary(str(memories[layer][i].get("cluster_id", "")))
				_apply_memory_context(memories[layer][i], memory_context)
				
				save_memory()
				print("【记忆管理器】更新 %s 记忆 [%s]: %s" % [layer, id, new_content])
				return true
	return false

func update_memory_queued(layer: String, id: String, new_content: String, revision_source: Dictionary = {}) -> bool:
	var final_content := new_content.strip_edges()
	if not memories.has(layer) or final_content.is_empty():
		return false
	for memory in memories[layer]:
		if str(memory.get("id", "")) != id or str(memory.get("status", MEMORY_STATUS_ACTIVE)) != MEMORY_STATUS_ACTIVE:
			continue
		var previous_content := str(memory.get("content", ""))
		if _normalize_memory_content(previous_content) == _normalize_memory_content(final_content):
			return true
		var options := revision_source.duplicate(true)
		options["source_type"] = str(options.get("source_type", "user_correction"))
		options["source_title"] = str(options.get("source_title", "用户纠正"))
		return supersede_memory(layer, id, final_content, {}, options, "user_correction")
	return false

func enqueue_memory_edit(layer: String, id: String, new_content: String, revision_source: Dictionary = {}) -> String:
	if GameDataManager.cognition_task_queue == null or new_content.strip_edges().is_empty():
		return ""
	return GameDataManager.cognition_task_queue.enqueue("memory_edit", {
		"layer": layer,
		"memory_id": id,
		"content": new_content.strip_edges(),
		"revision_source": revision_source.duplicate(true)
	}, get_memory_domain())

func enqueue_memory_embedding(layer: String, id: String) -> String:
	if GameDataManager.cognition_task_queue == null or GameDataManager.config == null or not GameDataManager.config.embedding_enabled:
		return ""
	if not memories.has(layer):
		return ""
	for memory in memories[layer]:
		if str(memory.get("id", "")) != id or str(memory.get("status", MEMORY_STATUS_ACTIVE)) != MEMORY_STATUS_ACTIVE:
			continue
		var content := str(memory.get("content", "")).strip_edges()
		if content.is_empty():
			return ""
		var embedding_model := _get_current_embedding_model()
		memory["embedding_status"] = "pending"
		memory["embedding_model"] = embedding_model
		memory["embedding_dimension"] = 0
		memory["embedding"] = []
		if not save_memory():
			return ""
		return GameDataManager.cognition_task_queue.enqueue("memory_embedding", {
			"layer": layer,
			"memory_id": id,
			"content": content,
			"content_hash": content.sha256_text(),
			"embedding_model": embedding_model
		}, get_memory_domain())
	return ""

func queue_pending_memory_embeddings() -> Array[String]:
	var task_ids: Array[String] = []
	if GameDataManager.config == null or not GameDataManager.config.embedding_enabled:
		return task_ids
	var embedding_model := _get_current_embedding_model()
	for layer in memories.keys():
		for memory in memories[layer]:
			if str(memory.get("status", MEMORY_STATUS_ACTIVE)) != MEMORY_STATUS_ACTIVE:
				continue
			var status := str(memory.get("embedding_status", "missing"))
			var model_mismatch := str(memory.get("embedding_model", "")) != embedding_model
			if status == "ready" and not model_mismatch and not Array(memory.get("embedding", [])).is_empty():
				continue
			if model_mismatch and status == "ready":
				memory["embedding_status"] = "stale"
			var task_id := enqueue_memory_embedding(str(layer), str(memory.get("id", "")))
			if not task_id.is_empty():
				task_ids.append(task_id)
	return task_ids

func get_memory_embedding_task_state(payload: Dictionary) -> Dictionary:
	var layer := str(payload.get("layer", ""))
	var memory_id := str(payload.get("memory_id", ""))
	if not memories.has(layer):
		return {"obsolete": true}
	for memory in memories[layer]:
		if str(memory.get("id", "")) != memory_id:
			continue
		var content := str(memory.get("content", "")).strip_edges()
		var obsolete := str(memory.get("status", MEMORY_STATUS_ACTIVE)) != MEMORY_STATUS_ACTIVE \
			or content.is_empty() \
			or content.sha256_text() != str(payload.get("content_hash", "")) \
			or _get_current_embedding_model() != str(payload.get("embedding_model", ""))
		return {"obsolete": obsolete, "content": content}
	return {"obsolete": true}

func confirm_memory(layer: String, id: String, source_options: Dictionary = {}) -> bool:
	if not memories.has(layer):
		return false
	for memory in memories[layer]:
		if str(memory.get("id", "")) != id or str(memory.get("status", MEMORY_STATUS_ACTIVE)) != MEMORY_STATUS_ACTIVE:
			continue
		var options := source_options.duplicate(true)
		options["source_type"] = str(options.get("source_type", "user_confirmation"))
		options["source_title"] = str(options.get("source_title", "用户明确确认"))
		_reinforce_memory_evidence(memory, options)
		memory["successful_use_count"] = int(memory.get("successful_use_count", 0)) + 1
		return save_memory()
	return false

func supersede_memory(layer: String, id: String, new_content: String, memory_context: Dictionary = {}, memory_options: Dictionary = {}, revision_reason: String = "supersede") -> bool:
	if not memories.has(layer) or new_content.strip_edges().is_empty():
		return false
	for memory in memories[layer]:
		if str(memory.get("id", "")) != id or str(memory.get("status", MEMORY_STATUS_ACTIVE)) != MEMORY_STATUS_ACTIVE:
			continue
		var now := Time.get_datetime_string_from_system()
		var original_memory: Dictionary = memory.duplicate(true)
		var previous_content := str(memory.get("content", ""))
		_append_memory_revision(memory, previous_content, revision_reason, memory_options)
		var replacement: Dictionary = memory.duplicate(true)
		var replacement_id := _generate_id()
		replacement["id"] = replacement_id
		replacement["content"] = new_content.strip_edges()
		replacement["timestamp"] = now
		replacement["last_confirmed_at"] = now
		replacement["status"] = MEMORY_STATUS_ACTIVE
		replacement["deleted_at"] = ""
		replacement["superseded_at"] = ""
		replacement["superseded_by"] = ""
		replacement["supersedes"] = [id]
		replacement["source_type"] = str(memory_options.get("source_type", memory.get("source_type", "chat_extraction")))
		replacement["source_id"] = str(memory_options.get("source_id", memory.get("source_id", "")))
		replacement["source_title"] = str(memory_options.get("source_title", memory.get("source_title", "AI 对话提取")))
		replacement["correction_count"] = int(memory.get("correction_count", 0)) + 1
		replacement["embedding"] = []
		replacement["embedding_status"] = "pending" if GameDataManager.config and GameDataManager.config.embedding_enabled else "disabled"
		replacement["embedding_dimension"] = 0
		if layer == "habit":
			_initialize_habit_cluster_fields(replacement)
			replacement["cluster_id"] = ""
			replacement["cluster_summary"] = ""
			replacement["cluster_summary_status"] = ""
		_apply_memory_context(replacement, memory_context)
		memory["status"] = MEMORY_STATUS_SUPERSEDED
		memory["superseded_at"] = now
		memory["superseded_by"] = replacement_id
		memory["is_pinned"] = false
		memory["correction_count"] = int(memory.get("correction_count", 0)) + 1
		memory["confidence"] = maxf(0.0, float(memory.get("confidence", DEFAULT_MEMORY_CONFIDENCE)) - CONFIDENCE_REINFORCEMENT_STEP)
		memories[layer].append(replacement)
		if layer == "habit":
			_invalidate_habit_cluster_summary(str(memory.get("cluster_id", "")))
		if not save_memory():
			memories[layer].erase(replacement)
			memory.clear()
			memory.merge(original_memory, true)
			return false
		if GameDataManager.memory_retrieval_service:
			GameDataManager.memory_retrieval_service.request_memory_embedding(self, layer, replacement_id, new_content)
		return true
	return false

func _append_memory_revision(memory: Dictionary, previous_content: String, reason: String, source: Dictionary = {}) -> void:
	var revisions: Array = memory.get("revision_history", []) if memory.get("revision_history", []) is Array else []
	revisions.append({
		"content": previous_content,
		"reason": reason,
		"revised_at": Time.get_datetime_string_from_system(),
		"source_type": str(source.get("source_type", "")),
		"source_id": str(source.get("source_id", "")),
		"source_title": str(source.get("source_title", ""))
	})
	if revisions.size() > 8:
		revisions = revisions.slice(revisions.size() - 8)
	memory["revision_history"] = revisions

func _reinforce_memory_evidence(memory: Dictionary, memory_options: Dictionary) -> void:
	var confirmed_at := Time.get_datetime_string_from_system()
	memory["evidence_count"] = int(memory.get("evidence_count", 1)) + 1
	memory["confidence"] = minf(MAX_MEMORY_CONFIDENCE, float(memory.get("confidence", DEFAULT_MEMORY_CONFIDENCE)) + CONFIDENCE_REINFORCEMENT_STEP)
	memory["last_confirmed_at"] = confirmed_at
	memory["decay"] = maxf(0.0, float(memory.get("decay", 0.0)) - 25.0)
	if get_memory_consolidation_status(memory) == CONSOLIDATION_STATUS_CANDIDATE and int(memory.get("evidence_count", 1)) >= CONSOLIDATION_EVIDENCE_REQUIRED:
		memory["consolidation_status"] = CONSOLIDATION_STATUS_CONSOLIDATED
		memory["consolidated_at"] = confirmed_at
	var sources: Array = memory.get("evidence_sources", []) if memory.get("evidence_sources", []) is Array else []
	var evidence := _build_evidence_source(memory_options, confirmed_at)
	if not str(evidence.get("source_type", "")).is_empty() or not str(evidence.get("source_id", "")).is_empty():
		sources.append(evidence)
		if sources.size() > MAX_EVIDENCE_SOURCES:
			sources = sources.slice(sources.size() - MAX_EVIDENCE_SOURCES)
	memory["evidence_sources"] = sources

func _build_evidence_source(memory_options: Dictionary, confirmed_at: String) -> Dictionary:
	return {
		"source_type": str(memory_options.get("source_type", "")),
		"source_id": str(memory_options.get("source_id", "")),
		"source_title": str(memory_options.get("source_title", "")),
		"confirmed_at": confirmed_at
	}

func set_memory_embedding_state(layer: String, memory_id: String, embedding: Array, status: String) -> bool:
	if not memories.has(layer):
		return false
	for mem in memories[layer]:
		if str(mem.get("id", "")) != memory_id:
			continue
		mem["embedding"] = embedding.duplicate()
		mem["embedding_status"] = status
		mem["embedding_model"] = _get_current_embedding_model()
		mem["embedding_dimension"] = embedding.size()
		if layer == "habit":
			_invalidate_habit_cluster_summary(str(mem.get("cluster_id", "")))
		var saved := save_memory()
		if saved and layer == "habit" and status == "ready":
			queue_habit_cluster_summary_tasks()
		return saved
	return false

func _get_current_embedding_model() -> String:
	if GameDataManager.config == null:
		return ""
	if GameDataManager.config.ai_service_mode == ConfigResource.AI_SERVICE_OFFICIAL:
		return "official"
	return str(GameDataManager.config.doubao_embedding_model).strip_edges()

func _apply_memory_context(target_mem: Dictionary, memory_context: Dictionary) -> void:
	if memory_context.is_empty():
		return
	target_mem["context_domain"] = str(memory_context.get("context_domain", target_mem.get("context_domain", CONTEXT_DOMAIN_UNKNOWN)))
	target_mem["context_time_type"] = str(memory_context.get("time_type", target_mem.get("context_time_type", "unknown")))
	target_mem["story_time"] = str(memory_context.get("story_time", target_mem.get("story_time", "")))
	target_mem["day_offset"] = int(memory_context.get("day_offset", target_mem.get("day_offset", 0)))
	target_mem["story_period"] = str(memory_context.get("story_period", target_mem.get("story_period", "")))
	target_mem["story_weather"] = str(memory_context.get("story_weather", target_mem.get("story_weather", "")))
	target_mem["story_location_id"] = str(memory_context.get("story_location_id", target_mem.get("story_location_id", "")))
	target_mem["story_area_id"] = str(memory_context.get("story_area_id", target_mem.get("story_area_id", "")))
	target_mem["real_datetime"] = str(memory_context.get("real_datetime", target_mem.get("real_datetime", "")))
	target_mem["real_date"] = str(memory_context.get("real_date", target_mem.get("real_date", "")))
	target_mem["real_hour"] = int(memory_context.get("real_hour", target_mem.get("real_hour", -1)))
	target_mem["real_period"] = str(memory_context.get("real_period", target_mem.get("real_period", "")))
	target_mem["real_weather"] = str(memory_context.get("real_weather", target_mem.get("real_weather", "")))
	target_mem["real_temp"] = float(memory_context.get("real_temp", target_mem.get("real_temp", 0.0)))

func delete_memory(layer: String, id: String) -> bool:
	if not memories.has(layer):
		return false
	for memory in memories[layer]:
		if str(memory.get("id", "")) != id or str(memory.get("status", MEMORY_STATUS_ACTIVE)) != MEMORY_STATUS_ACTIVE:
			continue
		memory["status"] = MEMORY_STATUS_DELETED
		memory["deleted_at"] = Time.get_datetime_string_from_system()
		memory["deletion_reason"] = DELETION_REASON_USER
		memory["is_pinned"] = false
		if layer == "habit":
			_invalidate_habit_cluster_summary(str(memory.get("cluster_id", "")))
		if save_memory():
			print("【记忆管理器】软删除 %s 记忆 [%s]: %s" % [layer, id, str(memory.get("content", ""))])
			return true
	return false

func restore_memory(layer: String, id: String, now_unix: float = -1.0) -> bool:
	if not memories.has(layer):
		return false
	for memory in memories[layer]:
		if str(memory.get("id", "")) != id or str(memory.get("status", MEMORY_STATUS_ACTIVE)) != MEMORY_STATUS_DELETED:
			continue
		memory["status"] = MEMORY_STATUS_ACTIVE
		memory["deleted_at"] = ""
		memory["restored_at"] = Time.get_datetime_string_from_unix_time(int(now_unix)) if now_unix >= 0.0 else Time.get_datetime_string_from_system()
		if layer == "habit":
			_invalidate_habit_cluster_summary(str(memory.get("cluster_id", "")))
		return save_memory()
	return false

func set_memory_pinned(layer: String, id: String, is_pinned: bool) -> bool:
	if not memories.has(layer):
		return false
	for memory in memories[layer]:
		if str(memory.get("id", "")) != id or str(memory.get("status", MEMORY_STATUS_ACTIVE)) != MEMORY_STATUS_ACTIVE:
			continue
		memory["is_pinned"] = is_pinned
		if is_pinned and get_memory_consolidation_status(memory) == CONSOLIDATION_STATUS_CANDIDATE:
			memory["consolidation_status"] = CONSOLIDATION_STATUS_CONSOLIDATED
			memory["consolidated_at"] = Time.get_datetime_string_from_system()
		return save_memory()
	return false

func add_turn() -> bool:
	turns_since_last_extract += 1
	save_memory()
	# 将原本的10回合触发一次，改为每3回合触发一次，或者根据需要调整为更频繁
	return turns_since_last_extract % 3 == 0

func rollback_last_observed_turn() -> void:
	turns_since_last_extract = maxi(0, turns_since_last_extract - 1)
	save_memory()

func reset_turn_counter() -> void:
	turns_since_last_extract = 0
	save_memory()

func process_daily_decay(days: int) -> void:
	var changed = false
	# 只衰退 emotion 和 habit
	var layers_to_decay = ["emotion", "habit"]
	for layer in layers_to_decay:
		if memories.has(layer):
			var to_remove = []
			for i in range(memories[layer].size()):
				var mem = memories[layer][i]
				if str(mem.get("status", MEMORY_STATUS_ACTIVE)) != MEMORY_STATUS_ACTIVE:
					continue
				if mem.get("is_bond_mark", false) or mem.get("is_pinned", false):
					continue
				var confidence := clampf(float(mem.get("confidence", DEFAULT_MEMORY_CONFIDENCE)), 0.0, 1.0)
				var evidence_count := maxi(1, int(mem.get("evidence_count", 1)))
				var recall_count := maxi(0, int(mem.get("recall_count", 0)))
				var confidence_factor := maxf(0.25, 1.0 - confidence * 0.65)
				var evidence_factor := 1.0 / sqrt(float(evidence_count))
				var recall_factor := maxf(0.4, 1.0 / (1.0 + float(recall_count) * 0.05))
				var decay_increment := float(days) * 10.0 * confidence_factor * evidence_factor * recall_factor
				mem["decay"] = min(100.0, float(mem.get("decay", 0.0)) + decay_increment)
				if mem["decay"] >= 100.0:
					if get_memory_consolidation_status(mem) == CONSOLIDATION_STATUS_CANDIDATE:
						mem["status"] = MEMORY_STATUS_DELETED
						mem["deleted_at"] = Time.get_datetime_string_from_system()
						mem["deletion_reason"] = DELETION_REASON_CANDIDATE_EXPIRED
						mem["candidate_expired_at"] = mem["deleted_at"]
						if layer == "habit":
							_invalidate_habit_cluster_summary(str(mem.get("cluster_id", "")))
						continue
					if confidence >= PROTECTED_MEMORY_CONFIDENCE:
						mem["decay"] = 95.0
					else:
						to_remove.append(i)
				changed = true
			
			# 倒序删除以防索引错乱
			for i in range(to_remove.size() - 1, -1, -1):
				var idx = to_remove[i]
				print("【记忆管理器】遗忘记忆(因衰退): %s" % memories[layer][idx]["content"])
				if layer == "habit":
					_invalidate_habit_cluster_summary(str(memories[layer][idx].get("cluster_id", "")))
				memories[layer].remove_at(idx)
	
	if changed:
		save_memory()

func reinforce_memory(layer: String, id: String) -> void:
	if memories.has(layer):
		for mem in memories[layer]:
			if mem["id"] == id and str(mem.get("status", MEMORY_STATUS_ACTIVE)) == MEMORY_STATUS_ACTIVE:
				mem["decay"] = max(0.0, mem.get("decay", 0.0) - 50.0) # 重新提及，衰退值减半
				save_memory()
				return

func get_memory_prompt(query_embedding: Array = [], query_options: Dictionary = {}) -> String:
	var result := build_memory_prompt_result(query_embedding, query_options)
	var rendered_memories: Array = []
	for candidate in result.get("selected", []):
		if bool(candidate.get("rendered", false)):
			rendered_memories.append(candidate.get("memory", {}))
	_record_recalled_memories(rendered_memories)
	last_memory_prompt_result = _sanitize_memory_prompt_result(result)
	return str(result.get("prompt", ""))

func build_memory_prompt_result(query_embedding: Array = [], query_options: Dictionary = {}) -> Dictionary:
	var prompt_lines: Array[String] = []
	var selected: Array = []
	var rejected: Array = []
	var has_query := query_embedding.size() > 0
	var now_unix := float(query_options.get("now_unix", Time.get_unix_time_from_system()))
	var emotion_context: Dictionary = query_options.get("emotion_context", {}) if query_options.get("emotion_context", {}) is Dictionary else {}
	process_candidate_expiration(now_unix)
	var layer_truncated := false
	
	if memories["core"].size() > 0:
		var contents: Array[String] = []
		var core_candidates: Array = []
		for m in memories["core"]:
			if m is Dictionary and should_surface_memory_in_player_channels(m, "prompt", has_query):
				core_candidates.append(m)
		core_candidates.sort_custom(func(a, b): return _is_memory_governance_higher(a, b))
		for index in range(core_candidates.size()):
			var memory_entry: Dictionary = core_candidates[index]
			if contents.size() >= int(MEMORY_LAYER_LIMITS["core"]):
				rejected.append(_build_retrieval_candidate(memory_entry, "core", "governance", -1.0, -1.0, "layer_limit", now_unix))
				continue
			contents.append(str(memory_entry["content"]))
			selected.append(_build_retrieval_candidate(memory_entry, "core", "governance", -1.0, -1.0, "selected", now_unix))
		if contents.size() > 0:
			var core_line := "- 核心记忆（永不覆盖，严格遵守）：" + "；".join(contents)
			layer_truncated = layer_truncated or core_line.length() > int(MEMORY_LAYER_CHAR_LIMITS["core"])
			prompt_lines.append(_truncate_memory_prompt(core_line, int(MEMORY_LAYER_CHAR_LIMITS["core"])))
		
	var layers = {
		"emotion": "- 情绪记忆（据此调整沟通方式）：",
		"habit": "- 习惯记忆（主动贴合用户日常）：",
		"bond": "- 羁绊记忆（专属情感锚点，可主动提起）："
	}
	
	for layer in layers.keys():
		if memories[layer].size() > 0:
			var relevant_mems: Array[String] = []
			var layer_limit := int(MEMORY_LAYER_LIMITS.get(layer, 3))
			var rendered_cluster_ids: Dictionary = {}
			
			if has_query:
				var scored_mems: Array = []
				var fallback_mems: Array = []
				for m in memories[layer]:
					if not should_surface_memory_in_player_channels(m, "prompt", true):
						continue
					var emb = m.get("embedding", [])
					if emb is Array and emb.size() > 0 and query_embedding.size() == emb.size():
						var similarity := _cosine_similarity(query_embedding, emb)
						if similarity >= 0.4:
							var confidence := float(m.get("confidence", DEFAULT_MEMORY_CONFIDENCE))
							var retrieval_factor := _get_memory_retrieval_factor(m, layer, now_unix)
							var emotion_factor := float(get_memory_emotion_modulation(m, layer, emotion_context).get("emotion_factor", 1.0))
							scored_mems.append({
								"content": str(m["content"]),
								"memory": m,
								"similarity": similarity,
								"score": similarity * (0.5 + confidence * 0.5) * retrieval_factor * emotion_factor,
								"confidence": confidence,
								"evidence_count": int(m.get("evidence_count", 1)),
								"retrieval_factor": retrieval_factor,
								"emotion_factor": emotion_factor
							})
						else:
							rejected.append(_build_retrieval_candidate(m, layer, "semantic", similarity, similarity * (0.5 + float(m.get("confidence", DEFAULT_MEMORY_CONFIDENCE)) * 0.5) * _get_memory_retrieval_factor(m, layer, now_unix) * float(get_memory_emotion_modulation(m, layer, emotion_context).get("emotion_factor", 1.0)), "below_threshold", now_unix, emotion_context))
					else:
						fallback_mems.append({
							"content": str(m["content"]),
							"memory": m,
							"confidence": float(m.get("confidence", DEFAULT_MEMORY_CONFIDENCE)),
							"evidence_count": int(m.get("evidence_count", 1)),
							"day_offset": int(m.get("day_offset", 0)),
							"timestamp": str(m.get("timestamp", ""))
							,"retrieval_factor": _get_memory_retrieval_factor(m, layer, now_unix)
							,"emotion_factor": float(get_memory_emotion_modulation(m, layer, emotion_context).get("emotion_factor", 1.0))
						})
				
				scored_mems.sort_custom(func(a, b):
					if not is_equal_approx(float(a["score"]), float(b["score"])):
						return a["score"] > b["score"]
					if not is_equal_approx(float(a["retrieval_factor"]), float(b["retrieval_factor"])):
						return a["retrieval_factor"] > b["retrieval_factor"]
					if not is_equal_approx(float(a["confidence"]), float(b["confidence"])):
						return a["confidence"] > b["confidence"]
					return a["evidence_count"] > b["evidence_count"]
				)
				fallback_mems.sort_custom(func(a, b):
					var adjusted_a := float(a["retrieval_factor"]) * float(a["emotion_factor"])
					var adjusted_b := float(b["retrieval_factor"]) * float(b["emotion_factor"])
					if not is_equal_approx(adjusted_a, adjusted_b):
						return adjusted_a > adjusted_b
					if not is_equal_approx(float(a["confidence"]), float(b["confidence"])):
						return a["confidence"] > b["confidence"]
					if a["evidence_count"] != b["evidence_count"]:
						return a["evidence_count"] > b["evidence_count"]
					if a["day_offset"] != b["day_offset"]:
						return a["day_offset"] > b["day_offset"]
					return a["timestamp"] > b["timestamp"]
				)
				for candidate in scored_mems:
					var semantic_cluster_id := _get_active_habit_cluster_id(candidate["memory"], layer)
					if not semantic_cluster_id.is_empty() and rendered_cluster_ids.has(semantic_cluster_id):
						rejected.append(_build_retrieval_candidate(candidate["memory"], layer, "semantic", float(candidate["similarity"]), float(candidate["score"]), "cluster_member_collapsed", now_unix, emotion_context))
						continue
					if relevant_mems.size() >= layer_limit:
						rejected.append(_build_retrieval_candidate(candidate["memory"], layer, "semantic", float(candidate["similarity"]), float(candidate["score"]), "layer_limit", now_unix, emotion_context))
						continue
					relevant_mems.append(_get_memory_prompt_content(candidate["memory"], layer))
					selected.append(_build_retrieval_candidate(candidate["memory"], layer, "semantic", float(candidate["similarity"]), float(candidate["score"]), "selected", now_unix, emotion_context))
					if not semantic_cluster_id.is_empty():
						rendered_cluster_ids[semantic_cluster_id] = true
				for candidate in fallback_mems:
					var fallback_cluster_id := _get_active_habit_cluster_id(candidate["memory"], layer)
					if not fallback_cluster_id.is_empty() and rendered_cluster_ids.has(fallback_cluster_id):
						rejected.append(_build_retrieval_candidate(candidate["memory"], layer, "fallback", -1.0, -1.0, "cluster_member_collapsed", now_unix, emotion_context))
						continue
					if relevant_mems.size() >= layer_limit:
						rejected.append(_build_retrieval_candidate(candidate["memory"], layer, "fallback", -1.0, -1.0, "layer_limit", now_unix, emotion_context))
						continue
					relevant_mems.append(_get_memory_prompt_content(candidate["memory"], layer))
					selected.append(_build_retrieval_candidate(candidate["memory"], layer, "fallback", -1.0, -1.0, "selected", now_unix, emotion_context))
					if not fallback_cluster_id.is_empty():
						rendered_cluster_ids[fallback_cluster_id] = true
			else:
				var fallback_candidates: Array = []
				for memory_entry in memories[layer]:
					if should_surface_memory_in_player_channels(memory_entry, "prompt", false):
						fallback_candidates.append(memory_entry)
				fallback_candidates.sort_custom(func(a, b):
					var factor_a := _get_memory_retrieval_factor(a, layer, now_unix) * float(get_memory_emotion_modulation(a, layer, emotion_context).get("emotion_factor", 1.0))
					var factor_b := _get_memory_retrieval_factor(b, layer, now_unix) * float(get_memory_emotion_modulation(b, layer, emotion_context).get("emotion_factor", 1.0))
					if not is_equal_approx(factor_a, factor_b):
						return factor_a > factor_b
					return _is_memory_governance_higher(a, b)
				)
				for memory_entry in fallback_candidates:
					var governance_cluster_id := _get_active_habit_cluster_id(memory_entry, layer)
					if not governance_cluster_id.is_empty() and rendered_cluster_ids.has(governance_cluster_id):
						rejected.append(_build_retrieval_candidate(memory_entry, layer, "governance", -1.0, -1.0, "cluster_member_collapsed", now_unix, emotion_context))
						continue
					if relevant_mems.size() >= layer_limit:
						rejected.append(_build_retrieval_candidate(memory_entry, layer, "governance", -1.0, -1.0, "layer_limit", now_unix, emotion_context))
						continue
					relevant_mems.append(_get_memory_prompt_content(memory_entry, layer))
					selected.append(_build_retrieval_candidate(memory_entry, layer, "governance", -1.0, -1.0, "selected", now_unix, emotion_context))
					if not governance_cluster_id.is_empty():
						rendered_cluster_ids[governance_cluster_id] = true
				
			if relevant_mems.size() > 0:
				var layer_line: String = str(layers[layer]) + "；".join(relevant_mems)
				layer_truncated = layer_truncated or layer_line.length() > int(MEMORY_LAYER_CHAR_LIMITS[layer])
				prompt_lines.append(_truncate_memory_prompt(layer_line, int(MEMORY_LAYER_CHAR_LIMITS[layer])))
		
	var untruncated_prompt := "【玩家专属长记忆档案】\n" + "\n".join(prompt_lines) if not prompt_lines.is_empty() else ""
	var prompt := _truncate_memory_prompt(untruncated_prompt, MEMORY_PROMPT_MAX_CHARS)
	for candidate in selected:
		candidate["rendered"] = prompt.contains(str(candidate.get("content", "")))
	for candidate in rejected:
		candidate["rendered"] = false
	return {
		"prompt": prompt,
		"has_query": has_query,
		"query_dimension": query_embedding.size(),
		"selected": selected,
		"rejected": rejected,
		"prompt_chars": prompt.length(),
		"max_prompt_chars": MEMORY_PROMPT_MAX_CHARS,
		"truncated": layer_truncated or prompt.length() < untruncated_prompt.length()
	}

func get_last_memory_prompt_result() -> Dictionary:
	return last_memory_prompt_result.duplicate(true)

func _sanitize_memory_prompt_result(result: Dictionary) -> Dictionary:
	var sanitized := result.duplicate(true)
	for candidate in sanitized.get("selected", []):
		candidate.erase("memory")
	for candidate in sanitized.get("rejected", []):
		candidate.erase("memory")
	return sanitized

func _build_retrieval_candidate(memory: Dictionary, layer: String, selection_mode: String, similarity: float, score: float, reason: String, now_unix: float = -1.0, emotion_context: Dictionary = {}) -> Dictionary:
	var time_state := get_memory_time_relevance(memory, layer, now_unix)
	var emotion_state := get_memory_emotion_modulation(memory, layer, emotion_context)
	var exposure_state := get_memory_exposure_relevance(memory, layer, now_unix)
	return {
		"memory": memory,
		"memory_id": str(memory.get("id", "")),
		"layer": layer,
		"content": _get_memory_prompt_content(memory, layer),
		"source_content": str(memory.get("content", "")),
		"cluster_id": _get_active_habit_cluster_id(memory, layer),
		"cluster_member_memory_ids": _get_habit_cluster_member_ids(memory),
		"cluster_summary_version": int(memory.get("cluster_summary_version", 0)),
		"uses_cluster_summary": not _get_active_habit_cluster_id(memory, layer).is_empty(),
		"selection_mode": selection_mode,
		"similarity": similarity,
		"score": score,
		"confidence": float(memory.get("confidence", DEFAULT_MEMORY_CONFIDENCE)),
		"consolidation_status": get_memory_consolidation_status(memory),
		"age_seconds": float(time_state.get("age_seconds", 0.0)),
		"half_life_days": float(time_state.get("half_life_days", 0.0)),
		"time_relevance": float(time_state.get("time_relevance", 1.0)),
		"time_protected": bool(time_state.get("protected", false)),
		"exposure_factor": float(exposure_state.get("exposure_factor", 1.0)),
		"exposure_age_seconds": float(exposure_state.get("exposure_age_seconds", 0.0)),
		"exposure_penalty": float(exposure_state.get("exposure_penalty", 0.0)),
		"emotion_affinity": str(emotion_state.get("emotion_affinity", "neutral")),
		"emotion_factor": float(emotion_state.get("emotion_factor", 1.0)),
		"matched_mood_id": str(emotion_state.get("matched_mood_id", "")),
		"reason": reason,
		"rendered": false
	}

func _record_recalled_memories(recalled_memories: Array) -> void:
	if recalled_memories.is_empty():
		return
	var recalled_at := Time.get_datetime_string_from_system()
	var recorded_ids: Dictionary = {}
	for memory in recalled_memories:
		if not memory is Dictionary:
			continue
		var memory_id := str(memory.get("id", ""))
		if memory_id.is_empty() or recorded_ids.has(memory_id):
			continue
		var cluster_id := _get_active_habit_cluster_id(memory, "habit")
		var recalled_cluster_members: Array = [memory]
		if not cluster_id.is_empty():
			recalled_cluster_members = memories.get("habit", []).filter(func(candidate): return candidate is Dictionary and str(candidate.get("cluster_id", "")) == cluster_id and str(candidate.get("status", MEMORY_STATUS_ACTIVE)) == MEMORY_STATUS_ACTIVE)
		for recalled_memory in recalled_cluster_members:
			var recalled_id := str(recalled_memory.get("id", ""))
			if recalled_id.is_empty() or recorded_ids.has(recalled_id):
				continue
			recorded_ids[recalled_id] = true
			recalled_memory["recall_count"] = int(recalled_memory.get("recall_count", 0)) + 1
			recalled_memory["exposure_count"] = int(recalled_memory.get("exposure_count", 0)) + 1
			recalled_memory["last_recalled_at"] = recalled_at
	save_memory()

func _truncate_memory_prompt(prompt: String, max_chars: int) -> String:
	if prompt.length() <= max_chars:
		return prompt
	return prompt.left(max_chars - 1).strip_edges() + "…"

func _build_memory_layer_line(label: String, contents: Array[String], max_chars: int) -> String:
	return _truncate_memory_prompt(label + "；".join(contents), max_chars)

func _get_revisit_candidate_layers() -> Array:
	return ["bond", "emotion", "habit"]

func _looks_like_story_bound_memory(mem: Dictionary) -> bool:
	return str(mem.get("story_time", "")) != "" or str(mem.get("story_location_id", "")) != "" or int(mem.get("day_offset", 0)) > 0

func _is_memory_revisit_eligible(mem: Dictionary, trigger_context: Dictionary) -> bool:
	if mem.is_empty():
		return false
	
	var mem_id = str(mem.get("id", ""))
	var content = str(mem.get("content", "")).strip_edges()
	if mem_id == "" or content == "":
		return false
	
	var context_domain = str(trigger_context.get("context_domain", CONTEXT_DOMAIN_STORY))
	
	var decay = float(mem.get("decay", 0.0))
	if decay >= 80.0:
		return false
	var reference_unix := float(trigger_context.get("now_unix", Time.get_unix_time_from_system()))
	var suppressed_until := str(mem.get("revisit_suppressed_until", "")).strip_edges()
	if not suppressed_until.is_empty() and reference_unix < float(Time.get_unix_time_from_datetime_string(suppressed_until)):
		return false

	var mem_domain = str(mem.get("context_domain", CONTEXT_DOMAIN_UNKNOWN))
	if context_domain == CONTEXT_DOMAIN_STORY:
		if mem_domain == CONTEXT_DOMAIN_REALITY:
			return false
		var current_day = int(trigger_context.get("day_offset", GameDataManager.story_time_manager.current_day_offset if GameDataManager.story_time_manager else 0))
		var day_offset = int(mem.get("day_offset", current_day))
		if current_day - day_offset < 1:
			return false
		if current_day - int(mem.get("last_revisited_story_day", -9999)) < REVISIT_COOLDOWN_DAYS:
			return false
	elif context_domain == CONTEXT_DOMAIN_REALITY:
		if mem_domain == CONTEXT_DOMAIN_STORY:
			return false
		if mem_domain == CONTEXT_DOMAIN_UNKNOWN and _looks_like_story_bound_memory(mem):
			return false
		var last_revisited_at := str(mem.get("last_revisited_at", "")).strip_edges()
		if not last_revisited_at.is_empty():
			var last_revisited_unix := float(Time.get_unix_time_from_datetime_string(last_revisited_at))
			if reference_unix - last_revisited_unix < REVISIT_COOLDOWN_DAYS * SECONDS_PER_DAY:
				return false
	
	return true

func _calculate_revisit_weight(layer: String, mem: Dictionary, trigger_context: Dictionary) -> float:
	var weight = 100.0 - float(mem.get("decay", 0.0))
	if layer == "bond":
		weight += 50.0
	elif layer == "emotion":
		weight += 20.0
	
	var context_domain = str(trigger_context.get("context_domain", CONTEXT_DOMAIN_STORY))
	var mem_domain = str(mem.get("context_domain", CONTEXT_DOMAIN_UNKNOWN))
	if context_domain == CONTEXT_DOMAIN_STORY:
		if mem_domain == CONTEXT_DOMAIN_STORY:
			weight += 30.0
		if str(trigger_context.get("story_location_id", "")) != "" and str(mem.get("story_location_id", "")) == str(trigger_context.get("story_location_id", "")):
			weight += 40.0
		if str(trigger_context.get("story_weather", "")) != "" and str(mem.get("story_weather", "")) == str(trigger_context.get("story_weather", "")):
			weight += 20.0
		if str(trigger_context.get("story_period", "")) != "" and str(mem.get("story_period", "")) == str(trigger_context.get("story_period", "")):
			weight += 10.0
	else:
		if mem_domain == CONTEXT_DOMAIN_REALITY:
			weight += 30.0
		if str(trigger_context.get("real_weather", "")) != "" and str(mem.get("real_weather", "")) == str(trigger_context.get("real_weather", "")):
			weight += 20.0
		if str(trigger_context.get("real_period", "")) != "" and str(mem.get("real_period", "")) == str(trigger_context.get("real_period", "")):
			weight += 15.0
	
	return weight

func get_revisit_event_candidate(trigger_context: Dictionary = {}) -> Dictionary:
	var context_domain = str(trigger_context.get("context_domain", CONTEXT_DOMAIN_STORY))
	if context_domain == CONTEXT_DOMAIN_STORY:
		var current_day = int(trigger_context.get("day_offset", GameDataManager.story_time_manager.current_day_offset if GameDataManager.story_time_manager else 0))
		var last_day = int(revisit_state.get("last_story_revisit_day", -9999))
		if current_day - last_day < 1:
			return {}
	else:
		var current_real_date = str(trigger_context.get("real_date", _get_real_date_key()))
		if current_real_date == str(revisit_state.get("last_reality_revisit_date", "")):
			return {}
	
	var candidates: Array = []
	for layer in _get_revisit_candidate_layers():
		if not memories.has(layer):
			continue
		for mem in memories[layer]:
			if mem is Dictionary and should_surface_memory_in_player_channels(mem, "revisit", false) and _is_memory_revisit_eligible(mem, trigger_context):
				var weight = _calculate_revisit_weight(layer, mem, trigger_context)
				candidates.append({
					"layer": layer,
					"memory": mem,
					"weight": weight
				})
	
	if candidates.is_empty():
		return {}
	
	candidates.sort_custom(func(a, b): return a["weight"] > b["weight"])
	var selected = candidates[0]
	var mem_data: Dictionary = selected["memory"]
	return {
		"memory_id": str(mem_data.get("id", "")),
		"layer": selected["layer"],
		"content": str(mem_data.get("content", "")),
		"story_time": str(mem_data.get("story_time", "")),
		"day_offset": int(mem_data.get("day_offset", 0)),
		"context_domain": str(mem_data.get("context_domain", CONTEXT_DOMAIN_UNKNOWN)),
		"story_location_id": str(mem_data.get("story_location_id", "")),
		"story_weather": str(mem_data.get("story_weather", "")),
		"story_period": str(mem_data.get("story_period", "")),
		"real_period": str(mem_data.get("real_period", "")),
		"real_weather": str(mem_data.get("real_weather", "")),
		"trigger_context": trigger_context.duplicate(true)
	}

func mark_memory_revisited(memory_id: String, trigger_context: Dictionary = {}) -> String:
	if memory_id == "":
		return ""
	var revisit_event_id := "revisit-%s" % _generate_id()
	var revisited_ids = revisit_state.get("revisited_memory_ids", [])
	if not revisited_ids is Array:
		revisited_ids = []
	if not revisited_ids.has(memory_id):
		revisited_ids.append(memory_id)
	revisit_state["revisited_memory_ids"] = revisited_ids
	var context_domain = str(trigger_context.get("context_domain", CONTEXT_DOMAIN_STORY))
	var reference_unix := float(trigger_context.get("now_unix", Time.get_unix_time_from_system()))
	var revisited_at := Time.get_datetime_string_from_unix_time(int(reference_unix))
	for layer in _get_revisit_candidate_layers():
		for memory in memories.get(layer, []):
			if memory is Dictionary and str(memory.get("id", "")) == memory_id:
				memory["revisit_count"] = int(memory.get("revisit_count", 0)) + 1
				memory["last_revisit_event_id"] = revisit_event_id
				memory["last_revisit_outcome"] = REVISIT_OUTCOME_PRESENTED
				memory["last_revisit_outcome_at"] = revisited_at
				memory["last_revisited_at"] = revisited_at
				memory["last_recalled_at"] = revisited_at
				memory["recall_count"] = int(memory.get("recall_count", 0)) + 1
				memory["exposure_count"] = int(memory.get("exposure_count", 0)) + 1
				if context_domain == CONTEXT_DOMAIN_STORY:
					memory["last_revisited_story_day"] = int(trigger_context.get("day_offset", GameDataManager.story_time_manager.current_day_offset if GameDataManager.story_time_manager else 0))
				break
	if context_domain == CONTEXT_DOMAIN_STORY:
		revisit_state["last_story_revisit_memory_id"] = memory_id
		revisit_state["last_story_revisit_day"] = int(trigger_context.get("day_offset", GameDataManager.story_time_manager.current_day_offset if GameDataManager.story_time_manager else 0))
	else:
		revisit_state["last_reality_revisit_memory_id"] = memory_id
		revisit_state["last_reality_revisit_date"] = str(trigger_context.get("real_date", _get_real_date_key()))
	save_memory()
	return revisit_event_id

func record_revisit_feedback(layer: String, memory_id: String, revisit_event_id: String, outcome: String, options: Dictionary = {}) -> bool:
	var normalized_outcome := outcome.strip_edges().to_lower()
	if not REVISIT_OUTCOMES.has(normalized_outcome) or revisit_event_id.is_empty() or not memories.has(layer):
		return false
	for memory in memories[layer]:
		if not memory is Dictionary or str(memory.get("id", "")) != memory_id:
			continue
		if str(memory.get("last_revisit_event_id", "")) != revisit_event_id:
			return false
		var now_unix := float(options.get("now_unix", Time.get_unix_time_from_system()))
		var outcome_at := Time.get_datetime_string_from_unix_time(int(now_unix))
		if normalized_outcome == REVISIT_OUTCOME_CONFIRMED:
			if not confirm_memory(layer, memory_id, {
				"source_type": "revisit_confirmation",
				"source_id": revisit_event_id,
				"source_title": "主动重访确认"
			}):
				return false
			memory["successful_revisit_count"] = int(memory.get("successful_revisit_count", 0)) + 1
		elif normalized_outcome == REVISIT_OUTCOME_CORRECTED:
			var corrected_content := str(options.get("corrected_content", "")).strip_edges()
			if corrected_content.is_empty():
				return false
			memory["last_revisit_outcome"] = normalized_outcome
			memory["last_revisit_outcome_at"] = outcome_at
			var corrected := supersede_memory(layer, memory_id, corrected_content, {}, {
				"source_type": "revisit_correction",
				"source_id": revisit_event_id,
				"source_title": "主动重访纠正"
			}, "revisit_correction")
			if corrected and GameDataManager.memory_retrieval_trace_service:
				GameDataManager.memory_retrieval_trace_service.mark_revisit_outcome(revisit_event_id, normalized_outcome)
			return corrected
		elif normalized_outcome == REVISIT_OUTCOME_DISMISSED:
			var suppression_days := maxi(1, int(options.get("suppression_days", REVISIT_DISMISSAL_DAYS)))
			memory["revisit_suppressed_until"] = Time.get_datetime_string_from_unix_time(int(now_unix + suppression_days * SECONDS_PER_DAY))
		memory["last_revisit_outcome"] = normalized_outcome
		memory["last_revisit_outcome_at"] = outcome_at
		var saved := save_memory()
		if saved and GameDataManager.memory_retrieval_trace_service:
			GameDataManager.memory_retrieval_trace_service.mark_revisit_outcome(revisit_event_id, normalized_outcome)
		return saved
	return false

func _cosine_similarity(vec1: Array, vec2: Array) -> float:
	if vec1.size() != vec2.size() or vec1.size() == 0:
		return 0.0
		
	var dot_product = 0.0
	var norm1 = 0.0
	var norm2 = 0.0
	
	for i in range(vec1.size()):
		var v1 = float(vec1[i])
		var v2 = float(vec2[i])
		dot_product += v1 * v2
		norm1 += v1 * v1
		norm2 += v2 * v2
		
	if norm1 == 0.0 or norm2 == 0.0:
		return 0.0
		
	return dot_product / (sqrt(norm1) * sqrt(norm2))
