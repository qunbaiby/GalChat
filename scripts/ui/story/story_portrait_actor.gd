@tool
class_name StoryPortraitActor
extends Node2D

const DEFAULT_STATIC_LIMIT := Vector2(500.0, 750.0)
const AVATAR_STATIC_LIMIT := Vector2(350.0, 650.0)
const ACTIVE_SCALE_MULTIPLIER := 1.002
const INACTIVE_SCALE_MULTIPLIER := 0.99
const ACTIVE_MODULATE := Color(1, 1, 1, 1)
const INACTIVE_MODULATE := Color(0.42, 0.42, 0.48, 1)
const FOCUS_OFFSET_Y := -10.0
const SHOW_DURATION := 0.30
const HIDE_DURATION := 0.22
const LAYOUT_DURATION := 0.26
const SHOW_OFFSET_X := 28.0
const SHOW_OFFSET_Y := 16.0

var actor_id: String = ""
var actor_name: String = ""
var slot_position: Vector2 = Vector2.ZERO
var is_loaded: bool = false
var is_focused: bool = false
var _visibility_tween: Tween = null
var _layout_tween: Tween = null
var _default_anim_scale: Vector2 = Vector2.ONE

@onready var character_ani: AnimatedSprite2D = $CharacterAni
@onready var static_sprite: Sprite2D = $StaticSprite

func _ready() -> void:
	_default_anim_scale = character_ani.scale
	if Engine.is_editor_hint():
		modulate = Color(1, 1, 1, 1)
		scale = Vector2.ONE
		return
	hide()
	modulate = Color(1, 1, 1, 0)
	scale = Vector2.ONE

func configure_from_data(data: Dictionary, mood: String = "") -> bool:
	actor_id = str(data.get("char_id", "")).strip_edges()
	actor_name = str(data.get("display_name", "")).strip_edges()
	is_loaded = false
	character_ani.stop()
	character_ani.hide()
	static_sprite.hide()

	var expression_texture = data.get("expression_texture", null)
	if expression_texture is Texture2D:
		_show_static_texture(expression_texture, bool(data.get("is_avatar_fallback", false)))
		is_loaded = true
		return true

	var sprite_frames_path = str(data.get("sprite_frames_path", "")).strip_edges()
	if sprite_frames_path != "" and ResourceLoader.exists(sprite_frames_path):
		var frames_res = load(sprite_frames_path)
		if frames_res is SpriteFrames:
			character_ani.sprite_frames = frames_res
			var anim_name = _pick_animation_name(frames_res, mood)
			if anim_name != "":
				character_ani.play(StringName(anim_name))
			elif frames_res.get_animation_names().size() > 0:
				character_ani.play(StringName(str(frames_res.get_animation_names()[0])))
			var default_anim_scale := _default_anim_scale if _default_anim_scale != Vector2.ZERO else character_ani.scale
			character_ani.scale = Vector2(
				float(data.get("base_anim_scale_x", default_anim_scale.x)),
				float(data.get("base_anim_scale_y", default_anim_scale.y))
			)
			
			var h = 800.0
			var tex = frames_res.get_frame_texture(anim_name if anim_name != "" else str(frames_res.get_animation_names()[0]), 0)
			if tex:
				h = tex.get_size().y
			character_ani.position = Vector2(0, -h / 2.0 * character_ani.scale.y)
			
			character_ani.show()
			static_sprite.hide()
			is_loaded = true
			return true

	var static_path = str(data.get("static_portrait", "")).strip_edges()
	if static_path != "" and ResourceLoader.exists(static_path):
		var tex = load(static_path)
		if tex is Texture2D:
			_show_static_texture(tex, bool(data.get("is_avatar_fallback", false)))
			
			# 如果是从精灵帧降级到静态图，我们需要重置一下动画缩放比例，让它和静态图对齐
			scale = Vector2.ONE
			
			is_loaded = true
			return true

	clear_actor()
	return false

