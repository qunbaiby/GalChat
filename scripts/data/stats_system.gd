class_name StatsSystem
extends Node

const MAX_BASIC_STAT: float = 2000.0

func _ready() -> void:
	pass

# ==========================================
# 核心三维计算 (体、智、魅)
# 根据公式：向下取整
# ==========================================

func get_core_physical(profile: CharacterProfile) -> int:
	# 体 = ⌊（身体素质×0.6 + 体能活力×0.4）÷ 10⌋
	var physical_fitness = profile.physical_fitness
	var vitality = profile.vitality
	var raw_val = (physical_fitness * 0.6 + vitality * 0.4) / 10.0
	return int(floor(raw_val))

func get_core_intelligence(profile: CharacterProfile) -> int:
	# 智 = ⌊（学业素养×0.5 + 知识储备×0.5）÷ 10⌋
	var academic_quality = profile.academic_quality
	var knowledge_reserve = profile.knowledge_reserve
	var raw_val = (academic_quality * 0.5 + knowledge_reserve * 0.5) / 10.0
	return int(floor(raw_val))

func get_core_charm(profile: CharacterProfile) -> int:
	# 魅 = ⌊（社交情商×0.5 + 创意审美×0.5）÷ 8⌋
	var social_eq = profile.social_eq
	var creative_aesthetics = profile.creative_aesthetics
	var raw_val = (social_eq * 0.5 + creative_aesthetics * 0.5) / 8.0
	return int(floor(raw_val))

# ==========================================
# 基础属性增加
# ==========================================

func add_basic_stat(profile: CharacterProfile, stat_name: String, amount: float) -> void:
	if not profile.get(stat_name) is float and not profile.get(stat_name) is int:
		printerr("Unknown stat: ", stat_name)
		return
		
	var current_val = profile.get(stat_name)
	var new_val = clamp(current_val + amount, 0.0, MAX_BASIC_STAT)
	profile.set(stat_name, new_val)
	
	print("[StatsSystem] 属性 %s 增加 %.1f，当前值为: %.1f" % [stat_name, amount, new_val])
	profile.save_profile()
