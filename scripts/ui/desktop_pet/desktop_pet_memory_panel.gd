extends PanelContainer

signal back_requested

const MEMORY_SECTION_SCENE: PackedScene = preload("res://scenes/ui/archive/archive_memory_section.tscn")
const MEMORY_ITEM_SCENE: PackedScene = preload("res://scenes/ui/archive/archive_memory_item.tscn")

@onready var back_btn: Button = $Margin/VBox/TopBar/BackButton
@onready var memory_list_container: VBoxContainer = $Margin/VBox/Scroll/ContentVBox/MemoryListContainer
@onready var empty_state_card: PanelContainer = $Margin/VBox/Scroll/ContentVBox/EmptyStateCard
@onready var empty_state_desc: Label = $Margin/VBox/Scroll/ContentVBox/EmptyStateCard/EmptyStateMargin/EmptyStateVBox/EmptyStateDesc

func _ready() -> void:
    hide()
    if is_instance_valid(back_btn) and not back_btn.pressed.is_connected(_on_back_pressed):
        back_btn.pressed.connect(_on_back_pressed)

func show_panel() -> void:
    _refresh_view()
    show()

func hide_panel() -> void:
    hide()

func _on_back_pressed() -> void:
    back_requested.emit()

func _refresh_view() -> void:
    for child in memory_list_container.get_children():
        child.queue_free()

    var mems := {"core": [], "emotion": [], "habit": [], "bond": []}
    var pet_memory_manager = GameDataManager.desktop_pet_memory_manager if GameDataManager else null
    if pet_memory_manager != null:
        var source_memories = pet_memory_manager.memories
        if source_memories is Dictionary:
            mems = source_memories.duplicate(true)

    _add_memory_category("核心记忆", "CORE", "记录桌宠最稳定、最核心的长期印象。", mems.get("core", []), Color("#d96b7f"))
    _add_memory_category("情绪记忆", "EMOTION", "保留玩家互动带来的情绪波动与感受。", mems.get("emotion", []), Color("#4f8fd8"))
    _add_memory_category("习惯记忆", "HABIT", "沉淀桌宠观察到的陪伴习惯与偏好。", mems.get("habit", []), Color("#d86a5f"))
    _add_memory_category("羁绊记忆", "BOND", "标记桌宠与玩家之间的重要陪伴片段。", mems.get("bond", []), Color("#c9a33d"))

    var has_sections := memory_list_container.get_child_count() > 0
    empty_state_card.visible = not has_sections
    if not has_sections:
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

    var text := ""
    var timestamp := ""
    var is_bond := false
    var decay := 0.0

    if item_data is Dictionary:
        text = str(item_data.get("content", ""))
        timestamp = str(item_data.get("real_datetime", "")).replace("T", " ")
        if timestamp == "":
            timestamp = str(item_data.get("timestamp", "")).replace("T", " ")
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
        meta_label.text = "这条桌宠记忆正在逐渐淡化，可以通过继续互动重新加深。"
        meta_label.show()
    else:
        tag_panel.hide()
        meta_label.hide()

    return item

func _apply_badge_style(panel: PanelContainer, label: Label, accent_color: Color) -> void:
    var style := StyleBoxFlat.new()
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
    var style := StyleBoxFlat.new()
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
    var style := StyleBoxFlat.new()
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
    var clean_timestamp := timestamp.strip_edges()
    if clean_timestamp == "":
        return "未记录"
    if " " in clean_timestamp:
        var parts := clean_timestamp.split(" ")
        if parts.size() >= 2:
            return "%s\n%s" % [parts[0], parts[1].substr(0, 5)]
    return clean_timestamp
