extends Control

@onready var api_key_input: LineEdit = %ApiKeyInput
@onready var doubao_chat_key_input: LineEdit = %DoubaoChatKeyInput
@onready var model_option: OptionButton = %ModelOption
@onready var temp_slider: HSlider = %TempSlider
@onready var tokens_spinbox: SpinBox = %TokensSpinBox
@onready var ai_mode_check: CheckButton = %AIModeCheck

@onready var voice_mode_check: CheckButton = %VoiceModeCheck
@onready var tts_backend_option: OptionButton = %TtsBackendOption
@onready var app_id_input: LineEdit = %AppIdInput
@onready var token_input: LineEdit = %TokenInput
@onready var cluster_input: LineEdit = %ClusterInput
@onready var qwen_tts_key_input: LineEdit = %QwenTtsKeyInput
@onready var asr_mode_check: CheckButton = %AsrModeCheck
@onready var asr_cluster_input: LineEdit = %AsrClusterInput
@onready var asr_test_button: Button = %AsrTestButton
@onready var asr_test_output: LineEdit = %AsrTestOutput
@onready var voice_type_container: VBoxContainer = %VoiceTypeContainer

@onready var embed_mode_check: CheckButton = %EmbedModeCheck
@onready var embed_key_input: LineEdit = %EmbedKeyInput
@onready var embed_model_input: LineEdit = %EmbedModelInput

@onready var vision_mode_check: CheckButton = %VisionModeCheck
@onready var player_nickname_input: LineEdit = %PlayerNicknameInput
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

@onready var pet_observe_time_slider: HSlider = %PetObserveTimeSlider
@onready var pet_observe_time_label: Label = %PetObserveTimeLabel
@onready var pet_same_app_cooldown_slider: HSlider = %PetSameAppCooldownSlider
@onready var pet_same_app_cooldown_label: Label = %PetSameAppCooldownLabel
@onready var pet_global_cooldown_slider: HSlider = %PetGlobalCooldownSlider
@onready var pet_global_cooldown_label: Label = %PetGlobalCooldownLabel
@onready var pet_scale_slider: HSlider = %PetScaleSlider
@onready var pet_scale_label: Label = %PetScaleLabel
@onready var pet_enable_app_observe_check: CheckButton = %PetEnableAppObserveCheck
@onready var pet_enable_hourly_chime_check: CheckButton = %PetEnableHourlyChimeCheck
@onready var pet_enable_afk_greeting_check: CheckButton = %PetEnableAfkGreetingCheck

@onready var resolution_option: OptionButton = %ResolutionOption
@onready var fps_option: OptionButton = %FPSOption
@onready var vsync_check: CheckButton = %VsyncCheck

@onready var bgm_slider: HSlider = %BGMSlider
@onready var voice_slider: HSlider = %VoiceSlider

@onready var background_panel: Panel = $Background
@onready var panel_root: PanelContainer = $CenterContainer/PanelRoot
@onready var tab_container: TabContainer = $CenterContainer/PanelRoot/MainMargin/RootVBox/BodyHBox/ContentPanel/ContentMargin/ContentVBox/ScrollContainer/TabContainer
@onready var back_button: Button = $CenterContainer/PanelRoot/MainMargin/RootVBox/BodyHBox/ContentPanel/ContentMargin/ContentVBox/TopBar/BackButton
@onready var header_title_label: Label = $CenterContainer/PanelRoot/MainMargin/RootVBox/BodyHBox/ContentPanel/ContentMargin/ContentVBox/TopBar/Title
@onready var header_hint_label: Label = $CenterContainer/PanelRoot/MainMargin/RootVBox/BodyHBox/ContentPanel/ContentMargin/ContentVBox/TopBar/HeaderHint
@onready var ai_tab_button: Button = $CenterContainer/PanelRoot/MainMargin/RootVBox/BodyHBox/SidePanel/SideMargin/SideVBox/AiTabButton
@onready var display_tab_button: Button = $CenterContainer/PanelRoot/MainMargin/RootVBox/BodyHBox/SidePanel/SideMargin/SideVBox/DisplayTabButton
@onready var audio_tab_button: Button = $CenterContainer/PanelRoot/MainMargin/RootVBox/BodyHBox/SidePanel/SideMargin/SideVBox/AudioTabButton
@onready var pet_tab_button: Button = $CenterContainer/PanelRoot/MainMargin/RootVBox/BodyHBox/SidePanel/SideMargin/SideVBox/PetTabButton
@onready var save_button: Button = get_node_or_null("SaveButton")
@onready var clear_history_btn: Button = %ClearHistoryBtn
@onready var audio_player: AudioStreamPlayer = $AudioStreamPlayer
@onready var mic_capture: AudioStreamPlayer = $MicCapture

