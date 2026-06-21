extends Control

static var _grayscale_texture_cache: Dictionary = {}

signal back_requested
signal apply_requested(bg_id: String)

const ITEM_SCENE = preload("res://scenes/ui/main/background_setting_item.tscn")
const THUMB_TARGET_SIZE: Vector2 = Vector2(116, 92)
const PREVIEW_CARD_PADDING: Vector2 = Vector2(24, 24)

@onready var title_label: Label = $PanelRoot/MainMargin/RootHBox/SidebarPanel/SidebarMargin/SidebarVBox/HeaderHBox/TitleLabel
@onready var thumb_grid: GridContainer = $PanelRoot/MainMargin/RootHBox/SidebarPanel/SidebarMargin/SidebarVBox/ThumbScroll/ThumbGrid
@onready var preview_card: PanelContainer = $PanelRoot/MainMargin/RootHBox/PreviewPanel/PreviewMargin/PreviewVBox/PreviewCard
@onready var preview_host: Control = $PanelRoot/MainMargin/RootHBox/PreviewPanel/PreviewMargin/PreviewVBox/PreviewCard/PreviewMargin/PreviewHost
@onready var description_label: Label = $PanelRoot/MainMargin/RootHBox/PreviewPanel/PreviewMargin/PreviewVBox/DescriptionPanel/DescriptionMargin/DescriptionLabel
@onready var apply_button: Button = $PanelRoot/MainMargin/RootHBox/PreviewPanel/PreviewMargin/PreviewVBox/BottomHBox/ApplyButton
@onready var back_button: Button = $PanelRoot/MainMargin/RootHBox/SidebarPanel/SidebarMargin/SidebarVBox/HeaderHBox/BackButton
@onready var dimmer: TextureRect = $Dimmer

var _entries: Array = []
var _active_bg_id: String = ""
var _current_index: int = 0
var _panel_tween: Tween = null
var _grid_items: Array[Button] = []
var _preview_item: Button = null
var _preview_item_reference_size: Vector2 = Vector2.ZERO

func _ready() -> void:
    visible = false
    back_button.pressed.connect(hide_panel)
    apply_button.pressed.connect(_emit_apply)
    dimmer.gui_input.connect(_on_dimmer_gui_input)
    title_label.text = "主页背景设定"

func show_panel(entries: Array, active_bg_id: String) -> void:
    _entries = []
    for entry in entries:
        if entry is Dictionary:
            _entries.append(entry.duplicate(true))
    _active_bg_id = active_bg_id
    _current_index = 0
    for i in range(_entries.size()):
        if str(_entries[i].get("id", "")) == _active_bg_id:
            _current_index = i
            break

    _rebuild_grid()
    _refresh_preview()
    _refresh_dimmer()
    visible = true
    modulate.a = 0.0
    if _panel_tween:
        _panel_tween.kill()
    _panel_tween = create_tween()
    _panel_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    _panel_tween.tween_property(self, "modulate:a", 1.0, 0.24)

func hide_panel() -> void:
    if not visible:
        return
    if _panel_tween:
        _panel_tween.kill()
    _panel_tween = create_tween()
    _panel_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
    _panel_tween.tween_property(self, "modulate:a", 0.0, 0.2)
    _panel_tween.tween_callback(func():
        visible = false
        back_requested.emit()
    )

func set_active_bg_id(bg_id: String) -> void:
    _active_bg_id = bg_id
    _refresh_grid_selection()
    _refresh_preview()
    _refresh_dimmer()

func _emit_apply() -> void:
    if _entries.is_empty():
        return
    var entry: Dictionary = _entries[_current_index]
    var is_current_active: bool = str(entry.get("id", "")) == _active_bg_id
    var is_current_unlocked: bool = bool(entry.get("unlocked", true))
    if is_current_active or not is_current_unlocked:
        return
    apply_requested.emit(str(entry.get("id", "")))

func _rebuild_grid() -> void:
    _clear_grid()
    _grid_items.clear()
    if _entries.is_empty():
        return

    for i in range(_entries.size()):
        var entry: Dictionary = _entries[i]
        var item: Button = _build_grid_item(entry, i)
        var thumb_host: Control = Control.new()
        thumb_host.custom_minimum_size = THUMB_TARGET_SIZE
        thumb_host.clip_contents = true
        thumb_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
        thumb_grid.add_child(thumb_host)
        thumb_host.add_child(item)
        item.set_anchors_preset(Control.PRESET_FULL_RECT)
        item.offset_left = 0.0
        item.offset_top = 0.0
        item.offset_right = 0.0
        item.offset_bottom = 0.0
        item.set_meta("entry_index", i)
        item.set_meta("entry_data", entry.duplicate(true))
        _grid_items.append(item)

