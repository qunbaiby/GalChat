class_name StatsSystem
extends Node

const MAX_BASIC_STAT: float = 2000.0

var stats_config: Dictionary = {}

func _ready() -> void:
	_load_stats_config()

func _load_stats_config() -> void:
	var path = "res://assets/data/config/stats_config.json"
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			stats_config = json.data
		file.close()
	else:
		printerr("[StatsSystem] stats_config.json not found!")

# ==========================================
# 核心四维计算 (体、智、魅、感)
# ==========================================

func get_core_physical(profile: CharacterProfile) -> int:
	var val = 0.0
	if stats_config.has("core_stats") and stats_config.core_stats.has("core_stamina"):
		for sub in stats_config.core_stats.core_stamina.sub_stats:
			val += float(profile.get(sub))
	return int(floor(val))

func get_core_intelligence(profile: CharacterProfile) -> int:
	var val = 0.0
	if stats_config.has("core_stats") and stats_config.core_stats.has("core_intelligence"):
		for sub in stats_config.core_stats.core_intelligence.sub_stats:
			val += float(profile.get(sub))
	return int(floor(val))

func get_core_charm(profile: CharacterProfile) -> int:
	var val = 0.0
	if stats_config.has("core_stats") and stats_config.core_stats.has("core_charm"):
		for sub in stats_config.core_stats.core_charm.sub_stats:
			val += float(profile.get(sub))
	return int(floor(val))

func get_core_sensibility(profile: CharacterProfile) -> int:
	var val = 0.0
	if stats_config.has("core_stats") and stats_config.core_stats.has("core_sensibility"):
		for sub in stats_config.core_stats.core_sensibility.sub_stats:
			val += float(profile.get(sub))
	return int(floor(val))

func get_sub_stat_name(stat_id: String) -> String:
	if stats_config.has("sub_stats") and stats_config.sub_stats.has(stat_id):
		return stats_config.sub_stats[stat_id]
	return stat_id

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
