extends SceneTree

const Scanner = preload("res://addons/story_editor/core/fixed_voice_call_scanner.gd")
const Validator = preload("res://addons/story_editor/core/fixed_voice_call_validator.gd")
const ResourceCatalog = preload("res://addons/story_editor/core/story_resource_catalog.gd")
const JsonService = preload("res://addons/story_editor/core/story_json_service.gd")
const CatalogScene = preload("res://addons/story_editor/ui/fixed_voice_call_catalog_window.tscn")

const TEMP_PATH := "user://fixed_voice_call_editor_smoke.json"

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var calls := Scanner.scan()
	_expect(calls.size() == 2, "真实固定来电数量应为 2。")
	var line_count := 0
	var reference_count := 0
	for call in calls:
		line_count += int(call.get("line_count", 0))
		reference_count += (call.get("references", []) as Array).size()
	_expect(line_count == 13, "真实固定来电台词总数应为 13。")
	_expect(reference_count == 0, "当前固定来电不应已有剧情引用。")
	var resource_catalog := ResourceCatalog.build()
	var character_ids: Array[String] = []
	for character in resource_catalog.get("character", []):
		character_ids.append(str((character as Dictionary).get("id", "")))
	_expect(character_ids.has("jing") and character_ids.has("ling"), "角色 catalog 必须使用文件名作为运行时 ID。")
	var load_result := Scanner.load_calls()
	_expect(load_result.get("ok", false), "无法加载固定来电根数组。")
	if load_result.get("ok", false):
		var fixture := (load_result.get("data", []) as Array).duplicate(true)
		(fixture[0] as Dictionary)["smoke_unknown_call"] = {"preserve": true}
		var diagnostics := Validator.validate(fixture, {"character_ids": character_ids}, Scanner.scan_story_references())
		_expect(diagnostics.is_empty(), "真实固定来电应通过校验。")
		var bad_calls := fixture.duplicate(true)
		(bad_calls[1] as Dictionary)["id"] = str((bad_calls[0] as Dictionary).get("id", ""))
		(bad_calls[0] as Dictionary)["char_id"] = "missing_character"
		((bad_calls[0] as Dictionary).get("lines", []) as Array)[0] = ""
		var bad_diagnostics := Validator.validate(bad_calls, {"character_ids": character_ids}, {"missing_call": [{"story_id": "smoke_story", "chapter_id": "start"}]})
		_expect(_has_message(bad_diagnostics, "通话 ID 重复"), "未识别重复通话 ID。")
		_expect(_has_message(bad_diagnostics, "角色不存在"), "未识别未知角色。")
		_expect(_has_message(bad_diagnostics, "台词必须是非空字符串"), "未识别空台词。")
		_expect(_has_message(bad_diagnostics, "引用的固定来电不存在"), "未识别不存在的剧情 call_id。")
		var write_result := JsonService.save_array(TEMP_PATH, fixture)
		_expect(write_result.get("ok", false), "无法写入固定来电临时副本。")
		var catalog := CatalogScene.instantiate() as Control
		root.add_child(catalog)
		await process_frame
		catalog.load_calls(TEMP_PATH, fixture)
		await process_frame
		var loaded_height := catalog.size.y
		catalog.call("_refresh_all")
		await process_frame
		_expect(catalog.size.y == loaded_height, "重建固定来电台词行后窗口高度发生变化。")
		_expect(catalog.current_data.size() == 2 and catalog.selected_call_index == 0, "工作台没有加载真实通话数组。")
		_expect(catalog.add_line(), "工作台无法新增台词。")
		var edited_lines := (catalog.current_data[0] as Dictionary).get("lines", []) as Array
		_expect(edited_lines.size() == 8, "新增台词后数量不正确。")
		_expect(catalog.move_line(7, -1), "工作台无法移动台词。")
		_expect(catalog.delete_line(7), "工作台无法删除台词。")
		_expect(catalog.undo(), "台词删除无法撤销。")
		_expect(((catalog.current_data[0] as Dictionary).get("lines", []) as Array).size() == 8, "撤销没有恢复台词。")
		_expect(catalog.redo(), "台词删除无法重做。")
		_expect(catalog.save_current_calls(), "有效固定来电无法保存。")
		var saved_result := JsonService.load_array(TEMP_PATH)
		_expect(saved_result.get("ok", false), "保存后的固定来电无法回读。")
		if saved_result.get("ok", false):
			var saved_calls := saved_result.get("data", []) as Array
			_expect(saved_calls.size() == 2, "保存回读改变了通话数量。")
			_expect((((saved_calls[0] as Dictionary).get("smoke_unknown_call", {}) as Dictionary).get("preserve", false)), "保存丢失未知通话字段。")
		catalog.queue_free()
		await process_frame

	if failures.is_empty():
		print("FIXED_VOICE_CALL_EDITOR_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("FIXED_VOICE_CALL_EDITOR_SMOKE: %s" % failure)
	quit(1)


func _has_message(diagnostics: Array, fragment: String) -> bool:
	for diagnostic in diagnostics:
		if str((diagnostic as Dictionary).get("message", "")).contains(fragment):
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)