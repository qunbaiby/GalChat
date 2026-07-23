extends Node

const SafeFileAccessUtil = preload("res://scripts/utils/safe_file_access.gd")

var config: ConfigResource
var profile: CharacterProfile # character profile
var history: ChatHistoryManager
var npc_relationship_manager: NPCRelationshipManager
var prompt_manager: Node
var audit_logger: Node
var persona_lock: Node
var mood_system: Node
var expression_system: Node
var memory_manager: MemoryManager
var desktop_pet_memory_manager: MemoryManager
var story_memory_manager: MemoryManager
var memory_retrieval_service: Node
var memory_retrieval_trace_service
var cognition_task_queue
var conversation_summary_manager
var player_emotion_state_manager
var personality_system: Node
var stats_system: Node
var activity_manager: Node
var gift_manager: Node
var story_time_manager: Node
var interaction_manager: Node
var save_manager: Node
var weather_manager: Node
var app_database: Dictionary = {}
const ACCOUNT_DATA_ROOT_DIR := "user://accounts"
const ARCHIVE_SETTINGS_FILE_NAME := "settings.json"
const ARCHIVE_CUSTOM_STATE_FILE_NAME := "custom_state.json"
const ACTIVE_STORY_STATE_FILE_NAME := "active_story_state.json"
const ARCHIVE_SCHEMA_VERSION := 1

# 番茄钟与待办事项数据
var pomodoro_data: Dictionary = {
	"work_duration": 25,
	"break_duration": 5,
	"total_focus_time": 0,
	"todos": []
}

signal character_switched(char_id: String)
signal archive_will_change(old_archive_id: String, new_archive_id: String)
signal archive_changed(archive_id: String)

# 用于记录上一个场景的路径，以便设置界面返回时知道该回到哪里
var previous_scene_path: String = ""

