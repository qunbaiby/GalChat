extends PanelContainer

signal rest_pressed(activity_id: String)
signal rest_hovered(act_data: Dictionary)

@onready var button: Button = $Button
@onready var name_label: Label = $Margin/HBox/NameLabel

var _act_data: Dictionary = {}
var _normal_style: StyleBoxFlat
var _hover_style: StyleBoxFlat

func _ready() -> void:
	_normal_style = get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	_hover_style = _normal_style.duplicate() if _normal_style else null
	if _hover_style:
		_hover_style.bg_color = Color(0.94, 0.98, 0.97, 1)
		_hover_style.border_color = Color(0.57, 0.82, 0.76, 0.7)
	button.pressed.connect(_on_pressed)
	button.mouse_entered.connect(_on_hovered)
	
	button.mouse_entered.connect(_apply_hover_style)
	button.mouse_exited.connect(_apply_normal_style)

func setup(act_data: Dictionary) -> void:
	_act_data = act_data
	
	if act_data.has("name"):
		name_label.text = act_data.name

func _on_pressed() -> void:
	if _act_data.has("id"):
		rest_pressed.emit(_act_data.id)

func _on_hovered() -> void:
	rest_hovered.emit(_act_data)

func _apply_hover_style() -> void:
	if _hover_style:
		add_theme_stylebox_override("panel", _hover_style)

func _apply_normal_style() -> void:
	if _normal_style:
		add_theme_stylebox_override("panel", _normal_style)
