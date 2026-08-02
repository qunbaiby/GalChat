extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var slot_scene := load("res://scenes/ui/activity/course_slot.tscn") as PackedScene
	_expect(slot_scene != null, "无法加载课程槽位场景。")
	if slot_scene == null:
		_finish()
		return

	var expected_colors := {
		"优秀": Color(0.95, 0.68, 0.22, 1.0),
		"良好": Color(0.25, 0.67, 0.78, 1.0),
		"合格": Color(0.48, 0.56, 0.61, 1.0)
	}
	for grade in expected_colors.keys():
		var slot := slot_scene.instantiate()
		root.add_child(slot)
		await process_frame
		slot.set_result_grade(grade)
		var result_label := slot.get_node("CourseMargin/ResultLabel") as Label
		var name_label := slot.get_node("CourseMargin/NameLabel") as Label
		var icon_plate := slot.get_node("CourseMargin/IconPlate") as Control
		var event_badge := slot.get_node("CourseMargin/EventBadge") as Control
		_expect(result_label.visible and result_label.text == grade, "课程槽位没有显示%s结果。" % grade)
		_expect(not name_label.visible, "%s结果显示后仍保留槽位编号。" % grade)
		_expect(result_label.get_theme_color("font_color").is_equal_approx(expected_colors[grade]), "%s结果文字颜色不正确。" % grade)
		_expect(not icon_plate.visible and not event_badge.visible, "%s结果显示后仍保留课程图标或事件徽章。" % grade)
		slot.queue_free()
		await process_frame

	var execution_source := FileAccess.get_file_as_string("res://scripts/ui/activity/schedule_execution_panel.gd")
	_expect(execution_source.contains('"name": "优秀", "weight": 0.25, "reward_multiplier": 1.25'), "优秀等级没有使用 1.25 倍课程收益。")
	_expect(execution_source.contains('"name": "良好", "weight": 0.50, "reward_multiplier": 1.00'), "良好等级没有使用标准课程收益。")
	_expect(execution_source.contains('"name": "合格", "weight": 0.25, "reward_multiplier": 0.75'), "合格等级没有使用 0.75 倍课程收益。")
	_expect(execution_source.contains('bonus.get("applied_value", bonus.get("value", 0.0))') and execution_source.contains("* multiplier"), "课程等级倍率没有应用到实际课程收益。")

	var execution_scene := load("res://scenes/ui/activity/schedule_execution_panel.tscn") as PackedScene
	_expect(execution_scene != null, "无法加载课程执行场景。")
	if execution_scene != null:
		var execution := execution_scene.instantiate()
		root.add_child(execution)
		await process_frame
		execution._start_attrs = {"学识": 100.0, "金币": 50.0, "心情": 50.0}
		execution._base_end_attrs = {"学识": 110.0, "金币": 50.0, "心情": 50.0}
		execution._courses_data = [{"bonus_list": [{"name": "学识", "value": 10.0, "applied_value": 10.0}]}]
		execution._non_course_end_attrs = execution._build_non_course_end_attrs()
		var expected_rewards := {"优秀": 112.5, "良好": 110.0, "合格": 107.5}
		var multipliers := {"优秀": 1.25, "良好": 1.0, "合格": 0.75}
		for grade in expected_rewards.keys():
			execution._course_results = {0: {"grade": grade, "reward_multiplier": multipliers[grade]}}
			execution._rebuild_final_end_attrs()
			_expect(is_equal_approx(float(execution._end_attrs.get("学识", 0.0)), float(expected_rewards[grade])), "%s等级的实际课程收益不正确。" % grade)
		execution.queue_free()
		await process_frame
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("SCHEDULE_COURSE_RESULT_GRADE_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("SCHEDULE_COURSE_RESULT_GRADE_SMOKE: %s" % failure)
	quit(1)