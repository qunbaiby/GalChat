class_name StoryMemoryManager
extends MemoryManager

const STORY_LAYER := "story"

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

func get_memory_prompt(_query_embedding: Array = []) -> String:
	return ""

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
	return item