func _ready() -> void:
	# 禁用自动退出机制，以便在关闭主窗口时可以保持桌宠运行
	get_tree().set_auto_accept_quit(false)
	
	# 注：由于 `window/size/transparent=true`，不要随便修改根窗口的穿透区域，
	# 否则会导致作为唯一非透明层的主场景也跟着被底层系统丢弃渲染（变成全透明黑屏）。
	# 如果想要真正的透明点击穿透功能，请取消 project.godot 里的 transparent=true
	# 或者使用外部 C# P/Invoke 调用系统 API 修改窗口扩展样式 (WS_EX_TRANSPARENT)。
	# 目前恢复为引擎默认机制。
	
	audit_logger = preload("res://scripts/data/audit_logger.gd").new()
	add_child(audit_logger)
	
	persona_lock = preload("res://scripts/data/persona_lock_manager.gd").new()
	add_child(persona_lock)
	
	mood_system = preload("res://scripts/data/mood_system.gd").new()
	add_child(mood_system)
	
	expression_system = preload("res://scripts/data/expression_system.gd").new()
	add_child(expression_system)
	
	memory_manager = preload("res://scripts/data/memory_manager.gd").new()
	memory_manager.name = "MemoryManager"
	add_child(memory_manager)

	desktop_pet_memory_manager = preload("res://scripts/data/desktop_pet_memory_manager.gd").new()
	desktop_pet_memory_manager.name = "DesktopPetMemoryManager"
	add_child(desktop_pet_memory_manager)

	story_memory_manager = preload("res://scripts/data/story_memory_manager.gd").new()
	story_memory_manager.name = "StoryMemoryManager"
	add_child(story_memory_manager)

	memory_retrieval_service = preload("res://scripts/data/memory_retrieval_service.gd").new()
	memory_retrieval_service.name = "MemoryRetrievalService"
	add_child(memory_retrieval_service)

	memory_retrieval_trace_service = preload("res://scripts/data/memory_retrieval_trace_service.gd").new()
	memory_retrieval_trace_service.name = "MemoryRetrievalTraceService"
	add_child(memory_retrieval_trace_service)

	cognition_task_queue = preload("res://scripts/data/cognition_task_queue.gd").new()
	cognition_task_queue.name = "CognitionTaskQueue"
	add_child(cognition_task_queue)

	conversation_summary_manager = preload("res://scripts/data/conversation_summary_manager.gd").new()
	conversation_summary_manager.name = "ConversationSummaryManager"
	add_child(conversation_summary_manager)

	player_emotion_state_manager = preload("res://scripts/data/player_emotion_state_manager.gd").new()
	player_emotion_state_manager.name = "PlayerEmotionStateManager"
	add_child(player_emotion_state_manager)
	
	personality_system = preload("res://scripts/data/personality_system.gd").new()
	add_child(personality_system)
	
	stats_system = preload("res://scripts/data/stats_system.gd").new()
	add_child(stats_system)
	
	activity_manager = preload("res://scripts/data/activity_manager.gd").new()
	add_child(activity_manager)
	
	gift_manager = preload("res://scripts/data/gift_manager.gd").new()
	add_child(gift_manager)
	
	story_time_manager = preload("res://scripts/data/story_time_manager.gd").new()
	add_child(story_time_manager)
	
	interaction_manager = preload("res://scripts/data/interaction_manager.gd").new()
	add_child(interaction_manager)
	
	save_manager = preload("res://scripts/data/save_manager.gd").new()
	add_child(save_manager)

	weather_manager = preload("res://scripts/data/weather_manager.gd").new()
	weather_manager.name = "WeatherManager"
	add_child(weather_manager)
	
	var weather_bridge = preload("res://scripts/data/weather_bridge.gd").new()
	weather_bridge.name = "WeatherBridge"
	add_child(weather_bridge)
	
	config = ConfigResource.new()
	config.load_config()
	var startup_archive_id := get_active_archive_id()
	if startup_archive_id != "" and save_manager and save_manager.has_method("recover_archive_if_interrupted"):
		if not save_manager.recover_archive_if_interrupted(startup_archive_id):
			push_error("GameDataManager 无法恢复活动档案：%s" % startup_archive_id)
			set_active_archive_id("", true)
	load_active_archive_settings()
	
	profile = CharacterProfile.new()
	profile.load_profile()
	if story_time_manager and story_time_manager.has_method("reload_for_current_character"):
		story_time_manager.reload_for_current_character(config.current_character_id)
	if gift_manager and gift_manager.has_method("reload_for_current_character"):
		gift_manager.reload_for_current_character(config.current_character_id)
	
	history = ChatHistoryManager.new()
	history.load_history()
	cognition_task_queue.load_queue()
	conversation_summary_manager.load_summaries()
	player_emotion_state_manager.load_state()
	memory_retrieval_trace_service.load_traces()
	memory_manager.load_memory()
	desktop_pet_memory_manager.load_memory()
	story_memory_manager.load_memory()
	memory_manager.queue_habit_cluster_summary_tasks()
	
	npc_relationship_manager = preload("res://scripts/data/npc_relationship_manager.gd").new()
	add_child(npc_relationship_manager)
	npc_relationship_manager.load_relationships()
	
	prompt_manager = preload("res://scripts/data/prompt_manager.gd").new()
	add_child(prompt_manager)
	
	# 角色加载完成后，进行人设锁检测
	persona_lock.check_and_lock_character(profile.char_name)
	
	_load_app_database()
	_load_pomodoro_data()

func get_active_archive_id() -> String:
	if config:
		return str(config.get_custom_config(_get_account_archive_config_key(), "")).strip_edges()
	return ""

func has_active_archive() -> bool:
	return get_active_archive_id() != ""

func set_active_archive_id(archive_id: String, save_config: bool = true) -> void:
	if config == null:
		return
	config.set_custom_config(_get_account_archive_config_key(), archive_id.strip_edges())
	if save_config:
		config.save_config()

func _get_account_archive_config_key() -> String:
	var user_id := OfficialAuthManager.get_user_id()
	return "active_archive_%s" % (user_id.validate_filename() if not user_id.is_empty() else "unauthenticated")

func get_archive_root_dir(archive_id: String = "") -> String:
	var final_archive_id := archive_id.strip_edges()
	if final_archive_id == "":
		final_archive_id = get_active_archive_id()
	if final_archive_id == "":
		final_archive_id = "default"
	var dir_path := get_archive_collection_dir().path_join(final_archive_id)
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)
	return dir_path

func get_archive_collection_dir() -> String:
	var user_id := OfficialAuthManager.get_user_id()
	if user_id.is_empty():
		return ACCOUNT_DATA_ROOT_DIR.path_join("unauthenticated").path_join("archives")
	var safe_user_id := user_id.validate_filename()
	var dir_path := ACCOUNT_DATA_ROOT_DIR.path_join(safe_user_id).path_join("archives")
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)
	return dir_path

