extends SceneTree

const JsonService = preload("res://addons/story_editor/core/story_json_service.gd")
const StoryScanner = preload("res://addons/story_editor/core/story_scanner.gd")
const StoryValidator = preload("res://addons/story_editor/core/story_validator.gd")
const EventTemplateService = preload("res://addons/story_editor/core/story_event_template_service.gd")
const MobileChatScanner = preload("res://addons/story_editor/core/mobile_fixed_chat_scanner.gd")
const MobileChatValidator = preload("res://addons/story_editor/core/mobile_chat_validator.gd")
const FixedCallScanner = preload("res://addons/story_editor/core/fixed_voice_call_scanner.gd")
const FixedCallValidator = preload("res://addons/story_editor/core/fixed_voice_call_validator.gd")
const StoryResourceCatalog = preload("res://addons/story_editor/core/story_resource_catalog.gd")
const EditorScene = preload("res://addons/story_editor/ui/story_editor_main.tscn")

const FIXTURE_PATH := "res://assets/data/story/scripts/events/ya_cafe_first_visit.json"
const TEMP_PATH := "user://story_editor_smoke.json"
const TEMPLATE_TEMP_PATH := "user://story_editor_smoke/templates/event_templates.json"

var failures: Array[String] = []


class FakeDateRequester extends Node:
	signal completed(job_id: String, raw_response: Dictionary, metadata: Dictionary)
	signal failed(job_id: String, error_message: String, metadata: Dictionary)

	func request(job_id: String, _context: Dictionary) -> void:
		var raw_response := {"summary": "离线队列结果", "segments": [{"lines": [
			{"speaker": "旁白", "content": "树影沿着道路缓慢移动。"},
			{"speaker": "luna", "content": "今天走过的路，我会认真记住。"},
			{"speaker": "player", "content": "下次我们再换一条路看看。"}
		]}]}
		completed.emit.call_deferred(job_id, raw_response, {
			"duration_ms": 8,
			"usage": {"total_tokens": 24},
			"model": "mock-date-model",
			"http_status": 200,
			"response_id": "mock-response-1",
			"quota": {"remaining": 17}
		})

	func cancel(_job_id: String) -> void:
		pass


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var stories := _test_scanner()
	_test_mobile_chat_catalog()
	_test_fixed_call_catalog()
	var fixture := _test_loading_and_validation()
	_test_event_template_service()
	await _test_editor_scene(fixture)
	await _test_all_story_scenes(stories)
	_test_safe_round_trip(fixture)
	_cleanup()

	if failures.is_empty():
		print("STORY_EDITOR_SMOKE_OK")
		quit(0)
		return

	for failure in failures:
		push_error("STORY_EDITOR_SMOKE: %s" % failure)
	quit(1)


func _test_scanner() -> Array[Dictionary]:
	var stories := StoryScanner.scan()
	_expect(not stories.is_empty(), "剧情扫描器没有发现任何固定剧情。")
	var fixture_found := false
	for story in stories:
		if str(story.get("path", "")) == FIXTURE_PATH:
			fixture_found = true
			break
	_expect(fixture_found, "剧情扫描器没有包含测试剧情。")
	return stories


func _test_mobile_chat_catalog() -> void:
	var chats := MobileChatScanner.scan()
	_expect(not chats.is_empty(), "手机固定聊天扫描器没有发现真实脚本。")
	var chat: Dictionary = chats[0] if not chats.is_empty() else {}
	_expect(str(chat.get("id", "")) == "jing_piano_practice_invite", "手机固定聊天扫描结果 ID 不正确。")
	_expect(int(chat.get("message_count", 0)) == 12, "手机固定聊天扫描结果消息数不正确。")
	_expect(not (chat.get("references", []) as Array).is_empty(), "手机固定聊天没有建立剧情 post_story_events 反向引用。")
	var load_result := JsonService.load_dictionary(str(chat.get("path", "")))
	_expect(load_result.get("ok", false), "无法加载真实手机固定聊天。")
	if not load_result.get("ok", false):
		return
	var data := load_result.get("data", {}) as Dictionary
	_expect(MobileChatValidator.validate(data).is_empty(), "真实手机固定聊天没有通过消息图校验。")
	var invalid := data.duplicate(true)
	var invalid_messages := invalid.get("messages", []) as Array
	(invalid_messages[1] as Dictionary)["options"] = [{"id": "bad", "text": "坏跳转", "next": "missing"}]
	_expect(_has_diagnostic(MobileChatValidator.validate(invalid), "目标消息不存在"), "手机消息校验器没有识别坏 next。")
	var cyclic := {"id": "cycle", "character_id": "jing", "messages": [
		{"id": "a", "speaker": "player_options", "options": [{"id": "to_b", "text": "B", "next": "b"}]},
		{"id": "b", "speaker": "player_options", "options": [{"id": "to_a", "text": "A", "next": "a"}]}
	], "on_complete_events": []}
	_expect(_has_diagnostic(MobileChatValidator.validate(cyclic), "无出口循环"), "手机消息校验器没有识别无出口循环。")
	var missing_story := data.duplicate(true)
	var completion_events := (missing_story.get("on_complete_events", []) as Array).duplicate(true)
	for event_index in completion_events.size():
		if completion_events[event_index] is Dictionary and str((completion_events[event_index] as Dictionary).get("type", "")) == "activate_main_chat_topic":
			var completion_event := (completion_events[event_index] as Dictionary).duplicate(true)
			completion_event["story_script_path"] = "res://assets/data/story/scripts/main/missing_story.json"
			completion_events[event_index] = completion_event
	missing_story["on_complete_events"] = completion_events
	_expect(_has_diagnostic(MobileChatValidator.validate(missing_story), "后续主线不存在"), "手机消息校验器没有提示缺失的后续主线。")


