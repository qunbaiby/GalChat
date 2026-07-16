@tool
extends Control

const JsonService = preload("res://addons/story_editor/core/story_json_service.gd")
const MobileChatScanner = preload("res://addons/story_editor/core/mobile_fixed_chat_scanner.gd")
const MobileChatValidator = preload("res://addons/story_editor/core/mobile_chat_validator.gd")
const MessageNodeScene = preload("res://addons/story_editor/ui/mobile_chat_message_node.tscn")
const WINDOW_LAYOUT_PATH := "res://addons/story_editor/core/editor_window_layout.gd"

const FLOW_COLOR := Color("#d7e1e8")
const OPTION_COLOR := Color("#58c99b")

var chats: Array[Dictionary] = []
var current_path := ""
var current_data: Dictionary = {}
var saved_data: Dictionary = {}
var selected_chat_index := -1
var selected_message_index := -1
var undo_stack: Array[Dictionary] = []
var redo_stack: Array[Dictionary] = []
var dirty := false
var embedded_mode := false

@onready var summary: Label = %Summary
@onready var chat_tree: Tree = %ChatTree
@onready var graph_edit: GraphEdit = %MessageGraph
@onready var diagnostics_tree: Tree = %DiagnosticsTree
@onready var inspector: VBoxContainer = %Inspector
@onready var body_split: HSplitContainer = $Root/Body
@onready var workspace_split: HSplitContainer = %Workspace
@onready var vertical_workspace: VSplitContainer = %VerticalWorkspace


func _ready() -> void:
	resized.connect(_apply_responsive_layout)
	%RefreshButton.pressed.connect(refresh_catalog)
	%ArrangeButton.pressed.connect(graph_edit.arrange_nodes)
	%AddMessageButton.pressed.connect(add_message)
	%DeleteMessageButton.pressed.connect(delete_selected_message)
	%MoveUpButton.pressed.connect(move_selected_message.bind(-1))
	%MoveDownButton.pressed.connect(move_selected_message.bind(1))
	%UndoButton.pressed.connect(undo)
	%RedoButton.pressed.connect(redo)
	%SaveButton.pressed.connect(save_current_chat)
	%ApplyCompletionButton.pressed.connect(apply_completion_events)
	_ensure_chat_tree_connections()
	graph_edit.connection_request.connect(_on_connection_request)
	graph_edit.disconnection_request.connect(_on_disconnection_request)
	graph_edit.begin_node_move.connect(_on_graph_move_started)
	graph_edit.end_node_move.connect(_on_graph_move_finished)
	inspector.connect("apply_requested", _apply_message)
	_setup_trees()
	_update_history_buttons()
	call_deferred("_apply_responsive_layout")


func open_catalog() -> void:
	_ensure_chat_tree_connections()
	show()
	call_deferred("_finish_open_catalog")


func set_embedded_mode(enabled: bool) -> void:
	embedded_mode = enabled
	$Root/Header.visible = not enabled
	$Root/Hint.visible = not enabled
	$Root/Body/ChatTree.visible = not enabled
	if enabled:
		body_split.split_offset = 0
	call_deferred("_apply_responsive_layout")


func _finish_open_catalog() -> void:
	_apply_responsive_layout()
	refresh_catalog()
	call_deferred("_ensure_selected_chat_loaded")


func refresh_catalog() -> void:
	chats = MobileChatScanner.scan()
	selected_chat_index = 0 if not chats.is_empty() else -1
	chat_tree.clear()
	var root := chat_tree.create_item()
	var reference_count := 0
	for chat_index in chats.size():
		var chat := chats[chat_index]
		var references := chat.get("references", []) as Array
		reference_count += references.size()
		var item := chat_tree.create_item(root)
		item.set_text(0, "%s\n%s · %d 条消息 · %d 个完成动作" % [
			str(chat.get("id", "")),
			str(chat.get("character_id", "未指定角色")),
			int(chat.get("message_count", 0)),
			int(chat.get("completion_event_count", 0))
		])
		item.set_tooltip_text(0, "剧情引用：%s\n%s" % [_format_references(references), str(chat.get("path", ""))])
		item.set_custom_minimum_height(48)
		item.set_metadata(0, chat_index)
	summary.text = "%d 个固定聊天 · %d 处剧情引用" % [chats.size(), reference_count]
	if selected_chat_index >= 0:
		select_chat(selected_chat_index)
	else:
		_show_diagnostics([])
	call_deferred("_ensure_selected_chat_loaded")


