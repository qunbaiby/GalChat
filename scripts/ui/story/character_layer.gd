@tool
extends Node2D

const StoryPortraitActorScene = preload("res://scenes/ui/story/story_portrait_actor.tscn")

const MAX_VISIBLE_CAST := 4
const RETIRE_GRACE_TIME := 0.03
const EDITOR_PREVIEW_SPRITE_FRAMES_PATH := "res://assets/images/characters/Luna/luna.tres"
const EDITOR_PREVIEW_SIZE := Vector2(220.0, 620.0)
const EDITOR_PREVIEW_COLOR_AUTO := Color(0.38, 0.72, 1.0, 0.16)
const EDITOR_PREVIEW_COLOR_MANUAL := Color(1.0, 0.62, 0.34, 0.18)
const EDITOR_PREVIEW_OUTLINE_AUTO := Color(0.45, 0.78, 1.0, 0.9)
const EDITOR_PREVIEW_OUTLINE_MANUAL := Color(1.0, 0.72, 0.42, 0.95)
const EDITOR_PREVIEW_BASELINE_COLOR := Color(1.0, 1.0, 1.0, 0.32)
const DEFAULT_SLOT_POSITIONS := {
    "auto_1_center": Vector2(640, 780),
    "auto_2_left": Vector2(360, 780),
    "auto_2_right": Vector2(920, 780),
    "auto_3_left": Vector2(220, 780),
    "auto_3_center": Vector2(640, 780),
    "auto_3_right": Vector2(1060, 780),
    "auto_4_far_left": Vector2(150, 780),
    "auto_4_left_center": Vector2(430, 780),
    "auto_4_right_center": Vector2(850, 780),
    "auto_4_far_right": Vector2(1130, 780),
    "far_left": Vector2(150, 780),
    "left": Vector2(360, 780),
    "left_center": Vector2(430, 780),
    "center": Vector2(640, 780),
    "right_center": Vector2(850, 780),
    "right": Vector2(920, 780),
    "far_right": Vector2(1130, 780)
}
const SLOT_LAYOUT_KEYS := {
    1: ["auto_1_center"],
    2: ["auto_2_left", "auto_2_right"],
    3: ["auto_3_left", "auto_3_center", "auto_3_right"],
    4: ["auto_4_far_left", "auto_4_left_center", "auto_4_right_center", "auto_4_far_right"]
}

var _actor_pool: Array = []
var _story_cast_order: Array[String] = []
var _story_actor_map: Dictionary = {}
var _story_actor_state: Dictionary = {}
var _story_mode_enabled: bool = false
var _current_story_speaker_id: String = ""
var _last_story_speaker_id: String = ""
var _character_cache: Dictionary = {}
var _retiring_actors: Dictionary = {}
var _retiring_timers: Dictionary = {}

@onready var slot_markers: Node2D = $SlotMarkers

func _ready() -> void:
    _ensure_actor_pool()
    if Engine.is_editor_hint():
        if is_instance_valid(slot_markers):
            slot_markers.show()
        set_process(true)
        _refresh_editor_actor_previews()
        queue_redraw()
        return

    GameDataManager.character_switched.connect(_on_character_switched)
    _refresh_default_actor(true)

func _process(_delta: float) -> void:
    if Engine.is_editor_hint():
        _refresh_editor_actor_previews()
        queue_redraw()

func _draw() -> void:
    if not Engine.is_editor_hint() or not is_instance_valid(slot_markers):
        return

    for child in slot_markers.get_children():
        var marker := child as Node2D
        if marker == null:
            continue
        _draw_editor_preview(marker.name, marker.position)

func _on_character_switched(_char_id: String) -> void:
    if _story_mode_enabled:
        var current_id = _get_current_character_id()
        if current_id != "" and _story_actor_map.has(current_id):
            _configure_actor_from_state(current_id)
            _sync_story_cast(true)
    else:
        _refresh_default_actor(true)

func begin_story_mode() -> void:
    _story_mode_enabled = true
    _clear_story_runtime()

