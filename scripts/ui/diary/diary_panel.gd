extends Control

@onready var color_rect: ColorRect = $ColorRect
@onready var diary_book: PanelContainer = $CenterContainer/DiaryBook

@onready var close_btn: Button = $CenterContainer/DiaryBook/OverlayLayer/CloseButton
@onready var prev_btn: Button = $CenterContainer/DiaryBook/OverlayLayer/PageTabs/PrevButton
@onready var next_btn: Button = $CenterContainer/DiaryBook/OverlayLayer/PageTabs/NextButton

@onready var date_label: Label = $CenterContainer/DiaryBook/Margin/HBox/RightPage/TopBar/DateLabel
@onready var weekday_label: Label = $CenterContainer/DiaryBook/Margin/HBox/RightPage/TopBar/WeekdayLabel
@onready var weather_label: Label = $CenterContainer/DiaryBook/Margin/HBox/RightPage/TopBar/WeatherBadge/WeatherLabel
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
var _diary_book_base_position: Vector2 = Vector2.ZERO
var _diary_tween: Tween = null

const DIARY_ENTER_OFFSET_X: float = -72.0
const DIARY_ENTER_DURATION: float = 0.24
const DIARY_EXIT_DURATION: float = 0.2
const FALLBACK_IMAGE: Texture2D = preload("res://icon.svg")
const WEEKDAY_LABELS: Array[String] = ["星期日", "星期一", "星期二", "星期三", "星期四", "星期五", "星期六"]

func _ready() -> void:
    if close_btn != null:
        close_btn.pressed.connect(_on_close_pressed)
    prev_btn.pressed.connect(_on_prev_pressed)
    next_btn.pressed.connect(_on_next_pressed)
    
    close_viewer_btn.pressed.connect(_close_image_viewer)
    
    polaroid_1.gui_input.connect(_on_polaroid_clicked.bind(img_1))
    polaroid_2.gui_input.connect(_on_polaroid_clicked.bind(img_2))
    polaroid_3.gui_input.connect(_on_polaroid_clicked.bind(img_3))
    
    polaroid_1.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    polaroid_2.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    polaroid_3.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    
    if color_rect:
        color_rect.hide()
    _diary_book_base_position = diary_book.position
    hide()

func show_diary() -> void:
    _load_diaries()
    if diaries.size() > 0:
        current_page_index = diaries.size() - 1
        _update_page()
    else:
        date_label.text = "暂无记录"
        weekday_label.text = ""
        weather_label.text = "晴"
        content_text.text = "    今天没有写日记哦..."
        page_num_label.text = "0 / 0"
        prev_btn.disabled = true
        next_btn.disabled = true
    
    _stop_diary_tween()
    show()
    modulate.a = 1.0
    diary_book.position = _diary_book_base_position + Vector2(DIARY_ENTER_OFFSET_X, 0.0)
    diary_book.modulate.a = 0.0
    diary_book.scale = Vector2.ONE
    _diary_tween = create_tween().set_parallel(true)
    _diary_tween.tween_property(diary_book, "position", _diary_book_base_position, DIARY_ENTER_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
    _diary_tween.tween_property(diary_book, "modulate:a", 1.0, DIARY_ENTER_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)

func hide_diary() -> void:
    if not visible:
        return
    _stop_diary_tween()
    _diary_tween = create_tween().set_parallel(true)
    _diary_tween.tween_property(diary_book, "position", _diary_book_base_position, DIARY_EXIT_DURATION).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUART)
    _diary_tween.tween_property(diary_book, "modulate:a", 0.0, DIARY_EXIT_DURATION).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUART)
    _diary_tween.chain().tween_callback(_finish_hide_diary)

func _stop_diary_tween() -> void:
    if _diary_tween != null and _diary_tween.is_running():
        _diary_tween.kill()
    _diary_tween = null

