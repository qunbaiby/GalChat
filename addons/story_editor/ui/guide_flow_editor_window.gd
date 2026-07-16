@tool
extends Window

const JsonService = preload("res://addons/story_editor/core/story_json_service.gd")
const Validator = preload("res://addons/story_editor/core/guide_flow_validator.gd")
const WINDOW_LAYOUT_PATH := "res://addons/story_editor/core/editor_window_layout.gd"
const DEFAULT_PATH := "res://assets/data/guide/guide_flows.json"

var guide_path := DEFAULT_PATH
var current_data: Dictionary = {}
var saved_data: Dictionary = {}
var selected_guide_index := -1
var selected_step_index := -1
var undo_stack: Array[Dictionary] = []
var redo_stack: Array[Dictionary] = []
var diagnostics: Array[Dictionary] = []

@onready var guide_tree: Tree = %GuideTree
@onready var step_tree: Tree = %StepTree
@onready var diagnostics_tree: Tree = %DiagnosticsTree


func _ready() -> void:
	close_requested.connect(hide)
	%RefreshButton.pressed.connect(refresh_editor)
	%SaveButton.pressed.connect(save_guides)
	%UndoButton.pressed.connect(undo)
	%RedoButton.pressed.connect(redo)
	%AddStepButton.pressed.connect(add_step)
	%DeleteStepButton.pressed.connect(delete_step)
	%MoveUpButton.pressed.connect(move_step.bind(-1))
	%MoveDownButton.pressed.connect(move_step.bind(1))
	%ApplyStepButton.pressed.connect(apply_step)
	guide_tree.item_selected.connect(_on_guide_selected)
	step_tree.item_selected.connect(_on_step_selected)
	for step_type in Validator.SUPPORTED_STEP_TYPES:
		%StepTypeSelect.add_item(step_type)
		%StepTypeSelect.set_item_metadata(%StepTypeSelect.item_count - 1, step_type)
	%StepTypeSelect.item_selected.connect(_update_type_fields)
	_setup_trees()
	_set_inspector_enabled(false)


func open_editor() -> void:
	(load(WINDOW_LAYOUT_PATH) as GDScript).new().open_window(self, Vector2i(1220, 780), Vector2i(900, 580))
	call_deferred("refresh_editor")


func refresh_editor() -> void:
	var result := JsonService.load_dictionary(guide_path)
	if not result.get("ok", false):
		current_data = {}
		diagnostics = [{"severity": "error", "code": "load_failed", "location": guide_path, "message": result.get("error", "读取失败。")}]
		_refresh_all()
		return
	load_guides(result.get("data", {}) as Dictionary)


func load_guides(data: Dictionary) -> void:
	current_data = data.duplicate(true)
	saved_data = current_data.duplicate(true)
	selected_guide_index = 0 if not _guides().is_empty() else -1
	selected_step_index = 0 if _step_count(selected_guide_index) > 0 else -1
	undo_stack.clear()
	redo_stack.clear()
	_refresh_all()


func select_guide(guide_index: int) -> void:
	if guide_index < 0 or guide_index >= _guides().size() or not _guides()[guide_index] is Dictionary:
		selected_guide_index = -1
		selected_step_index = -1
		_refresh_step_tree()
		_set_inspector_enabled(false)
		_update_buttons()
		return
	selected_guide_index = guide_index
	selected_step_index = 0 if _step_count(guide_index) > 0 else -1
	_refresh_step_tree()
	_select_guide_tree_item(guide_index)
	select_step(selected_step_index)


func select_step(step_index: int) -> void:
	var steps := _steps()
	if step_index < 0 or step_index >= steps.size() or not steps[step_index] is Dictionary:
		selected_step_index = -1
		_set_inspector_enabled(false)
		_update_buttons()
		return
	selected_step_index = step_index
	var step := steps[step_index] as Dictionary
	%InspectorTitle.text = str(step.get("id", "未命名步骤"))
	%StepIdEdit.text = str(step.get("id", ""))
	%StepTitleEdit.text = str(step.get("title", ""))
	%StepTextEdit.text = str(step.get("text", ""))
	%WaitActionEdit.text = str(step.get("wait_action", ""))
	%TargetSceneEdit.text = str(step.get("target_scene", ""))
	%StoryPathEdit.text = str(step.get("story_path", ""))
	%ScriptIdEdit.text = str(step.get("script_id", ""))
	%ReturnToMainCheck.button_pressed = bool(step.get("return_to_main", true))
	_select_step_type(str(step.get("type", "message")))
	_set_inspector_enabled(true)
	_select_step_tree_item(step_index)
	_update_buttons()


