extends Control

@onready var api_key_input: LineEdit = $"ScrollContainer/TabContainer/API 设置/ApiKeyInput"
@onready var model_option: OptionButton = $"ScrollContainer/TabContainer/API 设置/ModelOption"
@onready var temp_slider: HSlider = $"ScrollContainer/TabContainer/API 设置/TempSlider"
@onready var tokens_spinbox: SpinBox = $"ScrollContainer/TabContainer/API 设置/TokensSpinBox"
@onready var ai_mode_check: CheckButton = $"ScrollContainer/TabContainer/API 设置/AIModeCheck"

@onready var voice_mode_check: CheckButton = $"ScrollContainer/TabContainer/语音设置/VoiceModeCheck"
@onready var app_id_input: LineEdit = $"ScrollContainer/TabContainer/语音设置/AppIdInput"
@onready var token_input: LineEdit = $"ScrollContainer/TabContainer/语音设置/TokenInput"
@onready var cluster_input: LineEdit = $"ScrollContainer/TabContainer/语音设置/ClusterInput"
@onready var voice_type_input: LineEdit = $"ScrollContainer/TabContainer/语音设置/VoiceTypeInput"

@onready var embed_key_input: LineEdit = $"ScrollContainer/TabContainer/向量设置/EmbedKeyInput"
@onready var embed_model_input: LineEdit = $"ScrollContainer/TabContainer/向量设置/EmbedModelInput"

@onready var back_button: Button = $TopBar/BackButton
@onready var save_button: Button = $SaveButton
@onready var clear_history_btn: Button = $"ScrollContainer/TabContainer/API 设置/ClearHistoryBtn"

func _ready() -> void:
    back_button.pressed.connect(_on_back_pressed)
    save_button.pressed.connect(_on_save_pressed)
    clear_history_btn.pressed.connect(_on_clear_history_pressed)
    
    _load_ui_data()

func _load_ui_data() -> void:
    var config = GameDataManager.config
    api_key_input.text = config.api_key
    
    if config.model == "deepseek-coder":
        model_option.selected = 1
    else:
        model_option.selected = 0
        
    temp_slider.value = config.temperature
    tokens_spinbox.value = config.max_tokens
    ai_mode_check.button_pressed = config.ai_mode_enabled
    
    voice_mode_check.button_pressed = config.voice_enabled
    app_id_input.text = config.doubao_app_id
    token_input.text = config.doubao_token
    cluster_input.text = config.doubao_cluster
    voice_type_input.text = config.doubao_voice_type
    
    embed_key_input.text = config.doubao_embedding_api_key
    embed_model_input.text = config.doubao_embedding_model

func _save_ui_data() -> void:
    var config = GameDataManager.config
    config.api_key = api_key_input.text
    config.model = "deepseek-coder" if model_option.selected == 1 else "deepseek-chat"
    config.temperature = temp_slider.value
    config.max_tokens = tokens_spinbox.value
    config.ai_mode_enabled = ai_mode_check.button_pressed
    
    config.voice_enabled = voice_mode_check.button_pressed
    config.doubao_app_id = app_id_input.text
    config.doubao_token = token_input.text
    config.doubao_cluster = cluster_input.text
    config.doubao_voice_type = voice_type_input.text
    
    config.doubao_embedding_api_key = embed_key_input.text
    config.doubao_embedding_model = embed_model_input.text
    
    config.save_config()

func _on_back_pressed() -> void:
    if get_parent().name == "ChatScene":
        hide()
    elif GameDataManager.previous_scene_path != "":
        get_tree().change_scene_to_file(GameDataManager.previous_scene_path)
    else:
        get_tree().change_scene_to_file("res://assets/scenes/ui/start/start_scene.tscn")

func _on_save_pressed() -> void:
    _save_ui_data()
    if get_parent().name == "ChatScene":
        hide()
    elif GameDataManager.previous_scene_path != "":
        get_tree().change_scene_to_file(GameDataManager.previous_scene_path)
    else:
        get_tree().change_scene_to_file("res://assets/scenes/ui/start/start_scene.tscn")

func _on_clear_history_pressed() -> void:
    # 待实现清除历史记录的逻辑
    print("聊天记录已清除（模拟）")
