@tool
extends VBoxContainer

signal value_changed

const MODE_STRING_LIST := "string_list"
const MODE_BEAT_LIST := "beat_list"
const MODE_CHAPTER_MAP := "chapter_map"
const MODE_VARIANT := "variant"

var editor_mode := MODE_STRING_LIST
var chapter_ids: Array[String] = []
var source_complex_value: Variant = null
var loading := false


func _ready() -> void:
	%AddButton.pressed.connect(add_item)
	%VariantType.item_selected.connect(_on_variant_type_selected)


func setup(value: Variant, mode: String, available_chapters: Array[String] = []) -> void:
	editor_mode = mode
	chapter_ids = available_chapters.duplicate()
	loading = true
	_clear_rows()
	%CollectionPanel.visible = editor_mode != MODE_VARIANT
	%VariantPanel.visible = editor_mode == MODE_VARIANT
	_configure_header()
	if editor_mode == MODE_VARIANT:
		_setup_variant(value)
	else:
		_populate_collection(value)
	loading = false


func get_value() -> Variant:
	if editor_mode == MODE_VARIANT:
		return _get_variant_value()
	var result: Variant = [] if editor_mode != MODE_CHAPTER_MAP else {}
	for row in %Rows.get_children():
		match editor_mode:
			MODE_STRING_LIST:
				var text := str((row.get_node("ValueEdit") as LineEdit).text).strip_edges()
				if not text.is_empty():
					result.append(text)
			MODE_BEAT_LIST:
				var beat := (row.get_meta("source", {}) as Dictionary).duplicate(true)
				beat["id"] = (row.get_node("Header/IdEdit") as LineEdit).text.strip_edges()
				beat["instruction"] = (row.get_node("InstructionEdit") as TextEdit).text.strip_edges()
				result.append(beat)
			MODE_CHAPTER_MAP:
				var outcome := (row.get_node("OutcomeEdit") as LineEdit).text.strip_edges()
				var target := row.get_node("TargetSelect") as OptionButton
				if not outcome.is_empty():
					result[outcome] = str(target.get_item_metadata(target.selected))
	return result


func add_item() -> void:
	match editor_mode:
		MODE_STRING_LIST:
			_add_string_row("")
		MODE_BEAT_LIST:
			_add_beat_row({"id": "beat_%d" % (%Rows.get_child_count() + 1), "instruction": ""})
		MODE_CHAPTER_MAP:
			_add_chapter_map_row("", "end")
	_refresh_empty_state()
	value_changed.emit()


func _configure_header() -> void:
	match editor_mode:
		MODE_STRING_LIST:
			%AddButton.text = "添加一条"
			%CollectionHint.text = "每行填写一项，可单独删除，不需要输入引号、逗号或括号。"
		MODE_BEAT_LIST:
			%AddButton.text = "添加剧情点"
			%CollectionHint.text = "剧情点 ID 用于 AI 回传识别；描述写清本轮对话必须自然覆盖的信息。"
		MODE_CHAPTER_MAP:
			%AddButton.text = "添加结果分支"
			%CollectionHint.text = "为 AI 对话结果选择目标剧情节点；留空表示不启用结果分支。"


func _populate_collection(value: Variant) -> void:
	match editor_mode:
		MODE_STRING_LIST:
			if value is Array:
				for item in value:
					_add_string_row(str(item))
		MODE_BEAT_LIST:
			if value is Array:
				for item in value:
					if item is Dictionary:
						_add_beat_row(item as Dictionary)
		MODE_CHAPTER_MAP:
			if value is Dictionary:
				for outcome in value.keys():
					_add_chapter_map_row(str(outcome), str(value[outcome]))
	_refresh_empty_state()


func _add_string_row(value: String) -> void:
	var row := HBoxContainer.new()
	var value_edit := LineEdit.new()
	value_edit.name = "ValueEdit"
	value_edit.text = value
	value_edit.placeholder_text = "填写内容"
	value_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_edit.text_changed.connect(value_changed.emit.unbind(1))
	row.add_child(value_edit)
	row.add_child(_create_delete_button(row))
	%Rows.add_child(row)


