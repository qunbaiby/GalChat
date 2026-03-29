extends Control

@onready var back_btn: Button = $UIOverlay/BackButton
@onready var settings_btn: Button = $UIOverlay/SettingsButton
@onready var debug_btn: Button = $UIOverlay/DebugButton
@onready var history_btn: Button = $UIOverlay/HistoryButton
@onready var intimacy_bar: ProgressBar = $UIOverlay/IntimacyBar

@onready var name_label: Label = $DialogueLayer/NameLabel
@onready var dialogue_text: RichTextLabel = $DialogueLayer/RichTextLabel
@onready var input_field: TextEdit = $InputLayer/HBoxContainer/InputField
@onready var send_btn: Button = $InputLayer/HBoxContainer/SendButton
@onready var affection_btn: Button = $InputLayer/HBoxContainer/AffectionButton

@onready var character_layer: TextureRect = $CharacterLayer

@onready var deepseek_client: DeepSeekClient = $DeepSeekClient
@onready var doubao_tts = $DoubaoTTSService
@onready var audio_player: AudioStreamPlayer = $AudioStreamPlayer

@onready var history_panel: Panel = $HistoryPanel
@onready var history_close_btn: Button = $HistoryPanel/HistoryTopBar/HistoryCloseButton
@onready var history_vbox: VBoxContainer = $HistoryPanel/ScrollContainer/VBoxContainer

@onready var affection_panel: Control = $AffectionPanel
@onready var debug_panel: Control = $DebugPanel
@onready var settings_panel: Control = $SettingsScene
@onready var toast: ToastNotification = $ToastNotification
@onready var quick_options_container: VBoxContainer = $QuickOptionLayer/QuickOptions

const HISTORY_ITEM_SCENE = preload("res://assets/scenes/ui/history/history_item.tscn")
const QUICK_OPTION_ITEM_SCENE = preload("res://assets/scenes/ui/chat/quick_option_item.tscn")

func _ready() -> void:
    back_btn.pressed.connect(_on_back_pressed)
    settings_btn.pressed.connect(_on_settings_pressed)
    history_btn.pressed.connect(_on_history_pressed)
    debug_btn.pressed.connect(_on_debug_pressed)
    affection_btn.pressed.connect(_on_affection_pressed)
    affection_btn.mouse_entered.connect(func():
        var tween = create_tween()
        tween.tween_property(affection_btn, "scale", Vector2(1.1, 1.1), 0.1)
    )
    affection_btn.mouse_exited.connect(func():
        var tween = create_tween()
        tween.tween_property(affection_btn, "scale", Vector2(1.0, 1.0), 0.1)
    )
    send_btn.pressed.connect(_on_send_pressed)
    input_field.text_changed.connect(_on_input_text_changed)
    
    history_close_btn.pressed.connect(_on_history_close_pressed)
    
    debug_panel.stage_changed.connect(_on_debug_stage_changed)
    debug_panel.mood_changed.connect(_on_debug_mood_changed)
    
    GameDataManager.profile.stage_upgraded.connect(_on_stage_upgraded)
    
    deepseek_client.chat_request_completed.connect(_on_chat_response)
    deepseek_client.chat_request_failed.connect(_on_chat_error)
    
    deepseek_client.emotion_request_completed.connect(_on_emotion_response)
    deepseek_client.emotion_request_failed.connect(_on_emotion_error)
    
    deepseek_client.memory_request_completed.connect(_on_memory_response)
    deepseek_client.memory_request_failed.connect(_on_memory_error)
    
    deepseek_client.options_request_completed.connect(_on_options_response)
    deepseek_client.options_request_failed.connect(_on_options_error)
    
    doubao_tts.tts_success.connect(_on_tts_success)
    doubao_tts.tts_failed.connect(_on_tts_failed)
    
    # 配置TTS服务
    var config = GameDataManager.config
    doubao_tts.setup_auth(config.doubao_app_id, config.doubao_token, config.doubao_cluster)
    
    _update_ui()
    
    # 初始问候 (如果是从开始界面进入，则清空之前可能残留的对话状态，也可以不清空，这里选择不清空而是追加)
    var messages = GameDataManager.history.messages
    if messages.size() == 0:
        var char_name = GameDataManager.profile.char_name
        _show_message("你好...今天想聊点什么？", char_name, false)
    else:
        _restore_last_message()