func get_character_save_dir(char_id: String = "", archive_id: String = "") -> String:
	var final_char_id := char_id.strip_edges()
	if final_char_id == "":
		if config and str(config.current_character_id).strip_edges() != "":
			final_char_id = str(config.current_character_id).strip_edges()
		else:
			final_char_id = "default"
	var dir_path := get_archive_root_dir(archive_id).path_join("saves").path_join(final_char_id)
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)
	return dir_path

func get_character_save_path(file_name: String, char_id: String = "", archive_id: String = "") -> String:
	return get_character_save_dir(char_id, archive_id).path_join(file_name)

func get_archive_state_path(file_name: String, archive_id: String = "") -> String:
	return get_archive_root_dir(archive_id).path_join(file_name)

func save_active_story_checkpoint(state: Dictionary) -> void:
	save_story_checkpoint_for_archive(state, get_active_archive_id())

func save_story_checkpoint_for_archive(state: Dictionary, expected_archive_id: String) -> void:
	if not has_active_archive():
		return
	if not expected_archive_id.is_empty() and expected_archive_id != get_active_archive_id():
		return
	var path := get_archive_state_path(ACTIVE_STORY_STATE_FILE_NAME)
	if state.is_empty():
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
		return
	var checkpoint := state.duplicate(true)
	checkpoint["schema_version"] = ARCHIVE_SCHEMA_VERSION
	checkpoint["archive_id"] = get_active_archive_id()
	checkpoint["character_id"] = str(config.current_character_id) if config else ""
	SafeFileAccessUtil.store_string(path, JSON.stringify(checkpoint, "\t"))

func load_active_story_checkpoint() -> Dictionary:
	if not has_active_archive():
		return {}
	var checkpoint := _read_archive_state(ACTIVE_STORY_STATE_FILE_NAME)
	if int(checkpoint.get("schema_version", 0)) != ARCHIVE_SCHEMA_VERSION:
		return {}
	if str(checkpoint.get("archive_id", "")) != get_active_archive_id():
		return {}
	if config and str(checkpoint.get("character_id", "")) != str(config.current_character_id):
		return {}
	return checkpoint

func _read_archive_state(file_name: String) -> Dictionary:
	var path := get_archive_state_path(file_name)
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var json := JSON.new()
	var parse_result := json.parse(file.get_as_text())
	file.close()
	return json.data if parse_result == OK and json.data is Dictionary else {}

func save_active_archive_settings() -> bool:
	if config == null or not has_active_archive():
		return true
	return SafeFileAccessUtil.store_string(
		get_archive_state_path(ARCHIVE_SETTINGS_FILE_NAME),
		JSON.stringify({
			"schema_version": ARCHIVE_SCHEMA_VERSION,
			"archive_id": get_active_archive_id(),
			"settings": config.get_archive_settings_data()
		}, "\t")
	)

func load_active_archive_settings() -> void:
	if config == null:
		return
	config.reset_archive_settings()
	if not has_active_archive():
		return
	var path := get_archive_state_path(ARCHIVE_SETTINGS_FILE_NAME)
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var json := JSON.new()
	var parse_result := json.parse(file.get_as_text())
	file.close()
	if parse_result != OK or not json.data is Dictionary:
		return
	var envelope: Dictionary = json.data
	if int(envelope.get("schema_version", 0)) != ARCHIVE_SCHEMA_VERSION:
		return
	if str(envelope.get("archive_id", "")) != get_active_archive_id():
		return
	var settings: Variant = envelope.get("settings", {})
	if settings is Dictionary:
		config.apply_archive_settings_data(settings)

func get_archive_custom_config(key: String, default_value: Variant = null) -> Variant:
	if not has_active_archive():
		return default_value
	var state := _load_archive_custom_state()
	if state.has(key):
		return state[key]
	return default_value

func set_archive_custom_config(key: String, value: Variant, save_now: bool = true) -> bool:
	if not has_active_archive():
		return false
	var state := _load_archive_custom_state()
	state[key] = value
	if save_now:
		return _save_archive_custom_state(state)
	return true

func clear_archive_custom_config(archive_id: String, save_now: bool = true) -> void:
	var final_archive_id := archive_id.strip_edges()
	if final_archive_id == "":
		final_archive_id = get_active_archive_id()
	if final_archive_id == "":
		return
	var path := get_archive_collection_dir().path_join(final_archive_id).path_join(ARCHIVE_CUSTOM_STATE_FILE_NAME)
	if save_now and FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)

