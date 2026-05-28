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
var _current_area_id: String = ""
var _debug_label: Label

func _ready():
    # --- 调试工具：实时显示鼠标相对 SubAreaContainer 的坐标 ---
    _debug_label = Label.new()
    _debug_label.add_theme_font_size_override("font_size", 20)
    _debug_label.add_theme_color_override("font_color", Color(1, 1, 0, 1)) # 黄色
    _debug_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
    _debug_label.add_theme_constant_override("outline_size", 4)
    _debug_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _debug_label.z_index = 4096
    add_child(_debug_label)
    # --------------------------------------------------------
    
    # Load default world map background
    var world_map_bg = ImageManager.get_image_path("bg_world_map")
    if world_map_bg != "" and ResourceLoader.exists(world_map_bg):
        $Background.texture = load(world_map_bg)
        
    back_button.pressed.connect(_on_back_pressed)
    mode_toggle_btn.pressed.connect(_on_mode_toggle_pressed)
    
    # 进入世界地图时，默认模式改为快捷地图
    MapDataManager.is_quick_mode = true
    _update_mode_button_text()
    
    _apply_time_filter()
    
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
        _on_area_pressed("qingyu_street", true)
    else:
        var last = MapDataManager.get_last_area()
        if last == "studio":
            last = "qingyu_street"
        # Verify last area still exists, else use fallback
        if MapDataManager.areas.has(last):
            _on_area_pressed(last, true)
        else:
            if MapDataManager.areas.has("qingyu_street"):
                _on_area_pressed("qingyu_street", true)
            elif default_area_id != "":
                _on_area_pressed(default_area_id, true)

func _apply_time_filter():
    var time_sys = GameDataManager.story_time_manager
    if not time_sys: return
    
    var period = time_sys.current_period
    var bg = $Background
    
    # 设置不同时间段的环境光颜色
    var target_color = Color.WHITE
    if period == "上午" or period == "下午":
        target_color = Color(1.0, 1.0, 1.0)
    elif period == "傍晚":
        target_color = Color(1.0, 0.8, 0.7) # 偏橘红
    elif period == "夜晚":
        target_color = Color(0.6, 0.6, 0.9) # 偏暗蓝
        
    var tween = create_tween()
    tween.tween_property(bg, "modulate", target_color, 1.0)

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
    SceneTransitionManager.transition_to_scene("res://scenes/ui/main/main_scene.tscn")

func _on_area_pressed(area_id: String, force: bool = false):
    if not force and _current_area_id == area_id:
        return
        
    _current_area_id = area_id
    
    # Update selected effect for all buttons
    for child in area_list_container.get_children():
        if child.has_method("set_selected"):
            child.set_selected(child.area_id == area_id)

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
    
    var target_x = 0.0
    var target_y = 0.0
    
    # 优先读取 JSON 中配置的 camera_offset 比例，让每个区域分散在不同角落
    if area_data.has("camera_offset"):
        var offset = area_data["camera_offset"]
        # Godot JSON 解析后，如果是个对象它通常是个 Dictionary，但如果之前被其他代码强转了，它可能是个 Vector2
        if typeof(offset) == TYPE_DICTIONARY:
            target_x = - (max_x * offset.get("x", 0.0))
            target_y = - (max_y * offset.get("y", 0.0))
        elif typeof(offset) == TYPE_VECTOR2:
            target_x = - (max_x * offset.x)
            target_y = - (max_y * offset.y)
    else:
        # 如果 JSON 没配，给个默认的中心位置
        target_x = - (max_x * 0.5)
        target_y = - (max_y * 0.5)
        
    var target_pos = Vector2(target_x, target_y)
    
    if _bg_tween and _bg_tween.is_valid():
        _bg_tween.kill()
        
    # 设置背景居中缩放
    bg.pivot_offset = bg.size / 2.0
    
    # 第一步：缩小（拉远），如果 force 则不需要动画
    if force:
        bg.scale = Vector2(1.0, 1.0)
        bg.position = target_pos
        self._show_locations_for_area(area_id)
    else:
        _bg_tween = create_tween()
        # 缩小 (拉远) 0~0.45s，幅度变大到 0.9
        _bg_tween.tween_property(bg, "scale", Vector2(0.9, 0.9), 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
        
        # 平移 0~0.9s，时间加长让其更平滑
        _bg_tween.parallel().tween_property(bg, "position", target_pos, 0.9).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
        
        # 放大 (拉近) 0.45~0.9s
        _bg_tween.parallel().tween_property(bg, "scale", Vector2(1.0, 1.0), 0.45).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD).set_delay(0.45)
        
        # 等待镜头就位后，再显示区域内的具体地点按钮
        _bg_tween.chain().tween_callback(self._show_locations_for_area.bind(area_id))

