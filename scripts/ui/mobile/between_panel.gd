extends Control

signal back_requested

const MemoryAlbumManagerScript = preload("res://scripts/data/memory_album_manager.gd")
const EntryCardScene = preload("res://scenes/ui/mobile/between_entry_card.tscn")
const TimelineGroupScene = preload("res://scenes/ui/mobile/between_timeline_group.tscn")
const TimelineItemScene = preload("res://scenes/ui/mobile/between_timeline_item.tscn")

@onready var background_panel: Panel = null
@onready var dim_bg: ColorRect = $DimBg
@onready var panel_root: PanelContainer = $CenterContainer/PanelRoot
@onready var root_vbox: VBoxContainer = $CenterContainer/PanelRoot/VBox/Margin/RootVBox
@onready var top_bar: HBoxContainer = $CenterContainer/PanelRoot/VBox/HeaderPanel/Margin/TopBar
@onready var back_btn: Button = $CenterContainer/PanelRoot/VBox/HeaderPanel/Margin/TopBar/BackBtn
@onready var title_label: Label = $CenterContainer/PanelRoot/VBox/HeaderPanel/Margin/TopBar/TitleVBox/TitleLabel
@onready var summary_label: Label = $CenterContainer/PanelRoot/VBox/HeaderPanel/Margin/TopBar/TitleVBox/SummaryLabel
@onready var mode_bar: HBoxContainer = $CenterContainer/PanelRoot/VBox/Margin/RootVBox/ModeBar
@onready var summary_title: Label = $CenterContainer/PanelRoot/VBox/Margin/RootVBox/SummaryCard/SummaryMargin/SummaryVBox/SummaryTitle
@onready var summary_body: Label = $CenterContainer/PanelRoot/VBox/Margin/RootVBox/SummaryCard/SummaryMargin/SummaryVBox/SummaryBody
@onready var list_mode_btn: Button = $CenterContainer/PanelRoot/VBox/Margin/RootVBox/ModeBar/ListModeBtn
@onready var timeline_mode_btn: Button = $CenterContainer/PanelRoot/VBox/Margin/RootVBox/ModeBar/TimelineModeBtn
@onready var filter_scroll: ScrollContainer = $CenterContainer/PanelRoot/VBox/Margin/RootVBox/FilterScroll
@onready var filter_bar: HBoxContainer = $CenterContainer/PanelRoot/VBox/Margin/RootVBox/FilterScroll/FilterBar
@onready var list_scroll: ScrollContainer = $CenterContainer/PanelRoot/VBox/Margin/RootVBox/ListScroll
@onready var list_content: VBoxContainer = $CenterContainer/PanelRoot/VBox/Margin/RootVBox/ListScroll/ListContent
@onready var empty_label: Label = $CenterContainer/PanelRoot/VBox/Margin/RootVBox/EmptyLabel
@onready var empty_state_card: PanelContainer = $CenterContainer/PanelRoot/VBox/Margin/RootVBox/EmptyStateCard
@onready var empty_state_desc: Label = $CenterContainer/PanelRoot/VBox/Margin/RootVBox/EmptyStateCard/EmptyStateMargin/EmptyStateVBox/EmptyStateDesc
@onready var detail_overlay: ColorRect = $DetailOverlay
@onready var detail_panel: PanelContainer = $DetailOverlay/DetailPanel
@onready var detail_title: Label = $DetailOverlay/DetailPanel/VBoxRoot/HeaderPanel/Margin/TopBar/DetailTitle
@onready var detail_close_btn: Button = $DetailOverlay/DetailPanel/VBoxRoot/HeaderPanel/Margin/TopBar/DetailCloseBtn
@onready var detail_meta: Label = $DetailOverlay/DetailPanel/VBoxRoot/Margin/VBox/DetailMeta
@onready var detail_image: TextureRect = $DetailOverlay/DetailPanel/VBoxRoot/Margin/VBox/DetailImage
@onready var detail_tags: Label = $DetailOverlay/DetailPanel/VBoxRoot/Margin/VBox/DetailTags
@onready var detail_summary: RichTextLabel = $DetailOverlay/DetailPanel/VBoxRoot/Margin/VBox/DetailSummary
@onready var detail_relation_panel: PanelContainer = $DetailOverlay/DetailPanel/VBoxRoot/Margin/VBox/DetailRelationPanel
@onready var detail_relation_title: Label = $DetailOverlay/DetailPanel/VBoxRoot/Margin/VBox/DetailRelationPanel/Margin/VBox/DetailRelationTitle
@onready var detail_relation_body: Label = $DetailOverlay/DetailPanel/VBoxRoot/Margin/VBox/DetailRelationPanel/Margin/VBox/DetailRelationBody
@onready var detail_quote: Label = $DetailOverlay/DetailPanel/VBoxRoot/Margin/VBox/DetailQuote
@onready var detail_favorite_btn: Button = $DetailOverlay/DetailPanel/VBoxRoot/Margin/VBox/ActionBar/DetailFavoriteBtn
@onready var detail_pin_btn: Button = $DetailOverlay/DetailPanel/VBoxRoot/Margin/VBox/ActionBar/DetailPinBtn
@onready var detail_chat_btn: Button = $DetailOverlay/DetailPanel/VBoxRoot/Margin/VBox/ActionBar/DetailChatBtn
@onready var filter_buttons := {
	"all": $CenterContainer/PanelRoot/VBox/Margin/RootVBox/FilterScroll/FilterBar/AllBtn,
	"milestone": $CenterContainer/PanelRoot/VBox/Margin/RootVBox/FilterScroll/FilterBar/MilestoneBtn,
	"memory": $CenterContainer/PanelRoot/VBox/Margin/RootVBox/FilterScroll/FilterBar/MemoryBtn,
	"diary": $CenterContainer/PanelRoot/VBox/Margin/RootVBox/FilterScroll/FilterBar/DiaryBtn,
	"moment": $CenterContainer/PanelRoot/VBox/Margin/RootVBox/FilterScroll/FilterBar/MomentBtn,
	"photo": $CenterContainer/PanelRoot/VBox/Margin/RootVBox/FilterScroll/FilterBar/PhotoBtn
}

