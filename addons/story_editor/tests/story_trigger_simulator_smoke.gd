extends SceneTree

const Simulator = preload("res://addons/story_editor/core/story_trigger_simulator.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var story_time := {"daily_data": [{"day_offset": 2, "events": ["base"], "morning_events": ["morning_story"]}]}
	var map_data := {"locations": {"library": {"scheduled_entry_stories": [
		{"id": "low", "trigger_script": "res://low.json", "events": ["morning_story"], "periods": ["上午"], "priority": 10},
		{"id": "high", "trigger_script": "res://high.json", "events": ["morning_story"], "weather": ["rainy"], "priority": 100}
	]}}}
	var registry := {"events": [
		{"event_id": "first_registry", "event_type": "auto_trigger", "conditions": [{"type": "location", "value": "library"}, {"type": "npc_stage", "npc_id": "jing", "min_stage": 2}], "trigger_script": "res://registry_first.json"},
		{"event_id": "second_registry", "event_type": "auto_trigger", "conditions": [{"type": "location", "value": "library"}], "trigger_script": "res://registry_second.json"}
	]}
	var context := {"day_offset": 2, "period": "上午", "weather": "rainy", "location_id": "library", "stage": 1, "hour": 9, "npc_stages": {"jing": 2}, "stats": {}}
	var result := Simulator.simulate(registry, story_time, map_data, context)
	_expect(result.context.active_events == ["base", "morning_story"], "未按全天加当前时段生成激活事件。")
	_expect(result.map_candidates[0].source_id == "high", "地图候选未按优先级降序排列。")
	_expect(result.selected.source_type == "map_schedule" and result.selected.source_id == "high", "地图胜出者未优先于 Registry。")

	context.weather = "sunny"
	map_data.locations.library.scheduled_entry_stories[0].periods = ["下午"]
	var fallback := Simulator.simulate(registry, story_time, map_data, context)
	_expect(fallback.map_candidates.all(func(candidate: Dictionary) -> bool: return not candidate.passed), "地图失败候选仍被判定通过。")
	_expect(fallback.selected.source_type == "event_registry" and fallback.selected.source_id == "first_registry", "地图无匹配时未选择首个通过的 Registry 入口。")

	context.npc_stages.jing = 0
	var second := Simulator.simulate(registry, story_time, map_data, context)
	_expect(second.registry_candidates[0].failure_reasons.any(func(reason: String) -> bool: return reason.contains("NPC jing")), "未输出 NPC 阶段失败原因。")
	_expect(second.selected.source_id == "second_registry", "首个 Registry 失败后未按数组顺序选择下一项。")

	context.consumed_map_entry_ids = ["low", "high"]
	context.consumed_location_event_ids = ["first_registry", "second_registry"]
	registry.events.append({"event_id": "global_only", "event_type": "auto_trigger", "conditions": [], "trigger_script": "res://global.json"})
	var consumed := Simulator.simulate(registry, story_time, map_data, context)
	_expect(consumed.selected.is_empty(), "当天已消费入口或无 location 条件的 Registry 事件仍被地点进入模拟选中。")
	_expect(consumed.registry_candidates[2].failure_reasons.has("地点进入回退要求 location 条件"), "地点进入回退未拒绝无 location 条件事件。")

	if failures.is_empty():
		print("STORY_TRIGGER_SIMULATOR_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("STORY_TRIGGER_SIMULATOR_SMOKE: %s" % failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)