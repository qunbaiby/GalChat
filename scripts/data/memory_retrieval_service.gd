class_name MemoryRetrievalService
extends Node


func build_chat_prompt(profile: CharacterProfile, player_message: String, memory_manager_override = null, summary_channel: String = "main_chat", prompt_access_context: Dictionary = {}) -> String:
	var result := await build_chat_prompt_result(profile, player_message, memory_manager_override, summary_channel, prompt_access_context)
	return str(result.get("prompt", ""))


func build_chat_prompt_result(profile: CharacterProfile, player_message: String, memory_manager_override = null, summary_channel: String = "main_chat", prompt_access_context: Dictionary = {}) -> Dictionary:
	return await build_system_prompt_result(profile, "default_chat", player_message, memory_manager_override, summary_channel, prompt_access_context)


func build_system_prompt(profile: CharacterProfile, template_name: String, player_message: String, memory_manager_override = null, summary_channel: String = "", prompt_access_context: Dictionary = {}) -> String:
	var result := await build_system_prompt_result(profile, template_name, player_message, memory_manager_override, summary_channel, prompt_access_context)
	return str(result.get("prompt", ""))


func build_system_prompt_result(profile: CharacterProfile, template_name: String, player_message: String, memory_manager_override = null, summary_channel: String = "", prompt_access_context: Dictionary = {}) -> Dictionary:
	var request_id := "%d-%d" % [int(Time.get_unix_time_from_system()), Time.get_ticks_usec()]
	var query_embedding: Array = await get_query_embedding(player_message)
	var prompt: String = GameDataManager.prompt_manager.build_system_prompt(
		profile,
		template_name,
		player_message,
		query_embedding,
		memory_manager_override,
		summary_channel,
		prompt_access_context
	)
	var memory_manager = memory_manager_override if memory_manager_override != null else GameDataManager.memory_manager
	if memory_manager and memory_manager.has_method("get_last_memory_prompt_result") and GameDataManager.memory_retrieval_trace_service:
		var retrieval_result: Dictionary = memory_manager.get_last_memory_prompt_result()
		if GameDataManager.prompt_manager.has_method("get_last_long_term_context_result"):
			var context_result: Dictionary = GameDataManager.prompt_manager.get_last_long_term_context_result()
			var story_result: Dictionary = context_result.get("story_knowledge_result", {}) if context_result.get("story_knowledge_result", {}) is Dictionary else {}
			retrieval_result["selected"].append_array(story_result.get("selected", []))
			retrieval_result["rejected"].append_array(story_result.get("rejected", []))
			retrieval_result["access_subject_id"] = str(story_result.get("access_subject_id", ""))
			var final_context := str(context_result.get("context", ""))
			for candidate in retrieval_result.get("selected", []):
				candidate["rendered"] = final_context.contains(str(candidate.get("content", "")))
			retrieval_result["memory_prompt_chars"] = int(retrieval_result.get("prompt_chars", 0))
			retrieval_result["prompt_chars"] = int(context_result.get("final_chars", 0))
			retrieval_result["max_prompt_chars"] = int(context_result.get("max_chars", 0))
			retrieval_result["diary_chars"] = int(context_result.get("diary_chars", 0))
			retrieval_result["summary_chars"] = int(context_result.get("summary_chars", 0))
			retrieval_result["story_knowledge_chars"] = int(context_result.get("story_knowledge_chars", 0))
			retrieval_result["emotion_context"] = context_result.get("emotion_context", {}).duplicate(true) if context_result.get("emotion_context", {}) is Dictionary else {}
			retrieval_result["truncated"] = bool(retrieval_result.get("truncated", false)) or bool(context_result.get("truncated", false))
		var trace: Dictionary = GameDataManager.memory_retrieval_trace_service.record_trace(
			player_message,
			template_name,
			summary_channel,
			retrieval_result,
			request_id,
			prompt_access_context
		)
		return {
			"prompt": prompt,
			"request_id": request_id,
			"trace_id": str(trace.get("id", "")),
			"rendered_memory_ids": trace.get("rendered_memory_ids", []).duplicate()
		}
	return {"prompt": prompt, "request_id": request_id, "trace_id": "", "rendered_memory_ids": []}


func get_query_embedding(query_text: String) -> Array:
	var normalized_query := query_text.strip_edges()
	if normalized_query.is_empty() or GameDataManager.config == null or not GameDataManager.config.embedding_enabled:
		return []
	return await DoubaoEmbeddingClient.get_embedding(normalized_query)


func request_memory_embedding(memory_manager, layer: String, memory_id: String, content: String) -> void:
	if memory_manager == null or memory_id.is_empty() or content.strip_edges().is_empty():
		return
	if GameDataManager.config == null or not GameDataManager.config.embedding_enabled:
		memory_manager.set_memory_embedding_state(layer, memory_id, [], "disabled")
		return
	var embedding: Array = await DoubaoEmbeddingClient.get_embedding(content)
	var status := "ready" if not embedding.is_empty() else "failed"
	memory_manager.set_memory_embedding_state(layer, memory_id, embedding, status)