func _build_grid_item(entry: Dictionary, target_index: int) -> Button:
    var item: Button = Button.new()
    item.focus_mode = Control.FOCUS_NONE
    item.custom_minimum_size = THUMB_TARGET_SIZE
    item.clip_contents = true
    item.add_theme_stylebox_override("normal", _make_thumb_style(target_index, entry, false))
    item.add_theme_stylebox_override("hover", _make_thumb_style(target_index, entry, true))
    item.add_theme_stylebox_override("pressed", _make_thumb_style(target_index, entry, true))
    item.add_theme_stylebox_override("focus", _make_thumb_style(target_index, entry, true))

    var preview: TextureRect = TextureRect.new()
    preview.set_anchors_preset(Control.PRESET_FULL_RECT)
    preview.offset_left = 4.0
    preview.offset_top = 4.0
    preview.offset_right = -4.0
    preview.offset_bottom = -4.0
    preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var preview_path: String = str(entry.get("preview_path", "")).strip_edges()
    if preview_path != "" and ResourceLoader.exists(preview_path):
        var preview_texture := load(preview_path) as Texture2D
        preview.texture = _make_grayscale_texture(preview_texture) if not bool(entry.get("unlocked", true)) else preview_texture
    item.add_child(preview)

    if not bool(entry.get("unlocked", true)):
        var lock_overlay: ColorRect = ColorRect.new()
        lock_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
        lock_overlay.color = Color(0.04, 0.05, 0.08, 0.38)
        lock_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
        item.add_child(lock_overlay)
    item.tooltip_text = str(entry.get("unlock_condition", "")).strip_edges() if not bool(entry.get("unlocked", true)) else str(entry.get("name", ""))
    item.pressed.connect(func() -> void:
        _select_index(target_index)
    )
    return item

func _clear_grid() -> void:
    for child in thumb_grid.get_children():
        child.queue_free()

func _select_index(new_index: int) -> void:
    if new_index < 0 or new_index >= _entries.size():
        return
    if _current_index == new_index:
        return
    _current_index = new_index
    _refresh_grid_selection()
    _refresh_preview()
    _refresh_dimmer()

func _on_dimmer_gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        hide_panel()

func _refresh_preview() -> void:
    _clear_preview_host()
    if _entries.is_empty():
        description_label.text = "解锁更多主页背景后，可以在这里查看对应说明并应用到大厅。"
        apply_button.disabled = true
        apply_button.text = "应用到大厅"
        return

    var current_entry: Dictionary = _entries[_current_index]
    var is_current_active: bool = str(current_entry.get("id", "")) == _active_bg_id
    var is_current_unlocked: bool = bool(current_entry.get("unlocked", true))
    _preview_item = ITEM_SCENE.instantiate() as Button
    preview_host.add_child(_preview_item)
    if _preview_item.has_method("setup"):
        _preview_item.setup(current_entry, true, is_current_active, is_current_unlocked)
    _set_item_compact_mode(_preview_item, false)
    description_label.text = str(current_entry.get("description", "")).strip_edges()
    _preview_item_reference_size = _get_item_reference_size(_preview_item)
    _sync_preview_container_size(_preview_item_reference_size)
    _fit_item_to_host(_preview_item, preview_host.size if preview_host.size.length() > 1.0 else preview_host.custom_minimum_size, false)
    call_deferred("_refresh_preview_layout")
    apply_button.disabled = is_current_active or not is_current_unlocked
    apply_button.text = "已应用到大厅" if is_current_active else ("尚未解锁" if not is_current_unlocked else "应用到大厅")

func _clear_preview_host() -> void:
    for child in preview_host.get_children():
        child.queue_free()
    _preview_item = null
    _preview_item_reference_size = Vector2.ZERO

func _fit_item_to_host(item: Control, host_size: Vector2, compact: bool) -> void:
    if item == null:
        return
    var fit_size: Vector2 = host_size
    if fit_size.x <= 1.0 or fit_size.y <= 1.0:
        fit_size = THUMB_TARGET_SIZE if compact else _get_item_reference_size(item)
    var item_size: Vector2 = _get_item_reference_size(item)
    if item_size.x <= 1.0 or item_size.y <= 1.0:
        item_size = THUMB_TARGET_SIZE
    var scale_factor: float = minf(fit_size.x / item_size.x, fit_size.y / item_size.y)
    if compact:
        scale_factor = minf(scale_factor, 0.32)
    else:
        scale_factor = minf(scale_factor, 1.0)
    item.scale = Vector2(scale_factor, scale_factor)
    item.position = Vector2(
        (fit_size.x - item_size.x * scale_factor) * 0.5,
        (fit_size.y - item_size.y * scale_factor) * 0.5
    )

func _set_item_compact_mode(item: Button, compact: bool) -> void:
    if item == null:
        return
    if item.has_method("set_compact_mode"):
        item.set_compact_mode(compact)
        return
    var info_bubble: CanvasItem = item.get_node_or_null("InfoBubble") as CanvasItem
    var state_badge: CanvasItem = item.get_node_or_null("StateBadge") as CanvasItem
    var unlock_bar: CanvasItem = item.get_node_or_null("UnlockConditionBar") as CanvasItem
    if compact:
        if info_bubble:
            info_bubble.hide()
        if state_badge:
            state_badge.hide()
        if unlock_bar:
            unlock_bar.show()
    else:
        if info_bubble:
            info_bubble.show()
        if state_badge:
            state_badge.show()

