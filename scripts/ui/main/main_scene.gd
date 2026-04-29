extends Control

@onready var ui_panel: Panel = $UIPanel
@onready var galchat_button: Button = $UIPanel/StoryButton
@onready var activity_button: Button = $UIPanel/ActivityButton
@onready var desktop_pet_button: Button = $UIPanel/BottomPanel/BottomButton/DesktopPetButton
@onready var hide_ui_button: Button = $UIPanel/SystemButton/HideUIButton
@onready var settings_button: Button = $UIPanel/SystemButton/SettingsButton
@onready var affection_button: Button = $UIPanel/AffectionButton
@onready var phone_button: Button = $UIPanel/BottomPanel/BottomButton/PhoneButton
@onready var diary_button: Button = $UIPanel/BottomPanel/BottomButton/DiaryButton
@onready var map_button: Button = $UIPanel/MapButton
@onready var stats_panel = $UIPanel/StatsPanel
@onready var top_status_panel = $UIPanel/TopStatusPanel
@onready var bgm: AudioStreamPlayer = $BGM
@onready var music_player: Panel = $UIPanel/MusicPlayer
@onready var diary_panel: Control = $UIPanel/DiaryPanel
@onready var diary_notification: PanelContainer = $UIPanel/DiaryNotification
@onready var topic_panel: Panel = $TopicPanel
@onready var topic_container: VBoxContainer = $TopicPanel/TopicContainer
@onready var dialogue_panel: Control = $DialoguePanel
@onready var dialogue_name_label: Label = $DialoguePanel/DialogueLayer/NameLabel
@onready var dialogue_text: RichTextLabel = $DialoguePanel/DialogueLayer/RichTextLabel
@onready var input_layer: Panel = $DialoguePanel/InputLayer
@onready var input_field: TextEdit = $DialoguePanel/InputLayer/HBoxContainer/InputField
@onready var send_btn: Button = $DialoguePanel/InputLayer/HBoxContainer/SendButton
@onready var end_chat_btn: Button = $DialoguePanel/DialogueLayer/EndChatButton
@onready var history_btn: Button = $DialoguePanel/DialogueLayer/HistoryButton
@onready var quick_options_container: VBoxContainer = $DialoguePanel/QuickOptionLayer/QuickOptions

@onready var deepseek_client = $DeepSeekClient

@onready var chat_button: Button = $UIPanel/InteractGroup/ChatButton
@onready var rest_button: Button = $UIPanel/InteractGroup/RestButton

var activity_panel_instance = null

var _chat_tween: Tween = null
var _typewriter_tween: Tween = null
var stream_live_buffer: String = ""
var stream_live_active: bool = false

const QUICK_OPTION_ITEM_SCENE = preload("res://scenes/ui/story/quick_option_item.tscn")

var settings_panel_instance = null
var desktop_pet_instance: Window = null
var chat_scene_instance = null
var archive_panel_instance = null
var affection_panel_instance = null
var mobile_interface_instance = null
var incoming_call_notification_instance = null
var history_panel_instance = null

var _window_detector: Node = null
var _is_afk: bool = false
var _afk_timer: Timer = null
var _ui_tween: Tween = null
var doubao_tts = null
var audio_player: AudioStreamPlayer = null

var map_scene_instance = null

const TOPIC_LIST = [
    "最近在忙些什么呢？",
    "今天天气真不错，对吧？",
    "有什么心事想和我聊聊吗？",
    "推荐一本你喜欢的书或电影吧。",
    "聊聊你的兴趣爱好吧！",
    "最近有遇到什么有趣的事吗？",
    "周末通常是怎么过的呢？"
]

var stream_live_queue: Array = []
var stream_live_worker_running: bool = false
var stream_live_done: bool = false

var _waiting_for_chat_click: bool = false
signal _chat_click_proceed

var pending_options_data = []
var is_text_playback_finished = true

func _on_main_chat_pressed() -> void:
    _animate_button(chat_button)
    
    if _ui_tween:
        _ui_tween.kill()
    _ui_tween = create_tween()
    _ui_tween.tween_property(ui_panel, "modulate:a", 0.0, 0.3)
    _ui_tween.tween_callback(func(): ui_panel.visible = false)
    
    topic_panel.visible = true
    topic_panel.modulate.a = 0.0
    var t_tween = create_tween()
    t_tween.tween_property(topic_panel, "modulate:a", 1.0, 0.3)
    
    _populate_topics()

func _populate_topics() -> void:
    for child in topic_container.get_children():
        child.queue_free()
        
    var topics = TOPIC_LIST.duplicate()
    topics.shuffle()
    topics = topics.slice(0, 3)
    
    for topic_text in topics:
        var btn = Button.new()
        btn.text = topic_text
        btn.custom_minimum_size = Vector2(0, 50)
        btn.add_theme_font_size_override("font_size", 20)
        topic_container.add_child(btn)
        btn.pressed.connect(_on_topic_selected.bind(topic_text))

