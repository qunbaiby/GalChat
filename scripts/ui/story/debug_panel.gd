extends Control

signal stage_changed(new_stage: int)
signal mood_changed(new_mood: String)

@onready var close_btn: Button = $CenterContainer/Panel/VBoxContainer/CloseButton
@onready var stage_option: OptionButton = $"CenterContainer/Panel/VBoxContainer/TabContainer/情感控制/HBoxContainer/StageOption"
@onready var mood_option: OptionButton = $"CenterContainer/Panel/VBoxContainer/TabContainer/心情/HBoxContainer/MoodOption"

@onready var switch_char_btn: Button = $"CenterContainer/Panel/VBoxContainer/TabContainer/工具与测试/HBoxContainer/SwitchCharButton"
@onready var test_call_btn: Button = $"CenterContainer/Panel/VBoxContainer/TabContainer/工具与测试/HBoxContainer/TestCallButton"
@onready var generate_diary_btn: Button = $"CenterContainer/Panel/VBoxContainer/TabContainer/工具与测试/HBoxContainer/GenerateDiaryButton"

func _ready() -> void:
    close_btn.pressed.connect(_on_close_pressed)
    stage_option.item_selected.connect(_on_stage_selected)
    mood_option.item_selected.connect(_on_mood_selected)
    
    switch_char_btn.pressed.connect(_on_switch_char_pressed)
    test_call_btn.pressed.connect(_on_test_call_pressed)
    generate_diary_btn.pressed.connect(_on_generate_diary_pressed)
    
    _init_stage_options()
    _init_mood_options()
    
    var llm_manager = get_node_or_null("/root/LLMManager")
    var client = null
    if llm_manager and llm_manager.has("deepseek_client"):
        client = llm_manager.deepseek_client
    elif get_tree().current_scene.has_node("DeepseekClient"):
        client = get_tree().current_scene.get_node("DeepseekClient")
    elif get_node_or_null("/root/DeepseekClient"):
        client = get_node("/root/DeepseekClient")
        
    if client:
        if not client.is_connected("diary_generated", _on_diary_generated):
            client.diary_generated.connect(_on_diary_generated)
        if not client.is_connected("diary_error", _on_diary_error):
            client.diary_error.connect(_on_diary_error)

func _init_stage_options() -> void:
    stage_option.clear()
    var profile = GameDataManager.profile
    for i in range(profile.stages_config.size()):
        var config = profile.stages_config[i]
        var stage_num = config.get("stage", i + 1)
        var title = config.get("stageTitle", "未知阶段")
        
        var zh_title = ""
        var title_parts = title.split(" ")
        if title_parts.size() > 1:
            zh_title = title_parts[1]
        else:
            zh_title = title
            
        var display_text = "Stage %d: %s" % [stage_num, zh_title]
        stage_option.add_item(display_text, i)

func _init_mood_options() -> void:
    mood_option.clear()
    var index = 0
    for mood_id in GameDataManager.mood_system.all_mood_ids:
        var config = GameDataManager.mood_system.mood_configs[mood_id]
        var display_text = "%s (%s)" % [config.get("name", mood_id), mood_id]
        mood_option.add_item(display_text, index)
        index += 1

func show_panel() -> void:
    # 同步当前状态
    var profile = GameDataManager.profile
    stage_option.select(profile.current_stage - 1)
    
    var mood_id = profile.current_mood
    var idx = GameDataManager.mood_system.all_mood_ids.find(mood_id)
    if idx >= 0:
        mood_option.select(idx)
        
    show()

func _on_close_pressed() -> void:
    hide()

func _on_stage_selected(index: int) -> void:
    var stage = index + 1
    GameDataManager.profile.force_set_stage(stage)
    stage_changed.emit(stage)

func _on_mood_selected(index: int) -> void:
    if index >= 0 and index < GameDataManager.mood_system.all_mood_ids.size():
        var mood_id = GameDataManager.mood_system.all_mood_ids[index]
        GameDataManager.profile.update_mood(mood_id)
        mood_changed.emit(mood_id)

func _on_switch_char_pressed() -> void:
    var profiles = _get_available_character_ids()
    var current_id = GameDataManager.config.current_character_id
    if current_id == "": current_id = GameDataManager.profile.current_character_id
    
    if profiles.size() <= 1:
        print("[DebugPanel] 只有一个角色，无需切换")
        return
        
    var idx = profiles.find(current_id)
    var next_idx = (idx + 1) % profiles.size()
    var next_id = profiles[next_idx]
    
    print("[DebugPanel] 切换角色从 ", current_id, " 到 ", next_id)
    GameDataManager.switch_character(next_id)
    
    # Update debug panel UI for the new character
    show_panel()

