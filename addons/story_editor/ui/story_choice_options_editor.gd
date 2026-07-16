extends VBoxContainer

const OptionRowScene = preload("res://addons/story_editor/ui/story_choice_option_row.tscn")

var chapter_ids: Array[String] = []


func _ready() -> void:
	%AddButton.pressed.connect(add_option)


func setup(options: Array, available_chapters: Array[String]) -> void:
	chapter_ids = available_chapters.duplicate()
	_clear_rows()
	for option_value in options:
		if option_value is Dictionary:
			_add_row(option_value as Dictionary)
	_refresh_indices()


func add_option() -> void:
	var next_index := %Rows.get_child_count() + 1
	_add_row({"id": "option_%d" % next_index, "text": "新选项", "effects": {"intimacy": 0, "trust": 0}})
	_refresh_indices()


func get_options() -> Array:
	var options: Array = []
	for child in %Rows.get_children():
		if child.has_method("get_option"):
			options.append(child.get_option())
	return options


func _add_row(option: Dictionary) -> void:
	var row := OptionRowScene.instantiate()
	%Rows.add_child(row)
	row.setup(option, chapter_ids)
	row.move_requested.connect(_move_row)
	row.delete_requested.connect(_delete_row)


func _move_row(row: Control, direction: int) -> void:
	var current_index := row.get_index()
	var target_index := current_index + direction
	if target_index < 0 or target_index >= %Rows.get_child_count():
		return
	%Rows.move_child(row, target_index)
	_refresh_indices()


func _delete_row(row: Control) -> void:
	%Rows.remove_child(row)
	row.queue_free()
	_refresh_indices()


func _refresh_indices() -> void:
	var count := %Rows.get_child_count()
	for index in count:
		%Rows.get_child(index).set_index(index, count)


func _clear_rows() -> void:
	for child in %Rows.get_children():
		%Rows.remove_child(child)
		child.queue_free()