func _notification(what: int) -> void:
    if what == NOTIFICATION_RESIZED and is_instance_valid(_preview_item):
        _fit_item_to_host(_preview_item, preview_host.size, false)

func _refresh_preview_layout() -> void:
    if is_instance_valid(_preview_item):
        _sync_preview_container_size(_preview_item_reference_size)
        _fit_item_to_host(_preview_item, preview_host.size, false)

func _refresh_dimmer() -> void:
    if dimmer == null:
        return
    if _entries.is_empty() or _current_index < 0 or _current_index >= _entries.size():
        dimmer.texture = null
        return
    var current_entry: Dictionary = _entries[_current_index]
    var preview_path: String = str(current_entry.get("preview_path", "")).strip_edges()
    if preview_path != "" and ResourceLoader.exists(preview_path):
        dimmer.texture = load(preview_path) as Texture2D
    else:
        dimmer.texture = null

func _make_grayscale_texture(source_texture: Texture2D) -> Texture2D:
    if source_texture == null:
        return null
    var cache_key := source_texture.resource_path
    if cache_key == "":
        cache_key = str(source_texture.get_rid().get_id())
    if _grayscale_texture_cache.has(cache_key):
        return _grayscale_texture_cache[cache_key]
    var image := source_texture.get_image()
    if image == null:
        return source_texture
    var gray_image := image.duplicate()
    gray_image.decompress()
    gray_image.convert(Image.FORMAT_RGBA8)
    var width: int = gray_image.get_width()
    var height: int = gray_image.get_height()
    for y in range(height):
        for x in range(width):
            var color: Color = gray_image.get_pixel(x, y)
            var gray: float = color.r * 0.299 + color.g * 0.587 + color.b * 0.114
            gray_image.set_pixel(x, y, Color(gray, gray, gray, color.a))
    var gray_texture := ImageTexture.create_from_image(gray_image)
    _grayscale_texture_cache[cache_key] = gray_texture
    return gray_texture

func _refresh_grid_selection() -> void:
    for item in _grid_items:
        if item == null or not is_instance_valid(item):
            continue
        var target_index: int = int(item.get_meta("entry_index", -1))
        var entry: Dictionary = item.get_meta("entry_data", {})
        if target_index < 0 or entry.is_empty():
            continue
        item.add_theme_stylebox_override("normal", _make_thumb_style(target_index, entry, false))
        item.add_theme_stylebox_override("hover", _make_thumb_style(target_index, entry, true))
        item.add_theme_stylebox_override("pressed", _make_thumb_style(target_index, entry, true))
        item.add_theme_stylebox_override("focus", _make_thumb_style(target_index, entry, true))

func _get_item_reference_size(item: Control) -> Vector2:
    if item == null:
        return Vector2.ZERO
    var inferred_size: Vector2 = Vector2(item.offset_right - item.offset_left, item.offset_bottom - item.offset_top)
    if inferred_size.x > 1.0 and inferred_size.y > 1.0:
        return inferred_size
    var measured_size: Vector2 = item.size
    if measured_size.x > 1.0 and measured_size.y > 1.0:
        return measured_size
    if item.custom_minimum_size.x > 1.0 and item.custom_minimum_size.y > 1.0:
        return item.custom_minimum_size
    return Vector2.ZERO

func _sync_preview_container_size(item_size: Vector2) -> void:
    if item_size.x <= 1.0 or item_size.y <= 1.0:
        return
    preview_host.custom_minimum_size = item_size
    preview_card.custom_minimum_size = item_size + PREVIEW_CARD_PADDING

func _make_thumb_style(target_index: int, entry: Dictionary, is_hover: bool) -> StyleBoxFlat:
    var style: StyleBoxFlat = StyleBoxFlat.new()
    style.bg_color = Color(1, 1, 1, 0.98)
    style.corner_radius_top_left = 14
    style.corner_radius_top_right = 14
    style.corner_radius_bottom_right = 14
    style.corner_radius_bottom_left = 14
    style.shadow_color = Color(0.08, 0.1, 0.15, 0.12)
    style.shadow_size = 6
    style.shadow_offset = Vector2(0, 2)
    style.border_width_left = 3
    style.border_width_top = 3
    style.border_width_right = 3
    style.border_width_bottom = 3
    var is_selected: bool = target_index == _current_index
    var is_active: bool = str(entry.get("id", "")) == _active_bg_id
    var is_unlocked: bool = bool(entry.get("unlocked", true))
    if is_selected:
        style.border_color = Color(0.97, 0.67, 0.18, 1)
    elif is_active:
        style.border_color = Color(0.23, 0.78, 0.67, 1)
    elif is_hover and is_unlocked:
        style.border_color = Color(0.82, 0.85, 0.9, 1)
    elif is_unlocked:
        style.border_color = Color(0.93, 0.95, 0.98, 1)
    else:
        style.border_color = Color(0.62, 0.64, 0.7, 0.9)
    return style
