extends PanelContainer

signal item_clicked(index: int)
signal star_toggled(index: int, is_starred: bool)

var _index: int = 0
var _is_playing: bool = false
var _is_hovered: bool = false

var _style_normal: StyleBoxFlat
var _style_hover: StyleBoxFlat
var _style_playing: StyleBoxFlat

func _ready() -> void:
    gui_input.connect(_on_gui_input)
    mouse_entered.connect(_on_mouse_entered)
    mouse_exited.connect(_on_mouse_exited)
    get_star_btn().pressed.connect(_on_star_pressed)
    _ensure_styles()
    _update_style()

func setup(index: int, title: String, artist: String, is_playing: bool = false, is_favorite: bool = false) -> void:
    _index = index
    get_title_label().text = title
    get_artist_label().text = artist
    _set_star_state(is_favorite)
    set_playing(is_playing)

func set_playing(playing: bool) -> void:
    _is_playing = playing
    var play_icon := get_play_icon()
    if playing:
        play_icon.text = "||"
        play_icon.add_theme_color_override("font_color", Color(0.12, 0.15, 0.19, 1))
        get_title_label().add_theme_color_override("font_color", Color(0.13, 0.17, 0.22, 1))
    else:
        play_icon.text = ">"
        play_icon.add_theme_color_override("font_color", Color(0.44, 0.49, 0.58, 1))
        get_title_label().add_theme_color_override("font_color", Color(0.22, 0.27, 0.34, 1))
    _update_style()

func get_title_label() -> Label:
    return $HBox/TextVBox/TitleLabel

func get_artist_label() -> Label:
    return $HBox/TextVBox/ArtistLabel

func get_play_icon() -> Label:
    return $HBox/PlayIcon

func get_star_btn() -> Button:
    return $HBox/StarBtn

func _ensure_styles() -> void:
    if _style_normal != null:
        return

    _style_normal = StyleBoxFlat.new()
    _style_normal.bg_color = Color(0.98, 0.985, 0.99, 0.94)
    _style_normal.corner_radius_top_left = 18
    _style_normal.corner_radius_top_right = 18
    _style_normal.corner_radius_bottom_right = 18
    _style_normal.corner_radius_bottom_left = 18
    _style_normal.shadow_color = Color(0.3, 0.37, 0.48, 0.08)
    _style_normal.shadow_size = 10
    _style_normal.shadow_offset = Vector2(0, 4)

    _style_hover = _style_normal.duplicate()
    _style_hover.bg_color = Color(0.93, 0.97, 0.99, 0.98)
    _style_hover.border_width_left = 1
    _style_hover.border_width_top = 1
    _style_hover.border_width_right = 1
    _style_hover.border_width_bottom = 1
    _style_hover.border_color = Color(0.72, 0.82, 0.9, 0.9)

    _style_playing = _style_normal.duplicate()
    _style_playing.bg_color = Color(0.86, 0.93, 0.91, 1)
    _style_playing.border_width_left = 1
    _style_playing.border_width_top = 1
    _style_playing.border_width_right = 1
    _style_playing.border_width_bottom = 1
    _style_playing.border_color = Color(0.47, 0.68, 0.63, 0.95)
    _style_playing.shadow_color = Color(0.47, 0.68, 0.63, 0.18)
    _style_playing.shadow_size = 14

func _update_style() -> void:
    _ensure_styles()
    if _is_playing:
        add_theme_stylebox_override("panel", _style_playing)
    elif _is_hovered:
        add_theme_stylebox_override("panel", _style_hover)
    else:
        add_theme_stylebox_override("panel", _style_normal)

func _set_star_state(is_starred: bool) -> void:
    var star_btn := get_star_btn()
    if is_starred:
        star_btn.text = "*"
        star_btn.add_theme_color_override("font_color", Color(0.95, 0.71, 0.27, 1))
    else:
        star_btn.text = "+"
        star_btn.add_theme_color_override("font_color", Color(0.54, 0.59, 0.68, 1))

func _on_mouse_entered() -> void:
    _is_hovered = true
    _update_style()

func _on_mouse_exited() -> void:
    _is_hovered = false
    _update_style()

func _on_gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        item_clicked.emit(_index)

func _on_star_pressed() -> void:
    var is_starred := get_star_btn().text != "*"
    _set_star_state(is_starred)
    star_toggled.emit(_index, is_starred)
