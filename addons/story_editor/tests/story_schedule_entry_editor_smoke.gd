extends SceneTree

const WindowScene = preload("res://addons/story_editor/ui/story_schedule_entry_editor_window.tscn")
const JsonService = preload("res://addons/story_editor/core/story_json_service.gd")
const Validator = preload("res://addons/story_editor/core/story_schedule_entry_validator.gd")

const STORY_TIME_FIXTURE := "user://story_schedule_editor_time.json"
const MAP_FIXTURE := "user://story_schedule_editor_map.json"
const PIANO_PATH := "res://assets/data/story/scripts/main/luna_piano_practice.json"

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var real_time := JsonService.load_dictionary("res://assets/data/story/story_time.json")
	var real_map := JsonService.load_dictionary("res://assets/data/map/core/map_data.json")
	_expect(real_time.get("ok", false) and real_map.get("ok", false), "真实调度数据无法读取。")
	_expect(Validator.validate(real_time.get("data", {}) as Dictionary, real_map.get("data", {}) as Dictionary).is_empty(), "真实调度数据不应包含阻塞错误或冲突。")

	var story_fixture := {
		"root_unknown": "preserve-time-root",
		"daily_data": [{"day_offset": 4, "weather": "rainy", "morning_events": ["luna_piano_practice"], "day_unknown": "preserve-day"}]
	}
	var map_fixture := {
		"root_unknown": "preserve-map-root",
		"locations": {"concert_hall": {
			"name": "音乐馆",
			"location_unknown": "preserve-location",
			"scheduled_entry_stories": [{
				"id": "luna_piano_practice",
				"trigger_script": PIANO_PATH,
				"day_offsets": [4],
				"periods": ["上午"],
				"priority": 100,
				"entry_unknown": "preserve-entry"
			}]
		}}
	}
	_expect(JsonService.save_dictionary(STORY_TIME_FIXTURE, story_fixture).get("ok", false), "无法写入日程 fixture。")
	_expect(JsonService.save_dictionary(MAP_FIXTURE, map_fixture).get("ok", false), "无法写入地图 fixture。")
	var window := WindowScene.instantiate()
	window.story_time_path = STORY_TIME_FIXTURE
	window.map_path = MAP_FIXTURE
	root.add_child(window)
	await process_frame
	window.refresh_editor()
	await process_frame

	_expect(window.selected_day_index == 0, "未默认选择首个日程。")
	_expect(window.selected_location_id == "concert_hall" and window.selected_map_entry_index == 0, "未默认选择首个地图入口。")
	window.get_node("Root/Tabs/剧情日程/DayEditor/DayFields/MorningEdit").text = "luna_piano_practice, jing_library_guidance"
	_expect(window.apply_day(), "应用日程修改失败。")
	_expect(window.story_time_data.daily_data[0].morning_events.size() == 2, "日程事件数组没有写回。")
	_expect(window.story_time_data.daily_data[0].day_unknown == "preserve-day", "日程未知字段丢失。")
	window.get_node("Root/Tabs/地图入口/MapEditorScroll/MapEditor/MapFields/BadgeTextEdit").text = "主线"
	window.get_node("Root/Tabs/地图入口/MapEditorScroll/MapEditor/MapFields/BadgeNpcsEdit").text = "luna, jing"
	_expect(window.apply_map_entry(), "应用地图入口修改失败。")
	_expect(window.map_data.locations.concert_hall.scheduled_entry_stories[0].badge_npcs.size() == 2, "地图徽标 NPC 没有写回。")
	_expect(window.map_data.locations.concert_hall.scheduled_entry_stories[0].entry_unknown == "preserve-entry", "地图入口未知字段丢失。")
	_expect(window.undo(), "撤销地图入口修改失败。")
	_expect(not window.map_data.locations.concert_hall.scheduled_entry_stories[0].has("badge_text"), "撤销后地图字段未恢复。")
	_expect(window.redo(), "重做地图入口修改失败。")
	_expect(window.map_data.locations.concert_hall.scheduled_entry_stories[0].badge_text == "主线", "重做后地图字段未恢复。")
	window.get_node("Root/Tabs/触发模拟/ContextFields/SimDaySpin").value = 4
	window.get_node("Root/Tabs/触发模拟/ContextFields/SimLocationEdit").text = "concert_hall"
	window.get_node("Root/Tabs/触发模拟/ContextFields/SimWeatherEdit").text = "rainy"
	var simulation: Dictionary = window.run_trigger_simulation({"events": [{"event_id": "fallback", "event_type": "auto_trigger", "conditions": [{"type": "location", "value": "concert_hall"}], "trigger_script": PIANO_PATH}]})
	_expect(simulation.selected.source_type == "map_schedule" and simulation.selected.source_id == "luna_piano_practice", "模拟器没有优先选择匹配的地图入口。")
	_expect(window.get_node("Root/Tabs/触发模拟/SimulationSummary").text.contains("luna_piano_practice"), "模拟摘要未显示胜出入口。")
	_expect(window.get_node("Root/Tabs/触发模拟/SimulationResults").get_root().get_child_count() == 2, "模拟结果树未展示地图和 Registry 候选。")
	_expect(window.save_sources(), "合法调度修改未能保存。")
	var saved_time := JsonService.load_dictionary(STORY_TIME_FIXTURE).get("data", {}) as Dictionary
	var saved_map := JsonService.load_dictionary(MAP_FIXTURE).get("data", {}) as Dictionary
	_expect(saved_time.root_unknown == "preserve-time-root" and saved_time.daily_data[0].day_unknown == "preserve-day", "保存后日程未知字段丢失。")
	_expect(saved_map.root_unknown == "preserve-map-root" and saved_map.locations.concert_hall.location_unknown == "preserve-location", "保存后地图未知字段丢失。")

	window.get_node("Root/Tabs/地图入口/MapEditorScroll/MapEditor/MapFields/MinStageSpin").value = 5
	window.get_node("Root/Tabs/地图入口/MapEditorScroll/MapEditor/MapFields/MaxStageSpin").value = 2
	_expect(window.apply_map_entry(), "应用非法阶段范围失败。")
	_expect(window.diagnostics.any(func(item: Dictionary) -> bool: return item.get("code") == "invalid_stage_range"), "非法阶段范围没有产生即时诊断。")
	_expect(not window.save_sources(), "存在阻塞错误时仍允许保存调度数据。")

	window.queue_free()
	await process_frame
	if failures.is_empty():
		print("STORY_SCHEDULE_ENTRY_EDITOR_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("STORY_SCHEDULE_ENTRY_EDITOR_SMOKE: %s" % failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)