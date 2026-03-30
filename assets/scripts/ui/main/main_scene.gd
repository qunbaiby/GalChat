extends Control

@onready var galchat_button: Button = $VBoxContainer/GalChatButton
@onready var settings_button: Button = $TopBar/SettingsButton

func _ready() -> void:
    galchat_button.pressed.connect(_on_galchat_pressed)
    settings_button.pressed.connect(_on_settings_pressed)
    
    # 动画：按钮点击弹性反馈
    galchat_button.pivot_offset = galchat_button.size / 2
    settings_button.pivot_offset = settings_button.size / 2

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