func end_story_mode() -> void:
    _story_mode_enabled = false
    _clear_story_runtime()

func focus_story_speaker(raw_speaker_id: String, display_name: String = "", mood: String = "", presentation: Dictionary = {}) -> void:
    if not _story_mode_enabled:
        begin_story_mode()

    var speaker_key = str(presentation.get("character", "")).strip_edges()
    if speaker_key == "":
        speaker_key = raw_speaker_id
    var speaker_id = _normalize_story_speaker_id(speaker_key)
    if speaker_id == "":
        # 经典 AVG 里旁白通常不改变当前舞台构图，只是不再强制切换焦点。
        _sync_story_cast(false)
        return

    var state = _ensure_story_actor_state(speaker_id)
    _apply_dialogue_presentation_to_state(state, display_name, mood, presentation)
    var actor = _ensure_story_actor(speaker_id)
    if actor == null:
        return

    _current_story_speaker_id = speaker_id
    _last_story_speaker_id = speaker_id
    _sync_story_cast(false)

func show_story_character(raw_char_id: String, display_name: String = "", presentation: Dictionary = {}) -> void:
    if not _story_mode_enabled:
        begin_story_mode()

    var char_id = _normalize_story_speaker_id(raw_char_id)
    if char_id == "":
        return

    var state = _ensure_story_actor_state(char_id)
    _apply_show_presentation_to_state(state, display_name, str(state.get("expression", "")), presentation)
    var was_visible: bool = false
    if _story_actor_map.has(char_id):
        var existing_actor = _story_actor_map[char_id]
        if existing_actor:
            was_visible = bool(existing_actor.visible)
    var actor = _ensure_story_actor(char_id)
    if actor == null:
        return

    if bool(presentation.get("enter", false)) or not was_visible:
        # 新角色需要先拿到正确槽位，再按槽位做淡入/滑入动画。
        _sync_story_cast(true)
        actor.show_actor(_resolve_enter_animation(presentation), false)
    if presentation.get("focus", null) == true:
        _current_story_speaker_id = char_id
        _last_story_speaker_id = char_id
    _sync_story_cast(false)

func move_story_character(raw_char_id: String, display_name: String = "", presentation: Dictionary = {}) -> void:
    if not _story_mode_enabled:
        begin_story_mode()

    var char_id = _normalize_story_speaker_id(raw_char_id)
    if char_id == "":
        return

    var actor = _story_actor_map.get(char_id, null)
    if actor == null or not actor.visible:
        push_warning("[CharacterLayer] move_story_character called for non-visible actor: %s" % char_id)
        return

    var state = _ensure_story_actor_state(char_id)
    _apply_move_presentation_to_state(state, display_name, str(state.get("expression", "")), presentation)
    if presentation.get("focus", null) == true:
        _current_story_speaker_id = char_id
        _last_story_speaker_id = char_id
    _sync_story_cast(false)

func hide_story_character(raw_char_id: String, animation: String = "fade_out") -> void:
    var char_id = _normalize_story_speaker_id(raw_char_id)
    if char_id == "":
        return

    var actor = _story_actor_map.get(char_id, null)
    _story_actor_map.erase(char_id)
    _story_actor_state.erase(char_id)
    _story_cast_order.erase(char_id)

    if actor:
        _retire_actor(actor, animation if animation != "" else "fade_out")

    if _current_story_speaker_id == char_id:
        _current_story_speaker_id = _pick_fallback_focus_id()
    if _last_story_speaker_id == char_id:
        _last_story_speaker_id = _pick_fallback_focus_id()
    _sync_story_cast(false)

