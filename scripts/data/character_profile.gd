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
var base_personality: Dictionary = {}

var openness: float = 50.0
var conscientiousness: float = 50.0
var extraversion: float = 50.0
var agreeableness: float = 50.0
var neuroticism: float = 50.0

var last_online_time: int = 0

# 三维六基养成体系数值
var physical_fitness: float = 0.0 # 身体素质
var vitality: float = 0.0 # 体能活力
var academic_quality: float = 0.0 # 学业素养
var knowledge_reserve: float = 0.0 # 知识储备
var social_eq: float = 0.0 # 社交情商
var creative_aesthetics: float = 0.0 # 创意审美

var current_energy: float = 100.0
var max_energy: float = 100.0

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
				if file_name.ends_with(".json") and not file_name.ends_with("_stages.json"):
					current_character_id = file_name.replace(".json", "")
					break
				file_name = dir.get_next()
			
		if current_character_id == "":
			printerr("No character config found in res://assets/data/characters/")
			return
			
	# 先加载静态数据
	_load_static_data()
	_load_stage_data()
	
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
				intimacy = float(str(data.get("intimacy", intimacy)))
				current_mood = data.get("current_mood", current_mood)
				last_login_date = data.get("last_login_date", last_login_date)
				trust = float(str(data.get("trust", trust)))
				current_stage = int(str(data.get("current_stage", current_stage)))
				interaction_exp = int(str(data.get("interaction_exp", interaction_exp)))
				openness = float(str(data.get("openness", base_personality.get("openness", 50.0))))
				conscientiousness = float(str(data.get("conscientiousness", base_personality.get("conscientiousness", 50.0))))
				extraversion = float(str(data.get("extraversion", base_personality.get("extraversion", 50.0))))
				agreeableness = float(str(data.get("agreeableness", base_personality.get("agreeableness", 50.0))))
				neuroticism = float(str(data.get("neuroticism", base_personality.get("neuroticism", 50.0))))
				last_online_time = int(str(data.get("last_online_time", 0)))
				
				# 三维六基
				physical_fitness = float(str(data.get("physical_fitness", 0.0)))
				vitality = float(str(data.get("vitality", 0.0)))
				academic_quality = float(str(data.get("academic_quality", 0.0)))
				knowledge_reserve = float(str(data.get("knowledge_reserve", 0.0)))
				social_eq = float(str(data.get("social_eq", 0.0)))
				creative_aesthetics = float(str(data.get("creative_aesthetics", 0.0)))
				current_energy = float(str(data.get("current_energy", max_energy)))
	else:
		openness = float(str(base_personality.get("openness", 50.0)))
		conscientiousness = float(str(base_personality.get("conscientiousness", 50.0)))
		extraversion = float(str(base_personality.get("extraversion", 50.0)))
		agreeableness = float(str(base_personality.get("agreeableness", 50.0)))
		neuroticism = float(str(base_personality.get("neuroticism", 50.0)))
		
		# 三维六基初始值
		physical_fitness = 0.0
		vitality = 0.0
		academic_quality = 0.0
		knowledge_reserve = 0.0
		social_eq = 0.0
		creative_aesthetics = 0.0
		current_energy = max_energy
	
	init_daily_mood()

func _get_static_data_path() -> String:
	return "res://assets/data/characters/%s.json" % current_character_id

func _get_stage_data_path() -> String:
	return "res://assets/data/characters/%s_stages.json" % current_character_id

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
				if data.has("base_personality"):
					base_personality = data["base_personality"]
	else:
		printerr("Character static data not found: ", path)

func _load_stage_data() -> void:
	var path = _get_stage_data_path()
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		var content = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var error = json.parse(content)
		if error == OK:
			var data = json.get_data()
			if data is Dictionary and data.has("stages"):
				stages_config = data["stages"]
	else:
		printerr("Character stage data not found: ", path)

func init_daily_mood() -> void:
	var today = Time.get_date_string_from_system()
	if last_login_date != today:
		last_login_date = today
		if GameDataManager.mood_system != null:
			current_mood = GameDataManager.mood_system.get_random_mood()
			print("【心情系统】新的一天，抽取的初始心情为: ", current_mood)
		# 跨天恢复满精力
		current_energy = max_energy
		print("【精力系统】新的一天，精力已回满: ", current_energy)
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
		# 获取动态人格倍率
		var personality_mult = GameDataManager.personality_system.get_intimacy_multiplier(self)
		amount = amount * stage_multi * mood_multi * personality_mult
	intimacy = max(intimacy + amount, 0.0)
	check_stage_upgrade()

func update_trust(amount: float) -> void:
	if amount > 0:
		var stage_conf = get_current_stage_config()
		var stage_multi = stage_conf.get("trust_multiplier", 1.0)
		var mood_multi = GameDataManager.mood_system.get_trust_multiplier(current_mood)
		# 信任度同样受人格倍率影响
		var personality_mult = GameDataManager.personality_system.get_intimacy_multiplier(self)
		amount = amount * stage_multi * mood_multi * personality_mult
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
		"interaction_exp": interaction_exp,
		"openness": openness,
		"conscientiousness": conscientiousness,
		"extraversion": extraversion,
		"agreeableness": agreeableness,
		"neuroticism": neuroticism,
		"last_online_time": Time.get_unix_time_from_system(),
		"physical_fitness": physical_fitness,
		"vitality": vitality,
		"academic_quality": academic_quality,
		"knowledge_reserve": knowledge_reserve,
		"social_eq": social_eq,
		"creative_aesthetics": creative_aesthetics,
		"current_energy": current_energy
	}
	var file = FileAccess.open(PROFILE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
