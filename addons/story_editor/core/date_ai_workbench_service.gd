@tool
extends RefCounted

const JsonService = preload("res://addons/story_editor/core/story_json_service.gd")

const TEMPLATE_PATH := "res://assets/data/interaction/date_story_templates.json"
const MAP_PATH := "res://assets/data/map/core/map_data.json"
const DATE_MANAGER_PATH := "res://scripts/data/date_story_manager.gd"
const PROMPT_MANAGER_PATH := "res://scripts/data/prompt_manager.gd"
const RELATIONSHIP_BOUNDARY_RULES := [
	{"minimum_stage": 5, "category": "身体亲密", "terms": ["十指相扣", "紧紧抱住", "拥入怀中", "靠在你肩上", "吻了上去", "亲了你"]},
	{"minimum_stage": 6, "category": "排他占有", "terms": ["你是我的", "不许看别人", "只能看着我", "只属于我", "不准离开我"]},
	{"minimum_stage": 7, "category": "明确告白", "terms": ["我爱你", "我喜欢上你了", "做我的女朋友", "做我的男朋友", "成为恋人"]},
	{"minimum_stage": 8, "category": "共同生活承诺", "terms": ["搬来和我住", "以后一起生活", "我们的家", "戴上戒指", "和我结婚"]},
	{"minimum_stage": 9, "category": "终身承诺", "terms": ["一辈子不分开", "永远不离开你", "唯一的归宿", "此生只爱你", "生生世世"]}
]

const INTERACTION_HOOKS := {
	"stroll": "一起寻找最适合留影的角度",
	"shopping": "替对方挑一件意外合适的小物",
	"exhibition": "各自选出最想分享的一件作品",
	"dining": "各自替对方选择一道想尝试的食物"
}


static func scan_templates(path: String = TEMPLATE_PATH) -> Array[Dictionary]:
	var result := JsonService.load_dictionary(path)
	var entries: Array[Dictionary] = []
	if not result.get("ok", false):
		return entries
	var config := result.get("data", {}) as Dictionary
	var type_defaults := config.get("type_defaults", {}) as Dictionary
	for type_value in type_defaults.keys():
		_append_variants(entries, str(type_value), "type", "", (type_defaults[type_value] as Dictionary).get("variants", []))
	var locations := config.get("locations", {}) as Dictionary
	for location_value in locations.keys():
		var location_id := str(location_value)
		var location := locations[location_value] as Dictionary
		_append_variants(entries, str(location.get("type_id", "stroll")), "location", location_id, location.get("variants", []))
	entries.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return str(left.get("id", "")) < str(right.get("id", "")))
	return entries


static func get_template_targets(path: String = TEMPLATE_PATH) -> Dictionary:
	var result := JsonService.load_dictionary(path)
	if not result.get("ok", false):
		return result
	var config := result.get("data", {}) as Dictionary
	return {
		"ok": true,
		"types": (config.get("type_defaults", {}) as Dictionary).keys(),
		"locations": (config.get("locations", {}) as Dictionary).keys()
	}


