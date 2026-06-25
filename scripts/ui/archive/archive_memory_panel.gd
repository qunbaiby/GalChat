extends Control

@onready var background_panel: Panel = $Background
@onready var center_container: CenterContainer = $CenterContainer
@onready var panel_root: Panel = $CenterContainer/Panel
@onready var content_root: VBoxContainer = $CenterContainer/Panel/VBoxContainer
@onready var close_btn: Button = $CenterContainer/Panel/CloseButton
@onready var top_bar: Panel = $CenterContainer/Panel/VBoxContainer/TopBar
@onready var memory_list_container: VBoxContainer = $CenterContainer/Panel/VBoxContainer/BodyMargin/ScrollContainer/ContentVBox/MemoryListContainer
@onready var empty_state_card: PanelContainer = $CenterContainer/Panel/VBoxContainer/BodyMargin/ScrollContainer/ContentVBox/EmptyStateCard
@onready var empty_state_desc: Label = $CenterContainer/Panel/VBoxContainer/BodyMargin/ScrollContainer/ContentVBox/EmptyStateCard/EmptyStateMargin/EmptyStateVBox/EmptyStateDesc

const MEMORY_SECTION_SCENE: PackedScene = preload("res://scenes/ui/archive/archive_memory_section.tscn")
const MEMORY_ITEM_SCENE: PackedScene = preload("res://scenes/ui/archive/archive_memory_item.tscn")
const POPUP_MIN_SIZE: Vector2 = Vector2(1040, 660)

var _panel_tween: Tween = null
var _desktop_pet_mode: bool = false


func _ready() -> void:
	close_btn.pressed.connect(_on_close_pressed)
	background_panel.gui_input.connect(_on_background_gui_input)
	resized.connect(_on_panel_resized)
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


func _load_memory_archive(char_id: String) -> void:
	var mem_path = GameDataManager.get_character_save_path("player_memory.json", char_id)
	var mems = {"core": [], "emotion": [], "habit": [], "bond": []}
	if FileAccess.file_exists(mem_path):
		var file = FileAccess.open(mem_path, FileAccess.READ)
		var content = file.get_as_text()
		var json = JSON.new()
		if json.parse(content) == OK and json.data is Dictionary:
			var data = json.data
			for key in mems.keys():
				if data.has(key) and data[key] is Array:
					mems[key] = data[key]
	_update_memory_display(mems)


func _update_memory_display(mems: Dictionary) -> void:
	for child in memory_list_container.get_children():
		child.queue_free()

	_add_memory_category("核心记忆", "CORE", "记录角色最稳定、最核心的印象。", mems.get("core", []), Color("#d96b7f"))
	_add_memory_category("情绪记忆", "EMOTION", "保留情绪波动与当下感受。", mems.get("emotion", []), Color("#4f8fd8"))
	_add_memory_category("习惯记忆", "HABIT", "沉淀日常偏好、习惯与反应。", mems.get("habit", []), Color("#d86a5f"))
	_add_memory_category("羁绊记忆", "BOND", "标记推动关系变化的重要片段。", mems.get("bond", []), Color("#c9a33d"))

	var has_sections: bool = memory_list_container.get_child_count() > 0
	empty_state_card.visible = not has_sections
	if not has_sections:
		empty_state_desc.text = "继续聊天、推进剧情或触发关键互动后，这里会按分类整理角色对你的记忆。"

func _load_desktop_pet_memory_archive() -> void:
	var mems := {"core": [], "emotion": [], "habit": [], "bond": []}
	var pet_memory_manager = GameDataManager.desktop_pet_memory_manager if GameDataManager else null
	if pet_memory_manager != null and pet_memory_manager.memories is Dictionary:
		mems = pet_memory_manager.memories.duplicate(true)
	_update_memory_display(mems)
	if empty_state_card.visible:
		empty_state_desc.text = "继续和桌宠聊天、陪伴互动后，这里会逐步沉淀只属于桌宠的独立记忆。"


func _add_memory_category(title: String, badge_text: String, desc: String, items: Array, accent_color: Color) -> void:
	if items.is_empty():
		return

	var section: PanelContainer = MEMORY_SECTION_SCENE.instantiate() as PanelContainer
	var badge_panel: PanelContainer = section.get_node("Margin/ContentVBox/HeaderHBox/BadgePanel")
	var badge_label: Label = section.get_node("Margin/ContentVBox/HeaderHBox/BadgePanel/BadgeLabel")
	var title_label: Label = section.get_node("Margin/ContentVBox/HeaderHBox/TextVBox/TitleLabel")
	var desc_label: Label = section.get_node("Margin/ContentVBox/HeaderHBox/TextVBox/DescLabel")
	var count_label: Label = section.get_node("Margin/ContentVBox/HeaderHBox/CountLabel")
	var items_vbox: VBoxContainer = section.get_node("Margin/ContentVBox/ItemsVBox")

	title_label.text = title
	desc_label.text = desc
	badge_label.text = badge_text
	count_label.text = "%d 条" % items.size()
	_apply_badge_style(badge_panel, badge_label, accent_color)

	for item_data in items:
		var item: PanelContainer = _create_memory_item(item_data, accent_color)
		items_vbox.add_child(item)

	memory_list_container.add_child(section)

