class_name ConfigResource
extends Resource

const AI_SERVICE_OFFICIAL := "official"
const AI_SERVICE_PERSONAL := "personal"
const DEFAULT_OFFICIAL_AI_GATEWAY := "http://127.0.0.1:8787/v1/game"
const GLOBAL_SETTING_KEYS: PackedStringArray = [
    "ai_service_mode", "official_ai_gateway_url", "api_key", "doubao_chat_api_key",
    "model", "temperature", "max_tokens", "ai_mode_enabled", "tts_api_key",
    "tts_audio_format", "tts_sample_rate", "tts_speech_rate", "tts_loudness_rate",
    "tts_autoplay_ai_chat", "qwen_asr_enabled", "qwen_asr_api_key",
    "tts_character_speakers", "voice_enabled", "embedding_enabled",
    "doubao_embedding_api_key", "doubao_embedding_model", "vision_use_count",
    "vision_last_recovery_time", "vision_enabled", "vision_api_key",
    "vision_model", "vision_base_url", "pet_global_cooldown", "pet_scale_multiplier",
    "pet_enable_app_observe", "pet_enable_hourly_chime", "pet_enable_afk_greeting",
    "pet_disturbance_mode", "pet_quiet_time_ranges", "pet_observe_allow_list",
    "pet_never_capture_list", "pet_sensitive_window_list", "image_generation_enabled",
    "default_image_path", "openai_image_api_key", "image_generation_provider",
    "doubao_image_api_key", "doubao_image_model", "enable_ai_diary_illustration",
    "window_mode_idx", "resolution_idx", "fps_idx", "vsync_enabled", "bgm_volume", "voice_volume",
    "free_chat_enabled"
]
const ARCHIVE_SETTING_KEYS: PackedStringArray = [
    "current_character_id", "current_main_bg_id", "unlocked_main_bg_ids",
    "unlocked_area_ids", "player_name", "player_nickname", "player_bio",
    "moments_cover_path", "player_level", "player_eq_level"
]

var ai_service_mode: String = AI_SERVICE_OFFICIAL
var official_ai_gateway_url: String = DEFAULT_OFFICIAL_AI_GATEWAY
var official_access_token: String = ""
var api_key: String = ""
var model: String = "deepseek-chat"
var temperature: float = 0.7
var max_tokens: int = 2048
var ai_mode_enabled: bool = true

# 豆包对话模型配置 (Doubao Chat)
var doubao_chat_api_key: String = ""

# 语音相关配置
var tts_api_key: String = ""
var tts_audio_format: String = "mp3"
var tts_sample_rate: int = 24000
var tts_speech_rate: int = 0
var tts_loudness_rate: int = 0
var tts_autoplay_ai_chat: bool = true

var qwen_asr_enabled: bool = false
var qwen_asr_api_key: String = ""

const DEFAULT_TTS_CHARACTER_SPEAKERS: Dictionary = {
    "aili": "zh_female_vv_uranus_bigtts",
    "jing": "zh_female_vv_uranus_bigtts",
    "ling": "zh_female_vv_uranus_bigtts",
    "luna": "zh_female_vv_uranus_bigtts",
    "luna_father": "zh_female_vv_uranus_bigtts",
    "nicole": "zh_female_vv_uranus_bigtts",
    "shuo": "zh_female_vv_uranus_bigtts",
    "ya": "zh_female_vv_uranus_bigtts"
}

# 角色独立音色配置，key 为 char_id，value 为新版 TTS 2.0 speaker ID
var tts_character_speakers: Dictionary = DEFAULT_TTS_CHARACTER_SPEAKERS.duplicate(true)

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
var vision_model: String = "doubao-seed-2-0-lite-260428"
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
var default_image_path: String = "res://icon.svg"
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
var window_mode_idx: int = 0
var resolution_idx: int = 0
var fps_idx: int = 1
var vsync_enabled: bool = true
var bgm_volume: float = 1.0
var voice_volume: float = 1.0
var free_chat_enabled: bool = false

# 玩家基本信息
var player_name: String = "玩家"
var player_bio: String = "暂无简介"
var moments_cover_path: String = ""
var player_level: int = 70
var player_eq_level: int = 6

# 自定义/扩展配置
var custom_configs: Dictionary = {}

const CONFIG_PATH = "user://config.json"

func set_custom_config(key: String, value: Variant) -> void:
    custom_configs[key] = value

func get_custom_config(key: String, default_value: Variant = null) -> Variant:
    if custom_configs.has(key):
        return custom_configs[key]
    return default_value

func set_official_access_token(access_token: String) -> void:
    official_access_token = access_token.strip_edges()

func clear_official_access_token() -> void:
    official_access_token = ""

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

func get_archive_settings_data() -> Dictionary:
    return _get_settings_data(ARCHIVE_SETTING_KEYS)

