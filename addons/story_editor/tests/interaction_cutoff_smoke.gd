extends SceneTree

var failures: Array[String] = []
var original_hour := 0
var original_minute := 0
var original_energy := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_data_manager = root.get_node_or_null("GameDataManager")
	_expect(game_data_manager != null, "GameDataManager autoload 不可用。")
	if game_data_manager == null:
		_finish()
		return
	var manager = game_data_manager.interaction_manager
	var time_manager = game_data_manager.story_time_manager
	var profile = game_data_manager.profile
	original_hour = time_manager.current_hour
	original_minute = time_manager.current_minute
	original_energy = profile.current_energy

	profile.current_energy = 10
	time_manager.current_hour = 22
	time_manager.current_minute = 44
	_expect(manager.get_interaction_unavailable_reason("gift").is_empty(), "22:44 开始的 15 分钟互动被错误阻止。")

	time_manager.current_minute = 45
	_expect(str(manager.get_interaction_unavailable_reason("gift").get("reason", "")) == "late", "到达 23:00 的互动没有返回 late。")

	profile.current_energy = 1
	_expect(str(manager.get_interaction_unavailable_reason("gift").get("reason", "")) == "energy", "行动力与时间同时不足时没有优先返回 energy。")

	time_manager.current_hour = original_hour
	time_manager.current_minute = original_minute
	profile.current_energy = original_energy
	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("INTERACTION_CUTOFF_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("INTERACTION_CUTOFF_SMOKE: %s" % failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
