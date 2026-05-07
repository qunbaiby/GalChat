extends Control

@onready var start_button: Button = $VBoxContainer/StartButton
@onready var load_button: Button = $VBoxContainer/LoadButton
@onready var settings_button: Button = $VBoxContainer/SettingsButton

var settings_panel_instance = null
var save_load_panel_instance = null

func _ready() -> void:
    if GameDataManager.config:
        GameDataManager.config.apply_settings()
        
    # 开始界面需要占据全屏，取消鼠标穿透（恢复系统默认的全屏接受鼠标输入，同时确保画面渲染）
    DisplayServer.window_set_mouse_passthrough(PackedVector2Array(), get_tree().root.get_window_id())
        
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
    start_button.pressed.connect(_on_start_pressed)
    load_button.pressed.connect(_on_load_pressed)
    settings_button.pressed.connect(_on_settings_pressed)
    
    # 动画：按钮点击弹性反馈
    start_button.pivot_offset = start_button.size / 2
    load_button.pivot_offset = load_button.size / 2
    settings_button.pivot_offset = settings_button.size / 2

func _on_close_requested() -> void:
    pass

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_CLOSE_REQUEST:
        get_tree().quit()

func _on_start_pressed() -> void:
    _animate_button(start_button)
    var window = get_window()
    GameDataManager.set_meta("last_window_pos", window.position)
    
    # Check if the intro story has been finished properly
    var need_play_intro = false
    # 强制在检查前加载当前角色的存档数据
    if GameDataManager.profile:
        GameDataManager.profile.load_profile()
        
    if GameDataManager.profile and not GameDataManager.profile.has_finished_story("intro_story"):
        need_play_intro = true
        
    # Create black screen overlay
    var overlay = ColorRect.new()
    overlay.color = Color(0, 0, 0, 0)
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(overlay)
    
    var tween = create_tween()
    tween.tween_property(overlay, "color:a", 1.0, 1.0)
    await tween.finished
    
    if need_play_intro:
        # Clear history to ensure a clean slate if the player aborted the intro previously
        if GameDataManager.history:
            GameDataManager.history.clear_history()
            
        GameDataManager.set_meta("play_intro_story", true)
        get_tree().change_scene_to_file("res://scenes/ui/story/story_scene.tscn")
    else:
        # Load auto save by default if available, otherwise just go to main
        if GameDataManager.save_manager.load_game("auto"):
            get_tree().change_scene_to_file("res://scenes/ui/main/main_scene.tscn")
        else:
            get_tree().change_scene_to_file("res://scenes/ui/main/main_scene.tscn")

func _on_load_pressed() -> void:
    _animate_button(load_button)
    if save_load_panel_instance == null:
        var SaveLoadPanelObj = load("res://scenes/ui/save_load/save_load_panel.tscn")
        save_load_panel_instance = SaveLoadPanelObj.instantiate()
        add_child(save_load_panel_instance)
        save_load_panel_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    save_load_panel_instance.show_panel(false)

func _on_settings_pressed() -> void:
    _animate_button(settings_button)
    if settings_panel_instance == null:
        var SettingsPanelObj = load("res://scenes/ui/settings/settings_scene.tscn")
        settings_panel_instance = SettingsPanelObj.instantiate()
        add_child(settings_panel_instance)
        settings_panel_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    settings_panel_instance.show_panel()

func _animate_button(btn: Button) -> void:
    var tween = create_tween()
    tween.tween_property(btn, "scale", Vector2(0.9, 0.9), 0.05)
    tween.tween_property(btn, "scale", Vector2(1.1, 1.1), 0.05)
    tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.05)
