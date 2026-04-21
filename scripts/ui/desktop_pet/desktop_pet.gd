extends Window

@onready var input_edit: TextEdit = $Control/InputLayer/MarginContainer/HBoxContainer/InputField
@onready var send_button: Button = $Control/InputLayer/MarginContainer/HBoxContainer/SendButton
@onready var main_window_button: Button = $Control/UIContainer/MainWindowButton
@onready var close_button: Button = $Control/UIContainer/CloseButton
@onready var dialogue_button: Button = $Control/UIContainer/DialogueButton

@onready var ui_container: VBoxContainer = $Control/UIContainer
@onready var input_layer: PanelContainer = $Control/InputLayer
@onready var voice_record_button: Button = $Control/InputLayer/MarginContainer/HBoxContainer/VoiceRecordButton
@onready var close_input_button: Button = $Control/InputLayer/MarginContainer/HBoxContainer/Close

@onready var deepseek_client: DeepSeekClient = $DeepSeekClient
@onready var doubao_tts = $DoubaoTTSService
@onready var audio_player: AudioStreamPlayer = $AudioStreamPlayer
@onready var mic_capture: AudioStreamPlayer = $MicCapture

@onready var local_whisper_asr = get_node_or_null("LocalWhisperASR")
@onready var pet_body = get_node_or_null("Control/PetBody")

var dragging: bool = false
var drag_offset: Vector2i = Vector2i.ZERO

var pet_prompt: String = ""
var is_chatting: bool = false
var current_response: String = ""
var chat_history: Array = []
var _current_character_id: String = ""

var is_processing_bubbles: bool = false
var bubble_queue: Array = []

# 高级特性状态变量
var _last_reaction_tick: int = 0
var _last_hourly_chime_hour: int = -1
var _poll_timer: Timer

# 应用识别相关状态变量
var _window_detector: Node
var _time_since_last_switch: float = 0.0
var _current_app_name: String = ""
var _last_chatted_app: String = ""

var is_dialogue_panel_open: bool = false

