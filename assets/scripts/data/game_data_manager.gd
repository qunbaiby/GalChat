extends Node

var config: ConfigResource
var profile: CharacterProfile
var history: ChatHistoryManager

# 用于记录上一个场景的路径，以便设置界面返回时知道该回到哪里
var previous_scene_path: String = ""

func _ready() -> void:
    config = ConfigResource.new()
    config.load_config()
    
    profile = CharacterProfile.new()
    profile.load_profile()
    
    history = ChatHistoryManager.new()
    history.load_history()