func _on_topic_selected(topic: String) -> void:
    var t_tween = create_tween()
    t_tween.tween_property(topic_panel, "modulate:a", 0.0, 0.3)
    t_tween.tween_callback(func(): topic_panel.visible = false)
    
    dialogue_panel.visible = true
    dialogue_panel.modulate.a = 0.0
    var d_tween = create_tween()
    d_tween.tween_property(dialogue_panel, "modulate:a", 1.0, 0.3)
    
    dialogue_name_label.text = GameDataManager.profile.char_name
    dialogue_text.text = "..."
    input_field.text = ""
    input_field.editable = false
    send_btn.disabled = true
    
    for child in quick_options_container.get_children():
        child.queue_free()
        
    var user_msg = "【系统提示】玩家选择了话题：" + topic + "。请你根据这个话题作为开场白主动向玩家打招呼，不要复述系统提示，直接以第一人称代入角色进行对话。"
    deepseek_client.send_chat_message_stream(user_msg, "main_chat")

func _on_rest_pressed() -> void:
    _animate_button(rest_button)
    print("[MainScene] 休息按钮被点击，预留接口")

func _on_end_chat_pressed() -> void:
    if deepseek_client._chat_stream_active:
        deepseek_client._stop_chat_stream()
        
    stream_live_active = false
    stream_live_worker_running = false
    stream_live_queue.clear()
    
    if audio_player and audio_player.playing:
        audio_player.stop()
        
    if _typewriter_tween:
        _typewriter_tween.kill()
        
    var d_tween = create_tween()
    d_tween.tween_property(dialogue_panel, "modulate:a", 0.0, 0.3)
    d_tween.tween_callback(func(): dialogue_panel.visible = false)
    
    ui_panel.visible = true
    ui_panel.modulate.a = 0.0
    if _ui_tween:
        _ui_tween.kill()
    _ui_tween = create_tween()
    _ui_tween.tween_property(ui_panel, "modulate:a", 1.0, 0.3)

func _on_send_pressed() -> void:
    var text = input_field.text.strip_edges()
    if text.is_empty():
        return
        
    input_field.text = ""
    input_field.editable = false
    send_btn.disabled = true
    
    for child in quick_options_container.get_children():
        child.queue_free()
        
    GameDataManager.history.add_message("player", text, "", "main_chat")
    
    dialogue_name_label.text = "我"
    dialogue_text.text = text
    dialogue_text.visible_ratio = 0.0
    
    if _typewriter_tween:
        _typewriter_tween.kill()
    _typewriter_tween = create_tween()
    var dur = max(0.5, text.length() * 0.05)
    _typewriter_tween.tween_property(dialogue_text, "visible_ratio", 1.0, dur)
    
    if is_inside_tree():
        while _typewriter_tween and _typewriter_tween.is_valid() and _typewriter_tween.is_running():
            await get_tree().process_frame
            
    dialogue_text.visible_ratio = 1.0
    dialogue_text.visible_characters = -1
    
    deepseek_client.send_chat_message_stream(text, "main_chat")

func _on_chat_stream_started() -> void:
    stream_live_active = true
    stream_live_done = false
    stream_live_buffer = ""
    stream_live_queue.clear()
    is_text_playback_finished = false
    pending_options_data.clear()
    
    if _waiting_for_chat_click:
        _waiting_for_chat_click = false
        _chat_click_proceed.emit()
        
    _try_start_stream_worker()

func _on_chat_stream_delta(delta_text: String) -> void:
    if not stream_live_active:
        return
    stream_live_buffer += delta_text
    _extract_stream_segments(false)
    _try_start_stream_worker()

func _on_chat_response(response: Dictionary) -> void:
    if stream_live_active:
        stream_live_done = true
        _extract_stream_segments(true)
        _try_start_stream_worker()
        
        # 我们不再在这里直接保存全量内容，因为 _stream_worker_loop 会逐句保存并附带语音缓存
        # GameDataManager.history.add_message("char", deepseek_client._chat_stream_full_text, "", "main_chat")
        deepseek_client.send_options_generation(deepseek_client._chat_stream_full_text, "", "main_chat")
        return
        
    if response.has("choices") and response["choices"].size() > 0:
        var reply = response["choices"][0]["message"]["content"]
        # 我们不再在这里直接保存全量内容，因为 _stream_worker_loop 会逐句保存并附带语音缓存
        # GameDataManager.history.add_message("char", reply, "", "main_chat")
        deepseek_client.send_options_generation(reply, "", "main_chat")
            
        dialogue_name_label.text = GameDataManager.profile.char_name
        dialogue_text.text = reply
        dialogue_text.visible_ratio = 1.0
        input_field.editable = true
        send_btn.disabled = false
    else:
        dialogue_name_label.text = GameDataManager.profile.char_name
        dialogue_text.text = "似乎走神了..."
        input_field.editable = true
        send_btn.disabled = false

