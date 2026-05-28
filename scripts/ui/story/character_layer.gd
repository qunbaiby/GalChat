extends Node2D

const StoryPortraitActorScene = preload("res://scenes/ui/story/story_portrait_actor.tscn")

const MAX_VISIBLE_CAST := 4
const SLOT_LAYOUTS := {
	1: [Vector2(640, 720)],
	2: [Vector2(360, 720), Vector2(920, 720)],
	3: [Vector2(220, 720), Vector2(640, 720), Vector2(1060, 720)],
	4: [Vector2(150, 720), Vector2(430, 720), Vector2(850, 720), Vector2(1130, 720)]
}
const MANUAL_SLOT_POSITIONS := {
	"far_left": Vector2(150, 720),
	"left": Vector2(360, 720),
	"left_center": Vector2(430, 720),
	"center": Vector2(640, 720),
	"right_center": Vector2(850, 720),
	"right": Vector2(920, 720),
	"far_right": Vector2(1130, 720)
}

var _actor_pool: Array = []
var _story_actor_order: Array[String] = []
var _story_actor_map: Dictionary = {}
var _story_actor_state: Dictionary = {}
var _story_mode_enabled: bool = false
var _current_story_speaker_id: String = ""
var _character_cache: Dictionary = {}

func _ready() -> void:
	_ensure_actor_pool()
	GameDataManager.character_switched.connect(_on_character_switched)
	_refresh_default_actor(true)

func _on_character_switched(char_id: String) -> void:
	if _story_mode_enabled:
		var current_id = _get_current_character_id()
		if current_id != "" and _story_actor_map.has(current_id):
			var actor = _story_actor_map[current_id]
			if actor:
				actor.configure_from_data(_build_character_payload(current_id, actor.actor_name), "")
	else:
		_refresh_default_actor(true)

func begin_story_mode() -> void:
	_story_mode_enabled = true
	_current_story_speaker_id = ""
	_story_actor_order.clear()
	_story_actor_map.clear()
	_story_actor_state.clear()
	for actor in _actor_pool:
		actor.clear_actor()

func end_story_mode() -> void:
	_story_mode_enabled = false
	_current_story_speaker_id = ""
	_story_actor_order.clear()
	_story_actor_map.clear()
	_story_actor_state.clear()
	for actor in _actor_pool:
		actor.clear_actor()

func focus_story_speaker(raw_speaker_id: String, display_name: String = "", mood: String = "", presentation: Dictionary = {}) -> void:
	if not _story_mode_enabled:
		begin_story_mode()

	var speaker_key = str(presentation.get("character", raw_speaker_id))
	var speaker_id = _normalize_story_speaker_id(speaker_key)
	if speaker_id == "":
		_arrange_story_cast("", false)
		return

	_current_story_speaker_id = speaker_id
	var state = _ensure_story_actor_state(speaker_id)
	var expression = str(presentation.get("expression", mood)).strip_edges()
	if str(presentation.get("position", "")).strip_edges() != "":
		state["position"] = _normalize_position_key(str(presentation.get("position", "")))
	if expression != "":
		state["expression"] = expression
	if display_name != "":
		state["display_name"] = display_name
	if presentation.has("focus"):
		state["focus"] = presentation.get("focus")

	var actor = _ensure_story_actor(speaker_id, display_name, expression)
	if actor == null:
		return

	var should_enter = bool(presentation.get("enter", false))
	var enter_animation = str(presentation.get("animation", "fade_in")).strip_edges()
	if should_enter or not actor.visible:
		actor.show_actor(enter_animation if enter_animation != "" else "fade_in", false)

	_arrange_story_cast(speaker_id, false)

func show_story_character(raw_char_id: String, display_name: String = "", presentation: Dictionary = {}) -> void:
	if not _story_mode_enabled:
		begin_story_mode()

	var char_id = _normalize_story_speaker_id(raw_char_id)
	if char_id == "":
		return

	var state = _ensure_story_actor_state(char_id)
	if display_name != "":
		state["display_name"] = display_name
	if str(presentation.get("position", "")).strip_edges() != "":
		state["position"] = _normalize_position_key(str(presentation.get("position", "")))
	if str(presentation.get("expression", "")).strip_edges() != "":
		state["expression"] = str(presentation.get("expression", "")).strip_edges()
	if presentation.has("focus"):
		state["focus"] = presentation.get("focus")

	var actor = _ensure_story_actor(char_id, display_name, str(state.get("expression", "")))
	if actor == null:
		return

	var animation = str(presentation.get("animation", "fade_in")).strip_edges()
	actor.show_actor(animation if animation != "" else "fade_in", false)
	if bool(presentation.get("focus", false)):
		_current_story_speaker_id = char_id
	_arrange_story_cast(_current_story_speaker_id, false)

