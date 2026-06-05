extends Control

const PhotoMemoryManagerScript = preload("res://scripts/data/photo_memory_manager.gd")
const PhotoCardScene = preload("res://scenes/ui/mobile/album_list_card.tscn")
const CATEGORY_ALL := "all"
const CATEGORY_CAMERA := "camera"
const CATEGORY_CHAT := "chat"
const CATEGORY_CG := "cg"
const CATEGORY_DIARY := "diary"
const CATEGORY_MOMENT := "moment"
const CATEGORY_DRAWING := "drawing"
const CATEGORY_OTHER := "other"

signal photo_picked(path: String)
signal back_requested

@onready var background_panel: Panel = $Background
@onready var panel_root: PanelContainer = $CenterContainer/PanelRoot
@onready var back_btn: Button = $CenterContainer/PanelRoot/VBox/HeaderPanel/Margin/TopBar/BackBtn
@onready var title_label: Label = $CenterContainer/PanelRoot/VBox/HeaderPanel/Margin/TopBar/Title
@onready var summary_panel: PanelContainer = $CenterContainer/PanelRoot/VBox/BodyMargin/ContentVBox/SummaryPanel
@onready var summary_title_label: Label = $CenterContainer/PanelRoot/VBox/BodyMargin/ContentVBox/SummaryPanel/Margin/VBox/SummaryTitle
@onready var summary_label: Label = $CenterContainer/PanelRoot/VBox/BodyMargin/ContentVBox/SummaryPanel/Margin/VBox/SummaryLabel
@onready var filter_scroll: ScrollContainer = $CenterContainer/PanelRoot/VBox/BodyMargin/ContentVBox/FilterScroll
@onready var filter_bar: HBoxContainer = $CenterContainer/PanelRoot/VBox/BodyMargin/ContentVBox/FilterScroll/FilterBar
@onready var grid: GridContainer = $CenterContainer/PanelRoot/VBox/BodyMargin/ContentVBox/Scroll/Grid
@onready var empty_label: Label = $CenterContainer/PanelRoot/VBox/BodyMargin/ContentVBox/EmptyLabel
@onready var empty_state_card: PanelContainer = $CenterContainer/PanelRoot/VBox/BodyMargin/ContentVBox/EmptyStateCard
@onready var empty_state_title: Label = $CenterContainer/PanelRoot/VBox/BodyMargin/ContentVBox/EmptyStateCard/EmptyStateMargin/EmptyStateVBox/EmptyStateTitle
@onready var empty_state_desc: Label = $CenterContainer/PanelRoot/VBox/BodyMargin/ContentVBox/EmptyStateCard/EmptyStateMargin/EmptyStateVBox/EmptyStateDesc
@onready var fullscreen_viewer: Control = $FullscreenViewer
@onready var full_image: TextureRect = $FullscreenViewer/FullImage
@onready var close_viewer_btn: Button = $FullscreenViewer/CloseViewerBtn
@onready var send_btn: Button = $FullscreenViewer/MetaPanel/Margin/VBox/MetaFooterRow/SendBtn
@onready var meta_panel: PanelContainer = $FullscreenViewer/MetaPanel
@onready var meta_tag: Label = $FullscreenViewer/MetaPanel/Margin/VBox/MetaTag
@onready var meta_title: Label = $FullscreenViewer/MetaPanel/Margin/VBox/MetaTitle
@onready var meta_body: Label = $FullscreenViewer/MetaPanel/Margin/VBox/MetaBody
@onready var meta_footer: Label = $FullscreenViewer/MetaPanel/Margin/VBox/MetaFooterRow/MetaFooter
@onready var filter_buttons := {
	 CATEGORY_ALL: $CenterContainer/PanelRoot/VBox/BodyMargin/ContentVBox/FilterScroll/FilterBar/AllBtn,
	 CATEGORY_CAMERA: $CenterContainer/PanelRoot/VBox/BodyMargin/ContentVBox/FilterScroll/FilterBar/CameraBtn,
	 CATEGORY_CHAT: $CenterContainer/PanelRoot/VBox/BodyMargin/ContentVBox/FilterScroll/FilterBar/ChatBtn,
	 CATEGORY_CG: $CenterContainer/PanelRoot/VBox/BodyMargin/ContentVBox/FilterScroll/FilterBar/CgBtn,
	 CATEGORY_DIARY: $CenterContainer/PanelRoot/VBox/BodyMargin/ContentVBox/FilterScroll/FilterBar/DiaryBtn,
	 CATEGORY_MOMENT: $CenterContainer/PanelRoot/VBox/BodyMargin/ContentVBox/FilterScroll/FilterBar/MomentBtn,
	 CATEGORY_DRAWING: $CenterContainer/PanelRoot/VBox/BodyMargin/ContentVBox/FilterScroll/FilterBar/DrawingBtn,
	 CATEGORY_OTHER: $CenterContainer/PanelRoot/VBox/BodyMargin/ContentVBox/FilterScroll/FilterBar/OtherBtn
}