const VOICE_TYPE_ITEM_SCENE_PATH: String = "res://scenes/ui/settings/settings_voice_type_item.tscn"

const POPUP_MIN_SIZE: Vector2 = Vector2(1120, 660)

var _test_asr_client = null
var _is_testing_asr: bool = false
var _sidebar_buttons: Array[Button] = []
var _tab_header_titles: Dictionary = {
    "AI 设置": "设置 / AI",
    "画面设置": "设置 / 图像",
    "声音设置": "设置 / 声音",
    "桌宠设置": "设置 / 桌宠"
}
var _tab_descriptions: Dictionary = {
    "AI 设置": "模型、接口、语音与图像等能力配置",
    "画面设置": "分辨率、帧率与显示表现",
    "声音设置": "背景音乐、角色语音与音量表现",
    "桌宠设置": "桌宠行为、报时、称呼与外观缩放"
}

func _ready() -> void:
    if back_button: back_button.pressed.connect(_on_back_pressed)
    if save_button: save_button.hide()
    if clear_history_btn: clear_history_btn.pressed.connect(_on_clear_history_pressed)
    TTSManager.tts_success.connect(_on_tts_success)
    TTSManager.tts_failed.connect(_on_tts_failed)
    
    # 动态连接设置变化
    resolution_option.item_selected.connect(_on_resolution_changed)
    fps_option.item_selected.connect(_on_fps_changed)
    vsync_check.toggled.connect(_on_vsync_changed)
    bgm_slider.value_changed.connect(_on_bgm_changed)
    voice_slider.value_changed.connect(_on_voice_changed)
    model_option.item_selected.connect(_on_model_changed)
    image_provider_option.item_selected.connect(_on_image_provider_changed)
    tts_backend_option.item_selected.connect(_on_tts_backend_changed)
    image_gen_mode_check.toggled.connect(_on_image_gen_toggled)
    
    if pet_observe_time_slider: pet_observe_time_slider.value_changed.connect(_on_pet_slider_changed)
    if pet_same_app_cooldown_slider: pet_same_app_cooldown_slider.value_changed.connect(_on_pet_slider_changed)
    if pet_global_cooldown_slider: pet_global_cooldown_slider.value_changed.connect(_on_pet_slider_changed)
    if pet_scale_slider: pet_scale_slider.value_changed.connect(_on_pet_slider_changed)
    
    asr_test_button.button_down.connect(_on_asr_test_down)
    asr_test_button.button_up.connect(_on_asr_test_up)
    
    model_option.clear()
    model_option.add_item("deepseek-chat (V3)")
    model_option.set_item_metadata(0, "deepseek-chat")
    model_option.add_item("deepseek-coder")
    model_option.set_item_metadata(1, "deepseek-coder")
    model_option.add_item("deepseek-reasoner (R1/V4)")
    model_option.set_item_metadata(2, "deepseek-reasoner")
    _sidebar_buttons = [ai_tab_button, display_tab_button, audio_tab_button, pet_tab_button]
    for i in _sidebar_buttons.size():
        var button: Button = _sidebar_buttons[i]
        if is_instance_valid(button):
            button.pressed.connect(_select_tab.bind(i))
    if tab_container:
        tab_container.tab_changed.connect(_on_tab_changed)
    _load_ui_data()
    _select_tab(tab_container.current_tab if tab_container else 0)

