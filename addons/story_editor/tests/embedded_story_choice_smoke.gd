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
	var fixed_chat_manager := root.get_node_or_null("MobileFixedChatManager")
	_expect(guide_manager != null, "GuideManager 未初始化。")
	_expect(topic_manager != null, "MainChatTopicManager 未初始化。")
	_expect(fixed_chat_manager != null, "MobileFixedChatManager 未初始化。")
	var original_guide_state: Dictionary = guide_manager._state.duplicate(true)
	var character_id: String = main_scene._get_current_main_chat_character_id()
	var story_data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/story/scripts/main/jing_piano_practice_followup.json"))
	var opening_dialogue_count := 0
	if story_data is Dictionary:
		var story_events: Array = ((((story_data as Dictionary).get("chapters", {}) as Dictionary).get("start", {}) as Dictionary).get("events", []))
		for story_event_value in story_events:
			if not story_event_value is Dictionary:
				continue
			var story_event_type := str((story_event_value as Dictionary).get("type", ""))
			if story_event_type == "choice":
				break
			if story_event_type == "dialogue":
				opening_dialogue_count += 1
	_expect(opening_dialogue_count > 0, "专项辅导主线在首个选项前没有开场对白。")
	var invite_state: Dictionary = fixed_chat_manager._chat_states.get("jing_piano_practice_invite", {}).duplicate(true)
	invite_state["is_completed"] = true
	invite_state["is_active"] = false
	invite_state.erase("completion_events_applied")
	fixed_chat_manager._chat_states["jing_piano_practice_invite"] = invite_state
	topic_manager.consume_active_topic(character_id)
	guide_manager._state["active_guide_id"] = "schedule_onboarding_guide"
	var incomplete_guides: Array[String] = []
	guide_manager._state["completed_guides"] = incomplete_guides
	var guide_steps: Array = (guide_manager._guide_defs["schedule_onboarding_guide"] as Dictionary).get("steps", [])
	var goal_step_index := -1
	var topic_step_index := -1
	var finish_step_index := -1
	var resource_guide_step_index := -1
	var affection_step_index := -1
	var companion_step_index := -1
	var energy_step_index := -1
	var daily_chat_step_index := -1
	var wechat_session_step: Dictionary = {}
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
			"prompt_start_companion_journey":
				companion_step_index = step_index
			"explain_interaction_energy":
				energy_step_index = step_index
			"open_first_daily_chat":
				daily_chat_step_index = step_index
			"explain_wechat_chat_session":
				wechat_session_step = guide_steps[step_index] as Dictionary
	_expect(str(wechat_session_step.get("target_mode", "")) == "chat_session" and str(wechat_session_step.get("text", "")).contains("消息列表"), "微聊首次消息引导没有说明高亮消息列表。")
	var wechat_panel_source := FileAccess.get_file_as_string("res://scripts/ui/mobile/wechat/wechat_main_panel.gd")
	var chat_target_start := wechat_panel_source.find("func get_chat_session_target()")
	var chat_target_end := wechat_panel_source.find("func get_chat_session_focus_entry()", chat_target_start)
	var chat_target_source := wechat_panel_source.substr(chat_target_start, chat_target_end - chat_target_start)
	_expect(chat_target_source.contains("get_message_list_target"), "微聊首次消息高亮没有定位 MobileChatPanel 的 MessageList。")
	var input_target_start := wechat_panel_source.find("func get_input_edit_target()")
	var input_target_end := wechat_panel_source.find("func get_input_edit_focus_entry()", input_target_start)
	var input_target_source := wechat_panel_source.substr(input_target_start, input_target_end - input_target_start)
	_expect(input_target_source.contains("should_highlight_entire_chat_container_for_fixed_conversation") and input_target_source.contains("return content_panel"), "玩家首次发送后连续聊天高亮没有切换到 ContentPanel。")
	_expect(energy_step_index == companion_step_index + 1 and daily_chat_step_index == energy_step_index + 1, "陪伴、行动力与日常聊天引导没有连续排列。")
	if energy_step_index >= 0:
		guide_manager._state["current_step_index"] = energy_step_index
		guide_manager._main_scene_ref = weakref(main_scene)
		_expect(not guide_manager._resolve_step_focus_rects(guide_steps[energy_step_index] as Dictionary).is_empty(), "行动力引导无法高亮顶部行动力区域。")
	if daily_chat_step_index >= 0:
		guide_manager._state["current_step_index"] = daily_chat_step_index
		_expect(not guide_manager._resolve_step_focus_rects(guide_steps[daily_chat_step_index] as Dictionary).is_empty(), "日常聊天引导无法高亮当前背景的 ChatButton。")
	_expect(goal_step_index >= 0, "引导中缺少 GoalPanel 步骤。")
	_expect(goal_step_index < topic_step_index, "GoalPanel 引导没有排在 AI 主线话题之前。")
	_expect(float((guide_steps[topic_step_index] as Dictionary).get("highlight_padding", -1.0)) == 0.0, "AI 主线话题按钮高亮仍带有额外外扩。")
	_expect(finish_step_index + 1 == resource_guide_step_index, "AI 主线结束后没有紧接时间天气引导。")
	if resource_guide_step_index >= 0:
		var resource_step := guide_steps[resource_guide_step_index] as Dictionary
		_expect(str(resource_step.get("highlight_feature", "")) == "main.weather", "AI 主线结束后没有高亮时间天气区域。")
		_expect(not resource_step.has("focus_targets"), "AI 主线结束后仍同时高亮行动力区域。")
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
	main_scene._on_wechat_closed()
	var activated_topic: Dictionary = topic_manager.get_active_topic_for(character_id)
	_expect(str(activated_topic.get("event_id", "")) == "jing_piano_practice_followup", "已完成固定微聊的旧存档没有补回赴约前 AI 主线。")
	_expect(str(activated_topic.get("auto_start_state", "")) == "pending", "补回的 AI 主线没有进入 pending 状态。")
	_expect(str(activated_topic.get("auto_start_source_type", "")) == "fixed_chat_close", "补回的 AI 主线没有绑定关闭微聊触发源。")
	_expect(bool((fixed_chat_manager._chat_states.get("jing_piano_practice_invite", {}) as Dictionary).get("completion_events_applied", false)), "旧存档补偿后没有持久化完成事件标记。")
	main_scene._on_main_ui_restored_after_chat_closed()
	await process_frame
	_expect(not is_instance_valid(main_scene.chat_scene_instance), "关闭微聊后在 GoalPanel 引导前错误打开了剧情对话框。")
	var goal_step := guide_steps[goal_step_index] as Dictionary
	var goal_overlay_options := goal_step.get("overlay_options", {}) as Dictionary
	_expect(bool(goal_overlay_options.get("capture_focus_clicks", false)), "GoalPanel 引导没有捕获高亮区域点击。")
	_expect(str(goal_overlay_options.get("focus_wait_action", "")) == "click_main_goal", "GoalPanel 引导没有转发 click_main_goal。")
	guide_manager._on_overlay_focus_pressed("click_main_goal")
	await process_frame
	await process_frame
	var manager = main_scene.chat_scene_instance
	_expect(is_instance_valid(manager), "点击 GoalPanel 引导高亮后没有创建嵌入剧情管理器。")
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
		for line_index in range(opening_dialogue_count):
			var wait_frames := 0
			while wait_frames < 600 and not manager._line_text_complete:
				await process_frame
				wait_frames += 1
			_expect(manager._line_text_complete, "嵌入主线台词未完成打字机播放：line=%d event=%d ui_visible=%s alpha=%.3f intro_wait=%s advance=%s text=%s" % [line_index, int(manager.script_engine.current_event_index), str(manager.ui_panel.visible), manager.ui_panel.modulate.a, str(manager._intro_waiting_for_click), str(manager._line_advance_requested), manager.dialogue_text.text])
			if not manager._line_text_complete:
				break
			var click_event := InputEventMouseButton.new()
			click_event.button_index = MOUSE_BUTTON_LEFT
			click_event.pressed = true
			manager._on_click_blocker_input(click_event)
			await process_frame
			await process_frame
		_expect(manager._story_choice_active, "完整开场台词后没有进入剧情选项事件。")
		_expect(manager.dialogue_text.text == "她看向你，神情里既有期待，也藏着一点不安。", "快速推进后上一句旁白仍叠加在当前台词中。")
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
		_expect(int(game_data_manager.profile.current_energy) == energy_before_guided_chat, "目标引导后的 guided AI 主线不应消耗行动力。")
		_expect(manager.free_chat_info_layer.visible, "guided AI 主线开始后没有显示回合信息卡。")
		_expect(manager.free_chat_round_label.text.contains("剩余 4 / 4 回合"), "回合信息卡没有显示初始 4 / 4 回合。")
		guide_manager._state["current_step_index"] = finish_step_index - 1
		main_scene.ui_panel.visible = false
		main_scene._on_embedded_session_completed({
			"mode": "main_story",
			"story_topic": {"event_id": "jing_piano_practice_followup"}
		})
		main_scene._on_chat_closed()
		await create_timer(0.4).timeout
		_expect(guide_manager.get_current_step_id() == "inspect_main_panels_after_interact", "赴约前 AI 主线结束后没有续接时间天气引导。")
		var finished_stories: Array = game_data_manager.profile.finished_stories.duplicate()
		if not game_data_manager.profile.has_finished_story("jing_piano_practice_followup"):
			game_data_manager.profile.finished_stories.append("jing_piano_practice_followup")
		var recovered_state: Dictionary = guide_manager._normalize_state({
			"active_guide_id": "schedule_onboarding_guide",
			"current_step_index": finish_step_index,
			"guide_flow_revision": 4,
			"completed_guides": [],
			"feature_unlocks": {}
		})
		_expect(int(recovered_state.get("current_step_index", -1)) == resource_guide_step_index, "已完成 AI 主线的旧卡档没有恢复到时间天气引导。")
		game_data_manager.profile.finished_stories = finished_stories
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