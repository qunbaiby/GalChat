extends Node

const INTERACTION_CUTOFF_MINUTES := 23 * 60

# 互动行为开销与收益管理器
# 用于统一管理玩家与角色交互时产生的精力、金币、心情等影响

var interaction_config: Dictionary = {}

func _init() -> void:
	_load_interaction_config()

func _load_interaction_config() -> void:
	var path = "res://assets/data/story/interaction_cost.json"
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			interaction_config = json.data
			
func get_interaction_unavailable_reason(action_id: String) -> Dictionary:
	if not interaction_config.has(action_id):
		return {}
	var config = interaction_config[action_id]
	var energy_cost = int(config.get("energy_cost", 0))
	var gold_cost = int(config.get("gold_cost", 0))
	var time_cost = int(config.get("time_cost", 0))
	return get_cost_unavailable_reason(energy_cost, gold_cost, time_cost)

func get_cost_unavailable_reason(energy_cost: int, gold_cost: int, time_cost: int) -> Dictionary:
	var profile = GameDataManager.profile
	if energy_cost > 0 and profile.current_energy < energy_cost:
		return {"reason": "energy", "required": energy_cost, "available": int(profile.current_energy)}
	if gold_cost > 0 and profile.gold < gold_cost:
		return {"reason": "gold", "required": gold_cost, "available": int(profile.gold)}
	time_cost = maxi(0, time_cost)
	if time_cost > 0 and GameDataManager.story_time_manager:
		var current_minutes := int(GameDataManager.story_time_manager.current_hour) * 60 + int(GameDataManager.story_time_manager.current_minute)
		if current_minutes + time_cost >= INTERACTION_CUTOFF_MINUTES:
			return {"reason": "late", "required_minutes": time_cost, "current_minutes": current_minutes}
	return {}

func can_execute_interaction(action_id: String, show_message: bool = true) -> bool:
	var unavailable := get_interaction_unavailable_reason(action_id)
	if unavailable.is_empty():
		return true
	if not show_message:
		return false
	show_unavailable_dialog(unavailable)
	return false

func show_unavailable_dialog(unavailable: Dictionary) -> void:
	var message := "暂时无法开始这次互动。"
	match str(unavailable.get("reason", "")):
		"energy":
			message = "精力不足，至少需要 %d 点精力才能开始这次互动。" % int(unavailable.get("required", 0))
		"gold":
			message = "金币不足，至少需要 %d 金币才能开始这次互动。" % int(unavailable.get("required", 0))
		"late":
			message = "时间已经很晚了，无法在 23:00 前完成这次互动。"
	var confirm_scene = load("res://scenes/ui/common/confirm_dialog.tscn")
	var current_scene := get_tree().current_scene
	if confirm_scene == null or not is_instance_valid(current_scene):
		ToastManager.show_system_toast(message, Color.RED)
		return
	var dialog = confirm_scene.instantiate()
	current_scene.add_child(dialog)
	dialog.setup_advanced("暂时无法互动", message, "", "", "知道了", "")
	if dialog.cancel_button:
		dialog.cancel_button.hide()

# 执行互动开销，如果资源或时间不足则自动提示并返回 false
func execute_interaction(action_id: String) -> bool:
	if not interaction_config.has(action_id):
		print("[InteractionManager] 警告：未找到行为 '%s' 的配置，将按照默认放行。" % action_id)
		return true
	if not can_execute_interaction(action_id):
		return false
	var config = interaction_config[action_id]
	var profile = GameDataManager.profile
	var energy_cost = int(config.get("energy_cost", 0))
	var gold_cost = int(config.get("gold_cost", 0))
		
	# 扣除资源
	if energy_cost > 0:
		profile.consume_energy(energy_cost)
	if gold_cost > 0:
		profile.gold -= gold_cost
		
	# 调整心情
	var mood_impact = int(config.get("mood_impact", 0))
	
	if mood_impact != 0:
		profile.mood_value = clamp(profile.mood_value + mood_impact, 0, 100)
		
	# 推进时间
	var time_cost = int(config.get("time_cost", 0))
	if time_cost > 0 and GameDataManager.story_time_manager:
		GameDataManager.story_time_manager.tick_minutes(time_cost)
		
	# 保存档案更新状态
	profile.save_profile()
	if GameDataManager.has_node("TopStatusPanel"):
		var top_panel = GameDataManager.get_node("TopStatusPanel")
		if top_panel.has_method("_update_ui"):
			top_panel._update_ui()
			
	return true
