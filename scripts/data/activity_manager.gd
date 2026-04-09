class_name ActivityManager
extends Node

var _db_path: String = "res://assets/data/interaction/activity/activities.json"

var categories: Array = []
var activities: Array = []
var rest_activities: Array = []

func _ready() -> void:
	_load_activities_db()

func _load_activities_db() -> void:
	if not FileAccess.file_exists(_db_path):
		printerr("Activity DB not found at: ", _db_path)
		return
		
	var file = FileAccess.open(_db_path, FileAccess.READ)
	var json_str = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var err = json.parse(json_str)
	if err == OK:
		var data = json.get_data()
		if data.has("categories"):
			categories = data["categories"]
		if data.has("activities"):
			activities = data["activities"]
		if data.has("rest_activities"):
			rest_activities = data["rest_activities"]
		print("Loaded activities DB: %d categories, %d activities, %d rest activities" % [categories.size(), activities.size(), rest_activities.size()])
	else:
		printerr("Failed to parse activities JSON: ", json.get_error_message())

func get_categories() -> Array:
	return categories

func get_activities_by_category(cat_id: String) -> Array:
	var result = []
	for act in activities:
		if act.has("category_id") and act["category_id"] == cat_id:
			result.append(act)
	return result

func get_rest_activities() -> Array:
	return rest_activities

func get_activity_by_id(activity_id: String) -> Dictionary:
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
		
	if profile.current_energy < act.energy_cost:
		return { "success": false, "msg": "精力不足！", "gained_stats": {} }
		
	# 扣除精力
	profile.current_energy -= act.energy_cost
	profile.save_profile()
	
	# 计算收益
	var gained = {}
	if act.has("rewards"):
		for stat_name in act.rewards.keys():
			var range_arr = act.rewards[stat_name]
			var min_val = range_arr[0]
			var max_val = range_arr[1]
			var amount = randi_range(min_val, max_val)
			
			# 处理特殊的“恢复精力”机制
			if stat_name == "energy_recovery":
				profile.current_energy = min(profile.current_energy + amount, profile.max_energy)
				profile.save_profile()
				gained["energy_recovery"] = amount
			else:
				# 增加数值
				GameDataManager.stats_system.add_basic_stat(profile, stat_name, float(amount))
				gained[stat_name] = amount
		
	return { "success": true, "msg": "活动执行成功！", "gained_stats": gained }
