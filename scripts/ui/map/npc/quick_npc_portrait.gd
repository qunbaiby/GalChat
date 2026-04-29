extends VBoxContainer

signal npc_clicked(npc_id: String)

var npc_id: String = ""

@onready var portrait_bg: ColorRect = $Portrait/PlaceholderBG
@onready var name_label: Label = $NameLabel
@onready var interact_button: Button = $Portrait/InteractButton

func setup(id: String) -> void:
    npc_id = id
    
    var npc_data = MapDataManager.get_npc_data(npc_id)
    var npc_name = npc_data.get("name", npc_id)
    
    var char_file_path = "res://assets/data/characters/npc/" + npc_id + ".json"
    if npc_id == "luna":
        char_file_path = "res://assets/data/characters/luna.json"
        
    var portrait_texture = null
    var file = FileAccess.open(char_file_path, FileAccess.READ)
    if file:
        var json = JSON.new()
        if json.parse(file.get_as_text()) == OK:
            var data = json.get_data()
            if data is Dictionary:
                npc_name = data.get("char_name", npc_name)
                var tex_path = data.get("static_portrait", data.get("avatar", ""))
                if not tex_path.is_empty() and ResourceLoader.exists(tex_path):
                    portrait_texture = load(tex_path)
    
    name_label.text = npc_name
    
    if portrait_texture:
        $Portrait.texture = portrait_texture
        portrait_bg.hide()
    else:
        var npc_type = npc_data.get("type", "random")
        # Placeholder logic for portrait background colors
        if npc_type == "resident":
            portrait_bg.color = Color(0.4, 0.8, 0.4)
        elif npc_id == "luna":
            portrait_bg.color = Color(0.8, 0.4, 0.4)
        elif npc_id == "ya":
            portrait_bg.color = Color(0.4, 0.4, 0.8)
        else:
            portrait_bg.color = Color(0.6, 0.6, 0.6)

func _on_interact_button_pressed():
    npc_clicked.emit(npc_id)