func _setup_trees() -> void:
	chat_tree.select_mode = Tree.SELECT_ROW
	chat_tree.set_column_title(0, "固定聊天资源")
	chat_tree.set_column_expand(0, true)
	diagnostics_tree.set_column_title(0, "级别")
	diagnostics_tree.set_column_title(1, "位置")
	diagnostics_tree.set_column_title(2, "说明")
	diagnostics_tree.set_column_expand(0, false)
	diagnostics_tree.set_column_custom_minimum_width(0, 80)
	diagnostics_tree.set_column_custom_minimum_width(1, 160)


func _ensure_chat_tree_connections() -> void:
	for connection in chat_tree.item_selected.get_connections():
		var callable := connection.get("callable", Callable()) as Callable
		if callable.is_valid() and callable.get_object() == self:
			chat_tree.item_selected.disconnect(callable)
	for connection in chat_tree.item_mouse_selected.get_connections():
		var callable := connection.get("callable", Callable()) as Callable
		if callable.is_valid() and callable.get_object() == self:
			chat_tree.item_mouse_selected.disconnect(callable)
	for connection in chat_tree.gui_input.get_connections():
		var callable := connection.get("callable", Callable()) as Callable
		if callable.is_valid() and callable.get_object() == self:
			chat_tree.gui_input.disconnect(callable)
	chat_tree.gui_input.connect(_on_chat_tree_gui_input)


func select_chat(chat_index: int) -> void:
	if chat_index < 0 or chat_index >= chats.size():
		selected_chat_index = -1
		_clear_graph()
		inspector.clear()
		_update_history_buttons()
		return
	selected_chat_index = chat_index
	var chat := chats[chat_index]
	var chat_path := str(chat.get("path", ""))
	summary.text = "正在加载：%s" % str(chat.get("id", ""))
	var result := JsonService.load_dictionary(chat_path)
	if not result.get("ok", false):
		_clear_graph()
		var error_message := str(result.get("error", "读取失败"))
		%CurrentChat.text = "加载失败：%s" % error_message
		summary.text = "加载失败：%s" % error_message
		_show_diagnostics([{"severity": "error", "location": "文件", "message": error_message}])
		return
	load_chat(chat_path, result.get("data", {}) as Dictionary)
	_select_tree_index(chat_index)
	_update_summary_text()


func _on_chat_tree_gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	var item := chat_tree.get_item_at_position(mouse_event.position)
	if item != null:
		select_chat(int(item.get_metadata(0)))
		chat_tree.accept_event()


func _ensure_selected_chat_loaded() -> void:
	if not current_path.is_empty() and not current_data.is_empty():
		return
	var item := chat_tree.get_selected()
	if item != null:
		select_chat(int(item.get_metadata(0)))
	elif selected_chat_index >= 0:
		select_chat(selected_chat_index)


func _update_summary_text() -> void:
	var reference_count := 0
	for chat in chats:
		reference_count += (chat.get("references", []) as Array).size()
	summary.text = "%d 个固定聊天 · %d 处剧情引用" % [chats.size(), reference_count]


func _select_tree_index(chat_index: int) -> void:
	var root := chat_tree.get_root()
	if root != null and chat_index >= 0 and chat_index < root.get_child_count():
		var item := root.get_child(chat_index)
		if chat_tree.get_selected() != item:
			item.select(0)


func load_chat(path: String, data: Dictionary) -> void:
	current_path = path
	current_data = data.duplicate(true)
	saved_data = current_data.duplicate(true)
	dirty = false
	selected_message_index = -1
	undo_stack.clear()
	redo_stack.clear()
	_update_title()
	_update_history_buttons()
	%CompletionEventsEdit.text = JSON.stringify(current_data.get("on_complete_events", []), "    ")
	_rebuild_graph()
	_show_diagnostics(MobileChatValidator.validate(current_data))
	if is_instance_valid(inspector) and inspector.has_method("clear"):
		inspector.call("clear")


