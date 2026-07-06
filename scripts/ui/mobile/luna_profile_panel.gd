extends Control

signal back_requested

const FALLBACK_CHARACTER_ID := "luna"
const PANEL_MIN_SIZE := Vector2(1280, 720)
const BREATH_CYCLE_SECONDS := 4.8
const BREATH_INHALE_RATIO := 0.38

@onready var background_panel: Panel = $Background
@onready var panel_root: PanelContainer = $CenterContainer/PanelRoot
@onready var root_canvas: Control = $CenterContainer/PanelRoot/RootCanvas
@onready var back_btn: Button = $CenterContainer/PanelRoot/RootCanvas/CloseButton
@onready var title_label: Label = get_node_or_null("CenterContainer/PanelRoot/RootCanvas/HeaderPanel/Margin/TopBar/Title") as Label
@onready var hero_stage: Control = $CenterContainer/PanelRoot/RootCanvas/BodyCanvas/HeroStage
@onready var strip_portrait: TextureRect = $CenterContainer/PanelRoot/RootCanvas/BodyCanvas/PortraitStripCard/StripPortrait
@onready var static_portrait: TextureRect = $CenterContainer/PanelRoot/RootCanvas/BodyCanvas/HeroStage/StaticPortrait
@onready var animated_sprite: AnimatedSprite2D = $CenterContainer/PanelRoot/RootCanvas/BodyCanvas/HeroStage/AnimatedSprite
@onready var name_label: Label = $CenterContainer/PanelRoot/RootCanvas/BodyCanvas/InfoColumn/ContainerMargin/InfoScroll/InfoContainer/NameLabel
@onready var intro_label: Label = $CenterContainer/PanelRoot/RootCanvas/BodyCanvas/InfoColumn/ContainerMargin/InfoScroll/InfoContainer/IntroLabel
@onready var age_value_label: Label = $CenterContainer/PanelRoot/RootCanvas/BodyCanvas/InfoColumn/ContainerMargin/InfoScroll/InfoContainer/MetaVBox/AgeRow/HBox/Value
@onready var birthday_value_label: Label = $CenterContainer/PanelRoot/RootCanvas/BodyCanvas/InfoColumn/ContainerMargin/InfoScroll/InfoContainer/MetaVBox/BirthdayRow/HBox/Value
@onready var zodiac_value_label: Label = $CenterContainer/PanelRoot/RootCanvas/BodyCanvas/InfoColumn/ContainerMargin/InfoScroll/InfoContainer/MetaVBox/ZodiacRow/HBox/Value
@onready var description_label: Label = get_node_or_null("CenterContainer/PanelRoot/RootCanvas/BodyCanvas/InfoColumn/ContainerMargin/InfoScroll/InfoContainer/DescriptionCard/DescriptionMargin/DescriptionBody") as Label
@onready var info_scroll: ScrollContainer = $CenterContainer/PanelRoot/RootCanvas/BodyCanvas/InfoColumn/ContainerMargin/InfoScroll
@onready var scroll_fade_top: ColorRect = $CenterContainer/PanelRoot/RootCanvas/BodyCanvas/InfoColumn/ScrollFadeOverlay/FadeTop
@onready var scroll_fade_bottom: ColorRect = $CenterContainer/PanelRoot/RootCanvas/BodyCanvas/InfoColumn/ScrollFadeOverlay/FadeBottom

var _panel_tween: Tween = null
var _current_frames: SpriteFrames = null
var _current_animation: StringName = &""
var _breath_time: float = 0.0
var _animated_sprite_base_position: Vector2 = Vector2.ZERO
var _animated_sprite_base_scale: Vector2 = Vector2.ONE
var _static_portrait_base_position: Vector2 = Vector2.ZERO
var _static_portrait_base_scale: Vector2 = Vector2.ONE