func get_global_settings_data() -> Dictionary:
    return _get_settings_data(GLOBAL_SETTING_KEYS)

func _get_settings_data(keys: PackedStringArray) -> Dictionary:
    var data: Dictionary = {}
    for key in keys:
        var value: Variant = get(key)
        data[key] = value.duplicate(true) if value is Array or value is Dictionary else value
    return data

func apply_archive_settings_data(data: Dictionary) -> void:
    _apply_settings_data(data, ARCHIVE_SETTING_KEYS)

func apply_global_settings_data(data: Dictionary) -> void:
    _apply_settings_data(data, GLOBAL_SETTING_KEYS)

func _apply_settings_data(data: Dictionary, keys: PackedStringArray) -> void:
    for key in keys:
        if not data.has(key):
            continue
        var value: Variant = data[key]
        set(key, value.duplicate(true) if value is Array or value is Dictionary else value)
    tts_audio_format = _normalize_tts_audio_format(tts_audio_format)
    tts_character_speakers = _sanitize_tts_character_speakers(tts_character_speakers)
    if ai_service_mode != AI_SERVICE_OFFICIAL:
        ai_service_mode = AI_SERVICE_PERSONAL

func reset_archive_settings() -> void:
    var defaults := ConfigResource.new()
    apply_archive_settings_data(defaults.get_archive_settings_data())

func save_config() -> bool:
    var data := {
        "custom_configs": custom_configs,
        "settings": get_global_settings_data()
    }
    var file = FileAccess.open(CONFIG_PATH, FileAccess.WRITE)
    if file == null:
        return false
    file.store_string(JSON.stringify(data, "\t"))
    var write_error := file.get_error()
    file.close()
    if write_error != OK:
        return false
    if GameDataManager and GameDataManager.has_method("save_active_archive_settings"):
        var archive_result: Variant = GameDataManager.call("save_active_archive_settings")
        return archive_result is bool and bool(archive_result)
    return true

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

func _normalize_tts_audio_format(value: String) -> String:
    var normalized: String = value.strip_edges().to_lower()
    if normalized == "wav":
        return "wav"
    return "mp3"

func get_default_tts_speaker(char_id: String) -> String:
    var normalized_char_id: String = char_id.strip_edges().to_lower()
    return str(DEFAULT_TTS_CHARACTER_SPEAKERS.get(normalized_char_id, "zh_female_vv_uranus_bigtts"))

func _is_legacy_tts_speaker(speaker_id: String) -> bool:
    var normalized: String = speaker_id.strip_edges()
    if normalized.is_empty():
        return true
    if normalized.begins_with("S_"):
        return false
    if normalized.find("_uranus_bigtts") >= 0 or normalized.find("_saturn_bigtts") >= 0:
        return false
    if normalized.begins_with("ICL_uranus_") and normalized.ends_with("_tob"):
        return false
    if normalized.begins_with("ICL_"):
        return true
    if normalized.ends_with("_tob"):
        return true
    if normalized == "BV001_streaming":
        return true
    if normalized.find("_moon_bigtts") >= 0 or normalized.find("_mars_bigtts") >= 0:
        return true
    if normalized.find("_emo_v2_") >= 0:
        return true
    return false

func _sanitize_tts_character_speakers(raw_speakers: Dictionary) -> Dictionary:
    var sanitized: Dictionary = DEFAULT_TTS_CHARACTER_SPEAKERS.duplicate(true)
    for key_variant in raw_speakers.keys():
        var char_id: String = str(key_variant).strip_edges().to_lower()
        if char_id.is_empty():
            continue
        var speaker_id: String = str(raw_speakers.get(key_variant, "")).strip_edges()
        if _is_legacy_tts_speaker(speaker_id):
            speaker_id = get_default_tts_speaker(char_id)
        sanitized[char_id] = speaker_id
    return sanitized

func _apply_tts_defaults_from_data(data: Dictionary) -> void:
    var api_key_value: String = str(data.get("tts_api_key", "")).strip_edges()
    if api_key_value.is_empty():
        api_key_value = str(data.get("doubao_token", tts_api_key)).strip_edges()
    if not api_key_value.is_empty():
        tts_api_key = api_key_value

    tts_audio_format = _normalize_tts_audio_format(str(data.get("tts_audio_format", tts_audio_format)))
    tts_sample_rate = int(data.get("tts_sample_rate", tts_sample_rate))
    tts_speech_rate = int(data.get("tts_speech_rate", tts_speech_rate))
    tts_loudness_rate = int(data.get("tts_loudness_rate", tts_loudness_rate))
    tts_autoplay_ai_chat = bool(data.get("tts_autoplay_ai_chat", tts_autoplay_ai_chat))

    if data.has("tts_character_speakers") and data["tts_character_speakers"] is Dictionary:
        tts_character_speakers = _sanitize_tts_character_speakers(data["tts_character_speakers"] as Dictionary)
    elif data.has("character_voice_types") and data["character_voice_types"] is Dictionary:
        tts_character_speakers = _sanitize_tts_character_speakers(data["character_voice_types"] as Dictionary)
    elif data.has("doubao_voice_type"):
        tts_character_speakers["luna"] = get_default_tts_speaker("luna")