func apply_step() -> bool:
	if not _has_selected_step():
		return false
	_record_history()
	var steps := _steps()
	var step := (steps[selected_step_index] as Dictionary).duplicate(true)
	var step_type := str(%StepTypeSelect.get_item_metadata(%StepTypeSelect.selected))
	step["id"] = %StepIdEdit.text.strip_edges()
	step["type"] = step_type
	step["title"] = %StepTitleEdit.text
	step["text"] = %StepTextEdit.text
	if step_type == "play_story":
		step["story_path"] = %StoryPathEdit.text.strip_edges()
		step["script_id"] = %ScriptIdEdit.text.strip_edges()
		step["return_to_main"] = %ReturnToMainCheck.button_pressed
	else:
		step["wait_action"] = %WaitActionEdit.text.strip_edges()
		step["target_scene"] = %TargetSceneEdit.text.strip_edges()
	steps[selected_step_index] = step
	_set_steps(steps)
	_refresh_after_edit()
	return true


func add_step() -> bool:
	if selected_guide_index < 0:
		return false
	_record_history()
	var steps := _steps()
	steps.append({"id": _unique_step_id(steps), "type": "message", "title": "新步骤", "text": ""})
	_set_steps(steps)
	selected_step_index = steps.size() - 1
	_refresh_after_edit()
	return true


func delete_step() -> bool:
	if not _has_selected_step():
		return false
	_record_history()
	var steps := _steps()
	steps.remove_at(selected_step_index)
	_set_steps(steps)
	selected_step_index = mini(selected_step_index, steps.size() - 1)
	_refresh_after_edit()
	return true


func move_step(direction: int) -> bool:
	if not _has_selected_step():
		return false
	var steps := _steps()
	var target_index := selected_step_index + direction
	if target_index < 0 or target_index >= steps.size():
		return false
	_record_history()
	var value: Variant = steps[selected_step_index]
	steps[selected_step_index] = steps[target_index]
	steps[target_index] = value
	selected_step_index = target_index
	_set_steps(steps)
	_refresh_after_edit()
	return true


func undo() -> bool:
	if undo_stack.is_empty():
		return false
	redo_stack.append(_snapshot())
	_restore(undo_stack.pop_back())
	return true


func redo() -> bool:
	if redo_stack.is_empty():
		return false
	undo_stack.append(_snapshot())
	_restore(redo_stack.pop_back())
	return true


func save_guides() -> bool:
	diagnostics = Validator.validate(current_data)
	_show_diagnostics()
	if _has_errors() or current_data == saved_data:
		_update_buttons()
		return false
	var result := JsonService.save_dictionary(guide_path, current_data)
	if not result.get("ok", false):
		diagnostics.append({"severity": "error", "code": "save_failed", "location": guide_path, "message": result.get("error", "保存失败。")})
		_show_diagnostics()
		_update_buttons()
		return false
	saved_data = current_data.duplicate(true)
	_update_buttons()
	return true


func _refresh_all() -> void:
	diagnostics = Validator.validate(current_data)
	_refresh_guide_tree()
	_refresh_step_tree()
	_show_diagnostics()
	_update_summary()
	if selected_guide_index >= 0:
		select_guide(selected_guide_index)
	else:
		_set_inspector_enabled(false)
	_update_buttons()


func _refresh_after_edit() -> void:
	diagnostics = Validator.validate(current_data)
	_refresh_guide_tree()
	_refresh_step_tree()
	_show_diagnostics()
	_update_summary()
	select_step(selected_step_index)
	_update_buttons()


func _refresh_guide_tree() -> void:
	guide_tree.clear()
	var root := guide_tree.create_item()
	for guide_index in _guides().size():
		var guide_value: Variant = _guides()[guide_index]
		var guide := guide_value as Dictionary if guide_value is Dictionary else {}
		var item := guide_tree.create_item(root)
		item.set_text(0, str(guide.get("id", "无效 Guide")))
		item.set_metadata(0, guide_index)


func _refresh_step_tree() -> void:
	step_tree.clear()
	var root := step_tree.create_item()
	for step_index in _steps().size():
		var step_value: Variant = _steps()[step_index]
		var step := step_value as Dictionary if step_value is Dictionary else {}
		var item := step_tree.create_item(root)
		item.set_text(0, "%02d  %s" % [step_index + 1, str(step.get("id", "无效步骤"))])
		item.set_text(1, str(step.get("type", "message")))
		item.set_metadata(0, step_index)


func _show_diagnostics() -> void:
	diagnostics_tree.clear()
	var root := diagnostics_tree.create_item()
	for diagnostic in diagnostics:
		var item := diagnostics_tree.create_item(root)
		item.set_text(0, "错误" if diagnostic.get("severity") == "error" else "警告")
		item.set_text(1, str(diagnostic.get("location", "")))
		item.set_text(2, str(diagnostic.get("message", "")))


