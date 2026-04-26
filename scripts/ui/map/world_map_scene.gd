extends Control

@onready var back_button: Button = $TopBar/BackButton
@onready var area_detail_panel: Panel = $AreaDetailPanel
@onready var location_list: VBoxContainer = $AreaDetailPanel/VBoxContainer/ScrollContainer/LocationList
@onready var detail_title: Label = $AreaDetailPanel/VBoxContainer/Header/TitleLabel
@onready var close_detail_button: Button = $AreaDetailPanel/VBoxContainer/Header/CloseButton

# Area buttons
@onready var binhe_south_btn: Button = $MapContainer/BinheSouthButton
@onready var jia_nan_btn: Button = $MapContainer/JiaNanButton
@onready var north_btn: Button = $MapContainer/NorthButton
@onready var wen_hua_btn: Button = $MapContainer/WenHuaButton

signal location_selected(location_id: String)

func _ready():
    back_button.pressed.connect(_on_back_pressed)
    close_detail_button.pressed.connect(_on_close_detail_pressed)
    
    binhe_south_btn.pressed.connect(_on_area_pressed.bind("binhe_south"))
    jia_nan_btn.pressed.connect(_on_area_pressed.bind("jia_nan"))
    north_btn.pressed.connect(_on_area_pressed.bind("north"))
    wen_hua_btn.pressed.connect(_on_area_pressed.bind("wen_hua"))
    
    area_detail_panel.hide()

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
    hide_map()

func _on_area_pressed(area_id: String):
    var area_data = MapDataManager.get_area(area_id)
    if area_data.is_empty():
        return
        
    detail_title.text = area_data.get("name", "未知区域")
    
    # Clear previous locations
    for child in location_list.get_children():
        child.queue_free()
        
    var locs = MapDataManager.get_area_locations(area_id)
    if locs.size() == 0:
        var empty_label = Label.new()
        empty_label.text = "暂无可探索地点"
        empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        empty_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
        location_list.add_child(empty_label)
    else:
        for loc in locs:
            var btn = Button.new()
            btn.text = loc.get("name", "未知地点")
            btn.custom_minimum_size = Vector2(0, 60)
            btn.pressed.connect(_on_location_pressed.bind(loc.get("id", "")))
            
            # Optionally add a subtitle/description
            var desc = loc.get("description", "")
            if desc != "":
                var desc_label = Label.new()
                desc_label.text = desc
                desc_label.add_theme_font_size_override("font_size", 12)
                desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
                desc_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
                desc_label.position.y = 40
                desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
                btn.add_child(desc_label)
                
            location_list.add_child(btn)
            
    # Show detail panel with animation
    area_detail_panel.show()
    area_detail_panel.scale = Vector2(0.9, 0.9)
    area_detail_panel.modulate.a = 0.0
    var tween = create_tween().set_parallel(true)
    tween.tween_property(area_detail_panel, "scale", Vector2(1.0, 1.0), 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
    tween.tween_property(area_detail_panel, "modulate:a", 1.0, 0.2)

func _on_close_detail_pressed():
    var tween = create_tween().set_parallel(true)
    tween.tween_property(area_detail_panel, "scale", Vector2(0.9, 0.9), 0.15).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
    tween.tween_property(area_detail_panel, "modulate:a", 0.0, 0.15)
    tween.chain().tween_callback(area_detail_panel.hide)

func _on_location_pressed(location_id: String):
    # Transition to exploration map
    location_selected.emit(location_id)
    
    # Optional: We could transition to a new scene right here.
    var loc_data = MapDataManager.get_location(location_id)
    if loc_data and loc_data.has("scene_path"):
        var path = loc_data["scene_path"]
        if ResourceLoader.exists(path):
            get_tree().change_scene_to_file(path)
        else:
            print("[WorldMap] Scene not found: ", path)
