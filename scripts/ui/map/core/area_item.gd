extends PanelContainer

signal pressed(area_id: String)

@onready var background: TextureRect = $Mask/ClipControl/Background
@onready var name_label: Label = $Mask/ClipControl/VBoxContainer/NameLabel
@onready var en_name_label: Label = $Mask/ClipControl/VBoxContainer/EnNameLabel
@onready var button: Button = $Button
@onready var gradient: TextureRect = $Mask/ClipControl/Gradient

var area_id: String = ""

func _ready():
	button.pressed.connect(_on_button_pressed)
	button.mouse_entered.connect(_on_hover)
	button.mouse_exited.connect(_on_unhover)
	
	# Create a vertical gradient
	var grad = GradientTexture2D.new()
	var g = Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.9))
	g.set_color(1, Color(1, 1, 1, 0.0))
	grad.gradient = g
	grad.fill_from = Vector2(0, 0)
	grad.fill_to = Vector2(0, 1)
	gradient.texture = grad
	gradient.modulate = Color.WHITE # Texture will modulate this

func setup(id: String, area_data: Dictionary):
	area_id = id
	name_label.text = area_data.get("name", "未知区域")
	
	# Simple pinyin/english mock if not provided
	var en_names = {
		"qingyu_street": "QINGYU STREET",
		"j11_center": "J11 CENTER",
		"qinglan_mt": "QINGLAN MOUNTAIN",
		"jiangyu_bay": "JIANGYU BAY",
		"art_academy": "ART ACADEMY"
	}
	en_name_label.text = area_data.get("en_name", en_names.get(id, "AREA"))
	
	# Load background image
	var bg_id = area_data.get("bg_id", area_data.get("bg_path", ""))
	var bg_path = ""
	
	if bg_id != "":
		bg_path = ImageManager.get_image_path(bg_id)
		if bg_path == "":
			bg_path = bg_id # Fallback
			
	if bg_path == "" or not ResourceLoader.exists(bg_path):
		# Try to find a fallback background based on locations
		var locs = area_data.get("fixed_locations", [])
		if locs.size() == 0:
			locs = area_data.get("limited_locations", [])
			
		if locs.size() > 0:
			var first_loc = MapDataManager.get_location(locs[0])
			var loc_bg_id = first_loc.get("bg_id", first_loc.get("bg_path", ""))
			if loc_bg_id != "":
				bg_path = ImageManager.get_image_path(loc_bg_id)
				if bg_path == "":
					bg_path = loc_bg_id # Fallback
	
	if bg_path != "" and ResourceLoader.exists(bg_path):
		background.texture = load(bg_path)
	else:
		# Fallback texture: a placeholder gradient
		var placeholder = GradientTexture2D.new()
		placeholder.width = 256
		placeholder.height = 256
		var gradient_res = Gradient.new()
		gradient_res.add_point(0, Color(0.9, 0.9, 0.9))
		placeholder.gradient = gradient_res
		background.texture = placeholder

func _on_button_pressed():
	pressed.emit(area_id)

func _on_hover():
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.02, 1.02), 0.2).set_trans(Tween.TRANS_SINE)
	
func _on_unhover():
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_SINE)
