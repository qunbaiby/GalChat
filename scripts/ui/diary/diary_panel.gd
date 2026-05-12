extends Control

@onready var color_rect: ColorRect = $ColorRect
@onready var diary_book: PanelContainer = $CenterContainer/DiaryBook

@onready var close_btn: Button = $CenterContainer/DiaryBook/Margin/HBox/RightPage/TopBar/CloseButton
@onready var prev_btn: Button = $CenterContainer/DiaryBook/Margin/HBox/LeftPage/BottomBar/PrevButton
@onready var next_btn: Button = $CenterContainer/DiaryBook/Margin/HBox/RightPage/BottomBar/NextButton

@onready var date_label: Label = $CenterContainer/DiaryBook/Margin/HBox/RightPage/TopBar/DateLabel
@onready var weather_label: Label = $CenterContainer/DiaryBook/Margin/HBox/RightPage/TopBar/WeatherLabel
@onready var content_text: RichTextLabel = $CenterContainer/DiaryBook/Margin/HBox/RightPage/ScrollContainer/ContentText
@onready var page_num_label: Label = $CenterContainer/DiaryBook/Margin/HBox/RightPage/BottomBar/PageNumLabel

@onready var polaroid_1: PanelContainer = $CenterContainer/DiaryBook/Margin/HBox/LeftPage/PhotoContainer/Polaroid1
@onready var img_1: TextureRect = $CenterContainer/DiaryBook/Margin/HBox/LeftPage/PhotoContainer/Polaroid1/Margin/Image
@onready var polaroid_2: PanelContainer = $CenterContainer/DiaryBook/Margin/HBox/LeftPage/PhotoContainer/Polaroid2
@onready var img_2: TextureRect = $CenterContainer/DiaryBook/Margin/HBox/LeftPage/PhotoContainer/Polaroid2/Margin/Image
@onready var polaroid_3: PanelContainer = $CenterContainer/DiaryBook/Margin/HBox/LeftPage/PhotoContainer/Polaroid3
@onready var img_3: TextureRect = $CenterContainer/DiaryBook/Margin/HBox/LeftPage/PhotoContainer/Polaroid3/Margin/Image

@onready var image_viewer: ColorRect = $ImageViewer
@onready var full_image: TextureRect = $ImageViewer/FullImage
@onready var close_viewer_btn: Button = $ImageViewer/CloseViewerBtn

var diaries: Array = []
var current_page_index: int = 0

func _ready() -> void:
    close_btn.pressed.connect(_on_close_pressed)
    prev_btn.pressed.connect(_on_prev_pressed)
    next_btn.pressed.connect(_on_next_pressed)
    
    close_viewer_btn.pressed.connect(_close_image_viewer)
    
    polaroid_1.gui_input.connect(_on_polaroid_clicked.bind(img_1))
    polaroid_2.gui_input.connect(_on_polaroid_clicked.bind(img_2))
    polaroid_3.gui_input.connect(_on_polaroid_clicked.bind(img_3))
    
    # 启用鼠标事件接收
    polaroid_1.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    polaroid_2.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    polaroid_3.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    
    hide()

