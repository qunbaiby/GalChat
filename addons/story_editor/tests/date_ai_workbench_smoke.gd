extends SceneTree

const WorkbenchService = preload("res://addons/story_editor/core/date_ai_workbench_service.gd")
const WorkbenchScene = preload("res://addons/story_editor/ui/date_ai_workbench.tscn")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var workbench := WorkbenchScene.instantiate() as Window
	root.add_child(workbench)
	await process_frame
	await process_frame
	_expect(workbench.is_node_ready(), "AI 约会工作台没有完成初始化。")
	var input_tabs := workbench.get_node("Root/Body/InputAndResults/InputTabs") as TabContainer
	var planning_input := workbench.get_node("Root/Body/InputAndResults/InputTabs/生成输入") as Control
	var planning_tab := input_tabs.get_tab_idx_from_control(planning_input)
	_expect(planning_tab >= 0 and input_tabs.get_tab_title(planning_tab) == "策划参数", "AI 约会策划参数标签页初始化失败。")
	var planning_scroll := planning_input.get_node("PlanningScroll") as ScrollContainer
	var planning_content := planning_scroll.get_node("PlanningContent") as VBoxContainer
	_expect(planning_scroll != null, "AI 约会策划参数没有使用可滚动布局。")
	_expect(planning_content.size.x >= planning_scroll.size.x * 0.85, "AI 约会策划内容没有占满可用宽度。")
	for field_name in ["TaskEdit", "IncidentEdit", "TopicEdit", "ClosingEdit"]:
		var field := planning_input.find_child(field_name, true, false)
		_expect(field is TextEdit and field.custom_minimum_size.y >= 64, "策划参数 %s 不是可读的多行文本框。" % field_name)
		_expect(field is TextEdit and field.size.x >= planning_scroll.size.x * 0.85, "策划参数 %s 没有使用右侧可用空间（字段 %.0f / 视口 %.0f / 内容 %.0f）。" % [field_name, field.size.x, planning_scroll.size.x, planning_content.size.x])
	workbench.queue_free()
	await process_frame
	var templates := WorkbenchService.scan_templates()
	_expect(not templates.is_empty(), "没有扫描到 AI 约会模板。")
	if templates.is_empty():
		_finish()
		return
	var template := templates[0]
	var context := WorkbenchService.build_context(template, {"location_id": "sakura_avenue", "creative_seed": 42})
	_expect((context.get("date_plan", []) as Array).size() == 1, "没有构建约会计划。")
	var raw := {"summary": "两人在樱花大道完成了一次自然的共同体验。", "segments": [{"lines": [
		{"speaker": "旁白", "content": "樱花大道的风吹动枝梢。"},
		{"speaker": "luna", "content": "（抬头）今天的花开得很好。", "expression": "shy", "voice_instruction": "略带害羞地慢一点说"},
		{"speaker": "player", "content": "那就慢慢走一会儿。"},
		{"speaker": "invalid", "content": "这句应被清洗。"}
	]}]}
	var preview := WorkbenchService.preview(template, {"location_id": "sakura_avenue", "creative_seed": 42}, raw)
	_expect(str(preview.get("prompt", "")).contains("本次创意种子：42"), "Prompt 没有包含固定创意种子。")
	_expect(not bool(preview.get("used_fallback", true)), "合法原始响应错误地使用了 fallback。")
	var events := (((preview.get("sanitized", {}) as Dictionary).get("chapters", {}) as Dictionary).get("start", {}) as Dictionary).get("events", []) as Array
	_expect(_has_dialogue(events, "luna"), "清洗结果没有保留合法角色对白。")
	_expect(not _has_dialogue(events, "invalid"), "清洗结果保留了非法 speaker。")
	var voiced_line := _find_dialogue(events, "luna")
	_expect(str(voiced_line.get("expression", "")) == "shy", "清洗结果没有保留合法 expression。")
	_expect(str(voiced_line.get("voice_instruction", "")) == "略带害羞地慢一点说", "清洗结果没有保留 TTS 2.0 语音指令。")
	var fallback_preview := WorkbenchService.preview(template, {"location_id": "sakura_avenue"}, [])
	_expect(bool(fallback_preview.get("used_fallback", false)), "非法响应没有进入 fallback。")
	_expect(not str(fallback_preview.get("fallback_reason", "")).is_empty(), "fallback 没有提供原因。")
	var different_raw := {"summary": "不同体验", "segments": [{"lines": [
		{"speaker": "旁白", "content": "海边潮声盖过远处的人声。"},
		{"speaker": "luna", "content": "（停下脚步）我想把这一刻画下来。"},
		{"speaker": "player", "content": "那我替你记住光线。"}
	]}]}
	var batch: Dictionary = WorkbenchService.analyze_batch(template, {"location_id": "sakura_avenue"}, [raw, raw.duplicate(true), different_raw])
	var batch_results := batch.get("results", []) as Array
	_expect(batch_results.size() == 3, "批量分析没有保留全部结果。")
	if batch_results.size() == 3:
		_expect(float((batch_results[0] as Dictionary).get("max_similarity", 0.0)) >= 0.99, "相同结果没有被识别为高度重复。")
		_expect(int((batch_results[0] as Dictionary).get("most_similar_index", -1)) == 1, "相同结果没有互相匹配。")
		_expect(float((batch_results[2] as Dictionary).get("max_similarity", 1.0)) < 0.9, "明显不同的结果被错误判定为高度重复。")
	var confession_raw := {"summary": "阶段边界", "segments": [{"lines": [
		{"speaker": "luna", "content": "我爱你，也想成为你的恋人。"}
	]}]}
	var early_preview := WorkbenchService.preview(template, {"location_id": "sakura_avenue", "relationship_stage": 1}, confession_raw)
	_expect(_audit_count(early_preview.get("audit", []) as Array, "relationship_boundary") == 1, "初遇阶段没有识别明确告白越界。")
	var late_preview := WorkbenchService.preview(template, {"location_id": "sakura_avenue", "relationship_stage": 7}, confession_raw)
	_expect(_audit_count(late_preview.get("audit", []) as Array, "relationship_boundary") == 0, "倾心阶段错误地把明确告白标记为越界。")
	var caring_raw := {"summary": "普通关心", "segments": [{"lines": [
		{"speaker": "luna", "content": "今天有点冷，回去以后记得早点休息。"}
	]}]}
	var caring_preview := WorkbenchService.preview(template, {"location_id": "sakura_avenue", "relationship_stage": 1}, caring_raw)
	_expect(_audit_count(caring_preview.get("audit", []) as Array, "relationship_boundary") == 0, "初遇阶段的普通关心被误判为越界。")
	var boundary_batch := WorkbenchService.analyze_batch(template, {"location_id": "sakura_avenue", "relationship_stage": 1}, [confession_raw])
	var boundary_results := boundary_batch.get("results", []) as Array
	if not boundary_results.is_empty():
		_expect(int(((boundary_results[0] as Dictionary).get("features", {}) as Dictionary).get("boundary_count", 0)) == 1, "批量分析没有汇总关系越界数量。")
	_finish()


func _has_dialogue(events: Array, speaker: String) -> bool:
	for event_value in events:
		if event_value is Dictionary:
			var event := event_value as Dictionary
			if str(event.get("type", "")) == "dialogue" and str(event.get("speaker", "")) == speaker:
				return true
	return false


func _find_dialogue(events: Array, speaker: String) -> Dictionary:
	for event_value in events:
		if event_value is Dictionary:
			var event := event_value as Dictionary
			if str(event.get("type", "")) == "dialogue" and str(event.get("speaker", "")) == speaker:
				return event
	return {}


func _audit_count(findings: Array, code: String) -> int:
	var count := 0
	for finding_value in findings:
		if finding_value is Dictionary and str((finding_value as Dictionary).get("code", "")) == code:
			count += 1
	return count


func _finish() -> void:
	if failures.is_empty():
		print("DATE_AI_WORKBENCH_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("DATE_AI_WORKBENCH_SMOKE: %s" % failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)