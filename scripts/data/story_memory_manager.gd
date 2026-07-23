class_name StoryMemoryManager
extends MemoryManager

const STORY_LAYER := "story"
const STORY_KNOWLEDGE_MAX_COUNT := 6
const STORY_KNOWLEDGE_MAX_CHARS := 1200

func get_memory_file_path() -> String:
	var char_id = "default"
	if GameDataManager.config and GameDataManager.config.current_character_id != "":
		char_id = GameDataManager.config.current_character_id
	return GameDataManager.get_character_save_path("story_memory.json", char_id)

func get_memory_domain() -> String:
	return MEMORY_DOMAIN_STORY

func get_default_memory_scope() -> String:
	return MEMORY_SCOPE_WORLD_FACT

func get_default_memory_visibility() -> String:
	return MEMORY_VISIBILITY_ARCHIVE_ONLY

func accepts_memory_entry(layer: String, content: String, memory_context: Dictionary = {}, memory_options: Dictionary = {}) -> bool:
	return layer.strip_edges().to_lower() == STORY_LAYER and content.strip_edges() != ""

func load_memory() -> void:
	memories = {STORY_LAYER: []}
	turns_since_last_extract = 0
	revisit_state = _create_default_revisit_state()

	var path = get_memory_file_path()
	if not FileAccess.file_exists(path):
		return

	var file = FileAccess.open(path, FileAccess.READ)
	var content = file.get_as_text()
	file.close()

	var json = JSON.new()
	if json.parse(content) != OK or not json.data is Dictionary:
		return

	var data: Dictionary = json.data
	var story_items = data.get(STORY_LAYER, data.get("items", []))
	if story_items is Array:
		for item in story_items:
			if item is Dictionary and str(item.get("content", "")).strip_edges() != "":
				memories[STORY_LAYER].append(_normalize_story_memory_item(item))
			elif item is String and str(item).strip_edges() != "":
				memories[STORY_LAYER].append(_normalize_story_memory_item({"content": str(item)}))

func add_story_memory(content: String, memory_context: Dictionary = {}, memory_options: Dictionary = {}) -> void:
	var final_content = content.strip_edges()
	if final_content == "":
		return
	add_memory_quick(STORY_LAYER, final_content, memory_context, memory_options)

func get_story_memories() -> Array:
	return memories.get(STORY_LAYER, [])

func get_memory_prompt(_query_embedding: Array = [], _query_options: Dictionary = {}) -> String:
	return ""

func build_story_knowledge_prompt_result(access_context: Dictionary = {}) -> Dictionary:
	var selected: Array = []
	var rejected: Array = []
	var lines: Array[String] = []
	var channel := str(access_context.get("channel", ""))
	var allow_story_knowledge := bool(access_context.get("allow_story_knowledge", false))
	var character_id := str(access_context.get("character_id", "")).strip_edges().to_lower()
	var finished_story_ids: Array = access_context.get("finished_story_ids", []) if access_context.get("finished_story_ids", []) is Array else []
	for raw_memory in get_story_memories():
		if not raw_memory is Dictionary:
			continue
		var memory: Dictionary = raw_memory
		var reason := _get_story_knowledge_rejection_reason(memory, channel, allow_story_knowledge, character_id, finished_story_ids)
		var candidate := _build_story_knowledge_candidate(memory, reason)
		if not reason.is_empty():
			rejected.append(candidate)
			continue
		if selected.size() >= STORY_KNOWLEDGE_MAX_COUNT:
			candidate["reason"] = "budget_limit"
			rejected.append(candidate)
			continue
		candidate["reason"] = "authorized_story_knowledge"
		candidate["rendered"] = true
		selected.append(candidate)
		lines.append("- %s" % str(memory.get("content", "")))
	var prompt := "【当前角色已知且玩家可见的故事事实】\n" + "\n".join(lines) if not lines.is_empty() else ""
	prompt = _truncate_memory_prompt(prompt, STORY_KNOWLEDGE_MAX_CHARS)
	for candidate in selected:
		candidate["rendered"] = prompt.contains(str(candidate.get("content", "")))
	return {
		"prompt": prompt,
		"selected": selected,
		"rejected": rejected,
		"prompt_chars": prompt.length(),
		"max_prompt_chars": STORY_KNOWLEDGE_MAX_CHARS,
		"truncated": selected.any(func(candidate): return not bool(candidate.get("rendered", false))),
		"access_subject_id": character_id
	}

