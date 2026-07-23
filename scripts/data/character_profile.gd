class_name CharacterProfile
extends Resource

const SafeFileAccessUtil = preload("res://scripts/utils/safe_file_access.gd")
const PhotoMemoryManagerScript = preload("res://scripts/data/photo_memory_manager.gd")

var char_name: String = ""
var player_name: String = ""
var player_title: String = ""
var player_gender: String = "其他"
var player_birthday: String = ""
var player_zodiac: String = ""
var player_mbti: String = "未选择"
var player_profession: String = "创奇引路人"
var player_avatar_path: String = ""
var age: int = 22
var description: String = ""
var tags: Array = []
var spine_path: String = ""
var sprite_frames_path: String = ""
var desktop_pet_frames_path: String = ""
var avatar: String = ""
var current_outfit: String = "default" # 当前穿着服装的 ID
var current_main_bg_id: String = ""

var intimacy: float = 0.0 # 0-9999
var mood_value: float = 50.0 # 0-100, 长期心情值
var current_expression: String = "calm" # 瞬时表情ID
var last_login_date: String = "" # 用于判断是否跨天
var trust: float = 10.0 # 0-9999
var current_stage: int = 1 # 1-8

var stages_config: Array = []
var base_personality: Dictionary = {}

var openness: float = 50.0
var conscientiousness: float = 50.0
var extraversion: float = 50.0
var agreeableness: float = 50.0
var neuroticism: float = 50.0

var personality_history: Array = [] # 记录过去大五人格的数据，元素格式: {"day_offset": int, "openness": float, ...}
var personality_event_log: Array = [] # 最近人格事件日志
var personality_state: Dictionary = {
	"primary_id": "",
	"primary_desc": "",
	"primary_score": 0.0,
	"secondary_id": "",
	"secondary_desc": "",
	"secondary_score": 0.0,
	"flavor": "Guarded",
	"pending_primary_id": "",
	"pending_primary_streak": 0,
	"pending_secondary_id": "",
	"pending_secondary_streak": 0
}
var last_personality_snapshot_day: int = -1
var personality_tension: Dictionary = _create_default_personality_tension() # 兼容旧字段，等同短期张力
var short_term_personality_tension: Dictionary = _create_default_personality_tension()
var long_term_personality_shaping: Dictionary = _create_default_personality_tension()
var last_personality_settlement: Dictionary = {}
var personality_pattern_state: Dictionary = {}
var companion_streak_days: int = 0
var last_care_event_streak: int = 0

var last_online_time: int = 0

# 四基八维养成体系数值
# 体力 (Physical)
var stat_stamina: float = 0.0 # 体能
var stat_rhythm: float = 0.0 # 反应
# 智力 (Intelligence)
var stat_knowledge: float = 0.0 # 学识
var stat_expression: float = 0.0 # 表达
# 魅力 (Charm)
var stat_temperament: float = 0.0 # 气质
var stat_etiquette: float = 0.0 # 礼仪
# 感性 (Sensibility)
var stat_aesthetics: float = 0.0 # 审美
var stat_perception: float = 0.0 # 感知

var current_energy: int = 20
var max_energy: int = 50
var gold: int = 500

var unlocked_outfits: Array = ["default"] # 已解锁服装的 ID 列表

var course_progress: Dictionary = {}

var diaries: Array = []
var finished_stories: Array = []
var concern_template_state: Dictionary = {}

signal stage_upgraded(new_stage: int)
signal profile_updated()

const DEFAULT_PLAYER_AVATAR_MALE = "res://assets/images/ui/player/avatar_male.svg"
const DEFAULT_PLAYER_AVATAR_FEMALE = "res://assets/images/ui/player/avatar_female.svg"
const DEFAULT_PLAYER_AVATAR_OTHER = "res://assets/images/ui/player/avatar_other.svg"
var current_character_id: String = ""

func get_profile_path() -> String:
	var char_id = current_character_id
	if char_id == "": char_id = "default"
	if GameDataManager:
		return GameDataManager.get_character_save_path("character_profile.json", char_id)
	var dir_path = "user://saves/%s" % char_id
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)
	return "%s/character_profile.json" % dir_path

func _init():
	pass

func _create_default_personality_tension() -> Dictionary:
	return {
		"openness": 0.0,
		"conscientiousness": 0.0,
		"extraversion": 0.0,
		"agreeableness": 0.0,
		"neuroticism": 0.0
	}