func _ready() -> void:
	hide()
	if title_label != null:
		title_label.text = "Luna 档案"
	back_btn.pressed.connect(_on_back_pressed)
	background_panel.gui_input.connect(_on_background_gui_input)
	resized.connect(_on_panel_resized)
	hero_stage.resized.connect(_refresh_character_stage)
	_setup_info_scroll_visuals()
	set_process(true)


func show_panel() -> void:
	_apply_character_data(_load_character_data())
	_update_popup_layout()
	show()
	background_panel.modulate.a = 0.0
	panel_root.modulate.a = 0.0
	panel_root.scale = Vector2(0.97, 0.97)
	_kill_panel_tween()
	_panel_tween = create_tween()
	_panel_tween.set_parallel(true)
	_panel_tween.tween_property(background_panel, "modulate:a", 1.0, 0.18)
	_panel_tween.tween_property(panel_root, "modulate:a", 1.0, 0.22)
	_panel_tween.tween_property(panel_root, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func hide_panel() -> void:
	_kill_panel_tween()
	_stop_breath_animation(false)
	_panel_tween = create_tween()
	_panel_tween.set_parallel(true)
	_panel_tween.tween_property(background_panel, "modulate:a", 0.0, 0.15)
	_panel_tween.tween_property(panel_root, "modulate:a", 0.0, 0.15)
	_panel_tween.tween_property(panel_root, "scale", Vector2(0.97, 0.97), 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_panel_tween.set_parallel(false)
	_panel_tween.tween_callback(hide)


func _on_back_pressed() -> void:
	hide_panel()
	back_requested.emit()


func _on_background_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		hide_panel()


func _on_panel_resized() -> void:
	_update_popup_layout()
	_refresh_character_stage()


func _update_popup_layout() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var target_size: Vector2 = viewport_size
	if target_size.x < PANEL_MIN_SIZE.x or target_size.y < PANEL_MIN_SIZE.y:
		target_size.x = maxf(target_size.x, PANEL_MIN_SIZE.x)
		target_size.y = maxf(target_size.y, PANEL_MIN_SIZE.y)
	panel_root.custom_minimum_size = target_size
	panel_root.size = target_size
	panel_root.pivot_offset = target_size * 0.5
	root_canvas.custom_minimum_size = target_size
	root_canvas.size = target_size
	hero_stage.pivot_offset = hero_stage.size * 0.5
	_update_scroll_fades()


func _kill_panel_tween() -> void:
	if _panel_tween != null:
		_panel_tween.kill()
		_panel_tween = null


func _stop_breath_animation(reset_transform: bool = true) -> void:
	if reset_transform:
		if animated_sprite != null:
			animated_sprite.position = _animated_sprite_base_position
			animated_sprite.scale = _animated_sprite_base_scale
		if static_portrait != null:
			static_portrait.position = _static_portrait_base_position
			static_portrait.scale = _static_portrait_base_scale


func _restart_breath_animation() -> void:
	_stop_breath_animation(false)
	if animated_sprite.visible:
		_animated_sprite_base_position = animated_sprite.position
		_animated_sprite_base_scale = animated_sprite.scale
	elif static_portrait.visible:
		_static_portrait_base_position = static_portrait.position
		_static_portrait_base_scale = static_portrait.scale
	else:
		return
	_breath_time = 0.0


func _get_character_id() -> String:
	if GameDataManager.config:
		var current_id = str(GameDataManager.config.current_character_id).strip_edges()
		if current_id != "":
			return current_id
	return FALLBACK_CHARACTER_ID


func _load_character_data() -> Dictionary:
	var char_id = _get_character_id()
	var candidates = [
		"res://assets/data/characters/%s.json" % char_id,
		"res://assets/data/characters/npc/%s.json" % char_id,
		"res://assets/data/characters/%s.json" % FALLBACK_CHARACTER_ID
	]
	for path in candidates:
		if not FileAccess.file_exists(path):
			continue
		var file = FileAccess.open(path, FileAccess.READ)
		if file == null:
			continue
		var json = JSON.new()
		var result = json.parse(file.get_as_text())
		file.close()
		if result == OK and json.data is Dictionary:
			return json.data
	return {}


func _apply_character_data(char_data: Dictionary) -> void:
	var display_name = _beautify_character_name(str(char_data.get("display_name", char_data.get("char_name", FALLBACK_CHARACTER_ID))))
	var one_line_intro = str(char_data.get("one_line_intro", "")).strip_edges()
	var identity_background = str(char_data.get("identity_background", "")).strip_edges()
	var age_text = _format_age_text(char_data.get("age", "待补充"))
	var birthday_text = _format_text_value(char_data.get("birthday", "待补充"))
	var zodiac_text = _format_text_value(char_data.get("zodiac", "待补充"))

	if one_line_intro == "":
		one_line_intro = "安静温柔又有点慢热，熟悉之后会把最柔软的依赖与真心都交给你。"
	if identity_background == "":
		identity_background = one_line_intro

	if title_label != null:
		title_label.text = "%s 档案" % display_name

	name_label.text = display_name
	intro_label.text = one_line_intro
	age_value_label.text = age_text
	birthday_value_label.text = birthday_text
	zodiac_value_label.text = zodiac_text
	if description_label != null:
		description_label.text = identity_background

	_apply_visual_resources(char_data)


func _apply_visual_resources(char_data: Dictionary) -> void:
	var strip_path = str(char_data.get("static_portrait", char_data.get("avatar", ""))).strip_edges()
	var fallback_path = str(char_data.get("avatar", strip_path)).strip_edges()
	var sprite_frames_path = str(char_data.get("sprite_frames_path", "")).strip_edges()

	_apply_texture_to_rect(strip_portrait, strip_path if strip_path != "" else fallback_path)
	_apply_texture_to_rect(static_portrait, strip_path if strip_path != "" else fallback_path)

	_stop_breath_animation(false)
	_current_frames = null
	_current_animation = &""
	animated_sprite.stop()
	animated_sprite.hide()
	static_portrait.show()

	if sprite_frames_path != "" and ResourceLoader.exists(sprite_frames_path):
		var frames_res = load(sprite_frames_path)
		if frames_res is SpriteFrames:
			_current_frames = frames_res
			animated_sprite.sprite_frames = frames_res
			_current_animation = _pick_animation_name(frames_res)
			if _current_animation != &"":
				animated_sprite.play(_current_animation)
			animated_sprite.show()
			static_portrait.hide()
			_refresh_character_stage()
			return
	_restart_breath_animation()


func _apply_texture_to_rect(target: TextureRect, path: String) -> void:
	if target == null:
		return
	if path != "" and ResourceLoader.exists(path):
		var tex = load(path)
		if tex is Texture2D:
			target.texture = tex
			return
	target.texture = null


func _refresh_character_stage() -> void:
	if animated_sprite == null or not animated_sprite.visible or _current_frames == null:
		_stop_breath_animation(false)
		return
	var stage_size = hero_stage.size
	if stage_size.x <= 0.0 or stage_size.y <= 0.0 or _current_animation == &"":
		return

	var tex: Texture2D = _current_frames.get_frame_texture(_current_animation, 0)
	if tex == null:
		return

	var target_height: float = minf(stage_size.y * 0.96, 680.0)
	var source_height: float = maxf(tex.get_size().y, 1.0)
	var scale_ratio: float = clampf(target_height / source_height, 0.62, 1.08)
	animated_sprite.scale = Vector2.ONE * scale_ratio
	_animated_sprite_base_position = animated_sprite.position
	_animated_sprite_base_scale = animated_sprite.scale
	_restart_breath_animation()


func _process(delta: float) -> void:
	if not visible:
		return
	_breath_time += delta
	var breath_amount: float = _sample_breath_amount(_breath_time)
	var sway_amount: float = sin((_breath_time / BREATH_CYCLE_SECONDS) * PI + 0.35)
	if animated_sprite.visible:
		animated_sprite.position = _animated_sprite_base_position + Vector2(
			sway_amount * 0.8,
			lerpf(0.0, -5.5, breath_amount)
		)
		animated_sprite.scale = _animated_sprite_base_scale * lerpf(1.0, 1.018, breath_amount)
	elif static_portrait.visible:
		static_portrait.position = _static_portrait_base_position + Vector2(
			sway_amount * 0.6,
			lerpf(0.0, -4.2, breath_amount)
		)
		static_portrait.scale = _static_portrait_base_scale * lerpf(1.0, 1.014, breath_amount)


func _sample_breath_amount(time_seconds: float) -> float:
	var cycle_position: float = fposmod(time_seconds, BREATH_CYCLE_SECONDS) / BREATH_CYCLE_SECONDS
	var raw_amount: float = 0.0
	if cycle_position <= BREATH_INHALE_RATIO:
		raw_amount = cycle_position / BREATH_INHALE_RATIO
	else:
		raw_amount = 1.0 - ((cycle_position - BREATH_INHALE_RATIO) / (1.0 - BREATH_INHALE_RATIO))
	raw_amount = clampf(raw_amount, 0.0, 1.0)
	return raw_amount * raw_amount * (3.0 - 2.0 * raw_amount)


func _setup_info_scroll_visuals() -> void:
	if info_scroll == null:
		return
	info_scroll.clip_contents = true
	var v_scroll_bar: VScrollBar = info_scroll.get_v_scroll_bar()
	if v_scroll_bar != null:
		v_scroll_bar.visible = false
		v_scroll_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v_scroll_bar.value_changed.connect(_on_info_scroll_value_changed)
	var h_scroll_bar: HScrollBar = info_scroll.get_h_scroll_bar()
	if h_scroll_bar != null:
		h_scroll_bar.visible = false
		h_scroll_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_update_scroll_fades()


func _on_info_scroll_value_changed(_value: float) -> void:
	_update_scroll_fades()


func _update_scroll_fades() -> void:
	if info_scroll == null:
		return
	var v_scroll_bar: VScrollBar = info_scroll.get_v_scroll_bar()
	if v_scroll_bar == null:
		if scroll_fade_top != null:
			scroll_fade_top.modulate.a = 0.0
		if scroll_fade_bottom != null:
			scroll_fade_bottom.modulate.a = 0.0
		return
	var max_value: float = maxf(v_scroll_bar.max_value, 0.0)
	var current_value: float = v_scroll_bar.value
	var has_scroll: bool = max_value > 0.5
	if scroll_fade_top != null:
		scroll_fade_top.modulate.a = 1.0 if has_scroll and current_value > 1.0 else 0.0
	if scroll_fade_bottom != null:
		scroll_fade_bottom.modulate.a = 1.0 if has_scroll and current_value < max_value - 1.0 else 0.0


func _pick_animation_name(frames_res: SpriteFrames) -> StringName:
	for candidate in ["default", "idle", "calm"]:
		if frames_res.has_animation(candidate):
			return StringName(candidate)
	var names = frames_res.get_animation_names()
	if names.size() > 0:
		return StringName(names[0])
	return &""


func _beautify_character_name(name_text: String) -> String:
	var clean_name = name_text.strip_edges()
	if clean_name == "":
		return "Luna"
	if clean_name == clean_name.to_lower():
		return clean_name.capitalize()
	return clean_name


func _format_age_text(raw_value) -> String:
	var text_value = str(raw_value).strip_edges()
	if text_value == "":
		return "待补充"
	if text_value.is_valid_int():
		return "%s 岁" % text_value
	return text_value


func _format_text_value(raw_value) -> String:
	var text_value = str(raw_value).strip_edges()
	return text_value if text_value != "" else "待补充"