func _ready() -> void:
    _current_character_id = GameDataManager.config.current_character_id
    # 初始化上次交互时间为 0，避免启动后立刻触发被拦截
    # _last_reaction_tick = 0
    
    # 设置窗口属性：无边框透明
    transparent_bg = true
    transparent = true
    borderless = true
    always_on_top = true
    unresizable = true
    
    # 设置为小窗口大小
    var target_size = Vector2i(450, 500)
    size = target_size
    
    # 初始位置：右下角
    var active_screen = DisplayServer.window_get_current_screen()
    var screen_size = DisplayServer.screen_get_size(active_screen)
    # 考虑到 Windows 任务栏通常在底部（高度约 40-50），把 y 轴偏移量设为 60
    var init_pos = Vector2i(screen_size.x - target_size.x - 20, screen_size.y - target_size.y - 60)
    position = init_pos
    
    # 确保内部 Control 占满整个小窗口
    var control_node = $Control
    control_node.set_anchors_preset(Control.PRESET_FULL_RECT)
    control_node.size = Vector2(450, 500)
    control_node.position = Vector2.ZERO
    
    ui_container.hide()
    input_layer.hide()
    
    # 注入豆包 TTS 的 AppID 和 Token 配置
    if GameDataManager.config.doubao_app_id != "" and GameDataManager.config.doubao_token != "":
        doubao_tts.setup_auth(GameDataManager.config.doubao_app_id, GameDataManager.config.doubao_token, GameDataManager.config.doubao_cluster)
    
    # 连接信号
    send_button.pressed.connect(_on_send_pressed)
    main_window_button.pressed.connect(_on_main_window_pressed)
    close_button.pressed.connect(_on_close_pressed)
    
    dialogue_button.pressed.connect(_on_dialogue_button_pressed)
    close_input_button.pressed.connect(_on_close_input_pressed)
    voice_record_button.button_down.connect(_on_voice_record_down)
    voice_record_button.button_up.connect(_on_voice_record_up)
    
    if local_whisper_asr:
        local_whisper_asr.transcribe_completed.connect(_on_asr_success)
        local_whisper_asr.transcribe_failed.connect(_on_asr_failed)
        
    # 注意：TextEdit 没有 text_submitted，因此我们需要在 _input 里面监听回车或者单独处理。这里先移除之前的 line_edit 特有信号。
    # 监听 text_changed 拦截换行
    input_edit.text_changed.connect(_on_input_text_changed)
    
    deepseek_client.chat_stream_started.connect(_on_chat_started)
    deepseek_client.chat_stream_delta.connect(_on_chat_delta)
    deepseek_client.chat_request_completed.connect(_on_chat_completed)
    deepseek_client.chat_request_failed.connect(_on_chat_failed)
    
    doubao_tts.tts_success.connect(_on_tts_success)
    doubao_tts.tts_failed.connect(_on_tts_failed)
    
    _load_prompt()
    
    # 连接 Control 面板的输入信号以处理拖拽
    control_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var bg_layer = get_node_or_null("Control/Background_layer")
    if bg_layer:
        bg_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    
    # 初始化轮询定时器
    _poll_timer = Timer.new()
    _poll_timer.wait_time = 1.0 # 改为1秒以便更平滑地显示倒计时
    _poll_timer.autostart = true
    _poll_timer.timeout.connect(_on_poll_timer_timeout)
    add_child(_poll_timer)
    
    if pet_body:
        pet_body.bubbles_changed.connect(func(): call_deferred("_update_mouse_passthrough"))
        pet_body.pet_clicked.connect(_trigger_pet_touch)
    
    ui_container.visibility_changed.connect(func(): call_deferred("_update_mouse_passthrough"))
    input_layer.visibility_changed.connect(func(): call_deferred("_update_mouse_passthrough"))
    
    # 初始化时延迟调用以更新鼠标穿透区域
    call_deferred("_update_mouse_passthrough")
    
    # 实例化 WindowDetector (通过字符串路径加载，避免非 C# 版本下报错)
    var window_detector_path = "res://scripts/csharp/WindowDetector.cs"
    if FileAccess.file_exists(window_detector_path):
        var WindowDetectorObj = load(window_detector_path)
        if WindowDetectorObj:
            _window_detector = WindowDetectorObj.new()
            add_child(_window_detector)
    else:
        pass
    
    # 延迟一帧后显示窗口，以防止初次渲染的黑/灰块
    call_deferred("show")

func _input(_event: InputEvent) -> void:
    pass

func _on_dialogue_button_pressed() -> void:
    input_layer.show()
    is_dialogue_panel_open = true
    ui_container.hide()

func _on_close_input_pressed() -> void:
    input_layer.hide()
    is_dialogue_panel_open = false

func _on_voice_record_down() -> void:
    voice_record_button.text = "松开发送"
    voice_record_button.modulate = Color(0.8, 0.2, 0.2)
    if mic_capture:
        mic_capture.play()
    if local_whisper_asr:
        local_whisper_asr.start_recording()

func _on_voice_record_up() -> void:
    voice_record_button.text = "🎙"
    voice_record_button.modulate = Color(1, 1, 1)
    if mic_capture:
        mic_capture.stop()
    if local_whisper_asr:
        # Toast feedback could be added here if you have a toast system for the pet.
        local_whisper_asr.stop_recording()

func _on_asr_success(text: String) -> void:
    if not text.is_empty():
        input_edit.text = text

func _on_asr_failed(err: String) -> void:
    print("ASR Error: ", err)

func _on_input_text_changed() -> void:
    # TextEdit supports multiple lines, but we can intercept Enter to send
    var text = input_edit.text
    if text.ends_with("\n"):
        input_edit.text = text.strip_edges()
        _on_send_pressed()
    elif text.length() > 120:
        input_edit.text = text.substr(0, 120)
        input_edit.set_caret_column(120)

func _exit_tree() -> void:
    pass


