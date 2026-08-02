extends SceneTree

const TRANSITION_SCENE := preload("res://scenes/ui/main/transitions/day_rest_transition.tscn")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var transition: Control = TRANSITION_SCENE.instantiate()
	root.add_child(transition)
	transition.night_enter_duration = 0.1
	transition.night_hold_duration = 0.1
	transition.dawn_duration = 0.1
	transition.morning_hold_duration = 0.1
	transition.exit_duration = 0.1
	transition.setup({
		"ending_date": "3月7日 · 星期六",
		"new_date": "3月8日 · 星期日",
		"weather": "晴天 · 22°C",
		"energy_text": "精力已恢复"
	})
	_expect(transition.get_node("NightContent/EndingDateLabel").text == "3月7日 · 星期六", "旧日期没有写入过渡场景。")
	_expect(transition.get_node("MorningContent/NewDateLabel").text == "3月8日 · 星期日", "次日日期没有写入过渡场景。")
	_expect(transition.get_node("MorningContent/WeatherRow/WeatherLabel").text == "晴天 · 22°C", "次日天气没有写入过渡场景。")
	var signal_state := {"midpoint_emitted": false}
	transition.midpoint_reached.connect(func() -> void: signal_state["midpoint_emitted"] = true)
	transition.play_transition()
	await transition.transition_completed
	_expect(bool(signal_state["midpoint_emitted"]), "晨景出现后没有发出中点信号。")
	_expect(transition.visible, "播放期间过渡场景意外隐藏。")
	transition.queue_free()
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("DAY_REST_TRANSITION_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("DAY_REST_TRANSITION_SMOKE: %s" % failure)
	quit(1)