extends CanvasLayer

@onready var input_edit: TextEdit = $Control/InputLayer/MarginContainer/HBoxContainer/InputField
@onready var send_button: Button = $Control/InputLayer/MarginContainer/HBoxContainer/SendButton
@onready var main_window_button: Button = $Control/UIContainer/MainWindowButton
@onready var close_button: Button = $Control/UIContainer/CloseButton
@onready var settings_button: Button = $Control/UIContainer/SettingsButton
@onready var dialogue_button: Button = $Control/UIContainer/DialogueButton
@onready var pomodoro_button: Button = $Control/UIContainer/PomodoroButton

@onready var ui_container: VBoxContainer = $Control/UIContainer
@onready var input_layer: PanelContainer = $Control/InputLayer
@onready var voice_record_button: Button = $Control/InputLayer/MarginContainer/HBoxContainer/VoiceRecordButton
@onready var close_input_button: Button = $Control/InputLayer/MarginContainer/HBoxContainer/Close

@onready var deepseek_client: Node = $DeepSeekClient
@onready var audio_player: AudioStreamPlayer = $AudioStreamPlayer
@onready var mic_capture: AudioStreamPlayer = $MicCapture


var qwen_asr_client = null
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
var _tts_finished: bool = false

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
var settings_panel_instance = null
var pomodoro_panel_instance = null
var _spectrum_analyzer: AudioEffectSpectrumAnalyzerInstance

func _ready() -> void:
    _current_character_id = GameDataManager.config.current_character_id
    # 初始化上次交互时间为 0，避免启动后立刻触发被拦截
    # _last_reaction_tick = 0
    
    # 此时 DesktopPet 已经是一个 CanvasLayer 并且附着在系统默认主窗口上
    # 我们通过 get_window() 获取根窗口，并配置它
    var main_window = get_window()
    main_window.transparent_bg = true
    main_window.transparent = true
    main_window.borderless = true
    main_window.always_on_top = true
    main_window.unresizable = true
    
    # 获取当前鼠标所在的屏幕索引
    var screen_idx = DisplayServer.get_screen_from_rect(Rect2i(DisplayServer.mouse_get_position(), Vector2i.ONE))
    var screen_rect = DisplayServer.screen_get_usable_rect(screen_idx)
    
    # 伪全屏逻辑：左右和上下留 1 像素空间，避免真全屏影响透明穿透
    var target_size = Vector2i(screen_rect.size.x - 2, screen_rect.size.y - 2)
    main_window.size = target_size
    main_window.position = Vector2i(screen_rect.position.x + 1, screen_rect.position.y + 1)
    
    # 确保内部 Control 保持原始桌宠区域的相对大小 (约 250x550) 并靠在屏幕右下角
    var control_node = $Control
    control_node.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
    control_node.size = Vector2(250, 550)
    control_node.position = Vector2(target_size.x - 250, target_size.y - 550)
    
    # 设置内部 Control 的鼠标过滤器为 IGNORE，防止阻挡穿透
    control_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
    
    ui_container.hide()
    input_layer.hide()
    
    # 隐藏独立桌宠不需要的按钮
    main_window_button.hide()
    pomodoro_button.hide()
    
    # TTSManager 已在全局自动处理配置，这里不需要额外配置
    
    # 连接信号
    send_button.pressed.connect(_on_send_pressed)
    main_window_button.pressed.connect(_on_main_window_pressed)
    close_button.pressed.connect(_on_close_pressed)
    pomodoro_button.pressed.connect(_on_pomodoro_pressed)
    
    settings_button.pressed.connect(_on_settings_pressed)
    dialogue_button.pressed.connect(_on_dialogue_button_pressed)
    close_input_button.pressed.connect(_on_close_input_pressed)
    voice_record_button.button_down.connect(_on_voice_record_down)
    voice_record_button.button_up.connect(_on_voice_record_up)
    
    if GameDataManager.config.qwen_asr_enabled:
        var qwen_asr_client_class = load("res://scripts/api/qwen_asr_client.gd")
        if qwen_asr_client_class:
            qwen_asr_client = qwen_asr_client_class.new()
            qwen_asr_client.name = "QwenASRClientNode"
            add_child(qwen_asr_client)
            qwen_asr_client.transcribe_completed.connect(_on_asr_success)
            qwen_asr_client.transcribe_failed.connect(_on_asr_failed)
        
    # 注意：TextEdit 没有 text_submitted，因此我们需要在 _input 里面监听回车或者单独处理。这里先移除之前的 line_edit 特有信号。
    # 监听 text_changed 拦截换行
    input_edit.text_changed.connect(_on_input_text_changed)
    
    # 增加一个定时器，每秒强制更新一次鼠标穿透状态，防止在等待或状态切换时意外失去穿透
    var passthrough_timer = Timer.new()
    passthrough_timer.wait_time = 1.0
    passthrough_timer.autostart = true
    passthrough_timer.timeout.connect(_update_mouse_passthrough)
    add_child(passthrough_timer)
    
    deepseek_client.chat_stream_started.connect(_on_chat_started)
    deepseek_client.chat_stream_delta.connect(_on_chat_delta)
    deepseek_client.chat_request_completed.connect(_on_chat_completed)
    deepseek_client.chat_request_failed.connect(_on_chat_failed)
    
    deepseek_client.vision_request_completed.connect(_on_vision_completed)
    deepseek_client.vision_request_failed.connect(_on_vision_failed)
    
    TTSManager.tts_success.connect(_on_tts_success)
    TTSManager.tts_failed.connect(_on_tts_failed)
    
    # 获取音频分析器用于绘制波形环
    var bus_idx = AudioServer.get_bus_index("Voice")
    if bus_idx >= 0:
        for i in range(AudioServer.get_bus_effect_count(bus_idx)):
            var effect = AudioServer.get_bus_effect(bus_idx, i)
            if effect is AudioEffectSpectrumAnalyzer:
                _spectrum_analyzer = AudioServer.get_bus_effect_instance(bus_idx, i)
                break
    
    _load_prompt()
    
    # 设置各个 UI 容器的尺寸和锚点，避免它们自动拉伸占满整个屏幕从而阻挡穿透
    ui_container.set_anchors_preset(Control.PRESET_TOP_LEFT)
    input_layer.set_anchors_preset(Control.PRESET_TOP_LEFT)
    
    # 连接 Control 面板的输入信号以处理拖拽
    control_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
    
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