func _load_prompt() -> void:
    var current_id = GameDataManager.config.current_character_id
    if _current_character_id != current_id:
        _current_character_id = current_id
        chat_history.clear()
        
    # 强制在每次生成时都使用最新的系统提示词
    pet_prompt = GameDataManager.prompt_manager.build_system_prompt(GameDataManager.profile, "desktop_pet")
    if pet_prompt.is_empty():
        pet_prompt = "你是{name}，一个真实存在的人，正陪伴在玩家身边。请用生动自然的语气，根据你当前的心情和性格，以及你们的关系阶段，回答玩家的问题。绝对不能提到自己是AI或桌宠！你必须使用 [SPLIT] 分隔符将消息拆分为 1~2 段，且括号动作描述不超过10个字。"
        var char_name = GameDataManager.profile.char_name if GameDataManager.profile.char_name != "" else "Luna"
        pet_prompt = pet_prompt.replace("{name}", char_name)

func _on_poll_timer_timeout() -> void:
    _check_hourly_chime()
    _check_active_window()

func _check_active_window() -> void:
    if is_dialogue_panel_open: return
    if not is_instance_valid(_window_detector):
        # print("[DesktopPet Debug] _window_detector is invalid!")
        return
        
    if is_chatting:
        return
        
    var window_title = _window_detector.call("GetCurrentWindowTitle")
    var process_name = _window_detector.call("GetCurrentProcessName")
    
    if window_title == null: window_title = ""
    if process_name == null: process_name = ""
    
    if window_title == "" and process_name == "":
        return
        
    var app_identifier = process_name + "|" + window_title
    # print("[DesktopPet Debug] App Identifier: ", app_identifier, ", Time: ", _time_since_last_switch)
    
    if _current_app_name != app_identifier:
        _current_app_name = app_identifier
        _time_since_last_switch = 0.0
    else:
        _time_since_last_switch += _poll_timer.wait_time
        
    # 打印前置的 10 秒停留倒计时
    if _time_since_last_switch < 10.0:
        var remain = 10.0 - _time_since_last_switch
        print("[DesktopPet Debug] 观察新应用中 (%s)... 触发还需: %.1f 秒" % [process_name, remain])
        
    var current_tick = Time.get_ticks_msec()
    
    # 修改逻辑：当停留超过特定时间（如10秒）时，允许触发
    # 为了防止不切窗口就再也不触发，我们通过检查冷却时间(比如2分钟=120000ms)来允许重复触发
    if _time_since_last_switch >= 10.0:
        var cooldown_time = 120000 # 同一个应用连续停留，每3分钟可以再次吐槽一次
        if _last_chatted_app != app_identifier:
            cooldown_time = 30000 # 刚切到新应用，只需要和上一次任何对话间隔30秒即可
            
        if current_tick - _last_reaction_tick < cooldown_time:
            # 还在冷却中
            var remaining = (cooldown_time - (current_tick - _last_reaction_tick)) / 1000.0
            print("[DesktopPet Debug] 主动聊天冷却中: 剩余 %.1f 秒" % remaining)
            return
            
        _last_chatted_app = app_identifier
        _last_reaction_tick = current_tick
        
        # 既然重新触发了，把停留时间减掉一部分，或者保持不动，只要受冷却时间控制即可
        
        var app_type = _map_app_type(window_title, process_name)
        var time_dict = Time.get_datetime_dict_from_system()
        var h = time_dict["hour"]
        var m = time_dict["minute"]
        var prompt = "【系统动作：当前现实时间是 %02d:%02d，玩家正在看着屏幕上名为“%s”的内容（这可能是一个%s）。请你以真实陪伴者的身份，根据你当前的心情和性格，针对这个应用发表一句关心、好奇或者吐槽。注意：仅将时间作为语境参考（白天不催睡觉，晚上可提醒休息），绝不要在回复中直接报出当前时间，也绝对不能提到你是AI或桌宠。】" % [h, m, window_title, app_type]
        print("[DesktopPet Debug] Triggering proactive chat: ", prompt)
        _trigger_proactive_chat(prompt)

