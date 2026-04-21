extends Control

signal back_requested
signal character_selected(char_id: String)

@onready var back_btn: Button = $Panel/VBox/TopBar/BackBtn
@onready var contact_list: VBoxContainer = $Panel/VBox/ScrollContainer/ContactList

func _ready() -> void:
    back_btn.pressed.connect(_on_back_pressed)
    _load_contacts()

func _load_contacts() -> void:
    # 清空列表
    for child in contact_list.get_children():
        child.queue_free()
        
    var dir = DirAccess.open("res://assets/data/characters")
    if dir:
        dir.list_dir_begin()
        var file_name = dir.get_next()
        while file_name != "":
            if file_name.ends_with(".json") and not file_name.ends_with("_stages.json"):
                var char_id = file_name.replace(".json", "")
                var char_name = _get_char_name(char_id)
                _create_contact_item(char_id, char_name)
            file_name = dir.get_next()

func _get_char_name(char_id: String) -> String:
    var path = "res://assets/data/characters/%s.json" % char_id
    if FileAccess.file_exists(path):
        var file = FileAccess.open(path, FileAccess.READ)
        var content = file.get_as_text()
        var json = JSON.new()
        if json.parse(content) == OK and json.data is Dictionary:
            return json.data.get("char_name", char_id)
    return char_id

func _create_contact_item(char_id: String, char_name: String) -> void:
    var btn = Button.new()
    btn.custom_minimum_size = Vector2(0, 70)
    btn.text = "   " + char_name
    btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
    btn.add_theme_font_size_override("font_size", 18)
    btn.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2))
    
    var style = StyleBoxFlat.new()
    style.bg_color = Color(1, 1, 1, 1)
    style.border_width_bottom = 1
    style.border_color = Color(0.9, 0.9, 0.9)
    btn.add_theme_stylebox_override("normal", style)
    
    var hover_style = style.duplicate()
    hover_style.bg_color = Color(0.95, 0.95, 0.95, 1)
    btn.add_theme_stylebox_override("hover", hover_style)
    btn.add_theme_stylebox_override("pressed", hover_style)
    
    btn.pressed.connect(func(): _on_contact_selected(char_id))
    contact_list.add_child(btn)

func _on_contact_selected(char_id: String) -> void:
    character_selected.emit(char_id)

func _on_back_pressed() -> void:
    back_requested.emit()
    
func show_panel() -> void:
    show()
    # 滑入动画
    position.x = size.x
    modulate.a = 0.0
    var tween = create_tween()
    tween.set_parallel(true)
    tween.tween_property(self, "position:x", 0.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    tween.tween_property(self, "modulate:a", 1.0, 0.2)

func hide_panel() -> void:
    var tween = create_tween()
    tween.set_parallel(true)
    tween.tween_property(self, "position:x", size.x, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
    tween.tween_property(self, "modulate:a", 0.0, 0.2)
    tween.chain().tween_callback(self.hide)