func _process(delta: float) -> void:
    if not pet_body:
        return
        
    if is_chatting:
        pet_body.set_pet_state(1) # Thinking
    elif audio_player and audio_player.playing:
        pet_body.set_pet_state(2) # Speaking
        if _spectrum_analyzer:
            var magnitude = _spectrum_analyzer.get_magnitude_for_frequency_range(0, 4000)
            var volume = (magnitude.x + magnitude.y) / 2.0
            pet_body.update_voice_volume(volume * 5.0)
    else:
        # Check proactive cooldown
        if not is_dialogue_panel_open:
            var current_tick = Time.get_ticks_msec()
            var time_since_last_reaction = current_tick - _last_reaction_tick
            
            # 持续增加观察时间，使其平滑
            if _current_app_name != "":
                _time_since_last_switch += delta
            
            var target_progress = 0.0
            
            if _current_app_name != "" and _last_chatted_app != _current_app_name:
                # 新应用：需要停留5秒，且距离上次聊天至少5秒
                var switch_progress = _time_since_last_switch / 5.0
                var reaction_progress = float(time_since_last_reaction) / 5000.0
                target_progress = min(switch_progress, reaction_progress)
            else:
                # 相同应用：只需要满足120秒的冷却
                target_progress = float(time_since_last_reaction) / 120000.0
                
            if target_progress < 1.0 and _current_app_name != "":
                pet_body.set_pet_state(3, target_progress) # 统一使用绿色状态环
            else:
                pet_body.set_pet_state(0) # Idle
        else:
            pet_body.set_pet_state(0) # Idle

func _on_dialogue_button_pressed() -> void:
    input_layer.show()
    is_dialogue_panel_open = true
    ui_container.hide()

