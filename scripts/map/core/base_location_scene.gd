extends Control

@export var location_id: String = ""

@onready var bg_texture: TextureRect = $Background
@onready var title_label: Label = $TopBar/Title
@onready var back_btn: Button = $TopBar/BackButton

func _ready():
	back_btn.pressed.connect(_on_back_pressed)
	
	if location_id != "":
		_load_location_data()
	
	# Dispatch event
	if GameDataManager.has_method("dispatch_event"):
		GameDataManager.dispatch_event("location_entered", location_id)
		
	# Broadcast state change to EventManager to check for global events
	var event_manager = get_node_or_null("/root/EventManager")
	if event_manager and event_manager.has_method("broadcast_state_change"):
		event_manager.broadcast_state_change({"location_id": location_id})

func _load_location_data():
	var loc = MapDataManager.get_location(location_id)
	if loc.is_empty():
		return
		
	title_label.text = loc.get("name", "未知地点")
	
	# Load background based on time of day if possible
	var bg_id = loc.get("bg_id", "")
	if bg_id == "":
		bg_id = location_id # fallback
		
	var time_sys = GameDataManager.story_time_manager
	var period = time_sys.current_period if time_sys else "上午"
	
	# Try to find time-specific background
	var time_bg_id = bg_id
	if period == "傍晚":
		time_bg_id = bg_id + "_evening"
	elif period == "夜晚":
		time_bg_id = bg_id + "_night"
	elif period == "下午":
		time_bg_id = bg_id + "_afternoon"
	else:
		time_bg_id = bg_id + "_morning"
		
	var img_path = ImageManager.get_image_path(time_bg_id)
	if img_path == "" or not ResourceLoader.exists(img_path):
		# Fallback to base bg_id
		img_path = ImageManager.get_image_path(bg_id)
		
	if img_path != "" and ResourceLoader.exists(img_path):
		bg_texture.texture = load(img_path)
	else:
		print("[BaseLocation] Missing background for: ", bg_id)

func _on_back_pressed():
	# 返回世界地图
	var map_scene = load("res://scenes/ui/map/core/world_map_scene.tscn")
	if map_scene:
		get_tree().change_scene_to_packed(map_scene)
