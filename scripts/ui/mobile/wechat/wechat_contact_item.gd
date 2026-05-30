extends Button

signal selected(char_id: String)

var char_id: String = ""
var _pending_info: Dictionary = {}

@onready var avatar_rect: TextureRect = $Margin/HBox/AvatarMask/AvatarRect
@onready var name_label: Label = $Margin/HBox/NameLabel

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

    var avatar_path := str(info.get("avatar", ""))
    if avatar_path != "" and ResourceLoader.exists(avatar_path):
        avatar_rect.texture = load(avatar_path)
    else:
        avatar_rect.texture = preload("res://icon.svg")

func _on_pressed() -> void:
    selected.emit(char_id)
