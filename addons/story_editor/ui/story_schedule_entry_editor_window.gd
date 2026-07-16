@tool
extends Window

const JsonService = preload("res://addons/story_editor/core/story_json_service.gd")
const Validator = preload("res://addons/story_editor/core/story_schedule_entry_validator.gd")
const TriggerSimulator = preload("res://addons/story_editor/core/story_trigger_simulator.gd")
const WINDOW_LAYOUT_PATH := "res://addons/story_editor/core/editor_window_layout.gd"
const DEFAULT_STORY_TIME_PATH := "res://assets/data/story/story_time.json"
const DEFAULT_MAP_PATH := "res://assets/data/map/core/map_data.json"

var story_time_path := DEFAULT_STORY_TIME_PATH
var map_path := DEFAULT_MAP_PATH
var story_time_data: Dictionary = {}
var map_data: Dictionary = {}
var saved_story_time_data: Dictionary = {}
var saved_map_data: Dictionary = {}
var selected_day_index := -1
var selected_location_id := ""
var selected_map_entry_index := -1
var undo_stack: Array[Dictionary] = []
var redo_stack: Array[Dictionary] = []
var diagnostics: Array[Dictionary] = []
var syncing_tree_selection := false

@onready var day_tree: Tree = %DayTree
@onready var map_tree: Tree = %MapTree
@onready var diagnostics_tree: Tree = %DiagnosticsTree
@onready var simulation_results: Tree = %SimulationResults


func _ready() -> void:
	close_requested.connect(hide)
	%RefreshButton.pressed.connect(refresh_editor)
	%SaveButton.pressed.connect(save_sources)
	%UndoButton.pressed.connect(undo)
	%RedoButton.pressed.connect(redo)
	%ApplyDayButton.pressed.connect(apply_day)
	%ApplyMapButton.pressed.connect(apply_map_entry)
	%AddMapEntryButton.pressed.connect(add_map_entry)
	%DeleteMapEntryButton.pressed.connect(delete_map_entry)
	%RunSimulationButton.pressed.connect(run_trigger_simulation)
	day_tree.item_selected.connect(_on_day_selected)
	map_tree.item_selected.connect(_on_map_selected)
	for period in ["上午", "下午", "傍晚", "夜晚"]:
		%SimPeriodSelect.add_item(period)
	_setup_trees()
	_set_day_editor_enabled(false)
	_set_map_editor_enabled(false)


func open_editor() -> void:
	(load(WINDOW_LAYOUT_PATH) as GDScript).new().open_window(self, Vector2i(1240, 800), Vector2i(920, 600))
	call_deferred("refresh_editor")


func refresh_editor() -> void:
	var story_result := JsonService.load_dictionary(story_time_path)
	var map_result := JsonService.load_dictionary(map_path)
	if not story_result.get("ok", false) or not map_result.get("ok", false):
		diagnostics = []
		if not story_result.get("ok", false):
			diagnostics.append({"severity": "error", "location": story_time_path, "message": story_result.get("error", "读取失败。")})
		if not map_result.get("ok", false):
			diagnostics.append({"severity": "error", "location": map_path, "message": map_result.get("error", "读取失败。")})
		_show_diagnostics()
		return
	load_sources(story_result.get("data", {}) as Dictionary, map_result.get("data", {}) as Dictionary)


func load_sources(story_time: Dictionary, map_source: Dictionary) -> void:
	story_time_data = story_time.duplicate(true)
	map_data = map_source.duplicate(true)
	saved_story_time_data = story_time_data.duplicate(true)
	saved_map_data = map_data.duplicate(true)
	selected_day_index = 0 if not _days().is_empty() else -1
	_select_first_map_entry()
	undo_stack.clear()
	redo_stack.clear()
	_refresh_all()


func select_day(day_index: int) -> void:
	if day_index < 0 or day_index >= _days().size() or not _days()[day_index] is Dictionary:
		selected_day_index = -1
		_set_day_editor_enabled(false)
		return
	selected_day_index = day_index
	var day := _days()[day_index] as Dictionary
	%DayTitle.text = "日程 #%d" % (day_index + 1)
	%DayOffsetSpin.value = int(day.get("day_offset", day_index))
	%AllDayEdit.text = _join_values(day.get("events", []))
	%MorningEdit.text = _join_values(day.get("morning_events", []))
	%AfternoonEdit.text = _join_values(day.get("afternoon_events", []))
	%EveningEdit.text = _join_values(day.get("evening_events", []))
	%NightEdit.text = _join_values(day.get("night_events", []))
	_set_day_editor_enabled(true)
	_select_day_tree_item(day_index)


