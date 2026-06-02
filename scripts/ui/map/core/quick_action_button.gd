extends Button

@onready var icon_rect: TextureRect = $HBox/IconMargin/Icon
@onready var label: Label = $HBox/Label

func setup(action_id: String, action_text: String) -> void:
    if not is_inside_tree():
        await ready
        
    label.text = action_text
    
    # 尝试加载对应图标，如果找不到就用默认图标
    var icon_path = "res://assets/images/icons/ui/system/%s.svg" % action_id
    if ResourceLoader.exists(icon_path):
        icon_rect.texture = load(icon_path)
    else:
        # 默认回退到一个聊天的通用图标
        icon_rect.texture = load("res://assets/images/icons/ui/system/chat.svg")