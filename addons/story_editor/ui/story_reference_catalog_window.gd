@tool
extends Window

const Scanner = preload("res://addons/story_editor/core/story_entry_reference_scanner.gd")
const Validator = preload("res://addons/story_editor/core/story_entry_reference_validator.gd")
const JsonService = preload("res://addons/story_editor/core/story_json_service.gd")
const ConditionRowScene = preload("res://addons/story_editor/ui/story_event_condition_row.tscn")
const WINDOW_LAYOUT_PATH := "res://addons/story_editor/core/editor_window_layout.gd"

var scan_result: Dictionary = {}
var references: Array[Dictionary] = []
var diagnostics: Array[Dictionary] = []
var selected_reference_index := -1
var registry_path := Scanner.EVENT_REGISTRY_PATH
var registry_data: Dictionary = {}
var saved_registry_data: Dictionary = {}
var undo_stack: Array[Dictionary] = []
var redo_stack: Array[Dictionary] = []

@onready var reference_tree: Tree = %ReferenceTree
@onready var backlinks_tree: Tree = %BacklinksTree
@onready var diagnostics_tree: Tree = %DiagnosticsTree


func _ready() -> void:
	close_requested.connect(hide)
	%RefreshButton.pressed.connect(refresh_catalog)
	%UndoButton.pressed.connect(undo)
	%RedoButton.pressed.connect(redo)
	%SaveButton.pressed.connect(save_registry)
	%AddConditionButton.pressed.connect(add_condition_row)
	%ApplyEventButton.pressed.connect(apply_selected_event)
	reference_tree.item_selected.connect(_on_reference_selected)
	%EventTypeSelect.add_item("自动触发")
	%EventTypeSelect.set_item_metadata(0, "auto_trigger")
	%EventTypeSelect.add_item("手动触发")
	%EventTypeSelect.set_item_metadata(1, "manual")
	_setup_trees()


func open_catalog() -> void:
	(load(WINDOW_LAYOUT_PATH) as GDScript).new().open_window(self, Vector2i(1180, 760), Vector2i(820, 520))
	call_deferred("refresh_catalog")


func refresh_catalog() -> void:
	var registry_result := JsonService.load_dictionary(registry_path)
	if not registry_result.get("ok", false):
		load_scan_result(Scanner.scan(registry_path))
		return
	registry_data = (registry_result.get("data", {}) as Dictionary).duplicate(true)
	saved_registry_data = registry_data.duplicate(true)
	undo_stack.clear()
	redo_stack.clear()
	load_scan_result(Scanner.scan(registry_path))


func load_scan_result(value: Dictionary) -> void:
	scan_result = value.duplicate(true)
	references.clear()
	for reference_value in scan_result.get("references", []):
		if reference_value is Dictionary:
			references.append((reference_value as Dictionary).duplicate(true))
	diagnostics = Validator.validate(scan_result)
	selected_reference_index = 0 if not references.is_empty() else -1
	_rebuild_reference_tree()
	_show_diagnostics()
	_update_summary()
	if selected_reference_index >= 0:
		select_reference(selected_reference_index)
	else:
		_clear_details()
	_update_edit_buttons()


func select_reference(reference_index: int) -> void:
	if reference_index < 0 or reference_index >= references.size():
		selected_reference_index = -1
		_clear_details()
		return
	selected_reference_index = reference_index
	var reference := references[reference_index]
	%SelectionTitle.text = str(reference.get("source_id", "未命名入口"))
	%SourceValue.text = "%s | %s" % [_source_label(str(reference.get("source_type", ""))), str(reference.get("source_path", ""))]
	%LocationValue.text = str(reference.get("location", ""))
	%TargetValue.text = str(reference.get("target_path", ""))
	%ConditionsValue.text = JSON.stringify(reference.get("conditions", []), "  ")
	_rebuild_backlinks(str(reference.get("target_path", "")))
	_select_reference_tree_item(reference_index)
	_load_event_editor(reference)


func apply_selected_event() -> bool:
	if not _has_editable_event():
		return false
	var event_index := int(references[selected_reference_index].get("event_index", -1))
	var events := registry_data.get("events", []) as Array
	if event_index < 0 or event_index >= events.size() or not events[event_index] is Dictionary:
		return false
	_record_history()
	var event := (events[event_index] as Dictionary).duplicate(true)
	event["event_id"] = %EventIdEdit.text.strip_edges()
	event["event_type"] = str(%EventTypeSelect.get_item_metadata(%EventTypeSelect.selected))
	event["is_repeatable"] = %RepeatableCheck.button_pressed
	event["trigger_script"] = %TargetPathEdit.text.strip_edges()
	event["conditions"] = _collect_conditions()
	events[event_index] = event
	registry_data["events"] = events
	_rebuild_after_registry_edit(event_index)
	return true


