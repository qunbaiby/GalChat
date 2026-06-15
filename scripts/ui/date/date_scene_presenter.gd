class_name DateScenePresenter
extends Node

signal slot_clicked(period_id: String)
signal slots_swapped(source_period: String, target_period: String)

const SLOT_EMPTY_TEXT := "点击安排"
const SLOT_DISABLED_TEXT := "已经错过"
const SLOT_IDLE_SCALE := Vector2.ONE
const SLOT_HOVER_SCALE := Vector2(1.04, 1.04)
const SLOT_DRAG_SOURCE_SCALE := Vector2(1.08, 1.08)
const SLOT_DRAG_TARGET_SCALE := Vector2(1.12, 1.12)
const SLOT_IDLE_OFFSET_Y := 0.0
const SLOT_HOVER_OFFSET_Y := -4.0
const SLOT_DRAG_SOURCE_OFFSET_Y := -10.0
const SLOT_DRAG_TARGET_OFFSET_Y := -6.0
const SLOT_DRAG_SOURCE_ROTATION := -2.5
const SLOT_DRAG_TARGET_ROTATION := 1.2
const SLOT_DRAG_SOURCE_MODULATE := Color(1, 0.97, 0.99, 0.92)
const SLOT_DRAG_TARGET_MODULATE := Color(1, 0.95, 0.98, 1)
const SLOT_DRAG_TARGET_FROST_BASE := Color(1, 0.84, 0.92, 0.30)
const SLOT_DRAG_TARGET_FROST_PEAK := Color(1, 0.80, 0.90, 0.58)
const SLOT_DRAG_SOURCE_FROST := Color(1, 0.90, 0.95, 0.38)
const SLOT_DRAG_THRESHOLD := 12.0

var _scene_root: Control = null
var _portrait_texture: AnimatedSprite2D = null
var _heart_level: Label = null
var _resonance_bar: ProgressBar = null
var _resonance_text: Label = null
var _slot_buttons: Dictionary = {}
var _slot_state_snapshot: Dictionary = {}
var _drag_source_period: String = ""
var _drag_target_period: String = ""
var _drag_start_mouse: Vector2 = Vector2.ZERO
var _drag_active: bool = false


func setup(scene_root: Control, nodes: Dictionary, character_profile: Dictionary) -> void:
	_scene_root = scene_root
	_portrait_texture = nodes.get("portrait_texture", null) as AnimatedSprite2D
	_heart_level = nodes.get("heart_level", null) as Label
	_resonance_bar = nodes.get("resonance_bar", null) as ProgressBar
	_resonance_text = nodes.get("resonance_text", null) as Label
	_slot_buttons = nodes.get("slot_buttons", {}).duplicate(false)
	for period_id in _slot_buttons.keys():
		var btn: Button = _slot_buttons[period_id]
		btn.pivot_offset = btn.size * 0.5
		if not btn.pressed.is_connected(_on_slot_pressed.bind(period_id)):
			btn.pressed.connect(_on_slot_pressed.bind(period_id))
		if not btn.mouse_entered.is_connected(_on_slot_mouse_entered.bind(period_id)):
			btn.mouse_entered.connect(_on_slot_mouse_entered.bind(period_id))
		if not btn.mouse_exited.is_connected(_on_slot_mouse_exited.bind(period_id)):
			btn.mouse_exited.connect(_on_slot_mouse_exited.bind(period_id))
		if not btn.gui_input.is_connected(_on_slot_gui_input.bind(period_id)):
			btn.gui_input.connect(_on_slot_gui_input.bind(period_id))
	load_portrait(character_profile)
	set_process_input(true)


