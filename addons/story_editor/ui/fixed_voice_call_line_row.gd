extends HBoxContainer

signal move_requested(row: Control, direction: int)
signal delete_requested(row: Control)


func _ready() -> void:
	%MoveUpButton.pressed.connect(move_requested.emit.bind(self, -1))
	%MoveDownButton.pressed.connect(move_requested.emit.bind(self, 1))
	%DeleteButton.pressed.connect(delete_requested.emit.bind(self))


func setup(index: int, count: int, text: String) -> void:
	%IndexLabel.text = "%02d" % (index + 1)
	%LineEdit.text = text
	%MoveUpButton.disabled = index == 0
	%MoveDownButton.disabled = index >= count - 1


func get_line_text() -> String:
	return %LineEdit.text