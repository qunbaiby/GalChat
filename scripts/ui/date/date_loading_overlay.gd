extends Control
class_name DateLoadingOverlay

const DATE_LOADING_MIN_DURATION := 1.4
const DATE_LOADING_PROGRESS_DURATION := 4.6
const DATE_LOADING_PROGRESS_CAP := 90.0
const DATE_LOADING_TIP_INTERVAL := 1.25

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


func _ready() -> void:
	visible = false
	modulate.a = 0.0
	progress_bar.value = 0.0
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
	title_label.text = "今日约会准备中" if segment_count >= 2 else "约会准备中"
	kicker_label.text = "Luna 正在赴约" if segment_count <= 1 else "Luna 正在整理今天的约会安排"


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

	if date_plan.size() >= 2:
		return "Luna 正在慢慢整理心情，像是很在意今天和你的见面..."
	return "Luna 正在想着，这次见面要不要先对你笑一下..."


func _build_tips(context: Dictionary) -> Array[String]:
	var tips: Array[String] = [
		"Luna 正在整理今天的心情...",
		"Luna 正在确认这次约会的安排...",
		"Luna 正在对着镜子做最后检查..."
	]

	var weather_id := str(context.get("story_weather_id", "sunny"))
	match weather_id:
		"rainy", "thunder":
			tips.append("Luna 正在确认有没有带伞...")
		"foggy":
			tips.append("Luna 正在挑一件适合微凉天气的外套...")
		_:
			tips.append("Luna 正在挑选今天适合出门的搭配...")

	var date_plan: Array = context.get("date_plan", [])
	var type_ids: Array[String] = []
	for segment in date_plan:
		if not segment is Dictionary:
			continue
		var type_id := str(segment.get("type_id", "")).strip_edges()
		if type_id != "" and not type_ids.has(type_id):
			type_ids.append(type_id)

	for type_id in type_ids:
		match type_id:
			"stroll":
				tips.append("Luna 正在想等会儿要不要和你慢慢走一段路...")
			"shopping":
				tips.append("Luna 正在猜今天会不会逛到喜欢的小东西...")
			"exhibition":
				tips.append("Luna 正在挑一件安静又好看的搭配...")
			"dining":
				tips.append("Luna 正在犹豫要不要喷一点淡淡的香水...")

	var stage_num := int(context.get("relationship_stage", 1))
	if stage_num >= 4:
		tips.append("Luna 似乎比平时多花了一点时间准备今天的见面...")
	elif stage_num >= 2:
		tips.append("Luna 正在想着等会儿该先和你聊什么...")
	else:
		tips.append("Luna 正在认真整理仪容，不想让今天显得太随便...")

	return tips


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
	_icon_tween = create_tween().set_loops()
	_icon_tween.tween_property(icon_pivot, "position:y", -10.0, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_icon_tween.tween_property(icon_pivot, "position:y", 8.0, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_icon_tween.tween_property(icon_pivot, "position:y", 0.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	_glow_tween = create_tween().set_loops()
	_glow_tween.tween_property(glow_rect, "modulate:a", 0.72, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_glow_tween.tween_property(glow_rect, "modulate:a", 0.38, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func _reset_visual_state() -> void:
	if icon_pivot:
		icon_pivot.position = Vector2.ZERO
	if glow_rect:
		glow_rect.modulate.a = 0.5


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
