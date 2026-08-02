extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_data_manager = root.get_node_or_null("GameDataManager")
	_expect(game_data_manager != null, "GameDataManager autoload 不可用。")
	if game_data_manager == null:
		_finish()
		return

	var profile = game_data_manager.profile
	var time_manager = game_data_manager.story_time_manager
	var original_energy: int = profile.current_energy
	var original_hour: int = time_manager.current_hour
	var original_minute: int = time_manager.current_minute
	var original_progress: Dictionary = profile.course_progress.duplicate(true)
	var original_tutoring_history: Dictionary = profile.tutoring_history.duplicate(true)
	var original_stamina: float = profile.stat_stamina
	var original_rhythm: float = profile.stat_rhythm
	profile.current_energy = 100
	profile.course_progress["stage_stamina"] = 0
	profile.tutoring_history.clear()
	profile.stat_stamina = 0.0
	profile.stat_rhythm = 0.0
	time_manager.current_hour = 10
	time_manager.current_minute = 0

	var tutoring_menu_scene = load("res://scenes/ui/map/library/tutoring_menu.tscn")
	_expect(tutoring_menu_scene != null, "无法加载课业指导菜单场景。")
	if tutoring_menu_scene == null:
		_finish()
		return
	var menu = tutoring_menu_scene.instantiate()
	root.add_child(menu)
	await process_frame
	var course: Dictionary = menu._get_course_by_id("stage_stamina")
	_expect(not course.is_empty(), "课业指导菜单没有加载舞台耐力课程。")
	_expect(menu.get_guide_target("course_list") == menu.get_node("MenuPanel/ContentHBox/LeftPanel"), "课业指导引导没有定位整个左侧选课面板。")
	_expect(menu.get_guide_target("detail_panel") != null, "课业指导引导无法定位右侧详情区域。")
	_expect(menu.get_guide_target("start_button") == menu.start_btn, "课业指导引导没有定位真实开始按钮。")
	var course_list_target := menu.get_guide_target("course_list") as Control
	var course_list_focus_entry: Dictionary = menu.get_guide_focus_data("course_list")
	var course_list_focus: Rect2 = course_list_focus_entry.get("rect", Rect2())
	var detail_target := menu.get_guide_target("detail_panel") as Control
	var detail_focus_entry: Dictionary = menu.get_guide_focus_data("detail_panel")
	var detail_focus: Rect2 = detail_focus_entry.get("rect", Rect2())
	var start_focus_entry: Dictionary = menu.get_guide_focus_data("start_button")
	_expect(course_list_focus.size.is_equal_approx(course_list_target.size), "左侧课程列表高亮尺寸与真实面板不一致。")
	_expect(detail_focus.size.is_equal_approx(detail_target.size), "右侧详情高亮尺寸与真实面板不一致。")
	_expect(course_list_focus.position.x < detail_focus.position.x and course_list_focus.end.x <= detail_focus.position.x, "课程列表与详情高亮区域发生错误重叠。")
	_expect(float((course_list_focus_entry.get("shape_params", {}) as Dictionary).get("corner_radius", 0.0)) == 18.0, "左侧课程列表高亮没有使用圆角。")
	_expect(float((detail_focus_entry.get("shape_params", {}) as Dictionary).get("corner_radius", 0.0)) == 18.0, "右侧详情高亮没有使用圆角。")
	_expect(float((start_focus_entry.get("shape_params", {}) as Dictionary).get("corner_radius", 0.0)) == 12.0, "开始指导按钮高亮没有使用圆角。")
	_expect(menu._get_course_energy_cost(course) == 4, "课业指导精力没有按正常课程公式翻倍。")

	for _index in 5:
		menu._on_course_clicked(course)
	_expect(menu._get_total_planned_count() == 5, "五次课程安排没有被完整记录。")
	_expect(menu._get_total_planned_cost() == 20, "五次课程安排的精力合计错误。")
	_expect(menu._get_total_planned_minutes() == 300, "五次课程安排没有按每次 60 分钟累计。")
	menu._on_course_clicked(course)
	_expect(menu._get_total_planned_count() == 5, "同一门课程错误允许安排超过五次指导。")
	_expect(menu.warning_label.text.contains("今天最多还能安排 5 次指导"), "同一课程超过五次时没有提示每日次数限制。")
	menu._on_reset_pressed()
	var course_ids := ["yoga_body", "basic_stamina", "core_strength", "stage_stamina"]
	for course_id in course_ids:
		menu._on_course_clicked(menu._get_course_by_id(course_id))
	menu._on_course_clicked(course)
	menu._on_course_clicked(menu._get_course_by_id("visual_basics"))
	_expect(menu._get_total_planned_count() == 5, "混合课程安排错误允许超过五次指导。")
	_expect(menu._planned_counts.size() == 4, "重复课程不应被错误统计成不同课程。")
	_expect(menu.warning_label.text.contains("今天最多还能安排 5 次指导"), "混合课程超过五次时没有提示每日次数限制。")

	menu._on_reset_pressed()
	profile.current_energy = 3
	menu._on_course_clicked(course)
	_expect(menu._get_total_planned_count() == 0, "精力不足时仍然选中了课程。")
	_expect(menu.warning_label.text.contains("精力不足"), "精力不足时没有在选择阶段提示原因。")

	profile.current_energy = 100
	time_manager.current_hour = 22
	time_manager.current_minute = 0
	menu._on_course_clicked(course)
	_expect(menu._get_total_planned_count() == 0, "时间不足时仍然选中了课程。")
	_expect(menu.warning_label.text.contains("时间不足"), "时间不足时没有在选择阶段提示原因。")

	profile.current_energy = 100
	time_manager.current_hour = 10
	time_manager.current_minute = 0
	menu._on_course_clicked(course)
	menu._on_course_clicked(course)
	menu._on_start_pressed()
	_expect(profile.current_energy == 92, "两次课程实际结算没有扣除 8 点精力。")
	_expect(time_manager.current_hour == 12 and time_manager.current_minute == 0, "两次课程实际结算没有推进 120 分钟。")
	_expect(profile.course_progress.get("stage_stamina", 0) == 20, "两次课程实际结算没有增加 20 点课程进度。")
	_expect(profile.stat_stamina >= 60.0 and profile.stat_stamina <= 100.0, "两次课程的体能收益超出预览范围 60~100。")
	_expect(profile.stat_rhythm >= 30.0 and profile.stat_rhythm <= 50.0, "两次课程的反应收益超出预览范围 30~50。")
	_expect(profile.get_daily_tutoring_count() == 2, "首次完成两次指导后没有记录当天累计次数。")
	menu._on_start_pressed()
	_expect(profile.current_energy == 92, "重复触发开始按钮导致精力被二次扣除。")
	_expect(time_manager.current_hour == 12 and time_manager.current_minute == 0, "重复触发开始按钮导致时间被二次推进。")
	_expect(profile.course_progress.get("stage_stamina", 0) == 20, "重复触发开始按钮导致课程进度被二次结算。")

	var second_menu = tutoring_menu_scene.instantiate()
	root.add_child(second_menu)
	await process_frame
	var second_course: Dictionary = second_menu._get_course_by_id("stage_stamina")
	for _index in 3:
		second_menu._on_course_clicked(second_course)
	second_menu._on_course_clicked(second_course)
	_expect(second_menu._get_total_planned_count() == 3, "第二次进入错误允许当天累计超过五次指导。")
	_expect(second_menu.warning_label.text.contains("今天最多还能安排 3 次指导"), "第二次进入没有提示当天剩余三次额度。")
	second_menu._on_start_pressed()
	_expect(profile.get_daily_tutoring_count() == 5, "两次指导结算后当天累计次数不是五次。")

	var third_menu = tutoring_menu_scene.instantiate()
	root.add_child(third_menu)
	await process_frame
	third_menu._on_course_clicked(third_menu._get_course_by_id("stage_stamina"))
	_expect(third_menu._get_total_planned_count() == 0, "当天完成五次指导后仍可继续选择课程。")
	_expect(third_menu.warning_label.text.contains("今天最多还能安排 0 次指导"), "当天额度耗尽时没有明确提示。")

	var quick_location = load("res://scripts/ui/map/core/quick_location_scene.gd").new()
	quick_location.current_interacting_npc_id = "jing"
	_expect(quick_location._is_action_locked("study"), "当天完成五次指导后静的课业指导入口没有锁定。")
	quick_location.current_interacting_npc_id = "shuo"
	_expect(not quick_location._is_action_locked("study"), "静的课业额度错误锁定了其他 NPC 的学习入口。")
	quick_location.free()
	var quick_action_button = load("res://scenes/ui/map/core/quick_action_button.tscn").instantiate()
	root.add_child(quick_action_button)
	await process_frame
	quick_action_button.setup("study", "课业指导", true)
	_expect(quick_action_button.disabled, "课业指导锁定按钮仍可点击。")
	_expect(quick_action_button.lock_icon.visible, "课业指导锁定按钮没有显示锁图标。")

	profile.current_energy = original_energy
	profile.course_progress = original_progress
	profile.tutoring_history = original_tutoring_history
	profile.stat_stamina = original_stamina
	profile.stat_rhythm = original_rhythm
	time_manager.current_hour = original_hour
	time_manager.current_minute = original_minute
	if is_instance_valid(menu):
		menu.queue_free()
	if is_instance_valid(second_menu):
		second_menu.queue_free()
	if is_instance_valid(third_menu):
		third_menu.queue_free()
	if is_instance_valid(quick_action_button):
		quick_action_button.queue_free()
	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("LIBRARY_TUTORING_COST_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("LIBRARY_TUTORING_COST_SMOKE: %s" % failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)