@tool
extends Window

const WorkbenchService = preload("res://addons/story_editor/core/concern_ai_workbench_service.gd")
const WINDOW_LAYOUT_PATH := "res://addons/story_editor/core/editor_window_layout.gd"

var templates: Array[Dictionary] = []
var selected_template: Dictionary = {}
var _loading_form := false

@onready var template_list: ItemList = %TemplateList
@onready var template_json: CodeEdit = %TemplateJson
@onready var context_json: CodeEdit = %ContextJson
@onready var compiled_json: CodeEdit = %CompiledJson
@onready var diagnostics: RichTextLabel = %Diagnostics
@onready var status_label: Label = %StatusLabel


func _ready() -> void:
	close_requested.connect(hide)
	%PreviewTabs.set_tab_title(%PreviewTabs.get_tab_idx_from_control(context_json), "命中上下文")
	%PreviewTabs.set_tab_title(%PreviewTabs.get_tab_idx_from_control(compiled_json), "编译后剧情")
	%PreviewTabs.set_tab_title(%PreviewTabs.get_tab_idx_from_control(diagnostics), "校验报告")
	%TemplateTabs.set_tab_title(%TemplateTabs.get_tab_idx_from_control(%VisualConfig), "可视化配置")
	%TemplateTabs.set_tab_title(%TemplateTabs.get_tab_idx_from_control(%AdvancedJson), "高级 JSON")
	%TemplateSearch.text_changed.connect(_populate_templates)
	template_list.item_selected.connect(_select_template)
	%RefreshButton.pressed.connect(_refresh_templates)
	%PreviewButton.pressed.connect(run_preview)
	%SaveButton.pressed.connect(save_template)
	%CreateButton.pressed.connect(_open_create_dialog)
	%CreateDialog.confirmed.connect(_create_template)
	%AddBeatButton.pressed.connect(func(): _add_beat_row({}))
	%ApplyJsonButton.pressed.connect(_apply_json_to_form)
	%TemplateTabs.tab_changed.connect(_on_template_tab_changed)
	context_json.text = JSON.stringify({
		"character_id": "luna",
		"character_name": "Luna",
		"weekday": 6,
		"time_period": "evening",
		"day_offset": 1,
		"stage": 3,
		"intimacy": 50,
		"trust": 50
	}, "    ", false)
	_refresh_templates()


func open_workbench() -> void:
	(load(WINDOW_LAYOUT_PATH) as GDScript).new().open_window(self, Vector2i(1280, 760), Vector2i(980, 620))
	if selected_template.is_empty() and not templates.is_empty():
		template_list.select(0)
		_select_template(0)


func _refresh_templates() -> void:
	templates = WorkbenchService.scan_templates()
	_populate_templates(%TemplateSearch.text)
	_set_status("已扫描 %d 个心事模板。" % templates.size(), false)


func _populate_templates(filter_text: String = "") -> void:
	template_list.clear()
	var normalized_filter := filter_text.strip_edges().to_lower()
	for index in templates.size():
		var template := templates[index]
		var searchable := "%s %s %s" % [template.get("template_id", ""), template.get("title", ""), template.get("character_id", "")]
		if not normalized_filter.is_empty() and not searchable.to_lower().contains(normalized_filter):
			continue
		template_list.add_item("%s · %s" % [template.get("character_id", "*"), template.get("title", template.get("template_id", ""))])
		template_list.set_item_metadata(template_list.item_count - 1, index)


func _select_template(item_index: int) -> void:
	if item_index < 0 or item_index >= template_list.item_count:
		return
	var template_index := int(template_list.get_item_metadata(item_index))
	if template_index < 0 or template_index >= templates.size():
		return
	selected_template = templates[template_index].duplicate(true)
	template_json.text = JSON.stringify(selected_template, "    ", false)
	_load_form(selected_template)
	run_preview()


