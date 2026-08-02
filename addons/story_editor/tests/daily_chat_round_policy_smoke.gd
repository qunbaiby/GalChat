extends SceneTree

const DailyChatRoundPolicy = preload("res://scripts/dialogue/daily_chat_round_policy.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var cutoff_minutes := 24 * 60
	_expect(DailyChatRoundPolicy.get_unavailable_reason(3, 3, 23 * 60 + 49, 10, cutoff_minutes) == "", "可在 24:00 前完成的下一次回复被错误阻止。")
	_expect(DailyChatRoundPolicy.get_unavailable_reason(2, 3, 21 * 60, 10, cutoff_minutes) == "energy", "下一次回复所需精力不足时没有返回 energy。")
	_expect(DailyChatRoundPolicy.get_unavailable_reason(20, 3, 23 * 60 + 50, 10, cutoff_minutes) == "late", "下一次回复到达 24:00 时没有返回 late。")
	_expect(DailyChatRoundPolicy.get_unavailable_reason(2, 3, 23 * 60 + 50, 10, cutoff_minutes) == "energy", "精力与时间同时不足时没有优先提示精力不足。")
	var main_scene_source := FileAccess.get_file_as_string("res://scripts/ui/main/main_scene.gd")
	_expect(main_scene_source.contains("DAILY_CHAT_REPLY_ENERGY_COST := 3"), "日常聊天每次回复精力成本配置缺失或默认值错误。")
	_expect(main_scene_source.contains("DAILY_CHAT_REPLY_MINUTES := 10"), "日常聊天每次回复时间成本配置缺失或默认值错误。")
	_expect(not main_scene_source.contains("DAILY_CHAT_MAX_PLAYER_ROUNDS"), "日常聊天仍保留固定玩家回合上限。")
	_expect(main_scene_source.contains("DAILY_CHAT_CUTOFF_MINUTES := 24 * 60"), "主场景丽日日常对话截止时间不是 24:00。")
	_expect(main_scene_source.count("DAILY_CHAT_CUTOFF_MINUTES") >= 3, "日常对话入口或会话请求没有统一使用 24:00 截止时间。")
	_expect(main_scene_source.contains("DAILY_CHAT_REPLY_ENERGY_COST, 24"), "丽日日常对话过晚提示没有显示 24:00。")
	_expect(main_scene_source.contains("\"reply_energy_cost\": DAILY_CHAT_REPLY_ENERGY_COST"), "日常会话请求没有传递每次回复精力成本。")
	_expect(main_scene_source.contains("\"reply_minutes\": DAILY_CHAT_REPLY_MINUTES"), "日常会话请求没有传递每次回复时间成本。")
	_expect(not main_scene_source.contains("\"max_player_rounds\": DAILY_CHAT"), "日常会话请求仍传递固定回合数。")
	var daily_entry_start := main_scene_source.find("func _start_embedded_daily_chat")
	var daily_entry_end := main_scene_source.find("\nfunc ", daily_entry_start + 1)
	var daily_entry_source := main_scene_source.substr(daily_entry_start, daily_entry_end - daily_entry_start)
	_expect(not daily_entry_source.contains("consume_energy(") and not daily_entry_source.contains("tick_minutes("), "日常聊天仍在进入对话时立即结算资源。")
	_expect(not main_scene_source.contains("_set_daily_dialogue_hud_visible"), "日常聊天仍在对话期间搬移并显示时间天气或精力 UI。")
	_expect(not main_scene_source.contains("_settle_pending_daily_chat"), "日常聊天仍在退出后执行整次固定结算。")
	var manager_source := FileAccess.get_file_as_string("res://scripts/dialogue/dialogue_manager.gd")
	_expect(manager_source.contains("reply_energy_cost") and manager_source.contains("reply_minutes"), "DialogueManager 没有读取日常聊天逐次回复成本。")
	_expect(manager_source.contains("free_chat_max_rounds = 0") and manager_source.contains("_is_embedded_daily_chat()"), "日常聊天没有关闭固定玩家回合上限。")
	_expect(manager_source.contains("_commit_embedded_daily_reply_cost()"), "日常聊天发送回复时没有逐次结算资源。")
	_expect(manager_source.contains("_request_embedded_daily_closing(unavailable_reason)"), "日常聊天资源不足时没有触发对应结束语。")
	_expect(manager_source.contains("TimeLabel") and manager_source.contains("EnergyLabel"), "日常聊天没有绑定时间与精力状态卡。")
	_expect(manager_source.contains("free_chat_round_label.text = \"对话轮次%d/%d\""), "AI 主线与日常聊天没有统一使用紧凑回合文案。")
	_expect(manager_source.contains("_embedded_daily_close_queued = true"), "日常对话点击结束仍可能立即覆盖正在播放的回复。")
	_expect(manager_source.contains("elif _embedded_daily_close_queued:\n\t\t_request_embedded_daily_closing(\"manual\")"), "当前回复序列完成后没有消费日常关闭请求。")
	_expect(manager_source.contains("var close_auto_advance := _is_embedded_daily_chat() and (_embedded_daily_close_queued or _waiting_for_chat_exit)"), "日常当前回复或结束语逐字完成后没有自动推进。")
	_expect(manager_source.count("_embedded_daily_close_queued = false") >= 3, "日常关闭排队状态没有在请求、启动与清理阶段完整重置。")
	_expect(manager_source.count("之后有机会再聊") >= 2, "日常或主线 AI 告别语没有明确表达之后再聊。")
	_expect(not manager_source.contains("也不要说‘下次见’"), "AI 告别提示词仍在禁止表达下次再聊。")
	var end_chat_template := FileAccess.get_file_as_string("res://scripts/templates/prompts/end_chat.txt")
	_expect(end_chat_template.contains("之后有机会再聊") and end_chat_template.contains("只结束当前对话"), "普通 AI 告别模板没有只结束当前对话并表达之后再聊。")
	_expect(not end_chat_template.contains("不要说“下次见”"), "普通 AI 告别模板仍在禁止表达下次再聊。")

	var game_data_manager = root.get_node_or_null("GameDataManager")
	_expect(game_data_manager != null, "GameDataManager autoload 不可用。")
	if game_data_manager:
		var profile = game_data_manager.profile
		var time_manager = game_data_manager.story_time_manager
		var original_energy: int = profile.current_energy
		var original_hour: int = time_manager.current_hour
		var original_minute: int = time_manager.current_minute
		profile.current_energy = 20
		time_manager.current_hour = 21
		time_manager.current_minute = 0
		var manager = load("res://scripts/dialogue/dialogue_manager.gd").new()
		root.add_child(manager)
		manager._embedded_session_active = true
		manager._embedded_session_request = {
			"mode": "daily",
			"reply_energy_cost": 3,
			"reply_minutes": 10,
			"daily_chat_cutoff_minutes": cutoff_minutes
		}
		_expect(manager.free_chat_max_rounds == 0, "日常对话运行时仍存在固定回合上限。")
		_expect(manager._get_embedded_daily_reply_unavailable_reason() == "", "资源充足时错误阻止日常回复。")
		manager._commit_embedded_daily_reply_cost()
		manager._commit_embedded_daily_reply_cost()
		_expect(profile.current_energy == 14, "两次日常回复没有逐次扣除共 6 点精力。")
		_expect(time_manager.current_hour == 21 and time_manager.current_minute == 20, "两次日常回复没有逐次推进共 20 分钟。")
		profile.current_energy = 2
		_expect(manager._get_embedded_daily_reply_unavailable_reason() == "energy", "下一次回复精力不足时没有返回 energy。")
		manager._embedded_daily_turn_pending = true
		_expect(manager._settle_embedded_daily_turn() == "energy", "AI 回复完成后精力不足没有自动请求结束。")
		profile.current_energy = 20
		time_manager.current_hour = 23
		time_manager.current_minute = 50
		_expect(manager._get_embedded_daily_reply_unavailable_reason() == "late", "下一次回复会到达 24:00 时没有返回 late。")
		manager._embedded_daily_turn_pending = true
		_expect(manager._settle_embedded_daily_turn() == "late", "AI 回复完成后时间过晚没有自动请求结束。")
		profile.current_energy = original_energy
		time_manager.current_hour = original_hour
		time_manager.current_minute = original_minute
		manager.queue_free()
	if failures.is_empty():
		print("DAILY_CHAT_ROUND_POLICY_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("DAILY_CHAT_ROUND_POLICY_SMOKE: %s" % failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)