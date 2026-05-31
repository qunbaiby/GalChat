extends VBoxContainer

signal npc_clicked(npc_id: String)

var npc_id: String = ""

@onready var avatar_mask: Control = $AvatarContainer/AvatarMask
@onready var state_ring: ColorRect = $AvatarContainer/StateRing
@onready var portrait: TextureRect = $AvatarContainer/AvatarMask/Portrait
@onready var portrait_bg: ColorRect = $AvatarContainer/AvatarMask/Portrait/PlaceholderBG
@onready var name_label: Label = $NameLabel
@onready var interact_button: Button = $AvatarContainer/InteractButton

var ring_time: float = 0.0

func _ready() -> void:
    avatar_mask.draw.connect(_on_mask_draw)

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
                var tex_path = data.get("avatar", "")
                if not tex_path.is_empty() and ResourceLoader.exists(tex_path):
                    portrait_texture = load(tex_path)
    
    name_label.text = npc_name
    
    if portrait_texture:
        portrait.texture = portrait_texture
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

func _process(delta: float) -> void:
    ring_time += delta
    if is_instance_valid(state_ring) and state_ring.material is ShaderMaterial:
        var mat = state_ring.material as ShaderMaterial
        var BASE_WIDTH = 0.022
        var BASE_BLUR = 0.015
        
        var breath = (sin(ring_time * 2.5) + 1.0) * 0.5
        var alpha_mod = lerp(0.15, 0.95, breath)
        var current_blur = lerp(BASE_BLUR, BASE_BLUR + 0.012, breath)
        
        mat.set_shader_parameter("color1", Color(0.4, 0.75, 1.0, alpha_mod))
        mat.set_shader_parameter("color2", Color(0.7, 0.95, 1.0, alpha_mod))
        mat.set_shader_parameter("blur", current_blur)

func _on_mask_draw() -> void:
    var center = avatar_mask.size / 2.0
    var radius = (min(avatar_mask.size.x, avatar_mask.size.y) / 2.0) - 3.0
    avatar_mask.draw_circle(center, radius, Color.WHITE)

func _on_interact_button_pressed():
    npc_clicked.emit(npc_id)

func set_selected(is_selected: bool) -> void:
    if state_ring:
        state_ring.visible = is_selected