var album_manager = MemoryAlbumManagerScript.new()
var all_entries: Array = []
var current_filter: String = "all"
var current_view_mode: String = "list"
var selected_entry: Dictionary = {}
const POPUP_MIN_SIZE: Vector2 = Vector2(1080, 700)
var _panel_tween: Tween = null

func _ready() -> void:
	back_btn.pressed.connect(_on_back_pressed)
	list_mode_btn.pressed.connect(func():
		current_view_mode = "list"
		_update_view_mode_buttons()
		_refresh_list()
	)
	timeline_mode_btn.pressed.connect(func():
		current_view_mode = "timeline"
		_update_view_mode_buttons()
		_refresh_list()
	)
	for filter_key in filter_buttons.keys():
		var btn: Button = filter_buttons[filter_key]
		btn.pressed.connect(func(key := str(filter_key)):
			current_filter = key
			_update_filter_buttons()
			_refresh_list()
		)
	detail_close_btn.pressed.connect(_close_detail)
	detail_favorite_btn.pressed.connect(_on_toggle_favorite_pressed)
	detail_pin_btn.pressed.connect(_on_toggle_pin_pressed)
	detail_chat_btn.pressed.connect(_on_chat_about_entry_pressed)
	dim_bg.gui_input.connect(_on_dim_bg_gui_input)
	resized.connect(_on_panel_resized)
	hide()
	detail_overlay.hide()
	_update_view_mode_buttons()
	_update_filter_buttons()

