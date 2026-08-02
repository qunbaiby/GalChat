class_name DayRestTransition
extends Control

signal midpoint_reached
signal transition_completed

@export_range(0.1, 3.0, 0.05) var night_enter_duration := 0.75
@export_range(0.1, 5.0, 0.05) var night_hold_duration := 1.15
@export_range(0.1, 4.0, 0.05) var dawn_duration := 1.35
@export_range(0.1, 5.0, 0.05) var morning_hold_duration := 1.35
@export_range(0.1, 3.0, 0.05) var exit_duration := 0.65

@onready var morning_backdrop: TextureRect = $MorningBackdrop
@onready var night_tint: ColorRect = $NightTint
@onready var morning_glow: TextureRect = $MorningGlow
@onready var night_content: Control = $NightContent
@onready var ending_date_label: Label = $NightContent/EndingDateLabel
@onready var rest_label: Label = $NightContent/RestLabel
@onready var morning_content: Control = $MorningContent
@onready var new_day_label: Label = $MorningContent/NewDayLabel
@onready var new_date_label: Label = $MorningContent/NewDateLabel
@onready var weather_icon: TextureRect = $MorningContent/WeatherRow/WeatherIcon
@onready var weather_label: Label = $MorningContent/WeatherRow/WeatherLabel
@onready var energy_label: Label = $MorningContent/EnergyLabel
@onready var separator: ColorRect = $MorningContent/Separator

var _active_tween: Tween = null
var _night_content_position := Vector2.ZERO
var _morning_content_position := Vector2.ZERO


func _ready() -> void:
	_night_content_position = night_content.position
	_morning_content_position = morning_content.position
	mouse_filter = Control.MOUSE_FILTER_STOP
	hide()


func setup(data: Dictionary) -> void:
	ending_date_label.text = str(data.get("ending_date", ""))
	new_date_label.text = str(data.get("new_date", ""))
	weather_label.text = str(data.get("weather", ""))
	var icon_value: Variant = data.get("weather_icon")
	weather_icon.texture = icon_value as Texture2D if icon_value is Texture2D else null
	weather_icon.visible = weather_icon.texture != null
	rest_label.text = str(data.get("rest_text", "夜色渐深，今天就到这里。"))
	new_day_label.text = str(data.get("new_day_text", "新的一天"))
	energy_label.text = str(data.get("energy_text", "精力已恢复"))


func play_transition() -> void:
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()
	show()
	modulate.a = 1.0
	morning_backdrop.modulate.a = 0.0
	night_tint.modulate.a = 1.0
	morning_glow.modulate.a = 0.0
	night_content.position = _night_content_position + Vector2(0.0, 18.0)
	night_content.modulate.a = 0.0
	morning_content.position = _morning_content_position + Vector2(0.0, 24.0)
	morning_content.modulate.a = 0.0
	separator.scale.x = 0.0

	var night_enter := create_tween()
	_active_tween = night_enter
	night_enter.set_parallel(true)
	night_enter.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	night_enter.tween_property(night_content, "position", _night_content_position, night_enter_duration)
	night_enter.tween_property(night_content, "modulate:a", 1.0, night_enter_duration)
	await night_enter.finished
	await get_tree().create_timer(night_hold_duration).timeout

	var dawn := create_tween()
	_active_tween = dawn
	dawn.set_parallel(true)
	dawn.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	dawn.tween_property(night_content, "modulate:a", 0.0, dawn_duration * 0.45)
	dawn.tween_property(morning_backdrop, "modulate:a", 1.0, dawn_duration)
	dawn.tween_property(night_tint, "modulate:a", 0.0, dawn_duration)
	dawn.tween_property(morning_glow, "modulate:a", 1.0, dawn_duration)
	dawn.tween_property(morning_content, "position", _morning_content_position, dawn_duration)
	dawn.tween_property(morning_content, "modulate:a", 1.0, dawn_duration * 0.8).set_delay(dawn_duration * 0.2)
	dawn.tween_property(separator, "scale:x", 1.0, dawn_duration * 0.55).set_delay(dawn_duration * 0.35)
	await dawn.finished
	midpoint_reached.emit()
	await get_tree().create_timer(morning_hold_duration).timeout

	var exit_tween := create_tween()
	_active_tween = exit_tween
	exit_tween.set_parallel(true)
	exit_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	exit_tween.tween_property(morning_content, "modulate:a", 0.0, exit_duration)
	exit_tween.tween_property(morning_glow, "modulate:a", 0.0, exit_duration)
	await exit_tween.finished
	_active_tween = null
	transition_completed.emit()
