@tool
extends Window

const WorkbenchService = preload("res://addons/story_editor/core/date_ai_workbench_service.gd")
const GenerationQueue = preload("res://addons/story_editor/core/date_ai_generation_queue.gd")
const DeepSeekRequester = preload("res://addons/story_editor/core/date_ai_deepseek_requester.gd")
const WINDOW_LAYOUT_PATH := "res://addons/story_editor/core/editor_window_layout.gd"

var templates: Array[Dictionary] = []
var selected_template: Dictionary = {}
var generation_queue: Node
var generation_requester: Node
var template_config_path := WorkbenchService.TEMPLATE_PATH

@onready var template_list: ItemList = %TemplateList
@onready var template_json: CodeEdit = %TemplateJson
@onready var raw_json: CodeEdit = %RawJson
@onready var batch_json: CodeEdit = %BatchJson
@onready var prompt_preview: CodeEdit = %PromptPreview
@onready var sanitized_preview: CodeEdit = %SanitizedPreview
@onready var fallback_preview: CodeEdit = %FallbackPreview
@onready var audit_tree: Tree = %AuditTree
@onready var batch_results: Tree = %BatchResults
@onready var queue_results: Tree = %QueueResults
@onready var status_label: Label = %StatusLabel


func _ready() -> void:
	size_changed.connect(_apply_planning_layout)
	%InputTabs.set_tab_title(%InputTabs.get_tab_idx_from_control(%生成输入), "策划参数")
	%InputTabs.set_tab_title(%InputTabs.get_tab_idx_from_control(template_json), "模板 JSON")
	%ResultTabs.set_tab_title(%ResultTabs.get_tab_idx_from_control(%QualitySummary), "质量总览")
	%InputTabs.set_tab_title(%InputTabs.get_tab_idx_from_control(raw_json), "原始响应")
	%InputTabs.set_tab_title(%InputTabs.get_tab_idx_from_control(batch_json), "批量响应")
	%ResultTabs.set_tab_title(%ResultTabs.get_tab_idx_from_control(prompt_preview), "Prompt 预览")
	%ResultTabs.set_tab_title(%ResultTabs.get_tab_idx_from_control(sanitized_preview), "清洗与编译")
	%ResultTabs.set_tab_title(%ResultTabs.get_tab_idx_from_control(fallback_preview), "Fallback")
	%ResultTabs.set_tab_title(%ResultTabs.get_tab_idx_from_control(audit_tree), "审核报告")
	%ResultTabs.set_tab_title(%ResultTabs.get_tab_idx_from_control(batch_results), "重复度对比")
	%ResultTabs.set_tab_title(%ResultTabs.get_tab_idx_from_control(queue_results), "生成队列")
	close_requested.connect(hide)
	%TemplateSearch.text_changed.connect(_populate_templates)
	template_list.item_selected.connect(_select_template)
	%PreviewButton.pressed.connect(run_preview)
	%BatchAnalyzeButton.pressed.connect(run_batch_analysis)
	%SaveTemplateButton.pressed.connect(save_template)
	%CreateTemplateButton.pressed.connect(_open_create_template_dialog)
	%CreateTemplateDialog.confirmed.connect(_confirm_create_template)
	%CreateTemplateSource.item_selected.connect(_update_create_template_targets)
	%CreateTemplateId.text_changed.connect(_update_create_template_state.unbind(1))
	%CreateTemplateTitle.text_changed.connect(_update_create_template_state.unbind(1))
	%StartGenerationButton.pressed.connect(start_generation_queue)
	%PauseGenerationButton.pressed.connect(toggle_generation_pause)
	%CancelGenerationButton.pressed.connect(cancel_generation_queue)
	batch_results.item_activated.connect(_load_selected_batch_result)
	_setup_batch_tree()
	_setup_queue_tree()
	audit_tree.set_column_title(0, "级别")
	audit_tree.set_column_title(1, "说明")
	audit_tree.set_column_expand(0, false)
	audit_tree.set_column_custom_minimum_width(0, 76)
	_create_generation_queue()
	_refresh_templates()
	call_deferred("_apply_planning_layout")


