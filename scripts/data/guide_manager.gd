extends Node

signal guide_started(guide_id: String)
signal guide_step_changed(guide_id: String, step_id: String, step_data: Dictionary)
signal guide_completed(guide_id: String)
signal feature_states_changed

const GUIDE_DATA_PATH := "res://assets/data/guide/guide_flows.json"
const GUIDE_STATE_KEY := "guide_state_v1"
const GUIDE_FLOW_REVISION := 5
const AI_ROUND_GUIDE_INSERT_INDEX := 19
const DEFAULT_GUIDE_ID := "schedule_onboarding_guide"
const DEMO_GUIDE_ID := "map_story_demo_guide"
const DAY6_LIBRARY_GUIDE_ID := "day6_library_guidance_guide"
const GUIDE_SCENE_PATH := "res://scenes/ui/story/story_scene.tscn"
const GUIDE_OVERLAY_LAYER := 200
const GUIDE_LOCK_HINT := "当前处于新手引导中，暂未解锁该功能。"
const GuideOverlayScene = preload("res://scenes/ui/guide/guide_overlay.tscn")
const ConditionManagerScript = preload("res://scripts/data/condition_manager.gd")

const MAIN_SCENE_FEATURE_PATHS := {
	"main.affection": "UIPanel/AffectionButton",
	"main.goal": "UIPanel/GoalPanel",
	"main.stats": "UIPanel/StatsPanelAnchor/StatsPanel",
	"main.energy": "UIPanel/TopStatusPanel/MarginContainer/HBoxContainer/EnergySlot",
	"main.diary": "UIPanel/BottomBarHBox/BtnHBox/GiftButton",
	"main.wardrobe": "UIPanel/BottomBarHBox/BtnHBox/WardrobeButton",
	"main.main_action": "UIPanel/BottomBarHBox/ActionHBox/MainActionButton",
	"main.chat": "UIPanel/InteractGroup/ChatButton",
	"main.gift": "UIPanel/AffectionOverlay/PopupCenter/AffectionPopupFrame/AffectionPanel/RootMargin/RootVBox/ContentVBox/MainHBox/VisualColumn/GiftButton",
	"main.date": "UIPanel/DateButton"
}
const DEFAULT_LOCKED_FEATURES := {
	"main.diary": true,
	"main.creation": true,
	"main.wardrobe": true,
	"main.date": true
}

var _guide_defs: Dictionary = {}
var _state: Dictionary = {}
var _overlay: Control = null
var _overlay_layer: CanvasLayer = null
var _overlay_attach_queued: bool = false
var _main_scene_ref: WeakRef = null
var _world_map_scene_ref: WeakRef = null
var _location_detail_panel_ref: WeakRef = null
var _quick_location_scene_ref: WeakRef = null
var _tutoring_panel_ref: WeakRef = null
var _activity_panel_ref: WeakRef = null
var _schedule_execution_panel_ref: WeakRef = null

func _ready() -> void:
	_state = _build_default_state()
	_load_guide_defs()
	_ensure_overlay()
	if GameDataManager.has_signal("archive_changed") and not GameDataManager.archive_changed.is_connected(_on_archive_changed):
		GameDataManager.archive_changed.connect(_on_archive_changed)
	call_deferred("reload_for_current_archive")

func _on_archive_changed(_archive_id: String) -> void:
	reload_for_current_archive()

func _build_default_state() -> Dictionary:
	return {
		"active_guide_id": "",
		"current_step_index": 0,
		"guide_flow_revision": GUIDE_FLOW_REVISION,
		"completed_guides": [],
		"feature_unlocks": {},
		"guide_opt_in": "enabled"
	}

func _load_guide_defs() -> void:
	_guide_defs.clear()
	if not FileAccess.file_exists(GUIDE_DATA_PATH):
		push_warning("引导配置不存在：%s" % GUIDE_DATA_PATH)
		return
	var file := FileAccess.open(GUIDE_DATA_PATH, FileAccess.READ)
	if file == null:
		push_warning("引导配置读取失败：%s" % GUIDE_DATA_PATH)
		return
	var json := JSON.new()
	var parse_result: int = json.parse(file.get_as_text())
	file.close()
	if parse_result != OK:
		push_warning("引导配置解析失败：%s" % GUIDE_DATA_PATH)
		return
	var root_data: Variant = json.data
	var raw_guides: Array = []
	if root_data is Dictionary:
		raw_guides = root_data.get("guides", [])
	elif root_data is Array:
		raw_guides = root_data
	if not (raw_guides is Array):
		return
	for guide_variant in raw_guides:
		if not (guide_variant is Dictionary):
			continue
		var guide_dict: Dictionary = guide_variant
		var guide_id := str(guide_dict.get("id", "")).strip_edges()
		if guide_id == "":
			continue
		_guide_defs[guide_id] = guide_dict.duplicate(true)

func reload_for_current_archive() -> void:
	var raw_state: Variant = GameDataManager.get_archive_custom_config(GUIDE_STATE_KEY, {})
	_state = _normalize_state(raw_state)
	_refresh_current_step_display()

func _normalize_state(raw_state: Variant) -> Dictionary:
	var normalized := _build_default_state()
	if not (raw_state is Dictionary):
		return normalized
	normalized["active_guide_id"] = str(raw_state.get("active_guide_id", "")).strip_edges()
	normalized["current_step_index"] = maxi(0, int(raw_state.get("current_step_index", 0)))
	var saved_revision := maxi(1, int(raw_state.get("guide_flow_revision", 1)))
	if saved_revision < 2:
		if str(normalized["active_guide_id"]) == DEFAULT_GUIDE_ID and int(normalized["current_step_index"]) >= AI_ROUND_GUIDE_INSERT_INDEX:
			normalized["current_step_index"] = int(normalized["current_step_index"]) + 1
	if saved_revision < 3 and str(normalized["active_guide_id"]) == DEFAULT_GUIDE_ID:
		var previous_step_index := int(normalized["current_step_index"])
		if previous_step_index >= 18 and previous_step_index <= 20:
			normalized["current_step_index"] = previous_step_index + 1
		elif previous_step_index == 21:
			normalized["current_step_index"] = 22
	var completed_guides: Array[String] = []
	var raw_completed: Variant = raw_state.get("completed_guides", [])
	if raw_completed is Array:
		for item in raw_completed:
			var guide_id := str(item).strip_edges()
			if guide_id != "":
				completed_guides.append(guide_id)
	if saved_revision < 4 and completed_guides.has(DAY6_LIBRARY_GUIDE_ID) and GameDataManager.profile.has_finished_story("jing_library_guidance"):
		completed_guides.erase(DAY6_LIBRARY_GUIDE_ID)
		normalized["active_guide_id"] = DAY6_LIBRARY_GUIDE_ID
		normalized["current_step_index"] = 5
	if saved_revision < 5 and str(normalized["active_guide_id"]) == DEFAULT_GUIDE_ID and GameDataManager.profile.has_finished_story("jing_piano_practice_followup"):
		var onboarding_steps: Array = (_guide_defs.get(DEFAULT_GUIDE_ID, {}) as Dictionary).get("steps", [])
		var current_index := int(normalized["current_step_index"])
		var current_step_id := ""
		if current_index >= 0 and current_index < onboarding_steps.size():
			current_step_id = str((onboarding_steps[current_index] as Dictionary).get("id", ""))
		if current_step_id in ["explain_guided_ai_round_limit", "finish_first_chat_after_goal"]:
			for step_index in range(onboarding_steps.size()):
				if str((onboarding_steps[step_index] as Dictionary).get("id", "")) == "inspect_main_panels_after_interact":
					normalized["current_step_index"] = step_index
					break
	normalized["guide_flow_revision"] = GUIDE_FLOW_REVISION
	normalized["completed_guides"] = completed_guides
	var feature_unlocks: Dictionary = {}
	var raw_feature_unlocks: Variant = raw_state.get("feature_unlocks", {})
	if raw_feature_unlocks is Dictionary:
		for key in raw_feature_unlocks.keys():
			feature_unlocks[str(key)] = bool(raw_feature_unlocks[key])
	normalized["feature_unlocks"] = feature_unlocks
	normalized["guide_opt_in"] = "enabled"
	return normalized

