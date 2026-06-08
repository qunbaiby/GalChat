extends PanelContainer

signal slot_selected(slot_id: String, is_empty: bool)
signal delete_requested(slot_id: String)

@onready var id_label: Label = $MarginContainer/ContentVBox/HeaderHBox/IdLabel
@onready var summary_label: Label = $MarginContainer/ContentVBox/SummaryLabel
@onready var info_label: Label = $MarginContainer/ContentVBox/InfoLabel
@onready var time_label: Label = $MarginContainer/ContentVBox/TimeLabel
@onready var delete_button: Button = $MarginContainer/ContentVBox/HeaderHBox/DeleteButton

var current_slot_id: String = ""
var is_empty: bool = true
var _filled_style: StyleBoxFlat
var _empty_style: StyleBoxFlat

func _ready() -> void:
    mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    _build_styles()
    if delete_button:
        delete_button.pressed.connect(_on_delete_pressed)
    gui_input.connect(_on_card_gui_input)

func _build_styles() -> void:
    _filled_style = StyleBoxFlat.new()
    _filled_style.bg_color = Color(0.9607843, 0.98039216, 0.96862745, 0.92)
    _filled_style.border_width_left = 1
    _filled_style.border_width_top = 1
    _filled_style.border_width_right = 1
    _filled_style.border_width_bottom = 1
    _filled_style.border_color = Color(0.82, 0.9, 0.88, 0.95)
    _filled_style.corner_radius_top_left = 18
    _filled_style.corner_radius_top_right = 18
    _filled_style.corner_radius_bottom_left = 18
    _filled_style.corner_radius_bottom_right = 18
    _filled_style.shadow_color = Color(0.18, 0.28, 0.33, 0.08)
    _filled_style.shadow_size = 8
    _filled_style.shadow_offset = Vector2(0, 2)

    _empty_style = StyleBoxFlat.new()
    _empty_style.bg_color = Color(1, 1, 1, 0.72)
    _empty_style.border_width_left = 1
    _empty_style.border_width_top = 1
    _empty_style.border_width_right = 1
    _empty_style.border_width_bottom = 1
    _empty_style.border_color = Color(0.8, 0.87, 0.9, 0.92)
    _empty_style.corner_radius_top_left = 18
    _empty_style.corner_radius_top_right = 18
    _empty_style.corner_radius_bottom_left = 18
    _empty_style.corner_radius_bottom_right = 18

func setup(slot_index: int, slot_id: String, meta: Dictionary) -> void:
    current_slot_id = slot_id
    var archive_name := "档案 %d" % slot_index

    if meta.is_empty() or bool(meta.get("is_empty", false)):
        is_empty = true
        id_label.text = archive_name
        summary_label.text = "空槽位"
        info_label.text = "点击新建一份独立档案"
        time_label.text = ""
        add_theme_stylebox_override("panel", _empty_style)
        id_label.add_theme_color_override("font_color", Color(0.46, 0.55, 0.59, 1))
        summary_label.add_theme_color_override("font_color", Color(0.5, 0.59, 0.63, 1))
        info_label.add_theme_color_override("font_color", Color(0.56, 0.63, 0.67, 1))
        time_label.add_theme_color_override("font_color", Color(0.62, 0.68, 0.72, 1))
        if delete_button:
            delete_button.hide()
    else:
        is_empty = false
        id_label.text = archive_name
        summary_label.text = str(meta.get("display_line_1", "与 Luna 相处第1天"))
        info_label.text = str(meta.get("display_line_2", "未命名 & Luna  当前情感阶段：相识"))
        time_label.text = str(meta.get("display_line_3", "最后游玩：暂无"))
        add_theme_stylebox_override("panel", _filled_style)
        id_label.add_theme_color_override("font_color", Color(0.14, 0.15, 0.16, 1))
        summary_label.add_theme_color_override("font_color", Color(0.16, 0.23, 0.25, 1))
        info_label.add_theme_color_override("font_color", Color(0.31, 0.39, 0.42, 1))
        time_label.add_theme_color_override("font_color", Color(0.45, 0.53, 0.56, 1))
        if delete_button:
            delete_button.show()

func _on_card_gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        if delete_button and delete_button.visible and delete_button.get_global_rect().has_point(get_global_mouse_position()):
            return
        slot_selected.emit(current_slot_id, is_empty)

func _on_delete_pressed() -> void:
    if not is_empty:
        delete_requested.emit(current_slot_id)
