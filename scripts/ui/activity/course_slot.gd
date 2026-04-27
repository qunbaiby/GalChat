extends PanelContainer

@onready var name_label: Label = $NameLabel
@onready var check_mark: Label = $CheckMark

var _normal_style: StyleBox
var _completed_style: StyleBox

func _ready() -> void:
	_normal_style = get_theme_stylebox("panel").duplicate()
	
	_completed_style = _normal_style.duplicate()
	_completed_style.bg_color = Color(0.35, 0.25, 0.2, 1.0)
	_completed_style.border_color = Color(0.6, 0.5, 0.4, 1.0)

func setup(slot_name: String) -> void:
	name_label.text = slot_name

func set_completed(completed: bool) -> void:
	check_mark.visible = completed
	if completed:
		add_theme_stylebox_override("panel", _completed_style)
		name_label.add_theme_color_override("font_color", Color(0.6, 0.5, 0.4, 1.0))
	else:
		add_theme_stylebox_override("panel", _normal_style)
		name_label.add_theme_color_override("font_color", Color(0.8, 0.4, 0.3, 1.0))
