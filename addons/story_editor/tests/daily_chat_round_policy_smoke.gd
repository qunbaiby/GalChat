extends SceneTree

const DailyChatRoundPolicy = preload("res://scripts/dialogue/daily_chat_round_policy.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var cutoff_minutes := 23 * 60
	_expect(DailyChatRoundPolicy.get_unavailable_reason(3, 3, 22 * 60 + 39, 20, cutoff_minutes) == "", "可在 23:00 前完成的一轮被错误阻止。")
	_expect(DailyChatRoundPolicy.get_unavailable_reason(2, 3, 21 * 60, 20, cutoff_minutes) == "energy", "剩余行动力不足时没有返回 energy。")
	_expect(DailyChatRoundPolicy.get_unavailable_reason(20, 3, 22 * 60 + 40, 20, cutoff_minutes) == "late", "下一轮到达 23:00 时没有返回 late。")
	_expect(DailyChatRoundPolicy.get_unavailable_reason(2, 3, 22 * 60 + 40, 20, cutoff_minutes) == "energy", "行动力与时间同时不足时没有优先提示行动力不足。")
	if failures.is_empty():
		print("DAILY_CHAT_ROUND_POLICY_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("DAILY_CHAT_ROUND_POLICY_SMOKE: %s" % failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)