func add_condition_row(condition: Dictionary = {"type": "location", "value": ""}) -> void:
	var row := ConditionRowScene.instantiate()
	%ConditionRows.add_child(row)
	row.setup(condition)
	row.delete_requested.connect(_delete_condition_row)


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


func save_registry() -> bool:
	if not _is_registry_dirty() or _has_blocking_errors():
		return false
	var result := JsonService.save_dictionary(registry_path, registry_data)
	if not result.get("ok", false):
		diagnostics.append({"severity": "error", "code": "save_failed", "location": "Event Registry", "message": result.get("error", "保存失败。")})
		_show_diagnostics()
		_update_edit_buttons()
		return false
	saved_registry_data = registry_data.duplicate(true)
	_update_edit_buttons()
	return true


func _setup_trees() -> void:
	reference_tree.set_column_title(0, "入口")
	reference_tree.set_column_title(1, "目标剧情")
	reference_tree.set_column_expand(0, true)
	reference_tree.set_column_expand(1, true)
	backlinks_tree.set_column_title(0, "类型")
	backlinks_tree.set_column_title(1, "入口")
	backlinks_tree.set_column_title(2, "位置")
	diagnostics_tree.set_column_title(0, "级别")
	diagnostics_tree.set_column_title(1, "位置")
	diagnostics_tree.set_column_title(2, "说明")


func _rebuild_reference_tree() -> void:
	reference_tree.clear()
	var root := reference_tree.create_item()
	var groups := {}
	for reference_index in references.size():
		var reference := references[reference_index]
		var source_type := str(reference.get("source_type", "unknown"))
		if not groups.has(source_type):
			var group := reference_tree.create_item(root)
			group.set_text(0, _source_label(source_type))
			group.set_selectable(0, false)
			group.set_selectable(1, false)
			groups[source_type] = group
		var item := reference_tree.create_item(groups[source_type] as TreeItem)
		item.set_text(0, str(reference.get("source_id", "未命名入口")))
		item.set_text(1, str(reference.get("target_path", "")))
		item.set_metadata(0, reference_index)
		item.set_tooltip_text(1, str(reference.get("target_path", "")))


func _rebuild_backlinks(target_path: String) -> void:
	backlinks_tree.clear()
	var root := backlinks_tree.create_item()
	for reference in references:
		if str(reference.get("target_path", "")) != target_path:
			continue
		var item := backlinks_tree.create_item(root)
		item.set_text(0, _source_label(str(reference.get("source_type", ""))))
		item.set_text(1, str(reference.get("source_id", "")))
		item.set_text(2, str(reference.get("location", "")))


func _show_diagnostics() -> void:
	diagnostics_tree.clear()
	var root := diagnostics_tree.create_item()
	for diagnostic in diagnostics:
		var item := diagnostics_tree.create_item(root)
		item.set_text(0, "错误" if diagnostic.get("severity") == "error" else "警告")
		item.set_text(1, str(diagnostic.get("location", "")))
		item.set_text(2, str(diagnostic.get("message", "")))


func _update_summary() -> void:
	var target_paths := {}
	for reference in references:
		var target_path := str(reference.get("target_path", ""))
		if not target_path.is_empty():
			target_paths[target_path] = true
	var error_count := diagnostics.filter(func(diagnostic: Dictionary) -> bool: return diagnostic.get("severity") == "error").size()
	var unreferenced_count := diagnostics.filter(func(diagnostic: Dictionary) -> bool: return diagnostic.get("code") == "unreferenced_story").size()
	%Summary.text = "%d 个入口 | %d 个目标 | %d 个未引用 | %d 个错误 | %d 个警告" % [references.size(), target_paths.size(), unreferenced_count, error_count, diagnostics.size() - error_count]


func _clear_details() -> void:
	%SelectionTitle.text = "尚未选择入口"
	%SourceValue.text = ""
	%LocationValue.text = ""
	%TargetValue.text = ""
	%ConditionsValue.text = ""
	%EventEditor.visible = false
	_clear_condition_rows()
	backlinks_tree.clear()


