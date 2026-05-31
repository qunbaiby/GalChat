extends Control

signal character_selected(char_id: String)

const CONTACT_ITEM_SCENE = preload("res://scenes/ui/mobile/wechat/wechat_contact_item.tscn")

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
            info.avatar = json.data.get("avatar", "")
            
    return info

func _create_category(title: String, contacts: Array) -> void:
    if contacts.size() == 0:
        return
        
    var header = Label.new()
    header.text = "  " + title
    header.custom_minimum_size = Vector2(0, 30)
    header.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    header.add_theme_color_override("font_color", Color(0.560784, 0.592157, 0.65098))
    header.add_theme_font_size_override("font_size", 12)
    var style = StyleBoxFlat.new()
    style.bg_color = Color(0.965, 0.972, 0.985)
    header.add_theme_stylebox_override("normal", style)
    
    contact_list.add_child(header)
    
    for c in contacts:
        _create_contact_item(c)

func _create_contact_item(info: Dictionary) -> void:
    var item = CONTACT_ITEM_SCENE.instantiate()
    contact_list.add_child(item)
    item.setup(info)
    item.selected.connect(_on_contact_selected)

func _on_contact_selected(char_id: String) -> void:
    character_selected.emit(char_id)

func show_panel() -> void:
    show()
    _load_contacts()

func hide_panel() -> void:
    hide()