func _show_locations_for_area(area_id: String):
    var locs = MapDataManager.get_area_locations(area_id)
    if typeof(locs) == TYPE_ARRAY:
        locs = locs.duplicate()
    
    # Handle limited_locations, show them even if locked, but mark them
    var area = MapDataManager.get_area(area_id)
    if area.has("limited_locations"):
        for loc_id in area["limited_locations"]:
            var loc = MapDataManager.get_location(loc_id)
            if not loc.is_empty():
                var found = false
                for l in locs:
                    if typeof(l) == TYPE_DICTIONARY and l.get("id", "") == loc_id:
                        found = true
                        break
                if not found:
                    locs.append(loc)

    # Filter out invisible locations
    var visible_locs = []
    for loc in locs:
        if MapDataManager.is_location_visible(loc.get("id", "")):
            visible_locs.append(loc)
    locs = visible_locs

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
            
            # 必须先将节点添加到场景树，触发 _ready() 后，内部的 @onready 变量才会被正确赋值
            sub_area_container.add_child(btn)
            
            if btn.has_method("setup"):
                btn.setup(loc)
            else:
                btn.text = loc.get("name", "未知地点")
            
            btn.pressed.connect(_on_location_pressed.bind(loc.get("id", "")))
            
            # 从 JSON 配置中读取 map_position
            var target_pos = Vector2.ZERO
            if loc.has("map_position"):
                var pos_data = loc["map_position"]
                if typeof(pos_data) == TYPE_DICTIONARY:
                    target_pos = Vector2(pos_data.get("x", 0), pos_data.get("y", 0))
                elif typeof(pos_data) == TYPE_VECTOR2:
                    target_pos = pos_data
            
            # 如果 JSON 中没有配置坐标，或者配了 0，给个后备排列坐标防止重叠
            if target_pos == Vector2.ZERO:
                target_pos = fallback_positions[i % fallback_positions.size()]
            
            # 取消坐标越界限制，允许玩家在 JSON 中自由配置任意坐标
            # (注意：超出 SubAreaContainer 的部分可能会被 TopBar/BottomBar 遮挡或跑到屏幕外)
            # var max_x = max(0, sub_area_container.size.x - btn_size.x)
            # var max_y = max(0, sub_area_container.size.y - btn_size.y)
            # if target_pos.x > max_x or target_pos.y > max_y:
            #      print("[WorldMap] 警告：地点 ", loc.get("id"), " 配置的坐标 (", target_pos.x, ", ", target_pos.y, ") 超出了安全显示区域！已被强制限制为边界值。最大允许范围：(0~", max_x, ", 0~", max_y, ")")
            # target_pos.x = clamp(target_pos.x, 0, max_x)
            # target_pos.y = clamp(target_pos.y, 0, max_y)
            
            btn.position = target_pos
            
            # Add animation
            btn.scale = Vector2.ZERO
            btn.pivot_offset = btn_size / 2
            var tween = create_tween()
            tween.tween_property(btn, "scale", Vector2.ONE, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK).set_delay(i * 0.1)

func _on_location_pressed(location_id: String):
    # 检查是否解锁
    var is_unlocked = MapDataManager.is_location_unlocked(location_id)
    if not is_unlocked:
        var reason = MapDataManager.get_location_lock_reason(location_id)
        if reason == "":
            reason = "暂未解锁"
        ToastManager.show_system_toast(reason, Color.RED)
        return
        
    # 移动消耗时间 (15分钟)
    if GameDataManager.story_time_manager:
        GameDataManager.story_time_manager.tick_minutes(15)

    if MapDataManager.has_method("set_last_location"):
        MapDataManager.set_last_location(location_id)
        
    # Transition to exploration map
    location_selected.emit(location_id)
    
    if MapDataManager.is_quick_mode:
        var quick_scene = load("res://scenes/ui/map/core/quick_location_scene.tscn")
        if quick_scene:
            var instance = quick_scene.instantiate()
            instance.location_id = location_id
            SceneTransitionManager.transition_to_scene_instance(instance)
    else:
        var loc_data = MapDataManager.get_location(location_id)
        if loc_data and loc_data.has("scene_path"):
            var path = loc_data["scene_path"]
            if ResourceLoader.exists(path):
                # 如果是通用的 base_location_scene，手动实例化并传递 location_id
                if path.ends_with("base_location_scene.tscn"):
                    var scene = load(path)
                    var instance = scene.instantiate()
                    instance.location_id = location_id
                    SceneTransitionManager.transition_to_scene_instance(instance)
                else:
                    SceneTransitionManager.transition_to_scene(path)
            else:
                print("[WorldMap] Scene not found: ", path)

func _process(delta: float) -> void:
    if is_instance_valid(_debug_label) and is_instance_valid(sub_area_container):
        var local_pos = sub_area_container.get_local_mouse_position()
        _debug_label.text = "坐标: (%.0f, %.0f)" % [local_pos.x, local_pos.y]
        _debug_label.global_position = get_global_mouse_position() + Vector2(20, 20)
