@tool
extends RefCounted

const StoryScanner = preload("res://addons/story_editor/core/story_scanner.gd")
const JsonService = preload("res://addons/story_editor/core/story_json_service.gd")
const StoryValidator = preload("res://addons/story_editor/core/story_validator.gd")
const MobileChatScanner = preload("res://addons/story_editor/core/mobile_fixed_chat_scanner.gd")
const MobileChatValidator = preload("res://addons/story_editor/core/mobile_chat_validator.gd")
const FixedCallScanner = preload("res://addons/story_editor/core/fixed_voice_call_scanner.gd")
const FixedCallValidator = preload("res://addons/story_editor/core/fixed_voice_call_validator.gd")
const GuideFlowValidator = preload("res://addons/story_editor/core/guide_flow_validator.gd")
const ScheduleValidator = preload("res://addons/story_editor/core/story_schedule_entry_validator.gd")
const ReferenceScanner = preload("res://addons/story_editor/core/story_entry_reference_scanner.gd")
const ReferenceValidator = preload("res://addons/story_editor/core/story_entry_reference_validator.gd")

const GUIDE_FLOWS_PATH := "res://assets/data/guide/guide_flows.json"
const STORY_TIME_PATH := "res://assets/data/story/story_time.json"
const MAP_DATA_PATH := "res://assets/data/map/core/map_data.json"


static func validate_repository(story_paths: Array[String] = [], sources: Dictionary = {}) -> Dictionary:
	var paths := story_paths.duplicate()
	var include_extended_sources := story_paths.is_empty() or not sources.is_empty()
	if paths.is_empty():
		for story in StoryScanner.scan():
			paths.append(str(story.get("path", "")))
	paths.sort()
	var diagnostics: Array[Dictionary] = []
	var domain_counts := {
		"fixed_story": paths.size(),
		"mobile_chat": 0,
		"fixed_call": 0,
		"guide_flow": 0,
		"schedule": 0,
		"cross_reference": 0
	}
	for path in paths:
		_validate_story(path, diagnostics)
	if include_extended_sources:
		_validate_mobile_chats(sources, diagnostics, domain_counts)
		_validate_fixed_calls(sources, diagnostics, domain_counts)
		_validate_guide_flows(sources, diagnostics, domain_counts)
		_validate_schedule(sources, diagnostics, domain_counts)
		_validate_references(sources, diagnostics, domain_counts)
	var error_count := 0
	var warning_count := 0
	var domain_diagnostic_counts := {}
	for diagnostic in diagnostics:
		var domain := str(diagnostic.get("domain", "unknown"))
		domain_diagnostic_counts[domain] = int(domain_diagnostic_counts.get(domain, 0)) + 1
		if str(diagnostic.get("severity", "")) == "error":
			error_count += 1
		elif str(diagnostic.get("severity", "")) == "warning":
			warning_count += 1
	return {
		"ok": error_count == 0,
		"file_count": _sum_counts(domain_counts),
		"error_count": error_count,
		"warning_count": warning_count,
		"domain_counts": domain_counts,
		"domain_diagnostic_counts": domain_diagnostic_counts,
		"diagnostics": diagnostics
	}


static func _validate_story(path: String, diagnostics: Array[Dictionary]) -> void:
	var result := JsonService.load_dictionary(path)
	if not result.get("ok", false):
		_add_diagnostic(diagnostics, {
			"severity": "error",
			"location": "文件",
			"message": str(result.get("error", "读取失败"))
		}, "fixed_story", path)
		return
	_append_diagnostics(diagnostics, StoryValidator.validate(result.get("data", {}) as Dictionary), "fixed_story", path)


static func _validate_mobile_chats(sources: Dictionary, diagnostics: Array[Dictionary], domain_counts: Dictionary) -> void:
	var entries: Array = sources.get("mobile_chats", []) as Array if sources.has("mobile_chats") else MobileChatScanner.scan()
	domain_counts.mobile_chat = entries.size()
	for entry_value in entries:
		if not entry_value is Dictionary:
			continue
		var entry := entry_value as Dictionary
		var path := str(entry.get("path", "fixture://mobile_chat"))
		var data_result := _resolve_dictionary_source(entry, path)
		if not data_result.get("ok", false):
			_add_load_error(diagnostics, "mobile_chat", path, data_result)
			continue
		_append_diagnostics(diagnostics, MobileChatValidator.validate(data_result.get("data", {}) as Dictionary, sources.get("catalogs", {}) as Dictionary), "mobile_chat", path)