var _album_records: Array = []
var _is_picker_mode: bool = false
var _picker_btn_text: String = "确定"
var _current_viewing_path: String = ""
var _photo_manager = PhotoMemoryManagerScript.new()
var _current_filter: String = CATEGORY_ALL
var _filter_button_labels: Dictionary = {}
var _filter_button_normal_styles: Dictionary = {}
var _filter_button_active_styles: Dictionary = {}
const POPUP_MIN_SIZE: Vector2 = Vector2(1120, 700)
var _panel_tween: Tween = null

func _ready() -> void:
	back_btn.pressed.connect(_on_back_pressed)
	close_viewer_btn.pressed.connect(_on_close_viewer_pressed)
	send_btn.pressed.connect(_on_send_pressed)
	background_panel.gui_input.connect(_on_background_gui_input)
	resized.connect(_on_panel_resized)
	title_label.text = "相册"
	resized.connect(_update_grid_columns)
	for category in filter_buttons.keys():
		var btn: Button = filter_buttons[category]
		_filter_button_labels[category] = btn.text
		_filter_button_normal_styles[category] = btn.get_theme_stylebox("normal")
		_filter_button_active_styles[category] = btn.get_theme_stylebox("hover")
		btn.pressed.connect(func(filter_key := str(category)):
			_current_filter = filter_key
			_load_photos()
		)
	_update_grid_columns()
	_update_filter_buttons()
	hide()

func set_picker_mode(is_picker: bool, btn_text: String = "确定") -> void:
	_is_picker_mode = is_picker
	_picker_btn_text = btn_text

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
	_update_grid_columns()
	_load_photos()

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

func _load_photos() -> void:
	for child in grid.get_children():
		child.queue_free()
	_album_records = _photo_manager.get_album_records(_current_filter)
	_update_album_summary()
	_update_filter_buttons()
	if _album_records.is_empty():
		empty_label.text = "这个分类里还没有内容。" if _current_filter != CATEGORY_ALL else "相册空空如也~"
		empty_state_title.text = "这个分类还没有内容" if _current_filter != CATEGORY_ALL else "相册还在等待第一张纪念"
		empty_state_desc.text = _get_empty_state_desc()
		empty_label.show()
		empty_state_card.show()
		return
	empty_label.hide()
	empty_state_card.hide()
	_render_photos()