func _save_state() -> bool:
	var state_to_save := _state.duplicate(true)
	var persisted_raw: Variant = GameDataManager.get_archive_custom_config(GUIDE_STATE_KEY, {})
	if persisted_raw is Dictionary:
		var persisted := _normalize_state(persisted_raw)
		var active_guide_id := str(state_to_save.get("active_guide_id", "")).strip_edges()
		if active_guide_id != "" and active_guide_id == str(persisted.get("active_guide_id", "")).strip_edges():
			var persisted_step_index := int(persisted.get("current_step_index", 0))
			if persisted_step_index > int(state_to_save.get("current_step_index", 0)):
				state_to_save["current_step_index"] = persisted_step_index
				_state["current_step_index"] = persisted_step_index
	var result: Variant = GameDataManager.call("set_archive_custom_config", GUIDE_STATE_KEY, state_to_save, true)
	return result is bool and bool(result)

func _ensure_overlay() -> bool:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return false
	if not is_instance_valid(_overlay_layer):
		_overlay_layer = CanvasLayer.new()
		_overlay_layer.name = "GuideOverlayLayer"
		_overlay_layer.layer = GUIDE_OVERLAY_LAYER
		add_child(_overlay_layer)
	if not is_instance_valid(_overlay):
		_overlay = GuideOverlayScene.instantiate()
		_overlay.name = "GuideOverlay"
		if _overlay.has_method("hide_overlay"):
			_overlay.hide_overlay()
		if _overlay.has_signal("skip_pressed") and not _overlay.skip_pressed.is_connected(_on_overlay_skip_pressed):
			_overlay.skip_pressed.connect(_on_overlay_skip_pressed)
		if _overlay.has_signal("background_pressed") and not _overlay.background_pressed.is_connected(_on_overlay_background_pressed):
			_overlay.background_pressed.connect(_on_overlay_background_pressed)
		if _overlay.has_signal("focus_pressed") and not _overlay.focus_pressed.is_connected(_on_overlay_focus_pressed):
			_overlay.focus_pressed.connect(_on_overlay_focus_pressed)
	if _overlay.get_parent() == _overlay_layer:
		_overlay_layer.move_child(_overlay, -1)
		return true
	if not _overlay_attach_queued:
		_overlay_attach_queued = true
		call_deferred("_attach_overlay_to_root")
	return false

func _attach_overlay_to_root() -> void:
	_overlay_attach_queued = false
	if not is_instance_valid(_overlay):
		return
	var tree := get_tree()
	if tree == null or tree.root == null:
		return
	if not is_instance_valid(_overlay_layer):
		_overlay_layer = CanvasLayer.new()
		_overlay_layer.name = "GuideOverlayLayer"
		_overlay_layer.layer = GUIDE_OVERLAY_LAYER
		add_child(_overlay_layer)
	var overlay_parent := _overlay.get_parent()
	if overlay_parent == null:
		_overlay_layer.add_child(_overlay)
	elif overlay_parent != _overlay_layer:
		_overlay.reparent(_overlay_layer)
	if _overlay.get_parent() == _overlay_layer:
		_overlay_layer.move_child(_overlay, -1)
	_refresh_current_step_display()

func _on_overlay_skip_pressed() -> void:
	skip_active_guide()

func _on_overlay_background_pressed(action_id: String) -> void:
	report_action(action_id)

func _on_overlay_focus_pressed(action_id: String) -> void:
	var step_data := _get_current_step()
	var overlay_options: Dictionary = step_data.get("overlay_options", {}) if step_data.get("overlay_options", {}) is Dictionary else {}
	var focus_handler_method := str(overlay_options.get("focus_handler_method", "")).strip_edges()
	if focus_handler_method != "":
		var main_scene := _resolve_main_scene()
		if is_instance_valid(main_scene) and main_scene.has_method(focus_handler_method):
			main_scene.call(focus_handler_method)
			return
	if action_id == "open_music_playlist":
		var main_scene := _resolve_main_scene()
		if is_instance_valid(main_scene) and main_scene.has_method("open_music_playlist_from_guide"):
			main_scene.open_music_playlist_from_guide()
			return
	if action_id == "click_main_goal":
		var main_scene := _resolve_main_scene()
		if is_instance_valid(main_scene) and main_scene.has_method("open_main_goal_story_from_guide"):
			main_scene.open_main_goal_story_from_guide()
			return
	if action_id == "open_affection":
		var main_scene := _resolve_main_scene()
		if is_instance_valid(main_scene) and main_scene.has_method("open_affection_from_guide"):
			main_scene.open_affection_from_guide()
			return
	if action_id == "open_first_daily_chat":
		var main_scene := _resolve_main_scene()
		if is_instance_valid(main_scene) and main_scene.has_method("open_daily_chat_from_guide"):
			main_scene.open_daily_chat_from_guide()
			return
	if action_id == "open_map":
		var main_scene := _resolve_main_scene()
		if is_instance_valid(main_scene) and main_scene.has_method("open_map_from_guide"):
			main_scene.open_map_from_guide()
			return
	report_action(action_id)

func on_main_scene_ready(main_scene: Node, just_finished_intro_story: bool = false) -> void:
	reload_for_current_archive()
	_main_scene_ref = weakref(main_scene)
	_ensure_overlay()
	apply_main_scene_feature_states(main_scene)
	call_deferred("_deferred_handle_main_scene_guide_ready", just_finished_intro_story)

func on_story_scene_ready() -> void:
	_hide_overlay()

func _deferred_handle_main_scene_guide_ready(just_finished_intro_story: bool) -> void:
	if just_finished_intro_story:
		start_default_guide_if_needed("intro_story")
	else:
		if not start_default_guide_if_needed("main_scene_ready"):
			_refresh_current_step_display()

func on_world_map_scene_ready(world_map_scene: Node) -> void:
	_world_map_scene_ref = weakref(world_map_scene)
	_refresh_current_step_display()

func on_location_detail_panel_ready(panel: Node) -> void:
	_location_detail_panel_ref = weakref(panel)
	_refresh_current_step_display()

func on_quick_location_scene_ready(scene: Node) -> void:
	_quick_location_scene_ref = weakref(scene)
	call_deferred("_refresh_current_step_display")

func on_tutoring_panel_ready(panel: Node) -> void:
	_tutoring_panel_ref = weakref(panel)
	call_deferred("_refresh_current_step_display")

func on_activity_panel_ready(panel: Node) -> void:
	_activity_panel_ref = weakref(panel)
	call_deferred("_refresh_current_step_display")

func on_schedule_execution_panel_ready(panel: Node) -> void:
	_schedule_execution_panel_ref = weakref(panel)
	call_deferred("_refresh_current_step_display")

func start_default_guide_if_needed(trigger_source: String = "") -> bool:
	if not is_guide_opted_in():
		return false
	if not _guide_defs.has(DEFAULT_GUIDE_ID):
		return false
	if is_guide_completed(DEFAULT_GUIDE_ID):
		_refresh_current_step_display()
		return false
	if str(_state.get("active_guide_id", "")).strip_edges() != "":
		_refresh_current_step_display()
		return false
	var guide_data: Dictionary = _guide_defs.get(DEFAULT_GUIDE_ID, {})
	if trigger_source == "intro_story" and not bool(guide_data.get("auto_start_after_intro", false)):
		return false
	return start_guide(DEFAULT_GUIDE_ID)

func start_guide(guide_id: String) -> bool:
	var normalized_guide_id := guide_id.strip_edges()
	if normalized_guide_id == "" or not _guide_defs.has(normalized_guide_id):
		return false
	if is_guide_completed(normalized_guide_id):
		return false
	if get_active_guide_id() == normalized_guide_id:
		_refresh_current_step_display()
		return true
	_state["active_guide_id"] = normalized_guide_id
	_state["current_step_index"] = 0
	_save_state()
	_enter_current_step()
	guide_started.emit(normalized_guide_id)
	return true