func select_map_entry(location_id: String, entry_index: int) -> void:
	var stories := _map_stories(location_id)
	if location_id.is_empty() or entry_index < 0 or entry_index >= stories.size() or not stories[entry_index] is Dictionary:
		selected_location_id = ""
		selected_map_entry_index = -1
		_set_map_editor_enabled(false)
		return
	selected_location_id = location_id
	selected_map_entry_index = entry_index
	var story := stories[entry_index] as Dictionary
	%MapTitle.text = "%s / %s" % [location_id, str(story.get("id", "未命名入口"))]
	%MapIdEdit.text = str(story.get("id", ""))
	%MapPathEdit.text = str(story.get("trigger_script", ""))
	%MapOffsetsEdit.text = _join_values(story.get("day_offsets", []))
	%MapEventsEdit.text = _join_values(story.get("events", []))
	%MapWeatherEdit.text = _join_values(story.get("weather", []))
	%MapPeriodsEdit.text = _join_values(story.get("periods", []))
	%MinStageSpin.value = int(story.get("min_stage", 0))
	%MaxStageSpin.value = int(story.get("max_stage", -1))
	%PrioritySpin.value = int(story.get("priority", 0))
	%BadgeNpcsEdit.text = _join_values(story.get("badge_npcs", []))
	%BadgeTextEdit.text = str(story.get("badge_text", ""))
	_set_map_editor_enabled(true)
	_select_map_tree_item(location_id, entry_index)


func apply_day() -> bool:
	if selected_day_index < 0 or selected_day_index >= _days().size():
		return false
	_record_history()
	var days := _days()
	var day := (days[selected_day_index] as Dictionary).duplicate(true)
	day["day_offset"] = int(%DayOffsetSpin.value)
	_set_array_field(day, "events", _parse_strings(%AllDayEdit.text))
	_set_array_field(day, "morning_events", _parse_strings(%MorningEdit.text))
	_set_array_field(day, "afternoon_events", _parse_strings(%AfternoonEdit.text))
	_set_array_field(day, "evening_events", _parse_strings(%EveningEdit.text))
	_set_array_field(day, "night_events", _parse_strings(%NightEdit.text))
	days[selected_day_index] = day
	story_time_data["daily_data"] = days
	_refresh_after_edit()
	return true


func apply_map_entry() -> bool:
	if not _has_map_entry():
		return false
	_record_history()
	var stories := _map_stories(selected_location_id)
	var story := (stories[selected_map_entry_index] as Dictionary).duplicate(true)
	story["id"] = %MapIdEdit.text.strip_edges()
	story["trigger_script"] = %MapPathEdit.text.strip_edges()
	_set_array_field(story, "day_offsets", _parse_ints(%MapOffsetsEdit.text))
	_set_array_field(story, "events", _parse_strings(%MapEventsEdit.text))
	_set_array_field(story, "weather", _parse_strings(%MapWeatherEdit.text))
	_set_array_field(story, "periods", _parse_strings(%MapPeriodsEdit.text))
	_set_optional_int(story, "min_stage", int(%MinStageSpin.value), 0)
	_set_optional_int(story, "max_stage", int(%MaxStageSpin.value), -1)
	_set_optional_int(story, "priority", int(%PrioritySpin.value), 0)
	_set_array_field(story, "badge_npcs", _parse_strings(%BadgeNpcsEdit.text))
	var badge_text: String = %BadgeTextEdit.text.strip_edges()
	if badge_text.is_empty():
		story.erase("badge_text")
	else:
		story["badge_text"] = badge_text
	stories[selected_map_entry_index] = story
	_set_map_stories(selected_location_id, stories)
	_refresh_after_edit()
	return true


func add_map_entry() -> bool:
	if selected_location_id.is_empty():
		return false
	_record_history()
	var stories := _map_stories(selected_location_id)
	stories.append({"id": "new_story_entry", "trigger_script": "", "priority": 0})
	_set_map_stories(selected_location_id, stories)
	selected_map_entry_index = stories.size() - 1
	_refresh_after_edit()
	return true


func delete_map_entry() -> bool:
	if not _has_map_entry():
		return false
	_record_history()
	var stories := _map_stories(selected_location_id)
	stories.remove_at(selected_map_entry_index)
	_set_map_stories(selected_location_id, stories)
	selected_map_entry_index = mini(selected_map_entry_index, stories.size() - 1)
	_refresh_after_edit()
	return true


