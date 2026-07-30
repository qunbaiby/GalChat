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
			_expect(not chat_panel.chat_history.is_empty(), "静的聊天面板没有加载消息历史。")
			if not chat_panel.chat_history.is_empty():
				_expect(str((chat_panel.chat_history[0] as Dictionary).get("text", "")) == EXPECTED_TEXT, "静的聊天面板没有显示预期首条消息。")
			_expect(chat_panel.message_list.get_child_count() > 0, "静的聊天面板没有渲染消息气泡。")

	main_scene.queue_free()
	await process_frame
	game_data_manager.set_active_archive_id(original_archive_id, false)
	game_data_manager.reload_active_archive_data()
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("JING_FIXED_CHAT_UI_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("JING_FIXED_CHAT_UI_SMOKE: %s" % failure)
	quit(1)
