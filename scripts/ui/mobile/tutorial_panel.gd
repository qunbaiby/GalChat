extends Control

signal back_requested

const POPUP_MIN_SIZE: Vector2 = Vector2(1040, 660)
const TUTORIAL_DATA_PATH: String = "res://assets/data/mobile/tutorial_content.json"

@onready var background_panel: Panel = $Background
@onready var panel_root: PanelContainer = $CenterContainer/PanelRoot
@onready var back_btn: Button = $CenterContainer/PanelRoot/VBox/HeaderPanel/Margin/TopBar/BackBtn
@onready var category_title: Label = $CenterContainer/PanelRoot/VBox/BodyMargin/BodyHBox/LeftSidebar/LeftMargin/SidebarHBox/SectionVBox/CategoryTitle
@onready var category_button_vbox: VBoxContainer = $CenterContainer/PanelRoot/VBox/BodyMargin/BodyHBox/LeftSidebar/LeftMargin/SidebarHBox/IconRail/CategoryButtonVBox
@onready var lesson_list: VBoxContainer = $CenterContainer/PanelRoot/VBox/BodyMargin/BodyHBox/LeftSidebar/LeftMargin/SidebarHBox/SectionVBox/ScrollContainer/LessonList
@onready var lesson_title: Label = $CenterContainer/PanelRoot/VBox/BodyMargin/BodyHBox/RightContent/ContentVBox/LessonTitle
@onready var lesson_desc: Label = $CenterContainer/PanelRoot/VBox/BodyMargin/BodyHBox/RightContent/ContentVBox/LessonDesc
@onready var dots_label: Label = $CenterContainer/PanelRoot/VBox/BodyMargin/BodyHBox/RightContent/ContentVBox/PagerRow/DotsLabel
@onready var prev_btn: Button = $CenterContainer/PanelRoot/VBox/BodyMargin/BodyHBox/RightContent/ContentVBox/PagerRow/PrevBtn
@onready var next_btn: Button = $CenterContainer/PanelRoot/VBox/BodyMargin/BodyHBox/RightContent/ContentVBox/PagerRow/NextBtn
@onready var preview_image: TextureRect = $CenterContainer/PanelRoot/VBox/BodyMargin/BodyHBox/RightContent/PreviewPanel/PreviewMargin/PreviewStage/PreviewImage
@onready var stage_title: Label = $CenterContainer/PanelRoot/VBox/BodyMargin/BodyHBox/RightContent/PreviewPanel/PreviewMargin/PreviewStage/StageTitle
@onready var character_dots: Label = $CenterContainer/PanelRoot/VBox/BodyMargin/BodyHBox/RightContent/PreviewPanel/PreviewMargin/PreviewStage/CharacterDots
@onready var hotspot_cards: Array[PanelContainer] = [
    $CenterContainer/PanelRoot/VBox/BodyMargin/BodyHBox/RightContent/PreviewPanel/PreviewMargin/PreviewStage/HotspotCardA,
    $CenterContainer/PanelRoot/VBox/BodyMargin/BodyHBox/RightContent/PreviewPanel/PreviewMargin/PreviewStage/HotspotCardB,
    $CenterContainer/PanelRoot/VBox/BodyMargin/BodyHBox/RightContent/PreviewPanel/PreviewMargin/PreviewStage/HotspotCardC
]
@onready var cursor_hint: Label = $CenterContainer/PanelRoot/VBox/BodyMargin/BodyHBox/RightContent/PreviewPanel/PreviewMargin/PreviewStage/CursorHint
@onready var stage_hint: Label = $CenterContainer/PanelRoot/VBox/BodyMargin/BodyHBox/RightContent/PreviewPanel/PreviewMargin/PreviewStage/StageHint
@onready var hot_card_labels: Array[Label] = [
    $CenterContainer/PanelRoot/VBox/BodyMargin/BodyHBox/RightContent/PreviewPanel/PreviewMargin/PreviewStage/HotspotCardA/CardLabel,
    $CenterContainer/PanelRoot/VBox/BodyMargin/BodyHBox/RightContent/PreviewPanel/PreviewMargin/PreviewStage/HotspotCardB/CardLabel,
    $CenterContainer/PanelRoot/VBox/BodyMargin/BodyHBox/RightContent/PreviewPanel/PreviewMargin/PreviewStage/HotspotCardC/CardLabel
]

