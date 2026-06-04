class_name NPCRelationshipManager
extends Node

const SafeFileAccess = preload("res://scripts/utils/safe_file_access.gd")

# 存储各 NPC 的关系数据
# 格式: { npc_id: { "intimacy": float, "trust": float, "stage": int } }
var relationships: Dictionary = {}

func _init() -> void:
    pass

func get_save_path() -> String:
    var char_id = "default"
    if GameDataManager.config and GameDataManager.config.current_character_id != "":
        char_id = GameDataManager.config.current_character_id
    var dir_path = "user://saves/%s" % char_id
    if not DirAccess.dir_exists_absolute(dir_path):
        DirAccess.make_dir_recursive_absolute(dir_path)
    return "%s/npc_relationships.json" % dir_path

func load_relationships() -> void:
    relationships.clear()
    var path = get_save_path()
    if FileAccess.file_exists(path):
        var file = FileAccess.open(path, FileAccess.READ)
        var content = file.get_as_text()
        file.close()
        
        var json = JSON.new()
        if json.parse(content) == OK:
            var data = json.get_data()
            if typeof(data) == TYPE_DICTIONARY:
                # 迁移旧数据
                for npc_id in data.keys():
                    var npc_data = data[npc_id]
                    if npc_data.has("affection"):
                        var old_aff = npc_data["affection"]
                        npc_data["intimacy"] = float(old_aff)
                        npc_data["trust"] = float(old_aff) / 2.0
                        npc_data.erase("affection")
                    npc_data.erase("interaction_exp")
                relationships = data
                
func save_relationships() -> void:
    var path = get_save_path()
    var content = JSON.stringify(relationships, "\t")
    SafeFileAccess.store_string(path, content)

func get_intimacy(npc_id: String) -> float:
    if relationships.has(npc_id):
        return float(relationships[npc_id].get("intimacy", 0.0))
    return 0.0

func get_trust(npc_id: String) -> float:
    if relationships.has(npc_id):
        return float(relationships[npc_id].get("trust", 0.0))
    return 0.0

func get_stage(npc_id: String) -> int:
    if relationships.has(npc_id):
        return relationships[npc_id].get("stage", 1)
    return 1

func add_intimacy(npc_id: String, amount: float) -> void:
    if not relationships.has(npc_id):
        relationships[npc_id] = { "intimacy": 0.0, "trust": 0.0, "stage": 1 }
    relationships[npc_id]["intimacy"] += amount
    _update_stage(npc_id)
    save_relationships()

func add_trust(npc_id: String, amount: float) -> void:
    if not relationships.has(npc_id):
        relationships[npc_id] = { "intimacy": 0.0, "trust": 0.0, "stage": 1 }
    relationships[npc_id]["trust"] += amount
    _update_stage(npc_id)
    save_relationships()

func _update_stage(npc_id: String) -> void:
    var rel = relationships[npc_id]
    var current_stage = rel.get("stage", 1)
    var current_resonance = rel.get("intimacy", 0.0) + rel.get("trust", 0.0)
    
    var stages_file = "res://assets/data/characters/npc/" + npc_id + "_stages.json"
    if not FileAccess.file_exists(stages_file):
        return
        
    var file = FileAccess.open(stages_file, FileAccess.READ)
    var content = file.get_as_text()
    file.close()
    
    var json = JSON.new()
    if json.parse(content) == OK:
        var data = json.get_data()
        var stages_list = data.get("stages", [])
        
        # 逐级判定升阶 (与主角色逻辑保持一致: 双轨制+里程碑)
        for s in stages_list:
            var sid = s.get("stage", 1)
            if sid == current_stage:
                var res_threshold = s.get("resonance_threshold", 0)
                var milestone_story = str(s.get("milestone_story", "")).strip_edges()
                
                var is_milestone_met = true
                if milestone_story != "":
                    var event_manager = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("EventManager")
                    if event_manager and event_manager.has_method("is_event_triggered"):
                        is_milestone_met = event_manager.is_event_triggered(milestone_story)
                    else:
                        is_milestone_met = false
                        
                if current_resonance >= res_threshold and is_milestone_met:
                    rel["stage"] = current_stage + 1
                    _update_stage(npc_id) # 递归检查是否能连升
                    return

func get_stage_config(npc_id: String) -> Dictionary:
    var stg = get_stage(npc_id)
    var stages_file = "res://assets/data/characters/npc/" + npc_id + "_stages.json"
    if not FileAccess.file_exists(stages_file):
        return {}
        
    var file = FileAccess.open(stages_file, FileAccess.READ)
    var content = file.get_as_text()
    file.close()
    
    var json = JSON.new()
    if json.parse(content) == OK:
        var data = json.get_data()
        var stages_list = data.get("stages", [])
        
        for s in stages_list:
            var sid = s.get("stage", 1)
            if sid == stg:
                return s
    return {}
