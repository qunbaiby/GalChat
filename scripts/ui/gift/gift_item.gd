extends Button

signal gift_selected(gift_id: String)

@onready var icon_rect: TextureRect = $Margin/VBox/Icon
@onready var name_label: Label = $Margin/VBox/Name
@onready var new_badge: Control = $NewBadge
@onready var selected_corners: Control = $SelectedCorners

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
	
	new_badge.visible = bool(gift.get("is_new", false))

func set_selected(selected: bool) -> void:
	selected_corners.visible = selected
