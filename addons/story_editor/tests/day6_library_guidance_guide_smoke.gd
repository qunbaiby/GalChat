extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var guide_manager = root.get_node_or_null("GuideManager")
	var game_data_manager = root.get_node_or_null("GameDataManager")
	var map_data_manager = root.get_node_or_null("MapDataManager")
	var story_post_event_manager = root.get_node_or_null("StoryPostEventManager")
	_expect(guide_manager != null, "GuideManager 未初始化。")
	_expect(game_data_manager != null and game_data_manager.story_time_manager != null, "剧情时间系统未初始化。")
	_expect(map_data_manager != null, "MapDataManager 未初始化。")
	_expect(story_post_event_manager != null, "StoryPostEventManager 未初始化。")
	if guide_manager == null or game_data_manager == null or game_data_manager.story_time_manager == null or map_data_manager == null or story_post_event_manager == null:
		_finish()
		return

	var original_archive_id := str(game_data_manager.get_active_archive_id())
	if original_archive_id == "":
		game_data_manager.set_active_archive_id("day6_library_guidance_smoke", false)
	var original_guide_state: Dictionary = guide_manager._state.duplicate(true)
	guide_manager.reload_for_current_archive()
	guide_manager._state = guide_manager._normalize_state({})
	var original_unlocked_area_ids: Array = game_data_manager.config.unlocked_area_ids.duplicate()
	var original_unlocked_location_ids: Array = game_data_manager.config.unlocked_location_ids.duplicate()
	game_data_manager.config.unlocked_area_ids = []
	game_data_manager.config.unlocked_location_ids = []
	game_data_manager.story_time_manager.current_day_offset = 4
	_expect(not guide_manager.start_scheduled_guides_if_needed(), "第五剧情日错误启动了周六图书馆引导。")
	_expect(not map_data_manager.is_area_unlocked("qingyu_street") and not map_data_manager.is_area_unlocked("art_academy"), "第六剧情日前错误开放了青屿街或大学。")
	_expect(not map_data_manager.is_location_unlocked("studio") and not map_data_manager.is_location_unlocked("library"), "第六剧情日前错误开放了工作室或图书馆。")
	_expect(not map_data_manager.is_location_unlocked("qingyu_time_cafe"), "未配置解锁条件的咖啡厅被默认开放。")
	game_data_manager.story_time_manager.current_day_offset = 5
	game_data_manager.config.unlocked_area_ids = ["j11_center", "jiangyu_bay"]
	game_data_manager.config.unlocked_location_ids = ["movie_theater", "golden_beach"]
	_expect(map_data_manager.sync_story_progress_unlocks(false), "进入第六剧情日后没有写入永久地图解锁。")
	_expect(map_data_manager.is_area_unlocked("qingyu_street") and map_data_manager.is_area_unlocked("art_academy"), "第六剧情日没有开放青屿街和大学。")
	_expect(not map_data_manager.is_area_unlocked("qinglan_mt") and not map_data_manager.is_area_unlocked("j11_center") and not map_data_manager.is_area_unlocked("jiangyu_bay"), "第六剧情日仍开放了青屿街和大学以外的区域。")
	_expect(not game_data_manager.config.unlocked_area_ids.has("j11_center") and not game_data_manager.config.unlocked_area_ids.has("jiangyu_bay"), "第六剧情日没有清理旧存档中提前解锁的艺术中心或江屿湾。")
	_expect(map_data_manager.is_location_unlocked("studio") and map_data_manager.is_location_unlocked("library"), "第六剧情日没有开放工作室和图书馆。")
	_expect(not map_data_manager.is_location_unlocked("qingyu_time_cafe") and not map_data_manager.is_location_unlocked("yuli_alley") and not map_data_manager.is_location_unlocked("gym") and not map_data_manager.is_location_unlocked("concert_hall"), "第六剧情日仍开放了工作室和图书馆以外的地点。")
	game_data_manager.story_time_manager.current_day_offset = 6
	_expect(map_data_manager.is_area_unlocked("qingyu_street") and map_data_manager.is_area_unlocked("art_academy") and map_data_manager.is_location_unlocked("studio") and map_data_manager.is_location_unlocked("library"), "第六剧情日解锁结果没有永久保留到后续剧情日。")
	game_data_manager.story_time_manager.current_day_offset = 5
	var onboarding_steps: Array = (guide_manager._guide_defs.get("schedule_onboarding_guide", {}) as Dictionary).get("steps", [])
	var rest_transition_step_index := -1
	for step_index in range(onboarding_steps.size()):
		if str((onboarding_steps[step_index] as Dictionary).get("id", "")) == "wait_first_rest_transition_finished":
			rest_transition_step_index = step_index
			break
	_expect(rest_transition_step_index >= 0, "默认引导缺少跨日转场等待步骤。")
	guide_manager._state["active_guide_id"] = "schedule_onboarding_guide"
	guide_manager._state["current_step_index"] = rest_transition_step_index
	_expect(not guide_manager.start_scheduled_guides_if_needed(), "早餐前周六图书馆引导抢占了默认引导。")
	_expect(guide_manager.report_action("first_rest_transition_finished"), "跨日转场完成后没有进入精力引导。")
	_expect(guide_manager.get_current_step_id() == "explain_interaction_energy", "跨日转场完成后没有显示精力引导。")
	_expect(guide_manager.report_action("acknowledge_interaction_energy"), "确认精力引导后没有进入早餐按钮引导。")
	_expect(guide_manager.report_action("open_meal"), "点击早餐按钮没有进入外卖引导。")
	_expect(guide_manager.report_action("select_meal_takeout"), "选择早餐外卖后没有进入结果页引导。")
	_expect(not guide_manager.start_scheduled_guides_if_needed(), "早餐结果页关闭前周六图书馆引导提前启动。")
	_expect(guide_manager.report_action("close_meal_result"), "关闭早餐结果页没有完成默认引导。")
	_expect(guide_manager.get_active_guide_id().is_empty(), "早餐完成后默认引导仍占用活动引导。")
	_expect(guide_manager.start_scheduled_guides_if_needed(), "进入第六剧情日后没有启动周六图书馆引导。")
	_expect(guide_manager.get_current_step_id() == "open_map_for_saturday_guidance", "第一个引导步骤不是外出按钮。")

	_expect(guide_manager.report_action("open_map"), "点击外出没有推进引导。")
	_expect(guide_manager.get_current_step_id() == "select_art_academy_for_guidance", "外出后没有进入大学区域引导。")
	_expect(not guide_manager.report_action("select_map_area", {"area_id": "qingyu_street"}), "点击青屿街错误推进了大学区域引导。")
	_expect(guide_manager.get_current_step_id() == "select_art_academy_for_guidance", "错误区域点击改变了当前步骤。")
	_expect(guide_manager.report_action("select_map_area", {"area_id": "art_academy"}), "点击江屿现代艺术大学没有推进引导。")
	_expect(guide_manager.get_current_step_id() == "select_library_for_guidance", "选择大学后没有进入图书馆引导。")

	_expect(not guide_manager.report_action("select_map_location", {"location_id": "gym"}), "点击体育馆错误推进了图书馆引导。")
	_expect(guide_manager.report_action("select_map_location", {"location_id": "library"}), "点击图书馆没有推进引导。")
	_expect(guide_manager.get_current_step_id() == "enter_library_guidance_story", "打开图书馆详情后没有进入剧情按钮引导。")
	var location_detail_source := FileAccess.get_file_as_string("res://scripts/ui/map/core/location_detail_panel.gd")
	_expect(location_detail_source.contains("func get_enter_button_focus_entry() -> Dictionary:") and location_detail_source.contains('"corner_radius": 14.0'), "进入剧情按钮引导没有使用按钮圆角焦点。")
	var location_guide_manager_source := FileAccess.get_file_as_string("res://scripts/data/guide_manager.gd")
	_expect(location_guide_manager_source.contains("location_detail_panel.get_enter_button_focus_entry()"), "地点详情引导没有读取进入按钮的结构化圆角焦点。")
	_expect(not guide_manager.report_action("enter_location_detail", {"location_id": "art_gallery"}), "其他地点详情按钮错误完成了图书馆引导。")
	_expect(guide_manager.report_action("enter_location_detail", {"location_id": "library"}), "图书馆进入剧情按钮没有推进引导。")
	_expect(guide_manager.get_current_step_id() == "wait_library_guidance_story_finished", "进入剧情后没有等待专项辅导剧情完成。")
	_expect(bool(guide_manager._get_current_step().get("hide_overlay", false)), "图书馆剧情切换期间没有隐藏等待步骤 Overlay。")
	_expect(not guide_manager.report_story_finished("other_story"), "其他剧情错误推进了图书馆课业指导引导。")
	_expect(guide_manager.report_story_finished("jing_library_guidance"), "专项辅导剧情完成后没有续接课业指导引导。")
	_expect(guide_manager.get_current_step_id() == "open_library_tutoring", "剧情结束后没有进入静的课业指导按钮引导。")
	_expect(guide_manager.report_action("open_library_tutoring"), "点击课业指导按钮没有推进引导。")
	_expect(guide_manager.get_current_step_id() == "select_library_tutoring_courses", "打开课业指导后没有引导左侧课程列表。")
	_expect(not guide_manager.report_action("tutoring_schedule_full", {"count": 4}), "未选满五次时错误推进了课程列表引导。")
	_expect(guide_manager.report_action("tutoring_schedule_full", {"count": 5}), "选满五次后没有推进课程列表引导。")
	_expect(guide_manager.get_current_step_id() == "explain_library_tutoring_details", "选满五次后没有引导右侧详情。")
	_expect(guide_manager.report_action("tutoring_click_details"), "点击右侧详情没有推进引导。")
	_expect(guide_manager.get_current_step_id() == "start_library_tutoring", "查看详情后没有引导开始指导按钮。")
	_expect(guide_manager.report_action("tutoring_start"), "点击开始指导没有完成图书馆引导。")
	_expect(guide_manager.is_guide_completed("day6_library_guidance_guide"), "周六图书馆引导没有记录完成状态。")
	_expect(not map_data_manager.is_location_unlocked("qingyu_time_cafe"), "后续剧情测试前咖啡厅已经开放。")
	story_post_event_manager.register_story_completion("map_unlock_smoke", {
		"post_story_events": [{
			"type": "unlock_location",
			"location_id": "qingyu_time_cafe",
			"timing": "immediate"
		}]
	}, true)
	_expect(map_data_manager.is_location_unlocked("qingyu_time_cafe") and game_data_manager.config.unlocked_location_ids.has("qingyu_time_cafe"), "后续剧情的 unlock_location 事件没有永久解锁地点。")

	var story_text := FileAccess.get_file_as_string("res://assets/data/story/scripts/main/jing_library_guidance.json")
	var story_mentions_music_hall := story_text.contains("音乐馆")
	var story_mentions_invite := story_text.contains("微信") or story_text.contains("发来消息")
	var story_mentions_expectation := story_text.contains("期待")
	var story_mentions_concern := story_text.contains("顾虑") or story_text.contains("担忧") or story_text.contains("紧张")
	_expect(story_mentions_music_hall and story_mentions_invite and story_mentions_expectation and story_mentions_concern, "图书馆剧情没有承接音乐馆、微信邀约和 Luna 的顾虑。")
	var map_text := FileAccess.get_file_as_string("res://assets/data/map/core/map_data.json")
	_expect(map_text.contains('"trigger_script": "res://assets/data/story/scripts/main/jing_library_guidance.json"'), "图书馆入口没有触发专项辅导剧情。")
	_expect(map_text.contains('"id": "jing_library_guidance"') and map_text.contains('"events": ["jing_library_guidance"]'), "图书馆入口事件 ID 与专项辅导剧情不一致。")
	_expect(map_text.contains('"location_icon_path": "res://assets/images/backgrounds/map/icon/location/qingyu_time_cafe.png"'), "青屿街工作室地图节点图标被错误替换。")
	_expect(map_text.contains('"detail_image_path": "res://assets/images/backgrounds/main/default_room_bg.png"'), "青屿街工作室右侧详情页没有使用主场景配图。")
	_expect(map_text.contains('"description": "Luna日常生活与创作的工作室，也是你们共同休息、聊天和安排生活的主场景。"'), "青屿街工作室描述没有介绍主场景用途。")
	var invite_text := FileAccess.get_file_as_string("res://assets/data/mobile/fixed_chats/jing_piano_practice_invite.json")
	_expect(invite_text.contains('"type": "activate_main_chat_topic"') and invite_text.contains('"story_script_path": "res://assets/data/story/scripts/main/jing_piano_practice_followup.json"'), "静的微信邀约没有激活赴约前 AI 主线。")
	_expect(not invite_text.contains('"story_script_path": "res://assets/data/story/scripts/main/jing_library_guidance.json"'), "静的微信邀约错误提前绑定了第六天图书馆剧情。")
	var map_source := FileAccess.get_file_as_string("res://scripts/ui/map/core/world_map_scene.gd")
	_expect(map_source.contains('var initial_area_id := "qingyu_street"'), "世界地图没有默认选择青屿街。")
	_expect(map_source.contains('if location_id == "studio":') and map_source.contains("_on_back_pressed()"), "进入青屿街工作室没有复用返回主场景逻辑。")
	_expect(map_source.contains('report_action("select_map_area", {"area_id": area_id})'), "地图区域点击没有向引导上报 area_id。")
	_expect(map_source.contains("MAP_BACKGROUND_SCALE := Vector2(0.85, 0.85)"), "世界地图背景没有锁定为原尺寸的 85%。")
	_expect(map_source.contains("_play_area_fade_transition(area_id, target_pos)"), "地图区域切换没有使用淡出淡入过渡。")
	_expect(map_source.contains('tween_property(target, "modulate:a", 0.0'), "地图区域切换没有先淡出旧区域。")
	_expect(map_source.contains('$Background.position = target_position'), "地图完全淡出后没有切换到目标区域坐标。")
	_expect(map_source.contains('tween_property(target, "modulate:a", 1.0'), "目标区域就位后没有淡入显示。")
	_expect(map_source.contains("get_area_button_focus_entry") and map_source.contains("get_area_button(area_id), 18.0"), "地图区域引导没有使用圆角高亮。")
	_expect(map_source.contains("get_location_button_focus_entry") and map_source.contains("get_location_button(location_id), 14.0"), "地图地点引导没有使用圆角高亮。")
	_expect(map_source.contains("final_reveal_tween.finished.connect"), "地点引导没有等待按钮完整展开后再计算高亮范围。")
	_expect(map_source.contains("panel.guide_target_ready.connect"), "地点详情没有等待滑入完成后再显示进入剧情按钮引导。")
	var onboarding_guide: Dictionary = guide_manager._guide_defs.get("schedule_onboarding_guide", {})
	var library_guide: Dictionary = guide_manager._guide_defs.get("day6_library_guidance_guide", {})
	_expect(not bool(onboarding_guide.get("show_completion_toast", true)), "日常聊天结束后仍会显示通用新手引导完成提示。")
	_expect(not bool(library_guide.get("show_completion_toast", true)), "进入图书馆剧情后仍会显示通用新手引导完成提示。")
	var library_steps: Array = library_guide.get("steps", [])
	_expect(library_steps.size() == 9, "周六图书馆引导没有包含剧情后的课业指导步骤。")
	var library_step: Dictionary = library_steps[2] if library_steps.size() > 2 and library_steps[2] is Dictionary else {}
	var overlay_options: Dictionary = library_step.get("overlay_options", {})
	_expect(str(library_step.get("target_mode", "")) == "location_by_id" and str(library_step.get("target_id", "")) == "library", "图书馆引导没有以完整地点按钮节点作为目标。")
	_expect(float(library_step.get("highlight_padding", -1.0)) == 0.0, "图书馆地点高亮仍额外扩大或缩小节点范围。")
	_expect(str(overlay_options.get("panel_placement", "")) == "below", "图书馆地点引导提示框没有配置在高亮节点下方。")
	var tutoring_button_step: Dictionary = library_steps[5] if library_steps.size() > 5 else {}
	var tutoring_courses_step: Dictionary = library_steps[6] if library_steps.size() > 6 else {}
	var tutoring_detail_step: Dictionary = library_steps[7] if library_steps.size() > 7 else {}
	var tutoring_start_step: Dictionary = library_steps[8] if library_steps.size() > 8 else {}
	_expect(str(tutoring_button_step.get("target_id", "")) == "study" and str(tutoring_button_step.get("text", "")).contains("额外指导"), "剧情后没有高亮静的课业指导按钮或文案不完整。")
	_expect(bool((tutoring_button_step.get("overlay_options", {}) as Dictionary).get("capture_focus_clicks", false)) and str((tutoring_button_step.get("overlay_options", {}) as Dictionary).get("focus_wait_action", "")) == "open_library_tutoring", "课业指导入口没有稳定捕获高亮点击。")
	_expect(str(tutoring_courses_step.get("target_mode", "")) == "course_list" and str(tutoring_courses_step.get("text", "")).contains("最多安排五次指导"), "课程列表引导目标或文案不正确。")
	_expect(str(tutoring_detail_step.get("target_mode", "")) == "detail_panel" and str(tutoring_detail_step.get("text", "")).contains("属性变化"), "右侧详情引导目标或文案不正确。")
	_expect(float(tutoring_courses_step.get("highlight_padding", -1.0)) == 0.0 and str((tutoring_courses_step.get("overlay_options", {}) as Dictionary).get("panel_placement", "")) == "left", "课程列表高亮边界或提示框位置不正确。")
	_expect(float(tutoring_detail_step.get("highlight_padding", -1.0)) == 0.0 and str((tutoring_detail_step.get("overlay_options", {}) as Dictionary).get("panel_placement", "")) == "left", "右侧详情高亮边界或提示框位置不正确。")
	_expect(bool((tutoring_detail_step.get("overlay_options", {}) as Dictionary).get("capture_focus_clicks", false)) and str((tutoring_detail_step.get("overlay_options", {}) as Dictionary).get("focus_wait_action", "")) == "tutoring_click_details", "右侧详情高亮没有稳定捕获整块区域点击。")
	_expect(str(tutoring_start_step.get("target_mode", "")) == "start_button" and str(tutoring_start_step.get("text", "")).contains("点击开始指导"), "开始指导按钮目标或文案不正确。")
	_expect(bool((tutoring_start_step.get("overlay_options", {}) as Dictionary).get("capture_focus_clicks", false)) and str((tutoring_start_step.get("overlay_options", {}) as Dictionary).get("focus_wait_action", "")) == "tutoring_start", "开始指导按钮没有稳定捕获高亮点击。")
	var enter_story_step: Dictionary = library_steps[3] if library_steps.size() > 3 else {}
	var enter_story_overlay_options: Dictionary = enter_story_step.get("overlay_options", {})
	_expect(str(enter_story_overlay_options.get("panel_placement", "")) == "left", "进入剧情按钮的引导提示框没有避让到地点详情左侧。")
	var main_source := FileAccess.get_file_as_string("res://scripts/ui/main/main_scene.gd")
	_expect(main_source.contains("start_scheduled_guides_if_needed"), "休息跨日后没有尝试启动时间数据声明的引导。")
	var story_time_text := FileAccess.get_file_as_string("res://assets/data/story/story_time.json")
	_expect(story_time_text.contains('"start_guide_id": "day6_library_guidance_guide"'), "第六剧情日时间事件没有声明图书馆引导。")
	var guide_manager_source := FileAccess.get_file_as_string("res://scripts/data/guide_manager.gd")
	_expect(guide_manager_source.contains("GUIDE_OVERLAY_LAYER := 200") and guide_manager_source.contains("_overlay_layer.add_child(_overlay)"), "引导层没有提升到地点详情和课业菜单之上。")
	var original_current_scene: Node = current_scene
	var quick_location_host := Node.new()
	quick_location_host.name = "QuickLocationGuideHost"
	root.add_child(quick_location_host)
	current_scene = quick_location_host
	var tutoring_overlay := CanvasLayer.new()
	tutoring_overlay.name = "TutoringGuideOverlay"
	root.add_child(tutoring_overlay)
	guide_manager._quick_location_scene_ref = weakref(quick_location_host)
	guide_manager._tutoring_panel_ref = weakref(tutoring_overlay)
	_expect(guide_manager._is_tutoring_panel_in_active_context(), "根级课业指导覆盖层没有被识别为当前静互动页的一部分。")
	var inactive_scene := Node.new()
	inactive_scene.name = "InactiveGuideHost"
	root.add_child(inactive_scene)
	current_scene = inactive_scene
	_expect(not guide_manager._is_tutoring_panel_in_active_context(), "离开静互动页后仍错误识别课业指导覆盖层。")
	current_scene = original_current_scene
	tutoring_overlay.queue_free()
	quick_location_host.queue_free()
	inactive_scene.queue_free()
	var world_map_source := FileAccess.get_file_as_string("res://scripts/ui/map/core/world_map_scene.gd")
	_expect(world_map_source.contains("_guide_targets_ready = false") and world_map_source.contains("_guide_targets_ready = true"), "地图切区期间没有暂停引导并等待地点完整显示。")
	var quick_location_source := FileAccess.get_file_as_string("res://scripts/ui/map/core/quick_location_scene.gd")
	_expect(quick_location_source.contains("tween.finished.connect(_refresh_quick_location_guide_target"), "静互动页没有等待按钮动画完成再显示课业指导引导。")
	_expect(quick_location_source.contains("func get_action_button_focus_entry(action_id: String) -> Dictionary:") and quick_location_source.contains('"corner_radius": 16.0'), "课业指导入口按钮没有使用圆角高亮。")
	game_data_manager.config.unlocked_area_ids = original_unlocked_area_ids
	game_data_manager.config.unlocked_location_ids = original_unlocked_location_ids
	game_data_manager.config.save_config()
	guide_manager._state = original_guide_state
	game_data_manager.set_active_archive_id(original_archive_id, false)
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("DAY6_LIBRARY_GUIDANCE_GUIDE_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("DAY6_LIBRARY_GUIDANCE_GUIDE_SMOKE: %s" % failure)
	quit(1)