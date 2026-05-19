extends Control

@onready var back_button: Button = $TopBar/BackButton
@onready var title_label: Label = $TopBar/Title
@onready var mode_toggle_btn: Button = $TopBar/ModeToggleButton

# Sub areas container
@onready var sub_area_container: Control = $SubAreaContainer

# Area list container
@onready var area_list_container: HBoxContainer = $BottomBar/ScrollContainer/MarginContainer/AreaList

var area_item_scene = preload("res://scenes/ui/map/core/area_item.tscn")
var location_button_scene = preload("res://scenes/ui/map/core/location_button.tscn")

signal location_selected(location_id: String)

var _bg_tween: Tween

func _ready():
    # Load default world map background
    var world_map_bg = ImageManager.get_image_path("world_map_bg")
    if world_map_bg != "" and ResourceLoader.exists(world_map_bg):
        $Background.texture = load(world_map_bg)
        
    back_button.pressed.connect(_on_back_pressed)
    mode_toggle_btn.pressed.connect(_on_mode_toggle_pressed)
    
    # 进入世界地图时，默认模式改为快捷地图
    MapDataManager.is_quick_mode = true
    _update_mode_button_text()
    
    # Clear any previous children (in case of re-initialization)
    for child in area_list_container.get_children():
        child.queue_free()
        
    # Dynamically load area buttons
    var default_area_id = ""
    for area_id in MapDataManager.areas:
        if default_area_id == "":
            default_area_id = area_id
        var area_data = MapDataManager.areas[area_id]
        var item = area_item_scene.instantiate()
        area_list_container.add_child(item)
        item.setup(area_id, area_data)
        item.pressed.connect(_on_area_pressed)
    
    # Select default area
    if not MapDataManager.has_method("get_last_area") or MapDataManager.get_last_area() == "":
        _on_area_pressed("qingyu_street")
    else:
        var last = MapDataManager.get_last_area()
        if last == "studio":
            last = "qingyu_street"
        # Verify last area still exists, else use fallback
        if MapDataManager.areas.has(last):
            _on_area_pressed(last)
        else:
            if MapDataManager.areas.has("qingyu_street"):
                _on_area_pressed("qingyu_street")
            elif default_area_id != "":
                _on_area_pressed(default_area_id)

func _update_mode_button_text():
    if MapDataManager.is_quick_mode:
        mode_toggle_btn.text = "当前: 快捷模式"
    else:
        mode_toggle_btn.text = "当前: 场景模式"

func _on_mode_toggle_pressed():
    MapDataManager.is_quick_mode = !MapDataManager.is_quick_mode
    _update_mode_button_text()

func show_map():
    show()
    modulate.a = 0.0
    var tween = create_tween()
    tween.tween_property(self, "modulate:a", 1.0, 0.3)

func hide_map():
    var tween = create_tween()
    tween.tween_property(self, "modulate:a", 0.0, 0.3)
    tween.chain().tween_callback(hide)

func _on_back_pressed():
    # Transition back to main scene
    var main_scene = load("res://scenes/ui/main/main_scene.tscn")
    if main_scene:
        get_tree().change_scene_to_packed(main_scene)
    else:
        hide_map()

func _on_area_pressed(area_id: String):
    var area_data = MapDataManager.get_area(area_id)
    if area_data.is_empty():
        return
        
    # Save last area to MapDataManager so we can restore it when returning
    if MapDataManager.has_method("set_last_area"):
        MapDataManager.set_last_area(area_id)
        
    title_label.text = area_data.get("name", "未知区域")
    
    # Clear previous sub areas immediately so they don't linger during pan
    for child in sub_area_container.get_children():
        child.queue_free()
        
    # --- 计算背景图的镜头移动效果 ---
    var bg = $Background
    # 计算背景图比屏幕多出来的部分（即可移动的最大范围）
    var max_x = max(0, bg.size.x - size.x)
    var max_y = max(0, bg.size.y - size.y)
    
    # 利用 area_id 的哈希值生成伪随机的固定目标坐标，保证每次点同一个区域镜头位置都一样
    var hash_val = abs(area_id.hash())
    var target_x = - (hash_val % int(max_x + 1)) if max_x > 0 else 0
    var target_y = - ((hash_val / 100) % int(max_y + 1)) if max_y > 0 else 0
    var target_pos = Vector2(target_x, target_y)
    
    if _bg_tween and _bg_tween.is_valid():
        _bg_tween.kill()
        
    _bg_tween = create_tween()
    _bg_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
    # 镜头移动时长 0.5 秒
    _bg_tween.tween_property(bg, "position", target_pos, 0.5)
    
    # 等待镜头就位后，再显示区域内的具体地点按钮
    _bg_tween.tween_callback(self._show_locations_for_area.bind(area_id))

func _show_locations_for_area(area_id: String):
    var locs = MapDataManager.get_area_locations(area_id)
    if locs.size() == 0:
        var empty_label = Label.new()
        empty_label.text = "该区域暂无可探索地点"
        empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        empty_label.set_anchors_preset(Control.PRESET_FULL_RECT)
        empty_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
        sub_area_container.add_child(empty_label)
    else:
        var btn_size = Vector2(160, 200) # Button size
        
        # Define some fallback positions in case data doesn't have it
        var fallback_positions = [
            Vector2(150, 30),
            Vector2(450, 120),
            Vector2(700, 40),
            Vector2(950, 130),
            Vector2(1050, 50)
        ]
        
        for i in range(locs.size()):
            var loc = locs[i]
            var btn = location_button_scene.instantiate()
            
            if btn.has_method("setup"):
                btn.setup(loc)
            else:
                btn.text = loc.get("name", "未知地点")
            
            btn.pressed.connect(_on_location_pressed.bind(loc.get("id", "")))
            
            # Use position from data, or fallback if not set
            var target_pos = loc.get("map_position", Vector2.ZERO)
            if target_pos == Vector2.ZERO:
                target_pos = fallback_positions[i % fallback_positions.size()]
            
            # 限定按钮坐标范围，确保它完全在 SubAreaContainer 内部，不会被 TopBar 或 BottomBar 遮挡
            var max_x = max(0, sub_area_container.size.x - btn_size.x)
            var max_y = max(0, sub_area_container.size.y - btn_size.y)
            target_pos.x = clamp(target_pos.x, 0, max_x)
            target_pos.y = clamp(target_pos.y, 0, max_y)
            
            btn.position = target_pos
            
            # Add to container
            sub_area_container.add_child(btn)
            
            # Add animation
            btn.scale = Vector2.ZERO
            btn.pivot_offset = btn_size / 2
            var tween = create_tween()
            tween.tween_property(btn, "scale", Vector2.ONE, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK).set_delay(i * 0.1)

func _on_location_pressed(location_id: String):
    # Transition to exploration map
    location_selected.emit(location_id)
    
    if MapDataManager.is_quick_mode:
        var quick_scene = load("res://scenes/ui/map/core/quick_location_scene.tscn")
        if quick_scene:
            var instance = quick_scene.instantiate()
            instance.location_id = location_id
            get_tree().root.add_child(instance)
            get_tree().current_scene = instance
            self.queue_free()
    else:
        var loc_data = MapDataManager.get_location(location_id)
        if loc_data and loc_data.has("scene_path"):
            var path = loc_data["scene_path"]
            if ResourceLoader.exists(path):
                get_tree().change_scene_to_file(path)
            else:
                print("[WorldMap] Scene not found: ", path)
