extends Button

signal selected(char_id: String)

var char_id: String = ""
var _pending_info: Dictionary = {}
var _normal_style: StyleBox = null
var _selected_style: StyleBoxFlat = null
var _selected: bool = false

@onready var avatar_rect: TextureRect = $Margin/HBox/AvatarMask/AvatarRect
@onready var name_label: Label = $Margin/HBox/NameLabel

func _ready() -> void:
    pressed.connect(_on_pressed)
    _cache_styles()
    if not _pending_info.is_empty():
        _apply_info(_pending_info)
    _apply_selected_style()

func setup(info: Dictionary) -> void:
    _pending_info = info.duplicate()
    if is_node_ready():
        _apply_info(_pending_info)

func _apply_info(info: Dictionary) -> void:
    char_id = str(info.get("id", ""))
    name_label.text = str(info.get("name", ""))

    var avatar_path := str(info.get("avatar", ""))
    if avatar_path != "" and ResourceLoader.exists(avatar_path):
        avatar_rect.texture = load(avatar_path)
    else:
        avatar_rect.texture = preload("res://icon.svg")

func set_selected(is_selected: bool) -> void:
    _selected = is_selected
    if is_node_ready():
        _apply_selected_style()

func _cache_styles() -> void:
    var base_style := get_theme_stylebox("normal")
    if base_style:
        _normal_style = base_style.duplicate()

    _selected_style = StyleBoxFlat.new()
    _selected_style.bg_color = Color(0.90, 0.97, 0.95, 1.0)
    _selected_style.border_width_left = 1
    _selected_style.border_width_top = 1
    _selected_style.border_width_right = 1
    _selected_style.border_width_bottom = 1
    _selected_style.border_color = Color(0.57, 0.82, 0.76, 1.0)
    _selected_style.corner_radius_top_left = 8
    _selected_style.corner_radius_top_right = 8
    _selected_style.corner_radius_bottom_right = 8
    _selected_style.corner_radius_bottom_left = 8
    _selected_style.shadow_color = Color(0.57, 0.82, 0.76, 0.14)
    _selected_style.shadow_size = 8
    _selected_style.shadow_offset = Vector2(0, 3)

func _apply_selected_style() -> void:
    var style_to_use: StyleBox = _selected_style if _selected else _normal_style
    if style_to_use == null:
        return
    add_theme_stylebox_override("normal", style_to_use)
    add_theme_stylebox_override("hover", style_to_use)
    add_theme_stylebox_override("pressed", style_to_use)

func _on_pressed() -> void:
    selected.emit(char_id)
