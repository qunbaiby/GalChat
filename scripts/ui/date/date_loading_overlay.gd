extends Control
class_name DateLoadingOverlay

const DATE_LOADING_MIN_DURATION := 1.4
const DATE_LOADING_PROGRESS_DURATION := 4.6
const DATE_LOADING_PROGRESS_CAP := 90.0
const DATE_LOADING_TIP_INTERVAL := 1.25
const ICON_FLOAT_DISTANCE := 6.0
const ICON_FLOAT_HALF_CYCLE := 1.05

@onready var title_label: Label = %TitleLabel
@onready var kicker_label: Label = %KickerLabel
@onready var status_label: Label = %StatusLabel
@onready var summary_label: Label = %SummaryLabel
@onready var hint_label: Label = %HintLabel
@onready var progress_bar: ProgressBar = %ProgressBar
@onready var icon_pivot: Control = %IconPivot
@onready var glow_rect: ColorRect = %GlowRect

var _progress_tween: Tween = null
var _fade_tween: Tween = null
var _tip_timer: SceneTreeTimer = null
var _icon_tween: Tween = null
var _glow_tween: Tween = null
var _started_at_sec: float = 0.0
var _token: int = 0
var _tips: Array[String] = []
var _tip_index: int = 0
var _icon_base_offset_top: float = 0.0
var _icon_base_offset_bottom: float = 0.0


func _ready() -> void:
	visible = false
	modulate.a = 0.0
	progress_bar.value = 0.0
	if icon_pivot:
		_icon_base_offset_top = icon_pivot.offset_top
		_icon_base_offset_bottom = icon_pivot.offset_bottom
	_reset_visual_state()


