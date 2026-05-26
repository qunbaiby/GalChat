extends Control

signal back_requested
signal character_selected(char_id: String)

@onready var back_btn: Button = $Panel/VBox/TopBar/BackBtn
@onready var contact_list: VBoxContainer = $Panel/VBox/ScrollContainer/ContactList

func _ready() -> void:
	back_btn.pressed.connect(_on_back_pressed)
	_load_contacts()

func _load_contacts() -> void:
	# 清空列表
	for child in contact_list.get_children():
		child.queue_free()
		
	var contacts = []
	
	# Load main characters
	var dir = DirAccess.open("res://assets/data/characters")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".json") and not file_name.ends_with("_stages.json"):
				var char_id = file_name.replace(".json", "")
				contacts.append(_get_char_info(char_id, "res://assets/data/characters/" + file_name))
			file_name = dir.get_next()
			
	# Load NPCs
	var npc_dir = DirAccess.open("res://assets/data/characters/npc")
	if npc_dir:
		npc_dir.list_dir_begin()
		var file_name = npc_dir.get_next()
		while file_name != "":
			if file_name.ends_with(".json") and not file_name.ends_with("_stages.json"):
				var char_id = file_name.replace(".json", "")
				contacts.append(_get_char_info(char_id, "res://assets/data/characters/npc/" + file_name))
			file_name = npc_dir.get_next()
			
	# Sort contacts by last message time (newest first)
	contacts.sort_custom(func(a, b):
		return a.raw_time > b.raw_time
	)
	
	for c in contacts:
		_create_contact_item(c)

func _get_char_info(char_id: String, file_path: String) -> Dictionary:
	var info = {
		"id": char_id,
		"name": char_id,
		"avatar": "",
		"last_msg": "暂无消息",
		"last_time": "",
		"raw_time": "",
		"unread_count": 0
	}
	
	if FileAccess.file_exists(file_path):
		var file = FileAccess.open(file_path, FileAccess.READ)
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
			info.name = json.data.get("char_name", char_id)
			info.avatar = json.data.get("avatar", json.data.get("static_portrait", ""))
			
	# Get last message from mobile chat history
	var history_path = "user://saves/%s/mobile_chat_history.json" % char_id
	if FileAccess.file_exists(history_path):
		var file = FileAccess.open(history_path, FileAccess.READ)
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK and json.data is Array:
			var mobile_msgs = json.data
			if mobile_msgs.size() > 0:
				var last = mobile_msgs[-1]
				var raw_text = last.get("text", last.get("content", "..."))
				
				# If it's an image
				if raw_text.begins_with("[img]") and raw_text.ends_with("[/img]"):
					raw_text = "[图片]"
				
				# Strip BBCode tags (like [color=green]...[/color])
				var regex = RegEx.new()
				regex.compile("\\[.*?\\]")
				raw_text = regex.sub(raw_text, "", true)
				
				info.last_msg = raw_text
				info.raw_time = last.get("time", "")
				info.last_time = _format_time(info.raw_time)
				for msg in mobile_msgs:
					var speaker = msg.get("speaker", msg.get("role", ""))
					if speaker != "player" and not msg.get("is_read", false):
						info.unread_count += 1
				
	return info

func _format_time(time_str: String) -> String:
	if time_str == "":
		return ""
	var parts = time_str.split(" ")
	if parts.size() < 2:
		parts = time_str.split("T")
	if parts.size() >= 2:
		var date_part = parts[0]
		var time_part = parts[1]
		var today = Time.get_date_string_from_system()
		var time_short = time_part.substr(0, 5) # HH:MM
		if date_part == today:
			return time_short
		else:
			var date_split = date_part.split("-")
			if date_split.size() >= 3:
				return date_split[1] + "-" + date_split[2] # MM-DD
	return time_str.substr(0, 10)

