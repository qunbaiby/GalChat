extends Node

# 剧情时间系统管理器
# 用于管理虚构的故事时间，提供给桌宠外的其他界面和对话使用。

signal time_advanced(days: int, current_period: String)

# 一天的时段划分
const PERIOD_MORNING = "上午"
const PERIOD_AFTERNOON = "下午"
const PERIOD_EVENING = "傍晚"
const PERIOD_NIGHT = "夜晚"

# 虚构时间的存档数据
var current_day_offset: int = 0
var current_period: String = PERIOD_MORNING
var current_hour: int = 8
var current_minute: int = 0
var debug_weather_overrides: Dictionary = {}

# 故事设定的基准起始日期（例如 2026年3月7日 星期六）
var start_year: int = 2026
var start_month: int = 3
var start_day: int = 7

# 配置数据（从 JSON 加载）
var time_config: Dictionary = {}

func _init() -> void:
    _load_config()

func get_save_path(char_id: String = "") -> String:
    var final_char_id = char_id.strip_edges()
    if final_char_id == "":
        if GameDataManager.config and GameDataManager.config.current_character_id != "":
            final_char_id = GameDataManager.config.current_character_id
        else:
            final_char_id = "default"
    return GameDataManager.get_character_save_path("story_time_save.json", final_char_id)

func reload_for_current_character(char_id: String = "") -> void:
    load_data(char_id)

func _load_config() -> void:
    var path = "res://assets/data/story/story_time.json"
    if FileAccess.file_exists(path):
        var file = FileAccess.open(path, FileAccess.READ)
        var json = JSON.new()
        if json.parse(file.get_as_text()) == OK:
            time_config = json.data
            if time_config.has("start_date"):
                start_year = time_config["start_date"].get("year", 2026)
                start_month = time_config["start_date"].get("month", 3)
                start_day = time_config["start_date"].get("day", 7)

func load_data(char_id: String = "") -> void:
    current_day_offset = 0
    current_period = PERIOD_MORNING
    current_hour = 8
    current_minute = 0
    debug_weather_overrides = {}
    var path = get_save_path(char_id)
    
    if FileAccess.file_exists(path):
        var file = FileAccess.open(path, FileAccess.READ)
        var json = JSON.new()
        if json.parse(file.get_as_text()) == OK:
            var data: Dictionary = json.data
            current_day_offset = data.get("current_day_offset", 0)
            current_period = data.get("current_period", PERIOD_MORNING)
            current_hour = data.get("current_hour", 8)
            current_minute = data.get("current_minute", 0)
            var raw_overrides: Variant = data.get("debug_weather_overrides", {})
            if raw_overrides is Dictionary:
                for raw_key in raw_overrides.keys():
                    var override_key: int = int(str(raw_key))
                    var override_value: Variant = raw_overrides.get(raw_key, {})
                    if override_value is Dictionary:
                        debug_weather_overrides[override_key] = override_value

func save_data() -> bool:
    var data = {
        "current_day_offset": current_day_offset,
        "current_period": current_period,
        "current_hour": current_hour,
        "current_minute": current_minute,
        "debug_weather_overrides": debug_weather_overrides
    }
    var char_id = "default"
    if GameDataManager.config and GameDataManager.config.current_character_id != "":
        char_id = GameDataManager.config.current_character_id
    var path = GameDataManager.get_character_save_path("story_time_save.json", char_id)
    var file = FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        return false
    file.store_string(JSON.stringify(data, "\t"))
    var write_error := file.get_error()
    file.close()
    return write_error == OK

