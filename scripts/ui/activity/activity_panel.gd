extends Control

@onready var preview_title: Label = $Panel/Margin/MainHBox/LeftPanel/PreviewTitle
@onready var preview_image: TextureRect = $Panel/Margin/MainHBox/LeftPanel/PreviewImage
@onready var schedule_title: Label = $Panel/Margin/MainHBox/LeftPanel/ScheduleTitle
@onready var schedule_slots: GridContainer = $Panel/Margin/MainHBox/LeftPanel/ScheduleSlots
@onready var outcome_list: RichTextLabel = $Panel/Margin/MainHBox/LeftPanel/OutcomePanel/Margin/VBox/OutcomeList
@onready var undo_button: Button = $Panel/Margin/MainHBox/LeftPanel/BottomHBox/UndoButton
@onready var rest_hbox: HBoxContainer = $Panel/Margin/MainHBox/LeftPanel/BottomHBox/RestHBox

@onready var energy_label: Label = $Panel/Margin/MainHBox/RightPanel/EnergyLabel
@onready var category_tabs: HBoxContainer = $Panel/Margin/MainHBox/RightPanel/CategoryTabs
@onready var tab_container: TabContainer = $Panel/Margin/MainHBox/RightPanel/TabContainer
@onready var tech_list: VBoxContainer = $Panel/Margin/MainHBox/RightPanel/TabContainer/TechList/ScrollContainer/VBox
@onready var business_list: VBoxContainer = $Panel/Margin/MainHBox/RightPanel/TabContainer/BusinessList/ScrollContainer/VBox
@onready var art_list: VBoxContainer = $Panel/Margin/MainHBox/RightPanel/TabContainer/ArtList/ScrollContainer/VBox
@onready var sports_list: VBoxContainer = $Panel/Margin/MainHBox/RightPanel/TabContainer/SportsList/ScrollContainer/VBox
@onready var academic_list: VBoxContainer = $Panel/Margin/MainHBox/RightPanel/TabContainer/AcademicList/ScrollContainer/VBox
@onready var close_button: Button = $Panel/Margin/MainHBox/RightPanel/BottomHBox/CloseButton
@onready var execute_button: Button = $Panel/Margin/MainHBox/RightPanel/BottomHBox/ExecuteButton
@onready var loading_overlay: Control = $LoadingOverlay
@onready var main_panel: PanelContainer = $Panel

@onready var loading_progress: ProgressBar = $LoadingOverlay/LoadingPanel/ProgressBar
@onready var walker_icon: Control = $LoadingOverlay/LoadingPanel/TrackControl/WalkerIcon
@onready var track_control: Control = $LoadingOverlay/LoadingPanel/TrackControl

var scheduled_activities: Array = []
var current_category_id: String = "tech"

const MAX_SLOTS = 10

var _pending_progress_tween: Tween
var _walker_tween: Tween

var stat_name_map = {
    "physical_fitness": "身体素质",
    "vitality": "体能活力",
    "academic_quality": "学业素养",
    "knowledge_reserve": "知识储备",
    "social_eq": "社交情商",
    "creative_aesthetics": "创意审美",
    "energy_recovery": "精力恢复"
}

func _ready() -> void:
    close_button.pressed.connect(_on_close_pressed)
    execute_button.pressed.connect(_on_execute_pressed)
    undo_button.pressed.connect(_on_undo_pressed)
    
    _init_slots()
    _init_category_tabs()

func _init_slots() -> void:
    var index = 0
    for child in schedule_slots.get_children():
        if child is Button:
            child.pressed.connect(_on_slot_pressed.bind(index))
            child.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
            child.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
            index += 1

