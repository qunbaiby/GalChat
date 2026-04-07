class_name ActivityManager
extends Node

# 课程与活动定义
# type: 归属的维度
# energy_cost: 消耗精力
# rewards: 获得的收益属性及范围区间 (min, max)
var activities: Array = [
	{
		"id": "physical_training",
		"name": "体能特训课",
		"type": "体适养成线",
		"desc": "涵盖耐力跑、核心力量训练，提升精力恢复速度。",
		"energy_cost": 20,
		"rewards": { "vitality": [15, 25] }
	},
	{
		"id": "outdoor_practice",
		"name": "户外实践课",
		"type": "体适养成线",
		"desc": "包含晨跑、远足、户外拓展，兼顾体能与实践能力。",
		"energy_cost": 25,
		"rewards": { "physical_fitness": [20, 30] }
	},
	{
		"id": "major_reading",
		"name": "专业精读课",
		"type": "智育养成线",
		"desc": "对应专业核心课程（如高数、编程），拉高绩点。",
		"energy_cost": 30,
		"rewards": { "academic_quality": [20, 35] }
	},
	{
		"id": "general_knowledge",
		"name": "通识博学课",
		"type": "智育养成线",
		"desc": "涵盖历史、哲学等博雅教育，拓宽知识面。",
		"energy_cost": 20,
		"rewards": { "knowledge_reserve": [15, 25] }
	},
	{
		"id": "social_expression",
		"name": "社交表达课",
		"type": "魅育养成线",
		"desc": "涵盖演讲与口才、职场沟通，提升社交能力。",
		"energy_cost": 20,
		"rewards": { "social_eq": [15, 25] }
	},
	{
		"id": "image_design",
		"name": "形象设计课",
		"type": "魅育养成线",
		"desc": "包含化妆、形体、穿搭美学，提升个人气质。",
		"energy_cost": 25,
		"rewards": { "creative_aesthetics": [20, 30], "social_eq": [5, 5] }
	},
	{
		"id": "rest_at_home",
		"name": "在家休息",
		"type": "日常恢复",
		"desc": "什么也不做，在家睡个好觉。恢复 30~50 点精力。",
		"energy_cost": 0,
		"rewards": { "energy_recovery": [30, 50] } # 这是一个特殊标记，用于在逻辑中处理
	}
]

func _ready() -> void:
	pass

func get_all_activities() -> Array:
	return activities

# 执行活动
# 返回结果字典： { "success": bool, "msg": String, "gained_stats": Dictionary }
func execute_activity(profile: CharacterProfile, activity_id: String) -> Dictionary:
	var act = null
	for a in activities:
		if a.id == activity_id:
			act = a
			break
			
	if act == null:
		return { "success": false, "msg": "未找到对应的活动！", "gained_stats": {} }
		
	if profile.current_energy < act.energy_cost:
		return { "success": false, "msg": "精力不足！", "gained_stats": {} }
		
	# 扣除精力
	profile.current_energy -= act.energy_cost
	profile.save_profile()
	
	# 计算收益
	var gained = {}
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
