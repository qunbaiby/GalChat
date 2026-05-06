extends Control

@onready var api_key_input: LineEdit = %ApiKeyInput
@onready var doubao_chat_key_input: LineEdit = %DoubaoChatKeyInput
@onready var model_option: OptionButton = %ModelOption
@onready var temp_slider: HSlider = %TempSlider
@onready var tokens_spinbox: SpinBox = %TokensSpinBox
@onready var ai_mode_check: CheckButton = %AIModeCheck

@onready var voice_mode_check: CheckButton = %VoiceModeCheck
@onready var app_id_input: LineEdit = %AppIdInput
@onready var token_input: LineEdit = %TokenInput
@onready var cluster_input: LineEdit = %ClusterInput
@onready var voice_type_container: VBoxContainer = %VoiceTypeContainer

@onready var embed_mode_check: CheckButton = %EmbedModeCheck
@onready var embed_key_input: LineEdit = %EmbedKeyInput
@onready var embed_model_input: LineEdit = %EmbedModelInput

@onready var vision_mode_check: CheckButton = %VisionModeCheck
@onready var vision_key_input: LineEdit = %VisionKeyInput
@onready var vision_model_input: LineEdit = %VisionModelInput
@onready var vision_base_url_input: LineEdit = %VisionBaseUrlInput

@onready var image_gen_mode_check: CheckButton = %ImageGenModeCheck
@onready var default_image_path_input: LineEdit = %DefaultImagePathInput
@onready var image_provider_option: OptionButton = %ImageProviderOption
@onready var image_key_input: LineEdit = %ImageKeyInput
@onready var doubao_image_key_input: LineEdit = %DoubaoImageKeyInput
@onready var doubao_image_model_input: LineEdit = %DoubaoImageModelInput
@onready var enable_ai_illustration_check: CheckButton = %EnableAiIllustrationCheck

@onready var resolution_option: OptionButton = %ResolutionOption
@onready var fps_option: OptionButton = %FPSOption
@onready var vsync_check: CheckButton = %VsyncCheck

@onready var bgm_slider: HSlider = %BGMSlider
@onready var voice_slider: HSlider = %VoiceSlider

@onready var back_button: Button = $TopBar/BackButton
@onready var save_button: Button = $SaveButton
@onready var clear_history_btn: Button = %ClearHistoryBtn

func _ready() -> void:
    back_button.pressed.connect(_on_back_pressed)
    save_button.pressed.connect(_on_save_pressed)
    clear_history_btn.pressed.connect(_on_clear_history_pressed)
    
    # 动态连接设置变化
    resolution_option.item_selected.connect(_on_resolution_changed)
    fps_option.item_selected.connect(_on_fps_changed)
    vsync_check.toggled.connect(_on_vsync_changed)
    bgm_slider.value_changed.connect(_on_bgm_changed)
    voice_slider.value_changed.connect(_on_voice_changed)
    model_option.item_selected.connect(_on_model_changed)
    image_provider_option.item_selected.connect(_on_image_provider_changed)
    image_gen_mode_check.toggled.connect(_on_image_gen_toggled)
    
    model_option.clear()
    model_option.add_item("deepseek-chat (V3)")
    model_option.set_item_metadata(0, "deepseek-chat")
    model_option.add_item("deepseek-coder")
    model_option.set_item_metadata(1, "deepseek-coder")
    model_option.add_item("deepseek-reasoner (R1/V4)")
    model_option.set_item_metadata(2, "deepseek-reasoner")
    model_option.add_item("doubao-seed-character (豆包)")
    model_option.set_item_metadata(3, "doubao-seed-character-251128")
    
    _load_ui_data()

func show_panel() -> void:
    _load_ui_data()
    show()
    # Add a simple popup animation
    modulate.a = 0.0
    var tween = create_tween()
    tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
    tween.tween_property(self, "modulate:a", 1.0, 0.3)
    
    # Scale animation on the inner container if we want, but let's just animate the whole panel scale from 0.9 to 1.0
    scale = Vector2(0.9, 0.9)
    pivot_offset = get_viewport_rect().size / 2.0
    var scale_tween = create_tween()
    scale_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
    scale_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.3)

func hide_panel() -> void:
    var tween = create_tween()
    tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
    tween.tween_property(self, "modulate:a", 0.0, 0.2)
    var scale_tween = create_tween()
    scale_tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
    scale_tween.tween_property(self, "scale", Vector2(0.9, 0.9), 0.2)
    scale_tween.finished.connect(hide)