func _init_category_tabs() -> void:
    var categories = GameDataManager.activity_manager.get_categories()
    
    var idx = 0
    for child in category_tabs.get_children():
        if child is Button and idx < categories.size():
            var cat = categories[idx]
            child.text = cat.name
            # Disconnect any existing connections to avoid duplicates if re-init happens
            if child.pressed.is_connected(_on_category_pressed):
                child.pressed.disconnect(_on_category_pressed)
            child.pressed.connect(_on_category_pressed.bind(cat.id, idx))
            idx += 1
        
    _populate_all_lists()
    
    # Dynamically populate rest options
    var rest_scene = load("res://scenes/ui/activity/rest_item.tscn")
    var rest_acts = GameDataManager.activity_manager.get_rest_activities()
    
    # Clear any existing non-label children just in case
    for child in rest_hbox.get_children():
        if child is PanelContainer:
            child.queue_free()
            
    for act in rest_acts:
        var item = rest_scene.instantiate()
        rest_hbox.add_child(item)
        item.setup(act)
        item.rest_pressed.connect(_on_activity_pressed)
        item.rest_hovered.connect(_on_activity_hovered)

func _populate_all_lists() -> void:
    var item_scene = load("res://scenes/ui/activity/activity_item.tscn")
    var categories = GameDataManager.activity_manager.get_categories()
    
    var lists = [tech_list, business_list, art_list, sports_list, academic_list]
    
    for i in range(categories.size()):
        var cat_id = categories[i].id
        var list_container = lists[i]
        
        # Clear existing
        for child in list_container.get_children():
            child.queue_free()
            
        var acts = GameDataManager.activity_manager.get_activities_by_category(cat_id)
        for act in acts:
            var item = item_scene.instantiate()
            list_container.add_child(item)
            item.setup(act)
            item.activity_pressed.connect(_on_activity_pressed)
            item.activity_hovered.connect(_on_activity_hovered)

func _on_category_pressed(cat_id: String, tab_index: int = 0) -> void:
    current_category_id = cat_id
    tab_container.current_tab = tab_index
    
    for child in category_tabs.get_children():
        if child is Button:
            var is_selected = false
            var cat_info = _get_category_by_name(child.text)
            if cat_info and cat_info.id == cat_id:
                is_selected = true
            
            if is_selected:
                child.modulate = Color(1.2, 1.2, 1.2)
            else:
                child.modulate = Color(0.8, 0.8, 0.8)

func _get_category_by_name(cat_name: String) -> Dictionary:
    var categories = GameDataManager.activity_manager.get_categories()
    for cat in categories:
        if cat.name == cat_name:
            return cat
    return {}

func show_panel() -> void:
    _update_ui()
    if current_category_id == "":
        current_category_id = "tech"
    _on_category_pressed(current_category_id)
    
    loading_overlay.hide()
    main_panel.show()
    show()
    
    # Add popup animation
    modulate.a = 0.0
    var tween = create_tween()
    tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
    tween.tween_property(self, "modulate:a", 1.0, 0.3)
    
    scale = Vector2(0.9, 0.9)
    pivot_offset = get_viewport_rect().size / 2.0
    var scale_tween = create_tween()
    scale_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
    scale_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.3)

func hide_panel() -> void:
    var tween = create_tween()
    tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
    tween.tween_property(self, "modulate:a", 0.0, 0.2)
    var scale_tween = create_tween()
    scale_tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
    scale_tween.tween_property(self, "scale", Vector2(0.9, 0.9), 0.2)
    scale_tween.finished.connect(hide)

func _update_ui() -> void:
    var profile = GameDataManager.profile
    energy_label.text = "当前精力：%.1f / %.1f" % [profile.current_energy, profile.max_energy]
    
    schedule_title.text = "日程安排 (%d/%d)" % [scheduled_activities.size(), MAX_SLOTS]
    
    var slots = schedule_slots.get_children()
    for i in range(MAX_SLOTS):
        var btn = slots[i] as Button
        if i < scheduled_activities.size():
            var act_id = scheduled_activities[i]
            var act = GameDataManager.activity_manager.get_activity_by_id(act_id)
            if not act.is_empty():
                btn.text = "" 
                if act.has("icon_path"):
                    var icon_res = load(act.icon_path)
                    if icon_res:
                        btn.icon = icon_res
                else:
                    btn.text = act.name.substr(0, 1) 
            else:
                btn.text = "未知"
                btn.icon = null
        else:
            btn.text = "空"
            btn.icon = null
            
    execute_button.disabled = scheduled_activities.size() < MAX_SLOTS
    undo_button.disabled = scheduled_activities.size() == 0
    
    _update_outcome()

