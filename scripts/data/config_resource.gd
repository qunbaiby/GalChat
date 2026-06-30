class_name ConfigResource
extends Resource

var api_key: String = ""
var model: String = "deepseek-chat"
var temperature: float = 0.7
var max_tokens: int = 2048
var ai_mode_enabled: bool = true

# 豆包对话模型配置 (Doubao Chat)
var doubao_chat_api_key: String = ""

# 语音相关配置
var tts_backend: String = "qwen_tts" # "doubao" 或 "qwen_tts"
var doubao_app_id: String = "2557182005"
var doubao_token: String = "vtuoxQuuStbX442IL3ZhvH4QptGlfepf"
var doubao_cluster: String = "volcano_tts"

var qwen_tts_api_key: String = ""

var qwen_asr_enabled: bool = false
var qwen_asr_api_key: String = ""

# 角色独立音色配置，key 为 char_id，value 为音色 ID
var character_voice_types: Dictionary = {
    "luna": "ICL_zh_female_bingruoshaonv_tob",
    "ya": "ICL_zh_female_yujie_tob"
}

var qwen_tts_voice_types: Dictionary = {
    "luna": "Cherry",
    "ya": "Jielin"
}

var voice_enabled: bool = true

# 向量模型配置 (Doubao Embedding)
var embedding_enabled: bool = true
var doubao_embedding_api_key: String = ""
var doubao_embedding_model: String = "ep-xxxxxx"

# 桌宠多模态视觉限制
var vision_use_count: int = 0
var max_vision_uses: int = 10
var vision_last_recovery_time: int = 0 # 上次恢复多模态次数的时间戳（秒）

# 玩家称呼设置
var player_nickname: String = "哥哥"
var vision_enabled: bool = true
var vision_api_key: String = ""
var vision_model: String = "doubao-seed-2-0-mini-260428"
var vision_base_url: String = "https://ark.cn-beijing.volces.com/api/v3"

# 桌宠交互配置
var pet_global_cooldown: int = 10         # 全局主动发言最小冷却时间 (秒)
var pet_scale_multiplier: float = 1.0    # 桌宠立绘缩放倍率
var pet_enable_app_observe: bool = true  # 允许应用观察
var pet_enable_hourly_chime: bool = true # 允许整点报时
var pet_enable_afk_greeting: bool = true # 允许闲置问候
var pet_disturbance_mode: String = "摸鱼模式"
var pet_quiet_time_ranges: String = "23:30-08:00"
var pet_observe_allow_list: String = ""
var pet_never_capture_list: String = ""
var pet_sensitive_window_list: String = ""

# 图像生成配置 (Image Generation)
var image_generation_enabled: bool = true
var default_image_path: String = "res://assets/graphics/bg/default_bg.jpg"
var openai_image_api_key: String = ""
var image_generation_provider: int = 0 # 0: OpenAI, 1: Doubao
var doubao_image_api_key: String = ""
var doubao_image_model: String = "doubao-seedream-5-0-260128"
var enable_ai_diary_illustration: bool = true

# 当前选择的角色ID，默认为空，运行时会自动寻找第一个可用角色
var current_character_id: String = ""
var active_archive_id: String = ""
var current_main_bg_id: String = ""
var unlocked_main_bg_ids: Array = []
var unlocked_area_ids: Array = []

# 音画配置
var resolution_idx: int = 0
var fps_idx: int = 1
var vsync_enabled: bool = true
var bgm_volume: float = 1.0
var voice_volume: float = 1.0

# 玩家基本信息
var player_name: String = "玩家"
var player_bio: String = "暂无简介"
var moments_cover_path: String = ""
var player_level: int = 70
var player_eq_level: int = 6

# 自定义/扩展配置
var custom_configs: Dictionary = {}

const CONFIG_PATH = "user://config.json"
const TEST_DEFAULT_CONFIG_PATH = "res://assets/config/config.json"

func set_custom_config(key: String, value: Variant) -> void:
    custom_configs[key] = value

func get_custom_config(key: String, default_value: Variant = null) -> Variant:
    if custom_configs.has(key):
        return custom_configs[key]
    return default_value

func is_main_background_unlocked(bg_id: String) -> bool:
    var final_id := bg_id.strip_edges()
    if final_id == "":
        return false
    return unlocked_main_bg_ids.has(final_id)

