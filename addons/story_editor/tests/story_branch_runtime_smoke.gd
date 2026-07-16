extends SceneTree

const ScriptEngine = preload("res://scripts/script_engine/script_engine_manager.gd")

var failures: Array[String] = []
var requested_lines: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var engine := ScriptEngine.new()
	root.add_child(engine)
	engine.on_dialogue_requested.connect(_on_dialogue_requested)
	var loaded := engine.load_script_data({
		"script_id": "branch_runtime_smoke",
		"chapters": {
			"start": {"events": [{"type": "jump", "target_chapter": "target"}]},
			"target": {"events": [{"type": "dialogue", "speaker": "旁白", "content": "目标首事件"}]}
		}
	})
	_expect(loaded, "无法加载内存分支剧情。")
	engine.start_script()
	_expect(engine.current_chapter_id == "target", "Jump 没有切换到目标章节。")
	_expect(engine.current_event_index == 0, "Jump 后没有停在目标章节首事件。")
	_expect(requested_lines == ["目标首事件"], "目标章节首事件没有被执行。")

	if failures.is_empty():
		print("STORY_BRANCH_RUNTIME_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("STORY_BRANCH_RUNTIME_SMOKE: %s" % failure)
	quit(1)


func _on_dialogue_requested(_speaker: String, content: String, _mood: String, _presentation: Dictionary) -> void:
	requested_lines.append(content)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)