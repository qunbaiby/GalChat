extends Control

@onready var back_btn: Button = $UIOverlay/BackButton
@onready var settings_btn: Button = $UIOverlay/SettingsButton
@onready var history_btn: Button = $UIOverlay/HistoryButton
@onready var intimacy_bar: ProgressBar = $UIOverlay/IntimacyBar

@onready var name_label: Label = $DialogueLayer/NameLabel
@onready var dialogue_text: RichTextLabel = $DialogueLayer/RichTextLabel
@onready var input_field: TextEdit = $InputLayer/HBoxContainer/InputField
@onready var send_btn: Button = $InputLayer/HBoxContainer/SendButton

@onready var deepseek_client: DeepSeekClient = $DeepSeekClient
@onready var doubao_tts = $DoubaoTTSService
@onready var audio_player: AudioStreamPlayer = $AudioStreamPlayer

@onready var history_panel: Panel = $HistoryPanel
@onready var history_close_btn: Button = $HistoryPanel/HistoryTopBar/HistoryCloseButton
@onready var history_vbox: VBoxContainer = $HistoryPanel/ScrollContainer/VBoxContainer

const HISTORY_ITEM_SCENE = preload("res://assets/scenes/ui/history/history_item.tscn")

func _ready() -> void:
    back_btn.pressed.connect(_on_back_pressed)
    settings_btn.pressed.connect(_on_settings_pressed)
    history_btn.pressed.connect(_on_history_pressed)
    send_btn.pressed.connect(_on_send_pressed)
    input_field.text_changed.connect(_on_input_text_changed)
    
    history_close_btn.pressed.connect(_on_history_close_pressed)
    
    deepseek_client.api_request_completed.connect(_on_api_response)
    deepseek_client.api_request_failed.connect(_on_api_error)
    
    doubao_tts.tts_success.connect(_on_tts_success)
    doubao_tts.tts_failed.connect(_on_tts_failed)
    
    # 配置TTS服务
    var config = GameDataManager.config
    doubao_tts.setup_auth(config.doubao_app_id, config.doubao_token, config.doubao_cluster)
    
    _update_ui()
    
    # 如果是从设置界面返回，则恢复最后一条对话显示，不重播初始问候
    if GameDataManager.previous_scene_path == "res://assets/scenes/ui/settings/settings_scene.tscn":
        _restore_last_message()
    else:
        # 初始问候 (如果是从开始界面进入，则清空之前可能残留的对话状态，也可以不清空，这里选择不清空而是追加)
        var messages = GameDataManager.history.messages
        if messages.size() == 0:
            _show_message("你好...今天想聊点什么？", "neutral", "ayrrha", false)
        else:
            _restore_last_message()

func _restore_last_message() -> void:
    var messages = GameDataManager.history.messages
    if messages.size() > 0:
        var last_msg = messages[messages.size() - 1]
        # 直接静默显示最后一条，不触发打字机和语音
        dialogue_text.text = last_msg["text"]
        dialogue_text.visible_characters = -1
        name_label.text = last_msg["speaker"]
        # TODO: 恢复对应立绘
    else:
        # 如果没有历史记录，静默显示初始问候
        dialogue_text.text = "你好...今天想聊点什么？"
        dialogue_text.visible_characters = -1
        name_label.text = "ayrrha"

func _on_input_text_changed() -> void:
    if input_field.text.length() > 200:
        input_field.text = input_field.text.substr(0, 200)
        input_field.set_caret_column(200)

func _update_ui() -> void:
    intimacy_bar.value = GameDataManager.profile.intimacy

func _on_back_pressed() -> void:
    get_tree().change_scene_to_file("res://assets/scenes/ui/start/start_scene.tscn")

func _on_settings_pressed() -> void:
    GameDataManager.previous_scene_path = "res://assets/scenes/ui/chat/chat_scene.tscn"
    get_tree().change_scene_to_file("res://assets/scenes/ui/settings/settings_scene.tscn")

func _on_history_pressed() -> void:
    history_panel.show()
    _populate_history_ui()

func _on_history_close_pressed() -> void:
    history_panel.hide()

