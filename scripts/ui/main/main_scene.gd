extends Control

@onready var galchat_button: Button = $GalChatButton
@onready var activity_button: Button = $ActivityButton
@onready var desktop_pet_button: Button = $DesktopPetButton
@onready var settings_button: Button = $TopBar/SettingsButton
@onready var archive_button: Button = $TopBar/ArchiveButton
@onready var switch_char_button: Button = $TopBar/SwitchCharButton
@onready var stats_panel = $StatsPanel
@onready var archive_panel = $ArchivePanel
@onready var bgm: AudioStreamPlayer = $BGM

var activity_panel_instance = null
var settings_panel_instance = null
var desktop_pet_instance: Window = null
var chat_scene_instance = null

var _window_detector: Node = null
var _is_afk: bool = false
var _afk_timer: Timer = null

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
    archive_button.pressed.connect(_on_archive_pressed)
    switch_char_button.pressed.connect(_on_switch_char_pressed)
    activity_button.pressed.connect(_on_activity_pressed)
    desktop_pet_button.pressed.connect(_on_desktop_pet_pressed)
    
    GameDataManager.character_switched.connect(_on_character_switched)
    
    # 动画：按钮点击弹性反馈
    galchat_button.pivot_offset = galchat_button.size / 2
    settings_button.pivot_offset = settings_button.size / 2
    archive_button.pivot_offset = archive_button.size / 2
    switch_char_button.pivot_offset = switch_char_button.size / 2
    activity_button.pivot_offset = activity_button.size / 2
    desktop_pet_button.pivot_offset = desktop_pet_button.size / 2
    
    # 恢复整个主窗口的鼠标输入响应，清除可能因为之前透明测试遗留的 passthrough 多边形
    if not is_queued_for_deletion():
        DisplayServer.window_set_mouse_passthrough(PackedVector2Array(), get_window().get_window_id())
    
    # Update StatsPanel explicitly when returning to main scene
    if stats_panel and stats_panel.has_method("_update_ui"):
        stats_panel._update_ui()
        
    # 尝试找回已存在的桌宠实例
    if get_tree().root.has_node("DesktopPet"):
        desktop_pet_instance = get_tree().root.get_node("DesktopPet")
        
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


func _on_archive_pressed() -> void:
    _animate_button(archive_button)
    if archive_panel:
        archive_panel.show_panel()

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
        var ChatSceneObj = load("res://scenes/ui/chat/chat_scene.tscn")
        chat_scene_instance = ChatSceneObj.instantiate()
        add_child(chat_scene_instance)
        chat_scene_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        chat_scene_instance.chat_closed.connect(_on_chat_closed)
        
    chat_scene_instance.show_panel()
    if bgm.playing:
        bgm.stop()

func _on_chat_closed() -> void:
    if not bgm.playing:
        bgm.play()

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

func _on_switch_char_pressed() -> void:
    _animate_button(switch_char_button)
    
    # 简单的切换逻辑：如果有更多角色可以弹出一个面板，这里先做二切一
    var current_id = GameDataManager.config.current_character_id
    var target_id = "ya" if current_id == "luna" else "luna"
    
    # 调用 GameDataManager 统一接口切换
    GameDataManager.switch_character(target_id)

func _on_character_switched(char_id: String) -> void:
    # 角色切换后更新主界面的面板（特别是数值显示）
    if stats_panel and stats_panel.has_method("_update_ui"):
        stats_panel._update_ui()
    
    # 更新右上角的 AffectionPanel
    var affection_panel = $AffectionPanel
    if affection_panel and affection_panel.has_method("update_ui"):
        affection_panel.update_ui()
        
    # 注意：ChatScene 的更新由它自己内部监听信号处理

func _animate_button(btn: Button) -> void:
    var tween = create_tween()
    tween.tween_property(btn, "scale", Vector2(0.9, 0.9), 0.05)
    tween.tween_property(btn, "scale", Vector2(1.1, 1.1), 0.05)
    tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.05)
