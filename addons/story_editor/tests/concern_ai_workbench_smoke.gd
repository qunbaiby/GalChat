extends SceneTree

const WorkbenchService = preload("res://addons/story_editor/core/concern_ai_workbench_service.gd")
const WorkbenchScene = preload("res://addons/story_editor/ui/concern_ai_workbench.tscn")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var workbench := WorkbenchScene.instantiate() as Window
	root.add_child(workbench)
	await process_frame
	await process_frame
	_expect(workbench.is_node_ready(), "AI 心事工作台没有完成初始化。")
	_expect(workbench.get_node_or_null("Root/Body/Library/TemplateList") is ItemList, "工作台缺少模板列表。")
	_expect(workbench.get_node_or_null("Root/Body/EditorSplit/TemplatePanel/TemplateTabs/VisualConfig") is ScrollContainer, "工作台缺少可视化配置页。")
	_expect(workbench.get_node_or_null("Root/Body/EditorSplit/TemplatePanel/TemplateTabs/AdvancedJson/TemplateJson") is CodeEdit, "工作台缺少高级 JSON 编辑区。")
	var templates := WorkbenchService.scan_templates()
	_expect(not templates.is_empty(), "工作台没有扫描到心事模板。")
	if not templates.is_empty():
		var context := {
			"character_id": "luna",
			"character_name": "Luna",
			"weekday": 6,
			"time_period": "evening",
			"day_offset": 3,
			"stage": 3,
			"intimacy": 50,
			"trust": 50
		}
		var preview := WorkbenchService.preview(templates[0], context)
		_expect(bool(preview.get("ok", false)), "合法心事模板没有通过工作台校验。")
		_expect(not (preview.get("compiled", {}) as Dictionary).is_empty(), "工作台没有生成编译后剧情。")
		workbench.call("_select_template", 0)
		var title_edit := workbench.get_node("Root/Body/EditorSplit/TemplatePanel/TemplateTabs/VisualConfig/Form/BasicGrid/TitleEdit") as LineEdit
		var rounds_spin := workbench.get_node("Root/Body/EditorSplit/TemplatePanel/TemplateTabs/VisualConfig/Form/PolicyGrid/RoundsSpin") as SpinBox
		title_edit.text = "可视化配置测试"
		rounds_spin.value = 6
		var form_result: Dictionary = workbench.call("_template_from_form")
		var form_template: Dictionary = form_result.get("data", {})
		_expect(str(form_template.get("title", "")) == "可视化配置测试", "可视化标题没有同步到模板。")
		_expect(int((form_template.get("guided_ai_policy", {}) as Dictionary).get("max_player_rounds", 0)) == 6, "可视化轮数没有同步到模板。")
		var template_json := workbench.get_node("Root/Body/EditorSplit/TemplatePanel/TemplateTabs/AdvancedJson/TemplateJson") as CodeEdit
		_expect(template_json.text.contains("guided_ai_policy"), "选择模板后没有显示 guided AI 配置。")
	workbench.queue_free()
	await process_frame
	if failures.is_empty():
		print("CONCERN_AI_WORKBENCH_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("CONCERN_AI_WORKBENCH_SMOKE: %s" % failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