func _reset_dynamic_state() -> void:
	player_name = ""
	player_title = ""
	player_gender = "其他"
	player_birthday = ""
	player_zodiac = ""
	player_mbti = "未选择"
	player_profession = "创奇引路人"
	player_avatar_path = ""
	intimacy = 0.0
	mood_value = 50.0
	current_expression = "calm"
	last_login_date = ""
	trust = 10.0
	current_stage = 1
	personality_history = []
	personality_event_log = []
	personality_state = {
		"primary_id": "",
		"primary_desc": "",
		"primary_score": 0.0,
		"secondary_id": "",
		"secondary_desc": "",
		"secondary_score": 0.0,
		"flavor": "Guarded",
		"pending_primary_id": "",
		"pending_primary_streak": 0,
		"pending_secondary_id": "",
		"pending_secondary_streak": 0
	}
	last_personality_snapshot_day = -1
	personality_tension = _create_default_personality_tension()
	short_term_personality_tension = _create_default_personality_tension()
	long_term_personality_shaping = _create_default_personality_tension()
	last_personality_settlement = {}
	personality_pattern_state = {}
	companion_streak_days = 0
	last_care_event_streak = 0
	last_online_time = 0
	current_outfit = "default"
	current_main_bg_id = ""
	unlocked_outfits = ["default"]
	gold = 500
	course_progress = {}
	diaries = []
	finished_stories = []

func load_profile(force_char_id: String = "") -> void:
	# 确定要加载的角色ID
	if force_char_id != "":
		current_character_id = force_char_id
	elif GameDataManager.config and GameDataManager.config.current_character_id != "":
		current_character_id = GameDataManager.config.current_character_id
	else:
		# 如果未配置，优先寻找外部目录
		var ext_dir = DirAccess.open("user://game_data/characters")
		if ext_dir:
			ext_dir.list_dir_begin()
			var folder_name = ext_dir.get_next()
			while folder_name != "":
				if ext_dir.current_is_dir() and not folder_name.begins_with("."):
					if FileAccess.file_exists("user://game_data/characters/" + folder_name + "/settings.json"):
						current_character_id = folder_name
						break
				folder_name = ext_dir.get_next()
				
		# 否则寻找内置目录
		if current_character_id == "":
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
		elif GameDataManager.config:
			GameDataManager.config.current_character_id = current_character_id
			GameDataManager.config.save_config()
			
	# 先加载静态数据
	_load_static_data()
	_load_stage_data()
	_reset_dynamic_state()
	
	# 如果当前角色文件不存在，但 base_personality 是在上一次加载的，我们需要先把它重置掉，
	# 因为 static_data 里的加载是只有在有数据时才会覆盖
	if not FileAccess.file_exists(_get_static_data_path()):
		base_personality = {
			"openness": 50.0,
			"conscientiousness": 50.0,
			"extraversion": 50.0,
			"agreeableness": 50.0,
			"neuroticism": 50.0
		}
	
	# 加载动态存档
	var path = get_profile_path()
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		var content = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var error = json.parse(content)
		if error == OK:
			var data = json.get_data()
			if data is Dictionary:
				player_name = data.get("player_name", player_name)
				player_title = data.get("player_title", player_title)
				player_gender = data.get("player_gender", player_gender)
				player_birthday = data.get("player_birthday", player_birthday)
				player_zodiac = data.get("player_zodiac", player_zodiac)
				player_mbti = data.get("player_mbti", player_mbti)
				player_profession = data.get("player_profession", player_profession)
				player_avatar_path = data.get("player_avatar_path", player_avatar_path)
				intimacy = float(str(data.get("intimacy", intimacy)))
				mood_value = float(str(data.get("mood_value", 50.0)))
				current_expression = data.get("current_expression", "calm")
				
				last_login_date = data.get("last_login_date", last_login_date)
				trust = float(str(data.get("trust", trust)))
				current_stage = int(str(data.get("current_stage", current_stage)))
				openness = float(str(data.get("openness", base_personality.get("openness", 50.0))))
				conscientiousness = float(str(data.get("conscientiousness", base_personality.get("conscientiousness", 50.0))))
				extraversion = float(str(data.get("extraversion", base_personality.get("extraversion", 50.0))))
				agreeableness = float(str(data.get("agreeableness", base_personality.get("agreeableness", 50.0))))
				neuroticism = float(str(data.get("neuroticism", base_personality.get("neuroticism", 50.0))))
				
				personality_history = data.get("personality_history", [])
				personality_event_log = data.get("personality_event_log", [])
				personality_state = data.get("personality_state", personality_state)
				if not (personality_state is Dictionary):
					personality_state = {}
				var default_personality_state: Dictionary = {
					"primary_id": "",
					"primary_desc": "",
					"primary_score": 0.0,
					"secondary_id": "",
					"secondary_desc": "",
					"secondary_score": 0.0,
					"flavor": "Guarded",
					"pending_primary_id": "",
					"pending_primary_streak": 0,
					"pending_secondary_id": "",
					"pending_secondary_streak": 0
				}
				for state_key in default_personality_state.keys():
					if not personality_state.has(state_key):
						personality_state[state_key] = default_personality_state[state_key]
				last_personality_snapshot_day = int(str(data.get("last_personality_snapshot_day", -1)))
				personality_tension = data.get("personality_tension", data.get("personality_pressure", _create_default_personality_tension()))
				short_term_personality_tension = data.get("short_term_personality_tension", data.get("short_term_personality_pressure", personality_tension.duplicate(true)))
				long_term_personality_shaping = data.get("long_term_personality_shaping", data.get("long_term_personality_pressure", _create_default_personality_tension()))
				last_personality_settlement = data.get("last_personality_settlement", {})
				personality_pattern_state = data.get("personality_pattern_state", {})
				companion_streak_days = int(str(data.get("companion_streak_days", 0)))
				last_care_event_streak = int(str(data.get("last_care_event_streak", 0)))
				
				last_online_time = int(str(data.get("last_online_time", 0)))
				
				# 四基八维
				stat_stamina = float(str(data.get("stat_stamina", 0.0)))
				stat_rhythm = float(str(data.get("stat_rhythm", 0.0)))
				stat_knowledge = float(str(data.get("stat_knowledge", data.get("stat_artistic_literacy", 0.0))))
				stat_expression = float(str(data.get("stat_expression", data.get("stat_verbal_expression", 0.0))))
				stat_temperament = float(str(data.get("stat_temperament", 0.0)))
				stat_etiquette = float(str(data.get("stat_etiquette", data.get("stat_emotional_infection", 0.0))))
				stat_aesthetics = float(str(data.get("stat_aesthetics", 0.0)))
				stat_perception = float(str(data.get("stat_perception", data.get("stat_art_perception", 0.0))))
				current_energy = int(str(data.get("current_energy", max_energy)))
				current_outfit = data.get("current_outfit", "default")
				var default_main_bg_id := ""
				if GameDataManager.config:
					default_main_bg_id = str(GameDataManager.config.current_main_bg_id)
				current_main_bg_id = str(data.get("current_main_bg_id", default_main_bg_id)).strip_edges()
				unlocked_outfits = data.get("unlocked_outfits", ["default"])
				gold = int(str(data.get("gold", 500)))
				course_progress = data.get("course_progress", {})
				diaries = data.get("diaries", [])
				finished_stories = data.get("finished_stories", [])
				concern_template_state = data.get("concern_template_state", {})
	else:
		openness = float(str(base_personality.get("openness", 50.0)))
		conscientiousness = float(str(base_personality.get("conscientiousness", 50.0)))
		extraversion = float(str(base_personality.get("extraversion", 50.0)))
		agreeableness = float(str(base_personality.get("agreeableness", 50.0)))
		neuroticism = float(str(base_personality.get("neuroticism", 50.0)))
		
		# 四基八维初始值
		stat_stamina = 0.0
		stat_rhythm = 0.0
		stat_knowledge = 0.0
		stat_expression = 0.0
		stat_temperament = 0.0
		stat_etiquette = 0.0
		stat_aesthetics = 0.0
		stat_perception = 0.0
		current_energy = max_energy
	
	init_daily_mood()
	if GameDataManager.personality_system and GameDataManager.personality_system.has_method("resolve_archetype_state"):
		personality_state = GameDataManager.personality_system.resolve_archetype_state(self)
	_bind_event_manager()
	profile_updated.emit()