func _update_outcome() -> void:
    var total_rewards = {}
    var total_energy_cost = 0
    
    for act_id in scheduled_activities:
        var act = GameDataManager.activity_manager.get_activity_by_id(act_id)
        if act.is_empty(): continue
        
        total_energy_cost += act.get("energy_cost", 0)
        
        if act.has("rewards"):
            for key in act.rewards.keys():
                var range_arr = act.rewards[key]
                var avg_val = (range_arr[0] + range_arr[1]) / 2.0
                if not total_rewards.has(key):
                    total_rewards[key] = 0.0
                total_rewards[key] += avg_val
                
    var outcome_text = ""
    if total_energy_cost > 0:
        outcome_text += "[color=#d05050]预计精力消耗: -%d[/color]\n" % total_energy_cost
        
    for key in total_rewards.keys():
        var display_name = stat_name_map.get(key, key)
        var val = total_rewards[key]
        outcome_text += "[color=#40a040]%s: +%.1f (预计)[/color]\n" % [display_name, val]
        
    if outcome_text == "":
        outcome_text = "[color=#888888]暂无安排[/color]"
        
    outcome_list.text = outcome_text

func _on_activity_hovered(act: Dictionary) -> void:
    preview_title.text = act.name
    if act.has("preview_image") and act.preview_image != "":
        var tex = load(act.preview_image)
        if tex:
            preview_image.texture = tex
        else:
            preview_image.texture = null
    else:
        preview_image.texture = null

func _on_activity_pressed(activity_id: String) -> void:
    if scheduled_activities.size() < MAX_SLOTS:
        scheduled_activities.append(activity_id)
        _update_ui()

func _on_slot_pressed(index: int) -> void:
    pass # 取消点击移除逻辑，只能通过撤销按钮

func _on_undo_pressed() -> void:
    if scheduled_activities.size() > 0:
        scheduled_activities.pop_back()
        _update_ui()

