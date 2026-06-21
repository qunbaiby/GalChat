class_name DateGenerationController
extends Node

const DateStoryManager = preload("res://scripts/data/date_story_manager.gd")
const DateLoadingOverlayScene = preload("res://scenes/ui/date/date_loading_overlay.tscn")
const DeepSeekClientLocator = preload("res://scripts/api/utils/deepseek_client_locator.gd")
const MAX_DATE_STORY_RETRIES := 1

signal generation_state_changed(active: bool)
signal story_ready(script_data: Dictionary)

var _character_profile: Dictionary = {}
var _runtime_profile = null
var _date_story_manager: DateStoryManager = null
var _deepseek_client: Node = null
var _date_loading_overlay: DateLoadingOverlay = null
var _pending_date_request: Dictionary = {}
var _is_generating_date_story: bool = false
var _date_story_retry_count: int = 0
var _active_segment_request: Dictionary = {}
var _segment_generation_results: Array = []
var _segment_used_fallback_flags: Array = []
var _current_segment_request_index: int = -1

func setup(character_profile: Dictionary) -> void:
	_character_profile = character_profile.duplicate(true)
	_date_story_manager = DateStoryManager.new()
	_ensure_date_loading_overlay()


func set_runtime_profile(runtime_profile) -> void:
	_runtime_profile = runtime_profile
	if _date_story_manager and _date_story_manager.has_method("set_runtime_profile"):
		_date_story_manager.set_runtime_profile(_runtime_profile)


func cleanup() -> void:
	_stop_date_loading_animations()
	_disconnect_date_story_signals()


func start_date_plan(plan_list: Array) -> void:
	if _is_generating_date_story:
		return
	_pending_date_request.clear()
	_active_segment_request.clear()
	_segment_generation_results.clear()
	_segment_used_fallback_flags.clear()
	_current_segment_request_index = -1
	_date_story_retry_count = 0
	if _date_story_manager == null:
		_date_story_manager = DateStoryManager.new()
	var prepared_request := _date_story_manager.prepare_date_story_request(plan_list)
	var context: Dictionary = prepared_request.get("context", {})
	context["date_character_profile"] = _character_profile.duplicate(true)
	context["date_loading_style"] = _character_profile.get("loading_style", {}).duplicate(true)
	context["date_character_preferences"] = _character_profile.get("date_preferences", {}).duplicate(true)
	prepared_request["context"] = context
	_pending_date_request = prepared_request
	var fallback_script: Dictionary = prepared_request.get("fallback_script", {})
	var client := _find_deepseek_client()
	_show_date_loading_overlay(context)
	if client == null:
		if ToastManager:
			ToastManager.show_toast("未找到 AI 客户端，改用保底约会剧情")
		_set_generation_state(true)
		_complete_date_loading_and_emit(fallback_script)
		return
	_deepseek_client = client
	_disconnect_date_story_signals()
	if not _deepseek_client.is_connected("date_story_generated", _on_date_story_generated):
		_deepseek_client.date_story_generated.connect(_on_date_story_generated)
	if not _deepseek_client.is_connected("date_story_error", _on_date_story_error):
		_deepseek_client.date_story_error.connect(_on_date_story_error)
	_set_generation_state(true)
	_dispatch_next_segment_request()


func cancel() -> void:
	_stop_date_loading_animations()
	_disconnect_date_story_signals()
	_set_generation_state(false)


func is_generating() -> bool:
	return _is_generating_date_story


func _find_deepseek_client() -> Node:
	if _deepseek_client and is_instance_valid(_deepseek_client):
		return _deepseek_client
	return DeepSeekClientLocator.find(self)


func _set_generation_state(active: bool) -> void:
	_is_generating_date_story = active
	generation_state_changed.emit(active)


func _disconnect_date_story_signals() -> void:
	if _deepseek_client:
		if _deepseek_client.is_connected("date_story_generated", _on_date_story_generated):
			_deepseek_client.date_story_generated.disconnect(_on_date_story_generated)
		if _deepseek_client.is_connected("date_story_error", _on_date_story_error):
			_deepseek_client.date_story_error.disconnect(_on_date_story_error)