static func _validate_fixed_calls(sources: Dictionary, diagnostics: Array[Dictionary], domain_counts: Dictionary) -> void:
	var source := sources.get("fixed_calls", {}) as Dictionary
	var path := str(source.get("path", FixedCallScanner.CALL_PATH))
	var load_result := {"ok": true, "data": source.get("data")} if source.has("data") else FixedCallScanner.load_calls(path)
	if not load_result.get("ok", false):
		_add_load_error(diagnostics, "fixed_call", path, load_result)
		return
	var calls := load_result.get("data", []) as Array if load_result.get("data", []) is Array else []
	domain_counts.fixed_call = calls.size()
	var references := source.get("references", FixedCallScanner.scan_story_references()) as Dictionary
	_append_diagnostics(diagnostics, FixedCallValidator.validate(load_result.get("data"), sources.get("catalogs", {}) as Dictionary, references), "fixed_call", path)


static func _validate_guide_flows(sources: Dictionary, diagnostics: Array[Dictionary], domain_counts: Dictionary) -> void:
	var source := sources.get("guide_flows", {}) as Dictionary
	var path := str(source.get("path", GUIDE_FLOWS_PATH))
	var load_result := _resolve_dictionary_source(source, path)
	if not load_result.get("ok", false):
		_add_load_error(diagnostics, "guide_flow", path, load_result)
		return
	var data := load_result.get("data", {}) as Dictionary
	domain_counts.guide_flow = (data.get("guides", []) as Array).size() if data.get("guides", []) is Array else 1
	_append_diagnostics(diagnostics, GuideFlowValidator.validate(data), "guide_flow", path)


static func _validate_schedule(sources: Dictionary, diagnostics: Array[Dictionary], domain_counts: Dictionary) -> void:
	var story_time_source := sources.get("story_time", {}) as Dictionary
	var map_source := sources.get("map_data", {}) as Dictionary
	var story_time_path := str(story_time_source.get("path", STORY_TIME_PATH))
	var map_path := str(map_source.get("path", MAP_DATA_PATH))
	var story_time_result := _resolve_dictionary_source(story_time_source, story_time_path)
	var map_result := _resolve_dictionary_source(map_source, map_path)
	if not story_time_result.get("ok", false):
		_add_load_error(diagnostics, "schedule", story_time_path, story_time_result)
	if not map_result.get("ok", false):
		_add_load_error(diagnostics, "schedule", map_path, map_result)
	if not story_time_result.get("ok", false) or not map_result.get("ok", false):
		return
	domain_counts.schedule = 2
	_append_diagnostics(diagnostics, ScheduleValidator.validate(story_time_result.get("data", {}) as Dictionary, map_result.get("data", {}) as Dictionary), "schedule", "%s + %s" % [story_time_path, map_path])


static func _validate_references(sources: Dictionary, diagnostics: Array[Dictionary], domain_counts: Dictionary) -> void:
	var scan_result := sources.get("entry_scan_result", {}) as Dictionary
	if scan_result.is_empty():
		scan_result = ReferenceScanner.scan()
	domain_counts.cross_reference = (scan_result.get("references", []) as Array).size()
	_append_diagnostics(diagnostics, ReferenceValidator.validate(scan_result), "cross_reference", "repository://entry_references")


static func _resolve_dictionary_source(source: Dictionary, path: String) -> Dictionary:
	if source.has("data"):
		if source.get("data") is Dictionary:
			return {"ok": true, "data": source.get("data")}
		return {"ok": false, "error": "根节点必须是对象。"}
	return JsonService.load_dictionary(path)


static func _append_diagnostics(target: Array[Dictionary], values: Array[Dictionary], domain: String, path: String) -> void:
	for value in values:
		_add_diagnostic(target, value, domain, path)


static func _add_load_error(diagnostics: Array[Dictionary], domain: String, path: String, result: Dictionary) -> void:
	_add_diagnostic(diagnostics, {"severity": "error", "location": "文件", "message": str(result.get("error", "读取失败"))}, domain, path)


static func _add_diagnostic(diagnostics: Array[Dictionary], value: Dictionary, domain: String, path: String) -> void:
	var diagnostic := value.duplicate(true)
	diagnostic["domain"] = domain
	if str(diagnostic.get("path", "")).is_empty():
		diagnostic["path"] = path
	diagnostics.append(diagnostic)


static func _sum_counts(counts: Dictionary) -> int:
	var total := 0
	for value in counts.values():
		total += int(value)
	return total