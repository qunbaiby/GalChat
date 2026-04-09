extends Window

@onready var bubble_container: VBoxContainer = $Control/BubbleContainer
@onready var input_edit: LineEdit = $Control/HBoxContainer/InputEdit
@onready var send_button: Button = $Control/HBoxContainer/SendButton
@onready var main_window_button: Button = $Control/HBoxContainer/MainWindowButton
@onready var close_button: Button = $Control/HBoxContainer/CloseButton
@onready var deepseek_client: DeepSeekClient = $DeepSeekClient
@onready var doubao_tts = $DoubaoTTSService
@onready var audio_player: AudioStreamPlayer = $AudioStreamPlayer
@onready var pet_spine = get_node_or_null("Control/PetContainer/SpineSprite")

# 隐藏的模板气泡
@onready var bubble_template: PanelContainer = $Control/BubbleContainer/SpeechBubble

var dragging: bool = false
var drag_offset: Vector2i = Vector2i.ZERO
var _pet_click_start_pos: Vector2 = Vector2.ZERO

var pet_prompt: String = ""
var is_chatting: bool = false
var current_response: String = ""
var chat_history: Array = []

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

func _ready() -> void:
    # 初始化上次交互时间为 0，避免启动后立刻触发被拦截
    # _last_reaction_tick = 0
    
    # 设置窗口属性：无边框透明
    transparent_bg = true
    transparent = true
    borderless = true
    always_on_top = true
    unresizable = true
    
    # 设置为小窗口大小
    var target_size = Vector2i(300, 680)
    size = target_size
    
    # 初始位置：右下角
    var current_screen = DisplayServer.window_get_current_screen()
    var screen_size = DisplayServer.screen_get_size(current_screen)
    var init_pos = Vector2i(screen_size.x - target_size.x - 50, screen_size.y - target_size.y - 80)
    position = init_pos
    
    # 确保内部 Control 占满整个小窗口
    var control_node = $Control
    control_node.set_anchors_preset(Control.PRESET_FULL_RECT)
    control_node.size = Vector2(300, 680)
    control_node.position = Vector2.ZERO
    
    # 隐藏模板
    bubble_template.hide()
    
    # 注入豆包 TTS 的 AppID 和 Token 配置
    if GameDataManager.config.doubao_app_id != "" and GameDataManager.config.doubao_token != "":
        doubao_tts.setup_auth(GameDataManager.config.doubao_app_id, GameDataManager.config.doubao_token, GameDataManager.config.doubao_cluster)
    
    # 连接信号
    send_button.pressed.connect(_on_send_pressed)
    main_window_button.pressed.connect(_on_main_window_pressed)
    close_button.pressed.connect(_on_close_pressed)
    input_edit.text_submitted.connect(func(text): _on_send_pressed())
    
    deepseek_client.chat_stream_started.connect(_on_chat_started)
    deepseek_client.chat_stream_delta.connect(_on_chat_delta)
    deepseek_client.chat_request_completed.connect(_on_chat_completed)
    deepseek_client.chat_request_failed.connect(_on_chat_failed)
    
    doubao_tts.tts_success.connect(_on_tts_success)
    doubao_tts.tts_failed.connect(_on_tts_failed)
    
    _load_prompt()
    
    # 连接 Control 面板的输入信号以处理拖拽
    control_node.mouse_filter = Control.MOUSE_FILTER_STOP
    control_node.gui_input.connect(_on_control_gui_input)
    
    # 初始化轮询定时器
    _poll_timer = Timer.new()
    _poll_timer.wait_time = 5.0
    _poll_timer.autostart = true
    _poll_timer.timeout.connect(_on_poll_timer_timeout)
    add_child(_poll_timer)
    
    # 根据任务要求监听 speech_bubble (即 bubble_template) 的 visibility_changed 信号
    bubble_template.visibility_changed.connect(func(): call_deferred("_update_mouse_passthrough"))
    
    # 监听容器排版更新以处理气泡动态添加和删除时的尺寸变化
    bubble_container.sort_children.connect(func(): call_deferred("_update_mouse_passthrough"))
    
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
    
    if pet_spine:
        # 尝试播放默认的 idle 动画
        var anim_state = pet_spine.get_animation_state()
        var skeleton = pet_spine.get_skeleton()
        if anim_state and skeleton and skeleton.get_data():
            var anims = skeleton.get_data().get_animations()
            if anims.size() > 0:
                var target_anim = anims[0].get_name()
                for a in anims:
                    if "idle" in a.get_name().to_lower() or "daiji" in a.get_name().to_lower():
                        target_anim = a.get_name()
                        break
                anim_state.set_animation(target_anim, true, 0)
                
        # 绑定触碰事件
        var spine_control = get_node_or_null("Control/PetContainer")
        if spine_control:
            spine_control.mouse_filter = Control.MOUSE_FILTER_STOP
            spine_control.gui_input.connect(_on_pet_clicked)


