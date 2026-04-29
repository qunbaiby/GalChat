extends CharacterBody2D

@export var npc_id: String = ""

@onready var name_label = $NameLabel
@onready var interact_prompt = $InteractPrompt
@onready var placeholder = $Placeholder

var is_player_near: bool = false

func _ready():
    _setup_npc()

func _setup_npc():
    if npc_id == "":
        return
        
    var npc_data = MapDataManager.get_npc_data(npc_id)
    name_label.text = npc_data.get("name", npc_id)
    
    var npc_type = npc_data.get("type", "random")
    if npc_type == "resident":
        placeholder.color = Color(0.4, 0.8, 0.4)
    elif npc_id == "luna":
        placeholder.color = Color(1.0, 0.5, 0.5)
    elif npc_id == "ya":
        placeholder.color = Color(0.5, 0.5, 1.0)
    else:
        placeholder.color = Color(0.8, 0.8, 0.8)

func _unhandled_input(event):
    if is_player_near:
        if event.is_action_pressed("ui_accept") or (event is InputEventKey and event.keycode == KEY_F and event.pressed and not event.echo):
            _interact()
            get_viewport().set_input_as_handled()

func _interact():
    var menu_scene = load("res://scenes/ui/map/npc/npc_interaction_menu.tscn")
    if menu_scene:
        var menu = menu_scene.instantiate()
        menu.setup(npc_id)
        # Add to the root since current_scene might be null during transitions
        get_tree().root.add_child(menu)

func _on_interact_area_body_entered(body):
    if body.name == "PlayerCharacter" or body.has_method("move"): # Check if it's the player
        is_player_near = true
        interact_prompt.visible = true

func _on_interact_area_body_exited(body):
    if body.name == "PlayerCharacter" or body.has_method("move"):
        is_player_near = false
        interact_prompt.visible = false