static func create_template(definition: Dictionary, path: String = TEMPLATE_PATH) -> Dictionary:
	var template_id := str(definition.get("id", "")).strip_edges()
	if template_id.is_empty() or not template_id.is_valid_filename() or template_id.contains(" ") or template_id.contains("."):
		return {"ok": false, "error": "模板 ID 只能包含字母、数字、下划线和连字符。"}
	var source := str(definition.get("source", "type"))
	var target_id := str(definition.get("location_id", "")) if source == "location" else str(definition.get("type_id", ""))
	if target_id.is_empty():
		return {"ok": false, "error": "请选择模板所属的类型或地点。"}
	var load_result := JsonService.load_dictionary(path)
	if not load_result.get("ok", false):
		return load_result
	var config := load_result.get("data", {}) as Dictionary
	var groups := config.get("locations", {}) as Dictionary if source == "location" else config.get("type_defaults", {}) as Dictionary
	if not groups.has(target_id) or not groups[target_id] is Dictionary:
		return {"ok": false, "error": "模板目标不存在：%s" % target_id}
	var group := groups[target_id] as Dictionary
	var variants := group.get("variants", []) as Array
	for variant_value in variants:
		if variant_value is Dictionary and str((variant_value as Dictionary).get("id", "")) == template_id:
			return {"ok": false, "error": "模板 ID 已存在，未覆盖原模板。"}
	var stored := {
		"id": template_id,
		"time_periods": ["morning", "afternoon", "evening"],
		"weather_tags": ["sunny", "cloudy", "overcast", "rainy"],
		"weight": 1,
		"outline_title": str(definition.get("outline_title", template_id)).strip_edges(),
		"outline_prompt": str(definition.get("outline_prompt", "围绕地点环境、共同任务和关系阶段展开一段自然约会。")),
		"must_have_beats": ["自然开场", "共同体验", "关系推进", "留有余韵的收束"],
		"mood_tags": ["自然", "细腻"],
		"settlement": {"intimacy": 2.0, "trust": 2.0}
	}
	variants.append(stored)
	group["variants"] = variants
	groups[target_id] = group
	config["locations" if source == "location" else "type_defaults"] = groups
	var save_result := JsonService.save_dictionary(path, config)
	if not save_result.get("ok", false):
		return save_result
	var created := stored.duplicate(true)
	created["source"] = source
	created["type_id"] = str(group.get("type_id", "stroll")) if source == "location" else target_id
	created["location_id"] = target_id if source == "location" else ""
	return {"ok": true, "template": created}


static func build_context(template: Dictionary, overrides: Dictionary = {}) -> Dictionary:
	var location_id := str(overrides.get("location_id", template.get("location_id", "sakura_avenue")))
	if location_id.is_empty():
		location_id = "sakura_avenue"
	var location := _load_location(location_id)
	var type_id := str(template.get("type_id", "stroll"))
	var period_id := str(overrides.get("period_id", "afternoon"))
	var segment := {
		"period_id": period_id,
		"period_label": {"morning": "上午", "afternoon": "下午", "evening": "夜晚"}.get(period_id, period_id),
		"location_id": location_id,
		"location_name": str(location.get("name", location_id)),
		"location_description": str(location.get("description", "暂无地点描述")),
		"bg_id": str(location.get("bg_id", "")),
		"type_id": type_id,
		"type_name": {"stroll": "漫步散心", "shopping": "逛街购物", "exhibition": "观影看展", "dining": "餐饮小聚"}.get(type_id, type_id),
		"template_id": str(template.get("id", "")),
		"template_title": str(template.get("outline_title", "约会片段")),
		"template_outline": str(template.get("outline_prompt", "")),
		"must_have_beats": template.get("must_have_beats", []).duplicate(true),
		"mood_tags": template.get("mood_tags", []).duplicate(true),
		"interaction_hook": str(overrides.get("interaction_hook", INTERACTION_HOOKS.get(type_id, "一起完成一件地点相关的小事"))),
		"micro_incident": str(overrides.get("micro_incident", "计划中出现一个需要两人临场配合的小意外")),
		"conversation_topic": str(overrides.get("conversation_topic", "彼此最近才注意到的变化")),
		"closing_style": str(overrides.get("closing_style", "留下一个下次再继续的小约定")),
		"settlement": template.get("settlement", {}).duplicate(true),
		"template_source": str(template.get("source", "type"))
	}
	var context := {
		"script_id": "date_workbench_preview",
		"runtime_generated": true,
		"story_category": "date_dynamic",
		"date_label": str(overrides.get("date_label", "2026年7月15日 星期三")),
		"current_story_time": period_id,
		"story_weather_id": str(overrides.get("weather_id", "sunny")),
		"story_weather_desc": str(overrides.get("weather_desc", "晴天")),
		"temperature": int(overrides.get("temperature", 24)),
		"character_id": str(overrides.get("character_id", "luna")),
		"character_name": str(overrides.get("character_name", "Luna")),
		"player_name": str(overrides.get("player_name", "玩家")),
		"player_title": str(overrides.get("player_title", "老师")),
		"relationship_stage": int(overrides.get("relationship_stage", 1)),
		"relationship_stage_title": str(overrides.get("relationship_stage_title", "熟悉阶段")),
		"relationship_stage_desc": str(overrides.get("relationship_stage_desc", "保持自然克制的相处边界。")),
		"intimacy": float(overrides.get("intimacy", 20.0)),
		"trust": float(overrides.get("trust", 20.0)),
		"relationship_flavor": str(overrides.get("relationship_flavor", "逐渐熟悉")),
		"mood_summary": str(overrides.get("mood_summary", "平静而期待")),
		"base_traits": str(overrides.get("base_traits", "安静、细腻、有分寸")),
		"dynamic_traits": str(overrides.get("dynamic_traits", "愿意自然回应，但不会突然越界")),
		"date_plan": [segment],
		"location_names": [segment.location_name],
		"summary_hint": segment.location_name,
		"creative_seed": int(overrides.get("creative_seed", 1))
	}
	return context