func _apply_planning_layout() -> void:
	var planning_scroll := $Root/Body/InputAndResults/InputTabs/生成输入/PlanningScroll as ScrollContainer
	var creative_fields := planning_scroll.get_node("PlanningContent/CreativeGrid") as VBoxContainer
	var available_width := maxf(planning_scroll.size.x - 12.0, 240.0)
	creative_fields.custom_minimum_size.x = available_width
	for field_name in ["TaskEdit", "IncidentEdit", "TopicEdit", "ClosingEdit"]:
		var field := creative_fields.get_node(field_name) as TextEdit
		field.custom_minimum_size.x = available_width


func open_workbench() -> void:
	(load(WINDOW_LAYOUT_PATH) as GDScript).new().open_window(self, Vector2i(1280, 760), Vector2i(980, 620))
	if selected_template.is_empty() and not templates.is_empty():
		template_list.select(0)
		_select_template(0)


func run_preview() -> Dictionary:
	var template_result := _parse_object(template_json.text, "模板")
	if not template_result.get("ok", false):
		_set_status(str(template_result.error), true)
		return {}
	var raw_result := _parse_json(raw_json.text, "原始响应")
	if not raw_result.get("ok", false):
		_set_status(str(raw_result.error), true)
		return {}
	var overrides := _current_overrides()
	var preview := WorkbenchService.preview(template_result.data, overrides, raw_result.data)
	if preview.has("error"):
		_set_status(str(preview.error), true)
		return preview
	prompt_preview.text = str(preview.get("prompt", ""))
	sanitized_preview.text = JSON.stringify(preview.get("sanitized", {}), "    ", false)
	fallback_preview.text = JSON.stringify(preview.get("fallback", {}), "    ", false)
	_populate_audit(preview.get("audit", []) as Array)
	var fallback_reason := str(preview.get("fallback_reason", ""))
	_update_quality_summary(preview)
	_set_status("使用 Fallback：%s" % fallback_reason if preview.get("used_fallback", false) else "清洗完成，已生成运行时事件。", bool(preview.get("used_fallback", false)))
	%ResultTabs.current_tab = %ResultTabs.get_tab_idx_from_control(%QualitySummary)
	return preview


func save_template() -> void:
	var result := _parse_object(template_json.text, "模板")
	if not result.get("ok", false):
		_set_status(str(result.error), true)
		return
	var save_result := WorkbenchService.save_template(result.data, template_config_path)
	if save_result.get("ok", false):
		_set_status("模板已安全写回 date_story_templates.json。", false)
		_refresh_templates()
	else:
		_set_status(str(save_result.get("error", "模板保存失败。")), true)


func _open_create_template_dialog() -> void:
	%CreateTemplateId.clear()
	%CreateTemplateTitle.clear()
	%CreateTemplateOutline.clear()
	%CreateTemplateError.text = ""
	%CreateTemplateSource.select(0)
	_update_create_template_targets()
	_update_create_template_state()
	%CreateTemplateDialog.popup_centered()
	%CreateTemplateId.grab_focus.call_deferred()


func _update_create_template_targets(_index: int = 0) -> void:
	var source := str(%CreateTemplateSource.get_selected_metadata())
	%TargetLabel.text = "指定地点" if source == "location" else "所属约会类型"
	%CreateTemplateTarget.clear()
	var result := WorkbenchService.get_template_targets(template_config_path)
	if not result.get("ok", false):
		%CreateTemplateError.text = str(result.get("error", "无法读取模板配置。"))
		_update_create_template_state()
		return
	var targets := result.get("locations", []) as Array if source == "location" else result.get("types", []) as Array
	targets.sort()
	for target_value in targets:
		%CreateTemplateTarget.add_item(str(target_value))
		%CreateTemplateTarget.set_item_metadata(%CreateTemplateTarget.item_count - 1, str(target_value))
	_update_create_template_state()


