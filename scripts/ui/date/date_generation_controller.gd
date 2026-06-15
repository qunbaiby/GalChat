class_name DateGenerationController
extends Node

const DateStoryManager = preload("res://scripts/data/date_story_manager.gd")
const DateLoadingOverlayScene = preload("res://scenes/ui/date/date_loading_overlay.tscn")

signal generation_state_changed(active: bool)
signal story_ready(script_data: Dictionary)

var _character_profile: Dictionary = {}
var _date_story_manager: DateStoryManager = null
var _deepseek_client: Node = null
var _date_loading_overlay: DateLoadingOverlay = null
var _pending_date_request: Dictionary = {}
var _is_generating_date_story: bool = false


func setup(character_profile: Dictionary) -> void:
	_character_profile = character_profile.duplicate(true)
	_date_story_manager = DateStoryManager.new()
	_ensure_date_loading_overlay()


func cleanup() -> void:
	_stop_date_loading_animations()
	_disconnect_date_story_signals()


func start_date_plan(plan_list: Array) -> void:
	if _is_generating_date_story:
		return
	_pending_date_request.clear()
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
	if ToastManager:
		ToastManager.show_toast("正在生成约会剧情...")
	_deepseek_client.generate_date_story(context)


func cancel() -> void:
	_stop_date_loading_animations()
	_disconnect_date_story_signals()
	_set_generation_state(false)


func is_generating() -> bool:
	return _is_generating_date_story


func _find_deepseek_client() -> Node:
	if _deepseek_client and is_instance_valid(_deepseek_client):
		return _deepseek_client
	var main_scene = get_tree().get_root().get_node_or_null("MainScene")
	if main_scene and main_scene.has_node("DeepSeekClient"):
		return main_scene.get_node("DeepSeekClient")
	return null


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
	_set_generation_state(false)
	_disconnect_date_story_signals()
	var fallback_script: Dictionary = _pending_date_request.get("fallback_script", {})
	var context: Dictionary = _pending_date_request.get("context", {})
	var final_script := _date_story_manager.sanitize_generated_story(script_data, context, fallback_script)
	_complete_date_loading_and_emit(final_script)


func _on_date_story_error(_error_msg: String) -> void:
	_set_generation_state(false)
	_disconnect_date_story_signals()
	if ToastManager:
		ToastManager.show_toast("AI 约会剧情生成失败，已切换为保底剧情")
	var fallback_script: Dictionary = _pending_date_request.get("fallback_script", {})
	_complete_date_loading_and_emit(fallback_script, true)


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
