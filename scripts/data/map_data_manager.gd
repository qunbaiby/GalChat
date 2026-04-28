extends Node

var areas: Dictionary = {}
var locations: Dictionary = {}

var _last_visited_area: String = ""

func _ready():
    _load_map_data()

func _load_map_data():
    areas = {
        "studio": {
            "id": "studio",
            "name": "工作室",
            "description": "你的专属工作与生活空间。",
            "locations": ["studio_living_room", "studio_bedroom", "studio_kitchen"]
        },
        "binhe_south": {
            "id": "binhe_south",
            "name": "滨河南区",
            "description": "繁华的商业区与行政中心。",
            "locations": ["central_street", "themis_law_firm", "he_yin_hall"]
        },
        "jia_nan": {
            "id": "jia_nan",
            "name": "嘉南区",
            "description": "生活气息浓厚的老城区。",
            "locations": ["jia_nan_market"]
        },
        "north": {
            "id": "north",
            "name": "北区",
            "description": "安静的住宅区。",
            "locations": []
        },
        "wen_hua": {
            "id": "wen_hua",
            "name": "文华区",
            "description": "学府林立的文化中心。",
            "locations": ["university"]
        }
    }
    
    locations = {
        "studio_living_room": {
            "id": "studio_living_room",
            "name": "工作室大厅",
            "description": "接见委托人的地方。",
            "map_position": Vector2(500, 200)
        },
        "studio_bedroom": {
            "id": "studio_bedroom",
            "name": "卧室",
            "description": "温馨的休息空间。",
            "map_position": Vector2(150, 150)
        },
        "studio_kitchen": {
            "id": "studio_kitchen",
            "name": "厨房",
            "description": "制作美食的区域。",
            "map_position": Vector2(850, 100)
        },
        "university": {
            "id": "university",
            "name": "默名大学",
            "description": "历史悠久的学府。",
            "scene_path": "res://scenes/map/locations/university.tscn",
            "map_position": Vector2(150, 100)
        },
        "central_street": {
            "id": "central_street",
            "name": "中央大街",
            "description": "繁华的商业中心。",
            "map_position": Vector2(250, 150)
        },
        "themis_law_firm": {
            "id": "themis_law_firm",
            "name": "忒弥斯律所",
            "description": "顶级律师事务所。",
            "map_position": Vector2(600, 80)
        },
        "he_yin_hall": {
            "id": "he_yin_hall",
            "name": "和音堂",
            "description": "著名的音乐厅。",
            "map_position": Vector2(850, 250)
        },
        "jia_nan_market": {
            "id": "jia_nan_market",
            "name": "嘉南市场",
            "description": "充满烟火气的老集市。",
            "map_position": Vector2(400, 200)
        }
    }

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

func set_last_area(area_id: String) -> void:
    _last_visited_area = area_id

func get_last_area() -> String:
    return _last_visited_area