func _bind_event_manager() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return

	var event_manager = tree.root.get_node_or_null("EventManager")
	if event_manager == null or not event_manager.has_signal("event_triggered"):
		return

	var callback := Callable(self, "_on_event_triggered")
	if not event_manager.is_connected("event_triggered", callback):
		event_manager.connect("event_triggered", callback)

func _on_event_triggered(_event_id: String, _params: Dictionary) -> void:
	# 里程碑剧情触发后立即重算，避免玩家已经达标却还要再互动一次才升阶。
	check_stage_upgrade()

func _get_static_data_path() -> String:
	# 优先检查外部动态目录
	var ext_path = "user://game_data/characters/%s/settings.json" % current_character_id
	if FileAccess.file_exists(ext_path):
		return ext_path
	
	# 兼容 npc 目录
	var npc_path = "res://assets/data/characters/npc/%s.json" % current_character_id
	if FileAccess.file_exists(npc_path):
		return npc_path
		
	return "res://assets/data/characters/%s.json" % current_character_id

func _get_stage_data_path() -> String:
	var ext_path = "user://game_data/characters/%s/stages.json" % current_character_id
	if FileAccess.file_exists(ext_path):
		return ext_path
		
	# 兼容 npc 目录
	var npc_path = "res://assets/data/characters/npc/%s_stages.json" % current_character_id
	if FileAccess.file_exists(npc_path):
		return npc_path
		
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
				char_name = data.get("char_name", "")
				age = data.get("age", 22)
				spine_path = data.get("spine_path", "")
				sprite_frames_path = data.get("sprite_frames_path", "")
				desktop_pet_frames_path = data.get("desktop_pet_frames_path", "")
				avatar = data.get("avatar", "")
				description = data.get("identity_background", "")
				tags = data.get("tags", [])
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