func _add_beat_row(value: Dictionary) -> void:
	var row := VBoxContainer.new()
	row.set_meta("source", value.duplicate(true))
	var header := HBoxContainer.new()
	header.name = "Header"
	var id_edit := LineEdit.new()
	id_edit.name = "IdEdit"
	id_edit.text = str(value.get("id", ""))
	id_edit.placeholder_text = "剧情点 ID"
	id_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	id_edit.text_changed.connect(value_changed.emit.unbind(1))
	header.add_child(id_edit)
	header.add_child(_create_delete_button(row))
	row.add_child(header)
	var instruction_edit := TextEdit.new()
	instruction_edit.name = "InstructionEdit"
	instruction_edit.text = str(value.get("instruction", ""))
	instruction_edit.placeholder_text = "描述必须在对话中自然覆盖的信息"
	instruction_edit.custom_minimum_size = Vector2(0, 72)
	instruction_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	instruction_edit.text_changed.connect(value_changed.emit)
	row.add_child(instruction_edit)
	%Rows.add_child(row)


func _add_chapter_map_row(outcome: String, target_chapter: String) -> void:
	var row := HBoxContainer.new()
	var outcome_edit := LineEdit.new()
	outcome_edit.name = "OutcomeEdit"
	outcome_edit.text = outcome
	outcome_edit.placeholder_text = "结果名称"
	outcome_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outcome_edit.text_changed.connect(value_changed.emit.unbind(1))
	row.add_child(outcome_edit)
	var target_select := OptionButton.new()
	target_select.name = "TargetSelect"
	target_select.custom_minimum_size = Vector2(150, 0)
	for chapter_id in chapter_ids:
		target_select.add_item("剧情结束" if chapter_id == "end" else chapter_id)
		target_select.set_item_metadata(target_select.item_count - 1, chapter_id)
		if chapter_id == target_chapter:
			target_select.select(target_select.item_count - 1)
	if target_chapter != "" and not chapter_ids.has(target_chapter):
		target_select.add_item("未找到 · %s" % target_chapter)
		target_select.set_item_metadata(target_select.item_count - 1, target_chapter)
		target_select.select(target_select.item_count - 1)
	row.add_child(target_select)
	target_select.item_selected.connect(value_changed.emit.unbind(1))
	row.add_child(_create_delete_button(row))
	%Rows.add_child(row)


func _create_delete_button(row: Control) -> Button:
	var delete_button := Button.new()
	delete_button.text = "删除"
	delete_button.tooltip_text = "删除这一项"
	delete_button.pressed.connect(_delete_row.bind(row))
	return delete_button


func _delete_row(row: Control) -> void:
	%Rows.remove_child(row)
	row.queue_free()
	_refresh_empty_state()
	value_changed.emit()


func _refresh_empty_state() -> void:
	%EmptyHint.visible = %Rows.get_child_count() == 0


func _setup_variant(value: Variant) -> void:
	%VariantType.clear()
	for label in ["开关", "文本", "整数", "小数", "空值", "复杂值（保持原值）"]:
		%VariantType.add_item(label)
	var type_index := 5
	if value is bool:
		type_index = 0
		%BoolValue.button_pressed = value
	elif value is String:
		type_index = 1
		%TextValue.text = value
	elif value is int:
		type_index = 2
		%NumberValue.value = float(value)
	elif value is float:
		type_index = 3
		%NumberValue.value = value
	elif value == null:
		type_index = 4
	source_complex_value = value
	%VariantType.select(type_index)
	_refresh_variant_control(type_index)


func _on_variant_type_selected(index: int) -> void:
	if not loading:
		_refresh_variant_control(index)


func _refresh_variant_control(index: int) -> void:
	%BoolValue.visible = index == 0
	%TextValue.visible = index == 1
	%NumberValue.visible = index in [2, 3]
	%NumberValue.step = 1.0 if index == 2 else 0.1
	%ComplexValueHint.visible = index == 5


func _get_variant_value() -> Variant:
	match %VariantType.selected:
		0:
			return %BoolValue.button_pressed
		1:
			return %TextValue.text
		2:
			return int(%NumberValue.value)
		3:
			return %NumberValue.value
		4:
			return null
	return source_complex_value


func _clear_rows() -> void:
	for child in %Rows.get_children():
		%Rows.remove_child(child)
		child.queue_free()