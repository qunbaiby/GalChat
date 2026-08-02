extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://scenes/ui/map/core/world_map_scene.tscn") as PackedScene
	_expect(scene != null, "世界地图场景无法加载。")
	if scene == null:
		_finish()
		return
	var world_map := scene.instantiate() as Control
	root.add_child(world_map)
	await process_frame
	await process_frame
	var background := world_map.get_node("Background") as TextureRect
	_expect(background.scale.distance_to(Vector2(0.85, 0.85)) < 0.001, "世界地图背景没有锁定为原尺寸的 85%。")
	var transition_blocker := world_map.get_node_or_null("AreaTransitionInputBlocker") as ColorRect
	_expect(transition_blocker != null and transition_blocker.color.a == 0.0, "世界地图场景缺少透明的区域切换输入阻挡层。")
	var area_focus := world_map.call("get_area_button_focus_entry", "qingyu_street") as Dictionary
	var area_shape_params := area_focus.get("shape_params", {}) as Dictionary
	_expect(float(area_shape_params.get("corner_radius", 0.0)) == 18.0, "地图区域引导没有返回 18px 圆角焦点。")
	var location_scene := load("res://scenes/ui/map/core/location_button.tscn") as PackedScene
	var test_location := location_scene.instantiate() as Control
	world_map.get_node("SubAreaContainer").add_child(test_location)
	test_location.set("location_id", "round_focus_smoke")
	await process_frame
	var location_focus := world_map.call("get_location_button_focus_entry", "round_focus_smoke") as Dictionary
	var location_shape_params := location_focus.get("shape_params", {}) as Dictionary
	_expect(float(location_shape_params.get("corner_radius", 0.0)) == 14.0, "地图地点引导没有返回 14px 圆角焦点。")
	var camera_position := world_map.call("_get_background_position_for_camera_offset", background, Vector2.ONE) as Vector2
	var displayed_size := background.size * Vector2(0.85, 0.85)
	var expected_visual_top_left := -Vector2(
		maxf(0.0, displayed_size.x - world_map.size.x),
		maxf(0.0, displayed_size.y - world_map.size.y)
	)
	var actual_visual_top_left := camera_position + background.pivot_offset * Vector2(0.15, 0.15)
	_expect(actual_visual_top_left.distance_to(expected_visual_top_left) < 0.1, "区域镜头范围没有按缩放后的背景尺寸计算。")
	var source_location := Vector2(100.0, 40.0)
	var button_size := Vector2(100.0, 118.0)
	var scaled_location := world_map.call("_get_scaled_location_position", source_location, button_size) as Vector2
	var canvas := world_map.get_node("SubAreaContainer") as Control
	var expected_location := canvas.size / 2.0 + (source_location + button_size / 2.0 - canvas.size / 2.0) * Vector2(0.85, 0.85) - button_size / 2.0
	_expect(scaled_location.distance_to(expected_location) < 0.1, "地点坐标没有围绕地图画布中心按 85% 缩放。")
	var edge_location := world_map.call("_get_scaled_location_position", Vector2(5000.0, 5000.0), button_size) as Vector2
	_expect(edge_location.x + button_size.x <= canvas.size.x + 0.1 and edge_location.y + button_size.y <= canvas.size.y + 0.1, "缩放后的地点按钮超出了地图画布。")
	var start_position := background.position
	var target_position := start_position + Vector2(80.0, 40.0)
	world_map.call("_play_area_fade_transition", "qingyu_street", target_position)
	await create_timer(0.14).timeout
	_expect(transition_blocker.visible and background.modulate.a < 0.95 and canvas.modulate.a < 0.95, "区域切换开始后地图与地点没有一起淡出。")
	_expect(background.position.distance_to(start_position) < 0.1, "地图尚未完全淡出时背景位置已经改变。")
	await create_timer(0.2).timeout
	_expect(background.position.distance_to(target_position) < 0.1, "地图完全淡出后没有在隐藏状态下切换到目标区域。")
	_expect(background.modulate.a < 0.5, "地图就位时旧区域没有充分淡出。")
	await create_timer(0.4).timeout
	_expect(not transition_blocker.visible and background.modulate.a > 0.99 and canvas.modulate.a > 0.99, "目标区域就位后没有完成淡入显示。")
	world_map.queue_free()
	await process_frame
	_finish()

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _finish() -> void:
	if failures.is_empty():
		print("WORLD_MAP_AREA_TRANSITION_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("WORLD_MAP_AREA_TRANSITION_SMOKE: %s" % failure)
	quit(1)
