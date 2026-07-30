extends SceneTree

const GUIDE_ID := "day6_music_followup_guide"
const TRACK_ID := "starry_wish_bgm"

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_data_manager := root.get_node_or_null("GameDataManager")
	var guide_manager := root.get_node_or_null("GuideManager")
	var story_post_event_manager := root.get_node_or_null("StoryPostEventManager")
	_expect(game_data_manager != null, "GameDataManager 未初始化。")
	_expect(guide_manager != null, "GuideManager 未初始化。")
	_expect(story_post_event_manager != null, "StoryPostEventManager 未初始化。")
	if game_data_manager == null or guide_manager == null or story_post_event_manager == null:
		_finish()
		return

	var main_scene_resource := load("res://scenes/ui/main/main_scene.tscn") as PackedScene
	_expect(main_scene_resource != null, "无法加载主场景。")
	if main_scene_resource == null:
		_finish()
		return

	var original_archive_id: String = str(game_data_manager.get_active_archive_id())
	if original_archive_id == "":
		game_data_manager.set_active_archive_id("day6_music_followup_smoke", false)
	var original_guide_state: Dictionary = guide_manager._state.duplicate(true)
	var original_background_id := str(game_data_manager.config.current_main_bg_id)
	var original_profile_background_id := str(game_data_manager.profile.current_main_bg_id) if game_data_manager.profile else ""
	var original_tracks: Array = MusicLibrary.load_tracks()
	var original_day_offset := int(game_data_manager.story_time_manager.current_day_offset)
	var original_post_events: Dictionary = story_post_event_manager._pending_events_by_timing.duplicate(true)
	var original_voice_enabled := bool(game_data_manager.config.voice_enabled)
	game_data_manager.config.voice_enabled = false

	var main_scene := main_scene_resource.instantiate()
	root.add_child(main_scene)
	await process_frame
	await process_frame

	guide_manager._state = guide_manager._normalize_state({})
	MusicLibrary.update_track_fields(TRACK_ID, {"in_playlist": false})
	game_data_manager.story_time_manager.current_day_offset = 5
	story_post_event_manager._pending_events_by_timing = {"immediate": [], "next_main_scene": []}
	var completion_events: Array[Dictionary] = game_data_manager.story_time_manager.get_current_completion_events("tutoring_completed")
	_expect(completion_events.size() == 1, "第六日时间数据没有配置课业完成事件。")
	var presentation_event: Dictionary = completion_events[0] if not completion_events.is_empty() else {}
	_expect(str(presentation_event.get("background_id", "")) == "piano_room", "琴房背景没有配置在时间事件中。")
	_expect(str(presentation_event.get("play_track_id", "")) == TRACK_ID and (presentation_event.get("playlist_track_ids", []) as Array).has(TRACK_ID), "播放与歌单曲目没有配置在时间事件中。")
	_expect(str(presentation_event.get("guide_id", "")) == GUIDE_ID, "音乐引导 ID 没有配置在时间事件中。")
	_expect(story_post_event_manager.register_time_completion("tutoring_completed"), "课业完成没有注册时间配置中的后置事件。")
	story_post_event_manager.register_time_completion("tutoring_completed")
	_expect((story_post_event_manager._pending_events_by_timing.get("next_main_scene", []) as Array).size() == 1, "重复上报课业完成产生了重复后置事件。")
	main_scene._process_story_post_events_on_main_ready()
	await process_frame
	await process_frame

	_expect((story_post_event_manager._pending_events_by_timing.get("next_main_scene", []) as Array).is_empty(), "主场景没有消费时间配置的后置事件。")
	_expect(str(game_data_manager.config.current_main_bg_id) == "piano_room", "主场景没有切换并保存琴房背景。")
	_expect(game_data_manager.profile == null or str(game_data_manager.profile.current_main_bg_id) == "piano_room", "角色档案没有同步琴房背景。")
	var starry_track: Dictionary = {}
	for track_value in MusicLibrary.load_tracks():
		if track_value is Dictionary and str((track_value as Dictionary).get("id", "")) == TRACK_ID:
			starry_track = track_value
			break
	_expect(not starry_track.is_empty() and bool(starry_track.get("in_playlist", false)), "《星空下的祈愿》没有自动加入桌面歌单。")
	var bgm := main_scene.get_node_or_null("BGM") as AudioStreamPlayer
	_expect(bgm != null and str(bgm.get_meta("music_track_id", "")) == TRACK_ID, "主场景没有自动播放《星空下的祈愿》。")
	_expect(guide_manager.get_active_guide_id() == GUIDE_ID and guide_manager.get_current_step_id() == "explain_day6_music_player", "没有启动音乐播放器第一步引导。")

	guide_manager._on_overlay_focus_pressed("inspect_day6_music_player")
	_expect(guide_manager.get_current_step_id() == "open_day6_music_playlist", "点击音乐面板没有推进到 CoverBtn 引导。")
	guide_manager._on_overlay_focus_pressed("open_music_playlist")
	await process_frame
	await process_frame
	_expect(guide_manager.get_current_step_id() == "explain_day6_music_playlist", "点击 CoverBtn 没有推进到播放列表引导。")
	_expect(main_scene.is_music_playlist_ready_for_guide(), "CoverBtn 没有实际打开可高亮的播放列表。")
	guide_manager._on_overlay_focus_pressed("inspect_music_playlist")
	_expect(guide_manager.is_guide_completed(GUIDE_ID), "点击播放列表后没有完成音乐后续引导。")

	MusicLibrary.save_tracks(original_tracks)
	game_data_manager.story_time_manager.current_day_offset = original_day_offset
	story_post_event_manager._pending_events_by_timing = original_post_events
	game_data_manager.config.current_main_bg_id = original_background_id
	game_data_manager.config.voice_enabled = original_voice_enabled
	if game_data_manager.profile:
		game_data_manager.profile.current_main_bg_id = original_profile_background_id
	guide_manager._state = original_guide_state
	game_data_manager.set_active_archive_id(original_archive_id, false)
	main_scene.queue_free()
	await process_frame
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("DAY6_MUSIC_FOLLOWUP_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("DAY6_MUSIC_FOLLOWUP_SMOKE: %s" % failure)
	quit(1)
