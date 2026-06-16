class_name StoryPeriodCard
extends Control

const PRE_BLACK_DURATION := 0.22
const ENTER_DURATION := 0.45
const HOLD_EXTRA_DELAY := 0.0
const EXIT_DURATION := 0.48
const TITLE_TRAVEL := 28.0

@onready var backdrop: TextureRect = $Backdrop
@onready var dim: ColorRect = $Dim
@onready var top_title: Label = $Center/TopTitle
@onready var line: Panel = $Center/Line
@onready var bottom_title: Label = $Center/BottomTitle

var _top_base_position := Vector2.ZERO
var _bottom_base_position := Vector2.ZERO
var _line_base_scale := Vector2.ONE
var _active_tween: Tween = null

func _ready() -> void:
	_top_base_position = top_title.position
	_bottom_base_position = bottom_title.position
	_line_base_scale = line.scale
	hide()


func play_card(bg_texture: Texture2D, period_text: String, location_text: String, hold_duration: float = 2.0) -> void:
	if _active_tween:
		_active_tween.kill()
		_active_tween = null
	backdrop.texture = bg_texture
	top_title.text = period_text
	bottom_title.text = location_text
	show()
	modulate = Color(1, 1, 1, 1)
	backdrop.modulate = Color(1, 1, 1, 0)
	dim.color = Color(0, 0, 0, 1)
	top_title.position = _top_base_position + Vector2(0, TITLE_TRAVEL)
	bottom_title.position = _bottom_base_position + Vector2(0, -TITLE_TRAVEL)
	top_title.modulate = Color(1, 1, 1, 0)
	bottom_title.modulate = Color(1, 1, 1, 0)
	line.scale = Vector2(0.0, _line_base_scale.y)
	line.modulate = Color(1, 1, 1, 0)

	# 先给一个纯黑切场，再开始标题卡演出，避免上一时段残留直接闪到下一时段。
	if PRE_BLACK_DURATION > 0.0:
		await get_tree().create_timer(PRE_BLACK_DURATION).timeout
		if _active_tween != null:
			return

	var enter_tween: Tween = create_tween()
	_active_tween = enter_tween
	enter_tween.set_parallel(true)
	enter_tween.tween_property(backdrop, "modulate:a", 1.0, ENTER_DURATION)
	enter_tween.tween_property(dim, "color:a", 0.0, ENTER_DURATION)
	enter_tween.tween_property(top_title, "position", _top_base_position, ENTER_DURATION)
	enter_tween.tween_property(bottom_title, "position", _bottom_base_position, ENTER_DURATION)
	enter_tween.tween_property(top_title, "modulate:a", 1.0, ENTER_DURATION)
	enter_tween.tween_property(bottom_title, "modulate:a", 1.0, ENTER_DURATION)
	enter_tween.tween_property(line, "scale", _line_base_scale, ENTER_DURATION)
	enter_tween.tween_property(line, "modulate:a", 1.0, ENTER_DURATION)
	await enter_tween.finished

	# 严格在文字完整停住后再开始计时，避免出现“还没停住就开始消失”。
	if _active_tween != enter_tween:
		return
	await get_tree().create_timer(maxf(0.0, hold_duration) + HOLD_EXTRA_DELAY).timeout
	if _active_tween != enter_tween:
		return

	var exit_tween: Tween = create_tween()
	_active_tween = exit_tween
	exit_tween.set_parallel(true)
	exit_tween.tween_property(top_title, "modulate:a", 0.0, EXIT_DURATION)
	exit_tween.tween_property(bottom_title, "modulate:a", 0.0, EXIT_DURATION)
	exit_tween.tween_property(line, "modulate:a", 0.0, EXIT_DURATION)
	exit_tween.tween_property(backdrop, "modulate:a", 0.0, EXIT_DURATION)
	await exit_tween.finished
	_active_tween = null
	hide()