func _render_photos() -> void:
	for record in _album_records:
		var path = str(record.get("photo_path", ""))
		var tex = _load_texture(path)
		if tex == null:
			continue
		var card = PhotoCardScene.instantiate()
		var thumb: TextureRect = card.get_node("Content/ThumbMask/Thumb")
		var title_text: Label = card.get_node("MetaNodes/TitleLabel")
		var source_text: Label = card.get_node("MetaNodes/SourceLabel")
		var meta_text: Label = card.get_node("MetaNodes/MetaLabel")
		var click_btn: Button = card.get_node("ClickBtn")
		thumb.texture = tex
		title_text.text = _build_record_title(record)
		source_text.text = _build_record_source(record)
		meta_text.text = _build_record_meta(record)
		source_text.visible = false
		meta_text.visible = false
		click_btn.pressed.connect(_on_photo_clicked.bind(tex, record))
		grid.add_child(card)

func _on_photo_clicked(tex: Texture2D, record: Dictionary) -> void:
	full_image.texture = tex
	_current_viewing_path = str(record.get("photo_path", ""))
	_update_fullscreen_meta(record)
	fullscreen_viewer.show()
	if _is_picker_mode and _current_viewing_path != "":
		send_btn.text = _picker_btn_text
		send_btn.show()
	else:
		send_btn.hide()
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
		meta_panel.hide()
	)

func _on_send_pressed() -> void:
	if _current_viewing_path != "":
		photo_picked.emit(_current_viewing_path)
		_on_close_viewer_pressed()

func _update_filter_buttons() -> void:
	for category in filter_buttons.keys():
		var btn: Button = filter_buttons[category]
		btn.text = str(_filter_button_labels.get(category, _get_category_short_text(str(category))))
		var is_current = str(category) == _current_filter
		var normal_style: StyleBox = _filter_button_active_styles.get(category) if is_current else _filter_button_normal_styles.get(category)
		if normal_style:
			btn.add_theme_stylebox_override("normal", normal_style)
		btn.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2, 1.0) if is_current else Color(0.34, 0.31, 0.28, 1.0))

func _update_album_summary() -> void:
	var all_records = _photo_manager.get_album_records()
	var summary = _photo_manager.get_album_summary(all_records)
	summary_title_label.text = _get_summary_title()
	summary_label.text = "共 %d 张照片\n拍摄 %d  ·  聊天 %d  ·  CG %d  ·  日记 %d  ·  朋友圈 %d  ·  绘画 %d  ·  其他 %d" % [
		int(summary.get("total", 0)),
		int(summary.get(CATEGORY_CAMERA, 0)),
		int(summary.get(CATEGORY_CHAT, 0)),
		int(summary.get(CATEGORY_CG, 0)),
		int(summary.get(CATEGORY_DIARY, 0)),
		int(summary.get(CATEGORY_MOMENT, 0)),
		int(summary.get(CATEGORY_DRAWING, 0)),
		int(summary.get(CATEGORY_OTHER, 0))
	]

func _get_empty_state_desc() -> String:
	match _current_filter:
		CATEGORY_CAMERA:
			return "当你在剧情里拍照或记录日常画面后，这里会自动整理成拍摄相册。"
		CATEGORY_CHAT:
			return "聊天中的截图、分享图片和重要图像会收录到这一栏。"
		CATEGORY_CG:
			return "关键剧情 CG 与特殊画面会在解锁后统一展示。"
		CATEGORY_DIARY:
			return "角色日记里的插图和纪念配图会逐步同步到这里。"
		CATEGORY_MOMENT:
			return "朋友圈互动产生的图片与留影会在触发后出现在这里。"
		CATEGORY_DRAWING:
			return "你们共同生成或获得的绘画作品会收藏在这一栏。"
		CATEGORY_OTHER:
			return "暂未归类的图像与纪念素材会先放在这里。"
		_:
			return "拍照、聊天图片、日记插图和关键画面会逐步整理到这里。"

func _update_grid_columns() -> void:
	if not is_instance_valid(grid):
		return
	var viewport_width: float = panel_root.size.x
	if viewport_width <= 0.0:
		viewport_width = POPUP_MIN_SIZE.x
	var usable_width: float = maxf(320.0, viewport_width - 120.0)
	var target_card_width: float = 200.0
	var columns: int = int(floor((usable_width + 14.0) / (target_card_width + 14.0)))
	grid.columns = clampi(columns, 3, 5)