func _restore_last_message() -> void:
    var messages = GameDataManager.history.messages
    if messages.size() > 0:
        var last_msg = messages[messages.size() - 1]
        # 直接静默显示最后一条，不触发打字机和语音
        dialogue_text.text = last_msg["text"]
        dialogue_text.visible_characters = -1
        name_label.text = last_msg["speaker"]
        
        # 恢复对应立绘
        if last_msg["speaker"] == GameDataManager.profile.char_name:
            var current_mood = GameDataManager.profile.current_mood
            _update_character_sprite(current_mood)
    else:
        var char_name = GameDataManager.profile.char_name
        # 如果没有历史记录，静默显示初始问候
        dialogue_text.text = "你好...今天想聊点什么？"
        dialogue_text.visible_characters = -1
        name_label.text = char_name

func _on_input_text_changed() -> void:
    if input_field.text.length() > 120:
        input_field.text = input_field.text.substr(0, 120)
        input_field.set_caret_column(120)

func _update_ui() -> void:
    var conf = GameDataManager.profile.get_current_stage_config()
    var threshold = float(conf.get("threshold", 100))
    intimacy_bar.max_value = threshold
    intimacy_bar.value = GameDataManager.profile.intimacy

func _on_back_pressed() -> void:
    get_tree().change_scene_to_file("res://assets/scenes/ui/start/start_scene.tscn")

func _on_settings_pressed() -> void:
    settings_panel.show()
    if settings_panel.has_method("_load_ui_data"):
        settings_panel._load_ui_data()

func _on_debug_pressed() -> void:
    debug_panel.show_panel()

func _on_affection_pressed() -> void:
    affection_panel.show_panel()

func _on_debug_stage_changed(stage: int) -> void:
    toast.show_toast("【Debug】强制切换情感阶段至：" + str(stage), Color.CYAN)
    GameDataManager.profile.force_set_stage(stage)
    # Clear short term history so the AI doesn't get confused by previous stage's context
    GameDataManager.history.messages.clear()
    GameDataManager.history.save_history()
    _update_ui()
    toast.show_toast("已清空上下文历史，以重新适配新阶段", Color.GRAY)

func _on_stage_upgraded(new_stage: int, is_levelup: bool) -> void:
    if is_levelup:
        toast.show_toast("情感阶段提升至: Stage " + str(new_stage), Color.YELLOW)
        # 不再通过 _show_message 强行打断对话
    else:
        toast.show_toast("情感阶段下降至: Stage " + str(new_stage), Color.GRAY)
    
    var stage_conf = GameDataManager.profile.get_current_stage_config()
    if stage_conf.has("mood_switch"):
        var new_mood = stage_conf["mood_switch"]
        if GameDataManager.mood_system.is_valid_mood(new_mood):
            GameDataManager.profile.update_mood(new_mood)
            toast.show_toast("心情切换为：" + new_mood, Color.ORANGE)

func _on_debug_mood_changed(mood: String) -> void:
    toast.show_toast("【Debug】强制切换心情至：" + mood, Color.CYAN)
    GameDataManager.profile.update_mood(mood)
    _update_ui()

func _update_character_sprite(mood: String) -> void:
    var sprite_path = GameDataManager.mood_system.get_mood_sprite_path(mood)
    if sprite_path != "":
        var tex = load(sprite_path)
        if tex:
            if character_layer.has_method("update_sprite"):
                character_layer.update_sprite(tex)
            else:
                character_layer.texture = tex

func _on_history_pressed() -> void:
    history_panel.show()
    _populate_history_ui()
    
    # 延迟一帧等待容器布局完成，然后滚动到底部
    if is_inside_tree():
        await get_tree().process_frame
    var scroll = history_panel.get_node("ScrollContainer")
    if scroll:
        var v_scroll = scroll.get_v_scroll_bar()
        v_scroll.value = v_scroll.max_value

func _on_history_close_pressed() -> void:
    history_panel.hide()

func _populate_history_ui() -> void:
    # 清空现有子节点
    for child in history_vbox.get_children():
        child.queue_free()
        
    var messages = GameDataManager.history.messages
    for msg in messages:
        var item = HISTORY_ITEM_SCENE.instantiate()
        history_vbox.add_child(item)
        item.setup(msg)
        item.play_voice_requested.connect(_play_cached_voice)

func _play_cached_voice(cache_key: String) -> void:
    var cache_path = doubao_tts.CACHE_DIR + cache_key + "." + doubao_tts.default_encoding
    if FileAccess.file_exists(cache_path):
        var stream = doubao_tts._load_audio_from_file(cache_path)
        if stream:
            audio_player.stream = stream
            audio_player.play()
    else:
        print("未找到语音缓存: ", cache_key)