func start_demo_guide() -> bool:
	return start_guide(DEMO_GUIDE_ID)

func start_scheduled_guides_if_needed() -> bool:
	if not is_guide_opted_in() or get_active_guide_id() != "":
		return false
	if not GameDataManager.story_time_manager or not GameDataManager.story_time_manager.has_method("get_current_start_guide_ids"):
		return false
	var guide_ids: Array[String] = GameDataManager.story_time_manager.get_current_start_guide_ids()
	for guide_id in guide_ids:
		if _guide_defs.has(guide_id) and not is_guide_completed(guide_id):
			return start_guide(guide_id)
	return false

func start_day6_library_guide_if_needed() -> bool:
	return start_scheduled_guides_if_needed()

func is_guide_opted_in() -> bool:
	return true

func set_guide_opt_in(_enabled: bool = true) -> void:
	_state["guide_opt_in"] = "enabled"
	_save_state()

func skip_active_guide() -> void:
	var active_guide_id := str(_state.get("active_guide_id", "")).strip_edges()
	if active_guide_id == "":
		return
	var guide_data: Dictionary = _guide_defs.get(active_guide_id, {})
	_apply_feature_updates(guide_data.get("completion_feature_updates", {}))
	var completed_guides: Array[String] = _state.get("completed_guides", [])
	if not completed_guides.has(active_guide_id):
		completed_guides.append(active_guide_id)
	_state["completed_guides"] = completed_guides
	_state["active_guide_id"] = ""
	_state["current_step_index"] = 0
	_save_state()
	_hide_overlay()
	apply_main_scene_feature_states()
	if ToastManager and ToastManager.has_method("show_system_toast"):
		ToastManager.show_system_toast("已跳过当前新手引导")

func is_guide_completed(guide_id: String) -> bool:
	var completed_guides: Array[String] = _state.get("completed_guides", [])
	return completed_guides.has(guide_id.strip_edges())

func get_active_guide_id() -> String:
	return str(_state.get("active_guide_id", "")).strip_edges()

func get_current_step_id() -> String:
	return str(_get_current_step().get("id", "")).strip_edges()

func get_active_guide_category() -> String:
	return str(_get_active_guide().get("guide_category", "")).strip_edges()

func get_current_step_category() -> String:
	return str(_get_current_step().get("step_category", "")).strip_edges()

func is_feature_unlocked(feature_id: String, default_unlocked: bool = true) -> bool:
	var unlocks: Dictionary = _state.get("feature_unlocks", {})
	if unlocks.has(feature_id):
		return bool(unlocks[feature_id])
	if DEFAULT_LOCKED_FEATURES.has(feature_id):
		return false
	return default_unlocked

func set_feature_unlocked(feature_id: String, unlocked: bool, scene: Node = null, save_now: bool = true) -> bool:
	var normalized_feature_id := feature_id.strip_edges()
	if normalized_feature_id == "":
		return false
	var feature_unlocks: Dictionary = _state.get("feature_unlocks", {})
	if feature_unlocks.has(normalized_feature_id) and bool(feature_unlocks[normalized_feature_id]) == unlocked:
		return false
	feature_unlocks[normalized_feature_id] = unlocked
	_state["feature_unlocks"] = feature_unlocks
	if save_now:
		_save_state()
	apply_main_scene_feature_states(scene)
	return true

func set_feature_unlocks(raw_updates: Dictionary, scene: Node = null, save_now: bool = true) -> bool:
	if raw_updates.is_empty():
		return false
	var feature_unlocks: Dictionary = _state.get("feature_unlocks", {})
	var changed := false
	for raw_key in raw_updates.keys():
		var feature_id := str(raw_key).strip_edges()
		if feature_id == "":
			continue
		var unlocked := bool(raw_updates[raw_key])
		if feature_unlocks.has(feature_id) and bool(feature_unlocks[feature_id]) == unlocked:
			continue
		feature_unlocks[feature_id] = unlocked
		changed = true
	if not changed:
		return false
	_state["feature_unlocks"] = feature_unlocks
	if save_now:
		_save_state()
	apply_main_scene_feature_states(scene)
	return true

func report_action(action_id: String, payload: Dictionary = {}) -> bool:
	var current_step := _get_current_step()
	if current_step.is_empty():
		return false
	var wait_action := str(current_step.get("wait_action", "")).strip_edges()
	if wait_action == "" or wait_action != action_id.strip_edges():
		return false
	var payload_match: Variant = current_step.get("action_payload_match", {})
	if payload_match is Dictionary:
		for raw_key in (payload_match as Dictionary).keys():
			var key := str(raw_key)
			if not payload.has(key) or payload[key] != (payload_match as Dictionary)[raw_key]:
				return false
	_advance_step()
	return true

func report_story_finished(script_id: String, _script_meta: Dictionary = {}) -> bool:
	var current_step := _get_current_step()
	if current_step.is_empty():
		return false
	if str(current_step.get("type", "")).strip_edges() == "wait_action" and str(current_step.get("wait_action", "")).strip_edges() == "story_finished":
		var expected_wait_script_id := str(current_step.get("action_payload_match", {}).get("script_id", "")).strip_edges()
		if expected_wait_script_id == "" or expected_wait_script_id == script_id.strip_edges():
			_advance_step()
			return true
		return false
	if str(current_step.get("type", "")).strip_edges() != "play_story":
		return false
	var expected_script_id := str(current_step.get("script_id", "")).strip_edges()
	var expected_story_path := str(current_step.get("story_path", "")).strip_edges()
	var normalized_script_id := script_id.strip_edges()
	var matched := false
	if expected_script_id != "":
		matched = expected_script_id == normalized_script_id
	if not matched and expected_story_path != "":
		matched = expected_story_path.get_file().get_basename() == normalized_script_id
	if not matched:
		return false
	_advance_step()
	return true

func _get_active_guide() -> Dictionary:
	var active_guide_id := get_active_guide_id()
	if active_guide_id == "" or not _guide_defs.has(active_guide_id):
		return {}
	return _guide_defs.get(active_guide_id, {})

func _get_current_step() -> Dictionary:
	var guide_data := _get_active_guide()
	if guide_data.is_empty():
		return {}
	var steps: Array = guide_data.get("steps", [])
	var step_index := int(_state.get("current_step_index", 0))
	if step_index < 0 or step_index >= steps.size():
		return {}
	var step_data: Variant = steps[step_index]
	return step_data if step_data is Dictionary else {}

func _enter_current_step() -> void:
	var guide_data := _get_active_guide()
	if guide_data.is_empty():
		_hide_overlay()
		return
	var steps: Array = guide_data.get("steps", [])
	var step_index := int(_state.get("current_step_index", 0))
	if step_index >= steps.size():
		_complete_active_guide()
		return
	var step_data: Dictionary = _get_current_step()
	if step_data.is_empty():
		_complete_active_guide()
		return
	if _should_skip_step(step_data):
		call_deferred("_advance_step")
		return
	_apply_feature_updates(step_data.get("feature_updates", {}))
	_save_state()
	apply_main_scene_feature_states()
	if _should_complete_step_immediately(step_data):
		call_deferred("_advance_step")
		return
	var step_type := str(step_data.get("type", "message")).strip_edges()
	if step_type == "play_story":
		guide_step_changed.emit(get_active_guide_id(), str(step_data.get("id", "")), step_data)
		_play_story_step(step_data)
		return
	if step_type == "wait_action":
		_show_step_overlay(guide_data, step_data, step_index, steps.size())
		guide_step_changed.emit(get_active_guide_id(), str(step_data.get("id", "")), step_data)
		return
	_show_step_overlay(guide_data, step_data, step_index, steps.size())
	guide_step_changed.emit(get_active_guide_id(), str(step_data.get("id", "")), step_data)
	if bool(step_data.get("auto_advance", false)):
		call_deferred("_advance_step")

func _apply_feature_updates(raw_updates: Variant) -> void:
	if not (raw_updates is Dictionary):
		return
	var feature_unlocks: Dictionary = _state.get("feature_unlocks", {})
	for key in raw_updates.keys():
		feature_unlocks[str(key)] = bool(raw_updates[key])
	_state["feature_unlocks"] = feature_unlocks

