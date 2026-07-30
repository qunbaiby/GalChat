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
	var official_auth_manager := root.get_node_or_null("OfficialAuthManager")
	_expect(official_auth_manager != null, "OfficialAuthManager 未初始化。")
	var logged_in_for_smoke := false
	if official_auth_manager != null and game_data_manager.config.ai_service_mode == "official" and game_data_manager.config.official_access_token.is_empty():
		var auth_result := {"done": false, "success": false, "message": ""}
		official_auth_manager.auth_state_changed.connect(func(success: bool, message: String) -> void:
			auth_result["done"] = true
			auth_result["success"] = success
			auth_result["message"] = message
		, CONNECT_ONE_SHOT)
		official_auth_manager.login_with_email("galchat_test", "GalChatTest2026!")
		var auth_deadline_ms := Time.get_ticks_msec() + 20000
		while not bool(auth_result["done"]) and Time.get_ticks_msec() < auth_deadline_ms:
			await process_frame
		print("[DailyTopicRuntimeSmoke] auth_done=%s success=%s message=%s" % [
			str(auth_result["done"]),
			str(auth_result["success"]),
			str(auth_result["message"])
		])
		_expect(bool(auth_result["done"]) and bool(auth_result["success"]), "无法登录本地开发测试账号：%s" % str(auth_result["message"]))
		logged_in_for_smoke = bool(auth_result["success"])
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
	var repository = load("res://scripts/data/daily_chat_topic_repository.gd")
	var topic_data: Dictionary = repository._load_topic_data()
	var topic_random := RandomNumberGenerator.new()
	topic_random.seed = 20260731
	var drawn_topics: Dictionary = repository.draw_topic_map(topic_random)
	for category in ["study", "life", "emotion"]:
		var category_topics: Array = topic_data.get(category, [])
		_expect(category_topics.size() >= 10, "%s 分类的固定日常话题数量不足。" % category)
		_expect(category_topics.has(drawn_topics.get(category)), "%s 分类没有从对应固定题库抽取。" % category)
	var main_scene_source := FileAccess.get_file_as_string("res://scripts/ui/main/main_scene.gd")
	var daily_entry_start := main_scene_source.find("func _start_embedded_daily_chat")
	var next_function_start := main_scene_source.find("\nfunc ", daily_entry_start + 1)
	var daily_entry_source := main_scene_source.substr(daily_entry_start, next_function_start - daily_entry_start)
	_expect(not daily_entry_source.contains("generate_dynamic_topics"), "日常三类话题入口仍在调用 AI 生成。")
	var ui_panel: Control = main_scene.get_node("UIPanel") as Control
	var weather_panel: Control = main_scene.get_node("UIPanel/WeatherPanel") as Control
	var top_status_panel: Control = main_scene.get_node("UIPanel/TopStatusPanel") as Control
	main_scene._set_daily_dialogue_hud_visible(true)
	_expect(weather_panel.get_parent() == main_scene and weather_panel.is_visible_in_tree(), "日常对话没有复用并显示主场景时间天气 UI。")
	_expect(top_status_panel.get_parent() == main_scene and top_status_panel.is_visible_in_tree(), "日常对话没有复用并显示主场景行动力 UI。")
	var manager = main_scene._ensure_embedded_dialogue_manager()
	var request := {
		"session_id": "daily_runtime_smoke",
		"mode": "daily",
		"subtype": "daily_topic",
		"intro_events": [
			{"speaker": game_data_manager.profile.char_name, "content": "（放松地看向你）老师，要聊些什么呢？", "auto_advance": true}
		],
		"topic_options": [
			{"text": "聊聊最近的学习", "kind": "study"},
			{"text": "聊聊今天的生活", "kind": "life"},
			{"text": "聊聊此刻的感受", "kind": "emotion"}
		],
		"energy_cost_per_round": 3,
		"minutes_per_round": 20,
		"daily_chat_cutoff_minutes": 23 * 60
	}
	manager.start_embedded_topic_session(request)
	var wait_frames := 0
	while wait_frames < 300 and manager._intro_playing:
		await process_frame
		wait_frames += 1
	var options_parent: CanvasItem = manager.quick_options_container.get_parent() as CanvasItem
	var visibility_chain: Array[String] = []
	var chain_node: Node = manager.quick_options_container
	while chain_node != null:
		if chain_node is CanvasItem:
			visibility_chain.append("%s(visible=%s,tree=%s)" % [chain_node.name, str((chain_node as CanvasItem).visible), str((chain_node as CanvasItem).is_visible_in_tree())])
		else:
			visibility_chain.append(str(chain_node.name))
		chain_node = chain_node.get_parent()
	print("[DailyTopicRuntimeSmoke] visibility_chain=%s" % " <- ".join(visibility_chain))
	print("[DailyTopicRuntimeSmoke] frames=%d intro=%s parent_visible=%s parent_tree_visible=%s container_visible=%s container_tree_visible=%s children=%d" % [
		wait_frames,
		str(manager._intro_playing),
		str(options_parent.visible),
		str(options_parent.is_visible_in_tree()),
		str(manager.quick_options_container.visible),
		str(manager.quick_options_container.is_visible_in_tree()),
		manager.quick_options_container.get_child_count()
	])
	_expect(not manager._intro_playing, "日常固定对白没有自动结束。")
	_expect(options_parent.visible, "话题选项父层没有设为可见。")
	_expect(options_parent.is_visible_in_tree(), "话题选项父层不在可见场景树中。")
	_expect(manager.quick_options_container.is_visible_in_tree(), "话题选项容器不在可见场景树中。")
	_expect(manager.quick_options_container.get_child_count() == 3, "没有生成三个日常话题节点。")
	if manager.quick_options_container.get_child_count() > 0:
		var energy_before_topic := int(game_data_manager.profile.current_energy)
		var minutes_before_topic := int(game_data_manager.story_time_manager.current_hour) * 60 + int(game_data_manager.story_time_manager.current_minute)
		var ai_result := {
			"done": false,
			"success": false,
			"error": "",
			"context": {},
			"turn": {}
		}
		manager.deepseek_client.realize_turn_completed.connect(func(turn: Dictionary, context: Dictionary) -> void:
			ai_result["done"] = true
			ai_result["success"] = true
			ai_result["context"] = context.duplicate(true)
			ai_result["turn"] = turn.duplicate(true)
		, CONNECT_ONE_SHOT)
		manager.deepseek_client.realize_turn_failed.connect(func(error_message: String, context: Dictionary) -> void:
			ai_result["done"] = true
			ai_result["error"] = error_message
			ai_result["context"] = context.duplicate(true)
		, CONNECT_ONE_SHOT)
		var first_option: Node = manager.quick_options_container.get_child(0)
		print("[DailyTopicRuntimeSmoke] clicking_topic=%s service_mode=%s access_token_present=%s" % [
			str(first_option.call("get_option_text")),
			str(game_data_manager.config.ai_service_mode),
			str(not game_data_manager.config.official_access_token.is_empty())
		])
		var topic_request_started_ms := Time.get_ticks_msec()
		first_option.call("_on_pressed")
		var deadline_ms := Time.get_ticks_msec() + 65000
		while not bool(ai_result["done"]) and Time.get_ticks_msec() < deadline_ms:
			await process_frame
		var result_context := ai_result["context"] as Dictionary
		print("[DailyTopicRuntimeSmoke] ai_done=%s success=%s latency_ms=%d error=%s failure_stage=%s status=%s channel=%s origin=%s event_kind=%s" % [
			str(ai_result["done"]),
			str(ai_result["success"]),
			Time.get_ticks_msec() - topic_request_started_ms,
			str(ai_result["error"]),
			str(result_context.get("failure_stage", "")),
			str(result_context.get("response_code", "")),
			str(result_context.get("channel", "")),
			str(result_context.get("turn_origin", "")),
			str(result_context.get("event_kind", ""))
		])
		_expect(bool(ai_result["done"]), "选择话题后 65 秒内没有收到 AI 成功或失败信号。")
		if not bool(ai_result["success"]):
			_expect(
				str(result_context.get("failure_stage", "")) == "auth_preflight",
				"选择话题后的 AI 请求没有成功，也没有在认证预检阶段明确失败：%s" % str(ai_result["error"])
			)
		if bool(ai_result["success"]):
			var first_speech := _collect_speech(ai_result["turn"] as Dictionary)
			_expect(not first_speech.is_empty(), "选择话题后的 AI 响应没有角色台词。")
			await _verify_segment_playback(manager, ai_result["turn"] as Dictionary, "话题首轮")
			_expect(not manager._embedded_daily_turn_pending, "选择话题后的角色回复没有播放并结算完成。")
			var energy_after_topic := int(game_data_manager.profile.current_energy)
			var minutes_after_topic := int(game_data_manager.story_time_manager.current_hour) * 60 + int(game_data_manager.story_time_manager.current_minute)
			weather_panel.call("_update_time")
			await process_frame
			var displayed_time := str(weather_panel.get_node("Margin/HBox/RightVBox/TimeHBox/TimeLabel").text)
			var displayed_energy := str(top_status_panel.get_node("MarginContainer/HBoxContainer/EnergySlot/BgPanel/Margin/ValueLabel").text)
			print("[DailyConversationRuntimeSmoke] topic_ai_speech=%s energy=%d->%d minutes=%d->%d" % [
				first_speech,
				energy_before_topic,
				energy_after_topic,
				minutes_before_topic,
				minutes_after_topic
			])
			_expect(energy_after_topic == energy_before_topic - 3, "话题首轮没有扣除 3 点行动力。")
			_expect(minutes_after_topic == minutes_before_topic + 20, "话题首轮没有推进 20 分钟。")
			_expect(displayed_time == "%02d:%02d" % [int(game_data_manager.story_time_manager.current_hour), int(game_data_manager.story_time_manager.current_minute)], "日常对话中的主场景时间 UI 没有随结算刷新。")
			_expect(displayed_energy == "%d/%d" % [energy_after_topic, int(game_data_manager.profile.max_energy)], "日常对话中的主场景行动力 UI 没有随结算刷新。")

			var player_message := "那你具体卡在哪一部分？"
			var followup_result := {
				"done": false,
				"success": false,
				"error": "",
				"context": {},
				"turn": {}
			}
			manager.deepseek_client.realize_turn_completed.connect(func(turn: Dictionary, context: Dictionary) -> void:
				if str(context.get("channel", "")) != "story_dialogue_player":
					return
				followup_result["done"] = true
				followup_result["success"] = true
				followup_result["context"] = context.duplicate(true)
				followup_result["turn"] = turn.duplicate(true)
			)
			manager.deepseek_client.realize_turn_failed.connect(func(error_message: String, context: Dictionary) -> void:
				if str(context.get("channel", "")) != "story_dialogue_player":
					return
				followup_result["done"] = true
				followup_result["error"] = error_message
				followup_result["context"] = context.duplicate(true)
			)
			manager.input_field.text = player_message
			print("[DailyConversationRuntimeSmoke] player_sending=%s" % player_message)
			var followup_request_started_ms := Time.get_ticks_msec()
			manager._on_send_pressed()
			var player_bubble_deadline_ms := Time.get_ticks_msec() + 15000
			while not manager._waiting_for_chat_click and Time.get_ticks_msec() < player_bubble_deadline_ms:
				await process_frame
			_expect(manager._waiting_for_chat_click, "玩家消息气泡没有进入等待推进状态。")
			if manager._waiting_for_chat_click:
				print("[DailyConversationRuntimeSmoke] advancing_player_bubble=true")
				_simulate_dialogue_click(manager)
			var followup_deadline_ms := Time.get_ticks_msec() + 90000
			while not bool(followup_result["done"]) and Time.get_ticks_msec() < followup_deadline_ms:
				await process_frame
			var followup_context := followup_result["context"] as Dictionary
			var followup_speech := _collect_speech(followup_result["turn"] as Dictionary)
			var followup_last_speech := _last_speech(followup_result["turn"] as Dictionary)
			print("[DailyConversationRuntimeSmoke] followup_done=%s success=%s latency_ms=%d error=%s channel=%s origin=%s player_text=%s ai_speech=%s" % [
				str(followup_result["done"]),
				str(followup_result["success"]),
				Time.get_ticks_msec() - followup_request_started_ms,
				str(followup_result["error"]),
				str(followup_context.get("channel", "")),
				str(followup_context.get("turn_origin", "")),
				str(followup_context.get("player_text", "")),
				followup_speech
			])
			_expect(bool(followup_result["done"]), "玩家发送消息后 90 秒内没有收到 AI 成功或失败信号。")
			_expect(bool(followup_result["success"]), "玩家发送消息后的 AI 生成失败：%s" % str(followup_result["error"]))
			_expect(str(followup_context.get("channel", "")) == "story_dialogue_player", "玩家消息没有走 story_dialogue_player 渠道。")
			_expect(str(followup_context.get("turn_origin", "")) == "player_input", "玩家消息没有标记为 player_input。")
			_expect(str(followup_context.get("player_text", "")) == player_message, "AI 请求上下文没有保留玩家原文。")
			_expect(not followup_speech.is_empty(), "玩家消息后的 AI 响应没有角色台词。")
			await _verify_segment_playback(manager, followup_result["turn"] as Dictionary, "玩家消息轮")
			_expect(not manager._embedded_daily_turn_pending, "玩家消息后的角色回复没有播放并结算完成。")
			var energy_after_followup := int(game_data_manager.profile.current_energy)
			var minutes_after_followup := int(game_data_manager.story_time_manager.current_hour) * 60 + int(game_data_manager.story_time_manager.current_minute)
			print("[DailyConversationRuntimeSmoke] followup_played=true energy=%d->%d minutes=%d->%d dialogue_text=%s" % [
				energy_after_topic,
				energy_after_followup,
				minutes_after_topic,
				minutes_after_followup,
				str(manager.dialogue_text.text)
			])
			_expect(energy_after_followup == energy_after_topic - 3, "玩家消息轮没有扣除 3 点行动力。")
			_expect(minutes_after_followup == minutes_after_topic + 20, "玩家消息轮没有推进 20 分钟。")
			_expect(str(manager.dialogue_text.text).contains(followup_last_speech), "第二次角色回复的最后一个气泡没有实际显示在对话 UI。")
	game_data_manager.config.voice_enabled = original_voice_enabled
	main_scene._set_daily_dialogue_hud_visible(false)
	_expect(weather_panel.get_parent() == ui_panel, "日常对话结束后时间天气 UI 没有恢复到主场景 UIPanel。")
	_expect(top_status_panel.get_parent() == ui_panel, "日常对话结束后行动力 UI 没有恢复到主场景 UIPanel。")
	main_scene.queue_free()
	await process_frame
	if logged_in_for_smoke:
		official_auth_manager.logout()
	_finish()


