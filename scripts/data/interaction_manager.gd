extends Node

# 互动行为开销与收益管理器
# 用于统一管理玩家与角色交互时产生的行动力、金币、经验、心情、压力等影响

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
            
# 执行互动开销，如果资源不足则自动弹窗提示并返回 false
func execute_interaction(action_id: String) -> bool:
    if not interaction_config.has(action_id):
        print("[InteractionManager] 警告：未找到行为 '%s' 的配置，将按照默认放行。" % action_id)
        return true
        
    var config = interaction_config[action_id]
    var profile = GameDataManager.profile
    
    var energy_cost = int(config.get("energy_cost", 0))
    var gold_cost = int(config.get("gold_cost", 0))
    
    # 检查资源是否足够
    if energy_cost > 0 and profile.current_energy < energy_cost:
        ToastManager.show_system_toast("行动力不足，需要 %d 点行动力" % energy_cost, Color.RED)
        return false
        
    if gold_cost > 0 and profile.gold < gold_cost:
        ToastManager.show_system_toast("金币不足，需要 %d 金币" % gold_cost, Color.RED)
        return false
        
    # 扣除资源
    if energy_cost > 0:
        profile.consume_energy(energy_cost)
    if gold_cost > 0:
        profile.gold -= gold_cost
        
    # 增加互动经验
    var exp_gain = int(config.get("exp_gain", 0))
    if exp_gain > 0:
        profile.interaction_exp += exp_gain
        profile.check_stage_upgrade()
        ToastManager.show_toast("互动经验 +%d" % exp_gain, Color(0.9, 0.6, 0.4, 0.9))
        
    # 调整心情与压力
    var mood_impact = int(config.get("mood_impact", 0))
    var stress_impact = int(config.get("stress_impact", 0))
    
    if mood_impact != 0:
        profile.mood_value = clamp(profile.mood_value + mood_impact, 0, 100)
    if stress_impact != 0:
        profile.stress = clamp(profile.stress + stress_impact, 0, 100)
        
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
