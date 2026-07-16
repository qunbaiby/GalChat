extends SceneTree

const MigrationService = preload("res://addons/story_editor/core/story_schema_migration_service.gd")
const JsonService = preload("res://addons/story_editor/core/story_json_service.gd")

const STORY_PATH := "user://story/scripts/main/schema_migration_story.json"
const CHAT_PATH := "user://mobile/fixed_chats/schema_migration_chat.json"
const FUTURE_PATH := "user://guide_flows.json"
const INVALID_PATH := "user://story_time.json"
const CALLS_PATH := "user://fixed_calls.json"

var failures: Array[String] = []
var cleanup_paths: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_write(STORY_PATH, {"script_id": "schema_smoke", "chapters": {"start": {"events": []}}, "unknown": {"keep": true}})
	_write(CHAT_PATH, {"id": "schema_chat", "character_id": "jing", "messages": [{}]})
	_write(FUTURE_PATH, {"schema_version": 2, "guides": []})
	_write(INVALID_PATH, {"schema_version": "1", "daily_data": []})
	var calls_write := JsonService.save_array(CALLS_PATH, [])
	_expect(calls_write.get("ok", false), "无法创建数组根 fixture。")
	cleanup_paths.append(CALLS_PATH)

	var preview := MigrationService.preview(STORY_PATH)
	_expect(preview.status == "unversioned" and preview.can_apply, "无版本固定剧情未生成可应用预览。")
	_expect(preview.domain == "fixed_story", "固定剧情领域识别错误。")
	_expect(preview.changes == [{"op": "add", "path": "/schema_version", "before": null, "after": 1}], "迁移变更集不符合 v0 到 v1 契约。")
	_expect(not (preview.before as Dictionary).has("schema_version") and not (JsonService.load_dictionary(STORY_PATH).data as Dictionary).has("schema_version"), "预览修改了源文档。")
	_expect((preview.after as Dictionary).get("unknown", {}) == {"keep": true}, "预览丢失未知字段。")
	_expect(MigrationService.preview(CHAT_PATH).domain == "mobile_chat", "手机消息领域识别错误。")
	_expect(MigrationService.preview(FUTURE_PATH).status == "future", "未来版本未被禁止降级。")
	_expect(MigrationService.preview(INVALID_PATH).status == "invalid_version", "非法版本字段未被识别。")
	_expect(MigrationService.preview(CALLS_PATH).status == "unsupported_root_versioning", "固定来电数组根未明确标记为暂不支持。")

	var apply_result := MigrationService.apply(preview)
	_expect(apply_result.get("ok", false), "合法迁移应用失败：%s" % str(apply_result.get("error", "")))
	if apply_result.get("ok", false):
		var backup_path := str(apply_result.get("backup_path", ""))
		cleanup_paths.append(backup_path)
		_expect(FileAccess.file_exists(backup_path), "迁移未保留持久备份。")
		_expect(not (JSON.parse_string(FileAccess.get_file_as_string(backup_path)) as Dictionary).has("schema_version"), "迁移备份不是原始文档。")
		var migrated := JsonService.load_dictionary(STORY_PATH).get("data", {}) as Dictionary
		_expect(migrated.get("schema_version") == 1 and migrated.get("unknown", {}) == {"keep": true}, "迁移结果未保留数据或版本错误。")
		_expect(MigrationService.preview(STORY_PATH).status == "current", "迁移后文件未识别为当前版本。")

	var stale_preview := MigrationService.preview(CHAT_PATH)
	_write(CHAT_PATH, {"id": "schema_chat", "character_id": "jing", "messages": [{}], "external_change": true})
	var stale_result := MigrationService.apply(stale_preview)
	_expect(not stale_result.get("ok", false) and stale_result.get("status") == "source_changed", "源文件变化后仍应用了过期预览。")
	var future_preview := MigrationService.preview(FUTURE_PATH)
	_expect(not MigrationService.apply(future_preview).get("ok", false), "不可应用预览仍被写入。")

	var scan_results := MigrationService.scan()
	_expect(scan_results.size() > 0, "真实仓库 Schema 扫描为空。")
	_expect(scan_results.any(func(item: Dictionary) -> bool: return item.status == "unsupported_root_versioning"), "真实固定来电未显示暂不支持状态。")
	_finish()


func _write(path: String, data: Dictionary) -> void:
	var result := JsonService.save_dictionary(path, data)
	_expect(result.get("ok", false), "无法写入 fixture：%s" % path)
	cleanup_paths.append(path)


func _finish() -> void:
	for path in cleanup_paths:
		if not path.is_empty() and FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if failures.is_empty():
		print("STORY_SCHEMA_MIGRATION_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("STORY_SCHEMA_MIGRATION_SMOKE: %s" % failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)