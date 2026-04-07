extends Control

@onready var galchat_button: Button = $VBoxContainer/GalChatButton
@onready var stats_button: Button = $VBoxContainer/StatsButton
@onready var activity_button: Button = $VBoxContainer/ActivityButton
@onready var settings_button: Button = $TopBar/SettingsButton

var stats_panel_instance = null
var activity_panel_instance = null

func _ready() -> void:
    galchat_button.pressed.connect(_on_galchat_pressed)
    settings_button.pressed.connect(_on_settings_pressed)
    stats_button.pressed.connect(_on_stats_pressed)
    activity_button.pressed.connect(_on_activity_pressed)
    
    # 动画：按钮点击弹性反馈
    galchat_button.pivot_offset = galchat_button.size / 2
    settings_button.pivot_offset = settings_button.size / 2
    stats_button.pivot_offset = stats_button.size / 2
    activity_button.pivot_offset = activity_button.size / 2

func _on_stats_pressed() -> void:
    _animate_button(stats_button)
    if stats_panel_instance == null:
        var StatsPanelObj = load("res://assets/scenes/ui/stats_panel.tscn")
        stats_panel_instance = StatsPanelObj.instantiate()
        add_child(stats_panel_instance)
        # 确保它盖在最上面
        stats_panel_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    stats_panel_instance.show_panel()

func _on_activity_pressed() -> void:
    _animate_button(activity_button)
    if activity_panel_instance == null:
        var ActivityPanelObj = load("res://assets/scenes/ui/activity_panel.tscn")
        activity_panel_instance = ActivityPanelObj.instantiate()
        add_child(activity_panel_instance)
        # 确保它盖在最上面
        activity_panel_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    activity_panel_instance.show_panel()

func _on_galchat_pressed() -> void:
    _animate_button(galchat_button)
    await get_tree().create_timer(0.2).timeout
    get_tree().change_scene_to_file("res://assets/scenes/ui/chat/chat_scene.tscn")

func _on_settings_pressed() -> void:
    _animate_button(settings_button)
    await get_tree().create_timer(0.2).timeout
    GameDataManager.previous_scene_path = "res://assets/scenes/ui/main/main_scene.tscn"
    get_tree().change_scene_to_file("res://assets/scenes/ui/settings/settings_scene.tscn")

func _animate_button(btn: Button) -> void:
    var tween = create_tween()
    tween.tween_property(btn, "scale", Vector2(0.9, 0.9), 0.05)
    tween.tween_property(btn, "scale", Vector2(1.1, 1.1), 0.05)
    tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.05)
