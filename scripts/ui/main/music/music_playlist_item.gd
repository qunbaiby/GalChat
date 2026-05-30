extends PanelContainer

signal item_clicked(index: int)
signal star_toggled(index: int, is_starred: bool)

var _index: int = 0
var _is_playing: bool = false
var _is_hovered: bool = false

var style_normal: StyleBoxFlat
var style_hover: StyleBoxFlat
var style_playing: StyleBoxFlat

func _ready() -> void:
    _ensure_styles()

    gui_input.connect(_on_gui_input)
    mouse_entered.connect(_on_mouse_entered)
    mouse_exited.connect(_on_mouse_exited)
    
    get_star_btn().pressed.connect(_on_star_pressed)
    
    _update_style()

func get_title_label() -> Label:
    return $HBox/VBox/TitleLabel

func get_artist_label() -> Label:
    return $HBox/VBox/ArtistLabel

func get_play_icon() -> Label:
    return $HBox/PlayIcon

func get_star_btn() -> Button:
    return $HBox/StarBtn

func _ensure_styles() -> void:
    if style_normal != null and style_hover != null and style_playing != null:
        return

    style_normal = StyleBoxFlat.new()
    style_normal.bg_color = Color(0.15, 0.12, 0.2, 0.9)
    style_normal.corner_radius_top_left = 6
    style_normal.corner_radius_top_right = 6
    style_normal.corner_radius_bottom_right = 6
    style_normal.corner_radius_bottom_left = 6

    style_hover = StyleBoxFlat.new()
    style_hover.bg_color = Color(0.2, 0.15, 0.25, 0.9)
    style_hover.corner_radius_top_left = 6
    style_hover.corner_radius_top_right = 6
    style_hover.corner_radius_bottom_right = 6
    style_hover.corner_radius_bottom_left = 6

    style_playing = StyleBoxFlat.new()
    style_playing.bg_color = Color(0.25, 0.15, 0.2, 0.9)
    style_playing.border_width_left = 2
    style_playing.border_width_top = 2
    style_playing.border_width_right = 2
    style_playing.border_width_bottom = 2
    style_playing.border_color = Color(0.9, 0.4, 0.5, 1)
    style_playing.corner_radius_top_left = 6
    style_playing.corner_radius_top_right = 6
    style_playing.corner_radius_bottom_right = 6
    style_playing.corner_radius_bottom_left = 6
    style_playing.shadow_color = Color(0.9, 0.4, 0.5, 0.3)
    style_playing.shadow_size = 8

func setup(index: int, title: String, artist: String, is_playing: bool = false, is_favorite: bool = false) -> void:
    _index = index
    get_title_label().text = title
    get_artist_label().text = artist
    set_playing(is_playing)
    
    var star_btn := get_star_btn()
    if is_favorite:
        star_btn.text = "★"
        star_btn.add_theme_color_override("font_color", Color(1, 0.8, 0.2, 1))
    else:
        star_btn.text = "☆"
        star_btn.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))

func set_playing(playing: bool) -> void:
    _is_playing = playing
    _ensure_styles()
    var play_icon := get_play_icon()
    var title_label := get_title_label()
    if playing:
        play_icon.text = "ılı."
        play_icon.add_theme_color_override("font_color", Color(0.9, 0.4, 0.5, 1))
        title_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
    else:
        play_icon.text = "▶"
        play_icon.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1))
        title_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1))
    
    _update_style()

func _update_style() -> void:
    _ensure_styles()
    if _is_playing:
        add_theme_stylebox_override("panel", style_playing)
    elif _is_hovered:
        add_theme_stylebox_override("panel", style_hover)
    else:
        add_theme_stylebox_override("panel", style_normal)

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
    var star_btn := get_star_btn()
    var is_starred = false
    if star_btn.text == "☆":
        star_btn.text = "★"
        star_btn.add_theme_color_override("font_color", Color(1, 0.8, 0.2, 1))
        is_starred = true
    else:
        star_btn.text = "☆"
        star_btn.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))
        is_starred = false
        
    star_toggled.emit(_index, is_starred)
