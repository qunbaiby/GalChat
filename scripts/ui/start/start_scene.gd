extends Control

@onready var start_button: Button = $VBoxContainer/StartButton
@onready var settings_button: Button = $VBoxContainer/SettingsButton

var settings_panel_instance = null

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
    settings_button.pressed.connect(_on_settings_pressed)
    
    # 动画：按钮点击弹性反馈
    start_button.pivot_offset = start_button.size / 2
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
    await get_tree().create_timer(0.2).timeout
    get_tree().change_scene_to_file("res://scenes/ui/main/main_scene.tscn")

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
