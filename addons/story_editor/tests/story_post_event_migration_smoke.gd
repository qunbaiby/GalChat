extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var manager := root.get_node_or_null("StoryPostEventManager")
	var game_data_manager := root.get_node_or_null("GameDataManager")
	var fixed_chat_manager := root.get_node_or_null("MobileFixedChatManager")
	_expect(manager != null and game_data_manager != null and fixed_chat_manager != null, "迁移依赖的 autoload 未初始化。")
	if manager == null or game_data_manager == null or fixed_chat_manager == null:
		_finish()
		return

	var original_revision := int(manager._migration_revision)
	var original_events: Dictionary = manager._pending_events_by_timing.duplicate(true)
	var original_finished_stories: Array = game_data_manager.profile.finished_stories.duplicate(true)
	var original_chat_state: Dictionary = fixed_chat_manager._chat_states.get("jing_piano_practice_invite", {}).duplicate(true)
	var original_pending_triggers: Array = fixed_chat_manager._pending_trigger_queue.duplicate(true)
	var original_advancing_scripts: Dictionary = fixed_chat_manager._advancing_scripts.duplicate(true)
	var history_path: String = fixed_chat_manager._get_mobile_history_path("jing")
	var history_existed := FileAccess.file_exists(history_path)
	var original_history := FileAccess.get_file_as_string(history_path) if history_existed else ""
	if not game_data_manager.profile.finished_stories.has("luna_piano_practice"):
		game_data_manager.profile.finished_stories.append("luna_piano_practice")
	var chat_state := original_chat_state.duplicate(true)
	chat_state["is_active"] = false
	chat_state["is_completed"] = false
	fixed_chat_manager._chat_states["jing_piano_practice_invite"] = chat_state
	manager._migration_revision = 3
	manager._pending_events_by_timing = {"immediate": [], "next_main_scene": []}

	manager._apply_legacy_migrations(false)
	var queued: Array = manager._pending_events_by_timing.get("next_main_scene", [])
	_expect(manager._migration_revision == 4, "旧档修复迁移没有写入 revision 4。")
	_expect(queued.size() == 1 and str((queued[0] as Dictionary).get("script_id", "")) == "jing_piano_practice_invite", "revision 3 空队列旧档没有补建静的固定聊天事件。")
	manager._apply_legacy_migrations(false)
	_expect((manager._pending_events_by_timing.get("next_main_scene", []) as Array).size() == 1, "重复执行迁移产生了重复聊天事件。")
	manager._migration_revision = 3
	manager._pending_events_by_timing = {"immediate": [], "next_main_scene": [{
		"type": "fixed_chat",
		"script_id": "jing_piano_practice_invite",
		"timing": "next_main_scene",
		"source_story_id": "luna_piano_practice"
	}]}
	manager._apply_legacy_migrations(false)
	_expect((manager._pending_events_by_timing.get("next_main_scene", []) as Array).size() == 1, "修复迁移重复注册了正常剧情已经排队的静微聊。")
	fixed_chat_manager._pending_trigger_queue.clear()
	fixed_chat_manager._advancing_scripts.clear()
	fixed_chat_manager._chat_states["jing_piano_practice_invite"] = chat_state.duplicate(true)
	manager.process_timing("next_main_scene")
	await process_frame
	_expect(fixed_chat_manager.is_script_active("jing_piano_practice_invite"), "MainScene 时机没有真实激活静微聊。")
	var history: Variant = JSON.parse_string(FileAccess.get_file_as_string(history_path)) if FileAccess.file_exists(history_path) else []
	_expect(history is Array and not (history as Array).is_empty(), "静微聊触发后没有写入聊天历史。")
	if history is Array and not (history as Array).is_empty():
		_expect(str(((history as Array)[(history as Array).size() - 1] as Dictionary).get("text", "")) == "在吗？跟你说下Luna的情况。", "静微聊没有写入预期的第一条消息。")

	fixed_chat_manager._advancing_scripts["jing_piano_practice_invite"] = false
	manager._migration_revision = original_revision
	manager._pending_events_by_timing = original_events
	game_data_manager.profile.finished_stories = original_finished_stories
	fixed_chat_manager._chat_states["jing_piano_practice_invite"] = original_chat_state
	fixed_chat_manager._pending_trigger_queue = original_pending_triggers
	fixed_chat_manager._advancing_scripts = original_advancing_scripts
	if history_existed:
		var history_file := FileAccess.open(history_path, FileAccess.WRITE)
		if history_file != null:
			history_file.store_string(original_history)
			history_file.close()
	elif FileAccess.file_exists(history_path):
		DirAccess.remove_absolute(history_path)
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("STORY_POST_EVENT_MIGRATION_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("STORY_POST_EVENT_MIGRATION_SMOKE: %s" % failure)
	quit(1)
