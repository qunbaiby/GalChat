extends Node

var config: ConfigResource
var profile: CharacterProfile
var history: ChatHistoryManager
var prompt_manager: Node
var audit_logger: Node
var persona_lock: Node
var mood_system: Node
var memory_manager: MemoryManager
var personality_system: Node
var stats_system: Node
var activity_manager: Node
var gift_manager: Node
var app_database: Dictionary = {}

# 用于记录上一个场景的路径，以便设置界面返回时知道该回到哪里
var previous_scene_path: String = ""

func _ready() -> void:
	# 禁用自动退出机制，以便在关闭主窗口时可以保持桌宠运行
	get_tree().set_auto_accept_quit(false)
	
	audit_logger = preload("res://scripts/data/audit_logger.gd").new()
	add_child(audit_logger)
	
	persona_lock = preload("res://scripts/data/persona_lock_manager.gd").new()
	add_child(persona_lock)
	
	mood_system = preload("res://scripts/data/mood_system.gd").new()
	add_child(mood_system)
	
	memory_manager = preload("res://scripts/data/memory_manager.gd").new()
	add_child(memory_manager)
	
	personality_system = preload("res://scripts/data/personality_system.gd").new()
	add_child(personality_system)
	
	stats_system = preload("res://scripts/data/stats_system.gd").new()
	add_child(stats_system)
	
	activity_manager = preload("res://scripts/data/activity_manager.gd").new()
	add_child(activity_manager)
	
	gift_manager = preload("res://scripts/data/gift_manager.gd").new()
	add_child(gift_manager)
	
	config = ConfigResource.new()
	config.load_config()
	
	profile = CharacterProfile.new()
	profile.load_profile()
	
	history = ChatHistoryManager.new()
	history.load_history()
	
	prompt_manager = preload("res://scripts/data/prompt_manager.gd").new()
	add_child(prompt_manager)
	
	# 角色加载完成后，进行人设锁检测
	persona_lock.check_and_lock_character(profile.char_name)
	
	_load_app_database()

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

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		# 用户从任务栏强制关闭隐藏的Root窗口，直接退出程序
		get_tree().quit()