func show_character(anim_type: String = "fade_in") -> void:
    show()
    if _story_mode_enabled and not _story_actor_map.is_empty():
        for actor in _story_actor_map.values():
            if actor and actor.has_method("show_actor"):
                actor.show_actor(anim_type, anim_type == "none")
        _sync_story_cast(true)
        return

    var actor = _get_default_actor()
    if actor == null:
        return
    _refresh_default_actor(false)
    actor.show_actor(anim_type, anim_type == "none")
    actor.apply_layout(_get_default_slot_position(), true, true)

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
    _clear_story_runtime()

    var default_actor = _get_default_actor()
    if default_actor == null:
        return

    var payload = _build_character_payload(_get_current_character_id(), _get_current_character_display_name())
    if path != "":
        payload["sprite_frames_path"] = path
        payload.erase("expression_texture")
    default_actor.configure_from_data(payload, "")
    default_actor.apply_layout(_get_default_slot_position(), true, true)

func update_sprite(new_texture: Texture2D) -> void:
    if new_texture == null:
        return

    if _story_mode_enabled:
        var story_target_id = _get_effective_focus_id()
        if story_target_id == "" and _story_actor_map.has(_get_current_character_id()):
            story_target_id = _get_current_character_id()
        if story_target_id != "" and _story_actor_map.has(story_target_id):
            var story_actor = _story_actor_map[story_target_id]
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
        default_actor.apply_layout(_get_default_slot_position(), true, true)
        if show_now:
            default_actor.show_actor("none", true)

func _clear_story_runtime() -> void:
    _current_story_speaker_id = ""
    _last_story_speaker_id = ""
    _story_cast_order.clear()
    _story_actor_map.clear()
    _story_actor_state.clear()
    _retiring_timers.clear()
    _retiring_actors.clear()
    for actor in _actor_pool:
        actor.clear_actor()

func _merge_common_actor_state(state: Dictionary, display_name: String, fallback_expression: String, presentation: Dictionary) -> void:
    if display_name != "":
        state["display_name"] = display_name

    var expression = str(presentation.get("expression", fallback_expression)).strip_edges()
    if expression != "":
        state["expression"] = expression

    var focus_override = presentation.get("focus", null)
    if focus_override == true:
        state["focus_override"] = true
    else:
        state["focus_override"] = null

func _apply_dialogue_presentation_to_state(state: Dictionary, display_name: String, fallback_expression: String, presentation: Dictionary) -> void:
    _merge_common_actor_state(state, display_name, fallback_expression, presentation)

func _apply_show_presentation_to_state(state: Dictionary, display_name: String, fallback_expression: String, presentation: Dictionary) -> void:
    _merge_common_actor_state(state, display_name, fallback_expression, presentation)
    var position_key = _normalize_position_key(str(presentation.get("position", "")))
    if position_key != "" and _has_slot_position(position_key):
        state["position"] = position_key

func _apply_move_presentation_to_state(state: Dictionary, display_name: String, fallback_expression: String, presentation: Dictionary) -> void:
    _merge_common_actor_state(state, display_name, fallback_expression, presentation)
    var position_key = _normalize_position_key(str(presentation.get("position", "")))
    if position_key != "" and _has_slot_position(position_key):
        state["position"] = position_key

func _ensure_story_actor(char_id: String):
    if _story_actor_map.has(char_id):
        _configure_actor_from_state(char_id)
        return _story_actor_map[char_id]

    var actor = _find_free_actor()
    if actor == null:
        _evict_story_actor(char_id)
        actor = _find_free_actor()
    if actor == null:
        return null

    var actor_id = actor.get_instance_id()
    if _retiring_actors.has(actor_id):
        _finish_retiring_actor(actor_id)

    _story_actor_map[char_id] = actor
    if not _story_cast_order.has(char_id):
        _story_cast_order.append(char_id)
    _configure_actor_from_state(char_id)
    return actor

func _configure_actor_from_state(char_id: String) -> void:
    var actor = _story_actor_map.get(char_id, null)
    var state = _story_actor_state.get(char_id, {})
    if actor == null or state.is_empty():
        return
    var display_name = str(state.get("display_name", "")).strip_edges()
    var expression = str(state.get("expression", "")).strip_edges()
    actor.configure_from_data(_build_character_payload(char_id, display_name, expression), expression)