func _load_ui_data() -> void:
    var config = GameDataManager.config
    api_key_input.text = config.api_key
    doubao_chat_key_input.text = config.doubao_chat_api_key
    
    if config.model == "deepseek-coder":
        model_option.selected = 1
    elif config.model == "deepseek-reasoner":
        model_option.selected = 2
    elif config.model.begins_with("doubao"):
        model_option.selected = 3
    else:
        model_option.selected = 0
        
    temp_slider.value = config.temperature
    tokens_spinbox.value = config.max_tokens
    ai_mode_check.button_pressed = config.ai_mode_enabled
    
    voice_mode_check.button_pressed = config.voice_enabled
    app_id_input.text = config.doubao_app_id
    token_input.text = config.doubao_token
    cluster_input.text = config.doubao_cluster
    
    # 动态生成所有角色的音色输入框
    for child in voice_type_container.get_children():
        child.queue_free()
        
    # 主角色
    var dir = DirAccess.open("res://assets/data/characters")
    if dir:
        dir.list_dir_begin()
        var file_name = dir.get_next()
        while file_name != "":
            if file_name.ends_with(".json") and not file_name.ends_with("_stages.json"):
                var char_id = file_name.replace(".json", "")
                _create_voice_type_input(char_id, config, "主线角色")
            file_name = dir.get_next()
            
    # NPC
    var npc_dir = DirAccess.open("res://assets/data/characters/npc")
    if npc_dir:
        npc_dir.list_dir_begin()
        var npc_file = npc_dir.get_next()
        while npc_file != "":
            if npc_file.ends_with(".json") and not npc_file.ends_with("_stages.json"):
                var npc_id = npc_file.replace(".json", "")
                _create_voice_type_input(npc_id, config, "NPC")
            npc_file = npc_dir.get_next()
    
    embed_mode_check.button_pressed = config.embedding_enabled
    embed_key_input.text = config.doubao_embedding_api_key
    embed_model_input.text = config.doubao_embedding_model

    vision_mode_check.button_pressed = config.vision_enabled
    vision_key_input.text = config.vision_api_key
    vision_model_input.text = config.vision_model
    vision_base_url_input.text = config.vision_base_url

    image_gen_mode_check.button_pressed = config.image_generation_enabled
    default_image_path_input.text = config.default_image_path
    image_provider_option.selected = config.image_generation_provider
    image_key_input.text = config.openai_image_api_key
    doubao_image_key_input.text = config.doubao_image_api_key
    doubao_image_model_input.text = config.doubao_image_model
    enable_ai_illustration_check.button_pressed = config.enable_ai_diary_illustration
    
    _update_model_ui()
    _update_image_gen_ui()

    # 加载音画设置
    resolution_option.selected = config.resolution_idx
    fps_option.selected = config.fps_idx
    vsync_check.button_pressed = config.vsync_enabled
    bgm_slider.value = config.bgm_volume
    voice_slider.value = config.voice_volume

func _create_voice_type_input(char_id: String, config, tag: String = "") -> void:
    var vbox = VBoxContainer.new()
    voice_type_container.add_child(vbox)
    
    var label = Label.new()
    if tag != "":
        label.text = "[%s] %s 音色 (Voice Type)" % [tag, char_id.capitalize()]
    else:
        label.text = char_id.capitalize() + " 音色 (Voice Type)"
    vbox.add_child(label)
    
    var line_edit = LineEdit.new()
    line_edit.name = "Input_" + char_id
    line_edit.text = config.character_voice_types.get(char_id, "ICL_zh_female_bingruoshaonv_tob")
    vbox.add_child(line_edit)

