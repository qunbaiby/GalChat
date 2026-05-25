extends Node

# EventManager - 全局事件库
# 统一管理项目中的各种触发事件

signal event_triggered(event_id: String, params: Dictionary)

const EVENT_REGISTRY_PATH = "res://assets/data/events/event_registry.json"
const TRIGGERED_EVENTS_SAVE = "user://triggered_events.json"

var event_registry: Array = []
var triggered_events: Array = [] # 记录已触发过的事件ID

func _ready() -> void:
    _load_event_registry()
    _load_triggered_events()

func _load_event_registry() -> void:
    if FileAccess.file_exists(EVENT_REGISTRY_PATH):
        var file = FileAccess.open(EVENT_REGISTRY_PATH, FileAccess.READ)
        var json = JSON.new()
        if json.parse(file.get_as_text()) == OK:
            var data = json.get_data()
            if data.has("events"):
                event_registry = data["events"]
        file.close()

func _load_triggered_events() -> void:
    if FileAccess.file_exists(TRIGGERED_EVENTS_SAVE):
        var file = FileAccess.open(TRIGGERED_EVENTS_SAVE, FileAccess.READ)
        var json = JSON.new()
        if json.parse(file.get_as_text()) == OK:
            triggered_events = json.get_data()
        file.close()

func _save_triggered_events() -> void:
    var SafeFileAccess = preload("res://scripts/utils/safe_file_access.gd")
    SafeFileAccess.store_string(TRIGGERED_EVENTS_SAVE, JSON.stringify(triggered_events))

func is_event_triggered(event_id: String) -> bool:
    return triggered_events.has(event_id)

# 广播状态变更，尝试匹配全局事件
func broadcast_state_change(context: Dictionary = {}) -> void:
    var ConditionManager = preload("res://scripts/data/condition_manager.gd")
    
    for event in event_registry:
        var event_id = event.get("event_id", "")
        
        # 检查是否已触发过且不可重复
        if not event.get("is_repeatable", false) and event_id in triggered_events:
            continue
            
        var conditions = event.get("conditions", [])
        var eval_result = ConditionManager.evaluate_conditions(conditions)
        
        # 如果是 location 条件，我们要确保 context 里传过来的 location 是一致的
        if context.has("location_id"):
            var has_loc_cond = false
            var loc_match = false
            for c in conditions:
                if c.get("type", "") == "location":
                    has_loc_cond = true
                    if c.get("value", "") == context["location_id"]:
                        loc_match = true
            if has_loc_cond and not loc_match:
                continue
        
        if eval_result["passed"]:
            _trigger_registry_event(event)
            return # 一次只触发一个事件，避免冲突

func _trigger_registry_event(event_data: Dictionary) -> void:
    var event_id = event_data.get("event_id", "")
    print("[EventManager] 全局事件满足触发条件: ", event_id)
    
    var script_path = event_data.get("trigger_script", "")
    if script_path != "" and ResourceLoader.exists(script_path):
        # 标记为已触发
        if not event_id in triggered_events:
            triggered_events.append(event_id)
            _save_triggered_events()
            
        GameDataManager.set_meta("play_specific_story", script_path)
        var SceneTransitionManager = get_node_or_null("/root/SceneTransitionManager")
        if SceneTransitionManager:
            SceneTransitionManager.transition_to_scene("res://scenes/ui/story/story_scene.tscn")
    
    event_triggered.emit(event_id, event_data)

func execute_event(event_id: String, params: Dictionary = {}) -> void:
    print("[EventManager] 触发事件: ", event_id, " | 参数: ", params)
    
    match event_id:
        "proactive_greeting":
            _handle_proactive_greeting()
        "farewell":
            _handle_farewell()
        "show_interact_group":
            _handle_show_interact_group(params.get("visible", true))
        "toggle_interact_button":
            _handle_toggle_interact_button(params.get("button_name", ""), params.get("visible", true))
        "write_diary":
            _handle_write_diary()
        "post_moment":
            _handle_post_moment()
        _:
            print("[EventManager] 未知事件 ID: ", event_id)
            
    event_triggered.emit(event_id, params)

