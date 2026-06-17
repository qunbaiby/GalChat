extends Control

signal confirmed
signal canceled

const PANEL_WIDTH := 460.0
const HEADER_BODY_GAP := 20.0
const PANEL_BOTTOM_PADDING := 22.0
const PANEL_MIN_HEIGHT := 220.0

@onready var panel_root: Panel = $Panel
@onready var header_panel: PanelContainer = $Panel/HeaderPanel
@onready var content_vbox: VBoxContainer = $Panel/VBoxContainer
@onready var button_hbox: HBoxContainer = $Panel/VBoxContainer/HBoxContainer
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
    subtitle_label.visible = _subtitle != ""
    subtitle_label.text = _subtitle
    message_label.text = _message
    warning_label.visible = _warning != ""
    warning_label.text = _warning

    var requires_input: bool = _required_text != ""
    input_guide_label.visible = requires_input
    confirm_input.visible = requires_input
    _set_input_hint_state(false, requires_input)
    if requires_input:
        input_guide_label.text = "请输入“%s”后继续操作" % _required_text
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
    _set_input_hint_state(new_text != "" and not matched, true)

func _on_confirm_pressed() -> void:
    if _required_text != "" and confirm_input.text.strip_edges() != _required_text:
        _set_input_hint_state(true, true)
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
    var header_height: float = maxf(72.0, header_panel.get_combined_minimum_size().y)
    var content_top: float = header_height + HEADER_BODY_GAP
    header_panel.offset_bottom = header_height
    content_vbox.offset_top = content_top

    # 根据实际内容最小高度动态计算面板高度，但在输入过程中保持占位稳定。
    var body_height: float = content_vbox.get_combined_minimum_size().y
    var panel_height: float = maxf(PANEL_MIN_HEIGHT, content_top + body_height + PANEL_BOTTOM_PADDING)
    panel_root.offset_left = -PANEL_WIDTH * 0.5
    panel_root.offset_top = -panel_height * 0.5
    panel_root.offset_right = PANEL_WIDTH * 0.5
    panel_root.offset_bottom = panel_height * 0.5

func _set_input_hint_state(show_hint: bool, reserve_space: bool) -> void:
    input_hint_label.visible = reserve_space
    if not reserve_space:
        return
    input_hint_label.modulate = Color(1.0, 1.0, 1.0, 1.0 if show_hint else 0.0)
