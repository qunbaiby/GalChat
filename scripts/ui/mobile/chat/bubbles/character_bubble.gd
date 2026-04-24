extends HBoxContainer

@onready var avatar_rect = $AvatarMargin/AvatarPanel/AvatarRect
@onready var avatar_panel = $AvatarMargin/AvatarPanel
@onready var bubble_panel = $BubblePanel
@onready var content_container = $BubblePanel/MarginContainer/ContentContainer
@onready var margin_container = $BubblePanel/MarginContainer

var text_style: StyleBoxFlat
var rp_style: StyleBoxFlat

func _ready():
	alignment = BoxContainer.ALIGNMENT_BEGIN
	
	# Avatar rounding
	var avatar_style = StyleBoxFlat.new()
	avatar_style.bg_color = Color.WHITE
	avatar_style.corner_radius_top_left = 20
	avatar_style.corner_radius_top_right = 20
	avatar_style.corner_radius_bottom_left = 20
	avatar_style.corner_radius_bottom_right = 20
	avatar_panel.add_theme_stylebox_override("panel", avatar_style)
	
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
	rp_style.bg_color = Color(0.96, 0.6, 0.25, 1) # WeChat red packet orange-red
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
		if ResourceLoader.exists(char_profile.avatar_path):
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
		if ResourceLoader.exists("res://assets/images/icons/ui/stats/red_packet.svg"):
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
		
		# Set a fixed minimum width for the red packet
		margin_container.custom_minimum_size = Vector2(220, 70)
		
		content_container.add_child(rp_margin)
		
		bubble_panel.mouse_filter = Control.MOUSE_FILTER_STOP
		if not bubble_panel.gui_input.is_connected(_on_bubble_input.bind(msg)):
			bubble_panel.gui_input.connect(_on_bubble_input.bind(msg))
			
	elif is_voice:
		var wrapper = VBoxContainer.new()
		wrapper.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		
		var voice_row = HBoxContainer.new()
		voice_row.alignment = BoxContainer.ALIGNMENT_BEGIN
		voice_row.add_theme_constant_override("separation", 10)
		
		# Move the bubble logic into the voice row
		var voice_content = HBoxContainer.new()
		voice_content.add_theme_constant_override("separation", 5)
		var voice_icon = Label.new()
		voice_icon.text = "((•"
		voice_icon.add_theme_font_size_override("font_size", 16)
		voice_icon.add_theme_color_override("font_color", Color(0.22, 0.22, 0.22, 1))
		var dur_label = Label.new()
		dur_label.text = str(duration) + "\""
		dur_label.add_theme_font_size_override("font_size", 16)
		dur_label.add_theme_color_override("font_color", Color(0.22, 0.22, 0.22, 1))
		voice_content.add_child(voice_icon)
		voice_content.add_child(dur_label)
		
		content_container.add_child(voice_content)
		
		var min_w = 80
		var max_w = 180
		var calc_w = clamp(min_w + duration * 8, min_w, max_w)
		margin_container.custom_minimum_size = Vector2(calc_w, 40)
		
		# Add transcription button and red dot outside the bubble
		var transcribe_btn = Button.new()
		transcribe_btn.text = "转文字"
		transcribe_btn.add_theme_font_size_override("font_size", 12)
		transcribe_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var t_style = StyleBoxFlat.new()
		t_style.bg_color = Color(0.1, 0.08, 0.07, 0.8)
		t_style.corner_radius_top_left = 12
		t_style.corner_radius_top_right = 12
		t_style.corner_radius_bottom_left = 12
		t_style.corner_radius_bottom_right = 12
		t_style.content_margin_left = 8
		t_style.content_margin_right = 8
		t_style.content_margin_top = 4
		t_style.content_margin_bottom = 4
		transcribe_btn.add_theme_stylebox_override("normal", t_style)
		transcribe_btn.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		
		var red_dot = Label.new()
		red_dot.text = "•"
		red_dot.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
		red_dot.add_theme_font_size_override("font_size", 24)
		red_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		
		var is_read = msg.get("is_read", false)
		if not is_read:
			red_dot.show()
		else:
			red_dot.hide()
			
		# The panel itself should be reparented to voice_row
		var p_parent = bubble_panel.get_parent()
		if p_parent:
			var index = bubble_panel.get_index()
			p_parent.remove_child(bubble_panel)
			voice_row.add_child(bubble_panel)
			voice_row.add_child(red_dot)
			voice_row.add_child(transcribe_btn)
			wrapper.add_child(voice_row)
			p_parent.add_child(wrapper)
			p_parent.move_child(wrapper, index)
		
		var transcribed_panel = PanelContainer.new()
		transcribed_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		var tr_style = StyleBoxFlat.new()
		tr_style.bg_color = Color(0.14, 0.11, 0.1, 0.85)
		tr_style.corner_radius_top_left = 0
		tr_style.corner_radius_top_right = 15
		tr_style.corner_radius_bottom_left = 15
		tr_style.corner_radius_bottom_right = 15
		transcribed_panel.add_theme_stylebox_override("panel", tr_style)
		transcribed_panel.hide()
		
		var tr_margin = MarginContainer.new()
		tr_margin.add_theme_constant_override("margin_left", 16)
		tr_margin.add_theme_constant_override("margin_right", 16)
		tr_margin.add_theme_constant_override("margin_top", 12)
		tr_margin.add_theme_constant_override("margin_bottom", 12)
		
		var tr_label = RichTextLabel.new()
		tr_label.bbcode_enabled = true
		tr_label.text = "[color=#dddddd]%s[/color]" % text
		tr_label.fit_content = true
		tr_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tr_label.custom_minimum_size = Vector2(50, 0)
		var tr_max_w = 230.0
		tr_label.custom_minimum_size.x = min(tr_max_w, tr_label.get_theme_font("normal_font").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 20)
		if tr_label.custom_minimum_size.x > tr_max_w:
			tr_label.custom_minimum_size.x = tr_max_w
		tr_label.add_theme_font_size_override("normal_font_size", 14)
		tr_margin.add_child(tr_label)
		transcribed_panel.add_child(tr_margin)
		wrapper.add_child(transcribed_panel)
		
		transcribe_btn.pressed.connect(func():
			transcribed_panel.visible = not transcribed_panel.visible
			if transcribed_panel.visible:
				transcribe_btn.hide()
			if not is_read:
				red_dot.hide()
				var panel = get_tree().get_root().find_child("MobileChatPanel", true, false)
				if panel and panel.has_method("_mark_message_read"):
					panel._mark_message_read(text)
		)
		
		bubble_panel.mouse_filter = Control.MOUSE_FILTER_STOP
		bubble_panel.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				if not is_read:
					red_dot.hide()
					var panel = get_tree().get_root().find_child("MobileChatPanel", true, false)
					if panel and panel.has_method("_mark_message_read"):
						panel._mark_message_read(text)
				var panel = get_tree().get_root().find_child("MobileChatPanel", true, false)
				if panel and panel.has_method("_play_voice_message"):
					panel._play_voice_message(text)
		)
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
		
		img_rect.mouse_filter = Control.MOUSE_FILTER_STOP
		if not img_rect.gui_input.is_connected(_on_img_input.bind(text)):
			img_rect.gui_input.connect(_on_img_input.bind(text))
	else:
		var label = Label.new()
		label.text = text
		label.add_theme_font_size_override("font_size", 16)
		label.add_theme_color_override("font_color", Color(0.22, 0.22, 0.22, 1))
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		
		var font = ThemeDB.fallback_font
		if label.has_theme_font("font"):
			font = label.get_theme_font("font")
		var str_size = font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
		var max_w = 230.0
		label.custom_minimum_size = Vector2(min(str_size.x + 8.0, max_w), 0)
		
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content_container.add_child(label)

func _on_img_input(event: InputEvent, text: String):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var panel = get_tree().get_root().find_child("MobileChatPanel", true, false)
		if panel and panel.has_method("_show_image_fullscreen"):
			var img_path = text.replace("[img]", "").replace("[/img]", "")
			var tex = null
			if ResourceLoader.exists(img_path):
				tex = load(img_path)
			elif FileAccess.file_exists(img_path):
				var img = Image.load_from_file(img_path)
				if img:
					tex = ImageTexture.create_from_image(img)
			if tex:
				panel._show_image_fullscreen(tex, img_path, true)

func _on_bubble_input(event: InputEvent, msg: Dictionary):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var panel = get_tree().get_root().find_child("MobileChatPanel", true, false)
		if panel and panel.has_method("_on_red_packet_message_clicked"):
			panel._on_red_packet_message_clicked(msg)
