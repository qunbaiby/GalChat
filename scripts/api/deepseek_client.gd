extends Node
class_name DeepSeekClient

signal chat_request_completed(response: Dictionary)
signal chat_request_failed(error_message: String)
signal chat_stream_delta(delta_text: String)
signal chat_stream_started()

signal emotion_request_completed(response: Dictionary)
signal emotion_request_failed(error_message: String)

signal memory_request_completed(response: Dictionary)
signal memory_request_failed(error_message: String)

signal options_request_completed(response: Dictionary)
signal options_request_failed(error_message: String)

signal narrator_request_completed(response: Dictionary)
signal narrator_request_failed(error_message: String)

signal character_mood_request_completed(response: Dictionary)
signal character_mood_request_failed(error_message: String)

var chat_http: HTTPRequest
var emotion_http: HTTPRequest
var memory_http: HTTPRequest
var options_http: HTTPRequest
var narrator_http: HTTPRequest
var character_mood_http: HTTPRequest

var _chat_stream_client: HTTPClient
var _chat_stream_active: bool = false
var _chat_stream_request_sent: bool = false
var _chat_stream_body: String = ""
var _chat_stream_headers: Array = []
var _chat_stream_sse_buffer: String = ""
var _chat_stream_full_text: String = ""
var _chat_stream_response_code: int = 0

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
    
    character_mood_http = HTTPRequest.new()
    character_mood_http.timeout = 10.0
    add_child(character_mood_http)
    character_mood_http.request_completed.connect(_on_character_mood_completed)

func _get_headers() -> Array:
    var api_key = GameDataManager.config.api_key
    return [
        "Content-Type: application/json",
        "Authorization: Bearer " + api_key
    ]

func _get_url() -> String:
    return "https://api.deepseek.com/v1/chat/completions"

func _get_history_messages(limit: int = 10, is_chat: bool = true) -> Array:
    var api_messages = []
    var history_msgs = GameDataManager.history.messages
    var start_idx = max(0, history_msgs.size() - limit)
    var bbcode_regex = RegEx.new()
    bbcode_regex.compile("\\[/?color.*?\\]")
    
    for i in range(start_idx, history_msgs.size()):
        var msg = history_msgs[i]
        var role = "user" if msg["speaker"] == "玩家" else "assistant"
        var clean_text = bbcode_regex.sub(msg["text"], "", true)
        
        # 对最后一条历史记录打上强提示标记，确保AI的注意力集中在此
        if i == history_msgs.size() - 1 and is_chat:
            clean_text += " <--- 【系统提示：这是你们上次聊天的最后一句话，请顺着这个话题继续延展，不要生硬地开启新话题】"
            
        api_messages.append({"role": role, "content": clean_text})
    return api_messages

func send_chat_message(user_message: String) -> void:
    send_chat_message_stream(user_message)

func send_chat_message_stream(user_message: String) -> void:
    if not is_inside_tree() or GameDataManager.config.api_key.is_empty():
        chat_request_failed.emit("API Key未设置，请在设置界面配置。")
        return
        
    if _chat_stream_active:
        _stop_chat_stream()
        
    # 获取用户输入的 embedding
    var query_embedding = await DoubaoEmbeddingClient.get_embedding(user_message)
        
    var system_prompt = GameDataManager.prompt_manager.build_chat_prompt(GameDataManager.profile, user_message, query_embedding)
    var api_messages = [{"role": "system", "content": system_prompt}]
    api_messages.append_array(_get_history_messages(10))
    if api_messages.size() == 0:
        api_messages.append({"role": "user", "content": user_message})
    else:
        var last_msg = api_messages[api_messages.size() - 1]
        if last_msg is Dictionary and last_msg.get("role", "") == "user" and str(last_msg.get("content", "")).strip_edges() == user_message.strip_edges():
            pass
        else:
            api_messages.append({"role": "user", "content": user_message})
    
    _start_stream_request(api_messages)
    
    # Trigger emotion and memory agents in parallel
    _send_emotion_analysis(user_message)
    if GameDataManager.memory_manager.add_turn():
        _send_memory_extraction()

