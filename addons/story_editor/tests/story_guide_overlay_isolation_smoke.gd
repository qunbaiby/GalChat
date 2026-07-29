extends SceneTree

class MockMainScene:
	extends Node

	func is_main_ui_ready_for_guide() -> bool:
		return true

	func get_main_action_focus_entry() -> Dictionary:
		return {
			"rect": Rect2(100.0, 100.0, 120.0, 48.0),
			"shape": "trapezoid_left",
			"shape_params": {"cutout_slant": 0.35},
			"cutout_polygon": PackedVector2Array([
				Vector2(116.8, 100.0),
				Vector2(220.0, 100.0),
				Vector2(220.0, 148.0),
				Vector2(100.0, 148.0)
			])
		}

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var guide_manager = root.get_node_or_null("GuideManager")
	_expect(guide_manager != null, "GuideManager 未初始化。")
	if guide_manager == null:
		_finish()
		return

	await process_frame
	await process_frame
	var overlay: Control = guide_manager._overlay
	_expect(is_instance_valid(overlay), "引导遮罩未初始化。")
	if not is_instance_valid(overlay):
		_finish()
		return

	var original_state: Dictionary = guide_manager._state.duplicate(true)
	var original_main_scene_ref: WeakRef = guide_manager._main_scene_ref
	var original_activity_panel_ref: WeakRef = guide_manager._activity_panel_ref
	var mock_main_scene := MockMainScene.new()
	root.add_child(mock_main_scene)
	guide_manager._state["active_guide_id"] = "schedule_onboarding_guide"
	guide_manager._state["current_step_index"] = 1
	guide_manager._main_scene_ref = weakref(mock_main_scene)
	guide_manager._activity_panel_ref = null
	guide_manager.refresh_current_step_display()
	_expect(overlay.visible, "读档恢复到未打开的行程界面步骤时，引导没有显示继续入口。")
	_expect(int(guide_manager._state.get("current_step_index", -1)) == 1, "显示继续入口时错误推进了引导断点。")
	_expect(bool(overlay._panel_root.mouse_filter == Control.MOUSE_FILTER_IGNORE), "继续入口遮罩拦截了行程安排按钮。")
	_expect(overlay._focus_rects == [Rect2(100.0, 100.0, 120.0, 48.0)], "继续入口高亮范围没有沿用主界面按钮轮廓。")
	_expect(str(overlay._focus_entries[0].get("shape", "")) == "trapezoid_left", "继续入口丢失了主行动按钮的梯形高亮形状。")
	_expect((overlay._focus_entries[0].get("cutout_polygon", PackedVector2Array()) as PackedVector2Array).size() == 4, "继续入口丢失了主行动按钮的梯形挖孔轮廓。")
	mock_main_scene.queue_free()
	guide_manager._main_scene_ref = original_main_scene_ref
	guide_manager._activity_panel_ref = original_activity_panel_ref

	guide_manager._state["active_guide_id"] = "restored_guide"
	guide_manager._state["current_step_index"] = 3
	overlay.show()

	guide_manager.on_story_scene_ready()

	_expect(not overlay.visible, "进入剧情场景后，引导遮罩仍在拦截输入。")
	_expect(str(guide_manager._state.get("active_guide_id", "")) == "restored_guide", "挂起遮罩时错误清除了活动引导。")
	_expect(int(guide_manager._state.get("current_step_index", -1)) == 3, "挂起遮罩时错误修改了引导步骤。")
	guide_manager._state = original_state
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("STORY_GUIDE_OVERLAY_ISOLATION_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("STORY_GUIDE_OVERLAY_ISOLATION_SMOKE: %s" % failure)
	quit(1)
