extends Label

func setup(stat_key: String, display_name: String, value: int) -> void:
	text = "%s +%d" % [display_name, value]
	
	var style = get_theme_stylebox("normal").duplicate() as StyleBoxFlat
	if style:
		if stat_key.begins_with("stat_"):
			style.bg_color = Color(0.4, 0.6, 0.9)
		else:
			style.bg_color = Color(0.9, 0.6, 0.2)
		add_theme_stylebox_override("normal", style)
