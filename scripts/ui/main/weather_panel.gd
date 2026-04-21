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
	var time_dict = Time.get_time_dict_from_system()
	var date_dict = Time.get_date_dict_from_system()
	
	time_label.text = "%02d:%02d" % [time_dict.hour, time_dict.minute]
	period_label.text = "上午" if time_dict.hour < 12 else "下午"
	
	var weekday_str = ["日", "一", "二", "三", "四", "五", "六"]
	date_label.text = "%d/%02d/%02d(周%s)" % [date_dict.year, date_dict.month, date_dict.day, weekday_str[date_dict.weekday]]

func _simulate_weather() -> void:
	# 模拟天气逻辑
	var hour = Time.get_time_dict_from_system().hour
	var is_day = hour >= 6 and hour < 18
	
	var rand = randi() % 100
	var weather_type = "sunny"
	var temp_offset = randi_range(-3, 3)
	var base_temp = 22 if is_day else 15
	var temp = base_temp + temp_offset
	
	if rand < 60:
		weather_type = "sunny"
		weather_icon.texture = tex_sunny
		loc_label.text = "东京 %d°C" % temp
	elif rand < 85:
		weather_type = "cloudy"
		weather_icon.texture = tex_cloudy
		loc_label.text = "东京 %d°C" % (temp - 2)
	else:
		weather_type = "rainy"
		weather_icon.texture = tex_rainy
		loc_label.text = "东京 %d°C" % (temp - 4)
