extends Control
class_name ActivityLoadingOverlay

const DEFAULT_MIN_DURATION := 1.1
const DEFAULT_PROGRESS_DURATION := 4.8
const DEFAULT_PROGRESS_CAP := 90.0
const DEFAULT_TIP_INTERVAL := 1.15
const ICON_FLOAT_DISTANCE := 6.0
const ICON_FLOAT_HALF_CYCLE := 1.0

@onready var title_label: Label = %TitleLabel
@onready var kicker_label: Label = %KickerLabel
@onready var status_label: Label = %StatusLabel
@onready var summary_label: Label = %SummaryLabel
@onready var hint_label: Label = %HintLabel
@onready var visual_caption_label: Label = %VisualCaption
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
var _phased_tips: Array[Dictionary] = []
var _tip_index: int = 0
var _current_phase_index: int = -1
var _min_duration: float = DEFAULT_MIN_DURATION
var _progress_duration: float = DEFAULT_PROGRESS_DURATION
var _progress_cap: float = DEFAULT_PROGRESS_CAP
var _tip_interval: float = DEFAULT_TIP_INTERVAL
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
	_min_duration = max(0.0, float(context.get("min_duration", DEFAULT_MIN_DURATION)))
	_progress_duration = max(0.2, float(context.get("progress_duration", DEFAULT_PROGRESS_DURATION)))
	_progress_cap = clampf(float(context.get("progress_cap", DEFAULT_PROGRESS_CAP)), 10.0, 99.0)
	_tip_interval = max(0.35, float(context.get("tip_interval", DEFAULT_TIP_INTERVAL)))
	_tips = _build_tips(context)
	_phased_tips = _build_phased_tips(context)
	_tip_index = -1
	_current_phase_index = -1

	_update_content(context)
	_apply_current_phase_tip(true)

	_stop_animations(false)
	progress_bar.value = 0.0
	modulate.a = 0.0
	show()

	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", 1.0, 0.2)

	_progress_tween = create_tween()
	_progress_tween.tween_property(progress_bar, "value", _progress_cap, _progress_duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	_play_visual_animation()
	_cycle_tips(_token)


func complete(final_status: String = "", final_hint: String = "") -> void:
	var token: int = _token
	await _finish(token, final_status, final_hint)


func hide_immediately() -> void:
	_stop_animations(true)
	hide()
	modulate.a = 0.0
	progress_bar.value = 0.0


func cancel() -> void:
	_stop_animations(true)


func _update_content(context: Dictionary) -> void:
	title_label.text = str(context.get("title", "课程安排执行中"))
	kicker_label.text = str(context.get("kicker", "Luna 正在出发"))
	status_label.text = str(context.get("status", "Luna 正在整理今天的课程节奏..."))
	summary_label.text = str(context.get("summary", ""))
	hint_label.text = str(context.get("hint", "本周安排正在缓缓展开..."))
	visual_caption_label.text = str(context.get("visual_caption", "课程执行中"))


func _build_tips(context: Dictionary) -> Array[String]:
	var tips: Array[String] = []
	var raw_tips: Variant = context.get("tips", [])
	if raw_tips is Array:
		for item in raw_tips:
			var text := str(item).strip_edges()
			if text != "" and not tips.has(text):
				tips.append(text)

	if tips.is_empty():
		tips = [
			str(context.get("status", "Luna 正在整理今天的课程节奏...")),
			"Luna 正在确认今天的安排顺序...",
			"Luna 正在为接下来的课程做准备..."
		]

	return tips


func _build_phased_tips(context: Dictionary) -> Array[Dictionary]:
	var phases: Array[Dictionary] = []
	var raw_phases: Variant = context.get("phased_tips", [])
	if raw_phases is Array:
		for raw_phase in raw_phases:
			if not (raw_phase is Dictionary):
				continue
			var phase_until: float = clampf(float(raw_phase.get("until", _progress_cap)), 1.0, 99.0)
			var phase_tips: Array[String] = _variant_to_string_array(raw_phase.get("tips", []))
			var fallback_status := str(raw_phase.get("status", "")).strip_edges()
			if phase_tips.is_empty() and fallback_status != "":
				phase_tips.append(fallback_status)
			if phase_tips.is_empty():
				continue
			phases.append({
				"until": phase_until,
				"tips": phase_tips
			})

	if phases.is_empty():
		phases.append({
			"until": _progress_cap,
			"tips": _tips
		})

	phases.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("until", _progress_cap)) < float(b.get("until", _progress_cap))
	)
	return phases


func _variant_to_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if not (value is Array):
		return result
	for item in value:
		var text := str(item).strip_edges()
		if text != "" and not result.has(text):
			result.append(text)
	return result


func _get_current_phase_index() -> int:
	if _phased_tips.is_empty():
		return -1
	var progress_value: float = float(progress_bar.value)
	for i in range(_phased_tips.size()):
		var phase: Dictionary = _phased_tips[i]
		if progress_value <= float(phase.get("until", _progress_cap)):
			return i
	return _phased_tips.size() - 1


func _apply_current_phase_tip(reset_phase: bool) -> void:
	var phase_index := _get_current_phase_index()
	if phase_index < 0 or phase_index >= _phased_tips.size():
		if not _tips.is_empty():
			status_label.text = _tips[0]
		return

	var phase: Dictionary = _phased_tips[phase_index]
	var phase_tips: Array[String] = phase.get("tips", [])
	if phase_tips.is_empty():
		return

	if reset_phase or phase_index != _current_phase_index:
		_current_phase_index = phase_index
		_tip_index = 0
	else:
		if _tip_index < 0:
			_tip_index = 0
		elif phase_tips.size() > 1:
			_tip_index = (_tip_index + 1) % phase_tips.size()

	status_label.text = phase_tips[_tip_index]


func _cycle_tips(token: int) -> void:
	if token != _token or not visible:
		return
	_apply_current_phase_tip(false)
	_tip_timer = get_tree().create_timer(_tip_interval)
	_tip_timer.timeout.connect(func() -> void:
		_cycle_tips(token)
	)


func _finish(token: int, final_status: String, final_hint: String) -> void:
	var elapsed_sec := float(Time.get_ticks_msec()) / 1000.0 - _started_at_sec
	if elapsed_sec < _min_duration:
		await get_tree().create_timer(_min_duration - elapsed_sec).timeout
	if token != _token:
		return

	if _progress_tween:
		_progress_tween.kill()
		_progress_tween = null

	status_label.text = final_status if final_status.strip_edges() != "" else "Luna 已经准备好了，安排马上开始..."
	hint_label.text = final_hint if final_hint.strip_edges() != "" else "课程节奏已经整理完成..."

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
	_glow_tween.tween_property(glow_rect, "modulate:a", 0.72, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_glow_tween.tween_property(glow_rect, "modulate:a", 0.38, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


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
