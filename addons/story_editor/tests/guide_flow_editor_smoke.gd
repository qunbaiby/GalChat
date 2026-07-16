extends SceneTree

const WindowScene = preload("res://addons/story_editor/ui/guide_flow_editor_window.tscn")
const JsonService = preload("res://addons/story_editor/core/story_json_service.gd")
const Validator = preload("res://addons/story_editor/core/guide_flow_validator.gd")

const FIXTURE_PATH := "user://guide_flow_editor_smoke.json"
const STORY_PATH := "res://assets/data/story/scripts/main/jing_library_guidance.json"

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var real_result := JsonService.load_dictionary("res://assets/data/guide/guide_flows.json")
	_expect(real_result.get("ok", false), "真实 Guide Flow 无法读取。")
	_expect(Validator.validate(real_result.get("data", {}) as Dictionary).is_empty(), "真实 Guide Flow 不应包含阻塞错误。")

	var fixture := {
		"root_unknown": "preserve-root",
		"guides": [{
			"id": "fixture_guide",
			"title": "Fixture",
			"guide_unknown": "preserve-guide",
			"steps": [
				{"id": "message_step", "type": "message", "title": "消息", "text": "旧文本", "wait_action": "continue", "step_unknown": "preserve-message"},
				{"id": "story_step", "type": "play_story", "title": "剧情", "text": "播放剧情", "story_path": STORY_PATH, "script_id": "jing_library_guidance", "return_to_main": true, "step_unknown": "preserve-story"}
			]
		}]
	}
	_expect(JsonService.save_dictionary(FIXTURE_PATH, fixture).get("ok", false), "无法写入 Guide fixture。")
	var window := WindowScene.instantiate()
	window.guide_path = FIXTURE_PATH
	root.add_child(window)
	await process_frame
	window.refresh_editor()
	await process_frame

	_expect(window.selected_guide_index == 0 and window.selected_step_index == 0, "加载后未默认选择首个 Guide 步骤。")
	_expect(window.get_node("Root/Header/Summary").text.contains("2 个步骤"), "Guide 摘要未显示步骤数量。")
	window.select_step(1)
	_expect(window.get_node("Root/Body/Workspace/InspectorScroll/Inspector/StoryFields").visible, "play_story 字段区未显示。")
	window.get_node("Root/Body/Workspace/InspectorScroll/Inspector/StoryFields/ReturnToMainCheck").button_pressed = false
	window.get_node("Root/Body/Workspace/InspectorScroll/Inspector/Fields/StepTitleEdit").text = "修改后的剧情"
	_expect(window.apply_step(), "应用 play_story 修改失败。")
	_expect(window.current_data.guides[0].steps[1].title == "修改后的剧情", "步骤标题未写回文档。")
	_expect(window.current_data.guides[0].steps[1].step_unknown == "preserve-story", "步骤未知字段丢失。")
	_expect(window.move_step(-1), "play_story 步骤上移失败。")
	_expect(window.current_data.guides[0].steps[0].id == "story_step", "步骤顺序没有更新。")
	_expect(window.undo(), "撤销步骤上移失败。")
	_expect(window.current_data.guides[0].steps[1].id == "story_step", "撤销后步骤顺序未恢复。")
	_expect(window.redo(), "重做步骤上移失败。")
	_expect(window.current_data.guides[0].steps[0].id == "story_step", "重做后步骤顺序未恢复。")
	_expect(window.save_guides(), "合法 Guide 修改未能保存。")
	var saved := (JsonService.load_dictionary(FIXTURE_PATH).get("data", {}) as Dictionary)
	_expect(saved.root_unknown == "preserve-root", "Guide 根未知字段丢失。")
	_expect(saved.guides[0].guide_unknown == "preserve-guide", "Guide 未知字段丢失。")
	_expect(saved.guides[0].steps[0].step_unknown == "preserve-story", "保存后步骤未知字段丢失。")

	window.get_node("Root/Body/Workspace/InspectorScroll/Inspector/StoryFields/StoryPathEdit").text = "res://missing_guide_story.json"
	_expect(window.apply_step(), "应用无效剧情路径失败。")
	_expect(window.diagnostics.any(func(diagnostic: Dictionary) -> bool: return diagnostic.get("code") == "missing_story_target"), "无效剧情目标没有产生即时诊断。")
	_expect(not window.save_guides(), "存在无效剧情目标时仍允许保存。")

	window.queue_free()
	await process_frame
	if failures.is_empty():
		print("GUIDE_FLOW_EDITOR_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("GUIDE_FLOW_EDITOR_SMOKE: %s" % failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)