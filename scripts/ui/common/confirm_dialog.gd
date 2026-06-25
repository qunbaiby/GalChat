extends Control

signal confirmed
signal canceled

const PANEL_WIDTH := 460.0
const PANEL_MIN_HEIGHT := 220.0
const INPUT_GUIDE_NORMAL_COLOR := Color(0.36, 0.42, 0.45, 1.0)
const INPUT_GUIDE_ERROR_COLOR := Color(0.78, 0.31, 0.38, 1.0)

@onready var panel_root: PanelContainer = $ConfirmPanel
@onready var content_vbox: VBoxContainer = $ConfirmPanel/ConfirmMargin/ConfirmContainer
@onready var body_vbox: VBoxContainer = $ConfirmPanel/ConfirmMargin/ConfirmContainer/VBoxContainer
@onready var button_hbox: HBoxContainer = $ConfirmPanel/ConfirmMargin/ConfirmContainer/VBoxContainer/HBoxContainer
@onready var title_label: Label = $ConfirmPanel/ConfirmMargin/ConfirmContainer/TitleLabel
@onready var message_label: Label = $ConfirmPanel/ConfirmMargin/ConfirmContainer/VBoxContainer/MessageLabel
@onready var warning_label: Label = $ConfirmPanel/ConfirmMargin/ConfirmContainer/VBoxContainer/WarningLabel
@onready var input_guide_label: Label = $ConfirmPanel/ConfirmMargin/ConfirmContainer/VBoxContainer/InputGuideLabel
@onready var confirm_input: LineEdit = $ConfirmPanel/ConfirmMargin/ConfirmContainer/VBoxContainer/ConfirmInput
@onready var confirm_button: Button = $ConfirmPanel/ConfirmMargin/ConfirmContainer/VBoxContainer/HBoxContainer/ConfirmButton
@onready var cancel_button: Button = $ConfirmPanel/ConfirmMargin/ConfirmContainer/VBoxContainer/HBoxContainer/CancelButton

var _message: String = "确定要执行此操作吗？"
var _title: String = "确认操作"
var _subtitle: String = ""
var _warning: String = ""
var _required_text: String = ""
var _input_guide_base_text: String = ""

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
    call_deferred("_refresh_panel_layout")

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
    message_label.text = _message
    warning_label.visible = _warning != ""
    warning_label.text = _warning

    var requires_input: bool = _required_text != ""
    _input_guide_base_text = _subtitle
    if requires_input and _input_guide_base_text == "":
        _input_guide_base_text = "请输入“%s”后继续操作" % _required_text
    input_guide_label.visible = _input_guide_base_text != ""
    confirm_input.visible = requires_input
    _set_input_hint_state(false)
    if requires_input:
        confirm_input.placeholder_text = _required_text
        confirm_input.text = ""
        confirm_button.disabled = true
        call_deferred("_grab_input_focus")
    else:
        confirm_button.disabled = false
    call_deferred("_refresh_panel_layout")

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
    _set_input_hint_state(new_text != "" and not matched)

func _on_confirm_pressed() -> void:
    if _required_text != "" and confirm_input.text.strip_edges() != _required_text:
        _set_input_hint_state(true)
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

func _refresh_panel_layout() -> void:
    var content_size: Vector2 = panel_root.get_combined_minimum_size()
    var panel_width: float = maxf(PANEL_WIDTH, content_size.x)
    var panel_height: float = maxf(PANEL_MIN_HEIGHT, content_size.y)
    panel_root.offset_left = -panel_width * 0.5
    panel_root.offset_top = -panel_height * 0.5
    panel_root.offset_right = panel_width * 0.5
    panel_root.offset_bottom = panel_height * 0.5

func _set_input_hint_state(show_error: bool) -> void:
    if not input_guide_label.visible:
        return
    if show_error:
        input_guide_label.text = "输入内容不正确"
        input_guide_label.add_theme_color_override("font_color", INPUT_GUIDE_ERROR_COLOR)
        return
    input_guide_label.text = _input_guide_base_text
    input_guide_label.add_theme_color_override("font_color", INPUT_GUIDE_NORMAL_COLOR)
