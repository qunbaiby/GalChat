extends SceneTree

const ARCHIVE_A := "archive_isolation_a"
const ARCHIVE_B := "archive_isolation_b"
const MusicLibrary = preload("res://scripts/data/music_library.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_data_manager = root.get_node_or_null("GameDataManager")
	_expect(game_data_manager != null, "GameDataManager 未初始化。")
	if game_data_manager == null:
		_finish()
		return
	var save_manager = game_data_manager.save_manager
	_expect(save_manager != null, "SaveManager 未初始化。")
	if save_manager == null:
		_finish()
		return
	var guide_manager = root.get_node_or_null("GuideManager")
	_expect(guide_manager != null, "GuideManager 未初始化。")
	if guide_manager == null:
		_finish()
		return

	save_manager.delete_save(ARCHIVE_A)
	save_manager.delete_save(ARCHIVE_B)

	_expect(save_manager.prepare_empty_archive(ARCHIVE_A, "隔离测试 A"), "无法创建档案 A。")
	game_data_manager.profile.player_name = "档案 A"
	game_data_manager.profile.finished_stories = ["intro_story"]
	game_data_manager.config.bgm_volume = 0.23
	game_data_manager.config.resolution_idx = 2
	game_data_manager.config.pet_disturbance_mode = "安静模式"
	game_data_manager.config.unlocked_area_ids = ["archive_a_area"]
	game_data_manager.set_archive_custom_config("desktop_wallpaper_enabled", true)
	guide_manager.set_guide_opt_in(true)
	game_data_manager.config.free_chat_enabled = true
	game_data_manager.save_active_story_checkpoint({
		"script_id": "archive_a_story",
		"script_path": "res://archive_a_story.json",
		"chapter_id": "middle",
		"event_index": 3
	})
	game_data_manager.pomodoro_data["total_focus_time"] = 88
	game_data_manager.pomodoro_data["todos"] = [{"text": "仅属于 A"}]
	var tracks_a := MusicLibrary.load_tracks()
	var default_favorite := bool(tracks_a[0].get("is_favorite", false))
	tracks_a[0]["is_favorite"] = not default_favorite
	MusicLibrary.save_tracks(tracks_a)
	_expect(save_manager.auto_save("archive_isolation_a", ARCHIVE_A), "档案 A 保存失败。")
	var meta_a_first: Dictionary = save_manager.load_slot_meta(ARCHIVE_A)
	_expect(int(meta_a_first.get("schema_version", 0)) == 1, "档案 A 没有写入当前存档 schema。")
	_expect(int(meta_a_first.get("save_generation", 0)) == 1, "档案 A 首次提交代次错误。")
	_expect(str(meta_a_first.get("save_reason", "")) == "archive_isolation_a", "档案 A 没有记录存档原因。")
	_expect(not save_manager.auto_save("stale_archive_request", ARCHIVE_B), "跨档自动存档请求没有被拒绝。")
	_expect(save_manager.auto_save("archive_isolation_a_second", ARCHIVE_A), "档案 A 二次保存失败。")
	var meta_a_second: Dictionary = save_manager.load_slot_meta(ARCHIVE_A)
	_expect(int(meta_a_second.get("save_generation", 0)) == 2, "档案 A 提交代次没有递增。")
	save_manager._save_in_progress = true
	_expect(not save_manager.auto_save("reentrant_save", ARCHIVE_A), "重入自动存档请求没有被拒绝。")
	save_manager._save_in_progress = false
	var meta_after_reentrant_rejection: Dictionary = save_manager.load_slot_meta(ARCHIVE_A)
	_expect(int(meta_after_reentrant_rejection.get("save_generation", 0)) == 2, "失败的重入请求错误提交了新代次。")
	var profile_path_a: String = game_data_manager.get_character_save_path("character_profile.json", "luna", ARCHIVE_A)
	var damaged_profile_file := FileAccess.open(profile_path_a, FileAccess.WRITE)
	_expect(damaged_profile_file != null, "无法构造中断提交测试文件。")
	if damaged_profile_file != null:
		damaged_profile_file.store_string("{ damaged live profile")
		damaged_profile_file.close()
	_expect(save_manager._write_commit_marker(ARCHIVE_A, 2, 3, "interrupted_commit_smoke"), "无法构造中断提交标记。")
	_expect(save_manager.recover_archive_if_interrupted(ARCHIVE_A), "无法从 generation 快照恢复中断提交。")
	var restored_profile_file := FileAccess.open(profile_path_a, FileAccess.READ)
	_expect(restored_profile_file != null, "恢复后角色档案不存在。")
	if restored_profile_file != null:
		var restored_profile_json := JSON.new()
		_expect(restored_profile_json.parse(restored_profile_file.get_as_text()) == OK, "恢复后的角色档案仍然损坏。")
		restored_profile_file.close()
		if restored_profile_json.data is Dictionary:
			_expect(str(restored_profile_json.data.get("player_name", "")) == "档案 A", "恢复后的角色档案不是 manifest 指向的完整代次。")
	var checkpoint_after_recovery: Dictionary = game_data_manager.load_active_story_checkpoint()
	_expect(str(checkpoint_after_recovery.get("script_id", "")) == "archive_a_story", "恢复长期快照时错误覆盖了剧情检查点。")
	var archive_root_a: String = game_data_manager.get_archive_collection_dir().path_join(ARCHIVE_A)
	var manifest_path_a := archive_root_a.path_join("manifest.json")
	var damaged_manifest_file := FileAccess.open(manifest_path_a, FileAccess.WRITE)
	_expect(damaged_manifest_file != null, "无法构造损坏 manifest 测试。")
	if damaged_manifest_file != null:
		damaged_manifest_file.store_string("not valid json")
		damaged_manifest_file.close()
	_expect(save_manager._write_commit_marker(ARCHIVE_A, 2, 3, "damaged_manifest_smoke"), "无法写入 manifest 恢复测试标记。")
	_expect(save_manager.recover_archive_if_interrupted(ARCHIVE_A), "manifest 损坏后无法扫描有效 generation。")
	var rebuilt_pointer: Dictionary = save_manager._read_archive_manifest(ARCHIVE_A)
	_expect(int(rebuilt_pointer.get("generation", 0)) == 2, "manifest 没有重建到最新有效 generation。")

	_expect(save_manager.prepare_empty_archive(ARCHIVE_B, "隔离测试 B"), "无法创建档案 B。")
	_expect(is_equal_approx(game_data_manager.config.bgm_volume, 0.23), "全局背景音量没有沿用到新档。")
	_expect(game_data_manager.config.resolution_idx == 2, "全局分辨率没有沿用到新档。")
	_expect(game_data_manager.config.pet_disturbance_mode == "安静模式", "全局桌宠设置没有沿用到新档。")
	_expect(game_data_manager.config.unlocked_area_ids.is_empty(), "新档继承了 A 的区域解锁。")
	_expect(not game_data_manager.profile.has_finished_story("intro_story"), "新档继承了 A 的开篇剧情完成状态。")
	_expect(not bool(game_data_manager.get_archive_custom_config("desktop_wallpaper_enabled", false)), "新档继承了 A 的壁纸模式。")
	_expect(not guide_manager.is_guide_opted_in(), "新档继承了 A 的引导选择。")
	_expect(guide_manager.should_prompt_for_guide_opt_in(), "新档没有恢复首次引导询问状态。")
	_expect(game_data_manager.config.free_chat_enabled, "全局自由聊天开关没有沿用到新档。")
	_expect(game_data_manager.load_active_story_checkpoint().is_empty(), "新档继承了 A 的剧情检查点。")
	game_data_manager.save_story_checkpoint_for_archive({"script_id": "stale_archive_a_story"}, ARCHIVE_A)
	_expect(game_data_manager.load_active_story_checkpoint().is_empty(), "旧档剧情回调污染了新档检查点。")
	_expect(int(game_data_manager.pomodoro_data.get("total_focus_time", -1)) == 0, "新档继承了 A 的番茄钟时长。")
	_expect((game_data_manager.pomodoro_data.get("todos", []) as Array).is_empty(), "新档继承了 A 的待办。")
	_expect(bool(MusicLibrary.load_tracks()[0].get("is_favorite", false)) == default_favorite, "新档继承了 A 的音乐收藏。")
	game_data_manager.profile.player_name = "档案 B"
	_expect(save_manager.auto_save("archive_isolation_b", ARCHIVE_B), "档案 B 保存失败。")

	_expect(save_manager.load_archive(ARCHIVE_A), "无法切回档案 A。")
	_expect(is_equal_approx(game_data_manager.config.bgm_volume, 0.23), "切回 A 后背景音量未恢复。")
	_expect(game_data_manager.config.resolution_idx == 2, "切回 A 后分辨率未恢复。")
	_expect(game_data_manager.config.pet_disturbance_mode == "安静模式", "切回 A 后桌宠设置未恢复。")
	_expect(game_data_manager.config.unlocked_area_ids.has("archive_a_area"), "切回 A 后区域解锁未恢复。")
	_expect(bool(game_data_manager.get_archive_custom_config("desktop_wallpaper_enabled", false)), "切回 A 后壁纸模式未恢复。")
	_expect(guide_manager.is_guide_opted_in(), "切回 A 后引导选择未恢复。")
	_expect(game_data_manager.config.free_chat_enabled, "切回 A 后全局自由聊天开关发生变化。")
	var restored_checkpoint: Dictionary = game_data_manager.load_active_story_checkpoint()
	_expect(int(restored_checkpoint.get("schema_version", 0)) == 1, "剧情检查点没有写入当前 schema。")
	_expect(str(restored_checkpoint.get("archive_id", "")) == ARCHIVE_A, "剧情检查点没有绑定档案身份。")
	_expect(str(restored_checkpoint.get("character_id", "")) == str(game_data_manager.config.current_character_id), "剧情检查点没有绑定角色身份。")
	_expect(str(restored_checkpoint.get("script_id", "")) == "archive_a_story", "切回 A 后剧情 ID 未恢复。")
	_expect(str(restored_checkpoint.get("chapter_id", "")) == "middle", "切回 A 后剧情章节未恢复。")
	_expect(int(restored_checkpoint.get("event_index", -1)) == 3, "切回 A 后剧情事件游标未恢复。")
	_expect(int(game_data_manager.pomodoro_data.get("total_focus_time", 0)) == 88, "切回 A 后番茄钟时长未恢复。")
	_expect((game_data_manager.pomodoro_data.get("todos", []) as Array).size() == 1, "切回 A 后待办未恢复。")
	_expect(bool(MusicLibrary.load_tracks()[0].get("is_favorite", false)) == not default_favorite, "切回 A 后音乐收藏未恢复。")
	_expect(save_manager.auto_save("snapshot_retention_smoke", ARCHIVE_A), "无法提交快照保留策略测试代次。")
	var generations_root_a := archive_root_a.path_join(".generations")
	var generations_dir := DirAccess.open(generations_root_a)
	var retained_generations: Array[String] = []
	if generations_dir != null:
		generations_dir.list_dir_begin()
		var generation_entry := generations_dir.get_next()
		while generation_entry != "":
			if generations_dir.current_is_dir() and generation_entry.begins_with("gen-"):
				retained_generations.append(generation_entry)
			generation_entry = generations_dir.get_next()
		generations_dir.list_dir_end()
	_expect(retained_generations.size() == 3, "快照保留策略没有限制为最近三代。")

	_expect(save_manager.delete_save(ARCHIVE_A), "删除档案 A 失败。")
	var archive_a_root: String = game_data_manager.get_archive_collection_dir().path_join(ARCHIVE_A)
	_expect(not DirAccess.dir_exists_absolute(archive_a_root), "档案 A 删除后目录仍存在。")
	_expect(save_manager.delete_save(ARCHIVE_B), "删除档案 B 失败。")
	var archive_b_root: String = game_data_manager.get_archive_collection_dir().path_join(ARCHIVE_B)
	_expect(not DirAccess.dir_exists_absolute(archive_b_root), "档案 B 删除后目录仍存在。")
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("ARCHIVE_ISOLATION_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("ARCHIVE_ISOLATION_SMOKE: %s" % failure)
	quit(1)