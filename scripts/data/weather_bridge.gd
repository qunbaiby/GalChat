extends Node

var story_time_manager: Node
var weather_manager: Node
var env_system: Node
var _debug_server_url := "http://127.0.0.1:7777/event"
var _debug_session_id := "yellow-screen-tint"
var _debug_env_loaded := false
var _debug_last_report_ms := {}
var _active_weather_id: String = ""

func _ready() -> void:
	story_time_manager = GameDataManager.story_time_manager
	weather_manager = GameDataManager.weather_manager
	
	if not story_time_manager or not weather_manager:
		# #region debug-point B:bridge-missing-managers
		_debug_report(
			"B",
			"weather_bridge.gd:_ready",
			"[DEBUG] weather bridge managers missing",
			{
				"has_story_time_manager": story_time_manager != null,
				"has_weather_manager": weather_manager != null
			}
		)
		# #endregion
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
		# #region debug-point A:bridge-ready
		_debug_report(
			"A",
			"weather_bridge.gd:_ready",
			"[DEBUG] weather bridge created environment system",
			{
				"env_system_name": env_system.name,
				"overlay_layer": env_system.overlay_layer,
				"time_running": env_system.time_running,
				"enable_weather_spawning": env_system.enable_weather_spawning,
				"initial_weather_desc": weather_manager.current_weather_desc
			}
		)
		# #endregion

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
	# #region debug-point C:bridge-sync-time
	_debug_report(
		"C",
		"weather_bridge.gd:_sync_time",
		"[DEBUG] weather bridge synced time",
		{
			"target_day": target_day,
			"target_hour": snapped(target_hour, 0.001),
			"story_hour": story_time_manager.current_hour,
			"story_minute": story_time_manager.current_minute
		},
		1500
	)
	# #endregion

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
	# #region debug-point A:bridge-sync-weather
	_debug_report(
		"A",
		"weather_bridge.gd:_sync_weather",
		"[DEBUG] weather bridge synced weather",
		{
			"source_desc": desc,
			"target_weather_id": target_weather_id,
			"weather_summary": env_system.get_weather_summary() if env_system and env_system.has_method("get_weather_summary") else {}
		},
		1500
	)
	# #endregion


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
	# #region debug-point D:bridge-overlay-target
	_debug_report(
		"D",
		"weather_bridge.gd:set_weather_overlay_target",
		"[DEBUG] weather bridge updated overlay target",
		{
			"has_target": is_instance_valid(target),
			"target_path": str(target.get_path()) if is_instance_valid(target) else ""
		}
	)
	# #endregion


func _debug_ensure_env_loaded() -> void:
	if _debug_env_loaded:
		return
	_debug_env_loaded = true
	var env_path := ProjectSettings.globalize_path("res://.dbg/yellow-screen-tint.env")
	if not FileAccess.file_exists(env_path):
		return
	var env_file := FileAccess.open(env_path, FileAccess.READ)
	if env_file == null:
		return
	while not env_file.eof_reached():
		var line := env_file.get_line().strip_edges()
		if line.begins_with("DEBUG_SERVER_URL="):
			_debug_server_url = line.trim_prefix("DEBUG_SERVER_URL=")
		elif line.begins_with("DEBUG_SESSION_ID="):
			_debug_session_id = line.trim_prefix("DEBUG_SESSION_ID=")


func _debug_report(hypothesis_id: String, location: String, msg: String, data: Dictionary = {}, min_interval_ms: int = 0) -> void:
	_debug_ensure_env_loaded()
	var now := Time.get_ticks_msec()
	var throttle_key := "%s|%s" % [hypothesis_id, location]
	var last_sent := int(_debug_last_report_ms.get(throttle_key, 0))
	if min_interval_ms > 0 and now - last_sent < min_interval_ms:
		return
	_debug_last_report_ms[throttle_key] = now
	var request := HTTPRequest.new()
	add_child(request)
	request.request_completed.connect(func(_result: int, _response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
		request.queue_free()
	)
	var err := request.request(
		_debug_server_url,
		PackedStringArray(["Content-Type: application/json"]),
		HTTPClient.METHOD_POST,
		JSON.stringify({
			"sessionId": _debug_session_id,
			"runId": "pre-fix",
			"hypothesisId": hypothesis_id,
			"location": location,
			"msg": msg,
			"data": data,
			"ts": Time.get_unix_time_from_system() * 1000.0
		})
	)
	if err != OK:
		request.queue_free()