var pending_status_changes = []

func _on_send_pressed() -> void:
    var text = input_field.text.strip_edges()
    if text.is_empty():
        return
        
    input_field.text = ""
    send_btn.disabled = true
    input_field.editable = false
    
    pending_status_changes.clear()
    
    _show_message(text, "玩家")
    
    # 清空现有的快捷选项
    for child in quick_options_container.get_children():
        child.queue_free()
        
    if GameDataManager.config.ai_mode_enabled:
        deepseek_client.send_chat_message(text)
    else:
        # 本地兜底对话
        if is_inside_tree():
            await get_tree().create_timer(1.0).timeout
        var char_name = GameDataManager.profile.char_name
        _show_message("（离线模式）我...我不知道该说什么...", char_name)
        send_btn.disabled = false
        input_field.editable = true

func _on_chat_response(response: Dictionary) -> void:
    var char_name = GameDataManager.profile.char_name
    send_btn.disabled = false
    input_field.editable = true
    if response.has("choices") and response["choices"].size() > 0:
        var reply = response["choices"][0]["message"]["content"]
        _parse_and_show_reply(reply)
    else:
        _show_message(char_name + " 似乎走神了...", char_name)

func _on_chat_error(error_msg: String) -> void:
    var char_name = GameDataManager.profile.char_name
    send_btn.disabled = false
    input_field.editable = true
    toast.show_toast(error_msg, Color.RED)
    # 本地兜底
    if is_inside_tree():
        await get_tree().create_timer(1.0).timeout
    _show_message("刚才网络好像不太好...", char_name)

func _append_status_change(change_text: String, plain_text: String) -> void:
    # 不再向对话框追加状态，而是直接通过 toast 弹出，并输出到控制台
    # print("【情感分析/记忆提取】", plain_text)
    toast.show_toast(plain_text, Color.AQUAMARINE)

func _on_emotion_response(response: Dictionary) -> void:
    if response.has("choices") and response["choices"].size() > 0:
        var reply = response["choices"][0]["message"]["content"]
        
        print("\n========== [Emotion Agent Output] ==========")
        print(reply)
        print("============================================\n")
        
        var regex = RegEx.new()
        regex.compile("(?i)(?:<|\\<|《|\\[|【)\\s*(intimacy|trust|亲密度|亲密变化|信任度|信任值|信任变化)\\s*[:：]\\s*([^>\\>》\\]】]+)\\s*(?:>|\\>|》|\\]|】)")
        var matches = regex.search_all(reply)
        var has_changes = false
        var plain_text_changes = ""
        for m in matches:
            var tag = m.get_string(1).to_lower()
            var val = m.get_string(2).strip_edges()
            var f_val = val.to_float()
            if tag == "intimacy" or tag.begins_with("亲密"):
                GameDataManager.profile.update_intimacy(f_val)
                has_changes = true
                plain_text_changes += "亲密变化:" + ("+" if f_val > 0 else "") + str(f_val) + " "
            elif tag == "trust" or tag.begins_with("信任"):
                GameDataManager.profile.update_trust(f_val)
                has_changes = true
                plain_text_changes += "信任变化:" + ("+" if f_val > 0 else "") + str(f_val) + " "
        if has_changes:
            GameDataManager.profile.save_profile()
            _update_ui()
            _append_status_change("", plain_text_changes.strip_edges())

func _on_emotion_error(error_msg: String) -> void:
    print("Emotion Agent Failed: ", error_msg)

func _on_memory_response(response: Dictionary) -> void:
    if response.has("choices") and response["choices"].size() > 0:
        var reply = response["choices"][0]["message"]["content"]
        var regex = RegEx.new()
        regex.compile("(?i)(?:<|\\<|《|\\[|【)\\s*(mem_core|mem_emo|mem_habit|mem_bond|核心记忆|情绪记忆|习惯记忆|羁绊记忆)\\s*[:：]\\s*([^>\\>》\\]】]+)\\s*(?:>|\\>|》|\\]|】)")
        var matches = regex.search_all(reply)
        var extracted_memories = []
        for m in matches:
            var tag = m.get_string(1).to_lower()
            var val = m.get_string(2).strip_edges()
            if tag == "mem_core" or tag == "核心记忆":
                GameDataManager.memory_manager.add_memory("core", val)
                extracted_memories.append("核心记忆")
            elif tag == "mem_emo" or tag == "情绪记忆":
                GameDataManager.memory_manager.add_memory("emotion", val)
                extracted_memories.append("情绪记忆")
            elif tag == "mem_habit" or tag == "习惯记忆":
                GameDataManager.memory_manager.add_memory("habit", val)
                extracted_memories.append("习惯记忆")
            elif tag == "mem_bond" or tag == "羁绊记忆":
                GameDataManager.memory_manager.add_memory("bond", val)
                extracted_memories.append("羁绊记忆")
        if extracted_memories.size() > 0:
            var unique_mem = []
            for m in extracted_memories:
                if not unique_mem.has(m):
                    unique_mem.append(m)
            var plain_text_changes = "已提取: " + "、".join(unique_mem)
            _append_status_change("", plain_text_changes)