func _on_settings_pressed() -> void:
    if settings_panel_instance == null:
        var SettingsPanelObj = load("res://scenes/ui/settings/settings_scene.tscn")
        if SettingsPanelObj:
            settings_panel_instance = SettingsPanelObj.instantiate()
            $Control.add_child(settings_panel_instance)
            
            # 将设置面板的尺寸保持较大比例，并将其在全屏幕居中显示
            settings_panel_instance.set_anchors_preset(Control.PRESET_TOP_LEFT)
            settings_panel_instance.size = Vector2(1280, 720)
            var screen_size = DisplayServer.screen_get_size()
            settings_panel_instance.position = (Vector2(screen_size) - settings_panel_instance.size) / 2.0 - $Control.position
            
            # Ensure it can receive mouse events to block passthrough
            settings_panel_instance.mouse_filter = Control.MOUSE_FILTER_STOP
            
            # Connect visibility changed to update passthrough
            if settings_panel_instance.has_signal("visibility_changed"):
                settings_panel_instance.visibility_changed.connect(func(): call_deferred("_update_mouse_passthrough"))
            # Connect tree_exited to handle panel removal
            settings_panel_instance.tree_exited.connect(func(): 
                settings_panel_instance = null
                call_deferred("_update_mouse_passthrough")
            )
            
    if settings_panel_instance:
        settings_panel_instance.show()
        call_deferred("_update_mouse_passthrough")

func _on_pomodoro_pressed() -> void:
    pass # 独立桌宠版本移除了番茄钟联动

func _on_close_input_pressed() -> void:
    input_layer.hide()
    is_dialogue_panel_open = false

func _on_voice_record_down() -> void:
    voice_record_button.text = "松开发送"
    voice_record_button.modulate = Color(0.8, 0.2, 0.2)
    if mic_capture:
        mic_capture.play()
    if GameDataManager.config.qwen_asr_enabled and qwen_asr_client:
        qwen_asr_client.start_recording()

func _on_voice_record_up() -> void:
    voice_record_button.text = "🎙"
    voice_record_button.modulate = Color(1, 1, 1)
    if mic_capture:
        mic_capture.stop()
    if GameDataManager.config.qwen_asr_enabled and qwen_asr_client:
        qwen_asr_client.stop_recording()

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
        
    # 不再强制每次重新生成，依赖 PromptManager 的能力
    if GameDataManager.prompt_manager and GameDataManager.prompt_manager.has_method("build_system_prompt"):
        pet_prompt = GameDataManager.prompt_manager.build_system_prompt(GameDataManager.profile, "desktop_pet")
    else:
        pet_prompt = "你是{name}，一个真实存在的人，正陪伴在玩家身边。请用生动自然的语气，根据你当前的心情和性格，以及你们的关系阶段，回答玩家的问题。绝对不能提到自己是AI或桌宠！你必须使用 [SPLIT] 分隔符将消息拆分为 1~2 段，且括号动作描述不超过10个字。"
        var char_name = GameDataManager.profile.char_name if GameDataManager.profile.char_name != "" else "Luna"
        pet_prompt = pet_prompt.replace("{name}", char_name)

func _on_poll_timer_timeout() -> void:
    _check_hourly_chime()
    _check_active_window()