func update_texture(texture: Texture2D, treat_as_avatar: bool = false) -> void:
	if texture == null:
		return
	_show_static_texture(texture, treat_as_avatar)
	is_loaded = true

func show_actor(anim_type: String = "fade_in", instant: bool = false) -> void:
	if not is_loaded:
		return
	show()
	if _visibility_tween and _visibility_tween.is_valid():
		_visibility_tween.kill()

	if instant or anim_type == "none":
		modulate.a = 1.0
		position = _get_target_position()
		return

	var target_position = _get_target_position()
	match anim_type:
		"slide_left":
			position = target_position + Vector2(-SHOW_OFFSET_X, 0)
		"slide_right":
			position = target_position + Vector2(SHOW_OFFSET_X, 0)
		"slide_top":
			position = target_position + Vector2(0, -SHOW_OFFSET_Y)
		"slide_bottom":
			position = target_position + Vector2(0, SHOW_OFFSET_Y)
		_:
			position = target_position

	modulate.a = 0.0
	_visibility_tween = create_tween()
	_visibility_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_visibility_tween.parallel().tween_property(self, "position", target_position, SHOW_DURATION)
	_visibility_tween.parallel().tween_property(self, "modulate:a", 1.0, SHOW_DURATION)

func hide_actor(anim_type: String = "fade_out", instant: bool = false) -> void:
	if _visibility_tween and _visibility_tween.is_valid():
		_visibility_tween.kill()

	if instant or anim_type == "none":
		modulate.a = 0.0
		hide()
		return

	var target_position = position
	match anim_type:
		"slide_out_left":
			target_position += Vector2(-SHOW_OFFSET_X, 0)
		"slide_out_right":
			target_position += Vector2(SHOW_OFFSET_X, 0)
		"slide_out_top":
			target_position += Vector2(0, -SHOW_OFFSET_Y)
		"slide_out_bottom":
			target_position += Vector2(0, SHOW_OFFSET_Y)

	_visibility_tween = create_tween()
	_visibility_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_visibility_tween.parallel().tween_property(self, "position", target_position, HIDE_DURATION)
	_visibility_tween.parallel().tween_property(self, "modulate:a", 0.0, HIDE_DURATION)
	_visibility_tween.tween_callback(hide)

func apply_layout(target_slot_position: Vector2, focused: bool, instant: bool = false) -> void:
	slot_position = target_slot_position
	is_focused = focused
	var target_position = _get_target_position()
	var target_scale = Vector2.ONE * (ACTIVE_SCALE_MULTIPLIER if focused else INACTIVE_SCALE_MULTIPLIER)
	var target_modulate = ACTIVE_MODULATE if focused else INACTIVE_MODULATE
	z_index = 20 if focused else 5

	if _layout_tween and _layout_tween.is_valid():
		_layout_tween.kill()

	if instant:
		position = target_position
		scale = target_scale
		modulate = Color(target_modulate.r, target_modulate.g, target_modulate.b, modulate.a)
		return

	_layout_tween = create_tween()
	_layout_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_layout_tween.parallel().tween_property(self, "position", target_position, LAYOUT_DURATION)
	_layout_tween.parallel().tween_property(self, "scale", target_scale, LAYOUT_DURATION)
	_layout_tween.parallel().tween_property(self, "modulate:r", target_modulate.r, LAYOUT_DURATION)
	_layout_tween.parallel().tween_property(self, "modulate:g", target_modulate.g, LAYOUT_DURATION)
	_layout_tween.parallel().tween_property(self, "modulate:b", target_modulate.b, LAYOUT_DURATION)

