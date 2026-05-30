extends Label

func setup(cost_type: String, value: int) -> void:
	var style = get_theme_stylebox("normal")
	if style:
		style = style.duplicate() as StyleBoxFlat
	else:
		style = StyleBoxFlat.new()
		style.content_margin_left = 6
		style.content_margin_right = 6
		style.content_margin_top = 2
		style.content_margin_bottom = 2
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_left = 4
		style.corner_radius_bottom_right = 4
		
	match cost_type:
		"gold":
			text = "金币 -%d" % value
			add_theme_color_override("font_color", Color(0.8, 0.6, 0.2))
			style.bg_color = Color(0.8, 0.6, 0.2, 0.15)
		"mood_decrease":
			text = "心情 %d" % value
			add_theme_color_override("font_color", Color(0.3, 0.5, 0.8))
			style.bg_color = Color(0.3, 0.5, 0.8, 0.15)
		"mood_increase":
			text = "心情 +%d" % value
			add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))
			style.bg_color = Color(0.3, 0.8, 0.3, 0.15)
		"stress_increase":
			text = "压力 +%d" % value
			add_theme_color_override("font_color", Color(0.8, 0.4, 0.4))
			style.bg_color = Color(0.8, 0.4, 0.4, 0.15)
		"stress_decrease":
			text = "压力 %d" % value
			add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))
			style.bg_color = Color(0.4, 0.8, 0.4, 0.15)
		_:
			text = "%s %d" % [cost_type, value]
			
	add_theme_stylebox_override("normal", style)
