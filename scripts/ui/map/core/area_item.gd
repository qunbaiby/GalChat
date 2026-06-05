extends PanelContainer

signal pressed(area_id: String)

@onready var background: TextureRect = $Mask/ClipControl/Background
@onready var name_label: Label = $Mask/ClipControl/VBoxContainer/NameLabel
@onready var en_name_label: Label = $Mask/ClipControl/VBoxContainer/EnNameLabel
@onready var button: Button = $Button
@onready var gradient: TextureRect = $Mask/ClipControl/Gradient
@onready var dots_label: Label = $Mask/ClipControl/BottomBar/HBoxContainer/Dots
@onready var arrow_label: Label = $Mask/ClipControl/BottomBar/HBoxContainer/Arrow
@onready var locked_overlay: ColorRect = $Mask/ClipControl/LockedOverlay
@onready var lock_badge: PanelContainer = $Mask/ClipControl/LockBadge

var area_id: String = ""
var _is_locked: bool = false

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

func setup(id: String, area_data: Dictionary, is_unlocked: bool = true, lock_reason: String = ""):
	area_id = id
	_is_locked = not is_unlocked
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
	var bg_id = area_data.get("bg_id", "")
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
			var loc_bg_id = first_loc.get("bg_id", "")
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
	
	button.tooltip_text = lock_reason if _is_locked else ""
	locked_overlay.visible = _is_locked
	lock_badge.visible = _is_locked
	dots_label.text = "LOCK" if _is_locked else "●○○"
	arrow_label.text = "已锁定" if _is_locked else "进入 >"
	
	if _is_locked:
		background.modulate = Color(0.58, 0.6, 0.64, 1.0)
		gradient.modulate = Color(0.8, 0.82, 0.86, 0.95)
		name_label.add_theme_color_override("font_color", Color(0.9, 0.93, 0.96, 0.96))
		en_name_label.add_theme_color_override("font_color", Color(0.78, 0.82, 0.88, 0.92))
		dots_label.add_theme_color_override("font_color", Color(0.95, 0.96, 0.98, 0.92))
		arrow_label.add_theme_color_override("font_color", Color(0.95, 0.96, 0.98, 0.92))
	else:
		background.modulate = Color.WHITE
		gradient.modulate = Color.WHITE
		name_label.add_theme_color_override("font_color", Color(0.19, 0.22, 0.27, 1.0))
		en_name_label.add_theme_color_override("font_color", Color(0.52, 0.56, 0.62, 1.0))
		dots_label.add_theme_color_override("font_color", Color(0.99, 0.77, 0.44, 1.0))
		arrow_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1.0))

func _on_button_pressed():
	pressed.emit(area_id)

func _on_hover():
	if _is_locked:
		return
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.02, 1.02), 0.2).set_trans(Tween.TRANS_SINE)
	
func _on_unhover():
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_SINE)

func set_selected(is_selected: bool):
	var base_style := get_theme_stylebox("panel")
	if base_style == null:
		return
	var style = base_style.duplicate()
	if style is StyleBoxFlat:
		if is_selected and not _is_locked:
			style.border_width_left = 3
			style.border_width_top = 3
			style.border_width_right = 3
			style.border_width_bottom = 3
			style.border_color = Color(0.2, 0.8, 1.0, 0.9) # 亮蓝色边框
		else:
			style.border_width_left = 0
			style.border_width_top = 0
			style.border_width_right = 0
			style.border_width_bottom = 0
		add_theme_stylebox_override("panel", style)