static func preview(template: Dictionary, overrides: Dictionary, raw_response: Variant) -> Dictionary:
	var context := build_context(template, overrides)
	var date_manager_script: GDScript = load(DATE_MANAGER_PATH)
	var prompt_manager_script: GDScript = load(PROMPT_MANAGER_PATH)
	if date_manager_script == null or prompt_manager_script == null:
		return {"error": "无法加载 AI 约会运行时服务。"}
	var date_manager = date_manager_script.new()
	var prompt_manager = prompt_manager_script.new()
	var fallback: Dictionary = date_manager.build_fallback_story(context)
	var sanitized: Dictionary = date_manager.sanitize_generated_story(raw_response, context, fallback)
	var used_fallback := _same_story(sanitized, fallback)
	return {
		"context": context,
		"prompt": prompt_manager.build_date_story_prompt(context),
		"raw": raw_response,
		"sanitized": sanitized,
		"fallback": fallback,
		"used_fallback": used_fallback,
		"fallback_reason": _fallback_reason(raw_response, context) if used_fallback else "",
		"audit": audit_response(raw_response, sanitized, context)
	}


static func analyze_batch(template: Dictionary, overrides: Dictionary, raw_responses: Array) -> Dictionary:
	var results: Array[Dictionary] = []
	for response_index in raw_responses.size():
		var preview_result := preview(template, overrides, raw_responses[response_index])
		var features := _extract_features(preview_result.get("sanitized", {}) as Dictionary, template)
		features["boundary_count"] = _count_audit_code(preview_result.get("audit", []) as Array, "relationship_boundary")
		results.append({
			"index": response_index,
			"preview": preview_result,
			"features": features,
			"max_similarity": 0.0,
			"average_similarity": 0.0,
			"most_similar_index": -1
		})
	for left_index in results.size():
		var similarity_total := 0.0
		var comparison_count := 0
		for right_index in results.size():
			if left_index == right_index:
				continue
			var similarity := _feature_similarity(results[left_index].features, results[right_index].features)
			similarity_total += similarity
			comparison_count += 1
			if similarity > float(results[left_index].max_similarity):
				results[left_index].max_similarity = similarity
				results[left_index].most_similar_index = right_index
		results[left_index].average_similarity = similarity_total / comparison_count if comparison_count > 0 else 0.0
	var batch_average := 0.0
	for result in results:
		batch_average += float(result.average_similarity)
	batch_average = batch_average / results.size() if not results.is_empty() else 0.0
	return {"results": results, "average_similarity": batch_average}


static func save_template(template: Dictionary, path: String = TEMPLATE_PATH) -> Dictionary:
	var load_result := JsonService.load_dictionary(path)
	if not load_result.get("ok", false):
		return load_result
	var config := load_result.get("data", {}) as Dictionary
	var template_id := str(template.get("id", ""))
	var source := str(template.get("source", "type"))
	var type_id := str(template.get("type_id", ""))
	var location_id := str(template.get("location_id", ""))
	var variants: Array
	if source == "location":
		var locations := config.get("locations", {}) as Dictionary
		if not locations.has(location_id):
			return {"ok": false, "error": "模板地点不存在：%s" % location_id}
		variants = (locations[location_id] as Dictionary).get("variants", []) as Array
	else:
		var type_defaults := config.get("type_defaults", {}) as Dictionary
		if not type_defaults.has(type_id):
			return {"ok": false, "error": "模板类型不存在：%s" % type_id}
		variants = (type_defaults[type_id] as Dictionary).get("variants", []) as Array
	for index in variants.size():
		if variants[index] is Dictionary and str((variants[index] as Dictionary).get("id", "")) == template_id:
			var stored := template.duplicate(true)
			stored.erase("source")
			stored.erase("type_id")
			stored.erase("location_id")
			variants[index] = stored
			return JsonService.save_dictionary(path, config)
	return {"ok": false, "error": "找不到模板：%s" % template_id}


