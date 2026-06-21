class_name DateStoryManager
extends RefCounted

const TEMPLATE_PATH := "res://assets/data/interaction/date_story_templates.json"
const DATE_CONFIG_PATH := "res://assets/data/interaction/date_config.json"
const ALLOWED_EVENT_TYPES := {
	"background": true,
	"audio": true,
	"dialogue": true,
	"show_character": true,
	"move_character": true,
	"hide_character": true
}
const PERIOD_LABELS := {
	"morning": "上午",
	"afternoon": "下午",
	"evening": "夜晚"
}
const DATE_TYPE_NAMES := {
	"stroll": "漫步散心",
	"shopping": "逛街购物",
	"exhibition": "观影看展",
	"dining": "餐饮小聚"
}
const DATE_MIN_DIALOGUE_CHARS := 1500
const DATE_MIN_SEGMENT_DIALOGUE_CHARS := 320
const DATE_ACTION_COLOR_TAG := "#8fbc8f"
const DATE_FIXED_CHARACTER_ID := "luna"
const DATE_FIXED_CHARACTER_NAME := "Luna"

var _rng := RandomNumberGenerator.new()
var _template_config: Dictionary = {}
var _date_type_by_location: Dictionary = {}
var _runtime_profile = null


func _init() -> void:
	_rng.randomize()
	_load_template_config()
	_build_date_type_index()

func set_runtime_profile(profile_instance) -> void:
	_runtime_profile = profile_instance


func prepare_date_story_request(plan_list: Array) -> Dictionary:
	var profile = _runtime_profile if _runtime_profile != null else GameDataManager.profile
	var stage_conf: Dictionary = profile.get_current_stage_config() if profile else {}
	var story_time = GameDataManager.story_time_manager
	var weather_id: String = "sunny"
	var weather_desc: String = "晴天"
	var temperature: int = 20
	var date_label: String = ""
	var time_label: String = ""
	if story_time:
		weather_id = story_time.get_story_weather_id()
		weather_desc = story_time.get_story_weather_desc()
		temperature = int(story_time.get_current_day_config().get("temperature", 20))
		date_label = story_time.get_story_time_string()
		var date_dict: Dictionary = story_time.get_current_date_dict()
		date_label = "%d年%d月%d日 星期%s" % [
			int(date_dict.get("year", 2026)),
			int(date_dict.get("month", 1)),
			int(date_dict.get("day", 1)),
			_weekday_to_text(int(date_dict.get("weekday", 0)))
		]
		time_label = str(story_time.current_period)

	var plan_segments: Array = []
	var location_names: Array[String] = []
	for slot in plan_list:
		var segment: Dictionary = _build_plan_segment(slot, weather_id)
		if segment.is_empty():
			continue
		plan_segments.append(segment)
		location_names.append(str(segment.get("location_name", "")))

	var relationship_flavor: String = ""
	var mood_summary: String = ""
	var expression_name: String = ""
	var expression_desc: String = ""
	var base_traits: String = ""
	var dynamic_traits: String = ""
	var scene_setting: String = ""
	var important_notes: String = ""
	if profile:
		if GameDataManager.personality_system:
			relationship_flavor = str(GameDataManager.personality_system.get_relationship_flavor_label(profile)).strip_edges()
			base_traits = str(GameDataManager.personality_system.get_base_traits(profile)).strip_edges()
			dynamic_traits = str(GameDataManager.personality_system.get_dynamic_traits(profile)).strip_edges()
			mood_summary = str(GameDataManager.personality_system.get_mood_summary(profile)).strip_edges()
		scene_setting = str(stage_conf.get("scene_setting", "")).replace("{char_name}", DATE_FIXED_CHARACTER_NAME).strip_edges()
		important_notes = str(stage_conf.get("important_notes", "")).replace("{char_name}", DATE_FIXED_CHARACTER_NAME).strip_edges()
		var current_expression: String = str(profile.current_expression).strip_edges()
		if current_expression != "" and GameDataManager.expression_system:
			expression_name = str(GameDataManager.expression_system.expression_configs.get(current_expression, {}).get("expression_name", "")).strip_edges()
			expression_desc = str(GameDataManager.expression_system.get_expression_description(current_expression)).strip_edges()

	var script_id: String = _build_script_id()
	var context: Dictionary = {
		"script_id": script_id,
		"runtime_generated": true,
		"story_category": "date_dynamic",
		"date_label": date_label,
		"current_story_time": time_label,
		"story_weather_id": weather_id,
		"story_weather_desc": weather_desc,
		"temperature": temperature,
		"character_id": _get_character_id(),
		"character_name": DATE_FIXED_CHARACTER_NAME,
		"player_name": profile.player_name if profile else "玩家",
		"player_title": _get_player_title(),
		"relationship_stage": int(profile.current_stage) if profile else 1,
		"relationship_stage_title": str(stage_conf.get("stageTitle", "熟悉阶段")),
		"relationship_stage_desc": str(stage_conf.get("stageDesc", "请保持自然克制的相处边界。")).replace("{char_name}", DATE_FIXED_CHARACTER_NAME),
		"intimacy": float(profile.intimacy) if profile else 0.0,
		"trust": float(profile.trust) if profile else 0.0,
		"relationship_flavor": relationship_flavor,
		"mood_summary": mood_summary,
		"expression_name": expression_name,
		"expression_desc": expression_desc,
		"base_traits": base_traits,
		"dynamic_traits": dynamic_traits,
		"scene_setting": scene_setting,
		"important_notes": important_notes,
		"date_plan": plan_segments,
		"location_names": location_names,
		"summary_hint": "、".join(location_names)
	}

	return {
		"context": context,
		"fallback_script": build_fallback_story(context)
	}


