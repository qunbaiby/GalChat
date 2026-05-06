extends PanelContainer

@onready var weather_icon: TextureRect = $Margin/HBox/LeftVBox/WeatherIcon
@onready var loc_label: Label = $Margin/HBox/LeftVBox/LocLabel
@onready var time_label: Label = $Margin/HBox/RightVBox/TimeHBox/TimeLabel
@onready var period_label: Label = $Margin/HBox/RightVBox/TimeHBox/PeriodMargin/PeriodLabel
@onready var date_label: Label = $Margin/HBox/RightVBox/DateLabel

var tex_sunny: Texture2D = preload("res://assets/images/icons/ui/weather/sunny.svg")
var tex_cloudy: Texture2D = preload("res://assets/images/icons/ui/weather/cloudy.svg")
var tex_rainy: Texture2D = preload("res://assets/images/icons/ui/weather/rainy.svg")

var _update_timer: Timer

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
	# 时间的推进将由剧情行动力消耗或事件系统（StoryTimeManager.advance_period 等）来手动触发。
	var time_hour = GameDataManager.story_time_manager.current_hour
	var time_minute = GameDataManager.story_time_manager.current_minute
	var period_str = GameDataManager.story_time_manager.current_period
	var date_dict = GameDataManager.story_time_manager.get_current_date_dict()
	
	time_label.text = "%02d:%02d" % [time_hour, time_minute]
	period_label.text = period_str
	
	var weekday_str = ["日", "一", "二", "三", "四", "五", "六"]
	date_label.text = "%d/%02d/%02d(周%s)" % [date_dict.year, date_dict.month, date_dict.day, weekday_str[date_dict.weekday]]

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
