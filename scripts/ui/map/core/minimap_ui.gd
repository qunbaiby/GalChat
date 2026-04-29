extends CanvasLayer

@export var map_size: Vector2 = Vector2(1280, 720)
@export var player_path: NodePath

@onready var small_map_btn: Button = $SmallMapContainer/SmallMapButton
@onready var small_player_marker: ColorRect = $SmallMapContainer/SmallMapButton/Mask/PlayerMarker

@onready var expanded_map_panel: Control = $ExpandedMapPanel
@onready var expanded_grid: ColorRect = $ExpandedMapPanel/GridBg
@onready var expanded_player_marker: ColorRect = $ExpandedMapPanel/GridBg/PlayerMarker
@onready var location_label: Label = $ExpandedMapPanel/LocationLabel
@onready var close_btn: Button = $ExpandedMapPanel/CloseButton

var player_node: Node2D

func _ready() -> void:
    if not player_path.is_empty():
        player_node = get_node_or_null(player_path)
        
    small_map_btn.pressed.connect(_on_small_map_pressed)
    close_btn.pressed.connect(_on_close_expanded_pressed)
    
    expanded_map_panel.hide()

func _process(_delta: float) -> void:
    if not player_node:
        return
        
    var player_pos = player_node.global_position
    
    # Calculate relative position (0.0 to 1.0)
    var rel_x = clamp(player_pos.x / map_size.x, 0.0, 1.0)
    var rel_y = clamp(player_pos.y / map_size.y, 0.0, 1.0)
    
    # Update small map marker
    var small_rect = small_map_btn.size
    small_player_marker.position = Vector2(rel_x * small_rect.x, rel_y * small_rect.y) - small_player_marker.size / 2.0
    
    # Update expanded map marker
    if expanded_map_panel.visible:
        var expanded_rect = expanded_grid.size
        expanded_player_marker.position = Vector2(rel_x * expanded_rect.x, rel_y * expanded_rect.y) - expanded_player_marker.size / 2.0

func _on_small_map_pressed() -> void:
    expanded_map_panel.show()
    expanded_map_panel.modulate.a = 0.0
    
    # Pop animation
    var tween = create_tween()
    tween.tween_property(expanded_map_panel, "modulate:a", 1.0, 0.2)
    
    # Populate location name from parent scene
    if get_parent() and get_parent().get("location_id"):
        var loc_id = get_parent().location_id
        var loc_data = MapDataManager.get_location(loc_id)
        location_label.text = "📍 " + loc_data.get("name", "未知地点")

func _on_close_expanded_pressed() -> void:
    var tween = create_tween()
    tween.tween_property(expanded_map_panel, "modulate:a", 0.0, 0.2)
    tween.chain().tween_callback(expanded_map_panel.hide)
