class_name ConditionManager
extends Node

static func evaluate_conditions(conditions: Array) -> Dictionary:
    var result = {
        "passed": true,
        "failed_reason": ""
    }
    
    if conditions == null or conditions.is_empty():
        return result
        
    var time_sys = GameDataManager.story_time_manager
    var profile = GameDataManager.profile
    var current_stage = profile.current_stage if profile else 0
    
    for cond in conditions:
        var c_type = cond.get("type", "")
        if c_type == "time":
            var start_h = cond.get("start_hour", 0)
            var end_h = cond.get("end_hour", 24)
            if time_sys:
                var h = time_sys.current_hour
                if h < start_h or h >= end_h:
                    result["passed"] = false
                    result["failed_reason"] = "仅在 %02d:00 - %02d:00 期间开放" % [start_h, end_h]
                    return result
        elif c_type == "stat":
            var stat_name = cond.get("stat_name", "")
            var min_val = cond.get("value", 0)
            if profile:
                var val = profile.get(stat_name)
                if val == null or val < min_val:
                    result["passed"] = false
                    var display_name = GameDataManager.stats_system.get_stat_display_name(stat_name) if GameDataManager.has_method("stats_system") else stat_name
                    result["failed_reason"] = "需要【%s】达到 %d" % [display_name, min_val]
                    return result
        elif c_type == "stage":
            var min_stage = cond.get("min_stage", 0)
            if current_stage < min_stage:
                result["passed"] = false
                result["failed_reason"] = "好感度阶段不足"
                return result
        elif c_type == "npc_stage":
            var npc_id = cond.get("npc_id", "")
            var min_stage = cond.get("min_stage", 0)
            var npc_rel = GameDataManager.npc_relationship_manager
            if npc_rel:
                var n_stage = npc_rel.get_stage(npc_id)
                if n_stage < min_stage:
                    result["passed"] = false
                    result["failed_reason"] = "需要与该NPC关系更进一步"
                    return result
        elif c_type == "location":
            var req_loc = cond.get("value", "")
            var current_loc = MapDataManager.get_last_area() # 或其他获取当前位置的方式
            if current_loc != req_loc:
                result["passed"] = false
                result["failed_reason"] = "必须在特定地点触发"
                return result
        elif c_type == "time_period":
            var req_period = cond.get("value", "")
            if time_sys and time_sys.current_period != req_period:
                result["passed"] = false
                result["failed_reason"] = "需要在特定时段触发"
                return result
        elif c_type == "weather":
            var req_weather = cond.get("value", "")
            if GameDataManager.has_method("weather_manager") and GameDataManager.weather_manager:
                var current_weather = GameDataManager.weather_manager.current_weather_desc
                if req_weather not in current_weather:
                    result["passed"] = false
                    result["failed_reason"] = "需要在特定天气触发"
                    return result
                
    return result
