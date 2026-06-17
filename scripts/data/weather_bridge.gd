extends Node

var story_time_manager: Node
var weather_manager: Node
var env_system: Node
var _active_weather_id: String = ""

func _ready() -> void:
	story_time_manager = GameDataManager.story_time_manager
	weather_manager = GameDataManager.weather_manager
	
	if not story_time_manager or not weather_manager:
		return
		
	# 载入环境系统
	var env_scene = load("res://addons/romestead_weather_free/weather_system.tscn")
	if env_scene:
		env_system = env_scene.instantiate()
		env_system.name = "RomesteadEnvironmentSystem"
		# 关闭自带的时间流逝和天气随机生成，由我们的系统完全接管
		env_system.time_running = false
		env_system.enable_weather_spawning = false
		env_system.overlay_layer = 0 # 保证雨雪效果不遮挡上层UI
		add_child(env_system)
		
		# 监听我们的时间变化
		story_time_manager.time_advanced.connect(_on_time_advanced)
		
		# 监听我们的天气变化
		weather_manager.weather_updated.connect(_on_weather_updated)
		
		# 初始同步
		_sync_time()
		_sync_weather(_resolve_active_weather_desc())

func _process(delta: float) -> void:
	# 确保时间戳平滑（比如在UI时钟一分钟一分钟跳动时）
	if env_system and story_time_manager:
		var target_day = story_time_manager.current_day_offset
		var target_hour = story_time_manager.current_hour + story_time_manager.current_minute / 60.0
		
		# 避免每帧强制重置导致性能问题，只有当差值超过一定阈值才硬同步
		var current_env_day = env_system.current_day
		var current_env_hour = env_system.current_hour
		
		if current_env_day != target_day or abs(current_env_hour - target_hour) > 0.02:
			env_system.set_day_and_hour(target_day, target_hour)

func _on_time_advanced(days: int, period: String) -> void:
	_sync_time()
	_sync_weather(_resolve_active_weather_desc())

func _sync_time() -> void:
	if not env_system or not story_time_manager:
		return
	var target_day = story_time_manager.current_day_offset
	var target_hour = float(story_time_manager.current_hour) + (float(story_time_manager.current_minute) / 60.0)
	env_system.set_day_and_hour(target_day, target_hour)

func _on_weather_updated(desc: String, temp: float) -> void:
	if _has_story_weather_config():
		_sync_weather(_resolve_active_weather_desc())
		return
	_sync_weather(desc)

func _sync_weather(desc: String) -> void:
	if not env_system:
		return
		
	# 将我们系统的天气描述映射到插件的天气 ID
	var target_weather_id: String = _map_weather_desc_to_plugin_id(desc)
	if target_weather_id == _active_weather_id:
		return
	
	# 设置天气
	if target_weather_id == "normal":
		if env_system.has_method("fade_out_all_weather"):
			env_system.fade_out_all_weather()
		else:
			env_system.clear_weather()
	else:
		# 半径设大一点，覆盖全屏，并使用平滑过渡而不是直接替换
		if env_system.has_method("transition_preview_weather"):
			env_system.transition_preview_weather(target_weather_id, 4000.0, 99999.0)
		else:
			env_system.set_preview_weather(target_weather_id, 4000.0, 99999.0)
	_active_weather_id = target_weather_id


func _resolve_active_weather_desc() -> String:
	if _has_story_weather_config():
		return story_time_manager.get_story_weather_desc()
	if weather_manager:
		return weather_manager.current_weather_desc
	return "晴天"


func _has_story_weather_config() -> bool:
	if not story_time_manager:
		return false
	if not story_time_manager.has_method("get_current_day_config"):
		return false
	var day_cfg_value: Variant = story_time_manager.get_current_day_config()
	if not (day_cfg_value is Dictionary):
		return false
	var day_cfg: Dictionary = day_cfg_value
	return day_cfg.has("weather")


func _map_weather_desc_to_plugin_id(desc: String) -> String:
	var normalized := desc.strip_edges().to_lower()
	if normalized in ["多云", "cloudy", "partly_cloudy"]:
		return "cloudy"
	if normalized in ["阴天", "overcast"]:
		return "overcast"
	if normalized in ["有雾", "雾天", "foggy", "fog", "mist"]:
		return "foggy"
	if normalized in ["雨天", "下雨", "rainy", "rain", "shower"]:
		return "rainy"
	if normalized in ["雷雨", "雷阵雨", "thunder", "storm", "thunderstorm"]:
		return "thunder"
	if normalized in ["雪天", "下雪", "snow", "snowy", "blizzard"]:
		return "snow"
	return "normal"


func set_weather_overlay_target(target: Control) -> void:
	if not env_system or not env_system.has_method("set_overlay_target"):
		return
	env_system.set_overlay_target(target)
