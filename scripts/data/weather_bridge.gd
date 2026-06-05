extends Node

var story_time_manager: Node
var weather_manager: Node
var env_system: Node

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
		_sync_weather(weather_manager.current_weather_desc)

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

func _sync_time() -> void:
	if not env_system or not story_time_manager:
		return
	var target_day = story_time_manager.current_day_offset
	var target_hour = float(story_time_manager.current_hour) + (float(story_time_manager.current_minute) / 60.0)
	env_system.set_day_and_hour(target_day, target_hour)

func _on_weather_updated(desc: String, temp: float) -> void:
	_sync_weather(desc)

func _sync_weather(desc: String) -> void:
	if not env_system:
		return
		
	# 将我们系统的天气描述映射到插件的天气 ID
	var target_weather_id = "normal"
	
	if "雨" in desc:
		target_weather_id = "rainy"
		if "雷" in desc or "暴" in desc:
			target_weather_id = "thunder"
	elif "雪" in desc:
		target_weather_id = "snow"
	elif "阴" in desc or "云" in desc or "雾" in desc:
		target_weather_id = "normal" # 如果插件有cloudy可以换，没有就用normal
	
	# 设置天气
	if target_weather_id == "normal":
		env_system.clear_weather()
	else:
		# 半径设大一点，覆盖全屏
		env_system.set_preview_weather(target_weather_id, 4000.0, 99999.0)