func show_panel() -> void:
	_refresh_entries()
	_update_popup_layout()
	show()
	dim_bg.modulate.a = 0.0
	panel_root.modulate.a = 0.0
	panel_root.scale = Vector2(0.97, 0.97)
	_kill_panel_tween()
	_panel_tween = create_tween()
	_panel_tween.set_parallel(true)
	_panel_tween.tween_property(dim_bg, "modulate:a", 1.0, 0.18)
	_panel_tween.tween_property(panel_root, "modulate:a", 1.0, 0.22)
	_panel_tween.tween_property(panel_root, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func hide_panel() -> void:
	_kill_panel_tween()
	_panel_tween = create_tween()
	_panel_tween.set_parallel(true)
	_panel_tween.tween_property(dim_bg, "modulate:a", 0.0, 0.15)
	_panel_tween.tween_property(panel_root, "modulate:a", 0.0, 0.15)
	_panel_tween.tween_property(panel_root, "scale", Vector2(0.97, 0.97), 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_panel_tween.set_parallel(false)
	_panel_tween.tween_callback(func():
		hide()
		back_requested.emit()
	)

func _refresh_entries() -> void:
	title_label.text = "你我之间"
	all_entries = album_manager.build_entries()
	var summary = album_manager.get_summary(all_entries)
	summary_title.text = "关系总览" if current_filter == "all" else _get_filter_summary_title()
	if all_entries.is_empty():
		summary_label.text = "这里只收录你与 Luna 之间的共同记录。"
		summary_body.text = "当剧情推进、聊天加深或纪念事件触发后，这里会自动整理出共同回忆。"
	else:
		summary_label.text = "已收录 %d 段回忆  ·  节点 %d  ·  收藏 %d  ·  未读 %d" % [
			int(summary.get("total", 0)),
			int(summary.get("milestone", 0)),
			int(summary.get("favorite", 0)),
			int(summary.get("unviewed", 0))
		]
		summary_body.text = _build_summary_body(summary)
	_refresh_list()

func _refresh_list() -> void:
	for child in list_content.get_children():
		child.queue_free()
	var filtered_entries = _get_filtered_entries()
	var has_entries = not filtered_entries.is_empty()
	empty_label.visible = not has_entries
	empty_state_card.visible = not has_entries
	list_scroll.visible = has_entries
	if not has_entries:
		empty_label.text = "这个分类里还没有内容。" if current_filter != "all" else "这里只会收录你与Luna之间的纪念。"
		empty_state_desc.text = _get_empty_state_desc()
		return
	if current_view_mode == "timeline":
		_populate_timeline_view(filtered_entries)
		return
	for entry in filtered_entries:
		list_content.add_child(_create_entry_card(entry))

func _get_filtered_entries() -> Array:
	if current_filter == "all":
		return all_entries
	var result: Array = []
	for entry in all_entries:
		if str(entry.get("category", "")) == current_filter:
			result.append(entry)
	return result

func _update_view_mode_buttons() -> void:
	list_mode_btn.text = "当前: 分类" if current_view_mode == "list" else "分类视图"
	timeline_mode_btn.text = "当前: 时间线" if current_view_mode == "timeline" else "时间线"
	list_mode_btn.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2, 1) if current_view_mode == "list" else Color(0.34, 0.31, 0.28, 1))
	timeline_mode_btn.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2, 1) if current_view_mode == "timeline" else Color(0.34, 0.31, 0.28, 1))

func _update_filter_buttons() -> void:
	for filter_key in filter_buttons.keys():
		var btn: Button = filter_buttons[filter_key]
		var base_text = btn.text.replace("当前:", "")
		btn.text = "当前:%s" % base_text if filter_key == current_filter else base_text
		btn.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2, 1) if filter_key == current_filter else Color(0.34, 0.31, 0.28, 1))

func _populate_timeline_view(entries: Array) -> void:
	var timeline_entries = entries.duplicate(true)
	timeline_entries.sort_custom(func(a, b): return int(a.get("sort_value", 0)) > int(b.get("sort_value", 0)))
	var groups = _build_timeline_groups(timeline_entries)
	for group_data in groups:
		list_content.add_child(_create_timeline_group(group_data))

func _build_timeline_groups(entries: Array) -> Array:
	var groups: Array = []
	for entry in entries:
		var group_label = _get_timeline_group_label(entry)
		if groups.is_empty() or str(groups[groups.size() - 1].get("label", "")) != group_label:
			groups.append({
				"label": group_label,
				"entries": []
			})
		groups[groups.size() - 1]["entries"].append(entry)
	return groups