func _rebuild_graph() -> void:
	_clear_graph()
	var messages := current_data.get("messages", []) as Array
	var id_to_index := {}
	var previous_node: GraphNode
	for message_index in messages.size():
		var message_value: Variant = messages[message_index]
		if not message_value is Dictionary:
			continue
		var message := message_value as Dictionary
		var message_node := MessageNodeScene.instantiate() as GraphNode
		if message_node == null:
			continue
		graph_edit.add_child(message_node)
		message_node.setup(message_index, message)
		message_node.message_activated.connect(select_message)
		id_to_index[str(message.get("id", ""))] = message_index
		if previous_node != null and str((messages[message_index - 1] as Dictionary).get("speaker", "")) != "player_options":
			graph_edit.connect_node(previous_node.name, 0, message_node.name, 0, true)
		previous_node = message_node
	_connect_option_edges(messages, id_to_index)
	call_deferred("_focus_graph_start")


func _apply_responsive_layout() -> void:
	if not is_instance_valid(body_split) or not is_instance_valid(workspace_split) or not is_instance_valid(vertical_workspace):
		return
	var content_width := maxi(size.x - 28, 1)
	var catalog_width := 0 if embedded_mode else clampi(roundi(content_width * 0.24), 250, 340)
	body_split.split_offset = 0 if embedded_mode else mini(catalog_width, maxi(250, content_width - 500))
	var editor_width := maxi(content_width - catalog_width - (0 if embedded_mode else 8), 1)
	workspace_split.split_offset = clampi(roundi(editor_width * (0.72 if embedded_mode else 0.64)), 360, maxi(360, editor_width - 240))
	var editor_height := maxi(body_split.size.y - 40, 1)
	vertical_workspace.split_offset = clampi(roundi(editor_height * 0.68), 220, maxi(220, editor_height - 150))


func _focus_graph_start() -> void:
	graph_edit.scroll_offset = Vector2.ZERO
	var first_node := graph_edit.get_node_or_null("message_0") as GraphNode
	if first_node == null:
		return
	var viewport_size := graph_edit.size / graph_edit.zoom
	graph_edit.scroll_offset = Vector2(
		maxf(0.0, first_node.position_offset.x - viewport_size.x * 0.12),
		maxf(0.0, first_node.position_offset.y - viewport_size.y * 0.12)
	)


func _connect_option_edges(messages: Array, id_to_index: Dictionary) -> void:
	for message_index in messages.size():
		var message_value: Variant = messages[message_index]
		if not message_value is Dictionary:
			continue
		var message := message_value as Dictionary
		if str(message.get("speaker", "")) != "player_options":
			continue
		var options := message.get("options", []) as Array
		for option_index in options.size():
			var option_value: Variant = options[option_index]
			if not option_value is Dictionary:
				continue
			var target_id := str((option_value as Dictionary).get("next", ""))
			if not id_to_index.has(target_id):
				continue
			var target_index := int(id_to_index[target_id])
			graph_edit.connect_node(
				"message_%d" % message_index,
				option_index,
				"message_%d" % target_index,
				0,
				true
			)


func _clear_graph() -> void:
	graph_edit.clear_connections()
	for child in graph_edit.get_children():
		if child is GraphNode:
			graph_edit.remove_child(child)
			child.queue_free()


func select_message(message_index: int) -> void:
	var messages := current_data.get("messages", []) as Array
	if message_index < 0 or message_index >= messages.size() or not messages[message_index] is Dictionary:
		selected_message_index = -1
		inspector.clear()
		return
	selected_message_index = message_index
	for child in graph_edit.get_children():
		if child is GraphNode:
			child.selected = int(child.message_index) == message_index
	inspector.setup(messages[message_index] as Dictionary, _message_ids())


func _apply_message(message: Dictionary) -> void:
	var messages := current_data.get("messages", []) as Array
	if selected_message_index < 0 or selected_message_index >= messages.size():
		return
	_record_history()
	var updated_message := message.duplicate(true)
	var previous_message := messages[selected_message_index] as Dictionary
	if previous_message.has("_editor_position"):
		updated_message["_editor_position"] = (previous_message.get("_editor_position", {}) as Dictionary).duplicate(true)
	messages[selected_message_index] = updated_message
	_refresh_after_edit(selected_message_index)