func _handle_proactive_greeting() -> void:
    var main_scene = get_tree().root.get_node_or_null("MainScene")
    if not main_scene:
        return
        
    var story_time_manager = GameDataManager.story_time_manager
    if not story_time_manager:
        print("[EventManager] 找不到 story_time_manager，无法判断时间")
        return
        
    var date_dict = story_time_manager.get_current_date_dict()
    var weekday = date_dict.weekday # 0=周日, 1=周一, ..., 6=周六
    
    var prompt_type = ""
    if weekday == 1: # 星期一
        prompt_type = "course"
    elif weekday == 0 or weekday == 6: # 星期六、日
        prompt_type = "daily"
    else:
        print("[EventManager] 当前星期(", weekday, ")不满足主动问候触发条件。")
        return
        
    if main_scene.has_method("start_proactive_greeting"):
        main_scene.start_proactive_greeting(prompt_type)

func _handle_farewell() -> void:
    var main_scene = get_tree().root.get_node_or_null("MainScene")
    if main_scene and main_scene.has_method("start_farewell"):
        main_scene.start_farewell()

func _handle_show_interact_group(is_visible: bool) -> void:
    var main_scene = get_tree().root.get_node_or_null("MainScene")
    if main_scene and main_scene.has_node("UIPanel/InteractGroup"):
        main_scene.get_node("UIPanel/InteractGroup").visible = is_visible

func _handle_toggle_interact_button(btn_name: String, is_visible: bool) -> void:
    if btn_name == "": return
    var main_scene = get_tree().root.get_node_or_null("MainScene")
    if main_scene and main_scene.has_node("UIPanel/InteractGroup/" + btn_name):
        main_scene.get_node("UIPanel/InteractGroup/" + btn_name).visible = is_visible

func _handle_write_diary() -> void:
    var main_scene = get_tree().root.get_node_or_null("MainScene")
    if main_scene and main_scene.has_node("DeepSeekClient"):
        var client = main_scene.get_node("DeepSeekClient")
        if client.has_method("send_diary_generation"):
            client.send_diary_generation()
            print("[EventManager] 已触发日记生成事件。")
        else:
            print("[EventManager] DeepSeekClient 缺少 send_diary_generation 方法。")
    else:
        print("[EventManager] 未找到 MainScene 或 DeepSeekClient，无法触发日记生成。")

func _handle_post_moment() -> void:
    var client = null
    var llm_manager = get_node_or_null("/root/LLMManager")
    if llm_manager and llm_manager.has("deepseek_client"):
        client = llm_manager.deepseek_client
    elif get_tree().current_scene and get_tree().current_scene.has_node("DeepSeekClient"):
        client = get_tree().current_scene.get_node("DeepSeekClient")
    elif get_node_or_null("/root/DeepSeekClient"):
        client = get_node("/root/DeepSeekClient")
    elif get_tree().root.has_node("MainScene/DeepSeekClient"):
        client = get_node("/root/MainScene/DeepSeekClient")

    if client and client.has_method("send_moment_generation"):
        # 随机抽取一个角色发送朋友圈
        var target_profile = _get_random_character_profile()
        client.send_moment_generation(target_profile)
        print("[EventManager] 已触发朋友圈生成事件。")
    else:
        print("[EventManager] 未找到有效的 DeepSeekClient 或缺少 send_moment_generation 方法，无法触发朋友圈生成。")

func _get_random_character_profile() -> CharacterProfile:
    var char_ids = ["luna", "jing", "ya"]
    var random_id = char_ids[randi() % char_ids.size()]
    
    var new_profile = CharacterProfile.new()
    new_profile.load_profile(random_id)
    return new_profile
