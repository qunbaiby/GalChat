extends Button

signal item_selected(outfit_data: Dictionary, item_node: Node)

@export var fallback_icon: Texture2D
@export var normal_style: StyleBox
@export var selected_style: StyleBox
@export var locked_style: StyleBox
@export var preview_normal_style: StyleBox
@export var preview_locked_style: StyleBox

@onready var card_panel: PanelContainer = %CardPanel
@onready var preview_panel: PanelContainer = %PreviewPanel
@onready var icon_rect: TextureRect = %IconRect
@onready var name_label: Label = %NameLabel
@onready var meta_label: Label = %MetaLabel
@onready var wearing_badge: Label = %WearingBadge
@onready var lock_badge: Label = %LockBadge

var outfit_data: Dictionary = {}
var is_wearing: bool = false
var is_selected: bool = false
var is_unlocked: bool = true


func _ready() -> void:
	flat = true
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)


func setup(data: Dictionary, current_outfit_id: String, unlocked_outfit_ids: Array) -> void:
	outfit_data = data.duplicate(true)
	name_label.text = str(data.get("name", "未知服装"))
	var icon_path := str(data.get("icon", "")).strip_edges()
	if icon_path != "" and ResourceLoader.exists(icon_path):
		icon_rect.texture = load(icon_path)
	else:
		icon_rect.texture = fallback_icon
	is_unlocked = unlocked_outfit_ids.has(outfit_data.get("id", ""))
	update_wearing_status(current_outfit_id)
	_apply_visual_state()


func update_wearing_status(current_outfit_id: String) -> void:
	is_wearing = outfit_data.get("id", "") == current_outfit_id
	_apply_visual_state()


func update_unlock_status(unlocked_outfit_ids: Array) -> void:
	is_unlocked = unlocked_outfit_ids.has(outfit_data.get("id", ""))
	_apply_visual_state()


func set_selected(selected: bool) -> void:
	is_selected = selected
	_apply_visual_state()


func _apply_visual_state() -> void:
	if card_panel:
		var card_style := normal_style
		if not is_unlocked and locked_style:
			card_style = locked_style
		elif is_selected and selected_style:
			card_style = selected_style
		card_panel.add_theme_stylebox_override("panel", card_style)

	if preview_panel:
		var preview_style := preview_normal_style
		if not is_unlocked and preview_locked_style:
			preview_style = preview_locked_style
		preview_panel.add_theme_stylebox_override("panel", preview_style)

	wearing_badge.visible = is_wearing
	lock_badge.visible = not is_unlocked

	if not is_unlocked:
		name_label.add_theme_color_override("font_color", Color(0.76, 0.79, 0.82, 0.88))
		meta_label.text = "未拥有"
		meta_label.add_theme_color_override("font_color", Color(0.86, 0.76, 0.66, 0.9))
	elif is_wearing:
		name_label.add_theme_color_override("font_color", Color(0.15, 0.25, 0.28, 1))
		meta_label.text = "当前穿着"
		meta_label.add_theme_color_override("font_color", Color(0.42, 0.82, 0.76, 1))
	else:
		name_label.add_theme_color_override("font_color", Color(0.22, 0.32, 0.36, 1))
		meta_label.text = "已拥有"
		meta_label.add_theme_color_override("font_color", Color(0.56, 0.64, 0.68, 1))


func _on_pressed() -> void:
	item_selected.emit(outfit_data, self)
