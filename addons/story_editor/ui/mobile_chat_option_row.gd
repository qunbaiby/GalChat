extends HBoxContainer

signal delete_requested(row: Control)

var source_option: Dictionary = {}


func _ready() -> void:
	%DeleteButton.pressed.connect(delete_requested.emit.bind(self))


func setup(option: Dictionary, message_ids: Array[String]) -> void:
	source_option = option.duplicate(true)
	%IdEdit.text = str(option.get("id", ""))
	%TextEdit.text = str(option.get("text", ""))
	%NextSelect.clear()
	%NextSelect.add_item("按顺序继续")
	%NextSelect.set_item_metadata(0, "")
	for message_id in message_ids:
		%NextSelect.add_item(message_id)
		%NextSelect.set_item_metadata(%NextSelect.item_count - 1, message_id)
	var target := str(option.get("next", ""))
	for index in %NextSelect.item_count:
		if str(%NextSelect.get_item_metadata(index)) == target:
			%NextSelect.select(index)
			break


func get_option() -> Dictionary:
	var result := source_option.duplicate(true)
	result["id"] = %IdEdit.text.strip_edges()
	result["text"] = %TextEdit.text
	var target := str(%NextSelect.get_item_metadata(%NextSelect.selected))
	if target.is_empty():
		result.erase("next")
	else:
		result["next"] = target
	return result