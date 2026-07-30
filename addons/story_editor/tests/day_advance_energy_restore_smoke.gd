extends SceneTree

const TEMP_ARCHIVE_ID := "day_advance_energy_restore_smoke"

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_data_manager := root.get_node_or_null("GameDataManager")
	_expect(game_data_manager != null and game_data_manager.profile != null and game_data_manager.story_time_manager != null, "跨日行动力测试依赖未初始化。")
	if game_data_manager == null or game_data_manager.profile == null or game_data_manager.story_time_manager == null:
		_finish()
		return

	var original_archive_id := str(game_data_manager.get_active_archive_id())
	game_data_manager.set_active_archive_id(TEMP_ARCHIVE_ID, false)
	game_data_manager.reload_active_archive_data()
	var profile = game_data_manager.profile
	var time_manager = game_data_manager.story_time_manager
	profile.max_energy = 50
	profile.current_energy = 7
	profile.save_profile()
	var update_count := [0]
	profile.profile_updated.connect(func(): update_count[0] += 1)
	var original_day := int(time_manager.current_day_offset)

	time_manager.advance_day(1)
	_expect(time_manager.current_day_offset == original_day + 1, "advance_day 没有推进到下一天。")
	_expect(profile.current_energy == profile.max_energy, "跨日后内存中的行动力没有回满。")
	_expect(int(update_count[0]) > 0, "跨日恢复行动力后没有通知 UI 刷新。")
	var profile_path: String = str(game_data_manager.get_character_save_path("character_profile.json"))
	var saved_data: Variant = JSON.parse_string(FileAccess.get_file_as_string(profile_path)) if FileAccess.file_exists(profile_path) else {}
	_expect(saved_data is Dictionary and int((saved_data as Dictionary).get("current_energy", -1)) == profile.max_energy, "跨日恢复后的行动力没有写入角色存档。")

	game_data_manager.set_active_archive_id(original_archive_id, false)
	game_data_manager.reload_active_archive_data()
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("DAY_ADVANCE_ENERGY_RESTORE_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("DAY_ADVANCE_ENERGY_RESTORE_SMOKE: %s" % failure)
	quit(1)