func _on_memory_error(error_msg: String) -> void:
    print("Memory Agent Failed: ", error_msg)

func _on_options_response(response: Dictionary) -> void:
    if response.has("choices") and response["choices"].size() > 0:
        var reply = response["choices"][0]["message"]["content"]
        
        print("\n========== [Options Agent Output] ==========")
        print(reply)
        print("============================================\n")
        
        var json = JSON.new()
        if json.parse(reply.strip_edges()) == OK:
            var data = json.get_data()
            if data is Dictionary and data.has("options") and data["options"] is Array:
                _populate_quick_options(data["options"])
                return
                
        print("Warning: Options Agent did not return valid JSON.")

func _on_options_error(error_msg: String) -> void:
    print("Options Agent Failed: ", error_msg)

func _populate_quick_options(options: Array) -> void:
    for child in quick_options_container.get_children():
        child.queue_free()
        
    for opt_text in options:
        if typeof(opt_text) == TYPE_STRING:
            var item = QUICK_OPTION_ITEM_SCENE.instantiate()
            quick_options_container.add_child(item)
            item.setup(opt_text)
            item.option_selected.connect(_on_quick_option_selected)

func _on_quick_option_selected(text: String) -> void:
    input_field.text = text
    _on_send_pressed()

func _parse_and_show_reply(reply: String) -> void:
    # Print the raw reply to the console for debugging
    print("\n========== [Chat Agent Output] ==========")
    print(reply)
    print("=========================================\n")
    
    # Try to parse the reply as multiple bubbles using the [SPLIT] token
    var clean_reply = reply.strip_edges()
    
    # Remove any markdown formatting if the LLM still tries to output it
    if clean_reply.begins_with("```"):
        var lines = clean_reply.split("\n")
        if lines.size() > 2:
            lines.remove_at(0)
            if lines[lines.size()-1].begins_with("```"):
                lines.remove_at(lines.size()-1)
            clean_reply = "\n".join(lines).strip_edges()
            
    var message_list = _auto_split_message(clean_reply)
        
    var valid_lines = []
    for line in message_list:
        if typeof(line) == TYPE_STRING:
            var t = line.strip_edges()
            if t != "":
                valid_lines.append(t)
                
    if valid_lines.size() == 0:
        _show_message(GameDataManager.profile.char_name + " 似乎走神了...", GameDataManager.profile.char_name)
        return
        
    # Start the sequence
    _play_message_sequence(valid_lines, GameDataManager.profile.char_name)