func _get_available_character_ids() -> Array:
    var ids = []
    var dir = DirAccess.open("res://assets/data/characters")
    if dir:
        dir.list_dir_begin()
        var file_name = dir.get_next()
        while file_name != "":
            if file_name.ends_with(".json") and not file_name.ends_with("_stages.json"):
                ids.append(file_name.replace(".json", ""))
            file_name = dir.get_next()
    return ids

func _on_test_call_pressed() -> void:
    var fixed_calls_path = "res://assets/data/story/fixed_calls.json"
    if not FileAccess.file_exists(fixed_calls_path):
        print("[DebugPanel] 未找到通话数据文件:", fixed_calls_path)
        return
        
    var file = FileAccess.open(fixed_calls_path, FileAccess.READ)
    var json = JSON.new()
    var err = json.parse(file.get_as_text())
    if err == OK:
        var calls_data = json.data
        if calls_data is Dictionary and calls_data.keys().size() > 0:
            var first_call_id = calls_data.keys()[0]
            print("[DebugPanel] 测试发起通话:", first_call_id)
            
            var call_event = {
                "type": "video_call",
                "call_id": first_call_id
            }
            
            var call_system = get_node_or_null("/root/CallEventSystem")
            if call_system:
                call_system.trigger_call_event(call_event)
            else:
                var main_scene = get_tree().current_scene
                var chat_scene = preload("res://scenes/ui/mobile/chat/mobile_chat_panel.tscn").instantiate()
                main_scene.add_child(chat_scene)
                chat_scene.hide_panel(false)
                
                await get_tree().process_frame
                
                if chat_scene.has_method("start_call"):
                    chat_scene.start_call(first_call_id, true)
        else:
            print("[DebugPanel] 通话数据为空")
    else:
        print("[DebugPanel] 解析通话数据失败")

func _on_generate_diary_pressed() -> void:
    print("[DebugPanel] 测试生成日记")
    generate_diary_btn.disabled = true
    generate_diary_btn.text = "生成中..."
    
    var client = null
    var llm_manager = get_node_or_null("/root/LLMManager")
    if llm_manager and llm_manager.has("deepseek_client"):
        client = llm_manager.deepseek_client
    elif get_tree().current_scene.has_node("DeepSeekClient"):
        client = get_tree().current_scene.get_node("DeepSeekClient")
    elif get_node_or_null("/root/DeepSeekClient"):
        client = get_node("/root/DeepSeekClient")
        
    if client and client.has_method("send_diary_generation"):
        # Make sure we connect to signals if not connected
        if not client.diary_generated.is_connected(_on_diary_generated):
            client.diary_generated.connect(_on_diary_generated)
        if not client.diary_error.is_connected(_on_diary_error):
            client.diary_error.connect(_on_diary_error)
            
        client.send_diary_generation()
    else:
        print("[DebugPanel] 未找到 DeepSeekClient 或缺少 send_diary_generation 方法，执行模拟生成")
        # Simulate diary generation for testing
        await get_tree().create_timer(1.5).timeout
        
        var mock_diary = {
            "date": Time.get_date_string_from_system(),
            "weather": "晴",
            "content": "　　今天天气真不错，心情也跟着好起来了。测试生成了一篇新的日记，感觉这个系统越来越完善了呢。接下来还要继续努力，把剩下的功能都实现！\n　　而且今天和玩家聊天也很开心，希望能一直保持这样的状态。"
        }
        _on_diary_generated(mock_diary)

func _on_diary_generated(diary_entry: Dictionary) -> void:
    print("[DebugPanel] 日记生成成功")
    generate_diary_btn.disabled = false
    generate_diary_btn.text = "生成日记"
    
    var profile = GameDataManager.profile
    if profile and profile.has_method("add_diary"):
        profile.add_diary(diary_entry)
        
        # Trigger notification
        var main_scene = get_tree().current_scene
        if main_scene and main_scene.has_method("show_diary_notification"):
            main_scene.show_diary_notification()
    else:
        print("[DebugPanel] 未找到 profile.add_diary 方法")

func _on_diary_error(error_msg: String) -> void:
    print("[DebugPanel] 日记生成失败: ", error_msg)
    generate_diary_btn.disabled = false
    generate_diary_btn.text = "生成日记"
