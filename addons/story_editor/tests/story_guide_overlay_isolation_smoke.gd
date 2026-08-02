extends SceneTree

class MockMainScene:
	extends Node
	var target_available: bool = true

	func is_main_ui_ready_for_guide() -> bool:
		return true

	func get_main_action_focus_entry() -> Dictionary:
		if not target_available:
			return {}
		return {
			"rect": Rect2(100.0, 100.0, 120.0, 48.0),
			"shape": "trapezoid_left",
			"shape_params": {"cutout_slant": 0.35},
			"cutout_polygon": PackedVector2Array([
				Vector2(116.8, 100.0),
				Vector2(220.0, 100.0),
				Vector2(220.0, 148.0),
				Vector2(100.0, 148.0)
			])
		}

	func get_rest_button_focus_entry() -> Dictionary:
		return get_main_action_focus_entry()

	func is_rest_button_ready_for_guide() -> bool:
		return target_available

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var overlay_source := FileAccess.get_file_as_string("res://scripts/ui/guide/guide_overlay.gd")
	var overlay_scene_source := FileAccess.get_file_as_string("res://scenes/ui/guide/guide_overlay.tscn")
	var main_scene_source := FileAccess.get_file_as_string("res://scripts/ui/main/main_scene.gd")
	var top_status_source := FileAccess.get_file_as_string("res://scripts/ui/main/top_status_panel.gd")
	var energy_guide_manager_source := FileAccess.get_file_as_string("res://scripts/data/guide_manager.gd")
	_expect(top_status_source.contains("func get_energy_guide_focus_target() -> Control:") and top_status_source.contains("return energy_bg_panel"), "精力引导目标没有指向 EnergySlot/BgPanel。")
	_expect(main_scene_source.contains("_build_rounded_focus_entry(energy_target as Control, 8.0)"), "精力 BgPanel 引导没有使用匹配面板的 8px 圆角。")
	_expect(main_scene_source.contains("dialogue_panel.get_node_or_null(\"FreeChatInfoLayer\")") and main_scene_source.contains("return _build_rounded_focus_entry(round_info, 20.0)"), "AI 主线回合引导高亮没有根据当前回合面板实时矩形生成。")
	_expect(energy_guide_manager_source.contains('"main.energy": "UIPanel/TopStatusPanel/MarginContainer/HBoxContainer/EnergySlot/BgPanel"'), "main.energy 仍然映射到整个 EnergySlot。")
	_expect(energy_guide_manager_source.contains('highlight_feature == "main.top_status" or highlight_feature == "main.energy"'), "main.energy 实际步骤没有调用 BgPanel 圆角焦点接口。")
	_expect(overlay_scene_source.contains("[node name=\"GuidePanel\"") and overlay_scene_source.contains("modulate = Color(1, 1, 1, 0)"), "GuidePanel 场景资源没有默认保持透明隐藏。")
	_expect(overlay_scene_source.contains("z_index = 50"), "GuidePanel 场景资源没有声明高于呼吸高亮的稳定层级。")
	_expect(overlay_source.contains("const FOCUS_FILL_COLOR := Color(0.30, 1.0, 0.84, 0.0)"), "引导呼吸高亮内部仍有青绿色填充。")
	_expect(not overlay_source.contains("style.shadow_size") and overlay_source.contains("style.border_width_left = 2"), "引导呼吸高亮没有使用透明中心的细光带。")
	_expect(overlay_source.contains("style.draw_center = false") and overlay_source.contains("style.anti_aliasing_size = 3.0"), "引导呼吸高亮缺少透明中心或柔化羽边。")
	_expect(overlay_source.contains("FOCUS_GLOW_MIN_EXPANSION := 1.5") and overlay_source.contains("FOCUS_GLOW_MAX_EXPANSION := 5.5"), "引导呼吸高亮没有使用缩小后的四向等距外扩。")
	_expect(overlay_source.contains("MESSAGE_REVEAL_DELAY := 0.2") and overlay_source.contains("MESSAGE_REVEAL_DURATION := 0.5"), "引导文本框没有统一使用 0.2 秒延迟和 0.5 秒淡入。")
	_expect(not overlay_source.contains("_reveal_message_panel_when_focus_stable") and not overlay_source.contains("focus_already_stable\", false"), "引导文本框仍混有第二套稳定等待或立即显示逻辑。")
	_expect(overlay_source.contains("_panel_root.z_index = 50"), "引导文本框没有绘制在呼吸高亮、点击捕获层和点击手势上方。")
	_expect(not overlay_source.contains("return minf(base_width, side_width)"), "引导文本框仍会被高亮侧边空隙压窄到超过三行。")
	_expect(overlay_source.contains("lerpf(3.0, 7.0, _focus_pulse)") and overlay_source.contains("frame_color, 1.0, true"), "梯形引导高亮没有同步使用细边框和缩小后的柔光。")
	_expect(overlay_source.contains("focus_rect.position - Vector2.ONE * expansion") and overlay_source.contains("focus_rect.size + Vector2.ONE * expansion * 2.0"), "引导呼吸高亮的上下与左右没有同步外扩。")
	var guide_manager = root.get_node_or_null("GuideManager")
	_expect(guide_manager != null, "GuideManager 未初始化。")
	if guide_manager == null:
		_finish()
		return
	var game_data_manager = root.get_node("GameDataManager")
	var original_archive_id: String = str(game_data_manager.get_active_archive_id())
	var test_archive_id := "guide_overlay_isolation_smoke"
	game_data_manager.set_active_archive_id(test_archive_id, false)
	game_data_manager.clear_archive_custom_config(test_archive_id)
	guide_manager.reload_for_current_archive()
	var schedule_guide: Dictionary = guide_manager._guide_defs.get("schedule_onboarding_guide", {})
	var schedule_steps: Array = schedule_guide.get("steps", [])
	var schedule_step_by_id := {}
	for step_value in schedule_steps:
		if step_value is Dictionary:
			schedule_step_by_id[str(step_value.get("id", ""))] = step_value
	var category_intro: Dictionary = schedule_step_by_id.get("explain_schedule_tabs", {})
	_expect(str(category_intro.get("wait_action", "")) == "activity_acknowledge_categories", "课程分类介绍仍会触发真实 Tab 切换。")
	_expect(bool((category_intro.get("overlay_options", {}) as Dictionary).get("capture_focus_clicks", false)), "课程分类介绍没有由遮罩捕获高亮点击。")
	var expected_categories := ["physical_health", "creation_design", "music_dance_performance", "social_etiquette"]
	for category_index in expected_categories.size():
		var step_id := "select_schedule_category_%d" % (category_index + 1)
		var category_step: Dictionary = schedule_step_by_id.get(step_id, {})
		_expect(str(category_step.get("guide_category_id", "")) == expected_categories[category_index], "第 %d 次选课没有锁定到预期学科。" % (category_index + 1))
		_expect(str(category_step.get("wait_action", "")) == "activity_add_course", "第 %d 次选课没有等待课程添加。" % (category_index + 1))
		if category_index > 0:
			_expect(bool((category_step.get("overlay_options", {}) as Dictionary).get("hide_message_panel", false)), "第 %d 次选课仍显示了多余提示文本。" % (category_index + 1))
	var schedule_confirmation: Dictionary = schedule_step_by_id.get("confirm_schedule_courses", {})
	_expect(str(schedule_confirmation.get("wait_action", "")) == "activity_confirm_schedule_courses", "四门课程排满后没有独立确认步骤。")
	_expect(str(schedule_confirmation.get("text", "")).contains("{player_title}"), "四门课程确认文案没有使用玩家称呼占位符。")
	_expect(not str(guide_manager._format_guide_text(str(schedule_confirmation.get("text", "")))).contains("{player_title}"), "四门课程确认文案没有在运行时替换玩家称呼。")
	var open_schedule_step: Dictionary = schedule_step_by_id.get("open_schedule_panel", {})
	_expect(guide_manager._is_step_focus_interaction_allowed(open_schedule_step), "主场景行程安排按钮步骤没有启用点击手势。")
	var open_meal_step: Dictionary = schedule_step_by_id.get("open_first_meal", {})
	_expect(guide_manager._is_step_focus_interaction_allowed(open_meal_step), "早餐按钮高亮没有放行真实按钮点击。")
	var original_restart_state: Dictionary = guide_manager._state.duplicate(true)
	guide_manager._state["active_guide_id"] = "schedule_onboarding_guide"
	guide_manager._state["current_step_index"] = 6
	_expect(guide_manager._restart_incomplete_schedule_after_reload(), "读档时没有重启未完成的排课引导。")
	_expect(guide_manager.get_current_step_id() == "open_schedule_panel", "读档后未完成排课没有回到行程安排入口。")
	var execution_step_index := -1
	for step_index in range(schedule_steps.size()):
		if str((schedule_steps[step_index] as Dictionary).get("id", "")) == "explain_execution_info_panel":
			execution_step_index = step_index
			break
	guide_manager._state["current_step_index"] = execution_step_index
	_expect(not guide_manager._restart_incomplete_schedule_after_reload(), "进入课程执行后仍错误重启了排课引导。")
	_expect(guide_manager.get_current_step_id() == "explain_execution_info_panel", "课程执行阶段的读档断点被错误修改。")
	guide_manager._state = original_restart_state
	var fixed_options_step: Dictionary = schedule_step_by_id.get("explain_wechat_fixed_options", {})
	_expect(str(fixed_options_step.get("text", "")).contains("直接发送"), "固定回复引导没有说明点击选项会直接发送。")
	var fixed_conversation_step: Dictionary = schedule_step_by_id.get("explain_wechat_fixed_conversation", {})
	_expect(not bool(fixed_conversation_step.get("hide_overlay", false)), "固定回复发送后的连续对话引导仍被隐藏。")
	_expect(str(fixed_conversation_step.get("target_mode", "")) == "fixed_conversation", "固定回复发送后没有高亮右侧连续对话区域。")
	_expect(not bool((fixed_conversation_step.get("overlay_options", {}) as Dictionary).get("show_click_pointer", true)), "连续对话引导仍然显示点击手势。")
	_expect((fixed_conversation_step.get("allowed_interactions", []) as Array).has("wechat.fixed_option"), "连续对话引导没有放行后续固定玩家选项。")
	var activity_panel_source := FileAccess.get_file_as_string("res://scripts/ui/activity/activity_panel.gd")
	_expect(activity_panel_source.contains("func get_activity_items_focus_data() -> Array:"), "课程引导没有为所有课程卡提供独立高亮数据。")
	_expect(activity_panel_source.contains("var rect := _get_control_focus_rect(item)"), "课程卡高亮没有使用活动面板统一的坐标转换。")
	_expect(activity_panel_source.contains("await get_tree().process_frame\n\tawait get_tree().process_frame\n\tvar guide_manager := _get_guide_manager()"), "课程分类切换后没有等待网格完成布局再刷新高亮。")
	_expect(activity_panel_source.contains("guide_manager.show_schedule_slot_added_focus(i)"), "选择课程后没有请求对应槽位的引导挖孔高亮。")
	var guide_manager_source := FileAccess.get_file_as_string("res://scripts/data/guide_manager.gd")
	_expect(guide_manager_source.contains("raw_result = activity_panel.get_activity_items_focus_data()"), "课程列表引导仍未使用全部课程卡高亮。")
	_expect(guide_manager_source.contains("func _deferred_handle_main_scene_guide_ready(just_finished_intro_story: bool, expected_archive_id: String) -> void:\n\tawait get_tree().process_frame\n\tawait get_tree().process_frame"), "主场景引导没有等待按钮布局稳定或缺少档案身份快照。")
	_expect(guide_manager_source.contains("func _retry_main_focus_until_ready(retry_token: int) -> void:"), "主场景按钮目标短暂失效时没有持续重试引导手。")
	var guide_overlay_source := FileAccess.get_file_as_string("res://scripts/ui/guide/guide_overlay.gd")
	_expect(guide_overlay_source.contains("text_size.y <= MESSAGE_BODY_HEIGHT") and guide_overlay_source.contains("message_width = minf(message_max_width, message_width + 20.0)"), "引导文本框没有优先使用三行，或未在超过三行后才扩宽。")
	await _verify_activity_item_focus_layout()
	var mobile_chat_source := FileAccess.get_file_as_string("res://scripts/ui/mobile/chat/mobile_chat_panel.gd")
	_expect(mobile_chat_source.contains("input_row.hide()"), "固定对话没有隐藏输入框和发送按钮所在区域。")
	_expect(mobile_chat_source.contains("MobileFixedChatManager.submit_player_option(script_id, option_id, text)"), "固定选项点击后没有直接提交玩家回复。")
	_expect(not mobile_chat_source.contains("_pending_fixed_option_id"), "固定回复仍依赖输入框发送按钮的待发送状态。")
	var approved_luna_name_steps := [
		"select_first_meal_takeout",
		"open_first_daily_chat",
		"choose_first_daily_chat_topic",
		"explain_daily_chat_end_button",
		"explain_guided_ai_quick_options",
		"explain_guided_ai_input_field",
		"explain_guided_ai_send_button",
		"explain_guided_ai_voice_button",
		"finish_guided_ai_input_guide"
	]
	for guide_id_value in guide_manager._guide_defs.keys():
		var guide_id := str(guide_id_value)
		var guide_data: Dictionary = guide_manager._guide_defs.get(guide_id, {})
		var guide_uses_player_title := false
		for guide_step_value in (guide_data.get("steps", []) as Array):
			if not (guide_step_value is Dictionary):
				continue
			var guide_step := guide_step_value as Dictionary
			var guide_text := str(guide_step.get("text", ""))
			var scene_hint := str(guide_step.get("scene_hint", ""))
			var guide_step_id := str(guide_step.get("id", ""))
			_expect(not guide_text.contains("Luna") or approved_luna_name_steps.has(guide_step_id), "%s / %s 仍以第三人称称呼 Luna。" % [guide_id, guide_step_id])
			_expect(not guide_text.contains("引导系统") and not guide_text.contains("演示引导"), "%s / %s 仍使用后台说明口吻。" % [guide_id, str(guide_step.get("id", ""))])
			_expect(not scene_hint.contains("演示引导"), "%s / %s 的场景提示仍使用后台说明口吻。" % [guide_id, str(guide_step.get("id", ""))])
			if guide_text.contains("{player_title}") or scene_hint.contains("{player_title}"):
				guide_uses_player_title = true
		_expect(guide_uses_player_title, "%s 没有在合适步骤中使用玩家称呼。" % guide_id)

	await process_frame
	await process_frame
	var overlay: Control = guide_manager._overlay
	_expect(is_instance_valid(overlay), "引导遮罩未初始化。")
	if not is_instance_valid(overlay):
		_finish()
		return

	var original_state: Dictionary = guide_manager._state.duplicate(true)
	var original_main_scene_ref: WeakRef = guide_manager._main_scene_ref
	var original_activity_panel_ref: WeakRef = guide_manager._activity_panel_ref
	var original_current_scene: Node = current_scene
	var rest_prompt_step_index := -1
	for step_index in range(schedule_steps.size()):
		if str((schedule_steps[step_index] as Dictionary).get("id", "")) == "prompt_start_companion_journey":
			rest_prompt_step_index = step_index
			break
	_expect(rest_prompt_step_index >= 0, "没有找到首次休息提示步骤。")
	if rest_prompt_step_index >= 0:
		var stale_main_scene := MockMainScene.new()
		root.add_child(stale_main_scene)
		guide_manager._state["active_guide_id"] = "schedule_onboarding_guide"
		guide_manager._state["current_step_index"] = rest_prompt_step_index
		guide_manager._main_scene_ref = weakref(stale_main_scene)
		guide_manager.refresh_current_step_display()
		await process_frame
		await process_frame
		_expect(not overlay.visible, "旧主场景仍存活但不是 current_scene 时，引导错误显示在标题界面。")
		stale_main_scene.queue_free()
	var mock_main_scene := MockMainScene.new()
	root.add_child(mock_main_scene)
	current_scene = mock_main_scene
	guide_manager._state["active_guide_id"] = "schedule_onboarding_guide"
	guide_manager._state["current_step_index"] = 1
	guide_manager._main_scene_ref = weakref(mock_main_scene)
	guide_manager._activity_panel_ref = null
	guide_manager.refresh_current_step_display()
	_expect(overlay.visible, "读档恢复到未打开的行程界面步骤时，引导没有显示继续入口。")
	_expect(int(guide_manager._state.get("current_step_index", -1)) == 1, "显示继续入口时错误推进了引导断点。")
	_expect(bool(overlay._panel_root.mouse_filter == Control.MOUSE_FILTER_IGNORE), "继续入口遮罩拦截了行程安排按钮。")
	_expect(overlay._focus_rects == [Rect2(100.0, 100.0, 120.0, 48.0)], "继续入口高亮范围没有沿用主界面按钮轮廓。")
	_expect(str(overlay._focus_entries[0].get("shape", "")) == "trapezoid_left", "继续入口丢失了主行动按钮的梯形高亮形状。")
	_expect((overlay._focus_entries[0].get("cutout_polygon", PackedVector2Array()) as PackedVector2Array).size() == 4, "继续入口丢失了主行动按钮的梯形挖孔轮廓。")
	await process_frame
	var avatar := overlay.get_node_or_null("GuidePanel/GuideRow/AvatarFrame/AvatarMargin/LunaAvatar") as TextureRect
	_expect(avatar != null and avatar.texture != null, "引导提示框没有显示 Luna 头像。")
	var avatar_frame := overlay.get_node("GuidePanel/GuideRow/AvatarFrame") as PanelContainer
	var avatar_margin := overlay.get_node("GuidePanel/GuideRow/AvatarFrame/AvatarMargin") as MarginContainer
	var message_panel := overlay.get_node("GuidePanel/GuideRow/MessagePanel") as PanelContainer
	_expect(overlay._panel_root.z_index > overlay._focus_auras[0].z_index and overlay._panel_root.z_index > overlay._focus_glows[0].z_index and overlay._panel_root.z_index > overlay._focus_frames[0].z_index, "引导文本框运行时层级没有位于全部呼吸高亮之上：panel=%d aura=%d glow=%d frame=%d。" % [overlay._panel_root.z_index, overlay._focus_auras[0].z_index, overlay._focus_glows[0].z_index, overlay._focus_frames[0].z_index])
	_expect(avatar_frame.z_index > message_panel.z_index, "Luna 头像框没有绘制在文本框上方。")
	_expect(avatar_margin.get_theme_constant("margin_left") <= 4, "Luna 头像与头像框之间仍有过大留白。")
	_expect(is_equal_approx(overlay._panel_root.size.y, avatar_frame.custom_minimum_size.y), "引导提示框总高度没有适配头像框场景尺寸。")
	_expect(is_equal_approx(avatar_frame.size.x, avatar_frame.size.y), "Luna 头像框被父布局拉伸变形。")
	_expect(message_panel.size.y <= avatar_frame.size.y, "引导文本框高度超过了头像框。")
	_expect(is_equal_approx(overlay._body_label.custom_minimum_size.y, 66.0), "引导正文没有固定为三行文本高度。")
	_expect(overlay._click_pointer.visible, "可点击高亮步骤没有显示点击手势。")
	var pointer_hotspot: Vector2 = overlay._click_pointer.position + overlay.POINTER_HOTSPOT
	_expect(pointer_hotspot.distance_to(Rect2(100.0, 100.0, 120.0, 48.0).get_center()) < 1.0, "点击手势指尖没有对准高亮区域中心。")
	_expect(overlay.HAND_BASE_SCALE > 1.0, "点击手势没有使用放大后的基准尺寸。")
	_expect(overlay._hand_texture.position.distance_to(overlay._hand_base_position + Vector2(15.0, 3.0)) < 0.1, "手势没有应用运行时位置偏移。")
	_expect((overlay._hand_texture.position + overlay._hand_texture.pivot_offset).distance_to(overlay.POINTER_HOTSPOT) < 0.1, "手势缩放枢轴没有锁定在 ClickRing 中心。")
	mock_main_scene.target_available = false
	guide_manager.refresh_current_step_display()
	await process_frame
	mock_main_scene.target_available = true
	guide_manager.refresh_current_step_display()
	await process_frame
	_expect(overlay._click_pointer.visible, "主行动按钮布局恢复后引导手没有重新显示。")
	overlay.show_step("测试引导", "矩形目标", "点击高亮区域继续。", 1, 1, Rect2(300.0, 200.0, 160.0, 64.0), true, {})
	_expect(not overlay._panel_root.visible, "引导文本框在高亮稳定前提前显示。")
	await process_frame
	_expect(not overlay._focus_frames.is_empty() and overlay._focus_frames[0].visible, "矩形目标没有显示绿色高亮边框。")
	_expect(not overlay._focus_glows.is_empty() and overlay._focus_glows[0].visible, "矩形目标没有显示绿色外发光。")
	_expect(not overlay._focus_auras.is_empty() and overlay._focus_auras[0].visible, "矩形目标没有显示外层柔光 Aura。")
	var frame_style := overlay._focus_frames[0].get_theme_stylebox("panel") as StyleBoxFlat
	var glow_style := overlay._focus_glows[0].get_theme_stylebox("panel") as StyleBoxFlat
	_expect(frame_style.border_width_left == 1 and glow_style.border_width_left == 2, "引导高亮边框没有缩减到原来的一半。")
	_expect(not frame_style.draw_center and not glow_style.draw_center, "引导高亮边框仍在向内部填色。")
	await create_timer(0.15).timeout
	_expect(not overlay._panel_root.visible, "引导文本框没有在高亮出现后等待 0.2 秒。")
	await create_timer(0.1).timeout
	_expect(overlay._panel_root.visible, "引导文本框在高亮出现 0.2 秒后仍未开始淡入。")
	_expect(overlay._panel_root.modulate.a < 1.0, "引导文本框没有使用 0.5 秒淡入动画。")
	await create_timer(0.5).timeout
	_expect(is_equal_approx(overlay._panel_root.modulate.a, 1.0), "引导文本框在 0.5 秒淡入结束后仍未完全显示。")
	var stable_reveal_token: int = overlay._message_reveal_token
	overlay.show_step("测试引导", "矩形目标", "点击高亮区域继续。", 1, 1, Rect2(300.0, 200.0, 160.0, 64.0), true, {})
	_expect(overlay._message_reveal_token == stable_reveal_token, "同一步骤重复刷新错误重启了文本框淡入。")
	_expect(overlay._panel_root.visible, "同一步骤重复刷新导致已显示文本框再次隐藏闪烁。")
	overlay.show_step("测试引导", "长文本目标", "Luna现在还不会做饭，只能委屈哥哥跟我一起吃外卖了，等以后我学会了做饭，就能给哥哥做饭吃了。", 1, 1, Rect2(447.0, 247.0, 388.0, 52.0), true, {})
	await process_frame
	await process_frame
	_expect(overlay._panel_root.size.x > 500.0, "长引导文本没有向左右扩展文本框宽度。")
	_expect(overlay._body_label.get_content_height() <= 66.0, "长引导文本自适应宽度后仍超过三行。")
	var initial_glow_position: Vector2 = overlay._focus_glows[0].position
	var initial_glow_size: Vector2 = overlay._focus_glows[0].size
	await create_timer(0.4).timeout
	var glow_position_delta: Vector2 = initial_glow_position - overlay._focus_glows[0].position
	var glow_size_delta: Vector2 = overlay._focus_glows[0].size - initial_glow_size
	_expect(glow_position_delta.length() > 0.001 and glow_size_delta.length() > 0.001, "绿色高亮没有播放四向外扩呼吸动画。")
	_expect(absf(glow_position_delta.x - glow_position_delta.y) < 0.1, "绿色高亮的上下与左右外扩距离不一致。")
	_expect(absf(glow_size_delta.x - glow_size_delta.y) < 0.1, "绿色高亮的上下与左右尺寸增量不一致。")
	overlay.hide_overlay()
	guide_manager._active_presentation_key = ""
	guide_manager._pending_presentation_key = ""
	guide_manager._state["current_step_index"] = 0
	guide_manager.refresh_current_step_display()
	await _wait_for_manager_presentation(guide_manager, "schedule_onboarding_guide:0")
	var manager_reveal_token: int = overlay._message_reveal_token
	await create_timer(0.75).timeout
	_expect(overlay._panel_root.visible and is_equal_approx(overlay._panel_root.modulate.a, 1.0), "GuideManager 文本框没有完成统一的 0.2 秒延迟加 0.5 秒淡入。")
	var manager_panel_alpha: float = overlay._panel_root.modulate.a
	for _refresh_index in range(6):
		guide_manager.refresh_current_step_display()
		await process_frame
		_expect(overlay.visible and overlay._panel_root.visible, "GuideManager 同一步骤连续刷新导致 Overlay 闪烁。")
		_expect(overlay._message_reveal_token == manager_reveal_token, "GuideManager 同一步骤连续刷新重启了文本淡入。")
		_expect(overlay._panel_root.modulate.a >= manager_panel_alpha - 0.01, "GuideManager 同一步骤连续刷新重置了文本透明度。")
	_expect(rest_prompt_step_index >= 0, "没有找到首次休息提示步骤。")
	if rest_prompt_step_index >= 0:
		overlay.hide_overlay()
		guide_manager._active_presentation_key = ""
		guide_manager._pending_presentation_key = ""
		guide_manager._state["current_step_index"] = rest_prompt_step_index
		guide_manager.report_action("acknowledge_first_rest_prompt")
		await _wait_for_manager_presentation(guide_manager, "schedule_onboarding_guide:%d" % (rest_prompt_step_index + 1))
		_expect(guide_manager.get_current_step_id() == "open_first_rest_confirmation", "点击休息提示后没有推进到休息按钮高亮。")
		_expect(overlay.visible and not overlay._focus_entries.is_empty(), "休息按钮步骤没有呈现焦点 Overlay。")
	var visible_dim_count_before_transition: int = int(overlay._dim_segments.filter(func(dim_rect: ColorRect) -> bool: return dim_rect.visible).size())
	overlay.begin_step_transition()
	for _transition_frame in range(3):
		await process_frame
		_expect(overlay.visible, "点击高亮推进到下一步骤时全屏 Overlay 短暂消失。")
		_expect(overlay._dim_segments.filter(func(dim_rect: ColorRect) -> bool: return dim_rect.visible).size() == visible_dim_count_before_transition, "点击高亮推进时全屏遮罩出现闪烁。")
		_expect(not overlay._click_pointer.visible, "步骤交接期间旧点击手势仍可见。")
		_expect(overlay._focus_capture_overlays.all(func(capture: ColorRect) -> bool: return not capture.visible), "步骤交接期间旧高亮仍可重复点击。")
	overlay.show_step("测试引导", "新点击目标", "点击新目标继续。", 1, 1, Rect2(300.0, 200.0, 160.0, 64.0), true, {
		"capture_focus_clicks": true,
		"focus_wait_action": "test_next_focus"
	})
	_expect(overlay._input_blocker.visible and overlay._input_blocker.mouse_filter == Control.MOUSE_FILTER_STOP, "捕获高亮点击时场景 InputBlocker 没有阻断底层控件的鼠标输入。")
	_expect(overlay._focus_capture_overlays.any(func(capture: ColorRect) -> bool: return capture.visible), "新步骤呈现后焦点点击层没有恢复显示。")
	_expect(overlay._focus_capture_overlays.filter(func(capture: ColorRect) -> bool: return capture.visible).all(func(capture: ColorRect) -> bool: return capture.mouse_filter == Control.MOUSE_FILTER_IGNORE), "捕获型步骤仍由动态透明子节点竞争鼠标命中。")
	_expect(overlay._dim_segments.all(func(dim_rect: ColorRect) -> bool: return dim_rect.mouse_filter == Control.MOUSE_FILTER_IGNORE), "捕获型步骤的 dim 片段仍在抢占根 Overlay 输入。")
	var captured_focus_actions: Array[String] = []
	var capture_action := func(action_id: String) -> void: captured_focus_actions.append(action_id)
	overlay.focus_pressed.connect(capture_action)
	var visible_capture: ColorRect = overlay._focus_capture_overlays.filter(func(capture: ColorRect) -> bool: return capture.visible)[0]
	var focus_press := InputEventMouseButton.new()
	focus_press.button_index = MOUSE_BUTTON_LEFT
	focus_press.pressed = true
	visible_capture.gui_input.emit(focus_press)
	await process_frame
	_expect(captured_focus_actions == ["test_next_focus"], "高亮区域没有在鼠标按下时立即提交一次引导动作。")
	var focus_release := InputEventMouseButton.new()
	focus_release.button_index = MOUSE_BUTTON_LEFT
	focus_release.pressed = false
	visible_capture.gui_input.emit(focus_release)
	await process_frame
	_expect(captured_focus_actions == ["test_next_focus"], "高亮区域在鼠标释放时重复提交了引导动作。")
	captured_focus_actions.clear()
	var underlying_button := Button.new()
	underlying_button.position = Vector2(300.0, 200.0)
	underlying_button.size = Vector2(160.0, 64.0)
	root.add_child(underlying_button)
	var underlying_button_down_count := 0
	var underlying_button_up_count := 0
	underlying_button.button_down.connect(func() -> void: underlying_button_down_count += 1)
	underlying_button.button_up.connect(func() -> void: underlying_button_up_count += 1)
	await process_frame
	_expect(overlay._input_blocker.get_global_rect().has_point(Vector2(320.0, 220.0)), "场景 InputBlocker 的实际矩形没有覆盖高亮点击坐标。")
	var viewport_press := InputEventMouseButton.new()
	viewport_press.button_index = MOUSE_BUTTON_LEFT
	viewport_press.pressed = true
	viewport_press.position = Vector2(320.0, 220.0)
	viewport_press.global_position = viewport_press.position
	root.push_input(viewport_press, true)
	await process_frame
	var viewport_release := InputEventMouseButton.new()
	viewport_release.button_index = MOUSE_BUTTON_LEFT
	viewport_release.pressed = false
	viewport_release.position = viewport_press.position
	viewport_release.global_position = viewport_release.position
	root.push_input(viewport_release, true)
	await process_frame
	_expect(captured_focus_actions == ["test_next_focus"], "Viewport 真实点击高亮区域没有推进一次引导动作。")
	_expect(underlying_button_down_count == 0 and underlying_button_up_count == 0, "高亮点击穿透并触发了底层按钮。")
	underlying_button.queue_free()
	overlay.focus_pressed.disconnect(capture_action)
	overlay.show_step("测试引导", "无文本选课", "", 1, 1, Rect2(300.0, 200.0, 160.0, 64.0), true, {"hide_message_panel": true})
	_expect(not overlay._input_blocker.visible, "允许操作真实目标的步骤仍被场景 InputBlocker 阻断。")
	_expect(not overlay._panel_root.visible, "第 2 至 4 类选课步骤没有隐藏提示文本框。")
	_expect(overlay.visible and not overlay._focus_rects.is_empty(), "隐藏提示文本框时课程高亮也被错误隐藏。")
	mock_main_scene.queue_free()
	current_scene = original_current_scene
	guide_manager._main_scene_ref = original_main_scene_ref
	guide_manager._activity_panel_ref = original_activity_panel_ref

	guide_manager._state["active_guide_id"] = "restored_guide"
	guide_manager._state["current_step_index"] = 3
	overlay.show()

	guide_manager.on_story_scene_ready()

	_expect(not overlay.visible, "进入剧情场景后，引导遮罩仍在拦截输入。")
	_expect(str(guide_manager._state.get("active_guide_id", "")) == "restored_guide", "挂起遮罩时错误清除了活动引导。")
	_expect(int(guide_manager._state.get("current_step_index", -1)) == 3, "挂起遮罩时错误修改了引导步骤。")
	guide_manager._state = original_state
	game_data_manager.clear_archive_custom_config(test_archive_id)
	game_data_manager.set_active_archive_id(original_archive_id, false)
	guide_manager.reload_for_current_archive()
	_finish()


