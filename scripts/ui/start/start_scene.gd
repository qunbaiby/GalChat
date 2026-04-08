extends Control

@onready var start_button: Button = $VBoxContainer/StartButton
@onready var settings_button: Button = $VBoxContainer/SettingsButton

func _ready() -> void:
    start_button.pressed.connect(_on_start_pressed)
    settings_button.pressed.connect(_on_settings_pressed)
    
    # 动画：按钮点击弹性反馈
    start_button.pivot_offset = start_button.size / 2
    settings_button.pivot_offset = settings_button.size / 2

func _on_start_pressed() -> void:
    _animate_button(start_button)
    await get_tree().create_timer(0.2).timeout
    get_tree().change_scene_to_file("res://scenes/ui/main/main_scene.tscn")

func _on_settings_pressed() -> void:
    _animate_button(settings_button)
    await get_tree().create_timer(0.2).timeout
    GameDataManager.previous_scene_path = "res://scenes/ui/start/start_scene.tscn"
    get_tree().change_scene_to_file("res://scenes/ui/settings/settings_scene.tscn")

func _animate_button(btn: Button) -> void:
    var tween = create_tween()
    tween.tween_property(btn, "scale", Vector2(0.9, 0.9), 0.05)
    tween.tween_property(btn, "scale", Vector2(1.1, 1.1), 0.05)
    tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.05)
