extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var panel_scene := load("res://scenes/ui/common/dialogue_panel.tscn") as PackedScene
	_expect(panel_scene != null, "无法加载共用对话面板。")
	if panel_scene == null:
		_finish()
		return
	var panel = panel_scene.instantiate()
	root.add_child(panel)
	await process_frame
	panel.set_input_waiting_state("Luna")
	_expect(panel.input_field.text == "", "AI 思考状态污染了玩家输入文本。")
	_expect(panel.input_field.placeholder_text == "Luna 正在思考…", "AI 思考状态没有显示 Luna 提示。")
	_expect(not panel.input_field.editable, "AI 思考状态下输入框仍可编辑。")
	await create_timer(0.6).timeout
	_expect(not panel.input_field.editable, "等待计时器错误提前解锁了输入框。")
	panel.input_field.text = "【我】正在讲话中，请等待…"
	panel.set_input_ready_state()
	await process_frame
	_expect(panel.input_field.text == "", "轮到玩家输入时没有清理旧等待文本。")
	_expect(panel.input_field.placeholder_text == "输入你想说的话...", "轮到玩家输入时没有恢复默认提示。")
	_expect(panel.input_field.editable, "轮到玩家输入时输入框仍不可编辑。")
	_expect(panel.input_field.has_focus(), "轮到玩家输入时没有显示输入光标。")
	panel.queue_free()
	await process_frame
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("DIALOGUE_INPUT_STATE_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("DIALOGUE_INPUT_STATE_SMOKE: %s" % failure)
	quit(1)
