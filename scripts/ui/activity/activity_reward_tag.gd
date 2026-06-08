extends Label

func setup(stat_key: String, display_name: String, value: int) -> void:
	text = "%s +%d" % [display_name, value]
	
	var style: StyleBoxFlat = get_theme_stylebox("normal").duplicate() as StyleBoxFlat
	if style:
		if stat_key.begins_with("stat_"):
			style.bg_color = Color(0.94, 0.98, 0.97, 1)
			style.border_color = Color(0.57, 0.82, 0.76, 0.35)
			add_theme_color_override("font_color", Color(0.23, 0.58, 0.53, 1))
		else:
			style.bg_color = Color(1, 0.96, 0.9, 1)
			style.border_color = Color(0.93, 0.74, 0.42, 0.45)
			add_theme_color_override("font_color", Color(0.71, 0.46, 0.12, 1))
		add_theme_stylebox_override("normal", style)