func run_preview() -> Dictionary:
	var template_result := _template_from_form()
	var context_result := _parse_object(context_json.text, "命中上下文")
	if not template_result.get("ok", false) or not context_result.get("ok", false):
		var error_text := str(template_result.get("error", context_result.get("error", "JSON 解析失败。")))
		_set_status(error_text, true)
		return {}
	var preview := WorkbenchService.preview(template_result.data, context_result.data)
	compiled_json.text = JSON.stringify(preview.get("compiled", {}), "    ", false)
	var lines: Array[String] = []
	for error_value in preview.get("errors", []):
		lines.append("[color=#ff817a]错误：%s[/color]" % str(error_value))
	lines.append("最终命中：%s" % str(preview.get("resolved_template_id", "无")))
	lines.append("当前模板命中：%s" % ("是" if preview.get("selected_matches", false) else "否"))
	diagnostics.text = "\n".join(lines)
	_set_status("预览完成。" if preview.get("ok", false) else "模板校验未通过。", not preview.get("ok", false))
	return preview


func save_template() -> void:
	var result := _template_from_form()
	if not result.get("ok", false):
		_set_status(str(result.error), true)
		return
	var source_path := str(selected_template.get("source_path", ""))
	var save_result := WorkbenchService.save_template(result.data, source_path)
	if not save_result.get("ok", false):
		_set_status(str(save_result.get("error", "保存失败。")), true)
		return
	_set_status("心事模板已保存。", false)
	_refresh_templates()


func _load_form(template: Dictionary) -> void:
	_loading_form = true
	%TemplateIdEdit.text = str(template.get("template_id", ""))
	%TitleEdit.text = str(template.get("title", ""))
	%CharacterEdit.text = str(template.get("character_id", "*"))
	%PrioritySpin.value = float(template.get("priority", 0))
	%EnabledCheck.button_pressed = bool(template.get("enabled", true))
	var conditions: Dictionary = template.get("conditions", {})
	_set_check_values(
		[%SundayCheck, %MondayCheck, %TuesdayCheck, %WednesdayCheck, %ThursdayCheck, %FridayCheck, %SaturdayCheck],
		conditions.get("weekdays", [])
	)
	_set_check_values(
		[%MorningCheck, %AfternoonCheck, %EveningCheck, %NightCheck],
		conditions.get("time_periods", []),
		["morning", "afternoon", "evening", "night"]
	)
	%MinStageSpin.value = float(conditions.get("min_stage", 0))
	%MaxStageSpin.value = float(conditions.get("max_stage", 0))
	%MinIntimacySpin.value = float(conditions.get("min_intimacy", 0))
	%MinTrustSpin.value = float(conditions.get("min_trust", 0))
	var availability: Dictionary = template.get("availability", {})
	%CooldownSpin.value = float(availability.get("cooldown_days", 0))
	%MaxCompletionsSpin.value = float(availability.get("max_completions", 0))
	%OnceCheck.button_pressed = bool(availability.get("once", false))
	var intro_events: Array = template.get("intro_events", [])
	%NarrationEdit.text = _find_intro_content(intro_events, true)
	%CharacterLineEdit.text = _find_intro_content(intro_events, false)
	var policy: Dictionary = template.get("guided_ai_policy", {})
	%AnchorEdit.text = str(policy.get("narrative_anchor", ""))
	%ObjectiveEdit.text = str(policy.get("scene_objective", ""))
	%AllowedTopicsEdit.text = _join_lines(policy.get("allowed_topics", []))
	%ForbiddenFactsEdit.text = _join_lines(policy.get("forbidden_facts", []))
	_clear_beat_rows()
	for raw_beat in policy.get("required_beats", []):
		if raw_beat is Dictionary:
			_add_beat_row(raw_beat)
	if %RequiredBeats.get_child_count() == 0:
		_add_beat_row({})
	%RedirectEdit.text = str(policy.get("redirect_instruction", ""))
	%RoundsSpin.value = float(policy.get("max_player_rounds", 4))
	%MinutesSpin.value = float(policy.get("game_minutes", 0))
	%ActionCostSpin.value = float(policy.get("action_cost", 0))
	%EarlyCompletionCheck.button_pressed = bool(policy.get("allow_early_completion", true))
	%HideManualEndCheck.button_pressed = bool(policy.get("hide_manual_end", true))
	%ShowEntryLineCheck.button_pressed = bool(policy.get("show_entry_line", false))
	%ClosingEdit.text = str(policy.get("closing_instruction", ""))
	%FallbackClosingEdit.text = str(policy.get("fallback_closing_text", ""))
	%MemoryEnabledCheck.button_pressed = bool(template.get("memory_enabled", false))
	%MemorySummaryEdit.text = str(template.get("memory_summary", ""))
	_loading_form = false