func _play_story_step(step_data: Dictionary) -> void:
	var story_path := str(step_data.get("story_path", "")).strip_edges()
	if story_path == "" or not ResourceLoader.exists(story_path):
		push_warning("引导剧情不存在：%s" % story_path)
		call_deferred("_advance_step")
		return
	var debug_bridge := get_node_or_null("/root/StoryRuntimeDebugBridge")
	if debug_bridge != null:
		var guide_id := get_active_guide_id()
		var step_id := str(step_data.get("id", ""))
		debug_bridge.prepare_story("guide_flow", "%s/%s" % [guide_id, step_id], story_path, {
			"guide_id": guide_id,
			"step_id": step_id,
			"step_index": int(_state.get("current_step_index", 0)),
			"return_to_main": bool(step_data.get("return_to_main", true))
		})
	GameDataManager.set_meta("play_specific_story", story_path)
	GameDataManager.set_meta("story_scene_return_to_main_on_finish", bool(step_data.get("return_to_main", true)))
	_hide_overlay()
	if get_tree().root.has_node("SceneTransitionManager"):
		get_tree().root.get_node("SceneTransitionManager").transition_to_scene(GUIDE_SCENE_PATH)
	else:
		get_tree().change_scene_to_file(GUIDE_SCENE_PATH)

func _advance_step() -> void:
	_state["current_step_index"] = int(_state.get("current_step_index", 0)) + 1
	_save_state()
	_enter_current_step()

func go_to_previous_step_in_current_scene() -> bool:
	var guide_data := _get_active_guide()
	var current_step := _get_current_step()
	if guide_data.is_empty() or current_step.is_empty():
		return false
	var steps: Array = guide_data.get("steps", [])
	var current_index := int(_state.get("current_step_index", 0))
	if current_index <= 0 or current_index >= steps.size():
		return false
	var current_scene_id := _get_step_scene_id(current_step)
	for index in range(current_index - 1, -1, -1):
		var raw_step: Variant = steps[index]
		if not (raw_step is Dictionary):
			continue
		var step_data := raw_step as Dictionary
		if _get_step_scene_id(step_data) != current_scene_id:
			break
		_state["current_step_index"] = index
		_save_state()
		_enter_current_step()
		return true
	return false

func _complete_active_guide() -> void:
	var active_guide_id := get_active_guide_id()
	if active_guide_id == "":
		return
	var guide_data: Dictionary = _guide_defs.get(active_guide_id, {})
	_apply_feature_updates(guide_data.get("completion_feature_updates", {}))
	var completed_guides: Array[String] = _state.get("completed_guides", [])
	if not completed_guides.has(active_guide_id):
		completed_guides.append(active_guide_id)
	_state["completed_guides"] = completed_guides
	_state["active_guide_id"] = ""
	_state["current_step_index"] = 0
	_save_state()
	_hide_overlay()
	apply_main_scene_feature_states()
	if bool(guide_data.get("show_completion_toast", true)) and ToastManager and ToastManager.has_method("show_system_toast"):
		ToastManager.show_system_toast("新手引导已完成，更多功能已解锁")
	guide_completed.emit(active_guide_id)

func _show_step_overlay(guide_data: Dictionary, step_data: Dictionary, step_index: int, total_steps: int) -> void:
	if bool(step_data.get("hide_overlay", false)):
		_hide_overlay()
		return
	var overlay_ready := _ensure_overlay()
	var scene_ready := _is_step_scene_ready(step_data)
	var show_before_scene_ready := bool(step_data.get("show_before_scene_ready", false))
	if not overlay_ready:
		return
	if not is_instance_valid(_overlay) or not _overlay.has_method("show_step"):
		return
	var guide_title := str(guide_data.get("title", "新手引导")).strip_edges()
	var step_title := str(step_data.get("title", "当前步骤")).strip_edges()
	var step_text := str(step_data.get("text", "")).strip_edges()
	if step_text == "":
		step_text = "请根据当前提示继续操作。"
	if not scene_ready and (bool(step_data.get("hide_until_scene_ready", false)) or not show_before_scene_ready):
		if _show_resume_navigation_overlay(guide_data, step_data, step_index, total_steps):
			return
		_hide_overlay()
		return
	if not scene_ready:
		var scene_hint := str(step_data.get("scene_hint", "请先进入对应界面，再继续当前引导步骤。")).strip_edges()
		if scene_hint != "":
			step_text += "\n\n[color=#f2c98d]%s[/color]" % scene_hint
	var focus_rects: Array = _resolve_step_focus_rects(step_data)
	var focus_interaction_allowed: bool = _is_step_focus_interaction_allowed(step_data)
	var overlay_options := _resolve_overlay_options(step_data)
	_overlay.show_step(guide_title, step_title, step_text, step_index + 1, total_steps, focus_rects, focus_interaction_allowed, overlay_options)

func _show_resume_navigation_overlay(guide_data: Dictionary, step_data: Dictionary, step_index: int, total_steps: int) -> bool:
	if not is_instance_valid(_resolve_main_scene()):
		return false
	var requires_scene := str(step_data.get("requires_scene", step_data.get("target_scene", ""))).strip_edges()
	var navigation_feature := ""
	var navigation_text := ""
	match requires_scene:
		"activity":
			navigation_feature = "main.main_action"
			navigation_text = "引导将从当前步骤继续。请重新打开“行程安排”，进入后会恢复这里的操作提示。"
		"wechat":
			navigation_feature = "main.wechat"
			navigation_text = "引导将从当前步骤继续。请重新打开“微聊”，进入后会恢复这里的操作提示。"
		_:
			return false
	var navigation_step := {
		"target_scene": "main",
		"requires_scene": "main",
		"highlight_feature": navigation_feature
	}
	var focus_rects: Array = _resolve_step_focus_rects(navigation_step)
	if focus_rects.is_empty():
		return false
	var guide_title := str(guide_data.get("title", "新手引导")).strip_edges()
	var step_title := str(step_data.get("title", "继续引导")).strip_edges()
	_overlay.show_step(guide_title, step_title, navigation_text, step_index + 1, total_steps, focus_rects, true, {})
	return true

func _resolve_step_focus_rects(step_data: Dictionary) -> Array:
	var focus_rects: Array = []
	_append_focus_rect_result(focus_rects, _resolve_step_focus_result(step_data))
	var extra_targets: Variant = step_data.get("focus_targets", [])
	if extra_targets is Array:
		for raw_target in extra_targets:
			if not (raw_target is Dictionary):
				continue
			var target_data: Dictionary = {
				"target_scene": str(raw_target.get("target_scene", step_data.get("target_scene", "main"))).strip_edges(),
				"target_path": str(raw_target.get("target_path", "")).strip_edges(),
				"target_mode": str(raw_target.get("target_mode", "")).strip_edges(),
				"highlight_feature": str(raw_target.get("highlight_feature", "")).strip_edges(),
				"highlight_padding": float(raw_target.get("highlight_padding", step_data.get("highlight_padding", 10.0)))
			}
			_append_focus_rect_result(focus_rects, _resolve_step_focus_result(target_data))
	return focus_rects

func _append_focus_rect_result(target_rects: Array, focus_result: Variant) -> void:
	if focus_result is Rect2:
		var rect := focus_result as Rect2
		if rect.size.x > 1.0 and rect.size.y > 1.0:
			target_rects.append(rect)
		return
	if focus_result is Dictionary:
		var focus_entry := focus_result as Dictionary
		var rect_value: Variant = focus_entry.get("rect", Rect2())
		if rect_value is Rect2:
			var rect := rect_value as Rect2
			if rect.size.x > 1.0 and rect.size.y > 1.0:
				target_rects.append(focus_entry.duplicate(true))
		return
	if focus_result is Array:
		for item in focus_result:
			if item is Rect2:
				var rect := item as Rect2
				if rect.size.x > 1.0 and rect.size.y > 1.0:
					target_rects.append(rect)
			elif item is Dictionary:
				var focus_entry := item as Dictionary
				var rect_value: Variant = focus_entry.get("rect", Rect2())
				if rect_value is Rect2:
					var rect := rect_value as Rect2
					if rect.size.x > 1.0 and rect.size.y > 1.0:
						target_rects.append(focus_entry.duplicate(true))