func _create_contact_item(info: Dictionary) -> void:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(0, 80)
	btn.flat = true
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.18, 1)
	style.border_width_bottom = 1
	style.border_color = Color(0.2, 0.2, 0.3)
	btn.add_theme_stylebox_override("normal", style)
	
	var hover_style = style.duplicate()
	hover_style.bg_color = Color(0.18, 0.18, 0.25, 1)
	btn.add_theme_stylebox_override("hover", hover_style)
	btn.add_theme_stylebox_override("pressed", hover_style)
	
	btn.pressed.connect(func(): _on_contact_selected(info.id))
	
	# HBox container for layout
	var hbox = HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 15)
	
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	btn.add_child(margin)
	margin.add_child(hbox)
	
	# Avatar
	var avatar_rect = TextureRect.new()
	avatar_rect.custom_minimum_size = Vector2(60, 60)
	avatar_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	avatar_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	if info.avatar != "" and ResourceLoader.exists(info.avatar):
		avatar_rect.texture = load(info.avatar)
	else:
		avatar_rect.texture = preload("res://icon.svg")
		
	# Avatar mask (circle)
	var mask_panel = PanelContainer.new()
	mask_panel.custom_minimum_size = Vector2(60, 60)
	mask_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mask_panel.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	var mask_style = StyleBoxFlat.new()
	mask_style.bg_color = Color.WHITE
	mask_style.corner_radius_top_left = 30
	mask_style.corner_radius_top_right = 30
	mask_style.corner_radius_bottom_left = 30
	mask_style.corner_radius_bottom_right = 30
	mask_panel.add_theme_stylebox_override("panel", mask_style)
	mask_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mask_panel.add_child(avatar_rect)
	
	hbox.add_child(mask_panel)
	
	# VBox for Text
	var text_vbox = VBoxContainer.new()
	text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	text_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(text_vbox)
	
	# Top row in Text VBox (Name + Time)
	var top_hbox = HBoxContainer.new()
	top_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_vbox.add_child(top_hbox)
	
	var name_lbl = Label.new()
	name_lbl.text = info.name
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	name_lbl.add_theme_font_size_override("font_size", 16)
	top_hbox.add_child(name_lbl)
	
	var time_lbl = Label.new()
	time_lbl.text = info.last_time
	time_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	time_lbl.add_theme_font_size_override("font_size", 12)
	top_hbox.add_child(time_lbl)
	
	if int(info.get("unread_count", 0)) > 0:
		var unread_badge = Label.new()
		unread_badge.text = str(min(int(info.unread_count), 99))
		unread_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		unread_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		unread_badge.custom_minimum_size = Vector2(22, 22)
		unread_badge.add_theme_font_size_override("font_size", 11)
		unread_badge.add_theme_color_override("font_color", Color.WHITE)
		var badge_style = StyleBoxFlat.new()
		badge_style.bg_color = Color(0.92, 0.27, 0.27)
		badge_style.corner_radius_top_left = 11
		badge_style.corner_radius_top_right = 11
		badge_style.corner_radius_bottom_left = 11
		badge_style.corner_radius_bottom_right = 11
		unread_badge.add_theme_stylebox_override("normal", badge_style)
		top_hbox.add_child(unread_badge)
	
	# Bottom row in Text VBox (Last Message)
	var msg_lbl = Label.new()
	msg_lbl.text = info.last_msg
	msg_lbl.add_theme_color_override("font_color", Color(0.95, 0.95, 0.98) if int(info.get("unread_count", 0)) > 0 else Color(0.6, 0.6, 0.7))
	msg_lbl.add_theme_font_size_override("font_size", 14)
	msg_lbl.clip_text = true
	msg_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	msg_lbl.custom_minimum_size = Vector2(0, 20)
	text_vbox.add_child(msg_lbl)
	
	contact_list.add_child(btn)

func _on_contact_selected(char_id: String) -> void:
	character_selected.emit(char_id)

func _on_back_pressed() -> void:
	back_requested.emit()
	
func show_panel() -> void:
	show()
	_load_contacts() # 每次显示时重新加载，更新最新消息
	# 滑入动画
	position.x = size.x
	modulate.a = 0.0
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:x", 0.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, 0.2)

func hide_panel() -> void:
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:x", size.x, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.chain().tween_callback(self.hide)
