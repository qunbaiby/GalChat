extends Node

var areas: Dictionary = {}
var locations: Dictionary = {}
var npcs_data: Dictionary = {}

var _last_visited_area: String = ""
var is_quick_mode: bool = false

const MAP_DATA_PATH = "res://assets/data/map/core/map_data.json"
const NPC_DATA_PATH = "res://assets/data/map/npc/npc_data.json"

func _ready():
    _load_map_data()
    _load_npcs_data()

func _load_npcs_data():
    if not FileAccess.file_exists(NPC_DATA_PATH):
        push_error("NPC data file not found: " + NPC_DATA_PATH)
        return
        
    var file = FileAccess.open(NPC_DATA_PATH, FileAccess.READ)
    var json_str = file.get_as_text()
    file.close()
    
    var json = JSON.new()
    var error = json.parse(json_str)
    if error == OK:
        npcs_data = json.data
    else:
        push_error("Failed to parse NPC data JSON: " + json.get_error_message())

func _load_map_data():
    if not FileAccess.file_exists(MAP_DATA_PATH):
        push_error("Map data file not found: " + MAP_DATA_PATH)
        return
        
    var file = FileAccess.open(MAP_DATA_PATH, FileAccess.READ)
    var json_str = file.get_as_text()
    file.close()
    
    var json = JSON.new()
    var error = json.parse(json_str)
    if error == OK:
        var data = json.data
        areas = data.get("areas", {})
        
        # Parse locations and convert dictionary map_position back to Vector2
        var raw_locations = data.get("locations", {})
        for loc_id in raw_locations:
            var loc = raw_locations[loc_id]
            if loc.has("map_position"):
                var pos_dict = loc["map_position"]
                loc["map_position"] = Vector2(pos_dict.get("x", 0), pos_dict.get("y", 0))
            locations[loc_id] = loc
    else:
        push_error("Failed to parse Map data JSON: " + json.get_error_message())

func get_area(area_id: String) -> Dictionary:
    return areas.get(area_id, {})

func get_location(location_id: String) -> Dictionary:
    return locations.get(location_id, {})

func get_area_locations(area_id: String) -> Array:
    var area = get_area(area_id)
    var locs = []
    if area.has("locations"):
        for loc_id in area["locations"]:
            var loc = get_location(loc_id)
            if not loc.is_empty():
                locs.append(loc)
    return locs

func get_npc_data(npc_id: String) -> Dictionary:
    return npcs_data.get(npc_id, {})

func generate_location_npcs(location_id: String) -> Array:
    # 模拟生成当前地点的NPC列表(常驻+随机)
    var loc = get_location(location_id)
    var current_npcs = []
    if loc.has("resident_npcs"):
        current_npcs.append_array(loc["resident_npcs"])
    if loc.has("random_npcs"):
        # 简单随机逻辑：每个NPC有50%几率出现
        for npc in loc["random_npcs"]:
            if randf() > 0.5:
                current_npcs.append(npc)
    return current_npcs

func set_last_area(area_id: String) -> void:
    _last_visited_area = area_id

func get_last_area() -> String:
    return _last_visited_area