static func audit_response(raw_response: Variant, sanitized: Dictionary, context: Dictionary) -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	if not raw_response is Dictionary:
		findings.append({"severity": "error", "message": "原始响应不是 JSON 对象。"})
		return findings
	var serialized := JSON.stringify(raw_response, "", false)
	for term in ["气氛变得柔和", "时间慢慢过去", "聊了很多", "气氛很好"]:
		var count := serialized.count(term)
		if count > 0:
			findings.append({"severity": "warning", "message": "出现泛化表达“%s” %d 次。" % [term, count]})
	if serialized.contains("```html") or serialized.contains("```json") or serialized.contains("[b]"):
		findings.append({"severity": "error", "message": "模型响应包含 Markdown 或 BBCode。"})
	var allowed_speakers := {"旁白": true, "player": true, str(context.get("character_id", "luna")): true}
	var segments := (raw_response as Dictionary).get("segments", []) as Array
	for segment_value in segments:
		if not segment_value is Dictionary:
			continue
		for line_value in (segment_value as Dictionary).get("lines", []):
			if line_value is Dictionary:
				var speaker := str((line_value as Dictionary).get("speaker", ""))
				if not allowed_speakers.has(speaker):
					findings.append({"severity": "error", "message": "非法 speaker：%s" % speaker})
	var sanitized_events := (((sanitized.get("chapters", {}) as Dictionary).get("start", {}) as Dictionary).get("events", []) as Array)
	var dialogue_count := 0
	for event_value in sanitized_events:
		if event_value is Dictionary and str((event_value as Dictionary).get("type", "")) == "dialogue":
			dialogue_count += 1
	if dialogue_count < 7:
		findings.append({"severity": "warning", "message": "有效对白仅 %d 行，低于稳定模式建议下限。" % dialogue_count})
	findings.append_array(_audit_relationship_boundary(sanitized_events, int(context.get("relationship_stage", 1))))
	return findings


static func _audit_relationship_boundary(events: Array, current_stage: int) -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	var matched_rules := {}
	for event_value in events:
		if not event_value is Dictionary or str((event_value as Dictionary).get("type", "")) != "dialogue":
			continue
		var content := str((event_value as Dictionary).get("content", ""))
		for rule_value in RELATIONSHIP_BOUNDARY_RULES:
			var rule := rule_value as Dictionary
			var minimum_stage := int(rule.get("minimum_stage", 1))
			if current_stage >= minimum_stage:
				continue
			for term_value in rule.get("terms", []):
				var term := str(term_value)
				var match_key := "%d:%s" % [minimum_stage, term]
				if content.contains(term) and not matched_rules.has(match_key):
					matched_rules[match_key] = true
					findings.append({
						"severity": "error",
						"code": "relationship_boundary",
						"category": str(rule.get("category", "关系越界")),
						"current_stage": current_stage,
						"required_stage": minimum_stage,
						"term": term,
						"message": "关系阶段越界：当前第%d阶段，“%s”至少需要第%d阶段（命中“%s”）。" % [current_stage, str(rule.get("category", "关系越界")), minimum_stage, term]
					})
	return findings


static func _count_audit_code(findings: Array, code: String) -> int:
	var count := 0
	for finding_value in findings:
		if finding_value is Dictionary and str((finding_value as Dictionary).get("code", "")) == code:
			count += 1
	return count