func _extract_stream_segments(force_flush: bool) -> void:
    var delim = "[SPLIT]"
    while true:
        var idx = stream_live_buffer.find(delim)
        if idx == -1:
            break
        var part = stream_live_buffer.substr(0, idx).strip_edges()
        stream_live_buffer = stream_live_buffer.substr(idx + delim.length())
        if part != "":
            stream_live_queue.append(part)
            
    if force_flush:
        var last_part = stream_live_buffer.strip_edges()
        stream_live_buffer = ""
        if last_part != "":
            var parts = _auto_split_message(last_part)
            for p in parts:
                if typeof(p) == TYPE_STRING:
                    var tp = p.strip_edges()
                    if tp != "":
                        stream_live_queue.append(tp)

func _auto_split_message(text: String) -> Array:
    if "[SPLIT]" in text:
        return text.split("[SPLIT]", false)
        
    var mood_tag = ""
    var pure_text = text
    var mood_regex = RegEx.new()
    mood_regex.compile("(?i)(?:<|\\<|《|\\[|【)\\s*(mood|心情)\\s*[:：]\\s*([^>\\>》\\]】]+)\\s*(?:>|\\>|》|\\]|】)")
    var mood_match = mood_regex.search(text)
    if mood_match:
        mood_tag = mood_match.get_string()
        pure_text = text.replace(mood_tag, "")
        
    var modified_text = pure_text
    
    # 新增策略0：优先将大模型输出的换行符视为消息分隔符
    # 很多时候AI会用换行来排版不同的动作和对话
    modified_text = modified_text.replace("\r\n", "\n")
    var nl_regex = RegEx.new()
    nl_regex.compile("\\n+")
    modified_text = nl_regex.sub(modified_text, "[SPLIT]", true)
    
    # 修复：确保连续的 [SPLIT] 被合并为一个
    modified_text = modified_text.replace("[SPLIT][SPLIT]", "[SPLIT]")
    modified_text = modified_text.replace("[SPLIT] [SPLIT]", "[SPLIT]")
    
    if not "[SPLIT]" in modified_text:
        var endings = ["。", "！", "？", "……", "”", "」", "~", "～"]
        var brackets = ["（", "("]
        
        # 策略1：根据“标点+动作括号”完美切分，这样刚好能保证切分后下一句以动作开头，带着后续的对话
        for end_char in endings:
            for bracket in brackets:
                modified_text = modified_text.replace(end_char + bracket, end_char + "[SPLIT]" + bracket)
                modified_text = modified_text.replace(end_char + " " + bracket, end_char + "[SPLIT]" + bracket)
                
        # 策略2：如果文本仍未切分且过长（>80字），强行按标点切分
        if not "[SPLIT]" in modified_text and modified_text.length() > 80:
            modified_text = modified_text.replace("。", "。[SPLIT]")
            modified_text = modified_text.replace("！", "！[SPLIT]")
            modified_text = modified_text.replace("？", "？[SPLIT]")
            # 避免把连续的标点切碎
            modified_text = modified_text.replace("[SPLIT][SPLIT]", "[SPLIT]")
        
    var parts = modified_text.split("[SPLIT]", false)
    var merged_parts = []
    var temp_str = ""
    
    for p in parts:
        var tp = p.strip_edges()
        if tp == "": continue
        
        if temp_str == "":
            temp_str = tp
        else:
            # 优化：判断当前片段(tp)或者暂存片段(temp_str)是否*仅仅*包含动作描写（没有实质对话内容）
            var tp_clean = tp
            var temp_clean = temp_str
            var action_regex = RegEx.new()
            action_regex.compile("（.*?）|\\(.*?\\)")
            tp_clean = action_regex.sub(tp_clean, "", true).strip_edges()
            temp_clean = action_regex.sub(temp_clean, "", true).strip_edges()
            
            # 如果其中一个片段仅仅只有动作描写（去掉括号后无内容），则必须合并
            if tp_clean == "" or temp_clean == "":
                temp_str += " " + tp
            else:
                merged_parts.append(temp_str)
                temp_str = tp
                
    if temp_str != "":
        merged_parts.append(temp_str)
        
    # 新增限制：如果某一条消息长度超过 60，强制进行二次切分
    var final_split_parts = []
    for part in merged_parts:
        if part.length() > 60:
            var split_part = part
            var endings = ["。", "！", "？", "……", "”", "」", "~", "～"]
            var brackets = ["（", "("]
            # 尝试在动作前切分
            for end_char in endings:
                for bracket in brackets:
                    split_part = split_part.replace(end_char + bracket, end_char + "[FORCE_SPLIT]" + bracket)
                    split_part = split_part.replace(end_char + " " + bracket, end_char + "[FORCE_SPLIT]" + bracket)
            
            # 如果依然没有切分开，强行按标点切分
            if not "[FORCE_SPLIT]" in split_part:
                split_part = split_part.replace("。", "。[FORCE_SPLIT]")
                split_part = split_part.replace("！", "！[FORCE_SPLIT]")
                split_part = split_part.replace("？", "？[FORCE_SPLIT]")
                split_part = split_part.replace("[FORCE_SPLIT][FORCE_SPLIT]", "[FORCE_SPLIT]")
                
            var sub_parts = split_part.split("[FORCE_SPLIT]", false)
            for sp in sub_parts:
                if sp.strip_edges() != "":
                    final_split_parts.append(sp.strip_edges())
        else:
            final_split_parts.append(part)
            
    merged_parts = final_split_parts
        
    # 限制最多3条
    if merged_parts.size() > 3:
        # 只保留前3条，或者把后面的内容全部合并到第3条里
        var truncated_parts = []
        truncated_parts.append(merged_parts[0])
        truncated_parts.append(merged_parts[1])
        truncated_parts.append(merged_parts[2])
        merged_parts = truncated_parts
        
    if merged_parts.size() > 0 and mood_tag != "":
        merged_parts[merged_parts.size() - 1] += mood_tag
        
    if merged_parts.size() == 0:
        return [text]
        
    return merged_parts