func _get_timeline_group_label(entry: Dictionary) -> String:
	if bool(entry.get("is_milestone", false)):
		return "关系阶段"
	var time_label = str(entry.get("time_label", "")).strip_edges()
	if time_label != "":
		return time_label
	var subtitle = str(entry.get("subtitle", "")).strip_edges()
	if subtitle != "":
		return subtitle
	return "未标记时间"

func _create_timeline_group(group_data: Dictionary) -> Control:
	var wrapper = TimelineGroupScene.instantiate()
	var header: Label = wrapper.get_node("HeaderPanel/HeaderMargin/HeaderLabel")
	var items_vbox: VBoxContainer = wrapper.get_node("ItemsVBox")
	header.text = str(group_data.get("label", "未标记时间"))
	var entries = group_data.get("entries", [])
	for i in range(entries.size()):
		items_vbox.add_child(_create_timeline_item(entries[i], i < entries.size() - 1))
	return wrapper

func _create_timeline_item(entry: Dictionary, draw_tail: bool) -> Control:
	var row = TimelineItemScene.instantiate()
	var line_top: ColorRect = row.get_node("Rail/LineTop")
	var dot: ColorRect = row.get_node("Rail/Dot")
	var line_bottom: ColorRect = row.get_node("Rail/LineBottom")
	var card_holder: PanelContainer = row.get_node("CardHolder")
	line_top.visible = false
	line_bottom.visible = draw_tail
	if bool(entry.get("is_milestone", false)):
		dot.color = Color(0.95, 0.79, 0.42, 1.0)
		dot.offset_left = 5.0
		dot.offset_top = 34.0
		dot.offset_right = 21.0
		dot.offset_bottom = 50.0
	card_holder.add_child(_create_entry_card(entry))
	return row

func _create_entry_card(entry: Dictionary) -> Control:
	var card = EntryCardScene.instantiate()
	var card_panel: PanelContainer = card
	var click_btn: Button = card.get_node("ClickBtn")
	var cover_panel: PanelContainer = card.get_node("Margin/HBox/CoverPanel")
	var cover_image: TextureRect = card.get_node("Margin/HBox/CoverPanel/CoverMask/CoverImage")
	var cover_icon: Label = card.get_node("Margin/HBox/CoverPanel/CoverMask/CoverIcon")
	var title: Label = card.get_node("Margin/HBox/TextVBox/TitleLabel")
	var meta: Label = card.get_node("Margin/HBox/TextVBox/MetaLabel")
	var summary: Label = card.get_node("Margin/HBox/TextVBox/SummaryLabel")
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(1, 1, 1, 0.98)
	normal_style.corner_radius_top_left = 14
	normal_style.corner_radius_top_right = 14
	normal_style.corner_radius_bottom_left = 14
	normal_style.corner_radius_bottom_right = 14
	normal_style.border_width_left = 1
	normal_style.border_width_top = 1
	normal_style.border_width_right = 1
	normal_style.border_width_bottom = 1
	normal_style.border_color = Color(0.89, 0.91, 0.95, 1)
	if bool(entry.get("is_milestone", false)):
		normal_style.bg_color = Color(1, 0.972549, 0.945098, 1)
		normal_style.border_width_left = 1
		normal_style.border_width_top = 1
		normal_style.border_width_right = 1
		normal_style.border_width_bottom = 1
		normal_style.border_color = Color(0.956863, 0.529412, 0.188235, 0.35)
	elif not bool(entry.get("is_viewed", false)):
		normal_style.bg_color = Color(0.978, 0.982, 0.99, 1)
	card_panel.add_theme_stylebox_override("panel", normal_style)
	var cover_path = str(entry.get("cover_image", ""))
	var tex = _load_texture(cover_path)
	cover_image.texture = tex
	cover_image.visible = tex != null
	cover_icon.visible = tex == null
	cover_icon.text = _get_category_icon(str(entry.get("category", "")))
	if bool(entry.get("is_milestone", false)):
		var cover_style = StyleBoxFlat.new()
		cover_style.bg_color = Color(1, 0.972549, 0.945098, 1)
		cover_style.corner_radius_top_left = 12
		cover_style.corner_radius_top_right = 12
		cover_style.corner_radius_bottom_left = 12
		cover_style.corner_radius_bottom_right = 12
		cover_style.border_width_left = 1
		cover_style.border_width_top = 1
		cover_style.border_width_right = 1
		cover_style.border_width_bottom = 1
		cover_style.border_color = Color(0.956863, 0.529412, 0.188235, 0.25)
		cover_panel.add_theme_stylebox_override("panel", cover_style)
	title.text = _build_entry_title(entry)
	meta.text = _build_entry_meta(entry)
	summary.text = str(entry.get("summary", ""))
	click_btn.pressed.connect(func(): _open_detail(entry))
	return card

