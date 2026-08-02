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
	var original_archive_id := str(game_data_manager.get_active_archive_id())
	game_data_manager.set_active_archive_id("embedded_story_choice_smoke", false)
	game_data_manager.set_archive_custom_config("guide_state_v1", {}, true)
	game_data_manager.reload_active_archive_data()
	await process_frame
	await process_frame
	var original_voice_enabled := bool(game_data_manager.config.voice_enabled)
	game_data_manager.config.voice_enabled = false
	var main_scene_resource := load("res://scenes/ui/main/main_scene.tscn") as PackedScene
	_expect(main_scene_resource != null, "无法加载主场景。")
	if main_scene_resource == null:
		game_data_manager.config.voice_enabled = original_voice_enabled
		_finish()
		return
	var main_scene := main_scene_resource.instantiate()
	var original_current_scene: Node = current_scene
	root.add_child(main_scene)
	current_scene = main_scene
	await process_frame
	await process_frame
	var stats_focus_entry: Dictionary = main_scene.get_stats_panel_focus_entry()
	_expect(not stats_focus_entry.is_empty(), "主场景属性面板没有生成专用引导高亮。")
	_expect(float((stats_focus_entry.get("shape_params", {}) as Dictionary).get("corner_radius", 0.0)) == 26.0, "主场景属性面板没有使用围绕面板的圆角高亮。")
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
	topic_manager.consume_active_topic(character_id)
	var invite_script: Dictionary = fixed_chat_manager._chat_scripts.get("jing_piano_practice_invite", {})
	for message_value in invite_script.get("messages", []):
		if message_value is Dictionary:
			(message_value as Dictionary)["delay"] = 0
	var invite_state: Dictionary = fixed_chat_manager._chat_states.get("jing_piano_practice_invite", {})
	invite_state["is_completed"] = false
	invite_state["is_active"] = false
	invite_state["current_step"] = 0
	invite_state["completion_notice_sent"] = false
	invite_state["completion_events_applied"] = false
	_expect(fixed_chat_manager.trigger_script("jing_piano_practice_invite"), "新存档无法启动固定微聊。")
	for option_round in range(3):
		var options: Array = await _wait_for_fixed_chat_options(fixed_chat_manager, "jing_piano_practice_invite")
		_expect(not options.is_empty(), "固定微聊第 %d 组选项没有出现。" % (option_round + 1))
		if options.is_empty():
			break
		var option: Dictionary = options[0]
		fixed_chat_manager.submit_player_option("jing_piano_practice_invite", str(option.get("id", "")), str(option.get("text", "")))
	await _wait_for_fixed_chat_completion(fixed_chat_manager, "jing_piano_practice_invite")
	guide_manager._state["active_guide_id"] = "schedule_onboarding_guide"
	var incomplete_guides: Array[String] = []
	guide_manager._state["completed_guides"] = incomplete_guides
	var guide_steps: Array = (guide_manager._guide_defs["schedule_onboarding_guide"] as Dictionary).get("steps", [])
	var goal_step_index := -1
	var topic_step_index := -1
	var guided_round_step_index := -1
	var finish_step_index := -1
	var resource_guide_step_index := -1
	var affection_step_index := -1
	var affection_panel_step_index := -1
	var affection_close_step_index := -1
	var companion_step_index := -1
	var rest_button_step_index := -1
	var rest_confirm_step_index := -1
	var rest_transition_step_index := -1
	var energy_step_index := -1
	var meal_button_step_index := -1
	var meal_takeout_step_index := -1
	var meal_result_step_index := -1
	var wechat_session_step: Dictionary = {}
	for step_index in range(guide_steps.size()):
		var step_id := str((guide_steps[step_index] as Dictionary).get("id", ""))
		match step_id:
			"explain_main_goal_panel":
				goal_step_index = step_index
			"choose_topic_after_goal":
				topic_step_index = step_index
			"explain_guided_ai_round_limit":
				guided_round_step_index = step_index
			"finish_first_chat_after_goal":
				finish_step_index = step_index
			"inspect_main_panels_after_interact":
				resource_guide_step_index = step_index
			"explain_main_affection_button":
				affection_step_index = step_index
			"explain_main_affection_panel":
				affection_panel_step_index = step_index
			"close_main_affection_panel":
				affection_close_step_index = step_index
			"prompt_start_companion_journey":
				companion_step_index = step_index
			"open_first_rest_confirmation":
				rest_button_step_index = step_index
			"confirm_first_rest":
				rest_confirm_step_index = step_index
			"wait_first_rest_transition_finished":
				rest_transition_step_index = step_index
			"explain_interaction_energy":
				energy_step_index = step_index
			"open_first_meal":
				meal_button_step_index = step_index
			"select_first_meal_takeout":
				meal_takeout_step_index = step_index
			"close_first_meal_result":
				meal_result_step_index = step_index
			"explain_wechat_chat_session":
				wechat_session_step = guide_steps[step_index] as Dictionary
	_expect(str(wechat_session_step.get("target_mode", "")) == "first_character_message", "微聊首次消息引导没有定位静的头像和消息气泡。")
	var wechat_session_options: Dictionary = wechat_session_step.get("overlay_options", {})
	_expect(bool(wechat_session_options.get("capture_focus_clicks", false)) and str(wechat_session_options.get("focus_wait_action", "")) == "wechat_view_chat_session", "静的首条消息高亮没有直接捕获点击推进引导。")
	var wechat_panel_source := FileAccess.get_file_as_string("res://scripts/ui/mobile/wechat/wechat_main_panel.gd")
	var chat_target_start := wechat_panel_source.find("func get_first_character_message_target()")
	var chat_target_end := wechat_panel_source.find("func get_first_character_message_focus_entry()", chat_target_start)
	var chat_target_source := wechat_panel_source.substr(chat_target_start, chat_target_end - chat_target_start)
	_expect(chat_target_source.contains("get_first_character_message_target"), "微聊首次消息高亮没有定位 MobileChatPanel 的首个角色气泡。")
	_expect(not wechat_panel_source.contains("should_highlight_entire_chat_container_for_fixed_conversation"), "固定选项点击即发送后仍保留输入框连续聊天高亮。")
	var main_scene_source := FileAccess.get_file_as_string("res://scripts/ui/main/main_scene.gd")
	_expect(main_scene_source.contains("_begin_main_chat_topic_options_layout_stabilization()"), "AI 主线话题选项显示后没有等待布局稳定。")
	_expect(main_scene_source.contains("stable_frames >= 2") and main_scene_source.contains("_main_chat_topic_options_layout_ready"), "AI 主线话题高亮没有要求目标矩形连续稳定。")
	_expect(
		companion_step_index == resource_guide_step_index + 1
		and rest_button_step_index == companion_step_index + 1
		and rest_confirm_step_index == rest_button_step_index + 1
		and rest_transition_step_index == rest_confirm_step_index + 1
		and energy_step_index == rest_transition_step_index + 1
		and meal_button_step_index == energy_step_index + 1
		and meal_takeout_step_index == meal_button_step_index + 1
		and meal_result_step_index == meal_takeout_step_index + 1,
		"天气、休息、跨日等待、精力与早餐引导没有连续排列。"
	)
	if rest_transition_step_index >= 0:
		var rest_transition_step := guide_steps[rest_transition_step_index] as Dictionary
		_expect(bool(rest_transition_step.get("hide_overlay", false)), "跨日转场期间引导遮罩没有隐藏。")
		_expect(str(rest_transition_step.get("wait_action", "")) == "first_rest_transition_finished", "精力引导没有等待跨日转场完成。")
	if energy_step_index >= 0:
		guide_manager._state["current_step_index"] = energy_step_index
		guide_manager._main_scene_ref = weakref(main_scene)
		_expect(not guide_manager._resolve_step_focus_rects(guide_steps[energy_step_index] as Dictionary).is_empty(), "精力引导无法高亮顶部精力区域。")
	_expect(goal_step_index >= 0, "引导中缺少 GoalPanel 步骤。")
	_expect(goal_step_index < topic_step_index, "GoalPanel 引导没有排在 AI 主线话题之前。")
	_expect(float((guide_steps[topic_step_index] as Dictionary).get("highlight_padding", -1.0)) == 0.0, "AI 主线话题按钮高亮仍带有额外外扩。")
	_expect(
		finish_step_index + 1 == affection_step_index
		and affection_step_index + 1 == affection_panel_step_index
		and affection_panel_step_index + 1 == affection_close_step_index
		and affection_close_step_index + 1 == resource_guide_step_index,
		"AI 主线结束后没有依次进入情感按钮、情感面板、关闭按钮和时间天气引导。"
	)
	if resource_guide_step_index >= 0:
		var resource_step := guide_steps[resource_guide_step_index] as Dictionary
		_expect(str(resource_step.get("highlight_feature", "")) == "main.weather", "关闭情感面板后没有高亮时间天气区域。")
		_expect(not resource_step.has("focus_targets"), "关闭情感面板后仍同时高亮精力区域。")
	_expect(affection_step_index >= 0, "引导中缺少情感按钮步骤。")
	if affection_step_index >= 0:
		var affection_step := guide_steps[affection_step_index] as Dictionary
		var affection_overlay_options := affection_step.get("overlay_options", {}) as Dictionary
		_expect(bool(affection_overlay_options.get("capture_focus_clicks", false)), "情感按钮高亮没有捕获焦点点击。")
		_expect(str(affection_overlay_options.get("focus_wait_action", "")) == "open_affection", "情感按钮高亮没有转发 open_affection。")
		guide_manager._state["current_step_index"] = affection_step_index
	guide_manager._on_overlay_focus_pressed("open_affection")
	await process_frame
	_expect(main_scene.affection_overlay.visible, "点击情感按钮高亮没有打开情感面板。")
	main_scene._hide_affection_popup()
	await create_timer(0.25).timeout
	guide_manager._state["current_step_index"] = goal_step_index
	main_scene._on_wechat_closed()
	var activated_topic: Dictionary = topic_manager.get_active_topic_for(character_id)
	_expect(str(activated_topic.get("event_id", "")) == "jing_piano_practice_followup", "固定微聊完成事件没有激活赴约前 AI 主线。")
	_expect(str(activated_topic.get("auto_start_state", "")) == "pending", "激活的 AI 主线没有进入 pending 状态。")
	_expect(str(activated_topic.get("auto_start_source_type", "")) == "fixed_chat_close", "激活的 AI 主线没有绑定关闭微聊触发源。")
	_expect(bool((fixed_chat_manager._chat_states.get("jing_piano_practice_invite", {}) as Dictionary).get("completion_events_applied", false)), "固定微聊完成事件没有持久化幂等标记。")
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
		_expect(int(game_data_manager.profile.current_energy) == energy_before_guided_chat, "目标引导后的 guided AI 主线不应消耗精力。")
		_expect(manager.free_chat_info_layer.visible, "guided AI 主线开始后没有显示回合信息卡。")
		_expect(manager.free_chat_round_label.text.contains("对话轮次0/4"), "回合信息卡没有显示初始 0/4 对话轮次，实际为：%s（current=%d max=%d）。" % [manager.free_chat_round_label.text, manager.free_chat_current_round, manager.free_chat_max_rounds])
		guide_manager._state["current_step_index"] = guided_round_step_index
		guide_manager._persist_state_exactly()
		guide_manager._refresh_current_step_display()
		var round_step_before := str(guide_manager.get_current_step_id())
		var round_action_accepted: bool = bool(guide_manager.report_action("acknowledge_guided_ai_round_limit"))
		var persisted_guide_state: Dictionary = game_data_manager.get_archive_custom_config("guide_state_v1", {})
		_expect(guide_manager.get_current_step_id() == "explain_guided_ai_quick_options", "点击回合卡后没有进入快捷对话引导：before=%s accepted=%s after=%s memory_index=%d persisted_index=%d loaded_archive=%s active_archive=%s。" % [round_step_before, str(round_action_accepted), guide_manager.get_current_step_id(), int(guide_manager._state.get("current_step_index", -1)), int(persisted_guide_state.get("current_step_index", -1)), guide_manager._loaded_archive_id, game_data_manager.get_active_archive_id()])
		manager._populate_quick_options([
			{"text": "我会陪你准备。", "focus": "intimacy"},
			{"text": "你最担心什么？", "focus": "trust"}
		])
		_expect(not guide_manager._overlay.visible, "AI 选项生成当帧就提前显示了尚未稳定的引导高亮。")
		await _wait_for_guide_overlay(guide_manager)
		var quick_option_focus_data: Array = guide_manager._resolve_step_focus_rects(guide_manager._get_current_step())
		var rendered_focus_entries: Array = guide_manager._overlay._focus_entries
		_expect(guide_manager._overlay.visible, "AI 选项稳定生成后快捷对话引导没有重新显示。")
		_expect(quick_option_focus_data.size() == 2, "快捷对话引导目标没有包含两个完整选项。")
		_expect(rendered_focus_entries.size() == 2, "快捷对话引导最终没有渲染两个高亮框。")
		if quick_option_focus_data.size() == 2 and rendered_focus_entries.size() == 2:
			for focus_index in range(2):
				var expected_rect: Rect2 = (quick_option_focus_data[focus_index] as Dictionary).get("rect", Rect2())
				var rendered_rect: Rect2 = (rendered_focus_entries[focus_index] as Dictionary).get("rect", Rect2())
				_expect(expected_rect.position.distance_to(rendered_rect.position) <= 0.75 and expected_rect.size.distance_to(rendered_rect.size) <= 0.75, "快捷对话第 %d 个高亮框没有稳定包裹实际选项。" % (focus_index + 1))
		guide_manager._on_overlay_focus_pressed("acknowledge_guided_ai_quick_options")
		_expect(guide_manager.get_current_step_id() == "explain_guided_ai_input_field", "快捷对话引导后没有进入输入框引导。")
		guide_manager._on_overlay_focus_pressed("acknowledge_guided_ai_input_field")
		_expect(guide_manager.get_current_step_id() == "explain_guided_ai_send_button", "输入框引导后没有进入发送按钮引导。")
		guide_manager._on_overlay_focus_pressed("acknowledge_guided_ai_send_button")
		_expect(guide_manager.get_current_step_id() == "explain_guided_ai_voice_button", "发送按钮引导后没有进入语音按钮引导。")
		await _wait_for_guide_presentation(guide_manager, "schedule_onboarding_guide:%d" % int(guide_manager._state.get("current_step_index", -1)))
		_expect(str(guide_manager._overlay._overlay_options.get("focus_wait_action", "")) == "acknowledge_guided_ai_voice_button", "语音按钮高亮仍携带上一步引导动作。")
		var voice_button_text_before: String = manager.voice_record_btn.text
		var voice_button_modulate_before: Color = manager.voice_record_btn.modulate
		manager._on_voice_record_down()
		_expect(guide_manager.get_current_step_id() == "finish_guided_ai_input_guide", "语音按钮教程点击没有直接进入输入方式收尾引导。")
		await _wait_for_guide_presentation(guide_manager, "schedule_onboarding_guide:%d" % int(guide_manager._state.get("current_step_index", -1)))
		_expect(guide_manager._active_presentation_key.ends_with(":30"), "输入方式收尾步骤状态已推进但 Overlay 没有切换到第 30 步。")
		_expect(guide_manager._overlay._focus_entries.is_empty(), "输入方式收尾步骤仍在等待不存在的 guided_ai_dialogue 焦点。")
		_expect(bool(guide_manager._overlay._overlay_options.get("center_panel_when_no_focus", false)), "输入方式收尾步骤没有按无焦点提示居中呈现。")
		_expect(str(guide_manager._overlay._overlay_options.get("background_wait_action", "")) == "finish_guided_ai_input_guide", "输入方式收尾步骤没有配置背景点击推进动作。")
		_expect(manager.voice_record_btn.text == voice_button_text_before, "点击语音按钮引导高亮错误触发了语音录制。")
		_expect(manager.voice_record_btn.modulate == voice_button_modulate_before, "点击语音按钮引导高亮错误改变了语音按钮状态。")
		_expect(not manager._voice_record_press_active, "语音按钮教程期间错误建立了录音按住状态。")
		manager._on_voice_record_up()
		_expect(manager.voice_record_btn.text == voice_button_text_before, "语音教程推进后的鼠标释放错误触发了语音识别。")
		_expect(manager.voice_record_btn.modulate == voice_button_modulate_before, "语音教程推进后的鼠标释放错误改变了语音按钮状态。")
		guide_manager._on_overlay_background_pressed("finish_guided_ai_input_guide")
		_expect(guide_manager.get_current_step_id() == "finish_first_chat_after_goal", "输入方式收尾后没有进入等待主线完成步骤。")
		var completion_start_step := str(guide_manager.get_current_step_id())
		main_scene.ui_panel.visible = false
		main_scene._on_embedded_session_completed({
			"mode": "main_story",
			"story_topic": {"event_id": "jing_piano_practice_followup"}
		})
		_expect(int(guide_manager._state.get("current_step_index", -1)) > finish_step_index and str(guide_manager.get_current_step_id()) != "", "赴约前 AI 主线完成信号没有立即持久化推进后续引导：起点=%s 当前=%s index=%d finish_index=%d。" % [completion_start_step, guide_manager.get_current_step_id(), int(guide_manager._state.get("current_step_index", -1)), finish_step_index])
		_expect(main_scene._pending_guided_ai_completion_guide_actions, "主 UI 尚未恢复时没有保留后续引导刷新请求。")
		main_scene._on_chat_closed()
		await create_timer(0.4).timeout
		_expect(int(guide_manager._state.get("current_step_index", -1)) > finish_step_index and str(guide_manager.get_current_step_id()) != "", "赴约前 AI 主线结束后没有续接有效的后续引导。")
		_expect(not main_scene._pending_guided_ai_completion_guide_actions, "主 UI 恢复后没有完成后续引导刷新。")
		var guide_overlay := guide_manager._overlay as Control
		var guide_body := guide_overlay.get_node_or_null("GuidePanel/GuideRow/MessagePanel/MessageMargin/BodyLabel") as RichTextLabel if is_instance_valid(guide_overlay) else null
		_expect(is_instance_valid(guide_overlay) and guide_overlay.visible and guide_overlay.is_visible_in_tree(), "主线结束后后续引导 Overlay 没有真实显示：step=%s overlay_visible=%s ui_ready=%s。" % [guide_manager.get_current_step_id(), str(guide_overlay.visible if is_instance_valid(guide_overlay) else false), str(main_scene.is_main_ui_ready_for_guide())])
		_expect(is_instance_valid(guide_body) and not guide_body.text.strip_edges().is_empty(), "主线结束后后续引导 Overlay 没有可见提示正文。")
		_expect(guide_manager.get_current_step_id() == "explain_main_affection_button", "AI 主线结束后没有先进入情感按钮引导。")
		main_scene.open_affection_from_guide()
		await create_timer(0.3).timeout
		_expect(guide_manager.get_current_step_id() == "explain_main_affection_panel", "打开情感面板后没有进入面板说明引导。")
		_expect(not main_scene.get_affection_panel_focus_entry().is_empty(), "情感面板说明步骤没有生成可用焦点。")
		guide_manager._on_overlay_focus_pressed("acknowledge_affection_panel")
		_expect(guide_manager.get_current_step_id() == "close_main_affection_panel", "确认情感面板后没有进入关闭按钮引导。")
		_expect(not main_scene.get_affection_close_button_focus_entry().is_empty(), "情感面板关闭步骤没有生成关闭按钮焦点。")
		main_scene._hide_affection_popup()
		await create_timer(0.3).timeout
		_expect(guide_manager.get_current_step_id() == "inspect_main_panels_after_interact", "关闭情感面板后没有进入时间天气引导。")
		_expect(not guide_manager._resolve_step_focus_rects(guide_steps[resource_guide_step_index] as Dictionary).is_empty(), "关闭情感面板后时间天气区域无法生成高亮焦点。")
	guide_manager._state = original_guide_state
	game_data_manager.config.voice_enabled = original_voice_enabled
	game_data_manager.set_active_archive_id(original_archive_id, false)
	game_data_manager.reload_active_archive_data()
	current_scene = original_current_scene
	main_scene.queue_free()
	await process_frame
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _wait_for_fixed_chat_options(fixed_chat_manager: Node, script_id: String) -> Array:
	for _attempt in range(80):
		var options: Array = fixed_chat_manager.get_current_options(script_id)
		if not options.is_empty():
			return options
		await create_timer(0.1).timeout
	return []


func _wait_for_fixed_chat_completion(fixed_chat_manager: Node, script_id: String) -> void:
	for _attempt in range(80):
		var state: Dictionary = fixed_chat_manager._chat_states.get(script_id, {})
		if bool(state.get("completion_events_applied", false)):
			return
		await create_timer(0.1).timeout


func _wait_for_guide_overlay(guide_manager: Node) -> void:
	for _attempt in range(60):
		if is_instance_valid(guide_manager._overlay) and guide_manager._overlay.visible:
			return
		await process_frame


func _wait_for_guide_presentation(guide_manager: Node, expected_key: String) -> void:
	for _attempt in range(60):
		if (
			is_instance_valid(guide_manager._overlay)
			and guide_manager._active_presentation_key == expected_key
			and guide_manager._pending_presentation_key == ""
			and guide_manager._overlay.visible
		):
			return
		await process_frame


func _finish() -> void:
	if failures.is_empty():
		print("EMBEDDED_STORY_CHOICE_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("EMBEDDED_STORY_CHOICE_SMOKE: %s" % failure)
	quit(1)