func load_portrait(character_profile: Dictionary) -> void:
	if _portrait_texture == null:
		return
	var sprite_frames_path: String = str(character_profile.get("portrait_sprite_frames_path", "")).strip_edges()
	if sprite_frames_path == "" and GameDataManager.profile:
		sprite_frames_path = str(GameDataManager.profile.sprite_frames_path).strip_edges()
	if sprite_frames_path == "" or not ResourceLoader.exists(sprite_frames_path):
		return
	var frames_res: Resource = load(sprite_frames_path)
	if not (frames_res is SpriteFrames):
		return
	_portrait_texture.sprite_frames = frames_res
	var anim_name: String = ""
	for candidate in ["default", "idle", "calm"]:
		if frames_res.has_animation(candidate):
			anim_name = candidate
			break
	if anim_name == "" and frames_res.get_animation_names().size() > 0:
		anim_name = frames_res.get_animation_names()[0]
	if anim_name != "":
		_portrait_texture.play(StringName(anim_name))
	_portrait_texture.show()


func refresh_profile_summary(profile) -> void:
	if profile == null:
		return
	var current_stage: int = int(profile.current_stage)
	var current_resonance: float = float(profile.intimacy) + float(profile.trust)
	var stage_conf: Dictionary = profile.get_current_stage_config()
	var max_resonance: float = float(stage_conf.get("resonance_threshold", 100))
	if _heart_level:
		_heart_level.text = "LV\n%d" % current_stage
	if _resonance_bar:
		_resonance_bar.max_value = max_resonance
		_resonance_bar.value = current_resonance
	if _resonance_text:
		_resonance_text.text = "%d / %d" % [int(current_resonance), int(max_resonance)]


func refresh_all_slots(slot_state: Dictionary) -> void:
	_slot_state_snapshot = slot_state.duplicate(true)
	for period_id in _slot_buttons.keys():
		refresh_slot(period_id, _slot_state_snapshot.get(period_id, {}))


func refresh_slot(period_id: String, slot_data: Dictionary) -> void:
	if not _slot_buttons.has(period_id):
		return
	_slot_state_snapshot[period_id] = slot_data.duplicate(true)
	var btn: Button = _slot_buttons[period_id]
	_clear_drag_visual_tweens(btn)
	var thumb: TextureRect = btn.get_node("ThumbRect") as TextureRect
	var frost: CanvasItem = btn.get_node("FrostOverlay") as CanvasItem
	var heart: Label = btn.get_node("%HeartDecor") as Label
	var label: Label = btn.get_node("%SlotLabel") as Label
	var period_label: Label = btn.get_node("%PeriodLabel") as Label
	var enabled: bool = bool(slot_data.get("enabled", true))
	var location_id: String = str(slot_data.get("location_id", "")).strip_edges()
	var display_name: String = str(slot_data.get("location_name", "")).strip_edges()
	var texture: Texture2D = _resolve_slot_texture(slot_data)
	btn.z_index = 0
	btn.rotation_degrees = 0.0
	btn.scale = SLOT_IDLE_SCALE
	btn.position.y = SLOT_IDLE_OFFSET_Y
	btn.disabled = not enabled
	btn.modulate = Color(1, 1, 1, 0.85) if not enabled else Color(1, 1, 1, 1)
	if thumb:
		thumb.texture = texture
		thumb.modulate = Color(1, 1, 1, 1) if texture else Color(1, 1, 1, 0)
	if location_id == "":
		if frost:
			frost.hide()
		if heart:
			heart.show()
			heart.modulate = Color(1, 1, 1, 0.72 if enabled else 0.42)
		if label:
			label.show()
			label.text = SLOT_EMPTY_TEXT if enabled else SLOT_DISABLED_TEXT
			label.add_theme_color_override("font_color", Color(0.62, 0.42, 0.5, 1) if enabled else Color(0.62, 0.56, 0.6, 0.92))
			label.remove_theme_color_override("font_shadow_color")
			label.remove_theme_constant_override("shadow_outline_size")
		if period_label:
			period_label.add_theme_color_override("font_color", Color(0.58, 0.47, 0.54, 0.96) if enabled else Color(0.58, 0.52, 0.56, 0.78))
			period_label.remove_theme_color_override("font_shadow_color")
			period_label.remove_theme_constant_override("shadow_outline_size")
		return
	if heart:
		heart.hide()
	if frost:
		frost.visible = texture != null
	if label:
		if texture:
			label.hide()
		else:
			label.show()
			label.text = display_name if display_name != "" else "已选地点"
			label.add_theme_color_override("font_color", Color(0.35, 0.28, 0.32, 1))
			label.remove_theme_color_override("font_shadow_color")
			label.remove_theme_constant_override("shadow_outline_size")
	if period_label:
		period_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.94) if texture else Color(0.58, 0.47, 0.54, 0.96))
		if texture:
			period_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
			period_label.add_theme_constant_override("shadow_outline_size", 3)
		else:
			period_label.remove_theme_color_override("font_shadow_color")
			period_label.remove_theme_constant_override("shadow_outline_size")


