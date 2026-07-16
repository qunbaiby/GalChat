@tool
extends RefCounted

const JsonService = preload("res://addons/story_editor/core/story_json_service.gd")
const StoryScanner = preload("res://addons/story_editor/core/story_scanner.gd")
const BranchSimulator = preload("res://addons/story_editor/core/story_branch_simulator.gd")
const ResourceCatalog = preload("res://addons/story_editor/core/story_resource_catalog.gd")
const RepositoryValidator = preload("res://addons/story_editor/core/story_repository_validator.gd")

const CHARACTER_ALIASES := ["旁白", "player", "char"]
const RESOURCE_FIELDS := {
	"dialogue": [{"field": "speaker", "kind": "character"}, {"field": "character", "kind": "character"}, {"field": "expression", "kind": "expression"}],
	"background": [{"field": "bg_id", "kind": "image"}],
	"audio": [{"field": "audio_id", "kind": "audio"}],
	"bgm": [{"field": "audio_id", "kind": "audio"}],
	"show_character": [{"field": "character", "kind": "character"}, {"field": "expression", "kind": "expression"}],
	"move_character": [{"field": "character", "kind": "character"}, {"field": "expression", "kind": "expression"}],
	"hide_character": [{"field": "character", "kind": "character"}],
	"period_card": [{"field": "bg_id", "kind": "image"}],
	"voice_call": [{"field": "call_id", "kind": "call"}]
}

static func build(story_paths: Array[String] = [], resource_catalog: Dictionary = {}, dynamic_sessions: Dictionary = {}) -> Dictionary:
	var paths := story_paths.duplicate()
	if paths.is_empty():
		for story in StoryScanner.scan(): paths.append(str(story.get("path", "")))
	var catalog := resource_catalog if not resource_catalog.is_empty() else ResourceCatalog.build()
	var stories: Array[Dictionary] = []
	var references: Array[Dictionary] = []
	var diagnostics: Array[Dictionary] = []
	var event_lookup := {}
	for path in paths:
		var load_result := JsonService.load_dictionary(path)
		if not load_result.get("ok", false):
			diagnostics.append(_diagnostic("error", "coverage", "story_load_failed", path, "", str(load_result.get("error", "读取失败。"))))
			continue
		var story := _analyze_story(path, load_result.data as Dictionary, references)
		stories.append(story)
		for event in story.events: event_lookup[event.key] = event
	var dynamic := _merge_dynamic(dynamic_sessions, event_lookup, diagnostics)
	var resources := _build_resource_usage(references, catalog)
	var validation := RepositoryValidator.validate_repository(paths)
	var summary := _summary(stories, resources, diagnostics, validation)
	return {"schema_version": 1, "generated_at_msec": Time.get_ticks_msec(), "ok": summary.error_count == 0, "summary": summary, "coverage": _coverage(stories, dynamic), "stories": stories, "resources": resources, "diagnostics": diagnostics, "repository_validation": validation}

static func _analyze_story(path: String, data: Dictionary, references: Array[Dictionary]) -> Dictionary:
	var chapters := data.get("chapters", {}) as Dictionary
	var events: Array[Dictionary] = []
	for chapter_id_value in chapters:
		var chapter_id := str(chapter_id_value)
		var chapter := chapters[chapter_id_value] as Dictionary
		for event_index in (chapter.get("events", []) as Array).size():
			var value: Variant = (chapter.events as Array)[event_index]
			if not value is Dictionary: continue
			var event := value as Dictionary
			var item := {"key": _event_key(path, chapter_id, event_index), "path": path, "chapter_id": chapter_id, "event_index": event_index, "type": str(event.get("type", "")), "reachable": false, "simulated": false, "dynamic_hit": false, "dynamic_hit_count": 0}
			events.append(item)
			_extract_references(path, chapter_id, event_index, event, references)
	var reachable := {}
	_walk_reachable(chapters, "start", 0, reachable)
	var simulated := {}
	var paths := BranchSimulator.simulate(data)
	var path_counts := {"total": paths.size(), "ended": 0, "loop": 0, "error": 0}
	for result in paths:
		var status := str(result.get("status", "error"))
		path_counts[status] = int(path_counts.get(status, 0)) + 1
		for trace in result.get("trace", []):
			if trace is Dictionary: simulated[_event_key(path, str(trace.chapter), int(trace.event_index))] = true
	var reachable_count := 0
	var simulated_count := 0
	for event in events:
		event.reachable = reachable.has("%s::%d" % [event.chapter_id, event.event_index])
		event.simulated = simulated.has(event.key)
		if event.reachable: reachable_count += 1
		if event.simulated: simulated_count += 1
	return {"path": path, "script_id": str(data.get("script_id", path.get_file().get_basename())), "category": path.get_base_dir().get_file(), "chapter_count": chapters.size(), "event_count": events.size(), "reachable_event_count": reachable_count, "simulated_event_count": simulated_count, "dynamic_hit_event_count": 0, "path_counts": path_counts, "events": events}