func _verify_activity_item_focus_layout() -> void:
	var guide_manager = root.get_node_or_null("GuideManager")
	_expect(guide_manager != null, "GuideManager 未初始化，无法验证槽位挖孔。")
	if guide_manager == null:
		return
	var panel_scene := load("res://scenes/ui/activity/activity_panel.tscn") as PackedScene
	_expect(panel_scene != null, "无法加载真实行程安排面板。")
	if panel_scene == null:
		return
	var panel := panel_scene.instantiate() as Control
	var original_current_scene: Node = current_scene
	root.add_child(panel)
	current_scene = panel
	await process_frame
	await process_frame
	panel.current_category_id = "physical_health"
	panel._refresh_category_tabs()
	panel._populate_activities()
	await process_frame
	await process_frame
	var focus_entries: Array = panel.get_activity_items_focus_data()
	var items: Array = []
	for child in panel.activities_grid.get_children():
		if child is Control and child.is_visible_in_tree():
			items.append(child)
	_expect(focus_entries.size() == items.size() and focus_entries.size() > 1, "课程列表没有为所有可见课程卡生成独立高亮。")
	for index in range(mini(focus_entries.size(), items.size())):
		var focus_rect: Rect2 = (focus_entries[index] as Dictionary).get("rect", Rect2())
		var item_rect: Rect2 = panel._get_control_focus_rect(items[index] as Control)
		_expect(focus_rect.position.distance_to(item_rect.position) < 0.1, "第 %d 张课程卡高亮错误堆叠到其他卡片位置。" % (index + 1))
		_expect(focus_rect.size.distance_to(item_rect.size) < 0.1, "第 %d 张课程卡高亮范围小于完整列表项。" % (index + 1))
		if index > 0:
			var previous_rect: Rect2 = (focus_entries[index - 1] as Dictionary).get("rect", Rect2())
			_expect(focus_rect.position.distance_to(previous_rect.position) > 1.0, "多张课程卡高亮仍堆叠在同一位置。")
	var slot_focus_entry: Dictionary = panel.get_schedule_slot_focus_entry(0)
	var first_slot := panel._get_all_slot_buttons()[0] as Button
	var first_slot_rect: Rect2 = panel._get_control_focus_rect(first_slot)
	_expect(not slot_focus_entry.is_empty(), "新增课程对应槽位没有生成引导高亮目标。")
	_expect((slot_focus_entry.get("rect", Rect2()) as Rect2).position.distance_to(first_slot_rect.position) < 0.1, "槽位挖孔高亮没有对准对应安排槽位。")
	_expect((slot_focus_entry.get("rect", Rect2()) as Rect2).size.distance_to(first_slot_rect.size) < 0.1, "槽位挖孔高亮没有覆盖完整安排槽位。")
	_expect((slot_focus_entry.get("cutout_polygon", PackedVector2Array()) as PackedVector2Array).size() >= 4, "槽位高亮没有使用与其他引导一致的挖孔轮廓。")
	var original_panel_ref: WeakRef = guide_manager._activity_panel_ref
	guide_manager._activity_panel_ref = weakref(panel)
	guide_manager._state["active_guide_id"] = "schedule_onboarding_guide"
	guide_manager._state["current_step_index"] = 2
	guide_manager.show_schedule_slot_added_focus(0)
	await _wait_for_focus_entry_near(guide_manager._overlay, first_slot_rect.position)
	_expect(guide_manager._schedule_slot_focus_entries.has(0), "课程进入槽位后没有创建持续挖孔高亮。")
	_expect(guide_manager._overlay._focus_entries.any(func(entry: Dictionary) -> bool: return (entry.get("rect", Rect2()) as Rect2).position.distance_to(first_slot_rect.position) < 0.1), "对应槽位挖孔没有叠加到当前引导遮罩。")
	await create_timer(0.7).timeout
	_expect(guide_manager._schedule_slot_focus_entries.has(0), "对应槽位的挖孔高亮在排课引导中途错误消失。")
	guide_manager.show_schedule_slot_added_focus(1)
	await _wait_for_focus_entry_count(guide_manager._overlay, 2)
	_expect(guide_manager._schedule_slot_focus_entries.size() == 2, "连续添加课程时槽位挖孔没有持续累加。")
	var schedule_steps: Array = (guide_manager._guide_defs.get("schedule_onboarding_guide", {}) as Dictionary).get("steps", [])
	var fourth_course_step_index := -1
	var preview_step_index := -1
	var mood_bonus_step_index := -1
	var attribute_benefits_step_index := -1
	var execute_step_index := -1
	var mood_bonus_step: Dictionary = {}
	var attribute_benefits_step: Dictionary = {}
	var affection_panel_step: Dictionary = {}
	var affection_panel_step_index := -1
	var affection_close_step_index := -1
	var affection_close_step: Dictionary = {}
	for step_index in range(schedule_steps.size()):
		var schedule_step := schedule_steps[step_index] as Dictionary
		var step_id := str(schedule_step.get("id", ""))
		if step_id == "select_schedule_category_4":
			fourth_course_step_index = step_index
		elif step_id == "explain_schedule_preview":
			preview_step_index = step_index
		elif step_id == "explain_schedule_mood_bonus":
			mood_bonus_step_index = step_index
			mood_bonus_step = schedule_step
		elif step_id == "explain_schedule_attribute_benefits":
			attribute_benefits_step_index = step_index
			attribute_benefits_step = schedule_step
		elif step_id == "execute_schedule_plan":
			execute_step_index = step_index
		elif step_id == "explain_main_affection_panel":
			affection_panel_step_index = step_index
			affection_panel_step = schedule_step
		elif step_id == "close_main_affection_panel":
			affection_close_step_index = step_index
			affection_close_step = schedule_step
	var affection_overlay_options := affection_panel_step.get("overlay_options", {}) as Dictionary
	_expect(str(affection_overlay_options.get("panel_placement", "")) == "below", "情感面板引导提示框没有固定在高亮区域下方。")
	_expect(str(affection_panel_step.get("wait_action", "")) == "acknowledge_affection_panel", "情感面板说明没有使用独立确认动作。")
	_expect(affection_panel_step_index + 1 == affection_close_step_index, "情感面板确认后没有紧接关闭按钮引导。")
	_expect(str(affection_close_step.get("target_mode", "")) == "affection_close_button", "情感面板关闭步骤没有定位关闭按钮。")
	_expect(str(affection_close_step.get("wait_action", "")) == "close_affection_panel", "情感面板关闭步骤没有等待真实关闭动作。")
	_expect(preview_step_index + 1 == mood_bonus_step_index and mood_bonus_step_index + 1 == attribute_benefits_step_index and attribute_benefits_step_index + 1 == execute_step_index, "右侧详情、心情收益、属性收益和执行按钮引导顺序不正确。")
	_expect(str(mood_bonus_step.get("target_mode", "")) == "mood_bonus_region", "心情收益引导没有使用单孔容器。")
	_expect(str(mood_bonus_step.get("text", "")).contains("心情则会影响上课的收益"), "心情收益引导提示文本不正确。")
	_expect(str(attribute_benefits_step.get("target_mode", "")) == "attribute_benefit_region", "属性收益引导没有使用单孔容器。")
	_expect(str(attribute_benefits_step.get("text", "")).contains("从这里就能看到你为我安排的课程收益"), "属性收益引导提示文本不正确。")
	var mood_bonus_focus: Dictionary = panel.get_mood_bonus_focus_data()
	var expected_mood_bonus_rect: Rect2 = panel.status_hbox.get_global_rect().merge(panel.bonus_label.get_global_rect())
	_expect((mood_bonus_focus.get("rect", Rect2()) as Rect2).position.distance_to(expected_mood_bonus_rect.position) < 0.1, "心情状态与收益加成没有合并为同一个高亮区域。")
	_expect((mood_bonus_focus.get("rect", Rect2()) as Rect2).size.distance_to(expected_mood_bonus_rect.size) < 0.1, "心情收益单孔范围没有完整覆盖 StatusHBox 和 BonusLabel。")
	var attribute_benefit_focus: Dictionary = panel.get_attribute_benefit_focus_data()
	var expected_attribute_rect: Rect2 = panel.attribute_title.get_global_rect().merge(panel.attribute_scroll.get_global_rect())
	_expect((attribute_benefit_focus.get("rect", Rect2()) as Rect2).position.distance_to(expected_attribute_rect.position) < 0.1, "属性标题与收益列表没有合并为同一个高亮区域。")
	_expect((attribute_benefit_focus.get("rect", Rect2()) as Rect2).size.distance_to(expected_attribute_rect.size) < 0.1, "属性收益单孔范围没有完整覆盖 AttributeTitle 和 ScrollContainer。")
	guide_manager._state["current_step_index"] = fourth_course_step_index
	guide_manager._advance_step()
	guide_manager.show_schedule_slot_added_focus(3)
	_expect(guide_manager._schedule_slot_focus_entries.is_empty(), "进入整条课程栏引导后四个单槽位高亮没有清除。")
	var main_event_focus_entry: Dictionary = panel.get_main_event_slot_focus_entry()
	_expect(not main_event_focus_entry.is_empty(), "剧情槽位没有生成引导高亮目标。")
	_expect(float((main_event_focus_entry.get("shape_params", {}) as Dictionary).get("corner_radius", 0.0)) == 22.0, "剧情槽位没有使用与课程槽位一致的圆角半径。")
	_expect((main_event_focus_entry.get("cutout_polygon", PackedVector2Array()) as PackedVector2Array).size() >= 4, "剧情槽位高亮没有使用圆角挖孔轮廓。")
	guide_manager.show_schedule_slot_added_focus(0)
	guide_manager._state["current_step_index"] = execute_step_index
	guide_manager._advance_step()
	_expect(guide_manager._schedule_slot_focus_entries.is_empty(), "离开排课阶段后槽位挖孔高亮没有清除。")
	guide_manager._activity_panel_ref = original_panel_ref
	current_scene = original_current_scene
	panel.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _wait_for_focus_entry_near(overlay: Control, expected_position: Vector2) -> void:
	for _attempt in range(60):
		if overlay._focus_entries.any(func(entry: Dictionary) -> bool: return (entry.get("rect", Rect2()) as Rect2).position.distance_to(expected_position) < 0.1):
			return
		await process_frame


func _wait_for_focus_entry_count(overlay: Control, minimum_count: int) -> void:
	for _attempt in range(60):
		if overlay._focus_entries.size() >= minimum_count:
			return
		await process_frame


func _wait_for_overlay_visible(overlay: Control) -> void:
	for _attempt in range(60):
		if overlay.visible and overlay._panel_root.visible and overlay._panel_root.modulate.a >= 0.99:
			return
		await process_frame


func _wait_for_manager_presentation(guide_manager: Node, expected_key: String) -> void:
	for _attempt in range(60):
		if guide_manager._active_presentation_key == expected_key and guide_manager._pending_presentation_key == "":
			await _wait_for_overlay_visible(guide_manager._overlay)
			return
		await process_frame


func _finish() -> void:
	if failures.is_empty():
		print("STORY_GUIDE_OVERLAY_ISOLATION_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("STORY_GUIDE_OVERLAY_ISOLATION_SMOKE: %s" % failure)
	quit(1)
