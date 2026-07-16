@tool
extends Control

const JsonService = preload("res://addons/story_editor/core/story_json_service.gd")
const Scanner = preload("res://addons/story_editor/core/fixed_voice_call_scanner.gd")
const Validator = preload("res://addons/story_editor/core/fixed_voice_call_validator.gd")
const ResourceCatalog = preload("res://addons/story_editor/core/story_resource_catalog.gd")
const LineRowScene = preload("res://addons/story_editor/ui/fixed_voice_call_line_row.tscn")
const WINDOW_LAYOUT_PATH := "res://addons/story_editor/core/editor_window_layout.gd"

var current_path := ""
var current_data: Array = []
var saved_data: Array = []
var selected_call_index := -1
var undo_stack: Array[Dictionary] = []
var redo_stack: Array[Dictionary] = []
var character_entries: Array[Dictionary] = []
var dirty := false
var embedded_mode := false

@onready var call_tree: Tree = %CallTree
@onready var diagnostics_tree: Tree = %DiagnosticsTree
@onready var body_split: HSplitContainer = $Root/Body


func _ready() -> void:
	resized.connect(_apply_responsive_layout)
	%RefreshButton.pressed.connect(refresh_catalog)
	%AddCallButton.pressed.connect(add_call)
	%DeleteCallButton.pressed.connect(delete_selected_call)
	%ApplyMetadataButton.pressed.connect(apply_metadata)
	%AddLineButton.pressed.connect(add_line)
	%ApplyLinesButton.pressed.connect(apply_lines)
	%UndoButton.pressed.connect(undo)
	%RedoButton.pressed.connect(redo)
	%SaveButton.pressed.connect(save_current_calls)
	call_tree.item_selected.connect(_on_call_selected)
	_setup_trees()
	_load_character_catalog()
	_set_editor_enabled(false)
	_update_buttons()
	call_deferred("_apply_responsive_layout")


func open_catalog() -> void:
	show()
	call_deferred("refresh_catalog")


func set_embedded_mode(enabled: bool) -> void:
	embedded_mode = enabled
	$Root/Header.visible = not enabled
	$Root/Hint.visible = not enabled
	$Root/Body/Library.visible = not enabled
	if enabled:
		body_split.split_offset = 0
	call_deferred("_apply_responsive_layout")


func _apply_responsive_layout() -> void:
	if not is_instance_valid(body_split):
		return
	if embedded_mode:
		body_split.split_offset = 0
		return
	var content_width := maxi(size.x - 28, 1)
	body_split.split_offset = clampi(roundi(content_width * 0.27), 220, maxi(220, content_width - 520))


func refresh_catalog() -> void:
	var result := JsonService.load_array(Scanner.CALL_PATH)
	if not result.get("ok", false):
		_show_diagnostics([{"severity": "error", "location": "文件", "message": result.get("error", "读取失败")}])
		return
	load_calls(Scanner.CALL_PATH, result.get("data", []) as Array)


func load_calls(path: String, calls: Array) -> void:
	current_path = path
	current_data = calls.duplicate(true)
	saved_data = current_data.duplicate(true)
	selected_call_index = 0 if not current_data.is_empty() else -1
	undo_stack.clear()
	redo_stack.clear()
	dirty = false
	_refresh_all()


func select_call(call_index: int) -> void:
	if call_index < 0 or call_index >= current_data.size() or not current_data[call_index] is Dictionary:
		selected_call_index = -1
		_set_editor_enabled(false)
		_clear_line_rows()
		_update_buttons()
		return
	selected_call_index = call_index
	var call := current_data[call_index] as Dictionary
	%IdEdit.text = str(call.get("id", ""))
	_select_character(str(call.get("char_id", "")))
	_rebuild_line_rows(call.get("lines", []) as Array)
	_set_editor_enabled(true)
	_select_tree_index(call_index)
	_update_title()
	_update_buttons()


func add_call() -> void:
	_record_history()
	var call_id := _unique_call_id("new_fixed_call")
	var character_id := str(character_entries[0].get("id", "ya")) if not character_entries.is_empty() else "ya"
	current_data.append({"id": call_id, "char_id": character_id, "type": "voice_call", "lines": ["新通话台词"]})
	selected_call_index = current_data.size() - 1
	_refresh_after_edit()


func delete_selected_call() -> bool:
	if not _has_selected_call():
		return false
	_record_history()
	current_data.remove_at(selected_call_index)
	selected_call_index = mini(selected_call_index, current_data.size() - 1)
	_refresh_after_edit()
	return true


func apply_metadata() -> bool:
	if not _has_selected_call():
		return false
	_record_history()
	var call := current_data[selected_call_index] as Dictionary
	call["id"] = %IdEdit.text.strip_edges()
	call["char_id"] = str(%CharacterSelect.get_item_metadata(%CharacterSelect.selected))
	call["type"] = "voice_call"
	_refresh_after_edit()
	return true