func build_fallback_story(context: Dictionary) -> Dictionary:
	var plan_segments: Array = context.get("date_plan", [])
	if plan_segments.is_empty():
		return _build_empty_fallback_story(context)

	var raw_events: Array = []
	var char_id := str(context.get("character_id", "luna"))
	var char_name := str(context.get("character_name", "Luna"))
	var player_title := str(context.get("player_title", "老师"))
	var weather_desc := str(context.get("story_weather_desc", "晴天"))

	for i in range(plan_segments.size()):
		var segment: Dictionary = plan_segments[i]
		var location_name := str(segment.get("location_name", "未知地点"))
		var period_label := str(segment.get("period_label", "白天"))
		var bg_id := str(segment.get("bg_id", ""))
		var type_name := str(segment.get("type_name", "约会"))
		var outline_title := str(segment.get("template_title", "约会片段"))
		var outline_prompt := str(segment.get("template_outline", "你们在这里度过了一段轻松的相处时光。"))

		if bg_id != "":
			raw_events.append({
				"type": "background",
				"bg_id": bg_id,
				"transition_type": "fade" if i == 0 else "dissolve",
				"duration": 0.45
			})

		if i == 0:
			raw_events.append({
				"type": "audio",
				"audio_id": "luna_bgm",
				"audio_type": "bgm",
				"action": "play"
			})

		raw_events.append({
			"type": "dialogue",
			"speaker": "旁白",
			"content": "%s的%s里，我和%s来到了%s。%s的空气让脚步也慢了下来，像是很适合把心事一点点说开的时刻。"
				% [period_label, weather_desc, char_name, location_name, outline_title]
		})
		raw_events.append({
			"type": "dialogue",
			"speaker": char_id,
			"content": "%s，这里比我想的还要适合%s呢。（悄悄把目光落到你身上）和你一起过来之后，连心情都跟着安静下来了。"
				% [player_title, type_name]
		})
		raw_events.append({
			"type": "dialogue",
			"speaker": "player",
			"content": "你喜欢就好。今天就慢一点走，按我们的节奏来，不着急赶路。"
		})
		raw_events.append({
			"type": "dialogue",
			"speaker": char_id,
			"content": "嗯，那你可要陪我久一点。（轻轻弯起眼睛）难得有这样的时间，我还想把今天的感觉好好记下来。"
		})
		raw_events.append({
			"type": "dialogue",
			"speaker": "旁白",
			"content": "你们没有刻意加快脚步，只是顺着%s的气息慢慢往前走。话题从今天的安排聊到最近的小事，再从小事一点点落到彼此真正放在心上的东西。"
				% location_name
		})
		raw_events.append({
			"type": "dialogue",
			"speaker": char_id,
			"content": "其实我一直觉得，真正让人放松下来的不是地点本身，而是身边的人。（声音轻了一点）如果陪着我的人是你，我就会更想把自己心里的话说出来。"
		})
		raw_events.append({
			"type": "dialogue",
			"speaker": "player",
			"content": "那今天就把想说的都说给我听。我会记住，也会认真回应你。"
		})
		raw_events.append({
			"type": "dialogue",
			"speaker": char_id,
			"content": "你每次这样认真地看着我，我都会有种很奇怪的安心感。（抬手拢了拢耳边的发丝）明明只是普通地散步、聊天，可我就是会觉得，今天和别的时候不一样。"
		})
		raw_events.append({
			"type": "dialogue",
			"speaker": "旁白",
			"content": "风声、行人的脚步声、远处若有若无的背景音，都在这段相处里慢慢退到很远的地方，只剩下你们彼此的声音留在近处。"
		})
		raw_events.append({
			"type": "dialogue",
			"speaker": "player",
			"content": "如果你愿意的话，今天不只是陪你完成一次%s，我还想让你真正开心一点。"
				% type_name
		})
		raw_events.append({
			"type": "dialogue",
			"speaker": char_id,
			"content": "你已经做到了啊。（唇角忍不住扬起一点）因为只要你在旁边，我就不会觉得这些时间只是普通地过去了，而是真的被好好地留下来了。"
		})
		raw_events.append({
			"type": "dialogue",
			"speaker": "旁白",
			"content": "围绕着%s的轻声交谈在%s里缓缓延展开来，%s也在不知不觉间变成了今天最柔软的一段回忆。"
				% [outline_prompt, location_name, location_name]
		})

	var events := _polish_date_story_events(_ensure_minimum_story_length_raw(raw_events, context), context)

	var summary: String = "和%s一起度过了一场%s约会。" % [
		char_name,
		str(context.get("summary_hint", "特别"))
	]
	var memory_records: Array = [{
		"title": "动态约会回忆",
		"layer": "bond",
		"scope": "player_shared",
		"visibility": "prompt",
		"participants": ["player", char_id],
		"player_involved": true,
		"player_witnessed": true,
		"is_bond_mark": false,
		"content": summary
	}]

	return {
		"script_id": str(context.get("script_id", _build_script_id())),
		"runtime_generated": true,
		"story_category": "date_dynamic",
		"story_location_id": str(plan_segments[0].get("location_id", "")),
		"story_period": str(plan_segments[0].get("period_label", "上午")),
		"date_plan": plan_segments.duplicate(true),
		"location_names": context.get("location_names", []).duplicate(),
		"use_portraits": true,
		"memory_enabled": true,
		"memory_records": memory_records,
		"summary": summary,
		"date_settlement": build_date_settlement(context),
		"chapters": {
			"start": {
				"events": events
			}
		}
	}


func sanitize_generated_story(raw_script: Variant, context: Dictionary, fallback_script: Dictionary) -> Dictionary:
	if not raw_script is Dictionary:
		push_warning("[DateStoryManager] sanitize_generated_story: 原始返回不是 Dictionary，改用保底剧情")
		return fallback_script.duplicate(true)

	var safe_script: Dictionary = fallback_script.duplicate(true)
	var source: Dictionary = raw_script

	safe_script["script_id"] = str(context.get("script_id", safe_script.get("script_id", _build_script_id())))
	safe_script["runtime_generated"] = true
	safe_script["story_category"] = "date_dynamic"
	safe_script["story_location_id"] = _resolve_story_location_id(source, context, safe_script)
	safe_script["story_period"] = _resolve_story_period(source, context, safe_script)
	safe_script["date_plan"] = context.get("date_plan", []).duplicate(true)
	safe_script["location_names"] = context.get("location_names", []).duplicate(true)
	safe_script["use_portraits"] = bool(source.get("use_portraits", true))
	safe_script["memory_enabled"] = bool(source.get("memory_enabled", true))

	var summary_text: String = str(source.get("summary", "")).strip_edges()
	if summary_text != "":
		safe_script["summary"] = summary_text

	var memory_records: Array = _sanitize_memory_records(source.get("memory_records", []), context, str(safe_script.get("summary", "")))
	if not memory_records.is_empty():
		safe_script["memory_records"] = memory_records

	var chapters_data: Variant = source.get("chapters", {})
	var sanitized_events: Array = _sanitize_story_events(_extract_story_events(chapters_data, source, context), context, fallback_script)
	if sanitized_events.is_empty():
		push_warning("[DateStoryManager] sanitize_generated_story: 清洗后没有有效事件，改用保底剧情")
		return fallback_script.duplicate(true)
	if not _has_expected_date_coverage(sanitized_events, context):
		push_warning("[DateStoryManager] sanitize_generated_story: AI 剧情没有覆盖全部已选地点/时段，改用保底剧情")
		return fallback_script.duplicate(true)
	sanitized_events = _polish_date_story_events(_ensure_minimum_story_length_raw(sanitized_events, context), context)

	safe_script["chapters"] = {
		"start": {
			"events": sanitized_events
		}
	}
	safe_script["date_settlement"] = build_date_settlement(context, safe_script)
	return safe_script


