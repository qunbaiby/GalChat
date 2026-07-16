extends SceneTree

const Service = preload("res://addons/story_editor/core/date_ai_workbench_service.gd")
const JsonService = preload("res://addons/story_editor/core/story_json_service.gd")
const WorkbenchScene = preload("res://addons/story_editor/ui/date_ai_workbench.tscn")

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var path := "user://date_ai_template_creation_smoke.json"
	JsonService.save_dictionary(path, {
		"type_defaults": {"stroll": {"variants": []}},
		"locations": {"park": {"type_id": "stroll", "variants": []}},
		"unknown_root": {"keep": true}
	})
	var type_result := Service.create_template({"id": "new_type_date", "source": "type", "type_id": "stroll", "outline_title": "新通用约会", "outline_prompt": "一起完成一项任务。"}, path)
	var location_result := Service.create_template({"id": "new_park_date", "source": "location", "location_id": "park", "outline_title": "公园约会"}, path)
	_expect(type_result.get("ok", false) and location_result.get("ok", false), "通用或地点约会模板创建失败。")
	var data := JsonService.load_dictionary(path).get("data", {}) as Dictionary
	_expect(((data.type_defaults.stroll.variants as Array).size() == 1), "通用模板未写入对应类型。")
	_expect(((data.locations.park.variants as Array).size() == 1), "地点模板未写入对应地点。")
	_expect(bool(data.unknown_root.keep), "创建模板丢失了未知顶层字段。")
	_expect(not Service.create_template({"id": "new_type_date", "source": "type", "type_id": "stroll"}, path).get("ok", false), "重复模板 ID 覆盖了原模板。")
	_expect(not Service.create_template({"id": "bad id", "source": "type", "type_id": "stroll"}, path).get("ok", false), "非法模板 ID 未被拒绝。")
	var workbench := WorkbenchScene.instantiate() as Window
	workbench.template_config_path = path
	root.add_child(workbench)
	await process_frame
	workbench.call("_refresh_templates")
	workbench.call("_open_create_template_dialog")
	workbench.get_node("CreateTemplateDialog/Form/CreateTemplateId").text = "created_from_ui"
	workbench.get_node("CreateTemplateDialog/Form/CreateTemplateTitle").text = "工作台新模板"
	workbench.get_node("CreateTemplateDialog/Form/CreateTemplateOutline").text = "从工作台创建并继续编辑。"
	workbench.call("_confirm_create_template")
	_expect(str(workbench.selected_template.get("id", "")) == "created_from_ui", "工作台创建后没有自动选中新模板。")
	var input_tabs := workbench.get_node("Root/Body/InputAndResults/InputTabs") as TabContainer
	var template_json := workbench.get_node("Root/Body/InputAndResults/InputTabs/TemplateJson") as CodeEdit
	_expect(input_tabs.current_tab == input_tabs.get_tab_idx_from_control(template_json), "创建后没有打开模板 JSON 编辑页。")
	workbench.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if failures.is_empty(): print("DATE_AI_TEMPLATE_CREATION_SMOKE_OK"); quit(0); return
	for failure in failures: push_error("DATE_AI_TEMPLATE_CREATION_SMOKE: %s" % failure)
	quit(1)

func _expect(condition: bool, message: String) -> void:
	if not condition: failures.append(message)