func _open_detail(entry: Dictionary) -> void:
	album_manager.mark_viewed(str(entry.get("id", "")))
	selected_entry = _find_entry_by_id(str(entry.get("id", "")))
	if selected_entry.is_empty():
		selected_entry = entry
	_update_detail_view(selected_entry)
	_refresh_entries()
	detail_overlay.show()
	detail_overlay.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(detail_overlay, "modulate:a", 1.0, 0.16)

func _close_detail() -> void:
	var tween = create_tween()
	tween.tween_property(detail_overlay, "modulate:a", 0.0, 0.12)
	tween.tween_callback(func(): detail_overlay.hide())

func _on_chat_about_entry_pressed() -> void:
	if selected_entry.is_empty():
		return
	var revisit_payload = selected_entry.get("revisit_payload", {})
	if revisit_payload.is_empty():
		return
	_close_detail()
	hide_panel()
	var mobile_interface = _find_mobile_interface()
	if mobile_interface and mobile_interface.has_method("hide_phone"):
		mobile_interface.hide_phone()
	await get_tree().create_timer(0.2).timeout
	var main_scene = get_tree().root.get_node_or_null("MainScene")
	if main_scene and main_scene.has_method("start_memory_revisit"):
		main_scene.start_memory_revisit(revisit_payload)

func _find_mobile_interface() -> Node:
	var current_scene: Node = get_tree().current_scene
	if current_scene:
		var scene_mobile = current_scene.get_node_or_null("UIPanel/MobileInterface")
		if scene_mobile:
			return scene_mobile
	var curr = get_parent()
	while curr:
		if curr.has_method("show_phone") and curr.has_method("hide_phone"):
			return curr
		curr = curr.get_parent()
	return null

func _load_texture(path: String) -> Texture2D:
	if path == "":
		return null
	if path.begins_with("res://") and ResourceLoader.exists(path):
		var res = load(path)
		if res is Texture2D:
			return res
	if FileAccess.file_exists(path):
		var img = Image.load_from_file(path)
		if img and not img.is_empty():
			return ImageTexture.create_from_image(img)
	return null

func _get_category_icon(category: String) -> String:
	match category:
		"milestone":
			return "◆"
		"memory":
			return "♡"
		"diary":
			return "✎"
		"moment":
			return "☼"
		"photo":
			return "◫"
		_:
			return "•"

func _on_back_pressed() -> void:
	hide_panel()

func _build_summary_body(summary: Dictionary) -> String:
	return "本页整理共同节点、收藏片段与未读更新，方便你快速回看关系推进。当前已收藏 %d 条，仍有 %d 条新内容待查看。" % [
		int(summary.get("favorite", 0)),
		int(summary.get("unviewed", 0))
	]

func _get_filter_summary_title() -> String:
	match current_filter:
		"milestone":
			return "关键节点"
		"memory":
			return "共同回忆"
		"diary":
			return "日记片段"
		"moment":
			return "动态记录"
		"photo":
			return "影像留档"
		_:
			return "关系总览"