func combine_generated_segment_scripts(segment_scripts: Array, context: Dictionary, fallback_script: Dictionary) -> Dictionary:
	if segment_scripts.is_empty():
		return fallback_script.duplicate(true)
	var combined_script: Dictionary = fallback_script.duplicate(true)
	var combined_events: Array = []
	var summary_parts: Array[String] = []
	var audio_added: bool = false
	for segment_script in segment_scripts:
		if not segment_script is Dictionary:
			continue
		var script_data: Dictionary = segment_script
		var summary: String = str(script_data.get("summary", "")).strip_edges()
		if summary != "":
			summary_parts.append(summary)
		var chapters: Dictionary = script_data.get("chapters", {})
		var start_chapter: Dictionary = chapters.get("start", {})
		var events: Variant = start_chapter.get("events", [])
		if not events is Array:
			continue
		for event_data in events:
			if not event_data is Dictionary:
				continue
			var event_copy: Dictionary = (event_data as Dictionary).duplicate(true)
			if str(event_copy.get("type", "")).strip_edges() == "audio":
				if audio_added:
					continue
				audio_added = true
			combined_events.append(event_copy)
	if combined_events.is_empty():
		return fallback_script.duplicate(true)

	var summary_text: String = "和%s一起度过了一场%s约会。" % [
		str(context.get("character_name", "Luna")),
		str(context.get("summary_hint", "特别"))
	]
	if not summary_parts.is_empty():
		summary_text = "；".join(summary_parts)

	combined_script["script_id"] = str(context.get("script_id", combined_script.get("script_id", _build_script_id())))
	combined_script["runtime_generated"] = true
	combined_script["story_category"] = "date_dynamic"
	combined_script["story_location_id"] = _resolve_story_location_id({}, context, combined_script)
	combined_script["story_period"] = _resolve_story_period({}, context, combined_script)
	combined_script["date_plan"] = context.get("date_plan", []).duplicate(true)
	combined_script["location_names"] = context.get("location_names", []).duplicate(true)
	combined_script["use_portraits"] = true
	combined_script["memory_enabled"] = true
	combined_script["summary"] = summary_text
	combined_script["memory_records"] = _sanitize_memory_records([], context, summary_text)
	combined_script["chapters"] = {
		"start": {
			"events": combined_events
		}
	}
	combined_script["date_settlement"] = build_date_settlement(context, combined_script)
	return combined_script


func build_date_settlement(context: Dictionary, script_data: Dictionary = {}) -> Dictionary:
	var plan_segments: Array = context.get("date_plan", [])
	var intimacy_delta: float = 0.0
	var trust_delta: float = 0.0
	for segment in plan_segments:
		if not segment is Dictionary:
			continue
		var settlement_conf: Dictionary = _normalize_settlement_config(segment.get("settlement", {}))
		intimacy_delta += float(settlement_conf.get("intimacy", 0.0))
		trust_delta += float(settlement_conf.get("trust", 0.0))

	if is_zero_approx(intimacy_delta) and is_zero_approx(trust_delta):
		var fallback_settlement: Dictionary = _default_settlement_config()
		intimacy_delta = float(fallback_settlement.get("intimacy", 2.0))
		trust_delta = float(fallback_settlement.get("trust", 2.0))

	var summary_text: String = str(script_data.get("summary", context.get("summary_hint", ""))).strip_edges()
	var location_names: Array = context.get("location_names", [])
	var location_text: String = "、".join(location_names)
	if location_text == "":
		location_text = "这次约会"
	var result_desc: String = "在%s的相处让你们更自然地靠近了，彼此之间多了一点默契和安心感。" % location_text
	if summary_text != "":
		result_desc = summary_text

	var settlement_memory: String = "在%s的这次约会里，你们的距离悄悄拉近了些。那些一起走过、一起停下来的时刻，也让她对你更多了几分亲近和信任。" % location_text

	return {
		"intimacy_delta": snappedf(intimacy_delta, 0.1),
		"trust_delta": snappedf(trust_delta, 0.1),
		"result_desc": result_desc,
		"memory_record": {
			"title": "约会后的关系推进",
			"layer": "bond",
			"scope": "player_shared",
			"visibility": "prompt",
			"participants": ["player", str(context.get("character_id", "luna"))],
			"player_involved": true,
			"player_witnessed": true,
			"is_bond_mark": false,
			"content": settlement_memory
		}
	}


func _build_plan_segment(slot: Dictionary, weather_id: String) -> Dictionary:
	var location_id := str(slot.get("location_id", "")).strip_edges()
	if location_id == "":
		return {}

	var period_id := str(slot.get("period", "")).strip_edges()
	var type_id := str(slot.get("type_id", "")).strip_edges()
	if type_id == "":
		type_id = _resolve_type_id(location_id)

	var loc_data: Dictionary = MapDataManager.get_location(location_id)
	var location_conf: Dictionary = _template_config.get("locations", {}).get(location_id, {})
	var type_conf: Dictionary = _template_config.get("type_defaults", {}).get(type_id, {})
	var variant_info: Dictionary = _select_template_variant(type_id, location_id, period_id, weather_id)
	var variant: Dictionary = variant_info.get("variant", {})
	var loading_hints: Array[String] = _resolve_loading_hints(location_conf, type_conf, weather_id, period_id)

	return {
		"period_id": period_id,
		"period_label": PERIOD_LABELS.get(period_id, period_id),
		"location_id": location_id,
		"location_name": str(loc_data.get("name", location_id)),
		"location_description": str(loc_data.get("description", "暂无地点描述")),
		"bg_id": str(loc_data.get("bg_id", "")),
		"type_id": type_id,
		"type_name": DATE_TYPE_NAMES.get(type_id, type_id),
		"template_id": str(variant.get("id", "")),
		"template_title": str(variant.get("outline_title", "约会片段")),
		"template_outline": str(variant.get("outline_prompt", "围绕这个地点生成一段自然细腻的约会片段。")),
		"must_have_beats": variant.get("must_have_beats", []),
		"mood_tags": variant.get("mood_tags", []),
		"loading_hints": loading_hints,
		"loading_hint": loading_hints[0] if loading_hints.size() > 0 else "",
		"settlement": _normalize_settlement_config(variant.get("settlement", {})),
		"template_source": str(variant_info.get("source", "fallback"))
	}