# 推进时间（天数）
func advance_day(days: int = 1) -> void:
    current_day_offset += days
    current_period = PERIOD_MORNING
    current_hour = 8
    current_minute = 0
    # 移除自动保存，交由游戏核心的存档系统管理
    # save_data()
    
    # 触发记忆衰退
    if GameDataManager.memory_manager != null:
        if GameDataManager.memory_manager.has_method("process_daily_decay"):
            GameDataManager.memory_manager.process_daily_decay(days)
            
    # 记录大五人格变化历史
    if GameDataManager.personality_system and GameDataManager.personality_system.has_method("settle_personality_tension"):
        GameDataManager.personality_system.settle_personality_tension(GameDataManager.profile, "daily", {
            "short_settle_scale": 0.5,
            "long_settle_scale": 0.12,
            "force_log": false,
            "force_snapshot": true
        })
    if GameDataManager.profile and GameDataManager.profile.has_method("record_daily_personality"):
        GameDataManager.profile.record_daily_personality(current_day_offset)
            
    time_advanced.emit(days, current_period)

# 推进时段
func advance_period() -> void:
    if current_period == PERIOD_MORNING:
        current_period = PERIOD_AFTERNOON
        current_hour = 14
    elif current_period == PERIOD_AFTERNOON:
        current_period = PERIOD_EVENING
        current_hour = 18
    elif current_period == PERIOD_EVENING:
        current_period = PERIOD_NIGHT
        current_hour = 21
    else:
        # 夜晚推进会进入第二天上午
        advance_day(1)
        return
    current_minute = 0
    # 移除自动保存，交由游戏核心的存档系统管理
    # save_data()
    time_advanced.emit(0, current_period)

# 模拟时间流逝（分钟），适用于 UI 面板时钟的自然跳动
func tick_minutes(mins: int = 1) -> void:
    current_minute += mins
    var hours_added: int = 0
    var days_added: int = 0
    if current_minute >= 60:
        hours_added = current_minute / 60
        current_hour += hours_added
        current_minute %= 60
        
        # 如果时间自然流逝跨越了时段，也自动更新时段文本
        if current_hour >= 24:
            days_added = current_hour / 24
            current_hour = current_hour % 24
            current_day_offset += days_added
            if GameDataManager.memory_manager != null:
                if GameDataManager.memory_manager.has_method("process_daily_decay"):
                    GameDataManager.memory_manager.process_daily_decay(days_added)
            if GameDataManager.personality_system and GameDataManager.personality_system.has_method("settle_personality_tension"):
                GameDataManager.personality_system.settle_personality_tension(GameDataManager.profile, "daily", {
                    "short_settle_scale": 0.5,
                    "long_settle_scale": 0.12,
                    "force_log": false,
                    "force_snapshot": true
                })
            if GameDataManager.profile and GameDataManager.profile.has_method("record_daily_personality"):
                GameDataManager.profile.record_daily_personality(current_day_offset)
            
        if current_hour >= 6 and current_hour < 12:
            current_period = PERIOD_MORNING
        elif current_hour >= 12 and current_hour < 17:
            current_period = PERIOD_AFTERNOON
        elif current_hour >= 17 and current_hour < 20:
            current_period = PERIOD_EVENING
        else:
            current_period = PERIOD_NIGHT
            
    # 只要时间发生变化，就发出信号，方便外部UI更新（如按钮禁用状态）
    time_advanced.emit(days_added, current_period)

func set_debug_time(day_offset: int, period: String, hour: int, minute: int) -> void:
    current_day_offset = max(day_offset, 0)
    current_hour = clamp(hour, 0, 23)
    current_minute = clamp(minute, 0, 59)
    var normalized_period: String = period.strip_edges()
    if normalized_period == "":
        normalized_period = _resolve_period_from_hour(current_hour)
    elif not _is_valid_period(normalized_period):
        normalized_period = _resolve_period_from_hour(current_hour)
    current_period = normalized_period
    save_data()
    time_advanced.emit(0, current_period)

func set_debug_weather(weather_id: String, temperature: int, offset: int = -1) -> void:
    var target_offset: int = current_day_offset if offset < 0 else max(offset, 0)
    debug_weather_overrides[target_offset] = {
        "weather": normalize_story_weather_id(weather_id),
        "temperature": temperature
    }
    save_data()
    time_advanced.emit(0, current_period)