func undo() -> bool:
	if undo_stack.is_empty():
		return false
	redo_stack.append(_snapshot())
	_restore(undo_stack.pop_back())
	return true


func redo() -> bool:
	if redo_stack.is_empty():
		return false
	undo_stack.append(_snapshot())
	_restore(redo_stack.pop_back())
	return true


func save_sources() -> bool:
	diagnostics = Validator.validate(story_time_data, map_data)
	_show_diagnostics()
	if _has_errors() or not _is_dirty():
		_update_buttons()
		return false
	var story_result := JsonService.save_dictionary(story_time_path, story_time_data)
	if not story_result.get("ok", false):
		_add_save_error(story_time_path, story_result)
		return false
	var map_result := JsonService.save_dictionary(map_path, map_data)
	if not map_result.get("ok", false):
		_add_save_error(map_path, map_result)
		return false
	saved_story_time_data = story_time_data.duplicate(true)
	saved_map_data = map_data.duplicate(true)
	_update_buttons()
	return true


func run_trigger_simulation(event_registry_override: Dictionary = {}) -> Dictionary:
	var event_registry := event_registry_override
	if event_registry.is_empty():
		var registry_result := JsonService.load_dictionary("res://assets/data/events/event_registry.json")
		if registry_result.get("ok", false):
			event_registry = registry_result.get("data", {}) as Dictionary
	var context := {
		"day_offset": int(%SimDaySpin.value),
		"period": %SimPeriodSelect.get_item_text(%SimPeriodSelect.selected),
		"hour": int(%SimHourSpin.value),
		"weather": %SimWeatherEdit.text.strip_edges(),
		"location_id": %SimLocationEdit.text.strip_edges(),
		"stage": int(%SimStageSpin.value),
		"npc_stages": _parse_key_values(%SimNpcStagesEdit.text),
		"stats": _parse_key_values(%SimStatsEdit.text),
		"triggered_event_ids": _parse_strings(%SimTriggeredEdit.text),
		"consumed_map_entry_ids": _parse_strings(%SimConsumedMapEdit.text),
		"consumed_location_event_ids": _parse_strings(%SimConsumedLocationEdit.text)
	}
	var result := TriggerSimulator.simulate(event_registry, story_time_data, map_data, context)
	_show_simulation(result)
	return result


func _refresh_all() -> void:
	diagnostics = Validator.validate(story_time_data, map_data)
	_rebuild_day_tree()
	_rebuild_map_tree()
	_show_diagnostics()
	_update_summary()
	select_day(selected_day_index)
	select_map_entry(selected_location_id, selected_map_entry_index)
	_update_buttons()


func _refresh_after_edit() -> void:
	_refresh_all()


func _rebuild_day_tree() -> void:
	day_tree.clear()
	var root := day_tree.create_item()
	for day_index in _days().size():
		var day_value: Variant = _days()[day_index]
		var day := day_value as Dictionary if day_value is Dictionary else {}
		var item := day_tree.create_item(root)
		item.set_text(0, "第 %d 天" % int(day.get("day_offset", day_index)))
		item.set_text(1, "%d 个剧情" % _day_event_count(day))
		item.set_metadata(0, day_index)


func _rebuild_map_tree() -> void:
	map_tree.clear()
	var root := map_tree.create_item()
	var locations := _locations()
	for location_id_value in locations.keys():
		var location_id := str(location_id_value)
		var stories := _map_stories(location_id)
		if stories.is_empty():
			continue
		var group := map_tree.create_item(root)
		group.set_text(0, location_id)
		group.set_selectable(0, false)
		group.set_selectable(1, false)
		for entry_index in stories.size():
			var story_value: Variant = stories[entry_index]
			var story := story_value as Dictionary if story_value is Dictionary else {}
			var item := map_tree.create_item(group)
			item.set_text(0, str(story.get("id", "无效入口")))
			item.set_text(1, str(story.get("priority", 0)))
			item.set_metadata(0, {"location_id": location_id, "entry_index": entry_index})


func _show_diagnostics() -> void:
	diagnostics_tree.clear()
	var root := diagnostics_tree.create_item()
	for diagnostic in diagnostics:
		var item := diagnostics_tree.create_item(root)
		item.set_text(0, "错误" if diagnostic.get("severity") == "error" else "警告")
		item.set_text(1, str(diagnostic.get("location", "")))
		item.set_text(2, str(diagnostic.get("message", "")))