func _resolve_loading_hints(location_conf: Dictionary, type_conf: Dictionary, weather_id: String, period_id: String) -> Array[String]:
	var location_weather_hints: Array[String] = _extract_loading_hints_from_weather(location_conf, weather_id)
	if not location_weather_hints.is_empty():
		return location_weather_hints

	var location_period_hints: Array[String] = _extract_loading_hints_from_period(location_conf, period_id)
	if not location_period_hints.is_empty():
		return location_period_hints

	var location_hints: Array[String] = _extract_loading_hints(location_conf)
	if not location_hints.is_empty():
		return location_hints

	var type_weather_hints: Array[String] = _extract_loading_hints_from_weather(type_conf, weather_id)
	if not type_weather_hints.is_empty():
		return type_weather_hints

	var type_period_hints: Array[String] = _extract_loading_hints_from_period(type_conf, period_id)
	if not type_period_hints.is_empty():
		return type_period_hints

	var type_hints: Array[String] = _extract_loading_hints(type_conf)
	if not type_hints.is_empty():
		return type_hints

	return ["Luna 正在想着，这次见面要不要先对你笑一下..."]


func _extract_loading_hints_from_weather(source: Dictionary, weather_id: String) -> Array[String]:
	var weather_map: Dictionary = source.get("weather_loading_hints", {})
	if weather_map.is_empty():
		return []
	return _variant_to_string_array(weather_map.get(weather_id, []))


func _extract_loading_hints_from_period(source: Dictionary, period_id: String) -> Array[String]:
	var period_map: Dictionary = source.get("period_loading_hints", {})
	if period_map.is_empty():
		return []
	return _variant_to_string_array(period_map.get(period_id, []))


func _extract_loading_hints(source: Dictionary) -> Array[String]:
	var hints: Array[String] = _variant_to_string_array(source.get("loading_hints", []))
	if not hints.is_empty():
		return hints
	var single_hint := str(source.get("loading_hint", "")).strip_edges()
	if single_hint != "":
		return [single_hint]
	return []


func _variant_to_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item in value:
			var text := str(item).strip_edges()
			if text != "" and not result.has(text):
				result.append(text)
	return result


func _select_template_variant(type_id: String, location_id: String, period_id: String, weather_id: String) -> Dictionary:
	var location_conf: Dictionary = _template_config.get("locations", {}).get(location_id, {})
	var variants: Array = location_conf.get("variants", [])
	var matched: Dictionary = _pick_best_variant(variants, period_id, weather_id)
	if not matched.is_empty():
		return {"source": "location", "variant": matched}

	var type_conf: Dictionary = _template_config.get("type_defaults", {}).get(type_id, {})
	var fallback_variants: Array = type_conf.get("variants", [])
	var fallback: Dictionary = _pick_best_variant(fallback_variants, period_id, weather_id)
	if not fallback.is_empty():
		return {"source": "type", "variant": fallback}

	return {
		"source": "builtin",
		"variant": {
			"id": "%s_%s_default" % [type_id, period_id],
			"outline_title": "自然相处",
			"outline_prompt": "两人在这个地点自然相处，从轻松寒暄逐渐过渡到更柔和的情感交流，最后留下余韵。",
			"must_have_beats": ["见面寒暄", "共同体验", "情绪靠近", "余韵收束"],
			"mood_tags": ["轻松", "自然"],
			"settlement": _default_settlement_config()
		}
	}


func _pick_best_variant(variants: Array, period_id: String, weather_id: String) -> Dictionary:
	if variants.is_empty():
		return {}

	var exact: Array = []
	var time_only: Array = []
	var weather_only: Array = []
	var fallback: Array = []
	for item in variants:
		if not item is Dictionary:
			continue
		var variant: Dictionary = item
		var time_match: bool = _match_filter_list(variant.get("time_periods", []), period_id)
		var weather_match: bool = _match_filter_list(variant.get("weather_tags", []), weather_id)
		if time_match and weather_match:
			exact.append(variant)
		elif time_match:
			time_only.append(variant)
		elif weather_match:
			weather_only.append(variant)
		else:
			fallback.append(variant)

	var pool: Array = exact
	if pool.is_empty():
		pool = time_only
	if pool.is_empty():
		pool = weather_only
	if pool.is_empty():
		pool = fallback
	return _pick_weighted_variant(pool)


func _pick_weighted_variant(variants: Array) -> Dictionary:
	if variants.is_empty():
		return {}

	var total_weight: int = 0
	for item in variants:
		total_weight += max(1, int(item.get("weight", 1)))

	var roll: int = _rng.randi_range(1, total_weight)
	var cursor: int = 0
	for item in variants:
		cursor += max(1, int(item.get("weight", 1)))
		if roll <= cursor:
			return item.duplicate(true)
	return variants[0].duplicate(true)


func _extract_story_events(chapters_data: Variant, source: Dictionary, context: Dictionary) -> Array:
	var segment_events: Array = _build_events_from_story_segments(source.get("segments", []), context)
	if not segment_events.is_empty():
		return segment_events
	if chapters_data is Dictionary:
		var start_chapter: Dictionary = chapters_data.get("start", {})
		var start_events: Variant = start_chapter.get("events", [])
		if start_events is Array:
			return start_events
	if source.get("events", null) is Array:
		return source.get("events", [])
	return []