func _find_free_actor():
    for actor in _actor_pool:
        var actor_id = actor.get_instance_id()
        if _retiring_actors.has(actor_id):
            continue
        if not _story_actor_map.values().has(actor):
            return actor
    return null

func _evict_story_actor(exclude_id: String) -> void:
    for actor_id in _story_cast_order:
        if actor_id == exclude_id or actor_id == _current_story_speaker_id:
            continue
        var actor = _story_actor_map.get(actor_id, null)
        _story_actor_map.erase(actor_id)
        _story_actor_state.erase(actor_id)
        _story_cast_order.erase(actor_id)
        if actor:
            actor.hide_actor("none", true)
            actor.clear_actor()
        return

func _sync_story_cast(instant: bool) -> void:
    var visible_ids: Array[String] = []
    for actor_id in _story_cast_order:
        if _story_actor_map.has(actor_id):
            visible_ids.append(actor_id)

    if visible_ids.is_empty():
        return

    var layout_size = min(visible_ids.size(), MAX_VISIBLE_CAST)
    var positions: Array = _get_layout_positions(layout_size)
    var remaining_positions: Array = positions.duplicate()
    var auto_ids: Array[String] = []
    var focus_target_id = _get_effective_focus_id()
    var has_explicit_focus = _has_explicit_focused_actor(visible_ids)

    for actor_id in visible_ids:
        var state = _story_actor_state.get(actor_id, {})
        var position_key = _normalize_position_key(str(state.get("position", "")))
        if _has_slot_position(position_key):
            var manual_position: Vector2 = _get_slot_position(position_key)
            var manual_actor = _story_actor_map.get(actor_id, null)
            if manual_actor:
                var is_focused = _resolve_actor_focus(actor_id, focus_target_id, has_explicit_focus)
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
        var is_focused = _resolve_actor_focus(actor_id, focus_target_id, has_explicit_focus)
        actor.apply_layout(target_position, is_focused, instant)

func _retire_actor(actor, animation: String) -> void:
    if actor == null:
        return

    var actor_id = actor.get_instance_id()
    _cancel_retire_timer(actor_id)
    _retiring_actors[actor_id] = actor
    actor.hide_actor(animation, animation == "none")
    if animation == "none":
        _finish_retiring_actor(actor_id)
        return

    var timer := get_tree().create_timer(StoryPortraitActor.HIDE_DURATION + RETIRE_GRACE_TIME)
    _retiring_timers[actor_id] = timer
    timer.timeout.connect(_on_retire_timeout.bind(actor_id), CONNECT_ONE_SHOT)

func _cancel_retire_timer(actor_id: int) -> void:
    if _retiring_timers.has(actor_id):
        _retiring_timers.erase(actor_id)

func _on_retire_timeout(actor_id: int) -> void:
    _finish_retiring_actor(actor_id)

func _finish_retiring_actor(actor_id: int) -> void:
    var actor = _retiring_actors.get(actor_id, null)
    if actor:
        actor.clear_actor()
    _retiring_actors.erase(actor_id)
    _retiring_timers.erase(actor_id)

func _pick_fallback_focus_id() -> String:
    if _last_story_speaker_id != "" and _story_actor_map.has(_last_story_speaker_id):
        return _last_story_speaker_id
    if _current_story_speaker_id != "" and _story_actor_map.has(_current_story_speaker_id):
        return _current_story_speaker_id
    if not _story_cast_order.is_empty():
        return _story_cast_order[_story_cast_order.size() - 1]
    return ""

func _get_effective_focus_id() -> String:
    if _current_story_speaker_id != "" and _story_actor_map.has(_current_story_speaker_id):
        return _current_story_speaker_id
    if _last_story_speaker_id != "" and _story_actor_map.has(_last_story_speaker_id):
        return _last_story_speaker_id
    return ""

func _has_explicit_focused_actor(visible_ids: Array[String]) -> bool:
    for actor_id in visible_ids:
        var state = _story_actor_state.get(actor_id, {})
        if state.get("focus_override", null) == true:
            return true
    return false