func _update_create_template_state(_index: int = 0) -> void:
	var valid: bool = not %CreateTemplateId.text.strip_edges().is_empty() and not %CreateTemplateTitle.text.strip_edges().is_empty() and %CreateTemplateTarget.item_count > 0
	%CreateTemplateDialog.get_ok_button().disabled = not valid


func _confirm_create_template() -> void:
	var source := str(%CreateTemplateSource.get_selected_metadata())
	var target := str(%CreateTemplateTarget.get_selected_metadata())
	var definition := {
		"id": %CreateTemplateId.text.strip_edges(),
		"source": source,
		"outline_title": %CreateTemplateTitle.text.strip_edges(),
		"outline_prompt": %CreateTemplateOutline.text.strip_edges()
	}
	definition["location_id" if source == "location" else "type_id"] = target
	var result := WorkbenchService.create_template(definition, template_config_path)
	if not result.get("ok", false):
		%CreateTemplateError.text = str(result.get("error", "模板创建失败。"))
		%CreateTemplateDialog.popup_centered()
		return
	%TemplateSearch.clear()
	_refresh_templates()
	_select_template_by_id(str(definition.id))
	%InputTabs.current_tab = %InputTabs.get_tab_idx_from_control(template_json)
	_set_status("已创建约会模板，可继续编辑模板 JSON。", false)


func _select_template_by_id(template_id: String) -> bool:
	for list_index in template_list.item_count:
		var template_index := int(template_list.get_item_metadata(list_index))
		if template_index >= 0 and template_index < templates.size() and str(templates[template_index].get("id", "")) == template_id:
			template_list.select(list_index)
			_select_template(list_index)
			return true
	return false


func run_batch_analysis() -> Dictionary:
	var template_result := _parse_object(template_json.text, "模板")
	if not template_result.get("ok", false):
		_set_status(str(template_result.error), true)
		return {}
	var batch_result := _parse_json(batch_json.text, "批量响应")
	if not batch_result.get("ok", false) or not batch_result.data is Array:
		_set_status("批量响应必须是 JSON 数组。", true)
		return {}
	var analysis := WorkbenchService.analyze_batch(template_result.data, _current_overrides(), batch_result.data)
	_populate_batch_results(analysis.get("results", []) as Array)
	_update_batch_summary(analysis)
	_set_status("已分析 %d 份结果，批次平均重复度 %.1f%%。" % [(analysis.get("results", []) as Array).size(), float(analysis.get("average_similarity", 0.0)) * 100.0], false)
	%ResultTabs.current_tab = %ResultTabs.get_tab_idx_from_control(batch_results)
	return analysis


func set_generation_requester(requester: Node) -> void:
	if generation_requester != null and generation_requester.get_parent() == generation_queue:
		generation_requester.queue_free()
	generation_requester = requester
	if generation_requester.get_parent() == null:
		generation_queue.add_child(generation_requester)
	generation_queue.set_requester(generation_requester)


func start_generation_queue() -> void:
	var template_result := _parse_object(template_json.text, "模板")
	if not template_result.get("ok", false):
		_set_status(str(template_result.error), true)
		return
	if generation_requester == null:
		var production_requester: Node = DeepSeekRequester.new()
		set_generation_requester(production_requester)
	var contexts: Array[Dictionary] = []
	var base_seed := int(%SeedSpin.value)
	for generation_index in int(%GenerationCountSpin.value):
		var overrides := _current_overrides()
		overrides.creative_seed = base_seed + generation_index
		contexts.append(WorkbenchService.build_context(template_result.data, overrides))
	generation_queue.start(contexts, int(%RetrySpin.value))
	%ResultTabs.current_tab = %ResultTabs.get_tab_idx_from_control(queue_results)


func toggle_generation_pause() -> void:
	if generation_queue.paused:
		generation_queue.resume()
	else:
		generation_queue.pause()


func cancel_generation_queue() -> void:
	generation_queue.cancel()


