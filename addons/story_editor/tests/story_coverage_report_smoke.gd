extends SceneTree

const Report = preload("res://addons/story_editor/core/story_coverage_report.gd")
const JsonService = preload("res://addons/story_editor/core/story_json_service.gd")
const PATH := "user://story_coverage_report_smoke.json"

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var data := {"script_id": "coverage", "chapters": {
		"start": {"events": [{"type": "dialogue", "speaker": "char", "expression": "smile"}, {"type": "background", "bg_id": "room"}, {"type": "audio", "audio_id": "bell"}, {"type": "choice", "options": [{"id": "a", "text": "A", "target_chapter": "branch"}, {"id": "b", "text": "B", "target_chapter": "end"}]}]},
		"branch": {"events": [{"type": "voice_call", "call_id": "call_1"}, {"type": "show_character", "character": "jing", "expression": "missing_expression"}, {"type": "jump", "target_chapter": "end"}, {"type": "background", "bg_id": "unreachable"}]},
		"orphan": {"events": [{"type": "bgm", "audio_path": "res://legacy.ogg", "audio_id": ""}]}
	}}
	JsonService.save_dictionary(PATH, data)
	var catalog := {"image": [{"id": "room", "label": "房间"}, {"id": "unused_image", "label": "未引用"}], "audio": [{"id": "bell", "label": "铃声"}], "expression": [{"id": "smile", "label": "微笑"}], "call": [{"id": "call_1", "label": "来电"}], "character": [{"id": "jing", "label": "镜"}]}
	var sessions := {7: {"active": true, "events": [_runtime_event(PATH, "start", 0, "trace-a"), _runtime_event(PATH, "start", 0, "trace-a"), _runtime_event(PATH, "branch", 0, "trace-a"), _runtime_event(PATH, "missing", 0, "trace-b")]}}
	var report := Report.build([PATH], catalog, sessions)
	_expect(report.summary.event_count == 9 and report.coverage.structural.covered == 7, "静态可达统计不正确。")
	_expect(report.coverage.simulation.path_count == 2 and report.coverage.simulation.covered == 7, "Choice 模拟路径并集不正确。")
	_expect(report.coverage.dynamic.available and report.coverage.dynamic.covered == 2 and report.coverage.dynamic.unmatched_event_count == 1, "动态覆盖对齐或去重不正确。")
	_expect(report.resources.character.missing_id_count == 0, "char 运行时角色别名被误报。")
	_expect(report.resources.expression.missing_id_count == 1 and report.resources.image.unused_id_count == 1, "缺失资源或未被固定剧情引用统计不正确。")
	_expect(report.resources.audio.reference_count == 1, "空 audio_id 或 audio_path 被错误计入引用。")
	var unavailable := Report.build([PATH], {"image": [], "audio": [], "expression": [], "call": [], "character": []})
	_expect(unavailable.resources.expression.catalog_status == "unavailable" and unavailable.resources.expression.missing_id_count == 0, "不可用 catalog 批量制造缺失资源。")
	if FileAccess.file_exists(PATH): DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	if failures.is_empty(): print("STORY_COVERAGE_REPORT_SMOKE_OK"); quit(0); return
	for failure in failures: push_error("STORY_COVERAGE_REPORT_SMOKE: %s" % failure)
	quit(1)

func _runtime_event(path: String, chapter_id: String, event_index: int, trace_id: String) -> Dictionary:
	return {"event": "story.event.started", "trace_id": trace_id, "story": {"script_path": path, "runtime_generated": false}, "cursor": {"chapter_id": chapter_id, "event_index": event_index}}

func _expect(condition: bool, message: String) -> void:
	if not condition: failures.append(message)