func _hide_overlay() -> void:
	if is_instance_valid(_overlay) and _overlay.has_method("hide_overlay"):
		_overlay.hide_overlay()

func _refresh_current_step_display() -> void:
	var guide_data := _get_active_guide()
	var step_data := _get_current_step()
	if guide_data.is_empty() or step_data.is_empty():
		_hide_overlay()
		return
	var steps: Array = guide_data.get("steps", [])
	_show_step_overlay(guide_data, step_data, int(_state.get("current_step_index", 0)), steps.size())

func refresh_current_step_display() -> void:
	_refresh_current_step_display()

func _resolve_main_scene(scene: Node = null) -> Node:
	if is_instance_valid(scene):
		return scene
	if _main_scene_ref != null:
		var ref_value = _main_scene_ref.get_ref()
		if is_instance_valid(ref_value):
			return ref_value
	return null

func _resolve_world_map_scene() -> Node:
	if _world_map_scene_ref != null:
		var ref_value = _world_map_scene_ref.get_ref()
		if is_instance_valid(ref_value):
			return ref_value
	return null

func _resolve_location_detail_panel() -> Node:
	if _location_detail_panel_ref != null:
		var ref_value = _location_detail_panel_ref.get_ref()
		if is_instance_valid(ref_value):
			return ref_value
	return null

func _resolve_quick_location_scene() -> Node:
	if _quick_location_scene_ref != null:
		var ref_value = _quick_location_scene_ref.get_ref()
		if is_instance_valid(ref_value):
			return ref_value
	return null

func _resolve_tutoring_panel() -> Node:
	if _tutoring_panel_ref != null:
		var ref_value = _tutoring_panel_ref.get_ref()
		if is_instance_valid(ref_value):
			return ref_value
	return null

func _resolve_activity_panel() -> Node:
	if _activity_panel_ref != null:
		var ref_value = _activity_panel_ref.get_ref()
		if is_instance_valid(ref_value):
			return ref_value
	return null

func _resolve_schedule_execution_panel() -> Node:
	if _schedule_execution_panel_ref != null:
		var ref_value = _schedule_execution_panel_ref.get_ref()
		if is_instance_valid(ref_value):
			return ref_value
	return null

func _resolve_wechat_panel() -> Node:
	var main_scene := _resolve_main_scene()
	if not is_instance_valid(main_scene):
		return null
	var mobile_interface = main_scene.get("mobile_interface_instance")
	if not is_instance_valid(mobile_interface):
		return null
	var wechat_panel = mobile_interface.get("wechat_panel_instance")
	if not is_instance_valid(wechat_panel):
		return null
	if wechat_panel is Control and not (wechat_panel as Control).visible:
		return null
	return wechat_panel

func _is_step_scene_ready(step_data: Dictionary) -> bool:
	var requires_scene := str(step_data.get("requires_scene", step_data.get("target_scene", ""))).strip_edges()
	if requires_scene == "" or requires_scene == "any":
		return true
	if requires_scene == "main":
		var main_scene := _resolve_main_scene()
		if not is_instance_valid(main_scene):
			return false
		var highlight_feature := str(step_data.get("highlight_feature", "")).strip_edges()
		var target_mode := str(step_data.get("target_mode", "")).strip_edges()
		if highlight_feature == "main.goal" and main_scene.has_method("is_goal_panel_ready_for_guide"):
			return bool(main_scene.is_goal_panel_ready_for_guide())
		if highlight_feature == "main.ai_rounds" and main_scene.has_method("is_ai_round_info_ready_for_guide"):
			return bool(main_scene.is_ai_round_info_ready_for_guide())
		if highlight_feature == "main.affection" and main_scene.has_method("is_affection_button_ready_for_guide"):
			return bool(main_scene.is_affection_button_ready_for_guide())
		if highlight_feature == "main.affection_panel" and main_scene.has_method("is_affection_panel_ready_for_guide"):
			return bool(main_scene.is_affection_panel_ready_for_guide())
		if highlight_feature == "main.chat" and main_scene.has_method("is_chat_button_ready_for_guide"):
			return bool(main_scene.is_chat_button_ready_for_guide())
		if target_mode == "topic_options" and main_scene.has_method("is_main_chat_topic_options_ready"):
			return bool(main_scene.is_main_chat_topic_options_ready())
		if target_mode == "music_playlist" and main_scene.has_method("is_music_playlist_ready_for_guide"):
			return bool(main_scene.is_music_playlist_ready_for_guide())
		if main_scene.has_method("is_main_ui_ready_for_guide"):
			return bool(main_scene.is_main_ui_ready_for_guide())
		return true
	if requires_scene == "world_map":
		var world_map_scene := _resolve_world_map_scene()
		return is_instance_valid(world_map_scene) and (not world_map_scene.has_method("is_guide_target_ready") or bool(world_map_scene.is_guide_target_ready()))
	if requires_scene == "activity":
		var activity_panel := _resolve_activity_panel()
		return is_instance_valid(activity_panel) and (not (activity_panel is Control) or (activity_panel as Control).visible)
	if requires_scene == "schedule_execution":
		var execution_panel := _resolve_schedule_execution_panel()
		if not is_instance_valid(execution_panel) or ((execution_panel is Control) and not (execution_panel as Control).visible):
			return false
		var target_mode := str(step_data.get("target_mode", "")).strip_edges()
		if target_mode == "result_close_button" and execution_panel.has_method("is_result_close_button_ready_for_guide"):
			return bool(execution_panel.is_result_close_button_ready_for_guide())
		return true
	if requires_scene == "wechat":
		var wechat_panel := _resolve_wechat_panel()
		if not is_instance_valid(wechat_panel) or ((wechat_panel is Control) and not (wechat_panel as Control).visible):
			return false
		var target_mode := str(step_data.get("target_mode", "")).strip_edges()
		if target_mode == "recent_chats" and wechat_panel.has_method("is_recent_chats_ready_for_guide"):
			return bool(wechat_panel.is_recent_chats_ready_for_guide())
		if target_mode == "chat_session" and wechat_panel.has_method("is_chat_session_ready_for_guide"):
			return bool(wechat_panel.is_chat_session_ready_for_guide())
		if target_mode == "fixed_options" and wechat_panel.has_method("is_fixed_options_ready_for_guide"):
			return bool(wechat_panel.is_fixed_options_ready_for_guide())
		if target_mode == "input_edit" and wechat_panel.has_method("is_input_edit_ready_for_guide"):
			return bool(wechat_panel.is_input_edit_ready_for_guide())
		if target_mode == "send_button" and wechat_panel.has_method("is_send_button_ready_for_guide"):
			return bool(wechat_panel.is_send_button_ready_for_guide())
		if target_mode == "close_button" and wechat_panel.has_method("is_close_button_ready_for_guide"):
			return bool(wechat_panel.is_close_button_ready_for_guide())
		return true
	if requires_scene == "location_detail":
		var location_detail_panel := _resolve_location_detail_panel()
		return is_instance_valid(location_detail_panel) and (not (location_detail_panel is Control) or (location_detail_panel as Control).visible)
	if requires_scene == "quick_location":
		var quick_location_scene := _resolve_quick_location_scene()
		return is_instance_valid(quick_location_scene) and (not quick_location_scene.has_method("is_guide_target_ready") or bool(quick_location_scene.is_guide_target_ready()))
	if requires_scene == "tutoring":
		var tutoring_panel := _resolve_tutoring_panel()
		return is_instance_valid(tutoring_panel) and (not tutoring_panel.has_method("is_guide_target_ready") or bool(tutoring_panel.is_guide_target_ready()))
	return true

