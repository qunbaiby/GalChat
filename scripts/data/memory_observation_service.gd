class_name MemoryObservationService
extends Node

const CHANNEL_POLICIES := {
	"story_chat": {"enabled": true, "memory_domain": MemoryManager.MEMORY_DOMAIN_PLAYER, "context": "story"},
	"mobile_chat": {"enabled": true, "memory_domain": MemoryManager.MEMORY_DOMAIN_PLAYER, "context": "story"},
	"desktop_chat": {"enabled": true, "memory_domain": MemoryManager.MEMORY_DOMAIN_DESKTOP_PET, "context": "reality"},
	"desktop_pet": {"enabled": true, "memory_domain": MemoryManager.MEMORY_DOMAIN_DESKTOP_PET, "context": "reality"}
}


func observe_completed_turn(channel: String, player_text: String, ai_reply: String, options: Dictionary = {}) -> String:
	var policy: Dictionary = CHANNEL_POLICIES.get(channel, {})
	if policy.is_empty() or not bool(policy.get("enabled", false)):
		return ""
	var normalized_player_text := player_text.strip_edges()
	var normalized_ai_reply := ai_reply.strip_edges()
	if normalized_player_text.is_empty() or normalized_ai_reply.is_empty():
		return ""
	var memory_manager = _resolve_memory_manager(str(policy.get("memory_domain", "")))
	if memory_manager == null or not memory_manager.has_method("add_turn") or not memory_manager.add_turn():
		return ""
	var memory_context: Dictionary = options.get("memory_context", {}).duplicate(true) if options.get("memory_context", {}) is Dictionary else {}
	if memory_context.is_empty():
		memory_context = _build_memory_context(memory_manager, str(policy.get("context", "")))
	if GameDataManager.cognition_task_queue == null:
		return ""
	var task_id: String = GameDataManager.cognition_task_queue.enqueue("exchange", {
		"user_text": normalized_player_text,
		"ai_reply": normalized_ai_reply,
		"channel": channel
	}, str(policy.get("memory_domain", MemoryManager.MEMORY_DOMAIN_PLAYER)), memory_context)
	if task_id.is_empty() and memory_manager.has_method("rollback_last_observed_turn"):
		memory_manager.rollback_last_observed_turn()
	return task_id


func get_channel_policy(channel: String) -> Dictionary:
	return CHANNEL_POLICIES.get(channel, {}).duplicate(true)


func _resolve_memory_manager(memory_domain: String):
	if GameDataManager.cognition_task_queue:
		return GameDataManager.cognition_task_queue.resolve_memory_manager(memory_domain)
	return null


func _build_memory_context(memory_manager, context_type: String) -> Dictionary:
	if context_type == "story" and memory_manager.has_method("build_story_memory_context"):
		return memory_manager.build_story_memory_context()
	if context_type == "reality" and memory_manager.has_method("build_reality_memory_context"):
		return memory_manager.build_reality_memory_context()
	return {}