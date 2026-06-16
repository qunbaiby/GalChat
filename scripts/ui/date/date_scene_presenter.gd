class_name DateScenePresenter
extends Node

signal slot_clicked(period_id: String)

const SLOT_EMPTY_TEXT := "点击安排"
const SLOT_DISABLED_TEXT := "已经错过"

var _scene_root: Control = null
var _portrait_texture: AnimatedSprite2D = null
var _heart_level: Label = null
var _resonance_bar: ProgressBar = null
var _resonance_text: Label = null
var _slot_buttons: Dictionary = {}
var _slot_state_snapshot: Dictionary = {}


func setup(scene_root: Control, nodes: Dictionary, character_profile: Dictionary) -> void:
	_scene_root = scene_root
	_portrait_texture = nodes.get("portrait_texture", null) as AnimatedSprite2D
	_heart_level = nodes.get("heart_level", null) as Label
	_resonance_bar = nodes.get("resonance_bar", null) as ProgressBar
	_resonance_text = nodes.get("resonance_text", null) as Label
	_slot_buttons = nodes.get("slot_buttons", {}).duplicate(false)
	for period_id in _slot_buttons.keys():
		var btn: Button = _slot_buttons[period_id]
		if not btn.pressed.is_connected(_on_slot_pressed.bind(period_id)):
			btn.pressed.connect(_on_slot_pressed.bind(period_id))
	load_portrait(character_profile)


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
	var thumb: TextureRect = btn.get_node_or_null("ThumbRect") as TextureRect
	var frost: CanvasItem = btn.get_node_or_null("FrostOverlay") as CanvasItem
	var heart: Label = btn.find_child("HeartDecor", true, false) as Label
	var label: Label = btn.find_child("SlotLabel", true, false) as Label
	var period_label: Label = btn.find_child("PeriodLabel", true, false) as Label
	var enabled: bool = bool(slot_data.get("enabled", true))
	var location_id: String = str(slot_data.get("location_id", "")).strip_edges()
	var display_name: String = str(slot_data.get("location_name", "")).strip_edges()
	var texture: Texture2D = _resolve_slot_texture(slot_data)
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
			period_label.show()
			period_label.text = _get_period_text(period_id)
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
		period_label.visible = texture == null
		if texture:
			period_label.remove_theme_color_override("font_shadow_color")
			period_label.remove_theme_constant_override("shadow_outline_size")
		else:
			period_label.text = _get_period_text(period_id)
			period_label.add_theme_color_override("font_color", Color(0.58, 0.47, 0.54, 0.96))
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
	slot_clicked.emit(period_id)


func _get_period_text(period_id: String) -> String:
	match period_id:
		"morning":
			return "早上"
		"afternoon":
			return "下午"
		"evening":
			return "晚上"
	return period_id
