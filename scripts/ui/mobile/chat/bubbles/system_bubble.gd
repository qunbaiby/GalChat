extends HBoxContainer

@onready var label = $PanelContainer/MarginContainer/Label

func setup(msg: Dictionary):
	alignment = BoxContainer.ALIGNMENT_CENTER
	var text = msg.get("text", "")
	label.text = text
	label.add_theme_color_override("font_color", Color(0.560784, 0.592157, 0.65098))