func hide_story_character(raw_char_id: String, animation: String = "fade_out") -> void:
	var char_id = _normalize_story_speaker_id(raw_char_id)
	if char_id == "":
		return
	var actor = _story_actor_map.get(char_id, null)
	if actor:
		actor.hide_actor(animation if animation != "" else "fade_out", false)
	_story_actor_map.erase(char_id)
	_story_actor_state.erase(char_id)
	_story_actor_order.erase(char_id)
	if _current_story_speaker_id == char_id:
		_current_story_speaker_id = ""
	_arrange_story_cast(_current_story_speaker_id, false)

func show_character(anim_type: String = "fade_in") -> void:
	show()
	if _story_mode_enabled and not _story_actor_map.is_empty():
		for actor in _story_actor_map.values():
			if actor and actor.has_method("show_actor"):
				actor.show_actor(anim_type, anim_type == "none")
		_arrange_story_cast(_current_story_speaker_id, true)
		return

	var actor = _get_default_actor()
	if actor == null:
		return
	_refresh_default_actor(false)
	actor.show_actor(anim_type, anim_type == "none")
	actor.apply_layout(SLOT_LAYOUTS[1][0], true, true)

func hide_character(anim_type: String = "fade_out") -> void:
	if _story_mode_enabled and not _story_actor_map.is_empty():
		for actor in _story_actor_map.values():
			if actor and actor.has_method("hide_actor"):
				actor.hide_actor(anim_type, anim_type == "none")
		return

	var actor = _get_default_actor()
	if actor:
		actor.hide_actor(anim_type, anim_type == "none")

func load_sprite_frames_by_path(path: String) -> void:
	_story_mode_enabled = false
	_story_actor_order.clear()
	_story_actor_map.clear()
	_story_actor_state.clear()
	for actor in _actor_pool:
		actor.clear_actor()

	var default_actor = _get_default_actor()
	if default_actor == null:
		return

	var payload = _build_character_payload(_get_current_character_id(), _get_current_character_display_name())
	if path != "":
		payload["sprite_frames_path"] = path
		payload.erase("expression_texture")
	default_actor.configure_from_data(payload, "")
	default_actor.apply_layout(SLOT_LAYOUTS[1][0], true, true)

func update_sprite(new_texture: Texture2D) -> void:
	if new_texture == null:
		return

	var current_id = _get_current_character_id()
	if _story_mode_enabled and current_id != "" and _story_actor_map.has(current_id):
		var story_actor = _story_actor_map[current_id]
		if story_actor:
			story_actor.update_texture(new_texture, false)
			return

	var default_actor = _get_default_actor()
	if default_actor:
		default_actor.update_texture(new_texture, false)

func play_animation(anim_name: String, loop: bool = true) -> void:
	# 兼容旧调用，现阶段由单个 Actor 自行选择默认动画。
	pass

func _refresh_default_actor(show_now: bool) -> void:
	var default_actor = _get_default_actor()
	if default_actor == null:
		return

	var payload = _build_character_payload(_get_current_character_id(), _get_current_character_display_name(), "")
	if default_actor.configure_from_data(payload, ""):
		default_actor.apply_layout(SLOT_LAYOUTS[1][0], true, true)
		if show_now:
			default_actor.show_actor("none", true)

func _ensure_story_actor(char_id: String, display_name: String, mood: String):
	var state = _ensure_story_actor_state(char_id)
	if _story_actor_map.has(char_id):
		var existing_actor = _story_actor_map[char_id]
		if existing_actor:
			existing_actor.configure_from_data(_build_character_payload(char_id, display_name, str(state.get("expression", mood))), str(state.get("expression", mood)))
			return existing_actor

	var actor = _find_free_actor()
	if actor == null:
		_evict_story_actor(char_id)
		actor = _find_free_actor()
	if actor == null:
		return null

	_story_actor_map[char_id] = actor
	_story_actor_order.append(char_id)
	actor.configure_from_data(_build_character_payload(char_id, display_name, str(state.get("expression", mood))), str(state.get("expression", mood)))
	return actor

