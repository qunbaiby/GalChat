extends Node

# EventManager - 全局事件库
# 统一管理项目中的各种触发事件

signal event_triggered(event_id: String, params: Dictionary)

const EVENT_REGISTRY_PATH = "res://assets/data/events/event_registry.json"

var event_registry: Array = []
var triggered_events: Array = [] # 记录已触发过的事件ID

func _ready() -> void:
	_load_event_registry()
	_load_triggered_events()

func get_triggered_events_save_path() -> String:
	var char_id = "default"
	if GameDataManager.config and GameDataManager.config.current_character_id != "":
		char_id = GameDataManager.config.current_character_id
	return GameDataManager.get_character_save_path("triggered_events.json", char_id)

func _load_event_registry() -> void:
	if FileAccess.file_exists(EVENT_REGISTRY_PATH):
		var file = FileAccess.open(EVENT_REGISTRY_PATH, FileAccess.READ)
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			var data = json.get_data()
			if data.has("events"):
				event_registry = data["events"]
		file.close()

func _load_triggered_events() -> void:
	triggered_events.clear()
	var save_path = get_triggered_events_save_path()
	if FileAccess.file_exists(save_path):
		var file = FileAccess.open(save_path, FileAccess.READ)
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK and json.get_data() is Array:
			triggered_events = json.get_data()
		file.close()

func _save_triggered_events() -> void:
	var SafeFileAccess = preload("res://scripts/utils/safe_file_access.gd")
	SafeFileAccess.store_string(get_triggered_events_save_path(), JSON.stringify(triggered_events))

func reload_for_current_character() -> void:
	_load_triggered_events()

func _extract_location_id_from_conditions(conditions: Array) -> String:
	for raw_condition in conditions:
		if not (raw_condition is Dictionary):
			continue
		var condition: Dictionary = raw_condition
		if str(condition.get("type", "")).strip_edges() == "location":
			return str(condition.get("value", "")).strip_edges()
	return ""

func _resolve_event_trigger_id(event_data: Dictionary) -> String:
	var event_id := str(event_data.get("event_id", "")).strip_edges()
	if event_id != "":
		return event_id
	var script_path := str(event_data.get("trigger_script", "")).strip_edges()
	if script_path != "":
		return script_path.get_file().get_basename()
	return ""

func is_event_triggered(event_id: String) -> bool:
	return triggered_events.has(event_id)

func mark_event_triggered(event_id: String) -> void:
	var normalized_event_id := str(event_id).strip_edges()
	if normalized_event_id == "":
		return
	if triggered_events.has(normalized_event_id):
		return
	triggered_events.append(normalized_event_id)
	_save_triggered_events()

func unmark_event_triggered(event_id: String) -> void:
	var normalized_event_id := str(event_id).strip_edges()
	if normalized_event_id == "":
		return
	if not triggered_events.has(normalized_event_id):
		return
	triggered_events.erase(normalized_event_id)
	_save_triggered_events()

func clear_triggered_events() -> void:
	if triggered_events.is_empty():
		return
	triggered_events.clear()
	_save_triggered_events()

func try_mark_event_by_story(script_id: String) -> void:
	var normalized_script_id := str(script_id).strip_edges()
	if normalized_script_id == "":
		return

	for raw_event in event_registry:
		if not (raw_event is Dictionary):
			continue
		var event_data: Dictionary = raw_event
		var event_id := str(event_data.get("event_id", "")).strip_edges()
		var script_path := str(event_data.get("trigger_script", "")).strip_edges()
		var script_basename := script_path.get_file().get_basename() if script_path != "" else ""
		if event_id == normalized_script_id or script_basename == normalized_script_id:
			var conditions = event_data.get("conditions", [])
			if str(event_data.get("event_type", "")).strip_edges() == "auto_trigger" and _extract_location_id_from_conditions(conditions) != "":
				return
			mark_event_triggered(event_id)
			return

# 广播状态变更，尝试匹配全局事件
func broadcast_state_change(context: Dictionary = {}) -> void:
	var matched_event := find_matching_auto_trigger_event(context)
	if not matched_event.is_empty():
		_trigger_registry_event(matched_event, context)
		return # 一次只触发一个事件，避免冲突