func _should_skip_step(step_data: Dictionary) -> bool:
	if bool(step_data.get("compatibility_auto_skip", false)):
		return true
	var skip_conditions: Variant = step_data.get("skip_conditions", [])
	if skip_conditions is Array and not skip_conditions.is_empty():
		var result: Dictionary = ConditionManagerScript.evaluate_conditions(skip_conditions)
		if bool(result.get("passed", false)):
			return true
	if bool(step_data.get("skip_if_action_already_done", false)):
		var wait_action := str(step_data.get("wait_action", "")).strip_edges()
		if wait_action != "" and _is_action_already_satisfied(wait_action):
			return true
	if bool(step_data.get("skip_if_target_missing", false)):
		if _resolve_step_target_node(step_data) == null:
			return true
	return false

func _should_complete_step_immediately(step_data: Dictionary) -> bool:
	var complete_conditions: Variant = step_data.get("complete_conditions", [])
	if complete_conditions is Array and not complete_conditions.is_empty():
		var result: Dictionary = ConditionManagerScript.evaluate_conditions(complete_conditions)
		if bool(result.get("passed", false)):
			return true
	return false

func _is_action_already_satisfied(action_id: String) -> bool:
	match action_id:
		"open_affection":
			var main_scene := _resolve_main_scene()
			if is_instance_valid(main_scene):
				var popup = main_scene.get_node_or_null("UIPanel/AffectionOverlay/PopupCenter/AffectionPopupFrame") as Control
				return popup != null and popup.visible
		"open_wechat":
			var main_scene := _resolve_main_scene()
			if is_instance_valid(main_scene):
				var mobile_interface = main_scene.get("mobile_interface_instance")
				if is_instance_valid(mobile_interface):
					var wechat_panel = mobile_interface.get("wechat_panel_instance")
					return wechat_panel != null and wechat_panel.visible
		"open_diary":
			var main_scene := _resolve_main_scene()
			if is_instance_valid(main_scene):
				var diary_panel = main_scene.get_node_or_null("UIPanel/DiaryPanel") as Control
				return diary_panel != null and diary_panel.visible
		"open_gift":
			var main_scene := _resolve_main_scene()
			if is_instance_valid(main_scene):
				for child in main_scene.get_children():
					if child != null and child.name == "GiftPanel" and child is Control and child.visible:
						return true
		"open_date":
			var main_scene := _resolve_main_scene()
			if is_instance_valid(main_scene):
				var ui_panel = main_scene.get_node_or_null("UIPanel")
				if ui_panel:
					for child in ui_panel.get_children():
						if child != null and child.name == "DateScene" and child is Control and child.visible:
							return true
		"open_map", "select_map_location":
			return is_instance_valid(_resolve_world_map_scene())
		"enter_location_detail":
			return is_instance_valid(_resolve_location_detail_panel())
		"open_schedule":
			var activity_panel := _resolve_activity_panel()
			return is_instance_valid(activity_panel)
		"activity_add_course":
			var activity_panel := _resolve_activity_panel()
			if is_instance_valid(activity_panel) and activity_panel.has_method("get_user_selected_course_count"):
				return int(activity_panel.get_user_selected_course_count()) > 0
		"activity_schedule_full":
			var activity_panel := _resolve_activity_panel()
			if is_instance_valid(activity_panel) and activity_panel.has_method("get_total_scheduled_count"):
				return int(activity_panel.get_total_scheduled_count()) >= 5
		"activity_click_main_event_slot":
			return false
		"activity_click_preview_panel":
			return false
		"activity_execute_schedule":
			return is_instance_valid(_resolve_schedule_execution_panel())
		"schedule_execution_click_info_panel":
			return false
		"schedule_execution_click_track_panel":
			return false
		"schedule_execution_finish_intro":
			return false
		"schedule_execution_click_area":
			return false
		"schedule_execution_advance":
			var execution_panel := _resolve_schedule_execution_panel()
			if is_instance_valid(execution_panel) and execution_panel.has_method("has_started_execution"):
				return bool(execution_panel.has_started_execution())
	return false

func _resolve_step_focus_result(step_data: Dictionary) -> Variant:
	var target_scene := str(step_data.get("target_scene", "main")).strip_edges()
	var target_mode := str(step_data.get("target_mode", "")).strip_edges()
	var highlight_feature := str(step_data.get("highlight_feature", "")).strip_edges()
	var raw_result: Variant = null
	if target_scene == "main":
		var main_scene := _resolve_main_scene()
		if is_instance_valid(main_scene):
			if highlight_feature == "main.main_action" and main_scene.has_method("get_main_action_focus_entry"):
				raw_result = main_scene.get_main_action_focus_entry()
			elif highlight_feature == "main.affection" and main_scene.has_method("get_affection_button_focus_entry"):
				raw_result = main_scene.get_affection_button_focus_entry()
			elif highlight_feature == "main.affection_panel" and main_scene.has_method("get_affection_panel_focus_entry"):
				raw_result = main_scene.get_affection_panel_focus_entry()
			elif highlight_feature == "main.top_status" and main_scene.has_method("get_top_status_panel_focus_entry"):
				raw_result = main_scene.get_top_status_panel_focus_entry()
			elif highlight_feature == "main.weather" and main_scene.has_method("get_weather_panel_focus_entry"):
				raw_result = main_scene.get_weather_panel_focus_entry()
			elif highlight_feature == "main.goal" and main_scene.has_method("get_goal_panel_focus_entry"):
				raw_result = main_scene.get_goal_panel_focus_entry()
			elif highlight_feature == "main.stats" and main_scene.has_method("get_stats_panel_focus_entry"):
				raw_result = main_scene.get_stats_panel_focus_entry()
			elif highlight_feature == "main.wechat" and main_scene.has_method("get_wechat_button_focus_entry"):
				raw_result = main_scene.get_wechat_button_focus_entry()
			elif highlight_feature == "main.chat" and main_scene.has_method("get_chat_button_focus_entry"):
				raw_result = main_scene.get_chat_button_focus_entry()
			elif highlight_feature == "main.ai_rounds" and main_scene.has_method("get_ai_round_info_focus_entry"):
				raw_result = main_scene.get_ai_round_info_focus_entry()
			elif target_mode == "topic_options" and main_scene.has_method("get_main_chat_topic_options_focus_entry"):
				raw_result = main_scene.get_main_chat_topic_options_focus_entry()
			elif target_mode == "music_player" and main_scene.has_method("get_music_player_focus_entry"):
				raw_result = main_scene.get_music_player_focus_entry()
			elif target_mode == "music_cover" and main_scene.has_method("get_music_cover_focus_entry"):
				raw_result = main_scene.get_music_cover_focus_entry()
			elif target_mode == "music_playlist" and main_scene.has_method("get_music_playlist_focus_entry"):
				raw_result = main_scene.get_music_playlist_focus_entry()
	if target_scene == "activity":
		var activity_panel := _resolve_activity_panel()
		if is_instance_valid(activity_panel):
			match target_mode:
				"category_tabs":
					if activity_panel.has_method("get_category_tabs_focus_rect"):
						raw_result = activity_panel.get_category_tabs_focus_rect()
				"activity_list":
					if activity_panel.has_method("get_activity_list_focus_rect"):
						raw_result = activity_panel.get_activity_list_focus_rect()
				"tabs_and_list":
					if activity_panel.has_method("get_tabs_and_list_focus_rect"):
						raw_result = activity_panel.get_tabs_and_list_focus_rect()
				"schedule_slots":
					if activity_panel.has_method("get_schedule_slots_focus_rect"):
						raw_result = activity_panel.get_schedule_slots_focus_rect()
			if raw_result == null:
				var target_path := str(step_data.get("target_path", "")).strip_edges()
				if target_path == "BackgroundPanel/Margin/MainHBox/RightPanel":
					if activity_panel.has_method("get_preview_panel_focus_data"):
						raw_result = activity_panel.get_preview_panel_focus_data()
				elif target_path == "BackgroundPanel/Margin/MainHBox/RightPanel/Margin/VBox/ExecuteButton":
					if activity_panel.has_method("get_execute_button_focus_data"):
						raw_result = activity_panel.get_execute_button_focus_data()
	if target_scene == "schedule_execution":
		var execution_panel := _resolve_schedule_execution_panel()
		if is_instance_valid(execution_panel):
			match target_mode:
				"info_panel":
					if execution_panel.has_method("get_info_panel_focus_data"):
						raw_result = execution_panel.get_info_panel_focus_data()
				"track_panel":
					if execution_panel.has_method("get_track_panel_focus_data"):
						raw_result = execution_panel.get_track_panel_focus_data()
				"click_area":
					if execution_panel.has_method("get_click_area_focus_data"):
						raw_result = execution_panel.get_click_area_focus_data()
				"result_close_button":
					if execution_panel.has_method("get_result_close_button_focus_data"):
						raw_result = execution_panel.get_result_close_button_focus_data()
	if target_scene == "wechat":
		var wechat_panel := _resolve_wechat_panel()
		if is_instance_valid(wechat_panel):
			match target_mode:
				"window_panel":
					if wechat_panel.has_method("get_window_panel_focus_entry"):
						raw_result = wechat_panel.get_window_panel_focus_entry()
				"recent_chats":
					if wechat_panel.has_method("get_recent_chats_focus_entry"):
						raw_result = wechat_panel.get_recent_chats_focus_entry()
				"chat_session":
					if wechat_panel.has_method("get_chat_session_focus_entry"):
						raw_result = wechat_panel.get_chat_session_focus_entry()
				"fixed_options":
					if wechat_panel.has_method("get_fixed_options_focus_entry"):
						raw_result = wechat_panel.get_fixed_options_focus_entry()
				"input_edit":
					if wechat_panel.has_method("get_input_edit_focus_entry"):
						raw_result = wechat_panel.get_input_edit_focus_entry()
				"send_button":
					if wechat_panel.has_method("get_send_button_focus_entry"):
						raw_result = wechat_panel.get_send_button_focus_entry()
				"close_button":
					if wechat_panel.has_method("get_close_button_focus_entry"):
						raw_result = wechat_panel.get_close_button_focus_entry()
	if target_scene == "tutoring":
		var tutoring_panel := _resolve_tutoring_panel()
		if is_instance_valid(tutoring_panel) and tutoring_panel.has_method("get_guide_focus_data"):
			raw_result = tutoring_panel.get_guide_focus_data(target_mode)
	if raw_result == null:
		var target_node := _resolve_step_target_node(step_data)
		if target_node == null or not (target_node is Control):
			return Rect2()
		var target_control := target_node as Control
		if not target_control.is_visible_in_tree():
			return Rect2()
		raw_result = target_control.get_global_rect()
	var padding := _get_focus_padding(step_data, raw_result)
	return _apply_padding_to_focus_result(raw_result, padding)