func update_expression(expression_id: String) -> void:
	if GameDataManager.expression_system.is_valid_expression(expression_id):
		current_expression = expression_id
		save_profile()

func init_daily_mood() -> void:
	var today = Time.get_date_string_from_system()
	if last_login_date != today:
		var previous_login_date = last_login_date
		last_login_date = today
		_update_companion_streak(previous_login_date, today)
		if GameDataManager.mood_system != null:
			print("【心情系统】新的一天，当前心情数值为: ", mood_value)
		# 跨天恢复满精力
		current_energy = max_energy
		print("【精力系统】新的一天，精力已回满: ", current_energy)
		save_profile()

func record_daily_personality(day_offset: int) -> void:
	record_personality_snapshot("daily", false, day_offset)

func record_personality_snapshot(reason: String = "manual", force: bool = false, day_offset: int = -999999) -> void:
	var final_day_offset = day_offset
	if final_day_offset == -999999:
		final_day_offset = GameDataManager.story_time_manager.current_day_offset if GameDataManager.story_time_manager else 0
	if not force and reason == "daily" and last_personality_snapshot_day == final_day_offset:
		return
	var snapshot = {
		"day_offset": final_day_offset,
		"reason": reason,
		"timestamp": Time.get_unix_time_from_system(),
		"openness": openness,
		"conscientiousness": conscientiousness,
		"extraversion": extraversion,
		"agreeableness": agreeableness,
		"neuroticism": neuroticism,
		"personality_state": personality_state.duplicate(true)
	}
	if not force and not personality_history.is_empty():
		var last_snapshot = personality_history[personality_history.size() - 1]
		if last_snapshot is Dictionary:
			var same_day = int(last_snapshot.get("day_offset", -999998)) == final_day_offset
			var same_values = true
			same_values = same_values and abs(float(last_snapshot.get("openness", 0.0)) - openness) <= 0.01
			same_values = same_values and abs(float(last_snapshot.get("conscientiousness", 0.0)) - conscientiousness) <= 0.01
			same_values = same_values and abs(float(last_snapshot.get("extraversion", 0.0)) - extraversion) <= 0.01
			same_values = same_values and abs(float(last_snapshot.get("agreeableness", 0.0)) - agreeableness) <= 0.01
			same_values = same_values and abs(float(last_snapshot.get("neuroticism", 0.0)) - neuroticism) <= 0.01
			if same_day and same_values:
				return
	personality_history.append(snapshot)
	if personality_history.size() > 30:
		personality_history.pop_front()
	last_personality_snapshot_day = final_day_offset
	save_profile()

func append_personality_event(event_data: Dictionary) -> void:
	if event_data.is_empty():
		return
	personality_event_log.append(event_data.duplicate(true))
	if personality_event_log.size() > 40:
		personality_event_log.pop_front()

func get_recent_personality_events(limit: int = 5) -> Array:
	var final_limit = max(limit, 1)
	if personality_event_log.size() <= final_limit:
		return personality_event_log.duplicate(true)
	return personality_event_log.slice(personality_event_log.size() - final_limit, personality_event_log.size())

func refresh_personality_state() -> void:
	if GameDataManager.personality_system and GameDataManager.personality_system.has_method("resolve_archetype_state"):
		personality_state = GameDataManager.personality_system.resolve_archetype_state(self)
	save_profile()

func get_companion_streak_summary() -> String:
	if companion_streak_days <= 0:
		return "连续陪伴：暂无记录"
	return "连续陪伴：%d 天" % companion_streak_days

func get_personality_tension_summary() -> String:
	var short_summary = _build_tension_summary("短期张力", short_term_personality_tension)
	var long_summary = _build_tension_summary("长期塑形", long_term_personality_shaping)
	return short_summary + "\n" + long_summary

func get_personality_mood_summary() -> String:
	var mood_name = "平静"
	if GameDataManager.mood_system:
		mood_name = GameDataManager.mood_system.get_macro_mood_name(mood_value)
	return "当前心情：%s（%.0f）" % [mood_name, mood_value]

func get_personality_pattern_summary() -> String:
	if personality_pattern_state.is_empty():
		return "连续模式：暂无"
	var parts: Array = []
	for pattern_key in personality_pattern_state.keys():
		var item = personality_pattern_state.get(pattern_key, {})
		if not item is Dictionary:
			continue
		var streak = int(item.get("streak", 0))
		if streak < 2:
			continue
		var label = str(item.get("label", pattern_key))
		parts.append("%s x%d" % [label, streak])
	if parts.is_empty():
		return "连续模式：暂无"
	return "连续模式：" + " / ".join(parts)

