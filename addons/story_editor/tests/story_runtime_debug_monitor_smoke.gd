extends SceneTree

const DebugStore = preload("res://addons/story_editor/core/story_runtime_debug_store.gd")
const WindowScene = preload("res://addons/story_editor/ui/story_runtime_debug_window.tscn")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var receiver := DebugStore.new()
	receiver.start_session(7)
	var fixture := {
		"schema_version": 1,
		"sequence": 1,
		"trace_id": "trace-1",
		"event": "story.event.started",
		"severity": "info",
		"source": {"type": "guide_flow", "id": "intro/step_1", "context": {}},
		"story": {"script_id": "intro", "event_type": "dialogue"},
		"cursor": {"chapter_id": "start", "event_index": 0},
		"data": {}
	}
	receiver.add_event(7, fixture)
	_expect(receiver.get_events(7).size() == 1 and receiver.is_session_active(7), "Session 事件或活动状态未保存。")

	var window := WindowScene.instantiate() as Window
	root.add_child(window)
	await process_frame
	window.set_debug_store(receiver)
	window.open_monitor()
	await process_frame
	var tree := window.get_node("Root/Body/EventTree") as Tree
	_expect(window.visible and not window.wrap_controls, "运行时监视独立窗口未安全显示。")
	_expect(tree.get_root() != null and tree.get_root().get_child_count() == 1, "监视窗口未显示接收事件。")
	var item := tree.get_root().get_child(0)
	item.select(0)
	window.call("_show_selected_event")
	_expect((window.get_node("Root/Body/DetailText") as TextEdit).text.contains("guide_flow"), "事件详情未显示结构化来源。")
	receiver.stop_session(7)
	_expect(not receiver.is_session_active(7), "停止 Session 后状态仍为活动。")
	window.call("_clear_selected_session")
	_expect(receiver.get_events(7).is_empty(), "清空 Session 未删除缓存事件。")
	window.queue_free()
	if failures.is_empty():
		print("STORY_RUNTIME_DEBUG_MONITOR_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("STORY_RUNTIME_DEBUG_MONITOR_SMOKE: %s" % failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)