func _find_free_actor():
	for actor in _actor_pool:
		if not _story_actor_map.values().has(actor):
			return actor
	return null

func _evict_story_actor(exclude_id: String) -> void:
	for actor_id in _story_actor_order:
		if actor_id == exclude_id:
			continue
		var actor = _story_actor_map.get(actor_id, null)
		if actor:
			actor.hide_actor("fade_out", true)
			actor.clear_actor()
		_story_actor_map.erase(actor_id)
		_story_actor_state.erase(actor_id)
		_story_actor_order.erase(actor_id)
		return

func _arrange_story_cast(active_char_id: String, instant: bool) -> void:
	var visible_ids: Array[String] = []
	for actor_id in _story_actor_order:
		if _story_actor_map.has(actor_id):
			visible_ids.append(actor_id)
	if visible_ids.is_empty():
		return

	var layout_size = min(visible_ids.size(), MAX_VISIBLE_CAST)
	var positions: Array = SLOT_LAYOUTS.get(layout_size, SLOT_LAYOUTS[MAX_VISIBLE_CAST])
	var remaining_positions: Array = positions.duplicate()
	var auto_ids: Array[String] = []

	for actor_id in visible_ids:
		var state = _story_actor_state.get(actor_id, {})
		var position_key = _normalize_position_key(str(state.get("position", "")))
		if MANUAL_SLOT_POSITIONS.has(position_key):
			var manual_position: Vector2 = MANUAL_SLOT_POSITIONS[position_key]
			var manual_actor = _story_actor_map.get(actor_id, null)
			if manual_actor:
				var is_focused = _resolve_actor_focus(actor_id, active_char_id)
				manual_actor.apply_layout(manual_position, is_focused, instant)
				_remove_nearest_position(remaining_positions, manual_position)
		else:
			auto_ids.append(actor_id)

	for index in range(auto_ids.size()):
		var actor_id = auto_ids[index]
		var actor = _story_actor_map.get(actor_id, null)
		if actor == null:
			continue
		var target_position = remaining_positions[index] if index < remaining_positions.size() else positions[min(index, positions.size() - 1)]
		var is_focused = _resolve_actor_focus(actor_id, active_char_id)
		actor.apply_layout(target_position, is_focused, instant)

func _get_default_actor():
	if _actor_pool.is_empty():
		return null
	return _actor_pool[0]

func _ensure_actor_pool() -> void:
	if not _actor_pool.is_empty():
		return
	for index in range(MAX_VISIBLE_CAST):
		var actor = StoryPortraitActorScene.instantiate()
		actor.name = "StoryActor%d" % index
		add_child(actor)
		_actor_pool.append(actor)

func _build_character_payload(char_id: String, display_name: String = "", expression: String = "") -> Dictionary:
	var payload: Dictionary = {
		"char_id": char_id,
		"display_name": display_name
	}
	if char_id == "":
		return payload

	var current_id = _get_current_character_id()
	if char_id == current_id and GameDataManager.profile:
		payload["display_name"] = display_name if display_name != "" else _get_current_character_display_name()
		payload["sprite_frames_path"] = GameDataManager.profile.sprite_frames_path
		payload["static_portrait"] = _get_current_static_portrait_path()
		payload["avatar"] = GameDataManager.profile.avatar
		payload["base_anim_scale_x"] = 0.8
		payload["base_anim_scale_y"] = 0.8
		var expression_texture = _load_current_expression_texture(expression)
		if expression_texture != null:
			payload["expression_texture"] = expression_texture
		return payload

	var char_data = _load_character_data(char_id)
	payload["display_name"] = display_name if display_name != "" else _resolve_character_name_from_data(char_id, char_data)
	payload["sprite_frames_path"] = str(char_data.get("sprite_frames_path", "")).strip_edges()
	payload["static_portrait"] = str(char_data.get("static_portrait", char_data.get("avatar", ""))).strip_edges()
	payload["avatar"] = str(char_data.get("avatar", "")).strip_edges()
	payload["is_avatar_fallback"] = str(payload["static_portrait"]).find("/avatar/") != -1
	return payload