func send_desktop_pet_chat_stream(user_message: String, system_prompt: String, chat_history: Array = []) -> void:
    if not is_inside_tree() or GameDataManager.config.api_key.is_empty():
        chat_request_failed.emit("API Key未设置，请在设置界面配置。")
        return
        
    if _chat_stream_active:
        _stop_chat_stream()
        
    print("[DeepSeek Client] Sending desktop pet request...")
    
    var api_messages = [{"role": "system", "content": system_prompt}]
    for msg in chat_history:
        api_messages.append(msg)
        
    print("[DeepSeek Client] Final messages count: ", api_messages.size())
    print("[DeepSeek Client] === FULL PAYLOAD DUMP ===")
    for i in range(api_messages.size()):
        print("  [%d] Role: %s | Content: %s" % [i, api_messages[i].role, api_messages[i].content])
    print("[DeepSeek Client] === END PAYLOAD DUMP ===")
    
    _start_stream_request(api_messages)

func _start_stream_request(api_messages: Array) -> void:
    var body = {
        "model": GameDataManager.config.model,
        "messages": api_messages,
        "temperature": GameDataManager.config.temperature,
        "max_tokens": GameDataManager.config.max_tokens,
        "stream": true
    }
    
    _chat_stream_full_text = ""
    _chat_stream_sse_buffer = ""
    _chat_stream_request_sent = false
    _chat_stream_body = JSON.stringify(body)
    
    var api_key = GameDataManager.config.api_key
    _chat_stream_headers = [
        "Host: api.deepseek.com",
        "Content-Type: application/json",
        "Authorization: Bearer " + api_key,
        "Accept: text/event-stream",
		"Connection: keep-alive"
    ]
    
    _chat_stream_client = HTTPClient.new()
    var tls_options = TLSOptions.client()
    var err = _chat_stream_client.connect_to_host("api.deepseek.com", 443, tls_options)
    if err != OK:
        _stop_chat_stream()
        chat_request_failed.emit("网络请求发送失败。")
        return
        
    _chat_stream_active = true
    set_process(true)
    chat_stream_started.emit()


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
    
    # 将历史记录转化为纯文本传入，防止 AI 根据 role="assistant" 顺着往下进行角色扮演
    var history_text = ""
    var history_msgs = GameDataManager.history.messages
    var start_idx = max(0, history_msgs.size() - 20)
    var bbcode_regex = RegEx.new()
    bbcode_regex.compile("\\[/?color.*?\\]")
    
    for i in range(start_idx, history_msgs.size()):
        var msg = history_msgs[i]
        var clean_text = bbcode_regex.sub(msg["text"], "", true)
        history_text += msg["speaker"] + ": " + clean_text + "\n"
        
    var safe_user_prompt = "以下是最近的对话记录：\n" + history_text + "\n\n【系统强制指令：请作为专业的记忆提取系统，严格按照规定的 JSON 格式输出操作数组。如果没有需要提取的记忆，请输出空的 operations 数组。绝对不要进行角色扮演！不要回复任何对话！】"
    
    var api_messages = [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": safe_user_prompt}
    ]
    
    var body = {
        "model": GameDataManager.config.model,
        "messages": api_messages,
        "temperature": 0.1,
        "max_tokens": 200,
        "response_format": {"type": "json_object"}
    }
    
    memory_http.request(_get_url(), _get_headers(), HTTPClient.METHOD_POST, JSON.stringify(body))

func _process(_delta: float) -> void:
    if not _chat_stream_active or _chat_stream_client == null:
        return
        
    _chat_stream_client.poll()
    var status = _chat_stream_client.get_status()
    
    if status == HTTPClient.STATUS_CONNECTED and not _chat_stream_request_sent:
        var err = _chat_stream_client.request(HTTPClient.METHOD_POST, "/v1/chat/completions", _chat_stream_headers, _chat_stream_body)
        if err != OK:
            _stop_chat_stream()
            chat_request_failed.emit("网络请求发送失败。")
            return
        _chat_stream_request_sent = true
        return
        
    if status == HTTPClient.STATUS_BODY:
        if _chat_stream_response_code == 0:
            _chat_stream_response_code = _chat_stream_client.get_response_code()
            if _chat_stream_response_code != 200:
                var err_body = _read_all_stream_body()
                _stop_chat_stream()
                chat_request_failed.emit("API 请求错误，状态码: " + str(_chat_stream_response_code) + " Body: " + err_body)
                return
                
        var chunk = _chat_stream_client.read_response_body_chunk()
        if chunk.size() > 0:
            _chat_stream_sse_buffer += chunk.get_string_from_utf8()
            _consume_sse_buffer()
        return
        
    if status == HTTPClient.STATUS_DISCONNECTED:
        if _chat_stream_full_text.strip_edges() == "":
            _stop_chat_stream()
            chat_request_failed.emit("返回数据解析失败")
        else:
            _finish_chat_stream()

