extends Button

signal item_selected(outfit_data: Dictionary)

@onready var icon_rect: TextureRect = $MarginContainer/VBoxContainer/IconRect
@onready var name_label: Label = $MarginContainer/VBoxContainer/NameLabel
@onready var wearing_badge: Label = $WearingBadge

var outfit_data: Dictionary = {}
var is_wearing: bool = false

func _ready() -> void:
    pressed.connect(_on_pressed)

func setup(data: Dictionary, current_outfit_id: String) -> void:
    outfit_data = data
    name_label.text = data.get("name", "未知服装")
    
    var icon_path = data.get("icon", "")
    if icon_path != "" and ResourceLoader.exists(icon_path):
        icon_rect.texture = load(icon_path)
    
    update_wearing_status(current_outfit_id)

func update_wearing_status(current_outfit_id: String) -> void:
    is_wearing = (outfit_data.get("id", "") == current_outfit_id)
    wearing_badge.visible = is_wearing
    
    # 改变边框颜色等（可通过Theme或者直接修改modulate）
    if is_wearing:
        self.modulate = Color(1.0, 0.9, 0.7) # 简单的选中高亮
    else:
        self.modulate = Color(1.0, 1.0, 1.0)

func set_selected(selected: bool) -> void:
    if selected:
        # 可以加个选中的高亮框
        self.self_modulate = Color(0.8, 1.0, 1.0)
    else:
        self.self_modulate = Color(1.0, 1.0, 1.0)

func _on_pressed() -> void:
    item_selected.emit(outfit_data)