func _try_start_stream_worker() -> void:
    if stream_live_worker_running:
        return
    stream_live_worker_running = true
    _stream_worker_loop()

func _stream_worker_loop() -> void:
    while stream_live_queue.size() > 0 or (stream_live_active and not stream_live_done):
        if not stream_live_active and stream_live_queue.size() == 0:
            break
            
        if stream_live_queue.size() > 0:
            var text = stream_live_queue.pop_front()
            
            # 清理情绪标签等
            var mood_regex = RegEx.new()
            mood_regex.compile("(?i)(?:<|\\<|《|\\[|【)\\s*(mood|心情)\\s*[:：]\\s*([^>\\>》\\]】]+)\\s*(?:>|\\>|》|\\]|】)")
            var pure_text = mood_regex.sub(text, "", true).strip_edges()
            
            if pure_text == "":
                continue
                
            dialogue_name_label.text = GameDataManager.profile.char_name
            dialogue_text.text = pure_text
            dialogue_text.visible_ratio = 0.0
            
            var current_cache_key = ""
            
            if _typewriter_tween:
                _typewriter_tween.kill()
            _typewriter_tween = create_tween()
            var dur = max(0.5, pure_text.length() * 0.05)
            _typewriter_tween.tween_property(dialogue_text, "visible_ratio", 1.0, dur)
            
            var is_tts_started = false
            var tts_text = pure_text
            var action_regex = RegEx.new()
            action_regex.compile("（.*?）|\\(.*?\\)")
            tts_text = action_regex.sub(tts_text, "", true).strip_edges()
            
            if GameDataManager.config.voice_enabled and doubao_tts:
                var regex_tts = RegEx.new()
                regex_tts.compile("[a-zA-Z0-9\u4e00-\u9fa5]")
                if regex_tts.search(tts_text) != null:
                    is_tts_started = true
                    var char_id = GameDataManager.config.current_character_id
                    var v_type = "ICL_zh_female_bingruoshaonv_tob"
                    if GameDataManager.config.character_voice_types.has(char_id):
                        v_type = GameDataManager.config.character_voice_types[char_id]
                    var options = {"voice_type": v_type}
                    # 保存 cache key，为了后续写入历史记录关联语音播放
                    current_cache_key = doubao_tts._generate_cache_key(tts_text, options)
                    doubao_tts.synthesize(tts_text, options)
            
            # 这里必须等待一帧，确保 TTS 组件内部有机会触发 success 信号
            await get_tree().process_frame
            
            # 将该条切分后的消息存入历史记录中
            GameDataManager.history.add_message("char", pure_text, current_cache_key, "main_chat")
            
            if is_inside_tree():
                while _typewriter_tween and _typewriter_tween.is_valid() and _typewriter_tween.is_running():
                    if not stream_live_active:
                        break
                    await get_tree().process_frame
                    
            if not stream_live_active:
                break
                
            dialogue_text.visible_ratio = 1.0
            dialogue_text.visible_characters = -1
            
            if is_inside_tree():
                _waiting_for_chat_click = true
                
            if is_tts_started and is_inside_tree() and audio_player:
                var wait_count = 0
                while not audio_player.playing and wait_count < 10:
                    if not stream_live_active or not _waiting_for_chat_click:
                        break
                    await get_tree().create_timer(0.05).timeout
                    wait_count += 1
                    
                wait_count = 0
                while audio_player.playing and is_inside_tree() and wait_count < 1200:
                    if not stream_live_active or not _waiting_for_chat_click:
                        if audio_player: audio_player.stop()
                        break
                    await get_tree().create_timer(0.05).timeout
                    wait_count += 1
                    
            if is_inside_tree() and _waiting_for_chat_click:
                await _chat_click_proceed
                
            if audio_player and audio_player.playing:
                audio_player.stop()
                
            if not stream_live_active:
                break
        else:
            if is_inside_tree():
                await get_tree().create_timer(0.1).timeout
            
    stream_live_worker_running = false
    stream_live_active = false
    
    is_text_playback_finished = true
    _try_show_options()
    
    input_field.editable = true
    send_btn.disabled = false

func _on_chat_click_proceed_handler() -> void:
    pass