func _template_from_form() -> Dictionary:
	var template := selected_template.duplicate(true)
	var advanced_result := _parse_object(template_json.text, "模板")
	if advanced_result.get("ok", false):
		template = (advanced_result.get("data", {}) as Dictionary).duplicate(true)
	template["schema_version"] = int(template.get("schema_version", 1))
	template["template_id"] = %TemplateIdEdit.text.strip_edges()
	template["title"] = %TitleEdit.text.strip_edges()
	template["character_id"] = %CharacterEdit.text.strip_edges().to_lower()
	template["priority"] = int(%PrioritySpin.value)
	template["enabled"] = %EnabledCheck.button_pressed
	template["conditions"] = {
		"weekdays": _checked_values(
			[%SundayCheck, %MondayCheck, %TuesdayCheck, %WednesdayCheck, %ThursdayCheck, %FridayCheck, %SaturdayCheck]
		),
		"time_periods": _checked_values(
			[%MorningCheck, %AfternoonCheck, %EveningCheck, %NightCheck],
			["morning", "afternoon", "evening", "night"]
		),
		"min_stage": int(%MinStageSpin.value),
		"max_stage": int(%MaxStageSpin.value),
		"min_intimacy": int(%MinIntimacySpin.value),
		"min_trust": int(%MinTrustSpin.value)
	}
	template["availability"] = {
		"cooldown_days": int(%CooldownSpin.value),
		"once": %OnceCheck.button_pressed,
		"max_completions": int(%MaxCompletionsSpin.value)
	}
	var intro_events: Array[Dictionary] = []
	if not %NarrationEdit.text.strip_edges().is_empty():
		intro_events.append({"speaker": "旁白", "content": %NarrationEdit.text.strip_edges()})
	if not %CharacterLineEdit.text.strip_edges().is_empty():
		intro_events.append({"speaker": "{character_name}", "content": %CharacterLineEdit.text.strip_edges()})
	template["intro_events"] = intro_events
	var policy: Dictionary = template.get("guided_ai_policy", {}).duplicate(true)
	policy["narrative_anchor"] = %AnchorEdit.text.strip_edges()
	policy["scene_objective"] = %ObjectiveEdit.text.strip_edges()
	policy["allowed_topics"] = _split_lines(%AllowedTopicsEdit.text)
	policy["forbidden_facts"] = _split_lines(%ForbiddenFactsEdit.text)
	policy["required_beats"] = _collect_beats()
	policy["redirect_instruction"] = %RedirectEdit.text.strip_edges()
	policy["max_player_rounds"] = int(%RoundsSpin.value)
	policy["game_minutes"] = int(%MinutesSpin.value)
	policy["action_cost"] = int(%ActionCostSpin.value)
	policy["allow_early_completion"] = %EarlyCompletionCheck.button_pressed
	policy["hide_manual_end"] = %HideManualEndCheck.button_pressed
	policy["show_entry_line"] = %ShowEntryLineCheck.button_pressed
	policy["closing_instruction"] = %ClosingEdit.text.strip_edges()
	policy["fallback_closing_text"] = %FallbackClosingEdit.text.strip_edges()
	template["guided_ai_policy"] = policy
	template["memory_enabled"] = %MemoryEnabledCheck.button_pressed
	template["memory_summary"] = %MemorySummaryEdit.text.strip_edges()
	template_json.text = JSON.stringify(template, "    ", false)
	selected_template = template.duplicate(true)
	return {"ok": true, "data": template}


func _apply_json_to_form() -> void:
	var result := _parse_object(template_json.text, "模板")
	if not result.get("ok", false):
		_set_status(str(result.get("error", "JSON 解析失败。")), true)
		return
	selected_template = (result.get("data", {}) as Dictionary).duplicate(true)
	_load_form(selected_template)
	%TemplateTabs.current_tab = %TemplateTabs.get_tab_idx_from_control(%VisualConfig)
	_set_status("JSON 已应用到可视化表单。", false)


func _on_template_tab_changed(tab_index: int) -> void:
	if _loading_form:
		return
	if tab_index == %TemplateTabs.get_tab_idx_from_control(%AdvancedJson):
		_template_from_form()


