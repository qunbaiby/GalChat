extends HBoxContainer

@onready var label = $PanelContainer/MarginContainer/Label

func setup(msg: Dictionary):
	alignment = BoxContainer.ALIGNMENT_CENTER
	var text = msg.get("content", msg.get("text", ""))
	label.text = text
