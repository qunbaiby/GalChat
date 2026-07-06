extends PanelContainer

signal slot_selected(slot_id: String, is_empty: bool)
signal delete_requested(slot_id: String)
signal create_requested

@onready var id_label: Label = $MarginContainer/ContentVBox/HeaderHBox/IdLabel
@onready var summary_label: Label = $MarginContainer/ContentVBox/SummaryLabel
@onready var info_label: Label = $MarginContainer/ContentVBox/InfoLabel
@onready var time_label: Label = $MarginContainer/ContentVBox/TimeLabel
@onready var delete_button: Button = $MarginContainer/ContentVBox/HeaderHBox/DeleteButton
@onready var header_hbox: HBoxContainer = $MarginContainer/ContentVBox/HeaderHBox
@onready var spacer: Control = $MarginContainer/ContentVBox/HeaderHBox/Spacer
@onready var content_vbox: VBoxContainer = $MarginContainer/ContentVBox

var current_slot_id: String = ""
var is_empty: bool = true
var is_create_item: bool = false
var _filled_style: StyleBoxFlat
var _create_style: StyleBoxFlat

func _ready() -> void:
    mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    _build_styles()
    if delete_button:
        delete_button.pressed.connect(_on_delete_pressed)
    gui_input.connect(_on_card_gui_input)

func _build_styles() -> void:
    _filled_style = StyleBoxFlat.new()
    _filled_style.bg_color = Color(0.98, 0.995, 0.992, 0.96)
    _filled_style.border_width_left = 1
    _filled_style.border_width_top = 1
    _filled_style.border_width_right = 1
    _filled_style.border_width_bottom = 1
    _filled_style.border_color = Color(0.69, 0.84, 0.82, 0.95)
    _filled_style.corner_radius_top_left = 16
    _filled_style.corner_radius_top_right = 16
    _filled_style.corner_radius_bottom_left = 16
    _filled_style.corner_radius_bottom_right = 16
    _filled_style.shadow_color = Color(0.12, 0.24, 0.25, 0.1)
    _filled_style.shadow_size = 10
    _filled_style.shadow_offset = Vector2(0, 2)

    _create_style = StyleBoxFlat.new()
    _create_style.bg_color = Color(0.99, 0.998, 0.997, 0.86)
    _create_style.border_width_left = 2
    _create_style.border_width_top = 2
    _create_style.border_width_right = 2
    _create_style.border_width_bottom = 2
    _create_style.border_color = Color(0.16, 0.55, 0.53, 0.8)
    _create_style.corner_radius_top_left = 16
    _create_style.corner_radius_top_right = 16
    _create_style.corner_radius_bottom_left = 16
    _create_style.corner_radius_bottom_right = 16
    _create_style.shadow_color = Color(0.12, 0.24, 0.25, 0.12)
    _create_style.shadow_size = 10
    _create_style.shadow_offset = Vector2(0, 2)

func setup_create_item() -> void:
    current_slot_id = ""
    is_empty = true
    is_create_item = true
    custom_minimum_size = Vector2(0, 112)
    if is_instance_valid(content_vbox):
        content_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
    if is_instance_valid(header_hbox):
        header_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
    if is_instance_valid(spacer):
        spacer.hide()
    id_label.text = "+"
    summary_label.text = "创建新的记忆"
    info_label.text = "请为这段记忆命名"
    time_label.text = ""
    add_theme_stylebox_override("panel", _create_style)
    id_label.add_theme_color_override("font_color", Color(0.13, 0.62, 0.6, 1))
    id_label.add_theme_font_size_override("font_size", 36)
    id_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    summary_label.add_theme_color_override("font_color", Color(0.22, 0.28, 0.3, 1))
    summary_label.add_theme_font_size_override("font_size", 17)
    summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    info_label.add_theme_color_override("font_color", Color(0.44, 0.5, 0.53, 1))
    info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    time_label.hide()
    if delete_button:
        delete_button.hide()

func setup(slot_index: int, slot_id: String, meta: Dictionary) -> void:
    current_slot_id = slot_id
    is_create_item = false
    is_empty = false
    custom_minimum_size = Vector2(0, 138)
    if is_instance_valid(content_vbox):
        content_vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
    if is_instance_valid(header_hbox):
        header_hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
    if is_instance_valid(spacer):
        spacer.show()
    var archive_name := str(meta.get("archive_name", "")).strip_edges()
    if archive_name == "":
        archive_name = "记忆 %d" % slot_index

    id_label.text = archive_name
    id_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    summary_label.text = str(meta.get("display_line_1", "与 Luna 相处第1天"))
    summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    info_label.text = str(meta.get("display_line_2", "未命名 & Luna  当前情感阶段：相识"))
    info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    time_label.text = str(meta.get("display_line_3", "最后游玩：暂无"))
    time_label.show()
    add_theme_stylebox_override("panel", _filled_style)
    id_label.add_theme_color_override("font_color", Color(0.12, 0.18, 0.19, 1))
    id_label.add_theme_font_size_override("font_size", 20)
    summary_label.add_theme_color_override("font_color", Color(0.16, 0.23, 0.25, 1))
    info_label.add_theme_color_override("font_color", Color(0.31, 0.39, 0.42, 1))
    time_label.add_theme_color_override("font_color", Color(0.45, 0.53, 0.56, 1))
    if delete_button:
        delete_button.show()

func _on_card_gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        if delete_button and delete_button.visible and delete_button.get_global_rect().has_point(get_global_mouse_position()):
            return
        if is_create_item:
            create_requested.emit()
            return
        slot_selected.emit(current_slot_id, is_empty)

func _on_delete_pressed() -> void:
    if not is_empty:
        delete_requested.emit(current_slot_id)
