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
	game_data_manager.config.voice_enabled = false
	var main_scene_resource := load("res://scenes/ui/main/main_scene.tscn") as PackedScene
	_expect(main_scene_resource != null, "无法加载主场景。")
	if main_scene_resource == null:
		game_data_manager.config.voice_enabled = original_voice_enabled
		_finish()
		return
	var main_scene := main_scene_resource.instantiate()
	root.add_child(main_scene)
	await process_frame
	await process_frame
	var guide_manager := root.get_node_or_null("GuideManager")
	var topic_manager := root.get_node_or_null("MainChatTopicManager")
	_expect(guide_manager != null, "GuideManager 未初始化。")
	_expect(topic_manager != null, "MainChatTopicManager 未初始化。")
	var original_guide_state: Dictionary = guide_manager._state.duplicate(true)
	var character_id: String = main_scene._get_current_main_chat_character_id()
	topic_manager.activate_topic({
		"character_id": character_id,
		"event_id": "jing_piano_practice_followup",
		"topic_text": "静约你周六进行专项辅导",
		"story_script_path": "res://assets/data/story/scripts/main/jing_piano_practice_followup.json",
		"auto_start_source_type": "fixed_chat_close"
	})
	guide_manager._state["active_guide_id"] = "schedule_onboarding_guide"
	var incomplete_guides: Array[String] = []
	guide_manager._state["completed_guides"] = incomplete_guides
	var guide_steps: Array = (guide_manager._guide_defs["schedule_onboarding_guide"] as Dictionary).get("steps", [])
	var goal_step_index := -1
	var topic_step_index := -1
	var finish_step_index := -1
	var resource_guide_step_index := -1
	var affection_step_index := -1
	for step_index in range(guide_steps.size()):
		var step_id := str((guide_steps[step_index] as Dictionary).get("id", ""))
		match step_id:
			"explain_main_goal_panel":
				goal_step_index = step_index
			"choose_topic_after_goal":
				topic_step_index = step_index
			"finish_first_chat_after_goal":
				finish_step_index = step_index
			"inspect_main_panels_after_interact":
				resource_guide_step_index = step_index
			"explain_main_affection_button":
				affection_step_index = step_index
	_expect(goal_step_index >= 0, "引导中缺少 GoalPanel 步骤。")
	_expect(goal_step_index < topic_step_index, "GoalPanel 引导没有排在 AI 主线话题之前。")
	_expect(finish_step_index + 1 == resource_guide_step_index, "AI 主线结束后没有紧接时间和行动力引导。")
	_expect(affection_step_index >= 0, "引导中缺少情感按钮步骤。")
	if affection_step_index >= 0:
		var affection_step := guide_steps[affection_step_index] as Dictionary
		var affection_overlay_options := affection_step.get("overlay_options", {}) as Dictionary
		_expect(bool(affection_overlay_options.get("capture_focus_clicks", false)), "情感按钮高亮没有捕获焦点点击。")
		_expect(str(affection_overlay_options.get("focus_wait_action", "")) == "open_affection", "情感按钮高亮没有转发 open_affection。")
	guide_manager._on_overlay_focus_pressed("open_affection")
	await process_frame
	_expect(main_scene.affection_overlay.visible, "点击情感按钮高亮没有打开情感面板。")
	main_scene._hide_affection_popup()
	await create_timer(0.25).timeout
	guide_manager._state["current_step_index"] = goal_step_index
	main_scene._pending_auto_main_story_after_wechat_close = true
	main_scene._pending_auto_main_story_character_id = character_id
	main_scene._on_main_ui_restored_after_chat_closed()
	await process_frame
	_expect(not is_instance_valid(main_scene.chat_scene_instance), "关闭微聊后在 GoalPanel 引导前错误打开了剧情对话框。")
	var goal_click := InputEventMouseButton.new()
	goal_click.button_index = MOUSE_BUTTON_LEFT
	goal_click.pressed = true
	main_scene._on_goal_panel_gui_input(goal_click)
	await process_frame
	await process_frame
	var manager = main_scene.chat_scene_instance
	_expect(is_instance_valid(manager), "点击 GoalPanel 后没有创建嵌入剧情管理器。")
	if is_instance_valid(manager):
		var wait_for_first_line_frames := 0
		while wait_for_first_line_frames < 180 and not manager._line_text_complete:
			await process_frame
			wait_for_first_line_frames += 1
		var event_index_before_hide := int(manager.script_engine.current_event_index)
		manager._on_hide_ui_pressed()
		await create_timer(0.35).timeout
		_expect(not manager.ui_panel.visible, "点击隐藏 UI 后对话框仍然可见。")
		var restore_click := InputEventMouseButton.new()
		restore_click.button_index = MOUSE_BUTTON_LEFT
		restore_click.pressed = true
		manager._input(restore_click)
		await process_frame
		_expect(manager.ui_panel.visible, "隐藏 UI 后点击空白处没有恢复对话框。")
		_expect(int(manager.script_engine.current_event_index) == event_index_before_hide, "恢复 UI 的同一次点击错误推进了剧情。")
		await create_timer(0.35).timeout
		for _line_index in range(3):
			var wait_frames := 0
			while wait_frames < 180 and not manager._line_text_complete:
				await process_frame
				wait_frames += 1
			_expect(manager._line_text_complete, "嵌入主线台词未完成打字机播放。")
			var click_event := InputEventMouseButton.new()
			click_event.button_index = MOUSE_BUTTON_LEFT
			click_event.pressed = true
			manager._on_click_blocker_input(click_event)
			await process_frame
			await process_frame
		_expect(manager._story_choice_active, "第三句台词后没有进入剧情选项事件。")
		_expect(main_scene.quick_option_layer.visible, "剧情选项已生成，但 QuickOptionLayer 仍被隐藏。")
		_expect(main_scene.quick_option_layer.is_visible_in_tree(), "剧情选项层不在可见场景树中。")
		_expect(main_scene.quick_options_container.get_child_count() == 1, "微聊后主线没有生成预期的单个话题选项。")
		var energy_before_guided_chat := int(game_data_manager.profile.current_energy)
		manager._on_story_choice_selected("聊聊周六的专项辅导", 0)
		var choice_response_wait_frames := 0
		while choice_response_wait_frames < 180 and not manager._line_text_complete:
			await process_frame
			choice_response_wait_frames += 1
		_expect(manager._line_text_complete, "主线话题选择后的玩家台词未完成播放。")
		var choice_response_click := InputEventMouseButton.new()
		choice_response_click.button_index = MOUSE_BUTTON_LEFT
		choice_response_click.pressed = true
		manager._on_click_blocker_input(choice_response_click)
		var guided_wait_frames := 0
		while guided_wait_frames < 180 and not manager._guided_ai_chat_active:
			await process_frame
			guided_wait_frames += 1
		_expect(manager._guided_ai_chat_active, "选择主线话题后没有进入 guided AI 对话。")
		_expect(int(game_data_manager.profile.current_energy) == energy_before_guided_chat - 5, "guided AI 主线没有准确扣除 5 点行动力。")
		_expect(manager.free_chat_info_layer.visible, "guided AI 主线开始后没有显示回合信息卡。")
		_expect(manager.free_chat_round_label.text.contains("剩余 4 / 4 回合"), "回合信息卡没有显示初始 4 / 4 回合。")
	guide_manager._state = original_guide_state
	game_data_manager.config.voice_enabled = original_voice_enabled
	main_scene.queue_free()
	await process_frame
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("EMBEDDED_STORY_CHOICE_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("EMBEDDED_STORY_CHOICE_SMOKE: %s" % failure)
	quit(1)