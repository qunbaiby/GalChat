extends SceneTree

const WindowScene = preload("res://addons/story_editor/ui/story_coverage_report_window.tscn")
const DebugStore = preload("res://addons/story_editor/core/story_runtime_debug_store.gd")

var failures: Array[String] = []
var navigation: Dictionary = {}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var store := DebugStore.new()
	store.start_session(12)
	var window := WindowScene.instantiate()
	root.add_child(window)
	window.set_debug_store(store)
	window.navigate_requested.connect(_capture_navigation)
	await process_frame
	window.open_report()
	await process_frame
	_expect(window.visible and not window.wrap_controls, "覆盖率报告未作为独立窗口显示。")
	_expect(window.report.get("stories", []).size() > 0, "报告未扫描到真实固定剧情。")
	_expect(window.report.resources.expression.catalog_status == "available" and window.report.resources.expression.catalog_count > 0, "expression 数组根 catalog 仍不可用。")
	_expect(window.report.coverage.dynamic.available, "运行时 Session 未合并到报告。")
	var coverage_tree := window.get_node("Root/Tabs/CoverageTree") as Tree
	var story_item := coverage_tree.get_root().get_first_child()
	_expect(story_item != null and story_item.get_first_child() != null, "剧情覆盖树未填充事件。")
	if story_item != null and story_item.get_first_child() != null:
		var event_item := story_item.get_first_child()
		event_item.select(0)
		window.call("_navigate_coverage_item")
		_expect(not str(navigation.get("path", "")).is_empty() and int(navigation.get("event_index", -1)) >= 0, "覆盖树未发出准确跳转位置。")
	window.queue_free()
	if failures.is_empty(): print("STORY_COVERAGE_REPORT_WINDOW_SMOKE_OK"); quit(0); return
	for failure in failures: push_error("STORY_COVERAGE_REPORT_WINDOW_SMOKE: %s" % failure)
	quit(1)

func _capture_navigation(path: String, chapter_id: String, event_index: int) -> void:
	navigation = {"path": path, "chapter_id": chapter_id, "event_index": event_index}

func _expect(condition: bool, message: String) -> void:
	if not condition: failures.append(message)