@tool
extends VBoxContainer


func _ready() -> void:
	%AddPlayerButton.pressed.connect(_add_row.bind({"speaker": "player", "text": ""}))
	%AddCharacterButton.pressed.connect(_add_row.bind({"speaker": "char", "text": ""}))
	%AddSystemButton.pressed.connect(_add_row.bind({"speaker": "system", "type": "system", "text": ""}))


func setup(history: Array) -> void:
	_clear_rows()
	for entry_value in history:
		if entry_value is Dictionary:
			_add_row(entry_value as Dictionary)
	_refresh_empty_state()


func get_history() -> Array:
	var history: Array = []
	for row in %Rows.get_children():
		var source := (row.get_meta("source", {}) as Dictionary).duplicate(true)
		var speaker_select := row.get_node("Header/SpeakerSelect") as OptionButton
		var speaker := str(speaker_select.get_item_metadata(speaker_select.selected))
		var text := (row.get_node("TextEdit") as TextEdit).text.strip_edges()
		if text.is_empty():
			continue
		source["speaker"] = speaker
		source["text"] = text
		if speaker == "system":
			source["type"] = str(source.get("type", "system"))
		else:
			source.erase("type")
		history.append(source)
	return history


func _add_row(entry: Dictionary) -> void:
	var row := VBoxContainer.new()
	row.set_meta("source", entry.duplicate(true))
	var header := HBoxContainer.new()
	header.name = "Header"
	var speaker_select := OptionButton.new()
	speaker_select.name = "SpeakerSelect"
	for option in [["玩家", "player"], ["角色", "char"], ["系统事件", "system"]]:
		speaker_select.add_item(option[0])
		speaker_select.set_item_metadata(speaker_select.item_count - 1, option[1])
		if str(entry.get("speaker", "player")) == option[1]:
			speaker_select.select(speaker_select.item_count - 1)
	header.add_child(speaker_select)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	var up_button := Button.new()
	up_button.text = "上移"
	up_button.pressed.connect(_move_row.bind(row, -1))
	header.add_child(up_button)
	var down_button := Button.new()
	down_button.text = "下移"
	down_button.pressed.connect(_move_row.bind(row, 1))
	header.add_child(down_button)
	var delete_button := Button.new()
	delete_button.text = "删除"
	delete_button.pressed.connect(_delete_row.bind(row))
	header.add_child(delete_button)
	row.add_child(header)
	var text_edit := TextEdit.new()
	text_edit.name = "TextEdit"
	text_edit.text = str(entry.get("text", ""))
	text_edit.placeholder_text = "消息内容"
	text_edit.custom_minimum_size = Vector2(0, 64)
	text_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	row.add_child(text_edit)
	%Rows.add_child(row)
	_refresh_move_buttons()
	_refresh_empty_state()


func _move_row(row: Control, direction: int) -> void:
	var target := row.get_index() + direction
	if target < 0 or target >= %Rows.get_child_count():
		return
	%Rows.move_child(row, target)
	_refresh_move_buttons()


func _delete_row(row: Control) -> void:
	%Rows.remove_child(row)
	row.queue_free()
	_refresh_move_buttons()
	_refresh_empty_state()


func _refresh_move_buttons() -> void:
	var count := %Rows.get_child_count()
	for index in count:
		var buttons := %Rows.get_child(index).get_node("Header").get_children()
		(buttons[2] as Button).disabled = index == 0
		(buttons[3] as Button).disabled = index == count - 1


func _refresh_empty_state() -> void:
	%EmptyHint.visible = %Rows.get_child_count() == 0


func _clear_rows() -> void:
	for child in %Rows.get_children():
		%Rows.remove_child(child)
		child.queue_free()