func _test_fixed_call_catalog() -> void:
	var calls := FixedCallScanner.scan()
	_expect(calls.size() == 2, "固定来电扫描器没有发现 2 个真实通话。")
	var line_count := 0
	var reference_count := 0
	for call in calls:
		line_count += int(call.get("line_count", 0))
		reference_count += (call.get("references", []) as Array).size()
	_expect(line_count == 13, "固定来电扫描台词总数不正确。")
	_expect(reference_count == 0, "当前固定来电不应已有剧情引用。")
	var load_result := FixedCallScanner.load_calls()
	_expect(load_result.get("ok", false), "无法加载真实固定来电根数组。")
	if not load_result.get("ok", false):
		return
	var character_ids: Array[String] = []
	for character in StoryResourceCatalog.build().get("character", []):
		character_ids.append(str((character as Dictionary).get("id", "")))
	_expect(character_ids.has("jing") and character_ids.has("ling"), "固定来电角色没有使用运行时资源 ID。")
	_expect(FixedCallValidator.validate(load_result.get("data", []), {"character_ids": character_ids}).is_empty(), "真实固定来电没有通过结构校验。")


func _test_loading_and_validation() -> Dictionary:
	var result := JsonService.load_dictionary(FIXTURE_PATH)
	_expect(bool(result.get("ok", false)), "无法读取测试剧情：%s" % result.get("error", "未知错误"))
	if not result.get("ok", false):
		return {}
	var data := result.get("data", {}) as Dictionary
	_expect(str(data.get("script_id", "")) == "ya_cafe_first_visit", "读取后的 script_id 不正确。")
	_expect(StoryValidator.validate(data).is_empty(), "有效测试剧情未通过结构校验。")

	var invalid_data := data.duplicate(true)
	invalid_data.erase("script_id")
	_expect(not StoryValidator.validate(invalid_data).is_empty(), "校验器没有识别缺失的 script_id。")
	var branch_data := {
		"script_id": "branch_validation",
		"chapters": {
			"start": {"events": [{"type": "choice", "options": [{"id": "a", "text": "A", "target_chapter": "missing"}]}]},
			"orphan": {"events": []}
		}
	}
	var branch_diagnostics := StoryValidator.validate(branch_data)
	_expect(_has_diagnostic(branch_diagnostics, "目标章节不存在"), "校验器没有识别 Choice 的无效目标。")
	_expect(_has_diagnostic(branch_diagnostics, "无法从 start"), "校验器没有识别不可达章节。")
	var invalid_voice_data := {
		"script_id": "invalid_voice_instruction",
		"chapters": {"start": {"events": [{"type": "dialogue", "speaker": "luna", "content": "测试", "voice_instruction": "过长".repeat(41)}]}}
	}
	_expect(_has_diagnostic(StoryValidator.validate(invalid_voice_data), "语音指令不能超过 80"), "校验器没有限制 TTS 2.0 语音指令长度。")
	return data


func _test_event_template_service() -> void:
	_cleanup_template_files()
	var empty_result := EventTemplateService.load_templates(TEMPLATE_TEMP_PATH)
	_expect(empty_result.get("ok", false) and (empty_result.get("templates", []) as Array).is_empty(), "不存在的自定义模板库没有按空集合加载。")
	var source_event := {"type": "choice", "options": [{"text": "保留嵌套字段", "effects": {"custom": 7}}]}
	var save_result := EventTemplateService.save_event("Smoke 模板", source_event, TEMPLATE_TEMP_PATH)
	_expect(save_result.get("ok", false), "首次创建自定义模板库失败：%s" % save_result.get("error", "未知错误"))
	var load_result := EventTemplateService.load_templates(TEMPLATE_TEMP_PATH)
	_expect(load_result.get("ok", false) and (load_result.get("templates", []) as Array).size() == 1, "自定义模板保存后无法读回。")
	if load_result.get("ok", false) and not (load_result.get("templates", []) as Array).is_empty():
		var stored_template := (load_result.get("templates", []) as Array)[0] as Dictionary
		var stored_event := (stored_template.get("events", []) as Array)[0] as Dictionary
		_expect(int((((stored_event.get("options", []) as Array)[0] as Dictionary).get("effects", {}) as Dictionary).get("custom", 0)) == 7, "自定义模板丢失嵌套扩展字段。")
		_expect(not EventTemplateService.save_event("Smoke 模板", source_event, TEMPLATE_TEMP_PATH).get("ok", false), "自定义模板允许保存重复名称。")
		_expect(EventTemplateService.delete_template(str(stored_template.get("id", "")), TEMPLATE_TEMP_PATH).get("ok", false), "删除自定义模板失败。")
		_expect((EventTemplateService.load_templates(TEMPLATE_TEMP_PATH).get("templates", []) as Array).is_empty(), "删除后自定义模板仍然存在。")
	var multi_save_result := EventTemplateService.save_events("组合 Smoke 模板", [source_event, {"type": "dialogue", "content": "第二个事件"}], TEMPLATE_TEMP_PATH)
	_expect(multi_save_result.get("ok", false), "无法保存多事件自定义模板。")
	var multi_templates := EventTemplateService.load_templates(TEMPLATE_TEMP_PATH).get("templates", []) as Array
	_expect(multi_templates.size() == 1 and ((multi_templates[0] as Dictionary).get("events", []) as Array).size() == 2, "多事件自定义模板没有按顺序持久化。")
	_cleanup_template_files()


