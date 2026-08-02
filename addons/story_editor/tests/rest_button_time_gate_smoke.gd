extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_data_manager := root.get_node_or_null("GameDataManager")
	var main_scene_resource := load("res://scenes/ui/main/main_scene.tscn") as PackedScene
	_expect(game_data_manager != null, "GameDataManager 未初始化。")
	_expect(main_scene_resource != null, "主场景无法加载。")
	if game_data_manager == null or main_scene_resource == null:
		_finish()
		return

	var time_manager = game_data_manager.story_time_manager
	var original_day := int(time_manager.current_day_offset)
	var original_hour := int(time_manager.current_hour)
	var original_minute := int(time_manager.current_minute)
	time_manager.current_day_offset = _find_weekday_offset(time_manager, 5)
	var main_scene := main_scene_resource.instantiate() as Control
	root.add_child(main_scene)
	await process_frame
	await process_frame

	time_manager.current_hour = 18
	time_manager.current_minute = 59
	main_scene._update_button_states_by_time()
	var rest_button := main_scene.current_bg_scene.get_node_or_null("RestButton") as Button
	_expect(rest_button != null and not rest_button.visible and rest_button.disabled, "休息按钮在 18:59 前已经显示或可用。")

	time_manager.current_hour = 19
	time_manager.current_minute = 0
	main_scene._update_button_states_by_time()
	rest_button = main_scene.current_bg_scene.get_node_or_null("RestButton") as Button
	_expect(rest_button != null and rest_button.visible and not rest_button.disabled, "休息按钮在 19:00 没有显示并开放。")

	time_manager.current_day_offset = original_day
	time_manager.current_hour = original_hour
	time_manager.current_minute = original_minute
	main_scene.queue_free()
	await process_frame
	_finish()


func _find_weekday_offset(time_manager: Node, target_weekday: int) -> int:
	for offset in range(7):
		time_manager.current_day_offset = offset
		if int(time_manager.get_current_date_dict().get("weekday", -1)) == target_weekday:
			return offset
	return 0


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("REST_BUTTON_TIME_GATE_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("REST_BUTTON_TIME_GATE_SMOKE: %s" % failure)
	quit(1)