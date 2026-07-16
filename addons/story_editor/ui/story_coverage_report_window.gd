@tool
extends Window

signal navigate_requested(path: String, chapter_id: String, event_index: int)

const CoverageReport = preload("res://addons/story_editor/core/story_coverage_report.gd")
const WINDOW_LAYOUT_PATH := "res://addons/story_editor/core/editor_window_layout.gd"

var debug_store: RefCounted
var report: Dictionary = {}

func _ready() -> void:
	close_requested.connect(hide)
	%RefreshButton.pressed.connect(refresh_report)
	%IncludeDynamic.toggled.connect(_on_dynamic_toggled)
	%CoverageTree.item_activated.connect(_navigate_coverage_item)
	%ResourceTree.item_activated.connect(_navigate_resource_item)
	%Tabs.set_tab_title(0, "剧情覆盖")
	%Tabs.set_tab_title(1, "资源使用")
	%Tabs.set_tab_title(2, "诊断")
	for column in 5: %CoverageTree.set_column_title(column, ["剧情 / 事件", "类型", "可达", "模拟", "动态"][column])
	for column in 4: %ResourceTree.set_column_title(column, ["类别 / 资源", "状态", "引用", "位置"][column])
	for column in 4: %DiagnosticsTree.set_column_title(column, ["级别", "领域", "位置", "说明"][column])

func set_debug_store(value: RefCounted) -> void:
	debug_store = value

func open_report() -> void:
	(load(WINDOW_LAYOUT_PATH) as GDScript).new().open_window(self, Vector2i(1180, 740), Vector2i(800, 540))
	refresh_report()

func refresh_report() -> void:
	var sessions: Dictionary = debug_store.snapshot_sessions() if debug_store != null and %IncludeDynamic.button_pressed else {}
	report = CoverageReport.build([], {}, sessions)
	var coverage := report.coverage as Dictionary
	var dynamic_label := "%.1f%%" % (float(coverage.dynamic.ratio) * 100.0) if coverage.dynamic.available else "无数据"
	%Summary.text = "%d 个剧情 · %d 个事件 · 结构 %.1f%% · 模拟 %.1f%% · 动态 %s" % [report.summary.story_count, report.summary.event_count, float(coverage.structural.ratio) * 100.0, float(coverage.simulation.ratio) * 100.0, dynamic_label]
	_populate_coverage()
	_populate_resources()
	_populate_diagnostics()

func _populate_coverage() -> void:
	%CoverageTree.clear()
	var root: TreeItem = %CoverageTree.create_item()
	for story in report.get("stories", []):
		var story_item: TreeItem = %CoverageTree.create_item(root)
		story_item.set_text(0, str(story.get("script_id", story.get("path", ""))))
		story_item.set_tooltip_text(0, str(story.get("path", "")))
		for event in story.get("events", []):
			var item: TreeItem = %CoverageTree.create_item(story_item)
			item.set_text(0, "%s  #%d" % [str(event.chapter_id), int(event.event_index) + 1])
			item.set_text(1, str(event.type))
			item.set_text(2, "是" if event.reachable else "否")
			item.set_text(3, "是" if event.simulated else "否")
			item.set_text(4, str(event.dynamic_hit_count) if event.dynamic_hit else "-")
			item.set_metadata(0, {"path": story.path, "chapter_id": event.chapter_id, "event_index": event.event_index})

func _populate_resources() -> void:
	%ResourceTree.clear()
	var root: TreeItem = %ResourceTree.create_item()
	for kind in report.get("resources", {}):
		var usage := report.resources[kind] as Dictionary
		var kind_item: TreeItem = %ResourceTree.create_item(root)
		kind_item.set_text(0, str(kind))
		kind_item.set_text(1, str(usage.catalog_status))
		kind_item.set_text(2, str(usage.reference_count))
		for entry in usage.entries: _add_resource_item(kind_item, entry, "已引用")
		for entry in usage.missing: _add_resource_item(kind_item, entry, "缺失")
		for entry in usage.unused: _add_resource_item(kind_item, entry, "未被固定剧情引用")

func _add_resource_item(parent: TreeItem, entry: Dictionary, status: String) -> void:
	var item: TreeItem = %ResourceTree.create_item(parent)
	item.set_text(0, str(entry.get("label", entry.get("id", ""))))
	item.set_text(1, status)
	item.set_text(2, str(entry.get("reference_count", 0)))
	var references := entry.get("references", []) as Array
	if not references.is_empty():
		var reference := references[0] as Dictionary
		item.set_text(3, "%s:%s #%d" % [str(reference.path).get_file(), str(reference.chapter_id), int(reference.event_index) + 1])
		item.set_metadata(0, reference)

func _populate_diagnostics() -> void:
	%DiagnosticsTree.clear()
	var root: TreeItem = %DiagnosticsTree.create_item()
	for diagnostic in report.get("diagnostics", []) + report.get("repository_validation", {}).get("diagnostics", []):
		if diagnostic is Dictionary:
			var item: TreeItem = %DiagnosticsTree.create_item(root)
			item.set_text(0, str(diagnostic.get("severity", "info")))
			item.set_text(1, str(diagnostic.get("domain", "")))
			item.set_text(2, "%s %s" % [str(diagnostic.get("path", "")).get_file(), str(diagnostic.get("location", ""))])
			item.set_text(3, str(diagnostic.get("message", "")))

func _navigate_coverage_item() -> void:
	_emit_navigation(%CoverageTree.get_selected())

func _navigate_resource_item() -> void:
	_emit_navigation(%ResourceTree.get_selected())

func _emit_navigation(item: TreeItem) -> void:
	if item == null or not item.get_metadata(0) is Dictionary: return
	var target := item.get_metadata(0) as Dictionary
	navigate_requested.emit(str(target.get("path", "")), str(target.get("chapter_id", "")), int(target.get("event_index", -1)))

func _on_dynamic_toggled(_enabled: bool) -> void:
	refresh_report()