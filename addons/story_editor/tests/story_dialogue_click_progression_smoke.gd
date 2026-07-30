extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_data_manager = root.get_node_or_null("GameDataManager")
	_expect(game_data_manager != null, "GameDataManager 未初始化。")
	if game_data_manager == null:
		_finish()
		return

	var original_voice_enabled := bool(game_data_manager.config.voice_enabled)
	game_data_manager.config.voice_enabled = false
	game_data_manager.set_meta("play_intro_story", true)
	var story_scene_resource := load("res://scenes/ui/story/story_scene.tscn") as PackedScene
	_expect(story_scene_resource != null, "无法加载剧情场景。")
	if story_scene_resource == null:
		game_data_manager.config.voice_enabled = original_voice_enabled
		_finish()
		return
	var story_scene := story_scene_resource.instantiate()
	root.add_child(story_scene)

	var wait_frames := 0
	while wait_frames < 180 and (story_scene.script_engine == null or not story_scene.script_engine.is_waiting_for_resume):
		await process_frame
		wait_frames += 1
	_expect(story_scene.script_engine != null and story_scene.script_engine.is_waiting_for_resume, "开篇剧情没有进入首个阻塞台词。")
	if story_scene.script_engine != null and story_scene.script_engine.is_waiting_for_resume:
		var first_event_index: int = int(story_scene.script_engine.current_event_index)
		var dialogue_layer := story_scene.dialogue_panel.dialogue_layer as Control
		_expect(dialogue_layer != null, "剧情对话框缺少 DialogueLayer。")
		var click_event := InputEventMouseButton.new()
		click_event.button_index = MOUSE_BUTTON_LEFT
		click_event.pressed = true
		if dialogue_layer != null:
			click_event.position = dialogue_layer.get_global_rect().get_center()
			click_event.global_position = click_event.position
			root.push_input(click_event)
		await process_frame
		if dialogue_layer != null:
			root.push_input(click_event)
		await process_frame
		wait_frames = 0
		while wait_frames < 180 and story_scene.script_engine.current_event_index == first_event_index:
			await process_frame
			wait_frames += 1
		_expect(story_scene.script_engine.current_event_index > first_event_index, "点击完成台词后，剧情引擎没有推进到下一事件。")

	game_data_manager.config.voice_enabled = original_voice_enabled
	story_scene.queue_free()
	await process_frame
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("STORY_DIALOGUE_CLICK_PROGRESSION_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("STORY_DIALOGUE_CLICK_PROGRESSION_SMOKE: %s" % failure)
	quit(1)