func unlock_main_background(bg_id: String, save_now: bool = true) -> bool:
    var final_id := bg_id.strip_edges()
    if final_id == "":
        return false
    if unlocked_main_bg_ids.has(final_id):
        return false
    unlocked_main_bg_ids.append(final_id)
    if save_now:
        save_config()
    return true

func save_config() -> void:
    var data = {
        "api_key": api_key,
        "doubao_chat_api_key": doubao_chat_api_key,
        "model": model,
        "temperature": temperature,
        "max_tokens": max_tokens,
        "ai_mode_enabled": ai_mode_enabled,
        "tts_backend": tts_backend,
        "doubao_app_id": doubao_app_id,
        "doubao_token": doubao_token,
        "doubao_cluster": doubao_cluster,
        "qwen_tts_api_key": qwen_tts_api_key,
        "qwen_asr_enabled": qwen_asr_enabled,
        "qwen_asr_api_key": qwen_asr_api_key,
        "character_voice_types": character_voice_types,
        "qwen_tts_voice_types": qwen_tts_voice_types,
        "voice_enabled": voice_enabled,
        "embedding_enabled": embedding_enabled,
        "doubao_embedding_api_key": doubao_embedding_api_key,
        "doubao_embedding_model": doubao_embedding_model,
        "vision_use_count": vision_use_count,
        "vision_last_recovery_time": vision_last_recovery_time,
        "player_nickname": player_nickname,
        "vision_enabled": vision_enabled,
        "vision_api_key": vision_api_key,
        "vision_model": vision_model,
        "vision_base_url": vision_base_url,
        "pet_global_cooldown": pet_global_cooldown,
        "pet_scale_multiplier": pet_scale_multiplier,
        "pet_enable_app_observe": pet_enable_app_observe,
        "pet_enable_hourly_chime": pet_enable_hourly_chime,
        "pet_enable_afk_greeting": pet_enable_afk_greeting,
        "pet_disturbance_mode": pet_disturbance_mode,
        "pet_quiet_time_ranges": pet_quiet_time_ranges,
        "pet_observe_allow_list": pet_observe_allow_list,
        "pet_never_capture_list": pet_never_capture_list,
        "pet_sensitive_window_list": pet_sensitive_window_list,
        "image_generation_enabled": image_generation_enabled,
        "default_image_path": default_image_path,
        "openai_image_api_key": openai_image_api_key,
        "image_generation_provider": image_generation_provider,
        "doubao_image_api_key": doubao_image_api_key,
        "doubao_image_model": doubao_image_model,
        "enable_ai_diary_illustration": enable_ai_diary_illustration,
        "current_character_id": current_character_id,
        "active_archive_id": active_archive_id,
        "current_main_bg_id": current_main_bg_id,
        "unlocked_main_bg_ids": unlocked_main_bg_ids,
        "unlocked_area_ids": unlocked_area_ids,
        "resolution_idx": resolution_idx,
        "fps_idx": fps_idx,
        "vsync_enabled": vsync_enabled,
        "bgm_volume": bgm_volume,
        "voice_volume": voice_volume,
        "player_name": player_name,
        "player_bio": player_bio,
        "moments_cover_path": moments_cover_path,
        "player_level": player_level,
        "player_eq_level": player_eq_level,
        "custom_configs": custom_configs
    }
    var file = FileAccess.open(CONFIG_PATH, FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify(data, "\t"))
        file.close()

func _read_json_dict(file_path: String) -> Dictionary:
    if not FileAccess.file_exists(file_path):
        return {}
    var file := FileAccess.open(file_path, FileAccess.READ)
    if file == null:
        return {}
    var content := file.get_as_text()
    file.close()
    var json := JSON.new()
    if json.parse(content) != OK:
        return {}
    var data = json.get_data()
    if data is Dictionary:
        return data
    return {}