func apply_lines() -> bool:
	if not _has_selected_call():
		return false
	_record_history()
	(current_data[selected_call_index] as Dictionary)["lines"] = _collect_lines()
	_refresh_after_edit()
	return true


func add_line() -> bool:
	if not _has_selected_call():
		return false
	_record_history()
	var lines := _collect_lines()
	lines.append("新通话台词")
	(current_data[selected_call_index] as Dictionary)["lines"] = lines
	_refresh_after_edit()
	return true


func move_line(line_index: int, direction: int) -> bool:
	if not _has_selected_call():
		return false
	var lines := _collect_lines()
	var target_index := line_index + direction
	if line_index < 0 or line_index >= lines.size() or target_index < 0 or target_index >= lines.size():
		return false
	_record_history()
	var line_value: Variant = lines[line_index]
	lines[line_index] = lines[target_index]
	lines[target_index] = line_value
	(current_data[selected_call_index] as Dictionary)["lines"] = lines
	_refresh_after_edit()
	return true


func delete_line(line_index: int) -> bool:
	if not _has_selected_call():
		return false
	var lines := _collect_lines()
	if line_index < 0 or line_index >= lines.size():
		return false
	_record_history()
	lines.remove_at(line_index)
	(current_data[selected_call_index] as Dictionary)["lines"] = lines
	_refresh_after_edit()
	return true


func undo() -> bool:
	if undo_stack.is_empty():
		return false
	redo_stack.append(_make_snapshot())
	_restore_snapshot(undo_stack.pop_back())
	return true


func redo() -> bool:
	if redo_stack.is_empty():
		return false
	undo_stack.append(_make_snapshot())
	_restore_snapshot(redo_stack.pop_back())
	return true


func save_current_calls() -> bool:
	if current_path.is_empty():
		return false
	var diagnostics := _validate_current()
	_show_diagnostics(diagnostics)
	for diagnostic in diagnostics:
		if str(diagnostic.get("severity", "")) == "error":
			return false
	var result := JsonService.save_array(current_path, current_data)
	if not result.get("ok", false):
		_show_diagnostics([{"severity": "error", "location": "保存", "message": result.get("error", "保存失败")}])
		return false
	saved_data = current_data.duplicate(true)
	dirty = false
	_update_title()
	_update_buttons()
	return true


func has_unsaved_changes() -> bool:
	return dirty


func _refresh_all() -> void:
	_populate_tree()
	select_call(selected_call_index)
	_show_diagnostics(_validate_current())
	_update_summary()
	_update_buttons()


func _refresh_after_edit() -> void:
	dirty = current_data != saved_data
	_populate_tree()
	select_call(selected_call_index)
	_show_diagnostics(_validate_current())
	_update_summary()
	_update_buttons()


func _populate_tree() -> void:
	call_tree.clear()
	var root := call_tree.create_item()
	var references := Scanner.scan_story_references()
	for call_index in current_data.size():
		var call_value: Variant = current_data[call_index]
		if not call_value is Dictionary:
			continue
		var call := call_value as Dictionary
		var call_id := str(call.get("id", ""))
		var item := call_tree.create_item(root)
		item.set_text(0, call_id)
		item.set_text(1, str(call.get("char_id", "")))
		item.set_text(2, str((call.get("lines", []) as Array).size()))
		item.set_text(3, str((references.get(call_id, []) as Array).size()))
		for column in call_tree.columns:
			item.set_metadata(column, call_index)


func _rebuild_line_rows(lines: Array) -> void:
	_clear_line_rows()
	for line_index in lines.size():
		var row := LineRowScene.instantiate()
		%LineRows.add_child(row)
		row.setup(line_index, lines.size(), str(lines[line_index]))
		row.move_requested.connect(_move_line_row)
		row.delete_requested.connect(_delete_line_row)


func _move_line_row(row: Control, direction: int) -> void:
	move_line(row.get_index(), direction)


func _delete_line_row(row: Control) -> void:
	delete_line(row.get_index())


func _collect_lines() -> Array:
	var lines: Array = []
	for row in %LineRows.get_children():
		if row.has_method("get_line_text"):
			lines.append(row.get_line_text())
	return lines


func _clear_line_rows() -> void:
	for row in %LineRows.get_children():
		%LineRows.remove_child(row)
		row.queue_free()


func _record_history() -> void:
	undo_stack.append(_make_snapshot())
	redo_stack.clear()
	_update_buttons()


func _make_snapshot() -> Dictionary:
	return {"data": current_data.duplicate(true), "call_index": selected_call_index}


func _restore_snapshot(snapshot: Dictionary) -> void:
	current_data = (snapshot.get("data", []) as Array).duplicate(true)
	selected_call_index = int(snapshot.get("call_index", -1))
	dirty = current_data != saved_data
	_refresh_all()