func _map_app_type(window_title_str: String, process: String) -> String:
    var p = process.to_lower()
    var t = window_title_str.to_lower()
    
    var app_db = GameDataManager.app_database
    if app_db and not app_db.is_empty():
        for category_key in app_db:
            var category_data = app_db[category_key]
            var category_name = category_data.get("category_name", "某个应用")
            var keywords = category_data.get("keywords", [])
            
            for keyword in keywords:
                if keyword in p or keyword in t:
                    return category_name
    
    # Fallback if not found in database
    if "chrome" in p or "edge" in p or "firefox" in p or "browser" in p:
        return "网页浏览器"
    elif "code" in p or "idea" in p or "studio" in p or "devenv" in p or "pycharm" in p or "cursor" in p or "trae" in p:
        return "编程开发工具"
    elif "word" in p or "excel" in p or "powerpoint" in p or "wps" in p:
        return "办公文档软件"
    elif "steam" in p or "game" in p or "epic" in p:
        return "游戏"
    elif "wechat" in p or "qq" in p or "discord" in p or "telegram" in p:
        return "通讯聊天软件"
    elif "bilibili" in p or "youtube" in p or "video" in p or "player" in p:
        return "视频"
    elif "music" in p or "cloudmusic" in p or "netease" in p or "spotify" in p:
        return "音乐"
        
    return process if process != "" else "未知应用"

func _check_hourly_chime() -> void:
    if is_dialogue_panel_open: return
    if is_chatting:
        return
        
    var time_dict = Time.get_datetime_dict_from_system()
    var current_hour = time_dict["hour"]
    var current_minute = time_dict["minute"]
    
    # 触发条件：分钟在0~2之间，且本小时未报时
    if current_minute >= 0 and current_minute <= 2 and _last_hourly_chime_hour != current_hour:
        var current_tick = Time.get_ticks_msec()
        if current_tick - _last_reaction_tick < 60000:
            # 60秒内有过对话，稍后再尝试报时
            return
            
        _last_hourly_chime_hour = current_hour
        _last_reaction_tick = current_tick
        
        var time_str = ""
        var time_constraint = ""
        if current_hour >= 6 and current_hour < 11:
            time_str = "清晨"
            time_constraint = "现在是白天，请展现出活力，鼓励玩家开始新的一天，绝对不要催促休息。"
        elif current_hour >= 11 and current_hour < 14:
            time_str = "中午"
            time_constraint = "现在是中午，可以提醒玩家吃午饭或稍微午休放松一下。"
        elif current_hour >= 14 and current_hour < 19:
            time_str = "下午"
            time_constraint = "现在是下午，请陪伴玩家度过这段时间，可以说些提神的话，绝对不要催促睡觉。"
        elif current_hour >= 19 and current_hour < 23:
            time_str = "晚上"
            time_constraint = "现在是晚上，可以聊些轻松的话题，如果时间较晚可以适当提醒准备休息。"
        else:
            time_str = "深夜"
            time_constraint = "现在是深夜，玩家还在熬夜，可以表现出心疼或强制要求玩家去睡觉。"
            
        var prompt = "【系统提示：现在是现实时间 %s %02d:00。%s 请结合你的性格和心情，以真实陪伴者的身份进行整点报时或吐槽。绝对不能提到自己是AI或桌宠。】" % [time_str, current_hour, time_constraint]
        _trigger_proactive_chat(prompt)


func _trigger_proactive_chat(prompt_text: String) -> void:
    print("[DesktopPet Debug] Triggering proactive chat. is_chatting: ", is_chatting)
    if is_chatting:
        return
        
    is_chatting = true
    current_response = ""
    
    bubble_queue.clear()
    if pet_body:
        pet_body.clear_bubbles()
    if audio_player and audio_player.playing:
        audio_player.stop()
        
    # 维护历史记录长度
    if chat_history.size() > 10:
        chat_history = chat_history.slice(-10)
        
    # 每次发送前都重新构建 prompt，确保应用识别的 prompt 也是最新的约束
    _load_prompt()
        
    # 将系统触发的提示以系统事件的形式加入历史记录，然后再发给大模型
    # 这样才能保证发送的数据包含这一次最新的 action
    chat_history.append({"role": "user", "content": prompt_text})
    deepseek_client.send_desktop_pet_chat_stream(prompt_text, pet_prompt, chat_history)

