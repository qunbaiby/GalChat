extends Node2D

@onready var ui_layer: CanvasLayer = $UILayer
@onready var back_button: Button = $UILayer/BackButton
@onready var title_label: Label = $UILayer/TitleLabel

@export var location_id: String = ""

func _ready():
    back_button.pressed.connect(_on_back_pressed)
    
    var loc_data = MapDataManager.get_location(location_id)
    if not loc_data.is_empty():
        title_label.text = loc_data.get("name", "未知地点")

func _on_back_pressed():
    # Load back the world map scene directly
    var world_map_scene = load("res://scenes/ui/map/core/world_map_scene.tscn")
    get_tree().change_scene_to_packed(world_map_scene)
