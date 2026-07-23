extends SceneTree

const Repository = preload("res://scripts/data/concern_template_repository.gd")
const Compiler = preload("res://scripts/data/concern_template_compiler.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var templates: Array[Dictionary] = [
		_template("zeta", "*", 20, 0),
		_template("beta", "luna", 20, 1),
		_template("alpha", "luna", 20, 1),
		_template("highest", "luna", 30, 0)
	]
	var context := {
		"character_id": "luna",
		"character_name": "Luna",
		"weekday": 6,
		"time_period": "evening",
		"stage": 3,
		"intimacy": 50.0,
		"trust": 50.0,
		"day_offset": 12
	}
	var resolved := Repository.resolve_template(templates, context)
	_expect(str(resolved.get("template_id", "")) == "highest", "没有优先选择最高 priority 模板。")
	templates.pop_back()
	resolved = Repository.resolve_template(templates, context)
	_expect(str(resolved.get("template_id", "")) == "alpha", "同优先级时没有按角色、具体度和 ID 确定性排序。")
	var state := {"alpha": {"last_started_day": 12}, "beta": {"last_started_day": 12}}
	resolved = Repository.resolve_template(templates, context, state)
	_expect(str(resolved.get("template_id", "")) == "zeta", "冷却中的模板仍被选中。")

	var disk_templates := Repository.scan_templates()
	_expect(not disk_templates.is_empty(), "没有扫描到默认心事模板。")
	if not disk_templates.is_empty():
		var script := Compiler.compile(disk_templates[0], context)
		_expect(bool(script.get("runtime_generated", false)), "心事模板没有编译为运行时剧情。")
		_expect(str(script.get("story_category", "")) == "concern_template", "心事剧情分类错误。")
		var events: Array = ((script.get("chapters", {}) as Dictionary).get("start", {}) as Dictionary).get("events", [])
		_expect(events.size() >= 3, "编译结果缺少开场或 guided AI 事件。")
		if not events.is_empty():
			var guided: Dictionary = events[events.size() - 1]
			_expect(str(guided.get("type", "")) == "guided_ai_chat", "最后一个事件不是 guided_ai_chat。")
			_expect(not bool(guided.get("show_entry_line", true)), "心事模板没有关闭统一开场台词。")

	if failures.is_empty():
		print("CONCERN_TEMPLATE_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("CONCERN_TEMPLATE_SMOKE: %s" % failure)
	quit(1)


func _template(template_id: String, character_id: String, priority: int, min_stage: int) -> Dictionary:
	return {
		"template_id": template_id,
		"title": template_id,
		"character_id": character_id,
		"enabled": true,
		"priority": priority,
		"conditions": {"weekdays": [6], "min_stage": min_stage},
		"availability": {"cooldown_days": 2},
		"intro_events": [{"speaker": "旁白", "content": "测试"}],
		"guided_ai_policy": {
			"narrative_anchor": "测试锚点",
			"scene_objective": "测试目标",
			"max_player_rounds": 3
		}
	}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