static func _extract_features(script_data: Dictionary, template: Dictionary) -> Dictionary:
	var events := (((script_data.get("chapters", {}) as Dictionary).get("start", {}) as Dictionary).get("events", []) as Array)
	var dialogue_lines: Array[String] = []
	var actions: Array[String] = []
	for event_value in events:
		if not event_value is Dictionary or str((event_value as Dictionary).get("type", "")) != "dialogue":
			continue
		var content := str((event_value as Dictionary).get("content", "")).strip_edges()
		dialogue_lines.append(content)
		var action_end := content.find("）")
		if content.begins_with("（") and action_end > 1:
			actions.append(content.substr(1, action_end - 1))
	var full_text := "".join(dialogue_lines)
	var beat_hits: Array[String] = []
	for beat_value in template.get("must_have_beats", []):
		var beat := str(beat_value)
		if not beat.is_empty() and full_text.contains(beat):
			beat_hits.append(beat)
	var closing := dialogue_lines.back() if not dialogue_lines.is_empty() else ""
	return {
		"text": full_text,
		"bigrams": _bigrams(full_text),
		"actions": actions,
		"beat_hits": beat_hits,
		"closing": closing,
		"dialogue_count": dialogue_lines.size()
	}


static func _feature_similarity(left: Dictionary, right: Dictionary) -> float:
	var text_score := _set_similarity(left.get("bigrams", {}) as Dictionary, right.get("bigrams", {}) as Dictionary)
	var action_score := _array_similarity(left.get("actions", []) as Array, right.get("actions", []) as Array)
	var beat_score := _array_similarity(left.get("beat_hits", []) as Array, right.get("beat_hits", []) as Array)
	var closing_score := _set_similarity(_bigrams(str(left.get("closing", ""))), _bigrams(str(right.get("closing", ""))))
	var weighted_total := text_score * 0.55
	var active_weight := 0.55
	if not (left.get("actions", []) as Array).is_empty() or not (right.get("actions", []) as Array).is_empty():
		weighted_total += action_score * 0.2
		active_weight += 0.2
	if not (left.get("beat_hits", []) as Array).is_empty() or not (right.get("beat_hits", []) as Array).is_empty():
		weighted_total += beat_score * 0.1
		active_weight += 0.1
	if not str(left.get("closing", "")).is_empty() or not str(right.get("closing", "")).is_empty():
		weighted_total += closing_score * 0.15
		active_weight += 0.15
	return snappedf(weighted_total / active_weight, 0.001)


static func _bigrams(text: String) -> Dictionary:
	var normalized := text.replace(" ", "").replace("\n", "")
	var result := {}
	if normalized.length() < 2:
		if not normalized.is_empty():
			result[normalized] = true
		return result
	for index in normalized.length() - 1:
		result[normalized.substr(index, 2)] = true
	return result


static func _array_similarity(left: Array, right: Array) -> float:
	var left_set := {}
	var right_set := {}
	for value in left:
		left_set[str(value)] = true
	for value in right:
		right_set[str(value)] = true
	return _set_similarity(left_set, right_set)


static func _set_similarity(left: Dictionary, right: Dictionary) -> float:
	if left.is_empty() and right.is_empty():
		return 0.0
	var intersection := 0
	var union := left.duplicate()
	for key_value in right.keys():
		union[key_value] = true
		if left.has(key_value):
			intersection += 1
	return float(intersection) / float(union.size())


static func _append_variants(entries: Array[Dictionary], type_id: String, source: String, location_id: String, variants_value: Variant) -> void:
	if not variants_value is Array:
		return
	for variant_value in variants_value:
		if variant_value is Dictionary:
			var entry := (variant_value as Dictionary).duplicate(true)
			entry["type_id"] = type_id
			entry["source"] = source
			entry["location_id"] = location_id
			entries.append(entry)


static func _load_location(location_id: String) -> Dictionary:
	var result := JsonService.load_dictionary(MAP_PATH)
	if not result.get("ok", false):
		return {}
	var data := result.get("data", {}) as Dictionary
	return (data.get("locations", {}) as Dictionary).get(location_id, {}) as Dictionary


static func _same_story(left: Dictionary, right: Dictionary) -> bool:
	return str(left.get("summary", "")) == str(right.get("summary", "")) and left.get("chapters", {}) == right.get("chapters", {})


static func _fallback_reason(raw_response: Variant, context: Dictionary) -> String:
	if not raw_response is Dictionary:
		return "原始响应不是 JSON 对象。"
	var source := raw_response as Dictionary
	var segments := source.get("segments", []) as Array
	if segments.is_empty():
		return "原始响应没有 segments。"
	if segments.size() != (context.get("date_plan", []) as Array).size():
		return "segments 数量与约会计划不一致。"
	return "清洗后没有满足地点覆盖或有效对白要求。"