func show_panel() -> void:
    _load_ui_data()
    _update_popup_layout()
    _select_tab(tab_container.current_tab if tab_container else 0)
    show()
    modulate.a = 0.0
    if background_panel:
        background_panel.modulate.a = 0.0
    if panel_root:
        panel_root.modulate.a = 0.0
        panel_root.scale = Vector2(0.96, 0.96)
        panel_root.pivot_offset = panel_root.size * 0.5
    var tween: Tween = create_tween()
    tween.set_parallel(true)
    tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
    tween.tween_property(self, "modulate:a", 1.0, 0.24)
    if background_panel:
        tween.tween_property(background_panel, "modulate:a", 1.0, 0.24)
    if panel_root:
        tween.tween_property(panel_root, "modulate:a", 1.0, 0.28)
        tween.tween_property(panel_root, "scale", Vector2.ONE, 0.28)

func hide_panel() -> void:
    var tween: Tween = create_tween()
    tween.set_parallel(true)
    tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
    tween.tween_property(self, "modulate:a", 0.0, 0.18)
    if background_panel:
        tween.tween_property(background_panel, "modulate:a", 0.0, 0.18)
    if panel_root:
        tween.tween_property(panel_root, "modulate:a", 0.0, 0.18)
        tween.tween_property(panel_root, "scale", Vector2(0.96, 0.96), 0.18)
    tween.finished.connect(hide)

func _notification(what: int) -> void:
    if what == NOTIFICATION_RESIZED:
        _update_popup_layout()

func _select_tab(index: int) -> void:
    if index < 0 or index >= tab_container.get_tab_count():
        return
    tab_container.current_tab = index
    _refresh_tab_state(index)

func _on_tab_changed(index: int) -> void:
    _refresh_tab_state(index)

func _refresh_tab_state(index: int) -> void:
    var tab_title: String = tab_container.get_tab_title(index)
    if header_title_label:
        header_title_label.text = str(_tab_header_titles.get(tab_title, "设置"))
    if header_hint_label:
        header_hint_label.text = str(_tab_descriptions.get(tab_title, ""))
    for i in _sidebar_buttons.size():
        var button: Button = _sidebar_buttons[i]
        if button:
            var selected: bool = i == index
            button.button_pressed = selected
            button.modulate = Color(1, 1, 1, 1) if selected else Color(0.86, 0.86, 0.84, 1)
            var icon: TextureRect = button.get_node_or_null("Icon") as TextureRect
            if icon:
                icon.modulate = Color(0.15, 0.18, 0.18, 1) if selected else Color(0.95, 0.95, 0.92, 0.95)

func _update_popup_layout() -> void:
    if not panel_root:
        return
    var viewport_size: Vector2 = get_viewport_rect().size
    var target_size: Vector2 = POPUP_MIN_SIZE
    target_size.x = minf(target_size.x, viewport_size.x - 72.0)
    target_size.y = minf(target_size.y, viewport_size.y - 72.0)
    panel_root.custom_minimum_size = target_size
    panel_root.size = target_size
    panel_root.pivot_offset = target_size * 0.5