func _get_time_constraint(hour: int) -> String:
    if hour >= 6 and hour < 11:
        return "现在是清晨/上午，请展现出活力，【绝对禁止】说出“晚安”、“好困”或催促睡觉的词汇。"
    elif hour >= 11 and hour < 14:
        return "现在是中午，可以提醒玩家吃午饭或稍微午休，【绝对禁止】说出“晚安”或催促晚上睡觉的词汇。"
    elif hour >= 14 and hour < 19:
        return "现在是下午，请陪伴玩家度过这段时间，可以说些提神的话，【绝对禁止】说出“晚安”、“好困”或催促睡觉的词汇。"
    elif hour >= 19 and hour < 23:
        return "现在是晚上，可以聊些轻松的话题，如果时间较晚可以适当提醒准备休息。"
    else:
        return "现在是深夜，玩家还在熬夜，可以表现出困意、心疼或强制要求玩家去睡觉。"

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
        
    # 打印前置的 5 秒停留倒计时
    if _time_since_last_switch < 5.0:
        var remain = 5.0 - _time_since_last_switch
        print("[DesktopPet Debug] 观察新应用中 (%s)... 触发还需: %.1f 秒" % [process_name, remain])
        
    var current_tick = Time.get_ticks_msec()
    
    # 修改逻辑：当停留超过5秒时，允许触发
    if _time_since_last_switch >= 5.0:
        var cooldown_time = 120000 # 同一个应用连续停留，每2分钟可以再次吐槽一次
        if _last_chatted_app != app_identifier:
            cooldown_time = 5000 # 刚切到新应用，只需要和上一次任何对话间隔5秒即可
            
        if current_tick - _last_reaction_tick < cooldown_time:
            # 还在冷却中
            var remaining = (cooldown_time - (current_tick - _last_reaction_tick)) / 1000.0
            print("[DesktopPet Debug] 主动聊天冷却中: 剩余 %.1f 秒" % remaining)
            return
            
        _last_chatted_app = app_identifier
        _last_reaction_tick = current_tick
        
        # 为了保证即使触发了 Vision 逻辑，底层的定时更新机制也能重置透明穿透
        call_deferred("_update_mouse_passthrough")
        
        var app_type = _map_app_type(window_title, process_name)
        var time_dict = Time.get_datetime_dict_from_system()
        var h = time_dict["hour"]
        var m = time_dict["minute"]
        var _time_constraint = _get_time_constraint(h)
        
        # 尝试截图 (优先截取当前活动窗口)
        var base64_image = ""
        if GameDataManager.config.vision_enabled and not GameDataManager.config.vision_api_key.is_empty():
            if _window_detector.has_method("CaptureForegroundWindowToBase64"):
                base64_image = _window_detector.call("CaptureForegroundWindowToBase64")
            elif _window_detector.has_method("CaptureScreenToBase64"):
                base64_image = _window_detector.call("CaptureScreenToBase64")
            
        if base64_image != "":
            print("[DesktopPet Debug] Vision API Triggered! App: ", window_title)
            # 这里只要求大模型做纯粹的画面分析，绝对不包含任何角色扮演和对话要求
            var prompt = """【系统提示：当前现实时间是 %02d:%02d，玩家正在看名为“%s”的应用。这是该应用的窗口截图。】
请作为专业的视觉“互动话题提取系统”，精准提取画面中【最能引发角色互动、吃醋、好奇或心疼的细节信息】（控制在150字以内）。
要求：
1. 【屏蔽噪音】：忽略无用的UI外壳、菜单栏、行号、背景图等冗余元素。
2. 【提取社交雷达】：如果屏幕上有聊天、通讯、社交媒体或邮件，必须且只需提取出：在和谁聊天（对方名字/备注）？聊了什么核心内容？对方头像或性别？
3. 【提取工作细节】：如果屏幕上是代码、文档或表格，必须提取出：玩家正在解决什么具体的难题？文档标题是什么？代码中有什么能让外行人觉得“好厉害”或“好辛苦”的关键词？
4. 【提取娱乐焦点】：如果屏幕上是视频、游戏或网页，必须提取出：画面里有什么有趣的角色、商品或事件？这东西看起来是轻松的还是恐怖的？
5. 绝对不要进行角色扮演或输出对话！只需输出客观、提炼过、能够作为【绝佳聊天话题】的关键信息。""" % [h, m, window_title]
            _trigger_vision_chat(prompt, base64_image)
        else:
            var prompt = """【系统提示：当前现实时间是 %02d:%02d，玩家正在看着屏幕上名为“%s”的内容（这可能是一个%s）。】
请你代入当前设定的身份和性格，像真人一样对玩家屏幕上的内容做出最自然、最符合人设的反应。
- 【拒绝人机感与套路】：不要无脑套用模板或者道歉！展现你“温柔体贴”、“天然呆”或“安静陪伴”的一面。比如好奇应用里的内容，或者心疼玩家太辛苦，提供情绪价值。
- 结合你们的关系阶段和当前的【微习惯与口癖】，表现得软糯、真诚且自然。
- 【格式强制】：必须遵循【对话结构策略】，使用[SPLIT]拆分句子，必须包含括号动作描写。
- 绝对不要在台词中报出当前时间，绝对不能提到你是AI或桌宠。""" % [h, m, window_title, app_type]
            print("[DesktopPet Debug] Triggering proactive chat: ", prompt)
            _trigger_proactive_chat(prompt)

