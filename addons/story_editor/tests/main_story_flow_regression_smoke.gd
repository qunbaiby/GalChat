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
				_expect(step_text.length() <= 72, "引导步骤 %s 的正文超过引导面板软上限。" % str((step_value as Dictionary).get("id", "unknown")))
	_expect(guide_text.contains("\"id\": \"explain_interaction_energy\"") and guide_text.contains("\"highlight_feature\": \"main.energy\""), "第六天缺少精力说明。")
	if guide_data is Dictionary:
		var schedule_guide: Dictionary = {}
		var day6_music_guide: Dictionary = {}
		for guide_value in (guide_data as Dictionary).get("guides", []):
			if not guide_value is Dictionary:
				continue
			match str((guide_value as Dictionary).get("id", "")):
				"schedule_onboarding_guide":
					schedule_guide = guide_value
				"day6_music_followup_guide":
					day6_music_guide = guide_value
		var daily_chat_step_ids: Array[String] = []
		var day6_steps: Dictionary = {}
		for step_value in day6_music_guide.get("steps", []):
			if step_value is Dictionary:
				var day6_step_id := str((step_value as Dictionary).get("id", ""))
				day6_steps[day6_step_id] = step_value
				if day6_step_id in ["open_day6_lunch", "select_day6_lunch_takeout", "close_day6_lunch_result", "open_first_daily_chat", "explain_daily_chat_resources", "choose_first_daily_chat_topic", "wait_first_daily_chat_options", "explain_daily_chat_end_button", "finish_daily_chat_guide", "wait_first_daily_chat_finished"]:
					daily_chat_step_ids.append(day6_step_id)
		_expect(daily_chat_step_ids == ["open_day6_lunch", "select_day6_lunch_takeout", "close_day6_lunch_result", "open_first_daily_chat", "explain_daily_chat_resources", "choose_first_daily_chat_topic", "wait_first_daily_chat_options", "explain_daily_chat_end_button", "finish_daily_chat_guide", "wait_first_daily_chat_finished"], "Day6 午餐与日常聊天教程顺序不正确。")
		_expect(str(day6_steps.get("open_day6_lunch", {}).get("text", "")) == "补课一上午肚子有点饿了呢？{player_title}，我们先吃午餐吧，吃完以后我们聊聊天~", "Day6 午餐按钮引导文案不正确。")
		_expect(str(day6_steps.get("select_day6_lunch_takeout", {}).get("text", "")).is_empty(), "Day6 点外卖步骤不应显示引导文字。")
		_expect(str(day6_steps.get("explain_daily_chat_resources", {}).get("target_mode", "")) == "daily_resource_status", "日常聊天资源说明没有同时定位时间和精力面板。")
		_expect(str(day6_steps.get("explain_daily_chat_resources", {}).get("text", "")) == "日常聊天会推进时间和消耗精力呢，虽然很想跟{player_title}一直聊天，但还是要注意把控时间，不能太累呢~", "日常聊天资源说明文案不正确。")
		var expected_step_ids := [
			"prompt_start_companion_journey",
			"open_first_rest_confirmation",
			"confirm_first_rest",
			"wait_first_rest_transition_finished",
			"explain_interaction_energy",
			"open_first_meal",
			"select_first_meal_takeout",
			"close_first_meal_result"
		]
		var actual_step_ids: Array[String] = []
		var meal_steps: Dictionary = {}
		for step_value in schedule_guide.get("steps", []):
			if not step_value is Dictionary:
				continue
			var step_id := str((step_value as Dictionary).get("id", ""))
			if expected_step_ids.has(step_id):
				actual_step_ids.append(step_id)
				meal_steps[step_id] = step_value
		_expect(actual_step_ids == expected_step_ids, "Day5 休息与 Day6 精力早餐引导顺序不正确。")
		for daily_chat_step_id in daily_chat_step_ids:
			_expect(not schedule_guide.get("steps", []).any(func(step: Variant) -> bool: return step is Dictionary and str((step as Dictionary).get("id", "")) == daily_chat_step_id), "Day6 午餐或日常聊天步骤错误连接在默认引导中：%s。" % daily_chat_step_id)
		var rest_prompt_step: Dictionary = meal_steps.get("prompt_start_companion_journey", {})
		var rest_prompt_options: Dictionary = rest_prompt_step.get("overlay_options", {})
		_expect(bool(rest_prompt_options.get("center_panel_when_no_focus", false)), "首次休息提示没有在主界面中央显示。")
		_expect(str(rest_prompt_options.get("background_wait_action", "")) == "acknowledge_first_rest_prompt", "首次休息提示没有等待任意位置点击。")
		_expect(str(rest_prompt_step.get("text", "")) == "时间不早了呢，为了明天能够更好地接受静老师的引导，我们早点休息吧。", "首次休息提示文案不正确。")
		var rest_button_step: Dictionary = meal_steps.get("open_first_rest_confirmation", {})
		_expect(str(rest_button_step.get("target_mode", "")) == "rest_button", "首次休息引导没有高亮当前背景的休息按钮。")
		_expect(not bool((rest_button_step.get("overlay_options", {}) as Dictionary).get("capture_focus_clicks", false)), "首次休息按钮点击被遮罩拦截，无法打开确认弹窗。")
		var rest_confirm_step: Dictionary = meal_steps.get("confirm_first_rest", {})
		_expect(str(rest_confirm_step.get("target_mode", "")) == "rest_confirm_button", "首次休息确认引导没有高亮弹窗确认按钮。")
		_expect(not bool((rest_confirm_step.get("overlay_options", {}) as Dictionary).get("capture_focus_clicks", false)), "首次休息确认点击被遮罩拦截，无法执行休息。")
		var rest_wait_step: Dictionary = meal_steps.get("wait_first_rest_transition_finished", {})
		_expect(bool(rest_wait_step.get("hide_overlay", false)) and str(rest_wait_step.get("wait_action", "")) == "first_rest_transition_finished", "休息确认后没有隐藏等待跨日转场完成。")
		_expect(str(meal_steps.get("explain_interaction_energy", {}).get("text", "")) == "休息了一晚精力有所恢复，日常互动都会消耗精力，要记得随时补充哦。为了一会儿能以更好的状态接受辅导，我们先吃早餐吧。", "第六天精力引导文案不正确。")
		_expect(str(meal_steps.get("open_first_meal", {}).get("text", "")) == "点击吃饭按钮，我们先吃好早餐，再去找静老师接受辅导。", "早餐按钮引导文案不正确。")
		_expect(str(meal_steps.get("select_first_meal_takeout", {}).get("text", "")) == "Luna现在还不会做饭，只能委屈{player_title}跟我一起吃外卖了，等以后我学会了做饭，就能给{player_title}做饭吃了。", "点外卖引导文案不正确。")
		_expect(str(meal_steps.get("close_first_meal_result", {}).get("text", "")).contains("出发去找静老师"), "早餐结果页没有衔接外出引导。")
		_expect(str(meal_steps.get("open_first_meal", {}).get("highlight_feature", "")) == "main.meal", "吃饭按钮引导没有高亮 MealButton。")
		_expect((meal_steps.get("open_first_meal", {}).get("allowed_interactions", []) as Array) == ["main.meal"], "早餐按钮引导没有放行真实 MealButton 点击。")
		var meal_overlay_options: Dictionary = meal_steps.get("open_first_meal", {}).get("overlay_options", {})
		_expect(bool(meal_overlay_options.get("capture_focus_clicks", false)), "早餐按钮引导没有由 Overlay 稳定捕获高亮点击。")
		_expect(str(meal_overlay_options.get("focus_wait_action", "")) == "open_meal", "早餐按钮高亮点击没有上报 open_meal。")
		_expect(str(meal_overlay_options.get("focus_handler_method", "")) == "open_meal_from_guide", "早餐按钮高亮点击没有代理到真实吃饭处理。")
		_expect(str(meal_steps.get("select_first_meal_takeout", {}).get("target_mode", "")) == "meal_takeout_button", "点外卖引导没有定位外卖按钮。")
		_expect(str(meal_steps.get("close_first_meal_result", {}).get("target_mode", "")) == "meal_result", "结果页引导没有定位吃饭结果页。")

		var guided_ai_step_ids := [
			"explain_guided_ai_round_limit",
			"explain_guided_ai_quick_options",
			"explain_guided_ai_input_field",
			"explain_guided_ai_send_button",
			"explain_guided_ai_voice_button",
			"finish_guided_ai_input_guide",
			"finish_first_chat_after_goal"
		]
		var actual_guided_ai_step_ids: Array[String] = []
		var guided_ai_steps: Dictionary = {}
		for step_value in schedule_guide.get("steps", []):
			if not step_value is Dictionary:
				continue
			var step_id := str((step_value as Dictionary).get("id", ""))
			if guided_ai_step_ids.has(step_id):
				actual_guided_ai_step_ids.append(step_id)
				guided_ai_steps[step_id] = step_value
		_expect(actual_guided_ai_step_ids == guided_ai_step_ids, "AI 主线回合、输入方式与自由对话引导没有连续排列。")
		var expected_target_modes := {
			"explain_guided_ai_quick_options": "guided_ai_player_options",
			"explain_guided_ai_input_field": "guided_ai_input_field",
			"explain_guided_ai_send_button": "guided_ai_send_button",
			"explain_guided_ai_voice_button": "guided_ai_voice_button"
		}
		for step_id in expected_target_modes.keys():
			var input_step: Dictionary = guided_ai_steps.get(step_id, {})
			var input_options: Dictionary = input_step.get("overlay_options", {})
			_expect(str(input_step.get("target_mode", "")) == str(expected_target_modes[step_id]), "%s 没有定位正确的 AI 输入控件。" % step_id)
			_expect(bool(input_options.get("capture_focus_clicks", false)), "%s 没有拦截真实控件操作。" % step_id)
			_expect(str(input_options.get("focus_wait_action", "")) == str(input_step.get("wait_action", "")), "%s 的高亮点击没有只推进引导。" % step_id)
		var guided_finish_step: Dictionary = guided_ai_steps.get("finish_guided_ai_input_guide", {})
		var guided_finish_options: Dictionary = guided_finish_step.get("overlay_options", {})
		_expect(str(guided_finish_step.get("target_mode", "")).is_empty(), "AI 输入收尾提示仍声明了无法解析的伪焦点目标。")
		_expect(bool(guided_finish_step.get("show_before_scene_ready", false)), "AI 输入收尾提示没有在输入引导推进后立即呈现。")
		_expect(bool(guided_finish_options.get("center_panel_when_no_focus", false)), "AI 输入收尾提示没有居中显示。")
		_expect(str(guided_finish_options.get("background_wait_action", "")) == "finish_guided_ai_input_guide", "AI 输入收尾提示没有等待任意位置点击。")

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
	_expect(schedule_source.contains("time_manager.PERIOD_EVENING, 18, 0"), "行程完成后没有停在周五 18:00。")

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
	_expect(not chat_gate_source.contains("open_first_daily_chat"), "暂缓日常聊天引导仍绕过聊天开放时间。")
	_expect(chat_gate_source.contains("weekday == 5 and current_hour >= 18"), "主场景 ChatButton 没有在周五 18:00 开放日常聊天。")
	_expect(main_scene_source.contains("var rest_available: bool = current_hour >= 19"), "休息按钮没有统一限制为 19:00 后开放。")
	_expect(main_scene_source.contains("_pending_guided_ai_completion_guide_actions = true"), "AI 主线结束后没有等待主 UI 恢复再推进引导。")
	_expect(main_scene_source.contains("_pending_guided_ai_completion_guide_actions = true\n\t\t_advance_guided_ai_completion_guide_steps()"), "AI 主线完成信号没有立即持久化推进后续引导。")
	_expect(not main_scene_source.contains('_report_guide_action("finish_guided_ai_input_guide")'), "AI 主线结束时仍会强制跳过未触发的输入说明引导。")
	_expect(main_scene_source.contains("func open_daily_chat_from_guide() -> void:"), "日常聊天引导缺少启动入口。")
	var story_time_source := FileAccess.get_file_as_string("res://assets/data/story/story_time.json")
	_expect(not story_time_source.contains("deferred_daily_chat_guide"), "已移除的暂缓日常聊天教程仍被日期事件调度。")
	_expect(main_scene_source.contains('_report_guide_action("open_meal")'), "点击吃饭按钮没有推进吃饭引导。")
	_expect(main_scene_source.contains('_report_guide_action("close_meal_result")') and main_scene_source.contains("start_scheduled_guides_if_needed"), "关闭早餐结果页没有推进并启动第六天外出引导。")
	_expect(main_scene_source.contains('_update_button_states_by_time()\n\t_report_guide_action("first_rest_transition_finished")'), "跨日后没有在推进早餐引导前刷新吃饭按钮。")
	var meal_panel_source := FileAccess.get_file_as_string("res://scripts/ui/main/meal_panel.gd")
	_expect(meal_panel_source.contains('report_action("select_meal_takeout")'), "点击外卖按钮没有推进结果页引导。")
	_expect(main_scene_source.contains('"content": "（放松地看向你）%s，要聊些什么呢？" % player_address'), "日常聊天前置对白没有使用玩家称呼。")
	_expect(main_scene_source.contains('"content": "（放松地看向你）%s，要聊些什么呢？" % player_address, "auto_advance": true'), "日常聊天前置对白结束后不会自动展示话题。")
	_expect(not main_scene_source.contains('"content": "周末的片刻显得格外安静。"'), "日常聊天仍保留多余的开场旁白。")
	_expect(not main_scene_source.contains('"content": "她把选择交给了你。"'), "日常聊天仍保留‘她把选择交给了你’。")
	var chat_closed_start := main_scene_source.find("func _on_chat_closed() -> void:")
	var chat_closed_end := main_scene_source.find("\nfunc ", chat_closed_start + 1)
	var chat_closed_source := main_scene_source.substr(chat_closed_start, chat_closed_end - chat_closed_start) if chat_closed_start >= 0 and chat_closed_end > chat_closed_start else ""
	_expect(chat_closed_source.contains("_story_mode_active = false") and chat_closed_source.contains("_set_interaction_ui_hidden_for_dialogue(false)"), "AI 主线关闭后没有释放主场景交互锁。")
	_expect(main_scene_source.contains("[wechat_button, hide_ui_button, camera_button, phone_button]"), "主场景非时间门控按钮没有从引导锁中统一放行。")
	_expect(not main_scene_source.contains("[wechat_button, rest_button, hide_ui_button, camera_button, phone_button]"), "休息按钮仍被通用解锁逻辑绕过 19:00 时间门槛。")
	_expect(main_scene_source.contains("_pause_main_scene_bgm(\"afk\")") and main_scene_source.contains("_resume_main_scene_bgm(\"afk\")"), "普通挂机 BGM 暂停原因没有成对维护。")
	_expect(main_scene_source.contains("_pause_main_scene_bgm(\"desktop_game_foreground\")") and main_scene_source.contains("_resume_main_scene_bgm(\"desktop_game_foreground\")"), "桌面挂机 BGM 暂停原因没有成对维护。")
	var guide_source := FileAccess.get_file_as_string("res://scripts/data/guide_manager.gd")
	_expect(guide_source.contains('"open_first_meal":\n\t\t\treturn interaction_id == "main.meal"'), "GuideManager 没有将早餐步骤限制为 MealButton 交互。")
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