func _read_all_stream_body() -> String:
    var out = ""
    if _chat_stream_client == null:
        return out
    while true:
        var chunk = _chat_stream_client.read_response_body_chunk()
        if chunk.size() == 0:
            break
        out += chunk.get_string_from_utf8()
    return out

func _consume_sse_buffer() -> void:
    while true:
        var idx = _chat_stream_sse_buffer.find("\n\n")
        if idx == -1:
            break
        var event_text = _chat_stream_sse_buffer.substr(0, idx)
        _chat_stream_sse_buffer = _chat_stream_sse_buffer.substr(idx + 2)
        _consume_sse_event(event_text)

func _consume_sse_event(event_text: String) -> void:
    var lines = event_text.split("\n")
    for line in lines:
        var trimmed = line.strip_edges()
        if not trimmed.begins_with("data:"):
            continue
        var payload = trimmed.substr(5).strip_edges()
        if payload == "" or payload == "[DONE]":
            if payload == "[DONE]":
                _finish_chat_stream()
            continue
            
        var json = JSON.new()
        if json.parse(payload) != OK:
            continue
        var data = json.get_data()
        if not (data is Dictionary):
            continue
            
        var delta_text = ""
        if data.has("choices") and data["choices"] is Array and data["choices"].size() > 0:
            var c0 = data["choices"][0]
            if c0 is Dictionary:
                if c0.has("delta") and c0["delta"] is Dictionary and c0["delta"].has("content"):
                    delta_text = str(c0["delta"]["content"])
                elif c0.has("message") and c0["message"] is Dictionary and c0["message"].has("content"):
                    delta_text = str(c0["message"]["content"])
                    
        if delta_text != "":
            _chat_stream_full_text += delta_text
            chat_stream_delta.emit(delta_text)

func _finish_chat_stream() -> void:
    if not _chat_stream_active:
        return
    var final_text = _chat_stream_full_text
    _stop_chat_stream()
    chat_request_completed.emit({
        "choices": [
            {"message": {"content": final_text}}
        ]
    })

func _stop_chat_stream() -> void:
    _chat_stream_active = false
    _chat_stream_request_sent = false
    _chat_stream_body = ""
    _chat_stream_headers = []
    _chat_stream_sse_buffer = ""
    _chat_stream_response_code = 0
    if _chat_stream_client != null:
        _chat_stream_client.close()
        _chat_stream_client = null
    set_process(false)

func send_options_generation(last_ai_reply: String = "") -> void:
    if GameDataManager.config.api_key.is_empty():
        return
        
    # 如果调用时不在树上（极小概率，但为了安全起见），等待其重新入树
    while not is_inside_tree():
        await Engine.get_main_loop().process_frame
        
    # 防止正在处理上一个请求时产生冲突 (ERR_BUSY)
    if options_http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
        options_http.cancel_request()
        
    var history_text = ""
    var history_msgs = GameDataManager.history.messages
    var start_idx = max(0, history_msgs.size() - 10) # 仅取最近10条，避免长上下文导致AI转移话题
    
    # 提取所有包含“玩家”和角色的有效对话文本，去掉 BBCode
    var bbcode_regex = RegEx.new()
    bbcode_regex.compile("\\[/?color.*?\\]")
    
    for i in range(start_idx, history_msgs.size()):
        var msg = history_msgs[i]
        var clean_text = bbcode_regex.sub(msg["text"], "", true)
        if i == history_msgs.size() - 1 and msg["speaker"] != "玩家" and last_ai_reply == "":
            history_text += msg["speaker"] + ": " + clean_text + " <--- 【请主要针对这句话进行回应】\n"
        else:
            history_text += msg["speaker"] + ": " + clean_text + "\n"
            
    # 如果有提前生成选项时传入的最新AI回复，将其拼接到历史最后，并打上强提示标记
    if last_ai_reply != "":
        var char_name = GameDataManager.profile.char_name
        history_text += char_name + ": " + last_ai_reply + " <--- 【请主要针对这句话进行回应】\n"
        
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
    var file = FileAccess.open("res://scripts/templates/prompts/narrator_generation.txt", FileAccess.READ)
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
    system_prompt = system_prompt.replace("{{char_name}}", profile.char_name)
    
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

