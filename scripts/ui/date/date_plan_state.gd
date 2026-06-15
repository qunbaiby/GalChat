class_name DatePlanState
extends RefCounted

const SLOT_ORDER := ["morning", "afternoon", "evening"]
const DRAFT_CONFIG_KEY := "date_pending_plan_draft"

var _slots := {
	"morning": _create_slot_template("早上"),
	"afternoon": _create_slot_template("下午"),
	"evening": _create_slot_template("晚上")
}


static func _create_slot_template(slot_name: String) -> Dictionary:
	return {
		"name": slot_name,
		"enabled": true,
		"location_id": "",
		"location_name": "",
		"type_id": "",
		"custom_image_path": ""
	}


func setup_from_story_time() -> void:
	for period_id in SLOT_ORDER:
		_slots[period_id]["enabled"] = true
	var current_period_str := "上午"
	if GameDataManager.story_time_manager:
		current_period_str = str(GameDataManager.story_time_manager.current_period)
	var current_period_idx := 1
	if current_period_str == "下午":
		current_period_idx = 2
	elif current_period_str == "傍晚" or current_period_str == "夜晚":
		current_period_idx = 3
	if current_period_idx >= 2:
		_slots["morning"]["enabled"] = false
	if current_period_idx >= 3:
		_slots["afternoon"]["enabled"] = false


func get_slot(period_id: String) -> Dictionary:
	if not _slots.has(period_id):
		return {}
	return _slots[period_id].duplicate(true)


func get_slots() -> Dictionary:
	return _slots.duplicate(true)


func assign_first_available(location_id: String, location_name: String, type_id: String) -> String:
	var period_id := get_first_available_slot()
	if period_id == "":
		return ""
	assign_location(period_id, location_id, location_name, type_id)
	return period_id


func get_first_available_slot() -> String:
	for period_id in SLOT_ORDER:
		var slot: Dictionary = _slots[period_id]
		if bool(slot.get("enabled", true)) and str(slot.get("location_id", "")).strip_edges() == "":
			return period_id
	return ""


func assign_location(period_id: String, location_id: String, location_name: String, type_id: String, custom_image_path: String = "") -> void:
	if not _slots.has(period_id):
		return
	_slots[period_id]["location_id"] = location_id
	_slots[period_id]["location_name"] = location_name
	_slots[period_id]["type_id"] = type_id
	_slots[period_id]["custom_image_path"] = custom_image_path


func clear_slot(period_id: String) -> void:
	if not _slots.has(period_id):
		return
	var slot_name := str(_slots[period_id].get("name", period_id))
	var enabled := bool(_slots[period_id].get("enabled", true))
	_slots[period_id] = _create_slot_template(slot_name)
	_slots[period_id]["enabled"] = enabled


func has_any_plan() -> bool:
	for period_id in SLOT_ORDER:
		if str(_slots[period_id].get("location_id", "")).strip_edges() != "":
			return true
	return false


func build_plan_list() -> Array:
	var plan_list: Array = []
	for period_id in SLOT_ORDER:
		var slot: Dictionary = _slots[period_id]
		if not bool(slot.get("enabled", true)):
			continue
		var location_id := str(slot.get("location_id", "")).strip_edges()
		if location_id == "":
			continue
		plan_list.append({
			"period": period_id,
			"location_id": location_id,
			"type_id": str(slot.get("type_id", "")),
			"custom_image_path": str(slot.get("custom_image_path", ""))
		})
	return plan_list


func save_draft() -> void:
	var draft := {
		"slots": {}
	}
	for period_id in SLOT_ORDER:
		var slot: Dictionary = _slots[period_id]
		draft["slots"][period_id] = {
			"location_id": str(slot.get("location_id", "")),
			"location_name": str(slot.get("location_name", "")),
			"type_id": str(slot.get("type_id", "")),
			"custom_image_path": str(slot.get("custom_image_path", ""))
		}
	GameDataManager.set_archive_custom_config(DRAFT_CONFIG_KEY, draft, true)


func load_draft() -> bool:
	var draft: Variant = GameDataManager.get_archive_custom_config(DRAFT_CONFIG_KEY, {})
	if not (draft is Dictionary):
		return false
	var slot_dict: Variant = draft.get("slots", {})
	if not (slot_dict is Dictionary):
		return false
	var restored := false
	for period_id in SLOT_ORDER:
		var saved: Variant = slot_dict.get(period_id, {})
		if not (saved is Dictionary):
			continue
		var location_id := str(saved.get("location_id", "")).strip_edges()
		if location_id == "":
			continue
		assign_location(
			period_id,
			location_id,
			str(saved.get("location_name", "")),
			str(saved.get("type_id", "")),
			str(saved.get("custom_image_path", ""))
		)
		restored = true
	return restored


func clear_draft() -> void:
	GameDataManager.set_archive_custom_config(DRAFT_CONFIG_KEY, {}, true)
