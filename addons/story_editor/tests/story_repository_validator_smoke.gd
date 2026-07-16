extends SceneTree

const RepositoryValidator = preload("res://addons/story_editor/core/story_repository_validator.gd")
const JsonService = preload("res://addons/story_editor/core/story_json_service.gd")

const VALID_PATH := "user://story_repository_validator_valid.json"
const INVALID_PATH := "user://story_repository_validator_invalid.json"
const BROKEN_PATH := "user://story_repository_validator_broken.json"

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var valid_write := JsonService.save_dictionary(VALID_PATH, {
		"script_id": "ci_valid",
		"chapters": {"start": {"events": [{"type": "dialogue", "content": "ok"}]}}
	})
	var invalid_write := JsonService.save_dictionary(INVALID_PATH, {
		"script_id": "",
		"chapters": {"start": {"events": [{"type": "unknown_ci_event"}]}}
	})
	var broken_file := FileAccess.open(BROKEN_PATH, FileAccess.WRITE)
	if broken_file != null:
		broken_file.store_string("{broken")
		broken_file.close()
	_expect(valid_write.get("ok", false) and invalid_write.get("ok", false) and FileAccess.file_exists(BROKEN_PATH), "无法创建全库校验 fixture。")

	var fixture_report := RepositoryValidator.validate_repository([VALID_PATH, INVALID_PATH, BROKEN_PATH])
	_expect(not fixture_report.ok, "包含结构错误与损坏 JSON 的仓库报告仍标记为通过。")
	_expect(fixture_report.file_count == 3, "仓库报告文件计数错误。")
	_expect(fixture_report.error_count >= 3, "仓库报告没有聚合解析和结构错误。")
	_expect((fixture_report.diagnostics as Array).all(func(diagnostic: Dictionary) -> bool: return not str(diagnostic.get("path", "")).is_empty()), "仓库诊断缺少源文件路径。")

	var multi_source_report := RepositoryValidator.validate_repository([VALID_PATH], {
		"mobile_chats": [{"path": "fixture://mobile_chat.json", "data": {}}],
		"fixed_calls": {"path": "fixture://fixed_calls.json", "data": [{}], "references": {}},
		"guide_flows": {"path": "fixture://guide_flows.json", "data": {"guides": [{}]}},
		"story_time": {"path": "fixture://story_time.json", "data": {"daily_data": "invalid"}},
		"map_data": {"path": "fixture://map_data.json", "data": {"locations": "invalid"}},
		"entry_scan_result": {
			"references": [],
			"event_entries": [],
			"story_paths": [],
			"source_diagnostics": [{"severity": "error", "location": "fixture", "message": "引用源损坏"}]
		}
	})
	var error_domains := {}
	for diagnostic in multi_source_report.diagnostics:
		if str(diagnostic.get("severity", "")) == "error":
			error_domains[str(diagnostic.get("domain", ""))] = true
	_expect(not multi_source_report.ok, "多源错误 fixture 仍标记为通过。")
	for expected_domain in ["mobile_chat", "fixed_call", "guide_flow", "schedule", "cross_reference"]:
		_expect(error_domains.has(expected_domain), "统一报告未聚合 %s 错误。" % expected_domain)
	_expect((multi_source_report.diagnostics as Array).all(func(diagnostic: Dictionary) -> bool: return not str(diagnostic.get("path", "")).is_empty()), "多源诊断缺少源路径。")

	var repository_report := RepositoryValidator.validate_repository()
	_expect(repository_report.file_count > 0, "真实剧情目录未扫描到任何文件。")
	for expected_domain in ["fixed_story", "mobile_chat", "fixed_call", "guide_flow", "schedule", "cross_reference"]:
		_expect(int((repository_report.domain_counts as Dictionary).get(expected_domain, 0)) > 0, "真实仓库未覆盖 %s 领域。" % expected_domain)
	if not repository_report.ok:
		for diagnostic in repository_report.diagnostics:
			if str(diagnostic.get("severity", "")) == "error":
				failures.append("真实剧情错误：%s / %s / %s" % [str(diagnostic.get("path", "")), str(diagnostic.get("location", "")), str(diagnostic.get("message", ""))])

	_cleanup()
	if failures.is_empty():
		print("STORY_REPOSITORY_VALIDATOR_SMOKE_OK files=%d warnings=%d" % [int(repository_report.file_count), int(repository_report.warning_count)])
		quit(0)
		return
	for failure in failures:
		push_error("STORY_REPOSITORY_VALIDATOR_SMOKE: %s" % failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _cleanup() -> void:
	for path in [VALID_PATH, INVALID_PATH, BROKEN_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))