func _test_editor_scene(fixture: Dictionary) -> void:
	if fixture.is_empty():
		return
	var editor := EditorScene.instantiate()
	root.add_child(editor)
	await process_frame

	_expect(editor.is_node_ready(), "剧情编辑器主场景没有完成 ready。")
	_expect(editor.get_node("Root/Toolbar/DocumentState") != null, "主编辑器缺少文档保存状态。")
	_expect(editor.get_node("Root/Body/WorkspaceSplit/Workspace/CanvasGuide") != null, "主编辑器缺少画布工作流引导。")
	_expect(editor.get_node("Root/Body/WorkspaceSplit/Workspace/DiagnosticsHeader") != null, "主编辑器缺少校验摘要。")
	var mobile_catalog := editor.get_node("Root/Body/MobileChatEmbed/MobileChatCatalogWindow")
	_expect(mobile_catalog != null and mobile_catalog.has_method("refresh_catalog"), "主编辑器缺少手机固定消息资源入口。")
	if mobile_catalog != null:
		mobile_catalog.refresh_catalog()
		_expect(mobile_catalog.chats.size() >= 1, "手机消息资源概览没有加载真实固定聊天。")
		var mobile_tree := mobile_catalog.get_node("Root/Body/ChatTree") as Tree
		_expect(mobile_tree.get_root().get_child_count() == mobile_catalog.chats.size(), "手机消息资源概览列表数量不正确。")
		mobile_catalog.select_chat(0)
		var mobile_diagnostics := mobile_catalog.get_node("Root/Body/Editor/VerticalWorkspace/DetailsTabs/校验/DiagnosticsTree") as Tree
		_expect(mobile_diagnostics.get_root().get_child(0).get_text(0) == "OK", "真实手机聊天在资源概览中未通过校验。")
	var fixed_call_catalog := editor.get_node("Root/Body/FixedCallEmbed/FixedVoiceCallCatalogWindow")
	_expect(fixed_call_catalog != null and fixed_call_catalog.has_method("refresh_catalog"), "主编辑器缺少固定来电工作台入口。")
	if fixed_call_catalog != null:
		fixed_call_catalog.refresh_catalog()
		_expect(fixed_call_catalog.current_data.size() == 2, "固定来电工作台没有加载真实通话。")
		var call_tree := fixed_call_catalog.get_node("Root/Body/Library/CallTree") as Tree
		_expect(call_tree.get_root().get_child_count() == 2, "固定来电目录列表数量不正确。")
	var mobile_ai_workbench := editor.get_node("MobileAIWorkbench")
	_expect(mobile_ai_workbench != null and mobile_ai_workbench.has_method("build_preview"), "主编辑器缺少手机 AI 离线工作台入口。")
	if mobile_ai_workbench != null:
		_expect(mobile_ai_workbench.build_preview(), "手机 AI 工作台默认预览无法构建。")
		var mobile_ai_request := mobile_ai_workbench.last_preview.get("request", {}) as Dictionary
		_expect(not bool(mobile_ai_request.get("network_requested", true)), "手机 AI 工作台不应默认发起网络请求。")
		_expect((mobile_ai_request.get("persistent_history_writes", []) as Array).is_empty(), "手机 AI 工作台不应写入运行时历史。")
	if not editor.has_method("load_story"):
		_expect(false, "剧情编辑器主脚本未成功加载。")
		editor.queue_free()
		await process_frame
		return
	editor.load_story(FIXTURE_PATH)
	await process_frame
	_expect(editor.current_path == FIXTURE_PATH, "剧情编辑器没有记录当前文件路径。")
	_expect(editor.current_chapter == "start", "剧情编辑器没有打开 start 章节。")
	var event_search_edit := editor.get_node("Root/Body/WorkspaceSplit/Workspace/DocumentBar/EventSearchBar/EventSearchEdit") as LineEdit
	var event_search_status := editor.get_node("Root/Body/WorkspaceSplit/Workspace/DocumentBar/EventSearchBar/EventSearchStatus") as Label
	var next_event_match_button := editor.get_node("Root/Body/WorkspaceSplit/Workspace/DocumentBar/EventSearchBar/NextEventMatchButton") as Button
	event_search_edit.text = "第一次来吧"
	editor.call("_refresh_event_search", event_search_edit.text)
	_expect(editor.event_search_results.size() == 1, "事件搜索没有命中唯一对白。")
	_expect(not next_event_match_button.disabled, "有搜索结果时下一条按钮仍处于禁用状态。")
	_expect(editor.navigate_event_search(1), "事件搜索无法跳转到结果。")
	_expect(editor.current_chapter == "start" and editor.selected_event_index == 2, "事件搜索跳转到了错误事件。")
	_expect(event_search_status.text == "1 / 1", "事件搜索状态没有显示当前位置。")
	event_search_edit.text = "__missing_story_event__"
	editor.call("_refresh_event_search", event_search_edit.text)
	_expect(editor.event_search_results.is_empty(), "不存在的关键词仍然返回搜索结果。")
	_expect(editor.selected_event_index == 2, "空搜索结果改变了当前事件选择。")
	_expect(next_event_match_button.disabled, "无搜索结果时下一条按钮没有禁用。")
	var search_chapters := editor.current_data.get("chapters", {}) as Dictionary
	search_chapters["search_smoke"] = {"events": [{
		"type": "choice",
		"options": [{"text": "普通选项", "custom_data": {"planner_tag": "hidden_search_token"}}]
	}]}
	editor.call("_populate_chapters")
	event_search_edit.text = "hidden_search_token"
	editor.call("_refresh_event_search", event_search_edit.text)
	_expect(editor.event_search_results.size() == 1, "事件搜索没有递归命中未知嵌套字段。")
	_expect(editor.navigate_event_search(1), "事件搜索无法跨章节跳转。")
	_expect(editor.current_chapter == "search_smoke" and editor.selected_event_index == 0, "事件搜索跨章节定位错误。")
	_expect((editor.graph_edit.get_node("event_search_smoke_0") as GraphNode).selected, "跨章节搜索跳转后节点没有高亮。")
	search_chapters.erase("search_smoke")
	editor.call("_populate_chapters")
	event_search_edit.clear()
	editor.call("_refresh_event_search", "")

	var expected_events := ((fixture.get("chapters", {}) as Dictionary).get("start", {}) as Dictionary).get("events", []) as Array
	var graph_edit := editor.get_node("Root/Body/WorkspaceSplit/Workspace/GraphEdit") as GraphEdit
	var graph_node_count := 0
	for child in graph_edit.get_children():
		if child is GraphNode and str(child.name).begins_with("event_"):
			graph_node_count += 1
	_expect(graph_node_count == expected_events.size(), "节点数量 %d 与事件数量 %d 不一致。" % [graph_node_count, expected_events.size()])

	editor.call("_select_event", "start", 0)
	var first_event_node := graph_edit.get_node("event_start_0") as GraphNode
	var first_event_type := str((expected_events[0] as Dictionary).get("type", "unknown"))
	_expect(first_event_node.title.contains(first_event_type) and first_event_node.title.contains(" · "), "事件节点标题没有同时显示策划名称和技术 ID。")
	_expect(first_event_node.get_node("Content/TypeAccent").color != Color("#7f8b96") or first_event_type == "set_variable", "事件节点没有应用类型分类色。")
	_expect(first_event_node.selected, "程序化选择事件后画布节点没有同步高亮。")
	var persisted_position := Vector2(468.0, 326.0)
	editor.call("_on_graph_move_started")
	first_event_node.position_offset = persisted_position
	editor.call("_on_graph_move_finished")
	var positioned_event := (editor.call("_current_events") as Array)[0] as Dictionary
	var positioned_data := positioned_event.get("_editor_position", {}) as Dictionary
	_expect(Vector2(float(positioned_data.get("x", 0.0)), float(positioned_data.get("y", 0.0))) == persisted_position, "拖拽位置没有写回剧情事件。")
	editor.call("_show_chapter", "start")
	first_event_node = graph_edit.get_node("event_start_0") as GraphNode
	_expect(first_event_node.position_offset == persisted_position, "重建剧情图后节点位置丢失。")
	editor.current_path = TEMP_PATH
	editor.save_current_story()
	var positioned_save := JsonService.load_dictionary(TEMP_PATH)
	_expect(bool(positioned_save.get("ok", false)), "包含节点位置的剧情无法通过编辑器保存。")
	var saved_start := ((positioned_save.get("data", {}) as Dictionary).get("chapters", {}) as Dictionary).get("start", {}) as Dictionary
	var saved_position := ((((saved_start.get("events", []) as Array)[0] as Dictionary).get("_editor_position", {}) as Dictionary))
	_expect(Vector2(float(saved_position.get("x", 0.0)), float(saved_position.get("y", 0.0))) == persisted_position, "保存回读后剧情节点位置丢失。")
	editor.current_path = FIXTURE_PATH
	editor.call("_select_event", "start", 0)
	var focus_selection_button := editor.get_node("Root/Body/WorkspaceSplit/Workspace/DocumentBar/EventBar/FocusSelectionButton") as Button
	_expect(not focus_selection_button.disabled, "选择事件后定位按钮仍处于禁用状态。")
	graph_edit.scroll_offset = Vector2(5000, 5000)
	editor.focus_selected_event()
	_expect(graph_edit.scroll_offset != Vector2(5000, 5000), "定位选中没有将画布滚动到当前事件。")
	var chapter_entry_filter := editor.get_node("Root/Body/WorkspaceSplit/Workspace/DocumentBar/EventBar/ChapterEntryFilter") as LineEdit
	var fixture_chapter_ids := (fixture.get("chapters", {}) as Dictionary).keys()
	var filter_chapter_id := str(fixture_chapter_ids[0])
	var hidden_chapter_id := "end" if filter_chapter_id != "end" else str(fixture_chapter_ids[1])
	chapter_entry_filter.text = filter_chapter_id
	editor.call("_filter_chapter_entries", chapter_entry_filter.text)
	var matched_entry_name := "chapter_entry_%s" % filter_chapter_id.validate_node_name()
	var hidden_entry_name := "chapter_entry_%s" % hidden_chapter_id.validate_node_name()
	var matched_entry := graph_edit.get_node(matched_entry_name) as GraphNode
	var end_entry := graph_edit.get_node("chapter_entry_end") as GraphNode
	_expect(matched_entry.selectable, "章节入口节点不可选中。")
	_expect(end_entry.selectable, "剧情结束节点不可选中。")
	_expect(graph_edit.get_node(matched_entry_name).visible, "章节入口筛选隐藏了匹配章节。")
	_expect(not graph_edit.get_node(hidden_entry_name).visible, "章节入口筛选没有隐藏不匹配章节。")
	chapter_entry_filter.text = ""
	editor.call("_filter_chapter_entries", "")
	var event_inspector := editor.get_node("Root/Body/WorkspaceSplit/Inspector/EventInspector")
	var advanced_json_edit := event_inspector.get_node("Tabs/高级 JSON/AdvancedJsonEdit") as CodeEdit
	_expect(not advanced_json_edit.text.is_empty(), "选择节点后 Inspector 没有显示事件 JSON。")

	var editor_events := editor.call("_current_events") as Array
	var first_event := editor_events[0] as Dictionary
	first_event["smoke_unknown_field"] = "preserved"
	first_event["bg_id"] = "smoke_background"
	editor.call("_select_event", "start", 0)
	var bg_entry := event_inspector.field_controls.get("bg_id", {}) as Dictionary
	var bg_control := bg_entry.get("control") as OptionButton
	_expect(bg_control != null, "背景事件没有生成 bg_id 结构化控件。")
	if bg_control != null:
		_expect(bg_control.item_count > 1, "背景资源选择器没有加载项目资源。")
		_expect(str(bg_control.get_item_metadata(bg_control.selected)) == "smoke_background", "背景资源选择器没有保留未注册 ID。")
		event_inspector.call("_apply_structured")
		var updated_event := (editor.call("_current_events") as Array)[0] as Dictionary
		_expect(str(updated_event.get("bg_id", "")) == "smoke_background", "结构化 Inspector 没有写回 bg_id。")
		_expect(str(updated_event.get("smoke_unknown_field", "")) == "preserved", "结构化 Inspector 丢失了未知字段。")

	event_inspector.set_chapter_ids(["start", "branch", "end"])
	event_inspector.load_event({"type": "choice", "options": [{
		"id": "keep_id",
		"text": "原选项",
		"target_chapter": "branch",
		"effects": {"intimacy": 1, "trust": 2, "custom_effect": 9},
		"response": "保留响应"
	}]})
	var options_entry := event_inspector.field_controls.get("options", {}) as Dictionary
	var options_control: Control = options_entry.get("control") as Control
	_expect(options_control != null and options_control.has_method("get_options"), "Choice 没有生成可视化选项列表。")
	if options_control != null:
		var option_row := options_control.get_node("Rows").get_child(0)
		var target_select := option_row.get_node("Details/TargetSelect") as OptionButton
		_expect(target_select.custom_minimum_size.x >= 240 and target_select.item_count == 4, "Choice 目标剧情节点选择器不够清晰或缺少章节。")
		option_row.get_node("TextEdit").text = "修改后的选项"
		option_row.get_node("Details/IntimacySpin").value = 5
		var visual_options := options_control.get_options() as Array
		var visual_option := visual_options[0] as Dictionary
		_expect(str(visual_option.get("text", "")) == "修改后的选项", "Choice 可视化编辑没有写回文本。")
		_expect(str(visual_option.get("target_chapter", "")) == "branch", "Choice 可视化编辑没有保留目标章节。")
		_expect(int((visual_option.get("effects", {}) as Dictionary).get("intimacy", 0)) == 5, "Choice 可视化编辑没有写回亲密度效果。")
		_expect(int((visual_option.get("effects", {}) as Dictionary).get("custom_effect", 0)) == 9, "Choice 可视化编辑丢失未知效果字段。")
		_expect(str(visual_option.get("response", "")) == "保留响应", "Choice 可视化编辑丢失未知选项字段。")
	event_inspector.load_event({"type": "jump", "target_chapter": "end"})
	var jump_entry := event_inspector.field_controls.get("target_chapter", {}) as Dictionary
	var jump_control := jump_entry.get("control") as OptionButton
	_expect(jump_control != null and jump_control.item_count == 3, "Jump 没有生成包含全部章节的目标下拉。")
	if jump_control != null:
		_expect(str(jump_control.get_item_metadata(jump_control.selected)) == "end", "Jump 目标下拉没有选中当前目标。")
	editor.call("_select_event", "start", 0)
	editor.call("_navigate_to_diagnostic", {"location": "start / #1", "message": "定位测试"})
	_expect(editor.current_chapter == "start" and editor.selected_event_index == 0, "诊断双击定位没有选择对应事件。")

	var original_count := editor_events.size()
	editor.event_type_select.select(editor.CREATE_EVENT_TYPES.find("dialogue"))
	editor.add_event()
	await process_frame
	_expect((editor.call("_current_events") as Array).size() == original_count + 1, "新增事件后事件数量不正确。")
	_expect(_graph_node_count(graph_edit) == original_count + 1, "新增事件后节点数量没有同步。")
	editor.undo()
	await process_frame
	_expect((editor.call("_current_events") as Array).size() == original_count, "撤销新增事件后数量没有恢复。")
	editor.redo()
	await process_frame
	_expect((editor.call("_current_events") as Array).size() == original_count + 1, "重做新增事件后数量不正确。")
	var inserted_index: int = editor.selected_event_index
	editor.move_selected_event(-1)
	await process_frame
	_expect(editor.selected_event_index == maxi(inserted_index - 1, 0), "上移事件后选择索引不正确。")
	editor.delete_selected_event()
	await process_frame
	_expect((editor.call("_current_events") as Array).size() == original_count, "删除事件后没有恢复原事件数量。")
	_expect(_graph_node_count(graph_edit) == original_count, "删除事件后节点数量没有同步。")

	editor.call("_select_event", "start", 0)
	var copied_source := ((editor.call("_current_events") as Array)[0] as Dictionary)
	copied_source["smoke_nested"] = {"value": 7}
	var undo_count_before_copy: int = editor.undo_stack.size()
	_expect(editor.copy_selected_event(), "复制有效事件失败。")
	_expect(editor.undo_stack.size() == undo_count_before_copy, "复制事件不应写入撤销历史。")
	_expect(not (editor.paste_event_button as Button).disabled, "复制后粘贴按钮仍处于禁用状态。")
	_expect(editor.paste_event(), "粘贴已复制事件失败。")
	await process_frame
	var pasted_events := editor.call("_current_events") as Array
	_expect(pasted_events.size() == original_count + 1, "粘贴事件后数量不正确。")
	_expect(editor.selected_event_index == 1, "粘贴后没有选中新事件。")
	var pasted_event := pasted_events[1] as Dictionary
	(pasted_event.get("smoke_nested", {}) as Dictionary)["value"] = 99
	_expect(int((pasted_events[0] as Dictionary).get("smoke_nested", {}).get("value", 0)) == 7, "粘贴事件与源事件共享嵌套数据。")
	editor.undo()
	await process_frame
	_expect((editor.call("_current_events") as Array).size() == original_count, "撤销粘贴没有恢复事件数量。")
	editor.redo()
	await process_frame
	_expect((editor.call("_current_events") as Array).size() == original_count + 1, "重做粘贴没有恢复事件。")
	editor.undo()
	editor.call("_select_event", "start", 0)
	_expect(editor.duplicate_selected_event(), "重复有效事件失败。")
	await process_frame
	_expect((editor.call("_current_events") as Array).size() == original_count + 1, "重复事件后数量不正确。")
	_expect(editor.selected_event_index == 1, "重复事件后没有选中副本。")
	editor.undo()
	var duplicate_shortcut := InputEventKey.new()
	duplicate_shortcut.keycode = KEY_D
	duplicate_shortcut.ctrl_pressed = true
	duplicate_shortcut.pressed = true
	editor.call("_shortcut_input", duplicate_shortcut)
	await process_frame
	_expect((editor.call("_current_events") as Array).size() == original_count + 1, "Ctrl+D 没有重复当前事件。")
	var undo_shortcut := InputEventKey.new()
	undo_shortcut.keycode = KEY_Z
	undo_shortcut.ctrl_pressed = true
	undo_shortcut.pressed = true
	editor.call("_shortcut_input", undo_shortcut)
	await process_frame
	_expect((editor.call("_current_events") as Array).size() == original_count, "Ctrl+Z 没有撤销事件操作。")
	editor.call("_set_graph_selection", [0, 1], 1)
	_expect(editor.selected_event_indices == [0, 1] and editor.selected_event_index == 1, "程序化连续多选没有同步主选事件。")
	_expect((editor.move_up_button as Button).disabled and (editor.move_down_button as Button).disabled, "多选状态下单事件移动按钮没有禁用。")
	_expect(editor.inspector_title.text.contains("2 个事件") and editor.inspector_title.text.contains("主选"), "多选状态没有明确显示主选事件。")
	_expect(editor.copy_selected_event(), "无法复制连续事件选区。")
	_expect(editor.copied_events.size() == 2, "连续事件复制数量不正确。")
	_expect(editor.paste_event(), "无法粘贴连续事件组合。")
	await process_frame
	_expect((editor.call("_current_events") as Array).size() == original_count + 2, "批量粘贴事件数量不正确。")
	_expect(editor.selected_event_index == 2, "批量粘贴后没有选中组合首个事件。")
	editor.undo()
	_expect((editor.call("_current_events") as Array).size() == original_count, "一次撤销没有移除整组粘贴事件。")
	editor.call("_set_graph_selection", [0, 2], 0)
	var undo_count_before_invalid_selection: int = editor.undo_stack.size()
	_expect(not editor.copy_selected_event(), "非连续事件选区不应允许组合复制。")
	_expect(editor.undo_stack.size() == undo_count_before_invalid_selection, "拒绝非连续选区时不应修改历史。")
	editor.call("_set_graph_selection", [0, 1], 0)
	editor.delete_selected_event()
	await process_frame
	_expect((editor.call("_current_events") as Array).size() == original_count - 2, "批量删除连续事件数量不正确。")
	editor.undo()
	_expect((editor.call("_current_events") as Array).size() == original_count, "一次撤销没有恢复整组删除事件。")
	var template_menu := editor.get_node("Root/Body/WorkspaceSplit/Workspace/DocumentBar/EventBar/EventTemplateMenu") as MenuButton
	_expect(template_menu.get_popup().item_count >= editor.EVENT_TEMPLATE_NAMES.size() + 3, "组合模板菜单缺少内置项或管理命令。")
	_expect(template_menu.get_popup().get_item_index(editor.TEMPLATE_MENU_SAVE) >= 0, "组合模板菜单缺少保存自定义模板命令。")
	_expect(template_menu.get_popup().get_item_index(editor.TEMPLATE_MENU_DELETE) >= 0, "组合模板菜单缺少删除自定义模板命令。")
	for template_name in editor.EVENT_TEMPLATE_NAMES:
		var template_events := editor.EVENT_TEMPLATES[template_name] as Array
		_expect(not template_events.is_empty(), "组合模板 %s 没有事件。" % template_name)
		for template_event in template_events:
			_expect(template_event is Dictionary and editor.CREATE_EVENT_TYPES.has(str((template_event as Dictionary).get("type", ""))), "组合模板 %s 包含不受支持的事件类型。" % template_name)
	_cleanup_template_files()
	editor.template_library_path = TEMPLATE_TEMP_PATH
	editor.call("_refresh_event_template_menu")
	editor.call("_set_graph_selection", [0, 1], 0)
	var template_name_edit := editor.get_node("SaveEventTemplateDialog/TemplateNameEdit") as LineEdit
	template_name_edit.text = "UI Smoke 模板"
	editor.call("_confirm_save_event_template")
	_expect(editor.custom_event_templates.size() == 1, "从 UI 保存事件后自定义模板菜单没有刷新。")
	var custom_template := editor.custom_event_templates[0] as Dictionary
	_expect((custom_template.get("events", []) as Array).size() == 2, "UI 没有将连续选区保存为组合模板。")
	var custom_menu_id: int = editor.TEMPLATE_MENU_CUSTOM_START
	_expect(template_menu.get_popup().get_item_index(custom_menu_id) >= 0, "自定义模板没有出现在组合模板菜单。")
	var count_before_custom_insert := (editor.call("_current_events") as Array).size()
	editor.call("_on_event_template_selected", custom_menu_id)
	await process_frame
	_expect((editor.call("_current_events") as Array).size() == count_before_custom_insert + 2, "从菜单插入自定义组合模板失败。")
	editor.undo()
	_expect((editor.call("_current_events") as Array).size() == count_before_custom_insert, "一次撤销没有移除自定义模板事件。")
	var delete_template_select := editor.get_node("DeleteEventTemplateDialog/DeleteTemplateSelect") as OptionButton
	editor.call("_open_delete_event_template_dialog")
	_expect(delete_template_select.item_count == 1, "删除自定义模板对话框没有列出项目模板。")
	editor.call("_confirm_delete_event_template")
	_expect(editor.custom_event_templates.is_empty(), "从 UI 删除自定义模板后菜单没有刷新。")
	_expect((EventTemplateService.load_templates(TEMPLATE_TEMP_PATH).get("templates", []) as Array).is_empty(), "从 UI 删除后模板仍保存在磁盘。")
	var undo_count_before_template: int = editor.undo_stack.size()
	_expect(editor.insert_event_template("回应型玩家选择"), "无法插入回应型玩家选择模板。")
	await process_frame
	var templated_events := editor.call("_current_events") as Array
	_expect(templated_events.size() == original_count + 3, "组合模板插入的事件数量不正确。")
	_expect(editor.undo_stack.size() == undo_count_before_template + 1, "组合模板没有作为单个撤销事务记录。")
	_expect(editor.selected_event_index == 1, "组合模板插入后没有选中首个事件。")
	_expect(str((templated_events[1] as Dictionary).get("type", "")) == "dialogue", "组合模板首个事件类型不正确。")
	_expect(str((templated_events[2] as Dictionary).get("type", "")) == "choice", "组合模板 Choice 事件顺序不正确。")
	var first_template_options := (templated_events[2] as Dictionary).get("options", []) as Array
	_expect(first_template_options.size() == 2, "回应型玩家选择模板没有生成两个选项。")
	editor.undo()
	await process_frame
	_expect((editor.call("_current_events") as Array).size() == original_count, "一次撤销没有移除整个组合模板。")
	editor.redo()
	await process_frame
	_expect((editor.call("_current_events") as Array).size() == original_count + 3, "一次重做没有恢复整个组合模板。")
	editor.undo()
	editor.call("_select_event", "start", 0)
	_expect(editor.insert_event_template("回应型玩家选择"), "第一次插入深拷贝模板失败。")
	var first_choice := ((editor.call("_current_events") as Array)[2] as Dictionary)
	editor.call("_select_event", "start", 3)
	_expect(editor.insert_event_template("回应型玩家选择"), "第二次插入深拷贝模板失败。")
	var twice_templated_events := editor.call("_current_events") as Array
	var second_choice := twice_templated_events[5] as Dictionary
	((((first_choice.get("options", []) as Array)[0] as Dictionary).get("effects", {}) as Dictionary))["intimacy"] = 9
	_expect(int(((((second_choice.get("options", []) as Array)[0] as Dictionary).get("effects", {}) as Dictionary).get("intimacy", 0))) == 2, "两次组合模板插入共享了嵌套效果数据。")
	editor.undo()
	editor.undo()

	_expect(editor.create_chapter("smoke_chapter"), "无法新增测试章节。")
	_expect(editor.current_chapter == "smoke_chapter", "新增章节后没有切换到新章节。")
	_expect(editor.rename_current_chapter("smoke_chapter_renamed"), "无法重命名测试章节。")
	var chapters := editor.current_data.get("chapters", {}) as Dictionary
	_expect(chapters.has("smoke_chapter_renamed") and not chapters.has("smoke_chapter"), "章节重命名没有更新章节字典。")
	editor.undo()
	chapters = editor.current_data.get("chapters", {}) as Dictionary
	_expect(chapters.has("smoke_chapter") and editor.current_chapter == "smoke_chapter", "撤销章节重命名没有恢复章节。")
	editor.redo()
	_expect(editor.current_chapter == "smoke_chapter_renamed", "重做章节重命名没有恢复选择。")
	_expect(editor.delete_current_chapter(), "无法删除测试章节。")
	_expect(not (editor.current_data.get("chapters", {}) as Dictionary).has("smoke_chapter_renamed"), "删除章节后章节仍然存在。")
	editor.undo()
	_expect((editor.current_data.get("chapters", {}) as Dictionary).has("smoke_chapter_renamed"), "撤销删除章节没有恢复章节。")

	editor.call("_select_chapter_by_id", "start")
	var branch_events := editor.call("_current_events") as Array
	var jump_index := -1
	for event_index in branch_events.size():
		if branch_events[event_index] is Dictionary and str((branch_events[event_index] as Dictionary).get("type", "")) == "jump":
			jump_index = event_index
			break
	if jump_index >= 0:
		editor.call("_set_branch_target", jump_index, 0, "smoke_chapter_renamed")
		_expect(str((branch_events[jump_index] as Dictionary).get("target_chapter", "")) == "smoke_chapter_renamed", "Jump 分支连线没有写回 target_chapter。")
		editor.undo()
		_expect(str(((editor.call("_current_events") as Array)[jump_index] as Dictionary).get("target_chapter", "")) != "smoke_chapter_renamed", "撤销 Jump 分支连接没有恢复目标。")
	var choice_event := {"type": "choice", "options": [{"id": "a", "text": "A"}, {"id": "b", "text": "B"}]}
	branch_events = editor.call("_current_events") as Array
	editor.call("_record_history")
	branch_events.append(choice_event)
	var choice_index := branch_events.size() - 1
	editor.call("_set_branch_target", choice_index, 1, "smoke_chapter_renamed")
	var choice_options := ((editor.call("_current_events") as Array)[choice_index] as Dictionary).get("options", []) as Array
	_expect(str((choice_options[1] as Dictionary).get("target_chapter", "")) == "smoke_chapter_renamed", "Choice 选项端口没有写回 target_chapter。")
	editor.call("_set_branch_target", choice_index, 1, "")
	choice_options = ((editor.call("_current_events") as Array)[choice_index] as Dictionary).get("options", []) as Array
	_expect(not (choice_options[1] as Dictionary).has("target_chapter"), "断开 Choice 分支后没有移除 target_chapter。")

	editor.current_data = {
		"script_id": "simulation_ui_smoke",
		"chapters": {
			"start": {"events": [{"type": "choice", "options": [
				{"id": "a", "text": "A", "effects": {"trust": 1}, "target_chapter": "end"},
				{"id": "b", "text": "B", "effects": {"intimacy": 2}, "target_chapter": "end"}
			]}]}
		}
	}
	var initial_variables_edit := editor.get_node("BranchSimulationWindow/Root/Header/InitialVariablesEdit") as LineEdit
	initial_variables_edit.text = "{\"stage\": 2}"
	var simulation_results := editor.run_branch_simulation() as Array[Dictionary]
	_expect(simulation_results.size() == 2, "分支模拟 UI 没有显示全部路径。")
	_expect(editor.simulation_results.get_root().get_child_count() == 2, "分支模拟结果表行数不正确。")
	_expect(editor.simulation_summary.text.contains("0 条循环或错误"), "分支模拟摘要没有正确统计成功路径。")
	initial_variables_edit.text = "[]"
	_expect((editor.run_branch_simulation() as Array).is_empty(), "分支模拟没有拒绝非对象初始变量。")

	var ai_workbench := editor.get_node("DateAIWorkbench")
	_expect(ai_workbench.has_method("run_preview"), "AI 约会工作台主脚本没有加载。")
	_expect(ai_workbench.get_node("Root/WorkflowBar") != null, "AI 工作台缺少步骤导航。")
	_expect(ai_workbench.get_node("Root/Body/InputAndResults/ResultTabs/QualitySummary") != null, "AI 工作台缺少质量总览。")
	_expect(not ai_workbench.templates.is_empty(), "AI 约会工作台没有扫描到模板。")
	if not ai_workbench.templates.is_empty():
		ai_workbench.template_list.select(0)
		ai_workbench.call("_select_template", 0)
		ai_workbench.get_node("Root/Body/InputAndResults/InputTabs/生成输入/PlanningScroll/PlanningContent/Grid/SeedSpin").value = 77
		var ai_preview := ai_workbench.run_preview() as Dictionary
		_expect(str(ai_preview.get("prompt", "")).contains("本次创意种子：77"), "AI 工作台 Prompt 没有使用界面创意种子。")
		_expect(not ai_workbench.sanitized_preview.text.is_empty(), "AI 工作台没有显示清洗与编译结果。")
		_expect(not ai_workbench.fallback_preview.text.is_empty(), "AI 工作台没有显示 fallback 对比。")
		ai_workbench.raw_json.text = "[]"
		ai_preview = ai_workbench.run_preview()
		_expect(bool(ai_preview.get("used_fallback", false)), "AI 工作台没有对非对象响应使用 fallback。")
		_expect(ai_workbench.status_label.text.contains("Fallback"), "AI 工作台没有展示 fallback 原因。")
		var batch_sample := {"summary": "批量测试", "segments": [{"lines": [
			{"speaker": "旁白", "content": "雨停后路面映出灯光。"},
			{"speaker": "luna", "content": "（收起伞）我爱你，我们慢慢走回去吧。"}
		]}]}
		var different_sample := {"summary": "不同内容", "segments": [{"lines": [
			{"speaker": "旁白", "content": "海风吹动远处的风铃。"},
			{"speaker": "player", "content": "今天的夕阳很适合画下来。"}
		]}]}
		ai_workbench.batch_json.text = JSON.stringify([batch_sample, batch_sample.duplicate(true), different_sample])
		var batch_analysis := ai_workbench.run_batch_analysis() as Dictionary
		_expect((batch_analysis.get("results", []) as Array).size() == 3, "AI 工作台批量分析没有保留三份响应。")
		_expect(ai_workbench.batch_results.get_root().get_child_count() == 3, "AI 工作台重复度表行数不正确。")
		var first_batch_item: TreeItem = ai_workbench.batch_results.get_root().get_child(0)
		_expect(first_batch_item.get_text(1) == "100.0%", "AI 工作台没有识别完全重复的响应。")
		_expect(first_batch_item.get_text(3) == "#2", "AI 工作台没有指向最相似响应。")
		_expect(first_batch_item.get_text(7) == "1", "AI 工作台批量表没有展示关系越界数量。")
		ai_workbench.batch_json.text = "{}"
		_expect((ai_workbench.run_batch_analysis() as Dictionary).is_empty(), "AI 工作台没有拒绝非数组批量输入。")
		_expect(ai_workbench.status_label.text.contains("JSON 数组"), "AI 工作台没有解释批量输入格式错误。")
		var fake_requester := FakeDateRequester.new()
		ai_workbench.set_generation_requester(fake_requester)
		ai_workbench.get_node("Root/QueueBar/GenerationCountSpin").value = 2
		ai_workbench.start_generation_queue()
		await ai_workbench.generation_queue.queue_finished
		var queue_snapshot := ai_workbench.generation_queue.snapshot() as Dictionary
		_expect(int((queue_snapshot.get("counts", {}) as Dictionary).get("completed", 0)) == 2, "AI 工作台离线生成队列没有完成两份结果。")
		_expect(ai_workbench.queue_results.get_root().get_child_count() == 2, "AI 工作台生成队列表行数不正确。")
		var first_queue_item: TreeItem = ai_workbench.queue_results.get_root().get_child(0)
		_expect(first_queue_item.get_text(3) == "8 ms", "AI 工作台没有展示生成耗时。")
		_expect(first_queue_item.get_text(4) == "24", "AI 工作台没有展示 Token 元数据。")
		_expect(first_queue_item.get_text(5) == "mock-date-model", "AI 工作台没有展示模型元数据。")
		_expect(first_queue_item.get_text(6) == "200", "AI 工作台没有展示 HTTP 状态。")
		_expect(first_queue_item.get_text(7) == "17", "AI 工作台没有展示剩余配额。")
		_expect(first_queue_item.get_text(8) == "mock-response-1", "AI 工作台没有展示响应 ID。")
		var generated_batch := JSON.parse_string(ai_workbench.batch_json.text) as Array
		_expect(generated_batch.size() == 2, "AI 工作台没有把成功生成结果写入批量响应。")
		_expect(ai_workbench.batch_results.get_root().get_child_count() == 2, "AI 工作台没有自动分析生成结果。")
	editor.queue_free()
	await process_frame


