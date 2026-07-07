extends Button

signal gift_selected(gift_id: String)

@onready var icon_rect: TextureRect = $Margin/VBox/Icon
@onready var name_label: Label = $QuantityBar/HBox/Name
@onready var quantity_label: Label = $QuantityBar/HBox/Quantity
@onready var new_badge: Control = $NewBadge

var gift_id: String = ""

func _ready() -> void:
	pressed.connect(func(): gift_selected.emit(gift_id))

func setup(gift: Dictionary) -> void:
	gift_id = gift.get("id", "")
	if gift.has("name"):
		name_label.text = str(gift.name)
	else:
		name_label.text = ""
	
	if gift.has("icon_path"):
		var tex = load(gift.icon_path)
		if tex:
			icon_rect.texture = tex

	quantity_label.text = str(_get_display_amount(gift))
	
	new_badge.visible = bool(gift.get("is_new", false))

func set_selected(selected: bool) -> void:
	button_pressed = selected

func _get_display_amount(gift: Dictionary) -> int:
	for key in ["count", "quantity", "amount", "owned", "stock"]:
		if gift.has(key):
			return max(0, int(gift.get(key, 0)))
	return 1
