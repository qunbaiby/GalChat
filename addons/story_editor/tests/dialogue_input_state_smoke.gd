extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_data_manager := root.get_node_or_null("GameDataManager")
	_expect(game_data_manager != null, "GameDataManager 未初始化。")
	if game_data_manager == null:
		_finish()
		return
	var original_voice_enabled := bool(game_data_manager.config.voice_enabled)
	game_data_manager.config.voice_enabled = true
	var panel_scene := load("res://scenes/ui/common/dialogue_panel.tscn") as PackedScene
	_expect(panel_scene != null, "无法加载共用对话面板。")
	if panel_scene == null:
		game_data_manager.config.voice_enabled = original_voice_enabled
		_finish()
		return
	var panel = panel_scene.instantiate()
	root.add_child(panel)
	await process_frame
	var external_bubble_stream := AudioStreamWAV.new()
	panel._on_tts_success(external_bubble_stream, "主场景气泡问候")
	_expect(panel.audio_player.stream == null, "空闲的共用对话面板错误抢播了主场景气泡 TTS。")
	panel.set_input_waiting_state("Luna")
	_expect(panel.input_layer.visible and panel.input_layer.is_visible_in_tree(), "AI 等待或结束语状态隐藏了输入区域。")
	_expect(panel.input_field.text == "", "AI 思考状态污染了玩家输入文本。")
	_expect(panel.input_field.placeholder_text == "输入你想说的话...", "AI 等待状态仍然占用了输入框提示。")
	_expect(not panel.input_field.editable, "AI 思考状态下输入框仍可编辑。")
	_expect(panel.send_btn.disabled, "AI 等待或结束语状态下发送按钮仍可用。")
	_expect(panel.voice_btn.disabled, "AI 等待或结束语状态下语音按钮仍可用。")
	_expect(panel.end_chat_button.disabled, "AI 等待或结束语状态下结束对话按钮仍可重复点击。")
	panel.set_ai_player_option_status("Luna正在思考中")
	_expect(panel.ai_player_option_layer.visible, "AI 思考状态没有显示在玩家选项面板。")
	_expect(panel.ai_player_option_status_label.text == "Luna正在思考中", "玩家选项面板没有显示思考状态。")
	panel.set_ai_player_option_status("Luna正在讲话")
	_expect(panel.ai_player_option_status_label.text == "Luna正在讲话", "玩家选项面板没有切换到讲话状态。")
	await create_timer(0.4).timeout
	_expect(panel.ai_player_option_status_label.text == "Luna正在讲话.", "讲话状态没有播放动态省略号。")
	panel.show_ai_player_options()
	_expect(not panel.ai_player_option_status_label.visible, "玩家选项生成后仍显示默认状态文本。")
	_expect(panel.ai_player_options_container.visible, "玩家选项生成后没有显示双列选项槽。")
	_expect(panel.ai_player_options_container.columns == 2, "AI 玩家选项槽不是单行双列布局。")
	panel.clear_ai_player_options(false)
	_expect(panel.ai_player_option_layer.visible, "玩家选择回复后错误隐藏了整个 AI 玩家选项层。")
	panel.set_ai_player_option_status("Luna正在思考中")
	await create_timer(0.6).timeout
	_expect(not panel.input_field.editable, "等待计时器错误提前解锁了输入框。")
	panel.input_field.text = "【我】正在讲话中，请等待…"
	panel.set_input_ready_state()
	await process_frame
	_expect(panel.input_field.text == "", "轮到玩家输入时没有清理旧等待文本。")
	_expect(panel.input_field.placeholder_text == "输入你想说的话...", "轮到玩家输入时没有恢复默认提示。")
	_expect(panel.input_field.editable, "轮到玩家输入时输入框仍不可编辑。")
	_expect(panel.input_field.has_focus(), "轮到玩家输入时没有显示输入光标。")
	_expect(not panel.end_chat_button.disabled, "轮到玩家输入时结束对话按钮没有恢复可用。")
	panel.queue_free()
	await process_frame
	game_data_manager.config.voice_enabled = original_voice_enabled
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
