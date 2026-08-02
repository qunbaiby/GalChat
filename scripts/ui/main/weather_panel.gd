extends PanelContainer

@onready var weather_icon: TextureRect = $Margin/HBox/LeftVBox/WeatherIcon
@onready var loc_label: Label = $Margin/HBox/LeftVBox/LocLabel
@onready var time_label: Label = $Margin/HBox/RightVBox/TimeHBox/TimeLabel
@onready var period_label: Label = $Margin/HBox/RightVBox/TimeHBox/PeriodMargin/PeriodLabel
@onready var date_label: Label = $Margin/HBox/RightVBox/DateLabel

var tex_sunny: Texture2D = preload("res://assets/images/icons/ui/weather/sunny.svg")
var tex_cloudy: Texture2D = preload("res://assets/images/icons/ui/weather/cloudy.svg")
var tex_rainy: Texture2D = preload("res://assets/images/icons/ui/weather/rainy.svg")

const TIME_TWEEN_DURATION := 0.75

var _update_timer: Timer
var _displayed_minutes := 0
var _displayed_day_offset := 0
var _time_display_initialized := false
var _time_tween: Tween
var _time_tween_target_minutes := -1

func _ready() -> void:
	_update_time()
	
	_update_timer = Timer.new()
	_update_timer.wait_time = 1.0
	_update_timer.autostart = true
	_update_timer.timeout.connect(_update_time)
	add_child(_update_timer)

	_simulate_weather()
	
	# Optional: connect a slow timer to randomize weather occasionally
	var weather_timer = Timer.new()
	weather_timer.wait_time = 600.0 # 10 minutes
	weather_timer.autostart = true
	weather_timer.timeout.connect(_simulate_weather)
	add_child(weather_timer)

func _update_time() -> void:
	# 这里只做显示更新，不再让时间随现实秒数狂奔。
	# 时间的推进将由剧情精力消耗或事件系统（StoryTimeManager.advance_period 等）来手动触发。
	var time_manager = GameDataManager.story_time_manager
	var time_hour = int(time_manager.current_hour)
	var time_minute = int(time_manager.current_minute)
	var period_str = time_manager.get_detailed_period_label(time_hour) if time_manager.has_method("get_detailed_period_label") else time_manager.current_period
	var date_dict = GameDataManager.story_time_manager.get_current_date_dict()
	var target_minutes: int = time_hour * 60 + time_minute
	var target_day_offset: int = int(time_manager.current_day_offset)
	
	if not _time_display_initialized:
		_time_display_initialized = true
		_displayed_minutes = target_minutes
		_displayed_day_offset = target_day_offset
		_set_displayed_time(target_minutes)
	elif target_day_offset != _displayed_day_offset or target_minutes < _displayed_minutes:
		_stop_time_tween()
		_displayed_minutes = target_minutes
		_displayed_day_offset = target_day_offset
		_set_displayed_time(target_minutes)
	elif target_minutes > _displayed_minutes and target_minutes != _time_tween_target_minutes:
		_animate_time_to(target_minutes)
	period_label.text = period_str
	
	var weekday_str = ["日", "一", "二", "三", "四", "五", "六"]
	date_label.text = "%d/%02d/%02d(周%s)" % [date_dict.year, date_dict.month, date_dict.day, weekday_str[date_dict.weekday]]

func _animate_time_to(target_minutes: int) -> void:
	_stop_time_tween()
	var start_minutes := _displayed_minutes
	_time_tween_target_minutes = target_minutes
	_time_tween = create_tween()
	_time_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_time_tween.tween_method(
		func(value: float) -> void:
			_displayed_minutes = clampi(roundi(value), 0, 1439)
			_set_displayed_time(_displayed_minutes),
		float(start_minutes),
		float(target_minutes),
		TIME_TWEEN_DURATION
	)
	_time_tween.tween_callback(func() -> void:
		_displayed_minutes = target_minutes
		_set_displayed_time(target_minutes)
		_time_tween_target_minutes = -1
	)

func _stop_time_tween() -> void:
	if _time_tween != null and _time_tween.is_valid():
		_time_tween.kill()
	_time_tween = null
	_time_tween_target_minutes = -1

func _set_displayed_time(total_minutes: int) -> void:
	var display_hour := floori(total_minutes / 60.0)
	var display_minute := total_minutes % 60
	time_label.text = "%02d:%02d" % [display_hour, display_minute]

func _simulate_weather() -> void:
	# 从虚构的剧情时间系统读取固定的天气数据
	var day_config = GameDataManager.story_time_manager.get_current_day_config()
	var weather_type = day_config.get("weather", "sunny")
	var temp = day_config.get("temperature", 20)
	
	if weather_type == "sunny":
		weather_icon.texture = tex_sunny
		loc_label.text = "星律 %d°C" % temp
	elif weather_type == "cloudy":
		weather_icon.texture = tex_cloudy
		loc_label.text = "星律 %d°C" % temp
	elif weather_type == "rainy":
		weather_icon.texture = tex_rainy
		loc_label.text = "星律 %d°C" % temp
	else:
		weather_icon.texture = tex_sunny
		loc_label.text = "星律 %d°C" % temp
