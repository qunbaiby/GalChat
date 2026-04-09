extends Window

@onready var start_button: Button = $VBoxContainer/StartButton
@onready var settings_button: Button = $VBoxContainer/SettingsButton

func _ready() -> void:
    if self is Window:
        if GameDataManager.has_meta("last_window_pos"):
            var last_pos = GameDataManager.get_meta("last_window_pos")
            if typeof(last_pos) == TYPE_VECTOR2I or typeof(last_pos) == TYPE_VECTOR2:
                self.position = last_pos
            else:
                self.move_to_center()
        else:
            self.move_to_center()
            
    close_requested.connect(_on_close_requested)
    start_button.pressed.connect(_on_start_pressed)
    settings_button.pressed.connect(_on_settings_pressed)
    
    # 动画：按钮点击弹性反馈
    start_button.pivot_offset = start_button.size / 2
    settings_button.pivot_offset = settings_button.size / 2

func _on_close_requested() -> void:
    get_tree().quit()

func _on_start_pressed() -> void:
    _animate_button(start_button)
    if self is Window:
        GameDataManager.set_meta("last_window_pos", self.position)
    await get_tree().create_timer(0.2).timeout
    get_tree().change_scene_to_file("res://scenes/ui/main/main_scene.tscn")

func _on_settings_pressed() -> void:
    _animate_button(settings_button)
    if self is Window:
        GameDataManager.set_meta("last_window_pos", self.position)
    await get_tree().create_timer(0.2).timeout
    GameDataManager.previous_scene_path = "res://scenes/ui/start/start_scene.tscn"
    get_tree().change_scene_to_file("res://scenes/ui/settings/settings_scene.tscn")

func _animate_button(btn: Button) -> void:
    var tween = create_tween()
    tween.tween_property(btn, "scale", Vector2(0.9, 0.9), 0.05)
    tween.tween_property(btn, "scale", Vector2(1.1, 1.1), 0.05)
    tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.05)