func _auto_split_message(text: String) -> Array:
    # 如果AI主动遵守了提示词，直接使用
    if "[SPLIT]" in text:
        return text.split("[SPLIT]", false)
        
    # 系统级强制干预：根据语境智能切分
    # 提取情绪标签，防止它在切分时被破坏或抛弃
    var mood_tag = ""
    var pure_text = text
    var mood_regex = RegEx.new()
    mood_regex.compile("(?i)(?:<|\\<|《|\\[|【)\\s*(mood|心情)\\s*[:：]\\s*([^>\\>》\\]】]+)\\s*(?:>|\\>|》|\\]|】)")
    var mood_match = mood_regex.search(text)
    if mood_match:
        mood_tag = mood_match.get_string()
        pure_text = text.replace(mood_tag, "")
        
    var modified_text = pure_text
    
    # 新增策略0：优先将大模型输出的换行符视为消息分隔符
    # 很多时候AI会用换行来排版不同的动作和对话
    modified_text = modified_text.replace("\r\n", "\n")
    var nl_regex = RegEx.new()
    nl_regex.compile("\\n+")
    modified_text = nl_regex.sub(modified_text, "[SPLIT]", true)
    
    if not "[SPLIT]" in modified_text:
        var endings = ["。", "！", "？", "……", "”", "」", "~", "～"]
        var brackets = ["（", "("]
        
        # 策略1：根据“标点+动作括号”完美切分，这样刚好能保证切分后下一句以动作开头，带着后续的对话
        for end_char in endings:
            for bracket in brackets:
                modified_text = modified_text.replace(end_char + bracket, end_char + "[SPLIT]" + bracket)
                modified_text = modified_text.replace(end_char + " " + bracket, end_char + "[SPLIT]" + bracket)
                
        # 策略2：如果文本仍未切分且过长（>80字），强行按标点切分
        if not "[SPLIT]" in modified_text and modified_text.length() > 80:
            modified_text = modified_text.replace("。", "。[SPLIT]")
            modified_text = modified_text.replace("！", "！[SPLIT]")
            modified_text = modified_text.replace("？", "？[SPLIT]")
            # 避免把连续的标点切碎
            modified_text = modified_text.replace("[SPLIT][SPLIT]", "[SPLIT]")
        
    var parts = modified_text.split("[SPLIT]", false)
    var merged_parts = []
    var temp_str = ""
    
    for p in parts:
        var tp = p.strip_edges()
        if tp == "": continue
        
        if temp_str == "":
            temp_str = tp
        else:
            # 如果某一句太短（<15字符），合并到上一句，避免气泡过于细碎
            if temp_str.length() < 15 or tp.length() < 10:
                temp_str += " " + tp
            else:
                merged_parts.append(temp_str)
                temp_str = tp
                
    if temp_str != "":
        merged_parts.append(temp_str)
        
    # 限制最多3条
    if merged_parts.size() > 3:
        var final_parts = []
        final_parts.append(merged_parts[0])
        final_parts.append(merged_parts[1])
        var tail = ""
        for i in range(2, merged_parts.size()):
            tail += merged_parts[i]
        final_parts.append(tail)
        merged_parts = final_parts
        
    # 将心情标签加回最后一条消息末尾
    if merged_parts.size() > 0 and mood_tag != "":
        merged_parts[merged_parts.size() - 1] += mood_tag
        
    if merged_parts.size() == 0:
        return [text]
        
    return merged_parts

func _play_message_sequence(lines: Array, char_name: String) -> void:
    for line in lines:
        await _process_single_message_line_async(line, char_name)
        # 等待上一句（包括打字机和语音）彻底完成后，再强制额外等待 1 秒
        if is_inside_tree():
            await get_tree().create_timer(1.0).timeout
        
    GameDataManager.profile.add_interaction_exp()
    GameDataManager.profile.save_profile()
    _update_ui()
    
    # 整个序列播放完成后，请求生成玩家选项
    if lines.size() > 0 and GameDataManager.config.ai_mode_enabled:
        var last_ai_msg = lines[lines.size() - 1]
        
        # 如果当前不在场景树中（玩家切到了后台），暂停直到重回场景树
        while not is_inside_tree():
            await Engine.get_main_loop().process_frame
            
        deepseek_client.send_options_generation(last_ai_msg)

