class_name MemoryManager
extends Node

const SafeFileAccess = preload("res://scripts/utils/safe_file_access.gd")
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

# 四级记忆分层架构，每层存储字典列表 [{"id": String, "content": String, "timestamp": String}]
var memories: Dictionary = {
	"core": [],     # 核心记忆层：用户姓名、禁忌、核心价值观、人生大事、不可逆选择
	"emotion": [],  # 情绪记忆层：用户的情绪触发点、雷区、情感偏好
	"habit": [],    # 习惯记忆层：用户作息、饮食喜好、兴趣、日常习惯
	"bond": []      # 羁绊记忆层：专属约定、共同经历、纪念日、一起完成的事
}

var turns_since_last_extract: int = 0
var revisit_state: Dictionary = _create_default_revisit_state()

func get_memory_file_path() -> String:
	var char_id = "default"
	if GameDataManager.config and GameDataManager.config.current_character_id != "":
		char_id = GameDataManager.config.current_character_id
	return GameDataManager.get_character_save_path("player_memory.json", char_id)

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

func _is_duplicate_memory_entry(mem: Dictionary, content: String, source_type: String = "", source_id: String = "") -> bool:
	if str(mem.get("content", "")).strip_edges() != content.strip_edges():
		return false

	var existing_source_type = str(mem.get("source_type", "")).strip_edges()
	var existing_source_id = str(mem.get("source_id", "")).strip_edges()
	var incoming_has_source = source_type != "" or source_id != ""
	var existing_has_source = existing_source_type != "" or existing_source_id != ""
	if incoming_has_source or existing_has_source:
		return existing_source_type == source_type and existing_source_id == source_id
	return true

func should_surface_memory_in_player_channels(mem: Dictionary, channel: String = "prompt", has_query: bool = false) -> bool:
	if mem.is_empty():
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
									"real_temp": 0.0
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

func save_memory() -> void:
	var data = memories.duplicate(true)
	data["_turns_since_last_extract"] = turns_since_last_extract
	data["_revisit_state"] = revisit_state.duplicate(true)
	var content = JSON.stringify(data, "\t")
	SafeFileAccess.store_string(get_memory_file_path(), content)

func _generate_id() -> String:
	return str(Time.get_unix_time_from_system() * 1000 + randi() % 1000)

func add_memory(layer: String, content: String, memory_context: Dictionary = {}) -> void:
	if memories.has(layer):
		# 防止重复内容添加
		for mem in memories[layer]:
			if _is_duplicate_memory_entry(mem, content):
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
			"real_temp": 0.0
		}
		_apply_memory_context(new_mem, memory_context)
		memories[layer].append(new_mem)
		save_memory()
		print("【记忆管理器】新增 %s 记忆: [%s] %s" % [layer, new_mem["id"], content])

func add_memory_quick(layer: String, content: String, memory_context: Dictionary = {}, memory_options: Dictionary = {}) -> void:
	if not memories.has(layer):
		return
	var final_content = content.strip_edges()
	if final_content == "":
		return
	var source_type = str(memory_options.get("source_type", "")).strip_edges()
	var source_id = str(memory_options.get("source_id", "")).strip_edges()
	for mem in memories[layer]:
		if _is_duplicate_memory_entry(mem, final_content, source_type, source_id):
			return

	var new_mem = {
		"id": _generate_id(),
		"content": final_content,
		"timestamp": Time.get_datetime_string_from_system(),
		"story_time": GameDataManager.story_time_manager.get_story_time_string() if GameDataManager.story_time_manager else "",
		"day_offset": GameDataManager.story_time_manager.current_day_offset if GameDataManager.story_time_manager else 0,
		"decay": 0.0,
		"is_bond_mark": bool(memory_options.get("is_bond_mark", false)),
		"embedding": [],
		"source_type": source_type,
		"source_id": source_id,
		"source_title": str(memory_options.get("source_title", "")),
		"memory_scope": normalize_memory_scope(str(memory_options.get("memory_scope", MEMORY_SCOPE_PLAYER_SHARED))),
		"memory_visibility": normalize_memory_visibility(str(memory_options.get("memory_visibility", "")), str(memory_options.get("memory_scope", MEMORY_SCOPE_PLAYER_SHARED))),
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
		"real_temp": 0.0
	}
	_apply_memory_context(new_mem, memory_context)
	memories[layer].append(new_mem)
	save_memory()
	print("【记忆管理器】快速新增 %s 记忆: [%s] %s" % [layer, new_mem["id"], final_content])

func update_memory(layer: String, id: String, new_content: String, memory_context: Dictionary = {}) -> bool:
	if memories.has(layer):
		for i in range(memories[layer].size()):
			if memories[layer][i]["id"] == id:
				memories[layer][i]["content"] = new_content
				memories[layer][i]["timestamp"] = Time.get_datetime_string_from_system()
				
				var embedding = await DoubaoEmbeddingClient.get_embedding(new_content)
				memories[layer][i]["embedding"] = embedding
				_apply_memory_context(memories[layer][i], memory_context)
				
				save_memory()
				print("【记忆管理器】更新 %s 记忆 [%s]: %s" % [layer, id, new_content])
				return true
	return false

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
	if memories.has(layer):
		for i in range(memories[layer].size()):
			if memories[layer][i]["id"] == id:
				var content = memories[layer][i]["content"]
				memories[layer].remove_at(i)
				save_memory()
				print("【记忆管理器】删除 %s 记忆 [%s]: %s" % [layer, id, content])
				return true
	return false

