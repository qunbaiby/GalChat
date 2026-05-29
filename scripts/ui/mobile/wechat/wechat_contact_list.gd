extends Control

signal character_selected(char_id: String)

@onready var contact_list: VBoxContainer = $Panel/ScrollContainer/ContactList

func _ready() -> void:
    _load_contacts()

func _load_contacts() -> void:
    # 清空列表
    for child in contact_list.get_children():
        child.queue_free()
        
    var special_focus = []
    var my_friends = []
    
    # Load main characters (特别关注)
    var dir = DirAccess.open("res://assets/data/characters")
    if dir:
        dir.list_dir_begin()
        var file_name = dir.get_next()
        while file_name != "":
            if file_name.ends_with(".json") and not file_name.ends_with("_stages.json"):
                var char_id = file_name.replace(".json", "")
                special_focus.append(_get_char_info(char_id, "res://assets/data/characters/" + file_name))
            file_name = dir.get_next()
            
    # Load NPCs (我的好友)
    var npc_dir = DirAccess.open("res://assets/data/characters/npc")
    if npc_dir:
        npc_dir.list_dir_begin()
        var file_name = npc_dir.get_next()
        while file_name != "":
            if file_name.ends_with(".json") and not file_name.ends_with("_stages.json"):
                var char_id = file_name.replace(".json", "")
                my_friends.append(_get_char_info(char_id, "res://assets/data/characters/npc/" + file_name))
            file_name = npc_dir.get_next()
            
    _create_category("★ 特别关注", special_focus)
    _create_category("👥 我的好友", my_friends)

func _get_char_info(char_id: String, file_path: String) -> Dictionary:
    var info = {
        "id": char_id,
        "name": char_id,
        "avatar": ""
    }
    
    if FileAccess.file_exists(file_path):
        var file = FileAccess.open(file_path, FileAccess.READ)
        var json = JSON.new()
        if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
            info.name = json.data.get("char_name", char_id)
            info.avatar = json.data.get("avatar", json.data.get("static_portrait", ""))
            
    return info

func _create_category(title: String, contacts: Array) -> void:
    if contacts.size() == 0:
        return
        
    var header = Label.new()
    header.text = "  " + title
    header.custom_minimum_size = Vector2(0, 30)
    header.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    header.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
    header.add_theme_font_size_override("font_size", 12)
    var style = StyleBoxFlat.new()
    style.bg_color = Color(0.1, 0.1, 0.15)
    header.add_theme_stylebox_override("normal", style)
    
    contact_list.add_child(header)
    
    for c in contacts:
        _create_contact_item(c)

func _create_contact_item(info: Dictionary) -> void:
    var btn = Button.new()
    btn.custom_minimum_size = Vector2(0, 60)
    btn.flat = true
    
    var style = StyleBoxFlat.new()
    style.bg_color = Color(0.12, 0.12, 0.18, 1)
    style.border_width_bottom = 1
    style.border_color = Color(0.2, 0.2, 0.3)
    btn.add_theme_stylebox_override("normal", style)
    
    var hover_style = style.duplicate()
    hover_style.bg_color = Color(0.18, 0.18, 0.25, 1)
    btn.add_theme_stylebox_override("hover", hover_style)
    btn.add_theme_stylebox_override("pressed", hover_style)
    
    btn.pressed.connect(func(): _on_contact_selected(info.id))
    
    var hbox = HBoxContainer.new()
    hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    hbox.add_theme_constant_override("separation", 15)
    
    var margin = MarginContainer.new()
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    margin.add_theme_constant_override("margin_left", 15)
    margin.add_theme_constant_override("margin_right", 15)
    margin.add_theme_constant_override("margin_top", 10)
    margin.add_theme_constant_override("margin_bottom", 10)
    margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
    
    btn.add_child(margin)
    margin.add_child(hbox)
    
    var avatar_rect = TextureRect.new()
    avatar_rect.custom_minimum_size = Vector2(40, 40)
    avatar_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    avatar_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    avatar_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    
    if info.avatar != "" and ResourceLoader.exists(info.avatar):
        avatar_rect.texture = load(info.avatar)
    else:
        avatar_rect.texture = preload("res://icon.svg")
        
    var mask_panel = PanelContainer.new()
    mask_panel.custom_minimum_size = Vector2(40, 40)
    mask_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    mask_panel.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
    var mask_style = StyleBoxFlat.new()
    mask_style.bg_color = Color.WHITE
    mask_style.corner_radius_top_left = 8
    mask_style.corner_radius_top_right = 8
    mask_style.corner_radius_bottom_left = 8
    mask_style.corner_radius_bottom_right = 8
    mask_panel.add_theme_stylebox_override("panel", mask_style)
    mask_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    mask_panel.add_child(avatar_rect)
    
    hbox.add_child(mask_panel)
    
    var name_lbl = Label.new()
    name_lbl.text = info.name
    name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    name_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
    name_lbl.add_theme_font_size_override("font_size", 16)
    hbox.add_child(name_lbl)
    
    contact_list.add_child(btn)

func _on_contact_selected(char_id: String) -> void:
    character_selected.emit(char_id)

func show_panel() -> void:
    show()
    _load_contacts()

func hide_panel() -> void:
    hide()