func _load_character_data(char_id: String) -> Dictionary:
	if _character_cache.has(char_id):
		return _character_cache[char_id]

	var candidate_paths = [
		"res://assets/data/characters/%s.json" % char_id,
		"res://assets/data/characters/npc/%s.json" % char_id
	]
	for path in candidate_paths:
		if not ResourceLoader.exists(path):
			continue
		var file = FileAccess.open(path, FileAccess.READ)
		if file == null:
			continue
		var json = JSON.new()
		var parse_result = json.parse(file.get_as_text())
		file.close()
		if parse_result == OK and json.data is Dictionary:
			_character_cache[char_id] = json.data
			return json.data

	_character_cache[char_id] = {}
	return {}

func _resolve_character_name_from_data(char_id: String, char_data: Dictionary) -> String:
	var char_name = str(char_data.get("char_name", "")).strip_edges()
	if char_name != "":
		return _beautify_character_name(char_name)
	if typeof(MapDataManager) != TYPE_NIL:
		var npc_data = MapDataManager.get_npc_data(char_id)
		var npc_name = str(npc_data.get("name", "")).strip_edges()
		if npc_name != "":
			return npc_name
	return _beautify_character_name(char_id)

func _load_current_expression_texture(expression_override: String = "") -> Texture2D:
	if GameDataManager.profile == null or GameDataManager.expression_system == null:
		return null
	var expression = expression_override.strip_edges()
	if expression == "":
		expression = str(GameDataManager.profile.current_expression).strip_edges()
	if expression == "":
		return null
	var sprite_path = GameDataManager.expression_system.get_expression_sprite_path(expression)
	if sprite_path == "":
		return null
	if sprite_path.begins_with("user://"):
		var image = Image.new()
		var err = image.load(sprite_path)
		if err == OK:
			return ImageTexture.create_from_image(image)
		return null
	if ResourceLoader.exists(sprite_path):
		var tex = load(sprite_path)
		if tex is Texture2D:
			return tex
	return null

func _get_current_character_id() -> String:
	if GameDataManager.config == null:
		return ""
	return str(GameDataManager.config.current_character_id).strip_edges().to_lower()

func _get_current_character_display_name() -> String:
	if GameDataManager.profile == null:
		return ""
	return _beautify_character_name(str(GameDataManager.profile.char_name).strip_edges())

func _get_current_static_portrait_path() -> String:
	var current_id = _get_current_character_id()
	if current_id == "":
		return ""
	var char_data = _load_character_data(current_id)
	var portrait_path = str(char_data.get("static_portrait", char_data.get("avatar", ""))).strip_edges()
	if portrait_path != "":
		return portrait_path
	if GameDataManager.profile:
		return str(GameDataManager.profile.avatar).strip_edges()
	return ""

func _normalize_story_speaker_id(raw_speaker_id: String) -> String:
	var speaker = raw_speaker_id.strip_edges().to_lower()
	if speaker == "" or speaker == "旁白" or speaker == "player" or speaker == "我":
		return ""
	if speaker == "char":
		return _get_current_character_id()
	return speaker

func _ensure_story_actor_state(char_id: String) -> Dictionary:
	if not _story_actor_state.has(char_id):
		_story_actor_state[char_id] = {
			"position": "",
			"expression": "",
			"display_name": "",
			"focus": null
		}
	return _story_actor_state[char_id]

func _normalize_position_key(position: String) -> String:
	return position.strip_edges().to_lower()

func _remove_nearest_position(positions: Array, target: Vector2) -> void:
	if positions.is_empty():
		return
	var nearest_index := 0
	var nearest_distance := INF
	for index in range(positions.size()):
		var candidate = positions[index] as Vector2
		var distance = candidate.distance_squared_to(target)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_index = index
	positions.remove_at(nearest_index)

func _resolve_actor_focus(actor_id: String, active_char_id: String) -> bool:
	var state = _story_actor_state.get(actor_id, {})
	if state.has("focus") and state["focus"] != null:
		return bool(state["focus"])
	return actor_id == active_char_id and active_char_id != ""

func _beautify_character_name(name: String) -> String:
	if name == "":
		return ""
	if name == name.to_lower():
		return name.capitalize()
	return name
