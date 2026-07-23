class_name ConcernTemplateCompiler
extends RefCounted


static func compile(template: Dictionary, context: Dictionary = {}) -> Dictionary:
	var template_id := str(template.get("template_id", "concern")).strip_edges()
	var character_name := str(context.get("character_name", "角色")).strip_edges()
	var events: Array = []
	for raw_event in template.get("intro_events", []):
		if not raw_event is Dictionary:
			continue
		var event := (raw_event as Dictionary).duplicate(true)
		event["type"] = "dialogue"
		event["speaker"] = str(event.get("speaker", "旁白")).replace("{character_name}", character_name)
		event["content"] = str(event.get("content", "")).replace("{character_name}", character_name)
		if str(event.get("content", "")).strip_edges().is_empty():
			continue
		events.append(event)
	var policy: Dictionary = (template.get("guided_ai_policy", {}) as Dictionary).duplicate(true)
	policy["type"] = "guided_ai_chat"
	policy["session_id"] = "concern_%s_%d" % [template_id, int(context.get("day_offset", 0))]
	policy["show_entry_line"] = bool(policy.get("show_entry_line", false))
	events.append(policy)
	return {
		"script_id": "concern_%s" % template_id,
		"runtime_generated": true,
		"story_category": "concern_template",
		"use_portraits": false,
		"memory_enabled": bool(template.get("memory_enabled", true)),
		"memory_title": str(template.get("title", "心事对话")),
		"memory_summary": str(template.get("memory_summary", policy.get("scene_objective", ""))),
		"chapters": {
			"start": {"events": events}
		}
	}
