extends Panel

@onready var back_btn: Button = $VBox/TopBar/BackBtn
@onready var grid: GridContainer = $VBox/Scroll/Grid
@onready var empty_label: Label = $VBox/EmptyLabel

signal photo_picked(path: String)

@onready var fullscreen_viewer: Control = $FullscreenViewer
@onready var full_image: TextureRect = $FullscreenViewer/FullImage
@onready var close_viewer_btn: Button = $FullscreenViewer/CloseViewerBtn
@onready var send_btn: Button = $FullscreenViewer/SendBtn

var _photo_paths: Array = []
var _is_picker_mode: bool = false
var _current_viewing_path: String = ""

func _ready() -> void:
    back_btn.pressed.connect(_on_back_pressed)
    close_viewer_btn.pressed.connect(_on_close_viewer_pressed)
    send_btn.pressed.connect(_on_send_pressed)

func set_picker_mode(is_picker: bool) -> void:
    _is_picker_mode = is_picker

func show_panel() -> void:
    show()
    _load_photos()

func hide_panel() -> void:
    hide()

func _on_back_pressed() -> void:
    hide_panel()

func _load_photos() -> void:
    # Clear existing
    for child in grid.get_children():
        child.queue_free()
        
    _photo_paths.clear()
    
    var dir_path = "user://saves/photos"
    if not DirAccess.dir_exists_absolute(dir_path):
        DirAccess.make_dir_recursive_absolute(dir_path)
        
    var dir = DirAccess.open(dir_path)
    if dir:
        dir.list_dir_begin()
        var file_name = dir.get_next()
        while file_name != "":
            if not dir.current_is_dir() and file_name.ends_with(".png"):
                _photo_paths.append(dir_path + "/" + file_name)
            file_name = dir.get_next()
            
    _photo_paths.sort() # Sort by name (which includes time)
    _photo_paths.reverse() # Newest first
    
    if _photo_paths.is_empty():
        empty_label.show()
    else:
        empty_label.hide()
        _render_photos()

func _render_photos() -> void:
    var thumb_size = 110 # 3 columns in ~360 width phone screen
    
    for path in _photo_paths:
        var img = Image.load_from_file(path)
        if img:
            var tex = ImageTexture.create_from_image(img)
            
            var panel = PanelContainer.new()
            panel.custom_minimum_size = Vector2(thumb_size, thumb_size)
            
            var style = StyleBoxFlat.new()
            style.bg_color = Color(0.2, 0.2, 0.2)
            style.corner_radius_top_left = 8
            style.corner_radius_top_right = 8
            style.corner_radius_bottom_left = 8
            style.corner_radius_bottom_right = 8
            panel.add_theme_stylebox_override("panel", style)
            panel.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
            
            var rect = TextureRect.new()
            rect.texture = tex
            rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
            rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
            
            panel.add_child(rect)
            
            # 添加隐形的按钮用于接收点击事件
            var btn = Button.new()
            btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
            btn.flat = true
            # 传递纹理和路径给查看器
            btn.pressed.connect(_on_photo_clicked.bind(tex, path))
            panel.add_child(btn)
            
            grid.add_child(panel)

func _on_photo_clicked(tex: Texture2D, path: String = "") -> void:
    full_image.texture = tex
    _current_viewing_path = path
    fullscreen_viewer.show()
    
    if _is_picker_mode and path != "":
        send_btn.show()
    else:
        send_btn.hide()
        
    # 给个简单的弹出动画
    fullscreen_viewer.modulate.a = 0.0
    var tween = create_tween()
    tween.tween_property(fullscreen_viewer, "modulate:a", 1.0, 0.2)

func _on_close_viewer_pressed() -> void:
    var tween = create_tween()
    tween.tween_property(fullscreen_viewer, "modulate:a", 0.0, 0.2)
    tween.tween_callback(func():
        fullscreen_viewer.hide()
        full_image.texture = null
        send_btn.hide()
        _current_viewing_path = ""
    )

func _on_send_pressed() -> void:
    if _current_viewing_path != "":
        photo_picked.emit(_current_viewing_path)
        _on_close_viewer_pressed()
