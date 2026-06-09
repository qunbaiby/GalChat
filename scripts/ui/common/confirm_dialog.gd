extends Control

signal confirmed
signal canceled

@onready var title_label: Label = $Panel/HeaderPanel/HeaderMargin/HeaderVBox/TitleLabel
@onready var subtitle_label: Label = $Panel/HeaderPanel/HeaderMargin/HeaderVBox/SubtitleLabel
@onready var message_label: Label = $Panel/VBoxContainer/MessageLabel
@onready var warning_label: Label = $Panel/VBoxContainer/WarningLabel
@onready var input_guide_label: Label = $Panel/VBoxContainer/InputGuideLabel
@onready var confirm_input: LineEdit = $Panel/VBoxContainer/ConfirmInput
@onready var input_hint_label: Label = $Panel/VBoxContainer/InputHintLabel
@onready var confirm_button: Button = $Panel/VBoxContainer/HBoxContainer/ConfirmButton
@onready var cancel_button: Button = $Panel/VBoxContainer/HBoxContainer/CancelButton

var _message: String = "确定要执行此操作吗？"
var _title: String = "确认操作"
var _subtitle: String = ""
var _warning: String = ""
var _required_text: String = ""

func _ready() -> void:
    confirm_button.pressed.connect(_on_confirm_pressed)
    cancel_button.pressed.connect(_on_cancel_pressed)
    if confirm_input:
        confirm_input.text_changed.connect(_on_confirm_input_changed)
        confirm_input.text_submitted.connect(func(_text: String) -> void:
            if not confirm_button.disabled:
                _on_confirm_pressed()
        )
    _apply_content()

    modulate.a = 0.0
    var tween = create_tween()
    tween.tween_property(self, "modulate:a", 1.0, 0.2)

func setup(message: String, confirm_text: String = "确定", cancel_text: String = "取消") -> void:
    setup_advanced("确认操作", message, "", "", confirm_text, cancel_text, "")

func setup_advanced(title: String, message: String, warning: String = "", subtitle: String = "", confirm_text: String = "确定", cancel_text: String = "取消", required_text: String = "") -> void:
    _title = title
    _message = message
    _warning = warning
    _subtitle = subtitle
    _required_text = required_text
    if is_inside_tree():
        confirm_button.text = confirm_text
        cancel_button.text = cancel_text
        _apply_content()
    else:
        set_meta("confirm_text", confirm_text)
        set_meta("cancel_text", cancel_text)

func _apply_content() -> void:
    if has_meta("confirm_text"):
        confirm_button.text = str(get_meta("confirm_text"))
    if has_meta("cancel_text"):
        cancel_button.text = str(get_meta("cancel_text"))
    title_label.text = _title
    subtitle_label.visible = _subtitle != ""
    subtitle_label.text = _subtitle
    message_label.text = _message
    warning_label.visible = _warning != ""
    warning_label.text = _warning

    var requires_input: bool = _required_text != ""
    input_guide_label.visible = requires_input
    confirm_input.visible = requires_input
    input_hint_label.visible = false
    if requires_input:
        input_guide_label.text = "请输入“%s”后继续操作" % _required_text
        confirm_input.placeholder_text = _required_text
        confirm_input.text = ""
        confirm_button.disabled = true
        call_deferred("_grab_input_focus")
    else:
        confirm_button.disabled = false

func _grab_input_focus() -> void:
    if confirm_input and confirm_input.visible:
        confirm_input.grab_focus()

func _on_confirm_input_changed(new_text: String) -> void:
    var requires_input: bool = _required_text != ""
    if not requires_input:
        confirm_button.disabled = false
        return
    var matched: bool = new_text.strip_edges() == _required_text
    confirm_button.disabled = not matched
    input_hint_label.visible = new_text != "" and not matched

func _on_confirm_pressed() -> void:
    if _required_text != "" and confirm_input.text.strip_edges() != _required_text:
        input_hint_label.visible = true
        confirm_input.grab_focus()
        return
    confirmed.emit()
    _close()

func _on_cancel_pressed() -> void:
    canceled.emit()
    _close()

func _close() -> void:
    var tween = create_tween()
    tween.tween_property(self, "modulate:a", 0.0, 0.2)
    tween.tween_callback(queue_free)