func _build_tension_summary(prefix: String, pressure_data: Dictionary) -> String:
	var parts: Array = []
	for trait_name in pressure_data.keys():
		var value = float(pressure_data.get(trait_name, 0.0))
		if abs(value) < 0.05:
			continue
		var value_prefix = "+" if value > 0 else ""
		parts.append("%s %s%.2f" % [_get_personality_trait_short_name(str(trait_name)), value_prefix, value])
	if parts.is_empty():
		return "%s：当前平稳" % prefix
	return "%s：%s" % [prefix, " / ".join(parts)]

func _get_personality_trait_short_name(trait_name: String) -> String:
	match trait_name:
		"openness":
			return "O"
		"conscientiousness":
			return "C"
		"extraversion":
			return "E"
		"agreeableness":
			return "A"
		"neuroticism":
			return "N"
		_:
			return trait_name

func get_stage_config(stage_num: int) -> Dictionary:
	for config in stages_config:
		if config["stage"] == stage_num:
			return config
	return {}

func get_current_stage_config() -> Dictionary:
	return get_stage_config(current_stage)

func _emit_profile_changed(trigger_auto_save: bool = false) -> void:
	save_profile()
	profile_updated.emit()
	if trigger_auto_save and GameDataManager.save_manager:
		GameDataManager.save_manager.call_deferred("auto_save")

func _get_stage_resonance_target(stage_num: int) -> float:
	var clamped_stage = clamp(stage_num, 1, max(stages_config.size(), 1))
	var lower_bound = 0.0
	if clamped_stage > 1:
		lower_bound = float(get_stage_config(clamped_stage - 1).get("resonance_threshold", 0.0))
	var upper_bound = float(get_stage_config(clamped_stage).get("resonance_threshold", lower_bound + 80.0))
	if upper_bound <= lower_bound or upper_bound >= 9999.0:
		upper_bound = lower_bound + 120.0
	return lower_bound + (upper_bound - lower_bound) * 0.5

func _sync_relationship_metrics_for_stage(stage_num: int) -> void:
	var target_resonance = _get_stage_resonance_target(stage_num)
	var per_stat_value = max(target_resonance / 2.0, 0.0)
	intimacy = per_stat_value
	trust = per_stat_value

func force_set_stage(new_stage: int, sync_relationship_metrics: bool = true) -> void:
	current_stage = clamp(new_stage, 1, max(stages_config.size(), 1))
	if sync_relationship_metrics:
		_sync_relationship_metrics_for_stage(current_stage)
	_emit_profile_changed(true)

func _blend_relationship_multiplier(raw_multiplier: float, influence: float) -> float:
	var clamped_multiplier = clampf(raw_multiplier, 0.65, 1.55)
	return lerpf(1.0, clamped_multiplier, influence)

func _get_next_stage_soft_requirement(stat_name: String) -> float:
	var next_conf = get_stage_config(current_stage + 1)
	if not next_conf.is_empty():
		var next_threshold = float(next_conf.get("resonance_threshold", 0.0))
		if stat_name == "intimacy":
			return float(next_conf.get("min_intimacy", maxf(12.0, next_threshold * 0.38)))
		return float(next_conf.get("min_trust", maxf(12.0, next_threshold * 0.38)))
	var current_target = _get_stage_resonance_target(current_stage)
	return maxf(12.0, current_target / 2.0)

func _shape_relationship_delta(amount: float, stat_name: String) -> float:
	if absf(amount) <= 0.001:
		return 0.0
	var stage_conf = get_current_stage_config()
	var current_value = intimacy if stat_name == "intimacy" else trust
	var other_value = trust if stat_name == "intimacy" else intimacy
	var stage_multiplier = float(stage_conf.get("%s_multiplier" % stat_name, 1.0))
	var mood_multiplier = GameDataManager.mood_system.get_intimacy_multiplier(mood_value) if stat_name == "intimacy" else GameDataManager.mood_system.get_trust_multiplier(mood_value)
	var personality_multiplier = GameDataManager.personality_system.get_intimacy_multiplier(self) if stat_name == "intimacy" else GameDataManager.personality_system.get_trust_multiplier(self)
	var blended_multiplier = _blend_relationship_multiplier(stage_multiplier, 0.24)
	blended_multiplier *= _blend_relationship_multiplier(mood_multiplier, 0.33)
	blended_multiplier *= _blend_relationship_multiplier(personality_multiplier, 0.20)
	blended_multiplier = clampf(blended_multiplier, 0.78, 1.28)
	var shaped_amount = amount
	var soft_requirement = _get_next_stage_soft_requirement(stat_name)
	if amount > 0.0:
		shaped_amount *= blended_multiplier
		if current_value > soft_requirement:
			var overshoot_ratio = (current_value - soft_requirement) / maxf(soft_requirement, 20.0)
			shaped_amount *= clampf(1.0 / (1.0 + overshoot_ratio * 1.35), 0.35, 1.0)
		var gap_limit = float(stage_conf.get("max_relationship_gap", maxf(20.0, float(stage_conf.get("resonance_threshold", 0.0)) * 0.32)))
		var relation_gap = current_value - other_value
		if gap_limit > 0.0:
			if relation_gap > gap_limit * 0.55:
				var gap_ratio = (relation_gap - gap_limit * 0.55) / maxf(gap_limit, 1.0)
				shaped_amount *= clampf(1.0 - gap_ratio * 0.55, 0.38, 1.0)
			elif relation_gap < -gap_limit * 0.35:
				var catchup_ratio = minf(absf(relation_gap) / maxf(gap_limit, 1.0), 1.0)
				shaped_amount *= lerpf(1.0, 1.08, catchup_ratio)
	else:
		var stability_ratio = clampf(current_value / maxf(soft_requirement, 20.0), 0.25, 1.75)
		var negative_scale = lerpf(0.82, 1.05, (stability_ratio - 0.25) / 1.5)
		shaped_amount *= negative_scale
		if current_value <= 12.0:
			shaped_amount *= 0.6
	return shaped_amount