static func _walk_reachable(chapters: Dictionary, chapter_id: String, event_index: int, visited: Dictionary) -> void:
	var state := "%s::%d" % [chapter_id, event_index]
	if visited.has(state) or not chapters.has(chapter_id): return
	var events := ((chapters[chapter_id] as Dictionary).get("events", []) as Array)
	if event_index < 0 or event_index >= events.size() or not events[event_index] is Dictionary: return
	visited[state] = true
	var event := events[event_index] as Dictionary
	match str(event.get("type", "")):
		"jump": _walk_reachable(chapters, str(event.get("target_chapter", "")), 0, visited)
		"choice":
			for option in event.get("options", []):
				if option is Dictionary:
					var target := str(option.get("target_chapter", ""))
					_walk_reachable(chapters, chapter_id, event_index + 1, visited) if target.is_empty() else _walk_reachable(chapters, target, 0, visited)
		_: _walk_reachable(chapters, chapter_id, event_index + 1, visited)

static func _extract_references(path: String, chapter_id: String, event_index: int, event: Dictionary, output: Array[Dictionary]) -> void:
	var event_type := str(event.get("type", ""))
	for definition in RESOURCE_FIELDS.get(event_type, []):
		var field := str(definition.field)
		var id := str(event.get(field, "")).strip_edges()
		if not id.is_empty(): output.append({"kind": str(definition.kind), "id": id, "path": path, "chapter_id": chapter_id, "event_index": event_index, "event_type": event_type, "field": field})

static func _build_resource_usage(references: Array[Dictionary], catalog: Dictionary) -> Dictionary:
	var result := {}
	for kind in ["image", "audio", "expression", "call", "character"]:
		var catalog_entries := catalog.get(kind, []) as Array
		var by_id := {}
		for entry in catalog_entries:
			if entry is Dictionary: by_id[str(entry.get("id", ""))] = entry
		var usage := {}
		for reference in references:
			if reference.kind == kind:
				var id := str(reference.id)
				if not usage.has(id): usage[id] = []
				(usage[id] as Array).append(reference)
		var entries: Array[Dictionary] = []
		var missing: Array[Dictionary] = []
		for id in usage:
			if by_id.has(id) or (kind == "character" and CHARACTER_ALIASES.has(id)):
				var entry := (by_id.get(id, {"id": id, "label": id}) as Dictionary).duplicate(true)
				entry.reference_count = (usage[id] as Array).size(); entry.references = usage[id]; entries.append(entry)
			elif not catalog_entries.is_empty(): missing.append({"id": id, "reference_count": (usage[id] as Array).size(), "references": usage[id]})
		var unused: Array[Dictionary] = []
		for id in by_id:
			if not usage.has(id): unused.append((by_id[id] as Dictionary).duplicate(true))
		result[kind] = {"catalog_status": "available" if not catalog_entries.is_empty() else "unavailable", "catalog_count": catalog_entries.size(), "used_id_count": entries.size(), "reference_count": _reference_count(usage), "missing_id_count": missing.size(), "unused_id_count": unused.size(), "entries": entries, "missing": missing, "unused": unused}
	return result

