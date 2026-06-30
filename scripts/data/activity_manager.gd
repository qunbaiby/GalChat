class_name ActivityManager
extends Node

const ACTIVITIES_DATA = preload("res://assets/data/interaction/activity/activities_data.gd")

var categories: Array = []
var activities: Array = []
var rest_activities: Array = []

func _ready() -> void:
	_load_activities_db()

func _load_activities_db() -> void:
	var data: Dictionary = ACTIVITIES_DATA.get_data()
	if data.is_empty():
		printerr("Activity DB is empty.")
		return
	if data.has("categories"):
		categories = data["categories"]
	if data.has("activities"):
		activities = data["activities"]
		rest_activities.clear()
		for act in activities:
			if act.has("category_id") and act["category_id"] == "rest":
				rest_activities.append(act)

func get_categories() -> Array:
	if categories.is_empty() and activities.is_empty():
		_load_activities_db()
	return categories

func get_activities_by_category(cat_id: String) -> Array:
	if activities.is_empty():
		_load_activities_db()
	var result = []
	for act in activities:
		if act.has("category_id") and act["category_id"] == cat_id:
			result.append(act)
	return result

func get_rest_activities() -> Array:
	return rest_activities

func get_activity_by_id(activity_id: String) -> Dictionary:
	if activities.is_empty() and rest_activities.is_empty():
		_load_activities_db()
	for act in activities:
		if act["id"] == activity_id:
			return act
	for act in rest_activities:
		if act["id"] == activity_id:
			return act
	return {}

# 执行活动
# 返回结果字典： { "success": bool, "msg": String, "gained_stats": Dictionary }
func execute_activity(profile: CharacterProfile, activity_id: String) -> Dictionary:
	var act = get_activity_by_id(activity_id)
			
	if act.is_empty():
		return { "success": false, "msg": "未找到对应的活动！", "gained_stats": {} }
		
	# 计算收益
	var gained = {}
	if act.has("rewards"):
		for stat_name in act.rewards.keys():
			var range_arr = act.rewards[stat_name]
			var min_val = range_arr[0]
			var max_val = range_arr[1]
			var amount = randi_range(min_val, max_val)
			
			# 增加数值
			GameDataManager.stats_system.add_basic_stat(profile, stat_name, float(amount))
			gained[stat_name] = amount
		
	return { "success": true, "msg": "活动执行成功！", "gained_stats": gained }