func _collect_speech(realized_turn: Dictionary) -> String:
	var speech_parts: Array[String] = []
	var segments: Variant = realized_turn.get("segments", [])
	if segments is Array:
		for segment in segments:
			if segment is Dictionary:
				var speech := str((segment as Dictionary).get("speech", "")).strip_edges()
				if not speech.is_empty():
					speech_parts.append(speech)
	return " ".join(speech_parts)


func _last_speech(realized_turn: Dictionary) -> String:
	var segments: Variant = realized_turn.get("segments", [])
	if segments is Array:
		for segment_index in range(segments.size() - 1, -1, -1):
			var segment: Variant = segments[segment_index]
			if segment is Dictionary:
				var speech := str((segment as Dictionary).get("speech", "")).strip_edges()
				if not speech.is_empty():
					return speech
	return ""


func _verify_segment_playback(manager: Node, realized_turn: Dictionary, label: String) -> void:
	var segments: Variant = realized_turn.get("segments", [])
	if not segments is Array:
		_expect(false, "%s 没有可验证的 segments。" % label)
		return
	var observed_index := 0
	var playback_deadline_ms := Time.get_ticks_msec() + 30000
	while manager._embedded_daily_turn_pending and Time.get_ticks_msec() < playback_deadline_ms:
		if manager._waiting_for_chat_click:
			if observed_index >= segments.size():
				_expect(false, "%s 播放了超出 segment 数量的额外气泡。" % label)
				_simulate_dialogue_click(manager)
				await process_frame
				continue
			var segment: Dictionary = segments[observed_index] as Dictionary
			var expected_speech := str(segment.get("speech", "")).strip_edges()
			var action: Variant = segment.get("action")
			var action_description := str(action.get("description", "")).strip_edges() if action is Dictionary else ""
			var displayed_text := str(manager.dialogue_text.text).strip_edges()
			var expected_display := expected_speech
			_expect(not action_description.is_empty() and action_description != "本段未提供可见动作。", "%s 第 %d 个 segment 没有真实可见动作。" % [label, observed_index + 1])
			if not action_description.is_empty() and action_description != "本段未提供可见动作。":
				expected_display = "[color=green]（%s）[/color]%s" % [action_description, expected_speech]
			print("[DailyConversationRuntimeSmoke] %s segment=%d displayed=%s expected=%s action=%s" % [
				label,
				observed_index,
				displayed_text,
				expected_speech,
				action_description
			])
			_expect(displayed_text == expected_display, "%s 第 %d 个气泡没有严格对应本段 action 与 speech。" % [label, observed_index + 1])
			_expect(not action_description.is_empty() and displayed_text.count(action_description) == 1, "%s 第 %d 个气泡的动作缺失或重复。" % [label, observed_index + 1])
			if observed_index + 1 < segments.size():
				var next_segment: Variant = segments[observed_index + 1]
				var next_speech := str(next_segment.get("speech", "")).strip_edges() if next_segment is Dictionary else ""
				_expect(next_speech.is_empty() or not displayed_text.contains(next_speech), "%s 第 %d 个气泡提前混入了下一段台词。" % [label, observed_index + 1])
			observed_index += 1
			_simulate_dialogue_click(manager)
		await process_frame
	_expect(observed_index == segments.size(), "%s 实际播放 %d 个气泡，但响应包含 %d 个 segment。" % [label, observed_index, segments.size()])


func _simulate_dialogue_click(manager: Node) -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	manager._on_click_blocker_input(click)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("EMBEDDED_DAILY_TOPIC_RUNTIME_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("EMBEDDED_DAILY_TOPIC_RUNTIME_SMOKE: %s" % failure)
	quit(1)