func _on_tts_success(audio_stream: AudioStream, text: String) -> void:
    if audio_player:
        audio_player.stream = audio_stream
        audio_player.play()

func _on_tts_failed(error_msg: String, text: String) -> void:
    print("MainScene TTS 失败: ", error_msg)

func _on_dialogue_panel_gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        if dialogue_text.visible_ratio < 1.0:
            if _typewriter_tween:
                _typewriter_tween.kill()
            dialogue_text.visible_ratio = 1.0
            dialogue_text.visible_characters = -1
        elif _waiting_for_chat_click:
            _waiting_for_chat_click = false
            _chat_click_proceed.emit()

func _on_options_response(response: Dictionary) -> void:
    if response.has("choices") and response["choices"].size() > 0:
        var reply = response["choices"][0]["message"]["content"]
        var json = JSON.new()
        
        # 提取可能的 JSON 代码块
        var json_str = reply
        var regex = RegEx.new()
        regex.compile("```(?:json)?\\s*(\\{[\\s\\S]*?\\})\\s*```")
        var match = regex.search(reply)
        if match:
            json_str = match.get_string(1).strip_edges()
        else:
            var start_idx = reply.find("{")
            var end_idx = reply.rfind("}")
            if start_idx != -1 and end_idx != -1 and end_idx > start_idx:
                json_str = reply.substr(start_idx, end_idx - start_idx + 1)
                
        if json.parse(json_str.strip_edges()) == OK:
            var data = json.get_data()
            if data is Dictionary and data.has("options") and data["options"] is Array:
                pending_options_data = data["options"]
                _try_show_options()
                return

func _try_show_options() -> void:
    if is_text_playback_finished and pending_options_data.size() > 0:
        for child in quick_options_container.get_children():
            child.queue_free()
            
        for opt_text in pending_options_data:
            if typeof(opt_text) == TYPE_STRING:
                var item = QUICK_OPTION_ITEM_SCENE.instantiate()
                quick_options_container.add_child(item)
                item.setup(opt_text)
                item.option_selected.connect(_on_quick_option_selected)
                
        pending_options_data.clear()

func _on_quick_option_selected(text: String) -> void:
    input_field.text = text
    _on_send_pressed()

func _ready() -> void:
    if GameDataManager.config:
        GameDataManager.config.apply_settings()
        
    var window = get_window()
    if GameDataManager.has_meta("last_window_pos"):
        var last_pos = GameDataManager.get_meta("last_window_pos")
        if typeof(last_pos) == TYPE_VECTOR2I or typeof(last_pos) == TYPE_VECTOR2:
            window.position = last_pos
        else:
            window.move_to_center()
    else:
        window.move_to_center()
        
    window.close_requested.connect(_on_close_requested)
    
    galchat_button.pressed.connect(_on_galchat_pressed)
    settings_button.pressed.connect(_on_settings_pressed)
    hide_ui_button.pressed.connect(_on_hide_ui_pressed)
    affection_button.pressed.connect(_on_affection_pressed)
    phone_button.pressed.connect(_on_phone_pressed)
    activity_button.pressed.connect(_on_activity_pressed)
    desktop_pet_button.pressed.connect(_on_desktop_pet_pressed)
    diary_button.pressed.connect(_on_diary_pressed)
    
    if has_node("UIPanel/MapButton"):
        $UIPanel/MapButton.pressed.connect(_on_map_pressed)
        
    chat_button.pressed.connect(_on_main_chat_pressed)
    rest_button.pressed.connect(_on_rest_pressed)
    end_chat_btn.pressed.connect(_on_end_chat_pressed)
    if history_btn:
        history_btn.pressed.connect(_on_history_pressed)
    send_btn.pressed.connect(_on_send_pressed)
    
    deepseek_client.chat_stream_started.connect(_on_chat_stream_started)
    deepseek_client.chat_stream_delta.connect(_on_chat_stream_delta)
    deepseek_client.chat_request_completed.connect(_on_chat_response)
    deepseek_client.options_request_completed.connect(_on_options_response)
    
    topic_panel.visible = false
    topic_panel.modulate.a = 0.0
    dialogue_panel.visible = false
    dialogue_panel.modulate.a = 0.0
    if dialogue_panel.has_signal("panel_clicked"):
        dialogue_panel.panel_clicked.connect(_on_dialogue_panel_gui_input)
    
    diary_notification.modulate.a = 0.0
    diary_notification.position.x = 1300 # Initial off-screen position
    
    audio_player = AudioStreamPlayer.new()
    add_child(audio_player)
    
    var TTSService = load("res://scripts/api/doubao_TTS_Service.gd")
    if TTSService:
        doubao_tts = TTSService.new()
        add_child(doubao_tts)
        doubao_tts.tts_success.connect(_on_tts_success)
        doubao_tts.tts_failed.connect(_on_tts_failed)
        if GameDataManager.config:
            doubao_tts.setup_auth(GameDataManager.config.doubao_app_id, GameDataManager.config.doubao_token, GameDataManager.config.doubao_cluster)
            
    GameDataManager.character_switched.connect(_on_character_switched)
    
    if chat_button and GameDataManager.profile:
        chat_button.text = "与 " + GameDataManager.profile.char_name + " 聊天"
    
    # 动画：按钮点击弹性反馈
    galchat_button.pivot_offset = galchat_button.size / 2
    settings_button.pivot_offset = settings_button.size / 2
    phone_button.pivot_offset = phone_button.size / 2
    activity_button.pivot_offset = activity_button.size / 2
    desktop_pet_button.pivot_offset = desktop_pet_button.size / 2
    hide_ui_button.pivot_offset = hide_ui_button.size / 2
    settings_button.pivot_offset = settings_button.size / 2
    affection_button.pivot_offset = affection_button.size / 2
    
    # 恢复整个主窗口的鼠标输入响应，清除可能因为之前透明测试遗留的 passthrough 多边形
    if not is_queued_for_deletion():
        DisplayServer.window_set_mouse_passthrough(PackedVector2Array(), get_window().get_window_id())
    
    # Update StatsPanel explicitly when returning to main scene
    if stats_panel and stats_panel.has_method("_update_ui"):
        stats_panel._update_ui()
        
    if top_status_panel and top_status_panel.has_method("_update_ui"):
        top_status_panel._update_ui()
        
    # 尝试找回已存在的桌宠实例
    if get_tree().root.has_node("DesktopPet"):
        desktop_pet_instance = get_tree().root.get_node("DesktopPet")
        
    # 关联音乐播放器
    if is_instance_valid(music_player) and is_instance_valid(bgm):
        music_player.set_audio_player(bgm)
        
    # 初始化挂机检测
    var window_detector_path = "res://scripts/csharp/WindowDetector.cs"
    if FileAccess.file_exists(window_detector_path):
        var WindowDetectorObj = load(window_detector_path)
        if WindowDetectorObj:
            _window_detector = WindowDetectorObj.new()
            add_child(_window_detector)
            # 把当前主窗口的真实 HWND 传给 C# 层，用于精准判断
            var win_id = get_window().get_window_id()
            var hwnd = DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE, win_id)
            if hwnd:
                _window_detector.call("SetMainHwnd", hwnd)
            
    _afk_timer = Timer.new()
    _afk_timer.wait_time = 1.0
    _afk_timer.autostart = true
    _afk_timer.timeout.connect(_check_afk_status)
    add_child(_afk_timer)