func _exit_tree() -> void:
    pass


func _load_prompt() -> void:
    pet_prompt = GameDataManager.prompt_manager.build_system_prompt(GameDataManager.profile, "desktop_pet")
    if pet_prompt.is_empty():
        pet_prompt = "你扮演一名AI伴侣，名字叫{{char_name}}。现在你是玩家的桌宠。请用简短、可爱、日常的语气回答玩家的问题。你的回答应该像在桌面上轻声细语，每次回答不应超过三句话。"
        var char_name = GameDataManager.profile.char_name if GameDataManager.profile.char_name != "" else "Luna"
        pet_prompt = pet_prompt.replace("{{char_name}}", char_name)

func _on_poll_timer_timeout() -> void:
    _check_hourly_chime()
    _check_active_window()

func _check_active_window() -> void:
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
        
    var current_tick = Time.get_ticks_msec()
    
    # 修改逻辑：当停留超过特定时间（如10秒）时，允许触发
    # 为了防止不切窗口就再也不触发，我们通过检查冷却时间(比如3分钟=180000ms)来允许重复触发
    if _time_since_last_switch >= 10.0:
        var cooldown_time = 180000 # 同一个应用连续停留，每3分钟可以再次吐槽一次
        if _last_chatted_app != app_identifier:
            cooldown_time = 30000 # 刚切到新应用，只需要和上一次任何对话间隔30秒即可
            
        if current_tick - _last_reaction_tick < cooldown_time:
            # 还在冷却中
            return
            
        _last_chatted_app = app_identifier
        _last_reaction_tick = current_tick
        
        # 既然重新触发了，把停留时间减掉一部分，或者保持不动，只要受冷却时间控制即可
        
        var app_type = _map_app_type(window_title, process_name)
        var prompt = "【系统动作：玩家已经盯着名为“%s”的窗口（识别为%s）很久了。请根据你当前的心情和性格，以及你们的关系阶段，对此发表一句简短可爱的关心或吐槽。】" % [window_title, app_type]
        print("[DesktopPet Debug] Triggering proactive chat: ", prompt)
        _trigger_proactive_chat(prompt)

func _map_app_type(title: String, process: String) -> String:
    var p = process.to_lower()
    var t = title.to_lower()
    
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
    elif "code" in p or "idea" in p or "studio" in p or "devenv" in p or "pycharm" in p:
        return "编程开发工具"
    elif "word" in p or "excel" in p or "powerpoint" in p or "wps" in p:
        return "办公文档软件"
    elif "steam" in p or "game" in p or "epic" in p:
        return "游戏平台/游戏"
    elif "wechat" in p or "qq" in p or "discord" in p or "telegram" in p:
        return "通讯聊天软件"
    elif "bilibili" in p or "youtube" in p or "video" in p or "player" in p:
        return "视频播放软件"
    elif "music" in p or "cloudmusic" in p or "netease" in p or "spotify" in p:
        return "音乐播放软件"
        
    return process if process != "" else "某个应用"

func _check_hourly_chime() -> void:
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
        if current_hour >= 6 and current_hour < 11:
            time_str = "清晨"
        elif current_hour >= 11 and current_hour < 14:
            time_str = "中午"
        elif current_hour >= 14 and current_hour < 19:
            time_str = "下午"
        elif current_hour >= 19 and current_hour < 23:
            time_str = "晚上"
        else:
            time_str = "深夜"
            
        var prompt = "【系统提示：现在是现实时间%s %02d:00。请作为桌宠，根据你的性格，用简短的话语提醒玩家注意时间或进行整点报时。】" % [time_str, current_hour]
        _trigger_proactive_chat(prompt)


func _trigger_proactive_chat(prompt_text: String) -> void:
    is_chatting = true
    current_response = ""
    
    bubble_queue.clear()
    if audio_player and audio_player.playing:
        audio_player.stop()
        
    # 维护历史记录长度
    if chat_history.size() > 10:
        chat_history = chat_history.slice(-10)
        
    # print("[DesktopPet Debug] Sending request to DeepSeek...")
    deepseek_client.send_desktop_pet_chat_stream(prompt_text, pet_prompt, chat_history)
    
    # 将系统触发的提示以系统事件的形式加入历史记录
    chat_history.append({"role": "user", "content": "【系统事件】" + prompt_text})

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
    if audio_player and audio_player.playing:
        audio_player.stop()
    
    # Maintain history (max 10 items to prevent context window overflow)
    if chat_history.size() > 10:
        chat_history = chat_history.slice(-10)
    
    deepseek_client.send_desktop_pet_chat_stream(text, pet_prompt, chat_history)
    
    # Add user message to history
    chat_history.append({"role": "user", "content": text})

