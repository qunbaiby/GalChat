@tool
extends RefCounted

const JsonService = preload("res://addons/story_editor/core/story_json_service.gd")
const Repository = preload("res://scripts/data/concern_template_repository.gd")
const Compiler = preload("res://scripts/data/concern_template_compiler.gd")
const TEMPLATE_ROOT := Repository.TEMPLATE_ROOT


static func scan_templates(root_path: String = TEMPLATE_ROOT) -> Array[Dictionary]:
	return Repository.scan_templates(root_path)


static func save_template(template: Dictionary, source_path: String = "") -> Dictionary:
	var errors := Repository.validate_template(template)
	if not errors.is_empty():
		return {"ok": false, "error": "\n".join(errors)}
	var template_id := str(template.get("template_id", "")).strip_edges()
	var target_path := source_path
	if target_path.is_empty():
		target_path = TEMPLATE_ROOT.path_join("%s.json" % template_id)
	var stored := template.duplicate(true)
	stored.erase("source_path")
	var result := JsonService.save_dictionary(target_path, stored)
	if result.get("ok", false):
		result["path"] = target_path
	return result


static func create_template(template_id: String, title: String, character_id: String) -> Dictionary:
	var normalized_id := template_id.strip_edges()
	if normalized_id.is_empty() or not normalized_id.is_valid_filename() or normalized_id.contains(" ") or normalized_id.contains("."):
		return {"ok": false, "error": "模板 ID 只能包含字母、数字、下划线和连字符。"}
	var target_path := TEMPLATE_ROOT.path_join("%s.json" % normalized_id)
	if FileAccess.file_exists(target_path):
		return {"ok": false, "error": "模板 ID 已存在。"}
	var template := {
		"schema_version": 1,
		"template_id": normalized_id,
		"title": title.strip_edges() if not title.strip_edges().is_empty() else normalized_id,
		"character_id": character_id.strip_edges().to_lower(),
		"enabled": true,
		"priority": 100,
		"conditions": {
			"weekdays": [5, 6, 0],
			"time_periods": ["evening", "night"],
			"min_stage": 0,
			"max_stage": 0,
			"min_intimacy": 0,
			"min_trust": 0
		},
		"availability": {"cooldown_days": 3, "once": false, "max_completions": 0},
		"intro_events": [
			{"speaker": "旁白", "content": "填写此刻的环境与角色状态。"},
			{"speaker": "{character_name}", "content": "（稍稍移开目光）我有件事想和你说。"}
		],
		"guided_ai_policy": {
			"narrative_anchor": "填写不可被 AI 改写的事实。",
			"scene_objective": "填写本次心事对话的目标。",
			"allowed_topics": [],
			"forbidden_facts": [],
			"required_beats": [{"id": "beat_1", "instruction": "填写角色必须自然表达的信息。"}],
			"redirect_instruction": "回应偏题后自然回到当前心事。",
			"max_player_rounds": 4,
			"game_minutes": 20,
			"action_cost": 0,
			"allow_early_completion": true,
			"hide_manual_end": true,
			"show_entry_line": false,
			"closing_instruction": "自然收束对话。",
			"fallback_closing_text": "（轻轻呼出一口气）谢谢你听我说这些。"
		}
	}
	var save_result := save_template(template, target_path)
	if not save_result.get("ok", false):
		return save_result
	template["source_path"] = target_path
	return {"ok": true, "template": template, "path": target_path}


static func preview(template: Dictionary, context: Dictionary) -> Dictionary:
	var errors := Repository.validate_template(template)
	var all_templates: Array[Dictionary] = scan_templates()
	var preview_templates: Array[Dictionary] = []
	for candidate in all_templates:
		if str(candidate.get("template_id", "")) != str(template.get("template_id", "")):
			preview_templates.append(candidate)
	preview_templates.append(template.duplicate(true))
	var resolved := Repository.resolve_template(preview_templates, context)
	return {
		"ok": errors.is_empty(),
		"errors": errors,
		"resolved_template_id": str(resolved.get("template_id", "")),
		"selected_matches": str(resolved.get("template_id", "")) == str(template.get("template_id", "")),
		"compiled": Compiler.compile(template, context) if errors.is_empty() else {}
	}
