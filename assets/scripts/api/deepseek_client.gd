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

var chat_http: HTTPRequest
var emotion_http: HTTPRequest
var memory_http: HTTPRequest
var options_http: HTTPRequest

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
    var api_messages = [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": user_message}
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

func send_options_generation(last_ai_reply: String) -> void:
    if GameDataManager.config.api_key.is_empty():
        return
        
    # 如果调用时不在树上（极小概率，但为了安全起见），等待其重新入树
    while not is_inside_tree():
        await Engine.get_main_loop().process_frame
        
    var system_prompt = GameDataManager.prompt_manager.build_options_prompt(GameDataManager.profile, last_ai_reply)
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

func _on_chat_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
    _handle_response(result, response_code, body, chat_request_completed, chat_request_failed)

func _on_emotion_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
    _handle_response(result, response_code, body, emotion_request_completed, emotion_request_failed)

func _on_memory_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
    _handle_response(result, response_code, body, memory_request_completed, memory_request_failed)

func _on_options_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
    _handle_response(result, response_code, body, options_request_completed, options_request_failed)

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
