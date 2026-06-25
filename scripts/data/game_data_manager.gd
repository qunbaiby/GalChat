extends Node

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
var personality_system: Node
var stats_system: Node
var activity_manager: Node
var gift_manager: Node
var story_time_manager: Node
var interaction_manager: Node
var save_manager: Node
var weather_manager: Node
var app_database: Dictionary = {}
const ARCHIVE_ROOT_DIR := "user://archives"

# 番茄钟与待办事项数据
var pomodoro_data: Dictionary = {
	"work_duration": 25,
	"break_duration": 5,
	"total_focus_time": 0,
	"todos": []
}

signal character_switched(char_id: String)

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
	
	# 初始化天气和时间桥接器（将本地系统与 Romestead 插件绑定）
	var weather_bridge = preload("res://scripts/data/weather_bridge.gd").new()
	weather_bridge.name = "WeatherBridge"
	add_child(weather_bridge)
	
	config = ConfigResource.new()
	config.load_config()
	
	profile = CharacterProfile.new()
	profile.load_profile()
	if story_time_manager and story_time_manager.has_method("reload_for_current_character"):
		story_time_manager.reload_for_current_character(config.current_character_id)
	if gift_manager and gift_manager.has_method("reload_for_current_character"):
		gift_manager.reload_for_current_character(config.current_character_id)
	
	history = ChatHistoryManager.new()
	history.load_history()
	memory_manager.load_memory()
	desktop_pet_memory_manager.load_memory()
	
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
		return str(config.active_archive_id).strip_edges()
	return ""

func has_active_archive() -> bool:
	return get_active_archive_id() != ""

func set_active_archive_id(archive_id: String, save_config: bool = true) -> void:
	if config == null:
		return
	config.active_archive_id = archive_id.strip_edges()
	if save_config:
		config.save_config()

func get_archive_root_dir(archive_id: String = "") -> String:
	var final_archive_id := archive_id.strip_edges()
	if final_archive_id == "":
		final_archive_id = get_active_archive_id()
	if final_archive_id == "":
		final_archive_id = "default"
	var dir_path := "%s/%s" % [ARCHIVE_ROOT_DIR, final_archive_id]
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

func get_archive_custom_config(key: String, default_value: Variant = null) -> Variant:
	if config == null:
		return default_value
	var archive_id := get_active_archive_id()
	if archive_id == "":
		return default_value
	var bucket_key := "archive_%s" % archive_id
	var bucket = config.get_custom_config(bucket_key, {})
	if bucket is Dictionary and bucket.has(key):
		return bucket[key]
	return default_value

func set_archive_custom_config(key: String, value: Variant, save_now: bool = true) -> void:
	if config == null:
		return
	var archive_id := get_active_archive_id()
	if archive_id == "":
		return
	var bucket_key := "archive_%s" % archive_id
	var bucket = config.get_custom_config(bucket_key, {})
	if not bucket is Dictionary:
		bucket = {}
	bucket[key] = value
	config.set_custom_config(bucket_key, bucket)
	if save_now:
		config.save_config()

func clear_archive_custom_config(archive_id: String, save_now: bool = true) -> void:
	if config == null:
		return
	var final_archive_id := archive_id.strip_edges()
	if final_archive_id == "":
		final_archive_id = get_active_archive_id()
	if final_archive_id == "":
		return
	var bucket_key := "archive_%s" % final_archive_id
	if config.custom_configs.has(bucket_key):
		config.custom_configs.erase(bucket_key)
		if save_now:
			config.save_config()

func sync_profile_to_config() -> void:
	if config == null or profile == null:
		return
	config.player_name = str(profile.player_name)
	config.player_nickname = str(profile.player_title)
	config.current_main_bg_id = str(profile.current_main_bg_id).strip_edges()

func reload_active_archive_data() -> void:
	if profile:
		profile.load_profile()
	if history:
		history.load_history()
	if memory_manager:
		memory_manager.load_memory()
	if desktop_pet_memory_manager:
		desktop_pet_memory_manager.load_memory()
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
	sync_profile_to_config()
	if config:
		config.save_config()

func _load_pomodoro_data() -> void:
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
					
func save_pomodoro_data() -> void:
	var path = get_archive_state_path("pomodoro_data.json")
	var file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(pomodoro_data))
	file.close()

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
		# 用户从任务栏强制关闭隐藏的Root窗口，直接退出程序
		get_tree().quit()
