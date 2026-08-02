extends SceneTree

const SCRIPT_ID := "jing_piano_practice_invite"
const EXPECTED_TEXT := "在吗？跟你说下Luna的情况。"
const TEMP_ARCHIVE_ID := "jing_fixed_chat_ui_smoke"

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_data_manager := root.get_node_or_null("GameDataManager")
	var fixed_chat_manager := root.get_node_or_null("MobileFixedChatManager")
	var post_event_manager := root.get_node_or_null("StoryPostEventManager")
	_expect(game_data_manager != null and fixed_chat_manager != null and post_event_manager != null, "固定微聊 UI 测试依赖未初始化。")
	if game_data_manager == null or fixed_chat_manager == null or post_event_manager == null:
		_finish()
		return

	var original_archive_id := str(game_data_manager.get_active_archive_id())
	var fixed_chat_data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/mobile/fixed_chats/jing_piano_practice_invite.json"))
	var player_option_rounds := 0
	if fixed_chat_data is Dictionary:
		for message in (fixed_chat_data as Dictionary).get("messages", []):
			if message is Dictionary and str((message as Dictionary).get("speaker", "")) == "player_options":
				player_option_rounds += 1
	_expect(player_option_rounds == 3, "静固定微聊没有保留三轮需要引导放行的玩家选项。")
	game_data_manager.set_active_archive_id(TEMP_ARCHIVE_ID, false)
	game_data_manager.reload_active_archive_data()
	game_data_manager.profile.finished_stories = ["luna_piano_practice"]
	game_data_manager.profile.save_profile()
	fixed_chat_manager.clear_all_records()
	post_event_manager._migration_revision = 4
	post_event_manager._pending_events_by_timing = {"immediate": [], "next_main_scene": []}

	var main_scene_resource := load("res://scenes/ui/main/main_scene.tscn") as PackedScene
	var main_scene := main_scene_resource.instantiate()
	root.add_child(main_scene)
	await process_frame
	await process_frame
	await process_frame

	var history_path: String = game_data_manager.get_character_save_path("mobile_chat_history.json", "jing")
	var history: Variant = JSON.parse_string(FileAccess.get_file_as_string(history_path)) if FileAccess.file_exists(history_path) else []
	_expect(history is Array and not (history as Array).is_empty(), "MainScene 自动初始化后没有生成静的聊天历史。")
	if history is Array and not (history as Array).is_empty():
		_expect(str(((history as Array)[0] as Dictionary).get("text", "")) == EXPECTED_TEXT, "静聊天历史首条消息内容不正确。")

	main_scene._ensure_mobile_interface()
	main_scene.mobile_interface_instance.open_wechat_directly(true)
	await process_frame
	await process_frame
	var wechat_panel = main_scene.mobile_interface_instance.wechat_panel_instance
	_expect(is_instance_valid(wechat_panel), "MainScene 没有打开微聊面板。")
	if is_instance_valid(wechat_panel):
		wechat_panel._ensure_recent_chats()
		wechat_panel.recent_chats_instance._load_contacts()
		await process_frame
		var jing_item: Variant = wechat_panel.recent_chats_instance._item_map.get("jing")
		_expect(is_instance_valid(jing_item), "微聊联系人列表没有静。")
		if is_instance_valid(jing_item):
			_expect(str(jing_item.msg_label.text) == EXPECTED_TEXT, "静联系人摘要仍显示暂无消息。")
		wechat_panel._open_chat_session("jing")
		await process_frame
		await process_frame
		var chat_panel = wechat_panel.chat_session_instance
		_expect(is_instance_valid(chat_panel), "没有打开静的聊天会话。")
		if is_instance_valid(chat_panel):
			var guide_manager := root.get_node_or_null("GuideManager")
			var guide_steps: Array = ((guide_manager._guide_defs.get("schedule_onboarding_guide", {}) as Dictionary).get("steps", [])) if guide_manager != null else []
			var step_indices := {}
			for step_index in range(guide_steps.size()):
				var step_id := str((guide_steps[step_index] as Dictionary).get("id", ""))
				if step_id in ["explain_wechat_chat_session", "explain_wechat_fixed_options", "explain_wechat_fixed_conversation", "close_wechat_after_read"]:
					step_indices[step_id] = step_index
			_expect(not chat_panel.chat_history.is_empty(), "静的聊天面板没有加载消息历史。")
			if not chat_panel.chat_history.is_empty():
				_expect(str((chat_panel.chat_history[0] as Dictionary).get("text", "")) == EXPECTED_TEXT, "静的聊天面板没有显示预期首条消息。")
			_expect(chat_panel.message_list.get_child_count() > 0, "静的聊天面板没有渲染消息气泡。")
			if guide_manager != null and step_indices.has("explain_wechat_chat_session"):
				guide_manager._state["active_guide_id"] = "schedule_onboarding_guide"
				guide_manager._state["current_step_index"] = int(step_indices["explain_wechat_chat_session"])
				var first_message_target: Control = wechat_panel.get_first_character_message_target()
				var first_message_focus: Dictionary = wechat_panel.get_first_character_message_focus_entry()
				_expect(first_message_target != chat_panel.message_list, "静的首条消息引导仍然指向整个消息列表。")
				_expect(first_message_target.get_global_rect().size.x > 100.0, "静的首条消息高亮没有同时覆盖头像和消息气泡。")
				_expect((first_message_focus.get("rect", Rect2()) as Rect2).size.x < first_message_target.get_global_rect().size.x, "静的首条消息高亮仍包含消息行右侧空白区域。")
				_expect(float((first_message_focus.get("shape_params", {}) as Dictionary).get("corner_radius", 0.0)) == 18.0, "静的首条消息没有使用圆角高亮。")
				guide_manager._on_overlay_focus_pressed("wechat_view_chat_session")
				_expect(guide_manager.get_current_step_id() == "explain_wechat_fixed_options", "点击静的首条消息高亮后没有进入玩家选项引导。")
			_expect(not chat_panel.input_row.visible, "固定玩家选项显示时输入框和发送按钮仍然可见。")
			_expect(chat_panel.fixed_options_container.visible and chat_panel.fixed_options_container.get_child_count() > 0, "静的固定聊天没有显示玩家回复选项。")
			if chat_panel.fixed_options_container.get_child_count() > 0:
				if guide_manager != null and step_indices.has("explain_wechat_fixed_options"):
					guide_manager._state["active_guide_id"] = "schedule_onboarding_guide"
					guide_manager._state["current_step_index"] = int(step_indices["explain_wechat_fixed_options"])
				var first_option := chat_panel.fixed_options_container.get_child(0) as Button
				var selected_text := first_option.text
				first_option.pressed.emit()
				await process_frame
				_expect(chat_panel.chat_history.any(func(message: Dictionary) -> bool: return str(message.get("speaker", "")) == "player" and str(message.get("text", "")) == selected_text), "点击固定选项后没有立即发送对应玩家消息。")
				_expect(not chat_panel.input_row.visible, "固定选项发送后等待回复期间输入区重新出现。")
				if guide_manager != null:
					_expect(guide_manager.get_current_step_id() == "explain_wechat_fixed_conversation", "玩家选项发送后没有直接进入静连续回复引导。")
					_expect(guide_manager.is_guide_interaction_allowed("wechat.fixed_option"), "静连续回复期间后续玩家选项被引导锁拦截。")
					var conversation_focus: Dictionary = wechat_panel.get_fixed_conversation_focus_entry()
					_expect(not conversation_focus.is_empty(), "玩家选项发送后没有生成右侧连续对话高亮。")
					_expect(float((conversation_focus.get("shape_params", {}) as Dictionary).get("corner_radius", 0.0)) == 24.0, "右侧连续对话区域没有使用圆角高亮。")
					guide_manager.refresh_current_step_display()
					var conversation_rect: Rect2 = conversation_focus.get("rect", Rect2())
					await _wait_for_guide_focus(guide_manager, conversation_rect)
					_expect(guide_manager._overlay.visible, "玩家选项发送后连续对话引导 Overlay 没有显示。")
					_expect(not guide_manager._overlay._click_pointer.visible, "连续对话引导错误显示了点击手势。")
					_expect(guide_manager._overlay._focus_entries.any(func(entry: Dictionary) -> bool: return (entry.get("rect", Rect2()) as Rect2).position.distance_to(conversation_rect.position) < 0.1), "连续对话引导 Overlay 没有高亮右侧会话区域。")
					_expect(guide_manager.get_current_step_id() != "close_wechat_after_read", "系统结束消息出现前错误进入关闭按钮引导。")
					chat_panel.chat_history.append({"speaker": "system", "type": "system", "text": "本轮对话已结束"})
					var completion_history_file := FileAccess.open(history_path, FileAccess.WRITE)
					completion_history_file.store_string(JSON.stringify(chat_panel.chat_history, "\t"))
					completion_history_file.close()
					fixed_chat_manager._chat_states[SCRIPT_ID]["is_completed"] = true
					fixed_chat_manager.unread_count_changed.emit("jing", 0)
					await process_frame
					_expect(guide_manager.get_current_step_id() == "explain_wechat_fixed_conversation", "固定聊天仍活动时错误提前进入关闭按钮引导。")
					fixed_chat_manager._chat_states[SCRIPT_ID]["is_active"] = false
					fixed_chat_manager.unread_count_changed.emit("jing", 0)
					await process_frame
					await process_frame
					_expect(guide_manager.get_current_step_id() == "close_wechat_after_read", "系统结束消息发出后没有进入关闭按钮引导。")
					_expect(not chat_panel.input_row.visible, "固定微聊本轮结束后错误显示了自由 AI 输入面板。")
					_expect(not chat_panel.more_btn.visible and not chat_panel.plus_btn.visible, "固定微聊本轮结束后仍显示自由聊天附件入口。")

	main_scene.queue_free()
	await process_frame
	game_data_manager.set_active_archive_id(original_archive_id, false)
	game_data_manager.reload_active_archive_data()
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _wait_for_guide_focus(guide_manager: Node, expected_rect: Rect2) -> void:
	for _attempt in range(60):
		if is_instance_valid(guide_manager._overlay) and guide_manager._overlay.visible:
			var has_expected_focus: bool = guide_manager._overlay._focus_entries.any(
				func(entry: Dictionary) -> bool:
					return (entry.get("rect", Rect2()) as Rect2).position.distance_to(expected_rect.position) < 0.1
			)
			if has_expected_focus:
				return
		await process_frame


func _finish() -> void:
	if failures.is_empty():
		print("JING_FIXED_CHAT_UI_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("JING_FIXED_CHAT_UI_SMOKE: %s" % failure)
	quit(1)