func _on_chat_started() -> void:
    current_response = ""

func _on_chat_delta(delta_text: String) -> void:
    current_response += delta_text

func _on_chat_completed(response: Dictionary) -> void:
    is_chatting = false
    
    # Extract response text
    var text = ""
    if response.has("choices") and response.choices.size() > 0:
        text = response.choices[0].message.content
    else:
        text = current_response
        
    # Add assistant message to history
    chat_history.append({"role": "assistant", "content": text})
        
    display_bubble(text)

func _on_chat_failed(error_msg: String) -> void:
    _add_bubble("[color=red]错误: " + error_msg + "[/color]")
    is_chatting = false

func display_bubble(text: String) -> void:
    var chunks = text.split("[SPLIT]")
    for chunk in chunks:
        var c = chunk.strip_edges()
        if not c.is_empty():
            bubble_queue.append(c)
            
    if not is_processing_bubbles:
        _process_next_bubble()

func _add_bubble(text: String, is_typewriter: bool = false) -> void:
    var bubble = bubble_template.duplicate()
    bubble.visible = true
    bubble_container.add_child(bubble)
    
    var label: RichTextLabel = bubble.get_node("MarginContainer/RichTextLabel")
    label.text = text
    
    if is_typewriter:
        label.visible_characters = 0
        var plain_text = text.replace("[color=green]", "").replace("[/color]", "")
        var parsed_len = plain_text.length()
        var duration = parsed_len * 0.05
        if duration <= 0: duration = 0.5
        var tween = create_tween()
        tween.tween_property(label, "visible_ratio", 1.0, duration)
        tween.finished.connect(func(): label.visible_characters = -1)
    
    # 限制最多3个气泡
    var bubbles = bubble_container.get_children()
    # The first child is the hidden template
    if bubbles.size() > 4:
        bubbles[1].queue_free()
        
    # 设定气泡超时自动消失（由于有语音播放的需求，恢复为稍长的时间 10 秒后，以免文字消失比语音还快）
    var timer = get_tree().create_timer(10.0)
    var bubble_ref = weakref(bubble)
    timer.timeout.connect(func():
        var b = bubble_ref.get_ref()
        if b and is_instance_valid(b):
            var fade_tween = create_tween()
            fade_tween.tween_property(b, "modulate:a", 0.0, 0.5)
            fade_tween.finished.connect(func(): 
                if is_instance_valid(b): 
                    b.queue_free()
            )
    )

func _remove_last_bubble() -> void:
    var bubbles = bubble_container.get_children()
    if bubbles.size() > 1:
        bubbles[bubbles.size() - 1].queue_free()

func _process_next_bubble() -> void:
    if bubble_queue.is_empty():
        is_processing_bubbles = false
        return
        
    is_processing_bubbles = true
    var chunk = bubble_queue.pop_front()
    
    # Parse green action text and pure dialogue for TTS
    var display_text = _format_action_text(chunk)
    var tts_text = _extract_dialogue_text(chunk)
    
    _add_bubble(display_text, true)
    
    if GameDataManager.config.voice_enabled and tts_text != "":
        var options = {"voice_type": GameDataManager.config.doubao_voice_type}
        
        # 将标志位存入数组，以便在 Lambda 内部能够修改外层变量引用（GDScript 4.x 闭包机制）
        var tts_state = [false]
        
        var on_success = func(stream: AudioStream, text: String): tts_state[0] = true
        var on_failed = func(err: String, text: String): tts_state[0] = true
        
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

func _on_tts_success(audio_stream: AudioStream, text: String) -> void:
    if audio_player:
        audio_player.stream = audio_stream
        audio_player.play()

func _on_tts_failed(error_msg: String, text: String) -> void:
    print("Desktop Pet TTS failed: ", error_msg)

func _on_main_window_pressed() -> void:
    # 重新显示主窗口并请求焦点
    var current_scene: Node = get_tree().current_scene
    if current_scene and current_scene is Window:
        current_scene.show()
        current_scene.grab_focus()
        DisplayServer.window_request_attention()

func _on_close_pressed() -> void:
    queue_free()
    # 如果关闭桌宠时，主窗口被隐藏了，则彻底退出
    var current_scene = get_tree().current_scene
    if current_scene and not current_scene.visible:
        get_tree().quit()

func _on_control_gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT:
            if event.pressed:
                dragging = true
                drag_offset = Vector2i(event.global_position)
            else:
                dragging = false
    elif event is InputEventMouseMotion and dragging:
        # 更新 Window 位置
        position = DisplayServer.mouse_get_position() - drag_offset