func _get_summary_title() -> String:
	match _current_filter:
		CATEGORY_ALL:
			return "最近项目"
		CATEGORY_CAMERA:
			return "拍摄相册"
		CATEGORY_CHAT:
			return "聊天图片"
		CATEGORY_CG:
			return "剧情 CG"
		CATEGORY_DIARY:
			return "日记插图"
		CATEGORY_MOMENT:
			return "朋友圈留影"
		CATEGORY_DRAWING:
			return "绘画作品"
		_:
			return "其他收录"

func _update_fullscreen_meta(record: Dictionary) -> void:
	if record.is_empty():
		meta_panel.hide()
		return
	var reason = str(record.get("relation_reason", "")).strip_edges()
	var related_title = str(record.get("related_memory_title", "")).strip_edges()
	var related_content = str(record.get("related_memory_content", "")).strip_edges()
	var source_label = str(record.get("album_display_source", record.get("source_label", "相册照片"))).strip_edges()
	var source_title = str(record.get("album_display_title", record.get("source_title", ""))).strip_edges()
	var display_note = str(record.get("album_display_note", "")).strip_edges()
	meta_tag.text = "%s · %s" % [_get_category_badge_text(str(record.get("album_category", CATEGORY_OTHER))), _build_record_date(record)]
	if related_title != "" and reason != "":
		meta_title.text = "%s · %s" % [related_title, reason]
	elif source_title != "":
		meta_title.text = "%s · %s" % [source_title, source_label]
	elif related_title != "":
		meta_title.text = related_title
	elif reason != "":
		meta_title.text = "%s · %s" % [source_label, reason]
	else:
		meta_title.text = source_label
	if related_content != "":
		meta_body.text = "%s 收录时自动关联到这段回忆：%s" % [source_label, related_content]
	elif display_note != "":
		meta_body.text = display_note
	elif reason != "":
		meta_body.text = "%s 已按%s归档，之后可以继续补全更具体的回忆来源。" % [source_label, reason]
	elif str(record.get("source_text", "")).strip_edges() != "":
		meta_body.text = "%s：%s" % [source_label, str(record.get("source_text", ""))]
	else:
		meta_body.text = "%s 已写入照片档案，但当前还没有匹配到明确的回忆内容。" % source_label
	meta_footer.text = _build_record_footer(record)
	meta_footer.visible = meta_footer.text != ""
	meta_panel.show()

func _build_record_title(record: Dictionary) -> String:
	var title = str(record.get("album_display_title", record.get("source_title", ""))).strip_edges()
	if title != "":
		return title
	return str(record.get("album_display_source", record.get("source_label", "相册照片")))

func _build_record_meta(record: Dictionary) -> String:
	var display_subtitle = str(record.get("album_display_subtitle", "")).strip_edges()
	if display_subtitle != "":
		return display_subtitle
	var related_title = str(record.get("related_memory_title", "")).strip_edges()
	if related_title != "":
		return "关联回忆 · %s" % related_title
	var reason = str(record.get("relation_reason", "")).strip_edges()
	if reason != "":
		return "归档方式 · %s" % reason
	var source_text = str(record.get("source_text", "")).strip_edges()
	if source_text != "":
		return _trim_text(source_text, 34)
	return ""

func _build_record_date(record: Dictionary) -> String:
	var display_time = str(record.get("album_display_time", "")).strip_edges()
	if display_time != "":
		return display_time
	var saved_at = _format_saved_at(str(record.get("saved_at", "")))
	if saved_at != "":
		return saved_at
	var day_offset = int(record.get("day_offset", 0))
	var story_time = str(record.get("story_time", "")).strip_edges()
	if day_offset > 0 and story_time != "":
		return "第%d天 · %s" % [day_offset + 1, story_time]
	if story_time != "":
		return story_time
	var real_date = str(record.get("real_date", "")).strip_edges()
	if real_date != "":
		return real_date
	return "未记录时间"

