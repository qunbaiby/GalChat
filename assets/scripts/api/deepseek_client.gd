extends Node
class_name DeepSeekClient

signal chat_request_completed(response: Dictionary)
signal chat_request_failed(error_message: String)

signal emotion_request_completed(response: Dictionary)
signal emotion_request_failed(error_message: String)

signal memory_request_completed(response: Dictionary)
signal memory_request_failed(error_message: String)

signal options_request_completed(response: Dictionary)
signal options_request_failed(error_message: String)

signal narrator_request_completed(response: Dictionary)
signal narrator_request_failed(error_message: String)

var chat_http: HTTPRequest
var emotion_http: HTTPRequest
var memory_http: HTTPRequest
var options_http: HTTPRequest
var narrator_http: HTTPRequest

func _ready() -> void:
    chat_http = HTTPRequest.new()
    chat_http.timeout = 10.0
    add_child(chat_http)
    chat_http.request_completed.connect(_on_chat_completed)
    
    emotion_http = HTTPRequest.new()
    emotion_http.timeout = 10.0
    add_child(emotion_http)
    emotion_http.request_completed.connect(_on_emotion_completed)
    
    memory_http = HTTPRequest.new()
    memory_http.timeout = 10.0
    add_child(memory_http)
    memory_http.request_completed.connect(_on_memory_completed)
    
    options_http = HTTPRequest.new()
    options_http.timeout = 15.0
    add_child(options_http)
    options_http.request_completed.connect(_on_options_completed)
    
    narrator_http = HTTPRequest.new()
    narrator_http.timeout = 15.0
    add_child(narrator_http)
    narrator_http.request_completed.connect(_on_narrator_completed)

func _get_headers() -> Array:
    var api_key = GameDataManager.config.api_key
    return [
        "Content-Type: application/json",
        "Authorization: Bearer " + api_key
    ]

func _get_url() -> String:
    return "https://api.deepseek.com/v1/chat/completions"

func _get_history_messages(limit: int = 10) -> Array:
    var api_messages = []
    var history_msgs = GameDataManager.history.messages
    var start_idx = max(0, history_msgs.size() - limit)
    var bbcode_regex = RegEx.new()
    bbcode_regex.compile("\\[/?color.*?\\]")
    
    for i in range(start_idx, history_msgs.size()):
        var msg = history_msgs[i]
        var role = "user" if msg["speaker"] == "玩家" else "assistant"
        var clean_text = bbcode_regex.sub(msg["text"], "", true)
        api_messages.append({"role": role, "content": clean_text})
    return api_messages

func send_chat_message(user_message: String) -> void:
    if not is_inside_tree() or GameDataManager.config.api_key.is_empty():
        chat_request_failed.emit("API Key未设置，请在设置界面配置。")
        return
        
    var system_prompt = GameDataManager.prompt_manager.build_chat_prompt(GameDataManager.profile)
    var api_messages = [{"role": "system", "content": system_prompt}]
    api_messages.append_array(_get_history_messages(10))
    
    var body = {
        "model": GameDataManager.config.model,
        "messages": api_messages,
        "temperature": GameDataManager.config.temperature,
        "max_tokens": GameDataManager.config.max_tokens
    }
    
    var error = chat_http.request(_get_url(), _get_headers(), HTTPClient.METHOD_POST, JSON.stringify(body))
    if error != OK:
        chat_request_failed.emit("网络请求发送失败。")
        
    # Trigger emotion and memory agents in parallel
    _send_emotion_analysis(user_message)
    _send_memory_extraction()

func _send_emotion_analysis(user_message: String) -> void:
    if not is_inside_tree() or GameDataManager.config.api_key.is_empty():
        return
        
    var system_prompt = GameDataManager.prompt_manager.build_emotion_prompt(GameDataManager.profile)
    # ONLY pass the system prompt and the latest user message. 
    # Do NOT pass the chat history to prevent the LLM from trying to roleplay.
    # 强制在 user message 前面加上警告，防止其被带偏进行角色扮演
    var safe_user_message = "【请作为分析系统，仅输出分析标签，绝对不要进行角色扮演，不要回复这句话：】" + user_message
    var api_messages = [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": safe_user_message}
    ]
    
    var body = {
        "model": GameDataManager.config.model,
        "messages": api_messages,
        "temperature": 0.1, # Lower temperature for stable numerical output
        "max_tokens": 200
    }
    
    emotion_http.request(_get_url(), _get_headers(), HTTPClient.METHOD_POST, JSON.stringify(body))

