extends Node
class_name DeepSeekClient

signal api_request_completed(response: Dictionary)
signal api_request_failed(error_message: String)

var http_request: HTTPRequest

func _ready() -> void:
    http_request = HTTPRequest.new()
    http_request.timeout = 5.0 # 网络超时 5 s 未响应
    add_child(http_request)
    http_request.request_completed.connect(_on_request_completed)

func send_chat_message(user_message: String) -> void:
    var api_key = GameDataManager.config.api_key
    if api_key.is_empty():
        api_request_failed.emit("API Key未设置，请在设置界面配置。")
        return
        
    var url = "https://api.deepseek.com/v1/chat/completions"
    var headers = [
        "Content-Type: application/json",
        "Authorization: Bearer " + api_key
    ]
    
    var system_prompt = _build_system_prompt()
    var body = {
        "model": GameDataManager.config.model,
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_message}
        ],
        "temperature": GameDataManager.config.temperature,
        "max_tokens": GameDataManager.config.max_tokens
    }
    
    var error = http_request.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
    if error != OK:
        api_request_failed.emit("网络请求发送失败。")

func _build_system_prompt() -> String:
    var profile = GameDataManager.profile
    var time_str = Time.get_datetime_string_from_system()
    return "你扮演一名AI伴侣，名字叫{name}，{age}岁。\n人设：{desc}\n当前真实时间：{time}\n当前亲密度：{intimacy}/100\n当前心情：{mood}\n当前信任度：{trust}/100\n请根据以上信息及玩家历史选择，以{name}的口吻进行回复。回复中请在文本中插入指令标签，如 [mood:+5] [expr:blush]，来表达你的情绪变化和表情变化。可用的表情(expr)有：neutral, shy, happy, sad, surprise, angry, blush。亲密度正向每句增加[intimacy:+0.5]，负向减少[intimacy:-0.3]。".format({
        "name": profile.char_name,
        "age": str(profile.age),
        "desc": profile.description,
        "time": time_str,
        "intimacy": str(profile.intimacy),
        "mood": str(profile.mood),
        "trust": str(profile.trust)
    })

func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
    if result == HTTPRequest.RESULT_TIMEOUT:
        api_request_failed.emit("ayrrha 似乎走神了...")
        return
        
    if response_code == 200:
        var json = JSON.new()
        var error = json.parse(body.get_string_from_utf8())
        if error == OK:
            api_request_completed.emit(json.get_data())
        else:
            api_request_failed.emit("返回数据解析失败")
    else:
        if response_code == 0:
            api_request_failed.emit("ayrrha 似乎走神了...")
        else:
            api_request_failed.emit("API 请求错误，状态码: " + str(response_code))
