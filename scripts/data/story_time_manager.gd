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

# 故事设定的基准起始日期（例如 2026年3月7日 星期六）
var start_year: int = 2026
var start_month: int = 3
var start_day: int = 7

# 配置数据（从 JSON 加载）
var time_config: Dictionary = {}

func _init() -> void:
    _load_config()
    _load_save_data()

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

func _load_save_data() -> void:
    var path = "user://story_time_save.json"
    if FileAccess.file_exists(path):
        var file = FileAccess.open(path, FileAccess.READ)
        var json = JSON.new()
        if json.parse(file.get_as_text()) == OK:
            var data = json.data
            current_day_offset = data.get("current_day_offset", 0)
            current_period = data.get("current_period", PERIOD_MORNING)
            current_hour = data.get("current_hour", 8)
            current_minute = data.get("current_minute", 0)

func save_data() -> void:
    var data = {
        "current_day_offset": current_day_offset,
        "current_period": current_period,
        "current_hour": current_hour,
        "current_minute": current_minute
    }
    var file = FileAccess.open("user://story_time_save.json", FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify(data, "\t"))
        file.close()

# 推进时间（天数）
func advance_day(days: int = 1) -> void:
    current_day_offset += days
    current_period = PERIOD_MORNING
    current_hour = 8
    current_minute = 0
    # 移除自动保存，交由游戏核心的存档系统管理
    # save_data()
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
    if current_minute >= 60:
        var hours_added = current_minute / 60
        current_hour += hours_added
        current_minute %= 60
        
        # 如果时间自然流逝跨越了时段，也自动更新时段文本（但不主动触发advance_day的强制重置逻辑）
        if current_hour >= 24:
            current_hour = current_hour % 24
            current_day_offset += 1
            
        if current_hour >= 6 and current_hour < 12:
            current_period = PERIOD_MORNING
        elif current_hour >= 12 and current_hour < 17:
            current_period = PERIOD_AFTERNOON
        elif current_hour >= 17 and current_hour < 20:
            current_period = PERIOD_EVENING
        else:
            current_period = PERIOD_NIGHT
            
    # 移除自动保存，交由游戏核心的存档系统管理
    # save_data()

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
    if time_config.has("daily_data"):
        for day_data in time_config["daily_data"]:
            if int(day_data.get("day_offset", -1)) == offset:
                return day_data
    return {
        "weather": "sunny",
        "temperature": 22,
        "events": []
    }

# 获取当前日期的天气与事件配置
func get_current_day_config() -> Dictionary:
    return get_day_config(current_day_offset)

# 供大模型提示词使用的格式化剧情时间字符串
func get_story_time_string() -> String:
    var d = get_current_date_dict()
    var weekday_str = ["日", "一", "二", "三", "四", "五", "六"]
    var w = weekday_str[d.weekday]
    var weather_cfg = get_current_day_config()
    var weather_text = "晴天"
    if weather_cfg.get("weather") == "cloudy": weather_text = "多云"
    elif weather_cfg.get("weather") == "rainy": weather_text = "雨天"
    
    return "%d年%d月%d日 星期%s，%s，时间：%02d:%02d，天气：%s，气温：%d度" % [
        d.year, d.month, d.day, w, current_period, current_hour, current_minute,
        weather_text, weather_cfg.get("temperature", 20)
    ]
