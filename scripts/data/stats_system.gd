class_name StatsSystem
extends Node

const MAX_BASIC_STAT: float = 2000.0

func _ready() -> void:
	pass

# ==========================================
# 核心四维计算 (体、智、魅、感)
# ==========================================

func get_core_physical(profile: CharacterProfile) -> int:
	return int(floor(profile.stat_stamina + profile.stat_body + profile.stat_focus + profile.stat_rhythm))

func get_core_intelligence(profile: CharacterProfile) -> int:
	return int(floor(profile.stat_knowledge + profile.stat_expression + profile.stat_planning + profile.stat_art_theory))

func get_core_charm(profile: CharacterProfile) -> int:
	return int(floor(profile.stat_temperament + profile.stat_manner + profile.stat_etiquette + profile.stat_stage))

func get_core_sensibility(profile: CharacterProfile) -> int:
	return int(floor(profile.stat_empathy + profile.stat_inspiration + profile.stat_aesthetics + profile.stat_perception))

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