func update_intimacy(amount: float) -> void:
	var previous_stage = current_stage
	amount = _shape_relationship_delta(amount, "intimacy")
	intimacy = max(intimacy + amount, 0.0)
	check_stage_upgrade()
	if current_stage == previous_stage:
		profile_updated.emit()

func update_trust(amount: float) -> void:
	var previous_stage = current_stage
	amount = _shape_relationship_delta(amount, "trust")
	trust = max(trust + amount, 0.0)
	check_stage_upgrade()
	if current_stage == previous_stage:
		profile_updated.emit()

func check_stage_upgrade() -> void:
	var stage_conf = get_current_stage_config()
	if stage_conf.is_empty(): return
	
	# 获取升阶的共感值门槛 (共感值 = 亲密 + 信任)
	var resonance_threshold = float(stage_conf.get("resonance_threshold", 0))
	var current_resonance = intimacy + trust
	var min_intimacy = float(stage_conf.get("min_intimacy", maxf(8.0, resonance_threshold * 0.38)))
	var min_trust = float(stage_conf.get("min_trust", maxf(8.0, resonance_threshold * 0.38)))
	var max_relationship_gap = float(stage_conf.get("max_relationship_gap", maxf(20.0, resonance_threshold * 0.32)))
	var require_balanced_relationship = bool(stage_conf.get("require_balanced_relationship", true))
	var is_split_met = intimacy >= min_intimacy and trust >= min_trust
	var is_gap_met = true
	if require_balanced_relationship:
		is_gap_met = absf(intimacy - trust) <= max_relationship_gap
	
	# 获取升阶的里程碑剧情限制，统一使用 milestone_story。
	var milestone_story = str(stage_conf.get("milestone_story", "")).strip_edges()
	var is_milestone_met = true
	if milestone_story != "":
		# GameDataManager 已经作为 Autoload 存在，而且 event_manager 也是 autoload (或者通过其他方式访问)
		# 因为 event_manager 是 Autoload 的 "EventManager"，可以直接通过 Engine/SceneTree 获取
		var event_manager = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("EventManager")
		if event_manager and event_manager.has_method("is_event_triggered"):
			is_milestone_met = event_manager.is_event_triggered(milestone_story)
		else:
			# 如果配置了里程碑但系统未就绪，则判定为不满足
			is_milestone_met = false
	
	# 只有总共感、分项关系和阶段叙事门槛都满足时，才允许升阶。
	if current_stage < 9 and current_resonance >= resonance_threshold and is_milestone_met and is_split_met and is_gap_met:
		current_stage += 1
		
		print("【情感系统】升阶！当前阶段: Stage %d" % current_stage)
		if GameDataManager.personality_system and GameDataManager.personality_system.has_method("apply_personality_event"):
			GameDataManager.personality_system.apply_personality_event(self, "stage_upgraded", {
				"stage": current_stage,
				"force_log": true
			})
			GameDataManager.personality_system.settle_personality_tension(self, "stage_upgraded", {
				"short_settle_scale": 0.8,
				"long_settle_scale": 0.35,
				"force_log": true,
				"force_snapshot": true
			})
		
		stage_upgraded.emit(current_stage)
		_emit_profile_changed(true)

func consume_energy(amount: int) -> bool:
	if current_energy >= amount:
		current_energy -= amount
		save_profile()
		profile_updated.emit()
		return true
	return false

func get_player_avatar_path() -> String:
	var candidates: Array[String] = []
	if player_avatar_path.strip_edges() != "":
		candidates.append(player_avatar_path.strip_edges())

	match player_gender:
		"男":
			candidates.append(DEFAULT_PLAYER_AVATAR_MALE)
		"女":
			candidates.append(DEFAULT_PLAYER_AVATAR_FEMALE)
		_:
			candidates.append(DEFAULT_PLAYER_AVATAR_OTHER)

	candidates.append(DEFAULT_PLAYER_AVATAR_OTHER)

	for candidate in candidates:
		if _path_exists(candidate):
			return candidate

	return "res://icon.svg"