func _trigger_vision_chat(prompt_text: String, base64_image: String) -> void:
    if is_chatting: return
    is_chatting = true
    current_response = ""
    bubble_queue.clear()
    if pet_body: pet_body.clear_bubbles()
    if audio_player and audio_player.playing: audio_player.stop()
    
    # 构建专属的独立请求记录
    chat_history.append({"role": "user", "content": "【屏幕截图发送成功】" + prompt_text})
    if chat_history.size() > 10: chat_history = chat_history.slice(-10)
    _load_prompt()
    
    print("\n[DesktopPet Vision] --- Sending Vision Request ---")
    print("Prompt text length: ", prompt_text.length())
    print("Base64 length: ", base64_image.length())

    deepseek_client.send_vision_request(pet_prompt, prompt_text, base64_image)

func _on_vision_completed(response: Dictionary) -> void:
    print("\n[DesktopPet Vision] --- Vision Analysis Completed ---")
    
    var analysis_text = ""
    var is_valid = false
    
    # OpenAI format (choices[0].message.content)
    if response.has("choices") and response.choices.size() > 0:
        var msg = response.choices[0].get("message", {})
        analysis_text = msg.get("content", "").strip_edges()
        is_valid = true
    # Doubao Seed/Other formats fallback
    elif response.has("output") and typeof(response["output"]) == TYPE_ARRAY and response["output"].size() > 0:
        for item in response["output"]:
            if typeof(item) == TYPE_DICTIONARY:
                if item.has("text") and typeof(item["text"]) == TYPE_STRING:
                    analysis_text += item["text"]
                elif item.has("content") and typeof(item["content"]) == TYPE_STRING:
                    analysis_text += item["content"]
        analysis_text = analysis_text.strip_edges()
        is_valid = true
    # Simple text output fallback
    elif response.has("output") and typeof(response["output"]) == TYPE_STRING:
        analysis_text = response["output"].strip_edges()
        is_valid = true
    # Message structure fallback
    elif response.has("message") and typeof(response["message"]) == TYPE_DICTIONARY:
        var msg = response["message"]
        if msg.has("content"):
            analysis_text = str(msg["content"]).strip_edges()
            is_valid = true
    
    # Full raw dump for debug
    if not is_valid:
        print("[DesktopPet Vision Debug] Unrecognized response format. Raw dump: ", JSON.stringify(response))
        analysis_text = JSON.stringify(response)
        is_valid = true
    
    if is_valid:
        print("[DesktopPet Vision] Extracted Analysis Output:\n", analysis_text)
        
        # 将分析结果作为主动聊天的触发器，发给专门负责角色扮演的文本大模型
        var prompt = """【系统提示：视觉分析系统刚刚捕捉到了玩家当前正在查看的屏幕画面。】
以下是屏幕画面的详细分析结果：
%s

请你严格代入当前设定的身份和性格，基于以上画面分析，像真人一样对玩家屏幕上的内容做出最自然、最符合人设的反应。
- 【拒绝人机感与刻板印象】：不要每次都只套用固定模板！展现你性格的所有面。
- 【严格遵循情感阶段】：无论画面内容是日常软件还是玩家的私人社交记录，你的反应【必须完全以系统传入的“当前关系阶段”和“特殊场景反应”设定为最高准则】！仔细阅读传入的情感阶段设定，阶段未到绝对不可越界吃醋或发火。
- 【生动自然】：要有真人的温度，结合【微习惯与口癖】，可以有轻微的迟疑，但要真诚有趣。
- 绝对不要在台词中报出时间，绝不提自己是AI/桌宠。
- 【格式强制】：回复必须遵循【对话结构策略】，用 [SPLIT] 拆分长句，必须包含括号动作描写。""" % [analysis_text]
        
        # 必须先重置 is_chatting，否则 _trigger_proactive_chat 会被拦截
        is_chatting = false
        _trigger_proactive_chat(prompt)
    else:
        print("[DesktopPet Vision] Failed to parse analysis choices. Raw response:\n", response)
        is_chatting = false
        var text = "（看着屏幕发呆）……"
        chat_history.append({"role": "assistant", "content": text})
        display_bubble(text)

