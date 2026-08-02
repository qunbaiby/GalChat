extends SceneTree

const MAIN_SCENE_SCRIPT_PATH := "res://scripts/ui/main/main_scene.gd"

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var source := FileAccess.get_file_as_string(MAIN_SCENE_SCRIPT_PATH)
	_expect(not source.is_empty(), "无法读取主场景脚本。")
	_expect(source.contains("func _sync_fullscreen_overlay_bgm_pause() -> void:"), "缺少全屏覆盖 BGM 同步入口。")
	_expect(source.contains("_main_scene_bgm_pause_reasons.has(\"fullscreen_overlay\")"), "全屏覆盖没有使用独立暂停原因。")
	_expect(source.contains("func _has_fullscreen_main_overlay() -> bool:"), "缺少全屏覆盖状态判定。")
	_expect(source.contains('mobile_interface_instance.has_method("is_standalone_wechat_open")') and source.contains("continue"), "独立微聊仍被计入全屏 BGM 暂停界面。")
	_expect(source.contains("find_child(\"ScheduleExecutionPanel\", true, false)"), "活动执行与结算面板未纳入覆盖判定。")
	_expect(source.contains("func _process(delta: float) -> void:\n\t_check_afk_status()\n\t_sync_desktop_wallpaper_suspension()\n\t_sync_fullscreen_overlay_bgm_pause()"), "主场景没有持续同步全屏覆盖状态。")
	_expect(source.count("bgm.stop()") == 1, "覆盖界面入口仍可能直接停止 BGM 并丢失播放位置。")
	var mobile_source := FileAccess.get_file_as_string("res://scripts/ui/mobile/mobile_interface.gd")
	_expect(mobile_source.contains("func is_standalone_wechat_open() -> bool:"), "手机界面没有暴露独立微聊状态。")
	_expect(not mobile_source.contains("color_rect.color.a = 0.22"), "独立微聊仍会添加半透明根遮罩。")
	_expect(mobile_source.contains("color_rect.color = standalone_wechat_overlay_color"), "独立微聊根遮罩没有使用场景可调颜色。")
	var mobile_scene_source := FileAccess.get_file_as_string("res://scenes/ui/mobile/mobile_interface.tscn")
	_expect(mobile_scene_source.contains("standalone_wechat_overlay_color = Color(0, 0, 0, 0)"), "独立微聊根遮罩没有在场景中配置为全透明。")
	var wechat_scene_source := FileAccess.get_file_as_string("res://scenes/ui/mobile/wechat/wechat_main_panel.tscn")
	_expect(not wechat_scene_source.contains("Shader_WechatBlur"), "微聊界面仍使用背景模糊 Shader。")
	_expect(wechat_scene_source.contains("[node name=\"DimBg\"") and wechat_scene_source.contains("color = Color(0, 0, 0, 0)"), "微聊背景遮罩没有在场景中配置为全透明。")
	var wechat_scene := load("res://scenes/ui/mobile/wechat/wechat_main_panel.tscn") as PackedScene
	var wechat_panel = wechat_scene.instantiate()
	root.add_child(wechat_panel)
	await process_frame
	wechat_panel.show_panel(false)
	_expect(wechat_panel.dim_bg.color.a == 0.0, "微聊无动画打开时把 WindowPanel 外背景改成了纯黑。")
	wechat_panel.hide_panel(true)
	wechat_panel.show_panel(true)
	await create_timer(0.25).timeout
	_expect(wechat_panel.dim_bg.color.a == 0.0, "微聊动画打开时把 WindowPanel 外背景渐变成了纯黑。")
	wechat_panel.queue_free()
	await process_frame
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("MAIN_SCENE_BGM_OVERLAY_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("MAIN_SCENE_BGM_OVERLAY_SMOKE: %s" % failure)
	quit(1)