func _refresh_templates() -> void:
	templates = WorkbenchService.scan_templates(template_config_path)
	_populate_templates(%TemplateSearch.text)


func _populate_templates(filter_text: String = "") -> void:
	template_list.clear()
	var filter := filter_text.strip_edges().to_lower()
	for template_index in templates.size():
		var template := templates[template_index]
		var searchable := "%s %s %s %s" % [template.get("id", ""), template.get("outline_title", ""), template.get("type_id", ""), template.get("location_id", "")]
		if not filter.is_empty() and not searchable.to_lower().contains(filter):
			continue
		template_list.add_item("%s · %s" % [template.get("id", ""), template.get("outline_title", "")])
		template_list.set_item_metadata(template_list.item_count - 1, template_index)


func _select_template(list_index: int) -> void:
	var template_index := int(template_list.get_item_metadata(list_index))
	if template_index < 0 or template_index >= templates.size():
		return
	selected_template = templates[template_index].duplicate(true)
	%TemplateSummary.text = "%s\n类型：%s    地点：%s\n必须桥段：%d 项" % [str(selected_template.get("outline_title", selected_template.get("id", "未命名模板"))), str(selected_template.get("type_id", "通用")), str(selected_template.get("location_id", "任意地点")), (selected_template.get("must_have_beats", []) as Array).size()]
	template_json.text = JSON.stringify(selected_template, "    ", false)
	var location_id := str(selected_template.get("location_id", ""))
	%LocationEdit.text = location_id if not location_id.is_empty() else "sakura_avenue"
	var raw_sample := {"summary": "在具体地点发生了一段有共同体验和情绪推进的约会。", "segments": [{"lines": [
		{"speaker": "旁白", "content": "环境细节让两人自然放慢了脚步。"},
		{"speaker": "luna", "content": "（望向身旁）和你一起的时候，我会注意到更多细节。"},
		{"speaker": "player", "content": "那就把今天记得久一点。"}
	]}]}
	raw_json.text = JSON.stringify(raw_sample, "    ", false)
	batch_json.text = JSON.stringify([raw_sample, raw_sample.duplicate(true)], "    ", false)
	run_preview()


func _current_overrides() -> Dictionary:
	return {
		"location_id": %LocationEdit.text.strip_edges(),
		"period_id": %PeriodSelect.get_item_metadata(%PeriodSelect.selected),
		"weather_id": %WeatherEdit.text.strip_edges(),
		"weather_desc": %WeatherDescEdit.text.strip_edges(),
		"relationship_stage": int(%StageSpin.value),
		"intimacy": %IntimacySpin.value,
		"trust": %TrustSpin.value,
		"creative_seed": int(%SeedSpin.value),
		"interaction_hook": %TaskEdit.text,
		"micro_incident": %IncidentEdit.text,
		"conversation_topic": %TopicEdit.text,
		"closing_style": %ClosingEdit.text
	}


func _setup_batch_tree() -> void:
	var titles := ["结果", "最大重复", "平均重复", "最相似", "对白", "动作", "桥段", "越界", "Fallback"]
	for column in 9:
		batch_results.set_column_title(column, titles[column])


func _setup_queue_tree() -> void:
	var titles := ["任务", "状态", "尝试", "耗时", "Token", "模型", "HTTP", "剩余配额", "响应 ID", "错误"]
	for column in 10:
		queue_results.set_column_title(column, titles[column])


func _create_generation_queue() -> void:
	generation_queue = GenerationQueue.new()
	generation_queue.name = "GenerationQueue"
	add_child(generation_queue)
	generation_queue.queue_changed.connect(_on_generation_queue_changed)
	generation_queue.queue_finished.connect(_on_generation_queue_finished)


