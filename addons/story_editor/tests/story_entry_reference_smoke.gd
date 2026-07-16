extends SceneTree

const Scanner = preload("res://addons/story_editor/core/story_entry_reference_scanner.gd")
const Validator = preload("res://addons/story_editor/core/story_entry_reference_validator.gd")
const JsonService = preload("res://addons/story_editor/core/story_json_service.gd")

const EVENT_FIXTURE_PATH := "user://story_reference_events.json"
const GUIDE_FIXTURE_PATH := "user://story_reference_guides.json"
const SCHEDULE_FIXTURE_PATH := "user://story_reference_schedule.json"
const MAP_FIXTURE_PATH := "user://story_reference_map.json"
const VALID_STORY_PATH := "res://assets/data/story/scripts/events/ya_cafe_first_visit.json"
const MISSING_STORY_PATH := "res://assets/data/story/scripts/events/missing_story.json"

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var real_result := Scanner.scan()
	var real_references := real_result.get("references", []) as Array
	_expect(real_references.filter(func(reference: Dictionary) -> bool: return reference.get("source_type") == "event_registry").size() == 3, "真实 Event Registry 应扫描到 3 个剧情入口。")
	_expect(real_references.filter(func(reference: Dictionary) -> bool: return reference.get("source_type") == "guide_flow").size() == 1, "真实 Guide Flow 应扫描到 1 个 play_story 入口。")
	_expect(real_references.filter(func(reference: Dictionary) -> bool: return reference.get("source_type") == "story_schedule").size() == 2, "真实剧情日程应扫描到 2 个入口。")
	_expect(real_references.filter(func(reference: Dictionary) -> bool: return reference.get("source_type") == "map_schedule").size() == 1, "真实地图数据应扫描到 1 个定时入口。")
	var real_diagnostics := Validator.validate(real_result)
	_expect(real_diagnostics.filter(func(diagnostic: Dictionary) -> bool: return diagnostic.get("severity") == "error").is_empty(), "真实剧情入口不应包含阻塞错误。")
	_expect(_has_code(real_diagnostics, "unreferenced_story"), "真实固定剧情全集应产生未引用剧情诊断。")
	_expect(_has_code(real_diagnostics, "schedule_day_mismatch"), "未识别真实日程与剧情 day_offset 漂移。")

	var event_fixture := {"events": [
		{"event_id": "valid_entry", "event_type": "auto_trigger", "conditions": [{"type": "location", "value": "cafe"}], "trigger_script": VALID_STORY_PATH},
		{"event_id": "duplicate_entry", "event_type": "auto_trigger", "conditions": [{"value": "cafe", "type": "location"}], "trigger_script": MISSING_STORY_PATH},
		{"event_id": "duplicate_entry", "event_type": "manual", "conditions": [], "trigger_script": ""}
	]}
	var guide_fixture := {"guides": [{"id": "nested_guide", "steps": [
		{"id": "ignored", "type": "wait_action"},
		{"id": "group", "type": "group", "children": [{"id": "story_step", "type": "play_story", "story_path": VALID_STORY_PATH}]}
	]}]}
	var schedule_fixture := {"daily_data": [{"day_offset": 4, "morning_events": ["luna_piano_practice"]}]}
	var map_fixture := {"locations": {"library": {"scheduled_entry_stories": [{"id": "wrong_script_id", "events": ["fixture_event"], "periods": ["上午"], "trigger_script": VALID_STORY_PATH}]}}}
	_expect(JsonService.save_dictionary(EVENT_FIXTURE_PATH, event_fixture).get("ok", false), "无法写入 Event Registry fixture。")
	_expect(JsonService.save_dictionary(GUIDE_FIXTURE_PATH, guide_fixture).get("ok", false), "无法写入 Guide Flow fixture。")
	_expect(JsonService.save_dictionary(SCHEDULE_FIXTURE_PATH, schedule_fixture).get("ok", false), "无法写入日程 fixture。")
	_expect(JsonService.save_dictionary(MAP_FIXTURE_PATH, map_fixture).get("ok", false), "无法写入地图 fixture。")
	var result := Scanner.scan(EVENT_FIXTURE_PATH, GUIDE_FIXTURE_PATH, SCHEDULE_FIXTURE_PATH, MAP_FIXTURE_PATH)
	var references := result.get("references", []) as Array
	_expect(references.size() == 6, "fixture 应扫描到事件、Guide、日程和地图共 6 个入口。")
	_expect(references.filter(func(reference: Dictionary) -> bool: return reference.get("source_type") == "guide_flow").size() == 1, "嵌套 play_story 没有被扫描或被重复扫描。")
	var diagnostics := Validator.validate(result)
	_expect(_has_code(diagnostics, "duplicate_event_id"), "未识别重复 event_id。")
	_expect(_has_code(diagnostics, "condition_conflict"), "未识别完全相同的自动触发条件。")
	_expect(_has_code(diagnostics, "missing_target"), "未识别缺失或不存在的目标剧情。")
	_expect(_has_code(diagnostics, "script_id_mismatch"), "未识别入口与目标剧情 script_id 不一致。")
	_expect(_has_code(diagnostics, "schedule_day_mismatch"), "未识别日程 day_offset 不一致。")
	var invalid_condition_result := Scanner.scan_event_registry_data({"events": [{"event_id": "invalid", "event_type": "auto_trigger", "conditions": [{"type": "unknown"}], "trigger_script": VALID_STORY_PATH}]})
	_expect(_has_code(Validator.validate(invalid_condition_result), "unsupported_condition"), "未阻止运行时不支持的条件类型。")

	if failures.is_empty():
		print("STORY_ENTRY_REFERENCE_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("STORY_ENTRY_REFERENCE_SMOKE: %s" % failure)
	quit(1)


func _has_code(diagnostics: Array, code: String) -> bool:
	return diagnostics.any(func(diagnostic: Dictionary) -> bool: return str(diagnostic.get("code", "")) == code)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)