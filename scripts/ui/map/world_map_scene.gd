extends Control

@onready var back_button: Button = $TopBar/BackButton
@onready var title_label: Label = $TopBar/Title

# Sub areas container
@onready var sub_area_container: Control = $SubAreaContainer

# Area buttons
@onready var binhe_south_btn: Button = $BottomBar/ScrollContainer/AreaList/BinheSouthButton
@onready var jia_nan_btn: Button = $BottomBar/ScrollContainer/AreaList/JiaNanButton
@onready var north_btn: Button = $BottomBar/ScrollContainer/AreaList/NorthButton
@onready var wen_hua_btn: Button = $BottomBar/ScrollContainer/AreaList/WenHuaButton
@onready var studio_btn: Button = $BottomBar/ScrollContainer/AreaList/StudioButton

var location_button_scene = preload("res://scenes/ui/map/location_button.tscn")

signal location_selected(location_id: String)

func _ready():
	back_button.pressed.connect(_on_back_pressed)
	
	binhe_south_btn.pressed.connect(_on_area_pressed.bind("binhe_south"))
	jia_nan_btn.pressed.connect(_on_area_pressed.bind("jia_nan"))
	north_btn.pressed.connect(_on_area_pressed.bind("north"))
	wen_hua_btn.pressed.connect(_on_area_pressed.bind("wen_hua"))
	studio_btn.pressed.connect(_on_area_pressed.bind("studio"))
	
	# Select studio area by default if not coming from a sub-location
	if not MapDataManager.has_method("get_last_area") or MapDataManager.get_last_area() == "":
		_on_area_pressed("studio")
	else:
		_on_area_pressed(MapDataManager.get_last_area())

func show_map():
	show()
	modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.3)

func hide_map():
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.chain().tween_callback(hide)

func _on_back_pressed():
	# Transition back to main scene
	var main_scene = load("res://scenes/ui/main/main_scene.tscn")
	if main_scene:
		get_tree().change_scene_to_packed(main_scene)
	else:
		hide_map()

func _on_area_pressed(area_id: String):
	var area_data = MapDataManager.get_area(area_id)
	if area_data.is_empty():
		return
		
	# Save last area to MapDataManager so we can restore it when returning
	if MapDataManager.has_method("set_last_area"):
		MapDataManager.set_last_area(area_id)
		
	title_label.text = area_data.get("name", "未知区域")
	
	# Clear previous sub areas
	for child in sub_area_container.get_children():
		child.queue_free()
		
	var locs = MapDataManager.get_area_locations(area_id)
	if locs.size() == 0:
		var empty_label = Label.new()
		empty_label.text = "该区域暂无可探索地点"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		empty_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		sub_area_container.add_child(empty_label)
	else:
		var btn_size = Vector2(160, 200) # Button size
		
		# Define some fallback positions in case data doesn't have it
		var fallback_positions = [
			Vector2(150, 100),
			Vector2(500, 250),
			Vector2(850, 80),
			Vector2(1000, 280),
			Vector2(350, 300)
		]
		
		for i in range(locs.size()):
			var loc = locs[i]
			var btn = location_button_scene.instantiate()
			
			if btn.has_method("setup"):
				btn.setup(loc)
			else:
				btn.text = loc.get("name", "未知地点")
			
			btn.pressed.connect(_on_location_pressed.bind(loc.get("id", "")))
			
			# Use position from data, or fallback if not set
			var target_pos = loc.get("map_position", Vector2.ZERO)
			if target_pos == Vector2.ZERO:
				target_pos = fallback_positions[i % fallback_positions.size()]
			
			btn.position = target_pos
			
			# Add to container
			sub_area_container.add_child(btn)
			
			# Add animation
			btn.scale = Vector2.ZERO
			btn.pivot_offset = btn_size / 2
			var tween = create_tween()
			tween.tween_property(btn, "scale", Vector2.ONE, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK).set_delay(i * 0.1)

func _on_location_pressed(location_id: String):
	# Transition to exploration map
	location_selected.emit(location_id)
	
	var loc_data = MapDataManager.get_location(location_id)
	if loc_data and loc_data.has("scene_path"):
		var path = loc_data["scene_path"]
		if ResourceLoader.exists(path):
			get_tree().change_scene_to_file(path)
		else:
			print("[WorldMap] Scene not found: ", path)