func _resolve_slot_texture(slot_data: Dictionary) -> Texture2D:
	var custom_image_path: String = str(slot_data.get("custom_image_path", "")).strip_edges()
	if custom_image_path != "" and FileAccess.file_exists(custom_image_path):
		var image := Image.new()
		if image.load(custom_image_path) == OK:
			return ImageTexture.create_from_image(image)
	var location_id: String = str(slot_data.get("location_id", "")).strip_edges()
	if location_id == "" or location_id == "custom_location":
		return null
	var loc_data := MapDataManager.get_location(location_id)
	var bg_id: String = str(loc_data.get("bg_id", "")).strip_edges()
	var real_path: String = ""
	if bg_id != "":
		real_path = ImageManager.get_image_path(bg_id)
		if real_path.is_empty():
			real_path = bg_id
	if real_path != "" and ResourceLoader.exists(real_path):
		return load(real_path) as Texture2D
	return null


func _on_slot_pressed(period_id: String) -> void:
	if _drag_active:
		return
	slot_clicked.emit(period_id)


func _on_slot_mouse_entered(period_id: String) -> void:
	if not _slot_buttons.has(period_id):
		return
	var btn: Button = _slot_buttons[period_id]
	if btn.disabled:
		return
	if _drag_active:
		_set_drag_target(period_id)
		return
	_animate_slot_hover(btn, true)
	var heart: Label = btn.get_node("%HeartDecor") as Label
	if heart and heart.visible:
		heart.modulate = Color(1, 1, 1, 0.95)


func _on_slot_mouse_exited(period_id: String) -> void:
	if not _slot_buttons.has(period_id):
		return
	var btn: Button = _slot_buttons[period_id]
	if _drag_active:
		if _drag_target_period == period_id:
			_set_drag_target("")
		return
	_animate_slot_hover(btn, false)
	var heart: Label = btn.get_node("%HeartDecor") as Label
	if heart and heart.visible:
		heart.modulate = Color(1, 1, 1, 0.72)