func _build_events_from_story_segments(raw_segments: Variant, context: Dictionary) -> Array:
	if not raw_segments is Array:
		return []
	var plan_segments: Array = context.get("date_plan", [])
	if plan_segments.is_empty():
		return []
	var built_events: Array = []
	var segments: Array = raw_segments
	for i in range(plan_segments.size()):
		var plan_segment: Dictionary = plan_segments[i]
		var bg_id: String = str(plan_segment.get("bg_id", "")).strip_edges()
		if bg_id != "":
			built_events.append({
				"type": "background",
				"bg_id": bg_id,
				"transition_type": "fade" if i == 0 else "dissolve",
				"duration": 0.45
			})
		var dialogue_events: Array = []
		if i < segments.size() and segments[i] is Dictionary:
			dialogue_events = _sanitize_segment_lines((segments[i] as Dictionary).get("lines", []), context)
		if dialogue_events.is_empty():
			dialogue_events = _build_segment_fallback_lines(plan_segment, context)
		dialogue_events = _ensure_segment_story_depth(dialogue_events, plan_segment, context)
		built_events.append_array(dialogue_events)
	return built_events


func _sanitize_segment_lines(raw_lines: Variant, context: Dictionary) -> Array:
	if not raw_lines is Array:
		return []
	var results: Array = []
	var char_id: String = str(context.get("character_id", "luna")).to_lower()
	var char_name: String = str(context.get("character_name", "Luna")).strip_edges().to_lower()
	for item in raw_lines:
		if not item is Dictionary:
			continue
		var line_data: Dictionary = item
		var speaker: String = _normalize_speaker_id(str(line_data.get("speaker", "")), char_id, char_name)
		var content: String = str(line_data.get("content", "")).strip_edges()
		if speaker == "" or content == "":
			continue
		results.append({
			"type": "dialogue",
			"speaker": speaker,
			"content": content
		})
	return results


func _build_segment_fallback_lines(segment: Dictionary, context: Dictionary) -> Array:
	var char_id: String = str(context.get("character_id", "luna")).to_lower()
	var player_title: String = str(context.get("player_title", "老师")).strip_edges()
	var location_name: String = str(segment.get("location_name", "今天的约会地点")).strip_edges()
	var type_name: String = str(segment.get("type_name", "约会")).strip_edges()
	var outline_title: String = str(segment.get("template_title", "这段相处")).strip_edges()
	var outline_prompt: String = str(segment.get("template_outline", "你们慢慢把话题说开了。")).strip_edges()
	return [
		{
			"type": "dialogue",
			"speaker": "旁白",
			"content": "%s的气氛慢慢安静下来，你们顺着%s的节奏，把今天的心情一点点说开。"
				% [location_name, outline_title]
		},
		{
			"type": "dialogue",
			"speaker": char_id,
			"content": "%s，这里真的比我想的更适合%s。（轻轻看向你）只要和你待在一起，我就会不自觉放松下来。"
				% [player_title, type_name]
		},
		{
			"type": "dialogue",
			"speaker": "player",
			"content": "那就慢一点吧。今天不用急着赶路，我更想把这段时间好好留住。"
		},
		{
			"type": "dialogue",
			"speaker": char_id,
			"content": "你每次这样认真地回应我，我都会更想把真实的心情告诉你。（指尖轻轻拢住衣角）"
		},
		{
			"type": "dialogue",
			"speaker": "旁白",
			"content": outline_prompt if outline_prompt != "" else "你们的对话顺着眼前的景色慢慢延展开来，气氛也一点点变得柔和。"
		},
		{
			"type": "dialogue",
			"speaker": "player",
			"content": "和你一起把这些细碎的感受慢慢说出来，其实比我想的还要珍贵。"
		},
		{
			"type": "dialogue",
			"speaker": char_id,
			"content": "所以我才会越来越期待这种时候啊。（声音轻了下来）因为只有待在你身边，我才会觉得这些心情真的被认真接住了。"
		}
	]


func _ensure_segment_story_depth(events: Array, segment: Dictionary, context: Dictionary) -> Array:
	var result: Array = events.duplicate(true)
	var char_id: String = str(context.get("character_id", "luna")).to_lower()
	var player_title: String = str(context.get("player_title", "老师")).strip_edges()
	var location_name: String = str(segment.get("location_name", "今天的约会地点")).strip_edges()
	var type_name: String = str(segment.get("type_name", "约会")).strip_edges()
	var outline_prompt: String = str(segment.get("template_outline", "你们慢慢把今天的心事说开了。")).strip_edges()
	while _count_dialogue_characters(result) < DATE_MIN_SEGMENT_DIALOGUE_CHARS:
		result.append_array([
			{
				"type": "dialogue",
				"speaker": "旁白",
				"content": "围绕着%s的细碎话题被一点点展开，你们没有刻意追赶时间，只是顺着当下的气氛继续往前走。"
					% location_name
			},
			{
				"type": "dialogue",
				"speaker": char_id,
				"content": "%s，其实像这样和你待在%s里，我会很自然地想把平时不会轻易说出口的话告诉你。"
					% [player_title, location_name]
			},
			{
				"type": "dialogue",
				"speaker": "player",
				"content": "那就继续说吧，我在听。只要是和你有关的心情，我都想认真记住。"
			},
			{
				"type": "dialogue",
				"speaker": char_id,
				"content": "你总是会把一句很普通的话，说得让人完全放下戒心。（眼神柔和下来）所以这次%s，才会让我越来越舍不得太快结束。"
					% type_name
			},
			{
				"type": "dialogue",
				"speaker": "旁白",
				"content": outline_prompt if outline_prompt != "" else "你们的对话顺着眼前的景色慢慢延展开来，气氛也一点点变得柔和。"
			}
		])
	return result


