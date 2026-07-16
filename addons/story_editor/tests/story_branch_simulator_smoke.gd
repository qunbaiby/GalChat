extends SceneTree

const BranchSimulator = preload("res://addons/story_editor/core/story_branch_simulator.gd")

var failures: Array[String] = []


func _initialize() -> void:
	var story := {
		"script_id": "branch_simulator_smoke",
		"chapters": {
			"start": {"events": [
				{"type": "set_variable", "var_name": "visited", "var_value": true},
				{"type": "choice", "options": [
					{"id": "trust", "text": "信任", "effects": {"trust": 3}, "target_chapter": "trust_end"},
					{"id": "intimacy", "text": "亲近", "effects": {"intimacy": 2}, "target_chapter": "intimacy_end"}
				]}
			]},
			"trust_end": {"events": [{"type": "jump", "target_chapter": "end"}]},
			"intimacy_end": {"events": [{"type": "jump", "target_chapter": "end"}]}
		}
	}
	var results := BranchSimulator.simulate(story, {"seed": 7})
	_expect(results.size() == 2, "模拟器没有生成两条 Choice 路径。")
	for result in results:
		_expect(str(result.get("status", "")) == "ended", "分支没有运行到结束。")
		_expect((result.get("choices", []) as Array).size() == 1, "分支选择没有且仅执行一次。")
		var variables := result.get("variables", {}) as Dictionary
		_expect(variables.get("seed") == 7 and variables.get("visited") == true, "变量状态没有正确传播。")
	var first_effects := (results[0].get("effects", {}) as Dictionary) if not results.is_empty() else {}
	var second_effects := (results[1].get("effects", {}) as Dictionary) if results.size() > 1 else {}
	_expect(float(first_effects.get("trust", 0.0)) == 3.0, "第一条分支效果没有准确累计一次。")
	_expect(float(second_effects.get("intimacy", 0.0)) == 2.0, "第二条分支效果没有准确累计一次。")

	var loop_story := {"chapters": {"start": {"events": [{"type": "jump", "target_chapter": "start"}]}}}
	var loop_results := BranchSimulator.simulate(loop_story)
	_expect(loop_results.size() == 1 and str(loop_results[0].get("status", "")) == "loop", "模拟器没有识别循环分支。")

	if failures.is_empty():
		print("STORY_BRANCH_SIMULATOR_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("STORY_BRANCH_SIMULATOR_SMOKE: %s" % failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)