func _finish_hide_diary() -> void:
    diary_book.position = _diary_book_base_position
    diary_book.modulate.a = 1.0
    hide()

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
    var raw_date := str(entry.get("date", "未知日期"))
    date_label.text = _format_diary_date(raw_date)
    weekday_label.text = _get_weekday_text(raw_date)
    weather_label.text = str(entry.get("weather", "晴")).strip_edges()
    
    # Handle text indentation if not already present
    var content = entry.get("content", "")
    content_text.text = content
    
    # Reset all photos
    var images = [img_1, img_2, img_3]
    for image_node in images:
        image_node.texture = null
    polaroid_1.hide()
    polaroid_2.hide()
    polaroid_3.hide()
    
    # Handle image display
    var image_urls := _collect_diary_images(entry)
        
    var polaroids = [polaroid_1, polaroid_2, polaroid_3]
    
    var count = min(image_urls.size(), 3)
    if count == 0:
        image_urls.append("")
        count = 1
        
    _apply_layout(count)
    
    for i in range(count):
        var img_url = image_urls[i]
        images[i].texture = _load_diary_texture(img_url)
        polaroids[i].show()
    
    page_num_label.text = "%d / %d" % [current_page_index + 1, diaries.size()]
    
    prev_btn.disabled = current_page_index == 0
    next_btn.disabled = current_page_index == diaries.size() - 1
    _sync_page_tab_state()

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
    # 根据数量重新排列照片，尽量贴近参考图里“主图 + 补充留影”的摆放关系。
    var rand_offset = randf_range(-0.02, 0.02)
    
    if count == 1:
        polaroid_1.position = Vector2(34, 16)
        polaroid_1.size = Vector2(394, 470)
        polaroid_1.rotation = -0.06 + rand_offset
        
    elif count == 2:
        polaroid_1.position = Vector2(26, 18)
        polaroid_1.size = Vector2(338, 388)
        polaroid_1.rotation = -0.11 + rand_offset
        
        polaroid_2.position = Vector2(188, 304)
        polaroid_2.size = Vector2(220, 210)
        polaroid_2.rotation = 0.09 + rand_offset
        
    elif count == 3:
        polaroid_1.position = Vector2(18, 16)
        polaroid_1.size = Vector2(232, 214)
        polaroid_1.rotation = -0.13 + rand_offset
        
        polaroid_2.position = Vector2(206, 102)
        polaroid_2.size = Vector2(226, 214)
        polaroid_2.rotation = 0.1 + rand_offset
        
        polaroid_3.position = Vector2(64, 282)
        polaroid_3.size = Vector2(210, 198)
        polaroid_3.rotation = -0.04 + rand_offset

func _collect_diary_images(entry: Dictionary) -> Array[String]:
    var image_urls: Array[String] = []
    if entry.has("images") and entry.get("images") is Array:
        for image_path in entry.get("images", []):
            var normalized := str(image_path).strip_edges()
            if normalized != "" and not image_urls.has(normalized):
                image_urls.append(normalized)
    var legacy_image := str(entry.get("image_url", "")).strip_edges()
    if legacy_image != "" and not image_urls.has(legacy_image):
        image_urls.append(legacy_image)
    return image_urls

func _load_diary_texture(image_path: String) -> Texture2D:
    var normalized := image_path.strip_edges()
    if normalized == "":
        return FALLBACK_IMAGE
    if normalized.begins_with("res://"):
        var resource_tex := load(normalized) as Texture2D
        if resource_tex != null:
            return resource_tex
    var actual_path := normalized
    if normalized.begins_with("user://"):
        actual_path = ProjectSettings.globalize_path(normalized)
    if not FileAccess.file_exists(actual_path):
        return FALLBACK_IMAGE
    var image := Image.load_from_file(actual_path)
    if image == null or image.is_empty():
        return FALLBACK_IMAGE
    return ImageTexture.create_from_image(image)

func _sync_page_tab_state() -> void:
    prev_btn.modulate = Color(1, 1, 1, 0.45) if prev_btn.disabled else Color(1, 1, 1, 1)
    next_btn.modulate = Color(1, 1, 1, 0.45) if next_btn.disabled else Color(1, 1, 1, 1)

func _format_diary_date(raw_date: String) -> String:
    var parts := _parse_date_parts(raw_date)
    if parts.is_empty():
        return raw_date
    return "%d年%d月%d日" % [parts[0], parts[1], parts[2]]

func _get_weekday_text(raw_date: String) -> String:
    var parts := _parse_date_parts(raw_date)
    if parts.is_empty():
        return ""
    var datetime := {
        "year": parts[0],
        "month": parts[1],
        "day": parts[2],
        "hour": 12,
        "minute": 0,
        "second": 0
    }
    var weekday_index := int(Time.get_datetime_dict_from_unix_time(Time.get_unix_time_from_datetime_dict(datetime)).weekday)
    if weekday_index < 0 or weekday_index >= WEEKDAY_LABELS.size():
        return ""
    return WEEKDAY_LABELS[weekday_index]

func _parse_date_parts(raw_date: String) -> Array[int]:
    var regex := RegEx.new()
    var compile_error := regex.compile("(\\d{4})\\D+(\\d{1,2})\\D+(\\d{1,2})")
    if compile_error != OK:
        return []
    var result := regex.search(raw_date)
    if result == null:
        return []
    return [
        int(result.get_string(1)),
        int(result.get_string(2)),
        int(result.get_string(3))
    ]

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
