extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game_data_source := FileAccess.get_file_as_string("res://scripts/data/game_data_manager.gd")
	_expect(game_data_source.contains("config.apply_runtime_settings()"), "创建存档后没有保留当前窗口几何。")
	_expect(not game_data_source.contains("\t\tconfig.apply_settings()\n\t\tconfig.save_config()\n\tarchive_changed.emit"), "创建存档进入玩家信息面板时仍会重新应用分辨率。")
	await _verify_placeholder_focus(
		"res://scenes/ui/save_load/archive_name_popup.tscn",
		"PopupPanel/MarginContainer/VBoxContainer/NameInput",
		"例如 第一次相遇、夏日记忆、Luna 的新篇章"
	)
	await _verify_placeholder_focus(
		"res://scenes/ui/story/player_call_name_popup.tscn",
		"PopupPanel/MarginContainer/VBoxContainer/TitleInput",
		"例如 老师、哥哥、小名"
	)
	await _verify_confirm_delete_input()
	await _verify_account_auth_input()
	await _verify_bug_feedback_input()
	await _verify_player_info_zodiac()
	_finish()

func _verify_placeholder_focus(scene_path: String, input_path: String, expected_placeholder: String) -> void:
	var packed_scene := load(scene_path) as PackedScene
	_expect(packed_scene != null, "无法加载输入弹窗：%s" % scene_path)
	if packed_scene == null:
		return
	var popup := packed_scene.instantiate() as Control
	root.add_child(popup)
	await process_frame
	var input := popup.get_node(input_path) as LineEdit
	input.text = ""
	input.release_focus()
	await process_frame
	_expect(not input.has_focus(), "%s 打开时错误显示了输入光标。" % scene_path)
	_expect(input.placeholder_text == expected_placeholder, "%s 打开时没有显示参考文本。" % scene_path)
	_expect(input.get_theme_color("font_placeholder_color").a < 0.6, "%s 的参考文本颜色仍然过于醒目。" % scene_path)
	_expect(input.caret_blink, "%s 的输入光标没有启用闪烁。" % scene_path)
	input.grab_focus()
	await process_frame
	_expect(input.has_focus(), "%s 点击后没有获得输入焦点。" % scene_path)
	_expect(input.placeholder_text == "", "%s 获得焦点后参考文本没有消失。" % scene_path)
	input.release_focus()
	await process_frame
	_expect(input.placeholder_text == expected_placeholder, "%s 空内容失焦后没有恢复参考文本。" % scene_path)
	popup.queue_free()
	await process_frame

func _verify_confirm_delete_input() -> void:
	var packed_scene := load("res://scenes/ui/common/confirm_dialog.tscn") as PackedScene
	_expect(packed_scene != null, "无法加载确认清除弹窗。")
	if packed_scene == null:
		return
	var dialog := packed_scene.instantiate() as Control
	root.add_child(dialog)
	dialog.setup_advanced("清除记忆", "确认要清除这段记忆么？", "", "", "清除记忆", "取消", "确认清除")
	await process_frame
	var input := dialog.confirm_input as LineEdit
	_expect(not input.has_focus(), "确认清除弹窗打开时错误显示了输入光标。")
	_expect(input.placeholder_text == "确认清除", "确认清除弹窗没有显示参考文本。")
	_expect(input.get_theme_color("font_placeholder_color").a < 0.6, "确认清除参考文本颜色仍然过于醒目。")
	_expect(input.caret_blink, "确认清除输入光标没有启用闪烁。")
	input.grab_focus()
	await process_frame
	_expect(input.placeholder_text == "", "确认清除输入框获得焦点后参考文本没有消失。")
	input.release_focus()
	await process_frame
	_expect(input.placeholder_text == "确认清除", "确认清除输入框空内容失焦后没有恢复参考文本。")
	dialog.queue_free()
	await process_frame

func _verify_account_auth_input() -> void:
	var packed_scene := load("res://scenes/ui/start/account_auth_panel.tscn") as PackedScene
	_expect(packed_scene != null, "无法加载账号登录面板。")
	if packed_scene == null:
		return
	var panel := packed_scene.instantiate() as Control
	root.add_child(panel)
	await process_frame
	var username_input := panel.get_node("Panel/Margin/Content/UsernameInput") as LineEdit
	_expect(not username_input.has_focus(), "账号登录面板打开时错误显示了用户名光标。")
	panel.queue_free()
	await process_frame

func _verify_bug_feedback_input() -> void:
	var packed_scene := load("res://scenes/ui/start/bug_feedback_panel.tscn") as PackedScene
	_expect(packed_scene != null, "无法加载问题反馈面板。")
	if packed_scene == null:
		return
	var panel := packed_scene.instantiate() as Control
	root.add_child(panel)
	panel.show_panel()
	await process_frame
	var title_input := panel.title_input as LineEdit
	_expect(not title_input.has_focus(), "问题反馈面板打开时错误显示了标题光标。")
	_expect(title_input.get_theme_color("font_placeholder_color").a < 0.6, "问题反馈参考文本颜色仍然过于醒目。")
	panel.queue_free()
	await process_frame

func _verify_player_info_zodiac() -> void:
	var packed_scene := load("res://scenes/ui/story/player_info_popup.tscn") as PackedScene
	_expect(packed_scene != null, "无法加载玩家信息弹窗。")
	if packed_scene == null:
		return
	var popup := packed_scene.instantiate() as Control
	root.add_child(popup)
	await process_frame
	var name_input := popup.get_node("PopupPanel/MarginContainer/MainVBox/InfoCard/InfoMargin/FormVBox/NameField/NameInput") as LineEdit
	_expect(not name_input.caret_force_displayed, "玩家姓名输入框仍在未聚焦时强制显示光标。")
	_expect(name_input.get_theme_color("font_placeholder_color").a < 0.6, "玩家姓名参考文本颜色仍然过于醒目。")
	popup._clear_birthday_selection()
	await process_frame
	_expect(not popup.zodiac_field.visible, "未输入生日时星座字段仍然显示。")
	_expect(not popup.zodiac_divider.visible, "未输入生日时星座分隔线仍然占位。")
	_expect(popup.zodiac_label.text == "", "未输入生日时仍显示星座参考文本。")
	popup._on_birth_month_changed(7)
	await process_frame
	_expect(popup.zodiac_field.visible, "输入生日后星座字段没有显示。")
	_expect(popup.zodiac_divider.visible, "输入生日后星座分隔线没有恢复。")
	_expect(popup.zodiac_label.text != "", "输入生日后没有计算星座。")
	popup.queue_free()
	await process_frame

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _finish() -> void:
	if failures.is_empty():
		print("PROFILE_INPUT_EXPERIENCE_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("PROFILE_INPUT_EXPERIENCE_SMOKE: %s" % failure)
	quit(1)