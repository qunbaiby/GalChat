extends CanvasLayer

var npc_id: String = ""

@onready var options_vbox = $Control/InfoAndOptions/OptionsVBox

@onready var menu_title_label = $Control/InfoAndOptions/NPCInfoVBox/TitleLabel
@onready var name_label = $Control/InfoAndOptions/NPCInfoVBox/NameLabel
@onready var menu_stage_label = $Control/InfoAndOptions/NPCInfoVBox/StageHBox/StageLabel
@onready var menu_hearts_label = $Control/InfoAndOptions/NPCInfoVBox/HeartsLabel

func _ready():
    _setup_ui()

func setup(id: String) -> void:
    npc_id = id

func _setup_ui() -> void:
    if npc_id == "":
        return
        
    var npc_data = MapDataManager.get_npc_data(npc_id)
    var npc_name = npc_data.get("name", npc_id)
    
    var char_file_path = "res://assets/data/characters/npc/" + npc_id + ".json"
    if npc_id == "luna":
        char_file_path = "res://assets/data/characters/luna.json"
        
    var npc_title = "未知"
    
    var file = FileAccess.open(char_file_path, FileAccess.READ)
    if file:
        var json = JSON.new()
        if json.parse(file.get_as_text()) == OK:
            var data = json.get_data()
            if data is Dictionary:
                npc_name = data.get("char_name", npc_name)
                npc_title = data.get("title", npc_title)
                
    name_label.text = npc_name
    if npc_id == "luna":
        menu_title_label.text = "魔法少女" # 或从配置读取
    else:
        menu_title_label.text = npc_title
        
    # 好感度及情感阶段展示逻辑
    if npc_id == "luna":
        var profile = GameDataManager.profile
        var current_stage = profile.current_stage
        var conf = profile.get_current_stage_config()
        menu_stage_label.text = conf.get("stageTitle", "陌生人")
        
        # 构建爱心字符串 (根据当前阶段显示实心心，总共10颗心)
        var max_hearts = 10
        var filled_hearts = min(current_stage, max_hearts)
        var hearts_str = ""
        for i in range(max_hearts):
            if i < filled_hearts:
                hearts_str += "♥"
            else:
                hearts_str += "♡"
        menu_hearts_label.text = hearts_str
    else:
        # 默认非主角NPC的好感度展示
        menu_stage_label.text = "普通朋友"
        menu_hearts_label.text = "♥♡♡♡♡♡♡♡♡♡"
    
    # Clear existing buttons
    for child in options_vbox.get_children():
        child.queue_free()
        
    # Generate dynamic interaction buttons based on NPC data
    var interactions = npc_data.get("interactions", [])
    if interactions.is_empty():
        # Fallback interactions if not defined in json
        interactions = [{"id": "chat", "label": "聊天"}, {"id": "leave", "label": "离开"}]
        
    for action in interactions:
        var btn = Button.new()
        var action_label = action.get("label", "未知操作")
        
        # 添加对应的图标前缀 (根据ID简单匹配)
        var icon_str = "💬 "
        match action.get("id", ""):
            "chat": icon_str = "💬 "
            "order": icon_str = "☕ "
            "gift": icon_str = "🎁 "
            "leave": icon_str = "🏃 "
            "interact": icon_str = "✨ "
            "invite", "date": icon_str = "💕 "
        
        btn.text = icon_str + action_label
        btn.add_theme_font_size_override("font_size", 22)
        btn.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85, 1))
        btn.add_theme_color_override("font_hover_color", Color(1, 0.9, 0.6, 1))
        
        # 样式设计
        var style_normal = StyleBoxFlat.new()
        style_normal.bg_color = Color(0.15, 0.2, 0.3, 0.8)
        style_normal.corner_radius_top_left = 25
        style_normal.corner_radius_top_right = 25
        style_normal.corner_radius_bottom_left = 25
        style_normal.corner_radius_bottom_right = 25
        style_normal.border_width_bottom = 2
        style_normal.border_width_top = 2
        style_normal.border_width_left = 2
        style_normal.border_width_right = 2
        style_normal.border_color = Color(0.8, 0.7, 0.4, 0.5) # 淡淡的金边
        style_normal.content_margin_left = 30
        style_normal.content_margin_right = 30
        style_normal.content_margin_top = 15
        style_normal.content_margin_bottom = 15
        
        var style_hover = style_normal.duplicate()
        style_hover.bg_color = Color(0.2, 0.25, 0.35, 0.9)
        style_hover.border_color = Color(1.0, 0.9, 0.5, 0.8) # 高亮的金边
        
        var style_pressed = style_normal.duplicate()
        style_pressed.bg_color = Color(0.1, 0.15, 0.25, 0.9)
        style_pressed.border_color = Color(0.6, 0.5, 0.3, 0.8)
        
        btn.add_theme_stylebox_override("normal", style_normal)
        btn.add_theme_stylebox_override("hover", style_hover)
        btn.add_theme_stylebox_override("pressed", style_pressed)
        btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
        
        btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
        
        btn.pressed.connect(_on_action_pressed.bind(action.get("id", "")))
        options_vbox.add_child(btn)

func _on_action_pressed(action_id: String):
    match action_id:
        "chat":
            print("与 NPC: ", npc_id, " 聊天")
            # TODO: 触发聊天对话系统
        "order":
            print("与 NPC: ", npc_id, " 互动/点单")
            if npc_id == "ya":
                var order_menu_scene = load("res://scenes/ui/map/cafe/cafe_order_menu.tscn")
                if order_menu_scene:
                    var order_menu = order_menu_scene.instantiate()
                    get_tree().root.add_child(order_menu)
                queue_free()
            else:
                # TODO: 触发其他 NPC 的商店或特殊互动
                pass
        "interact":
            print("与 NPC: ", npc_id, " 互动")
            # TODO: 触发特殊互动
        "gift":
            print("给 NPC: ", npc_id, " 送礼")
            # TODO: 打开送礼界面
        "leave":
            queue_free()
        _:
            print("未知操作: ", action_id)
