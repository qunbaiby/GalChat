class_name GiftManager
extends Node

var _db_path: String = "res://assets/data/interaction/gift/gifts.json"
const STATE_FILE_NAME := "gift_state.json"
var gifts: Array = []

# 用于防止刷数值的衰减队列：结构为 [{ "id": gift_id, "time": timestamp }, ...]
var _recent_gifts: Array = []
const DECAY_WINDOW_SEC = 3600 * 24 # 24小时内的送礼会触发衰减
const GIFT_ACTION_COST = 10 # 统一的送礼行动力消耗

func _ready() -> void:
	_load_gifts_db()

func _get_current_char_id() -> String:
	if GameDataManager.profile and str(GameDataManager.profile.current_character_id) != "":
		return str(GameDataManager.profile.current_character_id)
	if GameDataManager.config and str(GameDataManager.config.current_character_id) != "":
		return str(GameDataManager.config.current_character_id)
	return "default"

func _get_state_path(char_id: String = "") -> String:
	var final_char_id = char_id.strip_edges()
	if final_char_id == "":
		final_char_id = _get_current_char_id()
	return "user://saves/%s/%s" % [final_char_id, STATE_FILE_NAME]

func reload_for_current_character(char_id: String = "") -> void:
	_load_state(char_id)

func save_state() -> void:
	var state_path = _get_state_path()
	var dir_path = state_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)
	var valid_recent: Array = []
	var now = Time.get_unix_time_from_system()
	for record in _recent_gifts:
		if not record is Dictionary:
			continue
		if now - int(record.get("time", 0)) <= DECAY_WINDOW_SEC:
			valid_recent.append(record)
	var file = FileAccess.open(state_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({
			"recent_gifts": valid_recent
		}, "\t"))
		file.close()

func _load_state(char_id: String = "") -> void:
	_recent_gifts = []
	var state_path = _get_state_path(char_id)
	if not FileAccess.file_exists(state_path):
		return
	var file = FileAccess.open(state_path, FileAccess.READ)
	if file == null:
		return
	var json = JSON.new()
	var result = json.parse(file.get_as_text())
	file.close()
	if result != OK or not json.data is Dictionary:
		return
	var data = json.data
	var now = Time.get_unix_time_from_system()
	for record in data.get("recent_gifts", []):
		if not record is Dictionary:
			continue
		if now - int(record.get("time", 0)) <= DECAY_WINDOW_SEC:
			_recent_gifts.append(record)

func _load_gifts_db() -> void:
	if not FileAccess.file_exists(_db_path):
		printerr("Gift DB not found at: ", _db_path)
		return
		
	var file = FileAccess.open(_db_path, FileAccess.READ)
	var json_str = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var err = json.parse(json_str)
	if err == OK:
		var data = json.get_data()
		if data is Dictionary and data.has("gifts"):
			gifts = data["gifts"]
		print("Loaded gifts DB: %d gifts" % gifts.size())
	else:
		printerr("Failed to parse gifts JSON: ", json.get_error_message())

func get_all_gifts() -> Array:
	return gifts

func get_gift_by_id(gift_id: String) -> Dictionary:
	for g in gifts:
		if g.id == gift_id:
			return g
	return {}

# 根据情感阶段（Stage）获取礼物加成倍率
func _get_stage_multiplier(stage: int, category: String) -> Dictionary:
	# 返回 {"intimacy": float, "trust": float}
	match stage:
		1: # 陌生人阶段：昂贵礼物增加信任，普通礼物效果一般，手工礼物可能会觉得突兀
			if category == "expensive": return {"intimacy": 0.5, "trust": 2.0}
			if category == "special": return {"intimacy": 0.2, "trust": 0.5}
			return {"intimacy": 1.0, "trust": 1.0}
		2: # 熟人阶段：均衡
			if category == "expensive": return {"intimacy": 1.0, "trust": 1.5}
			if category == "special": return {"intimacy": 1.5, "trust": 1.0}
			return {"intimacy": 1.2, "trust": 1.2}
		3: # 暧昧/恋人阶段：手工礼物大幅增加亲密，昂贵礼物不再特别加信任
			if category == "expensive": return {"intimacy": 1.5, "trust": 1.0}
			if category == "special": return {"intimacy": 3.0, "trust": 2.0}
			return {"intimacy": 1.5, "trust": 1.5}
		_:
			return {"intimacy": 1.0, "trust": 1.0}

# 获取连续送礼的衰减倍率
func _get_decay_multiplier(gift_id: String) -> float:
	var current_time = Time.get_unix_time_from_system()
	var count = 0
	
	# 清理过期记录
	var new_recent = []
	for record in _recent_gifts:
		if current_time - record.time <= DECAY_WINDOW_SEC:
			new_recent.append(record)
			if record.id == gift_id:
				count += 1
	_recent_gifts = new_recent
	
	# 衰减公式：第一次 1.0，第二次 0.8，第三次 0.5，后续 0.1
	if count == 0: return 1.0
	if count == 1: return 0.8
	if count == 2: return 0.5
	return 0.1

# 执行送礼操作
# 返回 { "success": bool, "msg": String, "gained_intimacy": float, "gained_trust": float }
func send_gift(profile: CharacterProfile, gift_id: String) -> Dictionary:
	var gift = get_gift_by_id(gift_id)
	if gift.is_empty():
		return { "success": false, "msg": "未找到对应的礼物" }
		
	# 委托 InteractionManager 统一处理行动力等消耗
	if GameDataManager.interaction_manager:
		if not GameDataManager.interaction_manager.execute_interaction("gift"):
			return { "success": false, "msg": "交互条件不足（如行动力不足）" }
	else:
		if not profile.consume_energy(GIFT_ACTION_COST):
			return { "success": false, "msg": "行动力不足，无法送礼" }
	
	# 计算基础值
	var base_i = gift.get("base_intimacy", 0)
	var base_t = gift.get("base_trust", 0)
	
	# 计算阶段加成
	var multipliers = _get_stage_multiplier(profile.current_stage, gift.get("category", "normal"))
	
	# 计算衰减
	var decay = _get_decay_multiplier(gift_id)
	
	var final_i = base_i * multipliers["intimacy"] * decay
	var final_t = base_t * multipliers["trust"] * decay
	
	# 记录此次送礼
	_recent_gifts.append({ "id": gift_id, "time": Time.get_unix_time_from_system() })
	save_state()
	
	# 应用数值
	if final_i > 0:
		profile.update_intimacy(final_i)
	if final_t > 0:
		profile.update_trust(final_t)

	if GameDataManager.personality_system and GameDataManager.personality_system.has_method("apply_personality_event"):
		var gift_event_type = _resolve_gift_personality_event(gift, decay)
		var intensity = max((final_i + final_t) / 20.0, 0.3)
		GameDataManager.personality_system.apply_personality_event(profile, gift_event_type, {
			"gift_id": gift_id,
			"gift_name": str(gift.get("name", "")),
			"gift_category": str(gift.get("category", "normal")),
			"decay": decay,
			"intensity": intensity,
			"force_log": true
		})
		
	profile.save_profile()
	
	return {
		"success": true,
		"msg": "送礼成功",
		"gained_intimacy": final_i,
		"gained_trust": final_t
	}

func _resolve_gift_personality_event(gift: Dictionary, decay: float) -> String:
	var category = str(gift.get("category", "normal"))
	if decay <= 0.5:
		return "gift_repeated"
	match category:
		"special":
			return "gift_special"
		"expensive":
			return "gift_expensive"
		_:
			return "gift_generic"