func _get_focus_padding(step_data: Dictionary, focus_result: Variant) -> float:
	if step_data.has("highlight_padding"):
		return maxf(0.0, float(step_data.get("highlight_padding", 0.0)))
	if _is_structured_focus_result(focus_result):
		return 0.0
	return 10.0

func _is_structured_focus_result(focus_result: Variant) -> bool:
	if focus_result is Dictionary:
		return (focus_result as Dictionary).has("rect")
	if focus_result is Array:
		for item in focus_result:
			if item is Dictionary and (item as Dictionary).has("rect"):
				return true
	return false

func _apply_padding_to_focus_result(focus_result: Variant, padding: float) -> Variant:
	if padding <= 0.0:
		return focus_result
	if focus_result is Rect2:
		return _grow_focus_rect(focus_result as Rect2, padding)
	if focus_result is Dictionary:
		var focus_entry := (focus_result as Dictionary).duplicate(true)
		var rect_value: Variant = focus_entry.get("rect", Rect2())
		if rect_value is Rect2:
			focus_entry["rect"] = _grow_focus_rect(rect_value as Rect2, padding)
		return focus_entry
	if focus_result is Array:
		var padded_items: Array = []
		for item in focus_result:
			if item is Rect2:
				padded_items.append(_grow_focus_rect(item as Rect2, padding))
			elif item is Dictionary:
				var focus_entry := (item as Dictionary).duplicate(true)
				var rect_value: Variant = focus_entry.get("rect", Rect2())
				if rect_value is Rect2:
					focus_entry["rect"] = _grow_focus_rect(rect_value as Rect2, padding)
				padded_items.append(focus_entry)
			else:
				padded_items.append(item)
		return padded_items
	return focus_result

func _grow_focus_rect(rect: Rect2, padding: float) -> Rect2:
	var grown_rect := rect
	grown_rect.position -= Vector2(padding, padding)
	grown_rect.size += Vector2(padding * 2.0, padding * 2.0)
	return grown_rect

func _resolve_overlay_options(step_data: Dictionary) -> Dictionary:
	var raw_options: Variant = step_data.get("overlay_options", {})
	if raw_options is Dictionary:
		return (raw_options as Dictionary).duplicate(true)
	return {}

func _get_step_scene_id(step_data: Dictionary) -> String:
	var requires_scene := str(step_data.get("requires_scene", "")).strip_edges()
	if requires_scene != "":
		return requires_scene
	var target_scene := str(step_data.get("target_scene", "")).strip_edges()
	if target_scene != "":
		return target_scene
	return "main"

