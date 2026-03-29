extends Button

signal option_selected(text: String)

func _ready() -> void:
    pressed.connect(_on_pressed)

func setup(text: String) -> void:
    self.text = text

func _on_pressed() -> void:
    option_selected.emit(self.text)