func _load_ui_data() -> void:
    var config = GameDataManager.config
    api_key_input.text = config.api_key
    doubao_chat_key_input.text = config.doubao_chat_api_key
    
    if config.model == "deepseek-coder":
        model_option.selected = 1
    elif config.model == "deepseek-reasoner":
        model_option.selected = 2
    else:
        model_option.selected = 0
        
    temp_slider.value = config.temperature
    tokens_spinbox.value = config.max_tokens
    ai_mode_check.button_pressed = config.ai_mode_enabled
    
    if config.tts_backend == "qwen_tts":
        tts_backend_option.selected = 1
    else:
        tts_backend_option.selected = 0
    
    voice_mode_check.button_pressed = config.voice_enabled
    app_id_input.text = config.doubao_app_id
    token_input.text = config.doubao_token
    cluster_input.text = config.doubao_cluster
    qwen_tts_key_input.text = config.qwen_tts_api_key
    asr_mode_check.button_pressed = config.qwen_asr_enabled
    asr_cluster_input.text = config.qwen_asr_api_key
    
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
    
    if pet_enable_app_observe_check:
        pet_enable_app_observe_check.button_pressed = config.pet_enable_app_observe
    if pet_enable_hourly_chime_check:
        pet_enable_hourly_chime_check.button_pressed = config.pet_enable_hourly_chime
    if pet_enable_afk_greeting_check:
        pet_enable_afk_greeting_check.button_pressed = config.pet_enable_afk_greeting
    
    if player_nickname_input:
        player_nickname_input.text = config.player_nickname
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
    
    if pet_observe_time_slider: pet_observe_time_slider.value = config.pet_new_app_observe_time
    if pet_same_app_cooldown_slider: pet_same_app_cooldown_slider.value = config.pet_same_app_cooldown
    if pet_global_cooldown_slider: pet_global_cooldown_slider.value = config.pet_global_cooldown
    if pet_scale_slider: pet_scale_slider.value = config.pet_scale_multiplier
    
    _update_pet_labels()
    
    _update_model_ui()
    _update_image_gen_ui()
    _update_tts_ui()

    # 加载音画设置
    resolution_option.selected = config.resolution_idx
    fps_option.selected = config.fps_idx
    vsync_check.button_pressed = config.vsync_enabled
    bgm_slider.value = config.bgm_volume
    voice_slider.value = config.voice_volume

func _create_voice_type_input(char_id: String, config, tag: String = "") -> void:
    if not ResourceLoader.exists(VOICE_TYPE_ITEM_SCENE_PATH):
        return

    var voice_type_scene: PackedScene = load(VOICE_TYPE_ITEM_SCENE_PATH) as PackedScene
    if voice_type_scene == null:
        return

    var item: VBoxContainer = voice_type_scene.instantiate() as VBoxContainer
    voice_type_container.add_child(item)

    var title_label: Label = item.get_node("TitleLabel")
    if tag != "":
        title_label.text = "[%s] %s 音色" % [tag, char_id.capitalize()]
    else:
        title_label.text = char_id.capitalize() + " 音色"

    var hbox_doubao: HBoxContainer = item.get_node_or_null("DoubaoHBox")
    if hbox_doubao == null:
        return
    var line_edit_doubao: LineEdit = hbox_doubao.get_node_or_null("InputDoubao")
    if line_edit_doubao == null:
        return
    var preview_btn_doubao: Button = hbox_doubao.get_node_or_null("PreviewDoubaoButton")
    if preview_btn_doubao == null:
        return
    hbox_doubao.name = "DoubaoHBox_" + char_id
    line_edit_doubao.name = "InputDoubao_" + char_id
    line_edit_doubao.text = config.character_voice_types.get(char_id, "ICL_zh_female_bingruoshaonv_tob")
    preview_btn_doubao.pressed.connect(_on_preview_voice_pressed.bind(line_edit_doubao, char_id, "doubao"))

    var hbox_qwen_tts: HBoxContainer = item.get_node_or_null("QwenTTSHBox")
    if hbox_qwen_tts == null:
        return
    var line_edit_qwen_tts: LineEdit = hbox_qwen_tts.get_node_or_null("InputQwenTTS")
    if line_edit_qwen_tts == null:
        return
    var preview_btn_qwen_tts: Button = hbox_qwen_tts.get_node_or_null("PreviewQwenButton")
    if preview_btn_qwen_tts == null:
        return
    hbox_qwen_tts.name = "QwenTTSHBox_" + char_id
    line_edit_qwen_tts.name = "InputQwenTTS_" + char_id
    line_edit_qwen_tts.placeholder_text = "填入音色 (如 Cherry)"
    var current_val: String = str(config.qwen_tts_voice_types.get(char_id, "Cherry"))
    line_edit_qwen_tts.text = str(current_val)
    preview_btn_qwen_tts.pressed.connect(_on_preview_voice_pressed.bind(line_edit_qwen_tts, char_id, "qwen_tts"))

