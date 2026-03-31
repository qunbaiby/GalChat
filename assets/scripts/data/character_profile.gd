class_name CharacterProfile
extends Resource

var char_name: String = ""
var age: int = 22
var description: String = ""
var tags: Array = []

var intimacy: float = 0.0 # 0-9999
var current_mood: String = "平静" # 从 9 种状态中选取
var last_login_date: String = "" # 用于判断是否跨天
var trust: float = 10.0 # 0-9999
var current_stage: int = 1 # 1-8
var interaction_exp: int = 0

var stages_config: Array = []

signal stage_upgraded(new_stage: int, unlock_dialog: String)

const PROFILE_PATH = "user://character_profile.json"
var current_character_id: String = ""

func _init():
	pass

func load_profile() -> void:
	# 确定要加载的角色ID
	if GameDataManager.config and GameDataManager.config.current_character_id != "":
		current_character_id = GameDataManager.config.current_character_id
	else:
		# 如果未配置，自动寻找第一个可用的角色文件
		var dir = DirAccess.open("res://assets/data/characters")
		if dir:
			dir.list_dir_begin()
			var file_name = dir.get_next()
			while file_name != "":
				if file_name.ends_with(".json"):
					current_character_id = file_name.replace(".json", "")
					break
				file_name = dir.get_next()
			
		if current_character_id == "":
			printerr("No character config found in res://assets/data/characters/")
			return
			
	# 先加载静态数据
	_load_static_data()
	
	# 加载动态存档
	if FileAccess.file_exists(PROFILE_PATH):
		var file = FileAccess.open(PROFILE_PATH, FileAccess.READ)
		var content = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var error = json.parse(content)
		if error == OK:
			var data = json.get_data()
			if data is Dictionary:
				intimacy = data.get("intimacy", intimacy)
				current_mood = data.get("current_mood", current_mood)
				last_login_date = data.get("last_login_date", last_login_date)
				trust = data.get("trust", trust)
				current_stage = data.get("current_stage", current_stage)
				interaction_exp = data.get("interaction_exp", interaction_exp)
	
	init_daily_mood()

func _get_static_data_path() -> String:
	return "res://assets/data/characters/%s.json" % current_character_id

func _load_static_data() -> void:
	var path = _get_static_data_path()
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		var content = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var error = json.parse(content)
		if error == OK:
			var data = json.get_data()
			if data is Dictionary:
				char_name = data.get("char_name", char_name)
				age = data.get("age", age)
				description = data.get("world_background", data.get("description", description))
				tags = data.get("tags", tags)
				if data.has("stages"):
					stages_config = data["stages"]
	else:
		printerr("Character static data not found: ", path)

func init_daily_mood() -> void:
	var today = Time.get_date_string_from_system()
	if last_login_date != today:
		last_login_date = today
		if GameDataManager.mood_system != null:
			current_mood = GameDataManager.mood_system.get_random_mood()
			print("【心情系统】新的一天，抽取的初始心情为: ", current_mood)
		save_profile()

func get_stage_config(stage_num: int) -> Dictionary:
	for config in stages_config:
		if config["stage"] == stage_num:
			return config
	return {}

func get_current_stage_config() -> Dictionary:
	return get_stage_config(current_stage)

func force_set_stage(new_stage: int) -> void:
	current_stage = clamp(new_stage, 1, 9)
	
	# 获取前一个阶段的配置以确定当前阶段的起点
	var prev_stage = max(1, current_stage - 1)
	var prev_conf = get_stage_config(prev_stage)
	
	var min_value = 0.0
	if current_stage > 1 and not prev_conf.is_empty():
		min_value = float(prev_conf.get("threshold", 0))
	
	intimacy = min_value
	trust = min_value
	interaction_exp = int(min_value)
	
	save_profile()

func update_intimacy(amount: float) -> void:
	if amount > 0:
		var stage_conf = get_current_stage_config()
		var stage_multi = stage_conf.get("intimacy_multiplier", 1.0)
		var mood_multi = GameDataManager.mood_system.get_intimacy_multiplier(current_mood)
		amount = amount * stage_multi * mood_multi
	intimacy = max(intimacy + amount, 0.0)
	check_stage_upgrade()

func update_trust(amount: float) -> void:
	if amount > 0:
		var stage_conf = get_current_stage_config()
		var stage_multi = stage_conf.get("trust_multiplier", 1.0)
		var mood_multi = GameDataManager.mood_system.get_trust_multiplier(current_mood)
		amount = amount * stage_multi * mood_multi
	trust = max(trust + amount, 0.0)
	
func add_interaction_exp() -> void:
	var stage_conf = get_current_stage_config()
	var base_exp = stage_conf.get("exp_per_interaction", 10)
	var mood_bonus = GameDataManager.mood_system.get_exp_bonus(current_mood)
	var total_exp = base_exp + mood_bonus
	if total_exp < 0:
		total_exp = 0
		
	interaction_exp += total_exp
	check_stage_upgrade()

func check_stage_upgrade() -> void:
	var stage_conf = get_current_stage_config()
	if stage_conf.is_empty(): return
	
	# 假设突破阈值是亲密度要求，如果当前亲密度达到了阈值，并且互动经验也满了（或者不限制经验），
	# 这里根据题意"不可突破阶段上限"是指经验不能超过当前阶段某个值？
	# 或者说突破阈值就是经验的阈值？
	# “阶段突破阈值（int，达标后才允许进入下一阶段）”
	# “互动经验累计值（int，每次互动累加，可溢出但不可突破阶段上限）”
	# 看起来经验有一个阶段上限。假设 threshold 既是亲密度阈值也是经验上限。
	# 让我们假设经验满 threshold 后可以升阶。
	
	var threshold = stage_conf.get("threshold", 9999)
	if interaction_exp > threshold:
		interaction_exp = threshold
		
	if current_stage < 9 and intimacy >= threshold and interaction_exp >= threshold:
		current_stage += 1
		# 经验不再重置为0，而是像亲密度一样继承，以适配绝对值的目标上限展示
		print("【情感系统】升阶！当前阶段: Stage", current_stage)
		var next_stage_conf = get_current_stage_config()
		var unlock_dialog = next_stage_conf.get("unlockDialog", "")
		stage_upgraded.emit(current_stage, unlock_dialog)

func update_mood(new_mood: String) -> void:
	if GameDataManager.mood_system.is_valid_mood(new_mood):
		current_mood = new_mood
		save_profile()

func save_profile() -> void:
	var data = {
		"intimacy": intimacy,
		"current_mood": current_mood,
		"last_login_date": last_login_date,
		"trust": trust,
		"current_stage": current_stage,
		"interaction_exp": interaction_exp
	}
	var file = FileAccess.open(PROFILE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
