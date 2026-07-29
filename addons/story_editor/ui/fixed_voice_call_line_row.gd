@tool
extends VBoxContainer

signal move_requested(row: Control, direction: int)
signal delete_requested(row: Control)

var source_data: Dictionary = {}


func _ready() -> void:
	%MoveUpButton.pressed.connect(move_requested.emit.bind(self, -1))
	%MoveDownButton.pressed.connect(move_requested.emit.bind(self, 1))
	%DeleteButton.pressed.connect(delete_requested.emit.bind(self))


func setup(index: int, count: int, line_value: Variant) -> void:
	source_data = (line_value as Dictionary).duplicate(true) if line_value is Dictionary else {}
	var text: String = str(source_data.get("text", "")) if not source_data.is_empty() else str(line_value)
	%IndexLabel.text = "%02d" % (index + 1)
	%LineEdit.text = text
	%ExpressionEdit.text = str(source_data.get("expression", ""))
	%VoiceInstructionEdit.text = str(source_data.get("voice_instruction", ""))
	%MoveUpButton.disabled = index == 0
	%MoveDownButton.disabled = index >= count - 1


func get_line_text() -> String:
	return %LineEdit.text

func get_line_data() -> Variant:
	var text: String = %LineEdit.text
	var expression: String = %ExpressionEdit.text.strip_edges()
	var voice_instruction: String = %VoiceInstructionEdit.text.strip_edges()
	if source_data.is_empty() and expression.is_empty() and voice_instruction.is_empty():
		return text
	var result: Dictionary = source_data.duplicate(true)
	result["text"] = text
	if expression.is_empty():
		result.erase("expression")
	else:
		result["expression"] = expression
	if voice_instruction.is_empty():
		result.erase("voice_instruction")
	else:
		result["voice_instruction"] = voice_instruction
	return result