func _setup_trees() -> void:
	day_tree.set_column_title(0, "日期")
	day_tree.set_column_title(1, "入口")
	map_tree.set_column_title(0, "地点 / 入口")
	map_tree.set_column_title(1, "优先级")
	diagnostics_tree.set_column_title(0, "级别")
	diagnostics_tree.set_column_title(1, "位置")
	diagnostics_tree.set_column_title(2, "说明")
	simulation_results.set_column_title(0, "来源")
	simulation_results.set_column_title(1, "入口")
	simulation_results.set_column_title(2, "状态")
	simulation_results.set_column_title(3, "优先级/顺序")
	simulation_results.set_column_title(4, "失败原因")


func _update_summary() -> void:
	var schedule_count := 0
	for day_value in _days():
		if day_value is Dictionary:
			schedule_count += _day_event_count(day_value as Dictionary)
	var map_count := 0
	for location_id in _locations().keys():
		map_count += _map_stories(str(location_id)).size()
	%Summary.text = "%d 个日程入口 | %d 个地图入口 | %d 个错误" % [schedule_count, map_count, diagnostics.filter(func(item: Dictionary) -> bool: return item.get("severity") == "error").size()]


func _days() -> Array:
	return story_time_data.get("daily_data", []) as Array if story_time_data.get("daily_data", []) is Array else []


func _locations() -> Dictionary:
	return map_data.get("locations", {}) as Dictionary if map_data.get("locations", {}) is Dictionary else {}


func _map_stories(location_id: String) -> Array:
	var location_value: Variant = _locations().get(location_id, {})
	if not location_value is Dictionary:
		return []
	var stories_value: Variant = (location_value as Dictionary).get("scheduled_entry_stories", [])
	return (stories_value as Array).duplicate(true) if stories_value is Array else []


func _set_map_stories(location_id: String, stories: Array) -> void:
	var locations := _locations()
	var location := (locations.get(location_id, {}) as Dictionary).duplicate(true)
	if stories.is_empty():
		location.erase("scheduled_entry_stories")
	else:
		location["scheduled_entry_stories"] = stories
	locations[location_id] = location
	map_data["locations"] = locations


func _select_first_map_entry() -> void:
	selected_location_id = ""
	selected_map_entry_index = -1
	for location_id_value in _locations().keys():
		var location_id := str(location_id_value)
		if not _map_stories(location_id).is_empty():
			selected_location_id = location_id
			selected_map_entry_index = 0
			return


func _has_map_entry() -> bool:
	return not selected_location_id.is_empty() and selected_map_entry_index >= 0 and selected_map_entry_index < _map_stories(selected_location_id).size()


func _is_dirty() -> bool:
	return story_time_data != saved_story_time_data or map_data != saved_map_data


func _has_errors() -> bool:
	return diagnostics.any(func(item: Dictionary) -> bool: return item.get("severity") == "error")


func _snapshot() -> Dictionary:
	return {"story_time": story_time_data.duplicate(true), "map_data": map_data.duplicate(true), "day_index": selected_day_index, "location_id": selected_location_id, "entry_index": selected_map_entry_index}


func _record_history() -> void:
	undo_stack.append(_snapshot())
	redo_stack.clear()


func _restore(snapshot: Dictionary) -> void:
	story_time_data = (snapshot.get("story_time", {}) as Dictionary).duplicate(true)
	map_data = (snapshot.get("map_data", {}) as Dictionary).duplicate(true)
	selected_day_index = int(snapshot.get("day_index", -1))
	selected_location_id = str(snapshot.get("location_id", ""))
	selected_map_entry_index = int(snapshot.get("entry_index", -1))
	_refresh_all()


func _parse_strings(text: String) -> Array[String]:
	var result: Array[String] = []
	for value in text.split(","):
		var normalized := value.strip_edges()
		if not normalized.is_empty() and not result.has(normalized):
			result.append(normalized)
	return result


func _parse_ints(text: String) -> Array[int]:
	var result: Array[int] = []
	for value in _parse_strings(text):
		var number := int(value)
		if not result.has(number):
			result.append(number)
	return result


func _parse_key_values(text: String) -> Dictionary:
	var result := {}
	for pair in text.split(","):
		var parts := pair.split("=", false, 1)
		if parts.size() != 2:
			continue
		var key := parts[0].strip_edges()
		if not key.is_empty():
			result[key] = float(parts[1].strip_edges())
	return result


