extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main_scene_resource := load("res://scenes/ui/main/main_scene.tscn") as PackedScene
	_expect(main_scene_resource != null, "主场景无法加载。")
	if main_scene_resource == null:
		_finish()
		return
	var main_scene := main_scene_resource.instantiate() as Control
	root.add_child(main_scene)
	await process_frame
	await process_frame
	var gift_button := main_scene.get_node("UIPanel/BottomBarHBox/BtnHBox/MainGiftButton") as Button
	var date_button := main_scene.get_node("UIPanel/DateButton") as Button
	var main_scene_source := FileAccess.get_file_as_string("res://scripts/ui/main/main_scene.gd")
	_expect(not main_scene_source.contains("FEATURE_LOCK_ICON"), "主场景功能锁仍在加载锁图标。")
	_expect(main_scene_source.contains('const MAIN_FEATURE_LOCK_HINT := "该功能尚未解锁"'), "主场景功能锁 Toast 文案不正确。")
	_expect(bool(gift_button.get_meta("feature_locked", false)), "礼物按钮默认没有进入锁定视觉状态。")
	_expect(not gift_button.disabled, "锁定的礼物按钮无法接收点击。")
	_expect(gift_button.find_child("LockIcon", true, false) == null, "锁定的礼物按钮仍动态创建锁图标。")
	_expect(date_button.visible, "锁定的约会按钮被隐藏，无法点击查看解锁提示。")
	var toast_manager := root.get_node_or_null("ToastManager")
	var toast_count_before := toast_manager.get_child_count() if toast_manager != null else -1
	var lock_click_handled := bool(main_scene.call("_show_locked_feature_toast_if_needed", "main.gift", gift_button))
	await process_frame
	var lock_toast := toast_manager.get_child(toast_manager.get_child_count() - 1) if toast_manager != null and toast_manager.get_child_count() > toast_count_before else null
	var lock_toast_label := lock_toast.get_node_or_null("CenterContainer/PanelContainer/MarginContainer/Label") as Label if lock_toast != null else null
	_expect(lock_click_handled, "锁定的礼物按钮点击没有被功能锁拦截。")
	_expect(lock_toast_label != null and lock_toast_label.text == "该功能尚未解锁", "锁定按钮没有显示正确的居中 Toast。")
	main_scene.queue_free()
	await process_frame
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("MAIN_FEATURE_LOCK_TOAST_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("MAIN_FEATURE_LOCK_TOAST_SMOKE: %s" % failure)
	quit(1)