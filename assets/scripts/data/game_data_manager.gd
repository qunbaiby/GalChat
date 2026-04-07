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

# 用于记录上一个场景的路径，以便设置界面返回时知道该回到哪里
var previous_scene_path: String = ""

func _ready() -> void:
    audit_logger = preload("res://assets/scripts/data/audit_logger.gd").new()
    add_child(audit_logger)
    
    persona_lock = preload("res://assets/scripts/data/persona_lock_manager.gd").new()
    add_child(persona_lock)
    
    mood_system = preload("res://assets/scripts/data/mood_system.gd").new()
    add_child(mood_system)
    
    memory_manager = preload("res://assets/scripts/data/memory_manager.gd").new()
    add_child(memory_manager)
    
    personality_system = preload("res://assets/scripts/data/personality_system.gd").new()
    add_child(personality_system)
    
    config = ConfigResource.new()
    config.load_config()
    
    profile = CharacterProfile.new()
    profile.load_profile()
    
    history = ChatHistoryManager.new()
    history.load_history()
    
    prompt_manager = preload("res://assets/scripts/data/prompt_manager.gd").new()
    add_child(prompt_manager)
    
    # 角色加载完成后，进行人设锁检测
    persona_lock.check_and_lock_character(profile.char_name)
