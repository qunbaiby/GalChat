extends SceneTree

const ENVIRONMENT_SCENE := "res://addons/romestead_weather_free/weather_system.tscn"
const DETAILED_TIME_PERIOD_SCRIPT := preload("res://scripts/data/detailed_time_period.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene: PackedScene = load(ENVIRONMENT_SCENE)
	_expect(scene != null, "无法加载环境系统场景。")
	if scene == null:
		_finish()
		return
	var environment: Node = scene.instantiate()
	var samples := {
		"午夜": environment.get_day_night_tint(0.0),
		"深夜": environment.get_day_night_tint(2.0),
		"黎明前": environment.get_day_night_tint(4.0),
		"黎明": environment.get_day_night_tint(6.0),
		"上午": environment.get_day_night_tint(8.0),
		"午前": environment.get_day_night_tint(10.0),
		"正午": environment.get_day_night_tint(12.0),
		"午后": environment.get_day_night_tint(14.0),
		"下午": environment.get_day_night_tint(16.0),
		"黄昏": environment.get_day_night_tint(18.0),
		"入夜": environment.get_day_night_tint(20.0),
		"夜深": environment.get_day_night_tint(22.0),
	}
	for period_name in samples:
		_expect((samples[period_name] as Color).a > 0.0, "%s 没有配置昼夜叠色。" % period_name)
	var names: Array = samples.keys()
	for index in range(names.size() - 1):
		var current: Color = samples[names[index]]
		var next: Color = samples[names[index + 1]]
		_expect(_color_distance(current, next) > 0.08, "%s 与 %s 的变化不够明显。" % [names[index], names[index + 1]])
	_expect((samples["深夜"] as Color).a >= 0.8, "深夜覆盖强度不足 80%。")
	_expect((samples["深夜"] as Color).a > (samples["正午"] as Color).a * 20.0, "深夜与正午的明暗差异不足。")
	var expected_labels := ["午夜", "深夜", "黎明", "清晨", "早晨", "上午", "中午", "午后", "下午", "黄昏", "晚上", "夜深"]
	var detailed_time_period := DETAILED_TIME_PERIOD_SCRIPT.new()
	for index in range(expected_labels.size()):
		var sample_hour: int = index * 2
		_expect(detailed_time_period.get_label(sample_hour) == expected_labels[index], "%02d:00 的细分时段不是 %s。" % [sample_hour, expected_labels[index]])
	environment.free()
	_finish()


func _color_distance(left: Color, right: Color) -> float:
	return Vector4(left.r, left.g, left.b, left.a).distance_to(Vector4(right.r, right.g, right.b, right.a))


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("DAY_NIGHT_TINT_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("DAY_NIGHT_TINT_SMOKE: %s" % failure)
	quit(1)