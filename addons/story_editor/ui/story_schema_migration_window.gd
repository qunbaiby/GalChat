@tool
extends Window

const MigrationService = preload("res://addons/story_editor/core/story_schema_migration_service.gd")
const WINDOW_LAYOUT_PATH := "res://addons/story_editor/core/editor_window_layout.gd"

var scan_results: Array[Dictionary] = []
var selected_index := -1

@onready var migration_tree: Tree = %MigrationTree


func _ready() -> void:
	close_requested.connect(hide)
	%RefreshButton.pressed.connect(refresh_scan)
	%ApplyButton.pressed.connect(_confirm_apply)
	%ApplyDialog.confirmed.connect(apply_selected)
	migration_tree.item_selected.connect(_on_item_selected)
	migration_tree.set_column_title(0, "领域")
	migration_tree.set_column_title(1, "状态")
	migration_tree.set_column_title(2, "版本")
	migration_tree.set_column_title(3, "文件")


func open_editor() -> void:
	(load(WINDOW_LAYOUT_PATH) as GDScript).new().open_window(self, Vector2i(1100, 700), Vector2i(760, 520))
	refresh_scan()


func refresh_scan() -> void:
	scan_results = MigrationService.scan()
	selected_index = -1
	migration_tree.clear()
	var root := migration_tree.create_item()
	var status_counts := {}
	for result_index in scan_results.size():
		var result := scan_results[result_index]
		var status := str(result.get("status", "unknown"))
		status_counts[status] = int(status_counts.get(status, 0)) + 1
		var item := migration_tree.create_item(root)
		item.set_text(0, str(result.get("domain_label", result.get("domain", "未知"))))
		item.set_text(1, _status_label(status))
		item.set_text(2, "v%s → v%s" % [str(result.get("from_version", 0)), str(result.get("to_version", 1))])
		item.set_text(3, str(result.get("path", "")))
		item.set_metadata(0, result_index)
	%Summary.text = "%d 个文档 · %d 个可迁移 · %d 个当前版本" % [scan_results.size(), int(status_counts.get("unversioned", 0)), int(status_counts.get("current", 0))]
	%PreviewText.text = "选择文档查看迁移预览。"
	%ApplyButton.disabled = true


func apply_selected() -> bool:
	if selected_index < 0 or selected_index >= scan_results.size():
		return false
	var preview := MigrationService.preview(str(scan_results[selected_index].get("path", "")))
	var result := MigrationService.apply(preview)
	if not result.get("ok", false):
		%PreviewText.text = "应用失败：%s" % str(result.get("error", "未知错误"))
		return false
	var backup_path := str(result.get("backup_path", ""))
	refresh_scan()
	%PreviewText.text = "迁移完成。\n备份：%s" % backup_path
	return true


func _on_item_selected() -> void:
	var item := migration_tree.get_selected()
	if item == null:
		return
	selected_index = int(item.get_metadata(0))
	var result := scan_results[selected_index]
	%ApplyButton.disabled = not bool(result.get("can_apply", false))
	var lines: Array[String] = [
		"文件：%s" % str(result.get("path", "")),
		"领域：%s" % str(result.get("domain_label", result.get("domain", ""))),
		"状态：%s" % _status_label(str(result.get("status", "")))
	]
	for change in result.get("changes", []):
		if change is Dictionary:
			lines.append("%s %s：%s → %s" % [str(change.get("op", "")), str(change.get("path", "")), str(change.get("before")), str(change.get("after"))])
	for diagnostic in result.get("diagnostics", []):
		if diagnostic is Dictionary:
			lines.append("%s：%s" % [str(diagnostic.get("severity", "warning")).to_upper(), str(diagnostic.get("message", ""))])
	%PreviewText.text = "\n".join(lines)


func _confirm_apply() -> void:
	if selected_index < 0 or selected_index >= scan_results.size():
		return
	%ApplyDialog.dialog_text = "将为原文件创建永久备份，然后应用所选迁移。\n\n%s" % str(scan_results[selected_index].get("path", ""))
	%ApplyDialog.popup_centered()


func _status_label(status: String) -> String:
	return {
		"unversioned": "可迁移",
		"current": "当前版本",
		"future": "未来版本",
		"invalid_version": "版本无效",
		"invalid_json": "JSON 无效",
		"unknown_domain": "无法识别",
		"unsupported_root_versioning": "暂不支持"
	}.get(status, status)