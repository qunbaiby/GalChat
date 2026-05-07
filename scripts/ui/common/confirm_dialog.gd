extends Control

signal confirmed
signal canceled

@onready var message_label: Label = $Panel/VBoxContainer/MessageLabel
@onready var confirm_button: Button = $Panel/VBoxContainer/HBoxContainer/ConfirmButton
@onready var cancel_button: Button = $Panel/VBoxContainer/HBoxContainer/CancelButton

var _message: String = "确定要执行此操作吗？"

func _ready() -> void:
    confirm_button.pressed.connect(_on_confirm_pressed)
    cancel_button.pressed.connect(_on_cancel_pressed)
    message_label.text = _message
    
    # 弹出动画
    modulate.a = 0.0
    var tween = create_tween()
    tween.tween_property(self, "modulate:a", 1.0, 0.2)

func setup(message: String, confirm_text: String = "确定", cancel_text: String = "取消") -> void:
    _message = message
    if is_inside_tree():
        message_label.text = message
        confirm_button.text = confirm_text
        cancel_button.text = cancel_text

func _on_confirm_pressed() -> void:
    confirmed.emit()
    _close()

func _on_cancel_pressed() -> void:
    canceled.emit()
    _close()

func _close() -> void:
    var tween = create_tween()
    tween.tween_property(self, "modulate:a", 0.0, 0.2)
    tween.tween_callback(queue_free)