func _apply_ai_voice_defaults(data: Dictionary) -> void:
    api_key = str(data.get("api_key", api_key))
    doubao_chat_api_key = str(data.get("doubao_chat_api_key", doubao_chat_api_key))
    model = str(data.get("model", model))
    _apply_tts_defaults_from_data(data)
    qwen_asr_enabled = bool(data.get("qwen_asr_enabled", qwen_asr_enabled))
    qwen_asr_api_key = str(data.get("qwen_asr_api_key", qwen_asr_api_key))
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
    enable_ai_diary_illustration = true

func load_config() -> void:
    official_access_token = OS.get_environment("GALCHAT_OFFICIAL_ACCESS_TOKEN").strip_edges()
    reset_archive_settings()
    if FileAccess.file_exists(CONFIG_PATH):
        var file = FileAccess.open(CONFIG_PATH, FileAccess.READ)
        var content = file.get_as_text()
        file.close()
        
        var json = JSON.new()
        var error = json.parse(content)
        if error == OK:
            var data = json.get_data()
            if data is Dictionary:
                var custom = data.get("custom_configs", {})
                if typeof(custom) == TYPE_DICTIONARY:
                    custom_configs = custom
                var persisted_settings: Variant = data.get("settings", {})
                if persisted_settings is Dictionary and not persisted_settings.is_empty():
                    apply_global_settings_data(persisted_settings)
    
    apply_settings()

func apply_settings() -> void:
    apply_resolution()
    apply_runtime_settings()

func apply_resolution() -> void:
    if GameDataManager and GameDataManager.has_meta("desktop_wallpaper_runtime_active"):
        return
    var tree = Engine.get_main_loop() as SceneTree
    if not tree or not is_instance_valid(tree.root):
        return
    var screen_index := DisplayServer.window_get_current_screen()
    if screen_index < 0 or screen_index >= DisplayServer.get_screen_count():
        screen_index = DisplayServer.get_primary_screen()
    match clampi(window_mode_idx, 0, 2):
        0:
            DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
            DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
            DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_RESIZE_DISABLED, false)
            var target_size := get_window_resolution_size(resolution_idx)
            var usable_rect := DisplayServer.screen_get_usable_rect(screen_index)
            target_size.x = mini(target_size.x, usable_rect.size.x)
            target_size.y = mini(target_size.y, usable_rect.size.y)
            DisplayServer.window_set_size(target_size)
            DisplayServer.window_set_position(get_centered_window_position(target_size, usable_rect))
            call_deferred("_stabilize_windowed_geometry", target_size, screen_index)
        1:
            DisplayServer.window_set_current_screen(screen_index)
            DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
        2:
            DisplayServer.window_set_current_screen(screen_index)
            DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)

func get_window_resolution_size(index: int) -> Vector2i:
    const WINDOW_RESOLUTIONS: Array[Vector2i] = [
        Vector2i(1280, 720),
        Vector2i(1600, 900),
        Vector2i(1920, 1080),
        Vector2i(2560, 1440)
    ]
    return WINDOW_RESOLUTIONS[clampi(index, 0, WINDOW_RESOLUTIONS.size() - 1)]

func _stabilize_windowed_geometry(target_size: Vector2i, screen_index: int) -> void:
    var tree = Engine.get_main_loop() as SceneTree
    if not tree:
        return
    await tree.process_frame
    if window_mode_idx != 0 or GameDataManager.has_meta("desktop_wallpaper_runtime_active"):
        return
    var usable_rect := DisplayServer.screen_get_usable_rect(screen_index)
    target_size.x = mini(target_size.x, usable_rect.size.x)
    target_size.y = mini(target_size.y, usable_rect.size.y)
    DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
    DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
    DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_RESIZE_DISABLED, false)
    DisplayServer.window_set_size(target_size)
    DisplayServer.window_set_position(get_centered_window_position(target_size, usable_rect))

func get_centered_window_position(window_size: Vector2i, usable_rect: Rect2i) -> Vector2i:
    var remaining_space := usable_rect.size - window_size
    var centered := usable_rect.position + Vector2i(
        floori(float(remaining_space.x) * 0.5),
        floori(float(remaining_space.y) * 0.5)
    )
    var maximum := usable_rect.end - window_size
    return Vector2i(
        clampi(centered.x, usable_rect.position.x, maximum.x),
        clampi(centered.y, usable_rect.position.y, maximum.y)
    )

func apply_runtime_settings() -> void:
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
