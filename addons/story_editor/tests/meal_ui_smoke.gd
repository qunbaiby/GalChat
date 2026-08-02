extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _verify_meal_panel()
	await _verify_background_buttons()
	_verify_main_scene_integration()
	_finish()


func _verify_meal_panel() -> void:
	var packed_scene := load("res://scenes/ui/main/meal_panel.tscn") as PackedScene
	_expect(packed_scene != null, "吃饭面板场景无法加载。")
	if packed_scene == null:
		return
	var panel := packed_scene.instantiate() as Control
	root.add_child(panel)
	await process_frame
	var takeout_button := panel.get_node("Panel/Margin/OptionPage/Options/TakeoutButton") as Button
	var luna_cooks_button := panel.get_node("Panel/Margin/OptionPage/Options/LunaCooksButton") as Button
	var dine_out_button := panel.get_node("Panel/Margin/OptionPage/Options/DineOutButton") as Button
	_expect(not panel.visible, "吃饭面板在主场景启动时自动弹出。")
	_expect(not takeout_button.disabled, "点外卖选项错误地被锁定。")
	_expect(panel.get_node_or_null("Panel/Margin/OptionPage/Subtitle") == null, "吃饭面板仍显示用餐方式副标题。")
	var takeout_icon := takeout_button.get_node_or_null("OptionIcon") as TextureRect
	var luna_lock := luna_cooks_button.get_node_or_null("LockIcon") as TextureRect
	var dine_out_lock := dine_out_button.get_node_or_null("LockIcon") as TextureRect
	_expect(takeout_icon != null and takeout_icon.position == Vector2(18, 17) and takeout_icon.size == Vector2(18, 18), "点外卖图标没有与锁图标对齐。")
	_expect(luna_cooks_button.disabled and luna_lock != null and luna_lock.size == Vector2(18, 18), "Luna做没有使用固定 18px 的锁图标。")
	_expect(dine_out_button.disabled and dine_out_lock != null and dine_out_lock.size == Vector2(18, 18), "出去吃没有使用固定 18px 的锁图标。")
	_expect(luna_lock.position == takeout_icon.position and dine_out_lock.position == takeout_icon.position, "三个选项的左侧图标没有对齐。")
	_expect(luna_cooks_button.text == "Luna做" and dine_out_button.text == "出去吃", "锁定选项仍显示“未解锁”文字。")
	var panel_style := panel.get_node("Panel").get_theme_stylebox("panel") as StyleBoxFlat
	var takeout_style := takeout_button.get_theme_stylebox("normal") as StyleBoxFlat
	_expect(panel_style != null and panel_style.bg_color.g > panel_style.bg_color.r and panel_style.bg_color.g > panel_style.bg_color.b, "吃饭弹窗没有使用青绿色背景。")
	_expect(takeout_style != null and takeout_style.bg_color.g > takeout_style.bg_color.r, "吃饭选项没有使用青绿色按钮样式。")
	panel.show_options()
	_expect(panel.visible, "吃饭按钮无法打开选项页。")
	panel.show_result({
		"name": "测试餐点",
		"image": "res://assets/images/ui/creation/cafe_break.png",
		"time_cost_minutes": 30
	})
	var result_page := panel.get_node("Panel/Margin/ResultPage") as Control
	var meal_image := panel.get_node("Panel/Margin/ResultPage/MealImage") as TextureRect
	var completion_content := panel.get_node("Panel/Margin/ResultPage/CompletionContent") as VBoxContainer
	var stat_changes := panel.get_node("Panel/Margin/ResultPage/CompletionContent/StatChanges") as Label
	var meal_progress := panel.get_node("Panel/Margin/ResultPage/MealProgress") as ProgressBar
	var dismiss_button := panel.get_node("DismissButton") as Button
	var elapsed_minutes := [0]
	panel.meal_minute_elapsed.connect(func(minutes: int) -> void: elapsed_minutes[0] += minutes)
	_expect(result_page.visible and meal_image.texture != null, "点外卖结果页没有显示配置图片。")
	_expect(completion_content.modulate.a == 0.0 and not dismiss_button.visible, "用餐进度完成前属性已显示或允许关闭。")
	panel._try_close_result()
	_expect(panel.visible, "用餐进度完成前可以关闭结果页。")
	await create_timer(3.2).timeout
	_expect(int(meal_progress.value) == 30 and int(elapsed_minutes[0]) == 30, "用餐进度没有与 30 分钟时间推进保持一致。")
	panel.reveal_completion({
		"energy_delta": 7,
		"mood_delta": 4.0,
		"time_cost_minutes": 30
	})
	_expect(stat_changes.text.contains("+7") and stat_changes.text.contains("+4") and stat_changes.text.contains("30 分钟"), "结果页没有显示实际属性变化和 30 分钟耗时。")
	_expect(dismiss_button.visible and dismiss_button.z_index > 0, "用餐完成后没有启用全区域点击关闭层。")
	panel._try_close_result()
	_expect(not panel.visible, "用餐完成后点击结果页无法关闭。")
	panel.queue_free()
	await process_frame


