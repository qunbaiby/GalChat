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
	_expect(source.contains("find_child(\"ScheduleExecutionPanel\", true, false)"), "活动执行与结算面板未纳入覆盖判定。")
	_expect(source.contains("func _process(delta: float) -> void:\n\t_check_afk_status()\n\t_sync_desktop_wallpaper_suspension()\n\t_sync_fullscreen_overlay_bgm_pause()"), "主场景没有持续同步全屏覆盖状态。")
	_expect(source.count("bgm.stop()") == 1, "覆盖界面入口仍可能直接停止 BGM 并丢失播放位置。")
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