func _save_ui_data() -> void:
    var config = GameDataManager.config
    config.api_key = api_key_input.text
    config.doubao_chat_api_key = doubao_chat_key_input.text
    if model_option.selected == 1:
        config.model = "deepseek-coder"
    elif model_option.selected == 2:
        config.model = "deepseek-reasoner"
    else:
        config.model = "deepseek-chat"
    config.temperature = temp_slider.value
    config.max_tokens = tokens_spinbox.value
    config.ai_mode_enabled = ai_mode_check.button_pressed
    
    if tts_backend_option.selected == 1:
        config.tts_backend = "qwen_tts"
    else:
        config.tts_backend = "doubao"
    
    config.voice_enabled = voice_mode_check.button_pressed
    config.doubao_app_id = app_id_input.text
    config.doubao_token = token_input.text
    config.doubao_cluster = cluster_input.text
    config.qwen_tts_api_key = qwen_tts_key_input.text
    config.qwen_asr_enabled = asr_mode_check.button_pressed
    config.qwen_asr_api_key = asr_cluster_input.text
    
    # 保存所有动态生成的角色音色配置
    for vbox in voice_type_container.get_children():
        for hbox in vbox.get_children():
            if hbox is HBoxContainer:
                for child in hbox.get_children():
                    if child is LineEdit and child.name.begins_with("InputDoubao_"):
                        var char_id = child.name.replace("InputDoubao_", "")
                        config.character_voice_types[char_id] = child.text
                    elif child is LineEdit and child.name.begins_with("InputQwenTTS_"):
                        var char_id = child.name.replace("InputQwenTTS_", "")
                        var val = child.text.strip_edges()
                        config.qwen_tts_voice_types[char_id] = val
    
    config.embedding_enabled = embed_mode_check.button_pressed
    config.doubao_embedding_api_key = embed_key_input.text
    config.doubao_embedding_model = embed_model_input.text
    
    config.vision_enabled = vision_mode_check.button_pressed
    if player_nickname_input:
        config.player_nickname = player_nickname_input.text
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
    
    if pet_observe_time_slider: config.pet_new_app_observe_time = int(pet_observe_time_slider.value)
    if pet_same_app_cooldown_slider: config.pet_same_app_cooldown = int(pet_same_app_cooldown_slider.value)
    if pet_global_cooldown_slider: config.pet_global_cooldown = int(pet_global_cooldown_slider.value)
    if pet_scale_slider: config.pet_scale_multiplier = float(pet_scale_slider.value)
    if pet_enable_app_observe_check: config.pet_enable_app_observe = pet_enable_app_observe_check.button_pressed
    if pet_enable_hourly_chime_check: config.pet_enable_hourly_chime = pet_enable_hourly_chime_check.button_pressed
    if pet_enable_afk_greeting_check: config.pet_enable_afk_greeting = pet_enable_afk_greeting_check.button_pressed
    
    config.resolution_idx = resolution_option.selected
    config.fps_idx = fps_option.selected
    config.vsync_enabled = vsync_check.button_pressed
    config.bgm_volume = bgm_slider.value
    config.voice_volume = voice_slider.value
    
    config.save_config()
    config.apply_settings()
    
    # 如果切换了 TTS 后端，直接通知 TTSManager 更新
    TTSManager.set_adapter(config.tts_backend)

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

func _on_tts_backend_changed(_idx: int) -> void:
    _update_tts_ui()

