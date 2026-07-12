extends VBoxContainer

signal npc_clicked(npc_id: String)

const STORY_BADGE_ICON: Texture2D = preload("res://assets/images/icons/ui/main/street_menu_icon_task.png")

var npc_id: String = ""

@onready var avatar_mask: Control = $AvatarContainer/AvatarMask
@onready var state_ring: ColorRect = $AvatarContainer/StateRing
@onready var portrait: TextureRect = $AvatarContainer/AvatarMask/Portrait
@onready var portrait_bg: ColorRect = $AvatarContainer/AvatarMask/Portrait/PlaceholderBG
@onready var name_label: Label = $NameLabel
@onready var interact_button: Button = $AvatarContainer/InteractButton

var ring_time: float = 0.0
var story_badge_panel: PanelContainer = null
var story_badge_label: Label = null

func _ready() -> void:
	avatar_mask.draw.connect(_on_mask_draw)
	_ensure_story_badge()

func setup(id: String) -> void:
	npc_id = id
	
	var npc_data = MapDataManager.get_npc_data(npc_id)
	var npc_name = npc_data.get("name", npc_id)
	
	var char_file_path = "res://assets/data/characters/npc/" + npc_id + ".json"
	if npc_id == "luna":
		char_file_path = "res://assets/data/characters/luna.json"
		
	var portrait_texture = null
	var file = FileAccess.open(char_file_path, FileAccess.READ)
	if file:
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			var data = json.get_data()
			if data is Dictionary:
				npc_name = data.get("char_name", npc_name)
				var tex_path = data.get("avatar", "")
				if not tex_path.is_empty() and ResourceLoader.exists(tex_path):
					portrait_texture = load(tex_path)
	
	name_label.text = npc_name
	
	if portrait_texture:
		portrait.texture = portrait_texture
		portrait_bg.hide()
	else:
		var npc_type = npc_data.get("type", "random")
		# Placeholder logic for portrait background colors
		if npc_type == "resident":
			portrait_bg.color = Color(0.4, 0.8, 0.4)
		elif npc_id == "luna":
			portrait_bg.color = Color(0.8, 0.4, 0.4)
		elif npc_id == "ya":
			portrait_bg.color = Color(0.4, 0.4, 0.8)
		else:
			portrait_bg.color = Color(0.6, 0.6, 0.6)

func _process(delta: float) -> void:
	ring_time += delta
	if is_instance_valid(state_ring) and state_ring.material is ShaderMaterial:
		var mat = state_ring.material as ShaderMaterial
		var BASE_WIDTH = 0.022
		var BASE_BLUR = 0.015
		
		var breath = (sin(ring_time * 2.5) + 1.0) * 0.5
		var alpha_mod = lerp(0.15, 0.95, breath)
		var current_blur = lerp(BASE_BLUR, BASE_BLUR + 0.012, breath)
		
		mat.set_shader_parameter("color1", Color(0.4, 0.75, 1.0, alpha_mod))
		mat.set_shader_parameter("color2", Color(0.7, 0.95, 1.0, alpha_mod))
		mat.set_shader_parameter("blur", current_blur)

func _on_mask_draw() -> void:
	var center = avatar_mask.size / 2.0
	var radius = (min(avatar_mask.size.x, avatar_mask.size.y) / 2.0) - 3.0
	avatar_mask.draw_circle(center, radius, Color.WHITE)

func _on_interact_button_pressed():
	npc_clicked.emit(npc_id)

func set_selected(is_selected: bool) -> void:
	if state_ring:
		state_ring.visible = is_selected

func set_story_badge(text: String) -> void:
	_ensure_story_badge()
	var final_text := text.strip_edges()
	if story_badge_panel == null or story_badge_label == null:
		return
	story_badge_panel.visible = final_text != ""
	story_badge_label.text = final_text

func _ensure_story_badge() -> void:
	if story_badge_panel != null and is_instance_valid(story_badge_panel):
		return
	
	story_badge_panel = PanelContainer.new()
	story_badge_panel.name = "StoryBadge"
	story_badge_panel.visible = false
	story_badge_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	story_badge_panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	story_badge_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	story_badge_panel.offset_left = -86.0
	story_badge_panel.offset_top = 8.0
	story_badge_panel.offset_right = -8.0
	story_badge_panel.offset_bottom = 34.0
	
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = Color(0.7529412, 0.99607843, 0.9764706, 0.92)
	badge_style.border_width_left = 1
	badge_style.border_width_top = 1
	badge_style.border_width_right = 1
	badge_style.border_width_bottom = 1
	badge_style.border_color = Color(0.16, 0.76, 0.72, 0.95)
	badge_style.corner_radius_top_left = 12
	badge_style.corner_radius_top_right = 4
	badge_style.corner_radius_bottom_right = 12
	badge_style.corner_radius_bottom_left = 4
	badge_style.shadow_color = Color(0.06, 0.28, 0.27, 0.16)
	badge_style.shadow_size = 6
	badge_style.shadow_offset = Vector2(0, 2)
	story_badge_panel.add_theme_stylebox_override("panel", badge_style)
	
	var badge_margin := MarginContainer.new()
	badge_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge_margin.add_theme_constant_override("margin_left", 8)
	badge_margin.add_theme_constant_override("margin_top", 3)
	badge_margin.add_theme_constant_override("margin_right", 8)
	badge_margin.add_theme_constant_override("margin_bottom", 3)
	story_badge_panel.add_child(badge_margin)
	
	var badge_row := HBoxContainer.new()
	badge_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge_row.alignment = BoxContainer.ALIGNMENT_CENTER
	badge_row.add_theme_constant_override("separation", 4)
	badge_margin.add_child(badge_row)
	
	var badge_icon := TextureRect.new()
	badge_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge_icon.custom_minimum_size = Vector2(14, 14)
	badge_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	badge_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	badge_icon.texture = STORY_BADGE_ICON
	badge_row.add_child(badge_icon)
	
	story_badge_label = Label.new()
	story_badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	story_badge_label.text = "主线"
	story_badge_label.add_theme_color_override("font_color", Color(0.11, 0.37, 0.36, 1))
	story_badge_label.add_theme_font_size_override("font_size", 13)
	badge_row.add_child(story_badge_label)
	
	$AvatarContainer.add_child(story_badge_panel)
