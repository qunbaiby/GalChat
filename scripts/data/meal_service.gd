class_name MealService
extends RefCounted

const DATABASE_PATH := "res://assets/data/interaction/meal_database.json"

var database: Dictionary = {}


func _init() -> void:
	database = _load_database()


func get_current_context(time_manager: Node, profile: Variant) -> Dictionary:
	if time_manager == null or profile == null or database.is_empty():
		return {"available": false, "reason": "unavailable"}
	var date_dict: Dictionary = time_manager.get_current_date_dict()
	var weekday := int(date_dict.get("weekday", -1))
	var allowed_weekdays: Array = database.get("allowed_weekdays", [])
	var weekday_allowed := allowed_weekdays.any(func(value: Variant) -> bool: return int(value) == weekday)
	if not weekday_allowed:
		return {"available": false, "reason": "weekday"}
	var current_minutes := int(time_manager.current_hour) * 60 + int(time_manager.current_minute)
	for slot_id in ["breakfast", "lunch", "dinner"]:
		var slot: Dictionary = database.get("slots", {}).get(slot_id, {})
		if current_minutes < int(slot.get("start_minutes", 0)) or current_minutes >= int(slot.get("end_minutes", 0)):
			continue
		var meal_key := _build_meal_key(int(time_manager.current_day_offset), slot_id)
		var consumed := bool(profile.meal_history.get(meal_key, false))
		return {
			"available": not consumed,
			"reason": "consumed" if consumed else "",
			"slot_id": slot_id,
			"slot_label": str(slot.get("label", slot_id)),
			"meal_key": meal_key
		}
	return {"available": false, "reason": "time_window"}


func draw_takeout(slot_id: String) -> Dictionary:
	var slot: Dictionary = database.get("slots", {}).get(slot_id, {})
	var items: Array = slot.get("items", [])
	if items.is_empty():
		return {}
	var item := (items.pick_random() as Dictionary).duplicate(true)
	item["slot_id"] = slot_id
	item["slot_label"] = str(slot.get("label", slot_id))
	item["time_cost_minutes"] = int(database.get("time_cost_minutes", 30))
	return item


func consume_takeout(profile: Variant, time_manager: Node, meal: Dictionary, time_already_advanced: bool = false, reserved_context: Dictionary = {}) -> Dictionary:
	var context := reserved_context.duplicate(true) if not reserved_context.is_empty() else get_current_context(time_manager, profile)
	if not reserved_context.is_empty():
		var meal_key := str(context.get("meal_key", ""))
		context["available"] = meal_key != "" and not bool(profile.meal_history.get(meal_key, false))
		context["reason"] = "consumed" if not bool(context.get("available", false)) else ""
	if not bool(context.get("available", false)) or str(context.get("slot_id", "")) != str(meal.get("slot_id", "")):
		return {"ok": false, "reason": str(context.get("reason", "unavailable"))}
	var stats: Dictionary = meal.get("stats", {})
	var energy_before := int(profile.current_energy)
	var mood_before := float(profile.mood_value)
	profile.current_energy = mini(profile.max_energy, profile.current_energy + int(stats.get("energy", 0)))
	profile.mood_value = clampf(profile.mood_value + float(stats.get("mood", 0)), 0.0, 100.0)
	profile.meal_history[str(context.get("meal_key", ""))] = true
	var time_cost := int(meal.get("time_cost_minutes", database.get("time_cost_minutes", 30)))
	if not time_already_advanced:
		time_manager.tick_minutes(time_cost)
	time_manager.save_data()
	profile.save_profile()
	return {
		"ok": true,
		"energy_delta": int(profile.current_energy) - energy_before,
		"mood_delta": profile.mood_value - mood_before,
		"time_cost_minutes": time_cost
	}


func _build_meal_key(day_offset: int, slot_id: String) -> String:
	return "%d:%s" % [day_offset, slot_id]


func _load_database() -> Dictionary:
	if not FileAccess.file_exists(DATABASE_PATH):
		return {}
	var file := FileAccess.open(DATABASE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var json := JSON.new()
	return json.data if json.parse(file.get_as_text()) == OK and json.data is Dictionary else {}