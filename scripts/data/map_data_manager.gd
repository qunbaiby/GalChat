extends Node

var areas: Dictionary = {}
var locations: Dictionary = {}

func _ready():
    _load_map_data()

func _load_map_data():
    areas = {
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
        "central_street": {
            "id": "central_street",
            "name": "中央商业街",
            "description": "繁华的购物街。",
            "scene_path": "res://scenes/map/locations/central_street.tscn"
        },
        "themis_law_firm": {
            "id": "themis_law_firm",
            "name": "忒弥斯律所",
            "description": "知名的律师事务所。",
            "scene_path": "res://scenes/map/locations/themis_law_firm.tscn"
        },
        "he_yin_hall": {
            "id": "he_yin_hall",
            "name": "和印大厅",
            "description": "和印集团的接待大厅。",
            "scene_path": "res://scenes/map/locations/he_yin_hall.tscn"
        },
        "jia_nan_market": {
            "id": "jia_nan_market",
            "name": "嘉南市场",
            "description": "热闹的市集。",
            "scene_path": "res://scenes/map/locations/jia_nan_market.tscn"
        },
        "university": {
            "id": "university",
            "name": "未名大学",
            "description": "历史悠久的学府。",
            "scene_path": "res://scenes/map/locations/university.tscn"
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
