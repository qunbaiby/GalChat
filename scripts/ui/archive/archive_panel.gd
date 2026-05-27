extends Control

@onready var close_btn: Button = $Panel/VBoxContainer/TopBar/CloseButton
@onready var tab_container: TabContainer = $Panel/VBoxContainer/TabContainer

# 性格演化
@onready var radar_chart: Control = $"Panel/VBoxContainer/TabContainer/性格演化/ScrollContainer/VBox/ChartCard/ContentVBox/ChartsVBox/RadarChart"
@onready var line_chart: Control = $"Panel/VBoxContainer/TabContainer/性格演化/ScrollContainer/VBox/ChartCard/ContentVBox/ChartsVBox/LineChart"
@onready var base_personality_text: RichTextLabel = $"Panel/VBoxContainer/TabContainer/性格演化/ScrollContainer/VBox/BaseTraitsCard/ContentVBox/AnalysisVBox/BasePersonalityText"
@onready var status_text: RichTextLabel = $"Panel/VBoxContainer/TabContainer/性格演化/ScrollContainer/VBox/ChartCard/ContentVBox/AnalysisVBox/StatusVBox/Text"
@onready var behavior_text: RichTextLabel = $"Panel/VBoxContainer/TabContainer/性格演化/ScrollContainer/VBox/ChartCard/ContentVBox/AnalysisVBox/BehaviorVBox/Text"
@onready var advice_text: RichTextLabel = $"Panel/VBoxContainer/TabContainer/性格演化/ScrollContainer/VBox/ChartCard/ContentVBox/AnalysisVBox/AdviceVBox/Text"
@onready var deepseek_client = $DeepSeekClient

# 记忆库
@onready var memory_list_container: VBoxContainer = $"Panel/VBoxContainer/TabContainer/记忆库/ScrollContainer/MemoryListContainer"
@onready var relation_graph_view = $"Panel/VBoxContainer/TabContainer/人物关系/ScrollContainer/RelationGraphView"

func _ready() -> void:
    close_btn.pressed.connect(_on_close_pressed)

