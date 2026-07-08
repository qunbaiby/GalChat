extends HBoxContainer

@onready var label = $PanelContainer/MarginContainer/Label

func setup(msg: Dictionary):
	alignment = BoxContainer.ALIGNMENT_CENTER
	var text = msg.get("text", "")
	label.text = text
	label.add_theme_color_override("font_color", Color(0.12, 0.36, 0.34, 1.0))