func _join_values(value: Variant) -> String:
	if not value is Array:
		return ""
	var texts: Array[String] = []
	for item in value:
		texts.append(str(item))
	return ", ".join(texts)


func _set_array_field(target: Dictionary, field: String, values: Array) -> void:
	if values.is_empty():
		target.erase(field)
	else:
		target[field] = values


func _set_optional_int(target: Dictionary, field: String, value: int, empty_value: int) -> void:
	if value == empty_value:
		target.erase(field)
	else:
		target[field] = value


func _day_event_count(day: Dictionary) -> int:
	var count := 0
	for field in Validator.EVENT_FIELDS:
		if day.get(field, []) is Array:
			count += (day.get(field, []) as Array).size()
	return count


func _set_day_editor_enabled(enabled: bool) -> void:
	%DayEditor.visible = enabled


func _set_map_editor_enabled(enabled: bool) -> void:
	%MapEditor.visible = enabled


func _update_buttons() -> void:
	%UndoButton.disabled = undo_stack.is_empty()
	%RedoButton.disabled = redo_stack.is_empty()
	%SaveButton.disabled = not _is_dirty() or _has_errors()
	%DeleteMapEntryButton.disabled = not _has_map_entry()
	%ApplyMapButton.disabled = not _has_map_entry()


func _add_save_error(path: String, result: Dictionary) -> void:
	diagnostics.append({"severity": "error", "location": path, "message": result.get("error", "保存失败。")})
	_show_diagnostics()
	_update_buttons()


func _show_simulation(result: Dictionary) -> void:
	simulation_results.clear()
	var root := simulation_results.create_item()
	var selected := result.get("selected", {}) as Dictionary
	var candidates: Array = []
	candidates.append_array(result.get("map_candidates", []) as Array)
	candidates.append_array(result.get("registry_candidates", []) as Array)
	for candidate_value in candidates:
		if not candidate_value is Dictionary:
			continue
		var candidate := candidate_value as Dictionary
		var item := simulation_results.create_item(root)
		item.set_text(0, "地图" if candidate.get("source_type") == "map_schedule" else "Registry")
		item.set_text(1, str(candidate.get("source_id", "")))
		var is_selected: bool = not selected.is_empty() and candidate.get("source_type") == selected.get("source_type") and candidate.get("source_id") == selected.get("source_id")
		item.set_text(2, "胜出" if is_selected else ("通过" if candidate.get("passed", false) else "失败"))
		item.set_text(3, str(candidate.get("priority", 0)))
		item.set_text(4, "；".join(candidate.get("failure_reasons", []) as Array))
	%ActiveEvents.text = "激活日程事件：%s" % str((result.get("context", {}) as Dictionary).get("active_events", []))
	if selected.is_empty():
		%SimulationSummary.text = "无入口满足当前上下文。"
	else:
		%SimulationSummary.text = "最终触发：%s / %s → %s" % ["地图定时入口" if selected.get("source_type") == "map_schedule" else "Event Registry", str(selected.get("source_id", "")), str(selected.get("target_path", ""))]


func _select_day_tree_item(day_index: int) -> void:
	var item := day_tree.get_root().get_first_child() if day_tree.get_root() != null else null
	while item != null:
		if int(item.get_metadata(0)) == day_index:
			if day_tree.get_selected() != item:
				syncing_tree_selection = true
				item.select(0)
				syncing_tree_selection = false
			return
		item = item.get_next()


func _select_map_tree_item(location_id: String, entry_index: int) -> void:
	var group := map_tree.get_root().get_first_child() if map_tree.get_root() != null else null
	while group != null:
		var item := group.get_first_child()
		while item != null:
			var metadata: Variant = item.get_metadata(0)
			if metadata is Dictionary and metadata.get("location_id") == location_id and int(metadata.get("entry_index", -1)) == entry_index:
				if map_tree.get_selected() != item:
					syncing_tree_selection = true
					item.select(0)
					syncing_tree_selection = false
				return
			item = item.get_next()
		group = group.get_next()


func _on_day_selected() -> void:
	if syncing_tree_selection:
		return
	var item := day_tree.get_selected()
	if item != null:
		select_day(int(item.get_metadata(0)))


func _on_map_selected() -> void:
	if syncing_tree_selection:
		return
	var item := map_tree.get_selected()
	if item != null and item.get_metadata(0) is Dictionary:
		var metadata := item.get_metadata(0) as Dictionary
		select_map_entry(str(metadata.get("location_id", "")), int(metadata.get("entry_index", -1)))