func get_player_avatar_texture() -> Texture2D:
	return _load_texture_from_path(get_player_avatar_path())

func _path_exists(path: String) -> bool:
	if path.strip_edges() == "":
		return false
	if path.begins_with("res://"):
		return ResourceLoader.exists(path) or FileAccess.file_exists(path)
	return FileAccess.file_exists(path)

func _load_texture_from_path(path: String) -> Texture2D:
	if path.strip_edges() == "":
		return null

	if path.begins_with("res://") and ResourceLoader.exists(path):
		var res = load(path)
		return res if res is Texture2D else null

	if path.begins_with("user://"):
		if FileAccess.file_exists(path):
			var img = Image.new()
			var err = img.load(path)
			if err == OK and not img.is_empty():
				return ImageTexture.create_from_image(img)
		return null

	if FileAccess.file_exists(path):
		var image = Image.load_from_file(path)
		if image and not image.is_empty():
			return ImageTexture.create_from_image(image)

	return null

func save_profile() -> bool:
	var data = {
		"player_name": player_name,
		"player_title": player_title,
		"player_gender": player_gender,
		"player_birthday": player_birthday,
		"player_zodiac": player_zodiac,
		"player_mbti": player_mbti,
		"player_profession": player_profession,
		"player_avatar_path": player_avatar_path,
		"intimacy": intimacy,
		"mood_value": mood_value,
		"current_expression": current_expression,
		"last_login_date": last_login_date,
		"trust": trust,
		"current_stage": current_stage,
		"openness": openness,
		"conscientiousness": conscientiousness,
		"extraversion": extraversion,
		"agreeableness": agreeableness,
		"neuroticism": neuroticism,
		"personality_history": personality_history,
		"personality_event_log": personality_event_log,
		"personality_state": personality_state,
		"last_personality_snapshot_day": last_personality_snapshot_day,
		"personality_tension": personality_tension,
		"short_term_personality_tension": short_term_personality_tension,
		"long_term_personality_shaping": long_term_personality_shaping,
		"last_personality_settlement": last_personality_settlement,
		"personality_pattern_state": personality_pattern_state,
		"companion_streak_days": companion_streak_days,
		"last_care_event_streak": last_care_event_streak,
		"last_online_time": Time.get_unix_time_from_system(),
		"stat_stamina": stat_stamina,
		"stat_rhythm": stat_rhythm,
		"stat_knowledge": stat_knowledge,
		"stat_expression": stat_expression,
		"stat_temperament": stat_temperament,
		"stat_etiquette": stat_etiquette,
		"stat_aesthetics": stat_aesthetics,
		"stat_perception": stat_perception,
		"current_energy": current_energy,
		"current_outfit": current_outfit,
		"current_main_bg_id": current_main_bg_id,
		"unlocked_outfits": unlocked_outfits,
		"gold": gold,
		"course_progress": course_progress,
		"diaries": diaries,
		"finished_stories": finished_stories,
		"concern_template_state": concern_template_state
	}
	var content = JSON.stringify(data, "\t")
	return SafeFileAccessUtil.store_string(get_profile_path(), content)

func _update_companion_streak(previous_date: String, current_date: String) -> void:
	if current_date.strip_edges() == "":
		return
	if previous_date.strip_edges() == "":
		companion_streak_days = max(companion_streak_days, 1)
		return
	if previous_date == current_date:
		return
	if _is_next_real_date(previous_date, current_date):
		companion_streak_days += 1
	else:
		companion_streak_days = 1

	if companion_streak_days >= 3 and companion_streak_days > last_care_event_streak:
		last_care_event_streak = companion_streak_days
		if GameDataManager.personality_system and GameDataManager.personality_system.has_method("apply_personality_event"):
			GameDataManager.personality_system.apply_personality_event(self, "player_consistent_care", {
				"intensity": 1.0 + float(companion_streak_days - 3) * 0.15,
				"streak_days": companion_streak_days,
				"force_log": true,
				"force_snapshot": companion_streak_days % 3 == 0
			})

func _is_next_real_date(previous_date: String, current_date: String) -> bool:
	var previous_parts = previous_date.split("-")
	var current_parts = current_date.split("-")
	if previous_parts.size() != 3 or current_parts.size() != 3:
		return false
	var previous_dict = {
		"year": int(previous_parts[0]),
		"month": int(previous_parts[1]),
		"day": int(previous_parts[2]),
		"hour": 0,
		"minute": 0,
		"second": 0
	}
	var current_dict = {
		"year": int(current_parts[0]),
		"month": int(current_parts[1]),
		"day": int(current_parts[2]),
		"hour": 0,
		"minute": 0,
		"second": 0
	}
	var previous_unix = Time.get_unix_time_from_datetime_dict(previous_dict)
	var current_unix = Time.get_unix_time_from_datetime_dict(current_dict)
	return int(current_unix - previous_unix) == 86400

