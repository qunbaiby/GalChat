extends Control

signal call_ended
signal message_sent(text)

@onready var bg_tex: TextureRect = $BackgroundTex
@onready var character_container: Control = $Panel/CharacterContainer
@onready var current_ani: AnimatedSprite2D = $Panel/CharacterContainer/CharacterAni
@onready var name_label: Label = $Panel/VBox/NameLabel
@onready var status_label: Label = $Panel/VBox/StatusLabel
@onready var message_label: RichTextLabel = $Panel/VBox/MessageCenter/MessageLabel
@onready var hangup_btn: Button = $Panel/VBox/BottomBar/HangupVBox/HangupBtn
@onready var record_btn: Button = $Panel/VBox/BottomBar/RecordVBox/RecordBtn
@onready var audio_player: AudioStreamPlayer = $AudioStreamPlayer
var qwen_asr_client = null

var current_char_id: String = ""
var char_profile: CharacterProfile = null

var is_character_speaking: bool = false
var is_recording: bool = false

var message_queue: Array = []
var is_processing_queue: bool = false
var is_fixed_mode: bool = false
var fixed_call_data: Array = []
var current_fixed_idx: int = 0

func _ready() -> void:
    hangup_btn.pressed.connect(_on_hangup_pressed)
    record_btn.button_down.connect(_on_record_down)
    record_btn.button_up.connect(_on_record_up)
    
    if GameDataManager.config.qwen_asr_enabled:
        var QwenASRClient = load("res://scripts/api/qwen_asr_client.gd")
        if QwenASRClient:
            qwen_asr_client = QwenASRClient.new()
            qwen_asr_client.name = "QwenASRClient"
            add_child(qwen_asr_client)
            qwen_asr_client.transcribe_completed.connect(_on_asr_completed)
            qwen_asr_client.transcribe_failed.connect(_on_asr_failed)
        
    TTSManager.tts_success.connect(_on_tts_success)
    TTSManager.tts_failed.connect(_on_tts_failed)

func setup(char_id: String, profile: CharacterProfile, is_incoming: bool = false, is_fixed: bool = false) -> void:
    current_char_id = char_id
    char_profile = profile
    is_fixed_mode = is_fixed
    
    name_label.text = profile.char_name
    status_label.text = "接通中..."
    message_label.text = "[center]...[/center]"
    
    if is_fixed_mode:
        hangup_btn.show()
        record_btn.show()
        hangup_btn.disabled = true
        record_btn.disabled = true
        set_process_input(true)
        
        if GameDataManager.has_meta("pending_fixed_call_data"):
            set_fixed_call_data(GameDataManager.get_meta("pending_fixed_call_data"))
            GameDataManager.remove_meta("pending_fixed_call_data")
    else:
        hangup_btn.show()
        record_btn.show()
        hangup_btn.disabled = false
        record_btn.disabled = false
        set_process_input(false)
    
    _update_character_ani()

func set_fixed_call_data(data: Array) -> void:
    fixed_call_data = data
    current_fixed_idx = 0
    _advance_fixed_call()

func _input(event: InputEvent) -> void:
    if is_fixed_mode and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        if is_character_speaking:
            return
        _advance_fixed_call()

func _advance_fixed_call() -> void:
    if current_fixed_idx < fixed_call_data.size():
        var text = fixed_call_data[current_fixed_idx]
        current_fixed_idx += 1
        add_character_message(text)
    else:
        call_ended.emit()

func set_loading_state() -> void:
    status_label.text = "对方正在连接..."
    record_btn.disabled = true

func set_background(bg_id: String) -> void:
    var bg_path = ImageManager.get_image_path(bg_id)
    if bg_path == "":
        bg_path = bg_id # Fallback
        
    if bg_path != "" and ResourceLoader.exists(bg_path):
        bg_tex.texture = load(bg_path)
    else:
        bg_tex.texture = null

