@tool
extends SceneTree

func _init():
	print("Generating bubbles...")
	
	# Create directories
	var dir = DirAccess.open("res://scripts/ui/mobile/chat")
	if not dir.dir_exists("bubbles"):
		dir.make_dir("bubbles")
		
	var sdir = DirAccess.open("res://scenes/ui/mobile/chat")
	if not sdir.dir_exists("bubbles"):
		sdir.make_dir("bubbles")
		
	# Write scripts
	var char_script_content = """extends HBoxContainer

@onready var avatar_rect = $AvatarMargin/AvatarRect
@onready var bubble_panel = $BubblePanel
@onready var content_container = $BubblePanel/MarginContainer/ContentContainer
@onready var margin_container = $BubblePanel/MarginContainer

var text_style: StyleBoxFlat
var rp_style: StyleBoxFlat

func _ready():
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	
	text_style = StyleBoxFlat.new()
	text_style.bg_color = Color(0.92, 0.92, 0.9, 1) # #EBEAE5 approx
	text_style.corner_radius_top_left = 0
	text_style.corner_radius_top_right = 15
	text_style.corner_radius_bottom_left = 15
	text_style.corner_radius_bottom_right = 15
	# Add shadow
	text_style.shadow_color = Color(0, 0, 0, 0.1)
	text_style.shadow_size = 4
	text_style.shadow_offset = Vector2(0, 2)
	
	rp_style = StyleBoxFlat.new()
	rp_style.bg_color = Color(0.85, 0.35, 0.25, 1)
	rp_style.corner_radius_top_left = 0
	rp_style.corner_radius_top_right = 12
	rp_style.corner_radius_bottom_left = 12
	rp_style.corner_radius_bottom_right = 12

func set_avatar(texture: Texture2D):
	if texture:
		avatar_rect.texture = texture

func setup(msg: Dictionary, char_profile: Dictionary = {}):
	# Clear previous content
	for child in content_container.get_children():
		child.queue_free()
		
	var msg_type = msg.get("type", "text")
	var text = msg.get("content", msg.get("text", ""))
	var is_voice = msg.get("is_voice", false)
	var duration = msg.get("duration", 0)
	
	# Load avatar from char_profile if available
	if char_profile and char_profile.has("avatar_path"):
		var tex = load(char_profile.avatar_path)
		if tex:
			set_avatar(tex)
	else:
		# Fallback to default character avatar or nothing
		pass
		
	bubble_panel.add_theme_stylebox_override("panel", text_style)
	
	# Reset margins
	margin_container.add_theme_constant_override("margin_left", 16)
	margin_container.add_theme_constant_override("margin_right", 16)
	margin_container.add_theme_constant_override("margin_top", 12)
	margin_container.add_theme_constant_override("margin_bottom", 12)
	
	if msg_type == "red_packet":
		var rp_style_copy = rp_style.duplicate()
		if msg.get("status") == "claimed":
			rp_style_copy.bg_color = Color(0.85, 0.35, 0.25, 0.6)
		bubble_panel.add_theme_stylebox_override("panel", rp_style_copy)
		
		# Reset margins for RP
		margin_container.add_theme_constant_override("margin_left", 0)
		margin_container.add_theme_constant_override("margin_right", 0)
		margin_container.add_theme_constant_override("margin_top", 0)
		margin_container.add_theme_constant_override("margin_bottom", 0)
		
		var rp_hbox = HBoxContainer.new()
		rp_hbox.add_theme_constant_override("separation", 10)
		
		var rp_icon = TextureRect.new()
		rp_icon.custom_minimum_size = Vector2(30, 40)
		rp_icon.texture = preload("res://assets/images/icons/ui/stats/red_packet.svg")
		rp_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rp_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rp_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		
		var rp_vbox = VBoxContainer.new()
		rp_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		rp_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var rp_title = Label.new()
		rp_title.text = text if text != "" else "恭喜发财，大吉大利"
		rp_title.add_theme_font_size_override("font_size", 14)
		rp_title.add_theme_color_override("font_color", Color.WHITE)
		rp_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		
		var rp_status = Label.new()
		rp_status.text = "已领取" if msg.get("status") == "claimed" else "微信红包"
		rp_status.add_theme_font_size_override("font_size", 12)
		rp_status.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
		
		rp_vbox.add_child(rp_title)
		rp_vbox.add_child(rp_status)
		rp_hbox.add_child(rp_icon)
		rp_hbox.add_child(rp_vbox)
		
		var rp_margin = MarginContainer.new()
		rp_margin.add_theme_constant_override("margin_left", 15)
		rp_margin.add_theme_constant_override("margin_right", 15)
		rp_margin.add_theme_constant_override("margin_top", 15)
		rp_margin.add_theme_constant_override("margin_bottom", 15)
		rp_margin.add_child(rp_hbox)
		
		content_container.add_child(rp_margin)
		
		bubble_panel.mouse_filter = Control.MOUSE_FILTER_STOP
		bubble_panel.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				var panel = get_tree().get_root().find_child("MobileChatPanel", true, false)
				if panel and panel.has_method("_on_red_packet_message_clicked"):
					panel._on_red_packet_message_clicked(msg)
		)
	elif is_voice:
		var voice_hbox = HBoxContainer.new()
		voice_hbox.alignment = HORIZONTAL_ALIGNMENT_LEFT
		voice_hbox.add_theme_constant_override("separation", 5)
		
		var voice_icon = Label.new()
		voice_icon.text = "((•"
		voice_icon.add_theme_font_size_override("font_size", 16)
		voice_icon.add_theme_color_override("font_color", Color(0.22, 0.22, 0.22, 1))
		
		var dur_label = Label.new()
		dur_label.text = str(duration) + "\\""
		dur_label.add_theme_font_size_override("font_size", 16)
		dur_label.add_theme_color_override("font_color", Color(0.22, 0.22, 0.22, 1))
		
		voice_hbox.add_child(voice_icon)
		voice_hbox.add_child(dur_label)
		content_container.add_child(voice_hbox)
		
		var min_w = 80
		var max_w = 180
		var calc_w = clamp(min_w + duration * 8, min_w, max_w)
		margin_container.custom_minimum_size = Vector2(calc_w, 40)
	elif text.begins_with("[img]") and text.ends_with("[/img]"):
		margin_container.add_theme_constant_override("margin_left", 0)
		margin_container.add_theme_constant_override("margin_right", 0)
		margin_container.add_theme_constant_override("margin_top", 0)
		margin_container.add_theme_constant_override("margin_bottom", 0)
		
		var trans_style = StyleBoxFlat.new()
		trans_style.bg_color = Color(0, 0, 0, 0)
		bubble_panel.add_theme_stylebox_override("panel", trans_style)
		
		var img_path = text.replace("[img]", "").replace("[/img]", "")
		var img_rect = TextureRect.new()
		img_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img_rect.custom_minimum_size = Vector2(200, 200)
		if ResourceLoader.exists(img_path):
			img_rect.texture = load(img_path)
		elif FileAccess.file_exists(img_path):
			var img = Image.load_from_file(img_path)
			if img:
				img_rect.texture = ImageTexture.create_from_image(img)
		
		content_container.add_child(img_rect)
	else:
		var label = Label.new()
		label.text = text
		label.add_theme_font_size_override("font_size", 16)
		label.add_theme_color_override("font_color", Color(0.22, 0.22, 0.22, 1))
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(0, 0)
		# Allow expanding up to a max width, then wrap
		# We'll use a hack to allow auto-resizing but max width
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		# Better text wrapping approach: wrap within container
		content_container.custom_minimum_size = Vector2(10, 0)
		# In a real game we might want to restrict max width to like 60-70% of screen width.
		# But since this is a mobile panel, it will wrap naturally if its parent restricts it.
		
		content_container.add_child(label)
"""
	var player_script_content = char_script_content.replace("extends HBoxContainer", "extends HBoxContainer").replace("text_style.bg_color = Color(0.92, 0.92, 0.9, 1) # #EBEAE5 approx", "text_style.bg_color = Color(0.46, 0.45, 0.53, 1) # #757488 approx").replace("text_style.corner_radius_top_left = 0", "text_style.corner_radius_top_left = 15").replace("text_style.corner_radius_top_right = 15", "text_style.corner_radius_top_right = 0").replace("Color(0.22, 0.22, 0.22, 1)", "Color.WHITE").replace("HORIZONTAL_ALIGNMENT_LEFT", "HORIZONTAL_ALIGNMENT_RIGHT").replace("avatar_rect = $AvatarMargin/AvatarRect", "avatar_rect = $AvatarMargin/AvatarRect").replace("((•", "•))")
	
	# Player specific setup overrides
	player_script_content = player_script_content.replace("""	# Load avatar from char_profile if available
	if char_profile and char_profile.has("avatar_path"):
		var tex = load(char_profile.avatar_path)
		if tex:
			set_avatar(tex)
	else:
		# Fallback to default character avatar or nothing
		pass""", """	# Load player avatar
	var tex = load("res://assets/images/characters/user/avatar.png")
	if tex:
		set_avatar(tex)
	else:
		# Try fallback to character profile if somehow needed or default
		pass""")
	
	var sys_script_content = """extends HBoxContainer

@onready var label = $PanelContainer/MarginContainer/Label

func setup(msg: Dictionary):
	alignment = HORIZONTAL_ALIGNMENT_CENTER
	var text = msg.get("content", msg.get("text", ""))
	label.text = text
"""

	# Write scripts
	var f1 = FileAccess.open("res://scripts/ui/mobile/chat/bubbles/character_bubble.gd", FileAccess.WRITE)
	f1.store_string(char_script_content)
	f1.close()
	
	var f2 = FileAccess.open("res://scripts/ui/mobile/chat/bubbles/player_bubble.gd", FileAccess.WRITE)
	f2.store_string(player_script_content)
	f2.close()
	
	var f3 = FileAccess.open("res://scripts/ui/mobile/chat/bubbles/system_bubble.gd", FileAccess.WRITE)
	f3.store_string(sys_script_content)
	f3.close()
	
	# Wait a frame to let scripts be registered by the ResourceLoader
	print("Scripts written. Creating scenes...")
	
	# Create Character Bubble Scene
	var char_hbox = HBoxContainer.new()
	char_hbox.name = "CharacterBubble"
	char_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	char_hbox.set_script(load("res://scripts/ui/mobile/chat/bubbles/character_bubble.gd"))
	
	var c_avatar_margin = MarginContainer.new()
	c_avatar_margin.name = "AvatarMargin"
	c_avatar_margin.custom_minimum_size = Vector2(40, 40)
	c_avatar_margin.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	c_avatar_margin.add_theme_constant_override("margin_left", 8)
	c_avatar_margin.add_theme_constant_override("margin_right", 8)
	c_avatar_margin.add_theme_constant_override("margin_top", 4)
	char_hbox.add_child(c_avatar_margin)
	c_avatar_margin.owner = char_hbox
	
	var c_avatar_rect = TextureRect.new()
	c_avatar_rect.name = "AvatarRect"
	c_avatar_rect.custom_minimum_size = Vector2(40, 40)
	c_avatar_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	c_avatar_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	c_avatar_margin.add_child(c_avatar_rect)
	c_avatar_rect.owner = char_hbox
	
	var c_bubble_panel = PanelContainer.new()
	c_bubble_panel.name = "BubblePanel"
	c_bubble_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	# Let label wrap naturally by restricting max width if we can, 
	# but for now SIZE_SHRINK_BEGIN is good.
	char_hbox.add_child(c_bubble_panel)
	c_bubble_panel.owner = char_hbox
	
	var c_margin = MarginContainer.new()
	c_margin.name = "MarginContainer"
	c_bubble_panel.add_child(c_margin)
	c_margin.owner = char_hbox
	
	var c_content = VBoxContainer.new()
	c_content.name = "ContentContainer"
	c_margin.add_child(c_content)
	c_content.owner = char_hbox
	
	var char_scene = PackedScene.new()
	char_scene.pack(char_hbox)
	ResourceSaver.save(char_scene, "res://scenes/ui/mobile/chat/bubbles/character_bubble.tscn")
	
	# Create Player Bubble Scene
	var player_hbox = HBoxContainer.new()
	player_hbox.name = "PlayerBubble"
	player_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_hbox.set_script(load("res://scripts/ui/mobile/chat/bubbles/player_bubble.gd"))
	
	# For player, bubble is first, then avatar
	var p_bubble_panel = PanelContainer.new()
	p_bubble_panel.name = "BubblePanel"
	p_bubble_panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	player_hbox.add_child(p_bubble_panel)
	p_bubble_panel.owner = player_hbox
	
	var p_margin = MarginContainer.new()
	p_margin.name = "MarginContainer"
	p_bubble_panel.add_child(p_margin)
	p_margin.owner = player_hbox
	
	var p_content = VBoxContainer.new()
	p_content.name = "ContentContainer"
	p_margin.add_child(p_content)
	p_content.owner = player_hbox
	
	var p_avatar_margin = MarginContainer.new()
	p_avatar_margin.name = "AvatarMargin"
	p_avatar_margin.custom_minimum_size = Vector2(40, 40)
	p_avatar_margin.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	p_avatar_margin.add_theme_constant_override("margin_left", 8)
	p_avatar_margin.add_theme_constant_override("margin_right", 8)
	p_avatar_margin.add_theme_constant_override("margin_top", 4)
	player_hbox.add_child(p_avatar_margin)
	p_avatar_margin.owner = player_hbox
	
	var p_avatar_rect = TextureRect.new()
	p_avatar_rect.name = "AvatarRect"
	p_avatar_rect.custom_minimum_size = Vector2(40, 40)
	p_avatar_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	p_avatar_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	p_avatar_margin.add_child(p_avatar_rect)
	p_avatar_rect.owner = player_hbox
	
	var player_scene = PackedScene.new()
	player_scene.pack(player_hbox)
	ResourceSaver.save(player_scene, "res://scenes/ui/mobile/chat/bubbles/player_bubble.tscn")
	
	# Create System Bubble Scene
	var sys_hbox = HBoxContainer.new()
	sys_hbox.name = "SystemBubble"
	sys_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sys_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	sys_hbox.set_script(load("res://scripts/ui/mobile/chat/bubbles/system_bubble.gd"))
	
	var sys_panel = PanelContainer.new()
	sys_panel.name = "PanelContainer"
	var sys_style = StyleBoxFlat.new()
	sys_style.bg_color = Color(0, 0, 0, 0.2)
	sys_style.corner_radius_top_left = 10
	sys_style.corner_radius_top_right = 10
	sys_style.corner_radius_bottom_left = 10
	sys_style.corner_radius_bottom_right = 10
	sys_panel.add_theme_stylebox_override("panel", sys_style)
	sys_hbox.add_child(sys_panel)
	sys_panel.owner = sys_hbox
	
	var sys_margin = MarginContainer.new()
	sys_margin.name = "MarginContainer"
	sys_margin.add_theme_constant_override("margin_left", 10)
	sys_margin.add_theme_constant_override("margin_right", 10)
	sys_margin.add_theme_constant_override("margin_top", 4)
	sys_margin.add_theme_constant_override("margin_bottom", 4)
	sys_panel.add_child(sys_margin)
	sys_margin.owner = sys_hbox
	
	var sys_label = Label.new()
	sys_label.name = "Label"
	sys_label.add_theme_font_size_override("font_size", 12)
	sys_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	sys_margin.add_child(sys_label)
	sys_label.owner = sys_hbox
	
	var sys_scene = PackedScene.new()
	sys_scene.pack(sys_hbox)
	ResourceSaver.save(sys_scene, "res://scenes/ui/mobile/chat/bubbles/system_bubble.tscn")
	
	print("Done generating bubbles.")
	quit()