func _check_afk_status() -> void:
    var window = get_window()
    var is_minimized = window.mode == Window.MODE_MINIMIZED
    
    var is_covered_fullscreen = false
    if is_instance_valid(_window_detector):
        is_covered_fullscreen = _window_detector.call("IsAnyFullScreenWindowCovering")
        
    var should_be_afk = is_minimized or is_covered_fullscreen
    
    if should_be_afk != _is_afk:
        _is_afk = should_be_afk
        if _is_afk:
            _on_enter_afk()
        else:
            _on_exit_afk()

func _on_enter_afk() -> void:
    print("[MainScene] 视为主场景后台挂机，暂停音乐与进度")
    if bgm:
        bgm.stream_paused = true
        
func _on_exit_afk() -> void:
    print("[MainScene] 退出后台挂机模式，恢复音乐与进度")
    if bgm:
        bgm.stream_paused = false

func _on_desktop_pet_pressed() -> void:
    _animate_button(desktop_pet_button)
    if is_instance_valid(desktop_pet_instance):
        # 桌宠已存在，关闭它。先隐藏以防止输入系统报错
        desktop_pet_instance.hide()
        desktop_pet_instance.queue_free()
        desktop_pet_instance = null
    else:
        # 创建桌宠，直接挂载在 root 下，这样切换场景也不会被销毁
        var DesktopPetObj = load("res://scenes/ui/desktop_pet/desktop_pet.tscn")
        desktop_pet_instance = DesktopPetObj.instantiate()
        get_tree().root.add_child(desktop_pet_instance)

func _on_incoming_call_accepted(char_id: String, is_video: bool, is_fixed: bool = false) -> void:
    # 接听电话：打开手机面板
    if mobile_interface_instance == null:
        _on_phone_pressed()
    else:
        mobile_interface_instance.show_phone()
        
    # 告诉手机面板直接跳转到通话界面
    mobile_interface_instance.open_call_directly(char_id, is_video, is_fixed)

func _on_phone_pressed() -> void:
    _animate_button(phone_button)
    if mobile_interface_instance == null:
        var MobileInterfaceObj = load("res://scenes/ui/mobile/mobile_interface.tscn")
        mobile_interface_instance = MobileInterfaceObj.instantiate()
        ui_panel.add_child(mobile_interface_instance)
        mobile_interface_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        mobile_interface_instance.app_opened.connect(_on_mobile_app_opened)
    
    # 如果当前在故事剧情场景中触发手机，需要把它提到最前面防止被剧情场景遮挡
    if is_instance_valid(chat_scene_instance) and chat_scene_instance.visible:
        mobile_interface_instance.get_parent().remove_child(mobile_interface_instance)
        add_child(mobile_interface_instance)
        move_child(mobile_interface_instance, -1)
        
    mobile_interface_instance.show_phone()

