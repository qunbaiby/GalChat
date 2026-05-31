extends Button

signal option_selected(text: String)

func _ready() -> void:
    pressed.connect(_on_pressed)

func setup(text: String, min_height: float = -1.0) -> void:
    self.text = text
    if min_height > 0.0:
        custom_minimum_size.y = min_height

func _on_pressed() -> void:
    option_selected.emit(self.text)