static func _merge_dynamic(sessions: Dictionary, event_lookup: Dictionary, diagnostics: Array[Dictionary]) -> Dictionary:
	var seen := {}; var traces := {}; var unmatched := 0
	for session_id in sessions:
		for event in (sessions[session_id] as Dictionary).get("events", []):
			if not event is Dictionary or str(event.get("event", "")) != "story.event.started": continue
			var story := event.get("story", {}) as Dictionary
			if bool(story.get("runtime_generated", false)): continue
			var cursor := event.get("cursor", {}) as Dictionary
			var path := str(story.get("script_path", "")); var key := _event_key(path, str(cursor.get("chapter_id", "")), int(cursor.get("event_index", -1)))
			var hit_key := "%s::%s::%s" % [str(session_id), str(event.get("trace_id", "")), key]
			if seen.has(hit_key): continue
			seen[hit_key] = true; traces[str(event.get("trace_id", ""))] = true
			if event_lookup.has(key):
				event_lookup[key].dynamic_hit = true; event_lookup[key].dynamic_hit_count += 1
			else:
				unmatched += 1; diagnostics.append(_diagnostic("warning", "dynamic_trace", "unmatched_dynamic_event", path, "%s:%s" % [cursor.get("chapter_id", ""), cursor.get("event_index", -1)], "运行时事件无法与固定剧情位置对齐。"))
	return {"available": not sessions.is_empty(), "session_count": sessions.size(), "trace_count": traces.size(), "unmatched_event_count": unmatched}

static func _coverage(stories: Array[Dictionary], dynamic: Dictionary) -> Dictionary:
	var total := 0; var reachable := 0; var simulated := 0; var dynamic_hits := 0; var path_counts := {"total": 0, "ended": 0, "loop": 0, "error": 0}
	for story in stories:
		total += int(story.event_count); reachable += int(story.reachable_event_count); simulated += int(story.simulated_event_count)
		for event in story.events:
			if event.dynamic_hit: dynamic_hits += 1
		for key in path_counts: path_counts[key] += int(story.path_counts.get(key, 0))
	return {"structural": _ratio(reachable, total), "simulation": _ratio(simulated, total).merged({"mode": "choice_exhaustive_without_conditions", "path_count": path_counts.total, "ended_path_count": path_counts.ended, "loop_path_count": path_counts.loop, "error_path_count": path_counts.error}), "dynamic": _ratio(dynamic_hits, reachable).merged(dynamic)}

static func _summary(stories: Array[Dictionary], resources: Dictionary, diagnostics: Array[Dictionary], validation: Dictionary) -> Dictionary:
	var summary := {"story_count": stories.size(), "chapter_count": 0, "event_count": 0, "reachable_event_count": 0, "simulated_event_count": 0, "dynamic_hit_event_count": 0, "resource_reference_count": 0, "missing_resource_count": 0, "unused_catalog_entry_count": 0, "error_count": int(validation.get("error_count", 0)), "warning_count": int(validation.get("warning_count", 0))}
	for story in stories:
		summary.chapter_count += int(story.chapter_count); summary.event_count += int(story.event_count); summary.reachable_event_count += int(story.reachable_event_count); summary.simulated_event_count += int(story.simulated_event_count)
		for event in story.events:
			if event.dynamic_hit: summary.dynamic_hit_event_count += 1
	for usage in resources.values(): summary.resource_reference_count += int(usage.reference_count); summary.missing_resource_count += int(usage.missing_id_count); summary.unused_catalog_entry_count += int(usage.unused_id_count)
	for diagnostic in diagnostics:
		if diagnostic.severity == "error": summary.error_count += 1
		elif diagnostic.severity == "warning": summary.warning_count += 1
	return summary

static func _ratio(covered: int, total: int) -> Dictionary:
	return {"covered": covered, "total": total, "ratio": float(covered) / float(total) if total > 0 else 1.0}
static func _reference_count(usage: Dictionary) -> int:
	var count := 0
	for values in usage.values(): count += (values as Array).size()
	return count
static func _event_key(path: String, chapter_id: String, event_index: int) -> String:
	return "%s::%s::%d" % [path, chapter_id, event_index]
static func _diagnostic(severity: String, domain: String, code: String, path: String, location: String, message: String) -> Dictionary:
	return {"severity": severity, "domain": domain, "code": code, "path": path, "location": location, "message": message}