func _load_event_editor(reference: Dictionary) -> void:
	var editable := str(reference.get("source_type", "")) == "event_registry"
	%EventEditor.visible = editable
	%ConditionsValue.visible = not editable
	if not editable:
		_clear_condition_rows()
		return
	var event_index := int(reference.get("event_index", -1))
	var events := registry_data.get("events", []) as Array
	if event_index < 0 or event_index >= events.size() or not events[event_index] is Dictionary:
		%EventEditor.visible = false
		return
	var event := events[event_index] as Dictionary
	%EventIdEdit.text = str(event.get("event_id", ""))
	%TargetPathEdit.text = str(event.get("trigger_script", ""))
	%RepeatableCheck.button_pressed = bool(event.get("is_repeatable", false))
	_select_event_type(str(event.get("event_type", "auto_trigger")))
	_clear_condition_rows()
	for condition_value in event.get("conditions", []):
		if condition_value is Dictionary:
			add_condition_row(condition_value as Dictionary)


func _rebuild_after_registry_edit(event_index: int) -> void:
	var event_scan := Scanner.scan_event_registry_data(registry_data)
	var preserved_references: Array[Dictionary] = []
	for reference in references:
		if str(reference.get("source_type", "")) != "event_registry":
			preserved_references.append(reference.duplicate(true))
	var rebuilt_references: Array[Dictionary] = []
	for event_reference in event_scan.get("references", []):
		if event_reference is Dictionary:
			rebuilt_references.append((event_reference as Dictionary).duplicate(true))
	rebuilt_references.append_array(preserved_references)
	scan_result["references"] = rebuilt_references
	scan_result["event_entries"] = event_scan.get("event_entries", [])
	references = rebuilt_references
	diagnostics = Validator.validate(scan_result)
	selected_reference_index = event_index
	_rebuild_reference_tree()
	_show_diagnostics()
	_update_summary()
	select_reference(selected_reference_index)
	_update_edit_buttons()


func _collect_conditions() -> Array[Dictionary]:
	var conditions: Array[Dictionary] = []
	for child in %ConditionRows.get_children():
		if child.visible and child.has_method("get_condition"):
			conditions.append(child.get_condition())
	return conditions


func _delete_condition_row(row: Control) -> void:
	row.queue_free()


func _clear_condition_rows() -> void:
	for child in %ConditionRows.get_children():
		if child.name != "ConditionRowPrototype":
			%ConditionRows.remove_child(child)
			child.queue_free()


func _record_history() -> void:
	undo_stack.append(_make_snapshot())
	redo_stack.clear()


func _make_snapshot() -> Dictionary:
	return {"registry_data": registry_data.duplicate(true), "event_index": int(references[selected_reference_index].get("event_index", 0)) if _has_editable_event() else 0}


func _restore_snapshot(snapshot: Dictionary) -> void:
	registry_data = (snapshot.get("registry_data", {}) as Dictionary).duplicate(true)
	_rebuild_after_registry_edit(int(snapshot.get("event_index", 0)))


func _has_editable_event() -> bool:
	return selected_reference_index >= 0 and selected_reference_index < references.size() and str(references[selected_reference_index].get("source_type", "")) == "event_registry"


func _is_registry_dirty() -> bool:
	return registry_data != saved_registry_data


func _has_blocking_errors() -> bool:
	return diagnostics.any(func(diagnostic: Dictionary) -> bool: return diagnostic.get("severity") == "error")


func _update_edit_buttons() -> void:
	%UndoButton.disabled = undo_stack.is_empty()
	%RedoButton.disabled = redo_stack.is_empty()
	%SaveButton.disabled = not _is_registry_dirty() or _has_blocking_errors()


func _select_event_type(event_type: String) -> void:
	for item_index in %EventTypeSelect.item_count:
		if str(%EventTypeSelect.get_item_metadata(item_index)) == event_type:
			%EventTypeSelect.select(item_index)
			return
	%EventTypeSelect.select(0)


func _on_reference_selected() -> void:
	var item := reference_tree.get_selected()
	if item != null and item.get_metadata(0) != null:
		select_reference(int(item.get_metadata(0)))


func _select_reference_tree_item(reference_index: int) -> void:
	var item := reference_tree.get_root().get_first_child() if reference_tree.get_root() != null else null
	while item != null:
		var child := item.get_first_child()
		while child != null:
			if int(child.get_metadata(0)) == reference_index:
				child.select(0)
				return
			child = child.get_next()
		item = item.get_next()


func _source_label(source_type: String) -> String:
	match source_type:
		"event_registry":
			return "Event Registry"
		"guide_flow":
			return "Guide Flow"
		"story_schedule":
			return "剧情日程"
		"map_schedule":
			return "地图定时入口"
		_:
			return source_type