func _get_empty_state_desc() -> String:
	match current_filter:
		"milestone":
			return "当关系推进到关键阶段后，这里会优先收录具有纪念意义的节点。"
		"memory":
			return "与 Luna 的聊天、事件和互动会逐步沉淀为可回看的共同回忆。"
		"diary":
			return "当角色日记记录到你们之间的重要内容后，会自动同步到这里。"
		"moment":
			return "朋友圈互动和动态片段会在触发后收录到这一栏。"
		"photo":
			return "拍照、CG 或关键画面会在形成纪念后出现在这里。"
		_:
			return "继续推进剧情、聊天或触发事件后，这里会逐步收录你与 Luna 的关键纪念。"

func _on_dim_bg_gui_input(event: InputEvent) -> void:
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

func _on_toggle_favorite_pressed() -> void:
	if selected_entry.is_empty():
		return
	album_manager.toggle_favorite(str(selected_entry.get("id", "")))
	_reopen_selected_entry()

func _on_toggle_pin_pressed() -> void:
	if selected_entry.is_empty():
		return
	album_manager.toggle_pinned(str(selected_entry.get("id", "")))
	_reopen_selected_entry()

func _reopen_selected_entry() -> void:
	var entry_id = str(selected_entry.get("id", ""))
	_refresh_entries()
	var refreshed = _find_entry_by_id(entry_id)
	if refreshed.is_empty():
		return
	selected_entry = refreshed
	_update_detail_view(selected_entry)

func _find_entry_by_id(entry_id: String) -> Dictionary:
	for entry in album_manager.build_entries():
		if str(entry.get("id", "")) == entry_id:
			return entry
	return {}

func _build_entry_title(entry: Dictionary) -> String:
	var title = str(entry.get("title", "共同回忆"))
	if bool(entry.get("is_pinned", false)):
		title = "置顶 · " + title
	elif bool(entry.get("is_milestone", false)):
		title = "节点 · " + title
	elif not bool(entry.get("is_viewed", false)):
		title = "新 · " + title
	return title

func _build_entry_meta(entry: Dictionary, include_status: bool = true) -> String:
	var parts: Array = []
	if str(entry.get("time_label", "")) != "":
		parts.append(str(entry.get("time_label", "")))
	if str(entry.get("subtitle", "")) != "":
		parts.append(str(entry.get("subtitle", "")))
	if include_status:
		if bool(entry.get("is_favorite", false)):
			parts.append("已收藏")
		if not bool(entry.get("is_viewed", false)):
			parts.append("未读")
	return "  ·  ".join(parts)

func _update_detail_view(entry: Dictionary) -> void:
	detail_title.text = str(entry.get("title", "共同回忆"))
	detail_meta.text = _build_entry_meta(entry, false)
	detail_summary.text = str(entry.get("summary", ""))

	var quote_text = str(entry.get("quote", "")).strip_edges()
	detail_quote.visible = quote_text != ""
	detail_quote.text = "“%s”" % quote_text if quote_text != "" else ""

	var tags = entry.get("tags", [])
	detail_tags.visible = tags is Array and not tags.is_empty()
	detail_tags.text = "标签：%s" % " / ".join(tags) if detail_tags.visible else ""

	var relation_info = _build_relation_info(entry)
	detail_relation_panel.visible = not relation_info.is_empty()
	if detail_relation_panel.visible:
		detail_relation_title.text = str(relation_info.get("title", "关联回忆"))
		detail_relation_body.text = str(relation_info.get("body", ""))

	detail_favorite_btn.text = "取消收藏" if bool(entry.get("is_favorite", false)) else "收藏"
	detail_pin_btn.text = "取消置顶" if bool(entry.get("is_pinned", false)) else "置顶"

	var cover_path = str(entry.get("cover_image", ""))
	detail_image.texture = _load_texture(cover_path) if cover_path != "" else null
	detail_image.visible = detail_image.texture != null

func _build_relation_info(entry: Dictionary) -> Dictionary:
	if str(entry.get("category", "")) != "photo":
		return {}
	var label = str(entry.get("binding_label", "")).strip_edges()
	var summary = str(entry.get("binding_summary", "")).strip_edges()
	if label == "" and summary == "":
		return {}
	return {
		"title": label if label != "" else "关联回忆",
		"body": summary if summary != "" else "这张照片已经被收录，但暂时没有补充更具体的回忆说明。"
	}