func _build_record_source(record: Dictionary) -> String:
	var parts: Array = []
	var source_label = str(record.get("album_display_source", record.get("source_label", "相册照片"))).strip_edges()
	if source_label != "":
		parts.append(source_label)
	var scene_name = str(record.get("album_display_scene", "")).strip_edges()
	if scene_name != "":
		parts.append(scene_name)
	var context_text = _build_record_context(record)
	if context_text != "":
		parts.append(context_text)
	return " · ".join(parts)

func _build_record_footer(record: Dictionary) -> String:
	var parts: Array = []
	var source_line = _build_record_source(record)
	if source_line != "":
		parts.append(source_line)
	var related_title = str(record.get("related_memory_title", "")).strip_edges()
	if related_title != "":
		parts.append("关联到 %s" % related_title)
	return "  ·  ".join(parts)

func _build_record_context(record: Dictionary) -> String:
	var context_domain = str(record.get("context_domain", "story")).strip_edges()
	if context_domain == "story":
		var story_parts: Array = []
		var day_offset = int(record.get("day_offset", 0))
		if day_offset >= 0:
			story_parts.append("第%d天" % (day_offset + 1))
		var story_period = str(record.get("story_period", "")).strip_edges()
		var story_time = str(record.get("story_time", "")).strip_edges()
		if story_period != "":
			story_parts.append(story_period)
		elif story_time != "":
			story_parts.append(story_time)
		return "剧情 %s" % " / ".join(story_parts) if not story_parts.is_empty() else "剧情"
	var real_parts: Array = []
	var real_date = str(record.get("real_date", "")).strip_edges()
	if real_date != "":
		real_parts.append(real_date)
	var real_period = str(record.get("real_period", "")).strip_edges()
	if real_period != "":
		real_parts.append(real_period)
	return "现实 %s" % " / ".join(real_parts) if not real_parts.is_empty() else "现实"

func _format_saved_at(saved_at: String) -> String:
	var text = saved_at.strip_edges()
	if text == "":
		return ""
	text = text.replace("T", " ")
	text = text.replace("/", "-")
	if text.length() >= 16:
		return text.substr(0, 16)
	return text

func _trim_text(text: String, limit: int) -> String:
	var clean = text.strip_edges()
	if clean.length() <= limit:
		return clean
	return clean.substr(0, max(0, limit - 1)) + "…"

func _get_category_short_text(category: String) -> String:
	match category:
		CATEGORY_ALL:
			return "全部"
		CATEGORY_CAMERA:
			return "拍摄"
		CATEGORY_CHAT:
			return "聊天"
		CATEGORY_CG:
			return "CG"
		CATEGORY_DIARY:
			return "日记"
		CATEGORY_MOMENT:
			return "朋友圈"
		CATEGORY_DRAWING:
			return "绘画"
		_:
			return "其他"

func _get_category_badge_text(category: String) -> String:
	match category:
		CATEGORY_CAMERA:
			return "拍摄"
		CATEGORY_CHAT:
			return "聊天"
		CATEGORY_CG:
			return "CG"
		CATEGORY_DIARY:
			return "日记"
		CATEGORY_MOMENT:
			return "朋友圈"
		CATEGORY_DRAWING:
			return "绘画"
		CATEGORY_OTHER:
			return "其他"
		_:
			return "收录"

func _load_texture(path: String) -> Texture2D:
	if path == "":
		return null
	if path.begins_with("res://") and ResourceLoader.exists(path):
		var res = load(path)
		return res if res is Texture2D else null
	if FileAccess.file_exists(path):
		var img = Image.load_from_file(path)
		if img and not img.is_empty():
			return ImageTexture.create_from_image(img)
	return null