func _update_tts_ui() -> void:
    var provider = tts_backend_option.selected
    var is_qwen_tts = (provider == 1)
    
    var set_visibility = func(node: Control, should_visible: bool):
        if is_instance_valid(node):
            node.visible = should_visible
            var label_name = node.name + "Label"
            var label = node.get_parent().get_node_or_null(label_name)
            if label:
                label.visible = should_visible
                
    set_visibility.call(app_id_input, not is_qwen_tts)
    set_visibility.call(token_input, not is_qwen_tts)
    set_visibility.call(cluster_input, not is_qwen_tts)
    set_visibility.call(qwen_tts_key_input, is_qwen_tts)
    
    # Toggle character voice inputs visibility
    for vbox in voice_type_container.get_children():
        for child in vbox.get_children():
            if child.name.begins_with("DoubaoHBox_"):
                child.visible = not is_qwen_tts
            elif child.name.begins_with("QwenTTSHBox_"):
                child.visible = is_qwen_tts

func _update_model_ui() -> void:
    var set_visibility = func(node: Control, should_visible: bool):
        node.visible = should_visible
        var label_name = node.name + "Label"
        var label = node.get_parent().get_node_or_null(label_name)
        if label:
            label.visible = should_visible
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
    _save_ui_data()
    hide_panel()

func _on_save_pressed() -> void:
    _save_ui_data()
    hide_panel()

func _on_preview_voice_pressed(input_node: Control, char_id: String, backend: String) -> void:
    var voice_type = ""
    if input_node is LineEdit:
        voice_type = input_node.text.strip_edges()
        
    if voice_type == "":
        print("音色配置为空，无法试听")
        return
        
    var test_text = ""
    if char_id == "jing":
        test_text = "哼，别在那发呆了，我叫静。"
    elif char_id == "luna":
        test_text = "您、您好……我是Luna，请多指教。"
    elif char_id == "ya":
        test_text = "你好呀！我是雅，很高兴认识你哦～"
    elif char_id == "shuo":
        test_text = "你好，我是朔。"
    elif char_id == "aili":
        test_text = "别紧张，试着放松点，我是艾莉。"
    elif char_id == "ling":
        test_text = "真是的，这点小事都要我帮忙……我叫铃。"
    else:
        test_text = "你好，这是一段默认的音色试听文本，测试声音是否正常。"
        
    print("正在请求试听音色: ", voice_type, " | 文本: ", test_text, " | 引擎: ", backend)
    
    if audio_player.playing:
        audio_player.stop()
        
    # 为了防止修改了设置但还没点保存就去点试听，我们需要让试听走专门的设置参数，
    # 这里因为 TTSManager 目前通过 GameDataManager.config 和当前选择的 adapter 发送，
    # 我们可以临时让 TTSManager 使用正在设置的后端和音色
    var options = {}
    if backend == "doubao":
        options["voice_type"] = voice_type
        # 强制使用当前的 doubao 配置 (即使还没保存)
        options["app_id"] = app_id_input.text
        options["token"] = token_input.text
        options["cluster"] = cluster_input.text
    elif backend == "qwen_tts":
        options["voice_type"] = voice_type
        options["qwen_tts_api_key"] = qwen_tts_key_input.text
        
    # 临时切换 TTSAdapter，播放完毕后不需要切回，因为保存时也会最终确认
    TTSManager.set_adapter(backend)
    
    # 需要把上面刚读到的动态 URL/Token 等注入到适配器中
    if TTSManager.current_adapter:
        TTSManager.current_adapter.setup_auth(options)
        
    TTSManager.synthesize(test_text, options)

func _on_tts_success(audio_stream: AudioStream, _text: String) -> void:
    if audio_player and is_inside_tree() and visible:
        audio_player.stream = audio_stream
        audio_player.play()

func _on_tts_failed(error_msg: String, _text: String) -> void:
    if is_inside_tree() and visible:
        print("音色试听失败: ", error_msg)

func _on_clear_history_pressed() -> void:
    # 待实现清除历史记录的逻辑
    print("聊天记录已清除（模拟）")