func _on_generation_queue_changed(snapshot: Dictionary) -> void:
	var counts := snapshot.get("counts", {}) as Dictionary
	var completed_count := int(counts.get("completed", 0))
	var failed_count := int(counts.get("failed", 0))
	var cancelled_count := int(counts.get("cancelled", 0))
	var total_count := (snapshot.get("jobs", []) as Array).size()
	%QueueStatusLabel.text = "完成 %d/%d · 失败 %d · 取消 %d" % [completed_count, total_count, failed_count, cancelled_count]
	%SummaryMetrics.text = "生成进度 %d/%d · 失败 %d · 取消 %d" % [completed_count, total_count, failed_count, cancelled_count]
	%SummaryState.text = "正在生成候选" if int(counts.get("running", 0)) > 0 else "候选生成队列"
	%SummaryNextAction.text = "生成结束后会自动清洗，并进入重复度与关系边界审核。"
	%PauseGenerationButton.text = "继续" if snapshot.get("paused", false) else "暂停"
	var running: bool = int(counts.get("pending", 0)) + int(counts.get("running", 0)) > 0 and not bool(snapshot.get("cancelled", false))
	%StartGenerationButton.disabled = running
	%PauseGenerationButton.disabled = not running
	%CancelGenerationButton.disabled = not running
	_populate_queue_results(snapshot.get("jobs", []) as Array)


func _on_generation_queue_finished(snapshot: Dictionary) -> void:
	_on_generation_queue_changed(snapshot)
	var raw_responses: Array = []
	for job_value in snapshot.get("jobs", []):
		if job_value is Dictionary and str((job_value as Dictionary).get("status", "")) == "completed":
			raw_responses.append((job_value as Dictionary).get("raw", {}))
	if not raw_responses.is_empty():
		batch_json.text = JSON.stringify(raw_responses, "    ", false)
		run_batch_analysis()
	else:
		_set_status("生成队列结束，没有可分析的成功响应。", true)


func _populate_queue_results(jobs: Array) -> void:
	queue_results.clear()
	var root := queue_results.create_item()
	for job_value in jobs:
		if not job_value is Dictionary:
			continue
		var job := job_value as Dictionary
		var metadata := job.get("metadata", {}) as Dictionary
		var usage := metadata.get("usage", {}) as Dictionary
		var quota := metadata.get("quota", {}) as Dictionary
		var item := queue_results.create_item(root)
		item.set_text(0, "#%d" % (int(job.get("index", 0)) + 1))
		item.set_text(1, str(job.get("status", "pending")))
		item.set_text(2, str(job.get("attempts", 0)))
		item.set_text(3, "%d ms" % int(job.get("duration_ms", 0)))
		item.set_text(4, str(usage.get("total_tokens", "未返回")))
		item.set_text(5, str(metadata.get("model", "未返回")))
		item.set_text(6, str(metadata.get("http_status", "未返回")))
		item.set_text(7, str(quota.get("remaining", "未返回")))
		item.set_text(8, str(metadata.get("response_id", "未返回")))
		item.set_text(9, str(job.get("error", "")))


func _populate_batch_results(results: Array) -> void:
	batch_results.clear()
	var root := batch_results.create_item()
	for result_value in results:
		if not result_value is Dictionary:
			continue
		var result := result_value as Dictionary
		var features := result.get("features", {}) as Dictionary
		var preview_result := result.get("preview", {}) as Dictionary
		var item := batch_results.create_item(root)
		item.set_text(0, "#%d" % (int(result.get("index", 0)) + 1))
		item.set_text(1, "%.1f%%" % (float(result.get("max_similarity", 0.0)) * 100.0))
		item.set_text(2, "%.1f%%" % (float(result.get("average_similarity", 0.0)) * 100.0))
		item.set_text(3, "#%d" % (int(result.get("most_similar_index", -1)) + 1) if int(result.get("most_similar_index", -1)) >= 0 else "-")
		item.set_text(4, str(features.get("dialogue_count", 0)))
		item.set_text(5, str((features.get("actions", []) as Array).size()))
		item.set_text(6, str((features.get("beat_hits", []) as Array).size()))
		item.set_text(7, str(features.get("boundary_count", 0)))
		item.set_text(8, "是" if preview_result.get("used_fallback", false) else "否")
		item.set_metadata(0, result)