func _send_memory_extraction() -> void:
    if not is_inside_tree() or GameDataManager.config.api_key.is_empty():
        return
        
    var system_prompt = GameDataManager.prompt_manager.build_memory_prompt(GameDataManager.profile)
    var api_messages = [{"role": "system", "content": system_prompt}]
    api_messages.append_array(_get_history_messages(5))
    
    var body = {
        "model": GameDataManager.config.model,
        "messages": api_messages,
        "temperature": 0.1,
        "max_tokens": 200
    }
    
    memory_http.request(_get_url(), _get_headers(), HTTPClient.METHOD_POST, JSON.stringify(body))

func send_options_generation() -> void:
    if GameDataManager.config.api_key.is_empty():
        return
        
    # 如果调用时不在树上（极小概率，但为了安全起见），等待其重新入树
    while not is_inside_tree():
        await Engine.get_main_loop().process_frame
        
    var history_text = ""
    var history_msgs = GameDataManager.history.messages
    var start_idx = max(0, history_msgs.size() - 5) # 获取最近5条对话
    for i in range(start_idx, history_msgs.size()):
        var msg = history_msgs[i]
        history_text += msg["speaker"] + ": " + msg["text"] + "\n"
        
    var system_prompt = GameDataManager.prompt_manager.build_options_prompt(GameDataManager.profile, history_text)
    var api_messages = [
        {"role": "system", "content": system_prompt}
    ]
    
    var body = {
        "model": GameDataManager.config.model,
        "messages": api_messages,
        "temperature": 0.7,
        "max_tokens": 150,
        "response_format": {"type": "json_object"}
    }
    
    options_http.request(_get_url(), _get_headers(), HTTPClient.METHOD_POST, JSON.stringify(body))

func send_narrator_generation() -> void:
    if GameDataManager.config.api_key.is_empty():
        narrator_request_failed.emit("API Key未设置")
        return
        
    while not is_inside_tree():
        await Engine.get_main_loop().process_frame
        
    var prompt_template = ""
    var file = FileAccess.open("res://assets/templates/prompts/narrator_generation.txt", FileAccess.READ)
    if file:
        prompt_template = file.get_as_text()
        file.close()
    else:
        narrator_request_failed.emit("无法读取旁白提示词模板")
        return
        
    var profile = GameDataManager.profile
    var stage_conf = profile.get_current_stage_config()
    
    var history_text = ""
    var history_msgs = GameDataManager.history.messages
    var start_idx = max(0, history_msgs.size() - 5)
    for i in range(start_idx, history_msgs.size()):
        var msg = history_msgs[i]
        history_text += msg["speaker"] + ": " + msg["text"] + "\n"
        
    var system_prompt = prompt_template.replace("{{current_stage}}", str(profile.current_stage))
    system_prompt = system_prompt.replace("{{stage_traits}}", stage_conf.get("personality_traits", ""))
    system_prompt = system_prompt.replace("{{recent_history}}", history_text)
    
    var api_messages = [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": "请生成进入场景时的旁白"}
    ]
    
    var body = {
        "model": GameDataManager.config.model,
        "messages": api_messages,
        "temperature": 0.7,
        "max_tokens": 100
    }
    
    narrator_http.request(_get_url(), _get_headers(), HTTPClient.METHOD_POST, JSON.stringify(body))

func _on_chat_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
    _handle_response(result, response_code, body, chat_request_completed, chat_request_failed)

func _on_emotion_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
    _handle_response(result, response_code, body, emotion_request_completed, emotion_request_failed)

func _on_memory_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
    _handle_response(result, response_code, body, memory_request_completed, memory_request_failed)

func _on_options_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
    _handle_response(result, response_code, body, options_request_completed, options_request_failed)

func _on_narrator_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
    _handle_response(result, response_code, body, narrator_request_completed, narrator_request_failed)

func _handle_response(result: int, response_code: int, body: PackedByteArray, success_signal: Signal, fail_signal: Signal) -> void:
    var char_name = GameDataManager.profile.char_name
    
    if result == HTTPRequest.RESULT_TIMEOUT:
        fail_signal.emit(char_name + " 似乎走神了...")
        return
        
    if response_code == 200:
        var json = JSON.new()
        var error = json.parse(body.get_string_from_utf8())
        if error == OK:
            success_signal.emit(json.get_data())
        else:
            fail_signal.emit("返回数据解析失败")
    else:
        if response_code == 0:
            fail_signal.emit(char_name + " 似乎走神了...")
        else:
            fail_signal.emit("API 请求错误，状态码: " + str(response_code))