func _update_character_ani() -> void:
    if not is_instance_valid(current_ani): return
    
    # 动态加载对应的动画帧
    if char_profile and char_profile.sprite_frames_path != "":
        if ResourceLoader.exists(char_profile.sprite_frames_path):
            current_ani.sprite_frames = load(char_profile.sprite_frames_path)
            
    # 首先尝试获取表情对应的立绘
    var expression = "calm"
    if char_profile:
        expression = char_profile.current_expression

    # 优先使用 AnimatedSprite2D 的表情动画，静态图只作为兼容回退。
    var frames = current_ani.sprite_frames
    var animation_name = GameDataManager.expression_system.get_expression_animation_name(expression)
    if frames and frames.has_animation(animation_name):
        _clear_dynamic_sprite()
        current_ani.show()
        current_ani.play(animation_name)
        return
    if frames and frames.has_animation("calm"):
        _clear_dynamic_sprite()
        current_ani.show()
        current_ani.play("calm")
        return
    if frames and frames.has_animation("idle"):
        _clear_dynamic_sprite()
        current_ani.show()
        current_ani.play("idle")
        return
    if frames and frames.has_animation("default"):
        _clear_dynamic_sprite()
        current_ani.show()
        current_ani.play("default")
        return

    var sprite_path = GameDataManager.expression_system.get_expression_sprite_path(expression)
    if sprite_path != "":
        if sprite_path.begins_with("user://"):
            var img = Image.new()
            var err = img.load(sprite_path)
            if err == OK:
                var tex = ImageTexture.create_from_image(img)
                _set_sprite_texture(tex)
                return
        elif ResourceLoader.exists(sprite_path):
            var tex = load(sprite_path)
            if tex is Texture2D:
                _set_sprite_texture(tex)
                return

func _set_sprite_texture(tex: Texture2D) -> void:
    # 动态创建一个 Sprite2D 来替代 AnimatedSprite2D 的显示
    var dynamic_sprite = get_node_or_null("Panel/CharacterContainer/DynamicSprite")
    if not dynamic_sprite:
        dynamic_sprite = Sprite2D.new()
        dynamic_sprite.name = "DynamicSprite"
        dynamic_sprite.position = current_ani.position
        dynamic_sprite.scale = current_ani.scale
        character_container.add_child(dynamic_sprite)
    
    dynamic_sprite.texture = tex
    dynamic_sprite.show()
    current_ani.hide()

func _clear_dynamic_sprite() -> void:
    var dynamic_sprite = get_node_or_null("Panel/CharacterContainer/DynamicSprite")
    if dynamic_sprite:
        dynamic_sprite.hide()

func _on_hangup_pressed() -> void:
    if audio_player.playing:
        audio_player.stop()
    message_queue.clear()
    call_ended.emit()

func _on_record_down() -> void:
    if is_character_speaking: return
    is_recording = true
    record_btn.text = "松开发送"
    record_btn.modulate = Color(0.8, 1.0, 0.8)
    status_label.text = "聆听中..."
    if GameDataManager.config.qwen_asr_enabled and qwen_asr_client:
        qwen_asr_client.start_recording()

func _on_record_up() -> void:
    if not is_recording: return
    is_recording = false
    record_btn.text = "处理中..."
    record_btn.disabled = true
    record_btn.modulate = Color(1.0, 1.0, 1.0)
    status_label.text = "转换中..."
    if GameDataManager.config.qwen_asr_enabled and qwen_asr_client:
        qwen_asr_client.stop_recording()

func _on_asr_completed(text: String) -> void:
    record_btn.text = "按住说话"
    status_label.text = "发送中..."
    text = text.strip_edges()
    
    if text == "":
        status_label.text = "视频通话中"
        record_btn.disabled = false
        return
        
    # Save player message to history
    if is_fixed_mode:
        GameDataManager.history.add_message("我", text, "", "fixed_story")
    else:
        GameDataManager.history.add_message("我", text, "", "story_chat")
        
    await _typewriter_effect("[color=#88ccff]" + text + "[/color]")
    
    await get_tree().create_timer(0.5).timeout
    message_sent.emit(text)