func _on_mobile_app_opened(app_name: String) -> void:
    pass # 目前 archive 由 mobile_interface 自己处理，如果有其他 app 可以加在这里

func _on_activity_pressed() -> void:
    _animate_button(activity_button)
    if activity_panel_instance == null:
        var ActivityPanelObj = load("res://scenes/ui/activity/activity_panel.tscn")
        activity_panel_instance = ActivityPanelObj.instantiate()
        add_child(activity_panel_instance)
        # 确保它盖在最上面
        activity_panel_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    activity_panel_instance.show_panel()

func _on_galchat_pressed() -> void:
    _animate_button(galchat_button)
    
    if chat_scene_instance == null:
        var ChatSceneObj = load("res://scenes/ui/story/story_scene.tscn")
        chat_scene_instance = ChatSceneObj.instantiate()
        add_child(chat_scene_instance)
        move_child(chat_scene_instance, -1)
        
        chat_scene_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        chat_scene_instance.chat_closed.connect(_on_chat_closed)
        
    chat_scene_instance.show_panel()
    if bgm.playing:
        bgm.stop()

func _on_chat_closed() -> void:
    if not bgm.playing:
        bgm.play()

func _on_history_pressed() -> void:
    if history_panel_instance == null:
        var HistoryPanelObj = load("res://scenes/ui/history/history_panel.tscn")
        history_panel_instance = HistoryPanelObj.instantiate()
        add_child(history_panel_instance)
        history_panel_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        
        # We need to hook up the close button of history panel manually if it doesn't self-close
        var close_btn = history_panel_instance.get_node_or_null("HistoryTopBar/HistoryCloseButton")
        if close_btn:
            close_btn.pressed.connect(func(): history_panel_instance.hide())
            
    history_panel_instance.show()
    _populate_history_ui()

func _populate_history_ui() -> void:
    if not history_panel_instance: return
    var history_vbox = history_panel_instance.get_node_or_null("ScrollContainer/VBoxContainer")
    if not history_vbox: return
    
    # 清空现有子节点
    for child in history_vbox.get_children():
        child.queue_free()
        
    var HISTORY_ITEM_SCENE = load("res://scenes/ui/history/history_item.tscn")
    var messages = GameDataManager.history.get_messages_by_type("main_chat")
    for msg in messages:
        var item = HISTORY_ITEM_SCENE.instantiate()
        history_vbox.add_child(item)
        item.setup(msg)
        item.play_voice_requested.connect(_play_cached_voice)
        
    # 延迟一帧等待容器布局完成，然后滚动到底部
    if is_inside_tree():
        await get_tree().process_frame
    var scroll = history_panel_instance.get_node_or_null("ScrollContainer")
    if scroll:
        var v_scroll = scroll.get_v_scroll_bar()
        v_scroll.value = v_scroll.max_value

func _play_cached_voice(cache_key: String) -> void:
    if doubao_tts == null: return
    var cache_path = doubao_tts.CACHE_DIR + cache_key + "." + doubao_tts.default_encoding
    if FileAccess.file_exists(cache_path):
        var stream = doubao_tts._load_audio_from_file(cache_path)
        if stream and audio_player:
            audio_player.stream = stream
            audio_player.play()
    else:
        print("未找到语音缓存: ", cache_key)

func _on_close_requested() -> void:
    pass

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_CLOSE_REQUEST:
        var desktop_pet = get_tree().root.get_node_or_null("DesktopPet")
        if is_instance_valid(desktop_pet) and desktop_pet.visible:
            # Godot 4 中，主场景是 Control 时，我们应该隐藏对应的 Window
            get_tree().root.hide()
        else:
            get_tree().quit()

func _on_settings_pressed() -> void:
    _animate_button(settings_button)
    if settings_panel_instance == null:
        var SettingsPanelObj = load("res://scenes/ui/settings/settings_scene.tscn")
        settings_panel_instance = SettingsPanelObj.instantiate()
        add_child(settings_panel_instance)
        settings_panel_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    settings_panel_instance.show_panel()

func _on_affection_pressed() -> void:
    _animate_button(affection_button)
    var was_visible = false
    if affection_panel_instance == null:
        var AffectionPanelObj = load("res://scenes/ui/story/affection_panel.tscn")
        affection_panel_instance = AffectionPanelObj.instantiate()
        ui_panel.add_child(affection_panel_instance)
        was_visible = false # 初次实例化，视为原本是隐藏的
    else:
        was_visible = affection_panel_instance.visible
        
    if not was_visible:
        # 根据按钮当前位置动态计算面板位置，显示在按钮右侧，并与按钮顶部对齐
        var button_width = affection_button.size.x
            
        affection_panel_instance.position = Vector2(
            affection_button.position.x + button_width + 10, # 10 为间距
            affection_button.position.y
        )
        affection_panel_instance.show()
    else:
        affection_panel_instance.hide()

