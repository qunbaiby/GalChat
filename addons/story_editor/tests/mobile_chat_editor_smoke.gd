extends SceneTree

const CatalogScene = preload("res://addons/story_editor/ui/mobile_chat_catalog_window.tscn")
const JsonService = preload("res://addons/story_editor/core/story_json_service.gd")

const CHAT_PATH := "res://assets/data/mobile/fixed_chats/jing_piano_practice_invite.json"
const TEMP_PATH := "user://mobile_chat_editor_smoke.json"

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var load_result := JsonService.load_dictionary(CHAT_PATH)
	_expect(load_result.get("ok", false), "无法加载真实固定聊天。")
	var catalog := CatalogScene.instantiate() as Control
	root.add_child(catalog)
	await process_frame
	var add_button := catalog.get_node("Root/Body/Editor/EditorBar/AddMessageButton") as Button
	_expect(add_button.disabled, "尚未加载聊天时新增按钮不应可用。")
	catalog.open_catalog()
	await process_frame
	await process_frame
	var opened_tree := catalog.get_node("Root/Body/ChatTree") as Tree
	var opened_graph := catalog.get_node("Root/Body/Editor/VerticalWorkspace/Workspace/MessageGraph") as GraphEdit
	_expect(opened_tree.get_selected() != null, "真实打开手机消息窗口后左侧没有选中聊天。")
	_expect(not catalog.current_path.is_empty() and not catalog.current_data.is_empty(), "真实打开手机消息窗口后已选聊天没有加载。")
	_expect(opened_graph.get_node_or_null("message_0") != null, "真实打开手机消息窗口后没有生成消息节点。")
	_expect((catalog.get_node("Root/Body/Editor/EditorBar/CurrentChat") as Label).text != "尚未选择固定聊天", "真实打开手机消息窗口后标题仍显示未选择。")
	if load_result.get("ok", false):
		var fixture := (load_result.get("data", {}) as Dictionary).duplicate(true)
		fixture["smoke_unknown_root"] = {"preserve": true}
		var fixture_options := ((fixture.get("messages", []) as Array)[1] as Dictionary).get("options", []) as Array
		(fixture_options[0] as Dictionary)["smoke_unknown_option"] = 42
		var write_result := JsonService.save_dictionary(TEMP_PATH, fixture)
		_expect(write_result.get("ok", false), "无法写入手机编辑器临时 fixture。")
		catalog.load_chat(TEMP_PATH, fixture)
		await process_frame
		var loaded_height := catalog.size.y
		catalog.call("_rebuild_graph")
		await process_frame
		_expect(catalog.size.y == loaded_height, "重建手机消息节点后窗口高度发生变化。")
		_expect(not add_button.disabled, "加载聊天后新增按钮没有启用。")
		catalog.refresh_catalog()
		var catalog_tree := catalog.get_node("Root/Body/ChatTree") as Tree
		var catalog_root := catalog_tree.get_root()
		var first_catalog_item := catalog_root.get_child(0)
		_expect(catalog_root.get_child_count() == catalog.chats.size(), "手机消息资源列表数量不正确。")
		_expect(first_catalog_item.get_text(0).contains("条消息"), "手机消息资源条目缺少可读摘要。")
		_expect(catalog_tree.allow_reselect, "手机消息唯一条目不允许重复点击。")
		_expect(catalog_tree.get_selected() == first_catalog_item, "刷新后手机消息首项没有按固定来电模式同步选中。")
		_expect(catalog.selected_chat_index == 0, "刷新后手机消息选中索引没有同步。")
		_expect(not catalog.current_path.is_empty() and not catalog.current_data.is_empty(), "选中资源列表聊天后没有加载文档。")
		catalog.current_path = ""
		catalog.current_data.clear()
		catalog.call("_ensure_selected_chat_loaded")
		_expect(not catalog.current_path.is_empty() and not catalog.current_data.is_empty(), "已选中的聊天文档为空时保底加载没有恢复文档。")
		catalog.current_path = ""
		catalog.current_data.clear()
		var click_event := InputEventMouseButton.new()
		click_event.button_index = MOUSE_BUTTON_LEFT
		click_event.pressed = true
		click_event.position = catalog_tree.get_item_area_rect(first_catalog_item, 0).get_center()
		catalog.call("_on_chat_tree_gui_input", click_event)
		_expect(not catalog.current_path.is_empty() and not catalog.current_data.is_empty(), "真实 Tree 鼠标事件没有加载聊天文档。")
		catalog.load_chat(TEMP_PATH, fixture)
		var graph := catalog.get_node("Root/Body/Editor/VerticalWorkspace/Workspace/MessageGraph") as GraphEdit
		catalog.size = Vector2i(800, 600)
		catalog.call("_apply_responsive_layout")
		await process_frame
		_expect(graph.size.x >= 240 and graph.size.y >= 220, "窄窗口下手机消息画布被分栏压缩到不可用尺寸。")
		var vertical_workspace := catalog.get_node("Root/Body/Editor/VerticalWorkspace") as VSplitContainer
		var workspace := catalog.get_node("Root/Body/Editor/VerticalWorkspace/Workspace") as HSplitContainer
		var inspector_scroll := catalog.get_node("Root/Body/Editor/VerticalWorkspace/Workspace/InspectorScroll") as ScrollContainer
		var details_tabs := catalog.get_node("Root/Body/Editor/VerticalWorkspace/DetailsTabs") as TabContainer
		_expect(workspace.position.y + workspace.size.y <= vertical_workspace.size.y, "手机消息画布区域越出纵向工作区。")
		_expect(details_tabs.position.y + details_tabs.size.y <= vertical_workspace.size.y, "手机消息详情标签页越出纵向工作区。")
		_expect(inspector_scroll.position.y + inspector_scroll.size.y <= workspace.size.y, "消息 Inspector 越出画布工作区。")
		var message_nodes := graph.get_children().filter(func(child: Node) -> bool: return child is GraphNode)
		_expect(message_nodes.size() == 12, "真实固定聊天没有生成 12 个消息节点。")
		_expect(graph.get_node_or_null("message_0") != null and (graph.get_node("message_0") as GraphNode).visible, "选中手机剧情后首个消息节点不可见。")
		var connection_count := graph.get_connection_list().size()
		_expect(connection_count == 13, "自动消息顺序边和玩家选项分支边数量不符合运行时语义，实际为 %d。" % connection_count)
		var option_node := graph.get_node_or_null("message_1")
		_expect(option_node != null and option_node.get_option_index(1) == 1, "玩家选项端口没有映射到正确选项。")
		var normal_node := graph.get_node_or_null("message_0")
		_expect(normal_node != null and normal_node.get_option_index(0) == -1, "普通消息不应暴露可编辑选项端口。")
		catalog.select_message(1)
		await process_frame
		_expect(inspector_scroll.position.y + inspector_scroll.size.y <= workspace.size.y, "显示玩家选项后 Inspector 撑破画布工作区。")
		var message_position := Vector2(512.0, 284.0)
		catalog.call("_on_graph_move_started")
		(normal_node as GraphNode).position_offset = message_position
		catalog.call("_on_graph_move_finished")
		var positioned_message := ((catalog.current_data.get("messages", []) as Array)[0] as Dictionary)
		var positioned_data := positioned_message.get("_editor_position", {}) as Dictionary
		_expect(Vector2(float(positioned_data.get("x", 0.0)), float(positioned_data.get("y", 0.0))) == message_position, "拖拽位置没有写回手机消息。")
		catalog.call("_rebuild_graph")
		_expect((graph.get_node("message_0") as GraphNode).position_offset == message_position, "重建手机消息图后节点位置丢失。")
		catalog.select_message(0)
		_expect(catalog.add_message(), "无法在选中消息后新增消息。")
		_expect((catalog.current_data.get("messages", []) as Array).size() == 13, "新增消息没有写入文档。")
		_expect(catalog.move_selected_message(1), "新增消息无法下移。")
		_expect(catalog.delete_selected_message(), "新增消息无法删除。")
		_expect((catalog.current_data.get("messages", []) as Array).size() == 12, "删除消息没有恢复消息数量。")
		_expect(catalog.set_option_next(1, 0, 4), "无法修改玩家选项 next。")
		var changed_options := (((catalog.current_data.get("messages", []) as Array)[1] as Dictionary).get("options", []) as Array)
		_expect(str((changed_options[0] as Dictionary).get("next", "")) == "m4", "连接没有回写目标消息 ID。")
		_expect(catalog.has_unsaved_changes(), "连接修改后没有进入未保存状态。")
		_expect(catalog.undo(), "连接修改无法撤销。")
		var undone_options := (((catalog.current_data.get("messages", []) as Array)[1] as Dictionary).get("options", []) as Array)
		_expect(str((undone_options[0] as Dictionary).get("next", "")) == "m3", "撤销没有恢复原 next。")
		_expect(catalog.redo(), "连接修改无法重做。")
		var completion_edit := catalog.get_node("Root/Body/Editor/VerticalWorkspace/DetailsTabs/完成动作/CompletionEventsEdit") as TextEdit
		completion_edit.text = JSON.stringify([{"type": "activate_goal", "goal_id": "smoke_goal", "unknown": true}])
		_expect(catalog.apply_completion_events(), "有效完成动作 JSON 无法应用。")
		completion_edit.text = "{}"
		_expect(not catalog.apply_completion_events(), "非数组完成动作不应被应用。")
		_expect(catalog.save_current_chat(), "有效固定聊天无法保存。")
		var saved_result := JsonService.load_dictionary(TEMP_PATH)
		_expect(saved_result.get("ok", false), "保存后的固定聊天无法回读。")
		if saved_result.get("ok", false):
			var saved := saved_result.get("data", {}) as Dictionary
			var saved_options := (((saved.get("messages", []) as Array)[1] as Dictionary).get("options", []) as Array)
			_expect(str((saved_options[0] as Dictionary).get("next", "")) == "m4", "保存回读丢失分支目标。")
			_expect((saved.get("smoke_unknown_root", {}) as Dictionary).get("preserve", false), "保存丢失未知根字段。")
			_expect(int((saved_options[0] as Dictionary).get("smoke_unknown_option", 0)) == 42, "保存丢失未知选项字段。")
			var saved_completion := saved.get("on_complete_events", []) as Array
			_expect(saved_completion.size() == 1 and bool((saved_completion[0] as Dictionary).get("unknown", false)), "保存丢失完成动作或未知动作字段。")
			var saved_message_position := ((((saved.get("messages", []) as Array)[0] as Dictionary).get("_editor_position", {}) as Dictionary))
			_expect(Vector2(float(saved_message_position.get("x", 0.0)), float(saved_message_position.get("y", 0.0))) == message_position, "保存回读后手机消息节点位置丢失。")
	catalog.queue_free()
	await process_frame

	if failures.is_empty():
		print("MOBILE_CHAT_EDITOR_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("MOBILE_CHAT_EDITOR_SMOKE: %s" % failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)