func find_matching_auto_trigger_event(context: Dictionary = {}) -> Dictionary:
	var ConditionManager = preload("res://scripts/data/condition_manager.gd")
	
	for raw_event in event_registry:
		if not (raw_event is Dictionary):
			continue
		var event_data: Dictionary = raw_event
		var event_id := str(event_data.get("event_id", "")).strip_edges()
		var event_type := str(event_data.get("event_type", "")).strip_edges()
		if event_type != "auto_trigger":
			continue
		var conditions = event_data.get("conditions", [])
		var matched_location_id := _extract_location_id_from_conditions(conditions)
		var is_location_entry_event := matched_location_id != ""
		
		# 地点进入类事件按天判重；其他事件沿用原先的永久判重。
		if is_location_entry_event and context.has("location_id"):
			if MapDataManager and MapDataManager.has_method("has_consumed_entry_trigger_today"):
				var event_trigger_id := _resolve_event_trigger_id(event_data)
				if event_trigger_id != "" and MapDataManager.has_consumed_entry_trigger_today("location_auto_event", event_trigger_id, matched_location_id):
					continue
		elif not bool(event_data.get("is_repeatable", false)) and event_id in triggered_events:
			continue
		
		var eval_result = ConditionManager.evaluate_conditions(conditions)
		
		# 如果是 location 条件，我们要确保 context 里传过来的 location 是一致的
		if context.has("location_id"):
			var has_loc_cond = false
			var loc_match = false
			for c in conditions:
				if c.get("type", "") == "location":
					has_loc_cond = true
					if c.get("value", "") == context["location_id"]:
						loc_match = true
			if not has_loc_cond or not loc_match:
				continue
		
		if bool(eval_result.get("passed", false)):
			return event_data
	
	return {}

func _trigger_registry_event(event_data: Dictionary, context: Dictionary = {}) -> void:
	var event_id = event_data.get("event_id", "")
	print("[EventManager] 全局事件满足触发条件: ", event_id)
	
	var script_path = event_data.get("trigger_script", "")
	if script_path != "" and ResourceLoader.exists(script_path):
		var debug_bridge := get_node_or_null("/root/StoryRuntimeDebugBridge")
		if debug_bridge != null:
			debug_bridge.prepare_story("event_registry", str(event_id), str(script_path), {
				"context": context.duplicate(true),
				"conditions": (event_data.get("conditions", []) as Array).duplicate(true),
				"event_type": str(event_data.get("event_type", ""))
			})
		var matched_location_id := _extract_location_id_from_conditions(event_data.get("conditions", []))
		var effective_location_id := str(context.get("location_id", matched_location_id)).strip_edges()
		if effective_location_id != "":
			GameDataManager.set_meta("pending_map_entry_trigger_completion", {
				"source_type": "location_auto_event",
				"source_id": _resolve_event_trigger_id(event_data),
				"location_id": effective_location_id
			})
		GameDataManager.set_meta("play_specific_story", script_path)
		var SceneTransitionManager = get_node_or_null("/root/SceneTransitionManager")
		if SceneTransitionManager:
			SceneTransitionManager.transition_to_scene("res://scenes/ui/story/story_scene.tscn")
	
	event_triggered.emit(event_id, event_data)

func execute_event(event_id: String, params: Dictionary = {}) -> void:
	print("[EventManager] 触发事件: ", event_id, " | 参数: ", params)
	
	match event_id:
		"proactive_greeting":
			_handle_proactive_greeting()
		"farewell":
			_handle_farewell()
		"show_interact_group":
			_handle_show_interact_group(params.get("visible", true))
		"toggle_interact_button":
			_handle_toggle_interact_button(params.get("button_name", ""), params.get("visible", true))
		"write_diary":
			_handle_write_diary()
		"post_moment":
			_handle_post_moment()
		"start_guide":
			_handle_start_guide(params)
		"start_demo_guide":
			_handle_start_demo_guide()
		"unlock_main_feature":
			_handle_set_main_feature_unlock(params, true)
		"lock_main_feature":
			_handle_set_main_feature_unlock(params, false)
		"set_main_feature_unlock":
			_handle_set_main_feature_unlock(params, bool(params.get("unlocked", true)))
		"memory_revisit":
			_handle_memory_revisit(params)
		_:
			print("[EventManager] 未知事件 ID: ", event_id)
			
	event_triggered.emit(event_id, params)