func _on_asr_test_down() -> void:
    if _is_testing_asr: return
    _is_testing_asr = true
    asr_test_button.text = "松开结束"
    asr_test_button.modulate = Color(0.8, 0.2, 0.2)
    asr_test_output.text = ""
    asr_test_output.placeholder_text = "聆听中..."
    
    if mic_capture:
        mic_capture.play()
        
    if asr_mode_check.button_pressed:
        if _test_asr_client == null:
            var qwen_asr_client_script = load("res://scripts/api/qwen_asr_client.gd")
            if qwen_asr_client_script:
                _test_asr_client = qwen_asr_client_script.new()
                _test_asr_client.name = "TestQwenASR"
                add_child(_test_asr_client)
                _test_asr_client.transcribe_completed.connect(_on_asr_test_success)
                _test_asr_client.transcribe_failed.connect(_on_asr_test_failed)
        if _test_asr_client:
            # 应用当前输入框的配置，而不是只读 config 的，方便玩家不保存直接测
            GameDataManager.config.qwen_asr_api_key = asr_cluster_input.text
            _test_asr_client.start_recording()
    else:
        asr_test_output.placeholder_text = "请先开启流式语音识别开关"
        _is_testing_asr = false
        asr_test_button.text = "按住说话"
        asr_test_button.modulate = Color(1, 1, 1)

func _on_asr_test_up() -> void:
    if not _is_testing_asr: return
    _is_testing_asr = false
    asr_test_button.text = "转换中..."
    asr_test_button.disabled = true
    asr_test_button.modulate = Color(1, 1, 1)
    asr_test_output.placeholder_text = "转换中..."
    
    if mic_capture:
        mic_capture.stop()
        
    if _test_asr_client:
        _test_asr_client.stop_recording()

func _on_asr_test_success(text: String) -> void:
    asr_test_button.text = "按住说话"
    asr_test_button.disabled = false
    asr_test_output.text = text
    
func _on_asr_test_failed(err: String) -> void:
    asr_test_button.text = "按住说话"
    asr_test_button.disabled = false
    asr_test_output.text = ""
    asr_test_output.placeholder_text = "识别失败: " + err

func _on_pet_slider_changed(_value: float) -> void:
    _update_pet_labels()
    var config = GameDataManager.config
    if pet_observe_time_slider: config.pet_new_app_observe_time = int(pet_observe_time_slider.value)
    if pet_same_app_cooldown_slider: config.pet_same_app_cooldown = int(pet_same_app_cooldown_slider.value)
    if pet_global_cooldown_slider: config.pet_global_cooldown = int(pet_global_cooldown_slider.value)
    if pet_scale_slider: 
        config.pet_scale_multiplier = float(pet_scale_slider.value)
        _notify_pet_scale_changed()

func _notify_pet_scale_changed() -> void:
    var root = get_tree().root
    for child in root.get_children():
        if child.name == "DesktopPet":
            var body = child.get_node_or_null("Control/PetBody")
            if body and body.has_method("_update_sprite_scale"):
                body._update_sprite_scale()

func _update_pet_labels() -> void:
    # 不修改原本的节点结构，避免影响 Label 的直接显示，我们可以通过父节点的标签或者直接修改 Label 文本（但这会覆盖原本的说明文字）
    # 为了避免破坏 UI，如果你的 Label 是直接用来做标题的，我们可以在旁边或者下面加显示数值。
    # 根据你提供的场景树结构：Label 是和 Slider 并列在 Grid 里的。
    # 最稳妥的方式是将当前值拼接到 Label 的末尾。
    
    if pet_observe_time_slider and pet_observe_time_label:
        pet_observe_time_label.text = "新应用观察时间 (%d 秒)" % int(pet_observe_time_slider.value)
    if pet_same_app_cooldown_slider and pet_same_app_cooldown_label:
        pet_same_app_cooldown_label.text = "同应用吐槽间隔 (%d 秒)" % int(pet_same_app_cooldown_slider.value)
    if pet_global_cooldown_slider and pet_global_cooldown_label:
        pet_global_cooldown_label.text = "全局最小冷却 (%d 秒)" % int(pet_global_cooldown_slider.value)
    if pet_scale_slider and pet_scale_label:
        pet_scale_label.text = "桌宠立绘缩放倍率 (%.2fx)" % pet_scale_slider.value