func _process_single_message_line_async(raw_line: String, char_name: String) -> void:
    var regex = RegEx.new()
    regex.compile("(?i)(?:<|\\<|《|\\[|【)\\s*(mood|心情)\\s*[:：]\\s*([^>\\>》\\]】]+)\\s*(?:>|\\>|》|\\]|】)")
    
    var clean_text = raw_line
    var mood_change: String = ""
    
    var matches = regex.search_all(raw_line)
    for m in matches:
        var tag = m.get_string(1).to_lower()
        var val = m.get_string(2).strip_edges()
        if tag == "mood" or tag == "心情":
            if GameDataManager.mood_system.is_valid_mood(val):
                mood_change = val
                GameDataManager.profile.update_mood(val)
            else:
                var clean_val = val.replace(" ", "").replace("。", "").replace("！", "").replace("!", "")
                if GameDataManager.mood_system.is_valid_mood(clean_val):
                    mood_change = clean_val
                    GameDataManager.profile.update_mood(clean_val)
                else:
                    print("Warning: Invalid mood tag received: ", val)
        clean_text = clean_text.replace(m.get_string(0), "")
        
    if mood_change == "":
        var detected_mood = GameDataManager.mood_system.get_mood_by_keywords(clean_text)
        if detected_mood != "" and detected_mood != GameDataManager.profile.current_mood:
            print("【心情系统】检测到关键词触发心情切换: ", detected_mood)
            mood_change = detected_mood
            GameDataManager.profile.update_mood(detected_mood)
            
    var any_tag_regex = RegEx.new()
    any_tag_regex.compile("(?i)(?:<|\\<|《|\\[|【)[^>\\>》\\]】]*?[:：][^>\\>》\\]】]*?(?:>|\\>|》|\\]|】)")
    if any_tag_regex.is_valid():
        clean_text = any_tag_regex.sub(clean_text, "", true)
        
    clean_text = clean_text.strip_edges()
    
    if mood_change != "":
        toast.show_toast("心情变为：" + mood_change, Color.ORANGE)
        
    var tts_text = clean_text
    
    var action_regex1 = RegEx.new()
    action_regex1.compile("\\(.*?\\)")
    tts_text = action_regex1.sub(tts_text, "", true)
    
    var action_regex2 = RegEx.new()
    action_regex2.compile("（.*?）")
    tts_text = action_regex2.sub(tts_text, "", true)
    
    var bracket_regex = RegEx.new()
    bracket_regex.compile("\\[.*?\\]|【.*?】|<.*?>|《.*?》")
    tts_text = bracket_regex.sub(tts_text, "", true)
    tts_text = tts_text.strip_edges()
    
    var display_text = clean_text
    var color_regex_zh = RegEx.new()
    color_regex_zh.compile("（(.*?)）")
    display_text = color_regex_zh.sub(display_text, "[color=#aaaaaa]（$1）[/color]", true)
    var color_regex_en = RegEx.new()
    color_regex_en.compile("\\((.*?)\\)")
    display_text = color_regex_en.sub(display_text, "[color=#aaaaaa]($1)[/color]", true)
    
    await _show_message_async(display_text, char_name, false, tts_text)

func _show_message(text: String, speaker_name: String = "", is_restore: bool = false, tts_text: String = "") -> void:
    _show_message_async(text, speaker_name, is_restore, tts_text)

func _show_message_async(text: String, speaker_name: String = "", is_restore: bool = false, tts_text: String = "") -> void:
    if speaker_name == "":
        speaker_name = GameDataManager.profile.char_name
        
    if speaker_name != "":
        name_label.text = speaker_name
        
    # 根据当前心情更新立绘
    if speaker_name == GameDataManager.profile.char_name:
        var current_mood = GameDataManager.profile.current_mood
        _update_character_sprite(current_mood)
        
    # 开启 BBCode 渲染
    dialogue_text.bbcode_enabled = true
    dialogue_text.text = text
    dialogue_text.visible_characters = 0
    
    # 简单的打字机效果
    var tween = create_tween()
    var duration = text.length() * 0.05 # 每个字符 0.05 秒
    tween.tween_property(dialogue_text, "visible_ratio", 1.0, duration)
    tween.finished.connect(func(): dialogue_text.visible_characters = -1)
    
    var cache_key = ""
    var is_tts_started = false
    
    # 触发TTS语音合成 (仅对 角色 发声)，如果是恢复记录则不发声
    if speaker_name == GameDataManager.profile.char_name and GameDataManager.config.voice_enabled and not is_restore:
        # 如果提供了专属的 tts_text (过滤了动作描写的纯净文本)，就用它来发声
        var text_to_speak = tts_text if tts_text != "" else text
        if text_to_speak != "":
            is_tts_started = true
            var options = {"voice_type": GameDataManager.config.doubao_voice_type}
            cache_key = doubao_tts._generate_cache_key(text_to_speak, options)
            doubao_tts.synthesize(text_to_speak, options)
        
    # 保存记录到历史管理器 (只有在非恢复模式时保存)
    if not is_restore:
        GameDataManager.history.add_message(speaker_name, text, cache_key)

    # 等待打字机效果完成
    if is_inside_tree():
        await get_tree().create_timer(duration).timeout
    
    # 如果启动了语音，并且语音还在播放中，则等待语音播放完毕
    if is_tts_started and is_inside_tree():
        # 等待一小会儿确保 TTS 请求有时间返回并开始播放
        await get_tree().create_timer(0.5).timeout 
        while audio_player.playing and is_inside_tree():
            await get_tree().process_frame

func _on_tts_success(audio_stream: AudioStream, text: String) -> void:
    if audio_player:
        audio_player.stream = audio_stream
        audio_player.play()

func _on_tts_failed(error_msg: String, text: String) -> void:
    print("TTS 失败: ", error_msg)
