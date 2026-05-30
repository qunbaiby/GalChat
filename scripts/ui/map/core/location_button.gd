extends Button

const LOCATION_HOVER_TOOLTIP_SCENE = preload("res://scenes/ui/map/core/location_hover_tooltip.tscn")

var location_id: String = ""
var loc_description: String = ""
var custom_tooltip: PanelContainer = null

@onready var icon_rect: TextureRect = $IconRect
@onready var name_label: Label = $NameTag/NameLabel

func _ready():
    mouse_entered.connect(_on_mouse_entered)
    mouse_exited.connect(_on_mouse_exited)

func _exit_tree():
    if custom_tooltip != null:
        custom_tooltip.queue_free()
        custom_tooltip = null

func setup(loc_data: Dictionary) -> void:
    location_id = loc_data.get("id", "")
    text = "" # 清空Button自身的文字
    loc_description = loc_data.get("description", "暂无描述")
    
    var loc_name = loc_data.get("name", "未知地点")
    
    # Check if locked
    var is_unlocked = MapDataManager.is_location_unlocked(location_id)
    if not is_unlocked:
        loc_name = "🔒 " + loc_name
        self.modulate = Color(0.6, 0.6, 0.6, 0.8) # 变暗
    else:
        self.modulate = Color(1.0, 1.0, 1.0, 1.0)
    
    if name_label:
        name_label.text = loc_name
    
    if icon_rect:
        var icon_name = loc_data.get("icon", "")
        if icon_name == "":
            icon_name = "loc_" + location_id
            
        var img_path = ""
        if GameDataManager.has_method("get_image_manager"):
            pass # ImageManager is a singleton
        
        # 尝试获取真实的地标图片
        img_path = ImageManager.get_image_path(icon_name)
            
        if img_path != "" and ResourceLoader.exists(img_path):
            icon_rect.texture = load(img_path)
        else:
            # 如果没有真实图片，用一个占位符代替
            var placeholder = GradientTexture2D.new()
            placeholder.width = 120
            placeholder.height = 120
            var gradient = Gradient.new()
            gradient.add_point(0, Color(0.3, 0.6, 0.8, 0.4))
            placeholder.gradient = gradient
            icon_rect.texture = placeholder

    var event_hbox = get_node_or_null("EventHBox")
    if event_hbox:
        for child in event_hbox.get_children():
            child.queue_free()
        
        var events = loc_data.get("events", [])
        for evt in events:
            var lbl = Label.new()
            lbl.add_theme_font_size_override("font_size", 20)
            if evt == "main":
                lbl.text = "!"
                lbl.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2)) # Red
            elif evt == "side":
                lbl.text = "?"
                lbl.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2)) # Yellow
            elif evt == "bond":
                lbl.text = "♥"
                lbl.add_theme_color_override("font_color", Color(1.0, 0.4, 0.7)) # Pink
            event_hbox.add_child(lbl)

    var npc_hbox = get_node_or_null("NPCHBox")
    if npc_hbox:
        # Clear existing npc icons
        for child in npc_hbox.get_children():
            child.queue_free()
        
        var npcs = MapDataManager.generate_location_npcs(location_id)
        for npc_id in npcs:
            var npc_data = MapDataManager.get_npc_data(npc_id)
            var npc_name = npc_data.get("name", npc_id)
            var npc_type = npc_data.get("type", "random")
            
            var char_file_path = "res://assets/data/characters/npc/" + npc_id + ".json"
            if npc_id == "luna":
                char_file_path = "res://assets/data/characters/luna.json"
                
            var portrait_texture = null
            var file = FileAccess.open(char_file_path, FileAccess.READ)
            if file:
                var json = JSON.new()
                if json.parse(file.get_as_text()) == OK:
                    var data = json.get_data()
                    if data is Dictionary:
                        npc_name = data.get("char_name", npc_name)
                        var tex_path = data.get("avatar", data.get("static_portrait", ""))
                        if not tex_path.is_empty() and ResourceLoader.exists(tex_path):
                            portrait_texture = load(tex_path)
            
            # Create a circular visual representation for the NPC
            var icon_container = Control.new()
            icon_container.custom_minimum_size = Vector2(50, 50) # 调大头像尺寸
            
            var mask = Control.new()
            mask.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
            mask.set_anchors_preset(Control.PRESET_FULL_RECT)
            icon_container.add_child(mask)
            
            # Draw the circle mask
            var mask_callable = func(m: Control):
                var center = m.size / 2.0
                var radius = min(m.size.x, m.size.y) / 2.0
                m.draw_circle(center, radius, Color.WHITE)
            mask.draw.connect(mask_callable.bind(mask))
            
            var icon_callable = func(c: Control):
                var center = c.size / 2.0
                var radius = min(c.size.x, c.size.y) / 2.0
                # 绘制一个明显一点的边框 (粗细 3，纯白，无透明度，开启抗锯齿)
                c.draw_arc(center, radius, 0, TAU, 64, Color(1.0, 1.0, 1.0, 1.0), 3.0, true)
                # 可以在内部再叠加一层稍微带点颜色的细边框增加层次感
                c.draw_arc(center, radius - 1.5, 0, TAU, 64, Color(0.9, 0.9, 0.9, 0.7), 1.5, true)
            icon_container.draw.connect(icon_callable.bind(icon_container))
            
            if portrait_texture:
                var tex_rect = TextureRect.new()
                tex_rect.texture = portrait_texture
                tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
                tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
                tex_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
                mask.add_child(tex_rect)
            else:
                var bg = ColorRect.new()
                bg.color = Color(0.6, 0.6, 0.6)
                if npc_type == "resident": bg.color = Color(0.4, 0.8, 0.4)
                if npc_id == "luna": bg.color = Color(0.8, 0.4, 0.4)
                if npc_id == "ya": bg.color = Color(0.4, 0.4, 0.8)
                bg.set_anchors_preset(Control.PRESET_FULL_RECT)
                mask.add_child(bg)
                
                var name_lbl = Label.new()
                name_lbl.text = npc_name.substr(0, 1).to_upper()
                name_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
                name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
                name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
                name_lbl.add_theme_color_override("font_color", Color.WHITE)
                name_lbl.add_theme_font_size_override("font_size", 18)
                mask.add_child(name_lbl)
            
            npc_hbox.add_child(icon_container)

func _on_mouse_entered():
    if custom_tooltip != null:
        custom_tooltip.queue_free()
    
    custom_tooltip = LOCATION_HOVER_TOOLTIP_SCENE.instantiate() as PanelContainer
    if custom_tooltip == null:
        return
    get_tree().root.add_child(custom_tooltip)
    if custom_tooltip.has_method("setup"):
        custom_tooltip.setup(loc_description)

    # Force UI layout update so we can get correct size for positioning
    custom_tooltip.reset_size()
    await get_tree().process_frame
    if custom_tooltip:
        var global_pos = get_global_transform().origin
        custom_tooltip.global_position = global_pos + Vector2(size.x / 2 - custom_tooltip.size.x / 2, -custom_tooltip.size.y - 10)
        
        # Fade in
        custom_tooltip.modulate.a = 0.0
        var tween = create_tween()
        tween.tween_property(custom_tooltip, "modulate:a", 1.0, 0.15)

func _on_mouse_exited():
    if custom_tooltip != null:
        var tween = create_tween()
        tween.tween_property(custom_tooltip, "modulate:a", 0.0, 0.1)
        tween.tween_callback(custom_tooltip.queue_free)
        custom_tooltip = null