func add_turn() -> bool:
	turns_since_last_extract += 1
	save_memory()
	# 将原本的10回合触发一次，改为每3回合触发一次，或者根据需要调整为更频繁
	return turns_since_last_extract % 3 == 0

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
				if mem.get("is_bond_mark", false):
					continue # 有羁绊印记的不会衰退
				mem["decay"] = min(100.0, mem.get("decay", 0.0) + (days * 10.0)) # 每天增加 10%
				if mem["decay"] >= 100.0:
					to_remove.append(i)
				changed = true
			
			# 倒序删除以防索引错乱
			for i in range(to_remove.size() - 1, -1, -1):
				var idx = to_remove[i]
				print("【记忆管理器】遗忘记忆(因衰退): %s" % memories[layer][idx]["content"])
				memories[layer].remove_at(idx)
	
	if changed:
		save_memory()

func reinforce_memory(layer: String, id: String) -> void:
	if memories.has(layer):
		for mem in memories[layer]:
			if mem["id"] == id:
				mem["decay"] = max(0.0, mem.get("decay", 0.0) - 50.0) # 重新提及，衰退值减半
				save_memory()
				return

func get_memory_prompt(query_embedding: Array = []) -> String:
	var prompt_lines = []
	var has_query = query_embedding.size() > 0
	
	if memories["core"].size() > 0:
		var contents = []
		for m in memories["core"]:
			if m is Dictionary and should_surface_memory_in_player_channels(m, "prompt", has_query):
				contents.append(m["content"])
		if contents.size() > 0:
			prompt_lines.append("- 核心记忆（永不覆盖，严格遵守）：" + "；".join(contents))
		
	var layers = {
		"emotion": "- 情绪记忆（据此调整沟通方式）：",
		"habit": "- 习惯记忆（主动贴合用户日常）：",
		"bond": "- 羁绊记忆（专属情感锚点，可主动提起）："
	}
	
	for layer in layers.keys():
		if memories[layer].size() > 0:
			var relevant_mems = []
			
			if has_query:
				var scored_mems = []
				for m in memories[layer]:
					if not should_surface_memory_in_player_channels(m, "prompt", true):
						continue
					var emb = m.get("embedding", [])
					var score = 0.0
					if emb is Array and emb.size() > 0 and query_embedding.size() == emb.size():
						score = _cosine_similarity(query_embedding, emb)
					else:
						score = -1.0 # 没嵌入或维度不匹配时
					scored_mems.append({"content": m["content"], "score": score})
				
				# 按分数降序
				scored_mems.sort_custom(func(a, b): return a["score"] > b["score"])
				
				# 选取前3条相关记忆，阈值设为0.4（或无嵌入的直接包含）
				for i in range(min(3, scored_mems.size())):
					var score = scored_mems[i]["score"]
					if score >= 0.4 or score == -1.0:
						relevant_mems.append(scored_mems[i]["content"])
			else:
				for m in memories[layer]:
					if should_surface_memory_in_player_channels(m, "prompt", false):
						relevant_mems.append(m["content"])
				
			if relevant_mems.size() > 0:
				prompt_lines.append(layers[layer] + "；".join(relevant_mems))
		
	if prompt_lines.size() > 0:
		return "【玩家专属长记忆档案】\n" + "\n".join(prompt_lines)
	return ""

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
	var last_memory_key = "last_story_revisit_memory_id" if context_domain == CONTEXT_DOMAIN_STORY else "last_reality_revisit_memory_id"
	if mem_id == str(revisit_state.get(last_memory_key, "")):
		return false
	
	var revisited_ids = revisit_state.get("revisited_memory_ids", [])
	if revisited_ids is Array and revisited_ids.has(mem_id):
		return false
	
	var decay = float(mem.get("decay", 0.0))
	if decay >= 80.0:
		return false

	var mem_domain = str(mem.get("context_domain", CONTEXT_DOMAIN_UNKNOWN))
	if context_domain == CONTEXT_DOMAIN_STORY:
		if mem_domain == CONTEXT_DOMAIN_REALITY:
			return false
		var current_day = int(trigger_context.get("day_offset", GameDataManager.story_time_manager.current_day_offset if GameDataManager.story_time_manager else 0))
		var day_offset = int(mem.get("day_offset", current_day))
		if current_day - day_offset < 1:
			return false
	elif context_domain == CONTEXT_DOMAIN_REALITY:
		if mem_domain == CONTEXT_DOMAIN_STORY:
			return false
		if mem_domain == CONTEXT_DOMAIN_UNKNOWN and _looks_like_story_bound_memory(mem):
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

func mark_memory_revisited(memory_id: String, trigger_context: Dictionary = {}) -> void:
	if memory_id == "":
		return
	var revisited_ids = revisit_state.get("revisited_memory_ids", [])
	if not revisited_ids is Array:
		revisited_ids = []
	if not revisited_ids.has(memory_id):
		revisited_ids.append(memory_id)
	revisit_state["revisited_memory_ids"] = revisited_ids
	var context_domain = str(trigger_context.get("context_domain", CONTEXT_DOMAIN_STORY))
	if context_domain == CONTEXT_DOMAIN_STORY:
		revisit_state["last_story_revisit_memory_id"] = memory_id
		revisit_state["last_story_revisit_day"] = int(trigger_context.get("day_offset", GameDataManager.story_time_manager.current_day_offset if GameDataManager.story_time_manager else 0))
	else:
		revisit_state["last_reality_revisit_memory_id"] = memory_id
		revisit_state["last_reality_revisit_date"] = str(trigger_context.get("real_date", _get_real_date_key()))
	save_memory()

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