func _load_selected_batch_result() -> void:
	var item := batch_results.get_selected()
	if item == null:
		return
	var result_value: Variant = item.get_metadata(0)
	if not result_value is Dictionary:
		return
	var preview_result := (result_value as Dictionary).get("preview", {}) as Dictionary
	raw_json.text = JSON.stringify(preview_result.get("raw", {}), "    ", false)
	%InputTabs.current_tab = %InputTabs.get_tab_idx_from_control(raw_json)
	run_preview()


func _populate_audit(findings: Array) -> void:
	audit_tree.clear()
	var root := audit_tree.create_item()
	for finding_value in findings:
		if finding_value is Dictionary:
			var finding := finding_value as Dictionary
			var item := audit_tree.create_item(root)
			item.set_text(0, str(finding.get("severity", "info")).to_upper())
			item.set_text(1, str(finding.get("message", "")))
	if findings.is_empty():
		var item := audit_tree.create_item(root)
		item.set_text(0, "OK")
		item.set_text(1, "未发现基础内容问题。")


func _update_quality_summary(preview: Dictionary) -> void:
	var findings := preview.get("audit", []) as Array
	var error_count := 0
	var warning_count := 0
	for finding_value in findings:
		if not finding_value is Dictionary:
			continue
		var severity := str((finding_value as Dictionary).get("severity", "info"))
		if severity == "error":
			error_count += 1
		elif severity == "warning":
			warning_count += 1
	var used_fallback := bool(preview.get("used_fallback", false))
	%SummaryState.text = "需要处理：已使用 Fallback" if used_fallback else ("需要修改" if error_count > 0 else "可以继续审核")
	%SummaryState.modulate = Color("#ff7f78") if used_fallback or error_count > 0 else Color("#73d9b0")
	%SummaryMetrics.text = "审核错误 %d · 警告 %d · Fallback %s" % [error_count, warning_count, "是" if used_fallback else "否"]
	%SummaryNextAction.text = "检查原始响应与 Fallback 原因。" if used_fallback else ("先修复审核错误，再生成候选。" if error_count > 0 else "参数已可用，可以生成多份候选并比较。")


func _update_batch_summary(analysis: Dictionary) -> void:
	var results := analysis.get("results", []) as Array
	var fallback_count := 0
	var boundary_count := 0
	var high_repeat_count := 0
	for result_value in results:
		if not result_value is Dictionary:
			continue
		var result := result_value as Dictionary
		var preview := result.get("preview", {}) as Dictionary
		var features := result.get("features", {}) as Dictionary
		fallback_count += 1 if preview.get("used_fallback", false) else 0
		boundary_count += int(features.get("boundary_count", 0))
		high_repeat_count += 1 if float(result.get("max_similarity", 0.0)) >= 0.75 else 0
	%SummaryState.text = "候选审核完成"
	%SummaryState.modulate = Color("#73d9b0") if fallback_count == 0 and boundary_count == 0 else Color("#f0bf67")
	%SummaryMetrics.text = "候选 %d · 高重复 %d · 越界 %d · Fallback %d" % [results.size(), high_repeat_count, boundary_count, fallback_count]
	%SummaryNextAction.text = "双击重复度对比中的候选，可载入单份结果继续检查。"


func _parse_object(text: String, label: String) -> Dictionary:
	var result := _parse_json(text, label)
	if result.get("ok", false) and not result.data is Dictionary:
		return {"ok": false, "error": "%s必须是 JSON 对象。" % label}
	return result


func _parse_json(text: String, label: String) -> Dictionary:
	var parser := JSON.new()
	var error := parser.parse(text)
	if error != OK:
		return {"ok": false, "error": "%s JSON 第 %d 行错误：%s" % [label, parser.get_error_line(), parser.get_error_message()]}
	return {"ok": true, "data": parser.data}


func _set_status(message: String, is_error: bool) -> void:
	status_label.text = message
	status_label.modulate = Color("#ff7f78") if is_error else Color("#73d9b0")