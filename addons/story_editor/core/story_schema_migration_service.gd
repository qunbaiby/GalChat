@tool
extends RefCounted

const JsonService = preload("res://addons/story_editor/core/story_json_service.gd")
const SchemaRegistry = preload("res://addons/story_editor/core/story_schema_registry.gd")
const StoryScanner = preload("res://addons/story_editor/core/story_scanner.gd")
const MobileChatScanner = preload("res://addons/story_editor/core/mobile_fixed_chat_scanner.gd")
const FixedCallScanner = preload("res://addons/story_editor/core/fixed_voice_call_scanner.gd")

const CONFIG_PATHS := [
	"res://assets/data/guide/guide_flows.json",
	"res://assets/data/story/story_time.json",
	"res://assets/data/map/core/map_data.json",
	"res://assets/data/events/event_registry.json"
]


static func scan() -> Array[Dictionary]:
	var paths: Array[String] = []
	for story in StoryScanner.scan():
		_append_unique(paths, str(story.get("path", "")))
	for chat in MobileChatScanner.scan():
		_append_unique(paths, str(chat.get("path", "")))
	for path in CONFIG_PATHS:
		_append_unique(paths, path)
	_append_unique(paths, FixedCallScanner.CALL_PATH)
	paths.sort()
	var results: Array[Dictionary] = []
	for path in paths:
		results.append(preview(path, false))
	return results


static func preview(path: String, include_documents: bool = true) -> Dictionary:
	var source_text := FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
	var result := JsonService.load_dictionary(path)
	if not result.get("ok", false):
		var array_result := JsonService.load_array(path)
		if array_result.get("ok", false):
			return _base_result(path, "fixed_calls", "unsupported_root_versioning", source_text, "固定来电使用数组根节点，v1 暂不迁移。")
		return _base_result(path, "", "invalid_json", source_text, str(result.get("error", "读取失败")))
	var data := result.get("data", {}) as Dictionary
	var domain := SchemaRegistry.identify(path, data)
	if domain.is_empty():
		return _base_result(path, "", "unknown_domain", source_text, "路径或最低根契约无法识别。")
	var version_value: Variant = data.get("schema_version", null)
	if data.has("schema_version") and not _is_valid_version(version_value):
		return _base_result(path, domain, "invalid_version", source_text, "schema_version 必须是非负整数。")
	var version := int(version_value) if data.has("schema_version") else 0
	if version > SchemaRegistry.CURRENT_VERSION:
		var future := _base_result(path, domain, "future", source_text, "文件版本高于当前编辑器支持版本。")
		future.from_version = version
		future.to_version = SchemaRegistry.CURRENT_VERSION
		return future
	if version == SchemaRegistry.CURRENT_VERSION:
		var current := _base_result(path, domain, "current", source_text)
		current.from_version = version
		current.to_version = version
		return current
	var migration := SchemaRegistry.migrate_to_current(domain, data)
	if not migration.get("ok", false):
		return _base_result(path, domain, "migration_unavailable", source_text, str(migration.get("error", "缺少迁移链")))
	var preview_result := _base_result(path, domain, "unversioned", source_text)
	preview_result.from_version = version
	preview_result.to_version = SchemaRegistry.CURRENT_VERSION
	preview_result.can_apply = true
	preview_result.steps = migration.get("steps", [])
	preview_result.changes = migration.get("changes", [])
	if include_documents:
		preview_result.before = data.duplicate(true)
		preview_result.after = (migration.get("data", {}) as Dictionary).duplicate(true)
	return preview_result


static func apply(preview_result: Dictionary) -> Dictionary:
	if not preview_result.get("can_apply", false):
		return {"ok": false, "error": "当前预览不可应用。"}
	var path := str(preview_result.get("path", ""))
	if path.is_empty() or not FileAccess.file_exists(path):
		return {"ok": false, "error": "源文件不存在。"}
	var source_text := FileAccess.get_file_as_string(path)
	if source_text.md5_text() != str(preview_result.get("source_hash", "")):
		return {"ok": false, "error": "源文件在预览后已变化，请重新扫描。", "status": "source_changed"}
	var after := preview_result.get("after", {}) as Dictionary
	if after.is_empty():
		return {"ok": false, "error": "预览不包含迁移后文档。"}
	var backup_path := _backup_path(path, int(preview_result.get("from_version", 0)), int(preview_result.get("to_version", 0)))
	var copy_error := DirAccess.copy_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(backup_path))
	if copy_error != OK:
		return {"ok": false, "error": "无法创建迁移备份，错误码：%d" % copy_error}
	var save_result := JsonService.save_dictionary(path, after)
	if not save_result.get("ok", false):
		_restore_backup(path, backup_path)
		return {"ok": false, "error": str(save_result.get("error", "迁移写入失败")), "backup_path": backup_path}
	var verify_result := JsonService.load_dictionary(path)
	var normalized_after: Variant = JSON.parse_string(JSON.stringify(after))
	if not verify_result.get("ok", false) or verify_result.get("data") != normalized_after:
		_restore_backup(path, backup_path)
		return {"ok": false, "error": "写后验证失败，已从备份恢复。", "backup_path": backup_path}
	return {"ok": true, "path": path, "backup_path": backup_path, "data": after.duplicate(true)}


static func _base_result(path: String, domain: String, status: String, source_text: String, message: String = "") -> Dictionary:
	return {
		"ok": status in ["current", "unversioned"],
		"path": path,
		"domain": domain,
		"domain_label": SchemaRegistry.label(domain),
		"status": status,
		"from_version": 0,
		"to_version": SchemaRegistry.CURRENT_VERSION,
		"can_apply": false,
		"source_hash": source_text.md5_text(),
		"steps": [],
		"changes": [],
		"diagnostics": [] if message.is_empty() else [{"severity": "error" if status not in ["unsupported_root_versioning"] else "warning", "message": message}]
	}


static func _backup_path(path: String, from_version: int, to_version: int) -> String:
	var timestamp := Time.get_datetime_string_from_system().replace(":", "").replace("-", "")
	return "%s.story_editor.migration.v%d-to-v%d.%s.bak" % [path, from_version, to_version, timestamp]


static func _restore_backup(path: String, backup_path: String) -> void:
	DirAccess.copy_absolute(ProjectSettings.globalize_path(backup_path), ProjectSettings.globalize_path(path))


static func _is_valid_version(value: Variant) -> bool:
	if value is int:
		return int(value) >= 0
	if value is float:
		return is_finite(float(value)) and float(value) >= 0.0 and float(value) == floor(float(value))
	return false


static func _append_unique(paths: Array[String], path: String) -> void:
	if not path.is_empty() and not paths.has(path):
		paths.append(path)