func _sanitize_story_events(raw_events: Array, context: Dictionary, fallback_script: Dictionary) -> Array:
	var sanitized: Array = []
	var char_id: String = str(context.get("character_id", "luna")).to_lower()
	var char_name: String = str(context.get("character_name", "Luna")).strip_edges().to_lower()
	var first_bg_id: String = _get_first_bg_id(context)
	var allowed_bg_ids: Array = _collect_allowed_bg_ids(context)

	for item in raw_events:
		if not item is Dictionary:
			continue
		var event_data: Dictionary = item.duplicate(true)
		var event_type := str(event_data.get("type", "")).strip_edges()
		if not ALLOWED_EVENT_TYPES.has(event_type):
			continue

		match event_type:
			"dialogue":
				var content := str(event_data.get("content", "")).strip_edges()
				if content == "":
					continue
				var speaker: String = _normalize_speaker_id(str(event_data.get("speaker", "")), char_id, char_name)
				if speaker == "":
					speaker = "旁白"
				event_data["speaker"] = speaker
				event_data["content"] = _colorize_action_descriptions(content)
			"background":
				var bg_id := str(event_data.get("bg_id", "")).strip_edges()
				if bg_id != "" and not allowed_bg_ids.has(bg_id):
					bg_id = first_bg_id
				if bg_id == "":
					bg_id = first_bg_id
				if bg_id == "":
					continue
				event_data["bg_id"] = bg_id
				event_data["transition_type"] = str(event_data.get("transition_type", "fade"))
				event_data["duration"] = float(event_data.get("duration", 0.45))
			"audio":
				var audio_id := str(event_data.get("audio_id", "")).strip_edges()
				var action := str(event_data.get("action", "play")).strip_edges()
				if action == "play" and audio_id == "":
					audio_id = "luna_bgm"
				event_data["audio_id"] = audio_id
				event_data["audio_type"] = str(event_data.get("audio_type", "bgm"))
				event_data["action"] = action
			"show_character", "move_character", "hide_character":
				# 约会动态剧本统一由后处理重建立绘出现时机，避免一开始就把角色立绘摆上来。
				continue

		sanitized.append(event_data)

	if sanitized.is_empty():
		return []

	if not _has_background_event(sanitized) and first_bg_id != "":
		sanitized.insert(0, {
			"type": "background",
			"bg_id": first_bg_id,
			"transition_type": "fade",
			"duration": 0.45
		})

	if not _has_audio_event(sanitized):
		var insert_index: int = 1 if sanitized.size() > 0 else 0
		sanitized.insert(insert_index, {
			"type": "audio",
			"audio_id": "luna_bgm",
			"audio_type": "bgm",
			"action": "play"
		})

	if not _has_dialogue_event(sanitized):
		return _extract_story_events(fallback_script.get("chapters", {}), fallback_script, context)

	return sanitized


func _colorize_action_descriptions(text: String) -> String:
	var result := text
	var cn_regex := RegEx.new()
	if cn_regex.compile("（[^（）]+）") == OK:
		var matches := cn_regex.search_all(result)
		for i in range(matches.size() - 1, -1, -1):
			var original := matches[i].get_string()
			var colored := "[color=%s]%s[/color]" % [DATE_ACTION_COLOR_TAG, original]
			result = result.substr(0, matches[i].get_start()) + colored + result.substr(matches[i].get_end())

	var en_regex := RegEx.new()
	if en_regex.compile("\\([^()]+\\)") == OK:
		var en_matches := en_regex.search_all(result)
		for i in range(en_matches.size() - 1, -1, -1):
			var original := en_matches[i].get_string()
			if original.find("[/color]") != -1:
				continue
			var colored := "[color=%s]%s[/color]" % [DATE_ACTION_COLOR_TAG, original]
			result = result.substr(0, en_matches[i].get_start()) + colored + result.substr(en_matches[i].get_end())
	return result


func _ensure_minimum_story_length_raw(events: Array, context: Dictionary) -> Array:
	var result: Array = events.duplicate(true)
	var char_id := str(context.get("character_id", "luna"))
	var player_title := str(context.get("player_title", "老师"))
	var plan_segments: Array = context.get("date_plan", [])
	var last_segment: Dictionary = plan_segments[plan_segments.size() - 1] if not plan_segments.is_empty() else {}
	var location_name := str(last_segment.get("location_name", "今天的约会地点"))
	var type_name := str(last_segment.get("type_name", "约会"))

	while _count_dialogue_characters(result) < DATE_MIN_DIALOGUE_CHARS:
		result.append({
			"type": "dialogue",
			"speaker": "旁白",
			"content": "时间像是被故意放慢了一点，你们没有谁急着把这段相处推向终点，只是在%s的气氛里，把那些原本藏得很深的话也一点点说了出来。"
				% location_name
		})
		result.append({
			"type": "dialogue",
			"speaker": char_id,
			"content": "%s，你有没有发现，只要像这样和你待久一点，我就会开始舍不得让今天太快结束。（轻轻眨了眨眼）明明只是一次%s，可我已经在偷偷把它当成很重要的回忆了。"
				% [player_title, type_name]
		})
		result.append({
			"type": "dialogue",
			"speaker": "player",
			"content": "那就别急着结束。今天剩下的时间，我都愿意继续陪你慢慢走、慢慢聊。"
		})
		result.append({
			"type": "dialogue",
			"speaker": char_id,
			"content": "你总是能把很普通的话，说得让人一下子安心下来。（指尖轻轻攥住衣角）所以我才会越来越想依赖这种感觉，想把更多真实的心情交给你。"
		})
		result.append({
			"type": "dialogue",
			"speaker": "旁白",
			"content": "你们的话题从眼前的景色、今天发生的小事，慢慢延伸到更久以后会不会再一起出门、会不会在下一次见面时继续记得彼此此刻的语气与神情。"
		})
		result.append({
			"type": "dialogue",
			"speaker": char_id,
			"content": "如果下次还能和你一起出来，我想我大概会提前很多天就开始期待吧。（唇边带着一点不好意思的笑）因为像今天这样被你认真对待的感觉，真的很容易让人上瘾。"
		})
		result.append({
			"type": "dialogue",
			"speaker": "player",
			"content": "那就把这份期待留到下次。等你想好了，我们再把想去的地方一个个走完。"
		})
		result.append({
			"type": "dialogue",
			"speaker": char_id,
			"content": "%s，那你可不准反悔。（目光柔软了下来）因为我已经开始认真地把“和你一起去做很多事”这件事，放进以后的计划里了。"
				% player_title
		})

	return result


func _count_dialogue_characters(events: Array) -> int:
	var total := 0
	for event_data in events:
		if not event_data is Dictionary:
			continue
		if str(event_data.get("type", "")) != "dialogue":
			continue
		var text := str(event_data.get("content", ""))
		var bbcode_regex := RegEx.new()
		if bbcode_regex.compile("\\[.*?\\]") == OK:
			text = bbcode_regex.sub(text, "", true)
		total += text.length()
	return total