func _load_archive_custom_state() -> Dictionary:
	var path := get_archive_state_path(ARCHIVE_CUSTOM_STATE_FILE_NAME)
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var json := JSON.new()
	var parse_result := json.parse(file.get_as_text())
	file.close()
	if parse_result != OK or not json.data is Dictionary:
		return {}
	var envelope: Dictionary = json.data
	if int(envelope.get("schema_version", 0)) != ARCHIVE_SCHEMA_VERSION:
		return {}
	if str(envelope.get("archive_id", "")) != get_active_archive_id():
		return {}
	var state: Variant = envelope.get("state", {})
	return state if state is Dictionary else {}

func _save_archive_custom_state(state: Dictionary) -> bool:
	return SafeFileAccessUtil.store_string(
		get_archive_state_path(ARCHIVE_CUSTOM_STATE_FILE_NAME),
		JSON.stringify({
			"schema_version": ARCHIVE_SCHEMA_VERSION,
			"archive_id": get_active_archive_id(),
			"state": state
		}, "\t")
	)

func sync_profile_to_config() -> void:
	if config == null or profile == null:
		return
	config.player_name = str(profile.player_name)
	config.player_nickname = str(profile.player_title)
	config.current_main_bg_id = str(profile.current_main_bg_id).strip_edges()

func reload_active_archive_data() -> void:
	load_active_archive_settings()
	if config and str(config.current_character_id).strip_edges() == "":
		config.current_character_id = "luna"
	if profile:
		profile.load_profile()
	if history:
		history.load_history()
	if memory_manager:
		memory_manager.load_memory()
	if desktop_pet_memory_manager:
		desktop_pet_memory_manager.load_memory()
	if story_memory_manager:
		story_memory_manager.load_memory()
	if player_emotion_state_manager:
		player_emotion_state_manager.load_state()
	if npc_relationship_manager:
		npc_relationship_manager.load_relationships()
	if story_time_manager and story_time_manager.has_method("reload_for_current_character"):
		story_time_manager.reload_for_current_character(config.current_character_id if config else "")
	if gift_manager and gift_manager.has_method("reload_for_current_character"):
		gift_manager.reload_for_current_character(config.current_character_id if config else "")
	if is_instance_valid(MomentsManager) and MomentsManager.has_method("reload_for_current_character"):
		MomentsManager.reload_for_current_character(config.current_character_id if config else "")
	if is_instance_valid(MobileFixedChatManager) and MobileFixedChatManager.has_method("reload_for_active_archive"):
		MobileFixedChatManager.reload_for_active_archive()
	var goal_manager = get_node_or_null("/root/GoalManager")
	if goal_manager and goal_manager.has_method("reload_for_active_archive"):
		goal_manager.reload_for_active_archive()
	var main_chat_topic_manager = get_node_or_null("/root/MainChatTopicManager")
	if main_chat_topic_manager and main_chat_topic_manager.has_method("reload_for_active_archive"):
		main_chat_topic_manager.reload_for_active_archive()
	var story_post_event_manager = get_node_or_null("/root/StoryPostEventManager")
	if story_post_event_manager and story_post_event_manager.has_method("reload_for_active_archive"):
		story_post_event_manager.reload_for_active_archive()
	var event_manager = get_node_or_null("/root/EventManager")
	if event_manager and event_manager.has_method("reload_for_current_character"):
		event_manager.reload_for_current_character()
	if is_instance_valid(MapDataManager) and MapDataManager.has_method("reload_for_current_character"):
		MapDataManager.reload_for_current_character()
	if cognition_task_queue:
		cognition_task_queue.load_queue()
	if memory_manager:
		memory_manager.queue_habit_cluster_summary_tasks()
	if conversation_summary_manager:
		conversation_summary_manager.load_summaries()
	if memory_retrieval_trace_service:
		memory_retrieval_trace_service.load_traces()
	var guide_manager = get_node_or_null("/root/GuideManager")
	if guide_manager and guide_manager.has_method("reload_for_current_archive"):
		guide_manager.reload_for_current_archive()
	_load_pomodoro_data()
	sync_profile_to_config()
	if config:
		config.apply_settings()
		config.save_config()
	archive_changed.emit(get_active_archive_id())

func _load_pomodoro_data() -> void:
	pomodoro_data = _build_default_pomodoro_data()
	var path = get_archive_state_path("pomodoro_data.json")
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		var json_text = file.get_as_text()
		file.close()
		var json = JSON.new()
		if json.parse(json_text) == OK:
			var data = json.data
			if typeof(data) == TYPE_DICTIONARY:
				for key in data.keys():
					pomodoro_data[key] = data[key]

