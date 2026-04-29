extends CanvasLayer

var npc_id: String = ""

@onready var name_label = $Control/PortraitCenter/Portrait/NameLabel
@onready var placeholder_bg = $Control/PortraitCenter/Portrait/PlaceholderBG
@onready var options_vbox = $Control/OptionsPanel/VBoxContainer

func _ready():
    _setup_ui()

func setup(id: String) -> void:
    npc_id = id

func _setup_ui() -> void:
    if npc_id == "":
        return
        
    var npc_data = MapDataManager.get_npc_data(npc_id)
    name_label.text = npc_data.get("name", npc_id)
    
    var npc_type = npc_data.get("type", "random")
    if npc_type == "resident":
        placeholder_bg.color = Color(0.4, 0.8, 0.4)
    else:
        if npc_id == "luna": placeholder_bg.color = Color(1.0, 0.5, 0.5)
        elif npc_id == "ya": placeholder_bg.color = Color(0.5, 0.5, 1.0)
        else: placeholder_bg.color = Color(0.8, 0.8, 0.8)

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
        btn.text = action.get("label", "未知操作")
        btn.add_theme_font_size_override("font_size", 20)
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
