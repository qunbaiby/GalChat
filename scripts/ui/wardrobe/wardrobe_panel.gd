extends Control

@onready var items_grid: GridContainer = $Panel/HBoxContainer/LeftPanel/ScrollContainer/ItemsGrid
@onready var char_portrait: AnimatedSprite2D = $Panel/HBoxContainer/CenterPanel/PortraitPivot/CharPortrait
@onready var detail_name: Label = $Panel/HBoxContainer/RightPanel/VBoxContainer/DetailName
@onready var detail_desc: RichTextLabel = $Panel/HBoxContainer/RightPanel/VBoxContainer/DetailDesc
@onready var detail_icon: TextureRect = $Panel/HBoxContainer/RightPanel/VBoxContainer/DetailIcon
@onready var wear_button: Button = $Panel/HBoxContainer/RightPanel/VBoxContainer/WearButton
@onready var close_button: Button = $Panel/CloseButton

const ITEM_SCENE = preload("res://scenes/ui/wardrobe/wardrobe_item.tscn")
const DATA_PATH = "res://assets/data/wardrobe/wardrobe_data.json"

var outfits_data: Array = []
var selected_outfit: Dictionary = {}
var current_outfit_id: String = "default"

signal outfit_changed(new_outfit_id: String)

func _ready() -> void:
    close_button.pressed.connect(_on_close_pressed)
    wear_button.pressed.connect(_on_wear_pressed)
    
    visibility_changed.connect(_on_visibility_changed)
    
    # 刚加载时隐藏，等待主场景调用
    hide()

func _on_visibility_changed() -> void:
    if visible:
        _load_data()
        _refresh_ui()

func _load_data() -> void:
    if FileAccess.file_exists(DATA_PATH):
        var file = FileAccess.open(DATA_PATH, FileAccess.READ)
        var json = JSON.new()
        var err = json.parse(file.get_as_text())
        if err == OK:
            var data = json.get_data()
            if data is Dictionary and data.has("outfits"):
                outfits_data = data["outfits"]
    else:
        printerr("Wardrobe data not found at: ", DATA_PATH)

    if GameDataManager.profile:
        current_outfit_id = GameDataManager.profile.current_outfit

func _refresh_ui() -> void:
    # 清空列表
    for child in items_grid.get_children():
        child.queue_free()
        
    var first_item = null
    
    for outfit in outfits_data:
        var item = ITEM_SCENE.instantiate()
        items_grid.add_child(item)
        item.setup(outfit, current_outfit_id)
        item.item_selected.connect(_on_item_selected.bind(item))
        
        if outfit.get("id") == current_outfit_id:
            first_item = item
            
    # 默认选中当前穿着的或者第一个
    if first_item:
        _on_item_selected(first_item.outfit_data, first_item)
    elif items_grid.get_child_count() > 0:
        var child = items_grid.get_child(0)
        _on_item_selected(child.outfit_data, child)

func _on_item_selected(outfit: Dictionary, item_node: Node) -> void:
    selected_outfit = outfit
    
    # 更新列表选中状态
    for child in items_grid.get_children():
        child.set_selected(child == item_node)
        
    # 更新详情面板
    detail_name.text = outfit.get("name", "未知")
    detail_desc.text = outfit.get("description", "没有描述")
    
    var icon_path = outfit.get("icon", "")
    if icon_path != "" and ResourceLoader.exists(icon_path):
        detail_icon.texture = load(icon_path)
    else:
        detail_icon.texture = null
        
    # 更新中间预览立绘 (支持动态构建 SpriteFrames)
    var sprite_path = outfit.get("sprite", "")
    if sprite_path == "" or not ResourceLoader.exists(sprite_path):
        sprite_path = "res://assets/images/characters/Luna/luna.tres"
        
    if ResourceLoader.exists(sprite_path):
        var res = load(sprite_path)
        if res is SpriteFrames:
            char_portrait.sprite_frames = res
            char_portrait.play("default")
        elif res is Texture2D:
            var frames = SpriteFrames.new()
            frames.add_animation("default")
            frames.add_frame("default", res)
            char_portrait.sprite_frames = frames
            char_portrait.play("default")
    else:
        char_portrait.sprite_frames = null
        
    var outfit_id = outfit.get("id", "default")
    
    # 更新穿上按钮状态
    if outfit_id == current_outfit_id:
        wear_button.text = "已穿着"
        wear_button.disabled = true
    else:
        wear_button.text = "穿上"
        wear_button.disabled = false

func _on_wear_pressed() -> void:
    if selected_outfit.is_empty(): return
    
    var new_id = selected_outfit.get("id", "default")
    current_outfit_id = new_id
    
    # 更新档案
    if GameDataManager.profile:
        GameDataManager.profile.current_outfit = current_outfit_id
        GameDataManager.profile.save_profile()
        if GameDataManager.save_manager:
            GameDataManager.save_manager.auto_save()
            
    # 刷新列表状态
    for child in items_grid.get_children():
        child.update_wearing_status(current_outfit_id)
        
    wear_button.text = "已穿着"
    wear_button.disabled = true
    
    outfit_changed.emit(current_outfit_id)

func _on_close_pressed() -> void:
    hide()