func _handle_proactive_greeting() -> void:
	var main_scene = get_tree().root.get_node_or_null("MainScene")
	if not main_scene:
		return
		
	var story_time_manager = GameDataManager.story_time_manager
	if not story_time_manager:
		print("[EventManager] 找不到 story_time_manager，无法判断时间")
		return
		
	var date_dict = story_time_manager.get_current_date_dict()
	var weekday = date_dict.weekday # 0=周日, 1=周一, ..., 6=周六
	
	var prompt_type = ""
	if weekday == 1: # 星期一
		prompt_type = "course"
	elif weekday == 0 or weekday == 6: # 星期六、日
		prompt_type = "daily"
	else:
		print("[EventManager] 当前星期(", weekday, ")不满足主动问候触发条件。")
		return
		
	if main_scene.has_method("start_proactive_greeting"):
		main_scene.start_proactive_greeting(prompt_type)

func _handle_farewell() -> void:
	var main_scene = get_tree().root.get_node_or_null("MainScene")
	if main_scene and main_scene.has_method("start_farewell"):
		main_scene.start_farewell()

func _handle_show_interact_group(is_visible: bool) -> void:
	var main_scene = get_tree().root.get_node_or_null("MainScene")
	if main_scene and main_scene.has_node("UIPanel/InteractGroup"):
		main_scene.get_node("UIPanel/InteractGroup").visible = is_visible

func _handle_toggle_interact_button(btn_name: String, is_visible: bool) -> void:
	if btn_name == "": return
	var main_scene = get_tree().root.get_node_or_null("MainScene")
	if main_scene and main_scene.has_node("UIPanel/InteractGroup/" + btn_name):
		main_scene.get_node("UIPanel/InteractGroup/" + btn_name).visible = is_visible

func _handle_write_diary() -> void:
	var client = DeepSeekClientLocator.find(self)
	if client and client.has_method("send_diary_generation"):
		client.send_diary_generation()
		print("[EventManager] 已触发日记生成事件。")
	elif client:
		print("[EventManager] DeepSeekClient 缺少 send_diary_generation 方法。")
	else:
		print("[EventManager] 未找到 DeepSeekClient，无法触发日记生成。")

func _handle_post_moment() -> void:
	var client = DeepSeekClientLocator.find(self)
	if client and client.has_method("send_moment_generation"):
		# 随机抽取一个角色发送朋友圈
		var target_profile = _get_random_character_profile()
		client.send_moment_generation(target_profile)
		print("[EventManager] 已触发朋友圈生成事件。")
	else:
		print("[EventManager] 未找到有效的 DeepSeekClient 或缺少 send_moment_generation 方法，无法触发朋友圈生成。")

func _handle_memory_revisit(params: Dictionary) -> void:
	var main_scene = get_tree().root.get_node_or_null("MainScene")
	if main_scene and main_scene.has_method("start_memory_revisit"):
		main_scene.start_memory_revisit(params)

func _handle_start_demo_guide() -> void:
	var guide_manager = get_node_or_null("/root/GuideManager")
	if guide_manager and guide_manager.has_method("start_demo_guide"):
		guide_manager.start_demo_guide()

func _handle_start_guide(params: Dictionary) -> void:
	var guide_id := str(params.get("guide_id", "")).strip_edges()
	if guide_id == "":
		return
	var guide_manager = get_node_or_null("/root/GuideManager")
	if guide_manager and guide_manager.has_method("start_guide"):
		guide_manager.start_guide(guide_id)

func _handle_set_main_feature_unlock(params: Dictionary, unlocked: bool) -> void:
	var guide_manager = get_node_or_null("/root/GuideManager")
	if guide_manager == null or not guide_manager.has_method("set_feature_unlocks"):
		return
	var updates: Dictionary = {}
	var feature_id := str(params.get("feature_id", "")).strip_edges()
	if feature_id != "":
		updates[feature_id] = unlocked
	var raw_feature_ids: Variant = params.get("feature_ids", [])
	if raw_feature_ids is Array:
		for raw_id in raw_feature_ids:
			var normalized_id := str(raw_id).strip_edges()
			if normalized_id != "":
				updates[normalized_id] = unlocked
	if updates.is_empty():
		return
	guide_manager.set_feature_unlocks(updates)
	print("[EventManager] 主场景功能%s: %s" % ["解锁" if unlocked else "锁定", updates.keys()])

func _get_random_character_profile() -> CharacterProfile:
	var char_ids = ["luna", "jing", "ya", "ling", "aili"]
	var random_id = char_ids[randi() % char_ids.size()]
	
	var new_profile = CharacterProfile.new()
	new_profile.load_profile(random_id)
	return new_profile
