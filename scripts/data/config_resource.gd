class_name ConfigResource
extends Resource

var api_key: String = ""
var model: String = "deepseek-chat"
var temperature: float = 0.7
var max_tokens: int = 2048
var ai_mode_enabled: bool = true

# 语音相关配置
var doubao_app_id: String = "2557182005"
var doubao_token: String = "vtuoxQuuStbX442IL3ZhvH4QptGlfepf"
var doubao_cluster: String = "volcano_tts"

# 角色独立音色配置，key 为 char_id，value 为音色 ID
var character_voice_types: Dictionary = {
    "luna": "ICL_zh_female_bingruoshaonv_tob",
    "ya": "ICL_zh_female_yujie_tob"
}
var voice_enabled: bool = true

# 向量模型配置 (Doubao Embedding)
var doubao_embedding_api_key: String = ""
var doubao_embedding_model: String = "ep-xxxxxx"

# 当前选择的角色ID，默认为空，运行时会自动寻找第一个可用角色
var current_character_id: String = ""

# 音画配置
var resolution_idx: int = 0
var fps_idx: int = 1
var vsync_enabled: bool = true
var bgm_volume: float = 1.0
var voice_volume: float = 1.0

# 玩家基本信息
var player_name: String = "开拓者"
var player_bio: String = "暂无简介"
var player_level: int = 70
var player_eq_level: int = 6

const CONFIG_PATH = "user://config.json"

func save_config() -> void:
    var data = {
        "api_key": api_key,
        "model": model,
        "temperature": temperature,
        "max_tokens": max_tokens,
        "ai_mode_enabled": ai_mode_enabled,
        "doubao_app_id": doubao_app_id,
        "doubao_token": doubao_token,
        "doubao_cluster": doubao_cluster,
        "character_voice_types": character_voice_types,
        "voice_enabled": voice_enabled,
        "doubao_embedding_api_key": doubao_embedding_api_key,
        "doubao_embedding_model": doubao_embedding_model,
        "current_character_id": current_character_id,
        "resolution_idx": resolution_idx,
        "fps_idx": fps_idx,
        "vsync_enabled": vsync_enabled,
        "bgm_volume": bgm_volume,
        "voice_volume": voice_volume,
        "player_name": player_name,
        "player_bio": player_bio,
        "player_level": player_level,
        "player_eq_level": player_eq_level
    }
    var file = FileAccess.open(CONFIG_PATH, FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify(data, "\t"))
        file.close()

func load_config() -> void:
    if FileAccess.file_exists(CONFIG_PATH):
        var file = FileAccess.open(CONFIG_PATH, FileAccess.READ)
        var content = file.get_as_text()
        file.close()
        
        var json = JSON.new()
        var error = json.parse(content)
        if error == OK:
            var data = json.get_data()
            if data is Dictionary:
                api_key = data.get("api_key", api_key)
                model = data.get("model", model)
                temperature = data.get("temperature", temperature)
                max_tokens = data.get("max_tokens", max_tokens)
                ai_mode_enabled = data.get("ai_mode_enabled", ai_mode_enabled)
                doubao_app_id = data.get("doubao_app_id", doubao_app_id)
                doubao_token = data.get("doubao_token", doubao_token)
                doubao_cluster = data.get("doubao_cluster", doubao_cluster)
                
                # 兼容旧版本的单变量配置
                if data.has("character_voice_types"):
                    var dict_data = data["character_voice_types"]
                    if dict_data is Dictionary:
                        character_voice_types = dict_data
                elif data.has("doubao_voice_type"):
                    character_voice_types["luna"] = data["doubao_voice_type"]
                
                voice_enabled = data.get("voice_enabled", voice_enabled)
                doubao_embedding_api_key = data.get("doubao_embedding_api_key", doubao_embedding_api_key)
                doubao_embedding_model = data.get("doubao_embedding_model", doubao_embedding_model)
                current_character_id = data.get("current_character_id", current_character_id)
                resolution_idx = data.get("resolution_idx", resolution_idx)
                fps_idx = data.get("fps_idx", fps_idx)
                vsync_enabled = data.get("vsync_enabled", vsync_enabled)
                bgm_volume = data.get("bgm_volume", bgm_volume)
                voice_volume = data.get("voice_volume", voice_volume)
                player_name = data.get("player_name", player_name)
                player_bio = data.get("player_bio", player_bio)
                player_level = data.get("player_level", player_level)
                player_eq_level = data.get("player_eq_level", player_eq_level)
    
    apply_settings()

func apply_settings() -> void:
    # Resolution
    var tree = Engine.get_main_loop() as SceneTree
    if tree and is_instance_valid(tree.current_scene) and tree.current_scene is Window:
        var window = tree.current_scene as Window
        match resolution_idx:
            0:
                window.mode = Window.MODE_WINDOWED
                window.size = Vector2i(1280, 720)
                window.move_to_center()
            1:
                window.mode = Window.MODE_WINDOWED
                window.size = Vector2i(1600, 900)
                window.move_to_center()
            2:
                window.mode = Window.MODE_WINDOWED
                window.size = Vector2i(1920, 1080)
                window.move_to_center()
            3:
                window.mode = Window.MODE_FULLSCREEN
            
    # FPS
    match fps_idx:
        0:
            Engine.max_fps = 30
        1:
            Engine.max_fps = 60
        2:
            Engine.max_fps = 120
            
    # Vsync
    if vsync_enabled:
        DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
    else:
        DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
        
    # Audio
    var bgm_bus_idx = AudioServer.get_bus_index("BGM")
    if bgm_bus_idx >= 0:
        AudioServer.set_bus_volume_db(bgm_bus_idx, linear_to_db(bgm_volume))
        
    var voice_bus_idx = AudioServer.get_bus_index("Voice")
    if voice_bus_idx >= 0:
        AudioServer.set_bus_volume_db(voice_bus_idx, linear_to_db(voice_volume))