func clear_actor() -> void:
	if _visibility_tween and _visibility_tween.is_valid():
		_visibility_tween.kill()
	if _layout_tween and _layout_tween.is_valid():
		_layout_tween.kill()
	_visibility_tween = null
	_layout_tween = null
	actor_id = ""
	actor_name = ""
	is_loaded = false
	is_focused = false
	character_ani.stop()
	character_ani.hide()
	character_ani.sprite_frames = null
	static_sprite.texture = null
	static_sprite.hide()
	position = slot_position
	scale = Vector2.ONE
	modulate = Color(1, 1, 1, 0)
	hide()

func show_editor_preview(sprite_frames_path: String, target_slot_position: Vector2, focused: bool) -> void:
	if not Engine.is_editor_hint():
		return

	slot_position = target_slot_position
	is_focused = focused
	_load_preview_sprite_frames(sprite_frames_path)
	position = _get_target_position()
	scale = Vector2.ONE * (ACTIVE_SCALE_MULTIPLIER if focused else INACTIVE_SCALE_MULTIPLIER)
	modulate = ACTIVE_MODULATE if focused else INACTIVE_MODULATE
	z_index = 20 if focused else 5
	show()

func clear_editor_preview() -> void:
	if not Engine.is_editor_hint():
		return
	character_ani.stop()
	character_ani.sprite_frames = null
	character_ani.hide()
	static_sprite.texture = null
	static_sprite.hide()
	hide()

func _show_static_texture(texture: Texture2D, treat_as_avatar: bool) -> void:
	static_sprite.texture = texture
	static_sprite.centered = true
	static_sprite.scale = _fit_texture_scale(texture, treat_as_avatar)
	
	# 动态计算高度偏移，使立绘底部对齐屏幕底部
	var tex_size = texture.get_size()
	if tex_size.y > 0:
		static_sprite.position = Vector2(0, -tex_size.y / 2.0 * static_sprite.scale.y)
	
	static_sprite.show()
	character_ani.stop()
	character_ani.hide()

func _fit_texture_scale(texture: Texture2D, treat_as_avatar: bool) -> Vector2:
	var size = texture.get_size()
	if size.x <= 0.0 or size.y <= 0.0:
		return Vector2.ONE
	var limit = AVATAR_STATIC_LIMIT if treat_as_avatar else DEFAULT_STATIC_LIMIT
	var scale_x = limit.x / size.x
	var scale_y = limit.y / size.y
	var final_scale = min(scale_x, scale_y)
	final_scale = clampf(final_scale, 0.1, 2.0)
	return Vector2(final_scale, final_scale)

func _pick_animation_name(frames_res: SpriteFrames, mood: String) -> String:
	var candidates = []
	if mood.strip_edges() != "":
		candidates.append(mood.strip_edges())
	candidates.append("default")
	candidates.append("defult")
	candidates.append("calm")
	candidates.append("idle")
	for candidate in candidates:
		if frames_res.has_animation(candidate):
			return candidate
	return ""

func _load_preview_sprite_frames(sprite_frames_path: String) -> void:
	character_ani.stop()
	character_ani.hide()
	static_sprite.hide()

	if sprite_frames_path == "" or not ResourceLoader.exists(sprite_frames_path):
		return

	var frames_res = load(sprite_frames_path)
	if not (frames_res is SpriteFrames):
		return

	character_ani.sprite_frames = frames_res
	var anim_name = _pick_animation_name(frames_res, "")
	if anim_name == "" and frames_res.get_animation_names().size() > 0:
		anim_name = str(frames_res.get_animation_names()[0])
	if anim_name == "":
		return

	character_ani.scale = _default_anim_scale if _default_anim_scale != Vector2.ZERO else character_ani.scale
	var tex = frames_res.get_frame_texture(anim_name, 0)
	var h = tex.get_size().y if tex else 800.0
	character_ani.position = Vector2(0, -h / 2.0 * character_ani.scale.y)
	character_ani.play(StringName(anim_name))
	character_ani.show()

func _get_target_position() -> Vector2:
	return slot_position + Vector2(0.0, FOCUS_OFFSET_Y if is_focused else 0.0)