func _populate_history_ui() -> void:
    # 清空现有子节点
    for child in history_vbox.get_children():
        child.queue_free()
        
    var messages = GameDataManager.history.messages
    for msg in messages:
        var item = HISTORY_ITEM_SCENE.instantiate()
        history_vbox.add_child(item)
        item.setup(msg)
        item.play_voice_requested.connect(_play_cached_voice)

func _play_cached_voice(cache_key: String) -> void:
    var cache_path = doubao_tts.CACHE_DIR + cache_key + "." + doubao_tts.default_encoding
    if FileAccess.file_exists(cache_path):
        var stream = doubao_tts._load_audio_from_file(cache_path)
        if stream:
            audio_player.stream = stream
            audio_player.play()
    else:
        print("未找到语音缓存: ", cache_key)

func _on_send_pressed() -> void:
    var text = input_field.text.strip_edges()
    if text.is_empty():
        return
        
    input_field.text = ""
    send_btn.disabled = true
    _show_message(text, "", "玩家")
    
    if GameDataManager.config.ai_mode_enabled:
        deepseek_client.send_chat_message(text)
    else:
        # 本地兜底对话
        await get_tree().create_timer(1.0).timeout
        _show_message("（离线模式）我...我不知道该说什么...", "shy", "ayrrha")
        send_btn.disabled = false

func _on_api_response(response: Dictionary) -> void:
    send_btn.disabled = false
    if response.has("choices") and response["choices"].size() > 0:
        var reply = response["choices"][0]["message"]["content"]
        _parse_and_show_reply(reply)
    else:
        _show_message("ayrrha 似乎走神了...", "sad", "ayrrha")

func _on_api_error(error_msg: String) -> void:
    send_btn.disabled = false
    _show_message("【系统提示】" + error_msg, "sad", "系统")
    # 本地兜底
    await get_tree().create_timer(1.0).timeout
    _show_message("刚才网络好像不太好...", "neutral", "ayrrha")

func _parse_and_show_reply(reply: String) -> void:
    # 提取 [mood:+5] [expr:blush] [intimacy:+0.5] 等指令
    var regex = RegEx.new()
    regex.compile("\\[(mood|expr|intimacy):([^\\]]+)\\]")
    
    var clean_text = reply
    var expr = "neutral"
    
    var matches = regex.search_all(reply)
    for m in matches:
        var tag = m.get_string(1)
        var val = m.get_string(2)
        
        if tag == "mood":
            GameDataManager.profile.update_mood(val.to_float())
        elif tag == "intimacy":
            GameDataManager.profile.update_intimacy(val.to_float())
        elif tag == "expr":
            expr = val
            
        clean_text = clean_text.replace(m.get_string(0), "")
        
    GameDataManager.profile.save_profile()
    _update_ui()
    
    # 打字机效果显示文本
    _show_message(clean_text.strip_edges(), expr, "ayrrha")

func _show_message(text: String, expr: String, speaker_name: String = "ayrrha", is_restore: bool = false) -> void:
    if speaker_name != "":
        name_label.text = speaker_name
        
    if expr != "":
        print("切换立绘表情: ", expr)
        # TODO: 根据 expr 更新 CharacterLayer 的图片
        
    dialogue_text.text = text
    dialogue_text.visible_characters = 0
    
    # 简单的打字机效果
    var tween = create_tween()
    var duration = text.length() * 0.05 # 每个字符 0.05 秒
    tween.tween_property(dialogue_text, "visible_characters", text.length(), duration)
    
    var cache_key = ""
    # 触发TTS语音合成 (仅对 ayrrha 发声)，如果是恢复记录则不发声
    if speaker_name == "ayrrha" and GameDataManager.config.voice_enabled and not is_restore:
        var options = {"voice_type": GameDataManager.config.doubao_voice_type}
        cache_key = doubao_tts._generate_cache_key(text, options)
        doubao_tts.synthesize(text, options)
        
    # 保存记录到历史管理器 (只有在非恢复模式时保存)
    if not is_restore:
        GameDataManager.history.add_message(speaker_name, text, cache_key)

func _on_tts_success(audio_stream: AudioStream, text: String) -> void:
    if audio_player:
        audio_player.stream = audio_stream
        audio_player.play()

func _on_tts_failed(error_msg: String, text: String) -> void:
    print("TTS 失败: ", error_msg)