func _test_all_story_scenes(stories: Array[Dictionary]) -> void:
	var editor := EditorScene.instantiate()
	root.add_child(editor)
	await process_frame
	if not editor.has_method("load_story"):
		_expect(false, "全量剧情测试无法加载编辑器主脚本。")
		editor.queue_free()
		await process_frame
		return
	for story in stories:
		var path := str(story.get("path", ""))
		var load_result := JsonService.load_dictionary(path)
		_expect(bool(load_result.get("ok", false)), "无法读取剧情：%s" % path)
		if not load_result.get("ok", false):
			continue
		editor.load_story(path)
		await process_frame
		_expect(editor.current_path == path, "编辑器没有成功打开剧情：%s" % path)
		var chapters := (load_result.get("data", {}) as Dictionary).get("chapters", {}) as Dictionary
		for chapter_id_value in chapters.keys():
			var chapter_id := str(chapter_id_value)
			editor.call("_show_chapter", chapter_id)
			await process_frame
			var chapter := chapters.get(chapter_id, {}) as Dictionary
			var expected_events := chapter.get("events", []) as Array
			var graph_edit := editor.get_node("Root/Body/WorkspaceSplit/Workspace/GraphEdit") as GraphEdit
			var graph_node_count := 0
			for child in graph_edit.get_children():
				if child is GraphNode and str(child.name).begins_with("event_"):
					graph_node_count += 1
			_expect(graph_node_count == expected_events.size(), "%s/%s 的节点数量 %d 与事件数量 %d 不一致。" % [path, chapter_id, graph_node_count, expected_events.size()])
	editor.queue_free()
	await process_frame


