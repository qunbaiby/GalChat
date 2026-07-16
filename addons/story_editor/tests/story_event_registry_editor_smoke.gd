extends SceneTree

const WindowScene = preload("res://addons/story_editor/ui/story_reference_catalog_window.tscn")
const JsonService = preload("res://addons/story_editor/core/story_json_service.gd")

const FIXTURE_PATH := "user://story_event_registry_editor_smoke.json"
const TARGET_PATH := "res://assets/data/story/scripts/events/ya_cafe_first_visit.json"

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var fixture := {
		"registry_note": "preserve-root",
		"events": [{
			"event_id": "ya_cafe_first_visit",
			"event_type": "auto_trigger",
			"is_repeatable": false,
			"trigger_script": TARGET_PATH,
			"custom_event_field": "preserve-event",
			"conditions": [{"type": "location", "value": "old_location", "custom_condition_field": "preserve-condition"}]
		}]
	}
	_expect(JsonService.save_dictionary(FIXTURE_PATH, fixture).get("ok", false), "无法写入 Registry 编辑 fixture。")
	var window := WindowScene.instantiate()
	window.registry_path = FIXTURE_PATH
	root.add_child(window)
	await process_frame
	window.refresh_catalog()
	await process_frame

	_expect(window.references.filter(func(reference: Dictionary) -> bool: return reference.get("source_type") == "event_registry").size() == 1, "fixture 应只产生 1 个 Event Registry 入口。")
	_expect(window.get_node("Root/Body/Details/DetailsScroll/Content/EventEditor").visible, "Event Registry 编辑区未显示。")
	var rows := window.get_node("Root/Body/Details/DetailsScroll/Content/EventEditor/ConditionsScroll/ConditionRows")
	var editable_row: Control = _first_visible_row(rows)
	_expect(editable_row != null, "条件编辑行未创建。")
	if editable_row != null:
		editable_row.get_node("FieldAEdit").text = "new_location"
	window.get_node("Root/Body/Details/DetailsScroll/Content/EventEditor/Metadata/RepeatableCheck").button_pressed = true
	_expect(window.apply_selected_event(), "应用 Event Registry 修改失败。")
	_expect(window.registry_data.events[0].conditions[0].value == "new_location", "条件值没有写回内存文档。")
	_expect(window.registry_data.events[0].conditions[0].custom_condition_field == "preserve-condition", "条件未知字段丢失。")
	_expect(window.registry_data.events[0].custom_event_field == "preserve-event", "事件未知字段丢失。")
	_expect(not window.get_node("Root/Header/UndoButton").disabled, "修改后撤销按钮未启用。")
	_expect(window.undo(), "撤销 Registry 修改失败。")
	_expect(window.registry_data.events[0].conditions[0].value == "old_location", "撤销后条件值未恢复。")
	_expect(window.redo(), "重做 Registry 修改失败。")
	_expect(window.registry_data.events[0].conditions[0].value == "new_location", "重做后条件值未恢复。")
	_expect(window.save_registry(), "合法 Registry 修改未能保存。")
	var saved_result := JsonService.load_dictionary(FIXTURE_PATH)
	var saved := saved_result.get("data", {}) as Dictionary
	_expect(saved.get("registry_note") == "preserve-root", "Registry 根未知字段丢失。")
	_expect(saved.events[0].custom_event_field == "preserve-event", "保存后事件未知字段丢失。")
	_expect(saved.events[0].conditions[0].custom_condition_field == "preserve-condition", "保存后条件未知字段丢失。")

	window.get_node("Root/Body/Details/DetailsScroll/Content/EventEditor/Metadata/EventIdEdit").text = "wrong_script_id"
	_expect(window.apply_selected_event(), "应用非法 script_id 修改失败。")
	_expect(window.diagnostics.any(func(diagnostic: Dictionary) -> bool: return diagnostic.get("code") == "script_id_mismatch"), "未即时显示 script_id 不一致诊断。")
	_expect(not window.save_registry(), "存在阻塞错误时仍允许保存 Registry。")

	window.queue_free()
	await process_frame
	if failures.is_empty():
		print("STORY_EVENT_REGISTRY_EDITOR_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("STORY_EVENT_REGISTRY_EDITOR_SMOKE: %s" % failure)
	quit(1)


func _first_visible_row(rows: Control) -> Control:
	for child in rows.get_children():
		if child.visible and child.has_method("get_condition"):
			return child
	return null


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)