func _create_memory_item(item_data, accent_color: Color) -> PanelContainer:
	var item: PanelContainer = MEMORY_ITEM_SCENE.instantiate() as PanelContainer
	var time_dot: Label = item.get_node("Margin/MainHBox/MetaVBox/TimeDot")
	var time_label: Label = item.get_node("Margin/MainHBox/MetaVBox/TimeLabel")
	var content_label: RichTextLabel = item.get_node("Margin/MainHBox/ContentVBox/ContentLabel")
	var meta_label: Label = item.get_node("Margin/MainHBox/ContentVBox/MetaLabel")
	var tag_panel: PanelContainer = item.get_node("Margin/MainHBox/TagPanel")
	var tag_label: Label = item.get_node("Margin/MainHBox/TagPanel/TagLabel")

	var text: String = ""
	var timestamp: String = ""
	var is_bond: bool = false
	var decay: float = 0.0

	if item_data is Dictionary:
		text = str(item_data.get("content", ""))
		timestamp = str(item_data.get("story_time", ""))
		if timestamp == "":
			timestamp = str(item_data.get("timestamp", "")).split("T")[0]
		is_bond = bool(item_data.get("is_bond_mark", false))
		decay = float(item_data.get("decay", 0.0))
	elif item_data is String:
		text = item_data

	time_dot.add_theme_color_override("font_color", accent_color)
	time_label.text = _format_memory_date(timestamp)
	content_label.text = text if text != "" else "暂无内容"

	if is_bond:
		tag_panel.show()
		tag_label.text = "羁绊印记"
		_apply_tag_style(tag_panel, tag_label, Color("#c9a33d"))
		_apply_item_highlight(item, Color("#ead8a5"))
	elif decay > 0.0:
		tag_panel.show()
		tag_label.text = "遗忘 %d%%" % int(decay)
		_apply_tag_style(tag_panel, tag_label, Color("#b97a6d"))
		meta_label.text = "该记忆正在缓慢衰减，可以通过互动重新加深印象。"
		meta_label.show()
	else:
		tag_panel.hide()
		meta_label.hide()

	return item

func _apply_badge_style(panel: PanelContainer, label: Label, accent_color: Color) -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = accent_color.lightened(0.38)
	style.bg_color.a = 0.2
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = accent_color.darkened(0.08)
	style.border_color.a = 0.35
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_right = 12
	style.corner_radius_bottom_left = 12
	panel.add_theme_stylebox_override("panel", style)
	label.add_theme_color_override("font_color", accent_color.darkened(0.18))

func _apply_tag_style(panel: PanelContainer, label: Label, accent_color: Color) -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = accent_color.lightened(0.4)
	style.bg_color.a = 0.18
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = accent_color.darkened(0.08)
	style.border_color.a = 0.32
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_right = 12
	style.corner_radius_bottom_left = 12
	panel.add_theme_stylebox_override("panel", style)
	label.add_theme_color_override("font_color", accent_color.darkened(0.18))

func _apply_item_highlight(item: PanelContainer, accent_border: Color) -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.992, 0.985, 0.966, 1)
	style.border_width_left = 2
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = accent_border
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_right = 14
	style.corner_radius_bottom_left = 14
	item.add_theme_stylebox_override("panel", style)

func _format_memory_date(timestamp: String) -> String:
	var clean_timestamp: String = timestamp.strip_edges()
	if clean_timestamp == "":
		return "未记录"
	if " " in clean_timestamp:
		return clean_timestamp.split(" ")[0]
	return clean_timestamp


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
	var target_size: Vector2 = POPUP_MIN_SIZE
	if _desktop_pet_mode:
		target_size = viewport_size
	else:
		target_size.x = minf(target_size.x, viewport_size.x - 72.0)
		target_size.y = minf(target_size.y, viewport_size.y - 72.0)
	panel_root.custom_minimum_size = target_size
	panel_root.size = target_size
	if content_root != null:
		content_root.custom_minimum_size = target_size
		content_root.size = target_size
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

func _kill_panel_tween() -> void:
	if _panel_tween != null:
		_panel_tween.kill()
		_panel_tween = null