func _apply_ai_voice_defaults(data: Dictionary) -> void:
    api_key = str(data.get("api_key", api_key))
    doubao_chat_api_key = str(data.get("doubao_chat_api_key", doubao_chat_api_key))
    model = str(data.get("model", model))
    tts_backend = str(data.get("tts_backend", tts_backend))
    if tts_backend == "chattts":
        tts_backend = "qwen_tts"
    doubao_app_id = str(data.get("doubao_app_id", doubao_app_id))
    doubao_token = str(data.get("doubao_token", doubao_token))
    doubao_cluster = str(data.get("doubao_cluster", doubao_cluster))
    qwen_tts_api_key = str(data.get("qwen_tts_api_key", qwen_tts_api_key))
    qwen_asr_enabled = bool(data.get("qwen_asr_enabled", qwen_asr_enabled))
    qwen_asr_api_key = str(data.get("qwen_asr_api_key", qwen_asr_api_key))
    if data.has("character_voice_types") and data["character_voice_types"] is Dictionary:
        character_voice_types = (data["character_voice_types"] as Dictionary).duplicate(true)
    if data.has("qwen_tts_voice_types") and data["qwen_tts_voice_types"] is Dictionary:
        qwen_tts_voice_types = (data["qwen_tts_voice_types"] as Dictionary).duplicate(true)
    voice_enabled = bool(data.get("voice_enabled", voice_enabled))
    embedding_enabled = bool(data.get("embedding_enabled", embedding_enabled))
    doubao_embedding_api_key = str(data.get("doubao_embedding_api_key", doubao_embedding_api_key))
    doubao_embedding_model = str(data.get("doubao_embedding_model", doubao_embedding_model))
    vision_enabled = bool(data.get("vision_enabled", vision_enabled))
    vision_api_key = str(data.get("vision_api_key", vision_api_key))
    vision_model = str(data.get("vision_model", vision_model))
    vision_base_url = str(data.get("vision_base_url", vision_base_url))
    image_generation_enabled = bool(data.get("image_generation_enabled", image_generation_enabled))
    image_generation_provider = int(data.get("image_generation_provider", image_generation_provider))
    openai_image_api_key = str(data.get("openai_image_api_key", openai_image_api_key))
    doubao_image_api_key = str(data.get("doubao_image_api_key", doubao_image_api_key))
    doubao_image_model = str(data.get("doubao_image_model", doubao_image_model))
    enable_ai_diary_illustration = bool(data.get("enable_ai_diary_illustration", enable_ai_diary_illustration))

