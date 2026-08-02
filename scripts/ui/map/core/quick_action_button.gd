extends Button

@onready var icon_rect: TextureRect = $HBox/IconMargin/Icon
@onready var label: Label = $HBox/Label
@onready var spacer: Control = $HBox/Spacer
@onready var lock_icon: TextureRect = $HBox/LockIcon
@onready var lock_margin: Control = $HBox/LockMargin

func setup(action_id: String, action_text: String, locked: bool = false) -> void:
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
    set_locked(locked)

func set_locked(locked: bool) -> void:
    if not is_inside_tree():
        await ready
    disabled = locked
    lock_icon.visible = locked
    lock_margin.visible = locked
    spacer.visible = not locked
    modulate = Color(0.62, 0.68, 0.68, 0.82) if locked else Color.WHITE