func _on_vision_failed(error_msg: String) -> void:
    print("[DesktopPet Debug] Vision request failed: ", error_msg)
    if pet_body:
        pet_body.add_bubble("[color=red]视觉感知失败: " + error_msg + "[/color]")
    is_chatting = false

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
        
        var _time_constraint = _get_time_constraint(current_hour)
        var prompt = """【系统提示：现在是现实时间 %02d:00。】
请你结合当前时间作为隐性语境，代入当前设定的身份、心情和性格，像真人一样对玩家进行整点报时或吐槽。
- 反应要生动多样！结合你们的【微习惯与口癖】。
- 【格式强制】：你的回复必须完全遵循系统提示词中的【对话结构策略】（使用[SPLIT]等规则，必须包含括号动作描写）。
- 绝对不能提到你是AI或桌宠。""" % [current_hour]
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
        
    # 构建专属的独立请求记录，不带历史上下文，防止主动吐槽被历史聊天带偏
    var proactive_history = []
    proactive_history.append({"role": "user", "content": prompt_text})
    
    # 我们把这次主动事件塞进专属的桌宠聊天历史里
    chat_history.append({"role": "user", "content": prompt_text})
    
    var pet_messages = [{"role": "system", "content": pet_prompt}]
    for msg in proactive_history:
        pet_messages.append(msg)
        
    if deepseek_client.has_method("_start_stream_request"):
        deepseek_client._start_stream_request(pet_messages)
    elif deepseek_client.has_method("send_chat_message_stream"):
        deepseek_client.send_chat_message_stream(prompt_text, "desktop_pet")

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
    # 我们不要再塞进全局的聊天历史里了，而是使用专门的桌宠历史
    chat_history.append({"role": "user", "content": text})
    
    # 构建专门为桌宠发送的历史数组，避免混用
    var pet_messages = [{"role": "system", "content": pet_prompt}]
    for msg in chat_history:
        pet_messages.append(msg)
        
    if deepseek_client.has_method("_start_stream_request"):
        deepseek_client._start_stream_request(pet_messages)
    elif deepseek_client.has_method("send_chat_message_stream"):
        deepseek_client.send_chat_message_stream(text, "desktop_pet")

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
    # 兼容处理大模型没有使用 [SPLIT] 而是使用了换行符 \n\n 或 \n 的情况
    var processed_text = text
    if "[SPLIT]" not in text:
        # 先把所有的回车符统一成换行符
        processed_text = processed_text.replace("\r\n", "\n")
        # 匹配括号在行首的情况，在前面插入 [SPLIT]（除了第一行）
        var regex = RegEx.new()
        # 查找连续两个以上的换行符，并且下一行以全角或半角括号开头
        regex.compile("\\n+\\s*([（\\(])")
        processed_text = regex.sub(processed_text, "[SPLIT]$1", true)
        
        # 如果还是没有拆分开，尝试简单的多换行拆分
        if "[SPLIT]" not in processed_text:
            regex.compile("\\n{2,}")
            processed_text = regex.sub(processed_text, "[SPLIT]", true)
            
    var chunks = processed_text.split("[SPLIT]")
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
        if "character_voice_types" in GameDataManager.config and GameDataManager.config.character_voice_types.has(char_id):
            v_type = GameDataManager.config.character_voice_types[char_id]
            
        var options = {"voice_type": v_type}
        
        # 移除有垃圾回收风险的 Lambda 和本地数组，使用成员变量控制
        _tts_finished = false
        
        var on_success = func(_stream: AudioStream, _text: String): 
            _tts_finished = true
        var on_failed = func(_err: String, _text: String): 
            _tts_finished = true
            
        TTSManager.tts_success.connect(on_success, CONNECT_ONE_SHOT)
        TTSManager.tts_failed.connect(on_failed, CONNECT_ONE_SHOT)
        
        TTSManager.synthesize(tts_text, options)
        
        # 第一阶段：死等网络请求回来（最多等10秒）
        var wait_net = 0.0
        while not _tts_finished and wait_net < 10.0:
            await get_tree().process_frame
            wait_net += get_process_delta_time()
            
        # 防止意外泄漏断开连接
        if TTSManager.tts_success.is_connected(on_success):
            TTSManager.tts_success.disconnect(on_success)
        if TTSManager.tts_failed.is_connected(on_failed):
            TTSManager.tts_failed.disconnect(on_failed)
            
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
    pass # 独立桌宠版本移除了主界面联动