func show_for_context(context: Dictionary) -> void:
	_token += 1
	_started_at_sec = float(Time.get_ticks_msec()) / 1000.0
	_tips = _build_tips(context)
	_tip_index = 0
	_update_header(context)
	_update_summary(context)
	_update_hint(context)

	if not _tips.is_empty():
		status_label.text = _tips[0]
	else:
		status_label.text = "Luna 正在准备今天的见面..."

	_stop_animations(false)
	progress_bar.value = 0.0
	modulate.a = 0.0
	show()

	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", 1.0, 0.2)

	_progress_tween = create_tween()
	_progress_tween.tween_property(progress_bar, "value", DATE_LOADING_PROGRESS_CAP, DATE_LOADING_PROGRESS_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	_play_visual_animation()
	_cycle_tips(_token)


func complete(is_fallback: bool = false) -> void:
	var token: int = _token
	await _finish(token, is_fallback)


func hide_immediately() -> void:
	_stop_animations(true)
	hide()
	modulate.a = 0.0
	progress_bar.value = 0.0


func cancel() -> void:
	_stop_animations(true)


func _update_header(context: Dictionary) -> void:
	var date_plan: Array = context.get("date_plan", [])
	var segment_count: int = date_plan.size()
	var style: Dictionary = _get_loading_style(context)
	var default_name := str(context.get("character_name", "她"))
	title_label.text = str(style.get("title_multi", "今日约会准备中")) if segment_count >= 2 else str(style.get("title_single", "约会准备中"))
	kicker_label.text = str(style.get("kicker_single", "%s 正在赴约" % default_name)) if segment_count <= 1 else str(style.get("kicker_multi", "%s 正在整理今天的约会安排" % default_name))


func _update_summary(context: Dictionary) -> void:
	var weather_desc := str(context.get("story_weather_desc", ""))
	var date_plan: Array = context.get("date_plan", [])
	var parts: Array[String] = []
	for segment in date_plan:
		if not segment is Dictionary:
			continue
		parts.append("%s · %s" % [
			str(segment.get("period_label", "白天")),
			str(segment.get("location_name", "未知地点"))
		])

	var plan_text := " / ".join(parts)
	if weather_desc != "":
		summary_label.text = "%s\n%s" % [weather_desc, plan_text]
	else:
		summary_label.text = plan_text


func _update_hint(context: Dictionary) -> void:
	hint_label.text = _build_hint_text(context)


func _build_hint_text(context: Dictionary) -> String:
	var date_plan: Array = context.get("date_plan", [])
	var hint_candidates: Array[String] = []
	for segment in date_plan:
		if not segment is Dictionary:
			continue
		var segment_hints: Variant = segment.get("loading_hints", [])
		if segment_hints is Array:
			for item in segment_hints:
				var text := str(item).strip_edges()
				if text != "" and not hint_candidates.has(text):
					hint_candidates.append(text)
		var loading_hint := str(segment.get("loading_hint", "")).strip_edges()
		if loading_hint != "" and not hint_candidates.has(loading_hint):
			hint_candidates.append(loading_hint)

	if not hint_candidates.is_empty():
		var hint_index: int = ((_token - 1) % hint_candidates.size() + hint_candidates.size()) % hint_candidates.size()
		return hint_candidates[hint_index]
	var style: Dictionary = _get_loading_style(context)
	if date_plan.size() >= 2:
		return str(style.get("default_hint_multi", "她正在慢慢整理心情，像是很在意今天和你的见面..."))
	return str(style.get("default_hint_single", "她正在想着，这次见面要不要先对你笑一下..."))


func _build_tips(context: Dictionary) -> Array[String]:
	var style: Dictionary = _get_loading_style(context)
	var tips: Array[String] = []
	var default_statuses: Variant = style.get("default_statuses", [])
	if default_statuses is Array:
		for item in default_statuses:
			var text := str(item).strip_edges()
			if text != "":
				tips.append(text)
	if tips.is_empty():
		tips = [
			"她正在整理今天的心情...",
			"她正在确认这次约会的安排...",
			"她正在做最后的出门准备..."
		]

	var weather_id := str(context.get("story_weather_id", "sunny"))
	var weather_tips: Dictionary = style.get("weather_tips", {})
	var weather_candidates: Variant = weather_tips.get(weather_id, weather_tips.get("default", []))
	if weather_candidates is Array:
		for item in weather_candidates:
			var text := str(item).strip_edges()
			if text != "":
				tips.append(text)

	var date_plan: Array = context.get("date_plan", [])
	var type_ids: Array[String] = []
	for segment in date_plan:
		if not segment is Dictionary:
			continue
		var type_id := str(segment.get("type_id", "")).strip_edges()
		if type_id != "" and not type_ids.has(type_id):
			type_ids.append(type_id)

	var type_tips: Dictionary = style.get("type_tips", {})
	for type_id in type_ids:
		var type_candidates: Variant = type_tips.get(type_id, [])
		if type_candidates is Array:
			for item in type_candidates:
				var text := str(item).strip_edges()
				if text != "":
					tips.append(text)

	var stage_num := int(context.get("relationship_stage", 1))
	var stage_tips: Dictionary = style.get("stage_tips", {})
	var stage_key := "early"
	if stage_num >= 4:
		stage_key = "late"
	elif stage_num >= 2:
		stage_key = "mid"
	var stage_candidates: Variant = stage_tips.get(stage_key, [])
	if stage_candidates is Array:
		for item in stage_candidates:
			var text := str(item).strip_edges()
			if text != "":
				tips.append(text)

	return tips


func _get_loading_style(context: Dictionary) -> Dictionary:
	var style_variant: Variant = context.get("date_loading_style", {})
	if style_variant is Dictionary:
		return style_variant
	return {}


func _cycle_tips(token: int) -> void:
	if token != _token or not visible:
		return
	if _tips.size() > 1:
		_tip_index = (_tip_index + 1) % _tips.size()
		status_label.text = _tips[_tip_index]
	_tip_timer = get_tree().create_timer(DATE_LOADING_TIP_INTERVAL)
	_tip_timer.timeout.connect(func() -> void:
		_cycle_tips(token)
	)


func _finish(token: int, is_fallback: bool) -> void:
	var elapsed_sec := float(Time.get_ticks_msec()) / 1000.0 - _started_at_sec
	if elapsed_sec < DATE_LOADING_MIN_DURATION:
		await get_tree().create_timer(DATE_LOADING_MIN_DURATION - elapsed_sec).timeout
	if token != _token:
		return

	if _progress_tween:
		_progress_tween.kill()
		_progress_tween = null

	status_label.text = "Luna 已经准备好了，约会马上开始..." if not is_fallback else "Luna 已经准备好了，今天的约会即将开始..."
	hint_label.text = "约会的氛围已经整理完成..."

	var finish_tween := create_tween()
	finish_tween.tween_property(progress_bar, "value", 100.0, 0.35).set_ease(Tween.EASE_IN_OUT)
	await finish_tween.finished
	if token != _token:
		return
	await get_tree().create_timer(0.18).timeout
	if token != _token:
		return
	hide_immediately()


func _play_visual_animation() -> void:
	_reset_visual_state()

	if icon_pivot:
		_icon_tween = create_tween().set_loops()
		_tween_icon_vertical_offsets(
			_icon_base_offset_top - ICON_FLOAT_DISTANCE,
			_icon_base_offset_bottom - ICON_FLOAT_DISTANCE,
			ICON_FLOAT_HALF_CYCLE,
			Tween.TRANS_SINE,
			Tween.EASE_OUT
		)
		_tween_icon_vertical_offsets(
			_icon_base_offset_top + ICON_FLOAT_DISTANCE,
			_icon_base_offset_bottom + ICON_FLOAT_DISTANCE,
			ICON_FLOAT_HALF_CYCLE * 2.0,
			Tween.TRANS_SINE,
			Tween.EASE_IN_OUT
		)
		_tween_icon_vertical_offsets(
			_icon_base_offset_top,
			_icon_base_offset_bottom,
			ICON_FLOAT_HALF_CYCLE,
			Tween.TRANS_SINE,
			Tween.EASE_IN
		)
	
	_glow_tween = create_tween().set_loops()
	_glow_tween.tween_property(glow_rect, "modulate:a", 0.72, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_glow_tween.tween_property(glow_rect, "modulate:a", 0.38, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func _reset_visual_state() -> void:
	if icon_pivot:
		icon_pivot.offset_top = _icon_base_offset_top
		icon_pivot.offset_bottom = _icon_base_offset_bottom
	if glow_rect:
		glow_rect.modulate.a = 0.5


func _tween_icon_vertical_offsets(target_top: float, target_bottom: float, duration: float, trans: Tween.TransitionType, ease: Tween.EaseType) -> void:
	_icon_tween.set_parallel(true)
	_icon_tween.tween_property(icon_pivot, "offset_top", target_top, duration).set_trans(trans).set_ease(ease)
	_icon_tween.tween_property(icon_pivot, "offset_bottom", target_bottom, duration).set_trans(trans).set_ease(ease)
	_icon_tween.set_parallel(false)


func _stop_animations(invalidate_token: bool) -> void:
	if invalidate_token:
		_token += 1
	if _progress_tween:
		_progress_tween.kill()
		_progress_tween = null
	if _fade_tween:
		_fade_tween.kill()
		_fade_tween = null
	if _icon_tween:
		_icon_tween.kill()
		_icon_tween = null
	if _glow_tween:
		_glow_tween.kill()
		_glow_tween = null
	_tip_timer = null
	_reset_visual_state()
