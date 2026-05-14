class_name WeatherManager
extends Node

signal weather_updated(desc: String, temp: float)

var current_weather_desc: String = "未知"
var current_temp: float = 20.0
var is_weather_ready: bool = false

var ip_http: HTTPRequest
var weather_http: HTTPRequest

func _ready() -> void:
    ip_http = HTTPRequest.new()
    add_child(ip_http)
    ip_http.request_completed.connect(_on_ip_completed)

    weather_http = HTTPRequest.new()
    add_child(weather_http)
    weather_http.request_completed.connect(_on_weather_completed)

    # 启动时获取一次
    fetch_weather()

    # 每小时更新一次天气
    var timer = Timer.new()
    timer.wait_time = 3600
    timer.autostart = true
    timer.timeout.connect(fetch_weather)
    add_child(timer)

func fetch_weather() -> void:
    ip_http.request("http://ip-api.com/json/")

func _on_ip_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
    if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
        var json = JSON.new()
        if json.parse(body.get_string_from_utf8()) == OK:
            var data = json.get_data()
            if data.has("lat") and data.has("lon"):
                var lat = data["lat"]
                var lon = data["lon"]
                var url = "https://api.open-meteo.com/v1/forecast?latitude=%s&longitude=%s&current_weather=true" % [str(lat), str(lon)]
                weather_http.request(url)

func _on_weather_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
    if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
        var json = JSON.new()
        if json.parse(body.get_string_from_utf8()) == OK:
            var data = json.get_data()
            if data.has("current_weather"):
                var cw = data["current_weather"]
                current_temp = float(cw.get("temperature", 20.0))
                var code = int(cw.get("weathercode", 0))
                current_weather_desc = _get_weather_desc(code)
                is_weather_ready = true
                weather_updated.emit(current_weather_desc, current_temp)
                print("[WeatherManager] 现实环境同步 - 天气: ", current_weather_desc, " | 气温: ", current_temp, "°C")

func _get_weather_desc(code: int) -> String:
    if code == 0: return "晴朗"
    elif code in [1, 2]: return "多云"
    elif code == 3: return "阴天"
    elif code in [45, 48]: return "有雾"
    elif code in [51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82]: return "下雨"
    elif code in [71, 73, 75, 77, 85, 86]: return "下雪"
    elif code in [95, 96, 99]: return "雷阵雨"
    return "未知"