func _polish_date_story_events(events: Array, context: Dictionary) -> Array:
	var polished: Array = []
	var char_id := str(context.get("character_id", "luna")).to_lower()
	var char_name := str(context.get("character_name", "Luna"))
	var plan_segments: Array = context.get("date_plan", [])
	var segment_cursor := 0
	var char_visible := false
	var has_audio := false
	var period_card_inserted := false

	for event_data in events:
		if not event_data is Dictionary:
			continue
		var event_type := str(event_data.get("type", ""))
		match event_type:
			"background":
				if char_visible:
					polished.append({
						"type": "hide_character",
						"character": char_id,
						"display_name": char_name,
						"animation": "fade_out"
					})
					char_visible = false
				var segment_index := _find_segment_index_for_background(str(event_data.get("bg_id", "")), plan_segments, segment_cursor)
				var period_label := "白天"
				var location_name := "未知地点"
				if segment_index != -1:
					var segment_data: Dictionary = plan_segments[segment_index]
					segment_cursor = segment_index + 1
					period_label = str(segment_data.get("period_label", "白天"))
					location_name = str(segment_data.get("location_name", "未知地点"))
				polished.append({
					"type": "period_card",
					"bg_id": str(event_data.get("bg_id", "")),
					"period_label": period_label,
					"location_name": location_name,
					"hold_duration": 3.0
				})
				period_card_inserted = true
				char_visible = false
			"audio":
				has_audio = true
				polished.append(event_data.duplicate(true))
			"dialogue":
				if not period_card_inserted:
					var fallback_segment := _resolve_segment_for_period_card(plan_segments, segment_cursor)
					if not fallback_segment.is_empty():
						if char_visible:
							polished.append({
								"type": "hide_character",
								"character": char_id,
								"display_name": char_name,
								"animation": "fade_out"
							})
							char_visible = false
						polished.append({
							"type": "period_card",
							"bg_id": str(fallback_segment.get("bg_id", "")),
							"period_label": str(fallback_segment.get("period_label", "白天")),
							"location_name": str(fallback_segment.get("location_name", "未知地点")),
							"hold_duration": 3.0
						})
						period_card_inserted = true
						segment_cursor = mini(segment_cursor + 1, plan_segments.size())
				var speaker := str(event_data.get("speaker", "")).strip_edges().to_lower()
				var dialogue_event: Dictionary = event_data.duplicate(true)
				dialogue_event["content"] = _colorize_action_descriptions(str(dialogue_event.get("content", "")))
				if speaker == char_id:
					if not char_visible:
						polished.append({
							"type": "show_character",
							"character": char_id,
							"display_name": char_name,
							"position": "center",
							"expression": "calm",
							"animation": "fade_in",
							"focus": true
						})
						char_visible = true
					polished.append(dialogue_event)
				else:
					polished.append(dialogue_event)

	if not has_audio:
		var insert_index := 1 if polished.size() > 0 else 0
		polished.insert(insert_index, {
			"type": "audio",
			"audio_id": "luna_bgm",
			"audio_type": "bgm",
			"action": "play"
		})

	return polished


func _find_segment_index_for_background(bg_id: String, plan_segments: Array, start_index: int) -> int:
	if plan_segments.is_empty():
		return -1
	for i in range(start_index, plan_segments.size()):
		var segment: Dictionary = plan_segments[i]
		if str(segment.get("bg_id", "")).strip_edges() == bg_id.strip_edges():
			return i
	if start_index < plan_segments.size():
		return start_index
	return plan_segments.size() - 1


func _resolve_segment_for_period_card(plan_segments: Array, segment_cursor: int) -> Dictionary:
	if plan_segments.is_empty():
		return {}
	if segment_cursor >= 0 and segment_cursor < plan_segments.size():
		return (plan_segments[segment_cursor] as Dictionary).duplicate(true)
	return (plan_segments[plan_segments.size() - 1] as Dictionary).duplicate(true)


func _build_segment_intro(segment: Dictionary) -> String:
	return "【%s · %s】" % [
		str(segment.get("period_label", "白天")),
		str(segment.get("location_name", "未知地点"))
	]


func _sanitize_memory_records(raw_records: Variant, context: Dictionary, summary_text: String) -> Array:
	var results: Array = []
	if raw_records is Array:
		for item in raw_records:
			if not item is Dictionary:
				continue
			var record: Dictionary = item.duplicate(true)
			var content := str(record.get("content", "")).strip_edges()
			if content == "":
				continue
			if not record.has("participants"):
				record["participants"] = ["player", str(context.get("character_id", "luna"))]
			record["player_involved"] = bool(record.get("player_involved", true))
			record["player_witnessed"] = bool(record.get("player_witnessed", true))
			record["scope"] = str(record.get("scope", "player_shared"))
			record["visibility"] = str(record.get("visibility", "prompt"))
			record["layer"] = str(record.get("layer", "bond"))
			results.append(record)

	if results.is_empty():
		results.append({
			"title": "动态约会回忆",
			"layer": "bond",
			"scope": "player_shared",
			"visibility": "prompt",
			"participants": ["player", str(context.get("character_id", "luna"))],
			"player_involved": true,
			"player_witnessed": true,
			"is_bond_mark": false,
			"content": summary_text if summary_text != "" else "你们一起完成了一次气氛温柔的约会。"
		})
	return results


func _build_empty_fallback_story(context: Dictionary) -> Dictionary:
	return {
		"script_id": str(context.get("script_id", _build_script_id())),
		"runtime_generated": true,
		"story_category": "date_dynamic",
		"story_location_id": "",
		"story_period": "上午",
		"use_portraits": true,
		"memory_enabled": true,
		"memory_records": [{
			"title": "动态约会回忆",
			"layer": "bond",
			"scope": "player_shared",
			"visibility": "prompt",
			"participants": ["player", str(context.get("character_id", "luna"))],
			"player_involved": true,
			"player_witnessed": true,
			"is_bond_mark": false,
			"content": "你们约好了见面，也因此留下了一段新的期待。"
		}],
		"summary": "一场新的约会正在开始。",
		"chapters": {
			"start": {
				"events": [{
					"type": "dialogue",
					"speaker": "旁白",
					"content": "原本该展开的约会脚本有些模糊，但两个人仍旧带着一点期待，朝今天的相处时间走去。"
				}]
			}
		}
	}