func _on_send_pressed() -> void:
    var text = input_edit.text.strip_edges()
    if text.is_empty() or is_chatting:
        return
        
    input_edit.text = ""
    is_chatting = true
    current_response = ""
    
    # 更新最后反应时间
    _last_reaction_tick = Time.get_ticks_msec()
    
    # Reset queue and stop TTS
    bubble_queue.clear()
    if pet_body:
        pet_body.clear_bubbles()
    if audio_player and audio_player.playing:
        audio_player.stop()
    
    # Maintain history (max 10 items to prevent context window overflow)
    if chat_history.size() > 10:
        chat_history = chat_history.slice(-10)
        
    _load_prompt()
    
    # Add user message to history
    # 桌宠特有逻辑：直接在发包前把话塞进去
    chat_history.append({"role": "user", "content": text})
    deepseek_client.send_desktop_pet_chat_stream(text, pet_prompt, chat_history)

func _on_chat_started() -> void:
    current_response = ""

func _on_chat_delta(delta_text: String) -> void:
    current_response += delta_text

func _on_chat_completed(response: Dictionary) -> void:
    print("[DesktopPet Debug] Chat request completed. Response keys: ", response.keys())
    is_chatting = false
    
    # Extract response text
    var text = ""
    if response.has("choices") and response.choices.size() > 0:
        text = response.choices[0].message.content
    else:
        text = current_response
        
    print("[DesktopPet Debug] === RAW AI RESPONSE ===")
    print(text)
    print("[DesktopPet Debug] =======================")
        
    print("[DesktopPet Debug] Extracted text length: ", text.length())
    if text.is_empty():
        print("[DesktopPet Debug] WARNING: Response text is empty! Fallback to error message.")
        text = "（沉默）……"
        
    # 如果大模型抽风只回复了括号动作而没有文字，强制补充省略号，否则无法发声且很怪异
    var pure_dialogue = _extract_dialogue_text(text)
    if pure_dialogue.is_empty():
        print("[DesktopPet Debug] WARNING: No dialogue text found in response! Appending fallback.")
        text += " ……"
        
    # Add assistant message to history
    chat_history.append({"role": "assistant", "content": text})
        
    display_bubble(text)

func _on_chat_failed(error_msg: String) -> void:
    print("[DesktopPet Debug] Chat request failed: ", error_msg)
    if pet_body:
        pet_body.add_bubble("[color=red]错误: " + error_msg + "[/color]")
    is_chatting = false

func display_bubble(text: String) -> void:
    var chunks = text.split("[SPLIT]")
    for chunk in chunks:
        var c = chunk.strip_edges()
        if not c.is_empty():
            # 为每一小段兜底：如果这小段只有括号，没有台词，也补上省略号
            var pure = _extract_dialogue_text(c)
            if pure.is_empty():
                c += " ……"
            bubble_queue.append(c)
            
    if not is_processing_bubbles:
        _process_next_bubble()

