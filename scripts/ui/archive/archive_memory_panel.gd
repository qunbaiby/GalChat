extends Control

@onready var background_panel: Panel = $Background
@onready var center_container: CenterContainer = $CenterContainer
@onready var panel_root: Panel = $CenterContainer/Panel
@onready var content_root: VBoxContainer = $CenterContainer/Panel/VBoxContainer
@onready var close_btn: Button = $CenterContainer/Panel/CloseButton
@onready var top_bar: Panel = $CenterContainer/Panel/VBoxContainer/TopBar
@onready var body_margin: MarginContainer = $CenterContainer/Panel/VBoxContainer/BodyMargin
@onready var body_hbox: HBoxContainer = $CenterContainer/Panel/VBoxContainer/BodyMargin/BodyHBox
@onready var category_title: Label = get_node_or_null("CenterContainer/Panel/VBoxContainer/BodyMargin/BodyHBox/LeftSidebar/SidebarMargin/SidebarVBox/CategoryTitle") as Label
@onready var category_hint: Label = get_node_or_null("CenterContainer/Panel/VBoxContainer/BodyMargin/BodyHBox/LeftSidebar/SidebarMargin/SidebarVBox/CategoryHint") as Label
@onready var category_button_vbox: VBoxContainer = get_node_or_null("CenterContainer/Panel/VBoxContainer/BodyMargin/BodyHBox/LeftSidebar/SidebarMargin/SidebarVBox/ButtonVBox") as VBoxContainer
@onready var summary_panel: PanelContainer = get_node_or_null("CenterContainer/Panel/VBoxContainer/BodyMargin/BodyHBox/RightContent/SummaryPanel") as PanelContainer
@onready var summary_title_label: Label = get_node_or_null("CenterContainer/Panel/VBoxContainer/BodyMargin/BodyHBox/RightContent/SummaryPanel/SummaryMargin/SummaryVBox/SummaryHeader/SummaryTitle") as Label
@onready var summary_updated_label: Label = get_node_or_null("CenterContainer/Panel/VBoxContainer/BodyMargin/BodyHBox/RightContent/SummaryPanel/SummaryMargin/SummaryVBox/SummaryHeader/SummaryUpdatedLabel") as Label
@onready var summary_total_label: Label = get_node_or_null("CenterContainer/Panel/VBoxContainer/BodyMargin/BodyHBox/RightContent/SummaryPanel/SummaryMargin/SummaryVBox/SummaryStatsRow/TotalChip/TotalLabel") as Label
@onready var summary_bond_label: Label = get_node_or_null("CenterContainer/Panel/VBoxContainer/BodyMargin/BodyHBox/RightContent/SummaryPanel/SummaryMargin/SummaryVBox/SummaryStatsRow/BondChip/BondLabel") as Label
@onready var summary_decay_label: Label = get_node_or_null("CenterContainer/Panel/VBoxContainer/BodyMargin/BodyHBox/RightContent/SummaryPanel/SummaryMargin/SummaryVBox/SummaryStatsRow/DecayChip/DecayLabel") as Label
@onready var summary_label: Label = get_node_or_null("CenterContainer/Panel/VBoxContainer/BodyMargin/BodyHBox/RightContent/SummaryPanel/SummaryMargin/SummaryVBox/SummaryLabel") as Label
@onready var scroll_container: ScrollContainer = $CenterContainer/Panel/VBoxContainer/BodyMargin/BodyHBox/RightContent/ContentScroll
@onready var memory_list_container: VBoxContainer = $CenterContainer/Panel/VBoxContainer/BodyMargin/BodyHBox/RightContent/ContentScroll/ContentVBox/MemoryListContainer
@onready var empty_state_card: PanelContainer = $CenterContainer/Panel/VBoxContainer/BodyMargin/BodyHBox/RightContent/ContentScroll/ContentVBox/EmptyStateCard
@onready var empty_state_desc: Label = $CenterContainer/Panel/VBoxContainer/BodyMargin/BodyHBox/RightContent/ContentScroll/ContentVBox/EmptyStateCard/EmptyStateMargin/EmptyStateVBox/EmptyStateDesc

