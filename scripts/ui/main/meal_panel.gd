extends Control

signal takeout_requested
signal meal_minute_elapsed(minutes: int)
signal meal_progress_completed
signal closed

const RESULT_FADE_DURATION := 0.25
const MEAL_PROGRESS_DURATION := 3.0

@onready var option_page: VBoxContainer = $Panel/Margin/OptionPage
@onready var result_page: VBoxContainer = $Panel/Margin/ResultPage
@onready var takeout_button: Button = $Panel/Margin/OptionPage/Options/TakeoutButton
@onready var luna_cooks_button: Button = $Panel/Margin/OptionPage/Options/LunaCooksButton
@onready var dine_out_button: Button = $Panel/Margin/OptionPage/Options/DineOutButton
@onready var meal_name_label: Label = $Panel/Margin/ResultPage/MealName
@onready var meal_image: TextureRect = $Panel/Margin/ResultPage/MealImage
@onready var completion_content: VBoxContainer = $Panel/Margin/ResultPage/CompletionContent
@onready var stat_changes_label: Label = $Panel/Margin/ResultPage/CompletionContent/StatChanges
@onready var meal_progress: ProgressBar = $Panel/Margin/ResultPage/MealProgress
@onready var progress_label: Label = $Panel/Margin/ResultPage/ProgressLabel
@onready var dismiss_button: Button = $DismissButton

var _result_close_allowed := false
var _progress_tween: Tween
var _progress_minutes_emitted := 0


func _ready() -> void:
	takeout_button.pressed.connect(_on_takeout_button_pressed)
	$Panel/Margin/OptionPage/CloseButton.pressed.connect(_close)
	$Panel/Margin/ResultPage/CompletionContent/ConfirmButton.pressed.connect(_try_close_result)
	dismiss_button.pressed.connect(_try_close_result)
	luna_cooks_button.disabled = true
	dine_out_button.disabled = true
	option_page.show()
	result_page.hide()


func _on_takeout_button_pressed() -> void:
	var guide_manager := get_node_or_null("/root/GuideManager")
	if guide_manager and guide_manager.has_method("report_action"):
		guide_manager.report_action("select_meal_takeout")
	takeout_requested.emit()


func show_options() -> void:
	_stop_progress_tween()
	_result_close_allowed = false
	dismiss_button.hide()
	option_page.show()
	result_page.hide()
	show()


func show_result(meal: Dictionary) -> void:
	option_page.hide()
	result_page.show()
	result_page.modulate.a = 0.0
	completion_content.modulate.a = 0.0
	_result_close_allowed = false
	dismiss_button.hide()
	meal_name_label.text = str(meal.get("name", "今日餐点"))
	var image_path := str(meal.get("image", ""))
	meal_image.texture = load(image_path) as Texture2D if ResourceLoader.exists(image_path) else null
	var time_cost := maxi(1, int(meal.get("time_cost_minutes", 30)))
	meal_progress.max_value = time_cost
	meal_progress.value = 0.0
	_progress_minutes_emitted = 0
	_update_progress_label(0, time_cost)
	var fade_tween := create_tween()
	fade_tween.tween_property(result_page, "modulate:a", 1.0, RESULT_FADE_DURATION)
	_start_meal_progress(time_cost)


func reveal_completion(result: Dictionary) -> void:
	stat_changes_label.text = "精力 +%d    心情 +%d\n用餐时间  %d 分钟" % [
		int(result.get("energy_delta", 0)),
		int(round(float(result.get("mood_delta", 0.0)))),
		int(result.get("time_cost_minutes", 30))
	]
	_result_close_allowed = true
	dismiss_button.show()
	var completion_tween := create_tween()
	completion_tween.tween_property(completion_content, "modulate:a", 1.0, RESULT_FADE_DURATION)


func _start_meal_progress(time_cost: int) -> void:
	_stop_progress_tween()
	_progress_tween = create_tween()
	_progress_tween.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	_progress_tween.tween_method(
		func(value: float) -> void: _set_progress_minutes(floori(value), time_cost),
		0.0,
		float(time_cost),
		MEAL_PROGRESS_DURATION
	)
	_progress_tween.tween_callback(func() -> void:
		_set_progress_minutes(time_cost, time_cost)
		meal_progress_completed.emit()
	)


func _set_progress_minutes(minutes: int, time_cost: int) -> void:
	var clamped_minutes := clampi(minutes, 0, time_cost)
	meal_progress.value = clamped_minutes
	_update_progress_label(clamped_minutes, time_cost)
	if clamped_minutes <= _progress_minutes_emitted:
		return
	var elapsed := clamped_minutes - _progress_minutes_emitted
	_progress_minutes_emitted = clamped_minutes
	meal_minute_elapsed.emit(elapsed)


func _update_progress_label(minutes: int, time_cost: int) -> void:
	progress_label.text = "正在用餐  %d / %d 分钟" % [minutes, time_cost]


func _try_close_result() -> void:
	if _result_close_allowed:
		_close()


func _stop_progress_tween() -> void:
	if _progress_tween and _progress_tween.is_valid():
		_progress_tween.kill()
	_progress_tween = null


func _close() -> void:
	_stop_progress_tween()
	hide()
	closed.emit()


func is_takeout_button_ready_for_guide() -> bool:
	return visible and option_page.visible and takeout_button.is_visible_in_tree() and not takeout_button.disabled


func is_result_ready_for_guide() -> bool:
	return visible and result_page.visible and _result_close_allowed and completion_content.modulate.a > 0.01


func get_takeout_button_focus_entry() -> Dictionary:
	return _build_focus_entry(takeout_button, 6.0)


func get_result_focus_entry() -> Dictionary:
	return _build_focus_entry($Panel as Control, 8.0)


func _build_focus_entry(control: Control, corner_radius: float) -> Dictionary:
	if not is_instance_valid(control) or not control.is_visible_in_tree():
		return {}
	var rect := control.get_global_rect()
	if rect.size.x <= 1.0 or rect.size.y <= 1.0:
		return {}
	return {"rect": rect, "shape": "rect", "shape_params": {"corner_radius": corner_radius}}