func _process_next_bubble() -> void:
    if bubble_queue.is_empty():
        is_processing_bubbles = false
        return
        
    is_processing_bubbles = true
    var chunk = bubble_queue.pop_front()
    
    # Parse green action text and pure dialogue for TTS
    var display_text = _format_action_text(chunk)
    var tts_text = _extract_dialogue_text(chunk)
    
    if pet_body:
        pet_body.add_bubble(display_text, true)
    
    if GameDataManager.config.voice_enabled and _has_readable_text(tts_text):
        var char_id = GameDataManager.config.current_character_id
        var v_type = "ICL_zh_female_bingruoshaonv_tob"
        if GameDataManager.config.character_voice_types.has(char_id):
            v_type = GameDataManager.config.character_voice_types[char_id]
            
        var options = {"voice_type": v_type}
        
        # 将标志位存入数组，以便在 Lambda 内部能够修改外层变量引用（GDScript 4.x 闭包机制）
        var tts_state = [false]
        
        var on_success = func(_stream: AudioStream, _text: String): tts_state[0] = true
        var on_failed = func(_err: String, _text: String): tts_state[0] = true
        
        doubao_tts.tts_success.connect(on_success, CONNECT_ONE_SHOT)
        doubao_tts.tts_failed.connect(on_failed, CONNECT_ONE_SHOT)
        
        doubao_tts.synthesize(tts_text, options)
        
        # 第一阶段：死等网络请求回来（最多等10秒）
        var wait_net = 0
        while not tts_state[0] and wait_net < 200:
            await get_tree().create_timer(0.05).timeout
            wait_net += 1
            
        # 安全清理连接，防止因为超时或其他原因导致的死连接
        if doubao_tts.tts_success.is_connected(on_success):
            doubao_tts.tts_success.disconnect(on_success)
        if doubao_tts.tts_failed.is_connected(on_failed):
            doubao_tts.tts_failed.disconnect(on_failed)
            
        # 第二阶段：网络请求回来后，由于播放有一点微小的延迟，我们稍微等几帧确保 audio_player.playing 状态更新
        await get_tree().process_frame
        await get_tree().process_frame
        await get_tree().process_frame
            
        # 第三阶段：死等音频播放结束
        var wait_count = 0
        while audio_player and audio_player.playing and wait_count < 1200: # 最多等60秒
            await get_tree().create_timer(0.05).timeout
            wait_count += 1
            
        # 极短的缓冲，让两句话之间显得自然，而不是生硬地等半天
        await get_tree().create_timer(0.2).timeout
    else:
        # 如果没有语音，等待打字机完成 + 短暂暂停
        var duration = chunk.length() * 0.05 + 1.0
        await get_tree().create_timer(duration).timeout
    
    _process_next_bubble()

func _format_action_text(text: String) -> String:
    # 简单正则替换 (...) 和 （...）为绿色
    var regex = RegEx.new()
    regex.compile("\\([^)]+\\)|\\（[^）]+\\）")
    var result = text
    var matches = regex.search_all(text)
    # 为了防止破坏BBCode，从后往前替换或者直接替换
    # 但由于没有嵌套，直接 replace 是可以的
    for m in matches:
        var matched_string = m.get_string()
        result = result.replace(matched_string, "[color=green]" + matched_string + "[/color]")
    return result

func _extract_dialogue_text(text: String) -> String:
    var regex = RegEx.new()
    regex.compile("\\([^)]+\\)|\\（[^）]+\\）")
    return regex.sub(text, "", true).strip_edges()

func _has_readable_text(text: String) -> bool:
    var regex = RegEx.new()
    regex.compile("[a-zA-Z0-9\u4e00-\u9fa5]")
    return regex.search(text) != null

func _on_tts_success(audio_stream: AudioStream, _text: String) -> void:
    if audio_player:
        audio_player.stream = audio_stream
        audio_player.play()

func _on_tts_failed(error_msg: String, _text: String) -> void:
    print("Desktop Pet TTS failed: ", error_msg)

func _on_main_window_pressed() -> void:
    # 重新显示主窗口并请求焦点
    var current_scene: Node = get_tree().current_scene
    if current_scene:
        get_tree().root.show()
        current_scene.show()
        if current_scene is Control and current_scene.focus_mode != Control.FOCUS_NONE:
            current_scene.grab_focus()
        DisplayServer.window_request_attention()

