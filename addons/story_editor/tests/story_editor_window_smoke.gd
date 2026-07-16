extends SceneTree

const WindowScene = preload("res://addons/story_editor/ui/story_editor_window.tscn")
const WINDOW_LAYOUT_PATH := "res://addons/story_editor/core/editor_window_layout.gd"

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var compact_geometry: Dictionary = (load(WINDOW_LAYOUT_PATH) as GDScript).new().calculate_geometry(Rect2i(100, 50, 800, 600), Vector2i(1500, 900), Vector2i(720, 520))
	var compact_rect := Rect2i(compact_geometry.position, compact_geometry.size)
	_expect(Rect2i(100, 50, 800, 600).encloses(compact_rect), "小屏窗口没有被限制在可用区域内。")
	_expect(compact_rect.position.y >= 50 + 56, "小屏窗口没有为系统标题栏预留顶部安全区。")
	_expect(compact_rect.end.y <= 50 + 600 - 32, "小屏窗口没有为底部边框预留安全区。")
	_expect((compact_geometry.min_size as Vector2i).x <= compact_rect.size.x and (compact_geometry.min_size as Vector2i).y <= compact_rect.size.y, "窗口最小尺寸大于实际可用尺寸。")
	var editor_window := WindowScene.instantiate() as Window
	root.add_child(editor_window)
	await process_frame
	await process_frame
	var editor := editor_window.get_node_or_null("StoryEditorMain") as Control
	_expect(editor != null, "独立窗口没有包含剧情编辑器主界面。")
	_expect(editor_window.size.x >= 1400 and editor_window.size.y >= 850, "独立窗口默认尺寸过小。")
	_expect(editor_window.min_size.x >= 1000 and editor_window.min_size.y >= 650, "独立窗口最小尺寸不足。")
	if editor != null:
		_expect(editor.anchor_right == 1.0 and editor.anchor_bottom == 1.0, "剧情编辑器内容没有填满独立窗口。")
		_expect(editor.has_method("load_story"), "独立窗口内的剧情编辑器脚本没有加载。")
		var body := editor.get_node("Root/Body") as Control
		var body_rect := body.get_global_rect()
		var library_panel := editor.get_node("Root/Body/LibraryPanel") as Control
		var story_workspace := editor.get_node("Root/Body/WorkspaceSplit/Workspace") as Control
		var story_inspector := editor.get_node("Root/Body/WorkspaceSplit/Inspector") as Control
		var expected_inspector_width := 350.0 if body.size.x >= 1300.0 else 235.0
		_expect(story_inspector.size.x >= expected_inspector_width, "主线与地图右侧面板宽度异常（Inspector %.0f / Workspace %.0f / Body %.0f）。" % [story_inspector.size.x, (editor.get_node("Root/Body/WorkspaceSplit") as Control).size.x, body.size.x])
		_expect(body_rect.encloses(library_panel.get_global_rect()), "左侧剧情库超出主窗口边界。")
		_expect(body_rect.encloses(story_workspace.get_global_rect()), "剧情画布超出主窗口边界。")
		_expect(body_rect.encloses(story_inspector.get_global_rect()), "右侧事件编辑面板超出主窗口边界。")
		var story_tree := editor.get_node("Root/Body/LibraryPanel/StoryTree") as Tree
		var library_root := story_tree.get_root()
		var category_labels: Array[String] = []
		for category in library_root.get_children():
			category_labels.append(category.get_text(0))
		_expect(category_labels == ["主线剧情", "地图世界", "手机消息", "固定来电"], "左侧固定内容没有按四类展示。")
		_expect(library_root.get_child(2).get_child_count() > 0 and library_root.get_child(3).get_child_count() > 0, "手机消息或固定来电分类没有填充条目。")
		_expect((library_root.get_child(2).get_first_child().get_metadata(0) as Dictionary).kind == "mobile_chat", "手机消息条目没有使用统一入口元数据。")
		_expect((library_root.get_child(3).get_first_child().get_metadata(0) as Dictionary).kind == "fixed_call", "固定来电条目没有使用统一入口元数据。")
		library_root.get_child(2).get_first_child().select(0)
		editor.call("_on_story_selected")
		await process_frame
		await process_frame
		var mobile_editor := editor.get_node("Root/Body/MobileChatEmbed/MobileChatCatalogWindow")
		_expect((editor.get_node("Root/Body/MobileChatEmbed") as Control).visible and mobile_editor.selected_chat_index == 0, "左侧手机消息入口未在主工作区打开并定位对应聊天。")
		_expect(not (mobile_editor.get_node("Root/Body/ChatTree") as Tree).visible, "内嵌手机消息仍显示重复资源列表。")
		var mobile_workspace := mobile_editor.get_node("Root/Body/Editor/VerticalWorkspace/Workspace") as HSplitContainer
		_expect(mobile_workspace.split_offset >= roundi(mobile_workspace.size.x * 0.68), "内嵌手机消息节点画布占比不足。")
		library_root.get_child(3).get_first_child().select(0)
		editor.call("_on_story_selected")
		await process_frame
		await process_frame
		var call_editor := editor.get_node("Root/Body/FixedCallEmbed/FixedVoiceCallCatalogWindow")
		_expect((editor.get_node("Root/Body/FixedCallEmbed") as Control).visible and call_editor.selected_call_index == 0, "左侧固定来电入口未在主工作区打开并定位对应来电。")
		_expect(not (call_editor.get_node("Root/Body/Library") as VBoxContainer).visible, "内嵌固定来电仍显示重复资源列表。")
		_expect(not (editor.get_node("Root/Body/WorkspaceSplit") as Control).visible, "固定内容内嵌时剧情节点工作区仍然可见。")
		_expect((editor.get_node("Root/ToolMenuBar/StoryToolsMenu") as MenuButton).visible, "剧情工具菜单不可见。")
		_expect((editor.get_node("Root/ToolMenuBar/ContentToolsMenu") as MenuButton).visible, "内容库菜单不可见。")
		_expect((editor.get_node("Root/ToolMenuBar/SystemToolsMenu") as MenuButton).visible, "系统工具菜单不可见。")
		var content_popup := (editor.get_node("Root/ToolMenuBar/ContentToolsMenu") as MenuButton).get_popup()
		var content_labels: Array[String] = []
		for menu_index in content_popup.item_count:
			content_labels.append(content_popup.get_item_text(menu_index))
		_expect(content_labels == ["AI 约会", "手机 AI", "剧情引用", "Guide Flow", "入口调度"], "内容库仍包含重复入口或菜单顺序异常。")
		_expect(not (editor.get_node("Root/Toolbar/ValidateButton") as Button).visible, "旧平铺工具按钮仍在顶部占用空间。")
		editor.call("_open_create_content_dialog")
		var create_type := editor.get_node("CreateContentDialog/Form/CreateContentType") as OptionButton
		_expect(create_type.item_count == 4, "新建对话框未提供四种固定内容类型。")
		create_type.select(2)
		editor.call("_update_create_content_form", 2)
		_expect((editor.get_node("CreateContentDialog/Form/CreateContentCharacter") as LineEdit).visible, "手机消息类型未显示必填角色 ID。")
		create_type.select(0)
		editor.call("_update_create_content_form", 0)
		_expect(not (editor.get_node("CreateContentDialog/Form/CreateContentCharacter") as LineEdit).visible, "主线剧情类型仍显示无关角色 ID。")
		(editor.get_node("CreateContentDialog") as ConfirmationDialog).hide()
		var simulation_window := editor.get_node("BranchSimulationWindow") as Window
		var close_button := simulation_window.get_node("Root/Header/CloseSimulationButton") as Button
		simulation_window.show()
		close_button.pressed.emit()
		_expect(not simulation_window.visible, "分支模拟窗口的关闭按钮无效。")
		editor.dirty = true
		_expect(editor.has_unsaved_changes(), "独立窗口没有保留剧情编辑状态。")
	editor_window.show()
	editor_window.close_requested.connect(editor_window.hide)
	editor_window.close_requested.emit()
	_expect(not editor_window.visible, "关闭独立窗口后没有隐藏窗口。")
	editor_window.queue_free()
	await process_frame

	if failures.is_empty():
		print("STORY_EDITOR_WINDOW_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("STORY_EDITOR_WINDOW_SMOKE: %s" % failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)