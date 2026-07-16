extends VBoxContainer

signal apply_requested(message: Dictionary)

const OptionRowScene = preload("res://addons/story_editor/ui/mobile_chat_option_row.tscn")

var source_message: Dictionary = {}
var message_ids: Array[String] = []


func _ready() -> void:
	%SpeakerEdit.text_changed.connect(_refresh_field_visibility.unbind(1))
	%VoiceCheck.toggled.connect(_refresh_voice_visibility.unbind(1))
	%AddOptionButton.pressed.connect(_add_option)
	%ApplyButton.pressed.connect(_apply)
	clear()


func setup(message: Dictionary, available_message_ids: Array[String]) -> void:
	source_message = message.duplicate(true)
	message_ids = available_message_ids.duplicate()
	%EmptyHint.visible = false
	%Fields.visible = true
	%IdEdit.text = str(message.get("id", ""))
	%SpeakerEdit.text = str(message.get("speaker", ""))
	%TextEdit.text = str(message.get("text", ""))
	%ImageEdit.text = str(message.get("image", ""))
	%DelaySpin.value = float(message.get("delay", 0.0))
	%VoiceCheck.button_pressed = bool(message.get("is_voice", false))
	%DurationSpin.value = float(message.get("duration", 0.0))
	_clear_options()
	for option_value in message.get("options", []):
		if option_value is Dictionary:
			_add_option_row(option_value as Dictionary)
	_refresh_field_visibility()
	_refresh_voice_visibility()


func clear() -> void:
	source_message.clear()
	if not is_node_ready():
		return
	%EmptyHint.visible = true
	%Fields.visible = false
	_clear_options()


func _apply() -> void:
	if source_message.is_empty():
		return
	var result := source_message.duplicate(true)
	result["id"] = %IdEdit.text.strip_edges()
	result["speaker"] = %SpeakerEdit.text.strip_edges()
	_set_optional_text(result, "text", %TextEdit.text)
	_set_optional_text(result, "image", %ImageEdit.text.strip_edges())
	result["delay"] = float(%DelaySpin.value)
	if %VoiceCheck.button_pressed:
		result["is_voice"] = true
		result["duration"] = float(%DurationSpin.value)
	else:
		result.erase("is_voice")
		result.erase("duration")
	if %SpeakerEdit.text.strip_edges() == "player_options":
		var options: Array = []
		for child in %OptionRows.get_children():
			if child.has_method("get_option"):
				options.append(child.get_option())
		result["options"] = options
	else:
		result.erase("options")
	apply_requested.emit(result)


func _add_option() -> void:
	_add_option_row({"id": "option_%d" % (%OptionRows.get_child_count() + 1), "text": "新回复"})


func _add_option_row(option: Dictionary) -> void:
	var row := OptionRowScene.instantiate()
	%OptionRows.add_child(row)
	row.setup(option, message_ids)
	row.delete_requested.connect(_delete_option)


func _delete_option(row: Control) -> void:
	%OptionRows.remove_child(row)
	row.queue_free()


func _clear_options() -> void:
	for child in %OptionRows.get_children():
		%OptionRows.remove_child(child)
		child.queue_free()


func _refresh_field_visibility() -> void:
	var is_options: bool = %SpeakerEdit.text.strip_edges() == "player_options"
	%ContentFields.visible = not is_options
	%OptionsSection.visible = is_options


func _refresh_voice_visibility() -> void:
	%DurationRow.visible = %VoiceCheck.button_pressed


func _set_optional_text(result: Dictionary, key: String, value: String) -> void:
	if value.is_empty():
		result.erase(key)
	else:
		result[key] = value