func _on_diary_pressed() -> void:
    _animate_button(diary_button)
    diary_panel.show_diary()

func _on_map_pressed() -> void:
    _animate_button(map_button)
    print("[MainScene] Map button pressed")
    if not map_scene_instance:
        var map_scene = load("res://scenes/ui/map/core/world_map_scene.tscn")
        map_scene_instance = map_scene.instantiate()
        add_child(map_scene_instance)
        # Move map scene to top so it overlays everything
        move_child(map_scene_instance, get_child_count() - 1)
        
        # When location is selected, we want to transition to it
        map_scene_instance.location_selected.connect(_on_location_selected)
    
    map_scene_instance.show_map()

func _on_location_selected(location_id: String):
    print("[MainScene] Transitioning to location: ", location_id)
    # The actual transition is currently handled inside world_map_scene.gd
    # But we can also handle hiding main UI here if needed

func show_diary_notification() -> void:
    var tween = create_tween().set_parallel(true)
    tween.tween_property(diary_notification, "position:x", 1280 - 300, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
    tween.tween_property(diary_notification, "modulate:a", 1.0, 0.5)
    
    var out_tween = create_tween()
    out_tween.tween_interval(3.0)
    out_tween.tween_property(diary_notification, "position:x", 1300, 0.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
    out_tween.parallel().tween_property(diary_notification, "modulate:a", 0.0, 0.5)

func _on_hide_ui_pressed() -> void:
    _animate_button(hide_ui_button)
    if _ui_tween:
        _ui_tween.kill()
    _ui_tween = create_tween()
    _ui_tween.tween_property(ui_panel, "modulate:a", 0.0, 0.3)
    _ui_tween.tween_callback(func(): ui_panel.visible = false)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and event.keycode == KEY_F12:
        var root = get_tree().root
        var debug_panel = root.get_node_or_null("GlobalDebugPanel")
        if debug_panel == null:
            var DebugPanelObj = load("res://scenes/ui/story/debug_panel.tscn")
            debug_panel = DebugPanelObj.instantiate()
            debug_panel.name = "GlobalDebugPanel"
            root.add_child(debug_panel)
            debug_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
            
            # 如果当前是主场景，连上信号
            debug_panel.stage_changed.connect(func(stage: int):
                GameDataManager.profile.force_set_stage(stage)
                GameDataManager.history.messages.clear()
                GameDataManager.history.save_history()
                print("【Debug】强制切换情感阶段至：" + str(stage))
            )
            debug_panel.mood_changed.connect(func(mood: String):
                GameDataManager.profile.update_mood(mood)
                print("【Debug】强制切换心情至：" + mood)
            )
            
        if debug_panel.visible:
            debug_panel.hide()
        else:
            debug_panel.show_panel()
        get_viewport().set_input_as_handled()
        return
        
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        # 如果手机界面存在且正在显示相机，不要显示UI
        if mobile_interface_instance and mobile_interface_instance.camera_panel_instance and mobile_interface_instance.camera_panel_instance.visible:
            return
            
        if not ui_panel.visible or ui_panel.modulate.a < 0.99:
            get_viewport().set_input_as_handled()
            if _ui_tween:
                _ui_tween.kill()
            ui_panel.visible = true
            _ui_tween = create_tween()
            _ui_tween.tween_property(ui_panel, "modulate:a", 1.0, 0.3)
            
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
        # 如果话题面板正在显示，右键点击则隐藏它并返回主界面UI
        if topic_panel and topic_panel.visible:
            get_viewport().set_input_as_handled()
            var t_tween = create_tween()
            t_tween.tween_property(topic_panel, "modulate:a", 0.0, 0.3)
            t_tween.tween_callback(func(): topic_panel.visible = false)
            
            if _ui_tween:
                _ui_tween.kill()
            ui_panel.visible = true
            _ui_tween = create_tween()
            _ui_tween.tween_property(ui_panel, "modulate:a", 1.0, 0.3)

func _on_character_switched(char_id: String) -> void:
    # 角色切换后更新主界面的面板（特别是数值显示）
    if stats_panel and stats_panel.has_method("_update_ui"):
        stats_panel._update_ui()
        
    if top_status_panel and top_status_panel.has_method("_update_ui"):
        top_status_panel._update_ui()
    
    # 更新右上角的 AffectionPanel
    if is_instance_valid(affection_panel_instance) and affection_panel_instance.has_method("update_ui"):
        affection_panel_instance.update_ui()
        
    if chat_button and GameDataManager.profile:
        chat_button.text = "与 " + GameDataManager.profile.char_name + " 聊天"
        
    # 注意：ChatScene 的更新由它自己内部监听信号处理

func _animate_button(btn: Button) -> void:
    var tween = create_tween()
    tween.tween_property(btn, "scale", Vector2(0.9, 0.9), 0.05)
    tween.tween_property(btn, "scale", Vector2(1.1, 1.1), 0.05)
    tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.05)