func _add_beat_row(beat: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var id_edit := LineEdit.new()
	id_edit.placeholder_text = "剧情点 ID"
	id_edit.custom_minimum_size.x = 130
	id_edit.text = str(beat.get("id", ""))
	row.add_child(id_edit)
	var instruction_edit := LineEdit.new()
	instruction_edit.placeholder_text = "角色必须自然表达的信息"
	instruction_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	instruction_edit.text = str(beat.get("instruction", ""))
	row.add_child(instruction_edit)
	var remove_button := Button.new()
	remove_button.text = "删除"
	remove_button.tooltip_text = "删除这个剧情点"
	remove_button.pressed.connect(func(): row.queue_free())
	row.add_child(remove_button)
	row.set_meta("id_edit", id_edit)
	row.set_meta("instruction_edit", instruction_edit)
	%RequiredBeats.add_child(row)


func _clear_beat_rows() -> void:
	for child in %RequiredBeats.get_children():
		child.free()


func _collect_beats() -> Array[Dictionary]:
	var beats: Array[Dictionary] = []
	for row in %RequiredBeats.get_children():
		var id_edit := row.get_meta("id_edit") as LineEdit
		var instruction_edit := row.get_meta("instruction_edit") as LineEdit
		if id_edit == null or instruction_edit == null:
			continue
		var beat_id := id_edit.text.strip_edges()
		var instruction := instruction_edit.text.strip_edges()
		if beat_id.is_empty() and instruction.is_empty():
			continue
		beats.append({"id": beat_id, "instruction": instruction})
	return beats


func _find_intro_content(events: Array, narration: bool) -> String:
	for raw_event in events:
		if not raw_event is Dictionary:
			continue
		var speaker := str((raw_event as Dictionary).get("speaker", ""))
		if (speaker == "旁白") == narration:
			return str((raw_event as Dictionary).get("content", ""))
	return ""


func _set_check_values(checks: Array, raw_values: Variant, values: Array = []) -> void:
	var selected: Array = raw_values if raw_values is Array else []
	for index in checks.size():
		var value: Variant = values[index] if not values.is_empty() else index
		(checks[index] as CheckBox).button_pressed = selected.has(value)


func _checked_values(checks: Array, values: Array = []) -> Array:
	var selected: Array = []
	for index in checks.size():
		if (checks[index] as CheckBox).button_pressed:
			selected.append(values[index] if not values.is_empty() else index)
	return selected


func _join_lines(raw_values: Variant) -> String:
	if not raw_values is Array:
		return ""
	var lines: Array[String] = []
	for value in raw_values:
		lines.append(str(value))
	return "\n".join(lines)


func _split_lines(text: String) -> Array[String]:
	var values: Array[String] = []
	for line in text.split("\n"):
		var value := line.strip_edges()
		if not value.is_empty():
			values.append(value)
	return values


func _open_create_dialog() -> void:
	%CreateId.clear()
	%CreateTitle.clear()
	%CreateCharacter.clear()
	%CreateDialog.popup_centered()
	%CreateId.grab_focus.call_deferred()


func _create_template() -> void:
	var result := WorkbenchService.create_template(%CreateId.text, %CreateTitle.text, %CreateCharacter.text)
	if not result.get("ok", false):
		_set_status(str(result.get("error", "创建失败。")), true)
		return
	_refresh_templates()
	var created_id := str((result.get("template", {}) as Dictionary).get("template_id", ""))
	for item_index in template_list.item_count:
		var template_index := int(template_list.get_item_metadata(item_index))
		if str(templates[template_index].get("template_id", "")) == created_id:
			template_list.select(item_index)
			_select_template(item_index)
			break
	_set_status("心事模板已创建。", false)


func _parse_object(text: String, label: String) -> Dictionary:
	var json := JSON.new()
	if json.parse(text) != OK:
		return {"ok": false, "error": "%s JSON 第 %d 行解析失败：%s" % [label, json.get_error_line(), json.get_error_message()]}
	if not json.data is Dictionary:
		return {"ok": false, "error": "%s必须是 JSON 对象。" % label}
	return {"ok": true, "data": (json.data as Dictionary).duplicate(true)}


func _set_status(message: String, is_error: bool) -> void:
	status_label.text = message
	status_label.modulate = Color("ff817a") if is_error else Color("75d6a5")