func _get_story_knowledge_rejection_reason(memory: Dictionary, channel: String, allow_story_knowledge: bool, character_id: String, finished_story_ids: Array) -> String:
	if channel != "story_chat" or not allow_story_knowledge:
		return "channel_not_story_chat"
	if str(memory.get("status", MEMORY_STATUS_ACTIVE)) != MEMORY_STATUS_ACTIVE:
		return "inactive_status"
	if character_id.is_empty():
		return "missing_character_id"
	var participants: Array = memory.get("memory_participants", []) if memory.get("memory_participants", []) is Array else []
	var normalized_participants: Array[String] = []
	for participant in participants:
		var normalized := str(participant).strip_edges().to_lower()
		if not normalized.is_empty() and not normalized_participants.has(normalized):
			normalized_participants.append(normalized)
	if normalized_participants.is_empty():
		return "legacy_acl_unknown"
	if not normalized_participants.has(character_id):
		return "character_not_authorized"
	if not bool(memory.get("memory_player_involved", false)) and not bool(memory.get("memory_player_witnessed", false)):
		return "player_not_authorized"
	var source_id := str(memory.get("source_id", "")).strip_edges()
	if source_id.is_empty() or not finished_story_ids.has(source_id):
		return "source_not_completed"
	return ""

func _build_story_knowledge_candidate(memory: Dictionary, reason: String) -> Dictionary:
	return {
		"memory": memory,
		"memory_id": str(memory.get("id", "")),
		"memory_domain": MEMORY_DOMAIN_STORY,
		"layer": STORY_LAYER,
		"content": str(memory.get("content", "")),
		"source_id": str(memory.get("source_id", "")),
		"scope": str(memory.get("memory_scope", MEMORY_SCOPE_WORLD_FACT)),
		"visibility": str(memory.get("memory_visibility", MEMORY_VISIBILITY_ARCHIVE_ONLY)),
		"selection_mode": "story_acl",
		"similarity": -1.0,
		"score": -1.0,
		"confidence": float(memory.get("confidence", DEFAULT_MEMORY_CONFIDENCE)),
		"reason": reason,
		"rendered": false
	}

func get_story_archive_prompt(max_count: int = 8) -> String:
	var items: Array = get_story_memories()
	if items.is_empty():
		return ""
	var lines: Array[String] = []
	var start_index = max(0, items.size() - max_count)
	for index in range(start_index, items.size()):
		var item = items[index]
		if not item is Dictionary:
			continue
		var content := str(item.get("content", "")).strip_edges()
		if content == "":
			continue
		var title := str(item.get("source_title", item.get("source_id", "固定剧情"))).strip_edges()
		lines.append("- %s：%s" % [title if title != "" else "固定剧情", content])
	if lines.is_empty():
		return ""
	return "【故事记忆归档】\n" + "\n".join(lines)

func _normalize_story_memory_item(item: Dictionary) -> Dictionary:
	if not item.has("id"):
		item["id"] = _generate_id()
	if not item.has("timestamp"):
		item["timestamp"] = Time.get_datetime_string_from_system()
	if not item.has("story_time"):
		item["story_time"] = ""
	if not item.has("day_offset"):
		item["day_offset"] = 0
	if not item.has("decay"):
		item["decay"] = 0.0
	if not item.has("is_bond_mark"):
		item["is_bond_mark"] = false
	if not item.has("source_type"):
		item["source_type"] = "story_script"
	if not item.has("source_id"):
		item["source_id"] = ""
	if not item.has("source_title"):
		item["source_title"] = ""
	if not item.has("memory_scope"):
		item["memory_scope"] = MEMORY_SCOPE_WORLD_FACT
	if not item.has("memory_visibility"):
		item["memory_visibility"] = MEMORY_VISIBILITY_ARCHIVE_ONLY
	if not item.has("memory_participants"):
		item["memory_participants"] = []
	if not item.has("memory_player_involved"):
		item["memory_player_involved"] = false
	if not item.has("memory_player_witnessed"):
		item["memory_player_witnessed"] = false
	if not item.has("context_domain"):
		item["context_domain"] = CONTEXT_DOMAIN_STORY
	if not item.has("context_time_type"):
		item["context_time_type"] = "story"
	if not item.has("status"):
		item["status"] = MEMORY_STATUS_ACTIVE
	if not item.has("deleted_at"):
		item["deleted_at"] = ""
	if not item.has("superseded_at"):
		item["superseded_at"] = ""
	if not item.has("superseded_by"):
		item["superseded_by"] = ""
	if not item.has("supersedes"):
		item["supersedes"] = []
	return item