func _on_execute_pressed() -> void:
    if scheduled_activities.size() == MAX_SLOTS:
        # 隐藏主面板，显示全屏过渡遮罩
        main_panel.hide()
        loading_overlay.modulate.a = 0.0
        loading_overlay.show()
        
        var tween = create_tween()
        tween.tween_property(loading_overlay, "modulate:a", 1.0, 0.3)
        
        # 重置动画状态
        loading_progress.value = 0.0
        walker_icon.position.x = 0.0
        walker_icon.position.y = -40.0
        
        if _pending_progress_tween: _pending_progress_tween.kill()
        if _walker_tween: _walker_tween.kill()
        
        # 创建进度条假加载动画 (5秒内走到90%)
        _pending_progress_tween = create_tween()
        _pending_progress_tween.tween_method(_update_loading_progress, 0.0, 90.0, 5.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
        
        # 创建小人上下蹦跳行走的动画
        _walker_tween = create_tween().set_loops()
        _walker_tween.tween_property(walker_icon, "position:y", -50.0, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
        _walker_tween.tween_property(walker_icon, "position:y", -40.0, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
        
        var courses_data = []
        
        # 收集所有 10 节课的数据，用于面板内部动态切换
        for act_id in scheduled_activities:
            var act = GameDataManager.activity_manager.get_activity_by_id(act_id)
            var single_course = {
                "name": act.get("name", "未知课程"),
                "image_path": act.get("preview_image", ""),
                "bonus_list": [],
                "desc": "正在生成描述中..." # 默认占位符
            }
            
            # 当前这节课的收益
            if act.has("rewards"):
                for stat_key in act["rewards"]:
                    var range_arr = act["rewards"][stat_key]
                    var avg_val = (range_arr[0] + range_arr[1]) / 2.0
                    
                    var zh_name = ""
                    match stat_key:
                        "physical_fitness": zh_name = "身体素质"
                        "academic_quality": zh_name = "学业素养"
                        "social_eq": zh_name = "社交情商"
                        "creative_aesthetics": zh_name = "艺术修养"
                        "vitality": zh_name = "体能活力"
                        "knowledge_reserve": zh_name = "知识储备"
                        "energy_recovery": zh_name = "精力恢复"
                        _: zh_name = stat_key
                        
                    single_course["bonus_list"].append({"name": zh_name, "value": avg_val})
            
            courses_data.append(single_course)
            
        # 发送预生成请求
        _fetch_all_course_descriptions_from_ai(courses_data)
        
        # 从真实的 profile 中获取初始属性
        var profile = GameDataManager.profile
        var start_attrs = {
            "身体素质": profile.physical_fitness,
            "学业素养": profile.academic_quality,
            "社交情商": profile.social_eq,
            "艺术修养": profile.creative_aesthetics,
            "体能活力": profile.vitality,
            "知识储备": profile.knowledge_reserve,
            "精力": profile.current_energy
        }
        var end_attrs = start_attrs.duplicate()
        
        # 计算整周(10节课)累积下来的真实收益（用于最后的结算面板）
        for course in courses_data:
            for bonus in course["bonus_list"]:
                var zh_name = bonus["name"]
                var val = bonus["value"]
                if zh_name == "精力恢复":
                    end_attrs["精力"] += val
                else:
                    if not end_attrs.has(zh_name):
                        end_attrs[zh_name] = start_attrs.get(zh_name, 0)
                    end_attrs[zh_name] += val
                
        # --- 注意：这里不要直接调用 setup() ---
        # 我们将数据暂存起来，等待 HTTP 请求完成或超时后再打开面板
        _pending_exec_data = {
            "courses_data": courses_data,
            "start_attrs": start_attrs,
            "end_attrs": end_attrs
        }
        
        scheduled_activities.clear()

var _pending_exec_data: Dictionary = {}

func _fetch_all_course_descriptions_from_ai(courses_data: Array) -> void:
    var api_key = ""
    if GameDataManager.config != null:
        api_key = GameDataManager.config.api_key
        
    if api_key.is_empty():
        _fallback_all_descriptions()
        return
        
    var http = HTTPRequest.new()
    http.timeout = 10.0
    add_child(http)
    http.request_completed.connect(func(res, code, hdrs, body): _on_all_ai_descriptions_completed(res, code, hdrs, body, http))
    
    var url = "https://api.deepseek.com/v1/chat/completions" 
    if "api_url" in GameDataManager.config and not GameDataManager.config.api_url.is_empty():
        url = GameDataManager.config.api_url
        
    var headers = [
        "Content-Type: application/json",
        "Authorization: Bearer " + api_key
    ]
    
    # 将十门课拼接起来
    var course_list_str = ""
    for i in range(courses_data.size()):
        course_list_str += "%d. 【%s】\n" % [i + 1, courses_data[i]["name"]]
        
    var profile = GameDataManager.profile
    var char_name = profile.char_name if profile else "角色"
        
    var prompt = "这里有一份本周的学习计划，共 10 节课（包含休息）。请你作为旁白（第三人称视角），针对这 10 节课依次生成一段 20 到 50 字以内、生动形象的文字，描述 %s 正在进行该课程时的画面和状态。注意必须严格按顺序，用一个 JSON 数组返回。格式要求如下：\n" % char_name
    prompt += "```json\n[\n"
    prompt += "  \"(针对第1节课的描述)\",\n"
    prompt += "  \"(针对第2节课的描述)\",\n"
    prompt += "  ... (共10个元素)\n"
    prompt += "]\n```\n"
    prompt += "以下是这周的课程列表：\n" + course_list_str
    
    var body = {
        "model": GameDataManager.config.model if "model" in GameDataManager.config else "deepseek-chat",
        "messages": [{"role": "user", "content": prompt}],
        "temperature": 0.7,
        "response_format": {"type": "json_object"}
    }
    
    var err = http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
    if err != OK:
        _fallback_all_descriptions()

func _update_loading_progress(val: float) -> void:
    if not is_instance_valid(loading_progress): return
    loading_progress.value = val
    var max_x = track_control.size.x - walker_icon.size.x
    walker_icon.position.x = max_x * (val / 100.0)

func _finish_loading_and_open() -> void:
    if _pending_progress_tween: _pending_progress_tween.kill()
    
    var finish_tween = create_tween()
    var start_val = loading_progress.value
    finish_tween.tween_method(_update_loading_progress, start_val, 100.0, 0.3).set_ease(Tween.EASE_IN_OUT)
    finish_tween.finished.connect(func():
        if _walker_tween: _walker_tween.kill()
        walker_icon.position.y = -40.0
        
        # 等待 0.2 秒让玩家看清 100% 满进度
        await get_tree().create_timer(0.2).timeout
        _open_execution_panel()
    )

func _on_all_ai_descriptions_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest) -> void:
    http.queue_free()
    
    if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
        _fallback_all_descriptions()
        return
        
    var json = JSON.parse_string(body.get_string_from_utf8())
    if json and json.has("choices") and json["choices"].size() > 0:
        var text = json["choices"][0]["message"]["content"].strip_edges()
        
        # 尝试解析 JSON 数组
        var extracted_json_str = _extract_json_array(text)
        var parsed_array = JSON.parse_string(extracted_json_str)
        
        if parsed_array is Array and parsed_array.size() >= 1:
            var courses = _pending_exec_data["courses_data"]
            for i in range(min(parsed_array.size(), courses.size())):
                var desc_str = str(parsed_array[i]).strip_edges()
                desc_str = desc_str.replace("\"", "").replace("'", "").replace("“", "").replace("”", "")
                if desc_str != "":
                    courses[i]["desc"] = desc_str
            _finish_loading_and_open()
            return
            
    _fallback_all_descriptions()

func _extract_json_array(text: String) -> String:
    # 简单提取 [] 内容
    var start = text.find("[")
    var end = text.rfind("]")
    if start != -1 and end != -1 and end > start:
        return text.substr(start, end - start + 1)
    return "[]"

func _fallback_all_descriptions() -> void:
    # 使用备用描述
    if _pending_exec_data.is_empty(): return
    var courses = _pending_exec_data["courses_data"]
    for course in courses:
        var c_name = course["name"]
        if "休息" in c_name:
            course["desc"] = "今天给自己放了个假，彻底放松下来，恢复了精力。"
        else:
            course["desc"] = "今天也是按部就班地完成了【%s】的训练，感觉收获颇丰。" % c_name
            
    _finish_loading_and_open()

func _open_execution_panel() -> void:
    if _pending_exec_data.is_empty():
        return
        
    var main_scene = get_tree().current_scene
    var exec_panel_obj = load("res://scenes/ui/activity/schedule_execution_panel.tscn")
    var exec_panel = exec_panel_obj.instantiate()
    main_scene.add_child(exec_panel)
    exec_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    
    exec_panel.setup(
        _pending_exec_data["courses_data"],
        _pending_exec_data["start_attrs"],
        _pending_exec_data["end_attrs"]
    )
    
    _pending_exec_data.clear()
    
    # 完全关闭安排面板
    hide()

func _on_close_pressed() -> void:
    hide_panel()
