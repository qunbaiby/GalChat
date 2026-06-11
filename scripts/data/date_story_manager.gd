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

var _rng := RandomNumberGenerator.new()
var _template_config: Dictionary = {}
var _date_type_by_location: Dictionary = {}


func _init() -> void:
	_rng.randomize()
	_load_template_config()
	_build_date_type_index()


func prepare_date_story_request(plan_list: Array) -> Dictionary:
	var profile = GameDataManager.profile
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
		"character_name": profile.char_name if profile else "Luna",
		"player_name": profile.player_name if profile else "玩家",
		"player_title": _get_player_title(),
		"relationship_stage": int(profile.current_stage) if profile else 1,
		"relationship_stage_title": str(stage_conf.get("title", "熟悉阶段")),
		"intimacy": float(profile.intimacy) if profile else 0.0,
		"trust": float(profile.trust) if profile else 0.0,
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

	var events: Array = []
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
			events.append({
				"type": "background",
				"bg_id": bg_id,
				"transition_type": "fade" if i == 0 else "dissolve",
				"duration": 0.45
			})

		if i == 0:
			events.append({
				"type": "audio",
				"audio_id": "luna_bgm",
				"audio_type": "bgm",
				"action": "play"
			})
			events.append({
				"type": "show_character",
				"character": char_id,
				"display_name": char_name,
				"position": "center",
				"expression": "calm",
				"animation": "fade_in",
				"focus": true
			})
		else:
			events.append({
				"type": "move_character",
				"character": char_id,
				"display_name": char_name,
				"position": "center",
				"expression": "calm",
				"animation": "slide_left",
				"focus": true
			})

		events.append({
			"type": "dialogue",
			"speaker": "旁白",
			"content": "%s的%s里，我和%s来到了%s。%s的空气让脚步也慢了下来，像是很适合把心事一点点说开的时刻。"
				% [period_label, weather_desc, char_name, location_name, outline_title]
		})
		events.append({
			"type": "dialogue",
			"speaker": char_id,
			"content": "%s，这里比我想的还要适合%s呢。和你一起过来之后，连心情都跟着安静下来了。"
				% [player_title, type_name]
		})
		events.append({
			"type": "dialogue",
			"speaker": "player",
			"content": "你喜欢就好。今天就慢一点走，按我们的节奏来。"
		})
		events.append({
			"type": "dialogue",
			"speaker": char_id,
			"content": "嗯，那你可要陪我久一点。难得有这样的时间，我还想把今天的感觉好好记下来。"
		})
		events.append({
			"type": "dialogue",
			"speaker": "旁白",
			"content": "围绕着%s的轻声交谈在%s里缓缓延展开来，%s也在不知不觉间变成了今天最柔软的一段回忆。"
				% [outline_prompt, location_name, location_name]
		})

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
	var sanitized_events: Array = _sanitize_story_events(_extract_story_events(chapters_data, source), context, fallback_script)
	if sanitized_events.is_empty():
		return fallback_script.duplicate(true)
	if not _has_expected_date_coverage(sanitized_events, context):
		return fallback_script.duplicate(true)

	safe_script["chapters"] = {
		"start": {
			"events": sanitized_events
		}
	}
	safe_script["date_settlement"] = build_date_settlement(context, safe_script)
	return safe_script


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


func _extract_story_events(chapters_data: Variant, source: Dictionary) -> Array:
	if chapters_data is Dictionary:
		var start_chapter: Dictionary = chapters_data.get("start", {})
		var start_events: Variant = start_chapter.get("events", [])
		if start_events is Array:
			return start_events
	if source.get("events", null) is Array:
		return source.get("events", [])
	return []


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
				event_data["content"] = content
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
				var event_char := str(event_data.get("character", "")).strip_edges().to_lower()
				if event_char == "":
					event_char = char_id
				event_data["character"] = event_char
				if not event_data.has("display_name") or str(event_data.get("display_name", "")).strip_edges() == "":
					event_data["display_name"] = str(context.get("character_name", "Luna"))

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

	if not _has_character_show_event(sanitized):
		var insert_at: int = min(2, sanitized.size())
		sanitized.insert(insert_at, {
			"type": "show_character",
			"character": char_id,
			"display_name": str(context.get("character_name", "Luna")),
			"position": "center",
			"expression": "calm",
			"animation": "fade_in",
			"focus": true
		})

	if not _has_dialogue_event(sanitized):
		return _extract_story_events(fallback_script.get("chapters", {}), fallback_script)

	return sanitized


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
	if GameDataManager.profile and str(GameDataManager.profile.current_character_id).strip_edges() != "":
		return str(GameDataManager.profile.current_character_id).strip_edges().to_lower()
	if GameDataManager.config:
		return str(GameDataManager.config.current_character_id).strip_edges().to_lower()
	return "luna"


func _get_player_title() -> String:
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