func _save_ui_data() -> void:
    var config = GameDataManager.config
    config.api_key = api_key_input.text
    config.doubao_chat_api_key = doubao_chat_key_input.text
    if model_option.selected == 1:
        config.model = "deepseek-coder"
    elif model_option.selected == 2:
        config.model = "deepseek-reasoner"
    elif model_option.selected == 3:
        config.model = "doubao-seed-character-251128"
    else:
        config.model = "deepseek-chat"
    config.temperature = temp_slider.value
    config.max_tokens = tokens_spinbox.value
    config.ai_mode_enabled = ai_mode_check.button_pressed
    
    config.voice_enabled = voice_mode_check.button_pressed
    config.doubao_app_id = app_id_input.text
    config.doubao_token = token_input.text
    config.doubao_cluster = cluster_input.text
    
    # 保存所有动态生成的角色音色配置
    for vbox in voice_type_container.get_children():
        for child in vbox.get_children():
            if child is LineEdit and child.name.begins_with("Input_"):
                var char_id = child.name.replace("Input_", "")
                config.character_voice_types[char_id] = child.text
    
    config.embedding_enabled = embed_mode_check.button_pressed
    config.doubao_embedding_api_key = embed_key_input.text
    config.doubao_embedding_model = embed_model_input.text
    
    config.vision_enabled = vision_mode_check.button_pressed
    config.vision_api_key = vision_key_input.text
    config.vision_model = vision_model_input.text
    config.vision_base_url = vision_base_url_input.text
    
    config.image_generation_enabled = image_gen_mode_check.button_pressed
    config.default_image_path = default_image_path_input.text
    config.image_generation_provider = image_provider_option.selected
    config.openai_image_api_key = image_key_input.text
    config.doubao_image_api_key = doubao_image_key_input.text
    config.doubao_image_model = doubao_image_model_input.text
    config.enable_ai_diary_illustration = enable_ai_illustration_check.button_pressed
    
    config.resolution_idx = resolution_option.selected
    config.fps_idx = fps_option.selected
    config.vsync_enabled = vsync_check.button_pressed
    config.bgm_volume = bgm_slider.value
    config.voice_volume = voice_slider.value
    
    config.save_config()
    config.apply_settings()

func _on_resolution_changed(idx: int) -> void:
    GameDataManager.config.resolution_idx = idx
    GameDataManager.config.apply_settings()
    GameDataManager.config.save_config()

func _on_fps_changed(idx: int) -> void:
    GameDataManager.config.fps_idx = idx
    GameDataManager.config.apply_settings()
    GameDataManager.config.save_config()

func _on_vsync_changed(toggled: bool) -> void:
    GameDataManager.config.vsync_enabled = toggled
    GameDataManager.config.apply_settings()
    GameDataManager.config.save_config()

func _on_bgm_changed(value: float) -> void:
    GameDataManager.config.bgm_volume = value
    GameDataManager.config.apply_settings()
    GameDataManager.config.save_config()

func _on_voice_changed(value: float) -> void:
    GameDataManager.config.voice_volume = value
    GameDataManager.config.apply_settings()
    GameDataManager.config.save_config()

func _on_model_changed(_idx: int) -> void:
    _update_model_ui()

func _update_model_ui() -> void:
    var set_visibility = func(node: Control, should_visible: bool):
        node.visible = should_visible
        var label_name = node.name + "Label"
        var label = node.get_parent().get_node_or_null(label_name)
        if label:
            label.visible = should_visible
            
    var provider = model_option.selected
    if provider == 3: # Doubao
        set_visibility.call(api_key_input, false)
        set_visibility.call(doubao_chat_key_input, true)
    else: # DeepSeek
        set_visibility.call(api_key_input, true)
        set_visibility.call(doubao_chat_key_input, false)

func _on_image_provider_changed(_idx: int) -> void:
    _update_image_gen_ui()

func _on_image_gen_toggled(_toggled: bool) -> void:
    _update_image_gen_ui()

func _update_image_gen_ui() -> void:
    var enabled = image_gen_mode_check.button_pressed
    
    var set_visibility = func(node: Control, should_visible: bool):
        node.visible = should_visible
        var label_name = node.name + "Label"
        var label = node.get_parent().get_node_or_null(label_name)
        if label:
            label.visible = should_visible
    
    set_visibility.call(image_provider_option, enabled)
    
    if not enabled:
        set_visibility.call(image_key_input, false)
        set_visibility.call(doubao_image_key_input, false)
        set_visibility.call(doubao_image_model_input, false)
        return
        
    var provider = image_provider_option.selected
    if provider == 0: # OpenAI
        set_visibility.call(image_key_input, true)
        set_visibility.call(doubao_image_key_input, false)
        set_visibility.call(doubao_image_model_input, false)
    else: # Doubao
        set_visibility.call(image_key_input, false)
        set_visibility.call(doubao_image_key_input, true)
        set_visibility.call(doubao_image_model_input, true)

func _on_back_pressed() -> void:
    hide_panel()

func _on_save_pressed() -> void:
    _save_ui_data()
    hide_panel()

func _on_clear_history_pressed() -> void:
    # 待实现清除历史记录的逻辑
    print("聊天记录已清除（模拟）")