func _get_default_actor():
    if _actor_pool.is_empty():
        return null
    return _actor_pool[0]

func _ensure_actor_pool() -> void:
    if not _actor_pool.is_empty():
        return
    for index in range(MAX_VISIBLE_CAST):
        var existing_actor = get_node_or_null("StoryActor%d" % index)
        if existing_actor:
            _actor_pool.append(existing_actor)
    for index in range(MAX_VISIBLE_CAST):
        if index < _actor_pool.size():
            continue
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
            "focus_override": null
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

func _resolve_actor_focus(actor_id: String, active_char_id: String, has_explicit_focus: bool) -> bool:
    var state = _story_actor_state.get(actor_id, {})
    var focus_override = state.get("focus_override", null)
    if focus_override == true:
        return true
    if has_explicit_focus:
        return false
    return actor_id == active_char_id and active_char_id != ""

func _resolve_enter_animation(presentation: Dictionary) -> String:
    var animation = str(presentation.get("animation", "fade_in")).strip_edges()
    return animation if animation != "" else "fade_in"

func _beautify_character_name(name: String) -> String:
    if name == "":
        return ""
    if name == name.to_lower():
        return name.capitalize()
    return name

func _get_default_slot_position() -> Vector2:
    return _get_slot_position("auto_1_center")

func _get_layout_positions(layout_size: int) -> Array:
    var slot_keys: Array = SLOT_LAYOUT_KEYS.get(layout_size, SLOT_LAYOUT_KEYS[MAX_VISIBLE_CAST])
    var positions: Array = []
    for slot_key in slot_keys:
        positions.append(_get_slot_position(str(slot_key)))
    return positions

func _refresh_editor_actor_previews() -> void:
    if not Engine.is_editor_hint():
        return
    if _actor_pool.is_empty():
        return

    var preview_slots = _get_layout_positions(MAX_VISIBLE_CAST)
    for index in range(_actor_pool.size()):
        var actor = _actor_pool[index]
        if actor == null:
            continue
        var slot_position = preview_slots[min(index, preview_slots.size() - 1)] if not preview_slots.is_empty() else Vector2.ZERO
        var focused = index == 1
        if actor.has_method("show_editor_preview"):
            actor.show_editor_preview(EDITOR_PREVIEW_SPRITE_FRAMES_PATH, slot_position, focused)

func _has_slot_position(slot_key: String) -> bool:
    return DEFAULT_SLOT_POSITIONS.has(slot_key)

func _get_slot_position(slot_key: String) -> Vector2:
    if is_instance_valid(slot_markers):
        var marker := slot_markers.get_node_or_null(slot_key) as Node2D
        if marker:
            return marker.position
    return DEFAULT_SLOT_POSITIONS.get(slot_key, Vector2.ZERO)

func _draw_editor_preview(slot_name: String, slot_position: Vector2) -> void:
    var is_auto_slot := slot_name.begins_with("auto_")
    var fill_color := EDITOR_PREVIEW_COLOR_AUTO if is_auto_slot else EDITOR_PREVIEW_COLOR_MANUAL
    var outline_color := EDITOR_PREVIEW_OUTLINE_AUTO if is_auto_slot else EDITOR_PREVIEW_OUTLINE_MANUAL
    var rect := Rect2(
        Vector2(slot_position.x - EDITOR_PREVIEW_SIZE.x / 2.0, slot_position.y - EDITOR_PREVIEW_SIZE.y),
        EDITOR_PREVIEW_SIZE
    )
    draw_rect(rect, fill_color, true)
    draw_rect(rect, outline_color, false, 2.0)
    draw_line(
        Vector2(slot_position.x - EDITOR_PREVIEW_SIZE.x / 2.0, slot_position.y),
        Vector2(slot_position.x + EDITOR_PREVIEW_SIZE.x / 2.0, slot_position.y),
        EDITOR_PREVIEW_BASELINE_COLOR,
        2.0
    )
    draw_circle(slot_position, 6.0, outline_color)
