extends SceneTree

const MealServiceScript = preload("res://scripts/data/meal_service.gd")

class ProfileStub:
	var current_energy := 20
	var max_energy := 50
	var mood_value := 50.0
	var meal_history: Dictionary = {}

	func save_profile() -> bool:
		return true

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var service = MealServiceScript.new()
	var profile := ProfileStub.new()
	var game_data_manager := root.get_node("GameDataManager")
	var time_manager = game_data_manager.story_time_manager
	var original_day := int(time_manager.current_day_offset)
	var original_hour := int(time_manager.current_hour)
	var original_minute := int(time_manager.current_minute)
	var saturday_offset := _find_weekday_offset(time_manager, 6)
	time_manager.current_day_offset = saturday_offset
	time_manager.current_hour = 6
	time_manager.current_minute = 0
	var saturday_breakfast: Dictionary = service.get_current_context(time_manager, profile)
	_expect(bool(saturday_breakfast.get("available", false)) and saturday_breakfast.get("slot_id") == "breakfast", "周六跨日后的 06:00 没有开放早餐。")
	var friday_offset := _find_weekday_offset(time_manager, 5)
	time_manager.current_day_offset = friday_offset
	time_manager.current_hour = 7
	time_manager.current_minute = 0
	var breakfast: Dictionary = service.get_current_context(time_manager, profile)
	_expect(bool(breakfast.get("available", false)) and breakfast.get("slot_id") == "breakfast", "周五 07:00 没有开放早餐。")
	var meal: Dictionary = service.draw_takeout("breakfast")
	_expect(not meal.is_empty() and meal.has("stats") and meal.has("image"), "早餐随机菜品缺少属性或图片配置。")
	var result: Dictionary = service.consume_takeout(profile, time_manager, meal)
	_expect(bool(result.get("ok", false)), "点外卖没有成功结算。")
	_expect(int(result.get("time_cost_minutes", 0)) == 30 and time_manager.current_hour == 7 and time_manager.current_minute == 30, "吃饭没有推进 30 分钟。")
	_expect(not bool(service.get_current_context(time_manager, profile).get("available", true)), "同一餐结算后仍可重复吃饭。")
	profile.meal_history.clear()
	time_manager.current_hour = 7
	time_manager.current_minute = 59
	_expect(service.get_current_context(time_manager, profile).get("slot_id") == "breakfast", "早餐没有持续开放到 07:59。")
	time_manager.current_hour = 8
	time_manager.current_minute = 0
	_expect(not bool(service.get_current_context(time_manager, profile).get("available", true)), "早餐在 08:00 后仍然开放。")
	time_manager.current_hour = 12
	time_manager.current_minute = 0
	var lunch_context: Dictionary = service.get_current_context(time_manager, profile)
	_expect(lunch_context.get("slot_id") == "lunch", "周五 12:00 没有切换到午餐。")
	var lunch: Dictionary = service.draw_takeout("lunch")
	time_manager.tick_minutes(30)
	var lunch_result: Dictionary = service.consume_takeout(profile, time_manager, lunch, true, lunch_context)
	_expect(bool(lunch_result.get("ok", false)), "进度推进后无法使用开始时的餐段凭据结算。")
	_expect(time_manager.current_hour == 12 and time_manager.current_minute == 30, "完成结算重复推进了用餐时间。")
	profile.meal_history.clear()
	time_manager.current_hour = 12
	time_manager.current_minute = 59
	_expect(service.get_current_context(time_manager, profile).get("slot_id") == "lunch", "午餐没有持续开放到 12:59。")
	time_manager.current_hour = 13
	time_manager.current_minute = 0
	_expect(not bool(service.get_current_context(time_manager, profile).get("available", true)), "午餐在 13:00 后仍然开放。")
	time_manager.current_hour = 18
	time_manager.current_minute = 59
	_expect(service.get_current_context(time_manager, profile).get("slot_id") == "dinner", "晚餐没有持续开放到 18:59。")
	time_manager.current_hour = 19
	time_manager.current_minute = 0
	_expect(not bool(service.get_current_context(time_manager, profile).get("available", true)), "晚餐在 19:00 后仍然开放。")
	time_manager.current_day_offset = _find_weekday_offset(time_manager, 1)
	_expect(not bool(service.get_current_context(time_manager, profile).get("available", true)), "周一错误开放了吃饭功能。")
	time_manager.current_day_offset = original_day
	time_manager.current_hour = original_hour
	time_manager.current_minute = original_minute
	_finish()


func _find_weekday_offset(time_manager: Node, target_weekday: int) -> int:
	for offset in range(7):
		time_manager.current_day_offset = offset
		if int(time_manager.get_current_date_dict().get("weekday", -1)) == target_weekday:
			return offset
	return 0


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("MEAL_SERVICE_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("MEAL_SERVICE_SMOKE: " + failure)
	quit(1)