func show_diary() -> void:
    _load_diaries()
    if diaries.size() > 0:
        current_page_index = diaries.size() - 1
        _update_page()
    else:
        date_label.text = "暂无记录"
        weather_label.text = ""
        content_text.text = "    今天没有写日记哦..."
        page_num_label.text = "0 / 0"
        prev_btn.disabled = true
        next_btn.disabled = true
        
    show()
    modulate.a = 0.0
    diary_book.scale = Vector2(0.9, 0.9)
    var tween = create_tween().set_parallel(true)
    tween.tween_property(self, "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
    tween.tween_property(diary_book, "scale", Vector2(1.0, 1.0), 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func hide_diary() -> void:
    var tween = create_tween().set_parallel(true)
    tween.tween_property(self, "modulate:a", 0.0, 0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
    tween.tween_property(diary_book, "scale", Vector2(0.9, 0.9), 0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
    tween.chain().tween_callback(hide)

func _load_diaries() -> void:
    var profile = GameDataManager.profile
    if profile and profile.has_method("get_diaries"):
        diaries = profile.get_diaries()
    else:
        # Fallback testing data or if method doesn't exist
        if profile and profile.data.has("diaries"):
            diaries = profile.data.diaries
        else:
            diaries = []

func _update_page() -> void:
    if diaries.size() == 0:
        return
        
    var entry = diaries[current_page_index]
    date_label.text = entry.get("date", "未知日期")
    weather_label.text = entry.get("weather", "晴")
    
    # Handle text indentation if not already present
    var content = entry.get("content", "")
    content_text.text = content
    
    # Reset all photos
    polaroid_1.hide()
    polaroid_2.hide()
    polaroid_3.hide()
    
    # Handle image display
    var image_urls = []
    
    # 如果日记中有多个图片 (数组格式)
    if entry.has("images") and typeof(entry.get("images")) == TYPE_ARRAY:
        image_urls = entry.get("images")
    # 兼容老的单张图片格式
    elif entry.has("image_url") and entry.get("image_url") != "":
        image_urls.append(entry.get("image_url"))
        
    var polaroids = [polaroid_1, polaroid_2, polaroid_3]
    var images = [img_1, img_2, img_3]
    
    var count = min(image_urls.size(), 3)
    if count == 0:
        image_urls.append("")
        count = 1
        
    _apply_layout(count)
    
    for i in range(count):
        var img_url = image_urls[i]
        if img_url != "" and FileAccess.file_exists(img_url):
            var image = Image.load_from_file(img_url)
            if image:
                var tex = ImageTexture.create_from_image(image)
                images[i].texture = tex
        else:
            images[i].texture = preload("res://icon.svg")
        polaroids[i].show()
    
    page_num_label.text = "%d / %d" % [current_page_index + 1, diaries.size()]
    
    prev_btn.disabled = current_page_index == 0
    next_btn.disabled = current_page_index == diaries.size() - 1

func _on_close_pressed() -> void:
    hide_diary()

func _on_prev_pressed() -> void:
    if current_page_index > 0:
        current_page_index -= 1
        _update_page()

func _on_next_pressed() -> void:
    if current_page_index < diaries.size() - 1:
        current_page_index += 1
        _update_page()

func _apply_layout(count: int) -> void:
    # count 可以是 1, 2, 3
    # 根据数量，重新排列三张图的大小、位置、角度，并加入一点点随机性以保证每次打开都有翻相册的感觉
    var rand_offset = randf_range(-0.02, 0.02)
    
    if count == 1:
        # 单张图：居中放大，轻微倾斜
        polaroid_1.position = Vector2(50, 60)
        polaroid_1.size = Vector2(320, 380)
        polaroid_1.rotation = -0.05 + rand_offset
        
    elif count == 2:
        # 两张图：上下交错摆放
        polaroid_1.position = Vector2(40, 30)
        polaroid_1.size = Vector2(240, 260)
        polaroid_1.rotation = -0.1 + rand_offset
        
        polaroid_2.position = Vector2(140, 230)
        polaroid_2.size = Vector2(250, 270)
        polaroid_2.rotation = 0.08 + rand_offset
        
    elif count == 3:
        # 三张图：原定的左上、右上、左下交错布局
        polaroid_1.position = Vector2(10, 10)
        polaroid_1.size = Vector2(200, 190)
        polaroid_1.rotation = -0.15 + rand_offset
        
        polaroid_2.position = Vector2(190, 80)
        polaroid_2.size = Vector2(200, 190)
        polaroid_2.rotation = 0.08 + rand_offset
        
        polaroid_3.position = Vector2(50, 230)
        polaroid_3.size = Vector2(200, 190)
        polaroid_3.rotation = -0.05 + rand_offset

func _on_polaroid_clicked(event: InputEvent, img_node: TextureRect) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        _open_image_viewer(img_node.texture)

func _open_image_viewer(tex: Texture2D) -> void:
    if tex:
        full_image.texture = tex
        image_viewer.show()
        image_viewer.modulate.a = 0.0
        full_image.scale = Vector2(0.9, 0.9)
        var tween = create_tween().set_parallel(true)
        tween.tween_property(image_viewer, "modulate:a", 1.0, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
        tween.tween_property(full_image, "scale", Vector2(1.0, 1.0), 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _close_image_viewer() -> void:
    var tween = create_tween().set_parallel(true)
    tween.tween_property(image_viewer, "modulate:a", 0.0, 0.15).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
    tween.tween_property(full_image, "scale", Vector2(0.9, 0.9), 0.15).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
    tween.chain().tween_callback(image_viewer.hide)