func load_config() -> void:
    _apply_ai_voice_defaults(_read_json_dict(TEST_DEFAULT_CONFIG_PATH))
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
                doubao_chat_api_key = data.get("doubao_chat_api_key", doubao_chat_api_key)
                model = data.get("model", model)
                temperature = data.get("temperature", temperature)
                max_tokens = data.get("max_tokens", max_tokens)
                ai_mode_enabled = data.get("ai_mode_enabled", ai_mode_enabled)
                tts_backend = data.get("tts_backend", tts_backend)
                if tts_backend == "chattts":
                    tts_backend = "qwen_tts"
                doubao_app_id = data.get("doubao_app_id", doubao_app_id)
                doubao_token = data.get("doubao_token", doubao_token)
                doubao_cluster = data.get("doubao_cluster", doubao_cluster)
                qwen_tts_api_key = data.get("qwen_tts_api_key", qwen_tts_api_key)
                qwen_asr_enabled = data.get("qwen_asr_enabled", qwen_asr_enabled)
                qwen_asr_api_key = data.get("qwen_asr_api_key", qwen_asr_api_key)
                if data.has("character_voice_types"):
                    var dict_data = data["character_voice_types"]
                    if dict_data is Dictionary:
                        character_voice_types = dict_data
                elif data.has("doubao_voice_type"):
                    character_voice_types["luna"] = data["doubao_voice_type"]
                
                if data.has("qwen_tts_voice_types"):
                    var seeds_data = data["qwen_tts_voice_types"]
                    if seeds_data is Dictionary:
                        qwen_tts_voice_types = seeds_data
                
                voice_enabled = data.get("voice_enabled", voice_enabled)
                embedding_enabled = data.get("embedding_enabled", embedding_enabled)
                doubao_embedding_api_key = data.get("doubao_embedding_api_key", doubao_embedding_api_key)
                doubao_embedding_model = data.get("doubao_embedding_model", doubao_embedding_model)
                vision_use_count = data.get("vision_use_count", vision_use_count)
                vision_last_recovery_time = data.get("vision_last_recovery_time", vision_last_recovery_time)
                player_nickname = data.get("player_nickname", player_nickname)
                vision_enabled = data.get("vision_enabled", vision_enabled)
                vision_api_key = data.get("vision_api_key", vision_api_key)
                vision_model = data.get("vision_model", vision_model)
                vision_base_url = data.get("vision_base_url", vision_base_url)
                
                pet_global_cooldown = data.get("pet_global_cooldown", pet_global_cooldown)
                pet_scale_multiplier = data.get("pet_scale_multiplier", pet_scale_multiplier)
                pet_enable_app_observe = data.get("pet_enable_app_observe", pet_enable_app_observe)
                pet_enable_hourly_chime = data.get("pet_enable_hourly_chime", pet_enable_hourly_chime)
                pet_enable_afk_greeting = data.get("pet_enable_afk_greeting", pet_enable_afk_greeting)
                pet_disturbance_mode = str(data.get("pet_disturbance_mode", pet_disturbance_mode))
                pet_quiet_time_ranges = str(data.get("pet_quiet_time_ranges", pet_quiet_time_ranges))
                pet_observe_allow_list = str(data.get("pet_observe_allow_list", pet_observe_allow_list)).strip_edges()
                pet_never_capture_list = str(data.get("pet_never_capture_list", pet_never_capture_list)).strip_edges()
                pet_sensitive_window_list = str(data.get("pet_sensitive_window_list", pet_sensitive_window_list)).strip_edges()

                # 将历史默认值迁移为空，避免旧版本预填内容持续误导当前策略。
                if pet_never_capture_list == "银行,支付,密码,验证码,登录,后台,控制台":
                    pet_never_capture_list = ""
                if pet_sensitive_window_list == "微信,wechat,qq,discord,telegram,飞书,钉钉,企业微信,outlook,mail,邮箱":
                    pet_sensitive_window_list = ""
                
                image_generation_enabled = data.get("image_generation_enabled", image_generation_enabled)
                default_image_path = data.get("default_image_path", default_image_path)
                openai_image_api_key = data.get("openai_image_api_key", openai_image_api_key)
                image_generation_provider = int(data.get("image_generation_provider", image_generation_provider))
                doubao_image_api_key = data.get("doubao_image_api_key", doubao_image_api_key)
                doubao_image_model = data.get("doubao_image_model", doubao_image_model)
                enable_ai_diary_illustration = data.get("enable_ai_diary_illustration", enable_ai_diary_illustration)
                current_character_id = data.get("current_character_id", current_character_id)
                active_archive_id = data.get("active_archive_id", active_archive_id)
                current_main_bg_id = data.get("current_main_bg_id", current_main_bg_id)
                if data.has("unlocked_main_bg_ids") and data["unlocked_main_bg_ids"] is Array:
                    unlocked_main_bg_ids = data["unlocked_main_bg_ids"]
                if data.has("unlocked_area_ids") and data["unlocked_area_ids"] is Array:
                    unlocked_area_ids = data["unlocked_area_ids"]
                resolution_idx = data.get("resolution_idx", resolution_idx)
                fps_idx = data.get("fps_idx", fps_idx)
                vsync_enabled = data.get("vsync_enabled", vsync_enabled)
                bgm_volume = data.get("bgm_volume", bgm_volume)
                voice_volume = data.get("voice_volume", voice_volume)
                player_name = data.get("player_name", player_name)
                player_bio = data.get("player_bio", player_bio)
                moments_cover_path = data.get("moments_cover_path", moments_cover_path)
                player_level = data.get("player_level", player_level)
                player_eq_level = data.get("player_eq_level", player_eq_level)
                
                var custom = data.get("custom_configs", {})
                if typeof(custom) == TYPE_DICTIONARY:
                    custom_configs = custom
    
    apply_settings()

func apply_settings() -> void:
    # Resolution
    var tree = Engine.get_main_loop() as SceneTree
    if tree and is_instance_valid(tree.root):
        var window = tree.root
        match resolution_idx:
            0:
                window.mode = Window.MODE_WINDOWED
                window.size = Vector2i(1280, 720)
            1:
                window.mode = Window.MODE_WINDOWED
                window.size = Vector2i(1600, 900)
            2:
                window.mode = Window.MODE_WINDOWED
                window.size = Vector2i(1920, 1080)
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
