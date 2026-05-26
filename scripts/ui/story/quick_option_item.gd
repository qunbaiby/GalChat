extends Button

signal option_selected(text: String)

var _hover_tween: Tween = null

func _ready() -> void:
    pressed.connect(_on_pressed)
    mouse_entered.connect(_on_mouse_entered)
    mouse_exited.connect(_on_mouse_exited)
    button_down.connect(_on_button_down)
    button_up.connect(_on_button_up)
    resized.connect(_update_pivot_offset)

    _update_pivot_offset()

func setup(text: String, min_height: float = -1.0) -> void:
    self.text = text
    if min_height > 0.0:
        custom_minimum_size.y = min_height

func _on_pressed() -> void:
    option_selected.emit(self.text)

func _update_pivot_offset() -> void:
    pivot_offset = size / 2.0

func _play_scale(target_scale: Vector2, duration: float) -> void:
    if _hover_tween:
        _hover_tween.kill()
    _hover_tween = create_tween()
    _hover_tween.tween_property(self, "scale", target_scale, duration).set_trans(Tween.TRANS_SINE)

func _on_mouse_entered() -> void:
    _play_scale(Vector2(1.02, 1.02), 0.2)

func _on_mouse_exited() -> void:
    _play_scale(Vector2(1.0, 1.0), 0.2)

func _on_button_down() -> void:
    _play_scale(Vector2(0.98, 0.98), 0.1)

func _on_button_up() -> void:
    _play_scale(Vector2(1.02, 1.02), 0.1)
