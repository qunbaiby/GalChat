extends Button

var location_id: String = ""

func setup(loc_data: Dictionary) -> void:
	location_id = loc_data.get("id", "")
	text = loc_data.get("name", "未知地点")

	var event_hbox = get_node_or_null("EventHBox")
	if event_hbox:
		for child in event_hbox.get_children():
			child.queue_free()
		
		var events = loc_data.get("events", [])
		for evt in events:
			var lbl = Label.new()
			lbl.add_theme_font_size_override("font_size", 20)
			if evt == "main":
				lbl.text = "!"
				lbl.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2)) # Red
			elif evt == "side":
				lbl.text = "?"
				lbl.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2)) # Yellow
			elif evt == "bond":
				lbl.text = "♥"
				lbl.add_theme_color_override("font_color", Color(1.0, 0.4, 0.7)) # Pink
			event_hbox.add_child(lbl)

	var npc_hbox = get_node_or_null("NPCHBox")
	if npc_hbox:
		# Clear existing npc icons
		for child in npc_hbox.get_children():
			child.queue_free()
		
		var npcs = MapDataManager.generate_location_npcs(location_id)
		for npc_id in npcs:
			var npc_data = MapDataManager.get_npc_data(npc_id)
			var npc_name = npc_data.get("name", npc_id)
			var npc_type = npc_data.get("type", "random")
			
			# Create a visual representation for the NPC
			var icon = TextureRect.new()
			icon.custom_minimum_size = Vector2(40, 40)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			
			# TODO: Load real NPC avatar texture based on npc_id
			# Here we just use a colored rect as a placeholder avatar
			var bg = ColorRect.new()
			bg.color = Color(0.8, 0.8, 0.8) # Default gray for generic NPC
			if npc_type == "resident": bg.color = Color(0.4, 0.8, 0.4) # Greenish for resident
			if npc_id == "luna": bg.color = Color(1.0, 0.5, 0.5) # Reddish for luna
			if npc_id == "ya": bg.color = Color(0.5, 0.5, 1.0) # Blueish for ya
			bg.set_anchors_preset(Control.PRESET_FULL_RECT)
			icon.add_child(bg)
			
			var name_lbl = Label.new()
			name_lbl.text = npc_name.substr(0, 1).to_upper() # Show first letter
			name_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
			name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			name_lbl.add_theme_color_override("font_color", Color.BLACK)
			icon.add_child(name_lbl)
			
			npc_hbox.add_child(icon)