func _on_date_story_generated(script_data: Dictionary) -> void:
	var fallback_script: Dictionary = _active_segment_request.get("fallback_script", {})
	var context: Dictionary = _active_segment_request.get("context", {})
	var final_script := _date_story_manager.sanitize_generated_story(script_data, context, fallback_script)
	var used_fallback := _looks_like_fallback_story(final_script, fallback_script)
	if used_fallback and _date_story_retry_count < MAX_DATE_STORY_RETRIES:
		_retry_date_story_generation("sanitize_fallback")
		return
	_store_segment_result(final_script, used_fallback)
	_dispatch_next_segment_request()


func _on_date_story_error(error_msg: String) -> void:
	if _date_story_retry_count < MAX_DATE_STORY_RETRIES:
		_retry_date_story_generation("service_error")
		return
	push_warning("[DateGenerationController] %s" % error_msg)
	var fallback_script: Dictionary = _active_segment_request.get("fallback_script", {})
	_store_segment_result(fallback_script, true)
	_dispatch_next_segment_request()


func _dispatch_date_story_request() -> void:
	if _deepseek_client == null:
		return
	var context: Dictionary = _active_segment_request.get("context", {}).duplicate(true)
	context["date_story_retry_count"] = _date_story_retry_count
	_active_segment_request["context"] = context
	_deepseek_client.generate_date_story(context)


func _retry_date_story_generation(reason: String) -> void:
	_date_story_retry_count += 1
	_dispatch_date_story_request()


func _ensure_date_loading_overlay() -> void:
	if _date_loading_overlay and is_instance_valid(_date_loading_overlay):
		return
	_date_loading_overlay = DateLoadingOverlayScene.instantiate()
	add_child(_date_loading_overlay)


func _show_date_loading_overlay(context: Dictionary) -> void:
	_ensure_date_loading_overlay()
	if _date_loading_overlay:
		_date_loading_overlay.show_for_context(context)


func _complete_date_loading_and_emit(script_data: Dictionary, is_fallback: bool = false) -> void:
	if _date_loading_overlay:
		await _date_loading_overlay.complete(is_fallback)
	_set_generation_state(false)
	story_ready.emit(script_data)


func _hide_date_loading_overlay_immediately() -> void:
	if _date_loading_overlay:
		_date_loading_overlay.hide_immediately()


func _stop_date_loading_animations() -> void:
	if _date_loading_overlay:
		_date_loading_overlay.cancel()


func _extract_story_event_count(script_data: Dictionary) -> int:
	if script_data.is_empty():
		return 0
	var chapters: Dictionary = script_data.get("chapters", {})
	var start_chapter: Dictionary = chapters.get("start", {})
	var events: Array = start_chapter.get("events", [])
	return events.size()


func _looks_like_fallback_story(final_script: Dictionary, fallback_script: Dictionary) -> bool:
	if final_script.is_empty() or fallback_script.is_empty():
		return false
	return str(final_script.get("summary", "")).strip_edges() == str(fallback_script.get("summary", "")).strip_edges() \
		and _extract_story_event_count(final_script) == _extract_story_event_count(fallback_script)


func _dispatch_next_segment_request() -> void:
	var full_context: Dictionary = _pending_date_request.get("context", {})
	var plan_segments: Array = full_context.get("date_plan", [])
	if plan_segments.is_empty():
		_set_generation_state(false)
		_disconnect_date_story_signals()
		_complete_date_loading_and_emit(_pending_date_request.get("fallback_script", {}), true)
		return
	_current_segment_request_index += 1
	if _current_segment_request_index >= plan_segments.size():
		_finish_segment_generation()
		return
	_date_story_retry_count = 0
	_active_segment_request = _build_segment_request(_current_segment_request_index)
	_dispatch_date_story_request()