func _test_safe_round_trip(fixture: Dictionary) -> void:
	if fixture.is_empty():
		return
	var initial_file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	_expect(initial_file != null, "无法创建临时剧情文件。")
	if initial_file == null:
		return
	initial_file.store_string("{}\n")
	initial_file.close()

	var save_result := JsonService.save_dictionary(TEMP_PATH, fixture)
	_expect(bool(save_result.get("ok", false)), "安全保存失败：%s" % save_result.get("error", "未知错误"))
	var load_result := JsonService.load_dictionary(TEMP_PATH)
	_expect(bool(load_result.get("ok", false)), "无法读回安全保存的剧情。")
	if load_result.get("ok", false):
		var saved_data := load_result.get("data", {}) as Dictionary
		_expect(saved_data == fixture, "安全保存往返后剧情数据发生变化。")


func _cleanup() -> void:
	var absolute_path := ProjectSettings.globalize_path(TEMP_PATH)
	for suffix in ["", ".story_editor.tmp", ".story_editor.bak"]:
		var candidate: String = absolute_path + str(suffix)
		if FileAccess.file_exists(candidate):
			DirAccess.remove_absolute(candidate)
	_cleanup_template_files()


func _cleanup_template_files() -> void:
	var absolute_path := ProjectSettings.globalize_path(TEMPLATE_TEMP_PATH)
	for suffix in ["", ".story_editor.tmp", ".story_editor.bak"]:
		var candidate: String = absolute_path + str(suffix)
		if FileAccess.file_exists(candidate):
			DirAccess.remove_absolute(candidate)


func _graph_node_count(graph_edit: GraphEdit) -> int:
	var count := 0
	for child in graph_edit.get_children():
		if child is GraphNode and str(child.name).begins_with("event_"):
			count += 1
	return count


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _has_diagnostic(diagnostics: Array[Dictionary], message_part: String) -> bool:
	for diagnostic in diagnostics:
		if str(diagnostic.get("message", "")).contains(message_part):
			return true
	return false