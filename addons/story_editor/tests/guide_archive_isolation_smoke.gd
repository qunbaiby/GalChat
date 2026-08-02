extends SceneTree

const ARCHIVE_A := "guide_archive_isolation_a"
const ARCHIVE_B := "guide_archive_isolation_b"
const GUIDE_ID := "schedule_onboarding_guide"

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_data_manager := root.get_node_or_null("GameDataManager")
	var guide_manager := root.get_node_or_null("GuideManager")
	var save_manager = game_data_manager.save_manager if game_data_manager != null else null
	_expect(game_data_manager != null and guide_manager != null and save_manager != null, "引导存档隔离测试依赖未初始化。")
	if game_data_manager == null or guide_manager == null or save_manager == null:
		_finish()
		return

	var original_archive_id: String = str(game_data_manager.get_active_archive_id())
	save_manager.delete_save(ARCHIVE_A)
	save_manager.delete_save(ARCHIVE_B)
	var steps: Array = (guide_manager._guide_defs.get(GUIDE_ID, {}) as Dictionary).get("steps", [])
	var step_a := _find_step_index(steps, "choose_topic_after_goal")
	var step_b := _find_step_index(steps, "explain_wechat_fixed_conversation")
	_expect(step_a >= 0 and step_b >= 0, "无法定位引导隔离测试步骤。")

	_expect(save_manager.prepare_empty_archive(ARCHIVE_A, "引导隔离 A"), "无法创建引导隔离档案 A。")
	guide_manager._state["active_guide_id"] = GUIDE_ID
	guide_manager._state["current_step_index"] = step_a
	var completed_a: Array[String] = ["completed_only_in_a"]
	guide_manager._state["completed_guides"] = completed_a
	guide_manager._state["feature_unlocks"] = {"feature_only_in_a": true}
	_expect(guide_manager._save_state(), "档案 A 引导状态保存失败。")

	_expect(save_manager.prepare_empty_archive(ARCHIVE_B, "引导隔离 B"), "无法创建引导隔离档案 B。")
	_expect(guide_manager.get_active_guide_id() == "", "新档 B 继承了 A 的活动引导。")
	_expect((guide_manager._state.get("completed_guides", []) as Array).is_empty(), "新档 B 继承了 A 的完成列表。")
	_expect((guide_manager._state.get("feature_unlocks", {}) as Dictionary).is_empty(), "新档 B 继承了 A 的功能解锁。")
	guide_manager._state["active_guide_id"] = GUIDE_ID
	guide_manager._state["current_step_index"] = step_b
	var completed_b: Array[String] = ["completed_only_in_b"]
	guide_manager._state["completed_guides"] = completed_b
	guide_manager._state["feature_unlocks"] = {"feature_only_in_b": true}
	_expect(guide_manager._save_state(), "档案 B 引导状态保存失败。")

	guide_manager._advance_step_if_context_matches(ARCHIVE_A, GUIDE_ID, step_a)
	_expect(int(guide_manager._state.get("current_step_index", -1)) == step_b, "A 的延迟推进污染了 B 的引导断点。")
	guide_manager._loaded_archive_id = ARCHIVE_A
	guide_manager._state["current_step_index"] = step_a + 1
	_expect(not guide_manager._save_state(), "旧档内存上下文被写入当前档案 B。")
	guide_manager.reload_for_current_archive()
	_expect(guide_manager.get_current_step_id() == "explain_wechat_fixed_conversation", "拒绝旧档写入后 B 的引导断点发生变化。")

	_expect(save_manager.load_archive(ARCHIVE_A), "无法切回引导隔离档案 A。")
	_expect(guide_manager.get_current_step_id() == "choose_topic_after_goal", "档案 A 没有恢复独立引导断点。")
	_expect((guide_manager._state.get("completed_guides", []) as Array).has("completed_only_in_a"), "档案 A 没有恢复独立完成列表。")
	_expect(bool((guide_manager._state.get("feature_unlocks", {}) as Dictionary).get("feature_only_in_a", false)), "档案 A 没有恢复独立功能解锁。")
	_expect(not (guide_manager._state.get("completed_guides", []) as Array).has("completed_only_in_b"), "档案 A 混入了 B 的完成列表。")

	_expect(save_manager.load_archive(ARCHIVE_B), "无法切回引导隔离档案 B。")
	_expect(guide_manager.get_current_step_id() == "explain_wechat_fixed_conversation", "档案 B 没有恢复独立引导断点。")
	_expect((guide_manager._state.get("completed_guides", []) as Array).has("completed_only_in_b"), "档案 B 没有恢复独立完成列表。")
	_expect(bool((guide_manager._state.get("feature_unlocks", {}) as Dictionary).get("feature_only_in_b", false)), "档案 B 没有恢复独立功能解锁。")
	_expect(not (guide_manager._state.get("completed_guides", []) as Array).has("completed_only_in_a"), "档案 B 混入了 A 的完成列表。")

	save_manager.delete_save(ARCHIVE_A)
	save_manager.delete_save(ARCHIVE_B)
	if original_archive_id != "" and save_manager.load_archive(original_archive_id):
		pass
	else:
		game_data_manager.set_active_archive_id(original_archive_id, true)
		game_data_manager.reload_active_archive_data()
	_finish()


func _find_step_index(steps: Array, step_id: String) -> int:
	for index in range(steps.size()):
		var step: Variant = steps[index]
		if step is Dictionary and str((step as Dictionary).get("id", "")) == step_id:
			return index
	return -1


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("GUIDE_ARCHIVE_ISOLATION_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("GUIDE_ARCHIVE_ISOLATION_SMOKE: %s" % failure)
	quit(1)