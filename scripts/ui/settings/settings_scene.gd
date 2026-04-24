extends Control

@onready var api_key_input: LineEdit = $"ScrollContainer/TabContainer/AI 设置/ApiKeyInput"
@onready var model_option: OptionButton = $"ScrollContainer/TabContainer/AI 设置/ModelOption"
@onready var temp_slider: HSlider = $"ScrollContainer/TabContainer/AI 设置/TempSlider"
@onready var tokens_spinbox: SpinBox = $"ScrollContainer/TabContainer/AI 设置/TokensSpinBox"
@onready var ai_mode_check: CheckButton = $"ScrollContainer/TabContainer/AI 设置/AIModeCheck"

@onready var voice_mode_check: CheckButton = $"ScrollContainer/TabContainer/AI 设置/VoiceModeCheck"
@onready var app_id_input: LineEdit = $"ScrollContainer/TabContainer/AI 设置/AppIdInput"
@onready var token_input: LineEdit = $"ScrollContainer/TabContainer/AI 设置/TokenInput"
@onready var cluster_input: LineEdit = $"ScrollContainer/TabContainer/AI 设置/ClusterInput"
@onready var voice_type_container: VBoxContainer = $"ScrollContainer/TabContainer/声音设置/VoiceTypeContainer"

@onready var embed_key_input: LineEdit = $"ScrollContainer/TabContainer/AI 设置/EmbedKeyInput"
@onready var embed_model_input: LineEdit = $"ScrollContainer/TabContainer/AI 设置/EmbedModelInput"

@onready var resolution_option: OptionButton = $"ScrollContainer/TabContainer/画面设置/ResolutionOption"
@onready var fps_option: OptionButton = $"ScrollContainer/TabContainer/画面设置/FPSOption"
@onready var vsync_check: CheckButton = $"ScrollContainer/TabContainer/画面设置/VsyncCheck"

@onready var bgm_slider: HSlider = $"ScrollContainer/TabContainer/声音设置/BGMSlider"
@onready var voice_slider: HSlider = $"ScrollContainer/TabContainer/声音设置/VoiceSlider"

@onready var back_button: Button = $TopBar/BackButton
@onready var save_button: Button = $SaveButton
@onready var clear_history_btn: Button = $"ScrollContainer/TabContainer/AI 设置/ClearHistoryBtn"

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
    
    model_option.clear()
    model_option.add_item("deepseek-chat (V3)")
    model_option.set_item_metadata(0, "deepseek-chat")
    model_option.add_item("deepseek-coder")
    model_option.set_item_metadata(1, "deepseek-coder")
    model_option.add_item("deepseek-reasoner (R1/V4)")
    model_option.set_item_metadata(2, "deepseek-reasoner")
    
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
    
    if config.model == "deepseek-coder":
        model_option.selected = 1
    elif config.model == "deepseek-reasoner":
        model_option.selected = 2
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
        
    var dir = DirAccess.open("res://assets/data/characters")
    if dir:
        dir.list_dir_begin()
        var file_name = dir.get_next()
        while file_name != "":
            if file_name.ends_with(".json") and not file_name.ends_with("_stages.json"):
                var char_id = file_name.replace(".json", "")
                _create_voice_type_input(char_id, config)
            file_name = dir.get_next()
    
    embed_key_input.text = config.doubao_embedding_api_key
    embed_model_input.text = config.doubao_embedding_model

    # 加载音画设置
    resolution_option.selected = config.resolution_idx
    fps_option.selected = config.fps_idx
    vsync_check.button_pressed = config.vsync_enabled
    bgm_slider.value = config.bgm_volume
    voice_slider.value = config.voice_volume

func _create_voice_type_input(char_id: String, config) -> void:
    var vbox = VBoxContainer.new()
    voice_type_container.add_child(vbox)
    
    var label = Label.new()
    label.text = char_id.capitalize() + " 音色 (Voice Type)"
    vbox.add_child(label)
    
    var line_edit = LineEdit.new()
    line_edit.name = "Input_" + char_id
    line_edit.text = config.character_voice_types.get(char_id, "ICL_zh_female_bingruoshaonv_tob")
    vbox.add_child(line_edit)

func _save_ui_data() -> void:
    var config = GameDataManager.config
    config.api_key = api_key_input.text
    if model_option.selected == 1:
        config.model = "deepseek-coder"
    elif model_option.selected == 2:
        config.model = "deepseek-reasoner"
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
    
    config.doubao_embedding_api_key = embed_key_input.text
    config.doubao_embedding_model = embed_model_input.text
    
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

func _on_back_pressed() -> void:
    hide_panel()

func _on_save_pressed() -> void:
    _save_ui_data()
    hide_panel()

func _on_clear_history_pressed() -> void:
    # 待实现清除历史记录的逻辑
    print("聊天记录已清除（模拟）")