func _build_segment_request(segment_index: int) -> Dictionary:
	var full_context: Dictionary = _pending_date_request.get("context", {}).duplicate(true)
	var full_plan: Array = full_context.get("date_plan", [])
	if segment_index < 0 or segment_index >= full_plan.size():
		return {}
	var plan_segment: Dictionary = (full_plan[segment_index] as Dictionary).duplicate(true)
	full_context["date_plan"] = [plan_segment]
	full_context["location_names"] = [str(plan_segment.get("location_name", ""))]
	full_context["summary_hint"] = str(plan_segment.get("location_name", ""))
	full_context["date_story_segment_index"] = segment_index
	full_context["date_story_segment_total"] = full_plan.size()
	full_context["date_story_previous_summaries"] = _collect_generated_segment_summaries()
	return {
		"context": full_context,
		"fallback_script": _date_story_manager.build_fallback_story(full_context)
	}


func _collect_generated_segment_summaries() -> Array:
	var summaries: Array = []
	for segment_script in _segment_generation_results:
		if segment_script is Dictionary:
			var summary: String = str((segment_script as Dictionary).get("summary", "")).strip_edges()
			if summary != "":
				summaries.append(summary)
	return summaries


func _store_segment_result(script_data: Dictionary, used_fallback: bool) -> void:
	_segment_generation_results.append(script_data.duplicate(true))
	_segment_used_fallback_flags.append(used_fallback)


func _finish_segment_generation() -> void:
	_set_generation_state(false)
	_disconnect_date_story_signals()
	var final_script: Dictionary = _date_story_manager.combine_generated_segment_scripts(
		_segment_generation_results,
		_pending_date_request.get("context", {}),
		_pending_date_request.get("fallback_script", {})
	)
	_complete_date_loading_and_emit(final_script, _all_segments_used_fallback())


func _all_segments_used_fallback() -> bool:
	if _segment_used_fallback_flags.is_empty():
		return true
	for used_fallback in _segment_used_fallback_flags:
		if not bool(used_fallback):
			return false
	return true


func _summarize_raw_segments(raw_segments: Variant) -> Array:
	var summary: Array = []
	if not raw_segments is Array:
		return summary
	for i in range(raw_segments.size()):
		var segment_summary := {
			"index": i,
			"line_count": 0,
			"char_count": 0
		}
		if raw_segments[i] is Dictionary:
			var lines: Variant = (raw_segments[i] as Dictionary).get("lines", [])
			if lines is Array:
				segment_summary["line_count"] = lines.size()
				for line in lines:
					if line is Dictionary:
						segment_summary["char_count"] = int(segment_summary["char_count"]) + str((line as Dictionary).get("content", "")).strip_edges().length()
		summary.append(segment_summary)
	return summary


func _summarize_final_segments(script_data: Dictionary) -> Array:
	var summary: Array = []
	var events: Array = _extract_story_events(script_data)
	var segment_index: int = -1
	var current: Dictionary = {}
	for event_data in events:
		if not event_data is Dictionary:
			continue
		var event_type: String = str(event_data.get("type", "")).strip_edges()
		if event_type == "period_card":
			if segment_index >= 0:
				summary.append(current)
			segment_index += 1
			current = {
				"index": segment_index,
				"period_label": str(event_data.get("period_label", "")),
				"location_name": str(event_data.get("location_name", "")),
				"dialogue_count": 0,
				"dialogue_chars": 0
			}
		elif event_type == "dialogue":
			if segment_index < 0:
				segment_index = 0
				current = {
					"index": segment_index,
					"period_label": "",
					"location_name": "",
					"dialogue_count": 0,
					"dialogue_chars": 0
				}
			current["dialogue_count"] = int(current.get("dialogue_count", 0)) + 1
			current["dialogue_chars"] = int(current.get("dialogue_chars", 0)) + str(event_data.get("content", "")).length()
	if segment_index >= 0:
		summary.append(current)
	return summary


func _extract_story_events(script_data: Dictionary) -> Array:
	if script_data.is_empty():
		return []
	var chapters: Dictionary = script_data.get("chapters", {})
	var start_chapter: Dictionary = chapters.get("start", {})
	var events: Variant = start_chapter.get("events", [])
	return events if events is Array else []


func _count_events_by_type(script_data: Dictionary, event_type: String) -> int:
	var total: int = 0
	for event_data in _extract_story_events(script_data):
		if event_data is Dictionary and str(event_data.get("type", "")).strip_edges() == event_type:
			total += 1
	return total