func _verify_background_buttons() -> void:
	var background_paths := [
		"res://scenes/ui/main/backgrounds/locations/default_room_bg.tscn",
		"res://scenes/ui/main/backgrounds/locations/art_studio_bg.tscn",
		"res://scenes/ui/main/backgrounds/locations/class_break_moments_bg.tscn",
		"res://scenes/ui/main/backgrounds/locations/holiday_pool_days_bg.tscn",
		"res://scenes/ui/main/backgrounds/locations/piano_room_bg.tscn"
	]
	for background_path in background_paths:
		var packed_scene := load(background_path) as PackedScene
		_expect(packed_scene != null, "%s 无法加载。" % background_path)
		if packed_scene == null:
			continue
		var background := packed_scene.instantiate() as Control
		root.add_child(background)
		await process_frame
		var meal_button := background.get_node_or_null("MealButton") as Button
		var chat_button := background.get_node_or_null("ChatButton") as Button
		var rest_button := background.get_node_or_null("RestButton") as Button
		_expect(meal_button != null and meal_button.get_parent() == background, "%s 没有直接配置根级吃饭按钮。" % background_path)
		_expect(meal_button != null and chat_button != null and meal_button.get_parent() == chat_button.get_parent(), "%s 的吃饭按钮没有采用聊天按钮的直接场景结构。" % background_path)
		_expect(rest_button != null and rest_button.size.is_equal_approx(chat_button.size), "%s 的休息按钮没有与聊天按钮保持同样大小。" % background_path)
		_expect(meal_button != null and meal_button.size.is_equal_approx(chat_button.size), "%s 的吃饭按钮没有与聊天按钮保持同样大小。" % background_path)
		_expect(chat_button != null and chat_button.size.is_equal_approx(Vector2(222.0404, 190.0)), "%s 的三项主场景按钮没有在场景中放大到双倍尺寸。" % background_path)
		if background.has_method("set_meal_button_available"):
			background.set_meal_button_available(true, "晚餐")
			await process_frame
		for button in [chat_button, rest_button, meal_button]:
			var content := button.get_node_or_null("ContentHBox") as HBoxContainer if button != null else null
			var icon := content.get_node_or_null("Icon") as TextureRect if content != null else null
			var label := content.get_node_or_null("Label") as Label if content != null else null
			_expect(content != null and icon != null and label != null, "%s 的 %s 没有配置左图标右文字内容。" % [background_path, button.name if button != null else "按钮"])
			if content != null and icon != null and label != null:
				_expect(icon.position.x < label.position.x, "%s 的 %s 不是左图标右文字布局。" % [background_path, button.name])
				_expect(icon.custom_minimum_size == Vector2(60, 60), "%s 的 %s 图标没有在场景中放大到 60×60。" % [background_path, button.name])
				_expect(label.get_theme_font_size("font_size") == 34, "%s 的 %s 文字没有在场景中放大到 34px。" % [background_path, button.name])
		var meal_label := meal_button.get_node_or_null("ContentHBox/Label") as Label if meal_button != null else null
		_expect(meal_label != null and meal_label.text == "晚餐", "%s 的吃饭按钮没有按餐段更新文字。" % background_path)
		background.queue_free()
		await process_frame


func _verify_main_scene_integration() -> void:
	var main_scene := load("res://scenes/ui/main/main_scene.tscn") as PackedScene
	_expect(main_scene != null, "加入吃饭面板后主场景无法加载。")
	if main_scene == null:
		return
	var main_instance := main_scene.instantiate()
	_expect(main_instance.get_node_or_null("MealPanel") != null, "主场景没有预置 MealPanel。")
	main_instance.free()
	var source := FileAccess.get_file_as_string("res://scripts/ui/main/main_scene.gd")
	_expect(source.contains("load_cached_audio_by_key(cache_key)"), "吃饭提示语没有优先读取 TTS 缓存。")
	_expect(source.contains("TTSManager.synthesize(MEAL_PROMPT_TEXT, options)"), "吃饭提示语缓存缺失时没有触发首次合成。")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("MEAL_UI_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("MEAL_UI_SMOKE: " + failure)
	quit(1)