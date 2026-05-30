extends Button

signal selected(char_id: String)

var char_id: String = ""
var _pending_info: Dictionary = {}

@onready var avatar_rect: TextureRect = $Margin/HBox/AvatarMask/AvatarRect
@onready var name_label: Label = $Margin/HBox/TextVBox/TopHBox/NameLabel
@onready var time_label: Label = $Margin/HBox/TextVBox/TopHBox/TimeLabel
@onready var unread_badge: Label = $Margin/HBox/TextVBox/TopHBox/UnreadBadge
@onready var msg_label: Label = $Margin/HBox/TextVBox/MsgLabel

func _ready() -> void:
    pressed.connect(_on_pressed)
    if not _pending_info.is_empty():
        _apply_info(_pending_info)

func setup(info: Dictionary) -> void:
    _pending_info = info.duplicate()
    if is_node_ready():
        _apply_info(_pending_info)

func _apply_info(info: Dictionary) -> void:
    char_id = str(info.get("id", ""))
    name_label.text = str(info.get("name", ""))
    time_label.text = str(info.get("last_time", ""))
    msg_label.text = str(info.get("last_msg", "暂无消息"))

    var unread_count := int(info.get("unread_count", 0))
    unread_badge.visible = unread_count > 0
    if unread_count > 0:
        unread_badge.text = str(min(unread_count, 99))
        msg_label.add_theme_color_override("font_color", Color(0.203922, 0.219608, 0.25098))
    else:
        msg_label.add_theme_color_override("font_color", Color(0.560784, 0.592157, 0.65098))

    var avatar_path := str(info.get("avatar", ""))
    if avatar_path != "" and ResourceLoader.exists(avatar_path):
        avatar_rect.texture = load(avatar_path)
    else:
        avatar_rect.texture = preload("res://icon.svg")

func _on_pressed() -> void:
    selected.emit(char_id)