func _on_graph_move_started() -> void:
	_record_history()


func _on_graph_move_finished() -> void:
	if not _commit_graph_positions():
		if not undo_stack.is_empty():
			undo_stack.pop_back()
		_update_history_buttons()
		return
	_refresh_dirty_state()


func _commit_graph_positions() -> bool:
	var messages := current_data.get("messages", []) as Array
	var changed := false
	for child in graph_edit.get_children():
		if not child is GraphNode or not "message_index" in child:
			continue
		var message_index := int(child.message_index)
		if message_index < 0 or message_index >= messages.size() or not messages[message_index] is Dictionary:
			continue
		var message := messages[message_index] as Dictionary
		var position_data := {"x": child.position_offset.x, "y": child.position_offset.y}
		if message.get("_editor_position", {}) != position_data:
			message["_editor_position"] = position_data
			changed = true
	return changed


func add_message() -> bool:
	if current_data.is_empty():
		return false
	var messages := current_data.get("messages", []) as Array
	var insert_index := selected_message_index + 1 if selected_message_index >= 0 else messages.size()
	_record_history()
	messages.insert(insert_index, {
		"id": _unique_message_id(messages),
		"speaker": str(current_data.get("character_id", "")),
		"text": "新消息",
		"delay": 0
	})
	_refresh_after_edit(insert_index)
	return true


func delete_selected_message() -> bool:
	var messages := current_data.get("messages", []) as Array
	if selected_message_index < 0 or selected_message_index >= messages.size() or messages.size() <= 1:
		return false
	_record_history()
	messages.remove_at(selected_message_index)
	var next_index := mini(selected_message_index, messages.size() - 1)
	_refresh_after_edit(next_index)
	return true


func move_selected_message(direction: int) -> bool:
	var messages := current_data.get("messages", []) as Array
	var target_index := selected_message_index + direction
	if selected_message_index < 0 or target_index < 0 or target_index >= messages.size():
		return false
	_record_history()
	var message_value: Variant = messages[selected_message_index]
	messages[selected_message_index] = messages[target_index]
	messages[target_index] = message_value
	_refresh_after_edit(target_index)
	return true


func _on_connection_request(from_node: StringName, from_port: int, to_node: StringName, _to_port: int) -> void:
	var source := graph_edit.get_node_or_null(NodePath(from_node))
	var target := graph_edit.get_node_or_null(NodePath(to_node))
	if source == null or target == null:
		return
	set_option_next(int(source.message_index), int(from_port), int(target.message_index))


func _on_disconnection_request(from_node: StringName, from_port: int, _to_node: StringName, _to_port: int) -> void:
	var source := graph_edit.get_node_or_null(NodePath(from_node))
	if source != null:
		set_option_next(int(source.message_index), int(from_port), -1)


func set_option_next(message_index: int, option_index: int, target_message_index: int) -> bool:
	var messages := current_data.get("messages", []) as Array
	if message_index < 0 or message_index >= messages.size() or not messages[message_index] is Dictionary:
		return false
	var message := messages[message_index] as Dictionary
	if str(message.get("speaker", "")) != "player_options":
		return false
	var options := message.get("options", []) as Array
	if option_index < 0 or option_index >= options.size() or not options[option_index] is Dictionary:
		return false
	_record_history()
	var option := options[option_index] as Dictionary
	if target_message_index < 0:
		option.erase("next")
	elif target_message_index < messages.size() and messages[target_message_index] is Dictionary:
		option["next"] = str((messages[target_message_index] as Dictionary).get("id", ""))
	else:
		undo_stack.pop_back()
		_update_history_buttons()
		return false
	_refresh_after_edit(message_index)
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


func save_current_chat() -> bool:
	if current_path.is_empty() or current_data.is_empty():
		return false
	var diagnostics := MobileChatValidator.validate(current_data)
	_show_diagnostics(diagnostics)
	for diagnostic in diagnostics:
		if str(diagnostic.get("severity", "")) == "error":
			return false
	var result := JsonService.save_dictionary(current_path, current_data)
	if not result.get("ok", false):
		return false
	saved_data = current_data.duplicate(true)
	dirty = false
	_update_title()
	return true


