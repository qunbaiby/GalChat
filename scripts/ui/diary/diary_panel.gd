extends Control

@onready var color_rect: ColorRect = $ColorRect
@onready var diary_book: PanelContainer = $CenterContainer/DiaryBook

@onready var close_btn: Button = $CenterContainer/DiaryBook/Margin/HBox/RightPage/TopBar/CloseButton
@onready var prev_btn: Button = $CenterContainer/DiaryBook/Margin/HBox/LeftPage/BottomBar/PrevButton
@onready var next_btn: Button = $CenterContainer/DiaryBook/Margin/HBox/RightPage/BottomBar/NextButton

@onready var date_label: Label = $CenterContainer/DiaryBook/Margin/HBox/RightPage/TopBar/DateLabel
@onready var weather_label: Label = $CenterContainer/DiaryBook/Margin/HBox/RightPage/TopBar/WeatherLabel
@onready var content_text: RichTextLabel = $CenterContainer/DiaryBook/Margin/HBox/RightPage/ScrollContainer/ContentText
@onready var photo_rect: TextureRect = $CenterContainer/DiaryBook/Margin/HBox/LeftPage/PhotoContainer/PhotoRect
@onready var page_num_label: Label = $CenterContainer/DiaryBook/Margin/HBox/RightPage/BottomBar/PageNumLabel

var diaries: Array = []
var current_page_index: int = 0

func _ready() -> void:
    close_btn.pressed.connect(_on_close_pressed)
    prev_btn.pressed.connect(_on_prev_pressed)
    next_btn.pressed.connect(_on_next_pressed)
    
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