func _validate_current() -> Array[Dictionary]:
	return Validator.validate(current_data, {"character_ids": _character_ids()}, Scanner.scan_story_references())


func _show_diagnostics(diagnostics: Array) -> void:
	diagnostics_tree.clear()
	var root := diagnostics_tree.create_item()
	if diagnostics.is_empty():
		var item := diagnostics_tree.create_item(root)
		item.set_text(0, "OK")
		item.set_text(2, "固定来电结构、角色与剧情引用有效。")
		return
	for diagnostic_value in diagnostics:
		if diagnostic_value is Dictionary:
			var diagnostic := diagnostic_value as Dictionary
			var item := diagnostics_tree.create_item(root)
			item.set_text(0, str(diagnostic.get("severity", "warning")).to_upper())
			item.set_text(1, str(diagnostic.get("location", "")))
			item.set_text(2, str(diagnostic.get("message", "")))


func _setup_trees() -> void:
	call_tree.select_mode = Tree.SELECT_ROW
	call_tree.set_column_title(0, "通话 ID")
	call_tree.set_column_title(1, "角色")
	call_tree.set_column_title(2, "台词")
	call_tree.set_column_title(3, "引用")
	call_tree.set_column_expand(0, true)
	call_tree.set_column_expand(1, true)
	call_tree.set_column_expand(2, false)
	call_tree.set_column_expand(3, false)
	diagnostics_tree.set_column_title(0, "级别")
	diagnostics_tree.set_column_title(1, "位置")
	diagnostics_tree.set_column_title(2, "说明")
	diagnostics_tree.set_column_expand(0, false)
	diagnostics_tree.set_column_custom_minimum_width(0, 80)
	diagnostics_tree.set_column_custom_minimum_width(1, 150)


func _load_character_catalog() -> void:
	character_entries.assign((ResourceCatalog.build().get("character", []) as Array).filter(func(entry: Dictionary) -> bool:
		return not ["旁白", "player"].has(str(entry.get("id", "")))
	))
	%CharacterSelect.clear()
	for entry in character_entries:
		%CharacterSelect.add_item("%s · %s" % [str(entry.get("label", "")), str(entry.get("id", ""))])
		%CharacterSelect.set_item_metadata(%CharacterSelect.item_count - 1, str(entry.get("id", "")))


func _character_ids() -> Array[String]:
	var ids: Array[String] = []
	for entry in character_entries:
		ids.append(str(entry.get("id", "")))
	return ids


func _select_character(character_id: String) -> void:
	for item_index in %CharacterSelect.item_count:
		if str(%CharacterSelect.get_item_metadata(item_index)) == character_id:
			%CharacterSelect.select(item_index)
			return


func _on_call_selected() -> void:
	var item := call_tree.get_selected()
	if item != null:
		var selected_column := maxi(call_tree.get_selected_column(), 0)
		select_call(int(item.get_metadata(selected_column)))


func _select_tree_index(call_index: int) -> void:
	var root := call_tree.get_root()
	if root != null and call_index >= 0 and call_index < root.get_child_count():
		root.get_child(call_index).select(0)


func _update_summary() -> void:
	var line_count := 0
	for call_value in current_data:
		if call_value is Dictionary:
			line_count += ((call_value as Dictionary).get("lines", []) as Array).size()
	%Summary.text = "%d 个固定来电 · %d 行台词" % [current_data.size(), line_count]


func _update_title() -> void:
	if not _has_selected_call():
		%DocumentState.text = "尚未选择通话"
		return
	var marker := " *" if dirty else ""
	%DocumentState.text = "%s%s" % [str((current_data[selected_call_index] as Dictionary).get("id", "未命名通话")), marker]


func _update_buttons() -> void:
	%UndoButton.disabled = undo_stack.is_empty()
	%RedoButton.disabled = redo_stack.is_empty()
	%SaveButton.disabled = current_path.is_empty() or not dirty
	%DeleteCallButton.disabled = not _has_selected_call()


func _set_editor_enabled(enabled: bool) -> void:
	%IdEdit.editable = enabled
	%CharacterSelect.disabled = not enabled
	%ApplyMetadataButton.disabled = not enabled
	%AddLineButton.disabled = not enabled
	%ApplyLinesButton.disabled = not enabled


func _has_selected_call() -> bool:
	return selected_call_index >= 0 and selected_call_index < current_data.size() and current_data[selected_call_index] is Dictionary


func _unique_call_id(base_id: String) -> String:
	var used := {}
	for call_value in current_data:
		if call_value is Dictionary:
			used[str((call_value as Dictionary).get("id", ""))] = true
	var candidate := base_id
	var suffix := 2
	while used.has(candidate):
		candidate = "%s_%d" % [base_id, suffix]
		suffix += 1
	return candidate