func _on_pet_clicked(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed:
            _pet_click_start_pos = event.global_position
            dragging = true
            drag_offset = Vector2i(event.global_position)
        else:
            dragging = false
            # 当鼠标松开时，如果位置没有发生明显偏移（偏移量小于10像素），才视为点击
            var dist = event.global_position.distance_to(_pet_click_start_pos)
            if dist < 10.0:
                _trigger_pet_touch()
    elif event is InputEventMouseMotion and dragging:
        # 当发生明显拖拽时，将起始点设为一个极远的位置，确保松开时不会触发点击
        var dist = event.global_position.distance_to(_pet_click_start_pos)
        if dist >= 10.0:
            _pet_click_start_pos = Vector2(-9999, -9999)
            
        position = DisplayServer.mouse_get_position() - drag_offset

func _trigger_pet_touch() -> void:
    if not pet_spine:
        return
        
    var anim_state = pet_spine.get_animation_state()
    if not anim_state:
        return
        
    var current_tick = Time.get_ticks_msec()
    # 增加一个冷却时间，防止疯狂点击
    if current_tick - _last_reaction_tick < 3000:
        return
        
    _last_reaction_tick = current_tick
    
    # 播放交互动画（例如 blink，或者是其他的动作），播放完后再切回 idle
    var skeleton = pet_spine.get_skeleton()
    var idle_anim = "Idle"
    var interact_anim = "Blink"
    
    if skeleton and skeleton.get_data():
        var anims = skeleton.get_data().get_animations()
        var anim_names = []
        for a in anims:
            anim_names.append(a.get_name())
            
        # 如果找不到预设名字，随便找个非 idle 的动作播放
        if not interact_anim in anim_names and anim_names.size() > 1:
            for name in anim_names:
                if name.to_lower() != "idle" and name.to_lower() != "daiji":
                    interact_anim = name
                    break
                    
        if idle_anim not in anim_names:
            idle_anim = anim_names[0]
    
    # track 0 播放交互动画，不循环
    anim_state.set_animation(interact_anim, false, 0)
    # 交互动画结束后，把待机动画加入队列排队播放，开启循环
    anim_state.add_animation(idle_anim, 0.0, true, 0)
    
    # 触发聊天
    if not is_chatting:
        var prompt = "【系统动作：玩家用鼠标轻轻戳了触碰了你一下。请根据你的性格和当前心情，做出可爱的回应或吐槽，一两句话即可。】"
        _trigger_proactive_chat(prompt)

func _update_mouse_passthrough() -> void:
    # 确保窗口已经有效存在
    if not is_inside_tree() or get_window_id() == DisplayServer.INVALID_WINDOW_ID:
        return
        
    var rects: Array[Rect2] = []
    
    var pet_container = get_node_or_null("Control/PetContainer")
    if pet_container and pet_container.is_visible_in_tree():
        rects.append(pet_container.get_global_rect().grow(5))
        
    var hbox_container = get_node_or_null("Control/HBoxContainer")
    if hbox_container and hbox_container.is_visible_in_tree():
        rects.append(hbox_container.get_global_rect().grow(5))
        
    if bubble_container:
        for child in bubble_container.get_children():
            # 只有当气泡可见时才将其加入碰撞区域
            if child is Control and child.is_visible_in_tree():
                rects.append(child.get_global_rect().grow(5))
                
    if rects.is_empty():
        # 如果没有矩形，为了实现全穿透，传递一个在屏幕外的极小多边形
        var dummy := PackedVector2Array([
            Vector2(-10, -10), Vector2(-9, -10),
            Vector2(-9, -9), Vector2(-10, -9)
        ])
        DisplayServer.window_set_mouse_passthrough(dummy, get_window_id())
        return
        
    var polygon := PackedVector2Array()
    var first = rects[0]
    
    # 绘制第一个矩形
    polygon.append(first.position)
    polygon.append(Vector2(first.end.x, first.position.y))
    polygon.append(first.end)
    polygon.append(Vector2(first.position.x, first.end.y))
    polygon.append(first.position)
    
    # 使用零宽桥接(Zero-width bridge)连接后续独立的矩形，形成单个多边形
    for i in range(1, rects.size()):
        var r = rects[i]
        
        # 从第一个矩形的起点连到当前矩形的起点 (去程桥接)
        polygon.append(r.position)
        
        # 绘制当前矩形
        polygon.append(Vector2(r.end.x, r.position.y))
        polygon.append(r.end)
        polygon.append(Vector2(r.position.x, r.end.y))
        polygon.append(r.position)
        
        # 从当前矩形的起点连回第一个矩形的起点 (回程桥接)
        polygon.append(first.position)
        
    DisplayServer.window_set_mouse_passthrough(polygon, get_window_id())