const MEMORY_ITEM_SCENE: PackedScene = preload("res://scenes/ui/archive/archive_memory_item.tscn")
const POPUP_VIEWPORT_MARGIN: Vector2 = Vector2(72, 72)
const BASE_MEMORY_CATEGORY_ORDER: Array[String] = ["core", "emotion", "habit", "bond"]
const STORY_MEMORY_CATEGORY_KEY := "story"
const MEMORY_CATEGORY_ORDER: Array[String] = ["core", "emotion", "habit", "bond", "story"]
const MEMORY_CATEGORY_CONFIG := {
	"core": {
		"title": "核心记忆",
		"badge": "CORE",
		"tab": "核心",
		"hint": "稳定信息与长期边界",
		"desc": "记录角色最稳定、最核心的印象。",
		"empty_desc": "继续聊天、推进剧情或触发关键互动后，这里会整理出最稳定的核心印象。",
		"accent": Color("#d96b7f")
	},
	"emotion": {
		"title": "情绪记忆",
		"badge": "EMOTION",
		"tab": "情绪",
		"hint": "情绪触发与安抚方式",
		"desc": "保留情绪波动与当下感受。",
		"empty_desc": "当对话触发明显情绪波动时，这里会记录角色对你的即时情绪记忆。",
		"accent": Color("#4f8fd8")
	},
	"habit": {
		"title": "习惯记忆",
		"badge": "HABIT",
		"tab": "习惯",
		"hint": "日常偏好与互动习惯",
		"desc": "沉淀日常偏好、习惯与反应。",
		"empty_desc": "随着陪伴和互动累积，这里会慢慢沉淀她对你形成的习惯性印象。",
		"accent": Color("#d86a5f")
	},
	"bond": {
		"title": "羁绊记忆",
		"badge": "BOND",
		"tab": "羁绊",
		"hint": "共同经历与关系节点",
		"desc": "标记推动关系变化的重要片段。",
		"empty_desc": "当关系推进到关键节点时，这里会收录真正改变你们距离的重要记忆。",
		"accent": Color("#c9a33d")
	},
	"story": {
		"title": "故事记忆",
		"badge": "STORY",
		"tab": "故事",
		"hint": "固定剧情与世界事件",
		"desc": "单独归档固定剧情与世界事件，不混入玩家专属记忆。",
		"empty_desc": "完成固定剧情后，这里会单独整理剧情推进、地点事件与世界状态。",
		"accent": Color("#6f8f72")
	}
}

var _panel_tween: Tween = null
var _desktop_pet_mode: bool = false
var _panel_design_size: Vector2 = Vector2(960, 540)
var _memory_data: Dictionary = {"core": [], "emotion": [], "habit": [], "bond": [], "story": []}
var _current_memory_tab: String = "core"
var _category_button_normal_styles: Dictionary = {}
var _category_button_active_styles: Dictionary = {}


func _ready() -> void:
	close_btn.pressed.connect(_on_close_pressed)
	background_panel.gui_input.connect(_on_background_gui_input)
	resized.connect(_on_panel_resized)
	_ensure_story_tab_button()
	for category_key in MEMORY_CATEGORY_ORDER:
		var button: Button = _get_memory_tab_button(category_key)
		if button == null:
			continue
		_category_button_normal_styles[category_key] = button.get_theme_stylebox("normal")
		_category_button_active_styles[category_key] = button.get_theme_stylebox("hover")
		button.pressed.connect(func(tab_key := category_key):
			_current_memory_tab = tab_key
			_refresh_memory_view()
		)
	if panel_root.custom_minimum_size.x > 0.0 and panel_root.custom_minimum_size.y > 0.0:
		_panel_design_size = panel_root.custom_minimum_size
	elif panel_root.size.x > 0.0 and panel_root.size.y > 0.0:
		_panel_design_size = panel_root.size
	hide()


func show_panel(char_id: String = "") -> void:
	_desktop_pet_mode = false
	_apply_mode_layout()
	var target_char_id := char_id
	if target_char_id == "" and GameDataManager.config and GameDataManager.config.current_character_id != "":
		target_char_id = GameDataManager.config.current_character_id
	if target_char_id == "":
		target_char_id = "luna"

	_load_memory_archive(target_char_id)
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
	call_deferred("_update_popup_layout")

