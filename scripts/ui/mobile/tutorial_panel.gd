extends Control

signal back_requested

const POPUP_MIN_SIZE: Vector2 = Vector2(1120, 700)

const TUTORIAL_CATEGORIES: Array[Dictionary] = [
	{
		"id": "combat",
		"label": "战斗",
		"icon": "战",
		"lessons": [
			{
				"title": "地点选择",
				"desc": "在卡尼思中，选择与当前地点相连的地点，即可前往所选地点。",
				"cards": ["当前地点", "可前往地点", "危险区域"]
			},
			{
				"title": "战斗区",
				"desc": "战斗区会遭遇常规敌人与小型冲突，建议优先熟悉基础指令与移动路线。",
				"cards": ["普通敌人", "回避点", "补给位"]
			},
			{
				"title": "精英区",
				"desc": "精英区的敌人更强，但也会提供更高质量的掉落与额外奖励。",
				"cards": ["精英敌人", "支援位", "奖励点"]
			},
			{
				"title": "首领区",
				"desc": "首领区通常位于路线尽头，进入前建议先完成补给与编队调整。",
				"cards": ["首领目标", "撤离点", "挑战提示"]
			}
		]
	},
	{
		"id": "support",
		"label": "支援",
		"icon": "辅",
		"lessons": [
			{
				"title": "安全区",
				"desc": "安全区可以整理状态、查看提示，并在继续推进前确认接下来的路线。",
				"cards": ["休整点", "路线提示", "状态恢复"]
			},
			{
				"title": "德朗商店",
				"desc": "商店会出售恢复品与战术卡片，建议结合当前局势有选择地购买。",
				"cards": ["恢复品", "战术卡", "资源交换"]
			},
			{
				"title": "航路点区域",
				"desc": "航路点区域用于快速切换线路，可以帮助你更高效地接近目标地点。",
				"cards": ["快速路线", "跨区移动", "节点切换"]
			}
		]
	},
	{
		"id": "system",
		"label": "系统",
		"icon": "脑",
		"lessons": [
			{
				"title": "使用卡牌",
				"desc": "战斗与探索中都能使用卡牌，合理安排时机可以明显改变当前局势。",
				"cards": ["主动卡", "增益卡", "撤离卡"]
			},
			{
				"title": "战术提醒",
				"desc": "关注当前目标、路径连通与敌人分布，能让你在推进中减少无效移动。",
				"cards": ["目标提示", "风险标记", "建议路线"]
			}
		]
	}
]

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
@onready var stage_title: Label = $CenterContainer/PanelRoot/VBox/BodyMargin/BodyHBox/RightContent/PreviewPanel/PreviewMargin/PreviewStage/StageTitle
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

func _ready() -> void:
	back_btn.pressed.connect(_on_back_pressed)
	prev_btn.pressed.connect(_on_prev_pressed)
	next_btn.pressed.connect(_on_next_pressed)
	background_panel.gui_input.connect(_on_background_gui_input)
	resized.connect(_on_panel_resized)
	_prepare_styles()
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

func _build_category_buttons() -> void:
	for child in category_button_vbox.get_children():
		child.queue_free()
	_category_buttons.clear()

	for i in range(TUTORIAL_CATEGORIES.size()):
		var category: Dictionary = TUTORIAL_CATEGORIES[i]
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
	if index < 0 or index >= TUTORIAL_CATEGORIES.size():
		return
	_current_category_index = index
	_current_lesson_index = 0
	_refresh_category()

func _build_lesson_buttons() -> void:
	for child in lesson_list.get_children():
		child.queue_free()
	_lesson_buttons.clear()

	var category: Dictionary = TUTORIAL_CATEGORIES[_current_category_index]
	var lessons: Array = category.get("lessons", [])
	for i in range(lessons.size()):
		var lesson: Dictionary = lessons[i]
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 52)
		button.text = str(lesson.get("title", "未命名"))
		button.focus_mode = Control.FOCUS_NONE
		button.clip_text = true
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 15)
		button.add_theme_color_override("font_color", Color(0.48, 0.5, 0.54, 1))
		button.add_theme_stylebox_override("normal", _lesson_button_normal_style)
		button.add_theme_stylebox_override("hover", _lesson_button_active_style)
		button.add_theme_stylebox_override("pressed", _lesson_button_active_style)
		button.pressed.connect(func(index := i): _on_lesson_selected(index))
		lesson_list.add_child(button)
		_lesson_buttons.append(button)

func _on_lesson_selected(index: int) -> void:
	var lessons: Array = TUTORIAL_CATEGORIES[_current_category_index].get("lessons", [])
	if index < 0 or index >= lessons.size():
		return
	_current_lesson_index = index
	_refresh_lesson()

func _refresh_category() -> void:
	var category: Dictionary = TUTORIAL_CATEGORIES[_current_category_index]
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
	var category: Dictionary = TUTORIAL_CATEGORIES[_current_category_index]
	var lessons: Array = category.get("lessons", [])
	if lessons.is_empty():
		return

	_current_lesson_index = clampi(_current_lesson_index, 0, lessons.size() - 1)
	var lesson: Dictionary = lessons[_current_lesson_index]
	lesson_title.text = str(lesson.get("title", "教程"))
	lesson_desc.text = str(lesson.get("desc", "暂无说明。"))
	stage_title.text = str(lesson.get("title", "教程预览"))
	stage_hint.text = "选择与当前位置相连的地点后，即可前往下一处区域。"

	var card_texts: Array = lesson.get("cards", [])
	for i in range(hot_card_labels.size()):
		var label: Label = hot_card_labels[i]
		label.text = str(card_texts[i]) if i < card_texts.size() else "节点"

	_refresh_lesson_button_states()
	_refresh_pager()

func _refresh_lesson_button_states() -> void:
	for i in range(_lesson_buttons.size()):
		var button: Button = _lesson_buttons[i]
		var is_current: bool = i == _current_lesson_index
		button.add_theme_stylebox_override("normal", _lesson_button_active_style if is_current else _lesson_button_normal_style)
		button.add_theme_color_override("font_color", Color(0.2, 0.21, 0.24, 1) if is_current else Color(0.48, 0.5, 0.54, 1))

func _refresh_pager() -> void:
	var lesson_count: int = int(TUTORIAL_CATEGORIES[_current_category_index].get("lessons", []).size())
	var dots: Array[String] = []
	for i in range(lesson_count):
		dots.append("●" if i == _current_lesson_index else "○")
	dots_label.text = " ".join(dots)
	prev_btn.disabled = lesson_count <= 1
	next_btn.disabled = lesson_count <= 1

func _on_prev_pressed() -> void:
	var lesson_count: int = int(TUTORIAL_CATEGORIES[_current_category_index].get("lessons", []).size())
	if lesson_count <= 0:
		return
	_current_lesson_index = posmod(_current_lesson_index - 1, lesson_count)
	_refresh_lesson()

func _on_next_pressed() -> void:
	var lesson_count: int = int(TUTORIAL_CATEGORIES[_current_category_index].get("lessons", []).size())
	if lesson_count <= 0:
		return
	_current_lesson_index = posmod(_current_lesson_index + 1, lesson_count)
	_refresh_lesson()