func get_diaries() -> Array:
	return diaries

func add_diary(diary_entry: Dictionary) -> void:
	diaries.append(diary_entry)
	_register_diary_images(diary_entry)
	profile_updated.emit()
	save_profile()
	if GameDataManager.save_manager and GameDataManager.save_manager.has_method("auto_save"):
		GameDataManager.save_manager.call_deferred("auto_save")

func mark_story_finished(story_id: String) -> void:
	if not finished_stories.has(story_id):
		finished_stories.append(story_id)
		if GameDataManager.personality_system and GameDataManager.personality_system.has_method("apply_personality_event"):
			GameDataManager.personality_system.apply_personality_event(self, "story_milestone", {
				"story_id": story_id,
				"force_log": true
			})
		save_profile()
		if GameDataManager.save_manager:
			GameDataManager.save_manager.call_deferred("auto_save")

func unmark_story_finished(story_id: String) -> void:
	var normalized_story_id := story_id.strip_edges()
	if normalized_story_id == "":
		return
	if not finished_stories.has(normalized_story_id):
		return
	finished_stories.erase(normalized_story_id)
	profile_updated.emit()
	save_profile()
	if GameDataManager.save_manager:
		GameDataManager.save_manager.call_deferred("auto_save")

func clear_finished_stories() -> void:
	if finished_stories.is_empty():
		return
	finished_stories.clear()
	profile_updated.emit()
	save_profile()
	if GameDataManager.save_manager:
		GameDataManager.save_manager.call_deferred("auto_save")

func has_finished_story(story_id: String) -> bool:
	return finished_stories.has(story_id)

func _register_diary_images(diary_entry: Dictionary) -> void:
	var image_paths: Array = []
	if diary_entry.has("images") and diary_entry["images"] is Array:
		for image_path in diary_entry["images"]:
			if typeof(image_path) == TYPE_STRING and str(image_path).strip_edges() != "":
				image_paths.append(str(image_path))
	if str(diary_entry.get("image_url", "")).strip_edges() != "":
		image_paths.append(str(diary_entry.get("image_url", "")))
	if image_paths.is_empty():
		return
	var photo_manager = PhotoMemoryManagerScript.new()
	var context = GameDataManager.memory_manager.build_story_memory_context() if GameDataManager.memory_manager else {}
	context["context_domain"] = "story"
	if str(diary_entry.get("date", "")).strip_edges() != "":
		context["story_time"] = str(diary_entry.get("date", ""))
	if str(diary_entry.get("weather", "")).strip_edges() != "":
		context["story_weather"] = str(diary_entry.get("weather", ""))
	var diary_id = str(diary_entry.get("id", diary_entry.get("date", "")))
	for image_path in image_paths:
		if GameDataManager.config and str(GameDataManager.config.default_image_path) == image_path:
			continue
		photo_manager.register_photo(image_path, "diary_image", {
			"album_category": "diary",
			"memory_context": context,
			"preferred_layers": ["bond", "emotion"],
			"source_title": "她写下的一页心情",
			"source_text": str(diary_entry.get("content", "")),
			"source_id": diary_id,
			"source_char_id": str(current_character_id)
		})
	
func get_recent_chat_history_text(limit: int = 10) -> String:
	return _build_recent_chat_history_text(get_chat_history("auto"), limit)

func get_recent_chat_history_text_by_type(history_type: String, limit: int = 10) -> String:
	return _build_recent_chat_history_text(get_chat_history(history_type), limit)

func _build_recent_chat_history_text(history: Array, limit: int) -> String:
	var history_text = ""
	var start_idx = max(0, history.size() - limit)
	
	for i in range(start_idx, history.size()):
		var msg = history[i]
		var sender = msg.get("sender", char_name)
		history_text += sender + "：" + msg.get("content", "") + "\n"
		
	return history_text

func get_chat_history(history_type: String = "auto") -> Array:
	if GameDataManager == null or GameDataManager.history == null:
		return []
	
	var raw_messages: Array = []
	if history_type == "auto":
		raw_messages = GameDataManager.history.messages
	else:
		raw_messages = GameDataManager.history.get_messages_by_type(history_type)
	
	var normalized_history: Array = []
	for raw_msg in raw_messages:
		if typeof(raw_msg) != TYPE_DICTIONARY:
			continue
		
		var speaker = str(raw_msg.get("speaker", ""))
		var content = str(raw_msg.get("text", ""))
		if content.strip_edges() == "":
			continue
		
		var is_user = speaker == "我" or speaker == "玩家" or speaker == "player"
		normalized_history.append({
			"sender": "玩家" if is_user else (speaker if speaker != "" else char_name),
			"content": content,
			"is_user": is_user,
			"type": raw_msg.get("type", "normal"),
			"time": raw_msg.get("time", "")
		})
	
	return normalized_history