func apply_completion_events() -> bool:
	var parsed: Variant = JSON.parse_string(%CompletionEventsEdit.text)
	if not parsed is Array:
		_show_diagnostics([{"severity": "error", "location": "完成动作", "message": "完成动作必须是有效 JSON 数组。"}])
		return false
	_record_history()
	current_data["on_complete_events"] = (parsed as Array).duplicate(true)
	_refresh_dirty_state()
	_show_diagnostics(MobileChatValidator.validate(current_data))
	return true


func has_unsaved_changes() -> bool:
	return dirty


func _record_history() -> void:
	undo_stack.append(_make_snapshot())
	redo_stack.clear()
	_update_history_buttons()


func _make_snapshot() -> Dictionary:
	return {"data": current_data.duplicate(true), "message_index": selected_message_index}


func _restore_snapshot(snapshot: Dictionary) -> void:
	current_data = (snapshot.get("data", {}) as Dictionary).duplicate(true)
	selected_message_index = int(snapshot.get("message_index", -1))
	%CompletionEventsEdit.text = JSON.stringify(current_data.get("on_complete_events", []), "    ")
	_rebuild_graph()
	select_message(selected_message_index)
	_refresh_dirty_state()
	_show_diagnostics(MobileChatValidator.validate(current_data))
	_update_history_buttons()


func _refresh_after_edit(message_index: int) -> void:
	_refresh_dirty_state()
	_rebuild_graph()
	select_message(message_index)
	_show_diagnostics(MobileChatValidator.validate(current_data))


func _refresh_dirty_state() -> void:
	dirty = current_data != saved_data
	_update_title()
	_update_history_buttons()


func _update_title() -> void:
	var dirty_marker := " *" if dirty else ""
	%CurrentChat.text = "%s · %s%s" % [str(current_data.get("id", "未命名聊天")), str(current_data.get("character_id", "未指定角色")), dirty_marker]


func _update_history_buttons() -> void:
	var has_document := not current_path.is_empty() and not current_data.is_empty()
	%UndoButton.disabled = undo_stack.is_empty()
	%RedoButton.disabled = redo_stack.is_empty()
	%SaveButton.disabled = current_path.is_empty() or not dirty
	%AddMessageButton.disabled = not has_document
	%DeleteMessageButton.disabled = not has_document or selected_message_index < 0
	%MoveUpButton.disabled = not has_document or selected_message_index <= 0
	%MoveDownButton.disabled = not has_document or selected_message_index < 0 or selected_message_index >= (current_data.get("messages", []) as Array).size() - 1
	%ArrangeButton.disabled = not has_document
	%ApplyCompletionButton.disabled = not has_document


func _message_ids() -> Array[String]:
	var ids: Array[String] = []
	for message_value in current_data.get("messages", []):
		if message_value is Dictionary:
			ids.append(str((message_value as Dictionary).get("id", "")))
	return ids


func _unique_message_id(messages: Array) -> String:
	var used_ids := {}
	for message_value in messages:
		if message_value is Dictionary:
			used_ids[str((message_value as Dictionary).get("id", ""))] = true
	var suffix := messages.size() + 1
	while used_ids.has("m%d" % suffix):
		suffix += 1
	return "m%d" % suffix


func _show_diagnostics(diagnostics: Array) -> void:
	diagnostics_tree.clear()
	var root := diagnostics_tree.create_item()
	if diagnostics.is_empty():
		var item := diagnostics_tree.create_item(root)
		item.set_text(0, "OK")
		item.set_text(2, "消息图结构与引用格式有效。")
		return
	for diagnostic_value in diagnostics:
		if not diagnostic_value is Dictionary:
			continue
		var diagnostic := diagnostic_value as Dictionary
		var item := diagnostics_tree.create_item(root)
		item.set_text(0, str(diagnostic.get("severity", "warning")).to_upper())
		item.set_text(1, str(diagnostic.get("location", "")))
		item.set_text(2, str(diagnostic.get("message", "")))


func _format_references(references: Array) -> String:
	var labels: Array[String] = []
	for reference_value in references:
		if reference_value is Dictionary:
			var reference := reference_value as Dictionary
			labels.append("%s (%s)" % [str(reference.get("story_id", "")), str(reference.get("timing", "immediate"))])
	return "、".join(labels) if not labels.is_empty() else "未被剧情引用"

