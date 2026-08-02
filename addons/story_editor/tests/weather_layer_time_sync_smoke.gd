extends SceneTree

const ENVIRONMENT_SCENE := "res://addons/romestead_weather_free/weather_system.tscn"
const BACKGROUND_SCENE := "res://scenes/ui/main/backgrounds/locations/default_room_bg.tscn"

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(320, 180)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	root.add_child(viewport)
	var root_control := Control.new()
	root_control.size = Vector2(viewport.size)
	viewport.add_child(root_control)

	var background: Control = (load(BACKGROUND_SCENE) as PackedScene).instantiate() as Control
	root_control.add_child(background)
	var weather_layer := background.get_node("WeatherLayer") as Control

	var environment: Node = (load(ENVIRONMENT_SCENE) as PackedScene).instantiate()
	viewport.add_child(environment)
	environment.time_running = false
	environment.enable_weather_spawning = false
	environment.set_overlay_target(weather_layer)
	await process_frame
	await process_frame

	var day_night_layer := weather_layer.get_node_or_null("DayNightTintLayer") as ColorRect
	var overlay := weather_layer.get_node_or_null("WeatherEffectLayer") as Control
	_expect(day_night_layer != null, "昼夜底色层没有挂载到 WeatherLayer。")
	_expect(overlay != null, "天气效果层没有挂载到 WeatherLayer。")
	if overlay != null:
		_expect(overlay.size.x > 0.0 and overlay.size.y > 0.0, "环境 overlay 尺寸为零。")
		_expect(overlay.visible, "环境 overlay 未显示。")

	environment.set_day_and_hour(0, 12.0)
	await _wait_for_render()
	var noon_tint: Color = environment.get_day_night_tint()
	var noon_layer_color: Color = day_night_layer.color
	environment.set_day_and_hour(0, 21.0)
	await _wait_for_render()
	var night_tint: Color = environment.get_day_night_tint()
	var night_layer_color: Color = day_night_layer.color
	_expect(_color_distance(noon_tint, night_tint) > 0.2, "12:00 与 21:00 的 WeatherLayer 叠色差异不足。")
	_expect(night_tint.a > noon_tint.a * 4.0, "21:00 的暗色覆盖强度没有明显高于正午。")
	_expect(_color_distance(noon_layer_color, night_layer_color) > 0.2, "昼夜底色层在 12:00 与 21:00 没有明显变化。")
	_expect(night_layer_color.a > noon_layer_color.a * 4.0, "昼夜底色层在 21:00 没有显著加深。")
	_expect(day_night_layer.get_index() < overlay.get_index(), "天气效果层没有叠加在昼夜底色层之上。")

	environment.queue_free()
	viewport.queue_free()
	_finish()


func _wait_for_render() -> void:
	await process_frame
	await process_frame
	await process_frame


func _color_distance(left: Color, right: Color) -> float:
	return Vector4(left.r, left.g, left.b, left.a).distance_to(Vector4(right.r, right.g, right.b, right.a))


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("WEATHER_LAYER_TIME_SYNC_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("WEATHER_LAYER_TIME_SYNC_SMOKE: %s" % failure)
	quit(1)