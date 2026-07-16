extends SceneTree

const WindowScene = preload("res://addons/story_editor/ui/story_reference_catalog_window.tscn")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var window := WindowScene.instantiate()
	root.add_child(window)
	await process_frame
	window.refresh_catalog()
	await process_frame

	_expect(window.references.size() == 7, "真实数据应包含 Event Registry、Guide Flow、剧情日程和地图入口共 7 个。")
	_expect(window.selected_reference_index == 0, "刷新后应默认选择第一个入口。")
	_expect(not window.get_node("Root/Body/Details/DetailsScroll/Content/SelectionTitle").text.is_empty(), "默认入口详情未显示。")
	_expect(window.get_node("Root/Body/Details/DetailsScroll/Content/BacklinksTree").get_root() != null, "反向引用树未创建。")
	_expect(window.get_node("Root/Header/Summary").text.contains("7 个入口"), "摘要未显示真实入口数量。")
	_expect(window.diagnostics.any(func(diagnostic: Dictionary) -> bool: return diagnostic.get("code") == "unreferenced_story"), "窗口未显示未引用剧情诊断。")
	_expect(window.diagnostics.any(func(diagnostic: Dictionary) -> bool: return diagnostic.get("code") == "schedule_day_mismatch"), "窗口未显示日程元数据漂移诊断。")
	var errors: Array = window.diagnostics.filter(func(diagnostic: Dictionary) -> bool: return diagnostic.get("severity") == "error")
	_expect(errors.is_empty(), "真实入口目录不应包含阻塞错误。")

	window.queue_free()
	await process_frame
	if failures.is_empty():
		print("STORY_REFERENCE_CATALOG_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("STORY_REFERENCE_CATALOG_SMOKE: %s" % failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)