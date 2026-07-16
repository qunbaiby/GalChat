extends SceneTree

const BridgeScript = preload("res://scripts/debug/story_runtime_debug_bridge.gd")
const EngineScript = preload("res://scripts/script_engine/script_engine_manager.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var existing := root.get_node_or_null("StoryRuntimeDebugBridge")
	if existing != null:
		existing.queue_free()
		await process_frame
	var bridge := BridgeScript.new()
	bridge.name = "StoryRuntimeDebugBridge"
	bridge.enabled = true
	bridge.capacity = 3
	root.add_child(bridge)
	for index in 5:
		bridge.record("test.%d" % index)
	var ring := bridge.snapshot()
	_expect(ring.size() == 3 and ring[0].event == "test.2" and ring[2].event == "test.4", "环形缓冲未保留最新三条事件。")
	bridge.clear()
	bridge.capacity = 64
	bridge.prepare_story("event_registry", "library_event", "res://fixture.json", {"location_id": "library"})
	var engine := EngineScript.new()
	root.add_child(engine)
	var loaded := engine.load_script_data({
		"script_id": "runtime_debug_smoke",
		"chapters": {
			"start": {"events": [{"type": "dialogue", "speaker": "旁白", "content": "测试"}, {"type": "jump", "target_chapter": "end"}]}
		}
	}, "res://fixture.json")
	_expect(loaded, "内存剧情加载失败。")
	engine.start_script()
	_expect(engine.is_waiting_for_resume, "对白事件未进入阻塞状态。")
	engine.resume()
	var events := bridge.snapshot()
	_expect(events.any(func(event: Dictionary) -> bool: return event.event == "story.started" and event.source.type == "event_registry" and event.source.id == "library_event"), "剧情开始事件未消费触发来源。")
	_expect(events.any(func(event: Dictionary) -> bool: return event.event == "story.event.blocked"), "未记录阻塞事件。")
	_expect(events.any(func(event: Dictionary) -> bool: return event.event == "story.jump.requested"), "未记录跳转请求。")
	_expect(events.any(func(event: Dictionary) -> bool: return event.event == "story.engine.finished"), "未记录剧情引擎结束。")
	_expect(events.all(func(event: Dictionary) -> bool: return JSON.stringify(event) != ""), "调试事件存在不可序列化值。")
	var first_trace := str(events.filter(func(event: Dictionary) -> bool: return event.event == "story.started")[0].trace_id)
	bridge.prepare_story("direct", "second", "res://second.json")
	bridge.begin_story("second", "res://second.json")
	_expect(str(bridge.snapshot()[-1].trace_id) != first_trace, "两次剧情播放复用了 trace_id。")
	var before_disabled := bridge.snapshot().size()
	bridge.enabled = false
	bridge.record("disabled")
	_expect(bridge.snapshot().size() == before_disabled, "关闭桥后仍写入事件。")
	engine.queue_free()
	bridge.queue_free()
	if failures.is_empty():
		print("STORY_RUNTIME_DEBUG_BRIDGE_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("STORY_RUNTIME_DEBUG_BRIDGE_SMOKE: %s" % failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)