var _panel_tween: Tween = null
var _current_category_index: int = 0
var _current_lesson_index: int = 0
var _category_buttons: Array[Button] = []
var _lesson_buttons: Array[Button] = []
var _category_button_normal_style: StyleBoxFlat
var _category_button_active_style: StyleBoxFlat
var _lesson_button_normal_style: StyleBoxFlat
var _lesson_button_active_style: StyleBoxFlat
var _tutorial_categories: Array[Dictionary] = []

func _ready() -> void:
    back_btn.pressed.connect(_on_back_pressed)
    prev_btn.pressed.connect(_on_prev_pressed)
    next_btn.pressed.connect(_on_next_pressed)
    background_panel.gui_input.connect(_on_background_gui_input)
    resized.connect(_on_panel_resized)
    _prepare_styles()
    _load_tutorial_data()
    _build_category_buttons()
    _refresh_category()
    hide()

func show_panel() -> void:
    _update_popup_layout()
    show()
    background_panel.modulate.a = 0.0
    panel_root.modulate.a = 0.0
    panel_root.scale = Vector2(0.97, 0.97)
    _kill_panel_tween()
    _panel_tween = create_tween()
    _panel_tween.set_parallel(true)
    _panel_tween.tween_property(background_panel, "modulate:a", 1.0, 0.18)
    _panel_tween.tween_property(panel_root, "modulate:a", 1.0, 0.22)
    _panel_tween.tween_property(panel_root, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func hide_panel() -> void:
    _kill_panel_tween()
    _panel_tween = create_tween()
    _panel_tween.set_parallel(true)
    _panel_tween.tween_property(background_panel, "modulate:a", 0.0, 0.15)
    _panel_tween.tween_property(panel_root, "modulate:a", 0.0, 0.15)
    _panel_tween.tween_property(panel_root, "scale", Vector2(0.97, 0.97), 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
    _panel_tween.set_parallel(false)
    _panel_tween.tween_callback(hide)

func _on_back_pressed() -> void:
    hide_panel()
    back_requested.emit()

func _on_background_gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        hide_panel()

func _on_panel_resized() -> void:
    if visible:
        _update_popup_layout()

func _update_popup_layout() -> void:
    var viewport_size: Vector2 = get_viewport_rect().size
    var target_size: Vector2 = POPUP_MIN_SIZE
    target_size.x = minf(target_size.x, viewport_size.x - 72.0)
    target_size.y = minf(target_size.y, viewport_size.y - 72.0)
    panel_root.custom_minimum_size = target_size
    panel_root.size = target_size
    panel_root.pivot_offset = target_size * 0.5

func _kill_panel_tween() -> void:
    if _panel_tween != null:
        _panel_tween.kill()
        _panel_tween = null

func _prepare_styles() -> void:
    _category_button_normal_style = StyleBoxFlat.new()
    _category_button_normal_style.bg_color = Color(1, 1, 1, 0)
    _category_button_normal_style.corner_radius_top_left = 12
    _category_button_normal_style.corner_radius_top_right = 12
    _category_button_normal_style.corner_radius_bottom_left = 12
    _category_button_normal_style.corner_radius_bottom_right = 12

    _category_button_active_style = StyleBoxFlat.new()
    _category_button_active_style.bg_color = Color(0.95, 0.97, 0.99, 1)
    _category_button_active_style.border_width_left = 2
    _category_button_active_style.border_color = Color(0.98, 0.74, 0.34, 0.95)
    _category_button_active_style.corner_radius_top_left = 12
    _category_button_active_style.corner_radius_top_right = 12
    _category_button_active_style.corner_radius_bottom_left = 12
    _category_button_active_style.corner_radius_bottom_right = 12

    _lesson_button_normal_style = StyleBoxFlat.new()
    _lesson_button_normal_style.bg_color = Color(0.965, 0.972, 0.978, 0.96)
    _lesson_button_normal_style.border_width_left = 1
    _lesson_button_normal_style.border_width_top = 1
    _lesson_button_normal_style.border_width_right = 1
    _lesson_button_normal_style.border_width_bottom = 1
    _lesson_button_normal_style.border_color = Color(0.89, 0.91, 0.94, 0.96)
    _lesson_button_normal_style.corner_radius_top_left = 12
    _lesson_button_normal_style.corner_radius_top_right = 12
    _lesson_button_normal_style.corner_radius_bottom_left = 12
    _lesson_button_normal_style.corner_radius_bottom_right = 12

    _lesson_button_active_style = StyleBoxFlat.new()
    _lesson_button_active_style.bg_color = Color(1, 1, 1, 1)
    _lesson_button_active_style.border_width_left = 3
    _lesson_button_active_style.border_width_top = 1
    _lesson_button_active_style.border_width_right = 1
    _lesson_button_active_style.border_width_bottom = 1
    _lesson_button_active_style.border_color = Color(0.97, 0.74, 0.36, 0.98)
    _lesson_button_active_style.corner_radius_top_left = 12
    _lesson_button_active_style.corner_radius_top_right = 12
    _lesson_button_active_style.corner_radius_bottom_left = 12
    _lesson_button_active_style.corner_radius_bottom_right = 12

func _load_tutorial_data() -> void:
    _tutorial_categories.clear()

    var file: FileAccess = FileAccess.open(TUTORIAL_DATA_PATH, FileAccess.READ)
    if file == null:
        push_warning("教学面板配置不存在：%s" % TUTORIAL_DATA_PATH)
        return

    var json := JSON.new()
    var parse_result: int = json.parse(file.get_as_text())
    if parse_result != OK:
        push_warning("教学面板配置解析失败：%s" % TUTORIAL_DATA_PATH)
        return

    var root_data = json.data
    var raw_categories: Array = []
    if root_data is Dictionary:
        raw_categories = root_data.get("categories", [])
    elif root_data is Array:
        raw_categories = root_data

    if not (raw_categories is Array):
        push_warning("教学面板配置格式不正确：%s" % TUTORIAL_DATA_PATH)
        return

    for category_variant in raw_categories:
        if not (category_variant is Dictionary):
            continue

        var category_dict: Dictionary = category_variant
        var normalized_category: Dictionary = {
            "id": str(category_dict.get("id", "")),
            "label": str(category_dict.get("label", "教学")),
            "icon": str(category_dict.get("icon", "教")),
            "lessons": []
        }

        var raw_lessons = category_dict.get("lessons", [])
        if raw_lessons is Array:
            for lesson_variant in raw_lessons:
                if not (lesson_variant is Dictionary):
                    continue
                var lesson_dict: Dictionary = lesson_variant
                var normalized_lesson: Dictionary = {
                    "title": str(lesson_dict.get("title", "未命名")),
                    "desc": str(lesson_dict.get("desc", "暂无说明。")),
                    "stage_hint": str(lesson_dict.get("stage_hint", "选择与当前位置相连的地点后，即可前往下一处区域。")),
                    "image_path": str(lesson_dict.get("image_path", "")),
                    "cards": []
                }

                var raw_cards = lesson_dict.get("cards", [])
                if raw_cards is Array:
                    for card_variant in raw_cards:
                        normalized_lesson["cards"].append(str(card_variant))

                normalized_category["lessons"].append(normalized_lesson)

        _tutorial_categories.append(normalized_category)

func _build_category_buttons() -> void:
    for child in category_button_vbox.get_children():
        child.queue_free()
    _category_buttons.clear()

    for i in range(_tutorial_categories.size()):
        var category: Dictionary = _tutorial_categories[i]
        var button := Button.new()
        button.custom_minimum_size = Vector2(42, 56)
        button.text = str(category.get("icon", "教"))
        button.flat = false
        button.focus_mode = Control.FOCUS_NONE
        button.add_theme_stylebox_override("normal", _category_button_normal_style)
        button.add_theme_stylebox_override("hover", _category_button_active_style)
        button.add_theme_stylebox_override("pressed", _category_button_active_style)
        button.add_theme_font_size_override("font_size", 18)
        button.add_theme_color_override("font_color", Color(0.58, 0.6, 0.64, 1))
        button.pressed.connect(func(index := i): _on_category_selected(index))
        category_button_vbox.add_child(button)
        _category_buttons.append(button)

func _on_category_selected(index: int) -> void:
    if index < 0 or index >= _tutorial_categories.size():
        return
    _current_category_index = index
    _current_lesson_index = 0
    _refresh_category()

func _build_lesson_buttons() -> void:
    for child in lesson_list.get_children():
        child.queue_free()
    _lesson_buttons.clear()

    if _tutorial_categories.is_empty():
        return

    var category: Dictionary = _tutorial_categories[_current_category_index]
    var lessons: Array = category.get("lessons", [])
    for i in range(lessons.size()):
        var lesson: Dictionary = lessons[i]
        var button := Button.new()
        button.custom_minimum_size = Vector2(0, 52)
        button.text = str(lesson.get("title", "未命名"))
        button.focus_mode = Control.FOCUS_NONE
        button.clip_text = true
        button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
        button.alignment = HORIZONTAL_ALIGNMENT_LEFT
        button.add_theme_font_size_override("font_size", 15)
        button.add_theme_color_override("font_color", Color(0.48, 0.5, 0.54, 1))
        button.add_theme_stylebox_override("normal", _lesson_button_normal_style)
        button.add_theme_stylebox_override("hover", _lesson_button_active_style)
        button.add_theme_stylebox_override("pressed", _lesson_button_active_style)
        button.pressed.connect(func(index := i): _on_lesson_selected(index))
        lesson_list.add_child(button)
        _lesson_buttons.append(button)

func _on_lesson_selected(index: int) -> void:
    if _tutorial_categories.is_empty():
        return

    var lessons: Array = _tutorial_categories[_current_category_index].get("lessons", [])
    if index < 0 or index >= lessons.size():
        return
    _current_lesson_index = index
    _refresh_lesson()

func _refresh_category() -> void:
    if _tutorial_categories.is_empty():
        category_title.text = "暂无教学"
        lesson_title.text = "暂无教学内容"
        lesson_desc.text = "请先在教学配置中补充分类与课程内容。"
        stage_title.text = "暂无预览"
        stage_hint.text = "当前未加载到教学配置。"
        preview_image.texture = null
        dots_label.text = ""
        prev_btn.disabled = true
        next_btn.disabled = true
        for label in hot_card_labels:
            label.text = "节点"
        _set_stage_overlay_visible(true)
        return

    _current_category_index = clampi(_current_category_index, 0, _tutorial_categories.size() - 1)
    var category: Dictionary = _tutorial_categories[_current_category_index]
    category_title.text = str(category.get("label", "教学"))
    _build_lesson_buttons()
    _refresh_category_button_states()
    _refresh_lesson()

func _refresh_category_button_states() -> void:
    for i in range(_category_buttons.size()):
        var button: Button = _category_buttons[i]
        var is_current: bool = i == _current_category_index
        button.add_theme_stylebox_override("normal", _category_button_active_style if is_current else _category_button_normal_style)
        button.add_theme_color_override("font_color", Color(0.93, 0.64, 0.16, 1) if is_current else Color(0.58, 0.6, 0.64, 1))

func _refresh_lesson() -> void:
    if _tutorial_categories.is_empty():
        return

    var category: Dictionary = _tutorial_categories[_current_category_index]
    var lessons: Array = category.get("lessons", [])
    if lessons.is_empty():
        lesson_title.text = "暂无课程"
        lesson_desc.text = "当前分类下还没有课程内容。"
        stage_title.text = "暂无预览"
        stage_hint.text = "请在教学配置中补充 lessons。"
        preview_image.texture = null
        dots_label.text = ""
        prev_btn.disabled = true
        next_btn.disabled = true
        for label in hot_card_labels:
            label.text = "节点"
        _set_stage_overlay_visible(true)
        return

    _current_lesson_index = clampi(_current_lesson_index, 0, lessons.size() - 1)
    var lesson: Dictionary = lessons[_current_lesson_index]
    lesson_title.text = str(lesson.get("title", "教程"))
    lesson_desc.text = str(lesson.get("desc", "暂无说明。"))
    stage_title.text = str(lesson.get("title", "教程预览"))
    stage_hint.text = str(lesson.get("stage_hint", "选择与当前位置相连的地点后，即可前往下一处区域。"))

    var card_texts: Array = lesson.get("cards", [])
    for i in range(hot_card_labels.size()):
        var label: Label = hot_card_labels[i]
        label.text = str(card_texts[i]) if i < card_texts.size() else "节点"

    _apply_lesson_preview(str(lesson.get("image_path", "")))

    _refresh_lesson_button_states()
    _refresh_pager()

func _refresh_lesson_button_states() -> void:
    for i in range(_lesson_buttons.size()):
        var button: Button = _lesson_buttons[i]
        var is_current: bool = i == _current_lesson_index
        button.add_theme_stylebox_override("normal", _lesson_button_active_style if is_current else _lesson_button_normal_style)
        button.add_theme_color_override("font_color", Color(0.2, 0.21, 0.24, 1) if is_current else Color(0.48, 0.5, 0.54, 1))

func _refresh_pager() -> void:
    var lesson_count: int = 0
    if not _tutorial_categories.is_empty():
        lesson_count = int(_tutorial_categories[_current_category_index].get("lessons", []).size())
    var dots: Array[String] = []
    for i in range(lesson_count):
        dots.append("●" if i == _current_lesson_index else "○")
    dots_label.text = " ".join(dots)
    prev_btn.disabled = lesson_count <= 1
    next_btn.disabled = lesson_count <= 1

func _on_prev_pressed() -> void:
    if _tutorial_categories.is_empty():
        return

    var lesson_count: int = int(_tutorial_categories[_current_category_index].get("lessons", []).size())
    if lesson_count <= 0:
        return
    _current_lesson_index = posmod(_current_lesson_index - 1, lesson_count)
    _refresh_lesson()

func _on_next_pressed() -> void:
    if _tutorial_categories.is_empty():
        return

    var lesson_count: int = int(_tutorial_categories[_current_category_index].get("lessons", []).size())
    if lesson_count <= 0:
        return
    _current_lesson_index = posmod(_current_lesson_index + 1, lesson_count)
    _refresh_lesson()

func _apply_lesson_preview(image_path: String) -> void:
    var texture: Texture2D = null
    if not image_path.is_empty():
        texture = load(image_path) as Texture2D

    preview_image.texture = texture
    preview_image.visible = texture != null
    _set_stage_overlay_visible(texture == null)

func _set_stage_overlay_visible(is_visible: bool) -> void:
    stage_title.visible = is_visible
    character_dots.visible = is_visible
    cursor_hint.visible = is_visible
    stage_hint.visible = is_visible
    for card in hotspot_cards:
        card.visible = is_visible