func send_character_mood_analysis(character_message: String) -> void:
    if GameDataManager.config.api_key.is_empty():
        character_mood_request_failed.emit("API Key未设置")
        return
        
    # 如果调用时不在树上（极小概率，但为了安全起见），等待其重新入树
    while not is_inside_tree():
        await Engine.get_main_loop().process_frame
        
    var system_prompt = GameDataManager.prompt_manager.build_character_mood_prompt(character_message)
    var api_messages = [
        {"role": "system", "content": system_prompt}
    ]
    
    var body = {
        "model": GameDataManager.config.model,
        "messages": api_messages,
        "temperature": 0.1,
        "max_tokens": 100,
        "response_format": {"type": "json_object"}
    }
    
    character_mood_http.request(_get_url(), _get_headers(), HTTPClient.METHOD_POST, JSON.stringify(body))

func analyze_mood_sync(character_message: String) -> String:
    if GameDataManager.config.api_key.is_empty():
        return ""
        
    while not is_inside_tree():
        await Engine.get_main_loop().process_frame
        
    var system_prompt = GameDataManager.prompt_manager.build_character_mood_prompt(character_message)
    var api_messages = [
        {"role": "system", "content": system_prompt}
    ]
    
    var body = {
        "model": GameDataManager.config.model,
        "messages": api_messages,
        "temperature": 0.1,
        "max_tokens": 100,
        "response_format": {"type": "json_object"}
    }
    
    # Create a temporary HTTPRequest node for this sync call
    var http = HTTPRequest.new()
    http.timeout = 10.0
    add_child(http)
    
    http.request(_get_url(), _get_headers(), HTTPClient.METHOD_POST, JSON.stringify(body))
    
    # Wait for the request to complete
    var result_array = await http.request_completed
    var result = result_array[0]
    var response_code = result_array[1]
    var response_body = result_array[3]
    
    http.queue_free()
    
    if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
        var json = JSON.new()
        if json.parse(response_body.get_string_from_utf8()) == OK:
            var data = json.get_data()
            if data is Dictionary and data.has("choices") and data["choices"].size() > 0:
                var reply = data["choices"][0]["message"]["content"]
                print("\n========== [Character Mood Sync Output] ==========")
                print(reply)
                print("==================================================\n")
                
                var clean_reply = reply.strip_edges()
                if clean_reply.begins_with("```json"):
                    clean_reply = clean_reply.replace("```json", "")
                if clean_reply.begins_with("```"):
                    clean_reply = clean_reply.replace("```", "")
                if clean_reply.ends_with("```"):
                    clean_reply = clean_reply.substr(0, clean_reply.length() - 3)
                
                clean_reply = clean_reply.strip_edges()
                        
                var reply_json = JSON.new()
                var error = reply_json.parse(clean_reply)
                if error == OK:
                    var reply_data = reply_json.get_data()
                    if reply_data is Dictionary and reply_data.has("mood_id"):
                        return reply_data["mood_id"]
                else:
                    print("Character Mood Sync Failed: Inner JSON Parse Error (Code: ", error, ") - Text: ", clean_reply)
        else:
            print("Character Mood Sync Failed: Outer JSON Parse Error")
    else:
        print("Character Mood Sync HTTP Request Failed: Code ", response_code)
    
    return ""

func _on_chat_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
    _handle_response(result, response_code, body, chat_request_completed, chat_request_failed)

func _on_emotion_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
    _handle_response(result, response_code, body, emotion_request_completed, emotion_request_failed)

func _on_memory_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
    _handle_response(result, response_code, body, memory_request_completed, memory_request_failed)

func _on_options_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
    _handle_response(result, response_code, body, options_request_completed, options_request_failed)

func _on_narrator_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
    _handle_response(result, response_code, body, narrator_request_completed, narrator_request_failed)

func _on_character_mood_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
    _handle_response(result, response_code, body, character_mood_request_completed, character_mood_request_failed)

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