func _on_close_pressed() -> void:
    # 先隐藏窗口并切断输入流，防止 _push_unhandled_input_internal 报错
    hide()
    
    # release_focus() 属于 Control 节点，Window 节点没有这个方法
    # 取消当前窗口中所有 Control 的焦点
    var focused_node = get_viewport().gui_get_focus_owner()
    if focused_node:
        focused_node.release_focus()
        
    # 如果 DesktopPet 是根节点（主场景），关闭桌宠就意味着退出程序
    get_tree().quit()

func _unhandled_input(event: InputEvent) -> void:
    # 如果打开了设置界面，禁止拖拽和右键菜单
    if settings_panel_instance and settings_panel_instance.is_visible_in_tree():
        dragging = false
        return
        
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
                # 因为现在是伪全屏，拖拽的是内部的 Control 节点而不是窗口
                var control_node = $Control
                drag_offset = Vector2i(get_viewport().get_mouse_position()) - Vector2i(control_node.position)
            else:
                dragging = false
    elif event is InputEventMouseMotion and dragging:
        var control_node = $Control
        var new_pos = Vector2i(get_viewport().get_mouse_position()) - drag_offset
        var screen_size = DisplayServer.screen_get_size()
        
        # 控制节点现在是真实的小尺寸，正常限制在屏幕范围内即可，允许稍微超出一点边缘
        new_pos.x = clampi(new_pos.x, -100, screen_size.x - int(control_node.size.x) + 100)
        new_pos.y = clampi(new_pos.y, -100, screen_size.y - int(control_node.size.y) + 100)
        
        control_node.position = new_pos
        call_deferred("_update_mouse_passthrough")

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
        var _time_constraint = _get_time_constraint(h)
        var prompt = """【系统提示：当前现实时间是 %02d:%02d，玩家用鼠标轻轻戳了触碰了你一下。】
请你结合当前时间作为隐性语境，代入你的性格和当前心情，像真人一样对玩家的触碰做出最自然的反应。
- 反应要生动多样！可以是撒娇、傲娇吐槽、疑惑等，取决于你们的关系和心情。
- 结合你们的【微习惯与口癖】。
- 【格式强制】：你的回复必须完全遵循系统提示词中的【对话结构策略】（使用[SPLIT]等规则，必须包含括号动作描写）。
- 绝对不要在台词中报出当前时间，绝对不能提到你是AI或桌宠。""" % [h, m]
        _trigger_proactive_chat(prompt)

func _update_mouse_passthrough() -> void:
    print("[DesktopPet Debug] _update_mouse_passthrough started")
    # 确保窗口已经有效存在且没有在被销毁的过程中
    if not is_inside_tree() or is_queued_for_deletion():
        print("[DesktopPet Debug] Window not in tree or queued for deletion")
        return
        
    var main_window = get_window()
    if not main_window:
        return
        
    var win_id = main_window.get_window_id()
    if win_id == DisplayServer.INVALID_WINDOW_ID:
        print("[DesktopPet Debug] INVALID_WINDOW_ID")
        return
        
    print("[DesktopPet Debug] Gathering rects...")
    var rects: Array[Rect2] = []

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
            
    # 如果打开了设置面板，只拦截设置面板本身所在的区域
    if settings_panel_instance and settings_panel_instance.is_visible_in_tree():
        # 计算设置面板在全局屏幕上的实际位置
        var global_pos = $Control.position + settings_panel_instance.position
        rects.append(Rect2(global_pos, settings_panel_instance.size))

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
