extends SceneTree

const RUNTIME_PATH := "res://scripts/data/chat_scene_state_runtime.gd"

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var runtime_script: GDScript = load(RUNTIME_PATH)
	_expect(runtime_script != null and runtime_script.can_instantiate(), "无法加载场景状态 runtime。")
	if runtime_script == null or not runtime_script.can_instantiate():
		_finish()
		return
	var runtime = runtime_script.new()
	var realized_turn := {"segments": [{"action": {"persistent_effect": {
		"event_type": "stance_change",
		"target_id": "character",
		"status": "completed",
		"description": "她保持抬眼直视你的姿态。"
	}}}]}
	var first_commit: Dictionary = runtime.apply_realized_turn(realized_turn)
	_expect(bool(first_commit.get("changed", false)), "首次持续效果没有改变现场。")
	_expect(int(first_commit.get("snapshot", {}).get("revision", 0)) == 1, "首次提交没有递增 revision。")
	var duplicate_commit: Dictionary = runtime.apply_realized_turn(realized_turn)
	_expect(not bool(duplicate_commit.get("changed", true)), "重复效果不应改变现场。")
	_expect(int(duplicate_commit.get("snapshot", {}).get("revision", 0)) == 1, "重复效果错误递增 revision。")
	var recovered: Dictionary = runtime.recover_from_history([{"scene_state_snapshot": first_commit.get("snapshot", {})}])
	_expect(int(recovered.get("revision", 0)) == 1, "无法从已接受历史恢复 revision。")
	_expect(str(recovered.get("effects", {}).get("stance_change", {}).get("description", "")) == "她保持抬眼直视你的姿态。", "无法恢复持续现场事实。")
	_expect(runtime.build_prompt_block().contains("scene_state"), "场景状态没有形成规范上下文块。")
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("CHAT_SCENE_STATE_RUNTIME_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("CHAT_SCENE_STATE_RUNTIME_SMOKE: %s" % failure)
	quit(1)