func _on_close_pressed() -> void:
    # 先隐藏窗口并切断输入流，防止 _push_unhandled_input_internal 报错
    hide()
    
    # release_focus() 属于 Control 节点，Window 节点没有这个方法
    # 取消当前窗口中所有 Control 的焦点
    var focused_node = get_viewport().gui_get_focus_owner()
    if focused_node:
        focused_node.release_focus()
        
    queue_free()
    
    # 如果关闭桌宠时，主窗口被隐藏了，则彻底退出
    var current_scene = get_tree().current_scene
    if current_scene and not get_tree().root.visible:
        get_tree().quit()

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
            # 右键点击背景：切换 UI 面板显示/隐藏
            if is_dialogue_panel_open:
                return
            ui_container.visible = not ui_container.visible
            get_viewport().set_input_as_handled()
        elif event.button_index == MOUSE_BUTTON_LEFT:
            if event.pressed:
                dragging = true
                drag_offset = Vector2i(event.global_position)
            else:
                dragging = false
    elif event is InputEventMouseMotion and dragging:
        var new_pos = DisplayServer.mouse_get_position() - drag_offset
        
        # 多显示器支持：获取目标位置所在的屏幕
        var screen_idx = DisplayServer.get_screen_from_rect(Rect2i(new_pos, size))
        var screen_rect = DisplayServer.screen_get_usable_rect(screen_idx)
        
        # 限制在新屏幕的边界范围内
        new_pos.x = clampi(new_pos.x, screen_rect.position.x, screen_rect.end.x - size.x)
        new_pos.y = clampi(new_pos.y, screen_rect.position.y, screen_rect.end.y - size.y)
        
        position = new_pos

func _trigger_pet_touch() -> void:
    if is_dialogue_panel_open: return
        
    var current_tick = Time.get_ticks_msec()
    # 增加一个冷却时间，防止疯狂点击
    if current_tick - _last_reaction_tick < 3000:
        return
        
    _last_reaction_tick = current_tick
    
    # 触发聊天
    if not is_chatting:
        var time_dict = Time.get_datetime_dict_from_system()
        var h = time_dict["hour"]
        var m = time_dict["minute"]
        var prompt = "【系统动作：当前现实时间是 %02d:%02d，玩家用鼠标轻轻戳了触碰了你一下。请结合当前时间作为隐性语境（如白天不催促睡觉），根据你的性格和当前心情，做出一两句话可爱的回应或吐槽。绝对不要在回复中直接报出当前时间或提到AI。】" % [h, m]
        _trigger_proactive_chat(prompt)