func _build_default_pomodoro_data() -> Dictionary:
	return {
		"work_duration": 25,
		"break_duration": 5,
		"total_focus_time": 0,
		"todos": []
	}

func begin_archive_change(new_archive_id: String) -> void:
	var old_archive_id := get_active_archive_id()
	archive_will_change.emit(old_archive_id, new_archive_id)
	var desktop_pet := get_tree().root.get_node_or_null("DesktopPet")
	if is_instance_valid(desktop_pet):
		desktop_pet.queue_free()
					
func save_pomodoro_data() -> bool:
	var path = get_archive_state_path("pomodoro_data.json")
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(pomodoro_data))
	var write_error := file.get_error()
	file.close()
	return write_error == OK

func _load_app_database() -> void:
	var path = "res://assets/data/interaction/app_database.json"
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		var json_text = file.get_as_text()
		file.close()
		var json = JSON.new()
		var error = json.parse(json_text)
		if error == OK:
			app_database = json.data
			print("[GameDataManager] Loaded app database successfully.")
		else:
			print("[GameDataManager] Error parsing app_database.json.")
	else:
		print("[GameDataManager] app_database.json not found.")

func switch_character(char_id: String) -> void:
	if config.current_character_id == char_id:
		return
		
	print("[GameDataManager] Switching character to: ", char_id)
	
	# 保存当前角色数据
	if profile: profile.save_profile()
	if history: history.save_history()
	if memory_manager: memory_manager.save_memory()
	if desktop_pet_memory_manager: desktop_pet_memory_manager.save_memory()
	if story_memory_manager: story_memory_manager.save_memory()
	if npc_relationship_manager: npc_relationship_manager.save_relationships()
	if story_time_manager: story_time_manager.save_data()
	if gift_manager and gift_manager.has_method("save_state"):
		gift_manager.save_state()
	var event_manager = get_node_or_null("/root/EventManager")
	if event_manager and event_manager.has_method("_save_triggered_events"):
		event_manager._save_triggered_events()
	
	# 更新配置并重新加载
	config.current_character_id = char_id
	config.save_config()
	
	profile.load_profile(char_id)
	history.load_history()
	memory_manager.load_memory()
	if desktop_pet_memory_manager:
		desktop_pet_memory_manager.load_memory()
	if story_memory_manager:
		story_memory_manager.load_memory()
	if cognition_task_queue:
		cognition_task_queue.load_queue()
	if memory_manager:
		memory_manager.queue_habit_cluster_summary_tasks()
	if conversation_summary_manager:
		conversation_summary_manager.load_summaries()
	if memory_retrieval_trace_service:
		memory_retrieval_trace_service.load_traces()
	if npc_relationship_manager: npc_relationship_manager.load_relationships()
	if story_time_manager and story_time_manager.has_method("reload_for_current_character"):
		story_time_manager.reload_for_current_character(char_id)
	if gift_manager and gift_manager.has_method("reload_for_current_character"):
		gift_manager.reload_for_current_character(char_id)
	var moments_manager = get_node_or_null("/root/MomentsManager")
	if moments_manager and moments_manager.has_method("reload_for_current_character"):
		moments_manager.reload_for_current_character(char_id)
	var goal_manager = get_node_or_null("/root/GoalManager")
	if goal_manager and goal_manager.has_method("reload_for_active_archive"):
		goal_manager.reload_for_active_archive()
	var main_chat_topic_manager = get_node_or_null("/root/MainChatTopicManager")
	if main_chat_topic_manager and main_chat_topic_manager.has_method("reload_for_active_archive"):
		main_chat_topic_manager.reload_for_active_archive()
	var story_post_event_manager = get_node_or_null("/root/StoryPostEventManager")
	if story_post_event_manager and story_post_event_manager.has_method("reload_for_active_archive"):
		story_post_event_manager.reload_for_active_archive()
	if event_manager and event_manager.has_method("reload_for_current_character"):
		event_manager.reload_for_current_character()
	if MapDataManager and MapDataManager.has_method("reload_for_current_character"):
		MapDataManager.reload_for_current_character()
	
	persona_lock.check_and_lock_character(profile.char_name)
	
	character_switched.emit(char_id)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if save_manager and save_manager.has_method("save_before_exit"):
			save_manager.save_before_exit()
		get_tree().quit()
