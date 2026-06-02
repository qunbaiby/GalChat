extends MarginContainer

signal add_requested(loc_id: String, loc_name: String)

@onready var name_lbl = $HBox/NameLabel
@onready var add_btn = $HBox/AddButton

var _loc_id: String = ""
var _loc_name: String = ""

func setup(loc_id: String, loc_name: String) -> void:
	_loc_id = loc_id
	_loc_name = loc_name
	if name_lbl:
		name_lbl.text = loc_name

func _ready() -> void:
	add_btn.pressed.connect(_on_add_pressed)
	if _loc_name != "":
		name_lbl.text = _loc_name

func _on_add_pressed() -> void:
	add_requested.emit(_loc_id, _loc_name)