func show_panel() -> void:
    var char_id = "luna"
    if GameDataManager.config and GameDataManager.config.current_character_id != "":
        char_id = GameDataManager.config.current_character_id
        
    _load_char_archive(char_id)
    show()
    
    # 打开动画：从右侧滑入并淡入
    position.x = size.x
    modulate.a = 0.0
    var tween = create_tween()
    tween.set_parallel(true)
    tween.tween_property(self, "position:x", 0.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    tween.tween_property(self, "modulate:a", 1.0, 0.2)

func _load_char_archive(char_id: String) -> void:
    # 临时加载该角色的 Profile 和 Memory
    var temp_profile = CharacterProfile.new()
    temp_profile.load_profile(char_id)
    
    # 读取记忆
    var mem_path = "user://saves/%s/player_memory.json" % char_id
    var mems = { "core": [], "emotion": [], "habit": [], "bond": [] }
    if FileAccess.file_exists(mem_path):
        var file = FileAccess.open(mem_path, FileAccess.READ)
        var content = file.get_as_text()
        var json = JSON.new()
        if json.parse(content) == OK and json.data is Dictionary:
            var data = json.data
            for key in mems.keys():
                if data.has(key) and data[key] is Array:
                    mems[key] = data[key]
                    
    _update_personality_display(temp_profile)
    _update_memory_display(mems)
    if is_instance_valid(relation_graph_view):
        relation_graph_view.set_archive_data(char_id, temp_profile)

func _get_story_day_offset_for_char(char_id: String) -> int:
    var path = "user://saves/%s/story_time_save.json" % char_id
    if not FileAccess.file_exists(path):
        return 0
    var file = FileAccess.open(path, FileAccess.READ)
    if file == null:
        return 0
    var json = JSON.new()
    var result = json.parse(file.get_as_text())
    file.close()
    if result != OK or not json.data is Dictionary:
        return 0
    return int(json.data.get("current_day_offset", 0))

func _update_personality_display(profile: CharacterProfile) -> void:
    var base_o = profile.base_personality.get("openness", 50.0)
    var base_c = profile.base_personality.get("conscientiousness", 50.0)
    var base_e = profile.base_personality.get("extraversion", 50.0)
    var base_a = profile.base_personality.get("agreeableness", 50.0)
    var base_n = profile.base_personality.get("neuroticism", 50.0)
    
    # 更新雷达图数据，确保传入的数组元素是 float 类型
    var base_values: Array[float] = [float(base_o), float(base_c), float(base_e), float(base_a), float(base_n)]
    var dynamic_values: Array[float] = [float(profile.openness), float(profile.conscientiousness), float(profile.extraversion), float(profile.agreeableness), float(profile.neuroticism)]
    radar_chart.set_values(base_values, dynamic_values)
    
    # 更新折线图数据
    var history = profile.personality_history.duplicate()
    # 把当前最新状态作为最后一天加上去
    var current_day_offset = _get_story_day_offset_for_char(profile.current_character_id)
    history.append({
        "day_offset": current_day_offset,
        "openness": float(profile.openness),
        "conscientiousness": float(profile.conscientiousness),
        "extraversion": float(profile.extraversion),
        "agreeableness": float(profile.agreeableness),
        "neuroticism": float(profile.neuroticism)
    })
    line_chart.set_data(history)
    
    var base_traits_str = GameDataManager.personality_system.get_base_traits(profile)
    if base_traits_str == "":
        if is_instance_valid(base_personality_text):
            base_personality_text.text = "暂无初始底色配置"
    else:
        if is_instance_valid(base_personality_text):
            base_personality_text.text = base_traits_str
        
    var dynamic_traits_parts: Array = [
        GameDataManager.personality_system.get_personality_state_summary(profile),
        GameDataManager.personality_system.get_recent_event_summary(profile),
        GameDataManager.personality_system.get_pressure_summary(profile),
        GameDataManager.personality_system.get_pattern_summary(profile),
        GameDataManager.personality_system.get_last_settlement_summary(profile),
        "",
        GameDataManager.personality_system.get_dynamic_traits(profile)
    ]
    var dynamic_traits_str = "\n".join(dynamic_traits_parts)
    if is_instance_valid(status_text):
        status_text.text = "AI 正在分析性格演化..."
        behavior_text.text = "等待分析..."
        advice_text.text = "等待分析..."
    
    _request_ai_personality_summary(profile, base_traits_str, dynamic_traits_str)

func _request_ai_personality_summary(profile: CharacterProfile, base_traits: String, dynamic_traits: String) -> void:
    if not is_instance_valid(deepseek_client):
        status_text.text = "AI 分析服务未就绪"
        return
        
    var system_prompt = "你是一位专业的心理学与人物性格分析师。请根据以下角色的【初始底色】和【当前因为属性变化而激活的动态性格特征】，分析该角色目前的性格状态、可能的行为倾向，以及给玩家的相处建议。\n请必须返回严格的JSON格式数据，不要包含任何Markdown代码块(如```json)，直接返回如下结构：\n{\"status\": \"性格状态描述(50-100字)\", \"behavior\": \"行为倾向描述(50-100字)\", \"advice\": \"相处建议(50-100字)\"}"
    var user_prompt = "角色名称：" + profile.char_name + "\n\n" + base_traits + "\n\n【当前激活的动态特征】\n" + dynamic_traits
    
    if deepseek_client.chat_request_completed.is_connected(_on_ai_summary_completed):
        deepseek_client.chat_request_completed.disconnect(_on_ai_summary_completed)
    if deepseek_client.chat_request_failed.is_connected(_on_ai_summary_failed):
        deepseek_client.chat_request_failed.disconnect(_on_ai_summary_failed)
        
    deepseek_client.chat_request_completed.connect(_on_ai_summary_completed, CONNECT_ONE_SHOT)
    deepseek_client.chat_request_failed.connect(_on_ai_summary_failed, CONNECT_ONE_SHOT)
    
    var messages = [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": user_prompt}
    ]
    
    deepseek_client.call_chat_api_non_stream(messages)

func _on_ai_summary_completed(response: Dictionary) -> void:
    if is_instance_valid(status_text):
        if response.has("choices") and response["choices"].size() > 0:
            var content = response["choices"][0].get("message", {}).get("content", "")
            var json = JSON.new()
            var err = json.parse(content)
            if err == OK and typeof(json.data) == TYPE_DICTIONARY:
                status_text.text = json.data.get("status", "分析失败")
                behavior_text.text = json.data.get("behavior", "分析失败")
                advice_text.text = json.data.get("advice", "分析失败")
            else:
                status_text.text = "[color=red]AI 返回格式无法解析[/color]\n" + content
                behavior_text.text = "等待分析..."
                advice_text.text = "等待分析..."
        else:
            status_text.text = "[color=red]AI 返回格式错误[/color]"
    else:
        # 如果组件还没加载好或者被销毁了，不要直接赋值
        pass

func _on_ai_summary_failed(err_msg: String) -> void:
    if is_instance_valid(status_text):
        status_text.text = "[color=red]AI 分析失败: " + err_msg + "[/color]"
        behavior_text.text = "分析失败"
        advice_text.text = "分析失败"

func _update_memory_display(mems: Dictionary) -> void:
    # 清空旧的记忆卡片
    for child in memory_list_container.get_children():
        child.queue_free()
        
    _add_memory_category("核心记忆 (Core)", mems.get("core", []), Color("#ff6b81"))
    _add_memory_category("情绪记忆 (Emotion)", mems.get("emotion", []), Color("#1e90ff"))
    _add_memory_category("习惯记忆 (Habit)", mems.get("habit", []), Color("#ff4757"))
    _add_memory_category("羁绊记忆 (Bond)", mems.get("bond", []), Color("#fbc531"))

func _add_memory_category(title: String, items: Array, color: Color) -> void:
    if items.size() == 0:
        return
        
    # 创建分类标题面板 (类似参考图的深色卡片头部)
    var header_panel = PanelContainer.new()
    var header_style = StyleBoxFlat.new()
    header_style.bg_color = Color(0.12, 0.13, 0.15, 0.9)
    header_style.corner_radius_top_left = 8
    header_style.corner_radius_top_right = 8
    header_style.corner_radius_bottom_left = 8
    header_style.corner_radius_bottom_right = 8
    header_panel.add_theme_stylebox_override("panel", header_style)
    
    var header_margin = MarginContainer.new()
    header_margin.add_theme_constant_override("margin_left", 15)
    header_margin.add_theme_constant_override("margin_top", 10)
    header_margin.add_theme_constant_override("margin_right", 15)
    header_margin.add_theme_constant_override("margin_bottom", 10)
    header_panel.add_child(header_margin)
    
    var header_vbox = VBoxContainer.new()
    header_vbox.add_theme_constant_override("separation", 10)
    header_margin.add_child(header_vbox)
    
    var title_label = Label.new()
    title_label.text = "◆ " + title
    title_label.add_theme_color_override("font_color", color)
    title_label.add_theme_font_size_override("font_size", 16)
    header_vbox.add_child(title_label)
    
    # 分割线
    var sep = ColorRect.new()
    sep.custom_minimum_size = Vector2(0, 1)
    sep.color = Color(1, 1, 1, 0.1)
    header_vbox.add_child(sep)
    
    # 记忆项列表
    var items_vbox = VBoxContainer.new()
    items_vbox.add_theme_constant_override("separation", 8)
    header_vbox.add_child(items_vbox)
    
    for item in items:
        var text = ""
        var timestamp = ""
        var is_bond = false
        var decay = 0.0
        
        if item is Dictionary:
            text = item.get("content", "")
            timestamp = item.get("story_time", "")
            if timestamp == "":
                # Fallback to system timestamp if story time is empty
                timestamp = item.get("timestamp", "").split("T")[0] 
            is_bond = item.get("is_bond_mark", false)
            decay = item.get("decay", 0.0)
        elif item is String:
            text = item
            
        var item_card = PanelContainer.new()
        var card_style = StyleBoxFlat.new()
        card_style.bg_color = Color(0.18, 0.20, 0.23, 0.8)
        card_style.corner_radius_top_left = 6
        card_style.corner_radius_top_right = 6
        card_style.corner_radius_bottom_left = 6
        card_style.corner_radius_bottom_right = 6
        # 如果是羁绊印记，给一个特殊的金色边框
        if is_bond:
            card_style.border_width_left = 2
            card_style.border_width_top = 2
            card_style.border_width_right = 2
            card_style.border_width_bottom = 2
            card_style.border_color = Color("#fbc531")
        item_card.add_theme_stylebox_override("panel", card_style)
        
        var card_margin = MarginContainer.new()
        card_margin.add_theme_constant_override("margin_left", 15)
        card_margin.add_theme_constant_override("margin_top", 10)
        card_margin.add_theme_constant_override("margin_right", 15)
        card_margin.add_theme_constant_override("margin_bottom", 10)
        item_card.add_child(card_margin)
        
        var card_hbox = HBoxContainer.new()
        card_hbox.add_theme_constant_override("separation", 15)
        card_margin.add_child(card_hbox)
        
        # 左侧时间戳
        var time_vbox = VBoxContainer.new()
        card_hbox.add_child(time_vbox)
        
        var time_dot = Label.new()
        time_dot.text = "◆"
        time_dot.add_theme_color_override("font_color", Color("#7bed9f"))
        time_dot.add_theme_font_size_override("font_size", 12)
        time_dot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        time_vbox.add_child(time_dot)
        
        var time_label = Label.new()
        time_label.text = timestamp.split(" ")[0] if " " in timestamp else timestamp # 只要日期部分
        time_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
        time_label.add_theme_font_size_override("font_size", 14)
        time_vbox.add_child(time_label)
        
        # 中间文本内容
        var content_label = RichTextLabel.new()
        content_label.bbcode_enabled = true
        content_label.text = text
        content_label.fit_content = true
        content_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        content_label.add_theme_font_size_override("normal_font_size", 15)
        card_hbox.add_child(content_label)
        
        # 右侧羁绊印记/贴纸
        if is_bond:
            var bond_label = Label.new()
            bond_label.text = "✨羁绊印记"
            bond_label.add_theme_color_override("font_color", Color("#fbc531"))
            bond_label.add_theme_font_size_override("font_size", 12)
            card_hbox.add_child(bond_label)
        elif decay > 0.0:
            var decay_label = Label.new()
            decay_label.text = "遗忘: %d%%" % int(decay)
            decay_label.add_theme_color_override("font_color", Color(0.6, 0.4, 0.4))
            decay_label.add_theme_font_size_override("font_size", 12)
            card_hbox.add_child(decay_label)
            
        items_vbox.add_child(item_card)
        
    memory_list_container.add_child(header_panel)

func _on_close_pressed() -> void:
    var tween = create_tween()
    tween.set_parallel(true)
    tween.tween_property(self, "position:x", size.x, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
    tween.tween_property(self, "modulate:a", 0.0, 0.2)
    tween.chain().tween_callback(self.hide)