func _on_slot_gui_input(period_id: String, event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
		var slot_data: Dictionary = _slot_state_snapshot.get(period_id, {})
		if str(slot_data.get("location_id", "")).strip_edges() == "":
			return
		if not bool(slot_data.get("enabled", true)):
			return
		_drag_source_period = period_id
		_drag_target_period = ""
		_drag_start_mouse = mouse_event.global_position
		_drag_active = false


func _input(event: InputEvent) -> void:
	if _drag_source_period == "":
		return
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if not _drag_active and motion.global_position.distance_to(_drag_start_mouse) >= SLOT_DRAG_THRESHOLD:
			_drag_active = true
			_apply_drag_source_state(true)
		if _drag_active:
			_set_drag_target(_find_period_at_position(motion.global_position))
	elif event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and not mouse_event.pressed:
			var final_target: String = _drag_target_period
			var final_source: String = _drag_source_period
			var was_drag_active: bool = _drag_active
			_reset_drag_state()
			if was_drag_active and final_target != "" and final_target != final_source:
				slots_swapped.emit(final_source, final_target)


func _find_period_at_position(global_pos: Vector2) -> String:
	for period_id in _slot_buttons.keys():
		var btn: Button = _slot_buttons[period_id]
		if btn.disabled:
			continue
		if period_id == _drag_source_period:
			continue
		if btn.get_global_rect().has_point(global_pos):
			return period_id
	return ""


func _set_drag_target(period_id: String) -> void:
	if _drag_target_period == period_id:
		return
	if _drag_target_period != "" and _slot_buttons.has(_drag_target_period):
		_apply_drag_target_state(_drag_target_period, false)
	_drag_target_period = period_id
	if _drag_target_period != "" and _slot_buttons.has(_drag_target_period):
		_apply_drag_target_state(_drag_target_period, true)


func _apply_drag_source_state(active: bool) -> void:
	if _drag_source_period == "" or not _slot_buttons.has(_drag_source_period):
		return
	var btn: Button = _slot_buttons[_drag_source_period]
	var frost: CanvasItem = btn.get_node("FrostOverlay") as CanvasItem
	_clear_drag_visual_tweens(btn)
	if not active:
		refresh_slot(_drag_source_period, _slot_state_snapshot.get(_drag_source_period, {}))
		return
	btn.z_index = 20
	if frost:
		frost.show()
		frost.modulate = SLOT_DRAG_SOURCE_FROST
	var tween: Tween = create_tween()
	btn.set_meta("drag_visual_tween", tween)
	tween.set_parallel(true)
	tween.tween_property(btn, "scale", SLOT_DRAG_SOURCE_SCALE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(btn, "position:y", SLOT_DRAG_SOURCE_OFFSET_Y, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(btn, "rotation_degrees", SLOT_DRAG_SOURCE_ROTATION, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(btn, "modulate", SLOT_DRAG_SOURCE_MODULATE, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _apply_drag_target_state(period_id: String, active: bool) -> void:
	if not _slot_buttons.has(period_id):
		return
	var btn: Button = _slot_buttons[period_id]
	var frost: CanvasItem = btn.get_node("FrostOverlay") as CanvasItem
	_clear_drag_visual_tweens(btn)
	if not active:
		refresh_slot(period_id, _slot_state_snapshot.get(period_id, {}))
		return
	btn.z_index = 15
	btn.modulate = SLOT_DRAG_TARGET_MODULATE
	if frost:
		frost.show()
		frost.modulate = SLOT_DRAG_TARGET_FROST_BASE
	var tween: Tween = create_tween()
	btn.set_meta("drag_visual_tween", tween)
	tween.set_parallel(true)
	tween.tween_property(btn, "scale", SLOT_DRAG_TARGET_SCALE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(btn, "position:y", SLOT_DRAG_TARGET_OFFSET_Y, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(btn, "rotation_degrees", SLOT_DRAG_TARGET_ROTATION, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if frost:
		var pulse: Tween = create_tween()
		btn.set_meta("drag_pulse_tween", pulse)
		pulse.set_loops()
		pulse.tween_property(frost, "modulate", SLOT_DRAG_TARGET_FROST_PEAK, 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		pulse.tween_property(frost, "modulate", SLOT_DRAG_TARGET_FROST_BASE, 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _reset_drag_state() -> void:
	if _drag_target_period != "" and _slot_buttons.has(_drag_target_period):
		_apply_drag_target_state(_drag_target_period, false)
	_drag_target_period = ""
	if _drag_source_period != "" and _slot_buttons.has(_drag_source_period):
		_apply_drag_source_state(false)
	_drag_source_period = ""
	_drag_active = false


func _animate_slot_hover(btn: Button, entering: bool) -> void:
	if _drag_active:
		return
	var hover_tween: Tween = btn.get_meta("hover_tween", null) as Tween
	if hover_tween:
		hover_tween.kill()
	var tween: Tween = create_tween()
	btn.set_meta("hover_tween", tween)
	tween.set_parallel(true)
	tween.tween_property(btn, "scale", SLOT_HOVER_SCALE if entering else SLOT_IDLE_SCALE, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(btn, "position:y", SLOT_HOVER_OFFSET_Y if entering else SLOT_IDLE_OFFSET_Y, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _clear_drag_visual_tweens(btn: Button) -> void:
	var drag_visual_tween: Tween = btn.get_meta("drag_visual_tween", null) as Tween
	if drag_visual_tween:
		drag_visual_tween.kill()
	var drag_pulse_tween: Tween = btn.get_meta("drag_pulse_tween", null) as Tween
	if drag_pulse_tween:
		drag_pulse_tween.kill()