func clear_debug_weather(offset: int = -1) -> void:
    if offset < 0:
        debug_weather_overrides.clear()
    else:
        debug_weather_overrides.erase(max(offset, 0))
    save_data()
    time_advanced.emit(0, current_period)

# 获取计算后的真实剧情日期（年、月、日、星期）
func get_current_date_dict() -> Dictionary:
    # Godot 的 Time 没有直接的日期加减，我们需要用 UNIX 时间戳计算
    var start_dict = {
        "year": start_year,
        "month": start_month,
        "day": start_day,
        "hour": 0,
        "minute": 0,
        "second": 0
    }
    var start_unix = Time.get_unix_time_from_datetime_dict(start_dict)
    var current_unix = start_unix + (current_day_offset * 86400)
    return Time.get_datetime_dict_from_unix_time(current_unix)

# 获取指定偏移天数的配置
func get_day_config(offset: int) -> Dictionary:
    var base_config: Dictionary = {
        "weather": "sunny",
        "temperature": 22,
        "events": []
    }
    if time_config.has("daily_data"):
        for day_data in time_config["daily_data"]:
            if int(day_data.get("day_offset", -1)) == offset:
                base_config = day_data.duplicate(true)
                break
    if debug_weather_overrides.has(offset):
        var override_data: Variant = debug_weather_overrides.get(offset, {})
        if override_data is Dictionary:
            var merged_config: Dictionary = base_config.duplicate(true)
            for key in override_data.keys():
                merged_config[key] = override_data[key]
            return merged_config
    return base_config

# 获取当前日期的天气与事件配置
func get_current_day_config() -> Dictionary:
    return get_day_config(current_day_offset)

func normalize_story_weather_id(raw_weather: String) -> String:
    var key: String = raw_weather.strip_edges().to_lower()
    match key:
        "sunny", "clear", "fine":
            return "sunny"
        "cloudy", "partly_cloudy":
            return "cloudy"
        "overcast":
            return "overcast"
        "foggy", "fog", "mist":
            return "foggy"
        "rainy", "rain", "shower":
            return "rainy"
        "thunder", "storm", "thunderstorm":
            return "thunder"
        "snow", "snowy", "blizzard":
            return "snow"
        _:
            return key

func get_story_weather_id(offset: int = current_day_offset) -> String:
    var day_cfg: Dictionary = get_day_config(offset)
    return normalize_story_weather_id(str(day_cfg.get("weather", "sunny")))

func get_story_weather_desc(offset: int = current_day_offset) -> String:
    match get_story_weather_id(offset):
        "sunny":
            return "晴天"
        "cloudy":
            return "多云"
        "overcast":
            return "阴天"
        "foggy":
            return "有雾"
        "rainy":
            return "雨天"
        "thunder":
            return "雷雨"
        "snow":
            return "雪天"
        _:
            return "晴天"

# 供大模型提示词使用的格式化剧情时间字符串
func get_story_time_string() -> String:
    var d: Dictionary = get_current_date_dict()
    var weekday_str: Array[String] = ["日", "一", "二", "三", "四", "五", "六"]
    var w: String = weekday_str[d.weekday]
    var weather_cfg: Dictionary = get_current_day_config()
    var weather_text: String = get_story_weather_desc()
    
    return "%d年%d月%d日 星期%s，%s，时间：%02d:%02d，天气：%s，气温：%d度" % [
        d.year, d.month, d.day, w, current_period, current_hour, current_minute,
        weather_text, weather_cfg.get("temperature", 20)
    ]

func _is_valid_period(period: String) -> bool:
    return period == PERIOD_MORNING or period == PERIOD_AFTERNOON or period == PERIOD_EVENING or period == PERIOD_NIGHT

func _resolve_period_from_hour(hour: int) -> String:
    if hour >= 6 and hour < 12:
        return PERIOD_MORNING
    if hour >= 12 and hour < 17:
        return PERIOD_AFTERNOON
    if hour >= 17 and hour < 20:
        return PERIOD_EVENING
    return PERIOD_NIGHT