func _resolve_story_location_id(source: Dictionary, context: Dictionary, fallback_script: Dictionary) -> String:
	var location_id := str(source.get("story_location_id", "")).strip_edges()
	if location_id != "":
		return location_id
	var segments: Array = context.get("date_plan", [])
	if not segments.is_empty():
		return str(segments[0].get("location_id", ""))
	return str(fallback_script.get("story_location_id", ""))


func _resolve_story_period(source: Dictionary, context: Dictionary, fallback_script: Dictionary) -> String:
	var period := str(source.get("story_period", "")).strip_edges()
	if period != "":
		return period
	var segments: Array = context.get("date_plan", [])
	if not segments.is_empty():
		return str(segments[0].get("period_label", "上午"))
	return str(fallback_script.get("story_period", "上午"))


func _get_first_bg_id(context: Dictionary) -> String:
	var segments: Array = context.get("date_plan", [])
	if segments.is_empty():
		return ""
	return str(segments[0].get("bg_id", ""))


func _collect_allowed_bg_ids(context: Dictionary) -> Array:
	var result: Array = []
	var segments: Array = context.get("date_plan", [])
	for segment in segments:
		if not segment is Dictionary:
			continue
		var bg_id := str(segment.get("bg_id", "")).strip_edges()
		if bg_id != "" and not result.has(bg_id):
			result.append(bg_id)
	return result


func _has_background_event(events: Array) -> bool:
	for event_data in events:
		if str(event_data.get("type", "")) == "background":
			return true
	return false


func _has_audio_event(events: Array) -> bool:
	for event_data in events:
		if str(event_data.get("type", "")) == "audio":
			return true
	return false


func _has_character_show_event(events: Array) -> bool:
	for event_data in events:
		var event_type := str(event_data.get("type", ""))
		if event_type == "show_character" or event_type == "move_character":
			return true
	return false


func _has_dialogue_event(events: Array) -> bool:
	for event_data in events:
		if str(event_data.get("type", "")) == "dialogue":
			return true
	return false


func _normalize_speaker_id(raw_speaker: String, char_id: String, char_name: String) -> String:
	var normalized := raw_speaker.strip_edges().to_lower()
	match normalized:
		"", "narrator", "旁白":
			return "旁白"
		"player", "玩家", "我":
			return "player"
		char_id:
			return char_id
		char_name:
			return char_id
		_:
			return ""


func _has_expected_date_coverage(events: Array, context: Dictionary) -> bool:
	var expected_bg_ids: Array = _collect_allowed_bg_ids(context)
	if expected_bg_ids.size() <= 1:
		return true

	var covered_bg_ids: Array = []
	for event_data in events:
		if not event_data is Dictionary:
			continue
		if str(event_data.get("type", "")) != "background":
			continue
		var bg_id := str(event_data.get("bg_id", "")).strip_edges()
		if bg_id != "" and not covered_bg_ids.has(bg_id):
			covered_bg_ids.append(bg_id)

	for bg_id in expected_bg_ids:
		if not covered_bg_ids.has(bg_id):
			return false
	return true


func _match_filter_list(raw_filters: Variant, target_value: String) -> bool:
	if not raw_filters is Array:
		return true
	if raw_filters.is_empty():
		return true
	for item in raw_filters:
		if str(item).strip_edges().to_lower() == target_value.to_lower():
			return true
	return false


func _load_template_config() -> void:
	_template_config.clear()
	if not FileAccess.file_exists(TEMPLATE_PATH):
		push_warning("[DateStoryManager] 找不到约会模板配置: %s" % TEMPLATE_PATH)
		return
	var file: FileAccess = FileAccess.open(TEMPLATE_PATH, FileAccess.READ)
	if file == null:
		return
	var json := JSON.new()
	var parse_result := json.parse(file.get_as_text())
	file.close()
	if parse_result == OK and json.data is Dictionary:
		_template_config = json.data


func _build_date_type_index() -> void:
	_date_type_by_location.clear()
	if FileAccess.file_exists(DATE_CONFIG_PATH):
		var file: FileAccess = FileAccess.open(DATE_CONFIG_PATH, FileAccess.READ)
		if file:
			var json := JSON.new()
			var parse_result := json.parse(file.get_as_text())
			file.close()
			if parse_result == OK and json.data is Dictionary:
				var type_list: Array = json.data.get("date_types", [])
				for item in type_list:
					if not item is Dictionary:
						continue
					var type_id := str(item.get("id", "")).strip_edges()
					var locations: Array = item.get("locations", [])
					for location_id in locations:
						_date_type_by_location[str(location_id)] = type_id

	var location_config: Dictionary = _template_config.get("locations", {})
	for location_id in location_config.keys():
		var location_entry: Dictionary = location_config.get(location_id, {})
		var type_id := str(location_entry.get("type_id", "")).strip_edges()
		if type_id != "":
			_date_type_by_location[str(location_id)] = type_id


func _resolve_type_id(location_id: String) -> String:
	return str(_date_type_by_location.get(location_id, "stroll"))


func _normalize_settlement_config(raw_settlement: Variant) -> Dictionary:
	if raw_settlement is Dictionary:
		return {
			"intimacy": float(raw_settlement.get("intimacy", 0.0)),
			"trust": float(raw_settlement.get("trust", 0.0))
		}
	return _default_settlement_config()


func _default_settlement_config() -> Dictionary:
	return {
		"intimacy": 2.0,
		"trust": 2.0
	}


func _build_script_id() -> String:
	var unix_time := Time.get_unix_time_from_system()
	return "date_dynamic_%s_%d" % [str(unix_time), _rng.randi_range(100, 999)]


func _get_character_id() -> String:
	return DATE_FIXED_CHARACTER_ID


func _get_player_title() -> String:
	if _runtime_profile:
		var runtime_title := str(_runtime_profile.player_title).strip_edges()
		if runtime_title != "":
			return runtime_title
	if GameDataManager.profile:
		var title := str(GameDataManager.profile.player_title).strip_edges()
		if title != "":
			return title
	return "老师"


func _weekday_to_text(weekday: int) -> String:
	var labels := ["日", "一", "二", "三", "四", "五", "六"]
	if weekday < 0 or weekday >= labels.size():
		return "?"
	return labels[weekday]