func _resolve_step_target_node(step_data: Dictionary) -> Node:
	var target_scene := str(step_data.get("target_scene", "main")).strip_edges()
	var highlight_feature := str(step_data.get("highlight_feature", "")).strip_edges()
	var target_path := str(step_data.get("target_path", "")).strip_edges()
	var target_mode := str(step_data.get("target_mode", "")).strip_edges()

	if target_scene == "main":
		var main_scene := _resolve_main_scene()
		if not is_instance_valid(main_scene):
			return null
		if target_mode == "topic_options" and main_scene.has_method("get_node_or_null"):
			return main_scene.get_node_or_null("DialoguePanel/QuickOptionLayer")
		if highlight_feature != "" and MAIN_SCENE_FEATURE_PATHS.has(highlight_feature):
			return main_scene.get_node_or_null(str(MAIN_SCENE_FEATURE_PATHS[highlight_feature]))
		if target_path != "":
			return main_scene.get_node_or_null(target_path)
	elif target_scene == "world_map":
		var world_map_scene := _resolve_world_map_scene()
		if not is_instance_valid(world_map_scene):
			return null
		if target_mode == "first_unlocked_location" and world_map_scene.has_method("get_first_unlocked_location_button"):
			return world_map_scene.get_first_unlocked_location_button()
		if target_mode == "area_by_id" and world_map_scene.has_method("get_area_button"):
			return world_map_scene.get_area_button(str(step_data.get("target_id", "")))
		if target_mode == "location_by_id" and world_map_scene.has_method("get_location_button"):
			return world_map_scene.get_location_button(str(step_data.get("target_id", "")))
		if target_path != "":
			return world_map_scene.get_node_or_null(target_path)
	elif target_scene == "activity":
		var activity_panel := _resolve_activity_panel()
		if not is_instance_valid(activity_panel):
			return null
		if target_mode == "category_tabs":
			return activity_panel.get_node_or_null("BackgroundPanel/Margin/MainHBox/LeftPanel/Margin/VBox/CategoryTabs")
		if target_mode == "activity_list":
			return activity_panel.get_node_or_null("BackgroundPanel/Margin/MainHBox/LeftPanel/Margin/VBox/CategoryContentCard/CategoryContentMargin/CategoryContentVBox/ScrollContainer")
		if target_mode == "tabs_and_list":
			return activity_panel.get_node_or_null("BackgroundPanel/Margin/MainHBox/LeftPanel/Margin/VBox/CategoryContentCard/CategoryContentMargin/CategoryContentVBox/ScrollContainer")
		if target_mode == "schedule_slots":
			return activity_panel.get_node_or_null("BackgroundPanel/Margin/MainHBox/LeftPanel/Margin/VBox/BottomHBox/ScheduleSlots")
		if target_mode == "main_event_slot" and activity_panel.has_method("get_main_event_slot_button"):
			return activity_panel.get_main_event_slot_button()
		if target_mode == "first_activity_item" and activity_panel.has_method("get_first_activity_item"):
			return activity_panel.get_first_activity_item()
		if target_path != "":
			return activity_panel.get_node_or_null(target_path)
	elif target_scene == "schedule_execution":
		var execution_panel := _resolve_schedule_execution_panel()
		if not is_instance_valid(execution_panel):
			return null
		if target_mode == "info_panel" and execution_panel.has_method("get_info_panel_target"):
			return execution_panel.get_info_panel_target()
		if target_mode == "track_panel" and execution_panel.has_method("get_track_panel_target"):
			return execution_panel.get_track_panel_target()
		if target_mode == "click_area" and execution_panel.has_method("get_click_area_target"):
			return execution_panel.get_click_area_target()
		if target_mode == "result_close_button" and execution_panel.has_method("get_result_close_button_target"):
			return execution_panel.get_result_close_button_target()
		if target_path != "":
			return execution_panel.get_node_or_null(target_path)
	elif target_scene == "wechat":
		var wechat_panel := _resolve_wechat_panel()
		if not is_instance_valid(wechat_panel):
			return null
		if target_mode == "window_panel" and wechat_panel.has_method("get_window_panel_target"):
			return wechat_panel.get_window_panel_target()
		if target_mode == "recent_chats" and wechat_panel.has_method("get_recent_chats_target"):
			return wechat_panel.get_recent_chats_target()
		if target_mode == "chat_session" and wechat_panel.has_method("get_chat_session_target"):
			return wechat_panel.get_chat_session_target()
		if target_mode == "fixed_options" and wechat_panel.has_method("get_fixed_options_target"):
			return wechat_panel.get_fixed_options_target()
		if target_mode == "input_edit" and wechat_panel.has_method("get_input_edit_target"):
			return wechat_panel.get_input_edit_target()
		if target_mode == "send_button" and wechat_panel.has_method("get_send_button_target"):
			return wechat_panel.get_send_button_target()
		if target_mode == "close_button" and wechat_panel.has_method("get_close_button_target"):
			return wechat_panel.get_close_button_target()
		if target_path != "":
			return wechat_panel.get_node_or_null(target_path)
	elif target_scene == "location_detail":
		var location_detail_panel := _resolve_location_detail_panel()
		if not is_instance_valid(location_detail_panel):
			return null
		if target_path != "":
			return location_detail_panel.get_node_or_null(target_path)
	elif target_scene == "quick_location":
		var quick_location_scene := _resolve_quick_location_scene()
		if not is_instance_valid(quick_location_scene):
			return null
		if target_mode == "action_by_id" and quick_location_scene.has_method("get_action_button_for_guide"):
			return quick_location_scene.get_action_button_for_guide(str(step_data.get("target_id", "")))
	elif target_scene == "tutoring":
		var tutoring_panel := _resolve_tutoring_panel()
		if not is_instance_valid(tutoring_panel):
			return null
		if tutoring_panel.has_method("get_guide_target"):
			return tutoring_panel.get_guide_target(target_mode)
	return null

func is_guide_interaction_allowed(interaction_id: String) -> bool:
	if get_active_guide_id() == "":
		return true
	var step_data := _get_current_step()
	if step_data.is_empty():
		return true
	if not _is_step_scene_ready(step_data):
		return true
	var allowed_interactions: Variant = step_data.get("allowed_interactions", [])
	if allowed_interactions is Array and not allowed_interactions.is_empty():
		return (allowed_interactions as Array).has(interaction_id)
	var step_id := str(step_data.get("id", "")).strip_edges()
	match step_id:
		"try_switch_category":
			return interaction_id == "activity.category_tabs"
		"explain_schedule_list", "explain_schedule_slots":
			return interaction_id == "activity.category_tabs" or interaction_id == "activity.activity_list"
		"explain_main_story_slot":
			return interaction_id == "activity.main_event_slot"
		"execute_schedule_plan":
			return interaction_id == "activity.execute_button"
		"explain_schedule_tabs":
			return interaction_id == "activity.category_tabs"
		"explain_schedule_preview":
			return interaction_id == "activity.preview_panel"
		"explain_execution_panel", "advance_first_course", "explain_execution_info_panel", "explain_execution_track_panel":
			return interaction_id == "schedule_execution.click_area"
		"close_schedule_result_popup":
			return interaction_id == "schedule_execution.result_close_button"
		"explain_post_schedule_stats":
			return interaction_id == "main.stats_panel"
		"open_wechat_after_schedule":
			return interaction_id == "main.wechat"
		"explain_wechat_recent_chats":
			return interaction_id == "wechat.recent_chats"
		"explain_wechat_chat_session":
			return interaction_id == "wechat.chat_session"
		"explain_wechat_fixed_options":
			return interaction_id == "wechat.fixed_option"
		"explain_wechat_fixed_conversation":
			return interaction_id == "wechat.fixed_option" or interaction_id == "wechat.input_edit" or interaction_id == "wechat.send"
		"close_wechat_after_read":
			return interaction_id == "wechat.close"
		"explain_main_goal_panel":
			return interaction_id == "main.goal_panel"
		"choose_topic_after_goal":
			return interaction_id == "main.chat_topic_options"
		"explain_main_affection_button":
			return interaction_id == "main.affection"
		"explain_day6_music_player":
			return interaction_id == "main.music_player"
		"open_day6_music_playlist":
			return interaction_id == "main.music_cover"
		"explain_day6_music_playlist":
			return interaction_id == "main.music_playlist"
		_:
			return true

func _is_step_focus_interaction_allowed(step_data: Dictionary) -> bool:
	var overlay_options: Variant = step_data.get("overlay_options", {})
	if overlay_options is Dictionary and bool((overlay_options as Dictionary).get("capture_focus_clicks", false)):
		return true
	var step_id := str(step_data.get("id", "")).strip_edges()
	match step_id:
		"explain_schedule_tabs", "explain_schedule_list", "explain_schedule_slots", "explain_main_story_slot", "explain_schedule_preview", "execute_schedule_plan", "explain_execution_panel", "advance_first_course", "explain_execution_info_panel", "explain_execution_track_panel", "close_schedule_result_popup", "explain_post_schedule_stats", "open_wechat_after_schedule", "explain_wechat_recent_chats", "explain_wechat_chat_session", "explain_wechat_fixed_options", "explain_wechat_fixed_conversation", "close_wechat_after_read", "explain_main_goal_panel", "open_interact_group_after_goal", "choose_topic_after_goal", "explain_main_affection_button", "explain_main_affection_panel", "open_map_for_saturday_guidance", "select_art_academy_for_guidance", "select_library_for_guidance", "enter_library_guidance_story", "open_library_tutoring", "select_library_tutoring_courses", "explain_library_tutoring_details", "start_library_tutoring", "explain_day6_music_player", "open_day6_music_playlist", "explain_day6_music_playlist":
			return true
		_:
			return false

func apply_main_scene_feature_states(scene: Node = null) -> void:
	var main_scene := _resolve_main_scene(scene)
	if not is_instance_valid(main_scene):
		return
	for feature_id in MAIN_SCENE_FEATURE_PATHS.keys():
		var node_path := str(MAIN_SCENE_FEATURE_PATHS[feature_id])
		var target_button := main_scene.get_node_or_null(node_path) as Button
		if target_button == null:
			continue
		_apply_button_lock_state(target_button, not is_feature_unlocked(feature_id, true))
	feature_states_changed.emit()

func _apply_button_lock_state(target_button: Button, is_locked: bool) -> void:
	target_button.set_meta("guide_locked", is_locked)
	if is_locked:
		target_button.disabled = true
		target_button.modulate = Color(0.52, 0.52, 0.56, 0.9)
		target_button.tooltip_text = GUIDE_LOCK_HINT
	else:
		target_button.disabled = false
		target_button.modulate = Color(1, 1, 1, 1)
		if target_button.tooltip_text == GUIDE_LOCK_HINT:
			target_button.tooltip_text = ""
