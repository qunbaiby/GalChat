extends Button
class_name CafeMenuItemCard

signal card_pressed(item: Dictionary, card: CafeMenuItemCard)

@export var fallback_icon: Texture2D
@export var normal_style: StyleBox
@export var selected_style: StyleBox

@onready var card_panel: PanelContainer = %CardPanel
@onready var icon_rect: TextureRect = %IconRect
@onready var name_label: Label = %NameLabel
@onready var price_label: Label = %PriceLabel

var item_data: Dictionary = {}

func _ready() -> void:
	flat = true
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	pressed.connect(_on_pressed)
	set_selected(false)
	_refresh_ui()

func setup(item: Dictionary) -> void:
	item_data = item.duplicate(true)
	if is_node_ready():
		_refresh_ui()

func _refresh_ui() -> void:
	if not name_label or not price_label or not icon_rect:
		return
	name_label.text = str(item_data.get("name", "未命名商品"))
	price_label.text = str(item_data.get("price", 0))

	var icon_path := str(item_data.get("icon", "")).strip_edges()
	if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
		icon_rect.texture = load(icon_path)
	else:
		icon_rect.texture = fallback_icon

func set_selected(is_selected: bool) -> void:
	if not card_panel:
		return
	if is_selected and selected_style:
		card_panel.add_theme_stylebox_override("panel", selected_style)
	elif normal_style:
		card_panel.add_theme_stylebox_override("panel", normal_style)

func _on_pressed() -> void:
	card_pressed.emit(item_data, self)