func show_desktop_pet_panel() -> void:
	_desktop_pet_mode = true
	_apply_mode_layout()
	_load_desktop_pet_memory_archive()
	_update_popup_layout()
	show()
	background_panel.modulate.a = 0.0
	panel_root.modulate.a = 0.0
	panel_root.scale = Vector2(0.97, 0.97)
	_kill_panel_tween()
	_panel_tween = create_tween()
	_panel_tween.set_parallel(true)
	_panel_tween.tween_property(panel_root, "modulate:a", 1.0, 0.18)
	_panel_tween.tween_property(panel_root, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	call_deferred("_update_popup_layout")


func _load_memory_archive(char_id: String) -> void:
	var mem_path = GameDataManager.get_character_save_path("player_memory.json", char_id)
	var mems = {"core": [], "emotion": [], "habit": [], "bond": [], "story": []}
	if FileAccess.file_exists(mem_path):
		var file = FileAccess.open(mem_path, FileAccess.READ)
		var content = file.get_as_text()
		var json = JSON.new()
		if json.parse(content) == OK and json.data is Dictionary:
			var data = json.data
			for key in BASE_MEMORY_CATEGORY_ORDER:
				if data.has(key) and data[key] is Array:
					mems[key] = _filter_player_archive_memories(data[key])
	mems[STORY_MEMORY_CATEGORY_KEY] = _load_story_archive_items(char_id)
	_memory_data = mems
	_set_story_tab_visible(true)
	if not MEMORY_CATEGORY_ORDER.has(_current_memory_tab):
		_current_memory_tab = "core"
	_refresh_memory_view()


func _refresh_memory_view() -> void:
	for child in memory_list_container.get_children():
		child.queue_free()

	_update_memory_tab_buttons()
	var config: Dictionary = MEMORY_CATEGORY_CONFIG.get(_current_memory_tab, MEMORY_CATEGORY_CONFIG["core"])
	var current_items: Array = _memory_data.get(_current_memory_tab, [])
	var accent_color: Color = config.get("accent", Color.WHITE)
	_apply_summary_style(accent_color)
	if category_title != null:
		category_title.text = str(config.get("title", "记忆分类"))
		category_title.add_theme_color_override("font_color", accent_color.darkened(0.38))
	if category_hint != null:
		category_hint.text = str(config.get("hint", "切换不同记忆分类，只看当前这一类的归档内容。"))
		category_hint.add_theme_color_override("font_color", accent_color.darkened(0.18))
	if summary_title_label != null:
		summary_title_label.text = "%s · %d 条" % [str(config.get("badge", "")), current_items.size()]
		summary_title_label.add_theme_color_override("font_color", accent_color.darkened(0.18))
	if summary_updated_label != null:
		summary_updated_label.text = "最近更新 · %s" % _get_latest_memory_timestamp(current_items)
	if summary_total_label != null:
		summary_total_label.text = "总数 %d" % current_items.size()
	if summary_bond_label != null:
		summary_bond_label.text = "羁绊 %d" % _count_bond_memories(current_items)
	if summary_decay_label != null:
		summary_decay_label.text = "衰减 %d" % _count_decaying_memories(current_items)
	if summary_label != null:
		summary_label.text = _build_memory_summary(_current_memory_tab, current_items)
	for item_data in current_items:
		var item: PanelContainer = _create_memory_item(item_data, accent_color, _current_memory_tab)
		memory_list_container.add_child(item)

	var has_sections: bool = memory_list_container.get_child_count() > 0
	empty_state_card.visible = not has_sections
	if not has_sections:
		empty_state_desc.text = str(config.get("empty_desc", "继续聊天、推进剧情或触发关键互动后，这里会按分类整理角色对你的记忆。"))

func _load_desktop_pet_memory_archive() -> void:
	var mems := {"core": [], "emotion": [], "habit": [], "bond": [], "story": []}
	var pet_memory_manager = GameDataManager.desktop_pet_memory_manager if GameDataManager else null
	if pet_memory_manager != null and pet_memory_manager.memories is Dictionary:
		for key in BASE_MEMORY_CATEGORY_ORDER:
			mems[key] = _filter_player_archive_memories(pet_memory_manager.memories.get(key, []))
	_memory_data = mems
	_set_story_tab_visible(false)
	if _current_memory_tab == STORY_MEMORY_CATEGORY_KEY:
		_current_memory_tab = "core"
	_refresh_memory_view()
	if empty_state_card.visible:
		empty_state_desc.text = "继续和桌宠聊天、陪伴互动后，这里会逐步沉淀只属于桌宠的独立记忆。"

func _create_memory_item(item_data, accent_color: Color, category_key: String) -> PanelContainer:
	var item: PanelContainer = MEMORY_ITEM_SCENE.instantiate() as PanelContainer
	var time_label: Label = item.get_node_or_null("Margin/ItemVBox/HeaderRow/TimePanel/TimeLabel") as Label
	var source_value_label: Label = item.get_node_or_null("Margin/ItemVBox/HeaderRow/SourceVBox/SourceTagPanel/SourceTagMargin/SourceValue") as Label
	var source_tag_panel: PanelContainer = item.get_node_or_null("Margin/ItemVBox/HeaderRow/SourceVBox/SourceTagPanel") as PanelContainer
	var content_label: RichTextLabel = item.get_node_or_null("Margin/ItemVBox/ContentLabel") as RichTextLabel
	var meta_label: Label = item.get_node_or_null("Margin/ItemVBox/MetaLabel") as Label
	_apply_memory_item_style(item, accent_color, false)
	_apply_source_tag_style(source_tag_panel, accent_color)

	var text: String = ""
	var timestamp: String = ""
	var is_bond: bool = false
	var source_text: String = ""
	var decay: float = 0.0

	if item_data is Dictionary:
		text = str(item_data.get("content", ""))
		timestamp = str(item_data.get("story_time", ""))
		if timestamp == "":
			timestamp = str(item_data.get("timestamp", "")).split("T")[0]
		is_bond = bool(item_data.get("is_bond_mark", false))
		source_text = _build_memory_source(item_data, category_key)
		decay = float(item_data.get("decay", 0.0))
	elif item_data is String:
		source_text = _get_default_memory_source(category_key)
		text = item_data
	if time_label != null:
		time_label.add_theme_color_override("font_color", accent_color.darkened(0.08))
		time_label.text = _format_memory_date(timestamp)
	if source_value_label != null:
		source_value_label.add_theme_color_override("font_color", accent_color.darkened(0.2))
		source_value_label.text = source_text
	if content_label != null:
		content_label.add_theme_color_override("default_color", Color(0.16, 0.18, 0.18, 1.0))
		content_label.text = text if text != "" else "暂无内容"
	if meta_label != null:
		meta_label.hide()

	if meta_label != null and is_bond:
		meta_label.text = "关键剧情记忆" if category_key == STORY_MEMORY_CATEGORY_KEY else "关键羁绊记忆"
		meta_label.add_theme_color_override("font_color", accent_color.darkened(0.22))
		meta_label.show()
		_apply_memory_item_style(item, accent_color, true)
	elif meta_label != null and decay > 0.0:
		meta_label.text = "遗忘 %d%% · 该记忆正在缓慢衰减，可以通过互动重新加深印象。" % int(decay)
		meta_label.add_theme_color_override("font_color", Color("#b97a6d"))
		meta_label.show()

	return item

func _make_panel_style(bg_color: Color, border_color: Color, radius: int = 18, border_width: int = 1, shadow_alpha: float = 0.0) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.border_color = border_color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_right = radius
	style.corner_radius_bottom_left = radius
	if shadow_alpha > 0.0:
		style.shadow_color = Color(0.08, 0.15, 0.16, shadow_alpha)
		style.shadow_size = 10
		style.shadow_offset = Vector2(0, 3)
	return style

func _apply_memory_item_style(item: PanelContainer, accent_color: Color, is_highlighted: bool) -> void:
	var bg_color := accent_color.lightened(0.88) if is_highlighted else Color(0.994, 0.998, 0.998, 0.98)
	var border_color := accent_color.lightened(0.34) if is_highlighted else Color(0.79, 0.88, 0.89, 0.72)
	var style := _make_panel_style(bg_color, border_color, 16, 1, 0.1 if is_highlighted else 0.05)
	style.border_width_left = 4
	style.border_color = border_color
	item.add_theme_stylebox_override("panel", style)

func _apply_source_tag_style(source_tag_panel: PanelContainer, accent_color: Color) -> void:
	if source_tag_panel == null:
		return
	var style := _make_panel_style(accent_color.lightened(0.82), accent_color.lightened(0.52), 12, 1, 0.0)
	source_tag_panel.add_theme_stylebox_override("panel", style)

func _apply_summary_style(accent_color: Color) -> void:
	if summary_panel != null:
		summary_panel.add_theme_stylebox_override("panel", _make_panel_style(accent_color.lightened(0.82), accent_color.lightened(0.48), 22, 1, 0.06))
	if summary_total_label != null:
		summary_total_label.add_theme_color_override("font_color", accent_color.darkened(0.22))
	if summary_bond_label != null:
		summary_bond_label.add_theme_color_override("font_color", accent_color.darkened(0.22))
	if summary_decay_label != null:
		summary_decay_label.add_theme_color_override("font_color", accent_color.darkened(0.22))

func _format_memory_date(timestamp: String) -> String:
	var clean_timestamp: String = timestamp.strip_edges()
	if clean_timestamp == "":
		return "未记录"
	if " " in clean_timestamp:
		return clean_timestamp.split(" ")[0]
	return clean_timestamp


func _build_memory_summary(category_key: String, items: Array) -> String:
	var config: Dictionary = MEMORY_CATEGORY_CONFIG.get(category_key, {})
	if items.is_empty():
		return str(config.get("desc", ""))
	var bond_count: int = _count_bond_memories(items)
	var decaying_count: int = _count_decaying_memories(items)
	var parts: Array[String] = [
		str(config.get("desc", "")),
		"当前共 %d 条记忆" % items.size()
	]
	if bond_count > 0:
		parts.append("其中 %d 条属于关键羁绊节点" % bond_count)
	if decaying_count > 0:
		parts.append("%d 条存在遗忘衰减" % decaying_count)
	return "，".join(parts) + "。"


func _filter_player_archive_memories(raw_items: Variant) -> Array:
	var results: Array = []
	if not raw_items is Array:
		return results
	for item in raw_items:
		if item is String:
			results.append(item)
			continue
		if not item is Dictionary:
			continue
		if str(item.get("source_type", "")) == "story_script":
			continue
		var scope := str(item.get("memory_scope", "player_shared")).strip_edges()
		if scope == "" or scope == "player_shared":
			results.append(item)
	return results


func _load_story_archive_items(char_id: String) -> Array:
	var story_path = GameDataManager.get_character_save_path("story_memory.json", char_id)
	if not FileAccess.file_exists(story_path):
		return []
	var file = FileAccess.open(story_path, FileAccess.READ)
	var content = file.get_as_text()
	file.close()
	var json = JSON.new()
	if json.parse(content) != OK or not json.data is Dictionary:
		return []
	var data: Dictionary = json.data
	var items = data.get(STORY_MEMORY_CATEGORY_KEY, data.get("items", []))
	return items if items is Array else []


func _build_memory_source(item_data: Dictionary, category_key: String) -> String:
	var candidate_keys: Array[String] = [
		"memory_source",
		"source_label",
		"source",
		"source_text",
		"source_type",
		"extracted_from",
		"origin",
		"origin_type",
		"event_type",
		"trigger_type"
	]
	for key in candidate_keys:
		var value: String = str(item_data.get(key, "")).strip_edges()
		if value != "":
			return value
	var story_time: String = str(item_data.get("story_time", "")).strip_edges()
	if story_time != "":
		return "剧情阶段 · %s" % story_time
	return _get_default_memory_source(category_key)


func _get_default_memory_source(category_key: String) -> String:
	match category_key:
		"core":
			return "长期对话提取"
		"emotion":
			return "情绪波动提取"
		"habit":
			return "互动习惯提取"
		"bond":
			return "关键节点提取"
		"story":
			return "固定剧情归档"
		_:
			return "记忆归档"


func _get_memory_tab_button(category_key: String) -> Button:
	var node_name: String = "%sBtn" % category_key.capitalize()
	return category_button_vbox.get_node_or_null(node_name) as Button


func _ensure_story_tab_button() -> void:
	if category_button_vbox == null or _get_memory_tab_button(STORY_MEMORY_CATEGORY_KEY) != null:
		return
	var template := _get_memory_tab_button("bond")
	if template == null:
		return
	var story_button := template.duplicate() as Button
	story_button.name = "StoryBtn"
	story_button.text = "故事 · 0"
	category_button_vbox.add_child(story_button)


func _set_story_tab_visible(is_visible: bool) -> void:
	var story_button := _get_memory_tab_button(STORY_MEMORY_CATEGORY_KEY)
	if story_button != null:
		story_button.visible = is_visible


func _update_memory_tab_buttons() -> void:
	for category_key in MEMORY_CATEGORY_ORDER:
		var button: Button = _get_memory_tab_button(category_key)
		if button == null:
			continue
		if category_key == STORY_MEMORY_CATEGORY_KEY and _desktop_pet_mode:
			button.visible = false
			continue
		var config: Dictionary = MEMORY_CATEGORY_CONFIG.get(category_key, {})
		var count: int = int((_memory_data.get(category_key, []) as Array).size())
		button.text = "%s · %d" % [str(config.get("tab", category_key)), count]
		var is_current: bool = category_key == _current_memory_tab
		var accent_color: Color = config.get("accent", Color("#5fb8ae"))
		var normal_style: StyleBox = _make_panel_style(accent_color.lightened(0.84), accent_color.lightened(0.54), 16, 1, 0.02) if is_current else _make_panel_style(Color(0.986, 0.994, 0.996, 1.0), Color(0.8, 0.88, 0.9, 0.72), 16, 1, 0.0)
		var active_style: StyleBox = _make_panel_style(accent_color.lightened(0.76), accent_color.lightened(0.34), 16, 1, 0.08)
		button.add_theme_stylebox_override("normal", normal_style)
		button.add_theme_stylebox_override("hover", active_style)
		button.add_theme_stylebox_override("pressed", active_style)
		button.add_theme_color_override("font_color", accent_color.darkened(0.34) if is_current else Color(0.34, 0.31, 0.28, 1.0))
		button.add_theme_font_size_override("font_size", 15 if is_current else 14)


func _count_bond_memories(items: Array) -> int:
	var count: int = 0
	for item_data in items:
		if item_data is Dictionary and bool(item_data.get("is_bond_mark", false)):
			count += 1
	return count


func _count_decaying_memories(items: Array) -> int:
	var count: int = 0
	for item_data in items:
		if item_data is Dictionary and float(item_data.get("decay", 0.0)) > 0.0:
			count += 1
	return count


func _get_latest_memory_timestamp(items: Array) -> String:
	var latest_value: String = ""
	for item_data in items:
		if not item_data is Dictionary:
			continue
		var timestamp: String = str(item_data.get("timestamp", "")).strip_edges()
		if timestamp == "":
			timestamp = str(item_data.get("story_time", "")).strip_edges()
		if timestamp == "":
			continue
		if latest_value == "" or timestamp > latest_value:
			latest_value = timestamp
	if latest_value == "":
		return "暂无"
	return _format_memory_date(latest_value)


func _on_close_pressed() -> void:
	hide_panel()

func hide_panel() -> void:
	if not visible:
		return
	_kill_panel_tween()
	_panel_tween = create_tween()
	_panel_tween.set_parallel(true)
	_panel_tween.tween_property(background_panel, "modulate:a", 0.0, 0.16)
	_panel_tween.tween_property(panel_root, "modulate:a", 0.0, 0.16)
	_panel_tween.tween_property(panel_root, "scale", Vector2(0.97, 0.97), 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_panel_tween.set_parallel(false)
	_panel_tween.tween_callback(hide)

func _on_background_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		hide_panel()

func _on_panel_resized() -> void:
	if visible:
		_update_popup_layout()

func _update_popup_layout() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var target_size: Vector2 = viewport_size
	if _desktop_pet_mode:
		target_size = _panel_design_size
		target_size.x = minf(target_size.x, viewport_size.x - POPUP_VIEWPORT_MARGIN.x)
		target_size.y = minf(target_size.y, viewport_size.y - POPUP_VIEWPORT_MARGIN.y)
	target_size.x = maxf(target_size.x, 0.0)
	target_size.y = maxf(target_size.y, 0.0)
	panel_root.custom_minimum_size = target_size
	panel_root.size = target_size
	if content_root != null:
		content_root.custom_minimum_size = Vector2.ZERO
	panel_root.pivot_offset = target_size * 0.5

func _apply_mode_layout() -> void:
	if _desktop_pet_mode:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		background_panel.hide()
		background_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if center_container != null:
			center_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
			center_container.show()
	else:
		mouse_filter = Control.MOUSE_FILTER_STOP
		background_panel.show()
		background_panel.mouse_filter = Control.MOUSE_FILTER_STOP
		if center_container != null:
			center_container.mouse_filter = Control.MOUSE_FILTER_STOP
			center_container.show()

func refresh_layout() -> void:
	_update_popup_layout()

func _kill_panel_tween() -> void:
	if _panel_tween != null:
		_panel_tween.kill()
		_panel_tween = null