func _update_summary() -> void:
	var step_count := 0
	for guide_value in _guides():
		if guide_value is Dictionary and (guide_value as Dictionary).get("steps", []) is Array:
			step_count += ((guide_value as Dictionary).get("steps", []) as Array).size()
	%Summary.text = "%d 个 Guide | %d 个步骤 | %d 个错误" % [_guides().size(), step_count, diagnostics.size()]


func _setup_trees() -> void:
	step_tree.set_column_title(0, "步骤")
	step_tree.set_column_title(1, "类型")
	diagnostics_tree.set_column_title(0, "级别")
	diagnostics_tree.set_column_title(1, "位置")
	diagnostics_tree.set_column_title(2, "说明")


func _update_type_fields(_selected_index: int) -> void:
	var is_story := str(%StepTypeSelect.get_item_metadata(%StepTypeSelect.selected)) == "play_story"
	%StoryFields.visible = is_story
	%ActionFields.visible = not is_story


func _set_inspector_enabled(enabled: bool) -> void:
	%Inspector.visible = enabled
	%AddStepButton.disabled = selected_guide_index < 0


func _update_buttons() -> void:
	var has_step := _has_selected_step()
	%UndoButton.disabled = undo_stack.is_empty()
	%RedoButton.disabled = redo_stack.is_empty()
	%SaveButton.disabled = current_data == saved_data or _has_errors()
	%MoveUpButton.disabled = not has_step or selected_step_index <= 0
	%MoveDownButton.disabled = not has_step or selected_step_index >= _steps().size() - 1
	%DeleteStepButton.disabled = not has_step


func _guides() -> Array:
	return current_data.get("guides", []) as Array if current_data.get("guides", []) is Array else []


func _steps() -> Array:
	if selected_guide_index < 0 or selected_guide_index >= _guides().size() or not _guides()[selected_guide_index] is Dictionary:
		return []
	var value: Variant = (_guides()[selected_guide_index] as Dictionary).get("steps", [])
	return (value as Array).duplicate(true) if value is Array else []


func _set_steps(steps: Array) -> void:
	var guides := _guides()
	var guide := (guides[selected_guide_index] as Dictionary).duplicate(true)
	guide["steps"] = steps
	guides[selected_guide_index] = guide
	current_data["guides"] = guides


func _step_count(guide_index: int) -> int:
	if guide_index < 0 or guide_index >= _guides().size() or not _guides()[guide_index] is Dictionary:
		return 0
	var value: Variant = (_guides()[guide_index] as Dictionary).get("steps", [])
	return (value as Array).size() if value is Array else 0


func _has_selected_step() -> bool:
	return selected_step_index >= 0 and selected_step_index < _steps().size()


func _has_errors() -> bool:
	return diagnostics.any(func(diagnostic: Dictionary) -> bool: return diagnostic.get("severity") == "error")


func _snapshot() -> Dictionary:
	return {"data": current_data.duplicate(true), "guide_index": selected_guide_index, "step_index": selected_step_index}


func _record_history() -> void:
	undo_stack.append(_snapshot())
	redo_stack.clear()


func _restore(snapshot: Dictionary) -> void:
	current_data = (snapshot.get("data", {}) as Dictionary).duplicate(true)
	selected_guide_index = int(snapshot.get("guide_index", -1))
	selected_step_index = int(snapshot.get("step_index", -1))
	_refresh_after_edit()


func _unique_step_id(steps: Array) -> String:
	var used := {}
	for step_value in steps:
		if step_value is Dictionary:
			used[str((step_value as Dictionary).get("id", ""))] = true
	var suffix := steps.size() + 1
	while used.has("new_step_%d" % suffix):
		suffix += 1
	return "new_step_%d" % suffix


func _select_step_type(step_type: String) -> void:
	for type_index in %StepTypeSelect.item_count:
		if str(%StepTypeSelect.get_item_metadata(type_index)) == step_type:
			%StepTypeSelect.select(type_index)
			_update_type_fields(type_index)
			return
	%StepTypeSelect.select(0)
	_update_type_fields(0)


func _select_guide_tree_item(guide_index: int) -> void:
	var item := guide_tree.get_root().get_first_child() if guide_tree.get_root() != null else null
	while item != null:
		if int(item.get_metadata(0)) == guide_index:
			item.select(0)
			return
		item = item.get_next()


func _select_step_tree_item(step_index: int) -> void:
	var item := step_tree.get_root().get_first_child() if step_tree.get_root() != null else null
	while item != null:
		if int(item.get_metadata(0)) == step_index:
			item.select(0)
			return
		item = item.get_next()


func _on_guide_selected() -> void:
	var item := guide_tree.get_selected()
	if item != null:
		select_guide(int(item.get_metadata(0)))


func _on_step_selected() -> void:
	var item := step_tree.get_selected()
	if item != null:
		select_step(int(item.get_metadata(0)))