func _update_mouse_passthrough() -> void:
    print("[DesktopPet Debug] _update_mouse_passthrough started")
    # 确保窗口已经有效存在且没有在被销毁的过程中
    if not is_inside_tree() or is_queued_for_deletion():
        print("[DesktopPet Debug] Window not in tree or queued for deletion")
        return
        
    var win_id = get_window_id()
    if win_id == DisplayServer.INVALID_WINDOW_ID:
        print("[DesktopPet Debug] INVALID_WINDOW_ID")
        return
        
    print("[DesktopPet Debug] Gathering rects...")
    var rects: Array[Rect2] = []
    
    # 始终包含左侧和底部边缘的一小块区域作为拖拽抓手，防止全透明后彻底丢失窗口控制权
    rects.append(Rect2(0, size.y - 40, 40, 40))
    
    var bg_layer = get_node_or_null("Control/Background_layer")
    if bg_layer and bg_layer.is_visible_in_tree():
        var bg_rect = bg_layer.get_global_rect()
        if bg_rect.size.x > 0 and bg_rect.size.y > 0:
            rects.append(bg_rect.grow(5))
        
    var u_container = get_node_or_null("Control/UIContainer")
    if u_container and u_container.is_visible_in_tree():
        var ui_rect = u_container.get_global_rect()
        if ui_rect.size.x > 0 and ui_rect.size.y > 0:
            rects.append(ui_rect.grow(5))
            
    var i_layer = get_node_or_null("Control/InputLayer")
    if i_layer and i_layer.is_visible_in_tree():
        var in_rect = i_layer.get_global_rect()
        if in_rect.size.x > 0 and in_rect.size.y > 0:
            rects.append(in_rect.grow(5))
        
    if pet_body and pet_body.is_visible_in_tree():
        if pet_body.has_method("get_passthrough_rects"):
            var pet_rects = pet_body.get_passthrough_rects()
            for r in pet_rects:
                if r.size.x > 0 and r.size.y > 0:
                    rects.append(r)
                
    if rects.is_empty():
        print("[DesktopPet Debug] Rects empty, setting dummy polygon")
        # 如果没有矩形，为了实现全穿透，传递一个在屏幕外的极小多边形
        var dummy := PackedVector2Array([
            Vector2(-10, -10), Vector2(-9, -10),
            Vector2(-9, -9), Vector2(-10, -9)
        ])
        if is_inside_tree() and not is_queued_for_deletion():
            DisplayServer.window_set_mouse_passthrough(dummy, win_id)
        return
        
    print("[DesktopPet Debug] Building polygons from %d rects" % rects.size())
    var polys: Array[PackedVector2Array] = []
    for r in rects:
        # 顺时针和逆时针的问题在Godot中要注意，这里先按照一个标准方向构建矩形
        var p = PackedVector2Array([
            r.position,
            Vector2(r.position.x, r.end.y),
            r.end,
            Vector2(r.end.x, r.position.y)
        ])
        # Godot中，Geometry2D处理的是逆时针多边形
        if Geometry2D.is_polygon_clockwise(p):
            p.reverse()
        polys.append(p)
        
    print("[DesktopPet Debug] Merging polygons...")
    # 消除重叠，避免零宽桥接在ALTERNATE填充规则下产生漏洞（镂空）
    var changed = true
    var loop_count = 0
    while changed and loop_count < 100: # 防死循环保护
        loop_count += 1
        changed = false
        for i in range(polys.size()):
            for j in range(i + 1, polys.size()):
                var intersection = Geometry2D.intersect_polygons(polys[i], polys[j])
                if intersection.size() > 0:
                    var merged = Geometry2D.merge_polygons(polys[i], polys[j])
                    polys.remove_at(j)
                    polys.remove_at(i)
                    for m in merged:
                        if m.size() >= 3 and not Geometry2D.is_polygon_clockwise(m):
                            polys.append(m)
                    changed = true
                    break
            if changed:
                break
                
    if loop_count >= 100:
        print("[DesktopPet Debug] ERROR: Polygon merge loop exceeded max iterations!")
                
    if polys.is_empty():
        print("[DesktopPet Debug] Polys empty after merge, setting dummy polygon")
        var dummy := PackedVector2Array([
            Vector2(-10, -10), Vector2(-9, -10),
            Vector2(-9, -9), Vector2(-10, -9)
        ])
        if is_inside_tree() and not is_queued_for_deletion():
            DisplayServer.window_set_mouse_passthrough(dummy, win_id)
        return
        
    print("[DesktopPet Debug] Bridging %d final polygons..." % polys.size())
    var polygon := PackedVector2Array()
    var first = polys[0]
    
    if first.size() < 3:
        print("[DesktopPet Debug] ERROR: First polygon has less than 3 points!")
        return
    
    polygon.append_array(first)
    polygon.append(first[0]) # 闭合第一个多边形
    
    # 使用零宽桥接(Zero-width bridge)连接后续独立的多边形，形成单个多边形
    for i in range(1, polys.size()):
        var current = polys[i]
        if current.size() < 3:
            continue
            
        # 从第一个多边形的起点连到当前多边形的起点 (去程桥接)
        polygon.append(first[0])
        polygon.append(current[0])
        
        # 绘制当前多边形
        polygon.append_array(current)
        polygon.append(current[0]) # 闭合当前多边形
        
        # 从当前多边形的起点连回第一个多边形的起点 (回程桥接)
        polygon.append(first[0])
        
    print("[DesktopPet Debug] Setting final passthrough polygon with %d points" % polygon.size())
    if is_inside_tree() and not is_queued_for_deletion():
        DisplayServer.window_set_mouse_passthrough(polygon, win_id)
    print("[DesktopPet Debug] _update_mouse_passthrough completed")
