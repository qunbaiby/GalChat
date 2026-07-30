extends SceneTree

const ChatSplitHelper = preload("res://scripts/utils/chat_split_helper.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var story_text := FileAccess.get_file_as_string("res://assets/data/story/scripts/main/jing_piano_practice_followup.json")
	var story_data: Variant = JSON.parse_string(story_text)
	_expect(story_data is Dictionary, "无法解析专项辅导主线。")
	if story_data is Dictionary:
		var story_events: Array = ((((story_data as Dictionary).get("chapters", {}) as Dictionary).get("start", {}) as Dictionary).get("events", []))
		var choice_index := -1
		var guided_index := -1
		for event_index in range(story_events.size()):
			var event_value: Variant = story_events[event_index]
			if not event_value is Dictionary:
				continue
			var event_type := str((event_value as Dictionary).get("type", ""))
			if event_type == "choice":
				choice_index = event_index
			elif event_type == "guided_ai_chat":
				guided_index = event_index
		_expect(choice_index >= 0 and guided_index == choice_index + 1, "专项辅导主线缺少紧邻 Guided AI 的话题选项。")
		if choice_index >= 0:
			var choice_options: Array = (story_events[choice_index] as Dictionary).get("options", [])
			var first_choice_text := str((choice_options[0] as Dictionary).get("text", "")) if not choice_options.is_empty() else ""
			_expect(first_choice_text.contains("周六") and first_choice_text.contains("专项辅导"), "专项辅导话题选项内容缺失。")
	var guide_text := FileAccess.get_file_as_string("res://assets/data/guide/guide_flows.json")
	_expect(guide_text.contains("\"id\": \"choose_topic_after_goal\"") and guide_text.contains("\"wait_action\": \"select_main_chat_topic\""), "话题选项新手引导配置缺失。")
	var guide_data: Variant = JSON.parse_string(guide_text)
	_expect(guide_data is Dictionary, "新手引导配置无法解析。")
	if guide_data is Dictionary:
		var guides: Array = (guide_data as Dictionary).get("guides", [])
		for guide_value in guides:
			if not guide_value is Dictionary:
				continue
			for step_value in (guide_value as Dictionary).get("steps", []):
				if not step_value is Dictionary:
					continue
				var step_text := str((step_value as Dictionary).get("text", "")).strip_edges()
				_expect(step_text.length() <= 54, "引导步骤 %s 的正文超过固定三行软上限。" % str((step_value as Dictionary).get("id", "unknown")))
	_expect(guide_text.contains("\"id\": \"explain_interaction_energy\"") and guide_text.contains("\"highlight_feature\": \"main.energy\""), "陪伴引导后缺少行动力说明。")
	_expect(guide_text.contains("\"id\": \"open_first_daily_chat\"") and guide_text.contains("\"focus_wait_action\": \"open_first_daily_chat\""), "行动力说明后缺少日常聊天按钮引导。")

	var repaired_parts := ChatSplitHelper.merge_incomplete_parentheses([
		"（她按住画稿，指尖停在纸页边缘",
		"抬眼时呼吸仍有些紧张"
	])
	_expect(repaired_parts.size() == 1, "跨气泡动作括号没有合并。")
	_expect(str(repaired_parts[0]).ends_with("）"), "末尾未闭合的全角括号没有补齐。")
	_expect(ChatSplitHelper.close_unbalanced_parentheses("(轻轻点头") == "(轻轻点头)", "半角括号没有按原样式补齐。")

	var schedule_source := FileAccess.get_file_as_string("res://scripts/ui/activity/schedule_execution_panel.gd")
	_expect(schedule_source.contains("_started_story_event_keys.has(event_id)"), "活动主线事件没有执行周期去重。")
	_expect(schedule_source.contains("if _result_shown:\n\t\treturn"), "活动结果弹窗没有幂等锁。")
	_expect(schedule_source.contains("if _settlement_committed:\n\t\treturn"), "活动结算没有幂等锁。")

	var dialogue_source := FileAccess.get_file_as_string("res://scripts/dialogue/dialogue_manager.gd")
	_expect(dialogue_source.contains("stage=response_discarded reason=reply_playback_active"), "Guided AI 没有拒绝播放期间的重复响应。")
	_expect(dialogue_source.contains("_guided_ai_reply_playback_active = true\n\t\t_play_message_sequence"), "Guided AI 没有在播放前占用互斥锁。")
	_expect(dialogue_source.contains("_refresh_guided_ai_round_guide_when_ready(host)"), "回合卡显示后没有刷新新手引导。")
	_expect(dialogue_source.contains("_guided_ai_used_option_texts.has(option_text)"), "Guided AI 没有过滤已选择过的选项。")
	_expect(dialogue_source.contains('"turn_origin": "program_event" if is_system_event else "player_input"'), "日常话题选择仍被错误标记为玩家输入。")
	_expect(dialogue_source.contains('"event_kind": "daily_topic_selected"'), "日常话题选择没有明确的程序事件类型。")
	_expect(dialogue_source.contains('var auto_advance := bool(event_data.get("auto_advance", false))') and dialogue_source.contains('await _show_message_async(content, display_speaker, true, "", "", "", auto_advance)'), "嵌入式开场没有把自动推进配置传给对白播放。")

	var main_scene_source := FileAccess.get_file_as_string("res://scripts/ui/main/main_scene.gd")
	var chat_gate_start := main_scene_source.find("func _is_scene_chat_entry_allowed_by_time()")
	var chat_gate_end := main_scene_source.find("\nfunc ", chat_gate_start + 1)
	var chat_gate_source := main_scene_source.substr(chat_gate_start, chat_gate_end - chat_gate_start) if chat_gate_start >= 0 and chat_gate_end > chat_gate_start else ""
	_expect(chat_gate_source.contains('get_current_step_id()) == "open_first_daily_chat"'), "日常聊天引导期间没有强制显示 ChatButton。")
	_expect(chat_gate_source.contains("weekday == 5 and current_hour >= 20"), "主场景 ChatButton 没有在周五晚开放日常聊天。")
	_expect(main_scene_source.contains("_pending_guided_ai_completion_guide_actions = true"), "AI 主线结束后没有等待主 UI 恢复再推进引导。")
	_expect(main_scene_source.contains("func open_daily_chat_from_guide() -> void:") and main_scene_source.contains("_start_embedded_daily_chat(_get_scene_chat_button())"), "ChatButton 引导没有直接开启日常聊天。")
	_expect(main_scene_source.contains('"content": "（放松地看向你）%s，要聊些什么呢？" % player_address'), "日常聊天前置对白没有使用玩家称呼。")
	_expect(main_scene_source.contains('"content": "（放松地看向你）%s，要聊些什么呢？" % player_address, "auto_advance": true'), "日常聊天前置对白结束后不会自动展示话题。")
	_expect(not main_scene_source.contains('"content": "周末的片刻显得格外安静。"'), "日常聊天仍保留多余的开场旁白。")
	_expect(not main_scene_source.contains('"content": "她把选择交给了你。"'), "日常聊天仍保留‘她把选择交给了你’。")
	var chat_closed_start := main_scene_source.find("func _on_chat_closed() -> void:")
	var chat_closed_end := main_scene_source.find("\nfunc ", chat_closed_start + 1)
	var chat_closed_source := main_scene_source.substr(chat_closed_start, chat_closed_end - chat_closed_start) if chat_closed_start >= 0 and chat_closed_end > chat_closed_start else ""
	_expect(chat_closed_source.contains("_story_mode_active = false") and chat_closed_source.contains("_set_interaction_ui_hidden_for_dialogue(false)"), "AI 主线关闭后没有释放主场景交互锁。")
	_expect(main_scene_source.contains("[wechat_button, rest_button, hide_ui_button, camera_button, phone_button]"), "主场景常用按钮没有从引导锁中统一放行。")
	_expect(main_scene_source.contains("_pause_main_scene_bgm(\"afk\")") and main_scene_source.contains("_resume_main_scene_bgm(\"afk\")"), "普通挂机 BGM 暂停原因没有成对维护。")
	_expect(main_scene_source.contains("_pause_main_scene_bgm(\"desktop_game_foreground\")") and main_scene_source.contains("_resume_main_scene_bgm(\"desktop_game_foreground\")"), "桌面挂机 BGM 暂停原因没有成对维护。")
	var guide_source := FileAccess.get_file_as_string("res://scripts/data/guide_manager.gd")
	var feature_paths_text := guide_source.substr(0, guide_source.find("const DEFAULT_LOCKED_FEATURES"))
	_expect(not feature_paths_text.contains("\"main.wechat\":"), "微聊仍被纳入主场景引导功能锁。")
	_expect(not feature_paths_text.contains("\"main.phone\":"), "手机仍被纳入主场景引导功能锁。")
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("MAIN_STORY_FLOW_REGRESSION_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("MAIN_STORY_FLOW_REGRESSION_SMOKE: %s" % failure)
	quit(1)