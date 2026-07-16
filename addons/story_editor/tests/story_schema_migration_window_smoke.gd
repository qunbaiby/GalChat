extends SceneTree

const WindowScene = preload("res://addons/story_editor/ui/story_schema_migration_window.tscn")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var window := WindowScene.instantiate() as Window
	root.add_child(window)
	await process_frame
	window.open_editor()
	await process_frame
	var tree := window.get_node("Root/Body/MigrationTree") as Tree
	var tree_root := tree.get_root()
	_expect(window.visible, "Schema 迁移窗口未显示。")
	_expect(not window.wrap_controls, "Schema 迁移窗口不应被内容撑大。")
	_expect(tree_root != null and tree_root.get_child_count() == window.scan_results.size(), "Schema 扫描结果未填充列表。")
	_expect(window.scan_results.size() > 0, "Schema 迁移窗口未扫描到真实文档。")
	_expect(window.scan_results.any(func(result: Dictionary) -> bool: return result.status == "unversioned"), "真实无版本文档未显示可迁移状态。")
	var first_migratable := -1
	for result_index in window.scan_results.size():
		if window.scan_results[result_index].get("can_apply", false):
			first_migratable = result_index
			break
	_expect(first_migratable >= 0, "没有找到可预览的 Schema 迁移。")
	if first_migratable >= 0:
		var item := tree_root.get_child(first_migratable)
		item.select(0)
		window.call("_on_item_selected")
		_expect(not (window.get_node("Root/Body/PreviewPanel/ApplyButton") as Button).disabled, "可迁移文档未启用应用按钮。")
		_expect((window.get_node("Root/Body/PreviewPanel/PreviewText") as TextEdit).text.contains("/schema_version"), "迁移预览未展示版本字段变更。")
	window.queue_free()
	if failures.is_empty():
		print("STORY_SCHEMA_MIGRATION_WINDOW_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("STORY_SCHEMA_MIGRATION_WINDOW_SMOKE: %s" % failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)