func _on_asr_failed(err_msg: String) -> void:
    record_btn.text = "按住说话"
    record_btn.disabled = false
    status_label.text = "语音识别失败"
    await get_tree().create_timer(2.0).timeout
    status_label.text = "视频通话中"

func add_character_message(text: String) -> void:
    var parts = ChatSplitHelper.merge_incomplete_parentheses(text.split("[SPLIT]"))
    for p in parts:
        var c = p.strip_edges()
        if c != "":
            message_queue.append(c)
            
    if not is_processing_queue:
        _process_next_message()

func _process_next_message() -> void:
    if message_queue.is_empty():
        is_processing_queue = false
        is_character_speaking = false
        if not is_fixed_mode:
            record_btn.disabled = false
        status_label.text = "视频通话中"
        
        _update_character_ani()
        
        if is_fixed_mode:
            await get_tree().create_timer(0.6).timeout
            if visible and not is_character_speaking:
                _advance_fixed_call()
        return
        
    is_processing_queue = true
    is_character_speaking = true
    record_btn.disabled = true
    status_label.text = "对方正在讲话..."
    
    var chunk = message_queue.pop_front()
    var display_text = _extract_dialogue_text(chunk)
    var tts_text = display_text
    
    # Save to history
    var char_name = char_profile.char_name if char_profile else current_char_id
    if is_fixed_mode:
        GameDataManager.history.add_message(char_name, chunk, "", "fixed_story")
    else:
        GameDataManager.history.add_message(char_name, chunk, "", "story_chat")
    
    var raw_action = _extract_action_only(chunk)
    # 开始 TTS
    if GameDataManager.config.voice_enabled and _has_readable_text(tts_text):
        var options = {}
        if GameDataManager.config.character_voice_types.has(current_char_id):
            options["voice_type"] = GameDataManager.config.character_voice_types[current_char_id]
            
        TTSManager.synthesize(tts_text, options)
        
        # 逐字显示和等待语音
        _typewriter_effect("[color=#ffffff]" + display_text + "[/color]")
        
        # 稍微增加一点启动等待时间，防止网络抖动导致的音频状态未更新
        var wait_net = 0
        while not audio_player.playing and wait_net < 100:
            await get_tree().create_timer(0.05).timeout
            wait_net += 1
            
        while audio_player.playing:
            await get_tree().process_frame
            
        await get_tree().create_timer(0.3).timeout
    else:
        await _typewriter_effect("[color=#ffffff]" + display_text + "[/color]")
        await get_tree().create_timer(0.6).timeout
        
    _process_next_message()

func _typewriter_effect(bbcode_text: String) -> void:
    message_label.text = "[center]" + bbcode_text + "[/center]"
    message_label.visible_characters = 0
    
    var total_chars = message_label.get_total_character_count()
    var delay = 0.05
    
    for i in range(total_chars):
        message_label.visible_characters = i + 1
        await get_tree().create_timer(delay).timeout
    
    message_label.visible_characters = -1

func _extract_dialogue_text(text: String) -> String:
    var regex = RegEx.new()
    regex.compile("\\([^)]+\\)|\\（[^）]+\\）")
    return regex.sub(text, "", true).strip_edges()

func _extract_action_only(text: String) -> String:
    var regex = RegEx.new()
    regex.compile("\\(([^)]+)\\)|\\（([^）]+)\\）")
    var result = regex.search(text)
    if result:
        return result.get_string(1) if result.get_string(1) != "" else result.get_string(2)
    return ""

func _has_readable_text(text: String) -> bool:
    var regex = RegEx.new()
    regex.compile("[a-zA-Z0-9\u4e00-\u9fa5]")
    return regex.search(text) != null

func _on_tts_success(stream: AudioStream, _text: String) -> void:
    if audio_player:
        audio_player.stream = stream
        audio_player.play()

func _on_tts_failed(err_msg: String, _text: String) -> void:
    print("Video Call TTS Failed: ", err_msg)
