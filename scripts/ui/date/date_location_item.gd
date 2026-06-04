extends MarginContainer

signal add_requested(loc_id: String, loc_name: String)

@onready var action_btn = $HBox/ActionButton
@onready var icon_rect = $HBox/ActionButton/ContentHBox/IconRect
@onready var name_lbl = $HBox/ActionButton/ContentHBox/NameLabel

const TYPE_ICON_PATHS := {
	"stroll": "res://assets/images/icons/ui/date/stroll.svg",
	"shopping": "res://assets/images/icons/ui/date/shopping.svg",
	"exhibition": "res://assets/images/icons/ui/date/exhibition.svg",
	"dining": "res://assets/images/icons/ui/date/dining.svg"
}

var _loc_id: String = ""
var _loc_name: String = ""
var _type_id: String = ""

func setup(loc_id: String, loc_name: String, type_id: String = "") -> void:
	_loc_id = loc_id
	_loc_name = loc_name
	_type_id = type_id
	_sync_ui()

func _ready() -> void:
	action_btn.pressed.connect(_on_add_pressed)
	_sync_ui()

func _on_add_pressed() -> void:
	add_requested.emit(_loc_id, _loc_name)

func _sync_ui() -> void:
	if name_lbl:
		name_lbl.text = _loc_name
	if icon_rect:
		icon_rect.texture = null
		var icon_path := str(TYPE_ICON_PATHS.get(_type_id, ""))
		if icon_path != "" and ResourceLoader.exists(icon_path):
			icon_rect.texture = load(icon_path)
